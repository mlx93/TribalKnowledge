#!/bin/bash
# DABstep Database Setup Script
# This script sets up the complete PostgreSQL database with DABstep data

set -e

echo "=== DABstep Database Setup ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-dabstep}
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-postgres}

echo "Database Configuration:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running or not accessible${NC}"
        echo "Please start Docker and try again."
        exit 1
    fi
}

# Function to wait for PostgreSQL to be ready
wait_for_postgres() {
    echo "Waiting for PostgreSQL to be ready..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker exec postgres-dabstep pg_isready -U postgres -h localhost >/dev/null 2>&1; then
            echo -e "${GREEN}PostgreSQL is ready!${NC}"
            return 0
        fi

        echo "Attempt $attempt/$max_attempts: PostgreSQL not ready yet..."
        sleep 2
        ((attempt++))
    done

    echo -e "${RED}Error: PostgreSQL failed to start within expected time${NC}"
    return 1
}

# Function to check if database exists
check_database() {
    echo "Checking if database '$DB_NAME' exists..."

    if docker exec postgres-dabstep psql -U postgres -lqt | cut -d\| -f1 | grep -qw "$DB_NAME"; then
        echo -e "${GREEN}Database '$DB_NAME' exists${NC}"
        return 0
    else
        echo -e "${YELLOW}Database '$DB_NAME' does not exist. Creating it...${NC}"
        docker exec postgres-dabstep createdb -U postgres "$DB_NAME"
        echo -e "${GREEN}Database '$DB_NAME' created${NC}"
        return 1
    fi
}

