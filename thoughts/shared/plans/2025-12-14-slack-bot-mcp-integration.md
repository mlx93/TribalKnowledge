# Slack Bot Integration with Company-MCP Implementation Plan

## Overview

Build a Slack bot that integrates with the Company-MCP servers via HTTP JSON-RPC. The bot lives in the Tribal_Knowledge repo and calls MCP servers remotely - no code sharing required. All tool calls (schema queries AND SQL execution) go through MCP's HTTP API.

## Current State Analysis

### Architecture Decision: Option A - Pure MCP HTTP Client

Based on research of the Company-MCP master branch (`frontend/main.py`), we're using the same architecture as the web UI:
- All tool calls go through MCP servers via HTTP JSON-RPC
- SQL execution via `postgres-mcp` server's `execute_query` tool
- Schema context via `mcp-synth` / `mcp-dabstep` servers
- No direct import of `sql_service.py` needed

#### Why Option A over Option B (chatbot_UI branch approach)?

| Aspect | Option A: MCP HTTP (chosen) | Option B: Direct sql_service.py |
|--------|-----------------------------|---------------------------------|
| **Architecture** | Pure microservices | Hybrid (MCP schema + direct SQL) |
| **Code Sharing** | None required | Must import sql_service.py |
| **SQL Execution** | Via `postgres-mcp__execute_query` | Direct function call |
| **Maintenance** | Changes to MCP auto-available | Must sync sql_service.py |
| **Security** | Same boundaries as web UI | New trust boundary |
| **Complexity** | Simpler, HTTP-only | More complex, mixed |

The `chatbot_UI` branch's `chatbot/ai_agent.py` imports `sql_service.py` directly for SQL execution, while MCP is only used for schema context. The master branch's `frontend/main.py` routes ALL operations through MCP HTTP, which is cleaner and what we're following.

### Existing Components

1. **Company-MCP master branch** (remote, called via HTTP):
   - `server.py` - Schema context MCP server (15 tools: search_tables, get_table_schema, etc.)
   - `postgres-mcp/server.py` - SQL execution MCP server (9 tools: execute_query, describe_table, etc.)
   - `frontend/main.py` - Reference implementation of MCP client + agentic loop

2. **TribalAgent fallback logic** (`TribalAgent/src/utils/llm.ts:707-939`):
   - 402 errors → immediate fallback to GPT-4o
   - Other errors → retry once, then fallback
   - Returns `usedFallback` and `actualModel` metadata

### Key Discoveries

- Slack Bolt requires acknowledgment within 3 seconds → must use `asyncio.create_task()` for LLM calls
- Thread context tracked via `thread_ts` field (unique per thread, not per channel)
- MCP uses JSON-RPC over HTTP with session-based protocol
- Tool naming convention: `{server_id}__{tool_name}` (e.g., `postgres-mcp__execute_query`)
- Dependencies needed: `slack-bolt`, `aiosqlite`, `httpx` (for async HTTP)

### MCP HTTP API Contract

All MCP servers expose a `/mcp` endpoint using JSON-RPC over HTTP with SSE responses:

**Step 1 - Initialize Session:**
```json
POST {server_url}/mcp
Headers: Content-Type: application/json, Accept: application/json, text/event-stream

{"jsonrpc": "2.0", "id": 1, "method": "initialize",
 "params": {"protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "SlackBot", "version": "1.0.0"}}}
```
Response: Session ID in `mcp-session-id` header

**Step 2 - List Tools:**
```json
POST {server_url}/mcp
Headers: mcp-session-id: {session_id}

{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
```

**Step 3 - Call Tool:**
```json
POST {server_url}/mcp
Headers: mcp-session-id: {session_id}

{"jsonrpc": "2.0", "id": 3, "method": "tools/call",
 "params": {"name": "execute_query", "arguments": {"sql": "SELECT...", "limit": 100}}}
```

**Response Format (SSE):**
```
data: {"jsonrpc": "2.0", "id": 3, "result": {...}}
```

### SQL Execution Security (postgres-mcp)

The `postgres-mcp` server enforces read-only access:
- **Allowed statements**: `SELECT`, `WITH`, `EXPLAIN`, `SHOW`, `TABLE`
- **Forbidden**: `INSERT`, `UPDATE`, `DELETE`, `DROP`, `CREATE`, `ALTER`, `TRUNCATE`, etc.
- **Query timeout**: 30 seconds
- **Row limit**: 1000 rows maximum (configurable via `limit` parameter)

## Desired End State

A Slack bot service (in Tribal_Knowledge repo) that:
1. Responds to @mentions in any channel/thread
2. Maintains conversation context per Slack thread (persisted in SQLite)
3. Calls Company-MCP servers via HTTP for all tool operations:
   - Schema queries via `mcp-synth` / `mcp-dabstep` servers
   - SQL execution via `postgres-mcp` server's `execute_query` tool
4. Falls back from OpenRouter (Claude) to OpenAI (GPT-4o) on failures
5. Runs standalone (requires Company-MCP servers to be accessible)

### Verification

- Bot responds to @mentions with "thinking" indicator within 3 seconds
- Follow-up questions in same thread have conversation context
- MCP tool calls return results (schema searches, SQL execution)
- 402 errors trigger immediate fallback (visible in logs)
- Bot restarts preserve thread context (SQLite persistence)

## What We're NOT Doing

- Rate limiting (per user decision)
- Direct message handling (only @mentions in channels)
- Slash commands
- Interactive buttons/modals
- Multi-workspace support
- Production HTTP mode (using Socket Mode only)

## Implementation Approach

The Slack bot will be a standalone Python service in the Tribal_Knowledge repo that:
1. Uses Slack Bolt AsyncApp with Socket Mode for event handling
2. Calls Company-MCP servers via HTTP JSON-RPC (no code sharing)
3. Adds a Python port of the TribalAgent LLM fallback pattern
4. Stores thread context in SQLite for persistence
5. Runs standalone or via Docker

## Phase 1: Project Structure and Dependencies

### Overview
Set up the Slack bot directory structure in the Tribal_Knowledge repository.

### Prerequisites

Before starting, verify the Company-MCP servers are running and accessible. The Slack bot depends on:

| Server | Default URL | Tools | Purpose |
|--------|-------------|-------|---------|
| `synth-mcp` | `http://localhost:8001` | 15 | Schema context and search |
| `postgres-mcp` | `http://localhost:8002` | 9 | SQL execution (read-only) |

**Quick verification (run from terminal):**

```bash
# Test synth-mcp server
curl -s http://localhost:8001/mcp -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}'

# Test postgres-mcp server
curl -s http://localhost:8002/mcp -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}'
```

**Expected response:** JSON with `"result"` containing server capabilities. If you get connection refused or timeout, start the Company-MCP services first (see Company-MCP README).

### Changes Required

#### 1.1 Create Slack Bot Directory Structure

**Directory**: `Tribal_Knowledge/slack_bot/` (new directory)

