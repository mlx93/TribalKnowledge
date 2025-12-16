# Action Plan: Fix MCP Relationship Discovery

## Priority 1: Debug & Fix FK Extraction (CRITICAL) 🔥

### Issue
`get_common_relationships()` and `get_join_path()` returning empty target tables

### Root Cause Investigation

**Step 1**: Check actual table documentation format
```bash
# Look at a real sales_order_lines doc
cat docs/synthetic_250_postgres/.../synthetic.sales_order_lines.md
```

**Look for**:
- How are foreign keys formatted in the markdown?
- What pattern do they follow?
- Do they match the regex in `relationships.ts`?

**Step 2**: Check what the documenter outputs

Read: `TribalAgent/src/agents/documenter/sub-agents/TableDocumenter.ts`

**Questions**:
- How does it format FK references?
- Does it use Unicode arrow `→` or ASCII `->`?
- Is schema name included?

**Step 3**: Test regex patterns

```typescript
// Test these patterns against ACTUAL doc content
const patterns = [
  /`(\w+)`\s*→\s*`(?:(\w+)\.)?(\w+)\.(\w+)`/g,
  /`(\w+)`\s*->\s*`(?:(\w+)\.)?(\w+)\.(\w+)`/g,
];

// Try on real content from your docs
const sampleContent = `...`; // Paste actual FK section
patterns.forEach(p => console.log(p.exec(sampleContent)));
```

### Fix Options

**Option A**: Fix the regex patterns
- Adjust patterns to match actual documentation format
- Add more lenient patterns
- Add debug logging to see what's being parsed

**Option B**: Fix the documenter output
- Ensure FKs are written in expected format
- Standardize on one format (e.g., always use `→` with backticks)

**Option C**: Both
- Standardize output format
- Make parser more robust

### Testing

After fix, verify:
```bash
# Re-run indexer
cd TribalAgent
npm run index:fresh

# Test MCP tool
# Should now show complete relationships
```

---

## Priority 2: Enhance MCP Tools

### Add `get_column_usage()` Tool

**File**: `TribalAgent/src/agents/retrieval/tools/column-usage.ts`

**Implementation**:
```typescript
export async function getColumnUsage(
  db: DatabaseType,
  columnName: string,
  database?: string
) {
  // Query all tables with this column using parameterized queries
  // to prevent SQL injection
  const params: string[] = [`%${columnName}%`];
  
  let query = `
    SELECT DISTINCT
      database_name,
      schema_name,
      table_name,
      doc_type
    FROM documents
    WHERE content LIKE ?
      AND doc_type IN ('table', 'column')
  `;
  
  if (database) {
    query += ` AND database_name = ?`;
    params.push(database);
  }
  
  const results = db.prepare(query).all(...params);
  
  // Build relationship map
  // Find common join patterns
  // Return structured result
}
```

### Enhance `get_join_path()` Output

**File**: `TribalAgent/src/agents/retrieval/tools/join-path.ts`

**Changes**:
```typescript
// Current: Returns minimal info
// New: Return complete path with SQL

export interface EnhancedJoinPath {
  found: boolean;
  hop_count: number;
  confidence: number;
  complete_sql: string;  // ✅ NEW
  path: {
    tables: string[];  // ✅ NEW - all intermediate tables
    joins: {  // ✅ ENHANCED
      from_table: string;
      to_table: string;
      on_clause: string;  // ✅ Complete join condition
      join_type: string;  // ✅ INNER/LEFT/RIGHT
      cardinality: string;  // ✅ 1:1, 1:N, N:M
    }[];
  };
  alternative_paths?: EnhancedJoinPath[];  // ✅ NEW
}
```

---

## Priority 3: Add Cross-Domain Documentation

### Create Relationship Map Files

**New documenter task**: Generate cross-domain relationship maps

**File**: `docs/{database}/cross_domain_relationships.md`

**Content**:
```markdown
# Cross-Domain Relationships

## Sales → Procurement

### Revenue to Cost (Margin Analysis)
- **Use Case**: Calculate profit margins
- **Path**: sales_order_lines → supplier_products → purchase_order_lines
- **Join Key**: product_id (common across all three)
- **SQL Pattern**:
  ```sql
  FROM sales_order_lines sol
  JOIN supplier_products sp ON sol.product_id = sp.product_id
  JOIN purchase_order_lines pol ON sp.product_id = pol.product_id
  ```

## Sales → Inventory

### Order to Stock
- **Use Case**: Check product availability
- **Path**: sales_order_lines → inventory_items
- **Join Key**: product_id
```

**Implementation location**: 
`TribalAgent/src/agents/documenter/generators/cross-domain-map.ts`

---

## Priority 4: Add Query Pattern Templates

### Create Pattern Documentation

**New directory**: `docs/{database}/query_patterns/`

**Files to create**:
1. `margin_analysis.md` - Revenue to cost joins
2. `inventory_availability.md` - Sales to inventory
3. `supplier_performance.md` - Supplier metrics
4. `customer_lifetime_value.md` - Customer aggregations

**Example**: `margin_analysis.md`
```markdown
# Query Pattern: Margin Analysis

## Business Question
"What's the profit margin on each sales order?"

## Required Tables (6)
1. sales_orders - Order header
2. sales_order_lines - Revenue per line
3. supplier_products - Product-supplier costs
4. suppliers - Supplier information
5. purchase_orders - Procurement header
6. purchase_order_lines - Actual costs paid

## Join Path
[Visual diagram]

## SQL Template
[Complete working SQL]

## Key Metrics
- Revenue: SUM(sales_order_lines.line_total)
- COGS: SUM(purchase_order_lines.unit_cost × quantity)
- Margin: Revenue - COGS
- Margin %: (Margin / Revenue) × 100

## Considerations
- Use preferred suppliers for cost
- Filter PO status to 'completed'
- Handle NULL costs (no PO data)
```

