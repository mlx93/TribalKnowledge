# Technical Context: Tribal Knowledge Deep Agent

## Technologies Used

### Core Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| Runtime | Node.js | 20 LTS | JavaScript execution |
| Language | TypeScript | 5.x | Type safety, maintainability |
| Database | SQLite | 3.x | Local persistent storage |
| Full-Text Search | FTS5 | (SQLite built-in) | Keyword search |
| Vector Search | sqlite-vec | 0.1.x | Embedding similarity (native vec0) |
| MCP SDK | @modelcontextprotocol/sdk | Latest | Tool server implementation |

### External Services

| Service | Provider | Purpose | Fallback |
|---------|----------|---------|----------|
| Embeddings | OpenAI text-embedding-3-small | Document vectorization | None (required) |
| Semantic Inference | Claude Sonnet 4 | Column/table descriptions | Basic name parsing |
| Source Database | PostgreSQL | Data source | N/A |
| Source Database | Snowflake | Data source | N/A |

### Key Libraries

| Library | Purpose |
|---------|---------|
| pg | PostgreSQL connection and queries |
| snowflake-sdk | Snowflake connection and queries |
| better-sqlite3 | SQLite database driver |
| sqlite-vec | Vector operations extension (native) |
| openai | OpenAI API client for embeddings |
| @anthropic-ai/sdk | Claude API for semantic inference |
| js-yaml | YAML parsing and generation |
| zod | Runtime type validation |
| commander | CLI argument parsing |

## Development Setup

### Prerequisites

- Node.js 20 LTS
- npm or yarn
- Access to PostgreSQL and/or Snowflake databases
- OpenAI API key
- Anthropic API key
- sqlite-vec extension (optional, blob fallback available)

### sqlite-vec Installation (macOS)

```bash
# Clone and build
git clone https://github.com/asg017/sqlite-vec.git
cd sqlite-vec
make loadable

# Copy to project (or system path)
mkdir -p /path/to/TribalAgent/node_modules/sqlite-vec/dist
cp dist/vec0.dylib /path/to/TribalAgent/node_modules/sqlite-vec/dist/
```

Or use the helper script: `./build-sqlite-vec.sh`

The indexer searches these paths for the extension:
- `node_modules/sqlite-vec-darwin-arm64/vec0`
- `node_modules/sqlite-vec-darwin-x64/vec0`
- `node_modules/sqlite-vec/dist/vec0`
- `sqlite-vec/dist/vec0`
- `/usr/local/lib/sqlite-vec/vec0`

### Project Structure

**Location**: `TribalAgent/` directory

```
TribalAgent/
├── src/
│   ├── agents/
│   │   ├── planner/             # ✅ Schema Analyzer (COMPLETE)
│   │   ├── documenter/          # ✅ Documentation Generator (COMPLETE)
│   │   │   ├── sub-agents/
│   │   │   │   ├── TableDocumenter.ts
│   │   │   │   └── ColumnInferencer.ts
│   │   ├── indexer/             # ✅ Search Index Builder (COMPLETE)
│   │   │   ├── database/
│   │   │   │   └── init.ts      # SQLite + sqlite-vec setup
│   │   │   ├── embeddings.ts
│   │   │   ├── parsers/
│   │   └── retrieval/           # ⏳ MCP Server (PENDING)
│   │       └── search/
│   │           └── hybrid-search.ts
│   ├── connectors/              # ✅ Database connectors
│   ├── contracts/               # ✅ Type definitions
│   ├── utils/                   # ✅ Shared utilities
│   ├── config/                  # ✅ Configuration
│   └── cli/                     # ✅ CLI commands
├── prompts/                     # ✅ Prompt templates
├── data/                        # Output: tribal-knowledge.db
├── docs/                        # Output: Generated documentation
├── progress/                    # Output: Plan and checkpoints
├── dist/                        # Compiled TypeScript
└── tests/                       # Test files
```

### Environment Variables

**Required** (in `.env` file):
- `OPENAI_API_KEY` - OpenAI API key for embeddings
- `ANTHROPIC_API_KEY` - Anthropic API key for inference
- `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DATABASE`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USERNAME`, `SNOWFLAKE_PASSWORD`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_REGION`

**Note**: Database credentials are stored in `.env` and referenced in `config/databases.yaml` using `${VAR_NAME}` syntax. The Planner and Documenter both support environment variable substitution via `substituteEnvVars()` functions.

**Optional**:
- `TRIBAL_DOCS_PATH` - Documentation output directory (default: `./docs`)
- `TRIBAL_DB_PATH` - SQLite database path (default: `./data/tribal-knowledge.db`)
- `TRIBAL_LOG_LEVEL` - Logging verbosity (default: `info`)

## CLI Commands

Run from `TribalAgent/` with `npx dotenv-cli` prefix:

### Pipeline Commands
| Command | Description |
|---------|-------------|
| `npm run pipeline` | Full pipeline: plan → document → index |
| `npm run pipeline:fresh` | Clear all caches, then full pipeline |

### Individual Agents
| Command | Description |
|---------|-------------|
| `npm run plan` | Generate documentation plan |
| `npm run plan:validate` | Validate an existing plan |
| `npm run document` | Generate documentation (uses cache) |
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

## Database Schema

### SQLite Database: data/tribal-knowledge.db

