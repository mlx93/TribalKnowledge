#!/usr/bin/env python3
"""
Add foreign key constraints to existing Supabase tables.
"""

import os
import sys
import argparse
import psycopg2

# Import domain definitions
from domains import DOMAINS
from domains_extended import DOMAINS_EXTENDED
from domains_more import DOMAINS_MORE
from main import DOMAINS_EDUCATION


def get_all_domains():
    all_domains = {}
    all_domains.update(DOMAINS)
    all_domains.update(DOMAINS_EXTENDED)
    all_domains.update(DOMAINS_MORE)
    all_domains.update(DOMAINS_EDUCATION)
    return all_domains


def get_all_foreign_keys(all_domains, schema):
    """Extract all FK definitions from domain configs."""
    fks = []
    
    for domain_name, domain_def in all_domains.items():
        for table in domain_def["tables"]:
            table_name = table["name"]
            for col in table["columns"]:
                if col.get("fk"):
                    ref_table, ref_col = col["fk"].split(".")
                    fks.append({
                        "table": table_name,
                        "column": col["name"],
                        "ref_table": ref_table,
                        "ref_column": ref_col,
                        "constraint_name": f"fk_{table_name}_{col['name']}"
                    })
    
    return fks


def check_constraint_exists(conn, schema, constraint_name):
    """Check if a constraint already exists."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_schema = %s AND constraint_name = %s
        """, (schema, constraint_name))
        return cur.fetchone() is not None


def check_table_exists(conn, schema, table_name):
    """Check if a table exists."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = %s AND table_name = %s
        """, (schema, table_name))
        return cur.fetchone() is not None


def add_foreign_key(conn, schema, fk):
    """Add a single foreign key constraint."""
    sql = f'''
        ALTER TABLE "{schema}"."{fk['table']}"
        ADD CONSTRAINT "{fk['constraint_name']}"
        FOREIGN KEY ("{fk['column']}")
        REFERENCES "{schema}"."{fk['ref_table']}" ("{fk['ref_column']}")
        ON DELETE SET NULL
        ON UPDATE CASCADE
    '''
    
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


def main():
    parser = argparse.ArgumentParser(description="Add foreign keys to Supabase tables")
    parser.add_argument("--url", default=os.environ.get("SUPABASE_DB_URL"), required=True)
    parser.add_argument("--schema", default="synthetic")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without executing")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("Adding Foreign Key Constraints")
    print("=" * 60)
    print()
    
    conn = psycopg2.connect(args.url, connect_timeout=30)
    print("✓ Connected to Supabase")
    print()
    
    all_domains = get_all_domains()
    all_fks = get_all_foreign_keys(all_domains, args.schema)
    
    print(f"Found {len(all_fks)} foreign key definitions")
    print()
    
    added = 0
    skipped_exists = 0
    skipped_missing_table = 0
    failed = 0
    
    for i, fk in enumerate(all_fks):
        status = ""
        
        # Check if constraint exists
        if check_constraint_exists(conn, args.schema, fk['constraint_name']):
            skipped_exists += 1
            status = "exists"
        # Check if both tables exist
        elif not check_table_exists(conn, args.schema, fk['table']):
            skipped_missing_table += 1
            status = f"table '{fk['table']}' missing"
        elif not check_table_exists(conn, args.schema, fk['ref_table']):
            skipped_missing_table += 1
            status = f"ref table '{fk['ref_table']}' missing"
        else:
            if args.dry_run:
                status = "would add"
                added += 1
            else:
                try:
                    add_foreign_key(conn, args.schema, fk)
                    status = "✓ added"
                    added += 1
                except Exception as e:
                    error_msg = str(e).split('\n')[0][:50]
                    status = f"✗ failed: {error_msg}"
                    failed += 1
                    conn.rollback()
        
        # Print progress every 10 or on interesting events
        if (i + 1) % 25 == 0 or status.startswith("✓") or status.startswith("✗"):
            print(f"[{i+1}/{len(all_fks)}] {fk['table']}.{fk['column']} → {fk['ref_table']}.{fk['ref_column']}: {status}")
    
    conn.close()
    
    print()
    print("=" * 60)
    print("Summary")
    print("=" * 60)
    print(f"  Added:                {added}")
    print(f"  Already existed:      {skipped_exists}")
    print(f"  Missing tables:       {skipped_missing_table}")
    print(f"  Failed:               {failed}")
    print()
    
    if args.dry_run:
        print("(Dry run - no changes made)")
    else:
        print("✅ Foreign keys added!")


if __name__ == "__main__":
    main()

