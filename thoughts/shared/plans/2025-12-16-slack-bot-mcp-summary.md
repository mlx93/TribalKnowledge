# Slack Bot MCP Integration - Summary Plan

## Overview

Build a Slack bot in the Tribal_Knowledge repo that integrates with Company-MCP servers via HTTP JSON-RPC. The bot calls MCP servers remotely for all operations - no code sharing required.

**Reference**: Full implementation details in `2025-12-14-slack-bot-mcp-integration.md`

---

## Quick Start Prerequisites

Before implementing, complete these setup steps:

### 1. MCP Server Access (Both Deployed!)
- **synth-mcp**: `https://company-mcp.com/mcp/synth` ✅
- **postgres-mcp**: `https://company-mcp.com/mcp/postgres` ✅

No local docker-compose needed - both servers are deployed.

### 2. Slack App Setup (before Phase 6)
1. Create app at https://api.slack.com/apps
2. Enable Socket Mode → get `SLACK_APP_TOKEN` (xapp-...)
3. Add bot scopes: `app_mentions:read`, `chat:write`, `channels:history`, `groups:history`
4. Subscribe to events: `app_mention`, `message.channels`, `message.groups`
5. Install to workspace → get `SLACK_BOT_TOKEN` (xoxb-...)
6. Get signing secret from Basic Information → `SLACK_SIGNING_SECRET`

### 3. API Keys
- `OPENROUTER_API_KEY` - Primary LLM (Claude)
- `OPENAI_API_KEY` - Fallback LLM (GPT-4o)

---

## Architecture Decision: Pure MCP HTTP Client

We're following the same architecture as Company-MCP's `frontend/main.py`:

- **All tool calls go through MCP servers via HTTP JSON-RPC**
- SQL execution via `postgres-mcp` server's `execute_query` tool
- Schema context via `mcp-synth` server
- No direct import of `sql_service.py` or other Company-MCP code

### Why This Approach

| Aspect | MCP HTTP (chosen) | Direct sql_service.py |
|--------|-------------------|-----------------------|
| Architecture | Pure microservices | Hybrid |
| Code Sharing | None required | Must import sql_service.py |
| Maintenance | Changes to MCP auto-available | Must sync code |
| Security | Same boundaries as web UI | New trust boundary |

---

## Key Technical Contracts

### MCP Server Endpoints

| Server | URL | Purpose |
|--------|-----|---------|
| `synth-mcp` | `https://company-mcp.com/mcp/synth` | Schema context (15 tools) |
| `postgres-mcp` | `https://company-mcp.com/mcp/postgres` | SQL execution (9 tools, read-only) |

**Both servers are deployed** - no local docker-compose needed.

### MCP JSON-RPC Protocol

All communication uses JSON-RPC over HTTP with SSE responses:

**1. Initialize Session:**
```
POST {server_url}/mcp
Headers: Content-Type: application/json, Accept: application/json, text/event-stream

{"jsonrpc": "2.0", "id": 1, "method": "initialize",
 "params": {"protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "SlackBot", "version": "1.0.0"}}}
```
Response includes `mcp-session-id` header for subsequent calls.

**2. List Tools:**
```
POST {server_url}/mcp
Headers: mcp-session-id: {session_id}

{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
```

**3. Call Tool:**
```
POST {server_url}/mcp
Headers: mcp-session-id: {session_id}

{"jsonrpc": "2.0", "id": 3, "method": "tools/call",
 "params": {"name": "execute_query", "arguments": {"sql": "SELECT...", "limit": 100}}}
```

**Response Format (SSE):**
```
data: {"jsonrpc": "2.0", "id": 3, "result": {...}}
```

### Tool Naming Convention

Tools are namespaced as `{server_id}__{tool_name}`:
- `synth-mcp__search_tables`
- `synth-mcp__get_table_schema`
- `postgres-mcp__execute_query`
- `postgres-mcp__describe_table`

### SQL Security (postgres-mcp)

- **Allowed**: `SELECT`, `WITH`, `EXPLAIN`, `SHOW`, `TABLE`
- **Forbidden**: `INSERT`, `UPDATE`, `DELETE`, `DROP`, `CREATE`, `ALTER`, `TRUNCATE`
- **Timeout**: 30 seconds
- **Row limit**: 1000 rows

### Slack Threading

- Thread context tracked via `thread_ts` (unique per thread)
- First @mention creates thread; follow-ups don't need re-mention
- Must acknowledge events within 3 seconds → use `asyncio.create_task()` for LLM calls

---

## Project Structure

```
Tribal_Knowledge/
├── slack_bot/
│   ├── __init__.py
│   ├── app.py              # Main Slack Bolt application
│   ├── llm_provider.py     # LLM with fallback logic
│   ├── thread_context.py   # SQLite-backed thread storage
│   ├── mcp_client.py       # MCP JSON-RPC client
│   ├── message_handler.py  # Agentic loop - all tools via MCP
│   ├── requirements.txt
│   └── Dockerfile
```

