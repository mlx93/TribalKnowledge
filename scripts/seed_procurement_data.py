#!/usr/bin/env python3
"""
Seed Procurement Data for Realistic Margins

This script creates realistic purchase orders and procurement costs
based on existing sales order data, giving realistic profit margins (15-40%).

Usage:
    # Load env vars first
    source /path/to/TribalAgent/.env
    
    python seed_procurement_data.py
    
    # Or with explicit connection string
    python seed_procurement_data.py --url "postgresql://user:pass@host:port/db"

Requirements:
    pip install psycopg2-binary python-dotenv
"""

import os
import sys
import argparse
import random
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Dict, List, Any, Optional

try:
    import psycopg2
    from psycopg2.extras import execute_batch, RealDictCursor
except ImportError:
    print("❌ psycopg2 not installed. Run: pip install psycopg2-binary")
    sys.exit(1)

try:
    from dotenv import load_dotenv
except ImportError:
    print("⚠️  python-dotenv not installed. Using system env vars only.")
    load_dotenv = None

# Seed for reproducibility
random.seed(42)

# Margin configuration - cost as percentage of sale price
MARGIN_CONFIG = {
    'min_cost_ratio': 0.55,  # Minimum cost = 55% of sale price (45% margin)
    'max_cost_ratio': 0.85,  # Maximum cost = 85% of sale price (15% margin)
    'avg_cost_ratio': 0.70,  # Average around 70% (30% margin)
}

# Supplier names for seeding
SUPPLIER_NAMES = [
    ("Global Supply Co.", "USA", "Net 30"),
    ("Pacific Trading Ltd.", "China", "Net 45"),
    ("Euro Components GmbH", "Germany", "Net 30"),
    ("Tokyo Industries", "Japan", "Net 60"),
    ("Atlas Materials Inc.", "USA", "Net 30"),
    ("Nordic Supplies AB", "Sweden", "Net 45"),
    ("Mumbai Exports Pvt Ltd", "India", "Net 30"),
    ("Canadian Resources Corp", "Canada", "Net 30"),
    ("Melbourne Trading Pty", "Australia", "Net 45"),
    ("São Paulo Distribuidora", "Brazil", "Net 60"),
]


def get_connection_string() -> str:
    """Build connection string from environment variables."""
    # Try direct URL first
    url = os.environ.get("SUPABASE_DB_URL")
    if url:
        return url
    
    # Build from individual components
    user = os.environ.get("SUPABASE_SYNTHETIC_USER")
    password = os.environ.get("SUPABASE_SYNTHETIC_PASSWORD")
    host = os.environ.get("SUPABASE_SYNTHETIC_HOST")
    port = os.environ.get("SUPABASE_SYNTHETIC_PORT", "6543")
    database = os.environ.get("SUPABASE_SYNTHETIC_DATABASE", "postgres")
    
    if all([user, password, host]):
        return f"postgresql://{user}:{password}@{host}:{port}/{database}"
    
    return None


def connect_db(url: str):
    """Connect to the database."""
    print(f"Connecting to database...")
    try:
        conn = psycopg2.connect(url)
        conn.autocommit = False
        print("✓ Connected successfully")
        return conn
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        sys.exit(1)


def seed_suppliers(conn, schema: str = "synthetic") -> List[int]:
    """Ensure we have suppliers and return their IDs."""
    print("\n📦 Checking/seeding suppliers...")
    
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Check existing suppliers
        cur.execute(f'SELECT supplier_id FROM "{schema}".suppliers ORDER BY supplier_id')
        existing = [row['supplier_id'] for row in cur.fetchall()]
        
        if len(existing) >= 5:
            print(f"  ✓ Found {len(existing)} existing suppliers")
            return existing
        
        # Seed suppliers
        print(f"  Seeding {len(SUPPLIER_NAMES)} suppliers...")
        supplier_ids = []
        
        for i, (name, country, terms) in enumerate(SUPPLIER_NAMES, start=1):
            code = f"SUP-{i:04d}"
            
            cur.execute(f'''
                INSERT INTO "{schema}".suppliers 
                (supplier_code, supplier_name, contact_name, email, country, payment_terms, lead_time_days, rating, is_active)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (supplier_code) DO UPDATE SET supplier_name = EXCLUDED.supplier_name
                RETURNING supplier_id
            ''', (
                code,
                name,
                f"Contact {i}",
                f"supplier{i}@example.com",
                country,
                terms,
                random.randint(7, 30),
                round(random.uniform(3.5, 5.0), 1),
                True
            ))
            result = cur.fetchone()
            if result:
                supplier_ids.append(result['supplier_id'])
        
        conn.commit()
        print(f"  ✓ Seeded {len(supplier_ids)} suppliers")
        return supplier_ids or existing