```sql
-- Main document storage
CREATE TABLE documents (
  id INTEGER PRIMARY KEY,
  doc_type TEXT,           -- 'table', 'column', 'relationship', 'domain'
  database_name TEXT,
  schema_name TEXT,
  table_name TEXT,
  column_name TEXT,
  domain TEXT,
  content TEXT,            -- Full markdown
  summary TEXT,            -- Compressed for retrieval
  keywords TEXT,           -- JSON array
  file_path TEXT UNIQUE,
  content_hash TEXT,
  indexed_at DATETIME,
  parent_doc_id INTEGER
);

-- FTS5 full-text search
CREATE VIRTUAL TABLE documents_fts USING fts5(
  content, summary, keywords,
  content=documents,
  tokenize='porter unicode61'
);

-- Vector embeddings (sqlite-vec)
-- NOTE: Uses document_id (not id) to match expected schema for test compatibility
CREATE VIRTUAL TABLE documents_vec USING vec0(
  document_id INTEGER PRIMARY KEY,
  embedding float[1536]
);

-- Or blob fallback if sqlite-vec unavailable:
CREATE TABLE documents_vec (
  document_id INTEGER PRIMARY KEY,
  embedding BLOB NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);

-- Relationships and join paths
CREATE TABLE relationships (
  source_table TEXT,
  target_table TEXT,
  join_sql TEXT,
  confidence REAL,
  hop_count INTEGER
);
```

## Technical Constraints

### Performance Targets
- Planning: < 30 seconds for 100 tables
- Documentation: ~3 minutes for 41 tables (parallelized)
- Indexing: < 2 minutes for 100 documents
- Search: < 500ms p95 latency

### API Constraints
- OpenAI embeddings: 8192 token limit per request, rate limits apply
  - Conservative limit: 7500 tokens per document (~30,000 chars at 4 chars/token)
  - Automatic splitting with chunk averaging for oversized documents
  - Enhanced error handling for context window exceeded errors
- Claude API: Token limits, rate limits
- Document splitting for texts > 30,000 characters (conservative estimate)

### Parallelization
- Table processing: Batch size 3
- Column inference: Batch size 5
- Max theoretical concurrent LLM calls: 15

### Storage
- Vector dimensions: 1536 (OpenAI text-embedding-3-small)
- sqlite-vec with native vec0 for fast similarity search
- Blob fallback for compatibility (slower but functional)

## Integration Details

### PostgreSQL
- Connection: Environment variables
- Metadata: information_schema views
- Sampling: SELECT * FROM table LIMIT 100

### Snowflake
- Connection: snowflake-sdk with account/user/password
- Metadata: INFORMATION_SCHEMA views
- Column normalization: Uppercase names converted
- Logging: Configured to WARN level to reduce verbosity (`snowflake.configure({ logLevel: 'WARN' })`)

### OpenAI Embeddings
- Model: text-embedding-3-small (1536 dimensions)
- Token-aware batching: ~7000 tokens per batch
- Document splitting: Large docs split at sentence boundaries (30,000 char limit)
- Embedding averaging: Split chunks averaged back to single embedding
- Error handling: Explicit guards for 8k token context window with detailed logging
- Character-per-token estimate: Conservative 4 chars/token (was 3) for safety margin
- **Storage format**: 
  - vec0 virtual table: Embeddings stored as JSON arrays using direct SQL with `vec_f32()` function
    - Format: `INSERT INTO documents_vec (document_id, embedding) VALUES (${docId}, vec_f32('${escapedJson}'))`
    - **Critical**: vec0's `float[1536]` column type doesn't support parameterized queries - must use direct SQL construction
    - JSON strings are escaped (single quotes doubled) to prevent SQL injection
    - Uses `db.exec()` instead of prepared statements for vec0 inserts
  - Blob fallback: Embeddings stored as BLOB (float32 array) using parameterized queries
  - Code automatically detects vec0 availability and uses appropriate format

### Claude Inference
- Model: claude-sonnet-4
- Use cases: Column descriptions, table descriptions, domain inference
- Retry with exponential backoff on failures
- Fallback descriptions when LLM fails

## Known Technical Challenges

1. **sqlite-vec Installation**: Requires manual build on macOS (see `build-sqlite-vec.sh`)
2. **Token Limits**: Large documents need splitting before embedding (8k limit enforced)
3. **API Costs**: Batch requests, use checkpoints to avoid re-processing
4. **Snowflake Column Names**: Uppercase normalization required
5. **Schema Compatibility**: `documents_vec` uses `document_id` column (not `id`) for test compatibility - migration script available
6. **vec0 Parameter Binding**: vec0's `float[1536]` column type doesn't support parameterized queries with `vec_f32()` function - must use direct SQL construction with proper escaping

## Migration and Maintenance

### Converting Existing Databases
If you have an existing database with the old `id` column in `documents_vec`, use the migration script:
```bash
npm run index:migrate-vec0
```
This will:
- Backup your database
- Drop the old blob-based table
- Create vec0 virtual table with `document_id` column
- Require re-indexing to populate embeddings

### Recent Schema Changes (December 11, 2025)
- `documents_vec` column renamed: `id` → `document_id`
- Affects: `init.ts`, `populate.ts`, `hybrid-search.ts`, `incremental.ts`, `optimize.ts`
- Migration script: `scripts/migrate-vec-to-vec0.ts`

### vec0 Insert Implementation (December 11, 2025)
- **Critical Fix**: vec0's `float[1536]` column type requires direct SQL construction, not parameterized queries
- **Implementation**: 
  ```typescript
  const embeddingJson = JSON.stringify(embedding);
  const escapedJson = embeddingJson.replace(/'/g, "''");
  const insertSql = `INSERT INTO documents_vec (document_id, embedding) VALUES (${docId}, vec_f32('${escapedJson}'))`;
  db.exec(insertSql);
  ```
- **Why**: Parameterized queries with `vec_f32(?)` fail with "Only integers are allowed for primary key values" error
- **Security**: JSON strings are escaped to prevent SQL injection (single quotes doubled)
- **Fallback**: When vec0 unavailable, uses BLOB storage with parameterized queries (works fine)
