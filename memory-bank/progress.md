# Progress: Tribal Knowledge Deep Agent

## What Works

### Full Pipeline ✅
The complete documentation pipeline is operational:
```
Plan → Document → Index
```

Run with: `npx dotenv-cli npm run pipeline`

### Planner (Schema Analyzer) ✅
- **Location**: `TribalAgent/src/agents/planner/`
- **CLI**: `npm run plan`
- **Output**: `progress/documentation-plan.json`
- **Features**:
  - Database connection and metadata extraction
  - LLM-powered domain inference
  - WorkUnit-based output for parallel documentation
  - Content hashes for change detection
  - Summary statistics with recommended parallelism

### Documenter ✅
- **Location**: `TribalAgent/src/agents/documenter/`
- **CLI**: `npm run document`, `npm run document:fresh`
- **Output**: `docs/` folder with Markdown and JSON files
- **Features**:
  - Parallel table processing (batch size: 3)
  - Parallel column inference (batch size: 5)
  - TableDocumenter and ColumnInferencer sub-agents
  - **SemanticEnricher** sub-agent for semantic metadata (roles, typical joins, analysis patterns)
  - **CrossDomainRelationshipGenerator** for domain relationship maps
  - LLM-powered semantic descriptions
  - Checkpoint recovery
  - Documentation manifest generation
  - Progress tracking
  - **Semantic metadata**: All tables include semantic_roles, typical_joins, analysis_patterns
  - **Cross-domain maps**: Auto-generated relationship documentation per database

### Indexer ✅
- **Location**: `TribalAgent/src/agents/indexer/`
- **CLI**: `npm run index`, `npm run index:fresh`, `npm run index:migrate-vec0`
- **Output**: `data/tribal-knowledge.db`
- **Features**:
  - sqlite-vec native vector operations (vec0 virtual table with `document_id` column)
  - Blob fallback when extension unavailable
  - FTS5 full-text search with Porter stemming
  - OpenAI embeddings (text-embedding-3-small)
  - Document splitting for large texts (8k token limit guard)
  - Keyword extraction
  - Relationship/join path indexing (with enhanced FK extraction patterns)
  - Embedding lookup by both file path and document identity
  - Incremental re-indexing support
  - Checkpoint/resume support
  - Migration script for converting blob-based vec tables to vec0

### Database Schema
```
tribal-knowledge.db (SQLite)
├── documents        ← metadata, content, file paths
├── documents_fts    ← FTS5 Porter-stemmed text index
├── documents_vec    ← vector embeddings (1536-dim, uses document_id column)
├── relationships    ← FK relationships, join paths
├── keywords         ← extracted terms + frequencies
├── index_weights    ← search scoring config
└── index_metadata   ← provenance info
```

**Important Schema Note**: The `documents_vec` table uses `document_id` (not `id`) as the primary key column to match expected schema for test compatibility. This applies to both vec0 virtual table and blob fallback implementations.

### Supporting Infrastructure ✅
- Database connectors: PostgreSQL and Snowflake
- LLM utilities with retry and fallback
- Prompt template system
- Configuration management
- Logging system
- CLI commands

## What's Left to Build

### LLM Fallback (OpenRouter → GPT-4o) ✅ COMPLETE
- **Plan**: `PlanningDocs/llm-fallback-sftp-sync-plan.md`
- **Status**: Implemented December 13, 2025
- **Features**:
  - [x] Automatic fallback from Claude to GPT-4o when OpenRouter fails
  - [x] Uses existing `OPENAI_API_KEY` (same as embeddings)
  - [x] Configurable via `LLM_FALLBACK_ENABLED` and `LLM_FALLBACK_MODEL`
  - [x] Response includes `usedFallback` and `actualModel` fields
  - [x] `getFallbackStatus()` export for debugging
- **Files**: `src/utils/llm.ts`

### SFTP Sync ✅ COMPLETE
- **Plan**: `PlanningDocs/llm-fallback-sftp-sync-plan.md`
- **Status**: Implemented December 13, 2025
- **SFTP Server**: `129.158.231.129:4100` (user: `gauntlet`)
- **Remote Structure**:
  - `/data/index/index.db` ← `data/tribal-knowledge.db` (RENAMED to index.db)
  - `/data/map/documentation-manifest.json` ← `docs/documentation-manifest.json`
  - `/data/map/{db_name}/` ← `docs/databases/{db_name}/`
