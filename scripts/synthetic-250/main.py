#!/usr/bin/env python3
"""
Synthetic 250-Table Database Generator
Generates PostgreSQL DDL for a diverse synthetic database across business domains.

Usage:
    python main.py [--output-dir OUTPUT_DIR]

Output:
    - synthetic_250_postgres.sql: PostgreSQL DDL script
    - synthetic_250_summary.md: Schema documentation
"""

import os
import sys
import argparse
from datetime import datetime
from typing import Dict, List, Any

# Import domain definitions
from domains import DOMAINS
from domains_extended import DOMAINS_EXTENDED
from domains_more import DOMAINS_MORE

# Additional 20 tables to reach 250
DOMAINS_EDUCATION: Dict[str, Dict[str, Any]] = {
    "education": {
        "description": "Education and Learning Management",
        "tables": [
            {
                "name": "students",
                "columns": [
                    {"name": "student_id", "type": "SERIAL", "primary_key": True},
                    {"name": "student_number", "type": "VARCHAR(20)", "unique": True},
                    {"name": "first_name", "type": "VARCHAR(100)", "not_null": True},
                    {"name": "last_name", "type": "VARCHAR(100)", "not_null": True},
                    {"name": "email", "type": "VARCHAR(255)", "unique": True},
                    {"name": "date_of_birth", "type": "DATE"},
                    {"name": "gender", "type": "VARCHAR(10)"},
                    {"name": "enrollment_date", "type": "DATE"},
                    {"name": "graduation_date", "type": "DATE"},
                    {"name": "program_id", "type": "INTEGER", "fk": "programs.program_id"},
                    {"name": "advisor_id", "type": "INTEGER", "fk": "instructors.instructor_id"},
                    {"name": "status", "type": "VARCHAR(50)", "default": "'active'"},
                    {"name": "gpa", "type": "DECIMAL(3,2)"},
                ],
            },
            {
                "name": "instructors",
                "columns": [
                    {"name": "instructor_id", "type": "SERIAL", "primary_key": True},
                    {"name": "employee_id", "type": "VARCHAR(20)", "unique": True},
                    {"name": "first_name", "type": "VARCHAR(100)", "not_null": True},
                    {"name": "last_name", "type": "VARCHAR(100)", "not_null": True},
                    {"name": "email", "type": "VARCHAR(255)"},
                    {"name": "department_id", "type": "INTEGER", "fk": "academic_departments.department_id"},
                    {"name": "title", "type": "VARCHAR(100)"},
                    {"name": "hire_date", "type": "DATE"},
                    {"name": "office_location", "type": "VARCHAR(100)"},
                    {"name": "is_active", "type": "BOOLEAN", "default": "true"},
                ],
            },
            {
                "name": "academic_departments",
                "columns": [
                    {"name": "department_id", "type": "SERIAL", "primary_key": True},
                    {"name": "department_code", "type": "VARCHAR(10)", "unique": True},
                    {"name": "department_name", "type": "VARCHAR(200)", "not_null": True},
                    {"name": "head_instructor_id", "type": "INTEGER"},
                    {"name": "building", "type": "VARCHAR(100)"},
                    {"name": "phone", "type": "VARCHAR(20)"},
                ],
            },
            {
                "name": "programs",
                "columns": [
                    {"name": "program_id", "type": "SERIAL", "primary_key": True},
                    {"name": "program_code", "type": "VARCHAR(20)", "unique": True},
                    {"name": "program_name", "type": "VARCHAR(200)", "not_null": True},
                    {"name": "department_id", "type": "INTEGER", "fk": "academic_departments.department_id"},
                    {"name": "degree_type", "type": "VARCHAR(50)"},
                    {"name": "credit_hours_required", "type": "INTEGER"},
                    {"name": "description", "type": "TEXT"},
                    {"name": "is_active", "type": "BOOLEAN", "default": "true"},
                ],
            },
            {
                "name": "courses",
                "columns": [
                    {"name": "course_id", "type": "SERIAL", "primary_key": True},
                    {"name": "course_code", "type": "VARCHAR(20)", "not_null": True, "unique": True},
                    {"name": "course_name", "type": "VARCHAR(200)", "not_null": True},
                    {"name": "department_id", "type": "INTEGER", "fk": "academic_departments.department_id"},
                    {"name": "credit_hours", "type": "INTEGER"},
                    {"name": "description", "type": "TEXT"},
                    {"name": "prerequisites", "type": "TEXT"},
                    {"name": "is_active", "type": "BOOLEAN", "default": "true"},
                ],
            },
            {
                "name": "course_sections",
                "columns": [
                    {"name": "section_id", "type": "SERIAL", "primary_key": True},
                    {"name": "course_id", "type": "INTEGER", "not_null": True, "fk": "courses.course_id"},
                    {"name": "section_number", "type": "VARCHAR(10)", "not_null": True},
                    {"name": "term_id", "type": "INTEGER", "fk": "academic_terms.term_id"},
                    {"name": "instructor_id", "type": "INTEGER", "fk": "instructors.instructor_id"},
                    {"name": "room_id", "type": "INTEGER", "fk": "classrooms.room_id"},
                    {"name": "max_enrollment", "type": "INTEGER"},
                    {"name": "current_enrollment", "type": "INTEGER", "default": "0"},
                    {"name": "schedule", "type": "VARCHAR(200)"},
                    {"name": "status", "type": "VARCHAR(50)", "default": "'open'"},
                ],
            },
            {
                "name": "academic_terms",
                "columns": [
                    {"name": "term_id", "type": "SERIAL", "primary_key": True},
                    {"name": "term_code", "type": "VARCHAR(20)", "unique": True},
                    {"name": "term_name", "type": "VARCHAR(100)", "not_null": True},
                    {"name": "start_date", "type": "DATE"},
                    {"name": "end_date", "type": "DATE"},
                    {"name": "registration_start", "type": "DATE"},
                    {"name": "registration_end", "type": "DATE"},
                    {"name": "is_current", "type": "BOOLEAN", "default": "false"},
                ],
            },
            {
                "name": "enrollments",
                "columns": [
                    {"name": "enrollment_id", "type": "SERIAL", "primary_key": True},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "section_id", "type": "INTEGER", "not_null": True, "fk": "course_sections.section_id"},
                    {"name": "enrollment_date", "type": "DATE"},
                    {"name": "status", "type": "VARCHAR(50)", "default": "'enrolled'"},
                    {"name": "grade", "type": "VARCHAR(5)"},
                    {"name": "grade_points", "type": "DECIMAL(3,2)"},
                    {"name": "credits_earned", "type": "INTEGER"},
                ],
            },
            {
                "name": "classrooms",
                "columns": [
                    {"name": "room_id", "type": "SERIAL", "primary_key": True},
                    {"name": "room_number", "type": "VARCHAR(20)", "not_null": True},
                    {"name": "building", "type": "VARCHAR(100)"},
                    {"name": "capacity", "type": "INTEGER"},
                    {"name": "room_type", "type": "VARCHAR(50)"},
                    {"name": "has_projector", "type": "BOOLEAN", "default": "false"},
                    {"name": "has_whiteboard", "type": "BOOLEAN", "default": "true"},
                    {"name": "is_available", "type": "BOOLEAN", "default": "true"},
                ],
            },
            {
                "name": "assignments",
                "columns": [
                    {"name": "assignment_id", "type": "SERIAL", "primary_key": True},
                    {"name": "section_id", "type": "INTEGER", "not_null": True, "fk": "course_sections.section_id"},
                    {"name": "assignment_name", "type": "VARCHAR(200)", "not_null": True},
                    {"name": "assignment_type", "type": "VARCHAR(50)"},
                    {"name": "description", "type": "TEXT"},
                    {"name": "due_date", "type": "TIMESTAMP"},
                    {"name": "max_points", "type": "DECIMAL(6,2)"},
                    {"name": "weight", "type": "DECIMAL(5,2)"},
                ],
            },
            {
                "name": "submissions",
                "columns": [
                    {"name": "submission_id", "type": "SERIAL", "primary_key": True},
                    {"name": "assignment_id", "type": "INTEGER", "not_null": True, "fk": "assignments.assignment_id"},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "submitted_at", "type": "TIMESTAMP"},
                    {"name": "file_path", "type": "VARCHAR(500)"},
                    {"name": "score", "type": "DECIMAL(6,2)"},
                    {"name": "feedback", "type": "TEXT"},
                    {"name": "graded_at", "type": "TIMESTAMP"},
                    {"name": "graded_by", "type": "INTEGER"},
                ],
            },
            {
                "name": "attendance",
                "columns": [
                    {"name": "attendance_id", "type": "SERIAL", "primary_key": True},
                    {"name": "section_id", "type": "INTEGER", "not_null": True, "fk": "course_sections.section_id"},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "class_date", "type": "DATE", "not_null": True},
                    {"name": "status", "type": "VARCHAR(20)"},
                    {"name": "notes", "type": "VARCHAR(500)"},
                ],
            },
            {
                "name": "tuition_fees",
                "columns": [
                    {"name": "fee_id", "type": "SERIAL", "primary_key": True},
                    {"name": "fee_name", "type": "VARCHAR(200)", "not_null": True},
                    {"name": "fee_type", "type": "VARCHAR(50)"},
                    {"name": "amount", "type": "DECIMAL(10,2)", "not_null": True},
                    {"name": "term_id", "type": "INTEGER", "fk": "academic_terms.term_id"},
                    {"name": "is_required", "type": "BOOLEAN", "default": "true"},
                ],
            },
            {
                "name": "student_accounts",
                "columns": [
                    {"name": "account_id", "type": "SERIAL", "primary_key": True},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "term_id", "type": "INTEGER", "fk": "academic_terms.term_id"},
                    {"name": "total_charges", "type": "DECIMAL(15,2)", "default": "0"},
                    {"name": "total_payments", "type": "DECIMAL(15,2)", "default": "0"},
                    {"name": "balance", "type": "DECIMAL(15,2)", "default": "0"},
                    {"name": "due_date", "type": "DATE"},
                ],
            },
            {
                "name": "student_payments",
                "columns": [
                    {"name": "payment_id", "type": "SERIAL", "primary_key": True},
                    {"name": "account_id", "type": "INTEGER", "not_null": True, "fk": "student_accounts.account_id"},
                    {"name": "payment_date", "type": "DATE", "not_null": True},
                    {"name": "amount", "type": "DECIMAL(10,2)", "not_null": True},
                    {"name": "payment_method", "type": "VARCHAR(50)"},
                    {"name": "reference_number", "type": "VARCHAR(100)"},
                ],
            },
            {
                "name": "financial_aid",
                "columns": [
                    {"name": "aid_id", "type": "SERIAL", "primary_key": True},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "term_id", "type": "INTEGER", "fk": "academic_terms.term_id"},
                    {"name": "aid_type", "type": "VARCHAR(50)"},
                    {"name": "aid_name", "type": "VARCHAR(200)"},
                    {"name": "amount", "type": "DECIMAL(10,2)"},
                    {"name": "status", "type": "VARCHAR(50)", "default": "'pending'"},
                    {"name": "disbursed_date", "type": "DATE"},
                ],
            },
            {
                "name": "degree_requirements",
                "columns": [
                    {"name": "requirement_id", "type": "SERIAL", "primary_key": True},
                    {"name": "program_id", "type": "INTEGER", "not_null": True, "fk": "programs.program_id"},
                    {"name": "course_id", "type": "INTEGER", "fk": "courses.course_id"},
                    {"name": "requirement_type", "type": "VARCHAR(50)"},
                    {"name": "credit_hours", "type": "INTEGER"},
                    {"name": "minimum_grade", "type": "VARCHAR(5)"},
                    {"name": "is_required", "type": "BOOLEAN", "default": "true"},
                ],
            },
            {
                "name": "transcripts",
                "columns": [
                    {"name": "transcript_id", "type": "SERIAL", "primary_key": True},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "request_date", "type": "DATE"},
                    {"name": "issue_date", "type": "DATE"},
                    {"name": "transcript_type", "type": "VARCHAR(50)"},
                    {"name": "recipient", "type": "VARCHAR(500)"},
                    {"name": "status", "type": "VARCHAR(50)", "default": "'pending'"},
                ],
            },
            {
                "name": "academic_holds",
                "columns": [
                    {"name": "hold_id", "type": "SERIAL", "primary_key": True},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "hold_type", "type": "VARCHAR(50)", "not_null": True},
                    {"name": "reason", "type": "TEXT"},
                    {"name": "placed_date", "type": "DATE"},
                    {"name": "released_date", "type": "DATE"},
                    {"name": "placed_by", "type": "INTEGER"},
                    {"name": "is_active", "type": "BOOLEAN", "default": "true"},
                ],
            },
            {
                "name": "course_waitlist",
                "columns": [
                    {"name": "waitlist_id", "type": "SERIAL", "primary_key": True},
                    {"name": "section_id", "type": "INTEGER", "not_null": True, "fk": "course_sections.section_id"},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "position", "type": "INTEGER"},
                    {"name": "added_date", "type": "TIMESTAMP"},
                    {"name": "status", "type": "VARCHAR(50)", "default": "'waiting'"},
                ],
            },
            {
                "name": "course_materials",
                "columns": [
                    {"name": "material_id", "type": "SERIAL", "primary_key": True},
                    {"name": "section_id", "type": "INTEGER", "not_null": True, "fk": "course_sections.section_id"},
                    {"name": "material_name", "type": "VARCHAR(200)", "not_null": True},
                    {"name": "material_type", "type": "VARCHAR(50)"},
                    {"name": "file_path", "type": "VARCHAR(500)"},
                    {"name": "description", "type": "TEXT"},
                    {"name": "is_required", "type": "BOOLEAN", "default": "false"},
                    {"name": "upload_date", "type": "TIMESTAMP"},
                ],
            },
            {
                "name": "office_hours",
                "columns": [
                    {"name": "office_hour_id", "type": "SERIAL", "primary_key": True},
                    {"name": "instructor_id", "type": "INTEGER", "not_null": True, "fk": "instructors.instructor_id"},
                    {"name": "day_of_week", "type": "VARCHAR(20)"},
                    {"name": "start_time", "type": "TIME"},
                    {"name": "end_time", "type": "TIME"},
                    {"name": "location", "type": "VARCHAR(100)"},
                    {"name": "term_id", "type": "INTEGER", "fk": "academic_terms.term_id"},
                ],
            },
            {
                "name": "student_clubs",
                "columns": [
                    {"name": "club_id", "type": "SERIAL", "primary_key": True},
                    {"name": "club_name", "type": "VARCHAR(200)", "not_null": True},
                    {"name": "description", "type": "TEXT"},
                    {"name": "advisor_id", "type": "INTEGER", "fk": "instructors.instructor_id"},
                    {"name": "meeting_schedule", "type": "VARCHAR(200)"},
                    {"name": "meeting_location", "type": "VARCHAR(100)"},
                    {"name": "is_active", "type": "BOOLEAN", "default": "true"},
                ],
            },
            {
                "name": "club_memberships",
                "columns": [
                    {"name": "membership_id", "type": "SERIAL", "primary_key": True},
                    {"name": "club_id", "type": "INTEGER", "not_null": True, "fk": "student_clubs.club_id"},
                    {"name": "student_id", "type": "INTEGER", "not_null": True, "fk": "students.student_id"},
                    {"name": "role", "type": "VARCHAR(50)"},
                    {"name": "join_date", "type": "DATE"},
                    {"name": "end_date", "type": "DATE"},
                ],
            },
            {
                "name": "grade_scales",
                "columns": [
                    {"name": "scale_id", "type": "SERIAL", "primary_key": True},
                    {"name": "grade_letter", "type": "VARCHAR(5)", "not_null": True},
                    {"name": "min_percentage", "type": "DECIMAL(5,2)"},
                    {"name": "max_percentage", "type": "DECIMAL(5,2)"},
                    {"name": "grade_points", "type": "DECIMAL(3,2)"},
                    {"name": "description", "type": "VARCHAR(100)"},
                ],
            },
            {
                "name": "academic_calendar",
                "columns": [
                    {"name": "event_id", "type": "SERIAL", "primary_key": True},
                    {"name": "term_id", "type": "INTEGER", "fk": "academic_terms.term_id"},
                    {"name": "event_name", "type": "VARCHAR(200)", "not_null": True},
                    {"name": "event_type", "type": "VARCHAR(50)"},
                    {"name": "start_date", "type": "DATE", "not_null": True},
                    {"name": "end_date", "type": "DATE"},
                    {"name": "description", "type": "TEXT"},
                    {"name": "is_holiday", "type": "BOOLEAN", "default": "false"},
                ],
            },
        ],
    },
}


