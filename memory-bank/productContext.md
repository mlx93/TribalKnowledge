# Product Context: Tribal Knowledge Deep Agent

## Why This Project Exists

Organizations struggle with "tribal knowledge" - critical data understanding locked in individual minds. This creates:
- Slow onboarding for new team members
- Dependencies on specific individuals
- Inefficient data discovery workflows
- Poor documentation maintenance

## Problems It Solves

### 1. Discovery Friction
**Problem**: Data scientists spend hours finding which tables contain relevant data for their analysis.

**Solution**: Natural language search that understands queries like "customer churn" or "monthly revenue" and returns relevant tables with context.

### 2. Schema Confusion
**Problem**: Cryptic column names (e.g., `cust_id`, `txn_amt`) don't reveal their meaning.

**Solution**: LLM-powered semantic inference that generates human-readable descriptions based on column names, data types, and sample values.

### 3. Join Complexity
**Problem**: Understanding how tables relate requires deep knowledge of foreign key relationships.

**Solution**: Automatic join path discovery with pre-computed SQL snippets showing how to connect tables.

### 4. Documentation Debt
**Problem**: Manual documentation becomes outdated quickly and requires constant maintenance.

**Solution**: Automated documentation generation that stays synchronized with actual database schemas.

## How It Should Work

### User Workflow

1. **Setup** (One-time)
   - Configure database connections in `config/databases.yaml`
   - Set environment variables for API keys
   - Run `npm run plan` to analyze schemas

2. **Documentation** (As needed)
   - Review generated `documentation-plan.json`
   - Run `npm run document` to generate docs
   - System automatically:
     - Connects to databases
     - Extracts metadata
     - Infers semantic descriptions
     - Generates Markdown, JSON Schema, YAML

3. **Indexing** (After documentation)
   - Run `npm run index` to build search index
   - System generates embeddings and populates SQLite

4. **Search** (Ongoing)
   - Run `npm run serve` to start MCP server
   - External AI agents query via MCP tools
   - Users can also query directly

### Key User Experiences

**Data Scientist Experience**:
```
Query: "find tables related to customer churn"
→ Returns: customers, orders, subscriptions, churn_events
→ Each result includes: description, key columns, sample data
→ Can drill down: get_table_schema("production.customers")
→ Can discover joins: get_join_path("customers", "orders")
```

**Data Engineer Experience**:
```
1. Add new database to config
2. Run: npm run orchestrate
3. System automatically plans, documents, indexes
4. Review generated docs in /docs directory
5. Done - documentation stays current
```

**AI Agent Experience**:
```
MCP Tool Call: search_tables("monthly revenue by region")
→ Returns: Structured JSON with relevant tables
→ Includes token count for context budgeting
→ Compressed to fit within limits
→ High-signal, low-noise results
```

## User Experience Goals

### Simplicity
- Single command to run full pipeline (`npm run orchestrate`)
- Smart detection of what needs to be done
- Clear progress indicators
- Helpful error messages

### Reliability
- Checkpoint recovery after failures
- Partial success handling (90% documented > 0%)
- Graceful degradation (text search if embeddings fail)
- Transparent state (always know what's happening)

### Consistency
- All descriptions follow template patterns
- Factual grounding (no speculation)
- Predictable output formats
- Professional documentation quality

### Performance
- Fast search (<500ms p95)
- Efficient documentation (<5 min for 100 tables)
- Incremental updates (only re-process changed tables)
- Parallel processing where possible

## Business Value

- **Reduced time-to-insight**: Data scientists find relevant data in seconds, not hours
- **Lower onboarding costs**: New analysts become productive faster
- **Eliminated dependencies**: Knowledge no longer locked in individual minds
- **AI enablement**: External agents can autonomously discover data context
- **Documentation maintenance**: 90% reduction in manual documentation effort

## Target Outcomes

1. **Data Scientists**: Can find relevant tables in < 30 seconds
2. **Data Engineers**: Full documentation in single command
3. **AI Agents**: Receive sufficient context for SQL generation
4. **New Team Members**: Understand data landscape during onboarding

## Out of Scope (MVP)

- Real-time schema change detection
- Multi-user concurrent access
- Cloud-hosted deployment
- PII/sensitive data detection
- Custom domain configuration (auto-detect only)
- Views and materialized views (tables only for MVP)
- Stored procedures and functions
- Autonomous re-documentation
