#!/usr/bin/env python3
"""
Supabase Batch Setup - Creates tables in small batches to avoid timeouts.

Usage:
    python setup-supabase-batch.py --url "postgresql://..." --batch 1
    python setup-supabase-batch.py --url "postgresql://..." --batch 2
    ... etc
    
    Or use --all to run all batches sequentially
"""

import os
import sys
import argparse
import random
from datetime import datetime, timedelta
from typing import Dict, List, Any
import json

import psycopg2
from psycopg2 import sql
from faker import Faker

# Import domain definitions
from domains import DOMAINS
from domains_extended import DOMAINS_EXTENDED
from domains_more import DOMAINS_MORE
from main import DOMAINS_EDUCATION

fake = Faker()
Faker.seed(42)
random.seed(42)

generated_ids: Dict[str, List[int]] = {}

BATCH_SIZE = 25  # Tables per batch


def get_all_domains():
    all_domains = {}
    all_domains.update(DOMAINS)
    all_domains.update(DOMAINS_EXTENDED)
    all_domains.update(DOMAINS_MORE)
    all_domains.update(DOMAINS_EDUCATION)
    return all_domains


def get_ordered_tables(all_domains):
    """Order tables by FK dependencies."""
    tables = []
    table_fks = {}
    
    for domain_name, domain_def in all_domains.items():
        for table in domain_def["tables"]:
            table_name = table["name"]
            tables.append((domain_name, table_name, table))
            fks = set()
            for col in table["columns"]:
                if col.get("fk"):
                    ref_table = col["fk"].split(".")[0]
                    if ref_table != table_name:
                        fks.add(ref_table)
            table_fks[table_name] = fks
    
    ordered = []
    remaining = {t[1]: t for t in tables}
    done = set()
    
    while remaining:
        made_progress = False
        for table_name in list(remaining.keys()):
            deps = table_fks.get(table_name, set())
            if deps <= done:
                ordered.append(remaining[table_name])
                done.add(table_name)
                del remaining[table_name]
                made_progress = True
        
        if not made_progress and remaining:
            table_name = next(iter(remaining.keys()))
            ordered.append(remaining[table_name])
            done.add(table_name)
            del remaining[table_name]
    
    return ordered