def generate_column_sql(column: Dict[str, Any]) -> str:
    """Generate SQL for a single column definition."""
    parts = [f'"{column["name"]}"', column["type"]]
    
    if column.get("primary_key"):
        parts.append("PRIMARY KEY")
    if column.get("not_null"):
        parts.append("NOT NULL")
    if column.get("unique"):
        parts.append("UNIQUE")
    if column.get("default"):
        parts.append(f"DEFAULT {column['default']}")
    
    return " ".join(parts)


def generate_table_sql(schema: str, table_name: str, table_def: Dict[str, Any]) -> str:
    """Generate SQL for a complete table definition."""
    columns = table_def["columns"]
    
    # Add timestamp columns
    timestamp_cols = [
        {"name": "created_at", "type": "TIMESTAMP", "default": "CURRENT_TIMESTAMP"},
        {"name": "updated_at", "type": "TIMESTAMP", "default": "CURRENT_TIMESTAMP"},
    ]
    
    all_columns = columns + timestamp_cols
    
    # Generate column definitions
    col_lines = [generate_column_sql(col) for col in all_columns]
    
    # Generate foreign key constraints
    fk_constraints = []
    for col in columns:
        if col.get("fk"):
            ref_table, ref_col = col["fk"].split(".")
            constraint_name = f"fk_{table_name}_{col['name']}"
            fk_constraints.append(
                f'    CONSTRAINT "{constraint_name}" FOREIGN KEY ("{col["name"]}") '
                f'REFERENCES "{schema}"."{ref_table}" ("{ref_col}")'
            )
    
    # Build full table SQL
    lines = [f'CREATE TABLE IF NOT EXISTS "{schema}"."{table_name}" (']
    lines.append(",\n".join(f"    {line}" for line in col_lines))
    
    if fk_constraints:
        lines[-1] += ","
        lines.append(",\n".join(fk_constraints))
    
    lines.append(");")
    
    return "\n".join(lines)


