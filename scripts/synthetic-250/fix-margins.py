#!/usr/bin/env python3
"""
Fix synthetic data to ensure positive margins on all sales orders.

Strategy:
1. Calculate weighted average cost per product from purchase_order_lines
2. Update sales_order_lines to ensure price > cost with realistic markup (20-80%)
3. Recalculate line_total based on new unit_price × quantity
"""

import os
import sys
import random
import psycopg2

random.seed(42)

def main():
    url = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("SUPABASE_DB_URL")
    
    if not url:
        print("Usage: python fix-margins.py <database_url>")
        sys.exit(1)
    
    print("=" * 60)
    print("Fixing Margins in Synthetic Data")
    print("=" * 60)
    print()
    
    conn = psycopg2.connect(url, connect_timeout=30)
    cur = conn.cursor()
    print("✓ Connected to database")
    print()
    
    # Step 1: Get weighted average costs per product
    print("Step 1: Calculating weighted average costs per product...")
    cur.execute("""
        SELECT 
            product_id,
            SUM(unit_cost * quantity_ordered) / NULLIF(SUM(quantity_ordered), 0) as avg_cost
        FROM synthetic.purchase_order_lines
        WHERE unit_cost IS NOT NULL AND quantity_ordered > 0
        GROUP BY product_id
    """)
    product_costs = {row[0]: float(row[1]) for row in cur.fetchall() if row[1]}
    print(f"   Found costs for {len(product_costs)} products")
    
    # Step 2: Get all sales order lines that need fixing
    print()
    print("Step 2: Finding sales order lines to update...")
    cur.execute("""
        SELECT 
            sol.so_line_id,
            sol.product_id,
            sol.quantity,
            sol.unit_price,
            sol.line_total
        FROM synthetic.sales_order_lines sol
        WHERE sol.product_id IS NOT NULL
    """)
    sales_lines = cur.fetchall()
    print(f"   Found {len(sales_lines)} sales order lines")
    
    # Step 3: Update each line with proper markup
    print()
    print("Step 3: Updating prices with realistic margins (20-80% markup)...")
    
    updated = 0
    skipped = 0
    
    for so_line_id, product_id, quantity, current_price, current_total in sales_lines:
        if product_id not in product_costs:
            skipped += 1
            continue
        
        avg_cost = product_costs[product_id]
        
        # Generate a random markup between 20% and 80%
        markup = random.uniform(0.20, 0.80)
        new_unit_price = round(avg_cost * (1 + markup), 2)
        qty = float(quantity) if quantity else 1.0
        new_line_total = round(new_unit_price * qty, 2)
        
        # Update the record
        cur.execute("""
            UPDATE synthetic.sales_order_lines
            SET unit_price = %s,
                line_total = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE so_line_id = %s
        """, (new_unit_price, new_line_total, so_line_id))
        
        updated += 1
        
        if updated % 100 == 0:
            print(f"   Updated {updated} lines...")
    
    conn.commit()
    print(f"   ✓ Updated {updated} lines, skipped {skipped} (no cost data)")
    
    # Step 4: Also update the products table base_price to match
    print()
    print("Step 4: Updating product base prices...")
    cur.execute("""
        WITH avg_selling_price AS (
            SELECT 
                product_id,
                AVG(unit_price) as avg_price
            FROM synthetic.sales_order_lines
            WHERE unit_price > 0
            GROUP BY product_id
        )
        UPDATE synthetic.products p
        SET base_price = asp.avg_price,
            updated_at = CURRENT_TIMESTAMP
        FROM avg_selling_price asp
        WHERE p.product_id = asp.product_id
    """)
    products_updated = cur.rowcount
    conn.commit()
    print(f"   ✓ Updated {products_updated} product base prices")
    
    # Step 5: Verify the fix
    print()
    print("Step 5: Verifying margins...")
    cur.execute("""
        WITH weighted_costs AS (
            SELECT
                product_id,
                SUM(unit_cost * quantity_ordered) / NULLIF(SUM(quantity_ordered), 0) AS weighted_avg_cost
            FROM synthetic.purchase_order_lines
            GROUP BY product_id
        ),
        order_margins AS (
            SELECT
                so.sales_order_id,
                SUM(sol.line_total) as revenue,
                SUM(sol.quantity * COALESCE(wc.weighted_avg_cost, 0)) as cogs,
                SUM(sol.line_total) - SUM(sol.quantity * COALESCE(wc.weighted_avg_cost, 0)) as margin
            FROM synthetic.sales_orders so
            JOIN synthetic.sales_order_lines sol ON so.sales_order_id = sol.sales_order_id
            LEFT JOIN weighted_costs wc ON sol.product_id = wc.product_id
            GROUP BY so.sales_order_id
        )
        SELECT 
            COUNT(*) as total_orders,
            SUM(CASE WHEN margin >= 0 THEN 1 ELSE 0 END) as positive_margins,
            SUM(CASE WHEN margin < 0 THEN 1 ELSE 0 END) as negative_margins,
            ROUND(AVG(CASE WHEN revenue > 0 THEN 100.0 * margin / revenue END), 1) as avg_margin_pct
        FROM order_margins
        WHERE revenue > 0
    """)
    
    result = cur.fetchone()
    total, positive, negative, avg_margin = result
    
    print(f"   Total orders: {total}")
    print(f"   Positive margins: {positive}")
    print(f"   Negative margins: {negative}")
    print(f"   Average margin: {avg_margin}%")
    
    # Step 6: Show sample results
    print()
    print("Step 6: Sample margin results...")
    cur.execute("""
        WITH weighted_costs AS (
            SELECT
                product_id,
                SUM(unit_cost * quantity_ordered) / NULLIF(SUM(quantity_ordered), 0) AS weighted_avg_cost
            FROM synthetic.purchase_order_lines
            GROUP BY product_id
        )
        SELECT
            so.sales_order_id as order_id,
            a.account_name as customer,
            ROUND(SUM(sol.line_total)::numeric, 2) as revenue,
            ROUND(SUM(sol.quantity * COALESCE(wc.weighted_avg_cost, 0))::numeric, 2) as cogs,
            ROUND((SUM(sol.line_total) - SUM(sol.quantity * COALESCE(wc.weighted_avg_cost, 0)))::numeric, 2) as margin,
            ROUND((100.0 * (SUM(sol.line_total) - SUM(sol.quantity * COALESCE(wc.weighted_avg_cost, 0))) / 
                   NULLIF(SUM(sol.line_total), 0))::numeric, 1) as margin_pct
        FROM synthetic.sales_orders so
        JOIN synthetic.sales_order_lines sol ON so.sales_order_id = sol.sales_order_id
        LEFT JOIN synthetic.accounts a ON so.account_id = a.account_id
        LEFT JOIN weighted_costs wc ON sol.product_id = wc.product_id
        GROUP BY so.sales_order_id, a.account_name
        HAVING SUM(sol.line_total) > 0
        ORDER BY so.sales_order_id
        LIMIT 10
    """)
    
    print()
    print(f"{'Order':<8} {'Customer':<25} {'Revenue':>12} {'COGS':>12} {'Margin':>12} {'%':>8}")
    print("-" * 80)
    
    for row in cur.fetchall():
        order_id, customer, revenue, cogs, margin, margin_pct = row
        customer_display = (customer or "N/A")[:24]
        print(f"{order_id:<8} {customer_display:<25} {revenue:>12,.2f} {cogs:>12,.2f} {margin:>12,.2f} {margin_pct:>7.1f}%")
    
    conn.close()
    
    print()
    print("=" * 60)
    print("✅ Margin fix complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()

