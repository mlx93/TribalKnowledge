# Tribal Knowledge Deep Agent
## Agent Contracts - Interface Definitions

**Version**: 1.0  
**Date**: December 10, 2025  
**Author**: Systems Architect  
**Status**: Draft  
**Companion**: See `agent-contracts-execution.md` for parallel execution model

---

## 1. Overview

This document defines the TypeScript interfaces and data structures for all inter-agent communication. It serves as the type-level contract between the four agent phases:

1. **Planner (Schema Analyzer)** → Outputs `documentation-plan.json`
2. **Documenter** → Outputs `documentation-manifest.json` + `/docs/` files
3. **Indexer** → Populates SQLite database
4. **Retriever** → Exposes MCP tools

### 1.1 Document Organization

| Section | Contents |
|---------|----------|
| §2 | Common types shared across all agents |
| §3 | Planner output interfaces |
| §4 | Documenter interfaces (progress + manifest) |
| §5 | Indexer interfaces |
| §6 | Retriever/MCP tool interfaces |
| §7 | JSON Schema definitions |

---

## 2. Common Types

```typescript
// =============================================================================
// COMMON TYPES - Shared across all agents
// =============================================================================

/** ISO 8601 timestamp string */
type ISOTimestamp = string;

/** SHA-256 hash string (64 hex characters) */
type ContentHash = string;

/** Agent execution status */
type AgentStatus = 'pending' | 'running' | 'completed' | 'failed' | 'partial';

/** Database type identifier */
type DatabaseType = 'postgres' | 'snowflake';

/** Table priority for documentation order (1=core, 2=standard, 3=system) */
type TablePriority = 1 | 2 | 3;

/** Fully qualified table name: database.schema.table */
type FullyQualifiedTableName = string;

/** Domain name (lowercase, no spaces) */
type DomainName = string;

/** Error severity level */
type ErrorSeverity = 'warning' | 'error' | 'fatal';

/**
 * Base error structure used throughout the system.
 * All agents use this format for consistent error handling.
 */
interface AgentError {
  /** Machine-readable error code (e.g., "DB_CONNECTION_FAILED") */
  code: string;
  /** Human-readable error message */
  message: string;
  /** Severity level */
  severity: ErrorSeverity;
  /** When the error occurred */
  timestamp: ISOTimestamp;
  /** Additional context for debugging */
  context?: Record<string, unknown>;
  /** Whether the operation can be retried */
  recoverable: boolean;
}
```

---

## 3. Planner Output Interfaces

### 3.1 DocumentationPlan (Root)

```typescript
/**
 * Root structure of the documentation plan.
 * File: progress/documentation-plan.json
 * Producer: Planner
 * Consumer: Documenter
 */
interface DocumentationPlan {
  /** Schema version for forward compatibility */
  schema_version: '1.0';
  
  /** When this plan was generated */
  generated_at: ISOTimestamp;
  
  /** Hash of databases.yaml used (for staleness detection) */
  config_hash: ContentHash;
  
  /** Overall complexity assessment */
  complexity: 'simple' | 'moderate' | 'complex';
  
  /** Per-database analysis results */
  databases: DatabaseAnalysis[];
  
  /** Discrete work units for parallel processing */
  work_units: WorkUnit[];
  
  /** Aggregate summary statistics */
  summary: PlanSummary;
  
  /** Any errors encountered during planning */
  errors: AgentError[];
}
```

### 3.2 DatabaseAnalysis

```typescript
/**
 * Analysis results for a single database.
 */
interface DatabaseAnalysis {
  /** Database identifier from config */
  name: string;
  
  /** Database platform */
  type: DatabaseType;
  
  /** Connection status during analysis */
  status: 'reachable' | 'unreachable';
  
  /** Error details if unreachable */
  connection_error?: AgentError;
  
  /** Total tables discovered */
  table_count: number;
  
  /** Number of schemas */
  schema_count: number;
  
  /** Estimated documentation time in minutes */
  estimated_time_minutes: number;
  
  /** Discovered business domains mapped to their tables */
  domains: Record<DomainName, string[]>;
  
  /** Hash of the database schema for change detection */
  schema_hash: ContentHash;
}
```

### 3.3 WorkUnit (Key for Parallelization)

```typescript
/**
 * A discrete, self-contained unit of work for the Documenter.
 * Each work unit can be processed independently and in parallel.
 * This is the KEY ENABLER for parallel domain processing.
 */
interface WorkUnit {
  /** Unique identifier: "{database}_{domain}" */
  id: string;
  
  /** Source database */
  database: string;
  
  /** Business domain this work unit covers */
  domain: DomainName;
  
  /** Tables to document in this work unit */
  tables: TableSpec[];
  
  /** Estimated processing time in minutes */
  estimated_time_minutes: number;
  
  /** Output directory (relative to /docs) */
  output_directory: string;
  
  /** Priority order for processing (lower = higher priority) */
  priority_order: number;
  
  /** Dependencies on other work units (usually empty) */
  depends_on: string[];
  
  /** Hash of this work unit's content for change detection */
  content_hash: ContentHash;
}
```

