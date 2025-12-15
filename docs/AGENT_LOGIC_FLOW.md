# Agent Logic Flow Documentation

## Overview

The Tribal Knowledge system uses a **Deep Agent Pipeline** architecture where three agents work in sequence:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        TRIBAL KNOWLEDGE PIPELINE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────┐      ┌─────────────┐      ┌─────────┐      ┌──────────┐    │
│   │ PLANNER  │ ──▶  │ DOCUMENTER  │ ──▶  │ INDEXER │ ──▶  │ RETRIEVER│    │
│   └──────────┘      └─────────────┘      └─────────┘      └──────────┘    │
│       │                   │                   │                            │
│       ▼                   ▼                   ▼                            │
│   documentation-      docs/*.md/json     tribal-                          │
│   plan.json          manifest.json       knowledge.db                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Planner (Schema Analyzer)

### Purpose
The Planner connects to databases, analyzes their structure, detects business domains using LLM, and creates a documentation plan with **WorkUnits** that enable parallel processing.

### Logic Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            PLANNER FLOW                                     │
└─────────────────────────────────────────────────────────────────────────────┘

                     ┌─────────────────────────┐
                     │   1. Load Configuration  │
                     │   (databases.yaml)       │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 2. Compute Config Hash   │
                     │ (for change detection)   │
                     └───────────┬─────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
    ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
    │ 3a. Check for   │ │ Is plan fresh?  │ │ Config changed? │
    │ existing plan   │ │ Return existing │ │ Schema drift?   │
    └────────┬────────┘ └────────┬────────┘ └────────┬────────┘
             │                   │                   │
             └───────────────────┼───────────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 4. FOR EACH DATABASE    │◀──────┐
                     │    in config            │       │
                     └───────────┬─────────────┘       │
                                 │                     │
              ┌──────────────────┼──────────────────┐  │
              ▼                  ▼                  ▼  │
    ┌─────────────────┐ ┌─────────────────┐ ┌──────────┴────┐
    │ 4a. Connect to  │ │ 4b. Extract     │ │ 4c. Get       │
    │ Database        │ │ Table Metadata  │ │ Relationships │
    └────────┬────────┘ └────────┬────────┘ └──────────────┬┘
             │                   │                         │
             └───────────────────┼─────────────────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 5. Infer Domains (LLM)  │
                     │   - Load prompt template│
                     │   - Call Claude API     │
                     │   - Parse JSON response │
                     │   - Fallback: prefix    │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 6. Validate Domains     │
                     │   - No duplicates       │
                     │   - All tables assigned │
                     │   - Uncategorized catch │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 7. Generate WorkUnits   │
                     │   - 1 WorkUnit/domain   │
                     │   - Priority scoring    │
                     │   - Content hashing     │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 8. Compute Summary      │
                     │   - Total tables        │
                     │   - Estimated time      │
                     │   - Parallelism level   │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 9. Validate & Save Plan │
                     │ (documentation-plan.json)│
                     └─────────────────────────┘
```

### Key Components

| Component | File | Purpose |
|-----------|------|---------|
| `runPlanner()` | `index.ts` | Main entry point, orchestrates flow |
| `analyzeDatabase()` | `analyze-database.ts` | Connects and extracts metadata |
| `inferDomains()` | `domain-inference.ts` | LLM-based domain detection |
| `generateWorkUnits()` | `generate-work-units.ts` | Creates parallelizable units |

### Domain Inference Logic

```
┌────────────────────────────────────────────────────────────────────┐
│                    DOMAIN INFERENCE FLOW                           │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│   ┌───────────────┐     ┌───────────────┐     ┌───────────────┐  │
│   │ Table Names   │ ──▶ │ Build Prompt  │ ──▶ │ Call LLM      │  │
│   │ + Columns     │     │ (template)    │     │ (Claude)      │  │
│   └───────────────┘     └───────────────┘     └───────┬───────┘  │
│                                                       │          │
│                              ┌────────────────────────┼──────┐   │
│                              │                        │      │   │
│                              ▼                        ▼      │   │
│                     ┌───────────────┐        ┌───────────────┐   │
│                     │ Parse JSON    │        │ LLM Failed?   │   │
│                     │ Response      │        │ Use Fallback  │   │
│                     └───────┬───────┘        └───────┬───────┘   │
│                             │                        │           │
│                             └────────────┬───────────┘           │
│                                          ▼                       │
│                              ┌───────────────────────┐           │
│                              │ Fallback: Prefix-     │           │
│                              │ based grouping        │           │
│                              │ (user_* → "users")    │           │
│                              └───────────────────────┘           │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Output: `documentation-plan.json`

```json
{
  "schema_version": "1.0",
  "config_hash": "abc123...",
  "complexity": "moderate",
  "databases": [...],
  "work_units": [
    {
      "id": "dbname_customers",
      "database": "dbname",
      "domain": "customers",
      "tables": [...],
      "priority_order": 1
    }
  ],
  "summary": {
    "total_tables": 45,
    "total_work_units": 6,
    "recommended_parallelism": 4
  }
}
```

---

## 2. Documenter

### Purpose
Executes the documentation plan using **sub-agents**. For each table, it samples data, infers column semantics via LLM, and generates Markdown + JSON documentation files.

### Logic Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DOCUMENTER FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

                     ┌─────────────────────────┐
                     │ 1. Load & Validate Plan │
                     │ (documentation-plan.json)│
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 2. Check Checkpoint     │
                     │   - Resume if valid     │
                     │   - Else start fresh    │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 3. Initialize Progress  │
                     │ (documenter-progress.json)│
                     └───────────┬─────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  WorkUnit 1   │      │  WorkUnit 2   │      │  WorkUnit N   │
│  (customers)  │      │  (orders)     │      │  (system)     │
└───────┬───────┘      └───────────────┘      └───────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│                  PROCESS WORK UNIT                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│    ┌────────────────────────┐                              │
│    │ 4. Connect to Database │                              │
│    └───────────┬────────────┘                              │
│                │                                            │
│    ┌───────────▼────────────┐                              │
│    │ 5. FOR EACH TABLE      │◀─────────────────────┐       │
│    │    in WorkUnit         │                      │       │
│    └───────────┬────────────┘                      │       │
│                │                                   │       │
│    ┌───────────▼────────────┐                      │       │
│    │ 6. Spawn TableDocumenter│                      │       │
│    │    Sub-Agent           │                      │       │
│    └───────────┬────────────┘                      │       │
│                │                                   │       │
│                ▼                                   │       │
│    ┌──────────────────────────────────────────┐   │       │
│    │          TABLE DOCUMENTER                 │   │       │
│    ├──────────────────────────────────────────┤   │       │
│    │  a. Extract metadata (getTableMetadata)  │   │       │
│    │  b. Sample data (SELECT * LIMIT 100)     │   │       │
│    │  c. Spawn ColumnInferencer per column    │   │       │
│    │  d. Generate table description (LLM)     │   │       │
│    │  e. Write .md file                       │   │       │
│    │  f. Write .json file                     │   │       │
│    │  g. Return summary (context quarantine)  │   │       │
│    └───────────┬──────────────────────────────┘   │       │
│                │                                   │       │
│    ┌───────────▼────────────┐                      │       │
│    │ 7. Update Progress     │                      │       │
│    │    Checkpoint every 10 │──────────────────────┘       │
│    └────────────────────────┘                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 8. Generate Manifest    │
                     │ (documentation-manifest.json)│
                     └─────────────────────────┘
```

### Sub-Agent: TableDocumenter

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       TABLE DOCUMENTER SUB-AGENT                            │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌───────────────────────────┐
                    │   Input: TableSpec        │
                    │   - schema_name           │
                    │   - table_name            │
                    │   - column_count          │
                    │   - row_count_approx      │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │ 1. Get Table Metadata     │
                    │    connector.getTableMetadata()│
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │ 2. Sample Table Data      │
                    │    (5 sec timeout)        │
                    │    SELECT * FROM t LIMIT 100│
                    └─────────────┬─────────────┘
                                  │
     ┌────────────────────────────┼────────────────────────────┐
     │                            │                            │
     ▼                            ▼                            ▼
┌─────────────┐          ┌─────────────┐          ┌─────────────┐
│ Column 1    │          │ Column 2    │          │ Column N    │
│ Inferencer  │          │ Inferencer  │          │ Inferencer  │
└──────┬──────┘          └──────┬──────┘          └──────┬──────┘
       │                        │                        │
       │  ┌─────────────────────┼────────────────────────┘
       │  │                     │
       ▼  ▼                     ▼
┌──────────────────────────────────────────────────────────────┐
│                    COLUMN INFERENCER                         │
├──────────────────────────────────────────────────────────────┤
│  Input: column metadata + sample values                      │
│                                                              │
│  1. Load prompt template (column-description.md)             │
│  2. Interpolate variables:                                   │
│     - column_name, data_type, is_nullable                   │
│     - table context (schema, table, database)               │
│     - sample_values (truncated)                             │
│  3. Call LLM (Claude claude-sonnet-4)                        │
│  4. Validate response (length, punctuation)                  │
│  5. Fallback if LLM fails                                    │
│                                                              │
│  Output: description string ONLY (context quarantine)        │
└──────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. Generate Table Description (LLM)                          │
│    - Load table-description.md prompt                        │
│    - Include column descriptions, PKs, FKs                   │
│    - Call Claude                                             │
└─────────────────────────┬────────────────────────────────────┘
                          │
       ┌──────────────────┼──────────────────┐
       ▼                                     ▼
┌─────────────────┐                  ┌─────────────────┐
│ 5a. Write .md   │                  │ 5b. Write .json │
│ (Markdown doc)  │                  │ (JSON schema)   │
└─────────────────┘                  └─────────────────┘
       │                                     │
       └──────────────────┬──────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────────┐
│ 6. Return Summary (CONTEXT QUARANTINE)                       │
│    - table, schema, description                              │
│    - column_count, output_files                              │
│    - NO raw sample data in return object                     │
└──────────────────────────────────────────────────────────────┘
```

### Context Quarantine Pattern

Sub-agents **never** return raw data to the parent. They return only:
- Descriptions (strings)
- Counts (numbers)  
- File paths (strings)

This prevents context pollution and reduces token usage.

### Output Files

```
docs/
├── databases/
│   └── {db_name}/
│       └── domains/
│           └── {domain}/
│               └── tables/
│                   ├── {schema}.{table}.md
│                   └── {schema}.{table}.json
└── documentation-manifest.json
```

---

## 3. Indexer

### Purpose
Parses documentation files, extracts keywords, generates embeddings, and builds a searchable SQLite database with FTS5 (full-text search) and vector indices.

### Logic Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            INDEXER FLOW                                     │
└─────────────────────────────────────────────────────────────────────────────┘

                     ┌─────────────────────────┐
                     │ 1. Load Manifest        │
                     │ (documentation-manifest.json)│
                     └───────────┬─────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
    ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
    │ --force?        │ │ --incremental?  │ │ --resume?       │
    │ Clear all data  │ │ Detect changes  │ │ Load checkpoint │
    └────────┬────────┘ └────────┬────────┘ └────────┬────────┘
             │                   │                   │
             └───────────────────┼───────────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 2. Open SQLite Database │
                     │ (tribal-knowledge.db)   │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 3. Get Valid Files      │
                     │ (filter by work unit)   │
                     └───────────┬─────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────┐
│                                │                                │
│              ┌─────────────────┼─────────────────┐              │
│              │   PHASE 1: PARSING                │              │
│              └─────────────────┬─────────────────┘              │
│                                │                                │
│              ┌─────────────────▼─────────────────┐              │
│              │ 4. FOR EACH file                  │◀────────┐    │
│              │    parseDocument(file)            │         │    │
│              └─────────────────┬─────────────────┘         │    │
│                                │                           │    │
│    ┌───────────────────────────┼───────────────────────┐   │    │
│    ▼                           ▼                       ▼   │    │
│ ┌──────────┐            ┌──────────┐            ┌──────────┐    │
│ │ Table    │            │ Domain   │            │ Overview │    │
│ │ Parser   │            │ Parser   │            │ Parser   │    │
│ └────┬─────┘            └──────────┘            └──────────┘    │
│      │                                                     │    │
│      ▼                                                     │    │
│ ┌──────────────────────────────────────────────┐          │    │
│ │ 5. Generate Column Documents from Tables     │          │    │
│ │    (1 table → N column docs)                 │──────────┘    │
│ └──────────────────────────────────────────────┘               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────┐
│              ┌─────────────────┼─────────────────┐              │
│              │   PHASE 2: KEYWORD EXTRACTION     │              │
│              └─────────────────┬─────────────────┘              │
│                                │                                │
│              ┌─────────────────▼─────────────────┐              │
│              │ 6. extractKeywordsForDocument()   │              │
│              │    - Table/column names           │              │
│              │    - Domain terms                 │              │
│              │    - Technical patterns           │              │
│              └─────────────────┬─────────────────┘              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────┐
│              ┌─────────────────┼─────────────────┐              │
│              │   PHASE 3: EMBEDDING GENERATION   │              │
│              └─────────────────┬─────────────────┘              │
│                                │                                │
│              ┌─────────────────▼─────────────────┐              │
│              │ 7. createEmbeddingText(doc)       │              │
│              │    - Table: schema + description  │              │
│              │    - Column: type + description   │              │
│              │    - Domain: tables list          │              │
│              └─────────────────┬─────────────────┘              │
│                                │                                │
│              ┌─────────────────▼─────────────────┐              │
│              │ 8. generateEmbeddings()           │              │
│              │    - OpenAI text-embedding-3-small│              │
│              │    - Batch processing             │              │
│              │    - Retry with backoff           │              │
│              └─────────────────┬─────────────────┘              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────┐
│              ┌─────────────────┼─────────────────┐              │
│              │   PHASE 4: INDEX POPULATION       │              │
│              └─────────────────┬─────────────────┘              │
│                                │                                │
│              ┌─────────────────▼─────────────────┐              │
│              │ 9. Sort documents                 │              │
│              │    (tables before columns for     │              │
│              │     parent_doc_id linking)        │              │
│              └─────────────────┬─────────────────┘              │
│                                │                                │
│              ┌─────────────────▼─────────────────┐              │
│              │ 10. populateIndex()               │              │
│              │    - UPSERT to documents table    │              │
│              │    - Insert FTS5 (auto-sync)      │              │
│              │    - Insert vec0 embeddings       │              │
│              │    - Track parent_doc_id          │              │
│              └─────────────────┬─────────────────┘              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 11. Build Relationships │
                     │     Index (FK joins)    │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 12. Optimize Database   │
                     │     (VACUUM, ANALYZE)   │
                     └───────────┬─────────────┘
                                 │
                     ┌───────────▼─────────────┐
                     │ 13. Save Checkpoint     │
                     │     Mark Complete       │
                     └─────────────────────────┘
```

### Database Schema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SQLITE DATABASE SCHEMA                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐                                                        │
│  │   documents     │◀──────────────────────────────┐                        │
│  ├─────────────────┤                               │                        │
│  │ id (PK)         │                               │                        │
│  │ doc_type        │ (table, column, domain, ...)  │                        │
│  │ database_name   │                               │                        │
│  │ schema_name     │                               │                        │
│  │ table_name      │                               │                        │
│  │ column_name     │                               │                        │
│  │ domain          │                               │                        │
│  │ content         │ (full markdown)               │                        │
│  │ summary         │ (for FTS)                     │                        │
│  │ keywords        │ (JSON array)                  │                        │
│  │ file_path       │ (unique)                      │                        │
│  │ content_hash    │ (SHA256)                      │                        │
│  │ parent_doc_id   │─────────────────────┐         │                        │
│  └─────────────────┘                     │ (self-ref for columns)           │
│           │                               │                                  │
│           │ 1:1                           │                                  │
│           ▼                               │                                  │
│  ┌─────────────────┐                     │                                  │
│  │ documents_fts   │ (FTS5 virtual table) │                                  │
│  ├─────────────────┤                     │                                  │
│  │ content         │◀────sync───────────┘                                   │
│  │ summary         │                                                        │
│  │ keywords        │                                                        │
│  └─────────────────┘                                                        │
│                                                                             │
│  ┌─────────────────┐                                                        │
│  │ documents_vec   │ (vec0 virtual table)                                   │
│  ├─────────────────┤                                                        │
│  │ document_id (PK)│ ◀── links to documents.id                              │
│  │ embedding       │ float[1536] (OpenAI)                                   │
│  └─────────────────┘                                                        │
│                                                                             │
│  ┌─────────────────┐       ┌─────────────────┐                             │
│  │  relationships  │       │    keywords     │                             │
│  ├─────────────────┤       ├─────────────────┤                             │
│  │ source_table    │       │ term            │                             │
│  │ target_table    │       │ source_type     │                             │
│  │ join_condition  │       │ frequency       │                             │
│  └─────────────────┘       └─────────────────┘                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Incremental Indexing Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      INCREMENTAL INDEXING                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                     ┌───────────────────────┐                              │
│                     │ detectChanges()       │                              │
│                     └───────────┬───────────┘                              │
│                                 │                                          │
│    ┌────────────────────────────┼────────────────────────────┐             │
│    ▼                            ▼                            ▼             │
│ ┌──────────┐            ┌──────────────┐            ┌──────────────┐       │
│ │ NEW      │            │ CHANGED      │            │ DELETED      │       │
│ │ files    │            │ files        │            │ files        │       │
│ │ (not in  │            │ (hash diff)  │            │ (missing)    │       │
│ │ index)   │            │              │            │              │       │
│ └────┬─────┘            └──────┬───────┘            └──────┬───────┘       │
│      │                         │                           │               │
│      ▼                         ▼                           ▼               │
│ ┌──────────┐            ┌──────────────┐            ┌──────────────┐       │
│ │ INSERT   │            │ UPDATE       │            │ DELETE       │       │
│ │          │            │              │            │ + cascade    │       │
│ └──────────┘            └──────────────┘            └──────────────┘       │
│                                                                             │
│    Skip UNCHANGED files → faster incremental updates                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Summary: Data Flow Between Agents

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE DATA FLOW                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  databases.yaml                                                              │
│       │                                                                      │
│       ▼                                                                      │
│  ┌──────────┐   documentation-    ┌─────────────┐   docs/*.md    ┌─────────┐│
│  │ PLANNER  │ ─────────────────▶ │ DOCUMENTER  │ ─────────────▶ │ INDEXER ││
│  └──────────┘   plan.json         └─────────────┘   manifest.json └─────────┘│
│       │                                │                              │      │
│       │                                │                              │      │
│       ▼                                ▼                              ▼      │
│  • Domains detected              • Table docs (.md/.json)     • FTS5 index  │
│  • WorkUnits created             • Column descriptions        • Vec index   │
│  • Priority assigned             • Sample data (in files)     • Keywords    │
│  • Time estimated                • Manifest for indexer       • Relations   │
│                                                                              │
│  CONTRACT:                       CONTRACT:                    OUTPUT:        │
│  documentation-plan.json         documentation-manifest.json  tribal-       │
│  (JSON with WorkUnits)           (JSON with file list)        knowledge.db  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Design Patterns

| Pattern | Implementation |
|---------|----------------|
| **Contract-Based Handoffs** | JSON files between agents (plan.json, manifest.json) |
| **Context Quarantine** | Sub-agents return summaries only, never raw data |
| **Incremental Processing** | Content hashes detect changes, skip unchanged |
| **Checkpoint Recovery** | Progress files enable resume after interruption |
| **Parallel Processing** | WorkUnits processed in batches (3 tables, 5 columns) |
| **Graceful Degradation** | LLM fallbacks, partial success is valid |

---

## Source Files Reference

### Planner (`src/agents/planner/`)
- `index.ts` - Main entry point, orchestrates flow
- `analyze-database.ts` - Database connection and metadata extraction
- `domain-inference.ts` - LLM-based domain detection with fallback
- `generate-work-units.ts` - WorkUnit generation and prioritization
- `staleness.ts` - Change detection via config/schema hashing
- `metrics.ts` - Performance tracking

### Documenter (`src/agents/documenter/`)
- `index.ts` - Main entry point, orchestrates documentation
- `work-unit-processor.ts` - Processes WorkUnits sequentially
- `table-processor.ts` - Processes tables within WorkUnits
- `sub-agents/TableDocumenter.ts` - Documents individual tables
- `sub-agents/ColumnInferencer.ts` - Infers column semantics
- `manifest-generator.ts` - Creates handoff manifest for Indexer
- `progress.ts` - Checkpoint and progress tracking
- `recovery.ts` - Resume from checkpoint logic

### Indexer (`src/agents/indexer/`)
- `index.ts` - Main entry point, orchestrates indexing
- `manifest.ts` - Manifest validation and file discovery
- `parsers/documents.ts` - Document parsing for all types
- `parsers/columns.ts` - Column document generation
- `keywords.ts` - Keyword extraction
- `embeddings.ts` - OpenAI embedding generation
- `populate.ts` - SQLite index population
- `relationships.ts` - FK relationship indexing
- `incremental.ts` - Change detection and incremental updates
- `progress.ts` - Checkpoint management
- `optimize.ts` - Database optimization (VACUUM, ANALYZE)

---

*Last updated: December 13, 2025*