- **Features**:
  - [x] `ssh2-sftp-client` dependency installed
  - [x] `src/utils/sftp-sync.ts` - SFTP sync service
  - [x] `src/cli/sync.ts` - CLI command
  - [x] npm scripts: `sync`, `sync:index`, `sync:docs`, `sync:no-backup`, `sync:dry-run`
  - [x] `npm run pipeline:deploy` - full pipeline + sync
  - [x] Automatic backup of existing remote files
  - [x] Configurable backup retention (default: 5)

### Retriever/MCP Server ⏳
- **Location**: `TribalAgent/src/agents/retrieval/` (TribalAgent) + `Company-MCP/` (Noah's repo)
- **Status**: Hybrid search logic exists, MCP tools partially implemented
- **Completed**:
  - [x] Database FK constraints added (24 FKs for product_id columns)
  - [x] Supply chain test data populated (suppliers, supplier_products, POs, PO lines)
  - [x] Sales data with valid product_ids for margin analysis
- **Needed**:
  - [ ] `get_column_usage()` tool in Company-MCP (find all tables using a column)
  - [ ] Enhanced `get_join_path()` output (complete SQL, intermediate tables)
  - [ ] Hybrid search integration (FTS5 + vector + RRF)
  - [ ] Context budgeting and compression
  - [ ] MCP protocol server

### End-to-End Testing
- [ ] Full pipeline integration tests
- [ ] Search quality validation
- [ ] Performance benchmarking

### Phase 3: Snowflake & Scale (Future)
- [ ] Mermaid ER diagram generation
- [ ] JSON Schema output
- [ ] YAML semantic models

### Phase 4: MCP Integration (Future)
- [ ] Noah's Company MCP integration
- [ ] Production deployment documentation

## Current Status

**Overall**: ~80% Complete

| Component | Status | Notes |
|-----------|--------|-------|
| Planning Documents | ✅ 100% | PRD, Technical Spec, Contracts |
| Planner Agent | ✅ 100% | Working |
| Documenter Agent | ✅ 100% | Parallelized, working |
| Indexer Agent | ✅ 100% | sqlite-vec enabled |
| Retriever Agent | ⏳ 20% | Search logic exists, MCP pending |
| Testing | ⏳ 40% | Unit tests exist, integration pending |

## Known Issues

### Resolved ✅
- ~~Documenter output schema didn't match Indexer expectations~~ → Fixed
- ~~Embedding token limit errors on large documents~~ → Document splitting implemented with enhanced 8k token guard
- ~~sqlite-vec extension not loading~~ → Added platform-specific paths and additional system paths
- ~~Embeddings key mismatch bug~~ → Fixed: Embeddings now use consistent identity format and dual-key lookup (filePath + document identity)
- ~~FK relationship extraction not matching documenter format~~ → Fixed: Added Unicode arrow `→` pattern matching
- ~~Snowflake SDK verbose logging~~ → Fixed: Configured log level to WARN
- ~~documents_vec schema mismatch~~ → Fixed: Changed column from `id` to `document_id` throughout codebase for test compatibility
- ~~vec0 embedding insert error~~ → Fixed: vec0's `float[1536]` doesn't support parameterized queries. Now uses direct SQL with `vec_f32()` function wrapper. JSON strings are properly escaped for security.

### Open
- `get_column_usage()` MCP tool not yet implemented (lives in Company-MCP repo)
- End-to-end integration tests pending
- Query pattern templates (cancelled - not needed with semantic metadata)

## Success Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Documentation coverage | 100% tables | ✅ 41/41 tables documented |
| Indexing coverage | 100% docs | ✅ 82 files indexed |
| Pipeline runtime | <5 min/100 tables | ~3 min for 41 tables |
| sqlite-vec enabled | Yes | ✅ Yes |

## Notes

- Full pipeline tested successfully with PostgreSQL (41 tables) and Snowflake (4 tables)
- sqlite-vec requires manual build on macOS (see `build-sqlite-vec.sh`)
- All agents support checkpoint recovery for interrupted runs
- Parallelization significantly improved documenter performance
- **Documentation Quality**: Semantic metadata and cross-domain maps enable better join path discovery
- **Database State**: Supabase synthetic_250_postgres now has proper FK constraints and realistic test data for margin analysis
- **Root Cause Analysis**: FK extraction "bug" was actually missing database constraints - fixed by adding FKs to Supabase
