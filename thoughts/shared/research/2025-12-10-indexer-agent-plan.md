---
date: 2025-12-10T17:56:00-06:00
researcher: Claude Opus 4.5
git_commit: 732cd65
branch: main
repository: Tribal_Knowledge
topic: "Indexer Agent (Module 3) Implementation Plan"
tags: [research, codebase, indexer, tribal-knowledge, deep-agent]
status: complete
last_updated: 2025-12-10
last_updated_by: Claude Opus 4.5
---

# Research: Indexer Agent (Module 3) Implementation Plan

**Date**: 2025-12-10T17:56:00-06:00
**Researcher**: Claude Opus 4.5
**Git Commit**: 732cd65
**Branch**: main
**Repository**: Tribal_Knowledge

## Research Question

Look up the plans in the TribalAgent planning folder, and then develop a plan for the Indexer Agent (i.e. module 3).

## Summary

Successfully analyzed the existing Tribal Knowledge Deep Agent planning documents and created a comprehensive implementation plan for the Indexer Agent (Module 3). The Indexer is the third component in the pipeline chain: Planner → Documenter → **Indexer** → Retriever.

The existing codebase has a skeleton implementation at `src/agents/indexer/index.ts` with TODO placeholders. The new plan provides detailed specifications for:
- Input contract validation (documentation-manifest.json)
- Document parsing (markdown, YAML, JSON)
- Keyword extraction with abbreviation expansion
- OpenAI embedding generation with batching
- SQLite database schema (FTS5 + vector)
- Incremental indexing via content hashes
- Relationship graph building for join paths
- Error handling and graceful degradation

## Detailed Findings

### Existing Planning Documents

The TribalAgent planning folder contains 8 documents:

| Document | Purpose |
|----------|---------|
| `tribal-knowledge-plan.md` | High-level project plan with phases |
| `tribal-knowledge-deep-agent-implementation.md` | Technical PRD with full specifications |
| `agent-contracts-summary.md` | Human-readable overview of agent contracts |
| `agent-contracts-interfaces.md` | TypeScript interfaces for all agents |
| `agent-contracts-execution.md` | Parallel execution model |
| `orchestrator-plan.md` | Coordination layer design |
| `tribal-knowledge-prd1-product.md` | Product requirements |
| `tribal-knowledge-prd2-technical.md` | Technical requirements |

### System Architecture

The Tribal Knowledge system is a deep agent pipeline:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Planner   │───▶│  Documenter │───▶│   Indexer   │───▶│  Retriever  │
│   (Schema   │    │  (Agent 1)  │    │  (Agent 2)  │    │  (Agent 3)  │
│  Analyzer)  │    │             │    │             │    │  MCP Server │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │                  │
       ▼                  ▼                  ▼                  ▼
  plan.json          manifest.json      SQLite DB         MCP Tools
```

### Indexer Agent Position

The Indexer Agent sits between the Documenter and Retriever:

- **Input**: `docs/documentation-manifest.json` (from Documenter)
- **Output**: `data/tribal-knowledge.db` (SQLite with FTS5 + vectors)

### Existing Implementation Status

The current skeleton at `src/agents/indexer/index.ts`:
- Has basic progress tracking schema
- Creates SQLite tables (documents, FTS5, relationships)
- Has placeholder functions with TODO comments for:
  - Document parsing
  - Keyword extraction
  - Embedding generation
  - Relationship building

### New Plan Created

Created `planning/indexer-agent-plan.md` with 12 sections covering:

1. **Executive Summary** - Position in pipeline, key responsibilities
2. **Input Contract** - Manifest validation rules
3. **Output Contract** - SQLite schema with 5 tables
4. **Processing Pipeline** - 7-step flow diagram
5. **Incremental Indexing** - Change detection via content hashes
6. **Error Handling** - 10 error codes with recovery strategies
7. **Configuration** - YAML config and environment variables
8. **CLI Interface** - npm run commands
9. **Implementation Checklist** - 7 phases with tasks
10. **Success Metrics** - Throughput, latency, accuracy targets
11. **Dependencies** - NPM packages, external services
12. **Testing Strategy** - Unit, integration, performance tests

### Key Design Decisions in Plan

| Decision | Rationale |
|----------|-----------|
| **FTS5 with Porter stemmer** | Better keyword matching via stemming |
| **text-embedding-3-small** | Balance of quality and cost |
| **50-document batch size** | Optimal for OpenAI rate limits |
| **Content hash change detection** | Enable incremental re-indexing |
| **Graceful degradation** | Continue with FTS if embeddings fail |
| **BFS for join paths** | Find shortest paths up to 3 hops |

## Code References

- `TribalAgent/planning/tribal-knowledge-plan.md` - Main project plan
- `TribalAgent/planning/tribal-knowledge-deep-agent-implementation.md` - Technical PRD
- `TribalAgent/planning/agent-contracts-interfaces.md` - TypeScript interfaces
- `TribalAgent/planning/agent-contracts-execution.md` - Execution model
- `TribalAgent/planning/agent-contracts-summary.md` - Human-readable summary
- `TribalAgent/planning/orchestrator-plan.md` - Orchestrator design
- `TribalAgent/src/agents/indexer/index.ts` - Existing skeleton implementation
- **`TribalAgent/planning/indexer-agent-plan.md` - NEW: Detailed implementation plan**

## Architecture Documentation

The Indexer follows the established patterns from the agent contracts:

- Uses `documentation-manifest.json` as handoff contract from Documenter
- Produces SQLite database as handoff to Retriever
- Implements checkpoint recovery via `indexer-progress.json`
- Supports partial success (can index what's available)
- Uses content hashes for change detection and incremental updates

## Related Research

None yet - this is the first research document in this repository.

## Open Questions

1. **sqlite-vec availability**: Should fallback to blob storage if sqlite-vec extension unavailable
2. **Embedding model upgrade**: May want to support switching to text-embedding-3-large later
3. **Cross-database relationships**: Not addressed in v1.0, semantic matching planned for future

---

*End of Research Document*
