# System Patterns: Tribal Knowledge Deep Agent

## Architecture Overview

The system follows a **deep agent architecture** with explicit planning, sub-agent delegation, filesystem-based persistent memory, and configurable system prompts. Each agent has a single responsibility and communicates through the filesystem and SQLite database.

**Architecture Style**: Deep Agent Pipeline with Planning

**Communication Pattern**: Filesystem-based (agents read/write files and database)

**Execution Model**: Plan → Execute → Index → Serve (manual triggers, no autonomous behavior)

## Component Architecture

### Agent Chain

```
Planner (Schema Analyzer) 
  → Documenter (with sub-agents)
    → Indexer
      → Retriever (MCP Server)
```

### 1. Planner: Schema Analyzer

**Responsibility**: Analyze database structure, detect domains, create documentation plan

**Input**: 
- `config/databases.yaml` - Database catalog configuration
- Environment credentials

**Output**: 
- `progress/documentation-plan.json` - Prioritized table list with domain assignments

**Key Pattern**: 
- Pre-analysis before expensive documentation phase
- Domain-based grouping for parallelization
- Content hashing for change detection

### 2. Documenter (Agent 1)

**Responsibility**: Execute documentation plan using sub-agents

**Input**: 
- `progress/documentation-plan.json`
- Prompt templates from `/prompts`

**Output**: 
- Markdown, JSON Schema, YAML files in `/docs`
- `progress/documenter-progress.json`
- `docs/documentation-manifest.json` (handoff to Indexer)

**Sub-agents**:
- **TableDocumenter**: Handles complete documentation of a single table
- **ColumnInferencer**: Generates semantic description for a single column
- **SemanticEnricher**: Infers semantic roles, typical joins, and analysis patterns for tables

**Key Pattern**:
- Sub-agent delegation for repeated tasks
- Context quarantine (sub-agents return summaries, not raw data)
- Parallel processing of work units (domains)
- **Semantic enrichment**: Rule-based + LLM inference for table roles and join patterns
- **Cross-domain analysis**: Post-processing step generates relationship maps after all tables documented

### 3. Indexer (Agent 2)

**Responsibility**: Parse documentation, extract keywords, generate embeddings, build search index

**Input**: 
- `docs/documentation-manifest.json`
- Documentation files from `/docs`

**Output**: 
- Populated SQLite database (`data/tribal-knowledge.db`)
- FTS5 full-text search index
- Vector embeddings (sqlite-vec)
- `progress/indexer-progress.json`

**Key Pattern**:
- Incremental re-indexing via content hash comparison
- Hybrid search preparation (FTS5 + vectors)
- Batch embedding generation
- **Embedding key consistency**: Embeddings stored with document identity keys (`db.schema.table`), looked up by both file path and identity
- **FK extraction**: Regex patterns match Unicode arrow format from TableDocumenter (`` `col` → `table.col` ``)
- **Schema alignment**: `documents_vec` uses `document_id` column (not `id`) for test compatibility
- **Token limit guards**: Enhanced 8k token limit handling with conservative character-per-token estimates

### 4. Retriever (Agent 3) - MCP Server

**Responsibility**: Handle search queries, perform hybrid search, return context-aware results

**Input**: 
- MCP tool calls from external agents
- SQLite database

**Output**: 
- Structured JSON responses with search results
- Token-counted responses

**Key Pattern**:
- Stateless (reads from database)
- Context budget management
- Response compression
- Hybrid search (FTS5 + vector + RRF)

## Data Flow Patterns

### Planning Phase
1. Load `databases.yaml`
2. Connect to each database
3. Count tables, analyze relationships
4. Detect domains (via LLM)
5. Generate prioritized plan
6. Write `documentation-plan.json`

### Documentation Phase
1. Read plan, iterate through work units (domains)
2. For each table in work unit:
   - Spawn TableDocumenter sub-agent
   - TableDocumenter spawns ColumnInferencer per column
   - TableDocumenter spawns SemanticEnricher for semantic metadata
   - Assemble markdown and JSON (with semantic metadata), write to `/docs`
3. Update progress, continue to next table
4. Generate manifest when complete
5. **Post-processing**: Generate cross-domain relationship maps for each database

### Indexing Phase
1. Read manifest, validate files exist
2. Parse each documentation file
3. Extract keywords, generate embeddings (batch)
4. Populate SQLite (documents, FTS5, vectors)
5. Update progress

### Retrieval Phase
1. Receive MCP tool call
2. Parse query (optional LLM understanding)
3. Execute hybrid search (FTS5 + vector)
4. Combine with RRF
5. Apply weights, filter, compress
6. Return structured response

## Storage Architecture

### Filesystem (Human-Readable)
```
/docs/
├── databases/
│   ├── {db}/
│   │   ├── domains/{domain}/
│   │   │   └── tables/{schema}.{table}.md (with semantic metadata)
│   │   │   └── tables/{schema}.{table}.json (with semantic_roles, typical_joins, analysis_patterns)
│   │   ├── cross_domain_relationships.md (domain connection maps)
│   │   └── er-diagrams/
├── documentation-manifest.json

/progress/
├── documentation-plan.json
├── documenter-progress.json
├── indexer-progress.json
└── work_units/{id}/progress.json

/prompts/
├── column-description.md
├── table-description.md
├── domain-inference.md
└── query-understanding.md
```