def generate_index_sql(schema: str, table_name: str, table_def: Dict[str, Any]) -> List[str]:
    """Generate index SQL for foreign key columns."""
    indexes = []
    for col in table_def["columns"]:
        if col.get("fk"):
            idx_name = f"idx_{table_name}_{col['name']}"
            indexes.append(
                f'CREATE INDEX IF NOT EXISTS "{idx_name}" ON "{schema}"."{table_name}" ("{col["name"]}");'
            )
    return indexes


def generate_schema_sql(all_domains: Dict[str, Dict[str, Any]], schema_name: str = "synthetic") -> str:
    """Generate complete SQL for all domains."""
    sql_parts = []
    
    # Header
    sql_parts.append(f"""-- ============================================================================
-- Synthetic 250-Table Database Schema
-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- Schema: {schema_name}
-- ============================================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS "{schema_name}";

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
""")
    
    # Track all tables for summary
    all_tables = []
    
    # Generate tables by domain (in dependency order)
    for domain_name, domain_def in all_domains.items():
        sql_parts.append(f"""
-- ============================================================================
-- Domain: {domain_def['description'].upper()}
-- ============================================================================
""")
        
        for table in domain_def["tables"]:
            table_name = table["name"]
            all_tables.append((domain_name, table_name, table))
            
            # Generate table SQL
            sql_parts.append(f"\n-- Table: {schema_name}.{table_name}")
            sql_parts.append(generate_table_sql(schema_name, table_name, table))
            
            # Generate indexes
            indexes = generate_index_sql(schema_name, table_name, table)
            if indexes:
                sql_parts.extend(indexes)
    
    # Add summary comment
    sql_parts.append(f"""
-- ============================================================================
-- Summary: {len(all_tables)} tables created in schema '{schema_name}'
-- ============================================================================
""")
    
    return "\n".join(sql_parts), all_tables