---

## Dependencies

```
slack-bolt>=1.18.0      # Slack SDK with async support
httpx>=0.26.0           # Async HTTP for MCP calls
openai>=1.0.0           # LLM providers (OpenRouter uses OpenAI-compatible API)
aiosqlite>=0.19.0       # Thread context persistence
python-dotenv>=1.0.0    # Environment variables
```

---

## Environment Variables

```bash
# Slack credentials
SLACK_BOT_TOKEN=xoxb-...
SLACK_APP_TOKEN=xapp-...
SLACK_SIGNING_SECRET=...

# MCP Server URLs (both deployed - no local setup needed)
MCP_SYNTH_URL=https://company-mcp.com/mcp/synth
MCP_POSTGRES_URL=https://company-mcp.com/mcp/postgres

# LLM configuration
OPENROUTER_API_KEY=sk-or-...
OPENAI_API_KEY=sk-...
LLM_PRIMARY_MODEL=anthropic/claude-opus-4.5
LLM_FALLBACK_MODEL=gpt-4o
LLM_FALLBACK_ENABLED=true

# Storage
THREAD_CONTEXT_DB=/data/thread_contexts.db
LOG_LEVEL=INFO
```

---

## Phase 1: Project Structure and Dependencies

### Goal
Set up the slack_bot directory with dependencies.

### Prerequisites
Before starting, verify MCP server access (both are deployed):

```bash
# Test synth-mcp
curl -s https://company-mcp.com/mcp/synth -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}'

# Test postgres-mcp
curl -s https://company-mcp.com/mcp/postgres -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}'
```

### Tasks
1. Create `slack_bot/` directory structure
2. Create `requirements.txt` with dependencies
3. Create `__init__.py`
4. Verify dependencies install: `pip install -r requirements.txt`

### Success Criteria
- [ ] Directory structure exists
- [ ] Dependencies install without errors
- [ ] `python -c "import slack_bolt; import aiosqlite; import httpx"` succeeds

---

## Phase 2: LLM Provider with Fallback

### Goal
Port TribalAgent fallback logic from TypeScript to Python.

### Module: `llm_provider.py`

**Responsibilities:**
- Primary LLM calls via OpenRouter (Claude)
- Fallback to OpenAI (GPT-4o) on failures
- 402 errors → immediate fallback (no retry)
- Other errors → retry once, then fallback

**Key Functions:**
- `call_llm_with_fallback(messages, tools, max_tokens, temperature)` → Returns response with `used_fallback` and `actual_model` metadata
- `is_credits_error(error)` → Check for 402/credits errors
- `get_fallback_status()` → Current configuration status

**Reference**: Port from `TribalAgent/src/utils/llm.ts:707-939`

### Success Criteria
- [ ] Module imports without errors
- [ ] Fallback triggers on 402 errors
- [ ] Retry logic works for non-402 errors

---

## Phase 3: Thread Context Storage

### Goal
SQLite-backed conversation persistence per Slack thread.

### Module: `thread_context.py`

**Responsibilities:**
- Store conversation history per thread
- Thread key format: `{channel_id}:{thread_ts}`
- Persist across bot restarts
- Auto-cleanup of old contexts (24 hours)

**Key Classes:**
- `ThreadContext` - Conversation state (messages, metadata)
- `ThreadContextStore` - SQLite operations (get, save, delete, cleanup)

**Key Methods:**
- `get_or_create(channel_id, thread_ts, user_id)` → ThreadContext
- `save(context)` → Persist to SQLite
- `cleanup_old_contexts(max_age_seconds)` → Remove expired

### Success Criteria
- [ ] Context persists across bot restarts
- [ ] Follow-up messages have access to conversation history
- [ ] Cleanup removes old contexts

---

## Phase 4: MCP Client

### Goal
JSON-RPC client for Company-MCP servers.

### Module: `mcp_client.py`

**Responsibilities:**
- Initialize sessions with MCP servers
- Fetch tool definitions dynamically
- Execute tool calls with proper namespacing
- Handle SSE response parsing

**Key Class: `MCPClient`**
- `__init__(servers)` - Configure server endpoints
- `get_tools_for_llm()` - Fetch tools in OpenAI format
- `call_tool(tool_name, arguments)` - Execute tool via JSON-RPC
- `close()` - Clean up HTTP client

**Session Management:**
- Create new MCPClient per Slack message
- Sessions reused within same message's agentic loop
- Fresh sessions for each new message

**Reference**: Based on `Company-MCP/frontend/main.py:541-619`

### Success Criteria
- [ ] Successfully connects to MCP servers
- [ ] Tools fetched and properly namespaced
- [ ] Tool calls return results

---

## Phase 5: Message Handler

### Goal
Agentic loop that processes messages using MCP tools.

### Module: `message_handler.py`

**Responsibilities:**
- Build LLM messages with system prompt and context
- Execute agentic loop (LLM → tool calls → results → repeat)
- Route tool calls to MCP client
- Format responses for Slack

