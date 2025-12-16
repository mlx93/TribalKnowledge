#!/usr/bin/env python3
"""
Seed salary_history table with current and historical salary records.
Each employee gets:
- 1-3 historical salary records (with end_date)
- 1 current salary record (end_date IS NULL)
"""

import os
import sys
import random
from datetime import date, timedelta
import psycopg2

random.seed(42)


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("SUPABASE_DB_URL")
    
    if not url:
        print("Usage: python fix-salary-history.py <database_url>")
        sys.exit(1)
    
    print("=" * 60)
    print("Seeding Salary History Data")
    print("=" * 60)
    print()
    
    conn = psycopg2.connect(url, connect_timeout=30)
    cur = conn.cursor()
    print("✓ Connected to database")
    print()
    
    # Step 1: Clear existing salary history
    print("Step 1: Clearing existing salary history...")
    cur.execute("DELETE FROM synthetic.salary_history")
    conn.commit()
    print("   ✓ Cleared existing data")
    
    # Step 2: Get all employees with their current salaries
    print()
    print("Step 2: Fetching employee data...")
    cur.execute("""
        SELECT employee_id, salary, hire_date
        FROM synthetic.employees
        WHERE salary IS NOT NULL
    """)
    employees = cur.fetchall()
    print(f"   Found {len(employees)} employees")
    
    # Step 3: Create salary history records
    print()
    print("Step 3: Creating salary history records...")
    
    total_records = 0
    today = date.today()
    
    for emp_id, current_salary, hire_date in employees:
        current_salary = float(current_salary)
        
        # Use hire_date or default to 3 years ago
        if hire_date:
            start_date = hire_date
        else:
            start_date = today - timedelta(days=random.randint(365, 1095))
        
        # Determine number of salary changes (1-3 historical + 1 current)
        num_changes = random.randint(1, 3)
        
        # Work backwards from current salary
        # Each prior salary was 5-15% less
        salaries = [current_salary]
        for _ in range(num_changes):
            prior_salary = salaries[-1] / (1 + random.uniform(0.05, 0.15))
            salaries.append(round(prior_salary, 2))
        
        salaries.reverse()  # Oldest to newest
        
        # Create date ranges
        total_days = (today - start_date).days
        if total_days < 30:
            total_days = 365  # Minimum 1 year of history
        
        days_per_period = total_days // len(salaries)
        
        for i, salary_amount in enumerate(salaries):
            effective_date = start_date + timedelta(days=i * days_per_period)
            
            if i < len(salaries) - 1:
                # Historical record - has end_date
                end_date = start_date + timedelta(days=(i + 1) * days_per_period - 1)
                change_reason = random.choice([
                    'Annual raise', 'Promotion', 'Merit increase', 
                    'Cost of living adjustment', 'Role change'
                ])
            else:
                # Current record - no end_date
                end_date = None
                change_reason = random.choice([
                    'Annual raise', 'Promotion', 'Merit increase'
                ])
            
            cur.execute("""
                INSERT INTO synthetic.salary_history 
                (employee_id, effective_date, end_date, salary_amount, currency, change_reason)
                VALUES (%s, %s, %s, %s, 'USD', %s)
            """, (emp_id, effective_date, end_date, salary_amount, change_reason))
            
            total_records += 1
    
    conn.commit()
    print(f"   ✓ Created {total_records} salary history records")
    
    # Step 4: Verify with the COO query
    print()
    print("Step 4: Verifying with COO query...")
    cur.execute("""
        SELECT 
            d.department_name,
            COUNT(DISTINCT e.employee_id) AS headcount,
            ROUND(SUM(sh.salary_amount)::numeric, 0) AS total_salary_expense
        FROM synthetic.employees e
        JOIN synthetic.salary_history sh ON e.employee_id = sh.employee_id
        JOIN synthetic.departments d ON e.department_id = d.department_id
        WHERE sh.end_date IS NULL OR sh.end_date > CURRENT_DATE
        GROUP BY d.department_name
        ORDER BY total_salary_expense DESC
    """)
    
    results = cur.fetchall()
    
    print()
    print(f"{'Department':<20} {'Headcount':>10} {'Total Salary':>15}")
    print("-" * 50)
    
    total_hc = 0
    total_sal = 0
    for dept, hc, sal in results:
        print(f"{dept:<20} {hc:>10} ${sal:>13,}")
        total_hc += hc
        total_sal += sal
    
    print("-" * 50)
    print(f"{'TOTAL':<20} {total_hc:>10} ${total_sal:>13,}")
    
    # Also show sample history for one employee
    print()
    print("Sample salary history (first employee):")
    cur.execute("""
        SELECT 
            e.first_name || ' ' || e.last_name as name,
            sh.effective_date,
            sh.end_date,
            sh.salary_amount,
            sh.change_reason
        FROM synthetic.salary_history sh
        JOIN synthetic.employees e ON sh.employee_id = e.employee_id
        WHERE e.employee_id = (SELECT MIN(employee_id) FROM synthetic.employees)
        ORDER BY sh.effective_date
    """)
    
    print()
    for row in cur.fetchall():
        name, eff, end, sal, reason = row
        end_str = str(end) if end else "Current"
        print(f"  {name}: ${sal:,.2f} ({eff} to {end_str}) - {reason}")
    
    conn.close()
    
    print()
    print("=" * 60)
    print("✅ Salary history seeded!")
    print("=" * 60)


if __name__ == "__main__":
    main()