def generate_summary_md(all_tables: List, schema_name: str) -> str:
    """Generate markdown documentation."""
    lines = [
        f"# Synthetic 250-Table Database Schema",
        f"",
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"",
        f"## Overview",
        f"",
        f"- **Schema**: `{schema_name}`",
        f"- **Total Tables**: {len(all_tables)}",
        f"",
        f"## Tables by Domain",
        f"",
    ]
    
    # Group by domain
    domains = {}
    for domain_name, table_name, table_def in all_tables:
        if domain_name not in domains:
            domains[domain_name] = []
        domains[domain_name].append((table_name, table_def))
    
    for domain_name, tables in domains.items():
        lines.append(f"### {domain_name.upper().replace('_', ' ')} ({len(tables)} tables)")
        lines.append("")
        lines.append("| Table | Columns | Foreign Keys |")
        lines.append("|-------|---------|--------------|")
        
        for table_name, table_def in tables:
            col_count = len(table_def["columns"])
            fk_count = sum(1 for c in table_def["columns"] if c.get("fk"))
            lines.append(f"| `{table_name}` | {col_count} | {fk_count} |")
        
        lines.append("")
    
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate synthetic 250-table database schema")
    parser.add_argument(
        "--output-dir",
        default="../../temp/synthetic-250",
        help="Output directory for generated files (default: ../../temp/synthetic-250)"
    )
    parser.add_argument(
        "--schema",
        default="synthetic",
        help="PostgreSQL schema name (default: synthetic)"
    )
    
    args = parser.parse_args()
    
    # Resolve output directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.normpath(os.path.join(script_dir, args.output_dir))
    
    # Merge all domains
    all_domains = {}
    all_domains.update(DOMAINS)
    all_domains.update(DOMAINS_EXTENDED)
    all_domains.update(DOMAINS_MORE)
    all_domains.update(DOMAINS_EDUCATION)
    
    print(f"=" * 60)
    print(f"Synthetic 250-Table Database Generator")
    print(f"=" * 60)
    print()
    
    # Count tables
    total_tables = sum(len(d["tables"]) for d in all_domains.values())
    print(f"Domains: {len(all_domains)}")
    print(f"Tables:  {total_tables}")
    print()
    
    # Generate SQL
    print("Generating PostgreSQL DDL...")
    sql_content, all_tables = generate_schema_sql(all_domains, args.schema)
    
    # Generate documentation
    print("Generating documentation...")
    md_content = generate_summary_md(all_tables, args.schema)
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Write files
    sql_file = os.path.join(output_dir, "synthetic_250_postgres.sql")
    md_file = os.path.join(output_dir, "synthetic_250_summary.md")
    
    with open(sql_file, "w") as f:
        f.write(sql_content)
    print(f"✅ SQL file: {sql_file}")
    
    with open(md_file, "w") as f:
        f.write(md_content)
    print(f"✅ Summary: {md_file}")
    
    print()
    print(f"Generated {len(all_tables)} tables across {len(all_domains)} domains")
    print()
    print("Domain breakdown:")
    for domain_name, domain_def in all_domains.items():
        table_count = len(domain_def["tables"])
        print(f"  - {domain_name}: {table_count} tables")


if __name__ == "__main__":
    main()

