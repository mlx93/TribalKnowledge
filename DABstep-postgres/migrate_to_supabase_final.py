#!/usr/bin/env python3
"""
DABstep Migration Script: Local PostgreSQL → Supabase

This script migrates all data from the local Docker PostgreSQL database
to a Supabase cloud instance.

Usage:
    python3 migrate_to_supabase_final.py

Connection Details (update as needed):
    - Local: localhost:5432/dabstep (postgres/postgres)
    - Supabase: Session pooler connection (IPv4 compatible)
"""

import psycopg2
from psycopg2.extras import execute_values
import json
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# =============================================================================
# CONFIGURATION - Set these in .env file (see .env.example)
# =============================================================================

LOCAL_DB = {
    'host': os.getenv('LOCAL_DB_HOST', 'localhost'),
    'port': int(os.getenv('LOCAL_DB_PORT', 5432)),
    'database': os.getenv('LOCAL_DB_NAME', 'dabstep'),
    'user': os.getenv('LOCAL_DB_USER', 'postgres'),
    'password': os.getenv('LOCAL_DB_PASSWORD', 'postgres')
}

# Supabase Session Pooler (IPv4 compatible)
# Get these from: Supabase Dashboard → Connect → Session pooler
SUPABASE_DB = {
    'host': os.getenv('SUPABASE_HOST'),           # e.g., aws-0-us-west-2.pooler.supabase.com
    'port': int(os.getenv('SUPABASE_PORT', 5432)),
    'database': os.getenv('SUPABASE_DB', 'postgres'),
    'user': os.getenv('SUPABASE_USER'),           # e.g., postgres.{project-ref}
    'password': os.getenv('SUPABASE_PASSWORD')    # Your database password
}

# =============================================================================
# SCHEMA DEFINITION
# =============================================================================

SCHEMA_SQL = '''
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS merchant_category_codes (
    mcc_code VARCHAR(10) PRIMARY KEY,
    category_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS acquirer_countries (
    country_code VARCHAR(3) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS merchants (
    merchant_id VARCHAR(50) PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payments (
    payment_id VARCHAR(100) PRIMARY KEY,
    merchant_id VARCHAR(50),
    card_brand VARCHAR(20),
    transaction_amount DECIMAL(15,2),
    issuing_country VARCHAR(3),
    device_type VARCHAR(20),
    shopper_interaction VARCHAR(20),
    card_bin VARCHAR(20),
    is_fraudulent BOOLEAN DEFAULT false,
    is_refused BOOLEAN DEFAULT false,
    aci VARCHAR(10),
    acquirer_country_code VARCHAR(3),
    ip_country VARCHAR(3),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fee_structures (
    fee_id SERIAL PRIMARY KEY,
    fee_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_merchant_id ON payments(merchant_id);
CREATE INDEX IF NOT EXISTS idx_payments_card_brand ON payments(card_brand);
'''

# =============================================================================
# MIGRATION FUNCTIONS
# =============================================================================

def migrate_simple_table(local_conn, supa_conn, table_name, columns, conflict_col=None):
    """Migrate a simple table with optional conflict handling."""
    print(f'\nMigrating {table_name}...')
    
    with local_conn.cursor() as cur:
        cur.execute(f"SELECT {', '.join(columns)} FROM {table_name}")
        rows = cur.fetchall()
    
    print(f'  Found {len(rows)} rows')
    
    if not rows:
        return
    
    conflict_clause = f" ON CONFLICT ({conflict_col}) DO NOTHING" if conflict_col else ""
    
    with supa_conn.cursor() as cur:
        sql = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES %s{conflict_clause}"
        execute_values(cur, sql, rows)
    
    supa_conn.commit()
    print(f'  ✓ Done')