```
Tribal_Knowledge/
├── slack_bot/
│   ├── __init__.py
│   ├── app.py              # Main Slack Bolt application
│   ├── llm_provider.py     # LLM with fallback logic (port from TribalAgent)
│   ├── thread_context.py   # SQLite-backed thread context storage
│   ├── mcp_client.py       # MCP JSON-RPC client (based on frontend/main.py)
│   ├── message_handler.py  # Agentic loop - all tools via MCP HTTP
│   ├── requirements.txt    # Slack bot specific dependencies
│   └── Dockerfile
├── TribalAgent/            # Existing - reference for fallback logic
└── thoughts/               # Existing - plans and research
```

**Note**: No dependency on company-mcp code. All MCP communication via HTTP.

#### 1.2 Create requirements.txt

**File**: `slack_bot/requirements.txt`

```
# Slack Bot Dependencies (standalone - no company-mcp imports)

# Slack
slack-bolt>=1.18.0

# Async HTTP client for MCP JSON-RPC calls
httpx>=0.26.0

# LLM providers
openai>=1.0.0

# Thread context persistence
aiosqlite>=0.19.0

# Environment variables
python-dotenv>=1.0.0
```

#### 1.3 Create slack_bot/__init__.py

**File**: `slack_bot/__init__.py`

```python
"""Slack Bot Integration with Company-MCP"""

__version__ = "0.1.0"
```

### Success Criteria

#### Automated Verification:
- [ ] Directory structure exists: `ls slack_bot/`
- [ ] Dependencies install cleanly: `pip install -r requirements.txt`
- [ ] No import errors: `python -c "import slack_bolt; import aiosqlite"`

#### Manual Verification:
- [ ] Directory structure matches specification

---

## Phase 2: LLM Provider with Fallback Logic

### Overview
Port the TribalAgent fallback logic from TypeScript to Python. This module handles OpenRouter (Claude) → OpenAI (GPT-4o) fallback.

### Changes Required

#### 2.1 Create LLM Provider Module

**File**: `slack_bot/llm_provider.py`

```python
"""
LLM Provider with Fallback Logic

Ported from TribalAgent/src/utils/llm.ts

Fallback Behavior:
- 402 (insufficient credits) errors: Immediate fallback to GPT-4o (no retry)
- Other errors: Retry once, then fallback to GPT-4o
- Controlled via LLM_FALLBACK_ENABLED env var (default: true)
"""

import os
import logging
from typing import Optional, TypedDict
from openai import OpenAI, AsyncOpenAI, APIError

logger = logging.getLogger(__name__)

# =============================================================================
# Configuration
# =============================================================================

DEFAULT_PRIMARY_MODEL = "anthropic/claude-3-5-haiku-20241022"
DEFAULT_FALLBACK_MODEL = "gpt-4o"
OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"


class LLMResponse(TypedDict):
    content: str
    tool_calls: list[dict]  # OpenAI tool_calls from response, empty if none
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    used_fallback: bool
    actual_model: str


def is_fallback_enabled() -> bool:
    """Check if LLM fallback is enabled. Default: true"""
    return os.environ.get("LLM_FALLBACK_ENABLED", "true").lower() != "false"


def get_primary_model() -> str:
    """Get primary model from env or default"""
    return os.environ.get("LLM_PRIMARY_MODEL", DEFAULT_PRIMARY_MODEL)


def get_fallback_model() -> str:
    """Get fallback model from env or default"""
    return os.environ.get("LLM_FALLBACK_MODEL", DEFAULT_FALLBACK_MODEL)


def is_credits_error(error: Exception) -> bool:
    """
    Check if error is a credits/insufficient funds error (402).
    These should fallback immediately without retry.

    Mirrors: TribalAgent/src/utils/llm.ts:81-89
    """
    error_str = str(error).lower()

    if isinstance(error, APIError) and error.status_code == 402:
        return True

    return any(indicator in error_str for indicator in [
        "402",
        "credits",
        "insufficient",
        "can only afford"
    ])


def get_openrouter_client() -> OpenAI:
    """
    Create OpenRouter client for Claude models.

    Mirrors: TribalAgent/src/utils/llm.ts:139-154
    """
    api_key = os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        raise ValueError("OPENROUTER_API_KEY environment variable not set")

    return OpenAI(
        api_key=api_key,
        base_url=OPENROUTER_BASE_URL,
        default_headers={
            "HTTP-Referer": "https://github.com/tribal-knowledge",
            "X-Title": "Tribal Knowledge Slack Bot",
        }
    )


def get_openai_client() -> OpenAI:
    """
    Create direct OpenAI client for fallback.

    Mirrors: TribalAgent/src/utils/llm.ts:157-165
    """
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY environment variable not set")

    return OpenAI(api_key=api_key)


async def get_async_openrouter_client() -> AsyncOpenAI:
    """Create async OpenRouter client for Claude models."""
    api_key = os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        raise ValueError("OPENROUTER_API_KEY environment variable not set")

    return AsyncOpenAI(
        api_key=api_key,
        base_url=OPENROUTER_BASE_URL,
        default_headers={
            "HTTP-Referer": "https://github.com/tribal-knowledge",
            "X-Title": "Tribal Knowledge Slack Bot",
        }
    )


async def get_async_openai_client() -> AsyncOpenAI:
    """Create async direct OpenAI client for fallback."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY environment variable not set")

    return AsyncOpenAI(api_key=api_key)


async def call_llm_with_fallback(
    messages: list[dict],
    tools: Optional[list[dict]] = None,
    max_tokens: int = 4096,
    temperature: float = 0.0,
) -> LLMResponse:
    """
    Call LLM with automatic fallback from OpenRouter (Claude) to OpenAI (GPT-4o).

    Mirrors the fallback logic from TribalAgent/src/utils/llm.ts:707-939

    Fallback Behavior:
    - 402 (credits) errors: Immediate fallback to GPT-4o (no retry)
    - Other errors: Retry once, then fallback to GPT-4o

    Args:
        messages: List of message dicts with role/content
        tools: Optional list of tool definitions (OpenAI format)
        max_tokens: Maximum tokens in response
        temperature: Sampling temperature

    Returns:
        LLMResponse with content, token usage, and fallback metadata
    """
    primary_model = get_primary_model()
    fallback_model = get_fallback_model()

    # Build request kwargs
    def build_kwargs(model: str) -> dict:
        kwargs = {
            "model": model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        if tools:
            kwargs["tools"] = tools
        return kwargs

    # ==========================================================================
    # Try Primary Model (Claude via OpenRouter)
    # ==========================================================================

    openrouter_key = os.environ.get("OPENROUTER_API_KEY")
    last_error: Optional[Exception] = None

    if openrouter_key:
        client = await get_async_openrouter_client()
        kwargs = build_kwargs(primary_model)

        for attempt in range(2):  # Max 2 attempts (initial + 1 retry)
            try:
                logger.debug(f"LLM call attempt {attempt + 1}/2 for model {primary_model}")

                response = await client.chat.completions.create(**kwargs)

                message = response.choices[0].message
                content = message.content or ""
                usage = response.usage

                # Extract tool_calls if present
                tool_calls = []
                if message.tool_calls:
                    tool_calls = [
                        {
                            "id": tc.id,
                            "type": "function",
                            "function": {
                                "name": tc.function.name,
                                "arguments": tc.function.arguments
                            }
                        }
                        for tc in message.tool_calls
                    ]

                logger.debug(f"LLM call successful, response length: {len(content)}, tool_calls: {len(tool_calls)}")

                return LLMResponse(
                    content=content,
                    tool_calls=tool_calls,
                    prompt_tokens=usage.prompt_tokens if usage else 0,
                    completion_tokens=usage.completion_tokens if usage else 0,
                    total_tokens=usage.total_tokens if usage else 0,
                    used_fallback=False,
                    actual_model=primary_model,
                )

            except Exception as e:
                last_error = e
                logger.warning(f"LLM call attempt {attempt + 1} failed: {e}")

                # 402 errors: immediate fallback (no retry)
                if is_credits_error(e):
                    logger.warning("Credits error detected, falling back immediately")
                    break

                # Other errors: retry once
                if attempt == 0:
                    logger.debug("Retrying primary model...")
                    continue
                else:
                    logger.warning("Retry failed, will attempt fallback")
                    break

    # ==========================================================================
    # Fallback to OpenAI (GPT-4o)
    # ==========================================================================

    openai_key = os.environ.get("OPENAI_API_KEY")

    if is_fallback_enabled() and openai_key:
        logger.warning(
            f"Primary LLM ({primary_model}) failed. "
            f"Falling back to {fallback_model}..."
        )

        try:
            client = await get_async_openai_client()
            kwargs = build_kwargs(fallback_model)

            response = await client.chat.completions.create(**kwargs)

            message = response.choices[0].message
            content = message.content or ""
            usage = response.usage

            # Extract tool_calls if present
            tool_calls = []
            if message.tool_calls:
                tool_calls = [
                    {
                        "id": tc.id,
                        "type": "function",
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments
                        }
                    }
                    for tc in message.tool_calls
                ]

            logger.info(
                f"Fallback to {fallback_model} succeeded! "
                f"Response length: {len(content)} chars, tool_calls: {len(tool_calls)}"
            )

            return LLMResponse(
                content=content,
                tool_calls=tool_calls,
                prompt_tokens=usage.prompt_tokens if usage else 0,
                completion_tokens=usage.completion_tokens if usage else 0,
                total_tokens=usage.total_tokens if usage else 0,
                used_fallback=True,
                actual_model=fallback_model,
            )

        except Exception as fallback_error:
            logger.error(
                f"Both primary ({primary_model}) and fallback ({fallback_model}) failed. "
                f"Primary error: {last_error}. Fallback error: {fallback_error}"
            )
            raise RuntimeError(
                f"All LLM providers failed. Primary: {last_error}. Fallback: {fallback_error}"
            )

    # No fallback available
    error_msg = f"LLM call failed: {last_error}"
    if not openai_key:
        error_msg += " (no OPENAI_API_KEY for fallback)"
    if not is_fallback_enabled():
        error_msg += " (fallback disabled)"

    raise RuntimeError(error_msg)


def get_fallback_status() -> dict:
    """
    Get current fallback configuration status.
    Useful for debugging and status reporting.

    Mirrors: TribalAgent/src/utils/llm.ts:998-1008
    """
    return {
        "enabled": is_fallback_enabled(),
        "available": bool(os.environ.get("OPENAI_API_KEY")),
        "primary_model": get_primary_model(),
        "fallback_model": get_fallback_model(),
    }
```