def get_products_from_sales(conn, schema: str = "synthetic") -> List[Dict]:
    """Get products that appear in sales order lines with their sale prices."""
    print("\n📊 Analyzing sales order lines for products...")
    
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(f'''
            SELECT DISTINCT 
                sol.product_id,
                sol.product_name,
                AVG(sol.unit_price) as avg_sale_price,
                SUM(sol.quantity) as total_quantity_sold,
                COUNT(*) as order_count
            FROM "{schema}".sales_order_lines sol
            WHERE sol.product_id IS NOT NULL
            GROUP BY sol.product_id, sol.product_name
            ORDER BY total_quantity_sold DESC
        ''')
        products = cur.fetchall()
        
        print(f"  ✓ Found {len(products)} products in sales orders")
        return products


def clear_existing_procurement_data(conn, schema: str = "synthetic"):
    """Optionally clear existing procurement data."""
    print("\n🗑️  Clearing existing procurement data...")
    
    with conn.cursor() as cur:
        cur.execute(f'DELETE FROM "{schema}".purchase_order_lines')
        po_lines_deleted = cur.rowcount
        
        cur.execute(f'DELETE FROM "{schema}".purchase_orders')
        po_deleted = cur.rowcount
        
    conn.commit()
    print(f"  ✓ Deleted {po_deleted} purchase orders and {po_lines_deleted} line items")


