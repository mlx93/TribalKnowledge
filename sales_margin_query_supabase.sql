-- ============================================================================
-- SALES ORDER MARGIN ANALYSIS - SUPABASE READY
-- ============================================================================
-- Database: synthetic_250_postgres | Schema: synthetic
-- Purpose: Calculate true margin on sales orders after procurement costs
--
-- Tables Used: (6 tables, 5 joins)
--   1. sales_orders
--   2. sales_order_lines 
--   3. supplier_products
--   4. suppliers
--   5. purchase_orders
--   6. purchase_order_lines
-- ============================================================================

-- ============================================================================
-- OPTION 1: SIMPLIFIED ORDER-LEVEL SUMMARY (RECOMMENDED FOR DASHBOARDS)
-- ============================================================================
-- Aggregates all line items per order
-- Shows total revenue, COGS, and margin percentage per order
-- Easiest to visualize and understand

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
    
    -- Order summary
    COUNT(DISTINCT so_line_id) AS line_item_count,
    SUM(quantity) AS total_units,
    
    -- Revenue metrics
    SUM(revenue) AS total_revenue,
    grand_total,
    
    -- Cost metrics (actual procurement)
    SUM(actual_unit_cost * quantity) AS total_cogs,
    
    -- Margin metrics
    SUM(revenue) - SUM(actual_unit_cost * quantity) AS gross_margin,
    ROUND(
        ((SUM(revenue) - SUM(actual_unit_cost * quantity)) / NULLIF(SUM(revenue), 0)) * 100,
        2
    ) AS margin_percentage
    
FROM sales_with_costs
GROUP BY 
    sales_order_id,
    order_number,
    order_date,
    status,
    grand_total
ORDER BY 
    order_date DESC
LIMIT 100;  -- Remove or adjust limit as needed


-- ============================================================================
-- OPTION 2: DETAILED LINE-ITEM LEVEL (FULL 6-TABLE JOIN)
-- ============================================================================
-- Shows every sales line with corresponding supplier and PO information
-- Includes both actual costs and supplier list costs for comparison
-- Best for detailed analysis and debugging

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
    sol.so_line_id
LIMIT 500;  -- Remove or adjust limit as needed


-- ============================================================================
-- OPTION 3: TOP 10 MOST PROFITABLE ORDERS
-- ============================================================================

WITH order_margins AS (
    SELECT 
        so.sales_order_id,
        so.order_number,
        so.order_date,
        so.status,
        SUM(sol.line_total) AS total_revenue,
        SUM(
            COALESCE(
                (SELECT AVG(pol2.unit_cost) 
                 FROM synthetic.purchase_order_lines pol2
                 INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
                 WHERE pol2.product_id = sol.product_id
                   AND po2.status IN ('approved', 'received', 'completed')
                ), 
                sp.unit_cost,
                0
            ) * sol.quantity
        ) AS total_cogs
        
    FROM synthetic.sales_orders so
    INNER JOIN synthetic.sales_order_lines sol 
        ON so.sales_order_id = sol.sales_order_id
    LEFT JOIN synthetic.supplier_products sp 
        ON sol.product_id = sp.product_id 
        AND sp.is_preferred = true
        
    WHERE so.status NOT IN ('cancelled', 'void')
    
    GROUP BY so.sales_order_id, so.order_number, so.order_date, so.status
)

SELECT 
    sales_order_id,
    order_number,
    order_date,
    total_revenue,
    total_cogs,
    total_revenue - total_cogs AS gross_margin,
    ROUND(
        ((total_revenue - total_cogs) / NULLIF(total_revenue, 0)) * 100,
        2
    ) AS margin_percentage
FROM order_margins
ORDER BY gross_margin DESC
LIMIT 10;


-- ============================================================================
-- OPTION 4: PRODUCTS WITH LOWEST MARGINS
-- ============================================================================
-- Identify which products have the smallest profit margins
-- Useful for pricing strategy and supplier negotiation

