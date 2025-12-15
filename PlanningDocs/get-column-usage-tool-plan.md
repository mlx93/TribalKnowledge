# Plan: Implement `get_column_usage()` MCP Tool

**Date**: December 14, 2025  
**Status**: Ready for Implementation  
**Priority**: 2 (after documenter enhancements)  
**Repository**: [Company-MCP](https://github.com/nstjuliana/Company-MCP/)

---

## Overview

Implement a new MCP tool `get_column_usage()` that finds all tables containing a specific column name and suggests join patterns through common columns. This addresses the gap identified when implicit joins (tables sharing column names but lacking FK constraints) couldn't be discovered.

### Problem Statement

When asked "What's the margin on sales orders?", the MCP tools found individual tables but couldn't discover that:
- `sales_order_lines.product_id`
- `supplier_products.product_id`  
- `purchase_order_lines.product_id`

...all share `product_id` and can be joined, even without explicit FK constraints.

### Solution

A new tool that:
1. Finds all tables containing a column name
2. Groups results by business domain
3. Suggests common join patterns
4. Identifies bridge tables

---

## Tool Specification

### Function Signature

```python
def get_column_usage(
    column_name: str,           # Column to search for (e.g., "product_id")
    database: str = "",         # Optional database filter
    domain: str = "",           # Optional domain filter
    include_patterns: bool = True  # Include suggested join patterns
) -> ColumnUsageResult
```

### Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `column_name` | string | Yes | Column name to search for (e.g., "product_id", "customer_id") |
| `database` | string | No | Filter by database name |
| `domain` | string | No | Filter by business domain |
| `include_patterns` | bool | No | Include suggested join patterns (default: true) |

### Output Schema

```python
class ColumnUsageResult:
    column: str                    # The searched column name
    total_tables: int              # Total tables containing this column
    tables: List[TableUsage]       # Detailed table info
    join_patterns: List[JoinPattern]  # Suggested join patterns
    tokens_used: int               # For billing/limits

class TableUsage:
    table_name: str                # Table name
    schema_name: str               # Schema name
    database: str                  # Database name
    domain: str                    # Business domain
    column_role: str               # "primary_key" | "foreign_key" | "attribute"
    references: Optional[str]      # If FK, what it references
    data_type: str                 # Column data type
    semantic_role: Optional[str]   # From semantic metadata if available

class JoinPattern:
    pattern_name: str              # e.g., "revenue_to_cost"
    description: str               # Business use case
    tables: List[str]              # Tables involved
    bridge_table: Optional[str]    # Intermediate table if needed
    example_sql: str               # Ready-to-use SQL snippet
```

### Example Response

```json
{
  "column": "product_id",
  "total_tables": 25,
  "tables": [
    {
      "table_name": "sales_order_lines",
      "schema_name": "synthetic",
      "database": "synthetic_250_postgres",
      "domain": "sales",
      "column_role": "foreign_key",
      "references": "products.product_id",
      "data_type": "integer",
      "semantic_role": "transaction_detail"
    },
    {
      "table_name": "purchase_order_lines",
      "schema_name": "synthetic",
      "database": "synthetic_250_postgres",
      "domain": "inventory_and_supply_chain",
      "column_role": "foreign_key",
      "references": "products.product_id",
      "data_type": "integer",
      "semantic_role": "transaction_detail"
    },
    {
      "table_name": "supplier_products",
      "schema_name": "synthetic",
      "database": "synthetic_250_postgres",
      "domain": "inventory_and_supply_chain",
      "column_role": "foreign_key",
      "references": "products.product_id",
      "data_type": "integer",
      "semantic_role": "bridge_table"
    }
  ],
  "join_patterns": [
    {
      "pattern_name": "revenue_to_cost",
      "description": "Link sales revenue to procurement costs for margin analysis",
      "tables": ["sales_order_lines", "supplier_products", "purchase_order_lines"],
      "bridge_table": "supplier_products",
      "example_sql": "SELECT sol.*, sp.unit_cost, pol.unit_cost as actual_cost\nFROM sales_order_lines sol\nJOIN supplier_products sp ON sol.product_id = sp.product_id\nJOIN purchase_order_lines pol ON sp.product_id = pol.product_id"
    },
    {
      "pattern_name": "sales_to_inventory",
      "description": "Check stock availability for ordered products",
      "tables": ["sales_order_lines", "inventory_items"],
      "bridge_table": null,
      "example_sql": "SELECT sol.*, ii.quantity_on_hand\nFROM sales_order_lines sol\nJOIN inventory_items ii ON sol.product_id = ii.product_id"
    }
  ],
  "tokens_used": 450
}
```

---

## Implementation Details

### Location in Company-MCP

```
Company-MCP/
├── server.py              # Add tool registration
├── tools/
│   ├── __init__.py
│   ├── search.py          # Existing search tools
│   ├── schema.py          # Existing schema tools
│   └── column_usage.py    # NEW: get_column_usage implementation
└── utils/
    └── patterns.py        # NEW: Join pattern inference logic
```

### Data Sources

The tool queries the indexed SQLite database (`data/index/index.db`):

```sql
-- Find all tables with the column
SELECT DISTINCT
    d.database_name,
    d.schema_name,
    d.table_name,
    d.domain,
    json_extract(d.content, '$.semantic_roles') as semantic_roles
FROM documents d
WHERE d.doc_type = 'table'
  AND d.content LIKE '%"name": "' || ? || '"%'
  AND (? = '' OR d.database_name = ?)
  AND (? = '' OR d.domain = ?);
```

### Pattern Inference Logic

1. **Group tables by domain**
2. **Identify cross-domain pairs** (same column, different domains)
3. **Find bridge tables** (tables that connect domains)
4. **Generate SQL snippets** for each pattern

```python
def infer_join_patterns(tables: List[TableUsage], column_name: str) -> List[JoinPattern]:
    patterns = []
    
    # Group by domain
    by_domain = group_by(tables, lambda t: t.domain)
    
    # Find cross-domain opportunities
    domains = list(by_domain.keys())
    for i, domain1 in enumerate(domains):
        for domain2 in domains[i+1:]:
            # Check if there's a bridge table
            bridge = find_bridge_table(by_domain[domain1], by_domain[domain2], column_name)
            
            patterns.append(JoinPattern(
                pattern_name=f"{domain1}_to_{domain2}",
                description=f"Join {domain1} and {domain2} data via {column_name}",
                tables=[t.table_name for t in by_domain[domain1] + by_domain[domain2]],
                bridge_table=bridge,
                example_sql=generate_join_sql(...)
            ))
    
    return patterns
```

### Known Join Patterns (Hardcoded)

For common business scenarios, include pre-defined patterns:

```python
KNOWN_PATTERNS = {
    "product_id": [
        {
            "name": "margin_analysis",
            "description": "Calculate profit margins by linking sales to costs",
            "domains": ["sales", "inventory_and_supply_chain"],
            "tables": ["sales_order_lines", "supplier_products", "purchase_order_lines"],
        },
        {
            "name": "inventory_check",
            "description": "Check stock availability for products",
            "domains": ["sales", "inventory"],
            "tables": ["sales_order_lines", "inventory_items"],
        }
    ],
    "customer_id": [
        {
            "name": "customer_360",
            "description": "Complete customer view across orders, support, payments",
            "domains": ["sales", "customer_service", "finance"],
        }
    ],
    "employee_id": [
        {
            "name": "hr_analysis",
            "description": "Employee data across HR, payroll, projects",
            "domains": ["human_resources", "finance", "projects"],
        }
    ]
}
```

---

## Integration Steps

### Step 1: Clone and Branch

```bash
cd /Users/mylessjs/Desktop/Tribal_Knowledge
git clone https://github.com/nstjuliana/Company-MCP.git
cd Company-MCP
git checkout -b feature/get-column-usage
```

### Step 2: Create Tool File

Create `tools/column_usage.py` with:
- `get_column_usage()` function
- Query logic against index.db
- Pattern inference logic

### Step 3: Register Tool in server.py

```python
from tools.column_usage import get_column_usage

@mcp.tool()
def mcp_get_column_usage(
    column_name: str,
    database: str = "",
    domain: str = "",
    include_patterns: bool = True
) -> dict:
    """
    Find all tables containing a specific column and suggest join patterns.
    
    Args:
        column_name: Column to search for (e.g., "product_id")
        database: Optional database filter
        domain: Optional domain filter
        include_patterns: Include suggested join patterns (default: true)
    
    Returns:
        Dict with tables list, join patterns, and token count
    """
    return get_column_usage(column_name, database, domain, include_patterns)
```

### Step 4: Test Locally

```bash
# Run MCP server locally
python server.py

# Test with curl or MCP client
curl -X POST http://localhost:8000/tools/get_column_usage \
  -H "Content-Type: application/json" \
  -d '{"column_name": "product_id"}'
```

### Step 5: Create PR

```bash
git add .
git commit -m "feat: add get_column_usage tool for cross-table column discovery"
git push origin feature/get-column-usage
# Create PR on GitHub
```

---

## Testing Plan

### Unit Tests

```python
def test_get_column_usage_basic():
    result = get_column_usage("product_id")
    assert result["total_tables"] > 0
    assert "tables" in result
    assert all("table_name" in t for t in result["tables"])

def test_get_column_usage_with_database_filter():
    result = get_column_usage("product_id", database="synthetic_250_postgres")
    assert all(t["database"] == "synthetic_250_postgres" for t in result["tables"])

def test_get_column_usage_join_patterns():
    result = get_column_usage("product_id", include_patterns=True)
    assert "join_patterns" in result
    assert len(result["join_patterns"]) > 0
    
def test_get_column_usage_no_results():
    result = get_column_usage("nonexistent_column_xyz")
    assert result["total_tables"] == 0
    assert result["tables"] == []
```

### Integration Tests

```python
def test_margin_analysis_discovery():
    """The tool should discover the margin analysis pattern"""
    result = get_column_usage("product_id")
    
    # Should find sales_order_lines, supplier_products, purchase_order_lines
    table_names = [t["table_name"] for t in result["tables"]]
    assert "sales_order_lines" in table_names
    assert "supplier_products" in table_names
    assert "purchase_order_lines" in table_names
    
    # Should suggest margin analysis pattern
    pattern_names = [p["pattern_name"] for p in result["join_patterns"]]
    assert any("margin" in p.lower() or "cost" in p.lower() for p in pattern_names)
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Query time | < 500ms |
| Pattern accuracy | Correctly identifies 80%+ of cross-domain joins |
| SQL validity | Generated SQL is syntactically correct |
| Coverage | Finds all tables with the column |

### Validation Query

After implementation, this should work instantly:

```
User: "What tables use product_id?"

AI → get_column_usage("product_id")
    → Returns 25 tables grouped by domain
    → Suggests margin_analysis pattern
    → Provides ready-to-run SQL
    
Time: < 1 second (vs 10+ minutes manual exploration)
```

---

## Dependencies

### Required
- Company-MCP repository cloned
- `data/index/index.db` with indexed documentation
- Python 3.9+
- FastMCP framework

### Optional
- Semantic metadata in table docs (enhances pattern quality)
- Cross-domain relationship maps (provides additional context)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Column name ambiguity (e.g., "id") | Filter by column role, prioritize FKs |
| Too many results | Domain grouping, pagination, relevance scoring |
| Invalid SQL generation | Validate generated SQL, use templates |
| Missing semantic metadata | Fall back to rule-based pattern inference |

---

## Timeline Estimate

| Task | Estimate |
|------|----------|
| Clone repo, create branch | 5 min |
| Implement `column_usage.py` | 30 min |
| Implement pattern inference | 30 min |
| Register in server.py | 10 min |
| Write tests | 20 min |
| Test locally | 15 min |
| Create PR | 10 min |
| **Total** | **~2 hours** |

---

## References

- `MCP_GAPS_ANALYSIS.md` - Original gap analysis
- `ACTION_PLAN_MCP_FIXES.md` - Implementation plan
- [Company-MCP README](https://github.com/nstjuliana/Company-MCP/) - Existing tool documentation
- `TribalAgent/src/agents/indexer/relationships.ts` - FK extraction logic