### Success Criteria

#### Automated Verification:
- [ ] Module imports without errors: `python -c "from slack_bot.llm_provider import call_llm_with_fallback"`
- [ ] Type hints are valid: `mypy slack_bot/llm_provider.py` (if mypy installed)

#### Manual Verification:
- [ ] Fallback logic matches TribalAgent behavior (compare with `llm.ts:707-939`)

---

## Phase 3: Thread Context Storage (SQLite)

### Overview
Implement SQLite-backed thread context storage for conversation persistence across bot restarts.

### Changes Required

#### 3.1 Create Thread Context Module

**File**: `slack_bot/thread_context.py`

```python
"""
Thread Context Storage

SQLite-backed storage for Slack thread conversation contexts.
Conversations persist per Slack thread (not per channel).

Thread Key Format: {channel_id}:{thread_ts}
"""

import os
import time
import json
import logging
import aiosqlite
from typing import Optional
from dataclasses import dataclass, field, asdict

logger = logging.getLogger(__name__)

# Default database path
DEFAULT_DB_PATH = os.environ.get("THREAD_CONTEXT_DB", "/data/thread_contexts.db")

# Context expiration (24 hours in seconds)
CONTEXT_EXPIRATION_SECONDS = 86400


@dataclass
class Message:
    """A single message in a thread conversation."""
    role: str  # "user" or "assistant"
    content: str
    timestamp: str  # Slack ts
    user_id: Optional[str] = None


@dataclass
class ThreadContext:
    """Conversation context for a single Slack thread."""
    thread_key: str
    channel_id: str
    thread_ts: str
    started_by: str  # User ID who started the conversation
    created_at: float
    last_updated: float
    messages: list[Message] = field(default_factory=list)

    def to_llm_messages(self) -> list[dict]:
        """Convert to LLM message format."""
        return [
            {"role": msg.role, "content": msg.content}
            for msg in self.messages
        ]

    def add_message(self, role: str, content: str, timestamp: str, user_id: Optional[str] = None):
        """Add a message to the conversation."""
        self.messages.append(Message(
            role=role,
            content=content,
            timestamp=timestamp,
            user_id=user_id,
        ))
        self.last_updated = time.time()


class ThreadContextStore:
    """
    SQLite-backed thread context storage.

    Usage:
        store = ThreadContextStore()
        await store.initialize()

        context = await store.get_or_create(channel_id, thread_ts, user_id)
        context.add_message("user", "Hello", "1234567890.123456", "U12345")
        await store.save(context)
    """

    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        self.db_path = db_path
        self._initialized = False

    async def initialize(self):
        """Create database tables if they don't exist."""
        if self._initialized:
            return

        # Ensure directory exists
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)

        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                CREATE TABLE IF NOT EXISTS thread_contexts (
                    thread_key TEXT PRIMARY KEY,
                    channel_id TEXT NOT NULL,
                    thread_ts TEXT NOT NULL,
                    started_by TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    last_updated REAL NOT NULL,
                    messages_json TEXT NOT NULL DEFAULT '[]'
                )
            """)

            # Index for cleanup queries
            await db.execute("""
                CREATE INDEX IF NOT EXISTS idx_thread_contexts_last_updated
                ON thread_contexts(last_updated)
            """)

            await db.commit()

        self._initialized = True
        logger.info(f"Thread context store initialized at {self.db_path}")

    @staticmethod
    def make_thread_key(channel_id: str, thread_ts: str) -> str:
        """Create unique thread key from channel and thread timestamp."""
        return f"{channel_id}:{thread_ts}"

    async def get(self, channel_id: str, thread_ts: str) -> Optional[ThreadContext]:
        """Get existing thread context or None if not found."""
        await self.initialize()

        thread_key = self.make_thread_key(channel_id, thread_ts)

        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute(
                "SELECT * FROM thread_contexts WHERE thread_key = ?",
                (thread_key,)
            )
            row = await cursor.fetchone()

            if not row:
                return None

            # Parse messages from JSON
            messages_data = json.loads(row["messages_json"])
            messages = [Message(**msg) for msg in messages_data]

            return ThreadContext(
                thread_key=row["thread_key"],
                channel_id=row["channel_id"],
                thread_ts=row["thread_ts"],
                started_by=row["started_by"],
                created_at=row["created_at"],
                last_updated=row["last_updated"],
                messages=messages,
            )

    async def get_or_create(
        self,
        channel_id: str,
        thread_ts: str,
        user_id: str
    ) -> ThreadContext:
        """Get existing context or create new one."""
        context = await self.get(channel_id, thread_ts)

        if context:
            return context

        # Create new context
        now = time.time()
        context = ThreadContext(
            thread_key=self.make_thread_key(channel_id, thread_ts),
            channel_id=channel_id,
            thread_ts=thread_ts,
            started_by=user_id,
            created_at=now,
            last_updated=now,
            messages=[],
        )

        await self.save(context)
        logger.debug(f"Created new thread context: {context.thread_key}")

        return context

    async def save(self, context: ThreadContext):
        """Save thread context to database."""
        await self.initialize()

        # Serialize messages to JSON
        messages_json = json.dumps([asdict(msg) for msg in context.messages])

        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                INSERT OR REPLACE INTO thread_contexts
                (thread_key, channel_id, thread_ts, started_by, created_at, last_updated, messages_json)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                context.thread_key,
                context.channel_id,
                context.thread_ts,
                context.started_by,
                context.created_at,
                context.last_updated,
                messages_json,
            ))
            await db.commit()

    async def delete(self, channel_id: str, thread_ts: str):
        """Delete a thread context."""
        await self.initialize()

        thread_key = self.make_thread_key(channel_id, thread_ts)

        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "DELETE FROM thread_contexts WHERE thread_key = ?",
                (thread_key,)
            )
            await db.commit()

    async def cleanup_old_contexts(self, max_age_seconds: int = CONTEXT_EXPIRATION_SECONDS) -> int:
        """
        Remove contexts older than max_age_seconds.
        Returns number of deleted contexts.
        """
        await self.initialize()

        cutoff = time.time() - max_age_seconds

        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute(
                "DELETE FROM thread_contexts WHERE last_updated < ?",
                (cutoff,)
            )
            await db.commit()

            deleted = cursor.rowcount
            if deleted > 0:
                logger.info(f"Cleaned up {deleted} old thread contexts")

            return deleted

    async def get_stats(self) -> dict:
        """Get storage statistics."""
        await self.initialize()

        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute("SELECT COUNT(*) FROM thread_contexts")
            row = await cursor.fetchone()
            total_contexts = row[0] if row else 0

            cursor = await db.execute(
                "SELECT SUM(LENGTH(messages_json)) FROM thread_contexts"
            )
            row = await cursor.fetchone()
            total_message_bytes = row[0] if row and row[0] else 0

            return {
                "total_contexts": total_contexts,
                "total_message_bytes": total_message_bytes,
                "db_path": self.db_path,
            }


# Global store instance
_store: Optional[ThreadContextStore] = None


def get_store() -> ThreadContextStore:
    """Get the global thread context store instance."""
    global _store
    if _store is None:
        _store = ThreadContextStore()
    return _store
```

