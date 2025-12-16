---
date: 2025-12-16T11:45:00-08:00
researcher: mlx93
git_commit: e3c9c5d54ca681e2ecddbb0ea550cc1e4d3b0a82
branch: main
repository: Tribal_Knowledge
topic: "Company-MCP Master Branch Architecture for Slack Bot Integration"
tags: [research, codebase, company-mcp, mcp, slack-bot, architecture]
status: complete
last_updated: 2025-12-16
last_updated_by: mlx93
---

# Research: Company-MCP Master Branch Architecture for Slack Bot Integration

**Date**: 2025-12-16T11:45:00-08:00
**Researcher**: mlx93
**Git Commit**: e3c9c5d54ca681e2ecddbb0ea550cc1e4d3b0a82
**Branch**: main
**Repository**: Tribal_Knowledge (containing Company-MCP clone)

## Research Question

Understanding the Company-MCP master branch architecture to determine:
1. How does frontend/main.py handle SQL execution?
2. What MCP tools are exposed and their schemas?
3. How does the agentic loop work?
4. What HTTP endpoints does the MCP server expose?
5. What are the differences between master and chatbot_UI branches?
6. Should the Slack bot route through MCP HTTP API or import sql_service.py directly?

## Summary

**The master branch uses a pure MCP HTTP API approach** - all SQL execution goes through the `postgres-mcp` server's `execute_query` tool via HTTP JSON-RPC calls. There is no direct import of `sql_service.py` in the master branch. This architecture is ideal for the Slack bot, which should route all tool calls through MCP's HTTP API.

**Key Finding**: The Slack bot should use **Option A: Route all tool calls through MCP's HTTP API**. This is simpler, requires no code sharing, and maintains the same security boundaries as the web UI.

## Detailed Findings

### 1. SQL Execution Flow in Master Branch

**Location**: `Company-MCP/frontend/main.py`

The frontend does NOT call sql_service.py directly. SQL execution follows this path:

```
User Question → GPT-4o → Tool Call Decision → call_mcp_tool_on_server()
→ HTTP POST to postgres-mcp → execute_query tool → PostgreSQL → Response
```

**Key Function**: `call_mcp_tool_on_server()` (lines 541-619)

```python
async def call_mcp_tool_on_server(server_url: str, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
    """Call a specific tool on an MCP server using session-based protocol."""
    # 1. Normalize URL for Docker internal networking
    server_url = normalize_mcp_url(server_url)
    mcp_endpoint = get_mcp_endpoint(server_url)

    # 2. Initialize MCP session (JSON-RPC)
    init_payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "CompanyMCP-Frontend", "version": "1.0.0"}
        }
    }
    init_response = await http_client.post(mcp_endpoint, json=init_payload, headers=headers)
    session_id = init_response.headers.get("mcp-session-id")

    # 3. Call tool with session
    tool_payload = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments
        }
    }
    headers["mcp-session-id"] = session_id
    response = await http_client.post(mcp_endpoint, json=tool_payload, headers=headers)
```

### 2. MCP Tools Exposed by server.py (Schema Context Server)

**Location**: `Company-MCP/server.py`

This server provides database schema context and search capabilities. It runs as multiple instances (`mcp-dabstep`, `mcp-synth`) with different data directories.

| Tool Name | Arguments | Description |
|-----------|-----------|-------------|
| `add` | `a: float, b: float` | Test tool for addition |
| `echo` | `message: str` | Connectivity test |
| `search_db_map` | `query: str, top_k: int=3` | Token overlap search on curated map |
| `search_fts` | `query, database?, domain?, doc_type?, limit=10` | FTS5 BM25 full-text search |
| `search_vector` | `query, database?, domain?, doc_type?, limit=10` | OpenAI embedding semantic search |
| `list_tables` | `database?, domain?` | List tables with metadata |
| `list_columns` | `table, database?` | Get column details for a table |
| `search_tables` | `query, database?, domain?, limit=5` | Natural language table search |
| `get_table_schema` | `table, database?, include_samples=False` | Full schema with columns, keys, indexes |
| `get_join_path` | `source_table, target_table, database?, max_hops=3` | FK graph traversal for join paths |
| `get_domain_overview` | `domain, database?` | Tables in a business domain |
| `list_domains` | `database?` | All business domains |
| `list_databases` | - | All indexed databases |
| `get_common_relationships` | `database?, domain?, limit=10` | Frequent FK join patterns |
| `get_column_usage` | `column_name, database?, domain?, include_patterns=True` | Tables sharing a column + join patterns |

