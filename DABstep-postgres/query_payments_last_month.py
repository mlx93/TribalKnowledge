#!/usr/bin/env python3
"""
Query script to count payments from the last month in Supabase.
"""

import psycopg2
import os
from dotenv import load_dotenv
from datetime import datetime, timedelta

# Load environment variables from .env file
load_dotenv()

# Supabase Session Pooler connection
SUPABASE_DB = {
    'host': os.getenv('SUPABASE_HOST'),
    'port': int(os.getenv('SUPABASE_PORT', 5432)),
    'database': os.getenv('SUPABASE_DB', 'postgres'),
    'user': os.getenv('SUPABASE_USER'),
    'password': os.getenv('SUPABASE_PASSWORD')
}

def count_payments_last_month():
    """Count payments made in the last month."""
    try:
        # Connect to Supabase
        print('Connecting to Supabase...')
        conn = psycopg2.connect(**SUPABASE_DB)
        print('✓ Connected to Supabase\n')
        
        # Calculate date one month ago
        one_month_ago = datetime.now() - timedelta(days=30)
        
        # Query to count payments from the last month
        query = """
        SELECT COUNT(*) as payment_count
        FROM payments
        WHERE created_at >= %s;
        """
        
        with conn.cursor() as cur:
            cur.execute(query, (one_month_ago,))
            result = cur.fetchone()
            count = result[0] if result else 0
            
            print(f"Date range: Last 30 days (from {one_month_ago.strftime('%Y-%m-%d %H:%M:%S')} to now)")
            print(f"\n📊 Total payments in the last month: {count:,}")
            
            # Also get some additional stats
            stats_query = """
            SELECT 
                COUNT(*) as total_count,
                SUM(transaction_amount) as total_volume,
                AVG(transaction_amount) as avg_amount,
                MIN(created_at) as earliest_payment,
                MAX(created_at) as latest_payment
            FROM payments
            WHERE created_at >= %s;
            """
            
            cur.execute(stats_query, (one_month_ago,))
            stats = cur.fetchone()
            
            if stats:
                total_count, total_volume, avg_amount, earliest, latest = stats
                print(f"\n📈 Additional Statistics:")
                print(f"   Total transaction volume: ${total_volume:,.2f}" if total_volume is not None else "   Total transaction volume: N/A")
                print(f"   Average transaction amount: ${avg_amount:,.2f}" if avg_amount is not None else "   Average transaction amount: N/A")
                print(f"   Earliest payment: {earliest}" if earliest is not None else "   Earliest payment: N/A")
                print(f"   Latest payment: {latest}" if latest is not None else "   Latest payment: N/A")
        
        conn.close()
        return count
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        raise
    except Exception as e:
        print(f"❌ Error: {e}")
        raise

if __name__ == '__main__':
    count_payments_last_month()

