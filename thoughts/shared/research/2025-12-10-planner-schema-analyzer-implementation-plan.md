---
date: 2025-12-10T12:00:00-08:00
researcher: mlx93
git_commit: 732cd65841072f1fb0e3850fdb94ab3e15b8c64d
branch: main
repository: Tribal_Knowledge
topic: "Planner Schema Analyzer (Module 1) Implementation Plan"
tags: [research, implementation-plan, planner, schema-analyzer, module-1]
status: complete
last_updated: 2025-12-10
last_updated_by: mlx93
---

# Planner Schema Analyzer (Module 1) - Implementation Plan

**Date**: 2025-12-10
**Researcher**: mlx93
**Git Commit**: 732cd65841072f1fb0e3850fdb94ab3e15b8c64d
**Branch**: main
**Repository**: Tribal_Knowledge

---

## Research Question

Develop a comprehensive implementation plan for the Planner Schema Analyzer (Module 1) based on the existing planning documents in the TribalAgent planning folder.

---

## Summary

The Planner (Schema Analyzer) is the first module in the Tribal Knowledge Deep Agent pipeline. It connects to configured databases, analyzes their structure, detects business domains using LLM, and creates a documentation plan with **WorkUnits** that enable parallel processing by downstream agents.

**Current State**: A basic implementation exists (`TribalAgent/src/agents/planner/index.ts`) with:
- Database connection and metadata extraction
- Simple prefix-based domain detection (LLM integration is a TODO)
- Basic Zod schema validation
- Output to `progress/documentation-plan.json`

**Gap Analysis**: The current implementation needs to be enhanced to match the specifications in the agent contracts:
1. WorkUnit-based output format for parallel documentation
2. LLM-powered domain inference using the `domain-inference.md` prompt
3. Content hashes for change detection and staleness
4. Structured error handling with `AgentError` format
5. Enhanced summary statistics with recommended parallelism

---

## Gap Analysis Resolution

This section documents how the plan addresses known gaps identified during review.

| Gap | Resolution | Section |
|-----|------------|---------|
| Contract alignment (TableSpec fields) | Connectors must populate all required fields using estimates | §1.3, §4.2a |
| Staleness/change detection (schema drift) | Compare metadata_hash and schema_hash against previous plan | §4.1a |
| Unreachable DB handling | Include unreachable DBs with status='unreachable' | §4.2 |
| Domain inference robustness (100% coverage) | Post-pass validation ensures all tables assigned | §3.4a |
| Row counts and performance (<30s target) | Use pg_class.reltuples / INFORMATION_SCHEMA.TABLES.ROW_COUNT | §4.2a |
| Logging/metrics (Planner Metrics) | Emit metrics for planning time, tables, domains, tokens | §6.1a |
| CLI review guardrails (FR-0.5) | Add `plan validate` command for user-edited plans | §7.1b |
| Config coverage (enabled toggle) | Respect `planner.enabled`, fail fast on missing config | §5.3 |
| Error taxonomy usage | Map runtime failures to codes with severity/recoverable | §1.2a |
| Test depth (e2e + LLM-off) | Add fixture-based integration test and LLM-off fallback test | §7.2a |
| Dependency clarity | Remove unused `openai`, document required env vars | §Dependencies |

---

## Detailed Implementation Plan

### Phase 1: Core Contracts and Types

**Objective**: Establish the TypeScript type foundation as specified in `agent-contracts-interfaces.md`

#### Step 1.1: Create Contracts Module

**File**: `src/contracts/types.ts`

```typescript
// Common types
export type ISOTimestamp = string;
export type ContentHash = string;
export type AgentStatus = 'pending' | 'running' | 'completed' | 'failed' | 'partial';
export type DatabaseType = 'postgres' | 'snowflake';
export type TablePriority = 1 | 2 | 3;
export type FullyQualifiedTableName = string;
export type DomainName = string;
export type ErrorSeverity = 'warning' | 'error' | 'fatal';

export interface AgentError {
  code: string;
  message: string;
  severity: ErrorSeverity;
  timestamp: ISOTimestamp;
  context?: Record<string, unknown>;
  recoverable: boolean;
}
```

**Reference**: `agent-contracts-interfaces.md:37-82`

#### Step 1.2: Create Error Codes Registry

**File**: `src/contracts/errors.ts`

Implement the canonical error codes as specified in Appendix A of `agent-contracts-interfaces.md:781-893`. Include:
- `PLAN_CONFIG_NOT_FOUND`
- `PLAN_CONFIG_INVALID`
- `PLAN_DB_UNREACHABLE`
- `PLAN_DOMAIN_INFERENCE_FAILED`
- `PLAN_WRITE_FAILED`
- `PLAN_SCHEMA_QUERY_FAILED`
- `PLAN_FK_QUERY_FAILED`

#### Step 1.2a: Error Taxonomy Mapping (NEW)

**File**: `src/contracts/errors.ts` (continued)

Map runtime failures to error codes with consistent severity and recoverability:

```typescript
/**
 * Error taxonomy mapping for Planner failures.
 * Each mapping defines: code, severity, recoverable, and when to use.
 */
export const PLANNER_ERROR_MAP = {
  // Configuration errors (fatal - cannot proceed)
  configNotFound: {
    code: 'PLAN_CONFIG_NOT_FOUND',
    severity: 'fatal' as const,
    recoverable: false,
    trigger: 'databases.yaml or agent-config.yaml missing',
  },
  configInvalid: {
    code: 'PLAN_CONFIG_INVALID',
    severity: 'fatal' as const,
    recoverable: false,
    trigger: 'YAML parse error or Zod validation failure',
  },

  // Database connection errors (warning - skip and continue)
  dbUnreachable: {
    code: 'PLAN_DB_UNREACHABLE',
    severity: 'warning' as const,
    recoverable: true,
    trigger: 'Connection timeout, auth failure, network error',
  },

  // Schema query errors (error - log and continue with partial data)
  schemaQueryFailed: {
    code: 'PLAN_SCHEMA_QUERY_FAILED',
    severity: 'error' as const,
    recoverable: true,
    trigger: 'information_schema query fails (permissions, timeout)',
  },
  fkQueryFailed: {
    code: 'PLAN_FK_QUERY_FAILED',
    severity: 'warning' as const,
    recoverable: true,
    trigger: 'FK query fails - continue without relationships',
  },

  // LLM errors (warning - fall back to prefix-based)
  domainInferenceFailed: {
    code: 'PLAN_DOMAIN_INFERENCE_FAILED',
    severity: 'warning' as const,
    recoverable: true,
    trigger: 'LLM API error, timeout, or unparseable response',
  },

  // Write errors (error - may need retry)
  writeFailed: {
    code: 'PLAN_WRITE_FAILED',
    severity: 'error' as const,
    recoverable: false,
    trigger: 'Cannot write documentation-plan.json (permissions, disk)',
  },
} as const;

/**
 * Helper to create AgentError from taxonomy.
 */
export function createPlannerError(
  type: keyof typeof PLANNER_ERROR_MAP,
  message: string,
  context?: Record<string, unknown>
): AgentError {
  const mapping = PLANNER_ERROR_MAP[type];
  return {
    code: mapping.code,
    message,
    severity: mapping.severity,
    timestamp: new Date().toISOString(),
    context,
    recoverable: mapping.recoverable,
  };
}
```

**Usage Example**:
```typescript
// In analyzeDatabase when connection fails:
return {
  success: false,
  error: createPlannerError('dbUnreachable', `Connection failed: ${err.message}`, {
    database: dbName,
    host: dbConfig.host,
  }),
};
```

#### Step 1.3: Create Planner Output Interfaces

**File**: `src/contracts/types.ts` (continued)

Define the `DocumentationPlan`, `DatabaseAnalysis`, `WorkUnit`, `TableSpec`, and `PlanSummary` interfaces exactly as specified in `agent-contracts-interfaces.md:87-257`.

**IMPORTANT**: All `TableSpec` fields are REQUIRED per contract. Connectors must populate them efficiently using estimates (not COUNT(*)):

| TableSpec Field | Postgres Source | Snowflake Source | Notes |
|-----------------|-----------------|------------------|-------|
| `row_count_approx` | `pg_class.reltuples` | `INFORMATION_SCHEMA.TABLES.ROW_COUNT` | Never use COUNT(*) |
| `incoming_fk_count` | FK query result | FK query result | Count of referencing tables |
| `outgoing_fk_count` | FK query result | FK query result | Count of referenced tables |
| `column_count` | Column query | Column query | Direct from metadata |
| `metadata_hash` | `computeTableMetadataHash()` | `computeTableMetadataHash()` | Hash of column definitions |