def create_purchase_orders(
    conn, 
    products: List[Dict], 
    supplier_ids: List[int],
    schema: str = "synthetic"
) -> Dict[int, List[Dict]]:
    """
    Create purchase orders for each product with realistic costs.
    Returns a mapping of product_id to purchase order line details.
    """
    print("\n📝 Creating purchase orders with realistic procurement costs...")
    
    if not supplier_ids:
        print("  ❌ No suppliers available!")
        return {}
    
    product_procurement = {}
    po_count = 0
    pol_count = 0
    
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Get max existing po_id
        cur.execute(f'SELECT COALESCE(MAX(po_id), 0) as max_id FROM "{schema}".purchase_orders')
        next_po_id = cur.fetchone()['max_id'] + 1
        
        # Get max existing po_line_id
        cur.execute(f'SELECT COALESCE(MAX(po_line_id), 0) as max_id FROM "{schema}".purchase_order_lines')
        next_pol_id = cur.fetchone()['max_id'] + 1
        
        for product in products:
            product_id = product['product_id']
            avg_sale_price = float(product['avg_sale_price'] or 100)
            total_qty = float(product['total_quantity_sold'] or 10)
            
            # Calculate realistic cost (55-85% of sale price)
            # Using beta distribution for more realistic spread around 70%
            cost_ratio = random.betavariate(2, 1) * (
                MARGIN_CONFIG['max_cost_ratio'] - MARGIN_CONFIG['min_cost_ratio']
            ) + MARGIN_CONFIG['min_cost_ratio']
            
            unit_cost = round(avg_sale_price * cost_ratio, 2)
            
            # Create 1-3 purchase orders per product (simulating multiple buys)
            num_pos = random.randint(1, 3)
            product_procurement[product_id] = []
            
            for po_num in range(num_pos):
                supplier_id = random.choice(supplier_ids)
                
                # Order date: 30-180 days ago
                order_date = datetime.now() - timedelta(days=random.randint(30, 180))
                expected_date = order_date + timedelta(days=random.randint(7, 30))
                
                # Quantity: portion of total sold
                qty_ordered = max(1, int(total_qty / num_pos * random.uniform(0.8, 1.5)))
                qty_received = qty_ordered if random.random() > 0.1 else int(qty_ordered * random.uniform(0.8, 1.0))
                
                line_total = round(unit_cost * qty_ordered, 2)
                tax_amount = round(line_total * 0.08, 2)  # 8% tax
                shipping = round(random.uniform(10, 100), 2)
                total_amount = round(line_total + tax_amount + shipping, 2)
                
                # Insert purchase order
                cur.execute(f'''
                    INSERT INTO "{schema}".purchase_orders 
                    (po_id, po_number, supplier_id, order_date, expected_date, status, 
                     subtotal, tax_amount, shipping_cost, total_amount, currency, notes)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING po_id
                ''', (
                    next_po_id,
                    f"PO-{next_po_id:06d}",
                    supplier_id,
                    order_date.date(),
                    expected_date.date(),
                    random.choice(['completed', 'completed', 'completed', 'partial', 'pending']),
                    line_total,
                    tax_amount,
                    shipping,
                    total_amount,
                    'USD',
                    f"Procurement for product {product_id}"
                ))
                
                po_id = cur.fetchone()['po_id']
                po_count += 1
                
                # Insert purchase order line
                cur.execute(f'''
                    INSERT INTO "{schema}".purchase_order_lines
                    (po_line_id, po_id, product_id, quantity_ordered, quantity_received, unit_cost, line_total)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                ''', (
                    next_pol_id,
                    po_id,
                    product_id,
                    qty_ordered,
                    qty_received,
                    unit_cost,
                    line_total
                ))
                
                product_procurement[product_id].append({
                    'po_id': po_id,
                    'unit_cost': unit_cost,
                    'quantity': qty_ordered,
                    'supplier_id': supplier_id
                })
                
                pol_count += 1
                next_po_id += 1
                next_pol_id += 1
        
        conn.commit()
    
    print(f"  ✓ Created {po_count} purchase orders with {pol_count} line items")
    return product_procurement


def update_product_cost_prices(conn, products: List[Dict], schema: str = "synthetic"):
    """Update products table with cost_price based on procurement data."""
    print("\n💰 Updating product cost_price from procurement data...")
    
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        # Calculate average procurement cost per product
        cur.execute(f'''
            UPDATE "{schema}".products p
            SET cost_price = subq.avg_cost
            FROM (
                SELECT 
                    pol.product_id,
                    AVG(pol.unit_cost) as avg_cost
                FROM "{schema}".purchase_order_lines pol
                GROUP BY pol.product_id
            ) subq
            WHERE p.product_id = subq.product_id
        ''')
        
        updated = cur.rowcount
        conn.commit()
    
    print(f"  ✓ Updated cost_price for {updated} products")


