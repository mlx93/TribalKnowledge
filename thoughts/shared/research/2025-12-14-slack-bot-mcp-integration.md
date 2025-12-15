---
date: 2025-12-15T00:29:10Z
researcher: Claude Code
git_commit: 6dfc7ec900be0032c8d46b48d9c08456a8d46457
branch: main
repository: Tribal_Knowledge
topic: "Slack Bot Integration with Company-MCP"
tags: [research, codebase, slack-bot, mcp, llm-integration, openai, openrouter, chatbot]
status: complete
last_updated: 2025-12-15
last_updated_by: Claude Code
last_updated_note: "Added master branch frontend chatbot analysis"
---

# Research: Slack Bot Integration with Company-MCP

**Date**: 2025-12-15T00:29:10Z
**Researcher**: Claude Code
**Git Commit**: 6dfc7ec900be0032c8d46b48d9c08456a8d46457
**Branch**: main
**Repository**: Tribal_Knowledge

## Research Question

How to build a Slack bot agent that:
1. Receives questions from users in Slack
2. Calls OpenAI (gpt-4o) or OpenRouter (claude-haiku-4.5) with fallback logic
3. Uses the Company-MCP to search documentation via MCP tools
4. Returns answers in Slack, similar to the existing chatbot implementation

## Summary

The research identified three key components that need to be integrated:

1. **TribalAgent LLM Layer** (`TribalAgent/src/utils/llm.ts`) - Already has robust fallback logic for OpenRouter (Claude) to OpenAI (GPT-4o) that can be reused
2. **Company-MCP Server** (https://github.com/nstjuliana/company-mcp) - FastMCP-based server with 14 tools for database documentation search
3. **Slack Bot Framework** - Slack Bolt Python SDK provides the foundation for building the bot

The recommended approach is to build a Python-based Slack bot using Slack Bolt that:
- Connects to Company-MCP via the MCP Python SDK
- Uses LLM providers (OpenAI/OpenRouter) to process user queries with MCP tool access
- Implements fallback logic similar to TribalAgent's existing `llm.ts`

## Detailed Findings

### 1. Existing LLM Integration Architecture (TribalAgent)

**Location**: `/Users/mylessjs/Desktop/Tribal_Knowledge/TribalAgent/src/utils/llm.ts`

The TribalAgent already has a production-ready LLM integration layer with:

**Model Configuration**:
- Primary model: `claude-haiku-4.5` via OpenRouter (OPENROUTER_API_KEY)
- Fallback model: `gpt-4o` via OpenAI direct (OPENAI_API_KEY)
- Configurable via environment variables:
  - `LLM_PRIMARY_MODEL` - Override primary model
  - `LLM_FALLBACK_ENABLED` - Enable/disable fallback (default: true)
  - `LLM_FALLBACK_MODEL` - Fallback model (default: gpt-4o)

**Fallback Logic** (lines 707-939):
- 402 (insufficient credits) errors: Immediate fallback to GPT-4o (no retry)
- Other errors: Retry once with exponential backoff, then fallback
- Returns `usedFallback: boolean` and `actualModel: string` in response

**Key Functions**:
- `callLLM()` - Main entry point with retry and fallback
- `callClaude()` - OpenRouter integration for Claude models
- `callOpenAI()` - Direct OpenAI integration
- `getOpenRouterClient()` - Creates OpenRouter client with proper headers
- `getFallbackStatus()` - Returns current fallback configuration

### 2. Company-MCP Server Architecture

**Repository**: https://github.com/nstjuliana/company-mcp

**Server Details**:
- Framework: FastMCP (Python)
- Port: 8000 (`/mcp` endpoint)
- Purpose: Serves pre-indexed database documentation without connecting to actual databases

**Available MCP Tools (14 total)**:

| Tool | Description |
|------|-------------|
| `list_databases()` | Lists indexed databases |
| `list_domains()` | Business domain categories |
| `list_tables()` | Available tables with filters |
| `search_fts()` | BM25-ranked full-text search |
| `search_vector()` | Semantic search via OpenAI embeddings |
| `search_db_map()` | Token-based in-memory search |
| `search_tables()` | Natural language table discovery |
| `list_columns()` | Column details by table |
| `get_table_schema()` | Full JSON schema retrieval |
| `get_domain_overview()` | Domain-wide table listing |

**Data Structure**:
```
data/
├── index/ → index.db (SQLite with FTS5 + vector search)
└── map/ → JSON/Markdown schema files organized by:
    ├── postgres_production
    └── snowflake_production
```

### 3. Existing Chatbot Implementation (chatbot_UI branch)

**Branch**: `chatbot_UI` in https://github.com/nstjuliana/company-mcp
**Last Updated**: Dec 14, 2025 by eweinhaus

The existing chatbot is a **Flask web application** with a ChatGPT-style interface:

**Directory Structure**:
```
company-mcp/
├── chatbot/
│   ├── web_app.py      # Flask app with chat interface
│   ├── ai_agent.py     # AI agent with tool orchestration
│   └── templates/      # HTML templates
├── sql_service.py      # SQL generation and execution
├── server.py           # FastMCP server
└── docker-compose.yml  # 3 services: MCP (8000), Chatbot (3000), SFTP (2222)
```

**Architecture (Three-Tier Fallback)**:
1. **AI Agent Layer** (`ai_agent.py`): Claude via OpenRouter with tool calling
2. **Pattern Matching Layer**: Deterministic query routing when AI unavailable
3. **JSON File Fallback**: Direct file access when MCP unavailable

**AI Agent Features** (`ai_agent.py`):
- Uses Anthropic Claude SDK via OpenRouter
- 8 tools available: `data_question`, `search_tables`, `list_columns`, `paginate_query`, `get_table_schema`, `list_databases`, `list_domains`, `list_tables`
- Token management: 100K budget with smart truncation
- Smart pagination for large results (>500 rows)
- Context preservation for follow-up questions

**Query Type Routing**:
| Query Type | Example | Handler |
|------------|---------|---------|
| Data Questions | "How many users signed up?" | `answer_question` → SQL generation & execution |
| Schema Queries | "What tables in payments domain?" | `search_tables` → formatted list |
| Structural Queries | "Show columns for merchants" | `get_table_schema` → detailed output |

**Dependencies** (`requirements.txt`):
```
fastmcp==2.13.3
sqlite-vec>=0.1.1
openai>=1.0.0
python-dotenv>=1.0.0
flask>=2.3.0
flask-cors>=4.0.0
psycopg2-binary>=2.9.0
snowflake-connector-python>=3.0.0
```

**Key Insight**: The chatbot_UI branch uses **the same OpenAI SDK** for OpenRouter that your TribalAgent uses.

### 4. Master Branch Chatbot (frontend/main.py)

**Branch**: `master` in https://github.com/nstjuliana/company-mcp
**Location**: `frontend/` directory

The master branch has a **different chatbot implementation** than chatbot_UI:

**Directory Structure**:
```
company-mcp/ (master branch)
├── frontend/
│   ├── main.py           # FastAPI app with GPT-4o chat
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── static/
│   └── templates/
├── filebrowser/
├── nginx/
├── server.py             # FastMCP server
└── docker-compose.yml
```

**Architecture**:
- **Framework**: FastAPI + Jinja2 (not Flask)
- **LLM**: GPT-4o via OpenAI directly (not OpenRouter/Claude)
- **Agentic Loop**: Up to 5 sequential tool calls per conversation
- **MCP Integration**: Multi-server registry with enable/disable controls

**Key Features** (`frontend/main.py`):
- AsyncOpenAI integration for GPT-4o with tool calling
- MCP server management registry (multiple servers)
- URL normalization for Docker internal hostnames
- Server-specific tool tagging: `server_id__tool_name` convention
- Fallback to rule-based routing when OpenAI unavailable
- SFTP file browsing via Paramiko
- SQLite queries for metadata (FTS5 search)

**Dependencies** (`frontend/requirements.txt`):
```
fastapi==0.109.0
uvicorn==0.27.0
httpx==0.26.0
python-multipart==0.0.6
jinja2==3.1.2
paramiko==3.4.0
aiofiles==23.2.1
openai==1.68.0
```

### Branch Comparison

| Feature | Master (`frontend/`) | chatbot_UI (`chatbot/`) |
|---------|---------------------|------------------------|
| **Framework** | FastAPI | Flask |
| **LLM Provider** | OpenAI direct (GPT-4o) | OpenRouter (Claude) |
| **Tool Loop** | 5 iterations max | Unlimited with token budget |
| **SQL Execution** | Via MCP tools | Direct `sql_service.py` |
| **Fallback** | Rule-based routing | Pattern matching + JSON files |
| **Multi-Server** | Yes (registry) | No (single server) |
| **Token Management** | Not specified | 100K budget with truncation |

**Key Insight**: The master branch is simpler (GPT-4o only) while chatbot_UI has more sophisticated fallback logic and token management. For your Slack bot with OpenRouter→OpenAI fallback, **chatbot_UI's patterns are more relevant**.

### 5. Slack Bot Implementation Approach

**Recommended Framework**: Slack Bolt Python SDK

**Official Resources**:
- [Slack AI Chatbot Tutorial](https://docs.slack.dev/tools/bolt-python/tutorial/ai-chatbot/)
- [GitHub - slack-samples/bolt-python-ai-chatbot](https://github.com/slack-samples/bolt-python-ai-chatbot)
- [GitHub - slack-samples/bolt-python-assistant-template](https://github.com/slack-samples/bolt-python-assistant-template)

**Key Dependencies**:
```python
slack-bolt>=1.18.0
openai>=1.0.0
anthropic>=0.20.0  # Optional, for direct Anthropic API
mcp>=0.1.0         # MCP Python SDK for connecting to company-mcp
```

### 6. Recommended Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         SLACK WORKSPACE                          │
│  ┌─────────────┐                                                │
│  │   User      │ ──── @bot "What tables have payment data?" ───►│
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SLACK BOT APPLICATION                         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Message Handler                         │   │
│  │  - Listens for @mentions, DMs, slash commands            │   │
│  │  - Extracts user query from Slack event                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   LLM Provider Layer                      │   │
│  │  ┌────────────────┐    ┌────────────────┐                │   │
│  │  │  OpenRouter    │    │    OpenAI      │                │   │
│  │  │  (Primary)     │───►│  (Fallback)    │                │   │
│  │  │  claude-haiku  │    │   gpt-4o       │                │   │
│  │  │     4.5        │    │                │                │   │
│  │  └────────────────┘    └────────────────┘                │   │
│  │                                                           │   │
│  │  Fallback triggers:                                       │   │
│  │  - 402 (credits) → immediate fallback                    │   │
│  │  - Other errors → retry once, then fallback              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              │ LLM decides to use MCP tools     │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   MCP Client Layer                        │   │
│  │  - Connects to company-mcp server (localhost:8000/mcp)   │   │
│  │  - Calls tools: search_fts, search_vector, search_tables │   │
│  │  - Returns results to LLM for response synthesis         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     COMPANY-MCP SERVER                           │
│                     (localhost:8000/mcp)                         │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ FastMCP Server                                          │    │
│  │ - 14 MCP Tools for database documentation search        │    │
│  │ - SQLite + FTS5 + Vector search (index.db)             │    │
│  │ - Pre-indexed schemas from TribalAgent                  │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 7. Implementation Code Pattern

**Slack Bot with MCP Integration** (`slack_mcp_bot.py`):

```python
import os
import asyncio
from slack_bolt.async_app import AsyncApp
from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler
from openai import OpenAI, AsyncOpenAI
from mcp import ClientSession
from mcp.client.sse import sse_client

# Environment variables
SLACK_BOT_TOKEN = os.environ["SLACK_BOT_TOKEN"]
SLACK_APP_TOKEN = os.environ["SLACK_APP_TOKEN"]
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
MCP_SERVER_URL = os.environ.get("MCP_SERVER_URL", "http://localhost:8000/mcp")

# LLM Configuration (mirrors TribalAgent's llm.ts)
PRIMARY_MODEL = os.environ.get("LLM_PRIMARY_MODEL", "anthropic/claude-haiku-4.5")
FALLBACK_MODEL = os.environ.get("LLM_FALLBACK_MODEL", "gpt-4o")
FALLBACK_ENABLED = os.environ.get("LLM_FALLBACK_ENABLED", "true").lower() != "false"

app = AsyncApp(token=SLACK_BOT_TOKEN)


def get_openrouter_client() -> OpenAI:
    """Create OpenRouter client for Claude models."""
    return OpenAI(
        api_key=OPENROUTER_API_KEY,
        base_url="https://openrouter.ai/api/v1",
        default_headers={
            "HTTP-Referer": "https://github.com/tribal-knowledge",
            "X-Title": "Tribal Knowledge Slack Bot",
        }
    )


def get_openai_client() -> OpenAI:
    """Create direct OpenAI client for fallback."""
    return OpenAI(api_key=OPENAI_API_KEY)


def is_credits_error(error: Exception) -> bool:
    """Check if error is a credits/insufficient funds error (402)."""
    error_str = str(error)
    return (
        "402" in error_str or
        "credits" in error_str.lower() or
        "insufficient" in error_str.lower() or
        "can only afford" in error_str.lower()
    )


async def call_llm_with_fallback(
    messages: list,
    tools: list | None = None,
    max_tokens: int = 4096
) -> dict:
    """
    Call LLM with automatic fallback from OpenRouter (Claude) to OpenAI (GPT-4o).

    Mirrors the fallback logic from TribalAgent/src/utils/llm.ts
    """
    # Try primary model (Claude via OpenRouter)
    if OPENROUTER_API_KEY:
        try:
            client = get_openrouter_client()
            kwargs = {
                "model": PRIMARY_MODEL,
                "messages": messages,
                "max_tokens": max_tokens,
            }
            if tools:
                kwargs["tools"] = tools

            response = client.chat.completions.create(**kwargs)
            return {
                "response": response,
                "used_fallback": False,
                "actual_model": PRIMARY_MODEL
            }
        except Exception as e:
            print(f"Primary LLM failed: {e}")

            # 402 errors: immediate fallback (no retry)
            if is_credits_error(e):
                print("Credits error - falling back immediately")
            else:
                # Other errors: retry once
                try:
                    response = client.chat.completions.create(**kwargs)
                    return {
                        "response": response,
                        "used_fallback": False,
                        "actual_model": PRIMARY_MODEL
                    }
                except Exception as retry_error:
                    print(f"Retry failed: {retry_error}")

    # Fallback to OpenAI (GPT-4o)
    if FALLBACK_ENABLED and OPENAI_API_KEY:
        print(f"Falling back to {FALLBACK_MODEL}")
        client = get_openai_client()
        kwargs = {
            "model": FALLBACK_MODEL,
            "messages": messages,
            "max_tokens": max_tokens,
        }
        if tools:
            kwargs["tools"] = tools

        response = client.chat.completions.create(**kwargs)
        return {
            "response": response,
            "used_fallback": True,
            "actual_model": FALLBACK_MODEL
        }

    raise Exception("All LLM providers failed and no fallback available")


class MCPClient:
    """Client for connecting to Company-MCP server."""

    def __init__(self, server_url: str):
        self.server_url = server_url
        self.session: ClientSession | None = None
        self.tools: list = []

    async def connect(self):
        """Connect to MCP server and discover tools."""
        async with sse_client(self.server_url) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()

                # Get available tools
                response = await session.list_tools()
                self.tools = response.tools
                self.session = session

                return self.tools

    async def call_tool(self, tool_name: str, arguments: dict) -> str:
        """Call an MCP tool and return the result."""
        if not self.session:
            raise Exception("Not connected to MCP server")

        result = await self.session.call_tool(tool_name, arguments=arguments)
        return result.content

    def get_tools_for_llm(self) -> list:
        """Format MCP tools for OpenAI function calling format."""
        return [
            {
                "type": "function",
                "function": {
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.inputSchema
                }
            }
            for tool in self.tools
        ]


# Initialize MCP client
mcp_client = MCPClient(MCP_SERVER_URL)


@app.event("app_mention")
async def handle_mention(event, say):
    """Handle @mentions in channels."""
    user_query = event["text"]
    channel = event["channel"]

    # Show typing indicator
    await say(channel=channel, text="_Searching database documentation..._")

    try:
        # Connect to MCP and get tools
        await mcp_client.connect()
        tools = mcp_client.get_tools_for_llm()

        # System prompt for the LLM
        system_prompt = """You are a helpful database documentation assistant.
        You have access to tools that search a database schema documentation system.
        Use these tools to help users find information about tables, columns, and domains.
        Always cite which tables/columns you found information from."""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_query}
        ]

        # Call LLM with MCP tools
        result = await call_llm_with_fallback(messages, tools=tools)
        response = result["response"]

        # Handle tool calls if the LLM wants to use MCP tools
        while response.choices[0].message.tool_calls:
            # Execute each tool call
            tool_results = []
            for tool_call in response.choices[0].message.tool_calls:
                tool_name = tool_call.function.name
                tool_args = json.loads(tool_call.function.arguments)

                print(f"Calling MCP tool: {tool_name} with {tool_args}")
                tool_result = await mcp_client.call_tool(tool_name, tool_args)

                tool_results.append({
                    "tool_call_id": tool_call.id,
                    "role": "tool",
                    "content": str(tool_result)
                })

            # Add tool results to messages and call LLM again
            messages.append(response.choices[0].message)
            messages.extend(tool_results)

            result = await call_llm_with_fallback(messages, tools=tools)
            response = result["response"]

        # Send final response to Slack
        final_response = response.choices[0].message.content

        # Add fallback indicator if used
        if result["used_fallback"]:
            final_response += f"\n\n_Used fallback model: {result['actual_model']}_"

        await say(channel=channel, text=final_response)

    except Exception as e:
        await say(channel=channel, text=f"Error processing request: {str(e)}")


@app.event("message")
async def handle_dm(event, say):
    """Handle direct messages to the bot."""
    # Only respond to DMs (no channel specified or channel starts with D)
    if event.get("channel_type") == "im":
        await handle_mention(event, say)


async def main():
    handler = AsyncSocketModeHandler(app, SLACK_APP_TOKEN)
    await handler.start_async()


if __name__ == "__main__":
    asyncio.run(main())
```

### 8. Environment Variables Required

```bash
# Slack credentials
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_APP_TOKEN=xapp-your-app-token

# LLM Providers (same as TribalAgent)
OPENROUTER_API_KEY=sk-or-your-key
OPENAI_API_KEY=sk-your-openai-key

# LLM Configuration
LLM_PRIMARY_MODEL=anthropic/claude-haiku-4.5
LLM_FALLBACK_MODEL=gpt-4o
LLM_FALLBACK_ENABLED=true

# MCP Server
MCP_SERVER_URL=http://localhost:8000/mcp
```

### 9. Slack App Setup Requirements

1. **Create Slack App** at https://api.slack.com/apps
2. **Enable Socket Mode** (for development) or **Event Subscriptions** (for production)
3. **Add Bot Token Scopes**:
   - `app_mentions:read` - Listen for @mentions
   - `chat:write` - Send messages
   - `im:history` - Read DM history
   - `im:read` - Access DM channels
   - `im:write` - Send DMs
4. **Subscribe to Bot Events**:
   - `app_mention`
   - `message.im`
5. **Install App** to workspace

## Code References

- `TribalAgent/src/utils/llm.ts:707-939` - Existing fallback logic implementation
- `TribalAgent/src/utils/llm.ts:139-154` - OpenRouter client creation
- `TribalAgent/src/utils/llm.ts:157-165` - OpenAI client creation
- `TribalAgent/src/utils/llm.ts:81-89` - Credits error detection
- `TribalAgent/src/utils/llm.ts:56-75` - Fallback configuration functions
- `TribalAgent/config/agent-config.yaml` - Model configuration template

## Architecture Documentation

The proposed Slack bot follows the same patterns established in TribalAgent:

1. **Provider Abstraction**: Use OpenRouter for Claude models, direct OpenAI for GPT models
2. **Fallback Pattern**: 402 errors trigger immediate fallback, other errors retry once then fallback
3. **Tool Integration**: MCP tools exposed to LLM via OpenAI function calling format
4. **Configuration**: Environment variables for API keys and model selection

## Related Resources

- [Slack Bolt Python Documentation](https://tools.slack.dev/bolt-python/getting-started)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
- [Build an MCP Client](https://modelcontextprotocol.io/quickstart/client)
- [Slack AI Chatbot Sample](https://github.com/slack-samples/bolt-python-ai-chatbot)
- [FastMCP Documentation](https://github.com/jlowin/fastmcp)

## Follow-up Research: chatbot_UI Branch Analysis

**Added**: 2025-12-15T00:45:00Z

Found the existing chatbot implementation in the `chatbot_UI` branch of company-mcp. Key findings:

1. **Location Confirmed**: `chatbot/` directory in `chatbot_UI` branch
2. **Architecture**: Flask + AI Agent + SQL Service (three-tier with fallbacks)
3. **LLM**: Uses OpenRouter for Claude (same pattern as TribalAgent)
4. **Tools**: 8 tools including `data_question` for SQL execution

### Recommended Approach for Slack Bot

**Option A: Minimal Changes (Recommended)**
Reuse `ai_agent.py` from company-mcp directly:
1. Import the existing `ai_agent` module
2. Replace Flask request handling with Slack Bolt event handlers
3. Replace HTML responses with Slack message formatting

```python
# slack_bot.py - Reuses existing ai_agent
from chatbot.ai_agent import process_message, ConversationManager
from slack_bolt import App

app = App(token=SLACK_BOT_TOKEN)
conversations = {}  # channel_id -> ConversationManager

@app.event("app_mention")
def handle_mention(event, say):
    channel = event["channel"]
    user_query = event["text"]

    # Get or create conversation manager for this channel
    if channel not in conversations:
        conversations[channel] = ConversationManager()

    # Use existing ai_agent
    response = process_message(user_query, conversations[channel])
    say(response)
```

**Option B: Fresh Implementation**
Build new Slack bot using patterns from `ai_agent.py`:
- Copy the tool definitions and LLM calling logic
- Add Slack-specific formatting (blocks, attachments)
- Add thread-based conversation context

### Key Code to Reuse from chatbot_UI

| Source File | What to Reuse |
|-------------|---------------|
| `chatbot/ai_agent.py` | Tool definitions, LLM calling, token management |
| `sql_service.py` | SQL generation and execution |
| `server.py` | MCP tool implementations (if calling directly) |

## Open Questions

1. **Thread Context**: Should conversations persist per-thread or per-channel in Slack?

2. **SQL Execution in Slack**: The web chatbot executes SQL directly. Should the Slack bot:
   - Execute and return results (current behavior)?
   - Return SQL for user to run manually (safer)?
   - Require confirmation before execution?

3. **Rate Limiting**: What limits should apply per-user or per-channel?

4. **Deployment**: Should the Slack bot:
   - Run as a 4th container in docker-compose?
   - Run separately and call the MCP server over HTTP?