### Success Criteria

#### Automated Verification:
- [ ] Module imports without errors: `python -c "from slack_bot.thread_context import ThreadContextStore"`
- [ ] Unit test passes: Create context, add message, retrieve, verify persistence

#### Manual Verification:
- [ ] Restart bot and verify thread context is preserved

---

## Phase 4: Message Handler with MCP Client Integration

### Overview
Create the message handler that connects to the MCP server to dynamically fetch available tools, then uses those tools for processing messages. This reuses the exact tool definitions from the MCP server.

### Changes Required

#### 4.1 Create MCP Client Module

**File**: `slack_bot/mcp_client.py`

```python
"""
MCP Client

JSON-RPC client for Company-MCP servers.
Based on frontend/main.py:541-619 from company-mcp master branch.

Protocol:
1. Initialize session → get mcp-session-id header
2. List tools → get available tools with schemas
3. Call tool → execute tool with arguments

Supports multiple MCP servers with tool namespacing: {server_id}__{tool_name}

Session Management:
- Sessions are reused within the same Slack thread (same MCPClient instance)
- New Slack messages create new MCPClient instances (fresh sessions)
- This balances efficiency with isolation
"""

import os
import json
import logging
import asyncio
from typing import Optional
from dataclasses import dataclass

import httpx

logger = logging.getLogger(__name__)


@dataclass
class MCPServer:
    """Configuration for an MCP server."""
    id: str
    url: str
    name: str


def normalize_mcp_url(url: str) -> str:
    """
    Normalize MCP server URL for Docker networking.

    Based on frontend/main.py - handles Docker internal hostnames.
    Converts localhost URLs to host.docker.internal when running in Docker.
    """
    # Check if we're running in Docker (common indicator)
    in_docker = os.path.exists('/.dockerenv') or os.environ.get('DOCKER_CONTAINER')

    if in_docker and 'localhost' in url:
        return url.replace('localhost', 'host.docker.internal')

    return url


# Default MCP server configurations
DEFAULT_SERVERS = [
    MCPServer(
        id="synth-mcp",
        url=os.environ.get("MCP_SYNTH_URL", "http://localhost:8001"),
        name="Schema Context (Synthetic)"
    ),
    MCPServer(
        id="postgres-mcp",
        url=os.environ.get("MCP_POSTGRES_URL", "http://localhost:8002"),
        name="PostgreSQL Execution (Read-Only)"
    ),
]


def parse_sse_response(text: str) -> dict:
    """
    Parse SSE response from MCP server.

    SSE format: 'data: {"jsonrpc": "2.0", ...}'
    """
    for line in text.strip().split("\n"):
        if line.startswith("data:"):
            json_str = line[5:].strip()
            if json_str:
                return json.loads(json_str)
    # Fallback: try parsing entire response as JSON
    return json.loads(text)


class MCPClient:
    """
    Client for connecting to multiple Company-MCP servers.

    Fetches tool definitions dynamically and executes tool calls via JSON-RPC.
    Tools are namespaced as {server_id}__{tool_name}.

    Session Management:
    - Sessions are cached per server and reused within the client lifetime
    - Create a new MCPClient instance for each new Slack message
    - Sessions persist across tool calls within the same message processing
    """

    def __init__(self, servers: list[MCPServer] = None):
        self.servers = servers or DEFAULT_SERVERS
        self._tools_cache: dict[str, list[dict]] = {}  # server_id -> tools
        self._session_cache: dict[str, str] = {}  # server_id -> session_id (reused within thread)
        self._all_tools_for_llm: Optional[list[dict]] = None
        self._http_client: Optional[httpx.AsyncClient] = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client."""
        if self._http_client is None:
            self._http_client = httpx.AsyncClient(timeout=60.0)
        return self._http_client

    async def close(self):
        """Close HTTP client."""
        if self._http_client:
            await self._http_client.aclose()
            self._http_client = None

    async def _get_session(self, server: MCPServer) -> Optional[str]:
        """
        Get or create MCP session with server.

        Sessions are cached and reused within the same MCPClient instance.
        Returns session ID from mcp-session-id header.
        """
        # Return cached session if available
        if server.id in self._session_cache:
            return self._session_cache[server.id]

        client = await self._get_client()
        # Normalize URL for Docker networking
        normalized_url = normalize_mcp_url(server.url)
        mcp_endpoint = f"{normalized_url.rstrip('/')}/mcp"

        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "TribalKnowledge-SlackBot", "version": "1.0.0"}
            }
        }

        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream"
        }

        try:
            response = await client.post(mcp_endpoint, json=payload, headers=headers)
            if response.status_code == 200:
                session_id = response.headers.get("mcp-session-id")
                if session_id:
                    self._session_cache[server.id] = session_id
                    logger.debug(f"Created new session for {server.id}: {session_id[:8]}...")
                return session_id
            else:
                logger.error(f"Failed to init session with {server.id}: {response.status_code}")
                return None
        except Exception as e:
            logger.error(f"Error initializing session with {server.id}: {e}")
            return None

    async def fetch_tools_from_server(self, server: MCPServer) -> list[dict]:
        """
        Fetch tools from a single MCP server.

        Returns list of tool definitions with server_id prefix.
        """
        if server.id in self._tools_cache:
            return self._tools_cache[server.id]

        session_id = await self._get_session(server)
        if not session_id:
            logger.warning(f"Could not get session for {server.id}, skipping")
            return []

        client = await self._get_client()
        normalized_url = normalize_mcp_url(server.url)
        mcp_endpoint = f"{normalized_url.rstrip('/')}/mcp"

        payload = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {}
        }

        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "mcp-session-id": session_id
        }

        try:
            response = await client.post(mcp_endpoint, json=payload, headers=headers)
            if response.status_code == 200:
                data = parse_sse_response(response.text)
                tools = data.get("result", {}).get("tools", [])

                # Add server_id prefix to tool names
                for tool in tools:
                    tool["_server_id"] = server.id
                    tool["_original_name"] = tool["name"]
                    tool["name"] = f"{server.id}__{tool['name']}"

                self._tools_cache[server.id] = tools
                logger.info(f"Loaded {len(tools)} tools from {server.id}")
                return tools
            else:
                logger.error(f"Failed to fetch tools from {server.id}: {response.status_code}")
                return []
        except Exception as e:
            logger.error(f"Error fetching tools from {server.id}: {e}")
            return []

    async def get_all_tools(self) -> list[dict]:
        """Fetch tools from all configured MCP servers."""
        all_tools = []
        for server in self.servers:
            tools = await self.fetch_tools_from_server(server)
            all_tools.extend(tools)
        return all_tools

    async def get_tools_for_llm(self) -> list[dict]:
        """
        Get tools formatted for OpenAI function calling format.

        Converts MCP tool schema to OpenAI tools format.
        """
        if self._all_tools_for_llm is not None:
            return self._all_tools_for_llm

        mcp_tools = await self.get_all_tools()

        self._all_tools_for_llm = []
        for tool in mcp_tools:
            self._all_tools_for_llm.append({
                "type": "function",
                "function": {
                    "name": tool["name"],  # Already prefixed with server_id__
                    "description": tool.get("description", ""),
                    "parameters": tool.get("inputSchema", {"type": "object", "properties": {}})
                }
            })

        logger.info(f"Prepared {len(self._all_tools_for_llm)} tools for LLM")
        return self._all_tools_for_llm

    async def call_tool(self, tool_name: str, arguments: dict) -> str:
        """
        Execute a tool on the appropriate MCP server.

        Tool name format: {server_id}__{tool_name}
        """
        logger.info(f"Calling MCP tool: {tool_name}")

        # Parse server_id from tool name
        if "__" not in tool_name:
            return f"Error: Invalid tool name format. Expected 'server_id__tool_name', got '{tool_name}'"

        server_id, original_tool_name = tool_name.split("__", 1)

        # Find server
        server = next((s for s in self.servers if s.id == server_id), None)
        if not server:
            return f"Error: Unknown server '{server_id}'"

        # Get session (reuses cached session if available)
        session_id = await self._get_session(server)
        if not session_id:
            return f"Error: Could not connect to {server_id}"

        client = await self._get_client()
        normalized_url = normalize_mcp_url(server.url)
        mcp_endpoint = f"{normalized_url.rstrip('/')}/mcp"

        payload = {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": original_tool_name,  # Use original name without prefix
                "arguments": arguments
            }
        }

        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "mcp-session-id": session_id
        }

        try:
            response = await client.post(mcp_endpoint, json=payload, headers=headers)
            if response.status_code == 200:
                data = parse_sse_response(response.text)

                if "error" in data:
                    return f"Error: {data['error'].get('message', 'Unknown error')}"

                result = data.get("result", {})
                content = result.get("content", [])

                # Extract text from content blocks
                text_parts = []
                for block in content:
                    if block.get("type") == "text":
                        text_parts.append(block.get("text", ""))

                return "\n".join(text_parts) if text_parts else json.dumps(result, indent=2)
            else:
                return f"Error ({response.status_code}): {response.text[:200]}"

        except asyncio.TimeoutError:
            return f"Error: Tool call timed out after 60 seconds"
        except Exception as e:
            logger.error(f"MCP tool call failed: {e}")
            return f"Error calling {tool_name}: {str(e)}"


# Note: MCPClient instances should be created per-message, not globally
# This ensures fresh sessions for each new Slack message while reusing
# sessions within the same message's agentic loop.
#
# Usage in message_handler.py:
#   mcp_client = MCPClient()  # Fresh client per message
#   tools = await mcp_client.get_tools_for_llm()
#   result = await mcp_client.call_tool(...)
#   await mcp_client.close()  # Clean up when done


def create_mcp_client() -> MCPClient:
    """Create a new MCP client instance for processing a message."""
    return MCPClient()
```