**Key Interfaces**:
```typescript
interface DocumentationPlan {
  schema_version: '1.0';
  generated_at: ISOTimestamp;
  config_hash: ContentHash;
  complexity: 'simple' | 'moderate' | 'complex';
  databases: DatabaseAnalysis[];
  work_units: WorkUnit[];
  summary: PlanSummary;
  errors: AgentError[];
}

interface WorkUnit {
  id: string;                    // "{database}_{domain}"
  database: string;
  domain: DomainName;
  tables: TableSpec[];
  estimated_time_minutes: number;
  output_directory: string;
  priority_order: number;
  depends_on: string[];
  content_hash: ContentHash;
}

/**
 * Complete TableSpec per agent-contracts-interfaces.md §3.4
 * ALL fields must be populated by the Planner
 */
interface TableSpec {
  fully_qualified_name: FullyQualifiedTableName;  // "database.schema.table"
  schema_name: string;
  table_name: string;
  domain: DomainName;
  priority: TablePriority;                        // 1=core, 2=standard, 3=system
  column_count: number;
  row_count_approx: number;                       // From pg_class.reltuples or COUNT(*)
  incoming_fk_count: number;                      // Tables that reference this via FK
  outgoing_fk_count: number;                      // Tables this references via FK
  metadata_hash: ContentHash;                     // Hash of column names + types
  existing_comment?: string;                      // Database comment if any
}

/**
 * PlanSummary with recommended_parallelism
 */
interface PlanSummary {
  total_databases: number;
  reachable_databases: number;
  total_tables: number;
  total_work_units: number;
  domain_count: number;
  total_estimated_minutes: number;
  recommended_parallelism: number;                // min(work_unit_count, 4)
}
```

---

### Phase 2: Utility Functions

**Objective**: Implement shared utilities for hashing and validation

#### Step 2.1: Hash Utilities

**File**: `src/utils/hash.ts`

```typescript
import { createHash } from 'crypto';

export function computeHash(content: string | Buffer): ContentHash {
  return createHash('sha256').update(content).digest('hex');
}

export function computeConfigHash(configPath: string): Promise<ContentHash> {
  // Read config file and compute hash
  const content = await fs.readFile(configPath, 'utf-8');
  return computeHash(content);
}

/**
 * Compute deterministic schema hash for change detection.
 * Hash includes: table names, column names, column types (sorted for stability).
 * Does NOT include: row counts, comments, or other volatile metadata.
 */
export function computeSchemaHash(tables: TableMetadata[]): ContentHash {
  // Sort tables by name for deterministic ordering
  const sortedTables = [...tables].sort((a, b) => a.name.localeCompare(b.name));

  const hashInput = sortedTables.map(table => ({
    name: table.name,
    columns: table.columns
      .sort((a, b) => a.name.localeCompare(b.name))
      .map(col => `${col.name}:${col.data_type}:${col.nullable}`),
  }));

  return computeHash(JSON.stringify(hashInput));
}

/**
 * Compute metadata hash for a single table (used in TableSpec.metadata_hash).
 * More granular than schema hash - detects column-level changes.
 */
export function computeTableMetadataHash(table: TableMetadata): ContentHash {
  const hashInput = {
    name: table.name,
    columns: table.columns
      .sort((a, b) => a.name.localeCompare(b.name))
      .map(col => ({
        name: col.name,
        type: col.data_type,
        nullable: col.nullable,
        default: col.default_value,
      })),
    primaryKey: table.primary_key?.sort(),
    foreignKeys: table.foreign_keys
      ?.sort((a, b) => a.constraint_name.localeCompare(b.constraint_name))
      .map(fk => `${fk.columns.join(',')}->${fk.references_table}`),
  };

  return computeHash(JSON.stringify(hashInput));
}
```

#### Step 2.2: Validation Utilities

**File**: `src/contracts/validators.ts`

Implement validation functions for the plan output as specified in `agent-contracts-execution.md:221-264`:
- `validatePlan(plan: unknown): DocumentationPlan`
- `validateWorkUnit(unit: unknown): void`
- `validateNoCycles(workUnits: WorkUnit[]): void`

---

### Phase 3: LLM Integration for Domain Inference

**Objective**: Implement LLM-based domain detection using the existing prompt template

#### Step 3.1: Implement LLM Client (OpenRouter)

**File**: `src/utils/llm.ts` (enhance existing)

Currently has mock implementations. Implement OpenRouter API client for Claude Sonnet 4.5:

```typescript
import OpenAI from 'openai';
import fs from 'fs/promises';
import path from 'path';

// OpenRouter uses OpenAI-compatible API
const openrouter = new OpenAI({
  baseURL: 'https://openrouter.ai/api/v1',
  apiKey: process.env.OPENROUTER_API_KEY,
  defaultHeaders: {
    'HTTP-Referer': 'https://tribal-knowledge.local',
    'X-Title': 'Tribal Knowledge Deep Agent',
  },
});

export interface LLMCallOptions {
  model?: string;
  maxTokens?: number;
  temperature?: number;
}

export interface LLMResponse {
  success: boolean;
  content: string | Record<string, unknown>;
  tokens: { input: number; output: number; total: number };
  duration_ms: number;
  error?: AgentError;
}

export async function callLLMWithTemplate(
  templatePath: string,
  variables: Record<string, string>,
  options: LLMCallOptions = {}
): Promise<LLMResponse> {
  const startTime = Date.now();
  const model = options.model ?? 'anthropic/claude-sonnet-4';

  try {
    // 1. Load template from prompts directory
    const fullPath = path.join(process.cwd(), 'prompts', templatePath);
    let template = await fs.readFile(fullPath, 'utf-8');

    // 2. Substitute variables ({{variable}} syntax)
    for (const [key, value] of Object.entries(variables)) {
      template = template.replace(new RegExp(`{{${key}}}`, 'g'), value);
    }

    // 3. Call OpenRouter API (OpenAI-compatible)
    const response = await openrouter.chat.completions.create({
      model,
      messages: [{ role: 'user', content: template }],
      max_tokens: options.maxTokens ?? 4096,
      temperature: options.temperature ?? 0.3,
    });

    const content = response.choices[0]?.message?.content ?? '';
    const usage = response.usage ?? { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 };

    return {
      success: true,
      content,
      tokens: {
        input: usage.prompt_tokens,
        output: usage.completion_tokens,
        total: usage.total_tokens,
      },
      duration_ms: Date.now() - startTime,
    };

  } catch (error) {
    return {
      success: false,
      content: '',
      tokens: { input: 0, output: 0, total: 0 },
      duration_ms: Date.now() - startTime,
      error: {
        code: 'PLAN_DOMAIN_INFERENCE_FAILED',
        message: `LLM call failed: ${error.message}`,
        severity: 'warning',
        timestamp: new Date().toISOString(),
        context: { model, templatePath },
        recoverable: true,
      },
    };
  }
}
```

**Note**: Uses `OPENROUTER_API_KEY` from `.env` (already configured).

**Reference**: Appendix C of `agent-contracts-interfaces.md:1129-1228`

#### Step 3.2: Implement Domain Inference

**File**: `src/agents/planner/domain-inference.ts` (new)

```typescript
import { callLLMWithTemplate } from '../../utils/llm.js';
import type { PlannerConfig } from '../../utils/agent-config.js';

export async function inferDomains(
  database: string,
  tables: TableMetadata[],
  relationships: Relationship[],
  config: PlannerConfig
): Promise<Record<DomainName, string[]>> {
  // Skip LLM if disabled in config (matches existing agent-config.yaml field name)
  if (!config.domain_inference) {
    return inferDomainsByPrefix(tables);
  }

  const batchSize = config.max_tables_per_database ?? 100;

  // For large databases, batch the domain inference calls
  if (tables.length > batchSize) {
    return inferDomainsInBatches(database, tables, relationships, batchSize, config);
  }

  // Single LLM call for smaller databases
  return inferDomainsWithLLM(database, tables, relationships, config);
}

async function inferDomainsWithLLM(
  database: string,
  tables: TableMetadata[],
  relationships: Relationship[],
  config: PlannerConfig
): Promise<Record<DomainName, string[]>> {
  // 1. Format table list as JSON
  // 2. Summarize relationships
  // 3. Call LLM with domain-inference.md template
  // 4. Parse JSON response
  // 5. Validate all tables are assigned
  // 6. Return domain mapping
}
```

#### Step 3.3: Domain Inference Batching (NEW)

**File**: `src/agents/planner/domain-inference.ts` (continued)

For databases with 500+ tables, batch inference into groups per `domain_inference_batch_size` config.