SELECT 
    sol.product_id,
    MAX(sol.product_name) AS product_name,
    COUNT(DISTINCT sol.sales_order_id) AS order_count,
    SUM(sol.quantity) AS total_units_sold,
    SUM(sol.line_total) AS total_revenue,
    
    -- Average costs
    AVG(
        COALESCE(
            (SELECT AVG(pol2.unit_cost) 
             FROM synthetic.purchase_order_lines pol2
             INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
             WHERE pol2.product_id = sol.product_id
               AND po2.status IN ('approved', 'received', 'completed')
            ), 
            sp.unit_cost,
            0
        )
    ) AS avg_unit_cost,
    
    SUM(
        COALESCE(
            (SELECT AVG(pol2.unit_cost) 
             FROM synthetic.purchase_order_lines pol2
             INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
             WHERE pol2.product_id = sol.product_id
               AND po2.status IN ('approved', 'received', 'completed')
            ), 
            sp.unit_cost,
            0
        ) * sol.quantity
    ) AS total_cogs,
    
    SUM(sol.line_total) - SUM(
        COALESCE(
            (SELECT AVG(pol2.unit_cost) 
             FROM synthetic.purchase_order_lines pol2
             INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
             WHERE pol2.product_id = sol.product_id
               AND po2.status IN ('approved', 'received', 'completed')
            ), 
            sp.unit_cost,
            0
        ) * sol.quantity
    ) AS total_margin,
    
    ROUND(
        (
            (SUM(sol.line_total) - SUM(
                COALESCE(
                    (SELECT AVG(pol2.unit_cost) 
                     FROM synthetic.purchase_order_lines pol2
                     INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
                     WHERE pol2.product_id = sol.product_id
                       AND po2.status IN ('approved', 'received', 'completed')
                    ), 
                    sp.unit_cost,
                    0
                ) * sol.quantity
            ))
            / NULLIF(SUM(sol.line_total), 0)
        ) * 100,
        2
    ) AS margin_percentage

FROM synthetic.sales_order_lines sol
LEFT JOIN synthetic.supplier_products sp 
    ON sol.product_id = sp.product_id 
    AND sp.is_preferred = true

GROUP BY sol.product_id
HAVING SUM(sol.line_total) > 0
ORDER BY margin_percentage ASC
LIMIT 20;


-- ============================================================================
-- OPTION 5: MONTHLY MARGIN TRENDS
-- ============================================================================
-- Track how margins trend over time
-- Useful for identifying seasonal patterns or pricing changes

SELECT 
    DATE_TRUNC('month', so.order_date) AS order_month,
    COUNT(DISTINCT so.sales_order_id) AS order_count,
    SUM(sol.line_total) AS total_revenue,
    
    SUM(
        COALESCE(
            (SELECT AVG(pol2.unit_cost) 
             FROM synthetic.purchase_order_lines pol2
             INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
             WHERE pol2.product_id = sol.product_id
               AND po2.status IN ('approved', 'received', 'completed')
            ), 
            sp.unit_cost,
            0
        ) * sol.quantity
    ) AS total_cogs,
    
    SUM(sol.line_total) - SUM(
        COALESCE(
            (SELECT AVG(pol2.unit_cost) 
             FROM synthetic.purchase_order_lines pol2
             INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
             WHERE pol2.product_id = sol.product_id
               AND po2.status IN ('approved', 'received', 'completed')
            ), 
            sp.unit_cost,
            0
        ) * sol.quantity
    ) AS total_margin,
    
    ROUND(
        (
            (SUM(sol.line_total) - SUM(
                COALESCE(
                    (SELECT AVG(pol2.unit_cost) 
                     FROM synthetic.purchase_order_lines pol2
                     INNER JOIN synthetic.purchase_orders po2 ON pol2.po_id = po2.po_id
                     WHERE pol2.product_id = sol.product_id
                       AND po2.status IN ('approved', 'received', 'completed')
                    ), 
                    sp.unit_cost,
                    0
                ) * sol.quantity
            ))
            / NULLIF(SUM(sol.line_total), 0)
        ) * 100,
        2
    ) AS margin_percentage

FROM synthetic.sales_orders so
INNER JOIN synthetic.sales_order_lines sol 
    ON so.sales_order_id = sol.sales_order_id
LEFT JOIN synthetic.supplier_products sp 
    ON sol.product_id = sp.product_id 
    AND sp.is_preferred = true

WHERE 
    so.status NOT IN ('cancelled', 'void')
    AND so.order_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')

GROUP BY DATE_TRUNC('month', so.order_date)
ORDER BY order_month DESC;


-- ============================================================================
-- NOTES & TIPS
-- ============================================================================
-- 
-- 1. START WITH OPTION 1 (Simplified Order-Level Summary)
--    - Easiest to understand and visualize
--    - Perfect for dashboards and executive reports
-- 
-- 2. Date Filters:
--    - Adjust WHERE clauses to focus on relevant time periods
--    - Example: WHERE so.order_date >= '2024-01-01'
-- 
-- 3. Status Filters:
--    - Customize which order statuses to include/exclude
--    - Currently excludes: 'cancelled', 'void'
--    - Only uses completed POs: 'approved', 'received', 'completed'
-- 
-- 4. Performance:
--    - Add LIMIT clauses for initial testing
--    - Consider creating indexes on frequently joined columns
--    - Materialized views can speed up repeated queries
-- 
-- 5. Cost Methodology:
--    - Uses actual PO costs when available
--    - Falls back to supplier list costs
--    - Returns 0 if no cost data (adjust as needed)
-- 
-- ============================================================================
