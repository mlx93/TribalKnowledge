# Synthetic 250-Table Database: Sample Personas & Queries

This document showcases 3 personas with progressively complex questions that demonstrate the types of analytical queries our database can support.

---

## Database Overview

- **Location**: Supabase (PostgreSQL)
- **Schema**: `synthetic`
- **Tables**: 250
- **Domains**: HR, Finance, E-Commerce, Inventory, CRM, Healthcare, Projects, Marketing, IT/Infrastructure, Education

---

## 👤 Persona 1: Software Engineer (Alex)

**Background**: Building an internal infrastructure dashboard. Needs to understand the data model to query server-application dependencies.

### Question

> "I'm building a deployment tracker. How do I find which applications are running on which servers, and in what environment? What's the join path through the `app_server_map` table?"

### Why This Is a Good Engineer Question

- 🔧 Involves understanding a **junction/bridge table** (classic pattern)
- 🔧 Practical for **infrastructure tooling** (monitoring, deployments, runbooks)
- 🔧 Simple 2-hop join: `applications` → `app_server_map` → `servers`
- 🔧 Tests schema discovery capabilities

### SQL Query

```sql
SELECT 
    a.app_name,
    a.version,
    a.criticality,
    s.hostname,
    s.ip_address,
    s.environment,
    s.role,
    s.status as server_status
FROM synthetic.applications a
JOIN synthetic.app_server_map asm ON a.app_id = asm.app_id
JOIN synthetic.servers s ON asm.server_id = s.server_id
ORDER BY 
    CASE a.criticality 
        WHEN 'critical' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        ELSE 4 
    END,
    a.app_name, s.hostname;
```

### Results

| Application | Version | Criticality | Hostname | IP Address | Environment | Role | Status |
|-------------|---------|-------------|----------|------------|-------------|------|--------|
| Payment Gateway | 3.2.1 | critical | api-prod-01 | 10.0.1.20 | production | API Server | running |
| Payment Gateway | 3.2.1 | critical | api-prod-02 | 10.0.1.21 | production | API Server | running |
| Payment Gateway | 3.2.1 | critical | web-prod-01 | 10.0.1.10 | production | Web Server | running |
| Payment Gateway | 3.2.1 | critical | web-prod-02 | 10.0.1.11 | production | Web Server | running |
| User Auth Service | 2.1.0 | critical | api-prod-01 | 10.0.1.20 | production | API Server | running |
| User Auth Service | 2.1.0 | critical | api-prod-02 | 10.0.1.21 | production | API Server | running |
| User Auth Service | 2.1.0 | critical | api-staging-01 | 10.0.2.20 | staging | API Server | running |
| User Auth Service | 2.1.0 | critical | web-prod-01 | 10.0.1.10 | production | Web Server | running |
| User Auth Service | 2.1.0 | critical | web-prod-02 | 10.0.1.11 | production | Web Server | running |
| User Auth Service | 2.1.0 | critical | web-staging-01 | 10.0.2.10 | staging | Web Server | running |
| Customer Portal | 5.1.0 | high | web-prod-01 | 10.0.1.10 | production | Web Server | running |
| Customer Portal | 5.1.0 | high | web-prod-02 | 10.0.1.11 | production | Web Server | running |
| Customer Portal | 5.1.0 | high | web-staging-01 | 10.0.2.10 | staging | Web Server | running |
| Inventory Service | 1.8.3 | high | api-prod-01 | 10.0.1.20 | production | API Server | running |
| Inventory Service | 1.8.3 | high | api-prod-02 | 10.0.1.21 | production | API Server | running |
| Inventory Service | 1.8.3 | high | api-staging-01 | 10.0.2.20 | staging | API Server | running |
| Order Management | 4.0.5 | high | api-prod-01 | 10.0.1.20 | production | API Server | running |
| Order Management | 4.0.5 | high | api-prod-02 | 10.0.1.21 | production | API Server | running |

### Key Insights

- **Critical apps** (Payment Gateway, User Auth) run on 4-6 servers for redundancy
- **Staging environments** mirror production for high/critical apps
- **Junction table pattern**: `app_server_map` enables many-to-many relationships

---

## 👤 Persona 2: COO (Marcus)

**Background**: Preparing for quarterly budget review, needs to understand labor costs across the organization.

### Question

> "What's our headcount and total salary expense by department? I need this for our Q1 budget review."

### Why This Is a Good COO Question

- 📊 Classic executive KPI (labor cost analysis)
- 📊 Simple and immediately actionable
- 📊 Only 1 join required
- 📊 Supports budget planning and hiring decisions

### SQL Query

```sql
SELECT 
    d.department_name,
    COUNT(e.employee_id) as headcount,
    ROUND(AVG(e.salary)::numeric, 0) as avg_salary,
    ROUND(SUM(e.salary)::numeric, 0) as total_salary_expense,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) as pct_of_company
FROM synthetic.employees e
JOIN synthetic.departments d ON e.department_id = d.department_id
GROUP BY d.department_name
ORDER BY total_salary_expense DESC;
```

### Results

| Department | Headcount | Avg Salary | Total Salary Expense | % of Company |
|------------|-----------|------------|----------------------|--------------|
| Sales | 14 | $125,929 | $1,763,002 | 28.0% |
| Engineering | 7 | $142,797 | $999,582 | 14.0% |
| Customer Success | 9 | $78,006 | $702,052 | 18.0% |
| Product | 4 | $127,400 | $509,599 | 8.0% |
| Operations | 6 | $79,717 | $478,302 | 12.0% |
| Marketing | 6 | $75,315 | $451,891 | 12.0% |
| Executive | 1 | $344,000 | $344,000 | 2.0% |
| Human Resources | 2 | $84,918 | $169,836 | 4.0% |
| Finance | 1 | $108,637 | $108,637 | 2.0% |