#### 4.2 Create Message Handler Module

**File**: `slack_bot/message_handler.py`

```python
"""
Message Handler

Processes Slack messages using:
- MCP server tools (dynamically fetched) for ALL operations
- LLM with fallback for orchestration

All tool calls go through MCP HTTP API:
- Schema tools via synth-mcp (all 15 tools available)
- SQL execution via postgres-mcp (all 9 tools available, read-only)
"""

import json
import logging
import asyncio

from slack_bot.llm_provider import call_llm_with_fallback, get_fallback_status
from slack_bot.thread_context import ThreadContext, get_store
from slack_bot.mcp_client import create_mcp_client

logger = logging.getLogger(__name__)

# System prompt for the Slack bot
SYSTEM_PROMPT = """You are a helpful database documentation assistant for the Tribal Knowledge team.
You help users understand database schemas, find tables, and answer questions about data.

You have access to ALL tools from two MCP servers (tools are prefixed with server name):

**synth-mcp** (Schema Context - 15 tools):
Tools for searching and exploring database schema documentation.
Examples: synth-mcp__search_tables, synth-mcp__get_table_schema, synth-mcp__search_fts,
synth-mcp__search_vector, synth-mcp__list_columns, synth-mcp__list_domains, etc.

**postgres-mcp** (SQL Execution - 9 tools, READ-ONLY):
Tools for executing queries and exploring live database.
Examples: postgres-mcp__execute_query, postgres-mcp__describe_table,
postgres-mcp__get_sample_data, postgres-mcp__list_tables, etc.
NOTE: Only SELECT queries are allowed - no INSERT, UPDATE, DELETE, etc.

Workflow for data questions:
1. Use synth-mcp tools to understand the schema (search_tables, get_table_schema)
2. Write SQL based on what you learned
3. Use postgres-mcp__execute_query to run your SQL

Always cite which tables/columns you found information from.
Format results as Slack-friendly text (use code blocks for SQL and data).

For follow-up questions, use the conversation context to understand references.
"""


async def process_message(
    user_message: str,
    context: ThreadContext,
    user_id: str,
    message_ts: str,
) -> tuple[str, bool]:
    """
    Process a user message and generate a response.

    Uses an agentic loop:
    1. Send message + context to LLM with available tools
    2. If LLM calls tools, execute them and continue
    3. Repeat until LLM returns final response

    Session Management:
    - Creates a fresh MCP client per message (new sessions)
    - Sessions are reused across tool calls within the same message

    Args:
        user_message: The user's message text
        context: Thread context with conversation history
        user_id: Slack user ID
        message_ts: Slack message timestamp

    Returns:
        Tuple of (response_text, used_fallback)
    """
    # Add user message to context
    context.add_message("user", user_message, message_ts, user_id)

    # Create fresh MCP client for this message (new sessions)
    # Sessions are reused within the agentic loop for efficiency
    mcp_client = create_mcp_client()

    try:
        # Get tools from MCP server (dynamically)
        tools = await mcp_client.get_tools_for_llm()

        if not tools:
            logger.warning("No tools available from MCP server")
        else:
            logger.info(f"Using {len(tools)} tools from MCP server")

        # Build messages for LLM
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            *context.to_llm_messages()
        ]

        # Agentic loop
        max_iterations = 10  # Prevent infinite loops
        used_fallback = False

        for iteration in range(max_iterations):
            logger.debug(f"LLM iteration {iteration + 1}/{max_iterations}")

            # Call LLM with tools
            response = await call_llm_with_fallback(
                messages=messages,
                tools=tools if tools else None,
                max_tokens=4096,
            )

            used_fallback = used_fallback or response["used_fallback"]

            # Check response for tool calls (now properly returned by LLM provider)
            tool_calls = response.get("tool_calls", [])

            if not tool_calls:
                # No tool calls - LLM is done, return content
                content = response["content"]

                # Add assistant response to context
                context.add_message("assistant", content, message_ts)

                # Save context
                store = get_store()
                await store.save(context)

                return content, used_fallback

            # Execute tool calls
            logger.info(f"Executing {len(tool_calls)} tool calls")

            # Add assistant message with tool calls to conversation
            messages.append({
                "role": "assistant",
                "content": response.get("content", ""),
                "tool_calls": tool_calls
            })

            # Execute each tool and add results (reuses MCP sessions within this message)
            for tool_call in tool_calls:
                tool_name = tool_call["function"]["name"]
                tool_args = json.loads(tool_call["function"]["arguments"])

                # Execute tool via MCP client (sessions reused within this message)
                logger.info(f"Executing tool: {tool_name}")
                tool_result = await mcp_client.call_tool(tool_name, tool_args)

                # Add tool result to messages
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "content": tool_result
                })

        # Max iterations reached
        logger.warning("Max iterations reached in agentic loop")
        return ":warning: I wasn't able to complete your request. Please try rephrasing your question.", used_fallback

    finally:
        # Always close the MCP client to clean up HTTP connections
        await mcp_client.close()
```

