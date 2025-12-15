#!/usr/bin/env python3
"""
Query script to find products with the most promotions over the past month.
"""

import psycopg2
import os
from dotenv import load_dotenv
from datetime import datetime, timedelta

# Load environment variables from .env file
load_dotenv('DABstep-postgres/.env')

# Use SUPABASE_DB_URL if available (for synthetic_250 database)
# Otherwise fall back to individual connection parameters
SUPABASE_DB_URL = os.getenv('SUPABASE_DB_URL')

# Fallback: Supabase Session Pooler connection (for DABstep database)
SUPABASE_DB = {
    'host': os.getenv('SUPABASE_HOST'),
    'port': int(os.getenv('SUPABASE_PORT', 5432)),
    'database': os.getenv('SUPABASE_DB', 'postgres'),
    'user': os.getenv('SUPABASE_USER'),
    'password': os.getenv('SUPABASE_PASSWORD')
}

def get_top_promoted_products():
    """Find products with the most promotions over the past month."""
    try:
        # Connect to Supabase
        print('Connecting to Supabase...')
        if SUPABASE_DB_URL:
            print('  Using SUPABASE_DB_URL (synthetic_250 database)')
            conn = psycopg2.connect(SUPABASE_DB_URL)
        else:
            print('  Using individual connection params')
            conn = psycopg2.connect(**SUPABASE_DB)
        print('✓ Connected to Supabase\n')
        
        # Calculate date one month ago
        one_month_ago = datetime.now() - timedelta(days=30)
        
        # Query to find products with the most promotions
        query = """
        SELECT 
            pp.product_id,
            COUNT(DISTINCT pp.promotion_id) as promotion_count,
            STRING_AGG(DISTINCT p.promotion_name, ', ' ORDER BY p.promotion_name) as promotion_names
        FROM synthetic.promotion_products pp
        INNER JOIN synthetic.promotions p 
            ON pp.promotion_id = p.promotion_id
        WHERE p.start_date >= %s
            OR (p.start_date <= CURRENT_DATE 
                AND p.end_date >= %s)
        GROUP BY pp.product_id
        ORDER BY promotion_count DESC
        LIMIT 10;
        """
        
        with conn.cursor() as cur:
            cur.execute(query, (one_month_ago, one_month_ago))
            results = cur.fetchall()
            
            print(f"📅 Date range: Last 30 days (from {one_month_ago.strftime('%Y-%m-%d')} to now)")
            print(f"\n🏆 Top 10 Products by Promotion Count:\n")
            print(f"{'Product ID':<15} {'Promotions':<15} {'Promotion Details'}")
            print("-" * 80)
            
            for row in results:
                product_id, promo_count, promo_names = row
                # Truncate promotion names if too long
                promo_display = promo_names[:50] + "..." if promo_names and len(promo_names) > 50 else promo_names
                print(f"{product_id:<15} {promo_count:<15} {promo_display or 'N/A'}")
            
            if not results:
                print("No products found with promotions in the past month.")
        
        conn.close()
        return results
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        raise
    except Exception as e:
        print(f"❌ Error: {e}")
        raise

if __name__ == '__main__':
    get_top_promoted_products()