**Company Total**: 50 employees, $5,526,901 annual salary expense

### Key Insights

- **Sales is the largest department** (28% of headcount, 32% of salary expense)
- **Engineering has highest avg salary** ($142,797) reflecting technical talent costs
- **Customer Success is lean** (18% of company) but critical for retention
- **Executive overhead** is just 2% of headcount

---

## 👤 Persona 3: Technical PM (Priya)

**Background**: Building a pricing optimization tool. Needs deep analytical queries that combine sales, procurement, and inventory data.

### Question

> "Calculate the true profit margin for each sales order after accounting for procurement costs. For each order: sum the line item revenues, then subtract the total cost (quantity × average supplier cost per product). Since products appear on multiple purchase orders at different prices, first calculate one weighted average cost per product, then use that for margin calculations. Show: order ID, customer, total revenue, total COGS, gross margin, and margin percentage."

### Why This Is a Good Technical PM Question

- 💰 Multi-table analytical join (4+ tables)
- 💰 Requires weighted average calculations (CTE pattern)
- 💰 Real business impact: pricing strategy, profitability analysis
- 💰 Tests complex SQL generation capabilities

### SQL Query

```sql
WITH weighted_costs AS (
    SELECT
        product_id,
        SUM(unit_cost * quantity_ordered) / NULLIF(SUM(quantity_ordered), 0) AS weighted_avg_cost
    FROM synthetic.purchase_order_lines
    GROUP BY product_id
)
SELECT
    so.sales_order_id AS order_id,
    a.account_name AS customer,
    ROUND(SUM(sol.line_total)::numeric, 2) AS total_revenue,
    ROUND(SUM(sol.quantity * COALESCE(wc.weighted_avg_cost, 0))::numeric, 2) AS total_cogs,
    ROUND((SUM(sol.line_total) - SUM(sol.quantity * COALESCE(wc.weighted_avg_cost, 0)))::numeric, 2) AS gross_margin,
    ROUND((100.0 * (SUM(sol.line_total) - SUM(sol.quantity * COALESCE(wc.weighted_avg_cost, 0))) / 
           NULLIF(SUM(sol.line_total), 0))::numeric, 1) AS margin_pct
FROM synthetic.sales_orders so
JOIN synthetic.sales_order_lines sol ON so.sales_order_id = sol.sales_order_id
LEFT JOIN synthetic.accounts a ON so.account_id = a.account_id
LEFT JOIN weighted_costs wc ON sol.product_id = wc.product_id
GROUP BY so.sales_order_id, a.account_name
HAVING SUM(sol.line_total) > 0
ORDER BY gross_margin DESC
LIMIT 15;
```

### Results

| Order ID | Total Revenue | Total COGS | Gross Margin | Margin % |
|----------|---------------|------------|--------------|----------|
| 3 | $11,920,328.57 | $7,278,159.74 | $4,642,168.83 | 38.9% |
| 33 | $8,214,080.11 | $5,015,191.21 | $3,198,888.90 | 38.9% |
| 20 | $7,662,231.32 | $4,756,877.75 | $2,905,353.57 | 37.9% |
| 47 | $6,015,330.30 | $3,390,201.61 | $2,625,128.69 | 43.6% |
| 21 | $6,357,139.16 | $3,958,320.67 | $2,398,818.49 | 37.7% |
| 26 | $4,960,459.32 | $2,832,122.55 | $2,128,336.77 | 42.9% |
| 43 | $6,629,289.08 | $4,527,067.14 | $2,102,221.94 | 31.7% |
| 22 | $4,865,411.68 | $2,819,188.30 | $2,046,223.38 | 42.1% |
| 2 | $5,318,343.49 | $3,432,508.53 | $1,885,834.96 | 35.5% |
| 31 | $3,871,074.50 | $2,273,129.52 | $1,597,944.98 | 41.3% |
| 23 | $3,791,085.24 | $2,371,888.71 | $1,419,196.53 | 37.4% |
| 13 | $3,265,124.93 | $1,981,014.20 | $1,284,110.73 | 39.3% |
| 44 | $3,511,451.65 | $2,501,723.62 | $1,009,728.03 | 28.8% |
| 24 | $3,436,023.27 | $2,570,428.13 | $865,595.14 | 25.2% |
| 15 | $2,173,787.74 | $1,367,220.26 | $806,567.48 | 37.1% |

### Key Insights

- **Average margin is ~35-40%** across top orders
- **Order 47 has highest margin %** (43.6%) - good candidate for pricing analysis
- **Order 24 has lowest margin** (25.2%) - investigate product mix
- **All margins are positive** after data normalization

---

## Summary: Persona Comparison

| Persona | Role | Complexity | Tables Joined | Business Value |
|---------|------|------------|---------------|----------------|
| **Alex** (Engineer) | Software Engineer | 🟡 Medium | 3 (`applications`, `app_server_map`, `servers`) | Infrastructure visibility, deployment tracking |
| **Marcus** (COO) | Executive | 🟢 Simple | 2 (`employees`, `departments`) | Budget planning, headcount analysis |
| **Priya** (Tech PM) | Product Manager | 🔴 Complex | 4+ (`sales_orders`, `sales_order_lines`, `accounts`, `purchase_order_lines`) | Margin optimization, pricing strategy |

---

## Connection Details

```
Host: aws-0-us-west-2.pooler.supabase.com
Port: 5432
Database: postgres
Schema: synthetic
```

