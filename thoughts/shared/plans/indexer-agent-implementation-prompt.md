# Indexer Agent Implementation Prompt

## Reference Documents

- **Primary Specification**: `thoughts/shared/plans/indexer-agent-plan.md` (v1.3)
- **Quick Reference**: `thoughts/shared/plans/indexer-agent-plan-summary.md`
- **Conflict Resolution**: If any ambiguity arises, the detailed plan (indexer-agent-plan.md) takes precedence over older PRDs or this prompt.

---

## Overview

Implement the **Indexer Agent** — the third module in the Tribal Knowledge pipeline that transforms documentation into a searchable knowledge base. The Indexer reads `docs/documentation-manifest.json`, processes markdown files, generates embeddings, and populates a SQLite database with hybrid search (FTS5 + vector).

```
Planner → Documenter → [INDEXER] → Retriever
                            │
                            ▼
                    SQLite Database
```

---

## Part 1: Core Data Structures

### 1.1 Document Types to Parse

| Type | Source | Notes |
|------|--------|-------|
| `table` | Manifest file → parse markdown | Primary docs; generate column children |
| `column` | Generated from table docs | Virtual docs with `parent_doc_id` linkage |
| `domain` | Manifest file → parse markdown | Domain groupings |
| `relationship` | Manifest file → parse markdown | FK and documented relationships |
| `overview` | Manifest file → parse markdown | Database overviews |

### 1.2 Required Output Schema

Create these tables in `data/tribal-knowledge.db`:

```sql
-- Main documents table
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  doc_type TEXT NOT NULL,           -- 'table'|'column'|'domain'|'relationship'|'overview'
  database_name TEXT NOT NULL,
  schema_name TEXT,
  table_name TEXT,
  column_name TEXT,
  domain TEXT,
  content TEXT NOT NULL,
  summary TEXT,
  keywords TEXT,                    -- JSON array
  file_path TEXT NOT NULL UNIQUE,
  content_hash TEXT NOT NULL,
  indexed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  source_modified_at DATETIME,
  parent_doc_id INTEGER,            -- Column docs → parent table doc
  FOREIGN KEY (parent_doc_id) REFERENCES documents(id) ON DELETE CASCADE
);

-- FTS5 index with triggers (auto-sync on INSERT/UPDATE/DELETE)
CREATE VIRTUAL TABLE documents_fts USING fts5(...);

-- Vector embeddings (1536-dim OpenAI)
CREATE VIRTUAL TABLE documents_vec USING vec0(...);
-- OR fallback: CREATE TABLE documents_vec_fallback (id, embedding BLOB);

-- Relationships (1-hop FK + computed multi-hop)
CREATE TABLE relationships (...);

-- Search weights per doc type
CREATE TABLE index_weights (...);

-- Metadata (MUST persist these keys)
CREATE TABLE index_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
-- Required keys: last_full_index, manifest_hash, plan_hash, document_count,
-- embedding_count, embedding_model, embedding_dimensions, index_version,
-- table_count, column_count, domain_count, relationship_count
```

---

## Part 2: File Identity and Matching (CRITICAL)

### 2.1 Exact Matching Requirements

The implementation MUST use exact matching on all identifying fields to prevent:
- Name collisions (e.g., `orders` vs `orders_archive`)
- Cross-schema confusion (e.g., `public.users` vs `admin.users`)
- Incorrect `content_hash` for change detection
- Broken `parent_doc_id` linkage

### 2.2 Required Helper Functions

**`findFilePathForTable(files: IndexableFile[], tableDoc: ParsedTableDoc): string`**
- Match on: `database` + `schema` + `table` (all three)
- Parse `{schema}.{table}.md` from filename
- Return empty string (with warning log) if no match

**`getFilePathForDoc(doc: ParsedDocument, files: IndexableFile[]): string`**
- Per-doc-type matching logic:
  - `table`: database + schema + table from filename
  - `domain`: database + domain name from filename
  - `relationship`: database + source/target tables in path
  - `overview`: database + contains `/overview`
  - `column`: return `${parentTablePath}#${columnName}` (virtual path)
