# Sales Order Margin Analysis
## True Margin Calculation After Procurement Costs

**Database**: `synthetic_250_postgres`  
**Schema**: `synthetic`  
**Analysis Date**: December 14, 2025

---

## 🚀 Quick Start: Ready-to-Run Queries

### ✅ YES - We captured ALL 6 tables in our complete join chain:

1. **sales_orders** → (sales_order_id)
2. **sales_order_lines** → (product_id)
3. **supplier_products** → (supplier_id)
4. **suppliers** → (supplier_id)
5. **purchase_orders** → (po_id)
6. **purchase_order_lines**

**Total Joins**: 5 joins connecting 6 tables

### 🎯 Recommended Queries for Supabase

**📄 Quick Copy File**: See `sales_margin_query_supabase.sql` for ready-to-paste queries!

This file includes 5 different query options:
1. **Simplified Order-Level Summary** ⭐ (Recommended for dashboards)
2. **Detailed Line-Item Level** (Full 6-table join)
3. **Top 10 Most Profitable Orders**
4. **Products with Lowest Margins**
5. **Monthly Margin Trends**

Jump to detailed explanations:
- **[Complete 6-Table Join](#-complete-supabase-ready-query-all-6-tables)** - Full detail with all relationships
- **[Simplified Aggregated Query](#-simplified-supabase-query-aggregated-order-margins)** - Order-level summary (easiest to use)

Both queries are **ready to copy-paste into Supabase SQL Editor** ✨

---

## Executive Summary

To calculate the **true margin** on each sales order after accounting for procurement costs from suppliers, we need to:

1. **Revenue**: Calculate total revenue from `sales_orders` and `sales_order_lines`
2. **Cost of Goods Sold (COGS)**: Determine procurement costs using `purchase_order_lines` and `supplier_products`
3. **Margin**: Calculate `Revenue - COGS` for each sales order

### Complete Data Flow

```
┌─────────────────┐
│ sales_orders    │  Header: order_number, order_date, grand_total
└────────┬────────┘
         │ 1
         │ sales_order_id
         │ *
┌────────▼────────┐
│sales_order_lines│  Detail: product_id, quantity, unit_price, line_total (REVENUE)
└────────┬────────┘
         │
         │ product_id
         │
┌────────▼─────────┐
│supplier_products │  Bridge: links products to suppliers with unit_cost
└────────┬─────────┘
         │
         │ supplier_id
         │
┌────────▼────────┐
│   suppliers     │  Supplier: supplier_name, rating, payment_terms
└────────┬────────┘
         │ 1
         │ supplier_id
         │ *
┌────────▼────────┐
│purchase_orders  │  PO Header: po_number, order_date, total_amount
└────────┬────────┘
         │ 1
         │ po_id
         │ *
┌────────▼─────────┐
│purchase_order_   │  PO Detail: product_id, unit_cost, quantity_ordered (COST)
│     lines        │
└──────────────────┘
```

**Key Insight**: We link sales to procurement costs through `product_id`, connecting:
- **Sales side**: `sales_order_lines.product_id` → revenue per product
- **Cost side**: `purchase_order_lines.product_id` → cost per product
- **Bridge**: `supplier_products` maintains the product-supplier-cost relationship

---

## Table Relationships

**Complete Join Chain (6 tables, 6 joins)**:

```
sales_orders 
    ↓ (sales_order_id)
sales_order_lines
    ↓ (product_id)
supplier_products
    ↓ (supplier_id)
suppliers
    ↓ (supplier_id)
purchase_orders
    ↓ (po_id)
purchase_order_lines
```

### Key Tables

| Table | Purpose | Key Columns | Joins To |
|-------|---------|-------------|----------|
| **sales_orders** | Header-level sales order | `sales_order_id`, `grand_total`, `status` | sales_order_lines |
| **sales_order_lines** | Line items sold | `sales_order_id`, `product_id`, `quantity`, `unit_price`, `line_total` | sales_orders, supplier_products |
| **supplier_products** | Product-supplier relationship & cost | `product_id`, `supplier_id`, `unit_cost` | sales_order_lines, suppliers |
| **suppliers** | Supplier information | `supplier_id`, `supplier_name`, `rating` | supplier_products, purchase_orders |
| **purchase_orders** | PO header from supplier | `po_id`, `supplier_id`, `total_amount` | suppliers, purchase_order_lines |
| **purchase_order_lines** | Actual procurement costs | `po_id`, `product_id`, `unit_cost` | purchase_orders |

---

## 🚀 Complete Supabase-Ready Query (All 6 Tables)

This query demonstrates the **complete join chain** across all 6 tables with proper relationships.

```sql
-- COMPLETE MARGIN ANALYSIS WITH FULL TABLE CHAIN
-- Shows sales orders with revenue, procurement costs, supplier info, and margins
-- All 6 tables joined: sales_orders → sales_order_lines → supplier_products → suppliers → purchase_orders → purchase_order_lines

SELECT 
    -- Sales Order Info
    so.sales_order_id,
    so.order_number,
    so.order_date,
    so.status AS order_status,
    
    -- Line Item Detail
    sol.so_line_id,
    sol.product_id,
    sol.product_name,
    sol.quantity AS qty_sold,
    sol.unit_price AS sell_price,
    sol.line_total AS line_revenue,
    
    -- Supplier Info (from supplier_products relationship)
    sp.supplier_id,
    s.supplier_name,
    s.rating AS supplier_rating,
    sp.unit_cost AS supplier_list_cost,
    sp.is_preferred,
    
    -- Purchase Order Info (actual procurement)
    po.po_id,
    po.po_number,
    po.order_date AS po_order_date,
    po.status AS po_status,
    
    -- Purchase Order Line (actual cost paid)
    pol.po_line_id,
    pol.unit_cost AS actual_unit_cost,
    pol.quantity_ordered,
    pol.quantity_received,
    
    -- Cost Calculations
    sp.unit_cost * sol.quantity AS supplier_list_total_cost,
    pol.unit_cost * sol.quantity AS actual_total_cost,
    
    -- Margin Calculations (using actual procurement cost)
    sol.line_total - (pol.unit_cost * sol.quantity) AS line_margin_actual,
    ROUND(
        ((sol.line_total - (pol.unit_cost * sol.quantity)) / NULLIF(sol.line_total, 0)) * 100,
        2
    ) AS margin_pct_actual,
    
    -- Margin Calculations (using supplier list cost)
    sol.line_total - (sp.unit_cost * sol.quantity) AS line_margin_list,
    ROUND(
        ((sol.line_total - (sp.unit_cost * sol.quantity)) / NULLIF(sol.line_total, 0)) * 100,
        2
    ) AS margin_pct_list

FROM synthetic.sales_orders so

-- Join 1: Sales order to line items
INNER JOIN synthetic.sales_order_lines sol 
    ON so.sales_order_id = sol.sales_order_id

-- Join 2: Line items to supplier products (product-supplier relationship)
LEFT JOIN synthetic.supplier_products sp 
    ON sol.product_id = sp.product_id 
    AND sp.is_preferred = true  -- Use preferred supplier

-- Join 3: Supplier products to suppliers
LEFT JOIN synthetic.suppliers s 
    ON sp.supplier_id = s.supplier_id

-- Join 4: Suppliers to purchase orders
LEFT JOIN synthetic.purchase_orders po 
    ON s.supplier_id = po.supplier_id
    AND po.status IN ('approved', 'received', 'completed')  -- Only completed POs

-- Join 5: Purchase orders to purchase order lines
LEFT JOIN synthetic.purchase_order_lines pol 
    ON po.po_id = pol.po_id
    AND pol.product_id = sol.product_id  -- Match same product

WHERE 
    so.status NOT IN ('cancelled', 'void')  -- Exclude cancelled orders
    AND so.order_date >= '2024-01-01'  -- Adjust date range as needed

ORDER BY 
    so.order_date DESC,
    sol.so_line_id;
```

### Query Notes:
- **6 tables joined** with proper foreign key relationships
- **LEFT JOINs** used to preserve sales orders even if supplier/PO data is missing
- **Filters** on preferred suppliers and completed POs
- **Both cost methods** shown side-by-side for comparison
- **Ready to run** on Supabase PostgreSQL

---

## 🎯 Simplified Supabase Query: Aggregated Order Margins

This simplified version aggregates to the **sales order level** for easier analysis:

```sql
-- SIMPLIFIED: Order-level margin summary
-- Aggregates all line items per order with total revenue, costs, and margins

WITH sales_with_costs AS (
    SELECT 
        so.sales_order_id,
        so.order_number,
        so.order_date,
        so.status,
        so.grand_total,
        
        -- Line item details
        sol.so_line_id,
        sol.product_id,
        sol.product_name,
        sol.quantity,
        sol.line_total AS revenue,
        
        -- Get supplier cost (preferred supplier)
        COALESCE(sp.unit_cost, 0) AS supplier_unit_cost,
        
        -- Get actual procurement cost (average from completed POs)
        COALESCE(
            (SELECT AVG(pol2.unit_cost) 
             FROM synthetic.purchase_order_lines pol2
             INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
             WHERE pol2.product_id = sol.product_id
               AND po2.status IN ('approved', 'received', 'completed')
            ), 
            sp.unit_cost,
            0
        ) AS actual_unit_cost
        
    FROM synthetic.sales_orders so
    INNER JOIN synthetic.sales_order_lines sol 
        ON so.sales_order_id = sol.sales_order_id
    LEFT JOIN synthetic.supplier_products sp 
        ON sol.product_id = sp.product_id 
        AND sp.is_preferred = true
        
    WHERE so.status NOT IN ('cancelled', 'void')
)

SELECT 
    sales_order_id,
    order_number,
    order_date,
    status,
    
    -- Revenue metrics
    COUNT(DISTINCT so_line_id) AS line_item_count,
    SUM(quantity) AS total_units,
    SUM(revenue) AS total_revenue,
    grand_total,
    
    -- Cost metrics (actual procurement)
    SUM(actual_unit_cost * quantity) AS total_cogs_actual,
    
    -- Margin metrics (actual)
    SUM(revenue) - SUM(actual_unit_cost * quantity) AS gross_margin,
    ROUND(
        ((SUM(revenue) - SUM(actual_unit_cost * quantity)) / NULLIF(SUM(revenue), 0)) * 100,
        2
    ) AS margin_percentage,
    
    -- Cost metrics (supplier list price - for comparison)
    SUM(supplier_unit_cost * quantity) AS total_cogs_list,
    ROUND(
        ((SUM(revenue) - SUM(supplier_unit_cost * quantity)) / NULLIF(SUM(revenue), 0)) * 100,
        2
    ) AS margin_pct_list
    
FROM sales_with_costs
GROUP BY 
    sales_order_id,
    order_number,
    order_date,
    status,
    grand_total
ORDER BY 
    order_date DESC;
```

### Output Columns Explained:
| Column | Description |
|--------|-------------|
| `sales_order_id` | Unique order identifier |
| `order_number` | Human-readable order number |
| `order_date` | When order was placed |
| `total_revenue` | Sum of all line_total amounts |
| `total_cogs_actual` | Total cost using actual PO costs |
| `gross_margin` | Revenue - COGS (dollar amount) |
| `margin_percentage` | (Margin / Revenue) × 100 |
| `margin_pct_list` | Margin % if using supplier list prices |

---

## SQL Query: Sales Order Margin Analysis

### Approach 1: Using Supplier Products Unit Cost

This approach uses the `supplier_products.unit_cost` as the baseline procurement cost for each product.

```sql
WITH sales_revenue AS (
    -- Calculate revenue per sales order line
    SELECT 
        so.sales_order_id,
        so.order_number,
        so.order_date,
        so.status,
        so.account_id,
        sol.so_line_id,
        sol.product_id,
        sol.product_name,
        sol.quantity,
        sol.unit_price,
        sol.line_total AS revenue,
        so.grand_total AS order_grand_total
    FROM synthetic.sales_orders so
    INNER JOIN synthetic.sales_order_lines sol 
        ON so.sales_order_id = sol.sales_order_id
    WHERE so.status NOT IN ('cancelled', 'void')  -- Exclude cancelled orders
),

procurement_costs AS (
    -- Get the preferred supplier's unit cost for each product
    SELECT 
        sp.product_id,
        sp.supplier_id,
        sp.unit_cost AS supplier_unit_cost,
        sp.is_preferred
    FROM synthetic.supplier_products sp
    WHERE sp.is_preferred = true  -- Use preferred supplier's cost
),

margin_calculation AS (
    -- Join sales with procurement costs and calculate margins
    SELECT 
        sr.sales_order_id,
        sr.order_number,
        sr.order_date,
        sr.status,
        sr.account_id,
        sr.so_line_id,
        sr.product_id,
        sr.product_name,
        sr.quantity,
        sr.unit_price,
        sr.revenue,
        
        -- Procurement cost calculation
        COALESCE(pc.supplier_unit_cost, 0) AS unit_cost,
        COALESCE(pc.supplier_unit_cost * sr.quantity, 0) AS total_cost,
        
        -- Margin calculation
        sr.revenue - COALESCE(pc.supplier_unit_cost * sr.quantity, 0) AS line_margin,
        
        -- Margin percentage
        CASE 
            WHEN sr.revenue > 0 THEN 
                ROUND(
                    ((sr.revenue - COALESCE(pc.supplier_unit_cost * sr.quantity, 0)) / sr.revenue) * 100, 
                    2
                )
            ELSE 0 
        END AS margin_percentage
        
    FROM sales_revenue sr
    LEFT JOIN procurement_costs pc 
        ON sr.product_id = pc.product_id
)

-- Final aggregated margin by sales order
SELECT 
    sales_order_id,
    order_number,
    order_date,
    status,
    account_id,
    
    -- Revenue metrics
    SUM(revenue) AS total_revenue,
    
    -- Cost metrics
    SUM(total_cost) AS total_cogs,
    
    -- Margin metrics
    SUM(line_margin) AS total_margin,
    
    -- Margin percentage (weighted by line revenue)
    CASE 
        WHEN SUM(revenue) > 0 THEN 
            ROUND((SUM(line_margin) / SUM(revenue)) * 100, 2)
        ELSE 0 
    END AS margin_percentage,
    
    -- Summary metrics
    COUNT(DISTINCT product_id) AS unique_products,
    SUM(quantity) AS total_units_sold
    
FROM margin_calculation
GROUP BY 
    sales_order_id,
    order_number,
    order_date,
    status,
    account_id
ORDER BY order_date DESC;
```

---

### Approach 2: Using Actual Purchase Order Lines

This approach uses actual procurement costs from `purchase_order_lines`, matching products purchased to products sold. This is more accurate if you want to use **actual** procurement costs rather than list prices from suppliers.

```sql
WITH sales_revenue AS (
    -- Calculate revenue per sales order line
    SELECT 
        so.sales_order_id,
        so.order_number,
        so.order_date,
        so.status,
        so.account_id,
        sol.so_line_id,
        sol.product_id,
        sol.product_name,
        sol.quantity,
        sol.unit_price,
        sol.line_total AS revenue,
        so.grand_total AS order_grand_total
    FROM synthetic.sales_orders so
    INNER JOIN synthetic.sales_order_lines sol 
        ON so.sales_order_id = sol.sales_order_id
    WHERE so.status NOT IN ('cancelled', 'void')
),

actual_procurement_costs AS (
    -- Get average unit cost from actual purchase orders
    SELECT 
        pol.product_id,
        AVG(pol.unit_cost) AS avg_unit_cost,
        SUM(pol.quantity_ordered) AS total_quantity_purchased
    FROM synthetic.purchase_order_lines pol
    INNER JOIN synthetic.purchase_orders po 
        ON pol.po_id = po.po_id
    WHERE po.status IN ('approved', 'received', 'completed')
    GROUP BY pol.product_id
),

margin_calculation AS (
    SELECT 
        sr.sales_order_id,
        sr.order_number,
        sr.order_date,
        sr.status,
        sr.account_id,
        sr.so_line_id,
        sr.product_id,
        sr.product_name,
        sr.quantity,
        sr.unit_price,
        sr.revenue,
        
        -- Use actual procurement cost (average from POs)
        COALESCE(apc.avg_unit_cost, 0) AS unit_cost,
        COALESCE(apc.avg_unit_cost * sr.quantity, 0) AS total_cost,
        
        -- Margin calculation
        sr.revenue - COALESCE(apc.avg_unit_cost * sr.quantity, 0) AS line_margin,
        
        -- Margin percentage
        CASE 
            WHEN sr.revenue > 0 THEN 
                ROUND(
                    ((sr.revenue - COALESCE(apc.avg_unit_cost * sr.quantity, 0)) / sr.revenue) * 100, 
                    2
                )
            ELSE 0 
        END AS margin_percentage
        
    FROM sales_revenue sr
    LEFT JOIN actual_procurement_costs apc 
        ON sr.product_id = apc.product_id
)

-- Final aggregated margin by sales order
SELECT 
    sales_order_id,
    order_number,
    order_date,
    status,
    account_id,
    
    -- Revenue metrics
    SUM(revenue) AS total_revenue,
    
    -- Cost metrics
    SUM(total_cost) AS total_cogs,
    
    -- Margin metrics
    SUM(line_margin) AS total_margin,
    
    -- Margin percentage
    CASE 
        WHEN SUM(revenue) > 0 THEN 
            ROUND((SUM(line_margin) / SUM(revenue)) * 100, 2)
        ELSE 0 
    END AS margin_percentage,
    
    -- Summary metrics
    COUNT(DISTINCT product_id) AS unique_products,
    SUM(quantity) AS total_units_sold
    
FROM margin_calculation
GROUP BY 
    sales_order_id,
    order_number,
    order_date,
    status,
    account_id
ORDER BY order_date DESC;
```

---

### Approach 3: Line-Level Detail with Both Cost Methods

For detailed analysis at the line item level:

```sql
SELECT 
    so.sales_order_id,
    so.order_number,
    so.order_date,
    so.status,
    sol.so_line_id,
    sol.product_id,
    sol.product_name,
    sol.quantity,
    
    -- Revenue
    sol.unit_price AS sell_price,
    sol.line_total AS line_revenue,
    
    -- Supplier list cost
    sp.unit_cost AS supplier_list_cost,
    sp.unit_cost * sol.quantity AS supplier_total_cost,
    
    -- Actual procurement cost (average from POs)
    COALESCE(
        (SELECT AVG(pol.unit_cost) 
         FROM synthetic.purchase_order_lines pol
         INNER JOIN synthetic.purchase_orders po ON pol.po_id = po.po_id
         WHERE pol.product_id = sol.product_id
           AND po.status IN ('approved', 'received', 'completed')
        ), 
        sp.unit_cost
    ) AS actual_unit_cost,
    
    COALESCE(
        (SELECT AVG(pol.unit_cost) 
         FROM synthetic.purchase_order_lines pol
         INNER JOIN synthetic.purchase_orders po ON pol.po_id = po.po_id
         WHERE pol.product_id = sol.product_id
           AND po.status IN ('approved', 'received', 'completed')
        ), 
        sp.unit_cost
    ) * sol.quantity AS actual_total_cost,
    
    -- Margin using actual costs
    sol.line_total - (
        COALESCE(
            (SELECT AVG(pol.unit_cost) 
             FROM synthetic.purchase_order_lines pol
             INNER JOIN synthetic.purchase_orders po ON pol.po_id = po.po_id
             WHERE pol.product_id = sol.product_id
               AND po.status IN ('approved', 'received', 'completed')
            ), 
            sp.unit_cost
        ) * sol.quantity
    ) AS line_margin,
    
    -- Margin percentage
    CASE 
        WHEN sol.line_total > 0 THEN 
            ROUND(
                (
                    (sol.line_total - (
                        COALESCE(
                            (SELECT AVG(pol.unit_cost) 
                             FROM synthetic.purchase_order_lines pol
                             INNER JOIN synthetic.purchase_orders po ON pol.po_id = po.po_id
                             WHERE pol.product_id = sol.product_id
                               AND po.status IN ('approved', 'received', 'completed')
                            ), 
                            sp.unit_cost
                        ) * sol.quantity
                    )) / sol.line_total
                ) * 100, 
                2
            )
        ELSE 0 
    END AS margin_percentage

FROM synthetic.sales_orders so
INNER JOIN synthetic.sales_order_lines sol 
    ON so.sales_order_id = sol.sales_order_id
LEFT JOIN synthetic.supplier_products sp 
    ON sol.product_id = sp.product_id 
    AND sp.is_preferred = true

WHERE so.status NOT IN ('cancelled', 'void')

ORDER BY so.order_date DESC, sol.so_line_id;
```

---

## Key Metrics Explained

| Metric | Formula | Description |
|--------|---------|-------------|
| **Revenue** | `SUM(sales_order_lines.line_total)` | Total revenue from sales order |
| **COGS** | `SUM(unit_cost × quantity)` | Total cost of goods sold (procurement cost) |
| **Gross Margin** | `Revenue - COGS` | Dollar amount of profit |
| **Margin %** | `(Gross Margin / Revenue) × 100` | Percentage profitability |

---

## Data Insights

### Schema Observations

1. **Sales Order Structure**:
   - Header: `sales_orders` contains order-level info (subtotal, tax, shipping, grand_total)
   - Lines: `sales_order_lines` contains product-level detail (product_id, quantity, unit_price)

2. **Procurement Cost Sources**:
   - **Option A**: `supplier_products.unit_cost` - List price from preferred supplier
   - **Option B**: `purchase_order_lines.unit_cost` - Actual cost paid in purchase orders

3. **Key Relationships**:
   - `sales_order_lines.product_id` → links to products
   - `supplier_products.product_id` → provides supplier cost per product
   - `purchase_order_lines.product_id` → provides actual procurement cost

### Cost Methodology Recommendation

**Use Approach 2 (Actual Purchase Orders)** when:
- You have reliable PO data with completed/received orders
- You want to account for negotiated discounts or bulk pricing
- You need to track actual historical costs

**Use Approach 1 (Supplier Products)** when:
- Purchase order data is incomplete
- You want to use standard/list costs for forecasting
- You prefer simplified cost management

---

## Additional Analysis Queries

### Top 10 Most Profitable Sales Orders

```sql
-- Use the margin_calculation CTE from Approach 2, then:

SELECT 
    sales_order_id,
    order_number,
    order_date,
    total_revenue,
    total_cogs,
    total_margin,
    margin_percentage
FROM (
    -- Insert Approach 2 query here
) AS order_margins
ORDER BY total_margin DESC
LIMIT 10;
```

### Products with Lowest Margins

```sql
WITH product_margins AS (
    SELECT 
        sol.product_id,
        sol.product_name,
        SUM(sol.line_total) AS total_revenue,
        SUM(
            COALESCE(
                (SELECT AVG(pol.unit_cost) 
                 FROM synthetic.purchase_order_lines pol
                 WHERE pol.product_id = sol.product_id
                ), 
                0
            ) * sol.quantity
        ) AS total_cogs,
        COUNT(DISTINCT sol.sales_order_id) AS order_count
    FROM synthetic.sales_order_lines sol
    GROUP BY sol.product_id, sol.product_name
)

SELECT 
    product_id,
    product_name,
    total_revenue,
    total_cogs,
    total_revenue - total_cogs AS total_margin,
    CASE 
        WHEN total_revenue > 0 THEN 
            ROUND(((total_revenue - total_cogs) / total_revenue) * 100, 2)
        ELSE 0 
    END AS margin_percentage,
    order_count
FROM product_margins
ORDER BY margin_percentage ASC
LIMIT 20;
```

### Monthly Margin Trends

```sql
SELECT 
    DATE_TRUNC('month', so.order_date) AS order_month,
    COUNT(DISTINCT so.sales_order_id) AS order_count,
    SUM(sol.line_total) AS total_revenue,
    SUM(
        COALESCE(sp.unit_cost, 0) * sol.quantity
    ) AS total_cogs,
    SUM(sol.line_total) - SUM(COALESCE(sp.unit_cost, 0) * sol.quantity) AS total_margin,
    CASE 
        WHEN SUM(sol.line_total) > 0 THEN 
            ROUND(
                (
                    (SUM(sol.line_total) - SUM(COALESCE(sp.unit_cost, 0) * sol.quantity)) 
                    / SUM(sol.line_total)
                ) * 100, 
                2
            )
        ELSE 0 
    END AS margin_percentage
FROM synthetic.sales_orders so
INNER JOIN synthetic.sales_order_lines sol 
    ON so.sales_order_id = sol.sales_order_id
LEFT JOIN synthetic.supplier_products sp 
    ON sol.product_id = sp.product_id 
    AND sp.is_preferred = true
WHERE so.status NOT IN ('cancelled', 'void')
GROUP BY DATE_TRUNC('month', so.order_date)
ORDER BY order_month DESC;
```

---

## Considerations & Caveats

### Data Quality Checks

Before running production analysis, validate:

1. **Product Matching**: Ensure all `sales_order_lines.product_id` have corresponding entries in `supplier_products` or `purchase_order_lines`
2. **Cost Completeness**: Check for NULL or zero unit costs that would understate COGS
3. **Order Status**: Verify which statuses represent "completed" sales vs. pending/cancelled
4. **Currency**: Ensure all monetary values use the same currency
5. **Time Alignment**: Match procurement costs to the time period of sales (e.g., use PO costs from before/during the sales period)

### Missing Cost Handling

When a product has no procurement cost data:
- **Option 1**: Default to $0 (shows maximum possible margin, but unrealistic)
- **Option 2**: Exclude from analysis (reduces sample size)
- **Option 3**: Estimate based on average margin % of similar products

### Additional Costs Not Included

This analysis calculates **gross margin** only. True profitability also requires:
- **Operating expenses**: Shipping, warehousing, fulfillment
- **Overhead**: Sales team salaries, marketing, admin
- **Returns/refunds**: Impact on net revenue
- **Payment processing fees**: Credit card fees, etc.

---

## Implementation Checklist

- [ ] Choose cost methodology (Supplier list vs. Actual PO costs)
- [ ] Validate product cost coverage (% of products with cost data)
- [ ] Define order status filters (what counts as "completed"?)
- [ ] Test query on sample data
- [ ] Set up scheduled reporting (daily/weekly/monthly)
- [ ] Create dashboard visualizations
- [ ] Document assumptions for stakeholders
- [ ] Implement alerts for low-margin orders

---

## Next Steps

1. **Run validation queries** to check data completeness
2. **Choose primary cost source** (supplier_products vs purchase_order_lines)
3. **Create materialized view** for performance if analyzing large datasets
4. **Build dashboard** connecting to this analysis
5. **Set margin thresholds** for business rules (e.g., flag orders < 20% margin)

---

## Contact & Questions

For questions about this analysis or the underlying data:
- Review table schemas: Use MCP tools `get_table_schema` for detailed column info
- Check data lineage: Review `documentation-manifest.json` for source metadata
- Database: `synthetic_250_postgres` schema `synthetic`

---

**Generated by**: Tribal Knowledge Deep Agent  
**Database Documentation**: `/docs/synthetic_250_postgres/`  
**Last Updated**: December 14, 2025
