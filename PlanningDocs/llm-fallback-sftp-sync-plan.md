# Implementation Plan: LLM Fallback & SFTP Sync

**Created**: December 13, 2025  
**Status**: Planning  
**Priority**: High

---

## Overview

This plan covers two features:
1. **LLM Fallback**: Enable GPT-4o as a backup when OpenRouter (Claude) calls fail
2. **SFTP Sync**: Push index database and documentation to SFTP server with backup of existing files

---

## Part 1: LLM Fallback (OpenRouter → GPT-4o)

### Problem Statement
Currently, the system uses OpenRouter to call Claude models. If OpenRouter is unavailable, rate-limited, or experiencing issues, the entire pipeline fails. We need a fallback to OpenAI's GPT-4o to ensure resilience.

### Current Architecture

```
src/utils/llm.ts
├── getOpenRouterClient() - Claude via OpenRouter
├── getOpenAIClient() - Embeddings only (currently)
├── callClaude() - OpenRouter API call
├── callOpenAI() - OpenAI direct call (exists but not used as fallback)
└── callLLM() - Main entry point with retry logic
```

### Affected Components

| Component | File | LLM Usage |
|-----------|------|-----------|
| **Planner** | `src/agents/planner/domain-inference.ts` | Domain grouping via `callLLM('claude-sonnet-4')` |
| **Documenter** | `src/agents/documenter/sub-agents/ColumnInferencer.ts` | Column descriptions via `callLLM('claude-sonnet-4')` |
| **Documenter** | `src/agents/documenter/sub-agents/TableDocumenter.ts` | Table descriptions via `callLLM('claude-sonnet-4')` |
| **Indexer** | `src/agents/indexer/embeddings.ts` | Uses OpenAI directly (embeddings) - no change needed |

### Implementation Plan

#### Step 1.1: Update `src/utils/llm.ts` - Add Fallback Logic

**Changes:**
1. Add a new `callLLMWithFallback()` function or modify `callLLM()` to:
   - First attempt: OpenRouter (Claude)
   - On failure (after retries): Fallback to OpenAI GPT-4o
   - Log when fallback is triggered

2. Add environment variable check for `OPENAI_API_KEY` (required for fallback)

3. Add configuration option to enable/disable fallback

**New Configuration** (`config/agent-config.yaml`):
```yaml
llm:
  primary_provider: openrouter  # or 'openai'
  fallback_enabled: true
  fallback_provider: openai
  fallback_model: gpt-4o
  primary_model: claude-sonnet-4
```

**Key Point**: The fallback uses your **existing `OPENAI_API_KEY`** (the same one already configured for embeddings). No new API key needed!

**Pseudo-code for fallback logic:**
```typescript
export async function callLLM(prompt: string, model: string, options?: LLMOptions): Promise<LLMResponse> {
  const fallbackEnabled = process.env.LLM_FALLBACK_ENABLED !== 'false';
  
  try {
    // Primary: OpenRouter (Claude) - uses OPENROUTER_API_KEY
    return await callWithRetries(prompt, model, options);
  } catch (primaryError) {
    // Fallback requires OPENAI_API_KEY (already configured for embeddings)
    if (!fallbackEnabled || !process.env.OPENAI_API_KEY) {
      throw primaryError;
    }
    
    logger.warn(`Primary LLM (${model}) failed, falling back to GPT-4o`, {
      primaryError: primaryError.message,
    });
    
    try {
      // Fallback: OpenAI GPT-4o - uses existing OPENAI_API_KEY
      const fallbackModel = process.env.LLM_FALLBACK_MODEL || 'gpt-4o';
      return await callOpenAI(prompt, fallbackModel, options?.maxTokens);
    } catch (fallbackError) {
      // Both failed - throw combined error
      throw new Error(`Both primary (${model}) and fallback (gpt-4o) failed: ${primaryError.message} | ${fallbackError.message}`);
    }
  }
}
```

#### Step 1.2: Update Environment Variables

**No new API key needed!** The fallback uses your existing `OPENAI_API_KEY` (already set for embeddings).

