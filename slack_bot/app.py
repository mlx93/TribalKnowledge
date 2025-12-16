"""
Tribal Knowledge Slack Bot

Main Slack Bolt AsyncApp with event handlers for database queries via MCP.

Features:
- @mention handling with "thinking" indicators
- Thread follow-up messages (no re-mention needed)
- MCP tool integration for schema queries and SQL execution
- LLM fallback from Claude to GPT-4o
- Thread context persistence via SQLite
- App Home tab with usage instructions

Usage:
    python -m slack_bot.app
    
    # Or with uvicorn for production:
    uvicorn slack_bot.app:api --host 0.0.0.0 --port 3000
"""

import os
import re
import asyncio
import logging
from typing import Optional

from dotenv import load_dotenv
from slack_bolt.async_app import AsyncApp
from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler
from slack_sdk.web.async_client import AsyncWebClient

from .llm_provider import LLMProvider, get_fallback_status
from .thread_context import ThreadContextStore, run_cleanup_task
from .mcp_client import MCPClient, test_mcp_connectivity
from .cache_store import QueryCacheStore, run_cache_cleanup_task, CACHE_AUTO_SAVE
from .message_handler import (
    process_message,
    format_response_for_slack,
    truncate_for_slack,
    ProcessingResult,
)

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO")),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# =============================================================================
# Configuration
# =============================================================================

SLACK_BOT_TOKEN = os.getenv("SLACK_BOT_TOKEN")
SLACK_APP_TOKEN = os.getenv("SLACK_APP_TOKEN")
SLACK_SIGNING_SECRET = os.getenv("SLACK_SIGNING_SECRET")

if not all([SLACK_BOT_TOKEN, SLACK_APP_TOKEN]):
    logger.error("Missing Slack tokens. Set SLACK_BOT_TOKEN and SLACK_APP_TOKEN.")

# =============================================================================
# Initialize App
# =============================================================================

app = AsyncApp(
    token=SLACK_BOT_TOKEN,
    signing_secret=SLACK_SIGNING_SECRET,
)

# Global instances (initialized in startup)
context_store: Optional[ThreadContextStore] = None
cache_store: Optional[QueryCacheStore] = None
cleanup_task: Optional[asyncio.Task] = None
cache_cleanup_task: Optional[asyncio.Task] = None

# Message-to-question mapping for reaction-based cache control
# Key: "{channel}:{message_ts}", Value: {"question": str, "result": ProcessingResult}
# This is kept in memory and cleared after 24 hours
message_question_map: dict[str, dict] = {}


# =============================================================================
# Startup / Shutdown
# =============================================================================

async def startup():
    """Initialize services on startup."""
    global context_store, cache_store, cleanup_task, cache_cleanup_task
    
    logger.info("Starting Tribal Knowledge Slack Bot...")
    
    # Initialize thread context store
    context_store = ThreadContextStore()
    await context_store.initialize()
    
    # Initialize query cache store (shares same DB connection)
    cache_store = QueryCacheStore()
    await cache_store.initialize()
    
    # Start background cleanup tasks
    cleanup_task = asyncio.create_task(run_cleanup_task(context_store))
    cache_cleanup_task = asyncio.create_task(run_cache_cleanup_task(cache_store))
    
    # Log configuration
    fallback_status = get_fallback_status()
    logger.info(f"LLM Config: primary={fallback_status['primary_model']}, "
                f"fallback={fallback_status['fallback_model']}, "
                f"fallback_enabled={fallback_status['fallback_enabled']}")
    
    # Log cache status
    cache_stats = await cache_store.get_stats()
    logger.info(f"Cache: enabled={cache_stats['enabled']}, "
                f"entries={cache_stats['total_entries']}, "
                f"hits={cache_stats['total_hits']}")
    
    # Test MCP connectivity
    try:
        mcp_status = await test_mcp_connectivity()
        logger.info(f"MCP Status: {mcp_status['total_tools']} tools from "
                    f"{len(mcp_status.get('tools_by_server', {}))} servers")
    except Exception as e:
        logger.warning(f"MCP connectivity check failed: {e}")
    
    logger.info("Slack Bot started successfully!")


