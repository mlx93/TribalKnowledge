# Project Brief: Tribal Knowledge Deep Agent

## Project Overview

Tribal Knowledge Deep Agent is an AI-powered deep agent system that automatically documents database schemas, indexes documentation for efficient retrieval, and exposes it via MCP (Model Context Protocol) for AI agent consumption. The system solves the "tribal knowledge" problem where critical data knowledge exists only in the minds of experienced team members.

## Core Problem

Organizations accumulate critical data knowledge that exists only in the minds of experienced team members. When data scientists need to answer business questions, they face:
- **Discovery friction**: Which tables contain relevant data?
- **Schema confusion**: What do cryptic column names actually mean?
- **Join complexity**: How do tables relate to each other?
- **Documentation debt**: Outdated or non-existent data dictionaries

## Solution

A deep agent system that:
1. **Plans** documentation strategy by analyzing database structure first
2. **Documents** database schemas with semantic understanding via specialized sub-agents
3. **Indexes** documentation for efficient natural language search
4. **Retrieves** relevant context via MCP for AI agent consumption

## Key Requirements

### Functional Requirements
- Support PostgreSQL and Snowflake databases
- Automatic schema analysis and domain detection
- Semantic inference for tables and columns using LLM
- Hybrid search (keyword + vector similarity)
- MCP tool integration for external AI agents
- Multi-database support with cross-database search
- Progress tracking and checkpoint recovery

### Technical Requirements
- TypeScript/Node.js implementation
- SQLite with FTS5 and sqlite-vec for search
- OpenAI embeddings API
- Claude/Anthropic API for semantic inference
- Filesystem-based documentation output (Markdown, JSON Schema, YAML)
- Configurable prompt templates

### Deep Agent Properties
- **Planning Tool**: Schema Analyzer runs first, creates documentation-plan.json
- **Sub-agents**: TableDocumenter and ColumnInferencer handle repeated tasks
- **File System**: /docs for output, /progress for state, /prompts for templates
- **System Prompts**: Configurable templates in /prompts directory

## Target Users

1. **Data Scientists**: Find relevant tables and understand how to query them
2. **Data Engineers**: Maintain accurate, up-to-date documentation
3. **AI Agents**: Receive minimal, high-signal context for SQL generation
4. **New Team Members**: Quickly understand data landscape during onboarding

## Success Criteria

- Documentation coverage: 100% of tables
- Search relevance (top-3 hit): >85%
- Join path accuracy: >95%
- Search latency (p95): <500ms
- Documentation time (100 tables): <5 minutes

## Project Status

**Current Phase**: Implementation In Progress
- Detailed PRDs completed (PRD1: Product, PRD2: Technical)
- Agent contracts defined
- Implementation plans created
- Test database setup (DABstep-postgres) available
- **Implementation Status**:
  - ✅ Planner (Schema Analyzer): Fully implemented and built
  - ✅ Documenter: Fully implemented and built
  - ✅ Indexer: Fully implemented and built
  - ⏳ Retriever/MCP Server: Pending implementation
- **Codebase Location**: `TribalAgent/` directory

## Key Documents

- `PlanningDocs/tribal-knowledge-prd1-product.md` - Product requirements
- `PlanningDocs/tribal-knowledge-prd2-technical.md` - Technical specification
- `PlanningDocs/tribal-knowledge-plan.md` - Project plan with phases
- `PlanningDocs/agent-contracts-*.md` - Agent interfaces and contracts
- `PlanningDocs/orchestrator-plan.md` - Orchestration layer design

## Implementation Status

- **Codebase**: `TribalAgent/` directory
- **Planner**: ✅ Implemented (`src/agents/planner/`) - Generates documentation plans
- **Documenter**: ✅ Implemented (`src/agents/documenter/`) - Generates Markdown and JSON documentation with LLM semantic inference
- **Indexer**: ✅ Implemented (`src/agents/indexer/`) - Builds search index
- **Retriever**: ⏳ Pending - Hybrid search logic exists, MCP tools needed

## Constraints

- Database access: Requires read access to metadata and sample data
- API costs: OpenAI embeddings and LLM calls incur per-token costs
- Local storage: Documentation and index stored locally (not cloud)
- Single user: Initial version designed for single-user operation
- Manual triggers: Users manually trigger pipeline (no autonomous execution)