**Add to `.env.example`:**
```bash
# LLM Fallback Configuration (uses existing OPENAI_API_KEY for GPT-4o)
LLM_FALLBACK_ENABLED=true
LLM_FALLBACK_MODEL=gpt-4o
```

#### Step 1.3: Update Agents (Minimal Changes)

The agents already use `callLLM()` from utils, so they will automatically get fallback support. However, we should:

1. **Log fallback events** at the agent level for visibility
2. **Update error handling** to distinguish between "all providers failed" vs "recovered via fallback"

#### Step 1.4: Testing

1. **Unit test**: Mock OpenRouter failure, verify GPT-4o is called
2. **Integration test**: Temporarily disable OpenRouter key, verify fallback works
3. **Manual test**: Run pipeline with verbose logging to confirm fallback behavior

### Files to Modify

| File | Changes |
|------|---------|
| `src/utils/llm.ts` | Add fallback logic to `callLLM()` |
| `config/agent-config.yaml` | Add `llm.fallback_*` settings |
| `src/config/schema.ts` | Add schema for new config options |
| `.env.example` | Document fallback env vars |
| `memory-bank/techContext.md` | Document fallback behavior |

### Estimated Effort
- **Development**: 2-3 hours
- **Testing**: 1 hour
- **Documentation**: 30 minutes

---

## Part 2: SFTP Sync

### Problem Statement
After running the documentation pipeline, we need to sync the generated artifacts to a remote SFTP server for access by other systems. The sync should:
- Backup existing remote files before overwriting
- Upload the index database (`tribal-knowledge.db`)
- Upload documentation files (`documentation-manifest.json` + database folders)

### SFTP Server Details

| Property | Value |
|----------|-------|
| **Host** | `129.158.231.129` |
| **Port** | `4100` |
| **User** | `gauntlet` |
| **Auth** | Password (interactive) or SSH key |
| **Protocol** | SFTP only (no SSH shell) |

### Remote Directory Structure

```
/data/
├── index/
│   └── index.db                     # ← tribal-knowledge.db (RENAMED)
└── map/
    ├── documentation-manifest.json  # ← docs/documentation-manifest.json
    ├── postgres_production/         # ← docs/databases/postgres_production/
    │   └── tables/*.md, *.json
    └── snowflake_production/        # ← docs/databases/snowflake_production/
        └── tables/*.md, *.json
```

**Important**: 
- `tribal-knowledge.db` is renamed to `index.db` on upload
- `documentation-manifest.json` lives in `/data/map/` alongside the database folders

### Local Directory Structure (Source)

```
TribalAgent/
├── data/
│   └── tribal-knowledge.db          # → SFTP /data/index/index.db (RENAMED)
└── docs/
    ├── documentation-manifest.json  # → SFTP /data/map/documentation-manifest.json
    └── databases/
        ├── {db_name}/               # → SFTP /data/map/{db_name}/
        │   └── tables/*.md, *.json
```

### Implementation Plan

#### Step 2.1: Create SFTP Sync Module

**New file**: `src/utils/sftp-sync.ts`

```typescript
/**
 * SFTP Sync Module
 * 
 * Handles synchronization of index database and documentation to remote SFTP server.
 * Includes backup functionality for existing remote files.
 * 
 * File Mapping:
 * - data/tribal-knowledge.db → /data/index/index.db (RENAMED)
 * - docs/documentation-manifest.json → /data/map/documentation-manifest.json
 * - docs/databases/{db_name}/ → /data/map/{db_name}/
 */

import { Client } from 'ssh2-sftp-client';
import { logger } from './logger.js';
import * as path from 'path';
import * as fs from 'fs/promises';

export interface SFTPConfig {
  host: string;
  port: number;
  username: string;
  password?: string;
  privateKey?: string;
}

export interface SyncOptions {
  backupBeforeUpload: boolean;
  backupSuffix?: string;  // e.g., '.backup-2025-12-13'
}

export class SFTPSyncService {
  private config: SFTPConfig;
  
  constructor(config: SFTPConfig) {
    this.config = config;
  }
  
  /**
   * Sync index database to SFTP
   * Local: data/tribal-knowledge.db → Remote: /data/index/index.db (RENAMED)
   */
  async syncIndex(localDbPath: string, options: SyncOptions): Promise<void>;
  
  /**
   * Sync documentation to SFTP
   * - docs/documentation-manifest.json → /data/map/documentation-manifest.json
   * - docs/databases/{db_name}/ → /data/map/{db_name}/
   */
  async syncDocs(localDocsPath: string, options: SyncOptions): Promise<void>;
  
  /**
   * Full sync: index + docs
   */
  async syncAll(options: SyncOptions): Promise<SyncResult>;
  
  /**
   * Backup remote file/directory before overwriting
   */
  private async backupRemote(remotePath: string, suffix: string): Promise<void>;
}
```

