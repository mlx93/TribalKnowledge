"""
Tribal Knowledge Slack Bot

A Slack bot that integrates with Company-MCP servers via HTTP JSON-RPC
for database schema queries and SQL execution.

Features:
- @mention handling with "thinking" indicators
- MCP tool integration (synth-mcp for schema, postgres-mcp for SQL)
- Thread context persistence per Slack thread
- LLM fallback from Claude (OpenRouter) to GPT-4o (OpenAI)
"""

__version__ = "1.0.0"