async def shutdown():
    """Cleanup on shutdown."""
    global context_store, cache_store, cleanup_task, cache_cleanup_task
    
    logger.info("Shutting down Slack Bot...")
    
    # Cancel cleanup tasks
    if cleanup_task:
        cleanup_task.cancel()
        try:
            await cleanup_task
        except asyncio.CancelledError:
            pass
    
    if cache_cleanup_task:
        cache_cleanup_task.cancel()
        try:
            await cache_cleanup_task
        except asyncio.CancelledError:
            pass
    
    # Close stores
    if cache_store:
        await cache_store.close()
    
    if context_store:
        await context_store.close()
    
    logger.info("Slack Bot shutdown complete.")


# =============================================================================
# Helper Functions
# =============================================================================

def extract_message_text(text: str, bot_user_id: str) -> str:
    """
    Extract message text, removing the bot mention.
    
    Args:
        text: Raw message text (may include <@BOT_ID>)
        bot_user_id: Bot's user ID
    
    Returns:
        Clean message text
    """
    # Remove bot mention pattern: <@U123ABC>
    pattern = rf"<@{bot_user_id}>\s*"
    return re.sub(pattern, "", text).strip()


async def send_thinking_message(
    client: AsyncWebClient,
    channel: str,
    thread_ts: str,
) -> str:
    """
    Post a "thinking" message and return its timestamp.
    
    Returns:
        Message timestamp for later updates
    """
    result = await client.chat_postMessage(
        channel=channel,
        thread_ts=thread_ts,
        text="🤔 Thinking...",
    )
    return result["ts"]


async def update_message(
    client: AsyncWebClient,
    channel: str,
    ts: str,
    text: str,
    blocks: Optional[list] = None,
):
    """Update an existing message."""
    kwargs = {
        "channel": channel,
        "ts": ts,
        "text": text,  # Fallback text for notifications
    }
    if blocks:
        kwargs["blocks"] = blocks
    await client.chat_update(**kwargs)


# =============================================================================
# Event Handlers
# =============================================================================

@app.event("app_mention")
async def handle_mention(event: dict, client: AsyncWebClient, context: dict):
    """
    Handle @mentions of the bot.
    
    This is the primary entry point for starting a conversation.
    """
    channel = event["channel"]
    user = event["user"]
    text = event.get("text", "")
    
    # Determine thread_ts (use event ts if not in a thread)
    thread_ts = event.get("thread_ts") or event["ts"]
    
    # Get bot user ID from context
    bot_user_id = context.get("bot_user_id", "")
    
    # Extract the actual message (remove mention)
    user_message = extract_message_text(text, bot_user_id)
    
    if not user_message:
        await client.chat_postMessage(
            channel=channel,
            thread_ts=thread_ts,
            text="Hi! Ask me anything about your database. For example:\n"
                 "• `@bot what tables have user data?`\n"
                 "• `@bot show me the schema for merchants`\n"
                 "• `@bot how many transactions happened last week?`",
        )
        return
    
    # Process in background to avoid Slack timeout
    asyncio.create_task(
        _process_and_respond(client, channel, thread_ts, user, user_message)
    )


@app.event("message")
async def handle_message(event: dict, client: AsyncWebClient, context: dict):
    """
    Handle messages in channels.
    
    We only respond to thread messages where we have existing context
    (i.e., the user already @mentioned us in this thread).
    """
    # Ignore bot messages
    if event.get("bot_id"):
        return
    
    # Ignore messages that aren't in a thread
    thread_ts = event.get("thread_ts")
    if not thread_ts:
        return
    
    channel = event["channel"]
    user = event["user"]
    text = event.get("text", "")
    
    # Check if we have context for this thread (means we were mentioned before)
    if context_store:
        existing_context = await context_store.get(channel, thread_ts)
        if not existing_context:
            # We weren't mentioned in this thread, ignore
            return
    else:
        return
    
    # Remove any accidental mentions
    bot_user_id = context.get("bot_user_id", "")
    user_message = extract_message_text(text, bot_user_id)
    
    if not user_message:
        return
    
    # Ignore emoji-only messages (like 📦 or 🔄 sent as text instead of reactions)
    stripped = user_message.strip()
    if len(stripped) <= 4 and not stripped.isalnum():
        # Likely just an emoji, ignore it
        logger.debug(f"Ignoring emoji-only message: {stripped}")
        return
    
    # Process the follow-up message
    asyncio.create_task(
        _process_and_respond(client, channel, thread_ts, user, user_message)
    )


