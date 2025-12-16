"""
MCP JSON-RPC Client

HTTP client for Company-MCP servers using JSON-RPC protocol with SSE responses.

Features:
- Session-based MCP protocol (initialize -> tools/list -> tools/call)
- Automatic SSE response parsing
- Tool namespacing (server_id__tool_name)
- Convert MCP tools to OpenAI function calling format

Based on: Company-MCP/frontend/main.py
"""

import os
import json
import logging
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

import httpx

logger = logging.getLogger(__name__)

# Default MCP server URLs
DEFAULT_SYNTH_URL = os.getenv("MCP_SYNTH_URL", "https://company-mcp.com/mcp/synth")
DEFAULT_POSTGRES_URL = os.getenv("MCP_POSTGRES_URL", "https://company-mcp.com/mcp/postgres")


@dataclass
class MCPServerConfig:
    """Configuration for an MCP server."""
    server_id: str
    url: str
    description: str = ""
    enabled: bool = True


@dataclass
class MCPTool:
    """A tool from an MCP server."""
    name: str
    description: str
    input_schema: Dict[str, Any]
    server_id: str
    server_url: str
    
    @property
    def full_name(self) -> str:
        """Get namespaced tool name (server_id__tool_name)."""
        return f"{self.server_id}__{self.name}"
    
    def to_openai_format(self) -> Dict[str, Any]:
        """Convert to OpenAI function calling format."""
        return {
            "type": "function",
            "function": {
                "name": self.full_name,
                "description": self.description,
                "parameters": self.input_schema or {"type": "object", "properties": {}},
            }
        }


def parse_sse_response(content: str) -> Dict[str, Any]:
    """
    Parse SSE event stream response to extract JSON data.
    
    MCP servers return responses in SSE format:
    data: {"jsonrpc": "2.0", "id": 1, "result": {...}}
    """
    for line in content.split('\n'):
        if line.startswith('data: '):
            try:
                return json.loads(line[6:])
            except json.JSONDecodeError:
                continue
    return {}


