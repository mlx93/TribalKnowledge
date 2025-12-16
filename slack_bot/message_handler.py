"""
Agentic Message Handler

Processes Slack messages using an agentic loop with MCP tools.

Flow:
1. Build LLM messages with system prompt and thread context
2. Send to LLM with tool definitions
3. If LLM returns tool_calls, execute via MCP client
4. Add tool results to messages
5. Repeat until LLM returns final response (max iterations)

Based on: Company-MCP/frontend/main.py
"""

import json
import logging
from typing import Optional, List, Dict, Any, Callable, Awaitable
from dataclasses import dataclass, field

from .llm_provider import LLMProvider, LLMResponse
from .mcp_client import MCPClient, parse_tool_name
from .thread_context import ThreadContext

logger = logging.getLogger(__name__)

# Maximum iterations for the agentic loop
MAX_ITERATIONS = 10

# Type for progress callback
ProgressCallback = Callable[[str], Awaitable[None]]


def build_system_prompt(tool_names: List[str]) -> str:
    """
    Build the system prompt for the Slack bot.
    
    Args:
        tool_names: List of available tool names
    """
    tool_list = ", ".join(tool_names[:20])
    if len(tool_names) > 20:
        tool_list += f" (and {len(tool_names) - 20} more)"
    
    return f"""You are a helpful AI assistant with access to database tools via MCP (Model Context Protocol) servers.

IMPORTANT: You MUST use the available tools to answer database-related questions. Don't guess - use the tools!

## Available Servers

**synth-mcp** - Schema Context Server
- Has pre-indexed documentation about database schemas
- Use for: discovering tables, understanding columns, finding relationships
- Key tools: search_tables, list_tables, get_table_schema, search_fts, search_vector

**postgres-mcp** - SQL Execution Server
- Executes read-only SQL queries against the live database
- Use for: running queries, getting actual data, verifying results
- Key tools: execute_query, describe_table, show_tables
- LIMITATIONS: Read-only (SELECT, WITH, EXPLAIN only), 1000 row limit, 30s timeout

## Tool Naming Convention

Tools are namespaced as "server_id__tool_name":
- synth-mcp__search_tables - Search for tables by keyword
- synth-mcp__get_table_schema - Get full schema for a table
- postgres-mcp__execute_query - Run SQL query
- postgres-mcp__describe_table - Get table columns

Available Tools ({len(tool_names)} total): {tool_list}

## Recommended Workflow

When answering database questions, follow this workflow:

1. **FIRST: Understand the schema** (use synth-mcp)
   - Use synth-mcp__search_tables to find relevant tables
   - Use synth-mcp__get_table_schema to understand table structure
   - Look at column names, types, and relationships

2. **THEN: Write accurate SQL** (based on schema)
   - Use the correct table names (tables are in "synthetic" schema)
   - Use the correct column names from the schema
   - Example: SELECT * FROM synthetic.merchants LIMIT 10

3. **FINALLY: Execute and present results** (use postgres-mcp)
   - Use postgres-mcp__execute_query to run your SQL
   - Format results nicely for Slack
   - If query fails, explain the error and try a corrected query

## IMPORTANT: Slack Formatting Rules

Slack has LIMITED markdown support. Follow these rules:

1. **For tables/data**: ALWAYS use triple backticks (```) to create code blocks:
   ```
   Column1    | Column2    | Column3
   -----------|------------|--------
   Value1     | Value2     | Value3
   ```

2. **Text formatting**: Use *bold* and _italic_ sparingly

3. **Lists**: Use simple bullet points with - or •

4. **Numbers/Money**: Format clearly: $1,234.56

5. **Keep it concise**: Slack threads should be scannable

Example of good table formatting:
```
Order ID | Customer        | Revenue      | Margin
---------|-----------------|--------------|--------
1001     | Acme Corp       | $50,000      | 35.2%
1002     | Widget Inc      | $32,500      | 42.1%
```

## Guidelines

1. ALWAYS use tools for database questions - don't make up data
2. If a tool returns an error, explain what went wrong
3. Be conversational and helpful
4. When uncertain, ask clarifying questions
5. Remember: you're in a Slack thread, so be concise
6. ALWAYS wrap tabular data in ``` code blocks for proper formatting"""


