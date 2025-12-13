#!/usr/bin/env python3
"""
Supabase Setup Script for Synthetic 250-Table Database
Uploads schema and generates fake data directly to Supabase.

Usage:
    python setup-supabase.py --url "postgresql://..." [--rows-per-table 100]
    
    Or set environment variable:
    export SUPABASE_DB_URL="postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres"
    python setup-supabase.py

Requirements:
    pip install psycopg2-binary faker
"""

import os
import sys
import argparse
import random
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Dict, List, Any, Optional
import json

try:
    import psycopg2
    from psycopg2 import sql
    from psycopg2.extras import execute_batch
except ImportError:
    print("❌ psycopg2 not installed. Run: pip install psycopg2-binary")
    sys.exit(1)

try:
    from faker import Faker
except ImportError:
    print("❌ faker not installed. Run: pip install faker")
    sys.exit(1)

# Import domain definitions
from domains import DOMAINS
from domains_extended import DOMAINS_EXTENDED
from domains_more import DOMAINS_MORE
from main import DOMAINS_EDUCATION

# Initialize Faker
fake = Faker()
Faker.seed(42)
random.seed(42)

# Track generated IDs for foreign key references
generated_ids: Dict[str, List[int]] = {}


def get_all_domains() -> Dict[str, Dict[str, Any]]:
    """Merge all domain definitions."""
    all_domains = {}
    all_domains.update(DOMAINS)
    all_domains.update(DOMAINS_EXTENDED)
    all_domains.update(DOMAINS_MORE)
    all_domains.update(DOMAINS_EDUCATION)
    return all_domains


def generate_value_for_column(col: Dict[str, Any], row_num: int) -> Any:
    """Generate a fake value based on column type and name."""
    col_name = col["name"].lower()
    col_type = col["type"].upper()
    
    # Skip auto-generated columns
    if col.get("primary_key") and "SERIAL" in col_type:
        return None  # Let PostgreSQL auto-generate
    
    # Handle foreign keys - reference existing IDs
    if col.get("fk"):
        ref_table = col["fk"].split(".")[0]
        if ref_table in generated_ids and generated_ids[ref_table]:
            return random.choice(generated_ids[ref_table])
        return None  # No reference available yet
    
    # Generate based on column name patterns
    if "email" in col_name:
        return fake.email()
    elif "phone" in col_name or "fax" in col_name or "mobile" in col_name:
        return fake.phone_number()[:20]
    elif "first_name" in col_name:
        return fake.first_name()
    elif "last_name" in col_name:
        return fake.last_name()
    elif col_name in ("name", "contact_name", "subscriber_name", "recipient"):
        return fake.name()
    elif "company" in col_name or "vendor_name" in col_name or "supplier_name" in col_name:
        return fake.company()
    elif "address" in col_name and "line" not in col_name:
        return fake.address().replace("\n", ", ")
    elif "address_line1" in col_name:
        return fake.street_address()
    elif "address_line2" in col_name:
        return fake.secondary_address() if random.random() > 0.5 else None
    elif "city" in col_name:
        return fake.city()
    elif "state" in col_name or "province" in col_name:
        return fake.state()[:100]
    elif "postal_code" in col_name or "zip" in col_name:
        return fake.postcode()
    elif "country" in col_name and "code" not in col_name:
        return fake.country()[:100]
    elif "country_code" in col_name:
        return fake.country_code()
    elif "website" in col_name or "url" in col_name:
        return fake.url()[:255]
    elif "description" in col_name or "notes" in col_name or "comment" in col_name:
        return fake.paragraph()
    elif "title" in col_name and "job" not in col_name:
        return fake.sentence(nb_words=4)[:200]
    elif "job_title" in col_name or col_name == "title":
        return fake.job()[:100]
    elif "password" in col_name:
        return fake.sha256()[:255]
    elif "ssn" in col_name:
        return fake.ssn()[-4:]
    elif "ip_address" in col_name:
        return fake.ipv4()
    elif "user_agent" in col_name:
        return fake.user_agent()[:500]
    
    # Generate based on column type
    if "SERIAL" in col_type or "INTEGER" in col_type:
        if "year" in col_name:
            return random.randint(2020, 2025)
        elif "count" in col_name or "quantity" in col_name:
            return random.randint(0, 1000)
        elif "percentage" in col_name or "percent" in col_name:
            return random.randint(0, 100)
        elif "rating" in col_name or "score" in col_name:
            return random.randint(1, 5)
        elif "priority" in col_name or "level" in col_name:
            return random.randint(1, 5)
        elif "days" in col_name:
            return random.randint(1, 30)
        elif "minutes" in col_name or "duration" in col_name:
            return random.randint(15, 120)
        elif "hours" in col_name:
            return random.randint(1, 40)
        else:
            return random.randint(1, 10000)
    
    elif "DECIMAL" in col_type or "NUMERIC" in col_type:
        if "amount" in col_name or "price" in col_name or "cost" in col_name or "salary" in col_name or "budget" in col_name:
            return round(random.uniform(100, 100000), 2)
        elif "rate" in col_name or "percentage" in col_name:
            return round(random.uniform(0, 100), 4)
        elif "weight" in col_name:
            return round(random.uniform(0.1, 100), 3)
        elif "gpa" in col_name:
            return round(random.uniform(2.0, 4.0), 2)
        else:
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
        return json.dumps({"key": fake.word(), "value": fake.word()})
    
    elif "TEXT" in col_type:
        return fake.paragraph()
    
    elif "VARCHAR" in col_type:
        # Extract length from VARCHAR(n)
        try:
            length = int(col_type.split("(")[1].split(")")[0])
        except:
            length = 100
        
        if "code" in col_name:
            return fake.lexify(text="?" * min(10, length)).upper()
        elif "number" in col_name:
            return fake.numerify(text="#" * min(20, length))
        elif "slug" in col_name:
            return fake.slug()[:length]
        elif "currency" in col_name:
            return random.choice(["USD", "EUR", "GBP", "JPY", "CAD"])[:length]
        elif "status" in col_name:
            return random.choice(["active", "inactive", "pending", "completed", "cancelled"])[:length]
        elif "type" in col_name:
            return fake.word()[:length]
        elif "gender" in col_name:
            return random.choice(["male", "female", "other"])[:length]
        else:
            return fake.text(max_nb_chars=length)[:length]
    
    return None