### 3.4 TableSpec

```typescript
/**
 * Specification for a single table to be documented.
 */
interface TableSpec {
  /** Fully qualified name: database.schema.table */
  fully_qualified_name: FullyQualifiedTableName;
  
  /** Schema name */
  schema_name: string;
  
  /** Table name */
  table_name: string;
  
  /** Assigned business domain */
  domain: DomainName;
  
  /** Documentation priority */
  priority: TablePriority;
  
  /** Number of columns */
  column_count: number;
  
  /** Approximate row count */
  row_count_approx: number;
  
  /** Tables that reference this via FK */
  incoming_fk_count: number;
  
  /** Tables this references via FK */
  outgoing_fk_count: number;
  
  /** Hash of table metadata for change detection */
  metadata_hash: ContentHash;
  
  /** Existing database comment (if any) */
  existing_comment?: string;
}
```

### 3.5 PlanSummary

```typescript
/**
 * Summary statistics for the entire plan.
 */
interface PlanSummary {
  total_databases: number;
  reachable_databases: number;
  total_tables: number;
  total_work_units: number;
  domain_count: number;
  total_estimated_minutes: number;
  /** Recommended number of parallel workers */
  recommended_parallelism: number;
}
```

---

## 4. Documenter Interfaces

### 4.1 DocumenterProgress

```typescript
/**
 * Progress tracking for overall documentation process.
 * File: progress/documenter-progress.json
 * Producer: Documenter
 * Consumer: Orchestrator, CLI
 */
interface DocumenterProgress {
  schema_version: '1.0';
  started_at: ISOTimestamp;
  completed_at: ISOTimestamp | null;
  status: AgentStatus;
  
  /** Path to the plan being executed */
  plan_file: string;
  
  /** Hash of the plan (detect if changed mid-run) */
  plan_hash: ContentHash;
  
  /** Progress for each work unit */
  work_units: Record<string, WorkUnitProgress>;
  
  /** Aggregated statistics */
  stats: DocumenterStats;
  
  /** Last checkpoint timestamp */
  last_checkpoint: ISOTimestamp;
  
  /** Top-level errors */
  errors: AgentError[];
}
```

### 4.2 WorkUnitProgress

```typescript
/**
 * Progress tracking for a single work unit.
 * File: progress/work_units/{id}/progress.json
 */
interface WorkUnitProgress {
  work_unit_id: string;
  status: AgentStatus;
  started_at?: ISOTimestamp;
  completed_at?: ISOTimestamp;
  
  /** PID of processing sub-agent (for parallel execution) */
  processor_pid?: number;
  
  tables_total: number;
  tables_completed: number;
  tables_failed: number;
  tables_skipped: number;
  
  /** Currently processing table */
  current_table?: FullyQualifiedTableName;
  
  /** Errors in this work unit */
  errors: AgentError[];
  
  /** Output files generated */
  output_files: string[];
}
```

### 4.3 DocumenterStats

```typescript
interface DocumenterStats {
  total_tables: number;
  completed_tables: number;
  failed_tables: number;
  skipped_tables: number;
  llm_tokens_used: number;
  llm_time_ms: number;
  db_query_time_ms: number;
}
```

### 4.4 DocumentationManifest (Handoff to Indexer)

```typescript
/**
 * Manifest of completed documentation.
 * File: docs/documentation-manifest.json
 * Producer: Documenter (on completion)
 * Consumer: Indexer
 * 
 * THIS IS THE PRIMARY HANDOFF CONTRACT FROM DOCUMENTER TO INDEXER.
 */
interface DocumentationManifest {
  schema_version: '1.0';
  completed_at: ISOTimestamp;
  plan_hash: ContentHash;
  
  /** Must be 'complete' or 'partial' for Indexer to proceed */
  status: 'complete' | 'partial';
  
  /** All databases documented */
  databases: DatabaseManifest[];
  
  /** Per-work-unit completion status */
  work_units: WorkUnitManifest[];
  
  /** Total files generated */
  total_files: number;
  
  /** Files that the indexer should process */
  indexable_files: IndexableFile[];
}

interface DatabaseManifest {
  name: string;
  type: DatabaseType;
  docs_directory: string;
  tables_documented: number;
  tables_failed: number;
  domains: string[];
}

interface WorkUnitManifest {
  id: string;
  status: 'completed' | 'failed' | 'partial';
  output_directory: string;
  files_generated: number;
  output_hash: ContentHash;
  /** Can this work unit be re-processed independently? */
  reprocessable: boolean;
  errors?: AgentError[];
}

interface IndexableFile {
  /** Relative path from /docs */
  path: string;
  type: 'table' | 'domain' | 'overview' | 'relationship';
  database: string;
  schema?: string;
  table?: string;
  domain?: DomainName;
  content_hash: ContentHash;
  size_bytes: number;
  modified_at: ISOTimestamp;
}
```