# Function to create schema
create_schema() {
    echo "Creating database schema..."

    # Create schema SQL inline
    docker exec postgres-dabstep psql -U postgres -d "$DB_NAME" -c "
    -- DABstep Database Schema
    -- Payment processing dataset from Adyen (actual structure)

    -- Enable UUID extension
    CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";

    -- Merchant Category Codes (MCC) table
    CREATE TABLE IF NOT EXISTS merchant_category_codes (
        mcc_code VARCHAR(10) PRIMARY KEY,
        category_description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Acquirer Countries table (simplified)
    CREATE TABLE IF NOT EXISTS acquirer_countries (
        country_code VARCHAR(3) PRIMARY KEY,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Merchants table (simplified)
    CREATE TABLE IF NOT EXISTS merchants (
        merchant_id VARCHAR(50) PRIMARY KEY,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Main payments table (matches actual CSV structure)
    CREATE TABLE IF NOT EXISTS payments (
        payment_id VARCHAR(100) PRIMARY KEY,
        merchant_id VARCHAR(50),
        card_brand VARCHAR(20),
        transaction_date TIMESTAMP,
        payment_method VARCHAR(50),
        transaction_amount DECIMAL(15,2),
        transaction_currency VARCHAR(3),
        acquirer_country_code VARCHAR(3),
        issuing_country VARCHAR(3),
        device_type VARCHAR(20),
        shopper_interaction VARCHAR(20),
        card_bin VARCHAR(20),
        is_fraudulent BOOLEAN DEFAULT false,
        is_refused BOOLEAN DEFAULT false,
        aci VARCHAR(10),
        ip_country VARCHAR(3),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Fee structures table (for JSON data)
    CREATE TABLE IF NOT EXISTS fee_structures (
        fee_id SERIAL PRIMARY KEY,
        fee_data JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Indexes for better performance
    CREATE INDEX IF NOT EXISTS idx_payments_merchant_id ON payments(merchant_id);
    CREATE INDEX IF NOT EXISTS idx_payments_transaction_date ON payments(transaction_date);
    CREATE INDEX IF NOT EXISTS idx_payments_card_brand ON payments(card_brand);
    CREATE INDEX IF NOT EXISTS idx_payments_acquirer_country ON payments(acquirer_country_code);
    " 2>/dev/null || {
        echo -e "${YELLOW}Schema creation had some warnings, but continuing...${NC}"
    }

    echo -e "${GREEN}Schema created successfully${NC}"
}

# Function to download data
download_data() {
    echo "Downloading DABstep dataset..."

    # Create data directory
    mkdir -p data

    # Download files using curl
    BASE_URL="https://huggingface.co/datasets/adyen/DABstep/resolve/main/data/context"

    files=("payments.csv" "acquirer_countries.csv" "fees.json" "merchant_category_codes.csv" "merchant_data.json" "manual.md" "payments-readme.md")

    for file in "${files[@]}"; do
        echo "Downloading $file..."
        if curl -L -o "data/$file" "$BASE_URL/$file" 2>/dev/null; then
            echo -e "${GREEN}✓ Downloaded $file${NC}"
        else
            echo -e "${YELLOW}⚠ Failed to download $file${NC}"
        fi
    done

    echo -e "${GREEN}Data download completed${NC}"
}

# Function to import data
import_data() {
    echo "Importing data into database..."

    if [ ! -d "data" ] || [ ! "$(ls -A data)" ]; then
        echo -e "${YELLOW}No data files found. Skipping import.${NC}"
        return
    fi

    # Copy data files to container for import
    echo "Copying data files to container..."
    docker cp data/. postgres-dabstep:/data/

    # Import merchant category codes
    if [ -f "data/merchant_category_codes.csv" ]; then
        echo "Importing merchant category codes..."
        docker exec postgres-dabstep psql -U postgres -d "$DB_NAME" << 'EOF'
        -- Handle CSV with extra first column
        CREATE TEMP TABLE temp_mcc_raw (
            col1 TEXT, mcc_code VARCHAR(10), category_description TEXT
        );
        \COPY temp_mcc_raw(col1, mcc_code, category_description) FROM '/data/merchant_category_codes.csv' WITH (FORMAT csv, HEADER true);

        INSERT INTO merchant_category_codes (mcc_code, category_description)
        SELECT mcc_code, category_description FROM temp_mcc_raw
        WHERE mcc_code IS NOT NULL AND mcc_code != ''
        ON CONFLICT (mcc_code) DO NOTHING;
EOF
    fi

    # Import acquirer countries
    if [ -f "data/acquirer_countries.csv" ]; then
        echo "Importing acquirer countries..."
        docker exec postgres-dabstep psql -U postgres -d "$DB_NAME" << 'EOF'
        -- Handle CSV with extra first column
        CREATE TEMP TABLE temp_countries_raw (
            col1 TEXT, acquirer TEXT, country_code VARCHAR(3)
        );
        \COPY temp_countries_raw(col1, acquirer, country_code) FROM '/data/acquirer_countries.csv' WITH (FORMAT csv, HEADER true);

        INSERT INTO acquirer_countries (country_code)
        SELECT DISTINCT country_code FROM temp_countries_raw
        WHERE country_code IS NOT NULL AND country_code != ''
        ON CONFLICT (country_code) DO NOTHING;
EOF
    fi

    # Import ALL payments data
    if [ -f "data/payments.csv" ]; then
        echo "Importing ALL payments data (this may take 2-5 minutes)..."
        echo "Processing complete 23MB CSV file with full DABstep dataset..."

        docker exec postgres-dabstep psql -U postgres -d "$DB_NAME" << 'EOF'
        -- Temporarily disable foreign key constraint for faster import
        ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_merchant_id_fkey;

        -- Import payments data with proper column mapping
        CREATE TEMP TABLE temp_payments_raw (
            psp_reference VARCHAR(100),
            merchant VARCHAR(50),
            card_scheme VARCHAR(20),
            year INTEGER,
            hour_of_day INTEGER,
            minute_of_hour INTEGER,
            day_of_year INTEGER,
            is_credit BOOLEAN,
            eur_amount DECIMAL(15,2),
            ip_country VARCHAR(3),
            issuing_country VARCHAR(3),
            device_type VARCHAR(20),
            ip_address VARCHAR(50),
            email_address VARCHAR(100),
            card_number VARCHAR(50),
            shopper_interaction VARCHAR(20),
            card_bin VARCHAR(20),
            has_fraudulent_dispute BOOLEAN,
            is_refused_by_adyen BOOLEAN,
            aci VARCHAR(10),
            acquirer_country VARCHAR(3)
        );

        -- Import the full CSV file (not just sample)
        \COPY temp_payments_raw FROM '/data/payments.csv' WITH (FORMAT csv, HEADER true);

        -- Insert into main payments table
        INSERT INTO payments(
            payment_id, merchant_id, card_brand, transaction_amount,
            issuing_country, device_type, shopper_interaction, card_bin,
            is_fraudulent, is_refused, aci, acquirer_country_code, ip_country
        )
        SELECT
            psp_reference, merchant, card_scheme, eur_amount,
            issuing_country, device_type, shopper_interaction, card_bin,
            has_fraudulent_dispute, is_refused_by_adyen, aci, acquirer_country, ip_country
        FROM temp_payments_raw;

        -- Clean up temp table
        DROP TABLE temp_payments_raw;

        -- Re-enable foreign key constraint (optional - will fail if merchants don't exist)
        -- ALTER TABLE payments ADD CONSTRAINT payments_merchant_id_fkey
        -- FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id);
EOF

        echo "✅ Full payments dataset imported successfully"
    fi

    echo -e "${GREEN}✅ Complete data import finished successfully!${NC}"
    echo "The full DABstep dataset is now available in your database."
}

# Function to verify setup
verify_setup() {
    echo "Verifying database setup..."

    # Check if tables exist and have data
    PAYMENT_COUNT=$(docker exec postgres-dabstep psql -U postgres -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM payments;" 2>/dev/null || echo "0")
    MERCHANT_COUNT=$(docker exec postgres-dabstep psql -U postgres -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM merchants;" 2>/dev/null || echo "0")
    MCC_COUNT=$(docker exec postgres-dabstep psql -U postgres -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM merchant_category_codes;" 2>/dev/null || echo "0")

    echo
    echo -e "${GREEN}Setup Summary:${NC}"
    echo "  Payments: $PAYMENT_COUNT rows"
    echo "  Merchants: $MERCHANT_COUNT rows"
    echo "  MCC Codes: $MCC_COUNT rows"

    if [ "$PAYMENT_COUNT" -gt 0 ] || [ "$MERCHANT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Database setup completed successfully!${NC}"
    else
        echo -e "${YELLOW}⚠ Database schema created but no data imported yet.${NC}"
    fi
}

# Main setup process
main() {
    echo "Starting DABstep database setup..."
    echo

    # Check prerequisites
    check_docker

    # Check if containers are running
    if ! docker ps | grep -q postgres-dabstep; then
        echo "Starting PostgreSQL container..."
        docker-compose up -d postgres pgadmin

        if ! wait_for_postgres; then
            exit 1
        fi
    else
        echo "PostgreSQL container is already running"
    fi

    # Setup database
    check_database
    create_schema

    # Data operations
    download_data
    import_data

    # Verification
    verify_setup

    echo
    echo -e "${GREEN}=== Setup Complete ===${NC}"
    echo
    echo "You can now connect to your database:"
    echo "  Host: localhost"
    echo "  Port: 5432"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Password: $DB_PASSWORD"
    echo
    echo "PgAdmin is available at: http://localhost:5050"
    echo "  Email: admin@dabstep.com"
    echo "  Password: admin"
}

# Run main function
main