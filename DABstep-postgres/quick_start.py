#!/usr/bin/env python3
"""
Quick start script for DABstep PostgreSQL database setup.
This script provides clear instructions and handles what it can.
"""

import os
import subprocess
import sys
from pathlib import Path

def check_docker():
    """Check if Docker is available and running."""
    try:
        result = subprocess.run(['docker', 'info'], capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False

def check_postgres_running():
    """Check if PostgreSQL container is running."""
    try:
        result = subprocess.run(['docker', 'ps'], capture_output=True, text=True)
        return 'postgres-dabstep' in result.stdout
    except:
        return False

def start_docker_services():
    """Start Docker services."""
    print("🚀 Starting Docker services...")
    try:
        result = subprocess.run(['docker-compose', 'up', '-d'], cwd='.')
        if result.returncode == 0:
            print("✅ Docker services started successfully")
            return True
        else:
            print("❌ Failed to start Docker services")
            return False
    except Exception as e:
        print(f"❌ Error starting Docker: {e}")
        return False

def download_dataset():
    """Download the DABstep dataset."""
    print("📥 Downloading DABstep dataset...")

    # Create data directory
    data_dir = Path("data")
    data_dir.mkdir(exist_ok=True)

    # Base URL for the dataset
    BASE_URL = "https://huggingface.co/datasets/adyen/DABstep/resolve/main/data/context"

    # Files to download
    files = [
        "payments.csv",
        "acquirer_countries.csv",
        "fees.json",
        "merchant_category_codes.csv",
        "merchant_data.json",
        "manual.md",
        "payments-readme.md"
    ]

    downloaded = 0
    for filename in files:
        url = f"{BASE_URL}/{filename}"
        output_path = data_dir / filename

        try:
            print(f"  Downloading {filename}...")
            result = subprocess.run(['curl', '-L', '-o', str(output_path), url],
                                  capture_output=True, text=True)
            if result.returncode == 0 and output_path.exists():
                size = output_path.stat().st_size
                print(f"  ✅ Downloaded {filename} ({size} bytes)")
                downloaded += 1
            else:
                print(f"  ❌ Failed to download {filename}")
        except Exception as e:
            print(f"  ❌ Error downloading {filename}: {e}")

    print(f"📊 Downloaded {downloaded}/{len(files)} files")
    return downloaded > 0

def show_manual_instructions():
    """Show manual setup instructions."""
    print("\n" + "="*60)
    print("📋 MANUAL SETUP INSTRUCTIONS")
    print("="*60)

    print("""
🔧 To complete the setup manually:

1. START DOCKER SERVICES:
   cd DABstep-postgres-2
   docker-compose up -d

2. WAIT FOR POSTGRESQL TO BE READY:
   # Wait about 30 seconds, then check:
   docker exec postgres-dabstep pg_isready -U postgres

3. DOWNLOAD DATASET:
   python3 quick_start.py download

4. CREATE DATABASE SCHEMA:
   # Connect to PostgreSQL and run the schema SQL
   docker exec -it postgres-dabstep psql -U postgres -d dabstep

5. IMPORT DATA:
   python3 quick_start.py import

6. ACCESS YOUR DATABASE:
   • PostgreSQL: localhost:5432
     User: postgres, Password: postgres
   • PgAdmin: http://localhost:5050
     Email: admin@dabstep.com, Password: admin

🔍 SAMPLE QUERY:
   docker exec -it postgres-dabstep psql -U postgres -d dabstep -c "
   SELECT COUNT(*) as total_payments,
          SUM(transaction_amount) as total_volume
   FROM payments;"

""")

def create_schema_sql():
    """Create the database schema SQL file."""
    schema_sql = """
-- DABstep Database Schema
-- Payment processing dataset from Adyen

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Merchant Category Codes (MCC) table
CREATE TABLE IF NOT EXISTS merchant_category_codes (
    mcc_code VARCHAR(10) PRIMARY KEY,
    category_name VARCHAR(255),
    category_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Acquirer Countries table
CREATE TABLE IF NOT EXISTS acquirer_countries (
    country_code VARCHAR(3) PRIMARY KEY,
    country_name VARCHAR(100),
    currency_code VARCHAR(3),
    region VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Merchants table
CREATE TABLE IF NOT EXISTS merchants (
    merchant_id VARCHAR(50) PRIMARY KEY,
    merchant_name VARCHAR(255),
    merchant_category_code VARCHAR(10) REFERENCES merchant_category_codes(mcc_code),
    country_code VARCHAR(3) REFERENCES acquirer_countries(country_code),
    registration_date DATE,
    risk_score DECIMAL(5,2),
    merchant_data JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Main payments table
CREATE TABLE IF NOT EXISTS payments (
    payment_id VARCHAR(100) PRIMARY KEY,
    merchant_id VARCHAR(50) REFERENCES merchants(merchant_id),
    acquirer_country_code VARCHAR(3) REFERENCES acquirer_countries(country_code),
    transaction_amount DECIMAL(15,2),
    transaction_currency VARCHAR(3),
    settlement_amount DECIMAL(15,2),
    settlement_currency VARCHAR(3),
    exchange_rate DECIMAL(10,6),
    transaction_date TIMESTAMP,
    settlement_date TIMESTAMP,
    payment_method VARCHAR(50),
    card_brand VARCHAR(20),
    card_country VARCHAR(3),
    authorization_code VARCHAR(20),
    response_code VARCHAR(10),
    transaction_type VARCHAR(20),
    is_chargeback BOOLEAN DEFAULT false,
    is_refund BOOLEAN DEFAULT false,
    fees_amount DECIMAL(10,2),
    interchange_fee DECIMAL(10,2),
    scheme_fee DECIMAL(10,2),
    processing_fee DECIMAL(10,2),
    merchant_fee DECIMAL(10,2),
    net_amount DECIMAL(15,2),
    batch_id VARCHAR(50),
    terminal_id VARCHAR(50),
    transaction_status VARCHAR(20),
    risk_score DECIMAL(5,2),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fee structures table
CREATE TABLE IF NOT EXISTS fee_structures (
    fee_id SERIAL PRIMARY KEY,
    merchant_category_code VARCHAR(10) REFERENCES merchant_category_codes(mcc_code),
    country_code VARCHAR(3) REFERENCES acquirer_countries(country_code),
    card_brand VARCHAR(20),
    transaction_type VARCHAR(20),
    interchange_percentage DECIMAL(5,4),
    interchange_fixed DECIMAL(10,2),
    scheme_percentage DECIMAL(5,4),
    scheme_fixed DECIMAL(10,2),
    processing_percentage DECIMAL(5,4),
    processing_fixed DECIMAL(10,2),
    merchant_percentage DECIMAL(5,4),
    merchant_fixed DECIMAL(10,2),
    effective_from DATE,
    effective_to DATE,
    fee_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payments_merchant_id ON payments(merchant_id);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_date ON payments(transaction_date);
CREATE INDEX IF NOT EXISTS idx_payments_settlement_date ON payments(settlement_date);
CREATE INDEX IF NOT EXISTS idx_payments_payment_method ON payments(payment_method);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(transaction_status);
CREATE INDEX IF NOT EXISTS idx_merchants_category ON merchants(merchant_category_code);
CREATE INDEX IF NOT EXISTS idx_merchants_country ON merchants(country_code);
CREATE INDEX IF NOT EXISTS idx_fee_structures_mcc ON fee_structures(merchant_category_code);
CREATE INDEX IF NOT EXISTS idx_fee_structures_country ON fee_structures(country_code);
CREATE INDEX IF NOT EXISTS idx_fee_structures_dates ON fee_structures(effective_from, effective_to);
"""

    with open("schema.sql", "w") as f:
        f.write(schema_sql)

    print("✅ Created schema.sql")

def import_data():
    """Import data into PostgreSQL."""
    print("📊 Importing data into PostgreSQL...")

    try:
        import psycopg2
        import pandas as pd

        # Database connection
        conn = psycopg2.connect(
            host="localhost",
            port=5432,
            database="dabstep",
            user="postgres",
            password="postgres"
        )
        conn.autocommit = False
        cursor = conn.cursor()

        data_dir = Path("data")

        # Import CSV files
        csv_files = {
            "merchant_category_codes.csv": "COPY merchant_category_codes(mcc_code, category_name, category_description) FROM STDIN WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '\"', ESCAPE '\"')",
            "acquirer_countries.csv": "COPY acquirer_countries(country_code, country_name, currency_code, region) FROM STDIN WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '\"', ESCAPE '\"')"
        }

        for csv_file, copy_cmd in csv_files.items():
            csv_path = data_dir / csv_file
            if csv_path.exists():
                print(f"  Importing {csv_file}...")
                with open(csv_path, 'r') as f:
                    cursor.copy_expert(copy_cmd, f)
                print(f"  ✅ Imported {csv_file}")

        # Import payments (chunked for large file)
        payments_file = data_dir / "payments.csv"
        if payments_file.exists():
            print("  Importing payments.csv (this may take a while)...")
            chunk_size = 10000

            copy_cmd = """
            COPY payments(
                payment_id, merchant_id, acquirer_country_code, transaction_amount,
                transaction_currency, settlement_amount, settlement_currency, exchange_rate,
                transaction_date, settlement_date, payment_method, card_brand, card_country,
                authorization_code, response_code, transaction_type, is_chargeback, is_refund,
                fees_amount, interchange_fee, scheme_fee, processing_fee, merchant_fee,
                net_amount, batch_id, terminal_id, transaction_status, risk_score, metadata
            ) FROM STDIN WITH (
                FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL 'NULL'
            )"""

            total_rows = 0
            for chunk in pd.read_csv(payments_file, chunksize=chunk_size):
                # Convert chunk to CSV string
                csv_string = chunk.to_csv(index=False, quoting=1, escapechar='\\')
                cursor.copy_expert(copy_cmd, iter([csv_string]))
                total_rows += len(chunk)
                print(f"  Processed {total_rows} payment rows...")

            print(f"  ✅ Imported {total_rows} payment records")

        # Update timestamps
        cursor.execute("""
        UPDATE merchant_category_codes SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL;
        UPDATE acquirer_countries SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL;
        UPDATE merchants SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL;
        UPDATE payments SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL;
        VACUUM ANALYZE;
        """)

        conn.commit()
        print("✅ Data import completed successfully")

        # Show summary
        cursor.execute("SELECT COUNT(*) FROM payments")
        payment_count = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(*) FROM merchants")
        merchant_count = cursor.fetchone()[0]

        print("\n📊 Database Summary:")
        print(f"  Payments: {payment_count} rows")
        print(f"  Merchants: {merchant_count} rows")

    except ImportError:
        print("❌ Python dependencies not available. Install with: pip install pandas psycopg2-binary")
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        if 'conn' in locals():
            conn.rollback()
    except Exception as e:
        print(f"❌ Import error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

def main():
    """Main quick start function."""
    print("🚀 DABstep Database Quick Start")
    print("="*40)

    # Check Docker availability
    if not check_docker():
        print("❌ Docker is not available or not running.")
        print("Please start Docker Desktop and try again.")
        show_manual_instructions()
        return

    print("✅ Docker is available")

    # Check if services are running
    if not check_postgres_running():
        print("📦 PostgreSQL container not running, starting services...")
        if not start_docker_services():
            show_manual_instructions()
            return
    else:
        print("✅ PostgreSQL container is running")

    # Wait a moment for services to be ready
    print("⏳ Waiting for PostgreSQL to be ready...")
    import time
    time.sleep(5)

    # Create schema
    create_schema_sql()

    # Download data
    if download_dataset():
        # Import data
        import_data()
    else:
        print("⚠️  Data download failed. You can try again later.")

    print("\n🎉 Quick start setup completed!")
    print("\n🔍 Test your database:")
    print("docker exec -it postgres-dabstep psql -U postgres -d dabstep -c \"SELECT COUNT(*) FROM payments;\"")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "download":
            download_dataset()
        elif sys.argv[1] == "import":
            import_data()
        elif sys.argv[1] == "schema":
            create_schema_sql()
        else:
            print("Usage: python3 quick_start.py [download|import|schema]")
    else:
        main()
