# Agent Prompt: Implement Planner Schema Analyzer (Module 1)

## Context

You are implementing the **Planner Schema Analyzer** (Module 1) for the Tribal Knowledge Deep Agent system. This is the first module in a pipeline that automatically documents database schemas.

## Your Task

Implement the Planner Schema Analyzer according to the detailed implementation plan located at:

```
thoughts/shared/research/2025-12-10-planner-schema-analyzer-implementation-plan.md
```

**Read this file completely before starting implementation.**

## Critical Reference Documents

Before writing any code, you MUST read these planning documents in this order:

1. **Implementation Plan** (your primary guide):
   - `thoughts/shared/research/2025-12-10-planner-schema-analyzer-implementation-plan.md`

2. **Contract Interfaces** (TypeScript types you must implement):
   - `TribalAgent/planning/agent-contracts-interfaces.md`
   - Focus on: §2 Common Types, §3 Planner Output Interfaces, Appendix A (Error Codes), Appendix B (Config Schemas), Appendix C (LLM Wrapper)

3. **Execution Model** (how agents hand off work):
   - `TribalAgent/planning/agent-contracts-execution.md`
   - Focus on: §3 Agent Boundary Contracts, §4 Validation Rules

4. **Existing Code** (understand current implementation):
   - `TribalAgent/src/agents/planner/index.ts` - Current basic implementation
   - `TribalAgent/src/connectors/postgres.ts` - Database connector
   - `TribalAgent/src/utils/llm.ts` - LLM utilities (needs enhancement)
   - `TribalAgent/prompts/domain-inference.md` - Prompt template for domain detection

## Implementation Requirements

### Phase 1: Core Contracts (Do First)

Create these files with exact interfaces from `agent-contracts-interfaces.md`:

```
src/contracts/
├── types.ts        # All TypeScript interfaces (§2-§3 of contracts doc)
├── errors.ts       # Error code registry (Appendix A)
└── validators.ts   # Validation functions
```

### Phase 2: Utilities

```
src/utils/
├── hash.ts         # NEW: computeHash(), computeConfigHash(), computeSchemaHash()
├── llm.ts          # ENHANCE: Implement actual Anthropic Claude API call
└── logger.ts       # ENHANCE: Structured JSON logging with correlation IDs
```

### Phase 3: Planner Module (Main Work)

```
src/agents/planner/
├── index.ts                  # REWRITE: Main runPlanner() with WorkUnit output
├── domain-inference.ts       # NEW: LLM-based domain detection
├── analyze-database.ts       # NEW: Database analysis with error handling
└── generate-work-units.ts    # NEW: WorkUnit generation from domains
```

## Key Output Format

The Planner MUST output `progress/documentation-plan.json` with this structure:

```typescript
interface DocumentationPlan {
  schema_version: '1.0';
  generated_at: ISOTimestamp;
  config_hash: ContentHash;           // SHA-256 of databases.yaml
  complexity: 'simple' | 'moderate' | 'complex';
  databases: DatabaseAnalysis[];
  work_units: WorkUnit[];             // KEY: This enables parallel documentation
  summary: PlanSummary;
  errors: AgentError[];
}
```

**WorkUnits are critical** - they enable the downstream Documenter to process domains in parallel.

## Key Technical Decisions

1. **LLM Integration**: Use `@anthropic-ai/sdk` to call Claude with the `prompts/domain-inference.md` template
2. **Fallback**: If LLM fails, fall back to prefix-based domain grouping (existing logic)
3. **Hashing**: Use SHA-256 for all content hashes
4. **Error Handling**: Use structured `AgentError` format with error codes from `errors.ts`
5. **Logging**: JSON format with correlation IDs for tracing

## Success Criteria

Your implementation is complete when:

- [ ] All interfaces from `agent-contracts-interfaces.md` §2-§3 are implemented in `src/contracts/types.ts`
- [ ] Error codes from Appendix A are in `src/contracts/errors.ts`
- [ ] `runPlanner()` outputs a valid `DocumentationPlan` with WorkUnits
- [ ] LLM-based domain inference works (with fallback)
- [ ] Content hashes are computed for change detection
- [ ] Config hash enables staleness detection
- [ ] Structured logging with correlation IDs
- [ ] All validation passes against the contract schemas
- [ ] TypeScript compiles without errors

## Do NOT

- Do NOT modify the database connector interfaces (they work)
- Do NOT change the prompt templates (they are finalized)
- Do NOT implement the Documenter, Indexer, or Retriever - only the Planner
- Do NOT add new dependencies without justification
- Do NOT skip reading the planning documents

## Getting Started

1. Read `thoughts/shared/research/2025-12-10-planner-schema-analyzer-implementation-plan.md` completely
2. Read the contract interfaces document
3. Create `src/contracts/types.ts` first
4. Implement phase by phase as specified in the plan
5. Test with the existing PostgreSQL connector

## Questions to Answer Before Starting

After reading the documents, confirm you understand:

1. What is a WorkUnit and why is it important?
2. What is the handoff contract between Planner and Documenter?
3. How does config_hash enable staleness detection?
4. What error codes does the Planner use?
5. What happens if LLM domain inference fails?

Begin by reading the implementation plan document, then proceed systematically through the phases.
