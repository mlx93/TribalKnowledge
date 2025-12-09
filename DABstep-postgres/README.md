# DABstep PostgreSQL Database - Quick Start

## 🚀 Quick Start (3 Commands)

```bash
# 1. Start database services
docker-compose up -d

# 2. Install Python dependencies
pip install requests pandas psycopg2-binary

# 3. Run complete setup
./setup_database.sh
```

## 📋 Manual Setup (if Docker isn't available)

### 1. Start Docker Services
```bash
cd DABstep-postgres-2
docker-compose up -d
```

### 2. Wait for PostgreSQL to be Ready
```bash
# Wait about 30 seconds, then check:
docker exec postgres-dabstep pg_isready -U postgres
```

### 3. Download Dataset
```bash
python3 quick_start.py download
```

### 4. Create Database Schema
```bash
# Connect to PostgreSQL
docker exec -it postgres-dabstep psql -U postgres -d dabstep

# Run the schema SQL (copy from schema.sql file)
\i schema.sql
```

### 5. Import Data
```bash
python3 quick_start.py import
```

## 🔍 Access Your Database

### PostgreSQL Direct Connection
- **Host**: localhost
- **Port**: 5432
- **Database**: dabstep
- **User**: postgres
- **Password**: postgres

### PgAdmin Web Interface
- **URL**: http://localhost:5050
- **Email**: admin@dabstep.com
- **Password**: admin

## 📊 Sample Queries

### Total Transaction Volume
```sql
SELECT
    COUNT(*) as total_payments,
    SUM(transaction_amount) as total_volume,
    AVG(transaction_amount) as avg_transaction
FROM payments;
```

### Transactions by Country
```sql
SELECT
    ac.country_name,
    COUNT(*) as transaction_count,
    SUM(p.transaction_amount) as total_volume
FROM payments p
JOIN acquirer_countries ac ON p.acquirer_country_code = ac.country_code
GROUP BY ac.country_name
ORDER BY total_volume DESC
LIMIT 10;
```

### Merchant Performance
```sql
SELECT
    m.merchant_name,
    COUNT(p.*) as transaction_count,
    SUM(p.transaction_amount) as total_volume,
    AVG(p.fees_amount) as avg_fees
FROM merchants m
LEFT JOIN payments p ON m.merchant_id = p.merchant_id
GROUP BY m.merchant_id, m.merchant_name
ORDER BY total_volume DESC
LIMIT 10;
```

## 🗂️ Database Schema

### Core Tables
- **`payments`** - Main transactions table (23.6MB of data)
- **`merchants`** - Merchant profiles and registration data
- **`merchant_category_codes`** - MCC codes with descriptions
- **`acquirer_countries`** - Country information for acquirers
- **`fee_structures`** - Dynamic fee configurations

## 🛠️ Available Scripts

- **`./setup_database.sh`** - Complete automated setup
- **`python3 quick_start.py`** - Interactive setup script
- **`python3 quick_start.py download`** - Download dataset only
- **`python3 quick_start.py import`** - Import data only
- **`python3 quick_start.py schema`** - Create schema SQL file

## 📁 Project Files

```
DABstep-postgres-2/
├── docker-compose.yml          # Docker services configuration
├── setup_database.sh           # Complete setup script
├── quick_start.py              # Interactive setup script
├── requirements.txt            # Python dependencies
├── schema.sql                  # Database schema (generated)
├── data/                       # Dataset files (downloaded)
├── README.md                   # This file
└── init-db/                    # Database initialization
```

## 🔧 Troubleshooting

### Docker Issues
```bash
# Check Docker status
docker info

# View container logs
docker-compose logs postgres

# Restart services
docker-compose restart
```

### Database Connection Issues
```bash
# Test PostgreSQL connection
docker exec postgres-dabstep pg_isready -U postgres

# Connect to database
docker exec -it postgres-dabstep psql -U postgres -d dabstep
```

### Data Import Issues
```bash
# Check data files
ls -la data/

# Verify file contents
head -5 data/payments.csv

# Re-run import
python3 quick_start.py import
```

## 📚 Dataset Information

The DABstep dataset contains real payment processing data from Adyen including:
- Transaction records with amounts, currencies, and fees
- Merchant information and category codes
- Country and regional data
- Fee structures and interchange rates

**Source**: [Hugging Face - Adyen DABstep Dataset](https://huggingface.co/datasets/adyen/DABstep)