#### Step 2.2: Add SFTP Dependencies

**Update `package.json`:**
```json
{
  "dependencies": {
    "ssh2-sftp-client": "^10.0.0"
  },
  "devDependencies": {
    "@types/ssh2-sftp-client": "^9.0.0"
  }
}
```

#### Step 2.3: Create CLI Command

**New file**: `src/cli/sync.ts`

```typescript
/**
 * CLI command: npm run sync
 * 
 * Usage:
 *   npm run sync              # Sync all (index + docs) with backup
 *   npm run sync:index        # Sync index only
 *   npm run sync:docs         # Sync docs only
 *   npm run sync:no-backup    # Sync without backup
 */
```

**Update `package.json` scripts:**
```json
{
  "scripts": {
    "sync": "tsx src/cli/sync.ts",
    "sync:index": "tsx src/cli/sync.ts --index-only",
    "sync:docs": "tsx src/cli/sync.ts --docs-only",
    "sync:no-backup": "tsx src/cli/sync.ts --no-backup"
  }
}
```

#### Step 2.4: Environment Configuration

**Add to `.env.example`:**
```bash
# SFTP Sync Configuration
SFTP_HOST=129.158.231.129
SFTP_PORT=4100
SFTP_USER=gauntlet
SFTP_PASSWORD=           # Or use SFTP_PRIVATE_KEY_PATH
SFTP_PRIVATE_KEY_PATH=   # Path to SSH private key

# Remote paths (defaults shown)
SFTP_REMOTE_INDEX_PATH=/data/index
SFTP_REMOTE_MAP_PATH=/data/map
```