def get_table_order(all_domains: Dict) -> List[tuple]:
    """
    Order tables for insertion based on foreign key dependencies.
    Tables with no FKs come first, then tables referencing those, etc.
    """
    # Collect all tables with their FK dependencies
    tables = []
    table_fks = {}
    
    for domain_name, domain_def in all_domains.items():
        for table in domain_def["tables"]:
            table_name = table["name"]
            tables.append((domain_name, table_name, table))
            
            # Get FK references
            fks = set()
            for col in table["columns"]:
                if col.get("fk"):
                    ref_table = col["fk"].split(".")[0]
                    if ref_table != table_name:  # Exclude self-references
                        fks.add(ref_table)
            table_fks[table_name] = fks
    
    # Topological sort
    ordered = []
    remaining = {t[1]: t for t in tables}
    done = set()
    
    max_iterations = len(tables) * 2
    iteration = 0
    
    while remaining and iteration < max_iterations:
        iteration += 1
        made_progress = False
        
        for table_name in list(remaining.keys()):
            # Check if all dependencies are satisfied
            deps = table_fks.get(table_name, set())
            if deps <= done:
                ordered.append(remaining[table_name])
                done.add(table_name)
                del remaining[table_name]
                made_progress = True
        
        if not made_progress and remaining:
            # Break circular dependency by adding one table anyway
            table_name = next(iter(remaining.keys()))
            ordered.append(remaining[table_name])
            done.add(table_name)
            del remaining[table_name]
    
    return ordered


def create_schema(conn, schema_name: str):
    """Create the schema if it doesn't exist."""
    with conn.cursor() as cur:
        cur.execute(sql.SQL("CREATE SCHEMA IF NOT EXISTS {}").format(
            sql.Identifier(schema_name)
        ))
        cur.execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";")
    conn.commit()
    print(f"✓ Schema '{schema_name}' ready")