```typescript
async function inferDomainsInBatches(
  database: string,
  tables: TableMetadata[],
  relationships: Relationship[],
  batchSize: number,
  config: PlannerConfig
): Promise<Record<DomainName, string[]>> {
  const batches = chunkArray(tables, batchSize);
  const partialDomains: Record<DomainName, string[]>[] = [];

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    logger.info(`Domain inference batch ${i + 1}/${batches.length}`, { tables: batch.length });

    // Filter relationships to only those relevant to this batch
    const batchTableNames = new Set(batch.map(t => t.name));
    const batchRelationships = relationships.filter(
      r => batchTableNames.has(r.source) || batchTableNames.has(r.target)
    );

    try {
      const domains = await inferDomainsWithLLM(database, batch, batchRelationships, config);
      partialDomains.push(domains);
    } catch (error) {
      logger.warn(`Batch ${i + 1} domain inference failed, using prefix fallback`, { error });
      partialDomains.push(inferDomainsByPrefix(batch));
    }
  }

  // Merge batch results, combining tables into matching domain names
  return mergeDomainResults(partialDomains);
}

function mergeDomainResults(
  partials: Record<DomainName, string[]>[]
): Record<DomainName, string[]> {
  const merged: Record<DomainName, string[]> = {};

  for (const partial of partials) {
    for (const [domain, tables] of Object.entries(partial)) {
      // Normalize domain names (lowercase, trim) for deterministic merging
      const normalizedDomain = domain.toLowerCase().trim();
      if (!merged[normalizedDomain]) {
        merged[normalizedDomain] = [];
      }
      merged[normalizedDomain].push(...tables);
    }
  }

  return merged;
}
```

**Reference**: `agent-contracts-interfaces.md:1017-1020` (domain_inference_batch_size)

**Fallback**: If LLM fails, use prefix-based grouping (existing logic)

**Prompt Template**: `prompts/domain-inference.md` (already exists)

#### Step 3.4a: Domain Validation Post-Pass (NEW)

**File**: `src/agents/planner/domain-inference.ts` (continued)

Ensure 100% table coverage and deterministic domain assignment:

```typescript
/**
 * Validate that every table is assigned to exactly one domain.
 * This post-pass catches LLM omissions and duplicate assignments.
 */
export function validateDomainAssignments(
  domains: Record<DomainName, string[]>,
  allTables: string[],
  logger: Logger
): { valid: boolean; domains: Record<DomainName, string[]>; warnings: string[] } {
  const warnings: string[] = [];
  const assignedTables = new Set<string>();
  const tableAssignments = new Map<string, string[]>(); // table -> domains it appears in

  // Track all assignments
  for (const [domain, tables] of Object.entries(domains)) {
    for (const table of tables) {
      assignedTables.add(table);
      if (!tableAssignments.has(table)) {
        tableAssignments.set(table, []);
      }
      tableAssignments.get(table)!.push(domain);
    }
  }

  // Check for duplicate assignments (table in multiple domains)
  for (const [table, assignedDomains] of tableAssignments) {
    if (assignedDomains.length > 1) {
      warnings.push(`Table ${table} assigned to multiple domains: ${assignedDomains.join(', ')}. Using first: ${assignedDomains[0]}`);
      // Remove from all but the first domain
      for (let i = 1; i < assignedDomains.length; i++) {
        domains[assignedDomains[i]] = domains[assignedDomains[i]].filter(t => t !== table);
      }
    }
  }

  // Check for unassigned tables
  const unassignedTables = allTables.filter(t => !assignedTables.has(t));
  if (unassignedTables.length > 0) {
    warnings.push(`${unassignedTables.length} tables not assigned to any domain. Assigning to 'uncategorized'.`);
    logger.warn('Unassigned tables detected', { count: unassignedTables.length, tables: unassignedTables.slice(0, 10) });

    // Create 'uncategorized' domain for unassigned tables
    if (!domains['uncategorized']) {
      domains['uncategorized'] = [];
    }
    domains['uncategorized'].push(...unassignedTables);
  }

  // Log warnings
  for (const warning of warnings) {
    logger.warn(warning);
  }

  return {
    valid: unassignedTables.length === 0 && warnings.length === 0,
    domains,
    warnings,
  };
}
```

**Integration**: Call `validateDomainAssignments()` after `inferDomains()` returns, before generating WorkUnits:

```typescript
// In runPlanner after domain inference:
const rawDomains = await inferDomains(dbName, tableMetadata, relationships, config);
const { domains, warnings } = validateDomainAssignments(rawDomains, allTableNames, logger);

if (warnings.length > 0) {
  logger.info('Domain validation completed with warnings', { warningCount: warnings.length });
}
```

---

### Phase 4: Enhanced Planner Implementation

**Objective**: Rewrite the planner to output WorkUnits and integrate all components

**Performance Target**: < 30 seconds for ~100 tables (NFR-P1). Achieved by:
- Using approximate row counts (reltuples, not COUNT(*))
- Single-pass FK queries (not per-table)
- Batched domain inference
- No blocking I/O in hot paths

**Complexity Thresholds** (per PRD2 §4.3):
- `simple`: < 50 tables
- `moderate`: 50-200 tables
- `complex`: > 200 tables

```typescript
function determineComplexity(totalTables: number): 'simple' | 'moderate' | 'complex' {
  if (totalTables < 50) return 'simple';
  if (totalTables <= 200) return 'moderate';
  return 'complex';
}
```

#### Step 4.1: Refactor Main Planner

**File**: `src/agents/planner/index.ts` (major rewrite)

**New Structure**:
```typescript
export async function runPlanner(options: PlannerOptions = {}): Promise<DocumentationPlan> {
  const correlationId = generateCorrelationId();
  const logger = createLogger('planner', correlationId);

  try {
    // Step 0: Load agent config and check if planner is enabled
    const agentConfig = await loadAgentConfig();
    if (!agentConfig.planner.enabled) {
      logger.info('Planner is disabled in agent-config.yaml, skipping');
      throw createPlannerError('configInvalid', 'Planner is disabled in agent-config.yaml. Set planner.enabled=true to run.');
    }

    // Step 1: Load and validate configuration
    const config = await loadAndValidateConfig();
    if (!config.databases || config.databases.length === 0) {
      throw createPlannerError('configInvalid', 'No databases configured in databases.yaml');
    }
    const configHash = await computeConfigHash('config/databases.yaml');

    // Step 2: Check for existing plan (resume logic with schema drift detection)
    if (!options.force) {
      const existingPlan = await loadExistingPlan();
      if (existingPlan) {
        const staleness = await checkPlanStaleness(existingPlan, configHash, config);

        switch (staleness.status) {
          case 'fresh':
            logger.info('Using existing plan (config and schema unchanged)');
            return existingPlan;
          case 'config_changed':
            logger.info('Config changed, replanning required');
            break;
          case 'schema_changed':
            logger.info('Schema drift detected, replanning', {
              changedDatabases: staleness.changedDatabases
            });
            break;
          case 'partial_stale':
            // Mark specific work units as stale but keep others
            logger.info('Partial staleness, updating affected work units', {
              staleWorkUnits: staleness.staleWorkUnits
            });
            // TODO: Implement partial replanning (out of MVP scope)
            break;
        }
      }
    }

    // Step 3: Analyze each database (include ALL configured DBs in output)
    const databases: DatabaseAnalysis[] = [];
    const errors: AgentError[] = [];

    for (const [dbName, dbConfig] of Object.entries(config.databases)) {
      const result = await analyzeDatabase(dbName, dbConfig, logger);
      if (result.success) {
        databases.push(result.analysis);
      } else {
        // IMPORTANT: Include unreachable databases with status='unreachable'
        // This ensures total_databases/reachable_databases are accurate
        databases.push({
          name: dbName,
          type: dbConfig.type,
          status: 'unreachable',
          connection_error: result.error,
          table_count: 0,
          schema_count: 0,
          estimated_time_minutes: 0,
          domains: {},
          schema_hash: '',
        });
        errors.push(result.error);
      }
    }

    // Step 4: Generate work units from domains
    const workUnits = generateWorkUnits(databases);

    // Step 5: Create plan summary
    const summary = computePlanSummary(databases, workUnits);

    // Step 6: Assemble and validate plan
    const plan: DocumentationPlan = {
      schema_version: '1.0',
      generated_at: new Date().toISOString(),
      config_hash: configHash,
      complexity: determineComplexity(summary.total_tables),
      databases,
      work_units: workUnits,
      summary,
      errors,
    };

    // Step 7: Write plan to file
    await writePlan(plan);

    return plan;

  } catch (error) {
    logger.error('Planning phase failed', { error });
    throw error;
  }
}
```

#### Step 4.1a: Staleness Detection Function (NEW)

**File**: `src/agents/planner/staleness.ts` (new)