### Success Criteria

#### Automated Verification:
- [ ] Module imports without errors: `python -c "from slack_bot.message_handler import process_message"`
- [ ] Tool definitions are valid JSON schema

#### Manual Verification:
- [ ] Send test message and receive response
- [ ] SQL queries execute and return formatted results

---

## Phase 5: Main Slack Bot Application

### Overview
Create the main Slack Bolt application with event handlers for @mentions and thread messages.

### Changes Required

#### 5.1 Create Main Application

**File**: `slack_bot/app.py`

```python
"""
Slack Bot Application

Main entry point for the Tribal Knowledge Slack bot.
Uses Slack Bolt AsyncApp with Socket Mode for event handling.
"""

import os
import sys
import logging
import asyncio
from dotenv import load_dotenv

from slack_bolt.async_app import AsyncApp
from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from slack_bot.thread_context import get_store
from slack_bot.message_handler import process_message
from slack_bot.llm_provider import get_fallback_status

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize Slack app
app = AsyncApp(
    token=os.environ.get("SLACK_BOT_TOKEN"),
    signing_secret=os.environ.get("SLACK_SIGNING_SECRET"),
)


def strip_bot_mention(text: str, bot_user_id: str) -> str:
    """Remove bot mention from message text."""
    import re
    # Remove <@BOT_ID> pattern
    pattern = f"<@{bot_user_id}>"
    return re.sub(pattern, "", text).strip()


async def handle_message_async(
    channel_id: str,
    thread_ts: str,
    user_id: str,
    message_ts: str,
    text: str,
    client,
):
    """
    Background task to process message with LLM.

    This runs asynchronously so the event handler can return within 3 seconds.
    """
    # Post "thinking" indicator
    thinking_msg = await client.chat_postMessage(
        channel=channel_id,
        thread_ts=thread_ts,
        text=":hourglass_flowing_sand: Thinking..."
    )
    thinking_ts = thinking_msg["ts"]

    try:
        # Get or create thread context
        store = get_store()
        context = await store.get_or_create(channel_id, thread_ts, user_id)

        # Process the message
        response_text, used_fallback = await process_message(
            user_message=text,
            context=context,
            user_id=user_id,
            message_ts=message_ts,
        )

        # Add fallback indicator if used
        if used_fallback:
            fallback_status = get_fallback_status()
            response_text += f"\n\n_:warning: Used fallback model: {fallback_status['fallback_model']}_"

        # Update the thinking message with the response
        await client.chat_update(
            channel=channel_id,
            ts=thinking_ts,
            text=response_text
        )

    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)

        # Update with error message
        await client.chat_update(
            channel=channel_id,
            ts=thinking_ts,
            text=f":x: Sorry, I encountered an error: {str(e)}"
        )


@app.event("app_mention")
async def handle_app_mention(event, client, logger):
    """
    Handle @mentions of the bot in channels.

    This is the primary way users interact with the bot.
    Conversations persist per thread.
    """
    channel_id = event["channel"]
    user_id = event["user"]
    message_ts = event["ts"]
    text = event.get("text", "")

    # Get thread_ts - if not in a thread, use message_ts as the thread root
    thread_ts = event.get("thread_ts", message_ts)

    # Get bot user ID to strip mention from text
    auth_response = await client.auth_test()
    bot_user_id = auth_response["user_id"]

    # Strip bot mention from text
    clean_text = strip_bot_mention(text, bot_user_id)

    if not clean_text:
        await client.chat_postMessage(
            channel=channel_id,
            thread_ts=thread_ts,
            text="Hi! How can I help you? Ask me about database schemas or data."
        )
        return

    logger.info(f"Received mention from {user_id} in {channel_id}: {clean_text[:50]}...")

    # Process in background (don't await - return immediately)
    asyncio.create_task(
        handle_message_async(
            channel_id=channel_id,
            thread_ts=thread_ts,
            user_id=user_id,
            message_ts=message_ts,
            text=clean_text,
            client=client,
        )
    )


@app.event("message")
async def handle_thread_message(event, client, logger):
    """
    Handle messages in threads where the bot is active.

    This allows follow-up questions without re-mentioning the bot.
    """
    # Skip bot messages
    if event.get("bot_id") or event.get("subtype"):
        return

    # Only respond to thread replies (not channel messages)
    thread_ts = event.get("thread_ts")
    if not thread_ts:
        return

    channel_id = event["channel"]
    user_id = event["user"]
    message_ts = event["ts"]
    text = event.get("text", "")

    # Check if we have an active context for this thread
    store = get_store()
    context = await store.get(channel_id, thread_ts)

    if not context:
        # Not a thread we're tracking - ignore
        return

    logger.info(f"Received thread message from {user_id}: {text[:50]}...")

    # Process in background
    asyncio.create_task(
        handle_message_async(
            channel_id=channel_id,
            thread_ts=thread_ts,
            user_id=user_id,
            message_ts=message_ts,
            text=text,
            client=client,
        )
    )


@app.event("app_home_opened")
async def handle_app_home(event, client, logger):
    """Handle App Home tab opened - show usage instructions."""
    user_id = event["user"]

    await client.views_publish(
        user_id=user_id,
        view={
            "type": "home",
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": ":wave: Welcome to Tribal Knowledge Bot"
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "I help you explore database schemas and query data. Here's how to use me:"
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*1. Mention me in a channel:*\n`@Tribal Knowledge what tables have user data?`"
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*2. Ask follow-up questions in the thread:*\nNo need to mention me again - I'll respond to any message in the thread."
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*3. Query data:*\n`How many users signed up last month?`\n`Show me the top 10 merchants by revenue`"
                    }
                },
                {
                    "type": "divider"
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "mrkdwn",
                            "text": ":gear: Powered by Company-MCP | :robot_face: AI: Claude + GPT-4o fallback"
                        }
                    ]
                }
            ]
        }
    )


async def cleanup_task():
    """Periodic task to clean up old thread contexts."""
    store = get_store()

    while True:
        await asyncio.sleep(3600)  # Run every hour
        try:
            deleted = await store.cleanup_old_contexts()
            if deleted > 0:
                logger.info(f"Cleaned up {deleted} old thread contexts")
        except Exception as e:
            logger.error(f"Cleanup task error: {e}")


async def main():
    """Main entry point."""
    logger.info("Starting Tribal Knowledge Slack Bot...")

    # Log configuration
    fallback_status = get_fallback_status()
    logger.info(f"LLM Configuration: {fallback_status}")

    # Initialize thread context store
    store = get_store()
    await store.initialize()

    stats = await store.get_stats()
    logger.info(f"Thread context store: {stats}")

    # Start cleanup task
    asyncio.create_task(cleanup_task())

    # Start Socket Mode handler
    handler = AsyncSocketModeHandler(
        app=app,
        app_token=os.environ.get("SLACK_APP_TOKEN")
    )

    logger.info("Bot is ready! Listening for events...")
    await handler.start_async()


if __name__ == "__main__":
    asyncio.run(main())
```

