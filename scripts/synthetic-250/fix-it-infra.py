#!/usr/bin/env python3
"""
Seed realistic IT infrastructure data: servers, applications, and mappings.
"""

import os
import sys
import random
import psycopg2

random.seed(42)

SERVERS = [
    {"hostname": "web-prod-01", "ip": "10.0.1.10", "env": "production", "os": "Ubuntu 22.04", "role": "Web Server", "cpu": 8, "ram": 32},
    {"hostname": "web-prod-02", "ip": "10.0.1.11", "env": "production", "os": "Ubuntu 22.04", "role": "Web Server", "cpu": 8, "ram": 32},
    {"hostname": "api-prod-01", "ip": "10.0.1.20", "env": "production", "os": "Ubuntu 22.04", "role": "API Server", "cpu": 16, "ram": 64},
    {"hostname": "api-prod-02", "ip": "10.0.1.21", "env": "production", "os": "Ubuntu 22.04", "role": "API Server", "cpu": 16, "ram": 64},
    {"hostname": "db-prod-01", "ip": "10.0.1.30", "env": "production", "os": "Ubuntu 22.04", "role": "Database", "cpu": 32, "ram": 128},
    {"hostname": "db-prod-02", "ip": "10.0.1.31", "env": "production", "os": "Ubuntu 22.04", "role": "Database Replica", "cpu": 32, "ram": 128},
    {"hostname": "cache-prod-01", "ip": "10.0.1.40", "env": "production", "os": "Ubuntu 22.04", "role": "Cache Server", "cpu": 8, "ram": 64},
    {"hostname": "worker-prod-01", "ip": "10.0.1.50", "env": "production", "os": "Ubuntu 22.04", "role": "Background Worker", "cpu": 16, "ram": 32},
    {"hostname": "worker-prod-02", "ip": "10.0.1.51", "env": "production", "os": "Ubuntu 22.04", "role": "Background Worker", "cpu": 16, "ram": 32},
    {"hostname": "web-staging-01", "ip": "10.0.2.10", "env": "staging", "os": "Ubuntu 22.04", "role": "Web Server", "cpu": 4, "ram": 16},
    {"hostname": "api-staging-01", "ip": "10.0.2.20", "env": "staging", "os": "Ubuntu 22.04", "role": "API Server", "cpu": 8, "ram": 32},
    {"hostname": "db-staging-01", "ip": "10.0.2.30", "env": "staging", "os": "Ubuntu 22.04", "role": "Database", "cpu": 8, "ram": 32},
    {"hostname": "dev-server-01", "ip": "10.0.3.10", "env": "development", "os": "Ubuntu 22.04", "role": "Dev Server", "cpu": 4, "ram": 16},
    {"hostname": "ci-runner-01", "ip": "10.0.3.20", "env": "development", "os": "Ubuntu 22.04", "role": "CI/CD Runner", "cpu": 8, "ram": 32},
]

APPLICATIONS = [
    {"name": "Payment Gateway", "version": "3.2.1", "vendor": "Internal", "criticality": "critical", "owner": "Payments Team"},
    {"name": "User Auth Service", "version": "2.1.0", "vendor": "Internal", "criticality": "critical", "owner": "Platform Team"},
    {"name": "Order Management", "version": "4.0.5", "vendor": "Internal", "criticality": "high", "owner": "Commerce Team"},
    {"name": "Inventory Service", "version": "1.8.3", "vendor": "Internal", "criticality": "high", "owner": "Supply Chain"},
    {"name": "Analytics Pipeline", "version": "2.3.0", "vendor": "Internal", "criticality": "medium", "owner": "Data Team"},
    {"name": "Email Service", "version": "1.5.2", "vendor": "Internal", "criticality": "medium", "owner": "Marketing"},
    {"name": "Customer Portal", "version": "5.1.0", "vendor": "Internal", "criticality": "high", "owner": "Product Team"},
    {"name": "Admin Dashboard", "version": "3.0.1", "vendor": "Internal", "criticality": "medium", "owner": "Platform Team"},
    {"name": "Report Generator", "version": "2.0.0", "vendor": "Internal", "criticality": "low", "owner": "Finance"},
    {"name": "Notification Service", "version": "1.2.4", "vendor": "Internal", "criticality": "medium", "owner": "Platform Team"},
]