async def _process_and_respond(
    client: AsyncWebClient,
    channel: str,
    thread_ts: str,
    user_id: str,
    user_message: str,
):
    """
    Process a message and respond in the thread.
    
    This runs as a background task to avoid Slack's 3-second acknowledgement timeout.
    """
    thinking_ts = None
    
    try:
        # Post "thinking" indicator
        thinking_ts = await send_thinking_message(client, channel, thread_ts)
        
        # Get or create thread context
        thread_context = await context_store.get_or_create(channel, thread_ts, user_id)
        
        # Create progress callback to update the thinking message
        async def on_progress(progress_text: str):
            """Update the thinking message with progress."""
            try:
                await update_message(client, channel, thinking_ts, progress_text)
            except Exception as e:
                logger.warning(f"Failed to update progress: {e}")
        
        # Process with MCP client and LLM
        async with MCPClient() as mcp_client:
            llm_provider = LLMProvider()
            
            try:
                result = await process_message(
                    user_message=user_message,
                    context=thread_context,
                    mcp_client=mcp_client,
                    llm_provider=llm_provider,
                    on_progress=on_progress,
                    cache_store=cache_store,  # Pass cache store for caching
                )
            finally:
                await llm_provider.close()
        
        # Save updated context
        await context_store.save(thread_context)
        
        # If from cache, replay progress events to simulate real execution
        if result.from_cache and result.progress_events:
            # Replay all progress events with realistic timing
            for i, event in enumerate(result.progress_events):
                await update_message(client, channel, thinking_ts, event)
                # Vary timing: faster for early events, slower for later ones
                delay = 0.2 + (i * 0.1)  # 0.2s, 0.3s, 0.4s, etc.
                delay = min(delay, 0.6)  # Cap at 0.6s
                await asyncio.sleep(delay)
        
        # Format response for Slack with blocks (show tool usage summary)
        fallback_text, blocks = format_response_for_slack(result, show_metadata=True)
        
        # Update the thinking message with the response using blocks
        await update_message(client, channel, thinking_ts, fallback_text, blocks=blocks)
        
        # Store message-question mapping for reaction-based cache control
        message_key = f"{channel}:{thinking_ts}"
        message_question_map[message_key] = {
            "question": user_message,
            "result": result,
            "thread_ts": thread_ts,
        }
        logger.debug(f"Stored message mapping: {message_key} -> '{user_message[:50]}...'")
        
        # Log success
        cache_info = f"from_cache={result.from_cache}" if result.from_cache else f"iterations={result.iterations}"
        logger.info(
            f"Processed message in {channel}/{thread_ts}: "
            f"{len(result.tools_used)} tools, "
            f"{cache_info}, "
            f"fallback={result.used_fallback}"
        )
    
    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)
        
        error_text = (
            f"Sorry, I encountered an error: {str(e)}\n\n"
            "Please try again or rephrase your question."
        )
        
        if thinking_ts:
            await update_message(client, channel, thinking_ts, error_text)
        else:
            await client.chat_postMessage(
                channel=channel,
                thread_ts=thread_ts,
                text=error_text,
            )


@app.event("app_home_opened")
async def handle_app_home(event: dict, client: AsyncWebClient):
    """
    Handle App Home tab opened.
    
    Shows usage instructions and current status.
    """
    user_id = event["user"]
    
    # Get current status
    fallback_status = get_fallback_status()
    
    try:
        mcp_status = await test_mcp_connectivity()
        mcp_info = f"✅ Connected to {mcp_status['total_tools']} tools"
    except Exception as e:
        mcp_info = f"⚠️ MCP connection issue: {e}"
    
    if context_store:
        store_stats = await context_store.get_stats()
        context_info = f"📊 {store_stats['total_contexts']} active conversations"
    else:
        context_info = "⚠️ Context store not initialized"
    
    # Get cache stats
    if cache_store:
        cache_stats = await cache_store.get_stats()
        cache_status = "enabled" if cache_stats['enabled'] else "disabled"
        cache_info = (
            f"📦 Cache: {cache_stats['total_entries']} entries, "
            f"{cache_stats['total_hits']} hits ({cache_status})"
        )
    else:
        cache_info = "⚠️ Cache not initialized"
    
    # Build App Home view
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "🗃️ Tribal Knowledge Bot",
                "emoji": True,
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": (
                    "I help you explore and query your database! "
                    "Mention me in any channel to get started."
                ),
            }
        },
        {"type": "divider"},
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*How to Use*\n\n"
                        "1. `@TribalKnowledge what tables have customer data?`\n"
                        "2. `@TribalKnowledge show me the merchants schema`\n"
                        "3. `@TribalKnowledge how many orders were placed yesterday?`\n"
                        "4. Follow up in the thread without re-mentioning me!",
            }
        },
        {"type": "divider"},
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": (
                    "*Current Status*\n\n"
                    f"• {mcp_info}\n"
                    f"• 🤖 LLM: {fallback_status['primary_model']}\n"
                    f"• 🔄 Fallback: {fallback_status['fallback_model']} "
                    f"({'enabled' if fallback_status['fallback_enabled'] else 'disabled'})\n"
                    f"• {context_info}\n"
                    f"• {cache_info}"
                ),
            }
        },
        {"type": "divider"},
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": "Powered by *Company-MCP* | synth-mcp for schema | postgres-mcp for SQL",
                }
            ]
        },
    ]
    
    await client.views_publish(
        user_id=user_id,
        view={
            "type": "home",
            "blocks": blocks,
        }
    )