---

## Priority 5: Add Semantic Metadata

### Extend Table Schema with Roles

**File**: Update table documentation to include:

```json
{
  "table": "sales_order_lines",
  "semantic_roles": [
    "transaction_detail",
    "revenue_source",
    "product_reference"
  ],
  "analysis_patterns": [
    "revenue_reporting",
    "margin_analysis",
    "product_performance"
  ],
  "typical_joins": [
    {
      "table": "sales_orders",
      "type": "parent",
      "frequency": "always"
    },
    {
      "table": "purchase_order_lines",
      "type": "cost_lookup",
      "frequency": "for_margin_analysis",
      "path": "via supplier_products"
    }
  ]
}
```

**Implementation**: Add to documenter's table schema generation

---

## Implementation Checklist

### Phase 1: Critical Bug Fix (Week 1)
- [ ] Debug FK extraction in indexer
- [ ] Check actual doc formats
- [ ] Fix regex patterns or documenter output
- [ ] Re-index test database
- [ ] Verify `get_join_path()` returns complete info
- [ ] Verify `get_common_relationships()` shows target tables

### Phase 2: Enhanced Tools (Week 2)
- [ ] Implement `get_column_usage()` tool
- [ ] Enhance `get_join_path()` output format
- [ ] Add complete SQL generation
- [ ] Add confidence scoring
- [ ] Add alternative paths option

### Phase 3: Documentation (Week 3)
- [ ] Generate cross-domain relationship maps
- [ ] Create query pattern templates
- [ ] Add to documenter pipeline
- [ ] Update MCP to expose patterns

### Phase 4: Semantic Enrichment (Week 4)
- [ ] Add semantic roles to tables
- [ ] Add typical joins metadata
- [ ] Add analysis pattern tags
- [ ] Update search to use semantic info

---

## Success Criteria

After these fixes, this query should work instantly:

**User**: "What's the true margin on sales orders after procurement costs?"

**AI Response** (in 10 seconds):
> "I found a 6-table join path to calculate margins. The path is:
> sales_orders → sales_order_lines → supplier_products → suppliers → purchase_orders → purchase_order_lines
> 
> Here's the complete SQL query ready to run on Supabase..."

**Tools used**:
1. `search_db_map("margin sales procurement")` → finds "margin_analysis" pattern
2. `get_query_pattern("margin_analysis")` → returns complete template
3. Done! ✅

**Time saved**: From 10 minutes to 10 seconds = **60x faster**

---

## Testing Plan

### Test Case 1: FK Extraction
```bash
# After fix, check relationships table
sqlite3 data/tribal-knowledge.db
SELECT source_table, target_table, join_sql 
FROM relationships 
WHERE source_table = 'sales_order_lines'
LIMIT 5;

# Should show:
# sales_order_lines | sales_orders | ...complete join SQL...
# NOT:
# sales_order_lines | (empty) | (empty)
```

### Test Case 2: Join Path Discovery
```typescript
// Should return complete path
get_join_path("sales_order_lines", "purchase_order_lines")

// Expected:
// - Shows ALL intermediate tables
// - Has complete join conditions
// - Includes generated SQL
```

### Test Case 3: Column Usage
```typescript
get_column_usage("product_id")

// Expected:
// - Lists 12+ tables
// - Shows join suggestions
// - Groups by domain
```

### Test Case 4: Query Patterns
```typescript
search_db_map("profit margin sales")

// Expected:
// - Finds "margin_analysis" pattern
// - Returns template SQL
// - Lists required tables
```

---

## Files to Create/Modify

### Create New Files
1. `TribalAgent/src/agents/retrieval/tools/column-usage.ts`
2. `TribalAgent/src/agents/retrieval/tools/query-patterns.ts`
3. `TribalAgent/src/agents/documenter/generators/cross-domain-map.ts`
4. `TribalAgent/src/agents/documenter/generators/query-patterns.ts`
5. `docs/{database}/cross_domain_relationships.md` (template)
6. `docs/{database}/query_patterns/*.md` (templates)

### Modify Existing Files
1. `TribalAgent/src/agents/indexer/relationships.ts` - Fix FK extraction
2. `TribalAgent/src/agents/retrieval/tools/join-path.ts` - Enhanced output
3. `TribalAgent/src/agents/documenter/sub-agents/TableDocumenter.ts` - Standardize FK format
4. Table schema types to include semantic metadata

---

## Questions to Answer

Before implementing, clarify:

1. **FK Format**: What format are FKs currently in the docs?
2. **Documenter**: How does TableDocumenter output FK info?
3. **Schema**: Do we have FK constraint info from the database?
4. **Indexer logs**: Any errors during FK extraction?
5. **Test data**: Can we test on a simple 3-table join first?

---

## Next Steps

1. **Read actual table doc** to see FK format
2. **Debug indexer** with added logging
3. **Fix FK extraction** (highest ROI)
4. **Test** with simple joins
5. **Then** add enhanced features

**Start here**: 
```bash
cat docs/synthetic_250_postgres/.../synthetic.sales_order_lines.md | grep -A 5 "Foreign"
```
