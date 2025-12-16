# Tribal Knowledge Slack Bot

A Slack bot that integrates with Company-MCP servers for database schema queries and SQL execution.

## Features

- **@mention handling** - Mention the bot to start a conversation
- **Thread context** - Follow up in threads without re-mentioning
- **MCP tool integration** - Schema discovery (synth-mcp) and SQL execution (postgres-mcp)
- **LLM fallback** - Automatic fallback from Claude to GPT-4o on errors
- **SQLite persistence** - Thread contexts persist across bot restarts
- **Query caching** - Cache responses for repeated questions (instant replay)

## Quick Start

### 1. Prerequisites

- Python 3.11+
- Slack App with Socket Mode enabled
- OpenRouter API key (for Claude)
- OpenAI API key (for fallback)

### 2. Slack App Setup

1. Create app at https://api.slack.com/apps
2. Enable **Socket Mode** → Generate App-Level Token (`xapp-...`)
3. Add **Bot Token Scopes**:
   - `app_mentions:read`
   - `chat:write`
   - `channels:history`
   - `groups:history`
   - `reactions:read` (for cache control)
   - `reactions:write` (for cache confirmation)
4. Subscribe to **Events**:
   - `app_mention`
   - `message.channels`
   - `message.groups`
   - `app_home_opened`
   - `reaction_added` (for cache control via emoji)
5. Install to workspace → Get Bot Token (`xoxb-...`)

### 3. Configuration

Copy the env template and fill in your values:

```bash
cp env.template .env
# Edit .env with your actual credentials
```

Required environment variables:

```bash
# Slack
SLACK_APP_TOKEN=xapp-...
SLACK_BOT_TOKEN=xoxb-...
SLACK_SIGNING_SECRET=...

# LLM
OPENROUTER_API_KEY=sk-or-...
OPENAI_API_KEY=sk-...

# MCP (defaults work out of the box)
MCP_SYNTH_URL=https://company-mcp.com/mcp/synth
MCP_POSTGRES_URL=https://company-mcp.com/mcp/postgres
```

### 4. Run Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run the bot
python -m slack_bot.app
```

### 5. Run with Docker

```bash
# Build and run
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

## Usage

Once running, mention the bot in any Slack channel:

```
@TribalKnowledge what tables have user data?
```

```
@TribalKnowledge show me the schema for merchants
```

```
@TribalKnowledge how many transactions happened last week?
```

Follow up in the thread without re-mentioning:

```
Show me the first 10 rows
```

## Architecture

```
slack_bot/
├── app.py              # Main Slack Bolt application
├── llm_provider.py     # LLM with Claude → GPT-4o fallback
├── thread_context.py   # SQLite-backed conversation storage
├── cache_store.py      # Query response caching
├── mcp_client.py       # MCP JSON-RPC client
├── message_handler.py  # Agentic loop for tool calls
├── requirements.txt    # Python dependencies
├── Dockerfile          # Container configuration
└── docker-compose.yml  # Docker Compose setup
```

## MCP Integration

The bot connects to two MCP servers via HTTP JSON-RPC:

### synth-mcp (Schema Context)
- URL: `https://company-mcp.com/mcp/synth`
- Tools: `search_tables`, `get_table_schema`, `list_tables`, `search_fts`, `search_vector`, etc.
- Purpose: Discover tables, understand schemas, find relationships

### postgres-mcp (SQL Execution)
- URL: `https://company-mcp.com/mcp/postgres`
- Tools: `execute_query`, `describe_table`, `show_tables`, etc.
- Purpose: Execute read-only SQL queries
- Limits: SELECT/WITH/EXPLAIN only, 1000 row limit, 30s timeout

## LLM Fallback

The bot uses a two-tier LLM strategy:

1. **Primary**: Claude via OpenRouter (`anthropic/claude-opus-4.5`)
2. **Fallback**: GPT-4o via OpenAI

Fallback triggers on:
- 402 errors (credits exhausted) → immediate fallback
- Other errors → retry once, then fallback

Configure via environment:
- `LLM_PRIMARY_MODEL` - Primary model (default: `anthropic/claude-opus-4.5`)
- `LLM_FALLBACK_MODEL` - Fallback model (default: `gpt-4o`)
- `LLM_FALLBACK_ENABLED` - Enable/disable fallback (default: `true`)

## Thread Context

Conversations are persisted per Slack thread in SQLite:

- **Storage**: `data/thread_contexts.db` (local) or `/data/thread_contexts.db` (Docker)
- **TTL**: 24 hours (automatic cleanup)
- **Persistence**: Survives bot restarts

## Query Caching

The bot caches responses to repeated questions for instant replay:

- **Storage**: Same SQLite database as thread contexts (`query_cache` table)
- **Matching**: Multi-tier matching (hash → exact → fuzzy)
- **TTL**: 7 days default (configurable)
- **Replay**: Shows cached progress events for visual continuity

### Cache Modes

**Explicit Mode** (default): Responses are only cached when you react with 📦. This gives you full control over what gets cached.

**Auto-Cache Mode**: Set `CACHE_AUTO_SAVE=true` to automatically cache all successful responses.

### Cache Control via Emoji Reactions

Caching is invisible to users - cached responses look and feel like real queries (progress events replay with realistic timing). Use emoji reactions to control:

| Emoji | Action |
|-------|--------|
| 📦 | Save response to cache |
| 🔄 | Clear from cache and re-run fresh |

**Workflow:**
1. Ask a question → Bot runs tools and responds
2. Like the response? React with 📦 (bot confirms with ✅)
3. Later, same question → Instant replay (looks real)
4. Response stale? React with 🔄 → Fresh query runs

### Configuration

```bash
# Cache settings (all optional - defaults shown)
CACHE_ENABLED=true               # Enable/disable caching
CACHE_AUTO_SAVE=false            # false = explicit mode (📦 to cache)
CACHE_TTL_SECONDS=604800         # 7 days
CACHE_FUZZY_THRESHOLD=0.99       # 99% = essentially exact match only
```

### Invisible Caching

Cached responses are indistinguishable from fresh ones:
- Progress events replay with realistic timing
- Tool usage and SQL queries display the same way
- No indicators that response came from cache

The only visible feedback:
- ✅ — Bot confirms when you successfully cache with 📦

## Development

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set log level for debugging
export LOG_LEVEL=DEBUG

# Run
python -m slack_bot.app
```

## Troubleshooting

### "Missing Slack tokens"
Ensure `SLACK_BOT_TOKEN` and `SLACK_APP_TOKEN` are set in `.env`

### "MCP connection failed"
Check that the MCP servers are accessible:
```bash
curl -X POST https://company-mcp.com/mcp/synth \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}'
```

### "LLM fallback triggered"
Check OpenRouter credits or API key. The bot will automatically use GPT-4o as fallback.

### Bot not responding
1. Check bot is running (`docker-compose logs`)
2. Ensure bot is invited to the channel
3. Check Slack App event subscriptions are configured

## License

MIT