- **NO `Date.now()` fallbacks** — use `getDocumentIdentity()` for deterministic fallback paths

**`getDocumentIdentity(doc: ParsedDocument): string`**
- Generate deterministic identity string per doc type
- Used when no file match found (fallback path generation)

---

## Part 3: Indexing Pipeline

### 3.1 Full Indexing Flow (`indexFiles`)

Execute these steps in order:

```
1. Parse documents      → parseDocument() dispatcher
2. Generate columns     → generateColumnDocuments() with rawContent
3. Extract keywords     → extractKeywordsForDocument() per type
4. Sort documents       → sortDocumentsForIndexing()
                          Order: tables → domains → overviews → relationships → columns
5. Map parent IDs       → Build parentDocIds map from table file paths
6. Generate embeddings  → embeddingService.generateBatch() with fallback
7. Populate index       → populateIndex(db, docs, embeddings, parentDocIds)
```

### 3.2 Document Sorting (CRITICAL for parent_doc_id)

```typescript
function sortDocumentsForIndexing(documents: ProcessedDocument[]): ProcessedDocument[] {
  const order = { table: 0, domain: 1, overview: 2, relationship: 3, column: 4 };
  return [...documents].sort((a, b) => order[a.docType] - order[b.docType]);
}
```

Tables MUST be indexed before columns so `parent_doc_id` can be resolved.

### 3.3 populateIndex Signature

```typescript
async function populateIndex(
  db: Database,
  documents: ProcessedDocument[],
  embeddings: Map<string, number[]>,
  parentDocIds: Map<string, number>  // parentTablePath → document ID
): Promise<IndexStats>
```

- Track table doc IDs after INSERT for later column linkage
- Resolve `parent_doc_id` for column docs using `parentDocIds` map
- UPSERT with `ON CONFLICT(file_path) DO UPDATE`

---

## Part 4: Document Parsers

### 4.1 Parser Dispatcher

```typescript
async function parseDocument(file: IndexableFile): Promise<ParsedDocument> {
  switch (file.type) {
    case 'table':        return parseTableDocument(file.path, content);
    case 'domain':       return parseDomainDocument(file.path, content);
    case 'overview':     return parseOverviewDocument(file.path, content);
    case 'relationship': return parseRelationshipDocument(file.path, content);
  }
}
```

### 4.2 Required Helpers

- `extractFrontmatter(content)` — Use `gray-matter` library
- `parseMarkdownSections(body)` — Split by `#{1,3}` headings
- `parseFilePath(filePath)` — Extract database/schema/table/domain
- `extractFromSection(sections, pattern)` — Find content by heading

### 4.3 Column Document Generation

Column docs MUST include `rawContent` for embedding text generation:

```typescript
function generateColumnDocuments(tableDoc: ParsedTableDoc, tableFilePath: string): ParsedColumnDoc[] {
  return tableDoc.columns.map(col => ({
    docType: 'column',
    // ... other fields
    parentTablePath: tableFilePath,  // Use findFilePathForTable result
    rawContent: generateColumnRawContent(col, tableDoc)  // REQUIRED
  }));
}
```

### 4.4 Relationship Document Parser

Must extract: `sourceSchema`, `sourceTable`, `sourceColumn`, `targetSchema`, `targetTable`, `targetColumn`, `relationshipType`, `joinCondition`

Try frontmatter first, then parse markdown sections.

---

## Part 5: Keyword Extraction

### 5.1 Per-Type Extraction

```typescript
function extractKeywordsForDocument(doc: ParsedDocument): string[] {
  switch (doc.docType) {
    case 'table':        return extractKeywordsFromTable(doc);
    case 'column':       return doc.keywords; // Already populated
    case 'domain':       return extractKeywordsFromDomain(doc);
    case 'relationship': return extractKeywordsFromRelationship(doc);
    case 'overview':     return extractKeywordsFromOverview(doc);
  }
}
```

### 5.2 Processing Techniques

