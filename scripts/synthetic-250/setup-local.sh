#!/bin/bash
# ============================================================================
# Synthetic 250-Table Database Setup Script
# Sets up a 250-table synthetic database in PostgreSQL locally
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Synthetic 250-Table Database Setup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Configuration with defaults
DB_NAME="${POSTGRES_DB:-synthetic_250}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_PASSWORD="${POSTGRES_PASSWORD:-}"
SCHEMA_NAME="${SCHEMA_NAME:-synthetic}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMP_DIR="$PROJECT_ROOT/temp/synthetic-250"
SQL_FILE="$TEMP_DIR/synthetic_250_postgres.sql"

# Print configuration
echo -e "${YELLOW}Configuration:${NC}"
echo "  Database: $DB_NAME"
echo "  User:     $DB_USER"
echo "  Host:     $DB_HOST:$DB_PORT"
echo "  Schema:   $SCHEMA_NAME"
echo ""

# Check for psql
if ! command -v psql &> /dev/null; then
    echo -e "${RED}❌ Error: psql not found${NC}"
    echo ""
    echo "Please install PostgreSQL client tools:"
    echo "  macOS:  brew install postgresql"
    echo "  Ubuntu: sudo apt-get install postgresql-client"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ psql found${NC}"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Error: python3 not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ python3 found${NC}"
echo ""

# Step 1: Generate SQL schema
echo -e "${YELLOW}Step 1: Generating SQL schema...${NC}"
cd "$SCRIPT_DIR"
python3 main.py --output-dir "$TEMP_DIR" --schema "$SCHEMA_NAME"
echo ""

# Check if SQL file was generated
if [ ! -f "$SQL_FILE" ]; then
    echo -e "${RED}❌ Error: SQL file not generated at $SQL_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SQL file generated: $SQL_FILE${NC}"
echo ""

# Step 2: Check PostgreSQL connection
echo -e "${YELLOW}Step 2: Checking PostgreSQL connection...${NC}"

# Build connection string for psql
PGPASSWORD_ENV=""
if [ -n "$DB_PASSWORD" ]; then
    PGPASSWORD_ENV="PGPASSWORD=$DB_PASSWORD"
fi

# Test connection to postgres database
if ! $PGPASSWORD_ENV psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to PostgreSQL${NC}"
    echo ""
    echo "Please check:"
    echo "  1. PostgreSQL is running"
    echo "  2. Connection details are correct"
    echo ""
    echo "You can set environment variables:"
    echo "  export POSTGRES_HOST=localhost"
    echo "  export POSTGRES_PORT=5432"
    echo "  export POSTGRES_USER=postgres"
    echo "  export POSTGRES_PASSWORD=yourpassword"
    echo "  export POSTGRES_DB=synthetic_250"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL connection successful${NC}"
echo ""

# Step 3: Create database
echo -e "${YELLOW}Step 3: Creating database '$DB_NAME'...${NC}"