# Which apps run on which servers (by index)
APP_SERVER_MAPPINGS = [
    # Payment Gateway - runs on web and api prod servers
    (0, [0, 1, 2, 3], "production"),
    # User Auth Service - runs everywhere
    (1, [0, 1, 2, 3, 9, 10], "production"),
    (1, [9, 10], "staging"),
    # Order Management
    (2, [2, 3, 7, 8], "production"),
    (2, [10], "staging"),
    # Inventory Service
    (3, [2, 3], "production"),
    (3, [10], "staging"),
    # Analytics Pipeline - workers
    (4, [7, 8], "production"),
    # Email Service
    (5, [7, 8], "production"),
    # Customer Portal
    (6, [0, 1], "production"),
    (6, [9], "staging"),
    # Admin Dashboard
    (7, [0, 1], "production"),
    (7, [9], "staging"),
    # Report Generator
    (8, [7], "production"),
    # Notification Service
    (9, [7, 8], "production"),
]


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("SUPABASE_DB_URL")
    
    if not url:
        print("Usage: python fix-it-infra.py <database_url>")
        sys.exit(1)
    
    print("=" * 60)
    print("Seeding IT Infrastructure Data")
    print("=" * 60)
    print()
    
    conn = psycopg2.connect(url, connect_timeout=30)
    cur = conn.cursor()
    print("✓ Connected to database")
    print()
    
    # Step 1: Clear existing data
    print("Step 1: Clearing existing IT data...")
    cur.execute("DELETE FROM synthetic.app_server_map")
    cur.execute("DELETE FROM synthetic.servers")
    cur.execute("DELETE FROM synthetic.applications")
    conn.commit()
    print("   ✓ Cleared existing data")
    
    # Step 2: Insert servers
    print()
    print("Step 2: Inserting servers...")
    server_ids = {}
    for i, server in enumerate(SERVERS):
        cur.execute("""
            INSERT INTO synthetic.servers 
            (hostname, ip_address, os, os_version, environment, role, cpu_cores, ram_gb, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'running')
            RETURNING server_id
        """, (
            server["hostname"], server["ip"], server["os"], "22.04",
            server["env"], server["role"], server["cpu"], server["ram"]
        ))
        server_ids[i] = cur.fetchone()[0]
    conn.commit()
    print(f"   ✓ Inserted {len(SERVERS)} servers")
    
    # Step 3: Insert applications
    print()
    print("Step 3: Inserting applications...")
    app_ids = {}
    for i, app in enumerate(APPLICATIONS):
        cur.execute("""
            INSERT INTO synthetic.applications 
            (app_name, version, vendor, criticality, status)
            VALUES (%s, %s, %s, %s, 'active')
            RETURNING app_id
        """, (app["name"], app["version"], app["vendor"], app["criticality"]))
        app_ids[i] = cur.fetchone()[0]
    conn.commit()
    print(f"   ✓ Inserted {len(APPLICATIONS)} applications")
    
    # Step 4: Insert app-server mappings
    print()
    print("Step 4: Creating app-server mappings...")
    mapping_count = 0
    for app_idx, server_indices, env in APP_SERVER_MAPPINGS:
        app_id = app_ids[app_idx]
        for server_idx in server_indices:
            server_id = server_ids[server_idx]
            cur.execute("""
                INSERT INTO synthetic.app_server_map 
                (app_id, server_id, environment)
                VALUES (%s, %s, %s)
            """, (app_id, server_id, env))
            mapping_count += 1
    conn.commit()
    print(f"   ✓ Created {mapping_count} app-server mappings")
    
    # Step 5: Verify
    print()
    print("Step 5: Verifying...")
    cur.execute("""
        SELECT 
            a.app_name,
            a.criticality,
            COUNT(DISTINCT s.server_id) as server_count,
            STRING_AGG(DISTINCT s.environment, ', ') as environments
        FROM synthetic.applications a
        JOIN synthetic.app_server_map asm ON a.app_id = asm.app_id
        JOIN synthetic.servers s ON asm.server_id = s.server_id
        GROUP BY a.app_id, a.app_name, a.criticality
        ORDER BY 
            CASE a.criticality 
                WHEN 'critical' THEN 1 
                WHEN 'high' THEN 2 
                WHEN 'medium' THEN 3 
                ELSE 4 
            END,
            a.app_name
    """)
    
    print()
    print(f"{'Application':<25} {'Criticality':<12} {'Servers':>8} {'Environments':<20}")
    print("-" * 70)
    for row in cur.fetchall():
        app, crit, count, envs = row
        print(f"{app:<25} {crit:<12} {count:>8} {envs:<20}")
    
    conn.close()
    
    print()
    print("=" * 60)
    print("✅ IT Infrastructure data seeded!")
    print("=" * 60)


if __name__ == "__main__":
    main()

