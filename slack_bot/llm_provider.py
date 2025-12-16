"""
LLM Provider with Fallback Logic

Handles LLM calls with automatic fallback from Claude (OpenRouter) to GPT-4o (OpenAI).

Fallback Behavior:
- 402 (credits) errors: Immediate fallback to GPT-4o (no retry)
- Other errors: Retry once, then fallback to GPT-4o
- Controlled via LLM_FALLBACK_ENABLED env var (default: true)
- Fallback model configurable via LLM_FALLBACK_MODEL (default: gpt-4o)

Ported from: TribalAgent/src/utils/llm.ts
"""

import os
import json
import logging
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any, Literal

from openai import AsyncOpenAI

logger = logging.getLogger(__name__)

# =============================================================================
# Configuration
# =============================================================================

DEFAULT_PRIMARY_MODEL = "anthropic/claude-opus-4.5"
DEFAULT_FALLBACK_MODEL = "gpt-4o"


@dataclass
class LLMConfig:
    """LLM configuration from environment variables."""
    
    primary_model: str = field(default_factory=lambda: os.getenv("LLM_PRIMARY_MODEL", DEFAULT_PRIMARY_MODEL))
    fallback_model: str = field(default_factory=lambda: os.getenv("LLM_FALLBACK_MODEL", DEFAULT_FALLBACK_MODEL))
    fallback_enabled: bool = field(default_factory=lambda: os.getenv("LLM_FALLBACK_ENABLED", "true").lower() != "false")
    openrouter_api_key: Optional[str] = field(default_factory=lambda: os.getenv("OPENROUTER_API_KEY"))
    openai_api_key: Optional[str] = field(default_factory=lambda: os.getenv("OPENAI_API_KEY"))
    
    @property
    def fallback_available(self) -> bool:
        """Check if fallback is available (OpenAI API key is set)."""
        return bool(self.openai_api_key)
    
    @property
    def primary_available(self) -> bool:
        """Check if primary (OpenRouter) is available."""
        return bool(self.openrouter_api_key)


def get_config() -> LLMConfig:
    """Get current LLM configuration."""
    return LLMConfig()


# =============================================================================
# Client Factories
# =============================================================================

def get_openrouter_client(api_key: str) -> AsyncOpenAI:
    """Create OpenRouter client (OpenAI-compatible API)."""
    return AsyncOpenAI(
        api_key=api_key,
        base_url="https://openrouter.ai/api/v1",
        default_headers={
            "HTTP-Referer": "https://github.com/tribal-knowledge",
            "X-Title": "Tribal Knowledge Slack Bot",
        }
    )


def get_openai_client(api_key: str) -> AsyncOpenAI:
    """Create OpenAI client."""
    return AsyncOpenAI(api_key=api_key)


# =============================================================================
# Error Classification
# =============================================================================

def is_credits_error(error: Exception) -> bool:
    """
    Check if error is a credits/insufficient funds error (402).
    These should fallback immediately without retry.
    """
    error_str = str(error).lower()
    
    # Check for 402 status code
    if hasattr(error, 'status_code') and error.status_code == 402:
        return True
    if hasattr(error, 'status') and error.status == 402:
        return True
    
    # Check error message
    credit_indicators = ['402', 'credits', 'insufficient', 'can only afford', 'quota exceeded']
    return any(indicator in error_str for indicator in credit_indicators)


def is_retryable_error(error: Exception) -> bool:
    """Check if error is retryable (rate limits, timeouts, server errors)."""
    error_str = str(error).lower()
    
    # Check status codes
    if hasattr(error, 'status_code'):
        status = error.status_code
        # Retry on 429 (rate limit), 5xx (server errors)
        if status == 429 or (500 <= status < 600):
            return True
    
    # Check error message patterns
    retryable_patterns = ['timeout', 'rate limit', '429', '503', '504', 'connection', 'network']
    return any(pattern in error_str for pattern in retryable_patterns)