def create_table(conn, schema_name: str, table_name: str, table_def: Dict) -> bool:
    """Create a single table."""
    columns = table_def["columns"]
    
    # Build column definitions
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
    
    # Add timestamp columns
    col_defs.append('"created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP')
    col_defs.append('"updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP')
    
    # Build CREATE TABLE statement
    create_sql = f'''
        CREATE TABLE IF NOT EXISTS "{schema_name}"."{table_name}" (
            {", ".join(col_defs)}
        )
    '''
    
    try:
        with conn.cursor() as cur:
            cur.execute(create_sql)
        conn.commit()
        return True
    except Exception as e:
        conn.rollback()
        print(f"  ⚠ Error creating {table_name}: {e}")
        return False


def add_foreign_keys(conn, schema_name: str, table_name: str, table_def: Dict):
    """Add foreign key constraints after all tables are created."""
    columns = table_def["columns"]
    
    for col in columns:
        if col.get("fk"):
            ref_table, ref_col = col["fk"].split(".")
            constraint_name = f"fk_{table_name}_{col['name']}"
            
            # Check if constraint already exists
            check_sql = """
                SELECT 1 FROM information_schema.table_constraints 
                WHERE constraint_name = %s AND table_schema = %s
            """
            
            try:
                with conn.cursor() as cur:
                    cur.execute(check_sql, (constraint_name, schema_name))
                    if cur.fetchone():
                        continue  # Constraint exists
                    
                    # Add constraint
                    alter_sql = f'''
                        ALTER TABLE "{schema_name}"."{table_name}"
                        ADD CONSTRAINT "{constraint_name}"
                        FOREIGN KEY ("{col['name']}")
                        REFERENCES "{schema_name}"."{ref_table}" ("{ref_col}")
                        ON DELETE SET NULL
                    '''
                    cur.execute(alter_sql)
                conn.commit()
            except Exception as e:
                conn.rollback()
                # Silently skip FK errors (might be due to missing referenced tables)


def insert_data(conn, schema_name: str, table_name: str, table_def: Dict, num_rows: int):
    """Insert fake data into a table."""
    columns = table_def["columns"]
    
    # Filter out auto-generated serial columns
    insert_cols = [col for col in columns if not (col.get("primary_key") and "SERIAL" in col["type"].upper())]
    
    if not insert_cols:
        return 0
    
    col_names = [col["name"] for col in insert_cols]
    placeholders = ", ".join(["%s"] * len(col_names))
    col_names_sql = ", ".join([f'"{c}"' for c in col_names])
    
    insert_sql = f'''
        INSERT INTO "{schema_name}"."{table_name}" ({col_names_sql})
        VALUES ({placeholders})
        RETURNING *
    '''
    
    # Find the primary key column
    pk_col = None
    for col in columns:
        if col.get("primary_key"):
            pk_col = col["name"]
            break
    
    rows_inserted = 0
    generated_ids[table_name] = []
    
    try:
        with conn.cursor() as cur:
            for i in range(num_rows):
                values = []
                for col in insert_cols:
                    val = generate_value_for_column(col, i)
                    values.append(val)
                
                try:
                    cur.execute(insert_sql, values)
                    result = cur.fetchone()
                    if result and pk_col:
                        # Find PK index in result
                        pk_idx = next((idx for idx, col in enumerate(columns) if col["name"] == pk_col), 0)
                        generated_ids[table_name].append(result[pk_idx])
                    rows_inserted += 1
                except Exception as e:
                    # Skip individual row errors (unique constraint violations, etc.)
                    pass
            
            conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"  ⚠ Error inserting into {table_name}: {e}")
    
    return rows_inserted


