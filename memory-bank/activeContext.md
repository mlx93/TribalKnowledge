# Active Context: Tribal Knowledge Deep Agent

## Current Work Focus

**Status**: Planning - LLM Fallback & SFTP Sync Features

The core pipeline (plan → document → index) is operational. Current focus is on two new features:

1. **LLM Fallback**: Enable GPT-4o as backup when OpenRouter (Claude) fails
2. **SFTP Sync**: Push index database and docs to remote SFTP server with backup

**Plan Document**: `PlanningDocs/llm-fallback-sftp-sync-plan.md`

## Recent Changes (December 11, 2025)

### Schema Alignment Fixes (Latest)
- **documents_vec column rename**: Changed from `id` to `document_id` to match expected schema for test compatibility
  - Updated `init.ts`: vec0 virtual table now uses `document_id INTEGER PRIMARY KEY`
  - Updated `populate.ts`: Insert/delete statements now use `document_id`
  - Updated `hybrid-search.ts`: Join clause now uses `document_id`
  - Updated `incremental.ts` and `optimize.ts`: All queries updated to use `document_id`
  - Migration script created: `scripts/migrate-vec-to-vec0.ts` for converting existing databases
- **vec0 embedding format fix**: Fixed critical bug where vec0 virtual table requires direct SQL with vec_f32(), not parameterized queries
  - **Root cause**: vec0's `float[1536]` column type doesn't support parameterized queries when using `vec_f32()` function
  - **Solution**: Use direct SQL construction: `INSERT INTO documents_vec (document_id, embedding) VALUES (${docId}, vec_f32('${escapedJson}'))`
  - Updated `populate.ts`: Converts embedding to JSON string, escapes single quotes, uses `db.exec()` with direct SQL
  - Updated `hybrid-search.ts`: Handles both JSON array (vec0) and BLOB (fallback) formats when reading embeddings
  - Added `cosineSimilarityArrays()` method to work directly with number arrays
  - **Security**: JSON strings are escaped to prevent SQL injection (single quotes doubled)
- **8k token limit guard**: Enhanced embedding generation with better error handling
  - More conservative character-per-token estimate (4 chars/token)
  - Better logging when documents exceed limits
  - Graceful handling of empty/invalid texts
  - Explicit error messages for context window exceeded errors

### Documenter Enhancements
- **Parallelized processing**: Tables processed in batches of 3, columns in batches of 5
- **Manifest schema alignment**: Output now matches Indexer's expected schema
- **Document splitting**: Large documents are split for embedding generation to avoid token limits
- **npm scripts added**: `document:clean`, `document:fresh` for cache management
- **Environment variable substitution**: Database credentials moved to `.env`, referenced via `${VAR}` in `databases.yaml` (commit: b69a5eb)

### Indexer Enhancements
- **sqlite-vec support**: Native vector operations enabled (vec0 virtual table)
- **Extended extension paths**: Now searches platform-specific npm packages (darwin-arm64, darwin-x64, linux-x64) and additional system paths (commit: 36012aa)
- **Blob fallback**: Graceful degradation if sqlite-vec unavailable
- **npm scripts added**: `index:clean`, `index:fresh` for cache management
- **Migration script**: Added `npm run index:migrate-vec0` for converting blob-based vec tables to vec0
- **Embeddings key mismatch fix**: Fixed critical bug where embeddings were generated with semantic IDs but looked up by file paths. Now uses consistent identity format (`db.schema.table`) and dual-key lookup (filePath + identity)
- **FK relationship extraction**: Enhanced regex patterns to match Unicode arrow `→` format used by TableDocumenter (e.g., `` `column` → `table.column` ``)
- **Snowflake SDK verbosity**: Reduced logging level to WARN to suppress verbose connection details

### Git Configuration
- **gitignore updates**: Separated memory-bank and sqlite-vec entries (commit: 3802faf)
- **sqlite-vec build directory**: Added to gitignore (commit: 06ea47d)

### Pipeline Scripts
- `npm run pipeline` - Full pipeline with caching
- `npm run pipeline:fresh` - Clear all caches and rebuild

## Available npm Commands

All commands run from `TribalAgent/` with `npx dotenv-cli` prefix:

### Main Pipeline
| Command | Description |
|---------|-------------|
| `npm run pipeline` | Run full: plan → document → index |
| `npm run pipeline:fresh` | Clear caches, then full pipeline |