@dataclass
class ToolCallInfo:
    """Information about a tool call for progress updates."""
    server: str
    tool: str
    arguments: Dict[str, Any]
    status: str = "calling"  # "calling", "complete", "error"
    result_preview: Optional[str] = None


@dataclass
class ProcessingResult:
    """Result of processing a message."""
    response_text: str
    used_fallback: bool = False
    actual_model: str = ""
    tools_used: List[Dict[str, Any]] = field(default_factory=list)
    iterations: int = 0
    error: Optional[str] = None


def format_progress_message(
    tools_in_progress: List[ToolCallInfo],
    tools_completed: List[ToolCallInfo],
) -> str:
    """Format a progress message showing tool calls."""
    lines = ["🤔 *Working on it...*\n"]
    
    # Show completed tools
    for tool in tools_completed:
        if tool.status == "complete":
            lines.append(f"✅ `{tool.server}/{tool.tool}`")
        else:
            lines.append(f"❌ `{tool.server}/{tool.tool}` (error)")
    
    # Show in-progress tools
    for tool in tools_in_progress:
        args_preview = ""
        if tool.arguments:
            # Show a preview of the arguments
            if "sql" in tool.arguments:
                sql = tool.arguments["sql"][:50]
                args_preview = f" - `{sql}...`"
            elif "query" in tool.arguments:
                args_preview = f" - \"{tool.arguments['query']}\""
            elif "table" in tool.arguments:
                args_preview = f" - {tool.arguments['table']}"
        lines.append(f"⏳ `{tool.server}/{tool.tool}`{args_preview}")
    
    return "\n".join(lines)