def verify_margins(conn, schema: str = "synthetic"):
    """Verify the margins look realistic now."""
    print("\n📈 Verifying margin calculations...")
    
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(f'''
            WITH avg_procurement_cost AS (
                SELECT 
                    pol.product_id,
                    SUM(pol.unit_cost * pol.quantity_ordered) / NULLIF(SUM(pol.quantity_ordered), 0) AS avg_unit_cost
                FROM "{schema}".purchase_order_lines pol
                GROUP BY pol.product_id
            ),
            line_margins AS (
                SELECT 
                    sol.sales_order_id,
                    sol.line_total AS revenue,
                    sol.quantity * COALESCE(apc.avg_unit_cost, p.cost_price, 0) AS cogs
                FROM "{schema}".sales_order_lines sol
                LEFT JOIN "{schema}".products p ON sol.product_id = p.product_id
                LEFT JOIN avg_procurement_cost apc ON sol.product_id = apc.product_id
            )
            SELECT 
                COUNT(*) as order_count,
                ROUND(AVG(
                    CASE WHEN revenue > 0 
                    THEN ((revenue - cogs) / revenue) * 100 
                    ELSE 0 END
                ), 2) as avg_margin_percent,
                ROUND(MIN(
                    CASE WHEN revenue > 0 
                    THEN ((revenue - cogs) / revenue) * 100 
                    ELSE 0 END
                ), 2) as min_margin_percent,
                ROUND(MAX(
                    CASE WHEN revenue > 0 
                    THEN ((revenue - cogs) / revenue) * 100 
                    ELSE 0 END
                ), 2) as max_margin_percent,
                SUM(revenue) as total_revenue,
                SUM(cogs) as total_cogs,
                SUM(revenue - cogs) as total_margin
            FROM line_margins
        ''')
        
        result = cur.fetchone()
        
        print(f"\n  📊 Margin Summary:")
        print(f"     Orders analyzed: {result['order_count']}")
        print(f"     Average margin:  {result['avg_margin_percent']}%")
        print(f"     Min margin:      {result['min_margin_percent']}%")
        print(f"     Max margin:      {result['max_margin_percent']}%")
        print(f"     Total revenue:   ${result['total_revenue']:,.2f}")
        print(f"     Total COGS:      ${result['total_cogs']:,.2f}")
        print(f"     Total margin:    ${result['total_margin']:,.2f}")


def main():
    parser = argparse.ArgumentParser(description="Seed procurement data for realistic margins")
    parser.add_argument(
        "--url",
        default=None,
        help="PostgreSQL connection URL (or use env vars)"
    )
    parser.add_argument(
        "--schema",
        default="synthetic",
        help="Schema name (default: synthetic)"
    )
    parser.add_argument(
        "--clear",
        action="store_true",
        help="Clear existing procurement data before seeding"
    )
    parser.add_argument(
        "--env-file",
        default=None,
        help="Path to .env file"
    )
    
    args = parser.parse_args()
    
    # Load environment variables
    if load_dotenv:
        env_file = args.env_file or os.path.join(
            os.path.dirname(__file__), 
            "../TribalAgent/.env"
        )
        if os.path.exists(env_file):
            load_dotenv(env_file)
            print(f"✓ Loaded env from {env_file}")
    
    # Get connection string
    url = args.url or get_connection_string()
    
    if not url:
        print("❌ Error: No database connection available")
        print("")
        print("Set environment variables:")
        print("  SUPABASE_SYNTHETIC_USER")
        print("  SUPABASE_SYNTHETIC_PASSWORD")
        print("  SUPABASE_SYNTHETIC_HOST")
        print("  SUPABASE_SYNTHETIC_PORT")
        print("")
        print("Or use --url flag:")
        print("  python seed_procurement_data.py --url 'postgresql://...'")
        sys.exit(1)
    
    print("=" * 60)
    print("🏭 Procurement Data Seeding for Realistic Margins")
    print("=" * 60)
    
    # Connect
    conn = connect_db(url)
    
    try:
        # Clear existing data if requested
        if args.clear:
            clear_existing_procurement_data(conn, args.schema)
        
        # Seed suppliers
        supplier_ids = seed_suppliers(conn, args.schema)
        
        # Get products from sales
        products = get_products_from_sales(conn, args.schema)
        
        if not products:
            print("\n⚠️  No products found in sales order lines!")
            print("   Make sure sales_order_lines has data with product_id values.")
            return
        
        # Create purchase orders with realistic costs
        product_procurement = create_purchase_orders(
            conn, products, supplier_ids, args.schema
        )
        
        # Update product cost_price
        update_product_cost_prices(conn, products, args.schema)
        
        # Verify margins
        verify_margins(conn, args.schema)
        
        print("\n" + "=" * 60)
        print("✅ Procurement data seeding complete!")
        print("=" * 60)
        print("\nRun your margin query again to see realistic margins.")
        
    except Exception as e:
        conn.rollback()
        print(f"\n❌ Error: {e}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()