def generate_value(col, row_num):
    col_name = col["name"].lower()
    col_type = col["type"].upper()
    
    if col.get("primary_key") and "SERIAL" in col_type:
        return None
    
    if col.get("fk"):
        ref_table = col["fk"].split(".")[0]
        if ref_table in generated_ids and generated_ids[ref_table]:
            return random.choice(generated_ids[ref_table])
        return None
    
    # Name patterns
    if "email" in col_name:
        return fake.email()
    elif "phone" in col_name or "mobile" in col_name:
        return fake.phone_number()[:20]
    elif "first_name" in col_name:
        return fake.first_name()
    elif "last_name" in col_name:
        return fake.last_name()
    elif col_name in ("name", "contact_name"):
        return fake.name()
    elif "company" in col_name or "vendor_name" in col_name:
        return fake.company()[:200]
    elif "address" in col_name and "line" not in col_name:
        return fake.address().replace("\n", ", ")[:255]
    elif "city" in col_name:
        return fake.city()[:100]
    elif "state" in col_name:
        return fake.state()[:100]
    elif "postal" in col_name or "zip" in col_name:
        return fake.postcode()[:20]
    elif "country_code" in col_name:
        return fake.country_code()
    elif "country" in col_name:
        return fake.country()[:100]
    elif "url" in col_name or "website" in col_name:
        return fake.url()[:255]
    elif "description" in col_name or "notes" in col_name:
        return fake.paragraph()[:500]
    elif "title" in col_name:
        return fake.sentence(nb_words=4)[:200]
    
    # Type patterns
    if "SERIAL" in col_type or "INTEGER" in col_type:
        if "year" in col_name:
            return random.randint(2020, 2025)
        elif "count" in col_name or "quantity" in col_name:
            return random.randint(1, 100)
        elif "percent" in col_name:
            return random.randint(0, 100)
        return random.randint(1, 1000)
    
    elif "DECIMAL" in col_type or "NUMERIC" in col_type:
        if "amount" in col_name or "price" in col_name or "cost" in col_name:
            return round(random.uniform(10, 10000), 2)
        elif "rate" in col_name:
            return round(random.uniform(0, 100), 4)
        return round(random.uniform(0, 1000), 2)
    
    elif "BOOLEAN" in col_type:
        return random.choice([True, False])
    
    elif "DATE" in col_type and "TIME" not in col_type:
        return fake.date_between(start_date="-2y", end_date="today")
    
    elif "TIMESTAMP" in col_type:
        return fake.date_time_between(start_date="-2y", end_date="now")
    
    elif "TIME" in col_type:
        return fake.time()
    
    elif "JSONB" in col_type or "JSON" in col_type:
        return json.dumps({"key": fake.word()})
    
    elif "TEXT" in col_type:
        return fake.paragraph()
    
    elif "VARCHAR" in col_type:
        try:
            length = int(col_type.split("(")[1].split(")")[0])
        except:
            length = 100
        
        if "code" in col_name:
            return fake.lexify(text="?" * min(8, length)).upper()
        elif "number" in col_name:
            return fake.numerify(text="#" * min(15, length))
        elif "status" in col_name:
            return random.choice(["active", "inactive", "pending"])[:length]
        elif "currency" in col_name:
            return random.choice(["USD", "EUR", "GBP"])[:length]
        elif length < 5:
            return fake.lexify(text="?" * length)
        return fake.text(max_nb_chars=max(5, min(length, 100)))[:length]
    
    return None


def create_table(conn, schema, table_name, table_def):
    columns = table_def["columns"]
    col_defs = []
    
    for col in columns:
        parts = [f'"{col["name"]}"', col["type"]]
        if col.get("primary_key"):
            parts.append("PRIMARY KEY")
        if col.get("not_null"):
            parts.append("NOT NULL")
        if col.get("unique"):
            parts.append("UNIQUE")
        if col.get("default"):
            parts.append(f"DEFAULT {col['default']}")
        col_defs.append(" ".join(parts))
    
    col_defs.append('"created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP')
    col_defs.append('"updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP')
    
    create_sql = f'CREATE TABLE IF NOT EXISTS "{schema}"."{table_name}" ({", ".join(col_defs)})'
    
    try:
        with conn.cursor() as cur:
            cur.execute(create_sql)
        conn.commit()
        return True
    except Exception as e:
        conn.rollback()
        print(f"    ⚠ Error: {str(e)[:60]}")
        return False


def insert_data(conn, schema, table_name, table_def, num_rows):
    columns = table_def["columns"]
    insert_cols = [c for c in columns if not (c.get("primary_key") and "SERIAL" in c["type"].upper())]
    
    if not insert_cols:
        return 0
    
    col_names = [c["name"] for c in insert_cols]
    placeholders = ", ".join(["%s"] * len(col_names))
    col_sql = ", ".join([f'"{c}"' for c in col_names])
    
    pk_col = next((c["name"] for c in columns if c.get("primary_key")), None)
    
    insert_sql = f'INSERT INTO "{schema}"."{table_name}" ({col_sql}) VALUES ({placeholders}) RETURNING *'
    
    rows_inserted = 0
    generated_ids[table_name] = []
    
    with conn.cursor() as cur:
        for i in range(num_rows):
            values = [generate_value(c, i) for c in insert_cols]
            try:
                cur.execute(insert_sql, values)
                result = cur.fetchone()
                if result and pk_col:
                    pk_idx = next((idx for idx, c in enumerate(columns) if c["name"] == pk_col), 0)
                    generated_ids[table_name].append(result[pk_idx])
                rows_inserted += 1
            except:
                pass
        conn.commit()
    
    return rows_inserted