async def process_message(
    user_message: str,
    context: ThreadContext,
    mcp_client: MCPClient,
    llm_provider: LLMProvider,
    on_progress: Optional[ProgressCallback] = None,
) -> ProcessingResult:
    """
    Process a user message through the agentic loop.
    
    Args:
        user_message: The user's message text
        context: Thread context with conversation history
        mcp_client: MCP client for tool calls
        llm_provider: LLM provider for AI calls
        on_progress: Optional callback for progress updates (receives formatted message)
    
    Returns:
        ProcessingResult with response and metadata
    """
    # Add user message to context
    context.add_user_message(user_message)
    
    # Get available tools
    tools = mcp_client.get_tools_for_llm()
    tool_names = [t["function"]["name"] for t in tools]
    
    # Build messages for LLM
    messages = [
        {"role": "system", "content": build_system_prompt(tool_names)}
    ]
    messages.extend(context.get_messages_for_llm(max_messages=15))
    
    tools_used = []
    tools_completed: List[ToolCallInfo] = []
    iteration = 0
    used_fallback = False
    actual_model = ""
    
    while iteration < MAX_ITERATIONS:
        iteration += 1
        logger.debug(f"Agentic loop iteration {iteration}/{MAX_ITERATIONS}")
        
        try:
            # Call LLM
            response = await llm_provider.call_with_fallback(
                messages=messages,
                tools=tools if tools else None,
                max_tokens=4096,
                temperature=0.0,
            )
            
            used_fallback = response.used_fallback
            actual_model = response.actual_model
            
            # Check for tool calls
            if response.tool_calls:
                logger.debug(f"LLM requested {len(response.tool_calls)} tool call(s)")
                
                # Add assistant message with tool calls
                assistant_msg = {
                    "role": "assistant",
                    "content": response.content or "",
                    "tool_calls": response.tool_calls,
                }
                messages.append(assistant_msg)
                context.add_assistant_message(response.content, response.tool_calls)
                
                # Execute each tool call
                for tool_call in response.tool_calls:
                    tool_id = tool_call["id"]
                    func = tool_call["function"]
                    full_name = func["name"]
                    
                    # Parse arguments (handle None or empty)
                    raw_args = func.get("arguments")
                    if raw_args:
                        try:
                            arguments = json.loads(raw_args)
                        except (json.JSONDecodeError, TypeError):
                            arguments = {}
                    else:
                        arguments = {}
                    
                    # Parse tool name
                    server_id, tool_name = parse_tool_name(full_name)
                    
                    # Create tool info for progress tracking
                    tool_info = ToolCallInfo(
                        server=server_id,
                        tool=tool_name,
                        arguments=arguments,
                        status="calling",
                    )
                    
                    # Send progress update
                    if on_progress:
                        progress_msg = format_progress_message([tool_info], tools_completed)
                        await on_progress(progress_msg)
                    
                    logger.info(f"Calling tool: {full_name}")
                    
                    # Execute tool via MCP
                    try:
                        tool_result = await mcp_client.call_tool(full_name, arguments)
                        tool_info.status = "complete"
                    except Exception as e:
                        tool_result = {"error": str(e)}
                        tool_info.status = "error"
                    
                    tools_completed.append(tool_info)
                    
                    # Record tool usage
                    tools_used.append({
                        "server": server_id,
                        "tool": tool_name,
                        "arguments": arguments,
                    })
                    
                    # Add tool result to messages
                    result_str = json.dumps(tool_result, default=str)
                    messages.append({
                        "role": "tool",
                        "tool_call_id": tool_id,
                        "content": result_str,
                    })
                    context.add_tool_result(tool_id, result_str)
                
                # Update progress to show all tools complete, waiting for LLM
                if on_progress:
                    progress_msg = format_progress_message([], tools_completed)
                    progress_msg += "\n\n💭 _Analyzing results..._"
                    await on_progress(progress_msg)
                
                # Continue loop to get LLM's response to tool results
                continue
            
            # No tool calls - this is the final response
            final_response = response.content or "I processed your request but have no response."
            
            # Add assistant response to context
            context.add_assistant_message(final_response)
            
            return ProcessingResult(
                response_text=final_response,
                used_fallback=used_fallback,
                actual_model=actual_model,
                tools_used=tools_used,
                iterations=iteration,
            )
        
        except Exception as e:
            logger.error(f"Error in agentic loop: {e}")
            return ProcessingResult(
                response_text=f"I encountered an error: {str(e)}",
                used_fallback=used_fallback,
                actual_model=actual_model,
                tools_used=tools_used,
                iterations=iteration,
                error=str(e),
            )
    
    # Max iterations reached
    logger.warning("Max iterations reached in agentic loop")
    return ProcessingResult(
        response_text="I reached the maximum number of tool calls. Here's what I found so far.",
        used_fallback=used_fallback,
        actual_model=actual_model,
        tools_used=tools_used,
        iterations=iteration,
    )


def format_response_for_slack(
    result: ProcessingResult,
    show_metadata: bool = True,
) -> str:
    """
    Format the processing result for Slack.
    
    Args:
        result: ProcessingResult from process_message
        show_metadata: Whether to include tool usage summary
    
    Returns:
        Formatted string for Slack
    """
    text = result.response_text
    
    # Add tool usage summary at the end
    if show_metadata and result.tools_used:
        tools_summary = ", ".join(
            f"`{t['server']}/{t['tool']}`"
            for t in result.tools_used
        )
        text += f"\n\n---\n🔧 _Used: {tools_summary}_"
    
    if result.used_fallback:
        text += f"\n⚠️ _Used fallback model: {result.actual_model}_"
    
    return text


def truncate_for_slack(text: str, max_length: int = 3000) -> str:
    """
    Truncate text to fit Slack's message limits.
    
    Slack block text has a ~3000 character limit.
    """
    if len(text) <= max_length:
        return text
    
    # Truncate and add indicator
    truncated = text[:max_length - 50]
    # Try to cut at a sensible point
    last_newline = truncated.rfind('\n')
    if last_newline > max_length - 500:
        truncated = truncated[:last_newline]
    
    return truncated + "\n\n... _(response truncated)_"