```typescript
type StalenessStatus = 'fresh' | 'config_changed' | 'schema_changed' | 'partial_stale';

interface StalenessResult {
  status: StalenessStatus;
  changedDatabases?: string[];
  staleWorkUnits?: string[];
}

/**
 * Check if existing plan is still valid by comparing:
 * 1. config_hash - has databases.yaml changed?
 * 2. schema_hash per database - has the schema structure changed?
 * 3. metadata_hash per table - have individual tables changed?
 */
export async function checkPlanStaleness(
  existingPlan: DocumentationPlan,
  currentConfigHash: ContentHash,
  config: DatabaseCatalog
): Promise<StalenessResult> {
  // Level 1: Config-level staleness (fast check)
  if (existingPlan.config_hash !== currentConfigHash) {
    return { status: 'config_changed' };
  }

  // Level 2: Schema-level staleness (requires DB connection)
  const changedDatabases: string[] = [];

  for (const dbAnalysis of existingPlan.databases) {
    if (dbAnalysis.status === 'unreachable') continue;

    const dbConfig = config.databases.find(d => d.name === dbAnalysis.name);
    if (!dbConfig) {
      changedDatabases.push(dbAnalysis.name); // DB removed from config
      continue;
    }

    try {
      // Quick schema hash check - just query table/column structure
      const currentSchemaHash = await computeCurrentSchemaHash(dbConfig);
      if (currentSchemaHash !== dbAnalysis.schema_hash) {
        changedDatabases.push(dbAnalysis.name);
      }
    } catch {
      // Can't connect - mark as changed to trigger replan
      changedDatabases.push(dbAnalysis.name);
    }
  }

  if (changedDatabases.length > 0) {
    return { status: 'schema_changed', changedDatabases };
  }

  // Level 3: Table-level staleness (for incremental updates - post-MVP)
  // Would compare metadata_hash per table to detect column changes

  return { status: 'fresh' };
}

/**
 * Compute schema hash for a database without full analysis.
 * Only queries table names + column definitions, not row counts.
 */
async function computeCurrentSchemaHash(dbConfig: DatabaseConfig): Promise<ContentHash> {
  const connector = getDatabaseConnector(dbConfig.type);
  await connector.connect(getConnectionString(dbConfig));

  // Fast query: just table + column structure
  const tables = await connector.getSchemaStructure(); // Lightweight query
  await connector.disconnect();

  return computeSchemaHash(tables);
}
```

**Reference**: Gap analysis requirement for schema drift detection beyond config_hash.

#### Step 4.2: Database Analysis Function

**File**: `src/agents/planner/analyze-database.ts` (new)

```typescript
export async function analyzeDatabase(
  dbName: string,
  dbConfig: DatabaseConfig,
  logger: Logger
): Promise<{ success: true; analysis: DatabaseAnalysis } | { success: false; error: AgentError }> {

  try {
    const connector = getDatabaseConnector(dbConfig.type);
    await connector.connect(getConnectionString(dbConfig));

    // Get all table metadata
    const tableMetadata = await connector.getAllTableMetadata(
      dbConfig.schemas_include,
      dbConfig.schemas_exclude,
      dbConfig.tables_exclude
    );

    // Get relationships
    const relationships = await connector.getRelationships(tableMetadata);

    // Infer domains using LLM
    let domains: Record<DomainName, string[]>;
    try {
      domains = await inferDomains(dbName, tableMetadata, relationships);
    } catch (error) {
      logger.warn('Domain inference failed, using fallback', { error });
      domains = inferDomainsByPrefix(tableMetadata);
    }

    // Compute schema hash
    const schemaHash = computeSchemaHash(tableMetadata);

    await connector.disconnect();

    return {
      success: true,
      analysis: {
        name: dbName,
        type: dbConfig.type,
        status: 'reachable',
        table_count: tableMetadata.length,
        schema_count: countSchemas(tableMetadata),
        estimated_time_minutes: estimateTime(tableMetadata.length),
        domains,
        schema_hash: schemaHash,
      },
    };

  } catch (error) {
    return {
      success: false,
      error: {
        code: 'PLAN_DB_UNREACHABLE',
        message: `Failed to connect to database ${dbName}: ${error.message}`,
        severity: 'warning',
        timestamp: new Date().toISOString(),
        context: { database: dbName, originalError: error.message },
        recoverable: true,
      },
    };
  }
}
```

#### Step 4.2a: Performance-Optimized Metadata Queries (NEW)

**File**: `src/connectors/postgres.ts` (enhance)

To meet the <30s target for ~100 tables, use efficient metadata queries:

```typescript
/**
 * Get all table metadata in a SINGLE query using pg_class for row estimates.
 * This is 10-100x faster than SELECT COUNT(*) per table.
 */
async function getAllTableMetadataFast(
  schemasInclude?: string[],
  schemasExclude?: string[],
  tablesExclude?: string[]
): Promise<TableMetadata[]> {
  const query = `
    SELECT
      t.table_schema,
      t.table_name,
      c.reltuples::bigint as row_count_approx,  -- Fast: from pg_class
      (
        SELECT COUNT(*)
        FROM information_schema.columns col
        WHERE col.table_schema = t.table_schema
          AND col.table_name = t.table_name
      ) as column_count,
      obj_description(c.oid) as table_comment
    FROM information_schema.tables t
    JOIN pg_class c ON c.relname = t.table_name
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.table_schema
    WHERE t.table_type = 'BASE TABLE'
      AND t.table_schema NOT IN ('pg_catalog', 'information_schema')
      ${schemasInclude ? `AND t.table_schema = ANY($1)` : ''}
      ${schemasExclude ? `AND t.table_schema != ALL($2)` : ''}
    ORDER BY t.table_schema, t.table_name
  `;

  // ... execute query
}

/**
 * Get all FK relationships in a SINGLE query (not per-table).
 * Returns both incoming and outgoing counts.
 */
async function getAllRelationships(): Promise<{
  relationships: Relationship[];
  incomingCounts: Map<string, number>;
  outgoingCounts: Map<string, number>;
}> {
  const query = `
    SELECT
      kcu.table_schema || '.' || kcu.table_name as source_table,
      ccu.table_schema || '.' || ccu.table_name as target_table,
      kcu.column_name as source_column,
      ccu.column_name as target_column,
      tc.constraint_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
  `;

  const rows = await this.query(query);

  // Build counts in a single pass
  const incomingCounts = new Map<string, number>();
  const outgoingCounts = new Map<string, number>();

  for (const row of rows) {
    // Target table has incoming FK
    incomingCounts.set(row.target_table, (incomingCounts.get(row.target_table) || 0) + 1);
    // Source table has outgoing FK
    outgoingCounts.set(row.source_table, (outgoingCounts.get(row.source_table) || 0) + 1);
  }

  return { relationships: rows, incomingCounts, outgoingCounts };
}
```

**Snowflake Equivalent** (`src/connectors/snowflake.ts`):
- Use `INFORMATION_SCHEMA.TABLES.ROW_COUNT` (maintained automatically)
- Use `SHOW IMPORTED KEYS IN DATABASE` for all FKs at once

**Performance Budget**:
| Operation | Target | Notes |
|-----------|--------|-------|
| Connection | < 2s | Per database |
| Table metadata | < 5s | Single query with reltuples |
| FK relationships | < 3s | Single query |
| Domain inference | < 15s | Batched LLM calls |
| Plan write | < 1s | JSON serialization |
| **Total (100 tables)** | **< 30s** | NFR-P1 target |

#### Step 4.3: WorkUnit Generation

**File**: `src/agents/planner/generate-work-units.ts` (new)

```typescript
export function generateWorkUnits(databases: DatabaseAnalysis[]): WorkUnit[] {
  const workUnits: WorkUnit[] = [];
  let priorityOrder = 1;

  for (const db of databases) {
    if (db.status !== 'reachable') continue;

    for (const [domain, tableNames] of Object.entries(db.domains)) {
      const workUnitId = `${db.name}_${domain}`;

      // Get table specs for this domain
      const tables = tableNames.map(tableName =>
        createTableSpec(db, tableName, domain)
      );

      // Sort tables by priority
      tables.sort((a, b) => a.priority - b.priority);

      // Compute content hash for change detection
      const contentHash = computeWorkUnitHash(tables);

      workUnits.push({
        id: workUnitId,
        database: db.name,
        domain,
        tables,
        estimated_time_minutes: estimateWorkUnitTime(tables),
        output_directory: `databases/${db.name}/domains/${domain}`,
        priority_order: priorityOrder++,
        depends_on: [],  // No dependencies between work units
        content_hash: contentHash,
      });
    }
  }

  // Sort work units by priority (core domains first)
  return workUnits.sort((a, b) => {
    const coreDomains = ['customers', 'users', 'orders', 'products'];
    const aCore = coreDomains.includes(a.domain) ? 0 : 1;
    const bCore = coreDomains.includes(b.domain) ? 0 : 1;
    return aCore - bCore || a.priority_order - b.priority_order;
  });
}
```

