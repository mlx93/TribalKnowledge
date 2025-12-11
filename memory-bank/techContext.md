# Technical Context: Tribal Knowledge Deep Agent

## Technologies Used

### Core Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| Runtime | Node.js | 20 LTS | JavaScript execution |
| Language | TypeScript | 5.x | Type safety, maintainability |
| Database | SQLite | 3.x | Local persistent storage |
| Full-Text Search | FTS5 | (SQLite built-in) | Keyword search |
| Vector Search | sqlite-vec | 0.1.x | Embedding similarity |
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

### Project Structure

**Actual Implementation Location**: `TribalAgent/` directory

```
TribalAgent/
├── src/
│   ├── agents/
│   │   ├── planner/             # ✅ Schema Analyzer (IMPLEMENTED)
│   │   │   ├── index.ts
│   │   │   ├── analyze-database.ts
│   │   │   ├── domain-inference.ts
│   │   │   ├── generate-work-units.ts
│   │   │   ├── metrics.ts
│   │   │   └── staleness.ts
│   │   ├── indexer/             # ✅ Agent 2 (IMPLEMENTED)
│   │   │   ├── index.ts
│   │   │   ├── embeddings.ts
│   │   │   ├── keywords.ts
│   │   │   ├── populate.ts
│   │   │   ├── relationships.ts
│   │   │   ├── parsers/
│   │   │   └── database/
│   │   ├── documenter/          # ⏳ Agent 1 (PENDING - sub-agents exist)
│   │   │   ├── sub-agents/
│   │   │   │   ├── TableDocumenter.ts
│   │   │   │   └── ColumnInferencer.ts
│   │   └── retrieval/           # ⏳ Agent 3 (PENDING - hybrid search exists)
│   │       └── search/
│   │           └── hybrid-search.ts
│   ├── connectors/              # ✅ Database connectors (IMPLEMENTED)
│   │   ├── postgres.ts
│   │   └── snowflake.ts
│   ├── contracts/               # ✅ Type definitions (IMPLEMENTED)
│   ├── utils/                   # ✅ Shared utilities (IMPLEMENTED)
│   ├── config/                  # ✅ Configuration (IMPLEMENTED)
│   └── cli/                     # ✅ CLI commands (IMPLEMENTED)
├── config/
│   ├── databases.yaml           # Database catalog
│   └── agent-config.yaml        # Agent configuration
├── prompts/                     # ✅ Prompt templates (IMPLEMENTED)
│   ├── column-description.md
│   ├── table-description.md
│   ├── domain-inference.md
│   └── query-understanding.md
├── dist/                        # ✅ Compiled TypeScript output
├── tests/                       # ✅ Test files (Planner & Indexer)
├── package.json                 # ✅ Dependencies configured
└── tsconfig.json                # ✅ TypeScript config
```

### Environment Variables

**Required**:
- `OPENAI_API_KEY` - OpenAI API key for embeddings
- `ANTHROPIC_API_KEY` - Anthropic API key for inference

**Optional**:
- `TRIBAL_DOCS_PATH` - Documentation output directory (default: `./docs`)
- `TRIBAL_DB_PATH` - SQLite database path (default: `./data/tribal-knowledge.db`)
- `TRIBAL_PROMPTS_PATH` - Prompt templates directory (default: `./prompts`)
- `TRIBAL_LOG_LEVEL` - Logging verbosity (default: `info`)

### Configuration Files

**databases.yaml** (Catalog Configuration):
```yaml
databases:
  - name: production_postgres
    type: postgres
    connection_env: POSTGRES_CONNECTION_STRING
    schemas: [public, analytics]
    exclude_tables: [temp_*, _old_*]
```

**agent-config.yaml** (Agent Behavior):
```yaml
planner:
  enabled: true
  domain_inference: true
documenter:
  concurrency: 5
  sample_timeout_ms: 5000
  llm_model: claude-sonnet-4
  checkpoint_interval: 10
indexer:
  batch_size: 50
  embedding_model: text-embedding-3-small
  checkpoint_interval: 100
retrieval:
  default_limit: 5
  max_limit: 20
  context_budgets:
    simple: 750
    moderate: 1500
    complex: 3000
  rrf_k: 60
  use_query_understanding: false
```

## Technical Constraints

### Database Access
- Requires read access to metadata (information_schema)
- Requires SELECT on target tables (for sampling)
- Connection via environment variables (never hardcoded)

### API Constraints
- OpenAI embeddings: Batch size 50, rate limits apply
- Claude API: Token limits, rate limits
- Exponential backoff on 429 errors

### Storage Constraints
- Local filesystem for documentation
- SQLite database size limits (practical: ~100GB)
- Vector dimensions: 1536 (OpenAI text-embedding-3-small)

### Performance Constraints
- Planning: < 30 seconds for 100 tables
- Documentation: < 5 minutes for 100 tables
- Indexing: < 2 minutes for 100 tables
- Search: < 500ms p95 latency

## Dependencies