### Individual Agents
| Command | Description |
|---------|-------------|
| `npm run plan` | Generate documentation plan |
| `npm run document` | Generate docs (uses cache) |
| `npm run document:clean` | Clear docs/ and progress |
| `npm run document:fresh` | Clear + regenerate docs |
| `npm run index` | Build search index |
| `npm run index:clean` | Delete knowledge.db |
| `npm run index:fresh` | Delete + rebuild index |

### Utilities
| Command | Description |
|---------|-------------|
| `npm run status` | Show pipeline status |
| `npm run validate-prompts` | Validate prompt templates |
| `npm run build` | Compile TypeScript |
| `npm run test` | Run all tests |

## Pipeline Output Artifacts

### Planner Output
- `progress/documentation-plan.json` - Work units and table specs

### Documenter Output
- `docs/{work_unit}/tables/*.md` - Markdown documentation
- `docs/{work_unit}/tables/*.json` - JSON documentation
- `docs/documentation-manifest.json` - Manifest for indexer
- `progress/documenter-progress.json` - Checkpoint file

### Indexer Output
- `data/tribal-knowledge.db` - SQLite database with:
  - `documents` - Metadata and content
  - `documents_fts` - FTS5 full-text search
  - `documents_vec` - Vector embeddings (vec0 virtual table with `document_id` column, or blob fallback)
  - `relationships` - FK and join paths
  - `keywords` - Extracted terms
  - `index_weights` - Search scoring config
  - `index_metadata` - Provenance info

## Implementation Status

| Agent | Status | Location |
|-------|--------|----------|
| **Planner** | ✅ Complete | `src/agents/planner/` |
| **Documenter** | ✅ Complete | `src/agents/documenter/` |
| **Indexer** | ✅ Complete | `src/agents/indexer/` |
| **Retriever** | ⏳ Pending | `src/agents/retrieval/` |

## Next Steps

### Immediate: LLM Fallback & SFTP Sync (December 13, 2025)
**Plan**: `PlanningDocs/llm-fallback-sftp-sync-plan.md`

#### Phase 1: LLM Fallback
1. Update `src/utils/llm.ts` with fallback logic (OpenRouter → GPT-4o)
2. Add config schema for fallback options
3. Update `.env.example` with `LLM_FALLBACK_ENABLED`, `LLM_FALLBACK_MODEL`
4. Test with OpenRouter disabled

#### Phase 2: SFTP Sync
1. Install `ssh2-sftp-client` dependency
2. Create `src/utils/sftp-sync.ts` - sync service
3. Create `src/cli/sync.ts` - CLI command
4. Add npm scripts: `sync`, `sync:index`, `sync:docs`, `pipeline:deploy`
5. Configure SFTP: `SFTP_HOST`, `SFTP_PORT`, `SFTP_USER`, `SFTP_PASSWORD`
6. Test with real SFTP server (129.158.231.129:4100)

### Then: Retriever/MCP Server
1. Implement MCP tool handlers
2. Complete hybrid search integration (FTS5 + vector + RRF)
3. Add context budgeting and compression
4. Expose search tools via MCP protocol

### Testing
- End-to-end pipeline testing
- Search quality validation
- Performance benchmarking

## Architecture Decisions

1. **Deep Agent Pattern**: Planning, sub-agents, filesystem memory, configurable prompts
2. **Storage**: Filesystem (human-readable) + SQLite (machine-searchable)
3. **Search**: Hybrid approach (FTS5 + vector + RRF fusion)
4. **Parallelization**: Batched processing (3 tables, 5 columns concurrently)
5. **Vector Storage**: sqlite-vec preferred, blob fallback available

## Active Files

### Implementation
- `TribalAgent/src/agents/planner/` - Planner ✅
- `TribalAgent/src/agents/documenter/` - Documenter ✅
- `TribalAgent/src/agents/indexer/` - Indexer ✅
- `TribalAgent/src/agents/retrieval/` - Retriever (pending)

### Configuration
- `TribalAgent/package.json` - npm scripts and dependencies
- `TribalAgent/.gitignore` - Excludes data/, docs/, sqlite-vec/

### Test Resources
- `DABstep-postgres/` - PostgreSQL test database
- Snowflake connection configured in .env