- `splitIdentifier()` — Split on underscores and camelCase
- `expandAbbreviations()` — Map `cust`→`customer`, `usr`→`user`, etc.
- `extractNounsFromDescription()` — DB terms and capitalized words
- Data type keywords (int→integer/number, varchar→string/text, etc.)
- Constraint keywords (PK→primary key/identifier, FK→foreign key/reference)

---

## Part 6: Embedding Generation

### 6.1 Configuration

- Model: `text-embedding-3-small`
- Dimensions: 1536
- Batch size: 50
- Max retries: 3 with exponential backoff

### 6.2 Embedding Text per Type

```typescript
function createEmbeddingText(doc: ParsedDocument): string {
  // Type-specific handlers for table, column, domain, relationship, overview
  // Fallback: return doc.rawContent
}
```

### 6.3 Fallback Mode

If OpenAI fails, continue with FTS-only mode (`indexWithFallbacks`). Log warning but don't fail the run.

---

## Part 7: Incremental Indexing

### 7.1 Change Detection

Compare manifest `content_hash` against `documents.content_hash` to identify:
- `newFiles` — In manifest, not in DB
- `changedFiles` — In both, hash differs
- `unchangedFiles` — In both, hash matches
- `deletedFiles` — In DB, not in manifest

### 7.2 Incremental Flow (`runIncrementalIndex`)

```typescript
async function runIncrementalIndex(options: IncrementalOptions): Promise<void> {
  const manifest = await validateAndLoadManifest();
  const changes = await detectChanges(manifest, db);

  // 1. Convert file paths to IndexableFile[] from manifest
  const filesToProcess = manifest.indexable_files.filter(f =>
    changes.newFiles.includes(f.path) || changes.changedFiles.includes(f.path)
  );

  // 2. Delete removed files FIRST
  if (changes.deletedFiles.length > 0) {
    await deleteDocumentsWithCascade(db, changes.deletedFiles);
  }

  // 3. Index new/changed files (same indexFiles() as full indexing)
  if (filesToProcess.length > 0) {
    await indexFiles(db, filesToProcess, manifest);
  }

  // 4. Rebuild relationships if table files changed
  const tableFilesChanged = filesToProcess.some(f => f.path.includes('/tables/'));
  if (tableFilesChanged) {
    await buildRelationshipsIndex(db);
  }

  // 5. Optimize database
  await optimizeDatabase(db, manifest);
}
```

### 7.3 Cascade Deletion (`deleteDocumentsWithCascade`)

This is a **pure deletion helper** — does NOT call indexFiles or optimizeDatabase:

1. Delete vector embedding
2. If table doc: delete child column docs and their vectors
3. If table doc: delete relationships (source or target)
4. If relationship doc: re-parse content to get source/target, delete from relationships table
5. Delete the document itself

---

## Part 8: Relationships Index

### 8.1 Build Process

1. Extract FK relationships from table doc content
2. Index explicit relationship documents (doc_type='relationship')
3. Compute multi-hop paths via BFS (max 3 hops)

### 8.2 Multi-Hop Path Computation

```typescript
function bfsShortestPath(graph, source, target, maxHops): JoinPath | null
function generateMultiHopJoinSQL(path: JoinPath): string
function computePathConfidence(path: JoinPath): number  // Decreases with hops
```

---

## Part 9: Resume Support

### 9.1 Checkpoint Strategy

- Save every 100 files
- Use `computeStableManifestHash()` for resume comparison
- Track: `indexed_files`, `failed_files`, `pending_files`, `phase`

### 9.2 Stable Manifest Hash (CRITICAL)

```typescript
function computeStableManifestHash(manifest: DocumentationManifest): string {
  const fileHashes = manifest.indexable_files
    .map(f => `${f.path}:${f.content_hash}`)
    .sort()
    .join('|');
  return computeSHA256(`${manifest.plan_hash}|${fileHashes}`);
}
```

Do NOT use `JSON.stringify()` directly — key order is not guaranteed.

### 9.3 The same stable hash MUST be used in:
- `initializeProgress()` — when starting fresh
- `runIndexerWithResume()` — for checkpoint comparison
- `optimizeDatabase()` — persisted to `index_metadata.manifest_hash`

---

## Part 10: CLI Interface

### 10.1 Required Commands