#### Step 2.5: Sync Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                         SFTP Sync Workflow                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Connect to SFTP server                                       │
│     ↓                                                            │
│  2. Check if backup needed                                       │
│     ├─ Yes: Rename /data/index/index.db → index.db.backup-{ts}  │
│     │       Rename /data/map/* → *.backup-{ts}                   │
│     └─ No: Continue                                              │
│     ↓                                                            │
│  3. Upload index database (RENAMED)                              │
│     Local: data/tribal-knowledge.db                              │
│     Remote: /data/index/index.db                                 │
│     ↓                                                            │
│  4. Upload documentation manifest                                │
│     Local: docs/documentation-manifest.json                      │
│     Remote: /data/map/documentation-manifest.json                │
│     ↓                                                            │
│  5. Upload database folders                                      │
│     Local: docs/databases/{db_name}/                             │
│     Remote: /data/map/{db_name}/                                 │
│     ↓                                                            │
│  6. Verify upload                                                │
│     - Check file sizes match                                     │
│     - Log success/failure                                        │
│     ↓                                                            │
│  7. Disconnect                                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Step 2.6: Backup Strategy

**Remote backup naming convention:**
```
/data/index/
├── index.db                    # Current
└── backups/
    ├── index.db.2025-12-13-001  # Backup 1
    ├── index.db.2025-12-13-002  # Backup 2
    └── ...

/data/map/
├── postgres_production/        # Current
├── snowflake_production/       # Current
└── backups/
    ├── postgres_production.2025-12-13-001/
    └── snowflake_production.2025-12-13-001/
```

**Backup retention policy:**
- Keep last 5 backups per database
- Auto-cleanup older backups during sync
- Manual cleanup via `npm run sync:cleanup`

### Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `src/utils/sftp-sync.ts` | **CREATE** | SFTP sync service |
| `src/cli/sync.ts` | **CREATE** | CLI command handler |
| `package.json` | **MODIFY** | Add sftp dependency + scripts |
| `.env.example` | **MODIFY** | Add SFTP config vars |
| `config/agent-config.yaml` | **MODIFY** | Add sftp section |
| `memory-bank/techContext.md` | **MODIFY** | Document SFTP sync |

### Estimated Effort
- **Development**: 4-5 hours
- **Testing**: 2 hours (requires SFTP access)
- **Documentation**: 1 hour

---

## Implementation Order

### Phase 1: LLM Fallback (Day 1)
1. [ ] Update `src/utils/llm.ts` with fallback logic
2. [ ] Add config schema for fallback options
3. [ ] Update `.env.example`
4. [ ] Test with OpenRouter disabled
5. [ ] Update memory-bank docs

### Phase 2: SFTP Sync (Day 1-2)
1. [ ] Install `ssh2-sftp-client` dependency
2. [ ] Create `src/utils/sftp-sync.ts`
3. [ ] Create `src/cli/sync.ts`
4. [ ] Add npm scripts
5. [ ] Update `.env.example` with SFTP config
6. [ ] Test with real SFTP server
7. [ ] Update memory-bank docs

### Phase 3: Integration (Day 2)
1. [ ] Add `npm run pipeline:deploy` that runs `pipeline` + `sync`
2. [ ] End-to-end testing
3. [ ] Update README with deployment instructions

---

## Configuration Summary

### Environment Variables (New)

```bash
# LLM Fallback (uses existing OPENAI_API_KEY - no new key needed!)
LLM_FALLBACK_ENABLED=true
LLM_FALLBACK_MODEL=gpt-4o

# SFTP Sync
SFTP_HOST=129.158.231.129
SFTP_PORT=4100
SFTP_USER=gauntlet
SFTP_PASSWORD=your-password
SFTP_REMOTE_INDEX_PATH=/data/index
SFTP_REMOTE_MAP_PATH=/data/map
```

### New npm Scripts

```bash
# LLM (no new scripts, just config)

# SFTP Sync
npm run sync              # Full sync with backup
npm run sync:index        # Index only
npm run sync:docs         # Docs only
npm run sync:no-backup    # Skip backup

# Combined
npm run pipeline:deploy   # plan + document + index + sync
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| OpenAI API key not configured | **Low** (already set for embeddings) | High | Check on startup, warn user |
| SFTP password stored in plaintext | Medium | Medium | Support SSH key auth |
| Large file upload timeout | Low | Medium | Implement resumable uploads |
| Backup storage grows unbounded | Low | Low | Auto-cleanup policy |
| GPT-4o response format differs from Claude | Medium | Medium | Normalize response parsing |

---

## Success Criteria

### LLM Fallback
- [ ] Pipeline completes when OpenRouter is unavailable (uses GPT-4o)
- [ ] Fallback is logged clearly
- [ ] Both providers failing results in clear error message
- [ ] No changes needed in agent code (transparent fallback)

### SFTP Sync
- [ ] `npm run sync` uploads index.db to `/data/index/`
- [ ] `npm run sync` uploads docs to `/data/map/`
- [ ] Existing files are backed up before overwrite
- [ ] Sync works with password auth
- [ ] Sync works with SSH key auth
- [ ] Failed sync doesn't corrupt remote state

---

## Questions/Decisions Needed

1. **Backup retention**: How many backups to keep? (Proposed: 5)
2. **SSH key path**: Should we default to `~/.ssh/id_rsa` or require explicit config?
3. **Partial sync**: If docs sync fails after index sync, should we rollback?
4. **Pipeline integration**: Should sync be part of default `npm run pipeline` or separate?

---

## References

- [ssh2-sftp-client npm](https://www.npmjs.com/package/ssh2-sftp-client)
- [OpenAI GPT-4o API](https://platform.openai.com/docs/models/gpt-4o)
- Current LLM integration: `src/utils/llm.ts`
- SFTP server details from user testing (Dec 13, 2025)