---

## 5. Indexer Interfaces

### 5.1 IndexerProgress

```typescript
/**
 * Progress tracking for indexing process.
 * File: progress/indexer-progress.json
 */
interface IndexerProgress {
  schema_version: '1.0';
  started_at: ISOTimestamp;
  completed_at: ISOTimestamp | null;
  status: AgentStatus;
  
  manifest_file: string;
  manifest_hash: ContentHash;
  
  files_total: number;
  files_indexed: number;
  files_failed: number;
  files_skipped: number;
  
  current_file?: string;
  embeddings_generated: number;
  last_checkpoint: ISOTimestamp;
  errors: AgentError[];
}
```

### 5.2 IndexMetadata

```typescript
/**
 * Index metadata stored in SQLite.
 * Table: index_metadata
 */
interface IndexMetadata {
  last_full_index: ISOTimestamp;
  manifest_hash: ContentHash;
  document_count: number;
  embedding_count: number;
  index_version: string;
  embedding_model: string;
  embedding_dimensions: number;
}
```

### 5.3 DocumentRecord

```typescript
/**
 * Document record stored in SQLite.
 * Table: documents
 */
interface DocumentRecord {
  id: number;
  doc_type: 'table' | 'column' | 'domain' | 'relationship';
  database_name: string;
  schema_name: string | null;
  table_name: string | null;
  column_name: string | null;
  domain: DomainName | null;
  content: string;
  summary: string;
  keywords: string; // JSON array
  file_path: string;
  content_hash: ContentHash;
  indexed_at: ISOTimestamp;
  source_modified_at: ISOTimestamp;
}
```

---

## 6. Retriever/MCP Interfaces

### 6.1 search_tables Tool

```typescript
interface SearchTablesInput {
  /** Natural language search query (required) */
  query: string;
  /** Filter to specific database */
  database?: string;
  /** Filter to specific domain */
  domain?: DomainName;
  /** Max results (default: 5, max: 20) */
  limit?: number;
  /** Min relevance score threshold (0-1) */
  min_score?: number;
}

interface SearchTablesOutput {
  success: boolean;
  tables: TableSearchResult[];
  total_matches: number;
  tokens_used: number;
  query_interpretation?: QueryInterpretation;
  error?: AgentError;
}

interface TableSearchResult {
  name: FullyQualifiedTableName;
  database: string;
  schema: string;
  table: string;
  domain: DomainName;
  description: string;
  key_columns: ColumnSummary[];
  row_count: number;
  relevance_score: number;
}

interface ColumnSummary {
  name: string;
  type: string;
  description: string;
  is_primary_key: boolean;
  is_foreign_key: boolean;
}

interface QueryInterpretation {
  original_query: string;
  concepts: string[];
  expanded_terms: string[];
  domain_hint: DomainName | null;
  is_relationship_query: boolean;
}
```

### 6.2 get_table_schema Tool

```typescript
interface GetTableSchemaInput {
  /** Fully qualified table name (required) */
  table: FullyQualifiedTableName;
  /** Include sample values? */
  include_samples?: boolean;
  /** Include related tables? */
  include_relationships?: boolean;
}

interface GetTableSchemaOutput {
  success: boolean;
  schema?: TableSchema;
  tokens_used: number;
  error?: AgentError;
}

interface TableSchema {
  name: FullyQualifiedTableName;
  database: string;
  schema: string;
  table: string;
  domain: DomainName;
  description: string;
  row_count: number;
  columns: ColumnDetail[];
  primary_key: string[];
  foreign_keys: ForeignKeyDetail[];
  indexes: IndexDetail[];
  related_tables?: RelatedTable[];
}

interface ColumnDetail {
  name: string;
  type: string;
  nullable: boolean;
  default_value: string | null;
  description: string;
  samples?: string[];
}

interface ForeignKeyDetail {
  name: string;
  columns: string[];
  references_table: FullyQualifiedTableName;
  references_columns: string[];
}

interface IndexDetail {
  name: string;
  columns: string[];
  unique: boolean;
}

interface RelatedTable {
  name: FullyQualifiedTableName;
  relationship: 'references' | 'referenced_by';
  via_columns: string[];
  description: string;
}
```

### 6.3 get_join_path Tool