# =============================================================================
# Reaction Handlers for Cache Control
# =============================================================================

@app.event("reaction_added")
async def handle_reaction_added(event: dict, client: AsyncWebClient):
    """
    Handle emoji reactions for cache control.
    
    📦 (package) - Save this response to cache (for manual cache mode)
    🔄 (arrows_counterclockwise) - Clear from cache and re-run fresh
    """
    reaction = event.get("reaction", "")
    channel = event["item"]["channel"]
    message_ts = event["item"]["ts"]
    user = event["user"]
    
    logger.info(f"Reaction received: {reaction} on {channel}:{message_ts} by {user}")
    
    message_key = f"{channel}:{message_ts}"
    
    # Check if this message is one of our responses
    if message_key not in message_question_map:
        logger.debug(f"Message {message_key} not in message_question_map (have {len(message_question_map)} entries)")
        return
    
    msg_data = message_question_map[message_key]
    question = msg_data["question"]
    result = msg_data["result"]
    thread_ts = msg_data["thread_ts"]
    
    # 📦 Package emoji - Save to cache (for manual cache mode)
    if reaction == "package" and cache_store:
        if result.from_cache:
            # Already cached - confirm with different emoji
            logger.info(f"📦 reaction on already-cached response: '{question[:50]}...'")
            await client.reactions_add(
                channel=channel,
                timestamp=message_ts,
                name="ballot_box_with_check",  # ☑️ already cached
            )
        elif result.tools_used:
            # Save new response to cache
            cache_id = await cache_store.save(
                question=question,
                response_text=result.response_text,
                tools_used=result.tools_used,
                sql_queries=result.sql_queries,
                progress_events=result.progress_events,
            )
            if cache_id > 0:
                logger.info(f"Manual cache save via 📦 reaction: '{question[:50]}...'")
                # React to confirm (requires reactions:write scope)
                await client.reactions_add(
                    channel=channel,
                    timestamp=message_ts,
                    name="white_check_mark",  # ✅ saved
                )
    
    # 🔄 Refresh emoji - Clear cache and re-run
    elif reaction == "arrows_counterclockwise" and cache_store:
        # Delete from cache
        deleted = await cache_store.delete_by_question(question)
        
        if deleted or result.from_cache:
            logger.info(f"Cache cleared via 🔄 reaction: '{question[:50]}...'")
            
            # Post a message that we're re-running
            await client.chat_postMessage(
                channel=channel,
                thread_ts=thread_ts,
                text="🔄 *Cache cleared* — running fresh query...",
            )
            
            # Re-run the query
            asyncio.create_task(
                _process_and_respond(client, channel, thread_ts, user, question)
            )
        else:
            # Not in cache, just acknowledge
            await client.reactions_add(
                channel=channel,
                timestamp=message_ts,
                name="x",  # ❌ to indicate nothing to clear
            )


# =============================================================================
# Main Entry Point
# =============================================================================

async def main():
    """Main entry point for running the bot."""
    await startup()
    
    try:
        handler = AsyncSocketModeHandler(app, SLACK_APP_TOKEN)
        logger.info("Starting Socket Mode handler...")
        await handler.start_async()
    except KeyboardInterrupt:
        logger.info("Received shutdown signal")
    finally:
        await shutdown()


if __name__ == "__main__":
    asyncio.run(main())