### Success Criteria

#### Automated Verification:
- [ ] Application starts without errors: `python slack_bot/app.py`
- [ ] Imports resolve correctly

#### Manual Verification:
- [ ] Bot responds to @mentions
- [ ] Bot responds to thread messages without re-mentioning
- [ ] "Thinking" indicator appears and updates
- [ ] App Home shows usage instructions

---

## Phase 6: Docker Configuration (Optional)

### Overview
Create Dockerfile for standalone deployment. The bot can run locally during development or in Docker for production.

### Changes Required

#### 6.1 Create Slack Bot Dockerfile

**File**: `slack_bot/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create data directory for SQLite
RUN mkdir -p /data

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV THREAD_CONTEXT_DB=/data/thread_contexts.db

# Run the bot
CMD ["python", "-m", "slack_bot.app"]
```

#### 6.2 Create docker-compose.yml (Standalone)

**File**: `slack_bot/docker-compose.yml`

This is a standalone docker-compose for the Slack bot only. It connects to Company-MCP servers running elsewhere.

```yaml
version: '3.8'

services:
  slack-bot:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      # Slack credentials
      - SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN}
      - SLACK_APP_TOKEN=${SLACK_APP_TOKEN}
      - SLACK_SIGNING_SECRET=${SLACK_SIGNING_SECRET}

      # MCP Server URLs (Company-MCP running separately)
      # Use host.docker.internal to reach services on host machine
      - MCP_SYNTH_URL=${MCP_SYNTH_URL:-http://host.docker.internal:8001}
      - MCP_POSTGRES_URL=${MCP_POSTGRES_URL:-http://host.docker.internal:8002}

      # LLM configuration
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - LLM_PRIMARY_MODEL=${LLM_PRIMARY_MODEL:-anthropic/claude-3-5-haiku-20241022}
      - LLM_FALLBACK_MODEL=${LLM_FALLBACK_MODEL:-gpt-4o}
      - LLM_FALLBACK_ENABLED=${LLM_FALLBACK_ENABLED:-true}

      # Logging
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
    volumes:
      - slack_bot_data:/data
    restart: unless-stopped
    # Note: No depends_on - MCP servers are external to this compose file
    # Ensure Company-MCP services are running before starting this bot

volumes:
  slack_bot_data:
```

