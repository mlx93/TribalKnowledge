"""
Query Cache Storage

SQLite-backed caching for repeated questions in Slack.

Features:
- Multi-tier matching: hash → exact → fuzzy
- Caches: response text, tools used, SQL queries, progress events
- TTL-based cleanup
- Hit count tracking
"""

import os
import json
import hashlib
import logging
import asyncio
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any
from pathlib import Path

import aiosqlite

logger = logging.getLogger(__name__)

# Configuration
CACHE_ENABLED = os.getenv("CACHE_ENABLED", "true").lower() == "true"
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", str(86400 * 7)))  # 7 days
CACHE_FUZZY_THRESHOLD = float(os.getenv("CACHE_FUZZY_THRESHOLD", "0.99"))  # 99% = essentially exact match
# Auto-cache mode: if False (default), only cache when user explicitly approves (📦 reaction)
CACHE_AUTO_SAVE = os.getenv("CACHE_AUTO_SAVE", "false").lower() == "true"

# Default database path (same as thread contexts)
DEFAULT_DB_PATH = os.getenv("THREAD_CONTEXT_DB", "./data/thread_contexts.db")


@dataclass
class CachedResponse:
    """A cached response to a user question."""
    id: int
    question_text: str
    question_normalized: str
    question_hash: str
    
    # Response data
    response_text: str
    tools_used: List[Dict[str, Any]]
    sql_queries: List[str]
    progress_events: List[str]  # Progress messages for replay
    
    # Metadata
    hit_count: int
    created_at: str
    last_hit_at: Optional[str]
    
    @property
    def is_expired(self) -> bool:
        """Check if this cache entry has expired."""
        created = datetime.fromisoformat(self.created_at)
        return datetime.utcnow() - created > timedelta(seconds=CACHE_TTL_SECONDS)


def normalize_question(question: str) -> str:
    """
    Normalize a question for matching.
    
    - Lowercase
    - Strip whitespace
    - Remove extra spaces
    """
    return " ".join(question.lower().strip().split())


def hash_question(normalized: str) -> str:
    """Create a hash of the normalized question."""
    return hashlib.md5(normalized.encode()).hexdigest()


def fuzzy_match_score(q1: str, q2: str) -> float:
    """
    Calculate fuzzy match score between two normalized questions.
    
    Uses word overlap ratio (Jaccard-like similarity).
    
    Returns:
        Score between 0.0 and 1.0
    """
    if not q1 or not q2:
        return 0.0
    
    # For very short questions, require exact match
    if len(q1) < 15 or len(q2) < 15:
        return 1.0 if q1 == q2 else 0.0
    
    words1 = set(q1.split())
    words2 = set(q2.split())
    
    if not words1 or not words2:
        return 0.0
    
    overlap = len(words1 & words2)
    max_len = max(len(words1), len(words2))
    
    return overlap / max_len if max_len > 0 else 0.0