### Production Dependencies
- Node.js 20 LTS
- TypeScript 5.x
- SQLite 3.x (via better-sqlite3)
- PostgreSQL client (pg)
- Snowflake SDK
- OpenAI SDK
- Anthropic SDK
- MCP SDK
- YAML parser (js-yaml)
- Validation (zod)
- CLI framework (commander)

### Development Dependencies
- TypeScript compiler
- Testing framework (TBD)
- Linting (ESLint)
- Formatting (Prettier)

## Database Schema Details

### SQLite Database: tribal-knowledge.db

**documents table**:
- Stores all indexed documentation
- Types: table, column, relationship, domain
- Includes content, summary, keywords, metadata

**documents_fts** (FTS5 virtual table):
- Full-text search index
- Tokenizer: porter (stemming)
- Indexed: content, summary, keywords

**documents_vec** (sqlite-vec):
- Vector embeddings (1536 dimensions)
- Cosine similarity distance
- Linked to documents.id

**relationships table**:
- Pre-computed join paths
- Includes SQL snippets
- Confidence scores

## Integration Details

### PostgreSQL Integration
- Connection: Connection string format
- Metadata queries: information_schema views
- Sampling: TABLESAMPLE or ORDER BY RANDOM()
- Permissions: SELECT on metadata and tables

### Snowflake Integration
- Connection: Connection parameters object
- Metadata queries: INFORMATION_SCHEMA views
- Sampling: SAMPLE clause
- Permissions: USAGE on database/schemas, SELECT on tables

### OpenAI Integration
- Endpoint: Embeddings API
- Model: text-embedding-3-small (1536 dims)
- Batch size: 50 documents
- Rate limiting: Exponential backoff

### Claude Integration
- Model: claude-sonnet-4
- Use cases: Column/table descriptions, domain inference, query understanding
- Prompt loading: Templates from /prompts directory

### MCP Integration
- Protocol: Model Context Protocol
- Communication: stdio or HTTP
- Tool registration: Export tool definitions
- Integration point: Noah's Company MCP

## Development Workflow

### CLI Commands

**Location**: Run commands from `TribalAgent/` directory

| Command | Status | Description |
|---------|--------|-------------|
| `npm run build` | ✅ Working | Compile TypeScript to JavaScript |
| `npm run plan` | ✅ Working | Run Schema Analyzer, generate documentation-plan.json |
| `npm run plan:validate` | ✅ Working | Validate documentation plan |
| `npm run document` | ⏳ Pending | Execute documentation using plan (Documenter not implemented) |
| `npm run index` | ✅ Working | Index documentation into SQLite |
| `npm run serve` | ⏳ Pending | Start MCP server (Retriever not implemented) |
| `npm run pipeline` | ⏳ Partial | Run plan → document → index (document step pending) |
| `npm run status` | ✅ Working | Show current progress |
| `npm run validate-prompts` | ✅ Working | Validate prompt template syntax |
| `npm test` | ✅ Working | Run unit tests (Vitest) |
| `npm run test:integration` | ✅ Working | Run integration tests |

### Development Process

**Current State**: Planner and Indexer are implemented and working

1. ✅ Clone repository, install dependencies (`cd TribalAgent && npm install`)
2. ✅ Copy example config files, set environment variables
3. ✅ Create or customize prompt templates in `prompts/`
4. ✅ Run `npm run validate-prompts` to verify templates
5. ✅ Run `npm run plan` to analyze target databases (WORKING)
6. ✅ Review `progress/documentation-plan.json`
7. ⏳ Run `npm run document` to generate docs (PENDING - Documenter not implemented)
8. ✅ Run `npm run index` to build search index (WORKING - if docs exist)
9. ⏳ Run `npm run serve` to start MCP server (PENDING - Retriever not implemented)
10. ⏳ Test with MCP client (PENDING)

**Note**: Full pipeline blocked until Documenter is implemented. Planner and Indexer are production-ready.

## Testing Strategy

### Unit Testing
- Schema analysis logic
- Metadata extraction
- Semantic inference
- Keyword extraction
- Embedding generation
- FTS5 indexing
- Vector search
- RRF ranking
- Prompt loading

### Integration Testing
- End-to-end PostgreSQL flow
- End-to-end Snowflake flow
- Multi-database support
- MCP integration
- Large schema handling
- Incremental updates
- Prompt customization

### Performance Testing
- Planning speed (10/50/100/500 tables)
- Documentation speed
- Indexing speed
- Search latency
- Memory usage

## Deployment Considerations

### Current: Local Development
- Single-user operation
- Local filesystem storage
- Manual triggers
- Development-focused

### Future Considerations
- Cloud-hosted deployment
- Multi-user concurrent access
- Scheduled re-documentation
- Schema change detection
- Pinecone migration (from sqlite-vec)

## Known Technical Challenges

1. **Large Schema Performance**: Chunked processing, sub-agent parallelism
2. **API Cost Management**: Batch requests, cache results
3. **MCP Integration Complexity**: Early integration testing required
4. **Snowflake Connector**: Reference existing implementations
5. **Vector Store Migration**: Abstraction layer for future Pinecone migration
