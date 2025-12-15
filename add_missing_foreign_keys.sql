-- ============================================================================
-- Add Missing Foreign Key Constraints to Supabase
-- ============================================================================
-- Purpose: Add FK constraints for product_id columns that exist but lack
--          database-level foreign key relationships. This enables the
--          MCP indexer to automatically discover join paths.
--
-- Run this on your Supabase database, then re-run the documenter + indexer
-- to pick up the new relationships.
-- ============================================================================

-- ============================================================================
-- CRITICAL: Tables for Sales Margin Analysis
-- These are the most important FKs for the margin analysis query
-- ============================================================================

-- 1. sales_order_lines.product_id → products.product_id
-- Enables: Revenue by product analysis, margin calculations
ALTER TABLE synthetic.sales_order_lines
ADD CONSTRAINT fk_sales_order_lines_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE SET NULL;

-- 2. purchase_order_lines.product_id → products.product_id  
-- Enables: Cost by product analysis, procurement tracking
ALTER TABLE synthetic.purchase_order_lines
ADD CONSTRAINT fk_purchase_order_lines_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE SET NULL;

-- 3. supplier_products.product_id → products.product_id
-- Enables: Bridge between products and suppliers, cost lookup
ALTER TABLE synthetic.supplier_products
ADD CONSTRAINT fk_supplier_products_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE CASCADE;


-- ============================================================================
-- HIGH PRIORITY: Inventory & Quotes
-- ============================================================================

-- 4. inventory_items.product_id → products.product_id
-- Enables: Stock availability, inventory valuation
ALTER TABLE synthetic.inventory_items
ADD CONSTRAINT fk_inventory_items_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE CASCADE;

-- 5. quote_lines.product_id → products.product_id
-- Enables: Quote to order analysis, pricing history
ALTER TABLE synthetic.quote_lines
ADD CONSTRAINT fk_quote_lines_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE SET NULL;

-- 6. receiving_lines.product_id → products.product_id
-- Enables: Goods receipt tracking, inventory updates
ALTER TABLE synthetic.receiving_lines
ADD CONSTRAINT fk_receiving_lines_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE SET NULL;


-- ============================================================================
-- MEDIUM PRIORITY: Sales & CRM
-- ============================================================================

-- 7. opportunity_products.product_id → products.product_id
-- Enables: Pipeline analysis by product
ALTER TABLE synthetic.opportunity_products
ADD CONSTRAINT fk_opportunity_products_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE CASCADE;

-- 8. price_book_entries.product_id → products.product_id
-- Enables: Pricing strategy analysis
ALTER TABLE synthetic.price_book_entries
ADD CONSTRAINT fk_price_book_entries_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE CASCADE;


-- ============================================================================
-- MEDIUM PRIORITY: Inventory Management
-- ============================================================================

-- 9. stock_transfer_lines.product_id → products.product_id
-- Enables: Inter-warehouse movement tracking
ALTER TABLE synthetic.stock_transfer_lines
ADD CONSTRAINT fk_stock_transfer_lines_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE CASCADE;

-- 10. reorder_rules.product_id → products.product_id
-- Enables: Automated reordering configuration
ALTER TABLE synthetic.reorder_rules
ADD CONSTRAINT fk_reorder_rules_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE CASCADE;

-- 11. abc_analysis.product_id → products.product_id
-- Enables: Inventory classification analysis
ALTER TABLE synthetic.abc_analysis
ADD CONSTRAINT fk_abc_analysis_product_id
FOREIGN KEY (product_id) REFERENCES synthetic.products(product_id)
ON DELETE CASCADE;


-- ============================================================================
-- LOWER PRIORITY: Product Catalog
-- These likely already have FKs but just in case...
-- ============================================================================

-- 12. product_bundles.bundle_product_id → products.product_id
-- Note: This table may use bundle_product_id, not product_id
ALTER TABLE synthetic.product_bundles
ADD CONSTRAINT fk_product_bundles_bundle_product_id
FOREIGN KEY (bundle_product_id) REFERENCES synthetic.products(product_id)
ON DELETE CASCADE;


-- ============================================================================
-- VERIFICATION QUERIES
-- Run these after adding FKs to verify they were created
-- ============================================================================

-- Check all FK constraints on product-related tables
/*
SELECT 
    tc.table_schema,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND (tc.table_name LIKE '%product%' 
         OR kcu.column_name = 'product_id')
ORDER BY tc.table_name;
*/


-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================
/*
ALTER TABLE synthetic.sales_order_lines DROP CONSTRAINT IF EXISTS fk_sales_order_lines_product_id;
ALTER TABLE synthetic.purchase_order_lines DROP CONSTRAINT IF EXISTS fk_purchase_order_lines_product_id;
ALTER TABLE synthetic.supplier_products DROP CONSTRAINT IF EXISTS fk_supplier_products_product_id;
ALTER TABLE synthetic.inventory_items DROP CONSTRAINT IF EXISTS fk_inventory_items_product_id;
ALTER TABLE synthetic.quote_lines DROP CONSTRAINT IF EXISTS fk_quote_lines_product_id;
ALTER TABLE synthetic.receiving_lines DROP CONSTRAINT IF EXISTS fk_receiving_lines_product_id;
ALTER TABLE synthetic.opportunity_products DROP CONSTRAINT IF EXISTS fk_opportunity_products_product_id;
ALTER TABLE synthetic.price_book_entries DROP CONSTRAINT IF EXISTS fk_price_book_entries_product_id;
ALTER TABLE synthetic.stock_transfer_lines DROP CONSTRAINT IF EXISTS fk_stock_transfer_lines_product_id;
ALTER TABLE synthetic.reorder_rules DROP CONSTRAINT IF EXISTS fk_reorder_rules_product_id;
ALTER TABLE synthetic.abc_analysis DROP CONSTRAINT IF EXISTS fk_abc_analysis_product_id;
ALTER TABLE synthetic.product_bundles DROP CONSTRAINT IF EXISTS fk_product_bundles_bundle_product_id;
*/