# =============================================================================
# Response Types
# =============================================================================

@dataclass
class TokenUsage:
    """Token usage information from LLM response."""
    prompt: int = 0
    completion: int = 0
    total: int = 0


@dataclass
class LLMMessage:
    """A message in the conversation."""
    role: Literal["system", "user", "assistant", "tool"]
    content: str
    tool_calls: Optional[List[Dict[str, Any]]] = None
    tool_call_id: Optional[str] = None


@dataclass
class LLMResponse:
    """LLM response with content and metadata."""
    content: Optional[str]
    tool_calls: Optional[List[Dict[str, Any]]]
    tokens: TokenUsage
    used_fallback: bool = False
    actual_model: str = ""
    finish_reason: str = "stop"


# =============================================================================
# Main LLM Caller
# =============================================================================

class LLMProvider:
    """
    LLM Provider with fallback support.
    
    Usage:
        provider = LLMProvider()
        response = await provider.call_with_fallback(
            messages=[{"role": "user", "content": "Hello"}],
            tools=[...],  # Optional
        )
    """
    
    def __init__(self, config: Optional[LLMConfig] = None):
        self.config = config or get_config()
        self._openrouter_client: Optional[AsyncOpenAI] = None
        self._openai_client: Optional[AsyncOpenAI] = None
    
    @property
    def openrouter_client(self) -> AsyncOpenAI:
        """Lazy-load OpenRouter client."""
        if self._openrouter_client is None:
            if not self.config.openrouter_api_key:
                raise ValueError("OPENROUTER_API_KEY not set")
            self._openrouter_client = get_openrouter_client(self.config.openrouter_api_key)
        return self._openrouter_client
    
    @property
    def openai_client(self) -> AsyncOpenAI:
        """Lazy-load OpenAI client."""
        if self._openai_client is None:
            if not self.config.openai_api_key:
                raise ValueError("OPENAI_API_KEY not set")
            self._openai_client = get_openai_client(self.config.openai_api_key)
        return self._openai_client
    
    async def call_with_fallback(
        self,
        messages: List[Dict[str, Any]],
        tools: Optional[List[Dict[str, Any]]] = None,
        max_tokens: int = 4096,
        temperature: float = 0.0,
        max_retries: int = 2,
    ) -> LLMResponse:
        """
        Call LLM with automatic fallback from primary to fallback model.
        
        Args:
            messages: List of message dicts with role and content
            tools: Optional list of tool definitions (OpenAI function calling format)
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            max_retries: Max retry attempts for non-credits errors
        
        Returns:
            LLMResponse with content, tool_calls, and metadata
        """
        last_error: Optional[Exception] = None
        
        # Try primary model (OpenRouter/Claude)
        if self.config.primary_available:
            for attempt in range(1, max_retries + 1):
                try:
                    logger.debug(f"Calling primary LLM ({self.config.primary_model}), attempt {attempt}/{max_retries}")
                    response = await self._call_openrouter(
                        messages=messages,
                        tools=tools,
                        max_tokens=max_tokens,
                        temperature=temperature,
                    )
                    response.used_fallback = False
                    response.actual_model = self.config.primary_model
                    return response
                
                except Exception as e:
                    last_error = e
                    logger.warning(f"Primary LLM attempt {attempt} failed: {e}")
                    
                    # Credits error: immediate fallback (no retry)
                    if is_credits_error(e):
                        logger.warning("Credits error detected, falling back immediately")
                        break
                    
                    # Non-retryable error: give up on primary
                    if not is_retryable_error(e):
                        logger.warning("Non-retryable error, attempting fallback")
                        break
                    
                    # Retryable error: try again (unless last attempt)
                    if attempt < max_retries:
                        import asyncio
                        delay = min(1.0 * (2 ** (attempt - 1)), 10.0)
                        logger.debug(f"Retrying in {delay}s...")
                        await asyncio.sleep(delay)
        else:
            logger.warning("Primary LLM (OpenRouter) not configured")
        
        # Try fallback model (OpenAI/GPT-4o)
        if self.config.fallback_enabled and self.config.fallback_available:
            try:
                logger.info(f"Falling back to {self.config.fallback_model}")
                response = await self._call_openai(
                    messages=messages,
                    tools=tools,
                    max_tokens=max_tokens,
                    temperature=temperature,
                )
                response.used_fallback = True
                response.actual_model = self.config.fallback_model
                return response
            
            except Exception as e:
                logger.error(f"Fallback LLM also failed: {e}")
                # Combine errors
                raise RuntimeError(
                    f"Both primary ({self.config.primary_model}) and fallback ({self.config.fallback_model}) failed. "
                    f"Primary error: {last_error}. Fallback error: {e}"
                ) from e
        
        # No fallback available
        if last_error:
            raise last_error
        raise RuntimeError("No LLM provider available (check API keys)")
    
    async def _call_openrouter(
        self,
        messages: List[Dict[str, Any]],
        tools: Optional[List[Dict[str, Any]]],
        max_tokens: int,
        temperature: float,
    ) -> LLMResponse:
        """Call OpenRouter (Claude) API."""
        params = {
            "model": self.config.primary_model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        
        if tools:
            params["tools"] = tools
            params["tool_choice"] = "auto"
        
        response = await self.openrouter_client.chat.completions.create(**params)
        return self._parse_response(response)
    
    async def _call_openai(
        self,
        messages: List[Dict[str, Any]],
        tools: Optional[List[Dict[str, Any]]],
        max_tokens: int,
        temperature: float,
    ) -> LLMResponse:
        """Call OpenAI (GPT-4o) API."""
        params = {
            "model": self.config.fallback_model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        
        if tools:
            params["tools"] = tools
            params["tool_choice"] = "auto"
        
        response = await self.openai_client.chat.completions.create(**params)
        return self._parse_response(response)
    
    def _parse_response(self, response) -> LLMResponse:
        """Parse OpenAI-compatible response into LLMResponse."""
        choice = response.choices[0]
        message = choice.message
        
        # Extract tool calls if present
        tool_calls = None
        if message.tool_calls:
            tool_calls = [
                {
                    "id": tc.id,
                    "type": "function",
                    "function": {
                        "name": tc.function.name,
                        "arguments": tc.function.arguments,
                    }
                }
                for tc in message.tool_calls
            ]
        
        # Extract token usage
        usage = response.usage
        tokens = TokenUsage(
            prompt=usage.prompt_tokens if usage else 0,
            completion=usage.completion_tokens if usage else 0,
            total=usage.total_tokens if usage else 0,
        )
        
        return LLMResponse(
            content=message.content,
            tool_calls=tool_calls,
            tokens=tokens,
            finish_reason=choice.finish_reason or "stop",
        )
    
    async def close(self):
        """Close HTTP clients."""
        if self._openrouter_client:
            await self._openrouter_client.close()
        if self._openai_client:
            await self._openai_client.close()


# =============================================================================
# Convenience Functions
# =============================================================================

async def call_llm_with_fallback(
    messages: List[Dict[str, Any]],
    tools: Optional[List[Dict[str, Any]]] = None,
    max_tokens: int = 4096,
    temperature: float = 0.0,
) -> LLMResponse:
    """
    Convenience function to call LLM with fallback.
    Creates a new provider for each call (for simple use cases).
    """
    provider = LLMProvider()
    try:
        return await provider.call_with_fallback(
            messages=messages,
            tools=tools,
            max_tokens=max_tokens,
            temperature=temperature,
        )
    finally:
        await provider.close()


def get_fallback_status() -> Dict[str, Any]:
    """Get current fallback configuration status."""
    config = get_config()
    return {
        "primary_model": config.primary_model,
        "fallback_model": config.fallback_model,
        "fallback_enabled": config.fallback_enabled,
        "primary_available": config.primary_available,
        "fallback_available": config.fallback_available,
    }