class QueryCacheStore:
    """
    SQLite-backed query cache.
    
    Usage:
        cache = QueryCacheStore()
        await cache.initialize()
        
        # Check for cached response
        cached = await cache.find_match("what tables have sales data?")
        if cached:
            return cached.response_text
        
        # Save new response
        await cache.save(
            question="what tables have sales data?",
            response_text="Here are the sales tables...",
            tools_used=[...],
            sql_queries=[...],
        )
    """
    
    def __init__(self, db_path: Optional[str] = None):
        self.db_path = db_path or DEFAULT_DB_PATH
        self._db: Optional[aiosqlite.Connection] = None
        self._lock = asyncio.Lock()
        self._enabled = CACHE_ENABLED
    
    @property
    def enabled(self) -> bool:
        """Check if caching is enabled."""
        return self._enabled
    
    def set_enabled(self, enabled: bool):
        """Enable or disable caching."""
        self._enabled = enabled
        logger.info(f"Query cache {'enabled' if enabled else 'disabled'}")
    
    async def initialize(self, db: Optional[aiosqlite.Connection] = None):
        """
        Initialize the cache table.
        
        Args:
            db: Optional existing database connection to reuse
        """
        if db:
            self._db = db
        else:
            Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
            self._db = await aiosqlite.connect(self.db_path)
        
        await self._db.execute("""
            CREATE TABLE IF NOT EXISTS query_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                question_hash TEXT NOT NULL,
                question_text TEXT NOT NULL,
                question_normalized TEXT NOT NULL,
                
                response_text TEXT NOT NULL,
                tools_used TEXT NOT NULL,
                sql_queries TEXT NOT NULL,
                progress_events TEXT NOT NULL,
                
                hit_count INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                last_hit_at TEXT,
                
                UNIQUE(question_hash)
            )
        """)
        
        # Indexes for fast lookup
        await self._db.execute("""
            CREATE INDEX IF NOT EXISTS idx_cache_hash 
            ON query_cache(question_hash)
        """)
        await self._db.execute("""
            CREATE INDEX IF NOT EXISTS idx_cache_normalized 
            ON query_cache(question_normalized)
        """)
        await self._db.execute("""
            CREATE INDEX IF NOT EXISTS idx_cache_created 
            ON query_cache(created_at)
        """)
        
        await self._db.commit()
        logger.info(f"Query cache initialized (enabled={self._enabled})")
    
    async def close(self):
        """Close the database connection."""
        if self._db:
            await self._db.close()
            self._db = None
    
    async def find_match(self, question: str) -> Optional[CachedResponse]:
        """
        Find a cached response matching the question.
        
        Uses multi-tier matching:
        1. Exact hash match (fastest)
        2. Exact normalized text match
        3. Fuzzy match (80%+ word overlap)
        
        Args:
            question: User's question text
        
        Returns:
            CachedResponse if found, None otherwise
        """
        if not self._enabled:
            return None
        
        normalized = normalize_question(question)
        question_hash = hash_question(normalized)
        
        # Tier 1: Hash match (fastest)
        cached = await self._find_by_hash(question_hash)
        if cached and not cached.is_expired:
            await self._record_hit(cached.id)
            logger.info(f"Cache HIT (hash): '{question[:50]}...' -> id={cached.id}")
            return cached
        
        # Tier 2: Exact normalized match (handles hash collisions)
        cached = await self._find_by_normalized(normalized)
        if cached and not cached.is_expired:
            await self._record_hit(cached.id)
            logger.info(f"Cache HIT (exact): '{question[:50]}...' -> id={cached.id}")
            return cached
        
        # Tier 3: Fuzzy match (for similar questions)
        cached = await self._find_fuzzy(normalized)
        if cached and not cached.is_expired:
            await self._record_hit(cached.id)
            logger.info(f"Cache HIT (fuzzy): '{question[:50]}...' -> id={cached.id}")
            return cached
        
        logger.debug(f"Cache MISS: '{question[:50]}...'")
        return None
    
    async def _find_by_hash(self, question_hash: str) -> Optional[CachedResponse]:
        """Find by exact hash match."""
        cursor = await self._db.execute(
            "SELECT * FROM query_cache WHERE question_hash = ?",
            (question_hash,)
        )
        row = await cursor.fetchone()
        return self._row_to_cached(row) if row else None
    
    async def _find_by_normalized(self, normalized: str) -> Optional[CachedResponse]:
        """Find by exact normalized text match."""
        cursor = await self._db.execute(
            "SELECT * FROM query_cache WHERE question_normalized = ?",
            (normalized,)
        )
        row = await cursor.fetchone()
        return self._row_to_cached(row) if row else None
    
    async def _find_fuzzy(self, normalized: str) -> Optional[CachedResponse]:
        """Find by fuzzy matching (expensive, limited to recent entries)."""
        # Only check recent entries to limit cost
        cursor = await self._db.execute(
            """SELECT * FROM query_cache 
               ORDER BY last_hit_at DESC NULLS LAST, created_at DESC 
               LIMIT 100"""
        )
        rows = await cursor.fetchall()
        
        best_match = None
        best_score = CACHE_FUZZY_THRESHOLD
        
        for row in rows:
            cached = self._row_to_cached(row)
            score = fuzzy_match_score(normalized, cached.question_normalized)
            if score > best_score:
                best_score = score
                best_match = cached
        
        return best_match
    
    async def _record_hit(self, cache_id: int):
        """Record a cache hit."""
        async with self._lock:
            await self._db.execute(
                """UPDATE query_cache 
                   SET hit_count = hit_count + 1, last_hit_at = ?
                   WHERE id = ?""",
                (datetime.utcnow().isoformat(), cache_id)
            )
            await self._db.commit()
    
    def _row_to_cached(self, row) -> CachedResponse:
        """Convert a database row to CachedResponse."""
        return CachedResponse(
            id=row[0],
            question_hash=row[1],
            question_text=row[2],
            question_normalized=row[3],
            response_text=row[4],
            tools_used=json.loads(row[5]),
            sql_queries=json.loads(row[6]),
            progress_events=json.loads(row[7]),
            hit_count=row[8],
            created_at=row[9],
            last_hit_at=row[10],
        )
    
    async def save(
        self,
        question: str,
        response_text: str,
        tools_used: List[Dict[str, Any]],
        sql_queries: List[str],
        progress_events: Optional[List[str]] = None,
    ) -> int:
        """
        Save a response to the cache.
        
        Args:
            question: Original user question
            response_text: Final response text
            tools_used: List of tool call info
            sql_queries: List of SQL queries executed
            progress_events: Optional list of progress messages for replay
        
        Returns:
            Cache entry ID
        """
        if not self._enabled:
            return -1
        
        normalized = normalize_question(question)
        question_hash = hash_question(normalized)
        now = datetime.utcnow().isoformat()
        
        async with self._lock:
            try:
                cursor = await self._db.execute(
                    """INSERT INTO query_cache 
                       (question_hash, question_text, question_normalized,
                        response_text, tools_used, sql_queries, progress_events,
                        hit_count, created_at, last_hit_at)
                       VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, NULL)""",
                    (
                        question_hash,
                        question,
                        normalized,
                        response_text,
                        json.dumps(tools_used),
                        json.dumps(sql_queries),
                        json.dumps(progress_events or []),
                        now,
                    )
                )
                await self._db.commit()
                cache_id = cursor.lastrowid
                logger.info(f"Cached response: '{question[:50]}...' -> id={cache_id}")
                return cache_id
            except aiosqlite.IntegrityError:
                # Hash collision - update existing entry
                await self._db.execute(
                    """UPDATE query_cache 
                       SET question_text = ?, response_text = ?, 
                           tools_used = ?, sql_queries = ?, progress_events = ?,
                           created_at = ?, hit_count = 0, last_hit_at = NULL
                       WHERE question_hash = ?""",
                    (
                        question,
                        response_text,
                        json.dumps(tools_used),
                        json.dumps(sql_queries),
                        json.dumps(progress_events or []),
                        now,
                        question_hash,
                    )
                )
                await self._db.commit()
                logger.info(f"Updated cached response: '{question[:50]}...'")
                return -1
    
    async def delete(self, cache_id: int):
        """Delete a cache entry by ID."""
        async with self._lock:
            await self._db.execute(
                "DELETE FROM query_cache WHERE id = ?",
                (cache_id,)
            )
            await self._db.commit()
        logger.info(f"Deleted cache entry: id={cache_id}")
    
    async def delete_by_question(self, question: str) -> bool:
        """
        Delete a cache entry by question text.
        
        Args:
            question: The original user question
        
        Returns:
            True if an entry was deleted, False otherwise
        """
        normalized = normalize_question(question)
        question_hash = hash_question(normalized)
        
        async with self._lock:
            cursor = await self._db.execute(
                "DELETE FROM query_cache WHERE question_hash = ?",
                (question_hash,)
            )
            await self._db.commit()
            deleted = cursor.rowcount > 0
        
        if deleted:
            logger.info(f"Deleted cache for question: '{question[:50]}...'")
        return deleted
    
    async def clear(self):
        """Clear all cache entries."""
        async with self._lock:
            cursor = await self._db.execute("DELETE FROM query_cache")
            await self._db.commit()
            deleted = cursor.rowcount
        logger.info(f"Cleared {deleted} cache entries")
        return deleted
    
    async def cleanup_expired(self) -> int:
        """
        Remove expired cache entries.
        
        Returns:
            Number of entries deleted
        """
        cutoff = (datetime.utcnow() - timedelta(seconds=CACHE_TTL_SECONDS)).isoformat()
        
        async with self._lock:
            cursor = await self._db.execute(
                "DELETE FROM query_cache WHERE created_at < ?",
                (cutoff,)
            )
            await self._db.commit()
            deleted = cursor.rowcount
        
        if deleted > 0:
            logger.info(f"Cleaned up {deleted} expired cache entries")
        return deleted
    
    async def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics."""
        cursor = await self._db.execute(
            "SELECT COUNT(*), SUM(hit_count) FROM query_cache"
        )
        row = await cursor.fetchone()
        total_entries = row[0] or 0
        total_hits = row[1] or 0
        
        cursor = await self._db.execute(
            """SELECT question_text, hit_count 
               FROM query_cache 
               ORDER BY hit_count DESC 
               LIMIT 5"""
        )
        top_hits = await cursor.fetchall()
        
        return {
            "enabled": self._enabled,
            "total_entries": total_entries,
            "total_hits": total_hits,
            "ttl_seconds": CACHE_TTL_SECONDS,
            "fuzzy_threshold": CACHE_FUZZY_THRESHOLD,
            "top_hits": [
                {"question": q[:50] + "..." if len(q) > 50 else q, "hits": h}
                for q, h in top_hits
            ],
        }


# =============================================================================
# Background Cleanup Task
# =============================================================================

async def run_cache_cleanup_task(
    cache: QueryCacheStore,
    interval_seconds: int = 3600,  # Run every hour
):
    """
    Background task to periodically clean up expired cache entries.
    
    Args:
        cache: QueryCacheStore instance
        interval_seconds: How often to run cleanup (default: 1 hour)
    """
    while True:
        try:
            await asyncio.sleep(interval_seconds)
            deleted = await cache.cleanup_expired()
            logger.debug(f"Cache cleanup: removed {deleted} expired entries")
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"Cache cleanup error: {e}")