def load_existing_ids(conn, schema, tables):
    """Load existing IDs from tables that were created in previous batches."""
    for _, table_name, table_def in tables:
        pk_col = next((c["name"] for c in table_def["columns"] if c.get("primary_key")), None)
        if pk_col:
            try:
                with conn.cursor() as cur:
                    cur.execute(f'SELECT "{pk_col}" FROM "{schema}"."{table_name}" LIMIT 1000')
                    ids = [row[0] for row in cur.fetchall()]
                    if ids:
                        generated_ids[table_name] = ids
            except:
                pass


def main():
    parser = argparse.ArgumentParser(description="Batch upload to Supabase")
    parser.add_argument("--url", default=os.environ.get("SUPABASE_DB_URL"), required=True)
    parser.add_argument("--schema", default="synthetic")
    parser.add_argument("--rows", type=int, default=50, help="Rows per table")
    parser.add_argument("--batch", type=int, help="Batch number (1-10)")
    parser.add_argument("--all", action="store_true", help="Run all batches")
    parser.add_argument("--list", action="store_true", help="List batches")
    
    args = parser.parse_args()
    
    all_domains = get_all_domains()
    ordered = get_ordered_tables(all_domains)
    total = len(ordered)
    num_batches = (total + BATCH_SIZE - 1) // BATCH_SIZE
    
    if args.list:
        print(f"Total tables: {total}")
        print(f"Batch size: {BATCH_SIZE}")
        print(f"Total batches: {num_batches}")
        print()
        for i in range(num_batches):
            start = i * BATCH_SIZE
            end = min(start + BATCH_SIZE, total)
            tables = [t[1] for t in ordered[start:end]]
            print(f"Batch {i+1}: {len(tables)} tables")
            print(f"  {', '.join(tables[:5])}{'...' if len(tables) > 5 else ''}")
        return
    
    print("=" * 50)
    print("Supabase Batch Setup")
    print("=" * 50)
    
    conn = psycopg2.connect(args.url, connect_timeout=30)
    print("✓ Connected to Supabase")
    
    # Create schema
    with conn.cursor() as cur:
        cur.execute(f'CREATE SCHEMA IF NOT EXISTS "{args.schema}"')
        cur.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')
    conn.commit()
    print(f"✓ Schema '{args.schema}' ready")
    
    # Load existing IDs for FK references
    load_existing_ids(conn, args.schema, ordered)
    
    batches_to_run = range(1, num_batches + 1) if args.all else [args.batch] if args.batch else []
    
    if not batches_to_run:
        print("\nSpecify --batch N or --all")
        print(f"Available batches: 1-{num_batches}")
        conn.close()
        return
    
    for batch_num in batches_to_run:
        start = (batch_num - 1) * BATCH_SIZE
        end = min(start + BATCH_SIZE, total)
        batch_tables = ordered[start:end]
        
        print(f"\n{'='*50}")
        print(f"Batch {batch_num}/{num_batches}: Tables {start+1}-{end}")
        print("=" * 50)
        
        for i, (domain, table_name, table_def) in enumerate(batch_tables):
            print(f"\n[{i+1}/{len(batch_tables)}] {table_name}")
            
            # Create table
            print(f"  Creating table...", end=" ", flush=True)
            if create_table(conn, args.schema, table_name, table_def):
                print("✓")
            else:
                print("⚠")
                continue
            
            # Insert data
            print(f"  Inserting {args.rows} rows...", end=" ", flush=True)
            rows = insert_data(conn, args.schema, table_name, table_def, args.rows)
            print(f"✓ ({rows} rows)")
    
    conn.close()
    
    print("\n" + "=" * 50)
    print("✅ Batch complete!")
    print("=" * 50)


if __name__ == "__main__":
    main()