```typescript
interface GetJoinPathInput {
  source_table: FullyQualifiedTableName;
  target_table: FullyQualifiedTableName;
  max_hops?: number; // default: 3
}

interface GetJoinPathOutput {
  success: boolean;
  path_found: boolean;
  source: FullyQualifiedTableName;
  target: FullyQualifiedTableName;
  hop_count?: number;
  path?: JoinStep[];
  sql_snippet?: string;
  tokens_used: number;
  error?: AgentError;
}

interface JoinStep {
  step: number;
  from_table: FullyQualifiedTableName;
  to_table: FullyQualifiedTableName;
  join_type: 'INNER' | 'LEFT' | 'RIGHT';
  on_clause: string;
}
```

### 6.4 get_domain_overview Tool

```typescript
interface GetDomainOverviewInput {
  domain: DomainName;
  database?: string;
}

interface GetDomainOverviewOutput {
  success: boolean;
  domain: DomainName;
  description: string;
  databases: string[];
  tables: DomainTableSummary[];
  er_diagram?: string; // Mermaid syntax
  common_joins?: string[];
  tokens_used: number;
  error?: AgentError;
}

interface DomainTableSummary {
  name: FullyQualifiedTableName;
  description: string;
  row_count: number;
}
```

### 6.5 list_domains Tool

```typescript
interface ListDomainsInput {
  database?: string;
}

interface ListDomainsOutput {
  success: boolean;
  domains: DomainInfo[];
  tokens_used: number;
  error?: AgentError;
}

interface DomainInfo {
  name: DomainName;
  description: string;
  table_count: number;
  databases: string[];
}
```

---

## 7. JSON Schema (Condensed)

### 7.1 documentation-plan.json Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "documentation-plan.schema.json",
  "type": "object",
  "required": ["schema_version", "generated_at", "config_hash", "work_units", "summary"],
  "properties": {
    "schema_version": { "const": "1.0" },
    "generated_at": { "type": "string", "format": "date-time" },
    "config_hash": { "type": "string", "minLength": 64 },
    "complexity": { "enum": ["simple", "moderate", "complex"] },
    "databases": { "type": "array" },
    "work_units": { "type": "array", "minItems": 1 },
    "summary": { "type": "object" },
    "errors": { "type": "array" }
  }
}
```

### 7.2 documentation-manifest.json Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "documentation-manifest.schema.json",
  "type": "object",
  "required": ["schema_version", "completed_at", "status", "indexable_files"],
  "properties": {
    "schema_version": { "const": "1.0" },
    "completed_at": { "type": "string", "format": "date-time" },
    "plan_hash": { "type": "string" },
    "status": { "enum": ["complete", "partial"] },
    "databases": { "type": "array" },
    "work_units": { "type": "array" },
    "total_files": { "type": "integer" },
    "indexable_files": { "type": "array" }
  }
}
```

---

## 8. File Location Summary

| File | Producer | Consumer | Purpose |
|------|----------|----------|---------|
| `progress/documentation-plan.json` | Planner | Documenter | Plan with work units |
| `progress/documenter-progress.json` | Documenter | Orchestrator | Aggregated progress |
| `progress/work_units/{id}/progress.json` | Documenter | Parent Documenter | Per-unit progress |
| `docs/documentation-manifest.json` | Documenter | Indexer | Completion handoff |
| `progress/indexer-progress.json` | Indexer | Orchestrator | Indexing progress |
| `data/tribal-knowledge.db` | Indexer | Retriever | Search index |

---

## 9. Type Export Summary

For implementation, export all types from a central module:

```typescript
// src/contracts/types.ts

// Common
export type { ISOTimestamp, ContentHash, AgentStatus, DatabaseType };
export type { TablePriority, FullyQualifiedTableName, DomainName };
export type { ErrorSeverity, AgentError };

// Planner
export type { DocumentationPlan, DatabaseAnalysis, WorkUnit, TableSpec, PlanSummary };

// Documenter
export type { DocumenterProgress, WorkUnitProgress, DocumenterStats };
export type { DocumentationManifest, DatabaseManifest, WorkUnitManifest, IndexableFile };

// Indexer
export type { IndexerProgress, IndexMetadata, DocumentRecord };

// Retriever
export type { SearchTablesInput, SearchTablesOutput, TableSearchResult };
export type { GetTableSchemaInput, GetTableSchemaOutput, TableSchema };
export type { GetJoinPathInput, GetJoinPathOutput, JoinStep };
export type { GetDomainOverviewInput, GetDomainOverviewOutput };
export type { ListDomainsInput, ListDomainsOutput, DomainInfo };
export type { ColumnSummary, ColumnDetail, ForeignKeyDetail, IndexDetail };
export type { QueryInterpretation, RelatedTable };
```

---

*End of Interface Definitions - See `agent-contracts-execution.md` for parallel execution model*