**Key Function:**
```python
async def process_message(
    user_message: str,
    context: ThreadContext,
    user_id: str,
    message_ts: str,
) -> tuple[str, bool]:  # (response_text, used_fallback)
```

**Agentic Loop:**
1. Send messages + tools to LLM
2. If LLM returns tool_calls, execute via MCP client
3. Add tool results to messages
4. Repeat until LLM returns final response (max 10 iterations)

**System Prompt Key Points:**
- Explain available tool servers (synth-mcp, postgres-mcp)
- Workflow: schema search → SQL generation → execution
- Format results as Slack-friendly text

**Reference**: Based on `Company-MCP/frontend/main.py:698-918`

### Success Criteria
- [ ] Messages processed with tool calls
- [ ] SQL queries execute and return results
- [ ] Context maintained across follow-ups

---

## Phase 6: Main Slack Application

### Goal
Slack Bolt AsyncApp with event handlers.

### Module: `app.py`

**Responsibilities:**
- Socket Mode connection to Slack
- Handle @mentions (`app_mention` event)
- Handle thread follow-ups (`message` event)
- Show "thinking" indicator during processing
- App Home tab with usage instructions

**Event Handlers:**
- `@app.event("app_mention")` - Primary entry point
- `@app.event("message")` - Thread follow-ups (only if we have context)
- `@app.event("app_home_opened")` - Show help

**Critical Pattern:**
```python
# Must acknowledge within 3 seconds - process async
@app.event("app_mention")
async def handle_mention(event, client):
    # Post "thinking" indicator
    # Process in background with asyncio.create_task()
    # Update message when done
```

**Background Tasks:**
- Cleanup task: Remove old thread contexts every hour

### Success Criteria
- [ ] Bot responds to @mentions
- [ ] "Thinking" indicator appears within 3 seconds
- [ ] Thread follow-ups work without re-mentioning
- [ ] App Home shows instructions

---

## Phase 7: Docker Configuration

### Goal
Containerized deployment.

### Files
- `Dockerfile` - Python 3.11-slim base, install deps, run app
- `docker-compose.yml` - Environment variables, volume for SQLite
- `.env.example` - Template for configuration

**Key Considerations:**
- Volume mount for `/data` (SQLite persistence)
- Both MCP servers accessed via HTTPS (deployed) - no networking changes needed
- No `depends_on` - MCP servers are external deployed services

### Success Criteria
- [ ] Docker builds successfully
- [ ] Bot connects to Slack from container
- [ ] Thread context persists across container restarts

---

## Slack App Configuration

### Required Bot Token Scopes
- `app_mentions:read` - Listen for @mentions
- `chat:write` - Send messages
- `channels:history` - Read channel messages
- `groups:history` - Read private channel messages

### Required Event Subscriptions
- `app_mention` - When bot is @mentioned
- `message.channels` - Messages in public channels
- `message.groups` - Messages in private channels
- `app_home_opened` - App Home tab

### Socket Mode
- Enable Socket Mode in Slack App settings
- Create App-Level Token with `connections:write` scope
- Use `xapp-` token as `SLACK_APP_TOKEN`

---

## What We're NOT Doing

- Rate limiting
- Direct message handling (only @mentions in channels)
- Slash commands
- Interactive buttons/modals
- Multi-workspace support
- Production HTTP mode (Socket Mode only)

---

## Testing Checklist

### Unit Tests
- [ ] LLM fallback triggers correctly on 402
- [ ] Thread context CRUD operations work
- [ ] MCP client parses SSE responses

### Integration Tests
- [ ] End-to-end: @mention → response
- [ ] Thread context: follow-up has history
- [ ] SQL execution: query → results

### Manual Tests
1. `@bot what tables have user data?`
2. Follow-up: `show me the columns`
3. `@bot how many merchants signed up last week?`
4. Restart bot, verify thread context preserved

---

## Implementation Order

1. **Phase 1**: Project structure - Quick setup, unblocks everything
2. **Phase 3**: Thread context - No external dependencies, testable in isolation
3. **Phase 2**: LLM provider - Needs API keys, test with simple prompts
4. **Phase 4**: MCP client - Needs MCP servers running
5. **Phase 5**: Message handler - Integrates phases 2-4
6. **Phase 6**: Slack app - Integrates everything
7. **Phase 7**: Docker - Production deployment

---

## References

- **Full implementation plan**: `thoughts/shared/plans/2025-12-14-slack-bot-mcp-integration.md`
- **Architecture research**: `thoughts/shared/research/2025-12-16-company-mcp-master-branch-architecture.md`
- **TribalAgent fallback**: `TribalAgent/src/utils/llm.ts:707-939`
- **Company-MCP client**: `Company-MCP/frontend/main.py:541-619`
- **Company-MCP agentic loop**: `Company-MCP/frontend/main.py:698-918`
- **Slack Bolt docs**: https://slack.dev/bolt-python/