def main():
    parser = argparse.ArgumentParser(description="Upload synthetic database to Supabase")
    parser.add_argument(
        "--url",
        default=os.environ.get("SUPABASE_DB_URL"),
        help="Supabase PostgreSQL connection URL (or set SUPABASE_DB_URL env var)"
    )
    parser.add_argument(
        "--schema",
        default="synthetic",
        help="Schema name (default: synthetic)"
    )
    parser.add_argument(
        "--rows-per-table",
        type=int,
        default=50,
        help="Number of rows per table (default: 50)"
    )
    parser.add_argument(
        "--skip-data",
        action="store_true",
        help="Only create schema, skip data generation"
    )
    parser.add_argument(
        "--drop-existing",
        action="store_true",
        help="Drop existing schema before creating"
    )
    
    args = parser.parse_args()
    
    if not args.url:
        print("❌ Error: No database URL provided")
        print("")
        print("Set SUPABASE_DB_URL environment variable or use --url flag:")
        print("")
        print("  export SUPABASE_DB_URL='postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres'")
        print("  python setup-supabase.py")
        print("")
        print("Or:")
        print("  python setup-supabase.py --url 'postgresql://...'")
        print("")
        print("Find your connection string in Supabase Dashboard:")
        print("  Project Settings → Database → Connection string → URI")
        sys.exit(1)
    
    print("=" * 60)
    print("Supabase Synthetic 250-Table Database Setup")
    print("=" * 60)
    print()
    
    # Connect to database
    print("Connecting to Supabase...")
    try:
        conn = psycopg2.connect(args.url)
        conn.autocommit = False
        print("✓ Connected successfully")
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        sys.exit(1)
    
    print()
    
    # Get all domains
    all_domains = get_all_domains()
    total_tables = sum(len(d["tables"]) for d in all_domains.values())
    
    print(f"Tables to create: {total_tables}")
    print(f"Rows per table: {args.rows_per_table}")
    print(f"Schema: {args.schema}")
    print()
    
    # Drop existing schema if requested
    if args.drop_existing:
        print(f"Dropping existing schema '{args.schema}'...")
        with conn.cursor() as cur:
            cur.execute(f'DROP SCHEMA IF EXISTS "{args.schema}" CASCADE')
        conn.commit()
        print("✓ Existing schema dropped")
        print()
    
    # Create schema
    create_schema(conn, args.schema)
    print()
    
    # Order tables by dependencies
    print("Analyzing table dependencies...")
    ordered_tables = get_table_order(all_domains)
    print(f"✓ Determined insertion order for {len(ordered_tables)} tables")
    print()
    
    # Create tables
    print("Creating tables...")
    tables_created = 0
    for domain_name, table_name, table_def in ordered_tables:
        if create_table(conn, args.schema, table_name, table_def):
            tables_created += 1
            if tables_created % 25 == 0:
                print(f"  Created {tables_created}/{total_tables} tables...")
    
    print(f"✓ Created {tables_created} tables")
    print()
    
    # Insert data
    if not args.skip_data:
        print(f"Inserting {args.rows_per_table} rows per table...")
        total_rows = 0
        tables_with_data = 0
        
        for domain_name, table_name, table_def in ordered_tables:
            rows = insert_data(conn, args.schema, table_name, table_def, args.rows_per_table)
            total_rows += rows
            if rows > 0:
                tables_with_data += 1
            
            if tables_with_data % 25 == 0 and tables_with_data > 0:
                print(f"  Populated {tables_with_data}/{total_tables} tables ({total_rows:,} rows)...")
        
        print(f"✓ Inserted {total_rows:,} rows across {tables_with_data} tables")
        print()
    
    # Add foreign keys (after data is inserted)
    print("Adding foreign key constraints...")
    fk_count = 0
    for domain_name, table_name, table_def in ordered_tables:
        for col in table_def["columns"]:
            if col.get("fk"):
                add_foreign_keys(conn, args.schema, table_name, table_def)
                fk_count += 1
                break
    print(f"✓ Foreign keys processed")
    print()
    
    # Close connection
    conn.close()
    
    # Summary
    print("=" * 60)
    print("✅ Setup Complete!")
    print("=" * 60)
    print()
    print(f"Schema: {args.schema}")
    print(f"Tables: {tables_created}")
    if not args.skip_data:
        print(f"Total rows: ~{total_rows:,}")
    print()
    print("View your data in Supabase Dashboard → Table Editor")
    print()


if __name__ == "__main__":
    main()