def migrate_payments(local_conn, supa_conn, chunk_size=5000):
    """Migrate payments table in chunks for large datasets."""
    print('\nMigrating payments (chunked for large dataset)...')
    
    columns = [
        'payment_id', 'merchant_id', 'card_brand', 'transaction_amount',
        'issuing_country', 'device_type', 'shopper_interaction', 'card_bin',
        'is_fraudulent', 'is_refused', 'aci', 'acquirer_country_code', 'ip_country'
    ]
    
    # Get total count
    with local_conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM payments")
        total = cur.fetchone()[0]
    
    print(f'  Total: {total} payments')
    
    offset = 0
    migrated = 0
    
    while offset < total:
        with local_conn.cursor() as cur:
            cur.execute(f"""
                SELECT {', '.join(columns)} 
                FROM payments 
                ORDER BY payment_id 
                LIMIT {chunk_size} OFFSET {offset}
            """)
            rows = cur.fetchall()
        
        if not rows:
            break
        
        with supa_conn.cursor() as cur:
            sql = f"INSERT INTO payments ({', '.join(columns)}) VALUES %s ON CONFLICT DO NOTHING"
            execute_values(cur, sql, rows, page_size=1000)
        
        supa_conn.commit()
        migrated += len(rows)
        offset += chunk_size
        print(f'  Migrated {migrated}/{total}...')
    
    print('  ✓ Payments migration complete!')


def migrate_fee_structures(local_conn, supa_conn):
    """Migrate fee structures (JSONB data)."""
    print('\nMigrating fee_structures...')
    
    with local_conn.cursor() as cur:
        cur.execute("SELECT fee_data FROM fee_structures")
        rows = cur.fetchall()
    
    print(f'  Found {len(rows)} rows')
    
    with supa_conn.cursor() as cur:
        for row in rows:
            fee_data = json.dumps(row[0]) if isinstance(row[0], dict) else row[0]
            cur.execute("INSERT INTO fee_structures (fee_data) VALUES (%s)", (fee_data,))
    
    supa_conn.commit()
    print('  ✓ Done')


def verify_migration(supa_conn):
    """Verify the migration by counting rows in each table."""
    print('\n' + '=' * 50)
    print('MIGRATION COMPLETE - Final counts:')
    print('=' * 50)
    
    tables = ['payments', 'merchants', 'merchant_category_codes', 
              'acquirer_countries', 'fee_structures']
    
    for table in tables:
        with supa_conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            count = cur.fetchone()[0]
        print(f'  {table}: {count} rows')


# =============================================================================
# MAIN MIGRATION
# =============================================================================

def main():
    print('=' * 50)
    print('DABstep Migration: Local PostgreSQL → Supabase')
    print('=' * 50)
    
    try:
        # Connect to databases
        print('\nConnecting to local database...')
        local_conn = psycopg2.connect(**LOCAL_DB)
        print('✓ Connected to local')
        
        print('Connecting to Supabase...')
        supa_conn = psycopg2.connect(**SUPABASE_DB)
        print('✓ Connected to Supabase')
        
        # Create schema
        print('\nCreating schema...')
        with supa_conn.cursor() as cur:
            cur.execute(SCHEMA_SQL)
        supa_conn.commit()
        print('✓ Schema created')
        
        # Migrate reference tables
        migrate_simple_table(local_conn, supa_conn, 
            'merchant_category_codes', 
            ['mcc_code', 'category_description'], 
            'mcc_code')
        
        migrate_simple_table(local_conn, supa_conn,
            'acquirer_countries',
            ['country_code'],
            'country_code')
        
        migrate_simple_table(local_conn, supa_conn,
            'merchants',
            ['merchant_id'],
            'merchant_id')
        
        # Migrate fee structures
        migrate_fee_structures(local_conn, supa_conn)
        
        # Migrate payments (large table, chunked)
        migrate_payments(local_conn, supa_conn)
        
        # Verify
        verify_migration(supa_conn)
        
        # Cleanup
        local_conn.close()
        supa_conn.close()
        
        print('\n✅ All data migrated to Supabase!')
        print('\nYour Supabase database is now ready at:')
        print(f"  Host: {SUPABASE_DB['host']}")
        print(f"  Database: {SUPABASE_DB['database']}")
        print('\nView your data at: https://supabase.com/dashboard/project/ubfnjrsqfohuydzlmmvd/editor')
        
    except psycopg2.OperationalError as e:
        print(f'\n❌ Connection error: {e}')
        print('\nTroubleshooting:')
        print('  1. Make sure local Docker PostgreSQL is running')
        print('  2. Check Supabase connection string (use Session pooler for IPv4)')
        print('  3. Verify your database password')
        raise


if __name__ == '__main__':
    main()