### 3. MCP Tools Exposed by postgres-mcp/server.py (Database Execution Server)

**Location**: `Company-MCP/postgres-mcp/server.py`

This server provides read-only SQL execution against PostgreSQL.

| Tool Name | Arguments | Description |
|-----------|-----------|-------------|
| `list_schemas` | - | List all database schemas |
| `list_tables` | `schema="synthetic"` | Tables in a schema with row estimates |
| `describe_table` | `table, schema="synthetic"` | Columns, PKs, FKs, indexes |
| `execute_query` | `sql, limit=100` | **Read-only SQL execution** |
| `search_tables` | `query, schema?` | ILIKE pattern table search |
| `get_sample_data` | `table, schema="synthetic", limit=5` | Sample rows from table |
| `get_table_stats` | `table, schema="synthetic"` | Row count, sizes, vacuum info |
| `echo` | `message` | Connectivity test |
| `test_connection` | - | Database connection status |

**SQL Security** (lines 57-78):
- Only `SELECT`, `WITH`, `EXPLAIN`, `SHOW`, `TABLE` allowed
- Forbidden: `INSERT`, `UPDATE`, `DELETE`, `DROP`, `CREATE`, `ALTER`, `TRUNCATE`, etc.
- 30-second statement timeout
- Max 1000 rows returned

### 4. Agentic Loop Implementation

**Location**: `Company-MCP/frontend/main.py` lines 698-918 (`chat_stream`)

The agentic loop follows this pattern:

```
1. Fetch tools from all enabled MCP servers (get_all_mcp_tools)
2. Convert to OpenAI function calling format (server_id__tool_name)
3. Build system prompt with tool list and workflow guidance
4. Loop (max 10 iterations):
   a. Call GPT-4o with messages + tools
   b. If tool_calls in response:
      - Execute each tool via call_mcp_tool_on_server()
      - Add tool results to message history
      - Continue loop
   c. If no tool_calls:
      - Stream final response
      - Exit loop
```

**Tool Naming Convention**: Tools are namespaced as `{server_id}__{tool_name}`:
- `synth-mcp__search_tables`
- `postgres-mcp__execute_query`

**System Prompt Workflow** (lines 632-687):
1. Use synth-mcp to understand schema (search_tables, get_table_schema)
2. Write SQL based on learned schema
3. Use postgres-mcp__execute_query to run SQL

### 5. HTTP API Contract for MCP Servers

**Protocol**: MCP JSON-RPC over HTTP with SSE (Server-Sent Events)

**Endpoint**: `{server_url}/mcp`

**Request Headers**:
```
Content-Type: application/json
Accept: application/json, text/event-stream
mcp-session-id: {session_id}  # After initialization
```

**Step 1 - Initialize Session**:
```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "SlackBot", "version": "1.0.0"}
    }
}
```
Response: Session ID in `mcp-session-id` header

**Step 2 - List Tools**:
```json
{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list",
    "params": {}
}
```
Response: SSE stream with tool definitions

**Step 3 - Call Tool**:
```json
{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
        "name": "execute_query",
        "arguments": {
            "sql": "SELECT * FROM synthetic.customers LIMIT 5",
            "limit": 100
        }
    }
}
```
Response: SSE stream with tool result

**Response Parsing** (SSE format):
```
data: {"jsonrpc": "2.0", "id": 3, "result": {...}}
```

### 6. Branch Differences: master vs chatbot_UI