class MCPClient:
    """
    MCP JSON-RPC client for interacting with Company-MCP servers.
    
    Usage:
        async with MCPClient() as client:
            tools = await client.get_tools_for_llm()
            result = await client.call_tool("synth-mcp__search_tables", {"query": "users"})
    """
    
    def __init__(
        self,
        servers: Optional[List[MCPServerConfig]] = None,
        timeout: float = 60.0,
    ):
        """
        Initialize MCP client.
        
        Args:
            servers: List of MCP server configurations. If None, uses defaults.
            timeout: HTTP request timeout in seconds
        """
        if servers is None:
            servers = [
                MCPServerConfig(
                    server_id="synth-mcp",
                    url=DEFAULT_SYNTH_URL,
                    description="Schema context and documentation (15 tools)",
                ),
                MCPServerConfig(
                    server_id="postgres-mcp",
                    url=DEFAULT_POSTGRES_URL,
                    description="SQL execution (read-only, 9 tools)",
                ),
            ]
        
        self.servers = {s.server_id: s for s in servers if s.enabled}
        self.timeout = timeout
        self._client: Optional[httpx.AsyncClient] = None
        self._sessions: Dict[str, str] = {}  # server_id -> session_id
        self._tools: Dict[str, MCPTool] = {}  # full_name -> MCPTool
    
    async def __aenter__(self):
        """Async context manager entry."""
        await self.initialize()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        await self.close()
    
    async def initialize(self):
        """Initialize HTTP client and fetch tools from all servers."""
        self._client = httpx.AsyncClient(timeout=self.timeout)
        
        # Initialize sessions and fetch tools from all servers
        for server_id, server in self.servers.items():
            try:
                session_id = await self._initialize_session(server)
                self._sessions[server_id] = session_id
                
                tools = await self._fetch_tools(server, session_id)
                for tool in tools:
                    self._tools[tool.full_name] = tool
                
                logger.info(f"Connected to {server_id}: {len(tools)} tools")
            except Exception as e:
                logger.warning(f"Failed to connect to {server_id}: {e}")
    
    async def close(self):
        """Close HTTP client."""
        if self._client:
            await self._client.aclose()
            self._client = None
        self._sessions.clear()
        self._tools.clear()
    
    async def _initialize_session(self, server: MCPServerConfig) -> str:
        """
        Initialize MCP session with a server.
        
        Returns:
            Session ID from server
        """
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "SlackBot",
                    "version": "1.0.0",
                }
            }
        }
        
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        
        response = await self._client.post(
            server.url,
            json=payload,
            headers=headers,
        )
        
        session_id = response.headers.get("mcp-session-id")
        if not session_id:
            raise RuntimeError(f"No session ID from {server.server_id}")
        
        logger.debug(f"Session initialized: {server.server_id} -> {session_id[:16]}...")
        return session_id
    
    async def _fetch_tools(self, server: MCPServerConfig, session_id: str) -> List[MCPTool]:
        """Fetch tool definitions from a server."""
        payload = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {},
        }
        
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "mcp-session-id": session_id,
        }
        
        response = await self._client.post(
            server.url,
            json=payload,
            headers=headers,
        )
        
        result = parse_sse_response(response.text)
        raw_tools = result.get("result", {}).get("tools", [])
        
        tools = []
        for t in raw_tools:
            tools.append(MCPTool(
                name=t["name"],
                description=t.get("description", f"Tool: {t['name']}"),
                input_schema=t.get("inputSchema", {}),
                server_id=server.server_id,
                server_url=server.url,
            ))
        
        return tools
    
    def get_tools(self) -> List[MCPTool]:
        """Get all available tools."""
        return list(self._tools.values())
    
    def get_tools_for_llm(self) -> List[Dict[str, Any]]:
        """Get all tools in OpenAI function calling format."""
        return [tool.to_openai_format() for tool in self._tools.values()]
    
    def get_tool(self, full_name: str) -> Optional[MCPTool]:
        """Get a tool by its full name (server_id__tool_name)."""
        return self._tools.get(full_name)
    
    async def call_tool(
        self,
        full_name: str,
        arguments: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Call a tool on an MCP server.
        
        Args:
            full_name: Tool name in format server_id__tool_name
            arguments: Tool arguments
        
        Returns:
            Tool result as dictionary
        """
        tool = self._tools.get(full_name)
        if not tool:
            return {"error": f"Unknown tool: {full_name}"}
        
        server = self.servers.get(tool.server_id)
        if not server:
            return {"error": f"Unknown server: {tool.server_id}"}
        
        # Get or refresh session
        session_id = self._sessions.get(tool.server_id)
        if not session_id:
            try:
                session_id = await self._initialize_session(server)
                self._sessions[tool.server_id] = session_id
            except Exception as e:
                return {"error": f"Failed to connect to {tool.server_id}: {e}"}
        
        # Call the tool
        payload = {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": tool.name,  # Use original tool name, not namespaced
                "arguments": arguments,
            }
        }
        
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "mcp-session-id": session_id,
        }
        
        logger.debug(f"Calling tool: {full_name} with args: {arguments}")
        
        try:
            response = await self._client.post(
                server.url,
                json=payload,
                headers=headers,
            )
            
            result = parse_sse_response(response.text)
            
            if "error" in result:
                logger.warning(f"Tool error: {result['error']}")
                return {"error": result["error"]}
            
            tool_result = result.get("result", result)
            logger.debug(f"Tool result: {str(tool_result)[:200]}...")
            return tool_result
            
        except Exception as e:
            logger.error(f"Tool call failed: {e}")
            return {"error": str(e)}
    
    async def refresh_session(self, server_id: str):
        """Refresh session for a specific server."""
        server = self.servers.get(server_id)
        if server:
            try:
                session_id = await self._initialize_session(server)
                self._sessions[server_id] = session_id
                logger.info(f"Refreshed session for {server_id}")
            except Exception as e:
                logger.error(f"Failed to refresh session for {server_id}: {e}")


# =============================================================================
# Helper Functions
# =============================================================================

def parse_tool_name(full_name: str) -> tuple[str, str]:
    """
    Parse a namespaced tool name into server_id and tool_name.
    
    Args:
        full_name: Tool name in format "server_id__tool_name"
    
    Returns:
        Tuple of (server_id, tool_name)
    """
    if "__" in full_name:
        parts = full_name.split("__", 1)
        return parts[0], parts[1]
    return "default", full_name


async def test_mcp_connectivity() -> Dict[str, Any]:
    """
    Test connectivity to MCP servers.
    
    Returns:
        Dict with server statuses
    """
    results = {}
    
    async with MCPClient() as client:
        for server_id, session_id in client._sessions.items():
            results[server_id] = {
                "connected": bool(session_id),
                "session_id": session_id[:16] + "..." if session_id else None,
                "url": client.servers[server_id].url,
            }
        
        results["total_tools"] = len(client._tools)
        results["tools_by_server"] = {
            server_id: len([t for t in client._tools.values() if t.server_id == server_id])
            for server_id in client.servers
        }
    
    return results