#### 6.3 Create .env.example

**File**: `slack_bot/.env.example`

```bash
# =============================================================================
# Slack Bot Configuration
# =============================================================================

# Slack credentials (from https://api.slack.com/apps)
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_APP_TOKEN=xapp-your-app-level-token
SLACK_SIGNING_SECRET=your-signing-secret

# =============================================================================
# MCP Server URLs
# =============================================================================
# These point to Company-MCP servers (running separately)
# Defaults work for local development with Company-MCP on same machine

MCP_SYNTH_URL=http://localhost:8001
MCP_POSTGRES_URL=http://localhost:8002

# =============================================================================
# LLM Configuration
# =============================================================================

# OpenRouter for Claude (primary)
OPENROUTER_API_KEY=sk-or-...

# OpenAI for GPT-4o (fallback)
OPENAI_API_KEY=sk-...

# Model selection (optional - these are the defaults)
LLM_PRIMARY_MODEL=anthropic/claude-3-5-haiku-20241022
LLM_FALLBACK_MODEL=gpt-4o
LLM_FALLBACK_ENABLED=true

# =============================================================================
# Logging
# =============================================================================

LOG_LEVEL=INFO
```

### Success Criteria

#### Automated Verification:
- [ ] Docker builds successfully: `docker-compose build slack-bot`
- [ ] Container starts: `docker-compose up slack-bot`
- [ ] Health check passes (MCP dependency)

#### Manual Verification:
- [ ] Bot connects to Slack workspace
- [ ] Bot responds to messages in container
- [ ] Thread context persists after container restart

---

## Phase 7: Slack App Configuration

### Overview
Document the required Slack App configuration for the bot to function.

### Changes Required

#### 7.1 Create Slack App Setup Documentation

**File**: `slack_bot/SETUP.md`

```markdown
# Slack App Setup Guide

## 1. Create Slack App

1. Go to https://api.slack.com/apps
2. Click "Create New App"
3. Choose "From scratch"
4. Name: "Tribal Knowledge Bot"
5. Select your workspace

## 2. Enable Socket Mode

1. Go to "Socket Mode" in the sidebar
2. Enable Socket Mode
3. Create an App-Level Token:
   - Name: "socket-mode-token"
   - Scopes: `connections:write`
4. Copy the token (starts with `xapp-`) → `SLACK_APP_TOKEN`

## 3. Configure OAuth & Permissions

Go to "OAuth & Permissions" and add these Bot Token Scopes:

### Required Scopes
- `app_mentions:read` - Listen for @mentions
- `chat:write` - Send messages
- `channels:history` - Read channel messages (for thread context)
- `groups:history` - Read private channel messages
- `im:history` - Read DM history (if needed)

### Install App
1. Click "Install to Workspace"
2. Authorize the app
3. Copy the Bot User OAuth Token (starts with `xoxb-`) → `SLACK_BOT_TOKEN`

## 4. Configure Event Subscriptions

Go to "Event Subscriptions":

1. Enable Events
2. Subscribe to bot events:
   - `app_mention` - When bot is @mentioned
   - `message.channels` - Messages in public channels
   - `message.groups` - Messages in private channels
   - `app_home_opened` - App Home tab opened

## 5. Configure App Home (Optional)

Go to "App Home":

1. Enable Home Tab
2. Enable Messages Tab (optional)

## 6. Get Signing Secret

Go to "Basic Information":

1. Copy the Signing Secret → `SLACK_SIGNING_SECRET`

## 7. Environment Variables

Create a `.env` file with:

```bash
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_APP_TOKEN=xapp-your-app-level-token
SLACK_SIGNING_SECRET=your-signing-secret
```

## 8. Test the Bot

1. Start the bot: `docker-compose up slack-bot`
2. Invite the bot to a channel: `/invite @Tribal Knowledge Bot`
3. Mention the bot: `@Tribal Knowledge Bot what tables have user data?`

## Troubleshooting

### Bot not responding
- Check Socket Mode is enabled
- Verify `SLACK_APP_TOKEN` starts with `xapp-`
- Check container logs: `docker-compose logs slack-bot`

### Permission errors
- Verify all scopes are added
- Reinstall the app after adding scopes

### Thread context not persisting
- Check volume mount: `slack_bot_data:/data`
- Verify SQLite file exists: `docker-compose exec slack-bot ls -la /data/`
```

### Success Criteria

#### Manual Verification:
- [ ] Slack App created with correct configuration
- [ ] Bot can be invited to channels
- [ ] Bot responds to @mentions

---

## Testing Strategy

### Unit Tests

1. **LLM Provider Tests** (`slack_bot/tests/test_llm_provider.py`):
   - Test `is_credits_error()` with various error types
   - Test fallback behavior with mocked API responses
   - Test retry logic (non-402 errors retry once)

2. **Thread Context Tests** (`slack_bot/tests/test_thread_context.py`):
   - Test context creation and retrieval
   - Test message addition and persistence
   - Test cleanup of old contexts

3. **Message Handler Tests** (`slack_bot/tests/test_message_handler.py`):
   - Test tool call parsing
   - Test SQL result formatting

### Integration Tests

1. **End-to-End Flow**:
   - Send @mention → receive response
   - Send follow-up in thread → receive contextual response
   - Trigger 402 error → verify fallback

2. **SQL Execution**:
   - Natural language → SQL generation → execution → formatted result

### Manual Testing Steps

1. Start bot: `docker-compose up slack-bot`
2. Invite bot to test channel
3. Test cases:
   - `@bot what tables have user data?`
   - Follow-up: `show me the columns in the users table`
   - `@bot how many merchants signed up last week?` (SQL execution)
   - Verify thread context persists after bot restart

## Performance Considerations

1. **Response Time**:
   - Acknowledge within 3 seconds (guaranteed by `asyncio.create_task`)
   - LLM calls may take 5-30 seconds (update message to show progress)

2. **Memory**:
   - Thread contexts stored in SQLite (not memory)
   - Cleanup task removes contexts older than 24 hours

3. **Concurrency**:
   - AsyncApp handles multiple events concurrently
   - Each message processed in separate async task

## Migration Notes

N/A - This is a new service, no migration needed.

## References

- Initial Research: `thoughts/shared/research/2025-12-14-slack-bot-mcp-integration.md`
- Architecture Research: `thoughts/shared/research/2025-12-16-company-mcp-master-branch-architecture.md`
- TribalAgent fallback logic: `TribalAgent/src/utils/llm.ts:707-939`
- Company-MCP master branch MCP client: `Company-MCP/frontend/main.py:541-619`
- Company-MCP agentic loop: `Company-MCP/frontend/main.py:698-918`
- Slack Bolt Python docs: https://slack.dev/bolt-python/
