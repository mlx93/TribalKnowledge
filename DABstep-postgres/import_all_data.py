#!/usr/bin/env python3
"""Import all DABstep data into PostgreSQL database."""

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import json
import os

# Database connection
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'dabstep',
    'user': 'postgres',
    'password': 'postgres'
}

DATA_DIR = 'data'

def get_connection():
    return psycopg2.connect(**DB_CONFIG)

def import_mcc_codes(conn):
    """Import merchant category codes."""
    print("Importing merchant category codes...")
    df = pd.read_csv(f'{DATA_DIR}/merchant_category_codes.csv')
    print(f"  Found {len(df)} MCC codes")
    
    with conn.cursor() as cur:
        for _, row in df.iterrows():
            cur.execute("""
                INSERT INTO merchant_category_codes (mcc_code, category_description)
                VALUES (%s, %s)
                ON CONFLICT (mcc_code) DO NOTHING
            """, (str(row['mcc']), row['description']))
    conn.commit()
    
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM merchant_category_codes")
        count = cur.fetchone()[0]
    print(f"  ✓ Imported {count} MCC codes")

def import_countries(conn):
    """Import acquirer countries."""
    print("Importing acquirer countries...")
    df = pd.read_csv(f'{DATA_DIR}/acquirer_countries.csv')
    print(f"  Found {len(df)} country records")
    
    # Get unique country codes
    unique_codes = df['country_code'].unique()
    
    with conn.cursor() as cur:
        for code in unique_codes:
            if pd.notna(code):
                cur.execute("""
                    INSERT INTO acquirer_countries (country_code)
                    VALUES (%s)
                    ON CONFLICT (country_code) DO NOTHING
                """, (code,))
    conn.commit()
    
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM acquirer_countries")
        count = cur.fetchone()[0]
    print(f"  ✓ Imported {count} unique country codes")

def import_payments(conn):
    """Import payments data."""
    print("Importing payments data (this may take a few minutes)...")
    
    # Read CSV in chunks for memory efficiency
    chunk_size = 10000
    total_imported = 0
    
    for chunk in pd.read_csv(f'{DATA_DIR}/payments.csv', chunksize=chunk_size):
        rows = []
        for _, row in chunk.iterrows():
            rows.append((
                str(row['psp_reference']),
                row['merchant'],
                row['card_scheme'],
                float(row['eur_amount']) if pd.notna(row['eur_amount']) else None,
                row['issuing_country'] if pd.notna(row['issuing_country']) else None,
                row['device_type'] if pd.notna(row['device_type']) else None,
                row['shopper_interaction'] if pd.notna(row['shopper_interaction']) else None,
                str(row['card_bin']) if pd.notna(row['card_bin']) else None,
                bool(row['has_fraudulent_dispute']) if pd.notna(row['has_fraudulent_dispute']) else False,
                bool(row['is_refused_by_adyen']) if pd.notna(row['is_refused_by_adyen']) else False,
                row['aci'] if pd.notna(row['aci']) else None,
                row['acquirer_country'] if pd.notna(row['acquirer_country']) else None,
                row['ip_country'] if pd.notna(row['ip_country']) else None
            ))
        
        with conn.cursor() as cur:
            execute_values(cur, """
                INSERT INTO payments (
                    payment_id, merchant_id, card_brand, transaction_amount,
                    issuing_country, device_type, shopper_interaction, card_bin,
                    is_fraudulent, is_refused, aci, acquirer_country_code, ip_country
                ) VALUES %s
                ON CONFLICT (payment_id) DO NOTHING
            """, rows)
        conn.commit()
        total_imported += len(rows)
        print(f"  Processed {total_imported} payments...")
    
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM payments")
        count = cur.fetchone()[0]
    print(f"  ✓ Imported {count} payments")

def import_merchants(conn):
    """Import merchants from merchant_data.json."""
    print("Importing merchants...")
    
    with open(f'{DATA_DIR}/merchant_data.json', 'r') as f:
        merchants = json.load(f)
    
    print(f"  Found {len(merchants)} merchants")
    
    with conn.cursor() as cur:
        for merchant in merchants:
            merchant_id = merchant.get('merchant') or merchant.get('merchant_id') or merchant.get('name')
            if merchant_id:
                cur.execute("""
                    INSERT INTO merchants (merchant_id)
                    VALUES (%s)
                    ON CONFLICT (merchant_id) DO NOTHING
                """, (merchant_id,))
    conn.commit()
    
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM merchants")
        count = cur.fetchone()[0]
    print(f"  ✓ Imported {count} merchants")

def import_fees(conn):
    """Import fee structures from fees.json."""
    print("Importing fee structures...")
    
    with open(f'{DATA_DIR}/fees.json', 'r') as f:
        fees = json.load(f)
    
    print(f"  Found {len(fees)} fee structures")
    
    with conn.cursor() as cur:
        for fee in fees:
            cur.execute("""
                INSERT INTO fee_structures (fee_data)
                VALUES (%s)
            """, (json.dumps(fee),))
    conn.commit()
    
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM fee_structures")
        count = cur.fetchone()[0]
    print(f"  ✓ Imported {count} fee structures")

def main():
    print("=" * 50)
    print("DABstep Data Import")
    print("=" * 50)
    
    # Check data directory exists
    if not os.path.exists(DATA_DIR):
        print(f"Error: Data directory '{DATA_DIR}' not found!")
        return
    
    try:
        conn = get_connection()
        print(f"Connected to database: {DB_CONFIG['database']}")
        print()
        
        import_mcc_codes(conn)
        import_countries(conn)
        import_merchants(conn)
        import_fees(conn)
        import_payments(conn)
        
        conn.close()
        
        print()
        print("=" * 50)
        print("✅ All data imported successfully!")
        print("=" * 50)
        
    except Exception as e:
        print(f"Error: {e}")
        raise

if __name__ == '__main__':
    main()