---

### Phase 5: Configuration and Progress Files

**Objective**: Implement config file schemas and progress tracking

#### Step 5.1: Configuration Schema

**File**: `src/config/schema.ts` (new)

Implement the `DatabaseCatalog` and `DatabaseConfig` interfaces from Appendix B of `agent-contracts-interfaces.md:899-999`.

#### Step 5.2: Config Loader Enhancement

**File**: `src/utils/config.ts` (enhance)

```typescript
export async function loadConfig(): Promise<DatabaseCatalog> {
  const configPath = getConfigPath('databases.yaml');

  if (!await fs.pathExists(configPath)) {
    throw createError('PLAN_CONFIG_NOT_FOUND', `Config not found: ${configPath}`);
  }

  const content = await fs.readFile(configPath, 'utf-8');
  const parsed = yaml.load(content);

  // Validate against schema
  const result = DatabaseCatalogSchema.safeParse(parsed);
  if (!result.success) {
    throw createError('PLAN_CONFIG_INVALID', result.error.message);
  }

  return result.data;
}
```

#### Step 5.3: Agent Config Loader (NEW)

**File**: `src/utils/agent-config.ts` (new)

Load `agent-config.yaml` matching the existing config file structure:

```typescript
import { z } from 'zod';
import yaml from 'js-yaml';
import fs from 'fs/promises';
import path from 'path';

/**
 * Planner config schema - matches existing agent-config.yaml structure
 * Per PRD2 §8.3, planner.enabled controls whether planning phase runs
 */
const PlannerConfigSchema = z.object({
  enabled: z.boolean().default(true),                 // Whether to run planning phase
  domain_inference: z.boolean().default(true),        // LLM-based domain detection
  max_tables_per_database: z.number().default(1000),  // Also used as batch size
  domain_inference_batch_size: z.number().default(100), // Tables per LLM call
});

/**
 * Documenter config schema - for reference (used by Documenter agent)
 */
const DocumenterConfigSchema = z.object({
  concurrency: z.number().default(5),
  sample_timeout_ms: z.number().default(5000),
  llm_model: z.string().default('claude-sonnet-4.5'),  // OpenRouter model ID
  checkpoint_interval: z.number().default(10),
  use_sub_agents: z.boolean().default(true),
});

/**
 * Full agent config schema
 */
const AgentConfigSchema = z.object({
  planner: PlannerConfigSchema,
  documenter: DocumenterConfigSchema.optional(),
  // indexer, retrieval configs parsed but not used by planner
}).passthrough();  // Allow extra fields we don't validate yet

export type PlannerConfig = z.infer<typeof PlannerConfigSchema>;
export type DocumenterConfig = z.infer<typeof DocumenterConfigSchema>;

export async function loadAgentConfig(): Promise<{
  planner: PlannerConfig;
  documenter?: DocumenterConfig;
}> {
  const configPath = path.join(process.cwd(), 'config', 'agent-config.yaml');

  // Use defaults if config doesn't exist
  try {
    await fs.access(configPath);
  } catch {
    return {
      planner: {
        enabled: true,
        domain_inference: true,
        max_tables_per_database: 1000,
      },
    };
  }

  const content = await fs.readFile(configPath, 'utf-8');
  const parsed = yaml.load(content);
  const result = AgentConfigSchema.safeParse(parsed);

  if (!result.success) {
    throw createError('PLAN_CONFIG_INVALID', `agent-config.yaml: ${result.error.message}`);
  }

  return result.data;
}
```

**Note**: Schema matches existing `config/agent-config.yaml`:
- `planner.enabled` → whether to run planning phase
- `planner.domain_inference` → whether to use LLM for domain detection
- `planner.max_tables_per_database` → limit and batch size for domain inference

**Reference**: `agent-contracts-interfaces.md:1001-1124` (Appendix B.2)

---

### Phase 6: Logging and Error Handling

**Objective**: Implement structured logging as specified in the contracts

#### Step 6.1: Logger Enhancement

**File**: `src/utils/logger.ts` (enhance)

Implement the `LogEntry` format from Appendix D of `agent-contracts-interfaces.md:1233-1303`:

#### Step 6.1a: Planner Metrics Emission (NEW)

**File**: `src/agents/planner/metrics.ts` (new)

Per PRD2 §12.2 "Planner Metrics", emit these metrics at planning completion:

```typescript
/**
 * Planner metrics per PRD2 §12.2.
 * Emitted to logs and optionally to metrics collector.
 */
export interface PlannerMetrics {
  // Required metrics
  planning_time_ms: number;          // Total planning duration
  databases_analyzed: number;        // Number of DBs connected
  databases_unreachable: number;     // Number of DBs that failed to connect
  tables_discovered: number;         // Total tables found
  domains_detected: number;          // Number of business domains
  llm_tokens_used: number;           // Domain inference token usage
  llm_calls_made: number;            // Number of LLM API calls

  // Performance metrics
  connection_time_ms: number;        // Time spent connecting
  metadata_query_time_ms: number;    // Time spent querying schemas
  domain_inference_time_ms: number;  // Time spent on LLM calls
  plan_write_time_ms: number;        // Time spent writing JSON

  // Quality metrics
  tables_per_domain_avg: number;     // Average tables per domain
  unassigned_tables: number;         // Tables in 'uncategorized' domain
  domain_validation_warnings: number;// Warnings from validation pass
}

/**
 * Emit planner metrics to structured log.
 * Format matches PRD2 §12.1 structured JSON logging.
 */
export function emitPlannerMetrics(
  metrics: PlannerMetrics,
  logger: Logger,
  correlationId: string
): void {
  logger.info('Planning phase completed', {
    operation: 'plan_complete',
    duration_ms: metrics.planning_time_ms,
    metrics,
  });

  // Emit individual metric log entries for easy aggregation
  logger.info('Planner metric: databases', {
    operation: 'metric',
    metric_name: 'databases_analyzed',
    metric_value: metrics.databases_analyzed,
  });

  logger.info('Planner metric: tables', {
    operation: 'metric',
    metric_name: 'tables_discovered',
    metric_value: metrics.tables_discovered,
  });

  logger.info('Planner metric: domains', {
    operation: 'metric',
    metric_name: 'domains_detected',
    metric_value: metrics.domains_detected,
  });

  logger.info('Planner metric: tokens', {
    operation: 'metric',
    metric_name: 'llm_tokens_used',
    metric_value: metrics.llm_tokens_used,
  });
}

/**
 * Create metrics collector that tracks timing throughout planning.
 */
export function createMetricsCollector(): {
  startTimer: (phase: string) => void;
  stopTimer: (phase: string) => void;
  increment: (metric: string, value?: number) => void;
  getMetrics: () => Partial<PlannerMetrics>;
} {
  const timers: Map<string, number> = new Map();
  const durations: Map<string, number> = new Map();
  const counters: Map<string, number> = new Map();

  return {
    startTimer: (phase) => timers.set(phase, Date.now()),
    stopTimer: (phase) => {
      const start = timers.get(phase);
      if (start) {
        durations.set(phase, Date.now() - start);
      }
    },
    increment: (metric, value = 1) => {
      counters.set(metric, (counters.get(metric) || 0) + value);
    },
    getMetrics: () => ({
      planning_time_ms: durations.get('total'),
      connection_time_ms: durations.get('connection'),
      metadata_query_time_ms: durations.get('metadata'),
      domain_inference_time_ms: durations.get('domain_inference'),
      plan_write_time_ms: durations.get('write'),
      llm_tokens_used: counters.get('llm_tokens') || 0,
      llm_calls_made: counters.get('llm_calls') || 0,
      databases_analyzed: counters.get('databases') || 0,
      tables_discovered: counters.get('tables') || 0,
      domains_detected: counters.get('domains') || 0,
    }),
  };
}
```

**Usage in runPlanner()**:
```typescript
const metrics = createMetricsCollector();
metrics.startTimer('total');

// ... planning logic ...
metrics.increment('databases', databases.filter(d => d.status === 'reachable').length);
metrics.increment('tables', summary.total_tables);
metrics.increment('domains', summary.domain_count);

metrics.stopTimer('total');
emitPlannerMetrics(metrics.getMetrics() as PlannerMetrics, logger, correlationId);
```

```typescript
interface LogEntry {
  timestamp: ISOTimestamp;
  level: LogLevel;
  agent: AgentName;
  work_unit_id?: string;
  correlation_id: string;
  message: string;
  context?: Record<string, unknown>;
}

export function createLogger(agent: AgentName, correlationId: string): Logger {
  return {
    debug: (msg, ctx) => log('debug', agent, correlationId, msg, ctx),
    info: (msg, ctx) => log('info', agent, correlationId, msg, ctx),
    warn: (msg, ctx) => log('warn', agent, correlationId, msg, ctx),
    error: (msg, ctx) => log('error', agent, correlationId, msg, ctx),
    child: (context) => createChildLogger(agent, correlationId, context),
  };
}
```

