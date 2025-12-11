# Indexer Agent Plan - Summary

**Full Plan**: `indexer-agent-plan.md` (detailed implementation with code)
**Version**: 1.3 | **Date**: December 10, 2025

---

## Purpose

The Indexer Agent transforms documentation from the Documenter into a searchable knowledge base. It reads `documentation-manifest.json`, processes markdown files, generates embeddings, and populates a SQLite database with hybrid search capabilities (FTS5 + vector).

## Pipeline Position

```
Planner → Documenter → [INDEXER] → Retriever
                            ↓
                    SQLite Database
```

## Input

- **Primary**: `docs/documentation-manifest.json` (from Documenter)
- **Files**: Markdown docs for tables, columns, domains, relationships, overviews
- **Status**: Manifest must be `complete` or `partial`

## Output

- **Database**: `data/tribal-knowledge.db`
  - `documents` - All doc types with metadata
  - `documents_fts` - FTS5 full-text search index
  - `documents_vec` - Vector embeddings (1536-dim, OpenAI)
  - `relationships` - Join paths between tables (1-hop and multi-hop)
  - `index_weights` - Per-doc-type search weights
  - `index_metadata` - Provenance hashes, counts, timestamps

- **Progress**: `progress/indexer-progress.json` (for resume support)

## Document Types

| Type | Source | Generated From |
|------|--------|----------------|
| `table` | Manifest file | Direct parse |
| `column` | N/A | Generated from table docs |
| `domain` | Manifest file | Direct parse |
| `relationship` | Manifest file | Direct parse |
| `overview` | Manifest file | Direct parse |

## Key Processing Steps

1. **Validate Manifest** - Check files exist, hashes match
2. **Parse Documents** - Route to type-specific parser via `parseDocument()`
3. **Generate Columns** - Create column docs from table docs
4. **Extract Keywords** - Abbreviation expansion, data patterns, nouns
5. **Sort Documents** - Tables before columns (for parent_doc_id linkage)
6. **Generate Embeddings** - OpenAI batch API with retry/fallback
7. **Populate Index** - UPSERT with parent_doc_id for columns
8. **Build Relationships** - FK extraction + BFS multi-hop paths
9. **Optimize** - FTS5 optimize, ANALYZE, VACUUM, metadata

## Critical Design Decisions (v1.3)

### File-to-Document Matching (CRITICAL)
- `getFilePathForDoc()` uses **exact matching** on database + schema + table/domain
- Prevents collisions between similar names (e.g., `orders` vs `orders_archive`)
- Prevents cross-schema confusion (e.g., `public.users` vs `admin.users`)
- `findFilePathForTable()` parses `{schema}.{table}.md` from filename for exact match
- `getDocumentIdentity()` provides deterministic fallback paths when no file match

### Parent-Child Linkage
- Column docs reference parent table via `parent_doc_id`
- Documents sorted before insertion: tables → domains → overviews → relationships → columns
- `parentDocIds` map tracks table IDs for column linkage
- `findFilePathForTable()` used to set correct `parentTablePath` on column docs

### Incremental Indexing
- Uses same `indexFiles()` as full indexing (same ordering/linkage guarantees)
- Cascade deletion: doc → vector → child docs → relationships
- Relationship docs deleted by re-parsing content (not naming convention)

### Resume Support
- Checkpoint every 100 files
- Stable manifest hash via `computeStableManifestHash()` (sorted file hashes)
- Same hash used in `optimizeDatabase()` for Retriever staleness checks

### Embedding Fallback
- If OpenAI fails, continue with FTS-only mode
- `indexWithFallbacks()` handles graceful degradation

## Key Functions

| Function | Purpose |
|----------|---------|
| `parseDocument()` | Main dispatcher to type-specific parsers |
| `indexFiles()` | Complete flow: parse → keywords → embed → populate |
| `populateIndex()` | DB insertion with parent_doc_id linkage |
| `sortDocumentsForIndexing()` | Ensures tables indexed before columns |
| `buildRelationshipsIndex()` | FK extraction + explicit relationship docs |
| `computeMultiHopPaths()` | BFS for 2-3 hop join paths |
| `deleteDocumentsWithCascade()` | Cleanup for incremental re-indexing |
| `computeStableManifestHash()` | Consistent hashing for resume/staleness |

## Helper Functions

| Function | Purpose |
|----------|---------|
| `extractFrontmatter()` | YAML frontmatter parsing (gray-matter) |
| `parseMarkdownSections()` | Split markdown by headings |
| `parseFilePath()` | Extract db/schema/table from path |
| `extractFromSection()` | Find content by heading pattern |
| `createEmbeddingText()` | Generate text for embedding by doc type |
| `getFilePathForDoc()` | Exact file matching by doc type + identifiers |
| `findFilePathForTable()` | Exact table file matching (db + schema + table) |
| `getDocumentIdentity()` | Deterministic identity for fallback paths |

## Error Handling

| Code | Severity | Recoverable |
|------|----------|-------------|
| `IDX_MANIFEST_NOT_FOUND` | fatal | No |
| `IDX_FILE_NOT_FOUND` | error | Yes (skip file) |
| `IDX_EMBEDDING_FAILED` | warning | Yes (FTS-only) |
| `IDX_PARSE_FAILED` | error | Yes (skip file) |

## CLI Interface

```bash
npm run index                    # Full index
npm run index -- --incremental   # Changed files only
npm run index -- --resume        # Continue from checkpoint
npm run index -- --skip-embeddings  # FTS only
npm run index -- --dry-run       # Preview changes
```

## Success Metrics

| Metric | Target |
|--------|--------|
| Throughput | >100 docs/min |
| Embedding success | >99% |
| FTS latency (p95) | <100ms |
| Vector latency (p95) | <200ms |

## Implementation Phases

1. **Foundation** - Types, manifest validation, DB init
2. **Parsers** - Table, domain, overview, relationship, column generation
3. **Keywords** - Identifier splitting, abbreviations, patterns
4. **Embeddings** - OpenAI integration, fallback mode
5. **Index Population** - UPSERT, parent_doc_id, sorting
6. **Relationships** - FK extraction, BFS multi-hop, explicit rel docs
7. **Incremental** - Change detection, cascade delete
8. **Resume** - Checkpoint save/restore, stable hash
9. **Metadata** - Provenance hashes, staleness detection
10. **Testing** - Integration, edge cases, performance

---

*For implementation details and code examples, see the full plan.*