### SQLite (Machine-Searchable)
```
tribal-knowledge.db
├── documents (id, type, content, metadata)
├── documents_fts (FTS5 virtual table)
├── documents_vec (vector embeddings, uses document_id column)
├── relationships (join paths)
└── keywords (extracted terms)
```

**Schema Note**: `documents_vec` uses `document_id` (not `id`) as the primary key column for test compatibility.

## Design Patterns

### 1. Deep Agent Pattern
- **Planning**: Explicit planning phase before execution
- **Sub-agents**: Specialized workers for repeated tasks
- **File System Memory**: Persistent state via filesystem
- **Configurable Prompts**: External prompt templates

### 2. Contract-Based Handoffs
- Planner → Documenter: `documentation-plan.json`
- Documenter → Indexer: `documentation-manifest.json`
- Indexer → Retriever: SQLite database

Each contract includes:
- Status (completed, partial, failed)
- Content hashes for change detection
- Metadata for validation

### 3. Domain-Based Parallelization
- Tables grouped into business domains
- Each domain = independent work unit
- Work units processed in parallel
- Enables scalable processing

### 4. Hybrid Search Pattern
- **FTS5**: Keyword matching with BM25 ranking
- **Vector**: Semantic similarity with cosine distance
- **RRF**: Reciprocal Rank Fusion to combine results
- **Weights**: Document type boosts (tables > columns)

### 5. Context Quarantine
- Sub-agents return summaries, not raw data
- Prevents context pollution
- Enables parallel processing
- Reduces token usage

### 6. Incremental Processing
- Content hashes at every level
- Compare hashes to detect changes
- Only re-process changed components
- Supports partial updates

### 7. Checkpoint Recovery
- Progress files track state
- Can resume after interruption
- Partial success is valid
- Errors isolated to components

### 8. Semantic Metadata Pattern
- **Rule-based inference**: Pattern matching on table/column names and structure
- **LLM enrichment**: LLM refines semantic roles and analysis patterns
- **Merge strategy**: Combine rule-based (accurate) with LLM (nuanced)
- **Output**: semantic_roles, typical_joins, analysis_patterns in every table doc
- **Use case**: Enables AI assistants to understand table purposes and suggest joins

### 9. Cross-Domain Relationship Discovery
- **Post-processing**: Runs after all tables documented
- **FK analysis**: Finds foreign keys crossing domain boundaries
- **Common column detection**: Identifies implicit joins through shared columns
- **LLM use cases**: Generates business use cases for each domain pair
- **Output**: Markdown map file per database showing domain connections

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Storage** | Filesystem + SQLite | Human-readable docs + fast search |
| **Search** | FTS5 + Vector + RRF | Proven hybrid approach |
| **Embeddings** | OpenAI → sqlite-vec | Start simple, scale later |
| **ER Diagrams** | Domain-grouped Mermaid | Readable for large schemas |
| **MCP Integration** | Tools in Noah's MCP | Single integration point |
| **Context Budget** | Adaptive per query | Efficient token usage |
| **Planning** | Schema Analyzer first | Understand before documenting |
| **Sub-agents** | Table + Column workers | Isolate repeated tasks |
| **Prompts** | External /prompts/ dir | Editable without code changes |

## Component Relationships

```
Planner
  ├─→ Reads: databases.yaml
  ├─→ Uses: domain-inference.md prompt
  └─→ Writes: documentation-plan.json

Documenter
  ├─→ Reads: documentation-plan.json
  ├─→ Uses: column-description.md, table-description.md
  ├─→ Spawns: TableDocumenter, ColumnInferencer, SemanticEnricher
  ├─→ Post-processes: CrossDomainRelationshipGenerator
  └─→ Writes: /docs/* (with semantic metadata), cross_domain_relationships.md, documentation-manifest.json

Indexer
  ├─→ Reads: documentation-manifest.json, /docs/*
  ├─→ Uses: OpenAI embeddings API
  └─→ Writes: tribal-knowledge.db

Retriever
  ├─→ Reads: tribal-knowledge.db
  ├─→ Uses: query-understanding.md (optional)
  └─→ Exposes: MCP tools
```

## Error Handling Patterns

1. **Isolate Failures**: Failed table doesn't fail work unit; failed work unit doesn't fail job
2. **Partial Success**: Prefer 90% documented over 0%
3. **Explicit Status**: Every contract file has clear status field
4. **Downstream Continues**: Indexer can index partial docs; Retriever can search partial index
5. **Retry Logic**: Connection timeouts and API errors retry with backoff
6. **Hash Detection**: Content hashes enable incremental re-processing

## Integration Points

- **PostgreSQL**: Via `pg` library, connection strings
- **Snowflake**: Via `snowflake-sdk`, connection parameters
- **OpenAI**: Embeddings API (text-embedding-3-small)
- **Anthropic**: Claude API for semantic inference
- **MCP**: Model Context Protocol for tool exposure
- **Noah's Company MCP**: External agent interface