---

### Phase 7: CLI and Testing

**Objective**: Update CLI commands and add tests

#### Step 7.1: CLI Commands

**File**: `src/cli/plan.ts` (new)

```typescript
import { Command } from 'commander';

export const planCommand = new Command('plan')
  .description('Analyze database schemas and create documentation plan')
  .option('--force', 'Force re-planning even if config unchanged')
  .option('--dry-run', 'Show what would be planned without executing')
  .option('--json', 'Output plan as JSON instead of summary')
  .action(async (options) => {
    const plan = await runPlanner(options);

    if (options.json) {
      console.log(JSON.stringify(plan, null, 2));
      return;
    }

    // Human-readable plan review output (FR-0.5)
    displayPlanSummary(plan);
  });
```

#### Step 7.1a: Plan Review Output (FR-0.5)

**File**: `src/cli/plan-display.ts` (new)

Implement human-readable plan review per FR-0.5 ("Allow user review and modification of plan before execution").

#### Step 7.1b: Plan Validation Command (NEW - FR-0.5 Guardrails)

**File**: `src/cli/plan-validate.ts` (new)

Add `npm run plan:validate` to validate user-edited plans before running Documenter:

```typescript
import { Command } from 'commander';
import { validatePlan } from '../contracts/validators.js';
import { loadPlan } from '../utils/plan-io.js';
import chalk from 'chalk';

export const planValidateCommand = new Command('plan:validate')
  .description('Validate documentation-plan.json (catches errors in user edits)')
  .option('--plan <path>', 'Path to plan file', 'progress/documentation-plan.json')
  .option('--strict', 'Fail on warnings, not just errors')
  .action(async (options) => {
    console.log(chalk.cyan('Validating plan...'));

    try {
      // Step 1: Load and parse JSON
      const plan = await loadPlan(options.plan);

      // Step 2: Schema validation (Zod)
      const schemaResult = validatePlan(plan);
      if (!schemaResult.success) {
        console.log(chalk.red('Schema validation failed:'));
        for (const error of schemaResult.errors) {
          console.log(`  ${chalk.red('✗')} ${error.path}: ${error.message}`);
        }
        process.exit(1);
      }
      console.log(chalk.green('  ✓ Schema valid'));

      // Step 3: Semantic validation (catches logical errors)
      const warnings: string[] = [];
      const errors: string[] = [];

      // Check: All tables in work_units exist in database analysis
      const allDbTables = new Set(
        plan.databases.flatMap(db =>
          Object.values(db.domains).flat()
        )
      );
      for (const wu of plan.work_units) {
        for (const table of wu.tables) {
          if (!allDbTables.has(table.table_name)) {
            errors.push(`WorkUnit ${wu.id}: table "${table.table_name}" not found in any database`);
          }
        }
      }

      // Check: No duplicate table assignments
      const tableAssignments = new Map<string, string[]>();
      for (const wu of plan.work_units) {
        for (const table of wu.tables) {
          if (!tableAssignments.has(table.fully_qualified_name)) {
            tableAssignments.set(table.fully_qualified_name, []);
          }
          tableAssignments.get(table.fully_qualified_name)!.push(wu.id);
        }
      }
      for (const [table, wuIds] of tableAssignments) {
        if (wuIds.length > 1) {
          errors.push(`Table "${table}" appears in multiple work units: ${wuIds.join(', ')}`);
        }
      }

      // Check: Work unit IDs are unique
      const wuIds = new Set<string>();
      for (const wu of plan.work_units) {
        if (wuIds.has(wu.id)) {
          errors.push(`Duplicate work unit ID: ${wu.id}`);
        }
        wuIds.add(wu.id);
      }

      // Check: No cyclic dependencies
      const depsResult = validateNoCycles(plan.work_units);
      if (!depsResult.valid) {
        errors.push(`Cyclic dependency detected: ${depsResult.cycle?.join(' -> ')}`);
      }

      // Check: content_hash is present (warns if empty - user may have cleared it)
      for (const wu of plan.work_units) {
        if (!wu.content_hash) {
          warnings.push(`WorkUnit ${wu.id}: content_hash is empty (will be regenerated)`);
        }
      }

      // Check: Unreachable databases have no work units
      const unreachableDBs = plan.databases.filter(d => d.status === 'unreachable').map(d => d.name);
      for (const wu of plan.work_units) {
        if (unreachableDBs.includes(wu.database)) {
          errors.push(`WorkUnit ${wu.id}: references unreachable database "${wu.database}"`);
        }
      }

      // Report results
      if (warnings.length > 0) {
        console.log(chalk.yellow('Warnings:'));
        for (const w of warnings) {
          console.log(`  ${chalk.yellow('⚠')} ${w}`);
        }
      }

      if (errors.length > 0) {
        console.log(chalk.red('Errors:'));
        for (const e of errors) {
          console.log(`  ${chalk.red('✗')} ${e}`);
        }
        process.exit(1);
      }

      if (options.strict && warnings.length > 0) {
        console.log(chalk.red('Validation failed (strict mode): warnings present'));
        process.exit(1);
      }

      console.log(chalk.green('\n✓ Plan is valid'));
      console.log(chalk.dim(`  ${plan.work_units.length} work units, ${plan.summary.total_tables} tables`));

    } catch (error) {
      console.log(chalk.red(`Validation error: ${error.message}`));
      process.exit(1);
    }
  });
```

**Implicit validation in Documenter**: The Documenter should also call `validatePlan()` before starting execution:

```typescript
// In src/agents/documenter/index.ts
export async function runDocumenter(options: DocumenterOptions = {}): Promise<void> {
  const plan = await loadPlan(options.planPath);

  // Validate before running (catches user edit errors)
  const validation = validatePlan(plan);
  if (!validation.success) {
    throw createError('DOC_PLAN_INVALID', 'Plan validation failed. Run `npm run plan:validate` for details.');
  }

  // ... proceed with documentation
}
```

**package.json script**:
```json
{
  "scripts": {
    "plan:validate": "tsx src/cli/plan-validate.ts"
  }
}
```

```typescript
import chalk from 'chalk';

export function displayPlanSummary(plan: DocumentationPlan): void {
  console.log('\n' + chalk.bold('=== Documentation Plan ===\n'));

  // Summary stats
  console.log(chalk.cyan('Summary:'));
  console.log(`  Databases:     ${plan.summary.reachable_databases}/${plan.summary.total_databases}`);
  console.log(`  Tables:        ${plan.summary.total_tables}`);
  console.log(`  Work Units:    ${plan.summary.total_work_units}`);
  console.log(`  Domains:       ${plan.summary.domain_count}`);
  console.log(`  Est. Time:     ${plan.summary.total_estimated_minutes} minutes`);
  console.log(`  Parallelism:   ${plan.summary.recommended_parallelism} workers`);
  console.log(`  Complexity:    ${plan.complexity}`);

  // Domain breakdown
  console.log('\n' + chalk.cyan('Domains by Database:'));
  for (const db of plan.databases) {
    console.log(`\n  ${chalk.bold(db.name)} (${db.type}, ${db.table_count} tables)`);
    for (const [domain, tables] of Object.entries(db.domains)) {
      console.log(`    ${domain}: ${tables.length} tables`);
    }
  }

  // Work units overview
  console.log('\n' + chalk.cyan('Work Units (processing order):'));
  for (const wu of plan.work_units.slice(0, 10)) {  // Show first 10
    console.log(`  ${wu.priority_order}. ${wu.id} - ${wu.tables.length} tables (~${wu.estimated_time_minutes}m)`);
  }
  if (plan.work_units.length > 10) {
    console.log(`  ... and ${plan.work_units.length - 10} more work units`);
  }

  // Errors if any
  if (plan.errors.length > 0) {
    console.log('\n' + chalk.yellow('Warnings/Errors:'));
    for (const err of plan.errors) {
      console.log(`  [${err.severity}] ${err.code}: ${err.message}`);
    }
  }

  // Next steps
  console.log('\n' + chalk.green('Plan saved to: progress/documentation-plan.json'));
  console.log(chalk.dim('Review the plan, then run: npm run document'));
}
```

**User can review and modify**:
1. View plan with `npm run plan` (displays summary above)
2. View full JSON with `npm run plan -- --json`
3. Edit `progress/documentation-plan.json` to adjust domain assignments or priorities
4. Run `npm run document` to proceed

**Reference**: PRD1 FR-0.5, US-8

#### Step 7.2: Unit Tests

**File**: `tests/planner/index.test.ts` (new)

