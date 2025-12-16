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
    
    @property
    def detail(self) -> str:
        """Get a brief detail about what this tool is doing."""
        args = self.arguments
        
        # SQL execution
        if "sql" in args:
            sql = args["sql"]
            # Extract table name from SQL
            sql_upper = sql.upper()
            if "FROM " in sql_upper:
                # Find table after FROM
                idx = sql_upper.index("FROM ") + 5
                rest = sql[idx:].strip().split()[0] if idx < len(sql) else ""
                table = rest.replace("synthetic.", "").split()[0] if rest else ""
                return f"`{table}`" if table else ""
            return "_query_"
        
        # Table operations
        if "table" in args:
            return f"`{args['table']}`"
        if "table_name" in args:
            return f"`{args['table_name']}`"
        
        # Search queries
        if "query" in args:
            q = args["query"]
            return f'"{q[:30]}..."' if len(q) > 30 else f'"{q}"'
        
        # Limit for list operations
        if "limit" in args and not args.get("query"):
            return f"(limit {args['limit']})"
        
        return ""


@dataclass
class ProcessingResult:
    """Result of processing a message."""
    response_text: str
    used_fallback: bool = False
    actual_model: str = ""
    tools_used: List[Dict[str, Any]] = field(default_factory=list)
    iterations: int = 0
    error: Optional[str] = None
    sql_queries: List[str] = field(default_factory=list)  # SQL queries executed


def format_progress_message(
    tools_in_progress: List[ToolCallInfo],
    tools_completed: List[ToolCallInfo],
) -> str:
    """Format a progress message showing tool calls with details."""
    lines = ["🤔 *Working on it...*\n"]
    
    # Show completed tools with details
    for tool in tools_completed:
        detail = tool.detail
        detail_str = f" → {detail}" if detail else ""
        if tool.status == "complete":
            lines.append(f"✅ `{tool.tool}`{detail_str}")
        else:
            lines.append(f"❌ `{tool.tool}`{detail_str} (error)")
    
    # Show in-progress tools with details
    for tool in tools_in_progress:
        detail = tool.detail
        detail_str = f" → {detail}" if detail else ""
        lines.append(f"⏳ `{tool.tool}`{detail_str}")
    
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
    sql_queries: List[str] = []  # Track SQL queries
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
                    
                    # Record tool usage with detail
                    tools_used.append({
                        "server": server_id,
                        "tool": tool_name,
                        "arguments": arguments,
                        "detail": tool_info.detail,
                    })
                    
                    # Track SQL queries
                    if "sql" in arguments:
                        sql_queries.append(arguments["sql"])
                    
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
                sql_queries=sql_queries,
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
                sql_queries=sql_queries,
            )
    
    # Max iterations reached
    logger.warning("Max iterations reached in agentic loop")
    return ProcessingResult(
        response_text="I reached the maximum number of tool calls. Here's what I found so far.",
        used_fallback=used_fallback,
        actual_model=actual_model,
        tools_used=tools_used,
        iterations=iteration,
        sql_queries=sql_queries,
    )


def format_response_for_slack(
    result: ProcessingResult,
    show_metadata: bool = True,
) -> tuple[str, list]:
    """
    Format the processing result for Slack with blocks.
    
    Args:
        result: ProcessingResult from process_message
        show_metadata: Whether to include tool usage summary
    
    Returns:
        Tuple of (fallback_text, blocks)
    """
    blocks = []
    
    # Add tool usage summary at the TOP with details
    if show_metadata and result.tools_used:
        # Create detailed tool summary
        tool_lines = []
        for t in result.tools_used:
            detail = t.get('detail', '')
            if detail:
                tool_lines.append(f"`{t['tool']}` → {detail}")
            else:
                tool_lines.append(f"`{t['tool']}`")
        
        # Combine into compact format (max 10 shown)
        if len(tool_lines) > 10:
            tools_text = " • ".join(tool_lines[:10]) + f" _(+{len(tool_lines)-10} more)_"
        else:
            tools_text = " • ".join(tool_lines)
        
        blocks.append({
            "type": "context",
            "elements": [
                {"type": "mrkdwn", "text": f"🔧 {tools_text}"}
            ]
        })
        blocks.append({"type": "divider"})
    
    # Process the response text to create proper blocks
    response_blocks = _create_response_blocks(result.response_text)
    blocks.extend(response_blocks)
    
    # Add SQL query block if any queries were executed
    if result.sql_queries:
        blocks.append({"type": "divider"})
        
        # Show the last (most relevant) SQL query
        final_sql = result.sql_queries[-1]
        
        blocks.append({
            "type": "context",
            "elements": [
                {"type": "mrkdwn", "text": "📝 *SQL Query Executed:*"}
            ]
        })
        
        # Format SQL nicely
        blocks.append({
            "type": "rich_text",
            "elements": [
                {
                    "type": "rich_text_preformatted",
                    "elements": [
                        {"type": "text", "text": final_sql[:2000]}  # Slack limit
                    ]
                }
            ]
        })
    
    # Add fallback model warning if used
    if result.used_fallback:
        blocks.append({
            "type": "context",
            "elements": [
                {"type": "mrkdwn", "text": f"⚠️ _Used fallback: {result.actual_model}_"}
            ]
        })
    
    # Fallback text for notifications
    fallback_text = result.response_text[:500] + "..." if len(result.response_text) > 500 else result.response_text
    
    return fallback_text, blocks


def _create_response_blocks(text: str) -> list:
    """
    Convert response text into Slack blocks, properly handling code blocks.
    
    Splits text on ``` to separate code blocks from regular text.
    """
    blocks = []
    
    # Split on code block markers
    parts = text.split("```")
    
    for i, part in enumerate(parts):
        if not part.strip():
            continue
            
        if i % 2 == 0:
            # Regular text (outside code blocks)
            # Split into chunks if too long (Slack limit is ~3000 chars per block)
            text_chunks = _chunk_text(part.strip(), 2900)
            for chunk in text_chunks:
                if chunk:
                    blocks.append({
                        "type": "section",
                        "text": {"type": "mrkdwn", "text": chunk}
                    })
        else:
            # Code block content
            code_content = part.strip()
            # Remove language hint if present (e.g., ```sql)
            if code_content and '\n' in code_content:
                first_line = code_content.split('\n')[0]
                if first_line.isalpha() and len(first_line) < 15:
                    code_content = '\n'.join(code_content.split('\n')[1:])
            
            if code_content:
                # Use rich_text block for proper code formatting
                blocks.append({
                    "type": "rich_text",
                    "elements": [
                        {
                            "type": "rich_text_preformatted",
                            "elements": [
                                {"type": "text", "text": code_content[:3000]}  # Slack limit
                            ]
                        }
                    ]
                })
    
    # If no blocks were created, add the text as-is
    if not blocks and text.strip():
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": text[:2900]}
        })
    
    return blocks


def _chunk_text(text: str, max_length: int) -> List[str]:
    """Split text into chunks at paragraph boundaries."""
    if len(text) <= max_length:
        return [text]
    
    chunks = []
    current = ""
    
    for paragraph in text.split("\n\n"):
        if len(current) + len(paragraph) + 2 <= max_length:
            current += ("\n\n" if current else "") + paragraph
        else:
            if current:
                chunks.append(current)
            current = paragraph[:max_length]
    
    if current:
        chunks.append(current)
    
    return chunks


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
