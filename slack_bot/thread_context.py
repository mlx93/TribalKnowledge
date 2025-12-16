"""
Thread Context Storage

SQLite-backed conversation persistence per Slack thread.

Features:
- Store conversation history per thread
- Thread key format: {channel_id}:{thread_ts}
- Persist across bot restarts
- Auto-cleanup of old contexts (configurable TTL)
"""

import os
import json
import logging
import asyncio
from datetime import datetime, timedelta
from dataclasses import dataclass, field, asdict
from typing import Optional, List, Dict, Any
from pathlib import Path

import aiosqlite

logger = logging.getLogger(__name__)

# Default database path
DEFAULT_DB_PATH = os.getenv("THREAD_CONTEXT_DB", "./data/thread_contexts.db")

# Default context TTL (24 hours)
DEFAULT_CONTEXT_TTL_SECONDS = 24 * 60 * 60


@dataclass
class Message:
    """A single message in a conversation."""
    role: str  # "user", "assistant", "system", "tool"
    content: str
    timestamp: str = ""
    user_id: Optional[str] = None
    tool_calls: Optional[List[Dict[str, Any]]] = None
    tool_call_id: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for storage."""
        d = {
            "role": self.role,
            "content": self.content,
            "timestamp": self.timestamp,
        }
        if self.user_id:
            d["user_id"] = self.user_id
        if self.tool_calls:
            d["tool_calls"] = self.tool_calls
        if self.tool_call_id:
            d["tool_call_id"] = self.tool_call_id
        return d
    
    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "Message":
        """Create from dictionary."""
        return cls(
            role=d.get("role", "user"),
            content=d.get("content", ""),
            timestamp=d.get("timestamp", ""),
            user_id=d.get("user_id"),
            tool_calls=d.get("tool_calls"),
            tool_call_id=d.get("tool_call_id"),
        )


@dataclass
class ThreadContext:
    """Conversation context for a Slack thread."""
    
    channel_id: str
    thread_ts: str
    user_id: str
    messages: List[Message] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)
    created_at: str = ""
    updated_at: str = ""
    
    @property
    def thread_key(self) -> str:
        """Unique key for this thread."""
        return f"{self.channel_id}:{self.thread_ts}"
    
    def add_user_message(self, content: str, user_id: Optional[str] = None) -> Message:
        """Add a user message to the context."""
        msg = Message(
            role="user",
            content=content,
            timestamp=datetime.utcnow().isoformat(),
            user_id=user_id or self.user_id,
        )
        self.messages.append(msg)
        self.updated_at = datetime.utcnow().isoformat()
        return msg
    
    def add_assistant_message(
        self,
        content: Optional[str] = None,
        tool_calls: Optional[List[Dict[str, Any]]] = None,
    ) -> Message:
        """Add an assistant message to the context."""
        msg = Message(
            role="assistant",
            content=content or "",
            timestamp=datetime.utcnow().isoformat(),
            tool_calls=tool_calls,
        )
        self.messages.append(msg)
        self.updated_at = datetime.utcnow().isoformat()
        return msg
    
    def add_tool_result(self, tool_call_id: str, content: str) -> Message:
        """Add a tool result message to the context."""
        msg = Message(
            role="tool",
            content=content,
            timestamp=datetime.utcnow().isoformat(),
            tool_call_id=tool_call_id,
        )
        self.messages.append(msg)
        self.updated_at = datetime.utcnow().isoformat()
        return msg
    
    def get_messages_for_llm(self, max_messages: int = 20) -> List[Dict[str, Any]]:
        """
        Get messages formatted for LLM API.
        Returns the most recent messages up to max_messages.
        """
        # Take the most recent messages
        recent = self.messages[-max_messages:] if len(self.messages) > max_messages else self.messages
        
        llm_messages = []
        for msg in recent:
            m = {"role": msg.role, "content": msg.content}
            if msg.tool_calls:
                m["tool_calls"] = msg.tool_calls
            if msg.tool_call_id:
                m["tool_call_id"] = msg.tool_call_id
            llm_messages.append(m)
        
        return llm_messages


class ThreadContextStore:
    """
    SQLite-backed storage for thread contexts.
    
    Usage:
        store = ThreadContextStore()
        await store.initialize()
        
        context = await store.get_or_create(channel_id, thread_ts, user_id)
        context.add_user_message("Hello!")
        await store.save(context)
    """
    
    def __init__(self, db_path: Optional[str] = None):
        self.db_path = db_path or DEFAULT_DB_PATH
        self._db: Optional[aiosqlite.Connection] = None
        self._lock = asyncio.Lock()
    
    async def initialize(self):
        """Initialize the database and create tables if needed."""
        # Ensure directory exists
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        
        self._db = await aiosqlite.connect(self.db_path)
        
        await self._db.execute("""
            CREATE TABLE IF NOT EXISTS thread_contexts (
                thread_key TEXT PRIMARY KEY,
                channel_id TEXT NOT NULL,
                thread_ts TEXT NOT NULL,
                user_id TEXT NOT NULL,
                messages TEXT NOT NULL,
                metadata TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)
        
        # Index for cleanup queries
        await self._db.execute("""
            CREATE INDEX IF NOT EXISTS idx_updated_at 
            ON thread_contexts(updated_at)
        """)
        
        await self._db.commit()
        logger.info(f"Thread context store initialized at {self.db_path}")
    
    async def close(self):
        """Close the database connection."""
        if self._db:
            await self._db.close()
            self._db = None
    
    async def get_or_create(
        self,
        channel_id: str,
        thread_ts: str,
        user_id: str,
    ) -> ThreadContext:
        """
        Get existing context or create a new one.
        
        Args:
            channel_id: Slack channel ID
            thread_ts: Thread timestamp (unique per thread)
            user_id: User who started the conversation
        
        Returns:
            ThreadContext for the thread
        """
        thread_key = f"{channel_id}:{thread_ts}"
        
        async with self._lock:
            cursor = await self._db.execute(
                "SELECT * FROM thread_contexts WHERE thread_key = ?",
                (thread_key,)
            )
            row = await cursor.fetchone()
            
            if row:
                # Parse existing context
                return ThreadContext(
                    channel_id=row[1],
                    thread_ts=row[2],
                    user_id=row[3],
                    messages=[Message.from_dict(m) for m in json.loads(row[4])],
                    metadata=json.loads(row[5]),
                    created_at=row[6],
                    updated_at=row[7],
                )
            
            # Create new context
            now = datetime.utcnow().isoformat()
            context = ThreadContext(
                channel_id=channel_id,
                thread_ts=thread_ts,
                user_id=user_id,
                messages=[],
                metadata={},
                created_at=now,
                updated_at=now,
            )
            
            # Insert into database
            await self._db.execute(
                """INSERT INTO thread_contexts 
                   (thread_key, channel_id, thread_ts, user_id, messages, metadata, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    thread_key,
                    context.channel_id,
                    context.thread_ts,
                    context.user_id,
                    json.dumps([]),
                    json.dumps({}),
                    context.created_at,
                    context.updated_at,
                )
            )
            await self._db.commit()
            
            logger.debug(f"Created new thread context: {thread_key}")
            return context
    
    async def get(self, channel_id: str, thread_ts: str) -> Optional[ThreadContext]:
        """
        Get existing context or None.
        
        Args:
            channel_id: Slack channel ID
            thread_ts: Thread timestamp
        
        Returns:
            ThreadContext if exists, None otherwise
        """
        thread_key = f"{channel_id}:{thread_ts}"
        
        cursor = await self._db.execute(
            "SELECT * FROM thread_contexts WHERE thread_key = ?",
            (thread_key,)
        )
        row = await cursor.fetchone()
        
        if row:
            return ThreadContext(
                channel_id=row[1],
                thread_ts=row[2],
                user_id=row[3],
                messages=[Message.from_dict(m) for m in json.loads(row[4])],
                metadata=json.loads(row[5]),
                created_at=row[6],
                updated_at=row[7],
            )
        return None
    
    async def save(self, context: ThreadContext):
        """
        Save or update a thread context.
        
        Args:
            context: ThreadContext to save
        """
        context.updated_at = datetime.utcnow().isoformat()
        
        async with self._lock:
            await self._db.execute(
                """UPDATE thread_contexts 
                   SET messages = ?, metadata = ?, updated_at = ?
                   WHERE thread_key = ?""",
                (
                    json.dumps([m.to_dict() for m in context.messages]),
                    json.dumps(context.metadata),
                    context.updated_at,
                    context.thread_key,
                )
            )
            await self._db.commit()
        
        logger.debug(f"Saved context: {context.thread_key} ({len(context.messages)} messages)")
    
    async def delete(self, channel_id: str, thread_ts: str):
        """
        Delete a thread context.
        
        Args:
            channel_id: Slack channel ID
            thread_ts: Thread timestamp
        """
        thread_key = f"{channel_id}:{thread_ts}"
        
        async with self._lock:
            await self._db.execute(
                "DELETE FROM thread_contexts WHERE thread_key = ?",
                (thread_key,)
            )
            await self._db.commit()
        
        logger.debug(f"Deleted context: {thread_key}")
    
    async def cleanup_old_contexts(
        self,
        max_age_seconds: int = DEFAULT_CONTEXT_TTL_SECONDS,
    ) -> int:
        """
        Remove contexts older than max_age_seconds.
        
        Args:
            max_age_seconds: Maximum age in seconds (default: 24 hours)
        
        Returns:
            Number of contexts deleted
        """
        cutoff = (datetime.utcnow() - timedelta(seconds=max_age_seconds)).isoformat()
        
        async with self._lock:
            cursor = await self._db.execute(
                "DELETE FROM thread_contexts WHERE updated_at < ?",
                (cutoff,)
            )
            await self._db.commit()
            deleted = cursor.rowcount
        
        if deleted > 0:
            logger.info(f"Cleaned up {deleted} old thread contexts")
        return deleted
    
    async def get_stats(self) -> Dict[str, Any]:
        """Get store statistics."""
        cursor = await self._db.execute("SELECT COUNT(*) FROM thread_contexts")
        count = (await cursor.fetchone())[0]
        
        cursor = await self._db.execute(
            "SELECT MAX(updated_at), MIN(updated_at) FROM thread_contexts"
        )
        row = await cursor.fetchone()
        
        return {
            "total_contexts": count,
            "newest_update": row[0],
            "oldest_update": row[1],
            "db_path": self.db_path,
        }


# =============================================================================
# Background Cleanup Task
# =============================================================================

async def run_cleanup_task(
    store: ThreadContextStore,
    interval_seconds: int = 3600,  # Run every hour
    max_age_seconds: int = DEFAULT_CONTEXT_TTL_SECONDS,
):
    """
    Background task to periodically clean up old contexts.
    
    Args:
        store: ThreadContextStore instance
        interval_seconds: How often to run cleanup (default: 1 hour)
        max_age_seconds: Max context age (default: 24 hours)
    """
    while True:
        try:
            await asyncio.sleep(interval_seconds)
            deleted = await store.cleanup_old_contexts(max_age_seconds)
            logger.debug(f"Cleanup task: removed {deleted} old contexts")
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"Cleanup task error: {e}")