Test cases:
1. Plan generation with mock database
2. Domain inference with mock LLM
3. WorkUnit generation correctness
4. Change detection via config hash
5. Error handling for unreachable databases
6. Fallback domain inference when LLM fails

#### Step 7.2a: Integration Tests (NEW)

**File**: `tests/planner/integration.test.ts` (new)

Add fixture-based end-to-end test with a sample Postgres catalog:

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { runPlanner } from '../../src/agents/planner/index.js';
import { validatePlan } from '../../src/contracts/validators.js';
import { DocumentationPlan } from '../../src/contracts/types.js';
import { spawn } from 'child_process';
import path from 'path';

/**
 * Integration test using a real Postgres fixture database.
 * Requires: Docker for test database container
 *
 * Test database contains:
 * - 10 tables across 3 domains (customers, orders, inventory)
 * - Foreign key relationships
 * - Sample row counts
 */
describe('Planner Integration Tests', () => {
  let testDbUrl: string;
  let plan: DocumentationPlan;

  beforeAll(async () => {
    // Start test Postgres container with fixture data
    // docker-compose -f tests/fixtures/docker-compose.test.yml up -d
    testDbUrl = process.env.TEST_DATABASE_URL || 'postgresql://test:test@localhost:5433/testdb';

    // Override config to use test database
    process.env.PRODUCTION_DATABASE_URL = testDbUrl;
  }, 60000); // 60s timeout for container startup

  afterAll(async () => {
    // Cleanup: stop container
    // docker-compose -f tests/fixtures/docker-compose.test.yml down
  });

  it('should generate a valid plan for the fixture database', async () => {
    plan = await runPlanner({ force: true });

    expect(plan).toBeDefined();
    expect(plan.schema_version).toBe('1.0');
  });

  it('should produce valid plan JSON schema', () => {
    const validation = validatePlan(plan);
    expect(validation.success).toBe(true);
  });

  it('should discover all fixture tables', () => {
    // Fixture has 10 tables
    expect(plan.summary.total_tables).toBe(10);
  });

  it('should detect expected domains', () => {
    // Fixture has customers, orders, inventory domains
    const domainNames = plan.databases[0].domains;
    expect(Object.keys(domainNames)).toContain('customers');
    expect(Object.keys(domainNames)).toContain('orders');
  });

  it('should populate all required TableSpec fields', () => {
    for (const wu of plan.work_units) {
      for (const table of wu.tables) {
        expect(table.fully_qualified_name).toBeDefined();
        expect(table.row_count_approx).toBeGreaterThanOrEqual(0);
        expect(table.incoming_fk_count).toBeGreaterThanOrEqual(0);
        expect(table.outgoing_fk_count).toBeGreaterThanOrEqual(0);
        expect(table.metadata_hash).toHaveLength(64); // SHA-256
      }
    }
  });

  it('should generate work units with content hashes', () => {
    for (const wu of plan.work_units) {
      expect(wu.content_hash).toHaveLength(64);
      expect(wu.id).toMatch(/^[a-z_]+_[a-z_]+$/); // database_domain format
    }
  });

  it('should complete within performance target (<30s)', () => {
    // Measured by test runner, logged above
    // This is asserted by the test timeout
  });
});

/**
 * LLM-off fallback test: verify planner works without API key
 */
describe('Planner LLM-Off Fallback', () => {
  beforeAll(() => {
    // Unset API keys to force fallback
    delete process.env.OPENROUTER_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;
  });

  it('should use prefix-based domain inference when LLM unavailable', async () => {
    const plan = await runPlanner({ force: true });

    expect(plan).toBeDefined();
    // Plan should still be valid, just with simpler domain assignments
    const validation = validatePlan(plan);
    expect(validation.success).toBe(true);

    // Domains should be based on table prefixes (e.g., 'cust_' -> 'cust')
    // or all in 'uncategorized' if no patterns detected
    expect(plan.summary.domain_count).toBeGreaterThan(0);
  });

  it('should log warning about LLM fallback', async () => {
    // Check logs for PLAN_DOMAIN_INFERENCE_FAILED warning
    // This would be verified by log capture in test setup
  });
});
```

**Fixture Database Schema** (`tests/fixtures/init.sql`):
```sql
-- Customers domain
CREATE TABLE customers (id SERIAL PRIMARY KEY, name VARCHAR(100), email VARCHAR(255));
CREATE TABLE addresses (id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(id), street TEXT);
CREATE TABLE customer_preferences (id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(id), theme VARCHAR(50));

-- Orders domain
CREATE TABLE orders (id SERIAL PRIMARY KEY, customer_id INT REFERENCES customers(id), total DECIMAL(10,2), created_at TIMESTAMP);
CREATE TABLE order_items (id SERIAL PRIMARY KEY, order_id INT REFERENCES orders(id), product_id INT, quantity INT);
CREATE TABLE order_status (id SERIAL PRIMARY KEY, order_id INT REFERENCES orders(id), status VARCHAR(50), changed_at TIMESTAMP);

-- Inventory domain
CREATE TABLE products (id SERIAL PRIMARY KEY, name VARCHAR(200), price DECIMAL(10,2));
CREATE TABLE categories (id SERIAL PRIMARY KEY, name VARCHAR(100));
CREATE TABLE product_categories (product_id INT REFERENCES products(id), category_id INT REFERENCES categories(id), PRIMARY KEY (product_id, category_id));
CREATE TABLE inventory_levels (id SERIAL PRIMARY KEY, product_id INT REFERENCES products(id), quantity INT);

-- Insert sample data for row count estimates
INSERT INTO customers (name, email) SELECT 'Customer ' || i, 'customer' || i || '@test.com' FROM generate_series(1, 100) i;
INSERT INTO products (name, price) SELECT 'Product ' || i, (random() * 100)::decimal(10,2) FROM generate_series(1, 50) i;
```

**Docker Compose** (`tests/fixtures/docker-compose.test.yml`):
```yaml
version: '3.8'
services:
  test-postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: testdb
    ports:
      - "5433:5432"
    volumes:
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test"]
      interval: 5s
      timeout: 5s
      retries: 5