```bash
npm run index                     # Full index
npm run index -- --incremental    # Changed files only
npm run index -- --resume         # Continue from checkpoint
npm run index -- --force          # Ignore checkpoint, fresh start
npm run index -- --status         # Show checkpoint/index status
npm run index -- --dry-run        # Preview changes only
npm run index -- --skip-embeddings # FTS only, no OpenAI calls
npm run index -- --work-unit <n>  # Process specific work unit

npm run index:verify              # Verify index integrity
npm run index:stats               # Show index statistics
```

### 10.2 Progress File

Location: `progress/indexer-progress.json`

---

## Part 11: Metadata Persistence

### 11.1 Required index_metadata Keys

After `optimizeDatabase()`, these MUST be persisted:

| Key | Value |
|-----|-------|
| `last_full_index` | ISO timestamp |
| `manifest_hash` | From `computeStableManifestHash()` |
| `plan_hash` | From `manifest.plan_hash` |
| `document_count` | Total documents |
| `embedding_count` | Documents with embeddings |
| `embedding_model` | `text-embedding-3-small` |
| `embedding_dimensions` | `1536` |
| `index_version` | `1.0` |
| `table_count` | Table documents |
| `column_count` | Column documents |
| `domain_count` | Domain documents |
| `relationship_count` | Relationship records |

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] TypeScript types for all interfaces
- [ ] Database schema creation and migrations
- [ ] Manifest validation (`validateAndLoadManifest`)

### Phase 2: Parsers
- [ ] `parseTableDocument` with column extraction
- [ ] `parseDomainDocument`
- [ ] `parseOverviewDocument`
- [ ] `parseRelationshipDocument`
- [ ] `generateColumnDocuments` with `rawContent`
- [ ] Helper functions (extractFrontmatter, parseMarkdownSections, etc.)

### Phase 3: File Matching
- [ ] `findFilePathForTable` (exact match on db+schema+table)
- [ ] `getFilePathForDoc` (per-type matching, no Date.now fallbacks)
- [ ] `getDocumentIdentity` (deterministic fallback paths)

### Phase 4: Keywords & Embeddings
- [ ] Per-type keyword extraction
- [ ] `splitIdentifier`, `expandAbbreviations`
- [ ] OpenAI embedding service with retry/fallback
- [ ] `createEmbeddingText` per doc type

### Phase 5: Indexing
- [ ] `sortDocumentsForIndexing`
- [ ] `indexFiles` (complete flow)
- [ ] `populateIndex` with `parentDocIds` map
- [ ] FTS5 triggers

### Phase 6: Relationships
- [ ] FK extraction from table content
- [ ] `indexExplicitRelationshipDocs`
- [ ] BFS multi-hop computation
- [ ] `generateMultiHopJoinSQL`

### Phase 7: Incremental
- [ ] `detectChanges`
- [ ] `runIncrementalIndex`
- [ ] `deleteDocumentsWithCascade`

### Phase 8: Resume
- [ ] `computeStableManifestHash`
- [ ] Checkpoint save/restore
- [ ] `runIndexerWithResume`

### Phase 9: CLI & Metadata
- [ ] All CLI flags
- [ ] `optimizeDatabase` with metadata persistence
- [ ] index:verify, index:stats commands

---

## Error Handling

| Code | Severity | Recoverable |
|------|----------|-------------|
| `IDX_MANIFEST_NOT_FOUND` | fatal | No |
| `IDX_MANIFEST_INVALID` | fatal | No |
| `IDX_FILE_NOT_FOUND` | error | Yes (skip file) |
| `IDX_FILE_HASH_MISMATCH` | warning | Yes (re-hash) |
| `IDX_PARSE_FAILED` | error | Yes (skip file) |
| `IDX_EMBEDDING_FAILED` | warning | Yes (FTS-only) |
| `IDX_DATABASE_ERROR` | error | Depends |

---

## Testing Requirements

- Unit tests for all parsers
- Unit tests for file matching helpers (especially edge cases)
- Integration test: full index → verify → incremental → verify
- Edge cases: empty manifest, missing files, embedding failures, resume after crash
