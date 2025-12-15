# Active Context: Tribal Knowledge Deep Agent

## Current Work Focus

**Status**: Documentation Enhancements - Semantic Metadata & Cross-Domain Relationships

The core pipeline (plan → document → index) is operational. Recent enhancements focus on improving documentation quality for better join path discovery and AI-assisted querying.

**Latest Work** (December 14, 2025):
1. **Database FK Constraints** ✅: Added 24 foreign key constraints to Supabase for product_id columns
2. **Supply Chain Data** ✅: Populated suppliers, supplier_products, purchase_orders, purchase_order_lines with realistic cost data
3. **Semantic Metadata** ✅: Enhanced table documentation with semantic roles, typical joins, and analysis patterns
4. **Cross-Domain Relationship Maps** ✅: Auto-generated relationship maps showing how domains connect

**Plan Documents**: 
- `PlanningDocs/llm-fallback-sftp-sync-plan.md` (completed)
- `MCP_GAPS_ANALYSIS.md` (analysis of documentation gaps)
- `ACTION_PLAN_MCP_FIXES.md` (implementation plan)

## Recent Changes (December 14, 2025)

### Documentation Quality Enhancements (Latest)
- **Semantic Metadata Enrichment**: Added `SemanticEnricher` sub-agent that infers:
  - `semantic_roles`: transaction_header, transaction_detail, master_data, reference_data, bridge_table, etc.
  - `typical_joins`: Common join patterns with relationship types, cardinality, frequency
  - `analysis_patterns`: Business use cases this table supports
  - Location: `src/agents/documenter/sub-agents/SemanticEnricher.ts`
  - Integrated into `TableDocumenter` - all tables now include semantic metadata in JSON and Markdown
- **Cross-Domain Relationship Maps**: New generator creates `docs/{database}/cross_domain_relationships.md`:
  - Shows how business domains connect (e.g., Sales → Procurement)
  - Identifies FK-based and common-column relationships
  - LLM-generated use cases for each domain pair
  - Example SQL joins
  - Location: `src/agents/documenter/generators/CrossDomainRelationshipGenerator.ts`
  - Runs automatically after all work units complete

### Database Schema Improvements
- **FK Constraints Added**: Added 24 foreign key constraints to Supabase synthetic_250_postgres database:
  - Critical for margin analysis: `sales_order_lines.product_id → products`, `purchase_order_lines.product_id → products`, `supplier_products.product_id → products`
  - Enables automatic join path discovery by indexer
  - Fixed orphaned data (set NULL or deleted invalid product_ids)
- **Supply Chain Data Population**: Populated empty tables with realistic test data:
  - 5 suppliers with contact info
  - 100 supplier_products entries with unit costs (40-70% of base price for positive margins)
  - 10 purchase orders (completed, shipped, pending statuses)
  - 50 purchase_order_lines with cost data
  - 30 sales_order_lines with valid product_ids matching supply chain

### LLM Configuration
- **Primary Model**: Set to `claude-haiku-4.5` via `LLM_PRIMARY_MODEL` env var
- **Fallback**: GPT-4o available when Claude fails (via `LLM_FALLBACK_ENABLED=true`)

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
- `docs/databases/{database}/domains/{domain}/tables/*.md` - Markdown documentation (with semantic metadata)
- `docs/databases/{database}/domains/{domain}/tables/*.json` - JSON documentation (with semantic_roles, typical_joins, analysis_patterns)
- `docs/databases/{database}/cross_domain_relationships.md` - Cross-domain relationship maps
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

### Completed: LLM Fallback & SFTP Sync (December 13, 2025) ✅
**Plan**: `PlanningDocs/llm-fallback-sftp-sync-plan.md`

#### LLM Fallback ✅
- `src/utils/llm.ts` - Automatic fallback from Claude to GPT-4o
- Uses existing `OPENAI_API_KEY` - no new key needed
- Configurable via `LLM_FALLBACK_ENABLED` and `LLM_FALLBACK_MODEL`

#### SFTP Sync ✅
- `src/utils/sftp-sync.ts` - SFTP sync service
- `src/cli/sync.ts` - CLI command
- npm scripts: `sync`, `sync:index`, `sync:docs`, `sync:no-backup`, `sync:dry-run`, `pipeline:deploy`
- SFTP server: `129.158.231.129:4100`

### Immediate: Test & Validate
1. Test SFTP sync with real server
2. Test LLM fallback by disabling OpenRouter key
3. Run full `npm run pipeline:deploy`

### Next: MCP Tool Enhancements
1. Implement `get_column_usage()` tool in Company-MCP repo (Priority 2)
   - Find all tables using a common column (e.g., product_id)
   - Suggest join patterns through bridge tables
   - Group by business domain
2. Enhance `get_join_path()` output with complete SQL and intermediate tables
3. Complete hybrid search integration (FTS5 + vector + RRF)
4. Add context budgeting and compression

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
