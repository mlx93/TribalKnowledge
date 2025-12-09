#!/usr/bin/env python3
"""
Script to import DABstep dataset into PostgreSQL.
"""

import os
import json
import csv
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from pathlib import Path
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class DABstepImporter:
    def __init__(self, db_config=None):
        if db_config is None:
            # When running inside container, use the container's internal connection
            db_config = {
                'host': os.environ.get('DB_HOST', 'localhost'),
                'port': int(os.environ.get('DB_PORT', 5432)),
                'database': os.environ.get('DB_NAME', 'dabstep'),
                'user': os.environ.get('DB_USER', 'postgres'),
                'password': os.environ.get('DB_PASSWORD', 'postgres')
            }

        self.db_config = db_config
        self.conn = None
        self.data_dir = Path("data")

    def connect(self):
        """Establish database connection."""
        try:
            self.conn = psycopg2.connect(**self.db_config)
            self.conn.autocommit = False  # We'll manage transactions manually
            logger.info("Connected to PostgreSQL database")
        except psycopg2.Error as e:
            logger.error(f"Failed to connect to database: {e}")
            raise

    def disconnect(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()
            logger.info("Disconnected from database")

    def import_merchant_category_codes(self):
        """Import merchant category codes from CSV."""
        filepath = self.data_dir / "merchant_category_codes.csv"
        if not filepath.exists():
            logger.warning(f"File {filepath} not found, skipping...")
            return

        logger.info("Importing merchant category codes...")

        df = pd.read_csv(filepath)
        logger.info(f"Found {len(df)} merchant category codes")

        with self.conn.cursor() as cursor:
            # Clear existing data
            cursor.execute("TRUNCATE TABLE merchant_category_codes CASCADE")

            # Insert data (skip the index column)
            values = []
            for _, row in df.iterrows():
                values.append((
                    str(row.iloc[1]),  # mcc column
                    str(row.iloc[2])   # description column
                ))

            execute_values(cursor,
                "INSERT INTO merchant_category_codes (mcc_code, category_description) VALUES %s",
                values)

        self.conn.commit()
        logger.info("Merchant category codes imported successfully")

    def import_acquirer_countries(self):
        """Import acquirer countries from CSV."""
        filepath = self.data_dir / "acquirer_countries.csv"
        if not filepath.exists():
            logger.warning(f"File {filepath} not found, skipping...")
            return

        logger.info("Importing acquirer countries...")

        df = pd.read_csv(filepath)
        logger.info(f"Found {len(df)} acquirer countries")

        with self.conn.cursor() as cursor:
            cursor.execute("TRUNCATE TABLE acquirer_countries CASCADE")

            values = []
            for _, row in df.iterrows():
                values.append((
                    str(row.iloc[2])  # country_code column
                ))

            execute_values(cursor,
                "INSERT INTO acquirer_countries (country_code) VALUES %s",
                values)

        self.conn.commit()
        logger.info("Acquirer countries imported successfully")

    def import_payments(self):
        """Import payments from CSV with proper column mapping."""
        filepath = self.data_dir / "payments.csv"
        if not filepath.exists():
            logger.warning(f"File {filepath} not found, skipping...")
            return

        logger.info("Importing payments (this may take a while)...")

        # Read the CSV with proper column names
        df = pd.read_csv(filepath, nrows=1000)  # First test with small sample

        # Map CSV columns to our table columns
        column_mapping = {
            'psp_reference': 'payment_id',
            'merchant': 'merchant_id',
            'card_scheme': 'card_brand',
            'eur_amount': 'transaction_amount',
            'ip_country': 'ip_country',
            'issuing_country': 'issuing_country',
            'device_type': 'device_type',
            'shopper_interaction': 'shopper_interaction',
            'card_bin': 'card_bin',
            'has_fraudulent_dispute': 'is_fraudulent',
            'is_refused_by_adyen': 'is_refused',
            'aci': 'aci',
            'acquirer_country': 'acquirer_country_code'
        }

        # Create transaction date from year/day/hour/minute columns
        def create_transaction_date(row):
            try:
                year = int(row.get('year', 2023))
                day_of_year = int(row.get('day_of_year', 1))
                hour = int(row.get('hour_of_day', 0))
                minute = int(row.get('minute_of_hour', 0))

                # Create date from year and day of year
                base_date = datetime(year, 1, 1)
                transaction_date = base_date.replace(hour=hour, minute=minute)
                # Add days (day_of_year is 1-indexed)
                transaction_date = transaction_date.replace(day=1)  # Reset to first of month
                # This is approximate - would need more complex date logic for exact day

                return transaction_date
            except:
                return None

        logger.info(f"Sample data columns: {list(df.columns)}")
        logger.info(f"First row sample: {df.iloc[0].to_dict()}")

        # For now, let's just import a few key columns to test
        with self.conn.cursor() as cursor:
            cursor.execute("TRUNCATE TABLE payments CASCADE")

            # Simple import for testing
            values = []
            for _, row in df.iterrows():
                values.append((
                    str(row.get('psp_reference', '')),
                    str(row.get('merchant', '')),
                    str(row.get('card_scheme', '')),
                    row.get('eur_amount'),
                    str(row.get('issuing_country', '')),
                    str(row.get('device_type', '')),
                    str(row.get('shopper_interaction', '')),
                    str(row.get('card_bin', '')),
                    bool(row.get('has_fraudulent_dispute', False)),
                    bool(row.get('is_refused_by_adyen', False)),
                    str(row.get('aci', '')),
                    str(row.get('acquirer_country', ''))
                ))

            execute_values(cursor,
                """INSERT INTO payments
                   (payment_id, merchant_id, card_brand, transaction_amount,
                    issuing_country, device_type, shopper_interaction, card_bin,
                    is_fraudulent, is_refused, aci, acquirer_country_code)
                   VALUES %s""",
                values)

        self.conn.commit()
        logger.info(f"Payments imported successfully: {len(values)} sample rows")

    def run_all_imports(self):
        """Run all import operations."""
        try:
            self.connect()

            # Import reference data first
            self.import_merchant_category_codes()
            self.import_acquirer_countries()

            # Import main payments data
            self.import_payments()

            # Final optimizations
            with self.conn.cursor() as cursor:
                logger.info("Running final optimizations...")
                cursor.execute("VACUUM ANALYZE")

            self.conn.commit()
            logger.info("All data imported successfully!")

        except Exception as e:
            logger.error(f"Import failed: {e}")
            if self.conn:
                self.conn.rollback()
            raise
        finally:
            self.disconnect()

def main():
    """Main import function."""
    importer = DABstepImporter()
    importer.run_all_imports()

if __name__ == "__main__":
    main()
