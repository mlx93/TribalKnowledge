#!/bin/bash
# Test script to verify the complete DABstep setup workflow

echo "🧪 Testing DABstep PostgreSQL Setup"
echo "=================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test 1: Check if files exist
echo -e "\n📁 Checking required files..."
files=("docker-compose.yml" "setup_database.sh" "requirements.txt" "README.md")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "✅ $file found"
    else
        echo -e "❌ $file missing"
        exit 1
    fi
done

# Test 2: Check if data directory exists and has files
echo -e "\n📊 Checking data files..."
if [ -d "data" ]; then
    echo "✅ data/ directory exists"
    csv_count=$(ls data/*.csv 2>/dev/null | wc -l)
    json_count=$(ls data/*.json 2>/dev/null | wc -l)
    echo "✅ Found $csv_count CSV files and $json_count JSON files"
else
    echo -e "❌ data/ directory missing"
    exit 1
fi

# Test 3: Check Docker availability (without starting)
echo -e "\n🐳 Checking Docker availability..."
if command -v docker &> /dev/null; then
    echo "✅ Docker command found"
    if docker info &> /dev/null; then
        echo "✅ Docker daemon is running"
        DOCKER_READY=true
    else
        echo -e "⚠️  Docker daemon not running (start Docker Desktop first)"
        DOCKER_READY=false
    fi
else
    echo -e "❌ Docker not installed"
    exit 1
fi

# Test 4: Check Python dependencies
echo -e "\n🐍 Checking Python dependencies..."
python3 -c "
try:
    import pandas
    import psycopg2
    import requests
    print('✅ All Python dependencies available')
except ImportError as e:
    print(f'❌ Missing dependency: {e}')
    exit(1)
"

# Test 5: Show expected workflow
echo -e "\n🚀 Expected Setup Workflow:"
echo "1. docker-compose up -d                    # Start PostgreSQL + PgAdmin"
echo "2. pip install -r requirements.txt         # Install Python deps (optional)"
echo "3. ./setup_database.sh                     # Run complete setup"
echo ""
echo "Expected Results:"
echo "• PostgreSQL: localhost:5432 (user: postgres, pass: postgres)"
echo "• PgAdmin: http://localhost:5050 (admin@dabstep.com / admin)"
echo "• Database: dabstep with FULL payment dataset (100,000+ records)"
echo ""

if [ "$DOCKER_READY" = true ]; then
    echo -e "${GREEN}✅ Setup ready to run!${NC}"
    echo "Run the three commands above to complete the setup."
else
    echo -e "${YELLOW}⚠️  Docker not running${NC}"
    echo "Start Docker Desktop, then run the setup commands."
fi

echo -e "\n${GREEN}🎉 DABstep database setup is configured and ready!${NC}"
