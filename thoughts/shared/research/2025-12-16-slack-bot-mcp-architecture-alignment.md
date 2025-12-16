---
date: 2025-12-16T17:37:25Z
researcher: Claude Code
git_commit: e3c9c5d54ca681e2ecddbb0ea550cc1e4d3b0a82
branch: main
repository: Tribal_Knowledge
topic: "Slack Bot MCP Architecture Alignment - Master vs chatbot_UI Branch Analysis"
tags: [research, codebase, slack-bot, mcp, architecture, fastmcp, company-mcp]
status: complete
last_updated: 2025-12-16
last_updated_by: Claude Code
last_updated_note: "Initial research with recommendations for plan alignment"
---

# Research: Slack Bot MCP Architecture Alignment

**Date**: 2025-12-16T17:37:25Z
**Researcher**: Claude Code
**Git Commit**: e3c9c5d54ca681e2ecddbb0ea550cc1e4d3b0a82
**Branch**: main
**Repository**: Tribal_Knowledge

## Research Question

The current Slack bot implementation plan is based on the `chatbot_UI` branch of company-mcp, which uses direct `sql_service.py` imports for SQL execution. The `master` branch takes a different approach - routing ALL requests through MCP tools using a multi-server registry pattern.

This research analyzes both approaches and provides recommendations for aligning the Slack bot plan with the master branch architecture.

## Summary

After analyzing the existing research and MCP client patterns, the **master branch approach is recommended** because:

1. **Cleaner Architecture**: Everything routes through MCP - no special routing logic needed
2. **Better Separation of Concerns**: Slack bot is purely an MCP client, no database dependencies
3. **Easier Testing**: Mock the MCP server, not multiple services
4. **Future-Proof**: Multi-server registry pattern supports scaling to additional services

The key change: **Remove direct `sql_service.py` import and instead ensure the MCP server exposes a `data_question` or `execute_sql` tool**.

## Detailed Findings

### Branch Comparison (from existing research)

| Aspect | chatbot_UI (Current Plan) | master (Recommended) |
|--------|---------------------------|----------------------|
| **Framework** | Flask | FastAPI |
| **LLM Provider** | OpenRouter (Claude) | OpenAI direct (GPT-4o) |
| **SQL Execution** | Direct `sql_service.py` import | Via MCP tools |
| **Routing Logic** | Complex (tool-specific routing) | Simple (all through MCP) |
| **Multi-Server** | No (single server) | Yes (registry pattern) |
| **Tool Loop** | Unlimited with token budget | 5 iterations max |

### Master Branch Architecture Pattern

Based on the research document (`2025-12-14-slack-bot-mcp-integration.md:157-217`):

```
┌──────────────────────────────────────────────────────────────┐
│                    SLACK BOT (Client Only)                    │
│  - Receives user messages                                     │
│  - Connects to MCP server(s)                                  │
│  - Sends queries to LLM with MCP tools                        │
│  - Returns responses to Slack                                 │
│  - NO database dependencies                                   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    MCP SERVER REGISTRY                        │
│  ┌─────────────────┐  ┌─────────────────┐                    │
│  │  company-mcp    │  │  future-mcp     │                    │
│  │  (schema tools) │  │  (other tools)  │                    │
│  │  + data_question│  │                 │                    │
│  └─────────────────┘  └─────────────────┘                    │
└──────────────────────────────────────────────────────────────┘
```

### Current Plan's Routing Logic (Complex)

The current plan (`2025-12-14-slack-bot-mcp-integration.md:1005-1033`) has this routing:

```python
# Current approach - COMPLEX
async def execute_tool(tool_name: str, arguments: dict) -> str:
    # Route data_question to sql_service for SQL generation and execution
    if tool_name == "data_question" and SQL_SERVICE_AVAILABLE:
        # Direct import of sql_service.py
        result = await loop.run_in_executor(
            None,
            lambda: generate_and_execute_sql(question, database)
        )
        return format_sql_result(result)

    # All other tools go to the MCP server
    mcp_client = get_mcp_client()
    return await mcp_client.call_tool(tool_name, arguments)
```

**Problems with this approach:**
1. Slack bot has direct dependency on `sql_service.py`
2. Requires database connection strings in Slack bot container
3. Inconsistent error handling (two different code paths)
4. Harder to test (must mock both MCP and sql_service)

### Recommended Architecture (Master Branch Style)

```python
# Recommended approach - SIMPLE
async def execute_tool(tool_name: str, arguments: dict) -> str:
    # ALL tools go through MCP - no special routing
    mcp_client = get_mcp_client()
    return await mcp_client.call_tool(tool_name, arguments)
```

**Benefits:**
1. Slack bot is a pure MCP client - no direct dependencies
2. Database credentials stay with MCP server (better security)
3. Single code path for all tools
4. Easy to test (mock one thing: MCP client)

### MCP Server Requirements

For this to work, the **company-mcp server must expose SQL execution as an MCP tool**. Based on FastMCP patterns, this would look like:

```python
# In company-mcp server.py
from fastmcp import FastMCP
from sql_service import generate_and_execute_sql

mcp = FastMCP("Company MCP")

@mcp.tool
def data_question(question: str, database: str = "postgres_production") -> dict:
    """
    Answer a data question using SQL.

    Args:
        question: Natural language question about the data
        database: Database to query (postgres_production or snowflake_production)

    Returns:
        SQL query and execution results
    """
    return generate_and_execute_sql(question, database)
```

### FastMCP Client Patterns (from web research)

The FastMCP 2.0 client supports multiple connection patterns:

**HTTP/SSE Connection (Recommended for Docker):**
```python
from fastmcp import Client

async with Client("http://mcp:8000/mcp") as client:
    tools = await client.list_tools()
    result = await client.call_tool("data_question", {
        "question": "How many users signed up last month?",
        "database": "postgres_production"
    })
```

**Multi-Server Registry (Future-proof):**
```python
config = {
    "mcpServers": {
        "company": {"url": "http://mcp:8000/mcp"},
        "analytics": {"url": "http://analytics:8000/mcp"}
    }
}

client = Client(config)
async with client:
    # Tools are prefixed with server name
    result = await client.call_tool("company__data_question", {"question": "..."})
```

## Recommendations for Plan Updates

### Phase 4 Changes: MCP Client Module

**Current** (`slack_bot/mcp_client.py`):
- Custom HTTP client using aiohttp
- Manual endpoint construction (`/tools`, `/tools/{name}`)
- Custom tool schema conversion

**Recommended**:
- Use FastMCP Python SDK's built-in `Client` class
- Handles all transport protocols automatically
- Built-in tool schema handling

```python
# slack_bot/mcp_client.py - SIMPLIFIED
from fastmcp import Client
import os

MCP_SERVER_URL = os.environ.get("MCP_SERVER_URL", "http://localhost:8000/mcp")

class MCPClient:
    def __init__(self, server_url: str = MCP_SERVER_URL):
        self.server_url = server_url
        self._client: Client | None = None

    async def connect(self):
        self._client = Client(self.server_url)
        await self._client.__aenter__()
        return self

    async def disconnect(self):
        if self._client:
            await self._client.__aexit__(None, None, None)

    async def list_tools(self) -> list:
        return await self._client.list_tools()

    async def call_tool(self, name: str, arguments: dict) -> str:
        result = await self._client.call_tool(name, arguments)
        return str(result)
```

### Phase 4 Changes: Message Handler

**Current** (`slack_bot/message_handler.py:1005-1033`):
- Special routing for `data_question` to `sql_service.py`
- Direct database dependencies
- Complex error handling

**Recommended**:
- Remove `sql_service.py` import entirely
- Remove all special routing logic
- Single code path: ALL tools → MCP server

```python
# slack_bot/message_handler.py - SIMPLIFIED
async def execute_tool(tool_name: str, arguments: dict) -> str:
    """Execute any tool through MCP server."""
    mcp_client = get_mcp_client()
    try:
        result = await mcp_client.call_tool(tool_name, arguments)
        return format_result(result)
    except Exception as e:
        logger.error(f"Tool execution failed: {tool_name} - {e}")
        return f"Error executing {tool_name}: {str(e)}"
```

### Phase 6 Changes: Docker Configuration

**Current** (`docker-compose.yml`):
- Slack bot has database credentials (POSTGRES_*, SNOWFLAKE_*)
- Slack bot imports `sql_service.py`

**Recommended**:
- Remove all database credentials from slack-bot service
- Slack bot only needs: Slack tokens, LLM keys, MCP_SERVER_URL
- Database credentials stay with MCP server only

```yaml
slack-bot:
  environment:
    # Slack credentials
    - SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN}
    - SLACK_APP_TOKEN=${SLACK_APP_TOKEN}
    - SLACK_SIGNING_SECRET=${SLACK_SIGNING_SECRET}
    # LLM configuration
    - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
    - OPENAI_API_KEY=${OPENAI_API_KEY}
    # MCP server (NO database credentials!)
    - MCP_SERVER_URL=http://mcp:8000/mcp
```

### New Dependency: FastMCP Client

Add to `requirements.txt`:
```
fastmcp>=2.13.3  # Already includes client
```

The FastMCP package includes both server and client functionality.

## MCP Server Prerequisites

Before implementing the simplified Slack bot, ensure the company-mcp server exposes:

1. **`data_question` tool** - for SQL generation and execution
2. **All schema tools** - `search_tables`, `list_columns`, etc.
3. **HTTP transport** - accessible at `http://mcp:8000/mcp`

If `data_question` is not currently exposed as an MCP tool, it needs to be added to the server before deploying the Slack bot.

## Code References

- Current plan routing logic: `thoughts/shared/plans/2025-12-14-slack-bot-mcp-integration.md:1005-1033`
- Master branch analysis: `thoughts/shared/research/2025-12-14-slack-bot-mcp-integration.md:157-217`
- FastMCP client patterns: https://github.com/jlowin/fastmcp

## Architecture Documentation

The recommended architecture follows these principles:

1. **MCP as the Integration Layer**: All database access happens through MCP tools, not direct imports
2. **Single Responsibility**: Slack bot handles Slack ↔ LLM communication only
3. **Credential Isolation**: Database credentials never leave the MCP server container
4. **Transport Agnostic**: FastMCP client handles HTTP/SSE/stdio automatically

## Related Research

- `thoughts/shared/research/2025-12-14-slack-bot-mcp-integration.md` - Original research document
- `thoughts/shared/plans/2025-12-14-slack-bot-mcp-integration.md` - Current implementation plan

## Open Questions

1. **MCP Server Status**: Does company-mcp master branch already expose `data_question` as an MCP tool, or does it need to be added?

2. **Tool Discovery Caching**: Should the Slack bot cache the tool list, or fetch fresh on each request? (Recommendation: cache with 5-minute TTL)

3. **Multi-Server Future**: If additional MCP servers are needed, should we implement the registry pattern now or defer?

4. **LLM Provider**: The master branch uses OpenAI direct. Should the Slack bot keep the OpenRouter → OpenAI fallback pattern from the current plan, or switch to OpenAI-only?