| Aspect | master branch | chatbot_UI branch |
|--------|---------------|-------------------|
| SQL Execution | Via MCP HTTP API (`postgres-mcp__execute_query`) | Direct import of `sql_service.py` |
| Main Entry Point | `frontend/main.py` (FastAPI) | `chatbot/ai_agent.py` + `chatbot/web_app.py` |
| sql_service.py | Does not exist | Root level, imported by ai_agent.py |
| MCP Usage | Full tool execution via HTTP | Schema context only |
| Architecture | Microservices (Frontend + MCP servers) | Hybrid (direct SQL + MCP schema) |

**chatbot_UI branch ai_agent.py** (lines 36-48):
```python
# SQL Service - direct import for SQL generation and execution
from sql_service import _sql_generator, _sql_executor, MAX_QUERY_ROWS
HAS_SQL_SERVICE = True
```

**chatbot_UI architecture**:
- MCP provides schema context only (search, list tools)
- `data_question` tool calls sql_service directly for SQL generation/execution
- More complex, requires shared code

### 7. Frontend HTTP Endpoints (for reference)

**Location**: `Company-MCP/frontend/main.py`

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/mcp/servers` | GET | List configured MCP servers |
| `/api/mcp/servers/{id}` | POST/PUT/DELETE | Manage server configs |
| `/api/mcp/servers/{id}/health` | GET | Check server health |
| `/api/mcp/servers/{id}/tools` | GET | Get tools from specific server |
| `/api/mcp/tools` | GET | List all MCP tools |
| `/api/mcp/tool` | POST | Call MCP tool directly |
| `/api/chat` | POST | Non-streaming chat |
| `/api/chat/stream` | POST | SSE streaming chat |

## Architecture Diagram

```
                    Slack Bot (Tribal_Knowledge repo)
                              │
                              │ HTTP/JSON-RPC
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     MCP Server Layer                             │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   mcp-dabstep   │  │    mcp-synth    │  │  mcp-postgres   │  │
│  │   (server.py)   │  │   (server.py)   │  │(postgres-mcp/   │  │
│  │                 │  │                 │  │   server.py)    │  │
│  │ Schema Context  │  │ Schema Context  │  │ SQL Execution   │  │
│  │ - search_tables │  │ - search_tables │  │ - execute_query │  │
│  │ - get_schema    │  │ - get_schema    │  │ - describe_table│  │
│  │ - list_domains  │  │ - search_fts    │  │ - get_sample    │  │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  │
│           │                    │                    │           │
│           ▼                    ▼                    ▼           │
│      SQLite Index         SQLite Index          PostgreSQL      │
│     (dabstep data)        (synth data)         (synthetic)      │
└─────────────────────────────────────────────────────────────────┘
```

## Recommendation for Slack Bot

**Use Option A: Route all tool calls through MCP's HTTP API**

**Reasons**:
1. **Simplicity**: No code sharing required between repos
2. **Security**: Same security boundaries as web UI
3. **Maintenance**: Changes to MCP servers automatically available to Slack bot
4. **Consistency**: Same agentic loop pattern as frontend/main.py

**Implementation Steps for Slack Bot**:
1. Copy the MCP client logic from `frontend/main.py`:
   - `call_mcp_tool_on_server()` function
   - `parse_sse_response()` function
   - `fetch_tools_from_server()` function
2. Implement similar agentic loop using LLM of choice (Claude, GPT-4o)
3. Configure MCP server URLs as environment variables
4. Handle tool namespacing (`{server_id}__{tool_name}`)

## Code References

- `Company-MCP/frontend/main.py:541-619` - `call_mcp_tool_on_server()` implementation
- `Company-MCP/frontend/main.py:698-918` - Agentic loop (`chat_stream`)
- `Company-MCP/frontend/main.py:302-310` - SSE response parsing
- `Company-MCP/server.py:368-1706` - All schema context MCP tools
- `Company-MCP/postgres-mcp/server.py:83-460` - All database execution MCP tools
- `Company-MCP/postgres-mcp/server.py:57-78` - SQL read-only validation

## Open Questions

1. **Authentication**: How should the Slack bot authenticate with MCP servers in production?
2. **Rate Limiting**: Are there rate limits on MCP server calls?
3. **Error Handling**: What error responses should the Slack bot handle gracefully?
4. **Session Management**: Should sessions be reused across Slack messages or created fresh?