# Check if database exists
DB_EXISTS=$($PGPASSWORD_ENV psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")

if [ "$DB_EXISTS" = "1" ]; then
    echo -e "${YELLOW}⚠ Database '$DB_NAME' already exists${NC}"
    echo ""
    read -p "Do you want to drop and recreate it? (y/N): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Dropping existing database..."
        $PGPASSWORD_ENV psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"
        echo "Creating fresh database..."
        $PGPASSWORD_ENV psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
        echo -e "${GREEN}✓ Database recreated${NC}"
    else
        echo "Using existing database..."
    fi
else
    $PGPASSWORD_ENV psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
    echo -e "${GREEN}✓ Database created${NC}"
fi
echo ""

# Step 4: Import schema
echo -e "${YELLOW}Step 4: Importing schema (this may take a moment)...${NC}"
$PGPASSWORD_ENV psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SQL_FILE"
echo -e "${GREEN}✓ Schema imported${NC}"
echo ""

# Step 5: Verify tables
echo -e "${YELLOW}Step 5: Verifying tables...${NC}"
TABLE_COUNT=$($PGPASSWORD_ENV psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$SCHEMA_NAME';")
echo -e "${GREEN}✓ Found $TABLE_COUNT tables in '$SCHEMA_NAME' schema${NC}"
echo ""

# Print domain breakdown
echo -e "${BLUE}Table Counts by Prefix:${NC}"
$PGPASSWORD_ENV psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    CASE 
        WHEN table_name LIKE 'employee%' OR table_name LIKE 'department%' OR table_name LIKE 'salary%' 
             OR table_name LIKE 'job%' OR table_name LIKE 'benefits%' OR table_name LIKE 'time_%'
             OR table_name LIKE 'training%' OR table_name LIKE 'skill%' OR table_name LIKE 'interview%'
             OR table_name LIKE 'performance%' OR table_name LIKE 'emergency%' OR table_name LIKE 'expense%'
             OR table_name LIKE 'org_%' OR table_name = 'office_locations'
        THEN 'HR'
        WHEN table_name LIKE 'chart_%' OR table_name LIKE 'fiscal%' OR table_name LIKE 'journal%' 
             OR table_name LIKE 'vendor%' OR table_name LIKE 'invoice%' OR table_name LIKE 'bank%'
             OR table_name LIKE 'budget%' OR table_name LIKE 'fixed_%' OR table_name LIKE 'depreciation%'
             OR table_name LIKE 'tax_%' OR table_name LIKE 'currency%' OR table_name LIKE 'exchange%'
             OR table_name LIKE 'cost_%' OR table_name LIKE 'projects_fin%' OR table_name LIKE 'project_cost%'
             OR table_name LIKE 'audit%' OR table_name LIKE 'financial%' OR table_name LIKE 'intercompany%'
             OR table_name LIKE 'payment_term%' OR table_name LIKE 'credit_memo%' OR table_name LIKE 'recurring%'
             OR table_name LIKE 'payment_alloc%'
        THEN 'Finance'
        WHEN table_name LIKE 'customer%' OR table_name LIKE 'product%' OR table_name LIKE 'brand%'
             OR table_name LIKE 'cart%' OR table_name LIKE 'wishlist%' OR table_name LIKE 'order%'
             OR table_name LIKE 'ship%' OR table_name LIKE 'coupon%' OR table_name LIKE 'gift%'
             OR table_name LIKE 'payment_trans%' OR table_name LIKE 'promo%' OR table_name LIKE 'related%'
             OR table_name LIKE 'bundle%' OR table_name LIKE 'return%' OR table_name LIKE 'shopping%'
        THEN 'E-Commerce'
        WHEN table_name LIKE 'warehouse%' OR table_name LIKE 'storage%' OR table_name LIKE 'inventory%'
             OR table_name LIKE 'supplier%' OR table_name LIKE 'purchase%' OR table_name LIKE 'receiving%'
             OR table_name LIKE 'stock%' OR table_name LIKE 'pick%' OR table_name LIKE 'pack%'
             OR table_name LIKE 'abc_%' OR table_name LIKE 'reorder%' OR table_name LIKE 'adjustment%'
        THEN 'Inventory'
        WHEN table_name LIKE 'account%' OR table_name LIKE 'contact%' OR table_name LIKE 'lead%'
             OR table_name LIKE 'opportunit%' OR table_name LIKE 'quote%' OR table_name LIKE 'sales_%'
             OR table_name LIKE 'activit%' OR table_name LIKE 'task%' OR table_name LIKE 'event%'
             OR table_name LIKE 'call%' OR table_name LIKE 'campaign%' OR table_name LIKE 'territor%'
             OR table_name LIKE 'team%' OR table_name LIKE 'forecast%' OR table_name LIKE 'price_%'
             OR table_name LIKE 'contract%' OR table_name LIKE 'case%' OR table_name LIKE 'solution%'
        THEN 'CRM'
        WHEN table_name LIKE 'patient%' OR table_name LIKE 'physician%' OR table_name LIKE 'medical%'
             OR table_name LIKE 'appointment%' OR table_name LIKE 'encounter%' OR table_name LIKE 'diagnos%'
             OR table_name LIKE 'prescription%' OR table_name LIKE 'medication%' OR table_name LIKE 'allerg%'
             OR table_name LIKE 'lab_%' OR table_name LIKE 'vital%' OR table_name LIKE 'immuniz%'
             OR table_name LIKE 'insurance%' OR table_name LIKE 'claim%' OR table_name LIKE 'procedure%'
             OR table_name LIKE 'referral%' OR table_name LIKE 'family_%' OR table_name LIKE 'care_%'
             OR table_name LIKE 'consent%'
        THEN 'Healthcare'
        WHEN table_name LIKE 'pm_%' OR table_name LIKE 'project_%' OR table_name LIKE 'milestone%'
             OR table_name LIKE 'sprint%' OR table_name LIKE 'resource_%' OR table_name LIKE 'change_%'
             OR table_name LIKE 'lesson%' OR table_name LIKE 'time_entr%' OR table_name = 'task_dependencies'
             OR table_name = 'task_assignments'
        THEN 'Projects'
        WHEN table_name LIKE 'marketing%' OR table_name LIKE 'email_%' OR table_name LIKE 'mailing%'
             OR table_name LIKE 'list_%' OR table_name LIKE 'landing%' OR table_name LIKE 'web_%'
             OR table_name LIKE 'social%' OR table_name LIKE 'ad_%' OR table_name LIKE 'keyword%'
             OR table_name LIKE 'content%' OR table_name LIKE 'utm%'
        THEN 'Marketing'
        WHEN table_name LIKE 'it_%' OR table_name LIKE 'server%' OR table_name LIKE 'application%'
             OR table_name LIKE 'app_%' OR table_name LIKE 'network%' OR table_name LIKE 'change_ticket%'
             OR table_name LIKE 'service_%' OR table_name LIKE 'software%' OR table_name LIKE 'backup%'
             OR table_name LIKE 'monitor%' OR table_name LIKE 'maintenance%' OR table_name LIKE 'deploy%'
             OR table_name LIKE 'ssl_%'
        THEN 'IT/Infra'
        WHEN table_name LIKE 'student%' OR table_name LIKE 'instructor%' OR table_name LIKE 'academic%'
             OR table_name LIKE 'program%' OR table_name LIKE 'course%' OR table_name LIKE 'enrollment%'
             OR table_name LIKE 'classroom%' OR table_name LIKE 'assignment%' OR table_name LIKE 'submission%'
             OR table_name LIKE 'attendance%' OR table_name LIKE 'tuition%' OR table_name LIKE 'financial_aid%'
             OR table_name LIKE 'degree_%' OR table_name LIKE 'transcript%' OR table_name LIKE 'waitlist%'
        THEN 'Education'
        ELSE 'Other'
    END as domain,
    COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = '$SCHEMA_NAME'
GROUP BY domain
ORDER BY table_count DESC;
"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  ✅ Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Connection Details:"
echo "  Host:     $DB_HOST"
echo "  Port:     $DB_PORT"
echo "  Database: $DB_NAME"
echo "  Schema:   $SCHEMA_NAME"
echo "  User:     $DB_USER"
echo ""
echo "Connection String:"
echo "  postgresql://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""
echo "Next Steps:"
echo "  1. Update TribalAgent/config/databases.yaml:"
echo ""
echo "     - name: synthetic_250"
echo "       type: postgres"
echo "       connection_string: \"postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@\${POSTGRES_HOST}:\${POSTGRES_PORT}/$DB_NAME\""
echo "       schemas:"
echo "         - $SCHEMA_NAME"
echo "       exclude_tables: []"
echo ""
echo "  2. Run: npm run plan (from TribalAgent directory)"
echo ""

