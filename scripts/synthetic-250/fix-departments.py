#!/usr/bin/env python3
"""
Fix departments and employee data to be realistic.
- 8-10 real department names
- Realistic salary ranges ($50K-$250K)
- Proper employee distribution
"""

import os
import sys
import random
import psycopg2

random.seed(42)

# Realistic departments with salary ranges
DEPARTMENTS = [
    {"name": "Engineering", "code": "ENG", "min_salary": 80000, "max_salary": 200000},
    {"name": "Sales", "code": "SALES", "min_salary": 60000, "max_salary": 180000},
    {"name": "Marketing", "code": "MKT", "min_salary": 55000, "max_salary": 150000},
    {"name": "Finance", "code": "FIN", "min_salary": 65000, "max_salary": 180000},
    {"name": "Human Resources", "code": "HR", "min_salary": 50000, "max_salary": 120000},
    {"name": "Operations", "code": "OPS", "min_salary": 45000, "max_salary": 130000},
    {"name": "Customer Success", "code": "CS", "min_salary": 50000, "max_salary": 110000},
    {"name": "Product", "code": "PROD", "min_salary": 90000, "max_salary": 220000},
    {"name": "Legal", "code": "LEGAL", "min_salary": 80000, "max_salary": 250000},
    {"name": "Executive", "code": "EXEC", "min_salary": 150000, "max_salary": 400000},
]

# Distribution of employees per department (weights)
DEPT_WEIGHTS = {
    "Engineering": 25,
    "Sales": 20,
    "Marketing": 10,
    "Finance": 8,
    "Human Resources": 5,
    "Operations": 12,
    "Customer Success": 10,
    "Product": 6,
    "Legal": 2,
    "Executive": 2,
}


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("SUPABASE_DB_URL")
    
    if not url:
        print("Usage: python fix-departments.py <database_url>")
        sys.exit(1)
    
    print("=" * 60)
    print("Fixing Departments & Employee Data")
    print("=" * 60)
    print()
    
    conn = psycopg2.connect(url, connect_timeout=30)
    cur = conn.cursor()
    print("✓ Connected to database")
    print()
    
    # Step 1: Clear existing departments and reset
    print("Step 1: Resetting departments table...")
    
    # First, remove FK constraints temporarily
    cur.execute("""
        ALTER TABLE synthetic.employees 
        DROP CONSTRAINT IF EXISTS fk_employees_department_id
    """)
    conn.commit()
    
    # Delete all existing departments
    cur.execute("DELETE FROM synthetic.departments")
    conn.commit()
    
    # Insert new realistic departments
    for i, dept in enumerate(DEPARTMENTS, 1):
        cur.execute("""
            INSERT INTO synthetic.departments 
            (department_id, department_name, department_code, description, cost_center)
            VALUES (%s, %s, %s, %s, %s)
        """, (i, dept["name"], dept["code"], f"{dept['name']} Department", f"CC-{dept['code']}"))
    
    conn.commit()
    print(f"   ✓ Created {len(DEPARTMENTS)} departments")
    
    # Step 2: Get employee count
    cur.execute("SELECT COUNT(*) FROM synthetic.employees")
    employee_count = cur.fetchone()[0]
    print(f"   Found {employee_count} employees to update")
    
    # Step 3: Assign employees to departments with realistic salaries
    print()
    print("Step 2: Updating employees with realistic data...")
    
    # Build weighted department list
    weighted_depts = []
    for dept in DEPARTMENTS:
        weight = DEPT_WEIGHTS.get(dept["name"], 5)
        weighted_depts.extend([dept] * weight)
    
    # Get all employee IDs
    cur.execute("SELECT employee_id FROM synthetic.employees")
    employee_ids = [row[0] for row in cur.fetchall()]
    
    # Update each employee
    for emp_id in employee_ids:
        dept = random.choice(weighted_depts)
        dept_id = DEPARTMENTS.index(dept) + 1
        salary = round(random.uniform(dept["min_salary"], dept["max_salary"]), 2)
        
        cur.execute("""
            UPDATE synthetic.employees
            SET department_id = %s,
                salary = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE employee_id = %s
        """, (dept_id, salary, emp_id))
    
    conn.commit()
    print(f"   ✓ Updated {len(employee_ids)} employees")
    
    # Step 4: Restore FK constraint
    print()
    print("Step 3: Restoring foreign key constraint...")
    cur.execute("""
        ALTER TABLE synthetic.employees 
        ADD CONSTRAINT fk_employees_department_id 
        FOREIGN KEY (department_id) 
        REFERENCES synthetic.departments(department_id)
        ON DELETE SET NULL
    """)
    conn.commit()
    print("   ✓ FK constraint restored")
    
    # Step 5: Verify the results
    print()
    print("Step 4: Verifying results...")
    cur.execute("""
        SELECT 
            d.department_name,
            COUNT(e.employee_id) as headcount,
            ROUND(AVG(e.salary)::numeric, 0) as avg_salary,
            ROUND(SUM(e.salary)::numeric, 0) as total_salary
        FROM synthetic.employees e
        JOIN synthetic.departments d ON e.department_id = d.department_id
        GROUP BY d.department_name
        ORDER BY headcount DESC
    """)
    
    results = cur.fetchall()
    
    print()
    print(f"{'Department':<20} {'Headcount':>10} {'Avg Salary':>12} {'Total Salary':>15}")
    print("-" * 60)
    
    total_headcount = 0
    total_salary = 0
    
    for row in results:
        dept, headcount, avg_sal, total_sal = row
        print(f"{dept:<20} {headcount:>10} ${avg_sal:>10,} ${total_sal:>13,}")
        total_headcount += headcount
        total_salary += total_sal
    
    print("-" * 60)
    print(f"{'TOTAL':<20} {total_headcount:>10} {'':<12} ${total_salary:>13,}")
    
    conn.close()
    
    print()
    print("=" * 60)
    print("✅ Department data fixed!")
    print("=" * 60)


if __name__ == "__main__":
    main()