```

**package.json scripts**:
```json
{
  "scripts": {
    "test:integration": "docker-compose -f tests/fixtures/docker-compose.test.yml up -d && sleep 5 && vitest run tests/planner/integration.test.ts && docker-compose -f tests/fixtures/docker-compose.test.yml down",
    "test:unit": "vitest run tests/planner/index.test.ts"
  }
}
```

---

## File Summary

| File | Action | Description |
|------|--------|-------------|
| `src/contracts/types.ts` | Create | All TypeScript interfaces |
| `src/contracts/errors.ts` | Create | Error code registry |
| `src/contracts/validators.ts` | Create | Validation functions |
| `src/utils/hash.ts` | Create | Hash computation utilities |
| `src/utils/llm.ts` | Enhance | Actual Claude API integration |
| `src/utils/logger.ts` | Enhance | Structured JSON logging |
| `src/utils/config.ts` | Enhance | Config validation |
| `src/agents/planner/index.ts` | Rewrite | Main planner with WorkUnits |
| `src/agents/planner/domain-inference.ts` | Create | LLM-based domain detection |
| `src/agents/planner/analyze-database.ts` | Create | Database analysis logic |
| `src/agents/planner/generate-work-units.ts` | Create | WorkUnit generation |
| `src/config/schema.ts` | Create | Config Zod schemas |
| `src/cli/plan.ts` | Create | CLI command |
| `tests/planner/*.test.ts` | Create | Unit tests |

---

## Dependencies

### NPM Packages to Add

```json
{
  "chalk": "^5.3.0"
}
```

**Note**:
- `chalk` is used for CLI plan review output (Step 7.1a)
- `openai` package is already installed (used for OpenRouter via OpenAI-compatible API)
- No `@anthropic-ai/sdk` needed - using OpenRouter instead

### NPM Packages NOT Used by Planner

| Package | Status | Notes |
|---------|--------|-------|
| `openai` | NOT USED | Planner uses OpenRouter (OpenAI-compatible). Only Indexer uses OpenAI for embeddings. |
| `@anthropic-ai/sdk` | NOT USED | All LLM calls go through OpenRouter. |

**Dependency Cleanup**: If `openai` was listed as a Planner dependency, remove it. The Planner only needs:
- `chalk` - CLI output
- `js-yaml` - Config parsing
- `zod` - Validation
- `commander` - CLI framework
- Node.js built-ins (`crypto`, `fs`, `path`)

### Environment Variables Required

**Required for Planner**:

| Variable | Purpose | Required? | Fallback |
|----------|---------|-----------|----------|
| `OPENROUTER_API_KEY` | Domain inference LLM calls | Optional | Prefix-based domain detection |
| Database URLs (per config) | Connect to source databases | Required | Planner fails with PLAN_DB_UNREACHABLE |

**NOT Required for Planner** (used by other agents):

| Variable | Used By | Purpose |
|----------|---------|---------|
| `OPENAI_API_KEY` | Indexer | Embedding generation |
| `ANTHROPIC_API_KEY` | N/A | Not used (all LLM via OpenRouter) |

**Config Files Required**:

| File | Purpose | Required? |
|------|---------|-----------|
| `config/databases.yaml` | Database connection configs | Required |
| `config/agent-config.yaml` | Agent behavior settings | Optional (has defaults) |

**Failure Modes**:

```typescript
// Missing databases.yaml → PLAN_CONFIG_NOT_FOUND (fatal)
// Invalid databases.yaml → PLAN_CONFIG_INVALID (fatal)
// Missing OPENROUTER_API_KEY → Falls back to prefix-based domains (warning)
// Missing database connection env → PLAN_DB_UNREACHABLE (warning, continues with other DBs)
```

---

## Success Criteria

### Automated Verification

| Criterion | Target | Verification |
|-----------|--------|--------------|
| TypeScript compilation | Zero errors | `npm run build` |
| All databases in output | 100% (including unreachable) | `plan.databases.length === config.databases.length` |
| Unreachable DBs visible | Have status='unreachable' | `databases.filter(d => d.status === 'unreachable')` |
| WorkUnits generated | One per domain per database | `plan.work_units.length > 0` |
| Content hashes computed | All work units have hash | `work_units.every(wu => wu.content_hash.length === 64)` |
| Config hash computed | Non-empty 64-char hex | `plan.config_hash.length === 64` |
| Schema hash computed | Per database | `databases.every(d => d.schema_hash.length === 64)` |
| Validation passes | All output matches schema | `validatePlan(plan)` succeeds |
| TableSpec complete | All required fields populated | See table below |
| Plan summary complete | Has all required fields | `plan.summary.recommended_parallelism > 0` |
| Domain coverage | 100% tables assigned | No tables in 'uncategorized' (or explicit handling) |
| Integration tests pass | Fixture DB test green | `npm run test:integration` |
| LLM-off fallback test | Works without API key | `npm run test:unit` (LLM fallback tests) |

**TableSpec Required Fields Verification**:
```typescript
for (const wu of plan.work_units) {
  for (const table of wu.tables) {
    assert(table.fully_qualified_name, 'fully_qualified_name required');
    assert(table.row_count_approx >= 0, 'row_count_approx required');
    assert(table.incoming_fk_count >= 0, 'incoming_fk_count required');
    assert(table.outgoing_fk_count >= 0, 'outgoing_fk_count required');
    assert(table.column_count > 0, 'column_count required');
    assert(table.metadata_hash.length === 64, 'metadata_hash required');
  }
}
```

### Manual Verification

| Criterion | Target | Verification |
|-----------|--------|--------------|
| LLM domain inference | Works with fallback | Run with `OPENROUTER_API_KEY` unset, verify fallback |
| Batching for large DBs | Handles 500+ tables | Test with large database |
| CLI plan review | Human-readable output | Run `npm run plan`, verify summary display |
| CLI plan validate | Catches user edit errors | Edit plan JSON incorrectly, run `npm run plan:validate` |
| Errors structured | Using `AgentError` format | Inspect error JSON in plan output |
| Error codes mapped | Correct severity/recoverable | Trigger each error type, verify mapping |
| Logging structured | JSON format with correlation ID | Review log output |
| Metrics emitted | All PRD2 §12.2 metrics | Check logs for planner metrics |
| Performance | < 30s for 100 tables | NFR-P1: Measure planning time |
| Config enabled check | Respects planner.enabled | Set enabled=false, verify planner exits |
| Schema drift detection | Triggers replan on change | Modify DB, run plan, verify schema_changed |

---

## Code References

- Current planner: `TribalAgent/src/agents/planner/index.ts:1-207`
- Database connector: `TribalAgent/src/connectors/postgres.ts:1-270`
- Domain inference prompt: `TribalAgent/prompts/domain-inference.md:1-28`
- Contract interfaces: `TribalAgent/planning/agent-contracts-interfaces.md:87-257`
- Execution model: `TribalAgent/planning/agent-contracts-execution.md:39-145`
- Error codes: `TribalAgent/planning/agent-contracts-interfaces.md:781-893`

---

## Architecture Documentation

The Planner follows the **Deep Agent** pattern:
1. **Planning Tool**: The Planner IS the planning tool - it creates the documentation plan
2. **Filesystem Memory**: Outputs `progress/documentation-plan.json`
3. **System Prompts**: Uses `prompts/domain-inference.md` for LLM calls

The key architectural decision is **WorkUnit-based parallelization**:
- Tables are grouped by business domain
- Each WorkUnit is self-contained and can be processed independently
- The Documenter will spawn parallel sub-agents per WorkUnit
- Content hashes enable incremental re-documentation

---

## Related Research

- `TribalAgent/planning/tribal-knowledge-plan.md` - Overall project plan
- `TribalAgent/planning/agent-contracts-summary.md` - Contract overview
- `TribalAgent/planning/tribal-knowledge-prd2-technical.md` - Technical specification

---

## Resolved Design Decisions

1. **Batch size for large databases**: ✅ RESOLVED
   - **Decision**: Batch domain inference when table count exceeds `domain_inference_batch_size` (default: 100)
   - **Implementation**: Step 3.3 adds `inferDomainsInBatches()` function
   - **Config**: `agent-config.yaml` → `planner.domain_inference_batch_size`

2. **Cross-database domains**: ✅ DEFERRED (Out of MVP Scope)
   - **Decision**: Domains remain per-database for MVP
   - **Rationale**: PRD1 §7.3 lists "Custom domain configuration" as out of scope
   - **Future**: Could add cross-database domain linking post-MVP

3. **Snowflake connector testing**: ✅ ACKNOWLEDGED
   - **Decision**: Focus on PostgreSQL first; Snowflake is lower priority
   - **Mitigation**: Mock tests for Snowflake connector; real testing when instance available
   - **Reference**: PRD1 §8.2 lists Snowflake test database as "TBD"

4. **Connector signature alignment**: ✅ RESOLVED
   - **Decision**: Update connector interface to match config structure
   - **Implementation**: `getAllTableMetadata(schemas_include?, schemas_exclude?, tables_exclude?)`
   - **Reference**: Verify `src/connectors/postgres.ts` interface matches

---

## File Summary (Updated)

| File | Action | Description |
|------|--------|-------------|
| `src/contracts/types.ts` | Create | All TypeScript interfaces (complete TableSpec, PlanSummary) |
| `src/contracts/errors.ts` | Create | Error code registry + PLANNER_ERROR_MAP taxonomy |
| `src/contracts/validators.ts` | Create | Validation functions (validatePlan, validateNoCycles) |
| `src/utils/hash.ts` | Create | Hash computation utilities (schema, table, config) |
| `src/utils/llm.ts` | Enhance | Actual Claude API integration via OpenRouter |
| `src/utils/logger.ts` | Enhance | Structured JSON logging with LogEntry format |
| `src/utils/config.ts` | Enhance | Config validation |
| `src/utils/agent-config.ts` | Create | Agent config loader for agent-config.yaml |
| `src/utils/plan-io.ts` | Create | Plan file loading/saving utilities |
| `src/agents/planner/index.ts` | Rewrite | Main planner with WorkUnits, enabled check, metrics |
| `src/agents/planner/domain-inference.ts` | Create | LLM-based domain detection with batching + validation |
| `src/agents/planner/analyze-database.ts` | Create | Database analysis with fast metadata queries |
| `src/agents/planner/generate-work-units.ts` | Create | WorkUnit generation with TableSpec population |
| `src/agents/planner/staleness.ts` | Create | Plan staleness/schema drift detection |
| `src/agents/planner/metrics.ts` | Create | PlannerMetrics emission per PRD2 §12.2 |
| `src/connectors/postgres.ts` | Enhance | Fast metadata queries using reltuples |
| `src/connectors/snowflake.ts` | Enhance | Use INFORMATION_SCHEMA.TABLES.ROW_COUNT |
| `src/config/schema.ts` | Create | Config Zod schemas |
| `src/cli/plan.ts` | Create | CLI command (plan, plan --json, plan --force) |
| `src/cli/plan-display.ts` | Create | Human-readable plan review output |
| `src/cli/plan-validate.ts` | Create | Plan validation command (FR-0.5 guardrails) |
| `tests/planner/index.test.ts` | Create | Unit tests |
| `tests/planner/integration.test.ts` | Create | E2E test with fixture database |
| `tests/fixtures/init.sql` | Create | Test database schema |
| `tests/fixtures/docker-compose.test.yml` | Create | Test database container |

---

*End of Implementation Plan*
