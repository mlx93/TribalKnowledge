-- ============================================================================
-- Synthetic 250-Table Database Schema
-- Generated: 2025-12-12 20:48:39
-- Schema: synthetic
-- ============================================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS "synthetic";

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ============================================================================
-- Domain: HUMAN RESOURCES MANAGEMENT
-- ============================================================================


-- Table: synthetic.employees
CREATE TABLE IF NOT EXISTS "synthetic"."employees" (
    "employee_id" SERIAL PRIMARY KEY,
    "first_name" VARCHAR(100) NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "email" VARCHAR(255) UNIQUE,
    "phone" VARCHAR(20),
    "hire_date" DATE NOT NULL,
    "termination_date" DATE,
    "birth_date" DATE,
    "gender" VARCHAR(10),
    "salary" DECIMAL(15,2),
    "department_id" INTEGER,
    "manager_id" INTEGER,
    "job_title_id" INTEGER,
    "employment_status" VARCHAR(20) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_employees_department_id" FOREIGN KEY ("department_id") REFERENCES "synthetic"."departments" ("department_id"),
    CONSTRAINT "fk_employees_manager_id" FOREIGN KEY ("manager_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_employees_job_title_id" FOREIGN KEY ("job_title_id") REFERENCES "synthetic"."job_titles" ("job_title_id")
);
CREATE INDEX IF NOT EXISTS "idx_employees_department_id" ON "synthetic"."employees" ("department_id");
CREATE INDEX IF NOT EXISTS "idx_employees_manager_id" ON "synthetic"."employees" ("manager_id");
CREATE INDEX IF NOT EXISTS "idx_employees_job_title_id" ON "synthetic"."employees" ("job_title_id");

-- Table: synthetic.departments
CREATE TABLE IF NOT EXISTS "synthetic"."departments" (
    "department_id" SERIAL PRIMARY KEY,
    "department_name" VARCHAR(100) NOT NULL UNIQUE,
    "department_code" VARCHAR(20) UNIQUE,
    "description" TEXT,
    "parent_department_id" INTEGER,
    "cost_center" VARCHAR(20),
    "location_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_departments_parent_department_id" FOREIGN KEY ("parent_department_id") REFERENCES "synthetic"."departments" ("department_id"),
    CONSTRAINT "fk_departments_location_id" FOREIGN KEY ("location_id") REFERENCES "synthetic"."office_locations" ("location_id")
);
CREATE INDEX IF NOT EXISTS "idx_departments_parent_department_id" ON "synthetic"."departments" ("parent_department_id");
CREATE INDEX IF NOT EXISTS "idx_departments_location_id" ON "synthetic"."departments" ("location_id");

-- Table: synthetic.job_titles
CREATE TABLE IF NOT EXISTS "synthetic"."job_titles" (
    "job_title_id" SERIAL PRIMARY KEY,
    "title" VARCHAR(100) NOT NULL,
    "job_family" VARCHAR(50),
    "job_level" INTEGER,
    "min_salary" DECIMAL(15,2),
    "max_salary" DECIMAL(15,2),
    "description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.office_locations
CREATE TABLE IF NOT EXISTS "synthetic"."office_locations" (
    "location_id" SERIAL PRIMARY KEY,
    "location_name" VARCHAR(100) NOT NULL,
    "address_line1" VARCHAR(255),
    "address_line2" VARCHAR(255),
    "city" VARCHAR(100),
    "state_province" VARCHAR(100),
    "postal_code" VARCHAR(20),
    "country_code" VARCHAR(3),
    "timezone" VARCHAR(50),
    "is_headquarters" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.salary_history
CREATE TABLE IF NOT EXISTS "synthetic"."salary_history" (
    "salary_history_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "effective_date" DATE NOT NULL,
    "end_date" DATE,
    "salary_amount" DECIMAL(15,2) NOT NULL,
    "currency" VARCHAR(3) DEFAULT 'USD',
    "change_reason" VARCHAR(100),
    "approved_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_salary_history_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_salary_history_approved_by" FOREIGN KEY ("approved_by") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_salary_history_employee_id" ON "synthetic"."salary_history" ("employee_id");
CREATE INDEX IF NOT EXISTS "idx_salary_history_approved_by" ON "synthetic"."salary_history" ("approved_by");

-- Table: synthetic.benefits_plans
CREATE TABLE IF NOT EXISTS "synthetic"."benefits_plans" (
    "plan_id" SERIAL PRIMARY KEY,
    "plan_name" VARCHAR(100) NOT NULL,
    "plan_type" VARCHAR(50),
    "provider_name" VARCHAR(100),
    "coverage_details" JSONB,
    "monthly_cost_employee" DECIMAL(10,2),
    "monthly_cost_employer" DECIMAL(10,2),
    "effective_date" DATE,
    "termination_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.employee_benefits
CREATE TABLE IF NOT EXISTS "synthetic"."employee_benefits" (
    "enrollment_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "plan_id" INTEGER NOT NULL,
    "enrollment_date" DATE NOT NULL,
    "coverage_level" VARCHAR(50),
    "dependents_count" INTEGER DEFAULT 0,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_employee_benefits_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_employee_benefits_plan_id" FOREIGN KEY ("plan_id") REFERENCES "synthetic"."benefits_plans" ("plan_id")
);
CREATE INDEX IF NOT EXISTS "idx_employee_benefits_employee_id" ON "synthetic"."employee_benefits" ("employee_id");
CREATE INDEX IF NOT EXISTS "idx_employee_benefits_plan_id" ON "synthetic"."employee_benefits" ("plan_id");

-- Table: synthetic.time_off_requests
CREATE TABLE IF NOT EXISTS "synthetic"."time_off_requests" (
    "request_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "request_type" VARCHAR(50) NOT NULL,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,
    "hours_requested" DECIMAL(5,2),
    "status" VARCHAR(20) DEFAULT 'pending',
    "approved_by" INTEGER,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_time_off_requests_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_time_off_requests_approved_by" FOREIGN KEY ("approved_by") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_time_off_requests_employee_id" ON "synthetic"."time_off_requests" ("employee_id");
CREATE INDEX IF NOT EXISTS "idx_time_off_requests_approved_by" ON "synthetic"."time_off_requests" ("approved_by");

-- Table: synthetic.time_off_balances
CREATE TABLE IF NOT EXISTS "synthetic"."time_off_balances" (
    "balance_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "leave_type" VARCHAR(50) NOT NULL,
    "fiscal_year" INTEGER NOT NULL,
    "hours_accrued" DECIMAL(6,2) DEFAULT 0,
    "hours_used" DECIMAL(6,2) DEFAULT 0,
    "hours_carried_over" DECIMAL(6,2) DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_time_off_balances_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_time_off_balances_employee_id" ON "synthetic"."time_off_balances" ("employee_id");

-- Table: synthetic.performance_reviews
CREATE TABLE IF NOT EXISTS "synthetic"."performance_reviews" (
    "review_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "reviewer_id" INTEGER NOT NULL,
    "review_period_start" DATE,
    "review_period_end" DATE,
    "review_date" DATE,
    "overall_rating" DECIMAL(3,2),
    "goals_met_percentage" INTEGER,
    "comments" TEXT,
    "status" VARCHAR(20) DEFAULT 'draft',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_performance_reviews_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_performance_reviews_reviewer_id" FOREIGN KEY ("reviewer_id") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_performance_reviews_employee_id" ON "synthetic"."performance_reviews" ("employee_id");
CREATE INDEX IF NOT EXISTS "idx_performance_reviews_reviewer_id" ON "synthetic"."performance_reviews" ("reviewer_id");

-- Table: synthetic.performance_goals
CREATE TABLE IF NOT EXISTS "synthetic"."performance_goals" (
    "goal_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "goal_title" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "category" VARCHAR(50),
    "target_date" DATE,
    "completion_percentage" INTEGER DEFAULT 0,
    "status" VARCHAR(20) DEFAULT 'active',
    "weight" DECIMAL(5,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_performance_goals_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_performance_goals_employee_id" ON "synthetic"."performance_goals" ("employee_id");

-- Table: synthetic.training_courses
CREATE TABLE IF NOT EXISTS "synthetic"."training_courses" (
    "course_id" SERIAL PRIMARY KEY,
    "course_name" VARCHAR(200) NOT NULL,
    "course_code" VARCHAR(50) UNIQUE,
    "description" TEXT,
    "category" VARCHAR(100),
    "duration_hours" DECIMAL(5,2),
    "is_mandatory" BOOLEAN DEFAULT false,
    "provider" VARCHAR(100),
    "cost" DECIMAL(10,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.employee_training
CREATE TABLE IF NOT EXISTS "synthetic"."employee_training" (
    "enrollment_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "course_id" INTEGER NOT NULL,
    "enrollment_date" DATE,
    "completion_date" DATE,
    "score" DECIMAL(5,2),
    "status" VARCHAR(20) DEFAULT 'enrolled',
    "certificate_number" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_employee_training_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_employee_training_course_id" FOREIGN KEY ("course_id") REFERENCES "synthetic"."training_courses" ("course_id")
);
CREATE INDEX IF NOT EXISTS "idx_employee_training_employee_id" ON "synthetic"."employee_training" ("employee_id");
CREATE INDEX IF NOT EXISTS "idx_employee_training_course_id" ON "synthetic"."employee_training" ("course_id");

-- Table: synthetic.skills
CREATE TABLE IF NOT EXISTS "synthetic"."skills" (
    "skill_id" SERIAL PRIMARY KEY,
    "skill_name" VARCHAR(100) NOT NULL UNIQUE,
    "category" VARCHAR(50),
    "description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.employee_skills
CREATE TABLE IF NOT EXISTS "synthetic"."employee_skills" (
    "employee_skill_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "skill_id" INTEGER NOT NULL,
    "proficiency_level" INTEGER,
    "years_experience" DECIMAL(4,1),
    "last_used_date" DATE,
    "is_primary" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_employee_skills_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_employee_skills_skill_id" FOREIGN KEY ("skill_id") REFERENCES "synthetic"."skills" ("skill_id")
);
CREATE INDEX IF NOT EXISTS "idx_employee_skills_employee_id" ON "synthetic"."employee_skills" ("employee_id");
CREATE INDEX IF NOT EXISTS "idx_employee_skills_skill_id" ON "synthetic"."employee_skills" ("skill_id");

-- Table: synthetic.job_postings
CREATE TABLE IF NOT EXISTS "synthetic"."job_postings" (
    "posting_id" SERIAL PRIMARY KEY,
    "job_title_id" INTEGER,
    "department_id" INTEGER,
    "location_id" INTEGER,
    "posting_title" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "requirements" TEXT,
    "salary_min" DECIMAL(15,2),
    "salary_max" DECIMAL(15,2),
    "employment_type" VARCHAR(50),
    "posted_date" DATE,
    "closing_date" DATE,
    "status" VARCHAR(20) DEFAULT 'open',
    "hiring_manager_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_job_postings_job_title_id" FOREIGN KEY ("job_title_id") REFERENCES "synthetic"."job_titles" ("job_title_id"),
    CONSTRAINT "fk_job_postings_department_id" FOREIGN KEY ("department_id") REFERENCES "synthetic"."departments" ("department_id"),
    CONSTRAINT "fk_job_postings_location_id" FOREIGN KEY ("location_id") REFERENCES "synthetic"."office_locations" ("location_id"),
    CONSTRAINT "fk_job_postings_hiring_manager_id" FOREIGN KEY ("hiring_manager_id") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_job_postings_job_title_id" ON "synthetic"."job_postings" ("job_title_id");
CREATE INDEX IF NOT EXISTS "idx_job_postings_department_id" ON "synthetic"."job_postings" ("department_id");
CREATE INDEX IF NOT EXISTS "idx_job_postings_location_id" ON "synthetic"."job_postings" ("location_id");
CREATE INDEX IF NOT EXISTS "idx_job_postings_hiring_manager_id" ON "synthetic"."job_postings" ("hiring_manager_id");

-- Table: synthetic.job_applicants
CREATE TABLE IF NOT EXISTS "synthetic"."job_applicants" (
    "applicant_id" SERIAL PRIMARY KEY,
    "first_name" VARCHAR(100) NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "phone" VARCHAR(20),
    "resume_url" VARCHAR(500),
    "linkedin_url" VARCHAR(500),
    "source" VARCHAR(100),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.job_applications
CREATE TABLE IF NOT EXISTS "synthetic"."job_applications" (
    "application_id" SERIAL PRIMARY KEY,
    "posting_id" INTEGER NOT NULL,
    "applicant_id" INTEGER NOT NULL,
    "application_date" DATE NOT NULL,
    "status" VARCHAR(50) DEFAULT 'new',
    "cover_letter" TEXT,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_job_applications_posting_id" FOREIGN KEY ("posting_id") REFERENCES "synthetic"."job_postings" ("posting_id"),
    CONSTRAINT "fk_job_applications_applicant_id" FOREIGN KEY ("applicant_id") REFERENCES "synthetic"."job_applicants" ("applicant_id")
);
CREATE INDEX IF NOT EXISTS "idx_job_applications_posting_id" ON "synthetic"."job_applications" ("posting_id");
CREATE INDEX IF NOT EXISTS "idx_job_applications_applicant_id" ON "synthetic"."job_applications" ("applicant_id");

-- Table: synthetic.interviews
CREATE TABLE IF NOT EXISTS "synthetic"."interviews" (
    "interview_id" SERIAL PRIMARY KEY,
    "application_id" INTEGER NOT NULL,
    "interviewer_id" INTEGER NOT NULL,
    "interview_type" VARCHAR(50),
    "scheduled_date" TIMESTAMP,
    "duration_minutes" INTEGER,
    "location" VARCHAR(200),
    "status" VARCHAR(20) DEFAULT 'scheduled',
    "rating" INTEGER,
    "feedback" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_interviews_application_id" FOREIGN KEY ("application_id") REFERENCES "synthetic"."job_applications" ("application_id"),
    CONSTRAINT "fk_interviews_interviewer_id" FOREIGN KEY ("interviewer_id") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_interviews_application_id" ON "synthetic"."interviews" ("application_id");
CREATE INDEX IF NOT EXISTS "idx_interviews_interviewer_id" ON "synthetic"."interviews" ("interviewer_id");

-- Table: synthetic.employee_documents
CREATE TABLE IF NOT EXISTS "synthetic"."employee_documents" (
    "document_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "document_type" VARCHAR(50) NOT NULL,
    "document_name" VARCHAR(200),
    "file_path" VARCHAR(500),
    "upload_date" DATE,
    "expiration_date" DATE,
    "is_verified" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_employee_documents_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_employee_documents_employee_id" ON "synthetic"."employee_documents" ("employee_id");

-- Table: synthetic.emergency_contacts
CREATE TABLE IF NOT EXISTS "synthetic"."emergency_contacts" (
    "contact_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "contact_name" VARCHAR(200) NOT NULL,
    "relationship" VARCHAR(50),
    "phone_primary" VARCHAR(20),
    "phone_secondary" VARCHAR(20),
    "email" VARCHAR(255),
    "is_primary" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_emergency_contacts_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_emergency_contacts_employee_id" ON "synthetic"."emergency_contacts" ("employee_id");

-- Table: synthetic.expense_reports
CREATE TABLE IF NOT EXISTS "synthetic"."expense_reports" (
    "report_id" SERIAL PRIMARY KEY,
    "employee_id" INTEGER NOT NULL,
    "report_title" VARCHAR(200),
    "submission_date" DATE,
    "total_amount" DECIMAL(15,2),
    "currency" VARCHAR(3) DEFAULT 'USD',
    "status" VARCHAR(20) DEFAULT 'pending',
    "approved_by" INTEGER,
    "approved_date" DATE,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_expense_reports_employee_id" FOREIGN KEY ("employee_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_expense_reports_approved_by" FOREIGN KEY ("approved_by") REFERENCES "synthetic"."employees" ("employee_id")
);
CREATE INDEX IF NOT EXISTS "idx_expense_reports_employee_id" ON "synthetic"."expense_reports" ("employee_id");
CREATE INDEX IF NOT EXISTS "idx_expense_reports_approved_by" ON "synthetic"."expense_reports" ("approved_by");

-- Table: synthetic.expense_items
CREATE TABLE IF NOT EXISTS "synthetic"."expense_items" (
    "item_id" SERIAL PRIMARY KEY,
    "report_id" INTEGER NOT NULL,
    "expense_date" DATE NOT NULL,
    "category" VARCHAR(50),
    "description" VARCHAR(500),
    "amount" DECIMAL(10,2) NOT NULL,
    "receipt_url" VARCHAR(500),
    "is_billable" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_expense_items_report_id" FOREIGN KEY ("report_id") REFERENCES "synthetic"."expense_reports" ("report_id")
);
CREATE INDEX IF NOT EXISTS "idx_expense_items_report_id" ON "synthetic"."expense_items" ("report_id");

-- Table: synthetic.org_announcements
CREATE TABLE IF NOT EXISTS "synthetic"."org_announcements" (
    "announcement_id" SERIAL PRIMARY KEY,
    "title" VARCHAR(200) NOT NULL,
    "content" TEXT,
    "author_id" INTEGER,
    "publish_date" TIMESTAMP,
    "expiry_date" TIMESTAMP,
    "priority" VARCHAR(20) DEFAULT 'normal',
    "target_department_id" INTEGER,
    "is_pinned" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_org_announcements_author_id" FOREIGN KEY ("author_id") REFERENCES "synthetic"."employees" ("employee_id"),
    CONSTRAINT "fk_org_announcements_target_department_id" FOREIGN KEY ("target_department_id") REFERENCES "synthetic"."departments" ("department_id")
);
CREATE INDEX IF NOT EXISTS "idx_org_announcements_author_id" ON "synthetic"."org_announcements" ("author_id");
CREATE INDEX IF NOT EXISTS "idx_org_announcements_target_department_id" ON "synthetic"."org_announcements" ("target_department_id");

-- Table: synthetic.org_policies
CREATE TABLE IF NOT EXISTS "synthetic"."org_policies" (
    "policy_id" SERIAL PRIMARY KEY,
    "policy_code" VARCHAR(50) UNIQUE,
    "policy_name" VARCHAR(200) NOT NULL,
    "category" VARCHAR(100),
    "content" TEXT,
    "effective_date" DATE,
    "review_date" DATE,
    "version" VARCHAR(20),
    "status" VARCHAR(20) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- Domain: FINANCE AND ACCOUNTING
-- ============================================================================


-- Table: synthetic.chart_of_accounts
CREATE TABLE IF NOT EXISTS "synthetic"."chart_of_accounts" (
    "account_id" SERIAL PRIMARY KEY,
    "account_number" VARCHAR(20) NOT NULL UNIQUE,
    "account_name" VARCHAR(200) NOT NULL,
    "account_type" VARCHAR(50) NOT NULL,
    "parent_account_id" INTEGER,
    "description" TEXT,
    "is_active" BOOLEAN DEFAULT true,
    "normal_balance" VARCHAR(10),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_chart_of_accounts_parent_account_id" FOREIGN KEY ("parent_account_id") REFERENCES "synthetic"."chart_of_accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_chart_of_accounts_parent_account_id" ON "synthetic"."chart_of_accounts" ("parent_account_id");

-- Table: synthetic.fiscal_periods
CREATE TABLE IF NOT EXISTS "synthetic"."fiscal_periods" (
    "period_id" SERIAL PRIMARY KEY,
    "period_name" VARCHAR(50) NOT NULL,
    "fiscal_year" INTEGER NOT NULL,
    "period_number" INTEGER NOT NULL,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,
    "is_closed" BOOLEAN DEFAULT false,
    "closed_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.journal_entries
CREATE TABLE IF NOT EXISTS "synthetic"."journal_entries" (
    "entry_id" SERIAL PRIMARY KEY,
    "entry_number" VARCHAR(50) UNIQUE,
    "entry_date" DATE NOT NULL,
    "period_id" INTEGER,
    "description" TEXT,
    "source" VARCHAR(50),
    "reference_number" VARCHAR(100),
    "status" VARCHAR(20) DEFAULT 'draft',
    "posted_by" INTEGER,
    "posted_date" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_journal_entries_period_id" FOREIGN KEY ("period_id") REFERENCES "synthetic"."fiscal_periods" ("period_id")
);
CREATE INDEX IF NOT EXISTS "idx_journal_entries_period_id" ON "synthetic"."journal_entries" ("period_id");

-- Table: synthetic.journal_entry_lines
CREATE TABLE IF NOT EXISTS "synthetic"."journal_entry_lines" (
    "line_id" SERIAL PRIMARY KEY,
    "entry_id" INTEGER NOT NULL,
    "account_id" INTEGER NOT NULL,
    "debit_amount" DECIMAL(15,2) DEFAULT 0,
    "credit_amount" DECIMAL(15,2) DEFAULT 0,
    "description" VARCHAR(500),
    "cost_center" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_journal_entry_lines_entry_id" FOREIGN KEY ("entry_id") REFERENCES "synthetic"."journal_entries" ("entry_id"),
    CONSTRAINT "fk_journal_entry_lines_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."chart_of_accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_journal_entry_lines_entry_id" ON "synthetic"."journal_entry_lines" ("entry_id");
CREATE INDEX IF NOT EXISTS "idx_journal_entry_lines_account_id" ON "synthetic"."journal_entry_lines" ("account_id");

-- Table: synthetic.vendors
CREATE TABLE IF NOT EXISTS "synthetic"."vendors" (
    "vendor_id" SERIAL PRIMARY KEY,
    "vendor_code" VARCHAR(50) UNIQUE,
    "vendor_name" VARCHAR(200) NOT NULL,
    "contact_name" VARCHAR(200),
    "email" VARCHAR(255),
    "phone" VARCHAR(20),
    "address_line1" VARCHAR(255),
    "city" VARCHAR(100),
    "state" VARCHAR(100),
    "postal_code" VARCHAR(20),
    "country" VARCHAR(100),
    "tax_id" VARCHAR(50),
    "payment_terms" VARCHAR(50),
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.invoices_payable
CREATE TABLE IF NOT EXISTS "synthetic"."invoices_payable" (
    "invoice_id" SERIAL PRIMARY KEY,
    "invoice_number" VARCHAR(100) NOT NULL,
    "vendor_id" INTEGER NOT NULL,
    "invoice_date" DATE NOT NULL,
    "due_date" DATE,
    "total_amount" DECIMAL(15,2) NOT NULL,
    "tax_amount" DECIMAL(15,2) DEFAULT 0,
    "currency" VARCHAR(3) DEFAULT 'USD',
    "status" VARCHAR(20) DEFAULT 'pending',
    "payment_date" DATE,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_invoices_payable_vendor_id" FOREIGN KEY ("vendor_id") REFERENCES "synthetic"."vendors" ("vendor_id")
);
CREATE INDEX IF NOT EXISTS "idx_invoices_payable_vendor_id" ON "synthetic"."invoices_payable" ("vendor_id");

-- Table: synthetic.invoice_payable_lines
CREATE TABLE IF NOT EXISTS "synthetic"."invoice_payable_lines" (
    "line_id" SERIAL PRIMARY KEY,
    "invoice_id" INTEGER NOT NULL,
    "account_id" INTEGER,
    "description" VARCHAR(500),
    "quantity" DECIMAL(10,2) DEFAULT 1,
    "unit_price" DECIMAL(15,4),
    "amount" DECIMAL(15,2) NOT NULL,
    "cost_center" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_invoice_payable_lines_invoice_id" FOREIGN KEY ("invoice_id") REFERENCES "synthetic"."invoices_payable" ("invoice_id"),
    CONSTRAINT "fk_invoice_payable_lines_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."chart_of_accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_invoice_payable_lines_invoice_id" ON "synthetic"."invoice_payable_lines" ("invoice_id");
CREATE INDEX IF NOT EXISTS "idx_invoice_payable_lines_account_id" ON "synthetic"."invoice_payable_lines" ("account_id");

-- Table: synthetic.vendor_payments
CREATE TABLE IF NOT EXISTS "synthetic"."vendor_payments" (
    "payment_id" SERIAL PRIMARY KEY,
    "payment_number" VARCHAR(50) UNIQUE,
    "vendor_id" INTEGER NOT NULL,
    "payment_date" DATE NOT NULL,
    "payment_method" VARCHAR(50),
    "total_amount" DECIMAL(15,2) NOT NULL,
    "currency" VARCHAR(3) DEFAULT 'USD',
    "bank_account_id" INTEGER,
    "reference_number" VARCHAR(100),
    "status" VARCHAR(20) DEFAULT 'completed',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_vendor_payments_vendor_id" FOREIGN KEY ("vendor_id") REFERENCES "synthetic"."vendors" ("vendor_id"),
    CONSTRAINT "fk_vendor_payments_bank_account_id" FOREIGN KEY ("bank_account_id") REFERENCES "synthetic"."bank_accounts" ("bank_account_id")
);
CREATE INDEX IF NOT EXISTS "idx_vendor_payments_vendor_id" ON "synthetic"."vendor_payments" ("vendor_id");
CREATE INDEX IF NOT EXISTS "idx_vendor_payments_bank_account_id" ON "synthetic"."vendor_payments" ("bank_account_id");

-- Table: synthetic.payment_allocations
CREATE TABLE IF NOT EXISTS "synthetic"."payment_allocations" (
    "allocation_id" SERIAL PRIMARY KEY,
    "payment_id" INTEGER NOT NULL,
    "invoice_id" INTEGER NOT NULL,
    "amount" DECIMAL(15,2) NOT NULL,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_payment_allocations_payment_id" FOREIGN KEY ("payment_id") REFERENCES "synthetic"."vendor_payments" ("payment_id"),
    CONSTRAINT "fk_payment_allocations_invoice_id" FOREIGN KEY ("invoice_id") REFERENCES "synthetic"."invoices_payable" ("invoice_id")
);
CREATE INDEX IF NOT EXISTS "idx_payment_allocations_payment_id" ON "synthetic"."payment_allocations" ("payment_id");
CREATE INDEX IF NOT EXISTS "idx_payment_allocations_invoice_id" ON "synthetic"."payment_allocations" ("invoice_id");

-- Table: synthetic.bank_accounts
CREATE TABLE IF NOT EXISTS "synthetic"."bank_accounts" (
    "bank_account_id" SERIAL PRIMARY KEY,
    "account_name" VARCHAR(200) NOT NULL,
    "account_number" VARCHAR(50),
    "routing_number" VARCHAR(50),
    "bank_name" VARCHAR(200),
    "account_type" VARCHAR(50),
    "currency" VARCHAR(3) DEFAULT 'USD',
    "current_balance" DECIMAL(15,2) DEFAULT 0,
    "gl_account_id" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_bank_accounts_gl_account_id" FOREIGN KEY ("gl_account_id") REFERENCES "synthetic"."chart_of_accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_bank_accounts_gl_account_id" ON "synthetic"."bank_accounts" ("gl_account_id");

-- Table: synthetic.bank_transactions
CREATE TABLE IF NOT EXISTS "synthetic"."bank_transactions" (
    "transaction_id" SERIAL PRIMARY KEY,
    "bank_account_id" INTEGER NOT NULL,
    "transaction_date" DATE NOT NULL,
    "transaction_type" VARCHAR(50),
    "amount" DECIMAL(15,2) NOT NULL,
    "description" VARCHAR(500),
    "reference_number" VARCHAR(100),
    "is_reconciled" BOOLEAN DEFAULT false,
    "reconciled_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_bank_transactions_bank_account_id" FOREIGN KEY ("bank_account_id") REFERENCES "synthetic"."bank_accounts" ("bank_account_id")
);
CREATE INDEX IF NOT EXISTS "idx_bank_transactions_bank_account_id" ON "synthetic"."bank_transactions" ("bank_account_id");

-- Table: synthetic.bank_reconciliations
CREATE TABLE IF NOT EXISTS "synthetic"."bank_reconciliations" (
    "reconciliation_id" SERIAL PRIMARY KEY,
    "bank_account_id" INTEGER NOT NULL,
    "statement_date" DATE NOT NULL,
    "statement_balance" DECIMAL(15,2) NOT NULL,
    "book_balance" DECIMAL(15,2),
    "difference" DECIMAL(15,2),
    "status" VARCHAR(20) DEFAULT 'in_progress',
    "completed_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_bank_reconciliations_bank_account_id" FOREIGN KEY ("bank_account_id") REFERENCES "synthetic"."bank_accounts" ("bank_account_id")
);
CREATE INDEX IF NOT EXISTS "idx_bank_reconciliations_bank_account_id" ON "synthetic"."bank_reconciliations" ("bank_account_id");

-- Table: synthetic.budgets
CREATE TABLE IF NOT EXISTS "synthetic"."budgets" (
    "budget_id" SERIAL PRIMARY KEY,
    "budget_name" VARCHAR(200) NOT NULL,
    "fiscal_year" INTEGER NOT NULL,
    "department_id" INTEGER,
    "status" VARCHAR(20) DEFAULT 'draft',
    "approved_by" INTEGER,
    "approved_date" DATE,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.budget_lines
CREATE TABLE IF NOT EXISTS "synthetic"."budget_lines" (
    "budget_line_id" SERIAL PRIMARY KEY,
    "budget_id" INTEGER NOT NULL,
    "account_id" INTEGER NOT NULL,
    "period_id" INTEGER,
    "budgeted_amount" DECIMAL(15,2) NOT NULL,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_budget_lines_budget_id" FOREIGN KEY ("budget_id") REFERENCES "synthetic"."budgets" ("budget_id"),
    CONSTRAINT "fk_budget_lines_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."chart_of_accounts" ("account_id"),
    CONSTRAINT "fk_budget_lines_period_id" FOREIGN KEY ("period_id") REFERENCES "synthetic"."fiscal_periods" ("period_id")
);
CREATE INDEX IF NOT EXISTS "idx_budget_lines_budget_id" ON "synthetic"."budget_lines" ("budget_id");
CREATE INDEX IF NOT EXISTS "idx_budget_lines_account_id" ON "synthetic"."budget_lines" ("account_id");
CREATE INDEX IF NOT EXISTS "idx_budget_lines_period_id" ON "synthetic"."budget_lines" ("period_id");

-- Table: synthetic.fixed_assets
CREATE TABLE IF NOT EXISTS "synthetic"."fixed_assets" (
    "asset_id" SERIAL PRIMARY KEY,
    "asset_tag" VARCHAR(50) UNIQUE,
    "asset_name" VARCHAR(200) NOT NULL,
    "category" VARCHAR(100),
    "acquisition_date" DATE,
    "acquisition_cost" DECIMAL(15,2),
    "useful_life_years" INTEGER,
    "salvage_value" DECIMAL(15,2) DEFAULT 0,
    "depreciation_method" VARCHAR(50),
    "accumulated_depreciation" DECIMAL(15,2) DEFAULT 0,
    "current_value" DECIMAL(15,2),
    "location" VARCHAR(200),
    "status" VARCHAR(20) DEFAULT 'active',
    "disposal_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.depreciation_schedule
CREATE TABLE IF NOT EXISTS "synthetic"."depreciation_schedule" (
    "schedule_id" SERIAL PRIMARY KEY,
    "asset_id" INTEGER NOT NULL,
    "period_id" INTEGER,
    "depreciation_date" DATE NOT NULL,
    "depreciation_amount" DECIMAL(15,2) NOT NULL,
    "accumulated_total" DECIMAL(15,2),
    "book_value" DECIMAL(15,2),
    "is_posted" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_depreciation_schedule_asset_id" FOREIGN KEY ("asset_id") REFERENCES "synthetic"."fixed_assets" ("asset_id"),
    CONSTRAINT "fk_depreciation_schedule_period_id" FOREIGN KEY ("period_id") REFERENCES "synthetic"."fiscal_periods" ("period_id")
);
CREATE INDEX IF NOT EXISTS "idx_depreciation_schedule_asset_id" ON "synthetic"."depreciation_schedule" ("asset_id");
CREATE INDEX IF NOT EXISTS "idx_depreciation_schedule_period_id" ON "synthetic"."depreciation_schedule" ("period_id");

-- Table: synthetic.tax_rates
CREATE TABLE IF NOT EXISTS "synthetic"."tax_rates" (
    "tax_rate_id" SERIAL PRIMARY KEY,
    "tax_code" VARCHAR(20) UNIQUE,
    "tax_name" VARCHAR(100) NOT NULL,
    "rate_percentage" DECIMAL(6,4) NOT NULL,
    "tax_type" VARCHAR(50),
    "jurisdiction" VARCHAR(100),
    "effective_date" DATE,
    "end_date" DATE,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.currencies
CREATE TABLE IF NOT EXISTS "synthetic"."currencies" (
    "currency_code" VARCHAR(3) PRIMARY KEY,
    "currency_name" VARCHAR(100) NOT NULL,
    "symbol" VARCHAR(10),
    "decimal_places" INTEGER DEFAULT 2,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.exchange_rates
CREATE TABLE IF NOT EXISTS "synthetic"."exchange_rates" (
    "rate_id" SERIAL PRIMARY KEY,
    "from_currency" VARCHAR(3) NOT NULL,
    "to_currency" VARCHAR(3) NOT NULL,
    "rate_date" DATE NOT NULL,
    "exchange_rate" DECIMAL(18,8) NOT NULL,
    "source" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_exchange_rates_from_currency" FOREIGN KEY ("from_currency") REFERENCES "synthetic"."currencies" ("currency_code"),
    CONSTRAINT "fk_exchange_rates_to_currency" FOREIGN KEY ("to_currency") REFERENCES "synthetic"."currencies" ("currency_code")
);
CREATE INDEX IF NOT EXISTS "idx_exchange_rates_from_currency" ON "synthetic"."exchange_rates" ("from_currency");
CREATE INDEX IF NOT EXISTS "idx_exchange_rates_to_currency" ON "synthetic"."exchange_rates" ("to_currency");

-- Table: synthetic.cost_centers
CREATE TABLE IF NOT EXISTS "synthetic"."cost_centers" (
    "cost_center_id" SERIAL PRIMARY KEY,
    "cost_center_code" VARCHAR(50) UNIQUE,
    "cost_center_name" VARCHAR(200) NOT NULL,
    "parent_id" INTEGER,
    "manager_id" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_cost_centers_parent_id" FOREIGN KEY ("parent_id") REFERENCES "synthetic"."cost_centers" ("cost_center_id")
);
CREATE INDEX IF NOT EXISTS "idx_cost_centers_parent_id" ON "synthetic"."cost_centers" ("parent_id");

-- Table: synthetic.projects_financial
CREATE TABLE IF NOT EXISTS "synthetic"."projects_financial" (
    "project_id" SERIAL PRIMARY KEY,
    "project_code" VARCHAR(50) UNIQUE,
    "project_name" VARCHAR(200) NOT NULL,
    "client_id" INTEGER,
    "start_date" DATE,
    "end_date" DATE,
    "budgeted_amount" DECIMAL(15,2),
    "actual_amount" DECIMAL(15,2) DEFAULT 0,
    "status" VARCHAR(20) DEFAULT 'active',
    "billing_type" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.project_costs
CREATE TABLE IF NOT EXISTS "synthetic"."project_costs" (
    "cost_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "cost_date" DATE NOT NULL,
    "cost_category" VARCHAR(100),
    "description" VARCHAR(500),
    "amount" DECIMAL(15,2) NOT NULL,
    "is_billable" BOOLEAN DEFAULT true,
    "invoice_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_costs_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."projects_financial" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_costs_project_id" ON "synthetic"."project_costs" ("project_id");

-- Table: synthetic.audit_trail
CREATE TABLE IF NOT EXISTS "synthetic"."audit_trail" (
    "audit_id" SERIAL PRIMARY KEY,
    "table_name" VARCHAR(100) NOT NULL,
    "record_id" INTEGER,
    "action" VARCHAR(20) NOT NULL,
    "old_values" JSONB,
    "new_values" JSONB,
    "changed_by" INTEGER,
    "changed_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "ip_address" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.financial_reports
CREATE TABLE IF NOT EXISTS "synthetic"."financial_reports" (
    "report_id" SERIAL PRIMARY KEY,
    "report_name" VARCHAR(200) NOT NULL,
    "report_type" VARCHAR(50),
    "period_id" INTEGER,
    "generated_date" TIMESTAMP,
    "generated_by" INTEGER,
    "parameters" JSONB,
    "file_path" VARCHAR(500),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_financial_reports_period_id" FOREIGN KEY ("period_id") REFERENCES "synthetic"."fiscal_periods" ("period_id")
);
CREATE INDEX IF NOT EXISTS "idx_financial_reports_period_id" ON "synthetic"."financial_reports" ("period_id");

-- Table: synthetic.intercompany_accounts
CREATE TABLE IF NOT EXISTS "synthetic"."intercompany_accounts" (
    "ic_account_id" SERIAL PRIMARY KEY,
    "entity_from" VARCHAR(100) NOT NULL,
    "entity_to" VARCHAR(100) NOT NULL,
    "gl_account_id" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_intercompany_accounts_gl_account_id" FOREIGN KEY ("gl_account_id") REFERENCES "synthetic"."chart_of_accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_intercompany_accounts_gl_account_id" ON "synthetic"."intercompany_accounts" ("gl_account_id");

-- Table: synthetic.intercompany_transactions
CREATE TABLE IF NOT EXISTS "synthetic"."intercompany_transactions" (
    "ic_transaction_id" SERIAL PRIMARY KEY,
    "ic_account_id" INTEGER NOT NULL,
    "transaction_date" DATE NOT NULL,
    "amount" DECIMAL(15,2) NOT NULL,
    "description" VARCHAR(500),
    "reference_number" VARCHAR(100),
    "status" VARCHAR(20) DEFAULT 'pending',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_intercompany_transactions_ic_account_id" FOREIGN KEY ("ic_account_id") REFERENCES "synthetic"."intercompany_accounts" ("ic_account_id")
);
CREATE INDEX IF NOT EXISTS "idx_intercompany_transactions_ic_account_id" ON "synthetic"."intercompany_transactions" ("ic_account_id");

-- Table: synthetic.payment_terms
CREATE TABLE IF NOT EXISTS "synthetic"."payment_terms" (
    "term_id" SERIAL PRIMARY KEY,
    "term_code" VARCHAR(20) UNIQUE,
    "term_name" VARCHAR(100) NOT NULL,
    "days_due" INTEGER,
    "discount_percentage" DECIMAL(5,2) DEFAULT 0,
    "discount_days" INTEGER,
    "description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.credit_memos
CREATE TABLE IF NOT EXISTS "synthetic"."credit_memos" (
    "memo_id" SERIAL PRIMARY KEY,
    "memo_number" VARCHAR(50) UNIQUE,
    "vendor_id" INTEGER,
    "original_invoice_id" INTEGER,
    "memo_date" DATE NOT NULL,
    "amount" DECIMAL(15,2) NOT NULL,
    "reason" TEXT,
    "status" VARCHAR(20) DEFAULT 'open',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_credit_memos_vendor_id" FOREIGN KEY ("vendor_id") REFERENCES "synthetic"."vendors" ("vendor_id"),
    CONSTRAINT "fk_credit_memos_original_invoice_id" FOREIGN KEY ("original_invoice_id") REFERENCES "synthetic"."invoices_payable" ("invoice_id")
);
CREATE INDEX IF NOT EXISTS "idx_credit_memos_vendor_id" ON "synthetic"."credit_memos" ("vendor_id");
CREATE INDEX IF NOT EXISTS "idx_credit_memos_original_invoice_id" ON "synthetic"."credit_memos" ("original_invoice_id");

-- Table: synthetic.recurring_entries
CREATE TABLE IF NOT EXISTS "synthetic"."recurring_entries" (
    "recurring_id" SERIAL PRIMARY KEY,
    "entry_name" VARCHAR(200) NOT NULL,
    "frequency" VARCHAR(20),
    "next_date" DATE,
    "end_date" DATE,
    "template_entry_id" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "last_generated" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_recurring_entries_template_entry_id" FOREIGN KEY ("template_entry_id") REFERENCES "synthetic"."journal_entries" ("entry_id")
);
CREATE INDEX IF NOT EXISTS "idx_recurring_entries_template_entry_id" ON "synthetic"."recurring_entries" ("template_entry_id");

-- ============================================================================
-- Domain: E-COMMERCE AND ONLINE RETAIL
-- ============================================================================


-- Table: synthetic.customers
CREATE TABLE IF NOT EXISTS "synthetic"."customers" (
    "customer_id" SERIAL PRIMARY KEY,
    "email" VARCHAR(255) NOT NULL UNIQUE,
    "password_hash" VARCHAR(255),
    "first_name" VARCHAR(100),
    "last_name" VARCHAR(100),
    "phone" VARCHAR(20),
    "date_of_birth" DATE,
    "gender" VARCHAR(10),
    "registration_date" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "last_login" TIMESTAMP,
    "is_verified" BOOLEAN DEFAULT false,
    "is_active" BOOLEAN DEFAULT true,
    "customer_tier" VARCHAR(20) DEFAULT 'standard',
    "total_orders" INTEGER DEFAULT 0,
    "total_spent" DECIMAL(15,2) DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.customer_addresses
CREATE TABLE IF NOT EXISTS "synthetic"."customer_addresses" (
    "address_id" SERIAL PRIMARY KEY,
    "customer_id" INTEGER NOT NULL,
    "address_type" VARCHAR(20) DEFAULT 'shipping',
    "address_line1" VARCHAR(255) NOT NULL,
    "address_line2" VARCHAR(255),
    "city" VARCHAR(100) NOT NULL,
    "state_province" VARCHAR(100),
    "postal_code" VARCHAR(20),
    "country_code" VARCHAR(3) NOT NULL,
    "is_default" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_customer_addresses_customer_id" FOREIGN KEY ("customer_id") REFERENCES "synthetic"."customers" ("customer_id")
);
CREATE INDEX IF NOT EXISTS "idx_customer_addresses_customer_id" ON "synthetic"."customer_addresses" ("customer_id");

-- Table: synthetic.product_categories
CREATE TABLE IF NOT EXISTS "synthetic"."product_categories" (
    "category_id" SERIAL PRIMARY KEY,
    "category_name" VARCHAR(200) NOT NULL,
    "slug" VARCHAR(200) UNIQUE,
    "parent_category_id" INTEGER,
    "description" TEXT,
    "image_url" VARCHAR(500),
    "sort_order" INTEGER DEFAULT 0,
    "is_active" BOOLEAN DEFAULT true,
    "meta_title" VARCHAR(200),
    "meta_description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_product_categories_parent_category_id" FOREIGN KEY ("parent_category_id") REFERENCES "synthetic"."product_categories" ("category_id")
);
CREATE INDEX IF NOT EXISTS "idx_product_categories_parent_category_id" ON "synthetic"."product_categories" ("parent_category_id");

-- Table: synthetic.brands
CREATE TABLE IF NOT EXISTS "synthetic"."brands" (
    "brand_id" SERIAL PRIMARY KEY,
    "brand_name" VARCHAR(200) NOT NULL UNIQUE,
    "slug" VARCHAR(200) UNIQUE,
    "logo_url" VARCHAR(500),
    "description" TEXT,
    "website" VARCHAR(255),
    "is_featured" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.products
CREATE TABLE IF NOT EXISTS "synthetic"."products" (
    "product_id" SERIAL PRIMARY KEY,
    "sku" VARCHAR(100) NOT NULL UNIQUE,
    "product_name" VARCHAR(300) NOT NULL,
    "slug" VARCHAR(300) UNIQUE,
    "brand_id" INTEGER,
    "category_id" INTEGER,
    "short_description" VARCHAR(500),
    "long_description" TEXT,
    "base_price" DECIMAL(15,2) NOT NULL,
    "sale_price" DECIMAL(15,2),
    "cost_price" DECIMAL(15,2),
    "weight_kg" DECIMAL(10,3),
    "dimensions_cm" VARCHAR(50),
    "is_active" BOOLEAN DEFAULT true,
    "is_featured" BOOLEAN DEFAULT false,
    "is_digital" BOOLEAN DEFAULT false,
    "tax_class" VARCHAR(50),
    "meta_title" VARCHAR(200),
    "meta_description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_products_brand_id" FOREIGN KEY ("brand_id") REFERENCES "synthetic"."brands" ("brand_id"),
    CONSTRAINT "fk_products_category_id" FOREIGN KEY ("category_id") REFERENCES "synthetic"."product_categories" ("category_id")
);
CREATE INDEX IF NOT EXISTS "idx_products_brand_id" ON "synthetic"."products" ("brand_id");
CREATE INDEX IF NOT EXISTS "idx_products_category_id" ON "synthetic"."products" ("category_id");

-- Table: synthetic.product_variants
CREATE TABLE IF NOT EXISTS "synthetic"."product_variants" (
    "variant_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "variant_sku" VARCHAR(100) UNIQUE,
    "variant_name" VARCHAR(200),
    "price_modifier" DECIMAL(10,2) DEFAULT 0,
    "weight_modifier" DECIMAL(10,3) DEFAULT 0,
    "stock_quantity" INTEGER DEFAULT 0,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_product_variants_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id")
);
CREATE INDEX IF NOT EXISTS "idx_product_variants_product_id" ON "synthetic"."product_variants" ("product_id");

-- Table: synthetic.product_attributes
CREATE TABLE IF NOT EXISTS "synthetic"."product_attributes" (
    "attribute_id" SERIAL PRIMARY KEY,
    "attribute_name" VARCHAR(100) NOT NULL,
    "attribute_type" VARCHAR(50),
    "is_filterable" BOOLEAN DEFAULT false,
    "is_required" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.product_attribute_values
CREATE TABLE IF NOT EXISTS "synthetic"."product_attribute_values" (
    "value_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "attribute_id" INTEGER NOT NULL,
    "attribute_value" VARCHAR(500),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_product_attribute_values_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_product_attribute_values_attribute_id" FOREIGN KEY ("attribute_id") REFERENCES "synthetic"."product_attributes" ("attribute_id")
);
CREATE INDEX IF NOT EXISTS "idx_product_attribute_values_product_id" ON "synthetic"."product_attribute_values" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_product_attribute_values_attribute_id" ON "synthetic"."product_attribute_values" ("attribute_id");

-- Table: synthetic.product_images
CREATE TABLE IF NOT EXISTS "synthetic"."product_images" (
    "image_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "variant_id" INTEGER,
    "image_url" VARCHAR(500) NOT NULL,
    "alt_text" VARCHAR(200),
    "sort_order" INTEGER DEFAULT 0,
    "is_primary" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_product_images_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_product_images_variant_id" FOREIGN KEY ("variant_id") REFERENCES "synthetic"."product_variants" ("variant_id")
);
CREATE INDEX IF NOT EXISTS "idx_product_images_product_id" ON "synthetic"."product_images" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_product_images_variant_id" ON "synthetic"."product_images" ("variant_id");

-- Table: synthetic.product_reviews
CREATE TABLE IF NOT EXISTS "synthetic"."product_reviews" (
    "review_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "customer_id" INTEGER,
    "rating" INTEGER NOT NULL,
    "title" VARCHAR(200),
    "review_text" TEXT,
    "is_verified_purchase" BOOLEAN DEFAULT false,
    "is_approved" BOOLEAN DEFAULT false,
    "helpful_votes" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_product_reviews_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_product_reviews_customer_id" FOREIGN KEY ("customer_id") REFERENCES "synthetic"."customers" ("customer_id")
);
CREATE INDEX IF NOT EXISTS "idx_product_reviews_product_id" ON "synthetic"."product_reviews" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_product_reviews_customer_id" ON "synthetic"."product_reviews" ("customer_id");

-- Table: synthetic.shopping_carts
CREATE TABLE IF NOT EXISTS "synthetic"."shopping_carts" (
    "cart_id" SERIAL PRIMARY KEY,
    "customer_id" INTEGER,
    "session_id" VARCHAR(100),
    "currency" VARCHAR(3) DEFAULT 'USD',
    "subtotal" DECIMAL(15,2) DEFAULT 0,
    "discount_total" DECIMAL(15,2) DEFAULT 0,
    "tax_total" DECIMAL(15,2) DEFAULT 0,
    "last_activity" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_shopping_carts_customer_id" FOREIGN KEY ("customer_id") REFERENCES "synthetic"."customers" ("customer_id")
);
CREATE INDEX IF NOT EXISTS "idx_shopping_carts_customer_id" ON "synthetic"."shopping_carts" ("customer_id");

-- Table: synthetic.cart_items
CREATE TABLE IF NOT EXISTS "synthetic"."cart_items" (
    "cart_item_id" SERIAL PRIMARY KEY,
    "cart_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "variant_id" INTEGER,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "unit_price" DECIMAL(15,2) NOT NULL,
    "added_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_cart_items_cart_id" FOREIGN KEY ("cart_id") REFERENCES "synthetic"."shopping_carts" ("cart_id"),
    CONSTRAINT "fk_cart_items_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_cart_items_variant_id" FOREIGN KEY ("variant_id") REFERENCES "synthetic"."product_variants" ("variant_id")
);
CREATE INDEX IF NOT EXISTS "idx_cart_items_cart_id" ON "synthetic"."cart_items" ("cart_id");
CREATE INDEX IF NOT EXISTS "idx_cart_items_product_id" ON "synthetic"."cart_items" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_cart_items_variant_id" ON "synthetic"."cart_items" ("variant_id");

-- Table: synthetic.wishlists
CREATE TABLE IF NOT EXISTS "synthetic"."wishlists" (
    "wishlist_id" SERIAL PRIMARY KEY,
    "customer_id" INTEGER NOT NULL,
    "wishlist_name" VARCHAR(100) DEFAULT 'My Wishlist',
    "is_public" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_wishlists_customer_id" FOREIGN KEY ("customer_id") REFERENCES "synthetic"."customers" ("customer_id")
);
CREATE INDEX IF NOT EXISTS "idx_wishlists_customer_id" ON "synthetic"."wishlists" ("customer_id");

-- Table: synthetic.wishlist_items
CREATE TABLE IF NOT EXISTS "synthetic"."wishlist_items" (
    "wishlist_item_id" SERIAL PRIMARY KEY,
    "wishlist_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "variant_id" INTEGER,
    "added_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "notes" VARCHAR(500),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_wishlist_items_wishlist_id" FOREIGN KEY ("wishlist_id") REFERENCES "synthetic"."wishlists" ("wishlist_id"),
    CONSTRAINT "fk_wishlist_items_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_wishlist_items_variant_id" FOREIGN KEY ("variant_id") REFERENCES "synthetic"."product_variants" ("variant_id")
);
CREATE INDEX IF NOT EXISTS "idx_wishlist_items_wishlist_id" ON "synthetic"."wishlist_items" ("wishlist_id");
CREATE INDEX IF NOT EXISTS "idx_wishlist_items_product_id" ON "synthetic"."wishlist_items" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_wishlist_items_variant_id" ON "synthetic"."wishlist_items" ("variant_id");

-- Table: synthetic.orders
CREATE TABLE IF NOT EXISTS "synthetic"."orders" (
    "order_id" SERIAL PRIMARY KEY,
    "order_number" VARCHAR(50) NOT NULL UNIQUE,
    "customer_id" INTEGER,
    "order_date" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" VARCHAR(50) DEFAULT 'pending',
    "subtotal" DECIMAL(15,2) NOT NULL,
    "discount_total" DECIMAL(15,2) DEFAULT 0,
    "shipping_total" DECIMAL(15,2) DEFAULT 0,
    "tax_total" DECIMAL(15,2) DEFAULT 0,
    "grand_total" DECIMAL(15,2) NOT NULL,
    "currency" VARCHAR(3) DEFAULT 'USD',
    "shipping_address_id" INTEGER,
    "billing_address_id" INTEGER,
    "shipping_method_id" INTEGER,
    "payment_method" VARCHAR(50),
    "notes" TEXT,
    "ip_address" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_orders_customer_id" FOREIGN KEY ("customer_id") REFERENCES "synthetic"."customers" ("customer_id"),
    CONSTRAINT "fk_orders_shipping_address_id" FOREIGN KEY ("shipping_address_id") REFERENCES "synthetic"."customer_addresses" ("address_id"),
    CONSTRAINT "fk_orders_billing_address_id" FOREIGN KEY ("billing_address_id") REFERENCES "synthetic"."customer_addresses" ("address_id"),
    CONSTRAINT "fk_orders_shipping_method_id" FOREIGN KEY ("shipping_method_id") REFERENCES "synthetic"."shipping_methods" ("shipping_method_id")
);
CREATE INDEX IF NOT EXISTS "idx_orders_customer_id" ON "synthetic"."orders" ("customer_id");
CREATE INDEX IF NOT EXISTS "idx_orders_shipping_address_id" ON "synthetic"."orders" ("shipping_address_id");
CREATE INDEX IF NOT EXISTS "idx_orders_billing_address_id" ON "synthetic"."orders" ("billing_address_id");
CREATE INDEX IF NOT EXISTS "idx_orders_shipping_method_id" ON "synthetic"."orders" ("shipping_method_id");

-- Table: synthetic.order_items
CREATE TABLE IF NOT EXISTS "synthetic"."order_items" (
    "order_item_id" SERIAL PRIMARY KEY,
    "order_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "variant_id" INTEGER,
    "product_name" VARCHAR(300),
    "sku" VARCHAR(100),
    "quantity" INTEGER NOT NULL,
    "unit_price" DECIMAL(15,2) NOT NULL,
    "discount_amount" DECIMAL(15,2) DEFAULT 0,
    "tax_amount" DECIMAL(15,2) DEFAULT 0,
    "line_total" DECIMAL(15,2) NOT NULL,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_order_items_order_id" FOREIGN KEY ("order_id") REFERENCES "synthetic"."orders" ("order_id"),
    CONSTRAINT "fk_order_items_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_order_items_variant_id" FOREIGN KEY ("variant_id") REFERENCES "synthetic"."product_variants" ("variant_id")
);
CREATE INDEX IF NOT EXISTS "idx_order_items_order_id" ON "synthetic"."order_items" ("order_id");
CREATE INDEX IF NOT EXISTS "idx_order_items_product_id" ON "synthetic"."order_items" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_order_items_variant_id" ON "synthetic"."order_items" ("variant_id");

-- Table: synthetic.order_status_history
CREATE TABLE IF NOT EXISTS "synthetic"."order_status_history" (
    "history_id" SERIAL PRIMARY KEY,
    "order_id" INTEGER NOT NULL,
    "status" VARCHAR(50) NOT NULL,
    "changed_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "changed_by" INTEGER,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_order_status_history_order_id" FOREIGN KEY ("order_id") REFERENCES "synthetic"."orders" ("order_id")
);
CREATE INDEX IF NOT EXISTS "idx_order_status_history_order_id" ON "synthetic"."order_status_history" ("order_id");

-- Table: synthetic.shipping_methods
CREATE TABLE IF NOT EXISTS "synthetic"."shipping_methods" (
    "shipping_method_id" SERIAL PRIMARY KEY,
    "method_name" VARCHAR(100) NOT NULL,
    "carrier" VARCHAR(100),
    "base_rate" DECIMAL(10,2) NOT NULL,
    "per_kg_rate" DECIMAL(10,2) DEFAULT 0,
    "estimated_days_min" INTEGER,
    "estimated_days_max" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.shipments
CREATE TABLE IF NOT EXISTS "synthetic"."shipments" (
    "shipment_id" SERIAL PRIMARY KEY,
    "order_id" INTEGER NOT NULL,
    "tracking_number" VARCHAR(100),
    "carrier" VARCHAR(100),
    "shipped_date" TIMESTAMP,
    "delivered_date" TIMESTAMP,
    "status" VARCHAR(50) DEFAULT 'pending',
    "shipping_cost" DECIMAL(10,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_shipments_order_id" FOREIGN KEY ("order_id") REFERENCES "synthetic"."orders" ("order_id")
);
CREATE INDEX IF NOT EXISTS "idx_shipments_order_id" ON "synthetic"."shipments" ("order_id");

-- Table: synthetic.shipment_items
CREATE TABLE IF NOT EXISTS "synthetic"."shipment_items" (
    "shipment_item_id" SERIAL PRIMARY KEY,
    "shipment_id" INTEGER NOT NULL,
    "order_item_id" INTEGER NOT NULL,
    "quantity_shipped" INTEGER NOT NULL,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_shipment_items_shipment_id" FOREIGN KEY ("shipment_id") REFERENCES "synthetic"."shipments" ("shipment_id"),
    CONSTRAINT "fk_shipment_items_order_item_id" FOREIGN KEY ("order_item_id") REFERENCES "synthetic"."order_items" ("order_item_id")
);
CREATE INDEX IF NOT EXISTS "idx_shipment_items_shipment_id" ON "synthetic"."shipment_items" ("shipment_id");
CREATE INDEX IF NOT EXISTS "idx_shipment_items_order_item_id" ON "synthetic"."shipment_items" ("order_item_id");

-- Table: synthetic.order_returns
CREATE TABLE IF NOT EXISTS "synthetic"."order_returns" (
    "return_id" SERIAL PRIMARY KEY,
    "order_id" INTEGER NOT NULL,
    "return_number" VARCHAR(50) UNIQUE,
    "requested_date" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "reason" VARCHAR(200),
    "status" VARCHAR(50) DEFAULT 'requested',
    "refund_amount" DECIMAL(15,2),
    "refund_method" VARCHAR(50),
    "processed_date" TIMESTAMP,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_order_returns_order_id" FOREIGN KEY ("order_id") REFERENCES "synthetic"."orders" ("order_id")
);
CREATE INDEX IF NOT EXISTS "idx_order_returns_order_id" ON "synthetic"."order_returns" ("order_id");

-- Table: synthetic.return_items
CREATE TABLE IF NOT EXISTS "synthetic"."return_items" (
    "return_item_id" SERIAL PRIMARY KEY,
    "return_id" INTEGER NOT NULL,
    "order_item_id" INTEGER NOT NULL,
    "quantity_returned" INTEGER NOT NULL,
    "condition" VARCHAR(50),
    "refund_amount" DECIMAL(15,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_return_items_return_id" FOREIGN KEY ("return_id") REFERENCES "synthetic"."order_returns" ("return_id"),
    CONSTRAINT "fk_return_items_order_item_id" FOREIGN KEY ("order_item_id") REFERENCES "synthetic"."order_items" ("order_item_id")
);
CREATE INDEX IF NOT EXISTS "idx_return_items_return_id" ON "synthetic"."return_items" ("return_id");
CREATE INDEX IF NOT EXISTS "idx_return_items_order_item_id" ON "synthetic"."return_items" ("order_item_id");

-- Table: synthetic.coupons
CREATE TABLE IF NOT EXISTS "synthetic"."coupons" (
    "coupon_id" SERIAL PRIMARY KEY,
    "coupon_code" VARCHAR(50) NOT NULL UNIQUE,
    "description" VARCHAR(500),
    "discount_type" VARCHAR(20) NOT NULL,
    "discount_value" DECIMAL(15,2) NOT NULL,
    "minimum_purchase" DECIMAL(15,2) DEFAULT 0,
    "maximum_discount" DECIMAL(15,2),
    "usage_limit" INTEGER,
    "usage_count" INTEGER DEFAULT 0,
    "per_customer_limit" INTEGER,
    "start_date" TIMESTAMP,
    "end_date" TIMESTAMP,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.coupon_usage
CREATE TABLE IF NOT EXISTS "synthetic"."coupon_usage" (
    "usage_id" SERIAL PRIMARY KEY,
    "coupon_id" INTEGER NOT NULL,
    "order_id" INTEGER NOT NULL,
    "customer_id" INTEGER,
    "discount_applied" DECIMAL(15,2) NOT NULL,
    "used_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_coupon_usage_coupon_id" FOREIGN KEY ("coupon_id") REFERENCES "synthetic"."coupons" ("coupon_id"),
    CONSTRAINT "fk_coupon_usage_order_id" FOREIGN KEY ("order_id") REFERENCES "synthetic"."orders" ("order_id"),
    CONSTRAINT "fk_coupon_usage_customer_id" FOREIGN KEY ("customer_id") REFERENCES "synthetic"."customers" ("customer_id")
);
CREATE INDEX IF NOT EXISTS "idx_coupon_usage_coupon_id" ON "synthetic"."coupon_usage" ("coupon_id");
CREATE INDEX IF NOT EXISTS "idx_coupon_usage_order_id" ON "synthetic"."coupon_usage" ("order_id");
CREATE INDEX IF NOT EXISTS "idx_coupon_usage_customer_id" ON "synthetic"."coupon_usage" ("customer_id");

-- Table: synthetic.gift_cards
CREATE TABLE IF NOT EXISTS "synthetic"."gift_cards" (
    "gift_card_id" SERIAL PRIMARY KEY,
    "card_code" VARCHAR(50) NOT NULL UNIQUE,
    "initial_balance" DECIMAL(15,2) NOT NULL,
    "current_balance" DECIMAL(15,2) NOT NULL,
    "currency" VARCHAR(3) DEFAULT 'USD',
    "purchaser_customer_id" INTEGER,
    "recipient_email" VARCHAR(255),
    "message" TEXT,
    "purchase_date" TIMESTAMP,
    "expiry_date" TIMESTAMP,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_gift_cards_purchaser_customer_id" FOREIGN KEY ("purchaser_customer_id") REFERENCES "synthetic"."customers" ("customer_id")
);
CREATE INDEX IF NOT EXISTS "idx_gift_cards_purchaser_customer_id" ON "synthetic"."gift_cards" ("purchaser_customer_id");

-- Table: synthetic.payment_transactions
CREATE TABLE IF NOT EXISTS "synthetic"."payment_transactions" (
    "transaction_id" SERIAL PRIMARY KEY,
    "order_id" INTEGER NOT NULL,
    "transaction_type" VARCHAR(50) NOT NULL,
    "amount" DECIMAL(15,2) NOT NULL,
    "currency" VARCHAR(3) DEFAULT 'USD',
    "payment_method" VARCHAR(50),
    "gateway" VARCHAR(100),
    "gateway_transaction_id" VARCHAR(200),
    "status" VARCHAR(50),
    "error_message" TEXT,
    "processed_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_payment_transactions_order_id" FOREIGN KEY ("order_id") REFERENCES "synthetic"."orders" ("order_id")
);
CREATE INDEX IF NOT EXISTS "idx_payment_transactions_order_id" ON "synthetic"."payment_transactions" ("order_id");

-- Table: synthetic.product_tags
CREATE TABLE IF NOT EXISTS "synthetic"."product_tags" (
    "tag_id" SERIAL PRIMARY KEY,
    "tag_name" VARCHAR(100) NOT NULL UNIQUE,
    "slug" VARCHAR(100) UNIQUE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.product_tag_map
CREATE TABLE IF NOT EXISTS "synthetic"."product_tag_map" (
    "product_tag_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "tag_id" INTEGER NOT NULL,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_product_tag_map_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_product_tag_map_tag_id" FOREIGN KEY ("tag_id") REFERENCES "synthetic"."product_tags" ("tag_id")
);
CREATE INDEX IF NOT EXISTS "idx_product_tag_map_product_id" ON "synthetic"."product_tag_map" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_product_tag_map_tag_id" ON "synthetic"."product_tag_map" ("tag_id");

-- Table: synthetic.related_products
CREATE TABLE IF NOT EXISTS "synthetic"."related_products" (
    "relation_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "related_product_id" INTEGER NOT NULL,
    "relation_type" VARCHAR(50),
    "sort_order" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_related_products_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_related_products_related_product_id" FOREIGN KEY ("related_product_id") REFERENCES "synthetic"."products" ("product_id")
);
CREATE INDEX IF NOT EXISTS "idx_related_products_product_id" ON "synthetic"."related_products" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_related_products_related_product_id" ON "synthetic"."related_products" ("related_product_id");

-- Table: synthetic.product_bundles
CREATE TABLE IF NOT EXISTS "synthetic"."product_bundles" (
    "bundle_id" SERIAL PRIMARY KEY,
    "bundle_product_id" INTEGER NOT NULL,
    "discount_percentage" DECIMAL(5,2) DEFAULT 0,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_product_bundles_bundle_product_id" FOREIGN KEY ("bundle_product_id") REFERENCES "synthetic"."products" ("product_id")
);
CREATE INDEX IF NOT EXISTS "idx_product_bundles_bundle_product_id" ON "synthetic"."product_bundles" ("bundle_product_id");

-- Table: synthetic.bundle_items
CREATE TABLE IF NOT EXISTS "synthetic"."bundle_items" (
    "bundle_item_id" SERIAL PRIMARY KEY,
    "bundle_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "is_required" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_bundle_items_bundle_id" FOREIGN KEY ("bundle_id") REFERENCES "synthetic"."product_bundles" ("bundle_id"),
    CONSTRAINT "fk_bundle_items_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id")
);
CREATE INDEX IF NOT EXISTS "idx_bundle_items_bundle_id" ON "synthetic"."bundle_items" ("bundle_id");
CREATE INDEX IF NOT EXISTS "idx_bundle_items_product_id" ON "synthetic"."bundle_items" ("product_id");

-- Table: synthetic.promotions
CREATE TABLE IF NOT EXISTS "synthetic"."promotions" (
    "promotion_id" SERIAL PRIMARY KEY,
    "promotion_name" VARCHAR(200) NOT NULL,
    "promotion_type" VARCHAR(50),
    "discount_type" VARCHAR(20),
    "discount_value" DECIMAL(15,2),
    "conditions" JSONB,
    "start_date" TIMESTAMP,
    "end_date" TIMESTAMP,
    "is_active" BOOLEAN DEFAULT true,
    "priority" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.promotion_products
CREATE TABLE IF NOT EXISTS "synthetic"."promotion_products" (
    "promo_product_id" SERIAL PRIMARY KEY,
    "promotion_id" INTEGER NOT NULL,
    "product_id" INTEGER,
    "category_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_promotion_products_promotion_id" FOREIGN KEY ("promotion_id") REFERENCES "synthetic"."promotions" ("promotion_id"),
    CONSTRAINT "fk_promotion_products_product_id" FOREIGN KEY ("product_id") REFERENCES "synthetic"."products" ("product_id"),
    CONSTRAINT "fk_promotion_products_category_id" FOREIGN KEY ("category_id") REFERENCES "synthetic"."product_categories" ("category_id")
);
CREATE INDEX IF NOT EXISTS "idx_promotion_products_promotion_id" ON "synthetic"."promotion_products" ("promotion_id");
CREATE INDEX IF NOT EXISTS "idx_promotion_products_product_id" ON "synthetic"."promotion_products" ("product_id");
CREATE INDEX IF NOT EXISTS "idx_promotion_products_category_id" ON "synthetic"."promotion_products" ("category_id");

-- ============================================================================
-- Domain: INVENTORY AND WAREHOUSE MANAGEMENT
-- ============================================================================


-- Table: synthetic.warehouses
CREATE TABLE IF NOT EXISTS "synthetic"."warehouses" (
    "warehouse_id" SERIAL PRIMARY KEY,
    "warehouse_code" VARCHAR(20) NOT NULL UNIQUE,
    "warehouse_name" VARCHAR(200) NOT NULL,
    "address_line1" VARCHAR(255),
    "city" VARCHAR(100),
    "state" VARCHAR(100),
    "country" VARCHAR(100),
    "postal_code" VARCHAR(20),
    "capacity_sqft" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "manager_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.warehouse_zones
CREATE TABLE IF NOT EXISTS "synthetic"."warehouse_zones" (
    "zone_id" SERIAL PRIMARY KEY,
    "warehouse_id" INTEGER NOT NULL,
    "zone_code" VARCHAR(20) NOT NULL,
    "zone_name" VARCHAR(100),
    "zone_type" VARCHAR(50),
    "temperature_controlled" BOOLEAN DEFAULT false,
    "min_temp" DECIMAL(5,2),
    "max_temp" DECIMAL(5,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_warehouse_zones_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_warehouse_zones_warehouse_id" ON "synthetic"."warehouse_zones" ("warehouse_id");

-- Table: synthetic.storage_locations
CREATE TABLE IF NOT EXISTS "synthetic"."storage_locations" (
    "location_id" SERIAL PRIMARY KEY,
    "zone_id" INTEGER NOT NULL,
    "location_code" VARCHAR(50) NOT NULL,
    "aisle" VARCHAR(10),
    "rack" VARCHAR(10),
    "shelf" VARCHAR(10),
    "bin" VARCHAR(10),
    "max_weight_kg" DECIMAL(10,2),
    "max_volume_cbm" DECIMAL(10,3),
    "is_available" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_storage_locations_zone_id" FOREIGN KEY ("zone_id") REFERENCES "synthetic"."warehouse_zones" ("zone_id")
);
CREATE INDEX IF NOT EXISTS "idx_storage_locations_zone_id" ON "synthetic"."storage_locations" ("zone_id");

-- Table: synthetic.inventory_items
CREATE TABLE IF NOT EXISTS "synthetic"."inventory_items" (
    "inventory_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "variant_id" INTEGER,
    "warehouse_id" INTEGER NOT NULL,
    "location_id" INTEGER,
    "quantity_on_hand" INTEGER NOT NULL DEFAULT 0,
    "quantity_reserved" INTEGER DEFAULT 0,
    "quantity_available" INTEGER DEFAULT 0,
    "reorder_point" INTEGER,
    "reorder_quantity" INTEGER,
    "last_count_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_inventory_items_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id"),
    CONSTRAINT "fk_inventory_items_location_id" FOREIGN KEY ("location_id") REFERENCES "synthetic"."storage_locations" ("location_id")
);
CREATE INDEX IF NOT EXISTS "idx_inventory_items_warehouse_id" ON "synthetic"."inventory_items" ("warehouse_id");
CREATE INDEX IF NOT EXISTS "idx_inventory_items_location_id" ON "synthetic"."inventory_items" ("location_id");

-- Table: synthetic.inventory_lots
CREATE TABLE IF NOT EXISTS "synthetic"."inventory_lots" (
    "lot_id" SERIAL PRIMARY KEY,
    "inventory_id" INTEGER NOT NULL,
    "lot_number" VARCHAR(100) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "manufacture_date" DATE,
    "expiry_date" DATE,
    "received_date" DATE,
    "cost_per_unit" DECIMAL(15,4),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_inventory_lots_inventory_id" FOREIGN KEY ("inventory_id") REFERENCES "synthetic"."inventory_items" ("inventory_id")
);
CREATE INDEX IF NOT EXISTS "idx_inventory_lots_inventory_id" ON "synthetic"."inventory_lots" ("inventory_id");

-- Table: synthetic.inventory_transactions
CREATE TABLE IF NOT EXISTS "synthetic"."inventory_transactions" (
    "transaction_id" SERIAL PRIMARY KEY,
    "inventory_id" INTEGER NOT NULL,
    "transaction_type" VARCHAR(50) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "reference_type" VARCHAR(50),
    "reference_id" INTEGER,
    "notes" TEXT,
    "transaction_date" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "performed_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_inventory_transactions_inventory_id" FOREIGN KEY ("inventory_id") REFERENCES "synthetic"."inventory_items" ("inventory_id")
);
CREATE INDEX IF NOT EXISTS "idx_inventory_transactions_inventory_id" ON "synthetic"."inventory_transactions" ("inventory_id");

-- Table: synthetic.suppliers
CREATE TABLE IF NOT EXISTS "synthetic"."suppliers" (
    "supplier_id" SERIAL PRIMARY KEY,
    "supplier_code" VARCHAR(50) UNIQUE,
    "supplier_name" VARCHAR(200) NOT NULL,
    "contact_name" VARCHAR(200),
    "email" VARCHAR(255),
    "phone" VARCHAR(20),
    "address" TEXT,
    "country" VARCHAR(100),
    "payment_terms" VARCHAR(50),
    "lead_time_days" INTEGER,
    "rating" DECIMAL(3,2),
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.supplier_products
CREATE TABLE IF NOT EXISTS "synthetic"."supplier_products" (
    "supplier_product_id" SERIAL PRIMARY KEY,
    "supplier_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "supplier_sku" VARCHAR(100),
    "unit_cost" DECIMAL(15,4),
    "minimum_order_qty" INTEGER DEFAULT 1,
    "lead_time_days" INTEGER,
    "is_preferred" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_supplier_products_supplier_id" FOREIGN KEY ("supplier_id") REFERENCES "synthetic"."suppliers" ("supplier_id")
);
CREATE INDEX IF NOT EXISTS "idx_supplier_products_supplier_id" ON "synthetic"."supplier_products" ("supplier_id");

-- Table: synthetic.purchase_orders
CREATE TABLE IF NOT EXISTS "synthetic"."purchase_orders" (
    "po_id" SERIAL PRIMARY KEY,
    "po_number" VARCHAR(50) NOT NULL UNIQUE,
    "supplier_id" INTEGER NOT NULL,
    "warehouse_id" INTEGER,
    "order_date" DATE NOT NULL,
    "expected_date" DATE,
    "status" VARCHAR(50) DEFAULT 'draft',
    "subtotal" DECIMAL(15,2),
    "tax_amount" DECIMAL(15,2) DEFAULT 0,
    "shipping_cost" DECIMAL(15,2) DEFAULT 0,
    "total_amount" DECIMAL(15,2),
    "currency" VARCHAR(3) DEFAULT 'USD',
    "notes" TEXT,
    "approved_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_purchase_orders_supplier_id" FOREIGN KEY ("supplier_id") REFERENCES "synthetic"."suppliers" ("supplier_id"),
    CONSTRAINT "fk_purchase_orders_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_purchase_orders_supplier_id" ON "synthetic"."purchase_orders" ("supplier_id");
CREATE INDEX IF NOT EXISTS "idx_purchase_orders_warehouse_id" ON "synthetic"."purchase_orders" ("warehouse_id");

-- Table: synthetic.purchase_order_lines
CREATE TABLE IF NOT EXISTS "synthetic"."purchase_order_lines" (
    "po_line_id" SERIAL PRIMARY KEY,
    "po_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "quantity_ordered" INTEGER NOT NULL,
    "quantity_received" INTEGER DEFAULT 0,
    "unit_cost" DECIMAL(15,4) NOT NULL,
    "line_total" DECIMAL(15,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_purchase_order_lines_po_id" FOREIGN KEY ("po_id") REFERENCES "synthetic"."purchase_orders" ("po_id")
);
CREATE INDEX IF NOT EXISTS "idx_purchase_order_lines_po_id" ON "synthetic"."purchase_order_lines" ("po_id");

-- Table: synthetic.receiving_orders
CREATE TABLE IF NOT EXISTS "synthetic"."receiving_orders" (
    "receiving_id" SERIAL PRIMARY KEY,
    "receiving_number" VARCHAR(50) UNIQUE,
    "po_id" INTEGER,
    "warehouse_id" INTEGER NOT NULL,
    "received_date" TIMESTAMP NOT NULL,
    "status" VARCHAR(50) DEFAULT 'pending',
    "received_by" INTEGER,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_receiving_orders_po_id" FOREIGN KEY ("po_id") REFERENCES "synthetic"."purchase_orders" ("po_id"),
    CONSTRAINT "fk_receiving_orders_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_receiving_orders_po_id" ON "synthetic"."receiving_orders" ("po_id");
CREATE INDEX IF NOT EXISTS "idx_receiving_orders_warehouse_id" ON "synthetic"."receiving_orders" ("warehouse_id");

-- Table: synthetic.receiving_lines
CREATE TABLE IF NOT EXISTS "synthetic"."receiving_lines" (
    "receiving_line_id" SERIAL PRIMARY KEY,
    "receiving_id" INTEGER NOT NULL,
    "po_line_id" INTEGER,
    "product_id" INTEGER NOT NULL,
    "quantity_received" INTEGER NOT NULL,
    "quantity_accepted" INTEGER,
    "quantity_rejected" INTEGER DEFAULT 0,
    "location_id" INTEGER,
    "lot_number" VARCHAR(100),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_receiving_lines_receiving_id" FOREIGN KEY ("receiving_id") REFERENCES "synthetic"."receiving_orders" ("receiving_id"),
    CONSTRAINT "fk_receiving_lines_po_line_id" FOREIGN KEY ("po_line_id") REFERENCES "synthetic"."purchase_order_lines" ("po_line_id"),
    CONSTRAINT "fk_receiving_lines_location_id" FOREIGN KEY ("location_id") REFERENCES "synthetic"."storage_locations" ("location_id")
);
CREATE INDEX IF NOT EXISTS "idx_receiving_lines_receiving_id" ON "synthetic"."receiving_lines" ("receiving_id");
CREATE INDEX IF NOT EXISTS "idx_receiving_lines_po_line_id" ON "synthetic"."receiving_lines" ("po_line_id");
CREATE INDEX IF NOT EXISTS "idx_receiving_lines_location_id" ON "synthetic"."receiving_lines" ("location_id");

-- Table: synthetic.stock_transfers
CREATE TABLE IF NOT EXISTS "synthetic"."stock_transfers" (
    "transfer_id" SERIAL PRIMARY KEY,
    "transfer_number" VARCHAR(50) UNIQUE,
    "from_warehouse_id" INTEGER NOT NULL,
    "to_warehouse_id" INTEGER NOT NULL,
    "transfer_date" DATE,
    "status" VARCHAR(50) DEFAULT 'pending',
    "requested_by" INTEGER,
    "approved_by" INTEGER,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_stock_transfers_from_warehouse_id" FOREIGN KEY ("from_warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id"),
    CONSTRAINT "fk_stock_transfers_to_warehouse_id" FOREIGN KEY ("to_warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_stock_transfers_from_warehouse_id" ON "synthetic"."stock_transfers" ("from_warehouse_id");
CREATE INDEX IF NOT EXISTS "idx_stock_transfers_to_warehouse_id" ON "synthetic"."stock_transfers" ("to_warehouse_id");

-- Table: synthetic.stock_transfer_lines
CREATE TABLE IF NOT EXISTS "synthetic"."stock_transfer_lines" (
    "transfer_line_id" SERIAL PRIMARY KEY,
    "transfer_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "quantity" INTEGER NOT NULL,
    "from_location_id" INTEGER,
    "to_location_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_stock_transfer_lines_transfer_id" FOREIGN KEY ("transfer_id") REFERENCES "synthetic"."stock_transfers" ("transfer_id"),
    CONSTRAINT "fk_stock_transfer_lines_from_location_id" FOREIGN KEY ("from_location_id") REFERENCES "synthetic"."storage_locations" ("location_id"),
    CONSTRAINT "fk_stock_transfer_lines_to_location_id" FOREIGN KEY ("to_location_id") REFERENCES "synthetic"."storage_locations" ("location_id")
);
CREATE INDEX IF NOT EXISTS "idx_stock_transfer_lines_transfer_id" ON "synthetic"."stock_transfer_lines" ("transfer_id");
CREATE INDEX IF NOT EXISTS "idx_stock_transfer_lines_from_location_id" ON "synthetic"."stock_transfer_lines" ("from_location_id");
CREATE INDEX IF NOT EXISTS "idx_stock_transfer_lines_to_location_id" ON "synthetic"."stock_transfer_lines" ("to_location_id");

-- Table: synthetic.inventory_counts
CREATE TABLE IF NOT EXISTS "synthetic"."inventory_counts" (
    "count_id" SERIAL PRIMARY KEY,
    "count_number" VARCHAR(50) UNIQUE,
    "warehouse_id" INTEGER NOT NULL,
    "count_date" DATE NOT NULL,
    "count_type" VARCHAR(50),
    "status" VARCHAR(50) DEFAULT 'planned',
    "started_at" TIMESTAMP,
    "completed_at" TIMESTAMP,
    "performed_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_inventory_counts_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_inventory_counts_warehouse_id" ON "synthetic"."inventory_counts" ("warehouse_id");

-- Table: synthetic.inventory_count_lines
CREATE TABLE IF NOT EXISTS "synthetic"."inventory_count_lines" (
    "count_line_id" SERIAL PRIMARY KEY,
    "count_id" INTEGER NOT NULL,
    "inventory_id" INTEGER NOT NULL,
    "expected_quantity" INTEGER,
    "counted_quantity" INTEGER,
    "variance" INTEGER,
    "counted_by" INTEGER,
    "counted_at" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_inventory_count_lines_count_id" FOREIGN KEY ("count_id") REFERENCES "synthetic"."inventory_counts" ("count_id"),
    CONSTRAINT "fk_inventory_count_lines_inventory_id" FOREIGN KEY ("inventory_id") REFERENCES "synthetic"."inventory_items" ("inventory_id")
);
CREATE INDEX IF NOT EXISTS "idx_inventory_count_lines_count_id" ON "synthetic"."inventory_count_lines" ("count_id");
CREATE INDEX IF NOT EXISTS "idx_inventory_count_lines_inventory_id" ON "synthetic"."inventory_count_lines" ("inventory_id");

-- Table: synthetic.inventory_adjustments
CREATE TABLE IF NOT EXISTS "synthetic"."inventory_adjustments" (
    "adjustment_id" SERIAL PRIMARY KEY,
    "adjustment_number" VARCHAR(50) UNIQUE,
    "warehouse_id" INTEGER NOT NULL,
    "adjustment_date" DATE NOT NULL,
    "reason" VARCHAR(200),
    "status" VARCHAR(50) DEFAULT 'pending',
    "approved_by" INTEGER,
    "total_value_change" DECIMAL(15,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_inventory_adjustments_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_inventory_adjustments_warehouse_id" ON "synthetic"."inventory_adjustments" ("warehouse_id");

-- Table: synthetic.adjustment_lines
CREATE TABLE IF NOT EXISTS "synthetic"."adjustment_lines" (
    "adjustment_line_id" SERIAL PRIMARY KEY,
    "adjustment_id" INTEGER NOT NULL,
    "inventory_id" INTEGER NOT NULL,
    "quantity_change" INTEGER NOT NULL,
    "unit_cost" DECIMAL(15,4),
    "reason" VARCHAR(200),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_adjustment_lines_adjustment_id" FOREIGN KEY ("adjustment_id") REFERENCES "synthetic"."inventory_adjustments" ("adjustment_id"),
    CONSTRAINT "fk_adjustment_lines_inventory_id" FOREIGN KEY ("inventory_id") REFERENCES "synthetic"."inventory_items" ("inventory_id")
);
CREATE INDEX IF NOT EXISTS "idx_adjustment_lines_adjustment_id" ON "synthetic"."adjustment_lines" ("adjustment_id");
CREATE INDEX IF NOT EXISTS "idx_adjustment_lines_inventory_id" ON "synthetic"."adjustment_lines" ("inventory_id");

-- Table: synthetic.pick_orders
CREATE TABLE IF NOT EXISTS "synthetic"."pick_orders" (
    "pick_id" SERIAL PRIMARY KEY,
    "pick_number" VARCHAR(50) UNIQUE,
    "warehouse_id" INTEGER NOT NULL,
    "order_id" INTEGER,
    "priority" INTEGER DEFAULT 0,
    "status" VARCHAR(50) DEFAULT 'pending',
    "assigned_to" INTEGER,
    "started_at" TIMESTAMP,
    "completed_at" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_pick_orders_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_pick_orders_warehouse_id" ON "synthetic"."pick_orders" ("warehouse_id");

-- Table: synthetic.pick_lines
CREATE TABLE IF NOT EXISTS "synthetic"."pick_lines" (
    "pick_line_id" SERIAL PRIMARY KEY,
    "pick_id" INTEGER NOT NULL,
    "inventory_id" INTEGER NOT NULL,
    "location_id" INTEGER,
    "quantity_requested" INTEGER NOT NULL,
    "quantity_picked" INTEGER DEFAULT 0,
    "picked_at" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_pick_lines_pick_id" FOREIGN KEY ("pick_id") REFERENCES "synthetic"."pick_orders" ("pick_id"),
    CONSTRAINT "fk_pick_lines_inventory_id" FOREIGN KEY ("inventory_id") REFERENCES "synthetic"."inventory_items" ("inventory_id"),
    CONSTRAINT "fk_pick_lines_location_id" FOREIGN KEY ("location_id") REFERENCES "synthetic"."storage_locations" ("location_id")
);
CREATE INDEX IF NOT EXISTS "idx_pick_lines_pick_id" ON "synthetic"."pick_lines" ("pick_id");
CREATE INDEX IF NOT EXISTS "idx_pick_lines_inventory_id" ON "synthetic"."pick_lines" ("inventory_id");
CREATE INDEX IF NOT EXISTS "idx_pick_lines_location_id" ON "synthetic"."pick_lines" ("location_id");

-- Table: synthetic.pack_orders
CREATE TABLE IF NOT EXISTS "synthetic"."pack_orders" (
    "pack_id" SERIAL PRIMARY KEY,
    "pack_number" VARCHAR(50) UNIQUE,
    "pick_id" INTEGER,
    "order_id" INTEGER,
    "status" VARCHAR(50) DEFAULT 'pending',
    "packed_by" INTEGER,
    "packed_at" TIMESTAMP,
    "total_weight_kg" DECIMAL(10,3),
    "num_packages" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_pack_orders_pick_id" FOREIGN KEY ("pick_id") REFERENCES "synthetic"."pick_orders" ("pick_id")
);
CREATE INDEX IF NOT EXISTS "idx_pack_orders_pick_id" ON "synthetic"."pack_orders" ("pick_id");

-- Table: synthetic.packages
CREATE TABLE IF NOT EXISTS "synthetic"."packages" (
    "package_id" SERIAL PRIMARY KEY,
    "pack_id" INTEGER NOT NULL,
    "package_number" INTEGER NOT NULL,
    "weight_kg" DECIMAL(10,3),
    "length_cm" DECIMAL(8,2),
    "width_cm" DECIMAL(8,2),
    "height_cm" DECIMAL(8,2),
    "tracking_number" VARCHAR(100),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_packages_pack_id" FOREIGN KEY ("pack_id") REFERENCES "synthetic"."pack_orders" ("pack_id")
);
CREATE INDEX IF NOT EXISTS "idx_packages_pack_id" ON "synthetic"."packages" ("pack_id");

-- Table: synthetic.abc_analysis
CREATE TABLE IF NOT EXISTS "synthetic"."abc_analysis" (
    "analysis_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "warehouse_id" INTEGER,
    "analysis_date" DATE NOT NULL,
    "classification" VARCHAR(1),
    "annual_usage_value" DECIMAL(15,2),
    "cumulative_percentage" DECIMAL(6,3),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_abc_analysis_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_abc_analysis_warehouse_id" ON "synthetic"."abc_analysis" ("warehouse_id");

-- Table: synthetic.reorder_rules
CREATE TABLE IF NOT EXISTS "synthetic"."reorder_rules" (
    "rule_id" SERIAL PRIMARY KEY,
    "product_id" INTEGER NOT NULL,
    "warehouse_id" INTEGER,
    "reorder_point" INTEGER NOT NULL,
    "reorder_quantity" INTEGER NOT NULL,
    "safety_stock" INTEGER DEFAULT 0,
    "max_stock" INTEGER,
    "lead_time_days" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_reorder_rules_warehouse_id" FOREIGN KEY ("warehouse_id") REFERENCES "synthetic"."warehouses" ("warehouse_id")
);
CREATE INDEX IF NOT EXISTS "idx_reorder_rules_warehouse_id" ON "synthetic"."reorder_rules" ("warehouse_id");

-- ============================================================================
-- Domain: CUSTOMER RELATIONSHIP MANAGEMENT AND SALES
-- ============================================================================


-- Table: synthetic.accounts
CREATE TABLE IF NOT EXISTS "synthetic"."accounts" (
    "account_id" SERIAL PRIMARY KEY,
    "account_name" VARCHAR(200) NOT NULL,
    "account_type" VARCHAR(50),
    "industry" VARCHAR(100),
    "website" VARCHAR(255),
    "phone" VARCHAR(20),
    "fax" VARCHAR(20),
    "employees_count" INTEGER,
    "annual_revenue" DECIMAL(15,2),
    "billing_address" TEXT,
    "shipping_address" TEXT,
    "description" TEXT,
    "owner_id" INTEGER,
    "parent_account_id" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_accounts_parent_account_id" FOREIGN KEY ("parent_account_id") REFERENCES "synthetic"."accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_accounts_parent_account_id" ON "synthetic"."accounts" ("parent_account_id");

-- Table: synthetic.contacts
CREATE TABLE IF NOT EXISTS "synthetic"."contacts" (
    "contact_id" SERIAL PRIMARY KEY,
    "account_id" INTEGER,
    "first_name" VARCHAR(100),
    "last_name" VARCHAR(100) NOT NULL,
    "email" VARCHAR(255),
    "phone" VARCHAR(20),
    "mobile" VARCHAR(20),
    "title" VARCHAR(100),
    "department" VARCHAR(100),
    "mailing_address" TEXT,
    "description" TEXT,
    "owner_id" INTEGER,
    "lead_source" VARCHAR(100),
    "do_not_call" BOOLEAN DEFAULT false,
    "do_not_email" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_contacts_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_contacts_account_id" ON "synthetic"."contacts" ("account_id");

-- Table: synthetic.leads
CREATE TABLE IF NOT EXISTS "synthetic"."leads" (
    "lead_id" SERIAL PRIMARY KEY,
    "first_name" VARCHAR(100),
    "last_name" VARCHAR(100) NOT NULL,
    "company" VARCHAR(200),
    "title" VARCHAR(100),
    "email" VARCHAR(255),
    "phone" VARCHAR(20),
    "website" VARCHAR(255),
    "lead_source" VARCHAR(100),
    "lead_status" VARCHAR(50) DEFAULT 'new',
    "rating" VARCHAR(20),
    "industry" VARCHAR(100),
    "annual_revenue" DECIMAL(15,2),
    "employees" INTEGER,
    "description" TEXT,
    "address" TEXT,
    "owner_id" INTEGER,
    "converted_account_id" INTEGER,
    "converted_contact_id" INTEGER,
    "converted_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_leads_converted_account_id" FOREIGN KEY ("converted_account_id") REFERENCES "synthetic"."accounts" ("account_id"),
    CONSTRAINT "fk_leads_converted_contact_id" FOREIGN KEY ("converted_contact_id") REFERENCES "synthetic"."contacts" ("contact_id")
);
CREATE INDEX IF NOT EXISTS "idx_leads_converted_account_id" ON "synthetic"."leads" ("converted_account_id");
CREATE INDEX IF NOT EXISTS "idx_leads_converted_contact_id" ON "synthetic"."leads" ("converted_contact_id");

-- Table: synthetic.opportunities
CREATE TABLE IF NOT EXISTS "synthetic"."opportunities" (
    "opportunity_id" SERIAL PRIMARY KEY,
    "opportunity_name" VARCHAR(200) NOT NULL,
    "account_id" INTEGER,
    "contact_id" INTEGER,
    "stage" VARCHAR(50),
    "amount" DECIMAL(15,2),
    "probability" INTEGER,
    "expected_revenue" DECIMAL(15,2),
    "close_date" DATE,
    "type" VARCHAR(50),
    "lead_source" VARCHAR(100),
    "next_step" VARCHAR(500),
    "description" TEXT,
    "owner_id" INTEGER,
    "campaign_id" INTEGER,
    "is_won" BOOLEAN,
    "is_closed" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_opportunities_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."accounts" ("account_id"),
    CONSTRAINT "fk_opportunities_contact_id" FOREIGN KEY ("contact_id") REFERENCES "synthetic"."contacts" ("contact_id"),
    CONSTRAINT "fk_opportunities_campaign_id" FOREIGN KEY ("campaign_id") REFERENCES "synthetic"."campaigns" ("campaign_id")
);
CREATE INDEX IF NOT EXISTS "idx_opportunities_account_id" ON "synthetic"."opportunities" ("account_id");
CREATE INDEX IF NOT EXISTS "idx_opportunities_contact_id" ON "synthetic"."opportunities" ("contact_id");
CREATE INDEX IF NOT EXISTS "idx_opportunities_campaign_id" ON "synthetic"."opportunities" ("campaign_id");

-- Table: synthetic.opportunity_stages
CREATE TABLE IF NOT EXISTS "synthetic"."opportunity_stages" (
    "stage_id" SERIAL PRIMARY KEY,
    "stage_name" VARCHAR(100) NOT NULL,
    "probability" INTEGER,
    "sort_order" INTEGER,
    "is_closed" BOOLEAN DEFAULT false,
    "is_won" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.opportunity_products
CREATE TABLE IF NOT EXISTS "synthetic"."opportunity_products" (
    "op_product_id" SERIAL PRIMARY KEY,
    "opportunity_id" INTEGER NOT NULL,
    "product_id" INTEGER,
    "product_name" VARCHAR(200),
    "quantity" DECIMAL(10,2),
    "unit_price" DECIMAL(15,2),
    "discount" DECIMAL(5,2) DEFAULT 0,
    "total_price" DECIMAL(15,2),
    "description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_opportunity_products_opportunity_id" FOREIGN KEY ("opportunity_id") REFERENCES "synthetic"."opportunities" ("opportunity_id")
);
CREATE INDEX IF NOT EXISTS "idx_opportunity_products_opportunity_id" ON "synthetic"."opportunity_products" ("opportunity_id");

-- Table: synthetic.quotes
CREATE TABLE IF NOT EXISTS "synthetic"."quotes" (
    "quote_id" SERIAL PRIMARY KEY,
    "quote_number" VARCHAR(50) UNIQUE,
    "opportunity_id" INTEGER,
    "account_id" INTEGER,
    "contact_id" INTEGER,
    "quote_name" VARCHAR(200),
    "status" VARCHAR(50) DEFAULT 'draft',
    "expiration_date" DATE,
    "subtotal" DECIMAL(15,2),
    "discount" DECIMAL(15,2) DEFAULT 0,
    "tax" DECIMAL(15,2) DEFAULT 0,
    "shipping" DECIMAL(15,2) DEFAULT 0,
    "grand_total" DECIMAL(15,2),
    "billing_address" TEXT,
    "shipping_address" TEXT,
    "description" TEXT,
    "owner_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_quotes_opportunity_id" FOREIGN KEY ("opportunity_id") REFERENCES "synthetic"."opportunities" ("opportunity_id"),
    CONSTRAINT "fk_quotes_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."accounts" ("account_id"),
    CONSTRAINT "fk_quotes_contact_id" FOREIGN KEY ("contact_id") REFERENCES "synthetic"."contacts" ("contact_id")
);
CREATE INDEX IF NOT EXISTS "idx_quotes_opportunity_id" ON "synthetic"."quotes" ("opportunity_id");
CREATE INDEX IF NOT EXISTS "idx_quotes_account_id" ON "synthetic"."quotes" ("account_id");
CREATE INDEX IF NOT EXISTS "idx_quotes_contact_id" ON "synthetic"."quotes" ("contact_id");

-- Table: synthetic.quote_lines
CREATE TABLE IF NOT EXISTS "synthetic"."quote_lines" (
    "quote_line_id" SERIAL PRIMARY KEY,
    "quote_id" INTEGER NOT NULL,
    "product_id" INTEGER,
    "product_name" VARCHAR(200),
    "quantity" DECIMAL(10,2) NOT NULL,
    "unit_price" DECIMAL(15,2) NOT NULL,
    "discount" DECIMAL(5,2) DEFAULT 0,
    "line_total" DECIMAL(15,2),
    "description" TEXT,
    "sort_order" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_quote_lines_quote_id" FOREIGN KEY ("quote_id") REFERENCES "synthetic"."quotes" ("quote_id")
);
CREATE INDEX IF NOT EXISTS "idx_quote_lines_quote_id" ON "synthetic"."quote_lines" ("quote_id");

-- Table: synthetic.sales_orders
CREATE TABLE IF NOT EXISTS "synthetic"."sales_orders" (
    "sales_order_id" SERIAL PRIMARY KEY,
    "order_number" VARCHAR(50) NOT NULL UNIQUE,
    "quote_id" INTEGER,
    "opportunity_id" INTEGER,
    "account_id" INTEGER,
    "contact_id" INTEGER,
    "order_date" DATE NOT NULL,
    "status" VARCHAR(50) DEFAULT 'pending',
    "subtotal" DECIMAL(15,2),
    "discount" DECIMAL(15,2) DEFAULT 0,
    "tax" DECIMAL(15,2) DEFAULT 0,
    "shipping" DECIMAL(15,2) DEFAULT 0,
    "grand_total" DECIMAL(15,2),
    "billing_address" TEXT,
    "shipping_address" TEXT,
    "owner_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_sales_orders_quote_id" FOREIGN KEY ("quote_id") REFERENCES "synthetic"."quotes" ("quote_id"),
    CONSTRAINT "fk_sales_orders_opportunity_id" FOREIGN KEY ("opportunity_id") REFERENCES "synthetic"."opportunities" ("opportunity_id"),
    CONSTRAINT "fk_sales_orders_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."accounts" ("account_id"),
    CONSTRAINT "fk_sales_orders_contact_id" FOREIGN KEY ("contact_id") REFERENCES "synthetic"."contacts" ("contact_id")
);
CREATE INDEX IF NOT EXISTS "idx_sales_orders_quote_id" ON "synthetic"."sales_orders" ("quote_id");
CREATE INDEX IF NOT EXISTS "idx_sales_orders_opportunity_id" ON "synthetic"."sales_orders" ("opportunity_id");
CREATE INDEX IF NOT EXISTS "idx_sales_orders_account_id" ON "synthetic"."sales_orders" ("account_id");
CREATE INDEX IF NOT EXISTS "idx_sales_orders_contact_id" ON "synthetic"."sales_orders" ("contact_id");

-- Table: synthetic.sales_order_lines
CREATE TABLE IF NOT EXISTS "synthetic"."sales_order_lines" (
    "so_line_id" SERIAL PRIMARY KEY,
    "sales_order_id" INTEGER NOT NULL,
    "product_id" INTEGER,
    "product_name" VARCHAR(200),
    "quantity" DECIMAL(10,2) NOT NULL,
    "unit_price" DECIMAL(15,2) NOT NULL,
    "discount" DECIMAL(5,2) DEFAULT 0,
    "line_total" DECIMAL(15,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_sales_order_lines_sales_order_id" FOREIGN KEY ("sales_order_id") REFERENCES "synthetic"."sales_orders" ("sales_order_id")
);
CREATE INDEX IF NOT EXISTS "idx_sales_order_lines_sales_order_id" ON "synthetic"."sales_order_lines" ("sales_order_id");

-- Table: synthetic.activities
CREATE TABLE IF NOT EXISTS "synthetic"."activities" (
    "activity_id" SERIAL PRIMARY KEY,
    "activity_type" VARCHAR(50) NOT NULL,
    "subject" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "status" VARCHAR(50) DEFAULT 'planned',
    "priority" VARCHAR(20),
    "due_date" TIMESTAMP,
    "completed_date" TIMESTAMP,
    "related_to_type" VARCHAR(50),
    "related_to_id" INTEGER,
    "owner_id" INTEGER,
    "assigned_to" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.tasks
CREATE TABLE IF NOT EXISTS "synthetic"."tasks" (
    "task_id" SERIAL PRIMARY KEY,
    "subject" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "status" VARCHAR(50) DEFAULT 'not_started',
    "priority" VARCHAR(20),
    "due_date" DATE,
    "reminder_date" TIMESTAMP,
    "related_to_type" VARCHAR(50),
    "related_to_id" INTEGER,
    "owner_id" INTEGER,
    "assigned_to" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.events
CREATE TABLE IF NOT EXISTS "synthetic"."events" (
    "event_id" SERIAL PRIMARY KEY,
    "subject" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "location" VARCHAR(500),
    "start_date" TIMESTAMP NOT NULL,
    "end_date" TIMESTAMP,
    "is_all_day" BOOLEAN DEFAULT false,
    "related_to_type" VARCHAR(50),
    "related_to_id" INTEGER,
    "owner_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.event_attendees
CREATE TABLE IF NOT EXISTS "synthetic"."event_attendees" (
    "attendee_id" SERIAL PRIMARY KEY,
    "event_id" INTEGER NOT NULL,
    "contact_id" INTEGER,
    "user_id" INTEGER,
    "email" VARCHAR(255),
    "status" VARCHAR(50) DEFAULT 'pending',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_event_attendees_event_id" FOREIGN KEY ("event_id") REFERENCES "synthetic"."events" ("event_id"),
    CONSTRAINT "fk_event_attendees_contact_id" FOREIGN KEY ("contact_id") REFERENCES "synthetic"."contacts" ("contact_id")
);
CREATE INDEX IF NOT EXISTS "idx_event_attendees_event_id" ON "synthetic"."event_attendees" ("event_id");
CREATE INDEX IF NOT EXISTS "idx_event_attendees_contact_id" ON "synthetic"."event_attendees" ("contact_id");

-- Table: synthetic.call_logs
CREATE TABLE IF NOT EXISTS "synthetic"."call_logs" (
    "call_id" SERIAL PRIMARY KEY,
    "subject" VARCHAR(500),
    "call_type" VARCHAR(50),
    "call_result" VARCHAR(50),
    "call_date" TIMESTAMP NOT NULL,
    "duration_minutes" INTEGER,
    "description" TEXT,
    "related_to_type" VARCHAR(50),
    "related_to_id" INTEGER,
    "owner_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.campaigns
CREATE TABLE IF NOT EXISTS "synthetic"."campaigns" (
    "campaign_id" SERIAL PRIMARY KEY,
    "campaign_name" VARCHAR(200) NOT NULL,
    "campaign_type" VARCHAR(50),
    "status" VARCHAR(50) DEFAULT 'planned',
    "start_date" DATE,
    "end_date" DATE,
    "budgeted_cost" DECIMAL(15,2),
    "actual_cost" DECIMAL(15,2) DEFAULT 0,
    "expected_revenue" DECIMAL(15,2),
    "expected_response" INTEGER,
    "num_sent" INTEGER DEFAULT 0,
    "num_responses" INTEGER DEFAULT 0,
    "description" TEXT,
    "owner_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.campaign_members
CREATE TABLE IF NOT EXISTS "synthetic"."campaign_members" (
    "member_id" SERIAL PRIMARY KEY,
    "campaign_id" INTEGER NOT NULL,
    "lead_id" INTEGER,
    "contact_id" INTEGER,
    "status" VARCHAR(50),
    "responded_date" DATE,
    "first_responded_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_campaign_members_campaign_id" FOREIGN KEY ("campaign_id") REFERENCES "synthetic"."campaigns" ("campaign_id"),
    CONSTRAINT "fk_campaign_members_lead_id" FOREIGN KEY ("lead_id") REFERENCES "synthetic"."leads" ("lead_id"),
    CONSTRAINT "fk_campaign_members_contact_id" FOREIGN KEY ("contact_id") REFERENCES "synthetic"."contacts" ("contact_id")
);
CREATE INDEX IF NOT EXISTS "idx_campaign_members_campaign_id" ON "synthetic"."campaign_members" ("campaign_id");
CREATE INDEX IF NOT EXISTS "idx_campaign_members_lead_id" ON "synthetic"."campaign_members" ("lead_id");
CREATE INDEX IF NOT EXISTS "idx_campaign_members_contact_id" ON "synthetic"."campaign_members" ("contact_id");

-- Table: synthetic.territories
CREATE TABLE IF NOT EXISTS "synthetic"."territories" (
    "territory_id" SERIAL PRIMARY KEY,
    "territory_name" VARCHAR(200) NOT NULL,
    "parent_territory_id" INTEGER,
    "description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_territories_parent_territory_id" FOREIGN KEY ("parent_territory_id") REFERENCES "synthetic"."territories" ("territory_id")
);
CREATE INDEX IF NOT EXISTS "idx_territories_parent_territory_id" ON "synthetic"."territories" ("parent_territory_id");

-- Table: synthetic.territory_assignments
CREATE TABLE IF NOT EXISTS "synthetic"."territory_assignments" (
    "assignment_id" SERIAL PRIMARY KEY,
    "territory_id" INTEGER NOT NULL,
    "user_id" INTEGER,
    "account_id" INTEGER,
    "assignment_type" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_territory_assignments_territory_id" FOREIGN KEY ("territory_id") REFERENCES "synthetic"."territories" ("territory_id"),
    CONSTRAINT "fk_territory_assignments_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_territory_assignments_territory_id" ON "synthetic"."territory_assignments" ("territory_id");
CREATE INDEX IF NOT EXISTS "idx_territory_assignments_account_id" ON "synthetic"."territory_assignments" ("account_id");

-- Table: synthetic.sales_teams
CREATE TABLE IF NOT EXISTS "synthetic"."sales_teams" (
    "team_id" SERIAL PRIMARY KEY,
    "team_name" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.team_members
CREATE TABLE IF NOT EXISTS "synthetic"."team_members" (
    "team_member_id" SERIAL PRIMARY KEY,
    "team_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "role" VARCHAR(100),
    "is_leader" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_team_members_team_id" FOREIGN KEY ("team_id") REFERENCES "synthetic"."sales_teams" ("team_id")
);
CREATE INDEX IF NOT EXISTS "idx_team_members_team_id" ON "synthetic"."team_members" ("team_id");

-- Table: synthetic.forecasts
CREATE TABLE IF NOT EXISTS "synthetic"."forecasts" (
    "forecast_id" SERIAL PRIMARY KEY,
    "user_id" INTEGER,
    "forecast_period" VARCHAR(20),
    "forecast_year" INTEGER,
    "quota_amount" DECIMAL(15,2),
    "forecast_amount" DECIMAL(15,2),
    "closed_amount" DECIMAL(15,2) DEFAULT 0,
    "pipeline_amount" DECIMAL(15,2) DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.price_books
CREATE TABLE IF NOT EXISTS "synthetic"."price_books" (
    "price_book_id" SERIAL PRIMARY KEY,
    "price_book_name" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "is_active" BOOLEAN DEFAULT true,
    "is_standard" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.price_book_entries
CREATE TABLE IF NOT EXISTS "synthetic"."price_book_entries" (
    "entry_id" SERIAL PRIMARY KEY,
    "price_book_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "unit_price" DECIMAL(15,2) NOT NULL,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_price_book_entries_price_book_id" FOREIGN KEY ("price_book_id") REFERENCES "synthetic"."price_books" ("price_book_id")
);
CREATE INDEX IF NOT EXISTS "idx_price_book_entries_price_book_id" ON "synthetic"."price_book_entries" ("price_book_id");

-- Table: synthetic.contracts
CREATE TABLE IF NOT EXISTS "synthetic"."contracts" (
    "contract_id" SERIAL PRIMARY KEY,
    "contract_number" VARCHAR(50) UNIQUE,
    "account_id" INTEGER,
    "contract_name" VARCHAR(200),
    "status" VARCHAR(50) DEFAULT 'draft',
    "start_date" DATE,
    "end_date" DATE,
    "contract_term" INTEGER,
    "contract_value" DECIMAL(15,2),
    "billing_frequency" VARCHAR(50),
    "description" TEXT,
    "owner_id" INTEGER,
    "signed_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_contracts_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_contracts_account_id" ON "synthetic"."contracts" ("account_id");

-- Table: synthetic.cases
CREATE TABLE IF NOT EXISTS "synthetic"."cases" (
    "case_id" SERIAL PRIMARY KEY,
    "case_number" VARCHAR(50) UNIQUE,
    "account_id" INTEGER,
    "contact_id" INTEGER,
    "subject" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "status" VARCHAR(50) DEFAULT 'new',
    "priority" VARCHAR(20),
    "type" VARCHAR(100),
    "reason" VARCHAR(200),
    "origin" VARCHAR(100),
    "owner_id" INTEGER,
    "closed_date" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_cases_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."accounts" ("account_id"),
    CONSTRAINT "fk_cases_contact_id" FOREIGN KEY ("contact_id") REFERENCES "synthetic"."contacts" ("contact_id")
);
CREATE INDEX IF NOT EXISTS "idx_cases_account_id" ON "synthetic"."cases" ("account_id");
CREATE INDEX IF NOT EXISTS "idx_cases_contact_id" ON "synthetic"."cases" ("contact_id");

-- Table: synthetic.case_comments
CREATE TABLE IF NOT EXISTS "synthetic"."case_comments" (
    "comment_id" SERIAL PRIMARY KEY,
    "case_id" INTEGER NOT NULL,
    "comment_body" TEXT NOT NULL,
    "is_public" BOOLEAN DEFAULT false,
    "author_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_case_comments_case_id" FOREIGN KEY ("case_id") REFERENCES "synthetic"."cases" ("case_id")
);
CREATE INDEX IF NOT EXISTS "idx_case_comments_case_id" ON "synthetic"."case_comments" ("case_id");

-- Table: synthetic.solutions
CREATE TABLE IF NOT EXISTS "synthetic"."solutions" (
    "solution_id" SERIAL PRIMARY KEY,
    "solution_title" VARCHAR(500) NOT NULL,
    "solution_body" TEXT,
    "status" VARCHAR(50) DEFAULT 'draft',
    "is_published" BOOLEAN DEFAULT false,
    "times_used" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.case_solutions
CREATE TABLE IF NOT EXISTS "synthetic"."case_solutions" (
    "case_solution_id" SERIAL PRIMARY KEY,
    "case_id" INTEGER NOT NULL,
    "solution_id" INTEGER NOT NULL,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_case_solutions_case_id" FOREIGN KEY ("case_id") REFERENCES "synthetic"."cases" ("case_id"),
    CONSTRAINT "fk_case_solutions_solution_id" FOREIGN KEY ("solution_id") REFERENCES "synthetic"."solutions" ("solution_id")
);
CREATE INDEX IF NOT EXISTS "idx_case_solutions_case_id" ON "synthetic"."case_solutions" ("case_id");
CREATE INDEX IF NOT EXISTS "idx_case_solutions_solution_id" ON "synthetic"."case_solutions" ("solution_id");

-- ============================================================================
-- Domain: HEALTHCARE AND MEDICAL RECORDS
-- ============================================================================


-- Table: synthetic.patients
CREATE TABLE IF NOT EXISTS "synthetic"."patients" (
    "patient_id" SERIAL PRIMARY KEY,
    "mrn" VARCHAR(50) UNIQUE,
    "first_name" VARCHAR(100) NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "date_of_birth" DATE NOT NULL,
    "gender" VARCHAR(10),
    "ssn_last4" VARCHAR(4),
    "email" VARCHAR(255),
    "phone" VARCHAR(20),
    "address" TEXT,
    "emergency_contact_name" VARCHAR(200),
    "emergency_contact_phone" VARCHAR(20),
    "primary_physician_id" INTEGER,
    "insurance_id" INTEGER,
    "blood_type" VARCHAR(10),
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_patients_primary_physician_id" FOREIGN KEY ("primary_physician_id") REFERENCES "synthetic"."physicians" ("physician_id"),
    CONSTRAINT "fk_patients_insurance_id" FOREIGN KEY ("insurance_id") REFERENCES "synthetic"."insurance_policies" ("insurance_id")
);
CREATE INDEX IF NOT EXISTS "idx_patients_primary_physician_id" ON "synthetic"."patients" ("primary_physician_id");
CREATE INDEX IF NOT EXISTS "idx_patients_insurance_id" ON "synthetic"."patients" ("insurance_id");

-- Table: synthetic.physicians
CREATE TABLE IF NOT EXISTS "synthetic"."physicians" (
    "physician_id" SERIAL PRIMARY KEY,
    "npi" VARCHAR(20) UNIQUE,
    "first_name" VARCHAR(100) NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "specialty" VARCHAR(100),
    "department_id" INTEGER,
    "email" VARCHAR(255),
    "phone" VARCHAR(20),
    "license_number" VARCHAR(50),
    "license_state" VARCHAR(2),
    "hire_date" DATE,
    "is_accepting_patients" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_physicians_department_id" FOREIGN KEY ("department_id") REFERENCES "synthetic"."medical_departments" ("department_id")
);
CREATE INDEX IF NOT EXISTS "idx_physicians_department_id" ON "synthetic"."physicians" ("department_id");

-- Table: synthetic.medical_departments
CREATE TABLE IF NOT EXISTS "synthetic"."medical_departments" (
    "department_id" SERIAL PRIMARY KEY,
    "department_name" VARCHAR(200) NOT NULL,
    "department_code" VARCHAR(20) UNIQUE,
    "location" VARCHAR(200),
    "phone" VARCHAR(20),
    "head_physician_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.appointments
CREATE TABLE IF NOT EXISTS "synthetic"."appointments" (
    "appointment_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "physician_id" INTEGER NOT NULL,
    "appointment_date" TIMESTAMP NOT NULL,
    "duration_minutes" INTEGER DEFAULT 30,
    "appointment_type" VARCHAR(50),
    "status" VARCHAR(50) DEFAULT 'scheduled',
    "reason" TEXT,
    "notes" TEXT,
    "room_number" VARCHAR(20),
    "checked_in_at" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_appointments_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_appointments_physician_id" FOREIGN KEY ("physician_id") REFERENCES "synthetic"."physicians" ("physician_id")
);
CREATE INDEX IF NOT EXISTS "idx_appointments_patient_id" ON "synthetic"."appointments" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_appointments_physician_id" ON "synthetic"."appointments" ("physician_id");

-- Table: synthetic.encounters
CREATE TABLE IF NOT EXISTS "synthetic"."encounters" (
    "encounter_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "physician_id" INTEGER NOT NULL,
    "appointment_id" INTEGER,
    "encounter_date" TIMESTAMP NOT NULL,
    "encounter_type" VARCHAR(50),
    "chief_complaint" TEXT,
    "notes" TEXT,
    "status" VARCHAR(50) DEFAULT 'in_progress',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_encounters_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_encounters_physician_id" FOREIGN KEY ("physician_id") REFERENCES "synthetic"."physicians" ("physician_id"),
    CONSTRAINT "fk_encounters_appointment_id" FOREIGN KEY ("appointment_id") REFERENCES "synthetic"."appointments" ("appointment_id")
);
CREATE INDEX IF NOT EXISTS "idx_encounters_patient_id" ON "synthetic"."encounters" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_encounters_physician_id" ON "synthetic"."encounters" ("physician_id");
CREATE INDEX IF NOT EXISTS "idx_encounters_appointment_id" ON "synthetic"."encounters" ("appointment_id");

-- Table: synthetic.diagnoses
CREATE TABLE IF NOT EXISTS "synthetic"."diagnoses" (
    "diagnosis_id" SERIAL PRIMARY KEY,
    "encounter_id" INTEGER NOT NULL,
    "icd10_code" VARCHAR(20),
    "diagnosis_description" TEXT,
    "diagnosis_date" DATE,
    "is_primary" BOOLEAN DEFAULT false,
    "severity" VARCHAR(50),
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_diagnoses_encounter_id" FOREIGN KEY ("encounter_id") REFERENCES "synthetic"."encounters" ("encounter_id")
);
CREATE INDEX IF NOT EXISTS "idx_diagnoses_encounter_id" ON "synthetic"."diagnoses" ("encounter_id");

-- Table: synthetic.prescriptions
CREATE TABLE IF NOT EXISTS "synthetic"."prescriptions" (
    "prescription_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "physician_id" INTEGER NOT NULL,
    "encounter_id" INTEGER,
    "medication_id" INTEGER,
    "dosage" VARCHAR(100),
    "frequency" VARCHAR(100),
    "quantity" INTEGER,
    "refills" INTEGER DEFAULT 0,
    "start_date" DATE,
    "end_date" DATE,
    "instructions" TEXT,
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_prescriptions_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_prescriptions_physician_id" FOREIGN KEY ("physician_id") REFERENCES "synthetic"."physicians" ("physician_id"),
    CONSTRAINT "fk_prescriptions_encounter_id" FOREIGN KEY ("encounter_id") REFERENCES "synthetic"."encounters" ("encounter_id"),
    CONSTRAINT "fk_prescriptions_medication_id" FOREIGN KEY ("medication_id") REFERENCES "synthetic"."medications" ("medication_id")
);
CREATE INDEX IF NOT EXISTS "idx_prescriptions_patient_id" ON "synthetic"."prescriptions" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_prescriptions_physician_id" ON "synthetic"."prescriptions" ("physician_id");
CREATE INDEX IF NOT EXISTS "idx_prescriptions_encounter_id" ON "synthetic"."prescriptions" ("encounter_id");
CREATE INDEX IF NOT EXISTS "idx_prescriptions_medication_id" ON "synthetic"."prescriptions" ("medication_id");

-- Table: synthetic.medications
CREATE TABLE IF NOT EXISTS "synthetic"."medications" (
    "medication_id" SERIAL PRIMARY KEY,
    "ndc_code" VARCHAR(20),
    "medication_name" VARCHAR(200) NOT NULL,
    "generic_name" VARCHAR(200),
    "drug_class" VARCHAR(100),
    "form" VARCHAR(50),
    "strength" VARCHAR(100),
    "manufacturer" VARCHAR(200),
    "is_controlled" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.allergies
CREATE TABLE IF NOT EXISTS "synthetic"."allergies" (
    "allergy_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "allergen" VARCHAR(200) NOT NULL,
    "allergy_type" VARCHAR(50),
    "reaction" TEXT,
    "severity" VARCHAR(50),
    "onset_date" DATE,
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_allergies_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id")
);
CREATE INDEX IF NOT EXISTS "idx_allergies_patient_id" ON "synthetic"."allergies" ("patient_id");

-- Table: synthetic.lab_orders
CREATE TABLE IF NOT EXISTS "synthetic"."lab_orders" (
    "order_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "physician_id" INTEGER NOT NULL,
    "encounter_id" INTEGER,
    "order_date" TIMESTAMP NOT NULL,
    "status" VARCHAR(50) DEFAULT 'ordered',
    "priority" VARCHAR(20),
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_lab_orders_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_lab_orders_physician_id" FOREIGN KEY ("physician_id") REFERENCES "synthetic"."physicians" ("physician_id"),
    CONSTRAINT "fk_lab_orders_encounter_id" FOREIGN KEY ("encounter_id") REFERENCES "synthetic"."encounters" ("encounter_id")
);
CREATE INDEX IF NOT EXISTS "idx_lab_orders_patient_id" ON "synthetic"."lab_orders" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_lab_orders_physician_id" ON "synthetic"."lab_orders" ("physician_id");
CREATE INDEX IF NOT EXISTS "idx_lab_orders_encounter_id" ON "synthetic"."lab_orders" ("encounter_id");

-- Table: synthetic.lab_tests
CREATE TABLE IF NOT EXISTS "synthetic"."lab_tests" (
    "test_id" SERIAL PRIMARY KEY,
    "test_code" VARCHAR(50) UNIQUE,
    "test_name" VARCHAR(200) NOT NULL,
    "category" VARCHAR(100),
    "specimen_type" VARCHAR(100),
    "normal_range" VARCHAR(200),
    "unit" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.lab_results
CREATE TABLE IF NOT EXISTS "synthetic"."lab_results" (
    "result_id" SERIAL PRIMARY KEY,
    "order_id" INTEGER NOT NULL,
    "test_id" INTEGER NOT NULL,
    "result_value" VARCHAR(200),
    "result_unit" VARCHAR(50),
    "reference_range" VARCHAR(200),
    "abnormal_flag" VARCHAR(10),
    "collected_date" TIMESTAMP,
    "resulted_date" TIMESTAMP,
    "status" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_lab_results_order_id" FOREIGN KEY ("order_id") REFERENCES "synthetic"."lab_orders" ("order_id"),
    CONSTRAINT "fk_lab_results_test_id" FOREIGN KEY ("test_id") REFERENCES "synthetic"."lab_tests" ("test_id")
);
CREATE INDEX IF NOT EXISTS "idx_lab_results_order_id" ON "synthetic"."lab_results" ("order_id");
CREATE INDEX IF NOT EXISTS "idx_lab_results_test_id" ON "synthetic"."lab_results" ("test_id");

-- Table: synthetic.vital_signs
CREATE TABLE IF NOT EXISTS "synthetic"."vital_signs" (
    "vital_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "encounter_id" INTEGER,
    "recorded_at" TIMESTAMP NOT NULL,
    "temperature_f" DECIMAL(5,2),
    "blood_pressure_systolic" INTEGER,
    "blood_pressure_diastolic" INTEGER,
    "heart_rate" INTEGER,
    "respiratory_rate" INTEGER,
    "oxygen_saturation" DECIMAL(5,2),
    "weight_kg" DECIMAL(6,2),
    "height_cm" DECIMAL(5,1),
    "bmi" DECIMAL(5,2),
    "recorded_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_vital_signs_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_vital_signs_encounter_id" FOREIGN KEY ("encounter_id") REFERENCES "synthetic"."encounters" ("encounter_id")
);
CREATE INDEX IF NOT EXISTS "idx_vital_signs_patient_id" ON "synthetic"."vital_signs" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_vital_signs_encounter_id" ON "synthetic"."vital_signs" ("encounter_id");

-- Table: synthetic.immunizations
CREATE TABLE IF NOT EXISTS "synthetic"."immunizations" (
    "immunization_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "vaccine_name" VARCHAR(200) NOT NULL,
    "cvx_code" VARCHAR(20),
    "administration_date" DATE NOT NULL,
    "lot_number" VARCHAR(50),
    "expiration_date" DATE,
    "site" VARCHAR(100),
    "dose_number" INTEGER,
    "administered_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_immunizations_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id")
);
CREATE INDEX IF NOT EXISTS "idx_immunizations_patient_id" ON "synthetic"."immunizations" ("patient_id");

-- Table: synthetic.insurance_policies
CREATE TABLE IF NOT EXISTS "synthetic"."insurance_policies" (
    "insurance_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "payer_name" VARCHAR(200) NOT NULL,
    "policy_number" VARCHAR(100),
    "group_number" VARCHAR(100),
    "subscriber_name" VARCHAR(200),
    "relationship_to_subscriber" VARCHAR(50),
    "coverage_type" VARCHAR(50),
    "effective_date" DATE,
    "termination_date" DATE,
    "is_primary" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_insurance_policies_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id")
);
CREATE INDEX IF NOT EXISTS "idx_insurance_policies_patient_id" ON "synthetic"."insurance_policies" ("patient_id");

-- Table: synthetic.medical_claims
CREATE TABLE IF NOT EXISTS "synthetic"."medical_claims" (
    "claim_id" SERIAL PRIMARY KEY,
    "claim_number" VARCHAR(50) UNIQUE,
    "patient_id" INTEGER NOT NULL,
    "encounter_id" INTEGER,
    "insurance_id" INTEGER,
    "service_date" DATE NOT NULL,
    "submitted_date" DATE,
    "total_charges" DECIMAL(15,2),
    "allowed_amount" DECIMAL(15,2),
    "paid_amount" DECIMAL(15,2),
    "patient_responsibility" DECIMAL(15,2),
    "status" VARCHAR(50) DEFAULT 'pending',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_medical_claims_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_medical_claims_encounter_id" FOREIGN KEY ("encounter_id") REFERENCES "synthetic"."encounters" ("encounter_id"),
    CONSTRAINT "fk_medical_claims_insurance_id" FOREIGN KEY ("insurance_id") REFERENCES "synthetic"."insurance_policies" ("insurance_id")
);
CREATE INDEX IF NOT EXISTS "idx_medical_claims_patient_id" ON "synthetic"."medical_claims" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_medical_claims_encounter_id" ON "synthetic"."medical_claims" ("encounter_id");
CREATE INDEX IF NOT EXISTS "idx_medical_claims_insurance_id" ON "synthetic"."medical_claims" ("insurance_id");

-- Table: synthetic.claim_lines
CREATE TABLE IF NOT EXISTS "synthetic"."claim_lines" (
    "claim_line_id" SERIAL PRIMARY KEY,
    "claim_id" INTEGER NOT NULL,
    "procedure_code" VARCHAR(20),
    "modifier" VARCHAR(20),
    "diagnosis_pointer" VARCHAR(20),
    "units" INTEGER DEFAULT 1,
    "charge_amount" DECIMAL(15,2),
    "allowed_amount" DECIMAL(15,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_claim_lines_claim_id" FOREIGN KEY ("claim_id") REFERENCES "synthetic"."medical_claims" ("claim_id")
);
CREATE INDEX IF NOT EXISTS "idx_claim_lines_claim_id" ON "synthetic"."claim_lines" ("claim_id");

-- Table: synthetic.procedures
CREATE TABLE IF NOT EXISTS "synthetic"."procedures" (
    "procedure_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "physician_id" INTEGER,
    "encounter_id" INTEGER,
    "cpt_code" VARCHAR(20),
    "procedure_name" VARCHAR(500),
    "procedure_date" TIMESTAMP,
    "notes" TEXT,
    "status" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_procedures_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_procedures_physician_id" FOREIGN KEY ("physician_id") REFERENCES "synthetic"."physicians" ("physician_id"),
    CONSTRAINT "fk_procedures_encounter_id" FOREIGN KEY ("encounter_id") REFERENCES "synthetic"."encounters" ("encounter_id")
);
CREATE INDEX IF NOT EXISTS "idx_procedures_patient_id" ON "synthetic"."procedures" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_procedures_physician_id" ON "synthetic"."procedures" ("physician_id");
CREATE INDEX IF NOT EXISTS "idx_procedures_encounter_id" ON "synthetic"."procedures" ("encounter_id");

-- Table: synthetic.referrals
CREATE TABLE IF NOT EXISTS "synthetic"."referrals" (
    "referral_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "referring_physician_id" INTEGER,
    "referred_to_physician_id" INTEGER,
    "referral_date" DATE NOT NULL,
    "reason" TEXT,
    "urgency" VARCHAR(50),
    "status" VARCHAR(50) DEFAULT 'pending',
    "authorization_number" VARCHAR(100),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_referrals_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_referrals_referring_physician_id" FOREIGN KEY ("referring_physician_id") REFERENCES "synthetic"."physicians" ("physician_id"),
    CONSTRAINT "fk_referrals_referred_to_physician_id" FOREIGN KEY ("referred_to_physician_id") REFERENCES "synthetic"."physicians" ("physician_id")
);
CREATE INDEX IF NOT EXISTS "idx_referrals_patient_id" ON "synthetic"."referrals" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_referrals_referring_physician_id" ON "synthetic"."referrals" ("referring_physician_id");
CREATE INDEX IF NOT EXISTS "idx_referrals_referred_to_physician_id" ON "synthetic"."referrals" ("referred_to_physician_id");

-- Table: synthetic.medical_history
CREATE TABLE IF NOT EXISTS "synthetic"."medical_history" (
    "history_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "condition" VARCHAR(500) NOT NULL,
    "icd10_code" VARCHAR(20),
    "onset_date" DATE,
    "resolution_date" DATE,
    "status" VARCHAR(50) DEFAULT 'active',
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_medical_history_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id")
);
CREATE INDEX IF NOT EXISTS "idx_medical_history_patient_id" ON "synthetic"."medical_history" ("patient_id");

-- Table: synthetic.family_history
CREATE TABLE IF NOT EXISTS "synthetic"."family_history" (
    "family_history_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "relationship" VARCHAR(50) NOT NULL,
    "condition" VARCHAR(500) NOT NULL,
    "age_at_onset" INTEGER,
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_family_history_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id")
);
CREATE INDEX IF NOT EXISTS "idx_family_history_patient_id" ON "synthetic"."family_history" ("patient_id");

-- Table: synthetic.care_plans
CREATE TABLE IF NOT EXISTS "synthetic"."care_plans" (
    "plan_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "physician_id" INTEGER,
    "plan_name" VARCHAR(200),
    "start_date" DATE,
    "end_date" DATE,
    "goals" TEXT,
    "interventions" TEXT,
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_care_plans_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_care_plans_physician_id" FOREIGN KEY ("physician_id") REFERENCES "synthetic"."physicians" ("physician_id")
);
CREATE INDEX IF NOT EXISTS "idx_care_plans_patient_id" ON "synthetic"."care_plans" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_care_plans_physician_id" ON "synthetic"."care_plans" ("physician_id");

-- Table: synthetic.care_team_members
CREATE TABLE IF NOT EXISTS "synthetic"."care_team_members" (
    "team_member_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "physician_id" INTEGER,
    "role" VARCHAR(100),
    "start_date" DATE,
    "end_date" DATE,
    "is_primary" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_care_team_members_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id"),
    CONSTRAINT "fk_care_team_members_physician_id" FOREIGN KEY ("physician_id") REFERENCES "synthetic"."physicians" ("physician_id")
);
CREATE INDEX IF NOT EXISTS "idx_care_team_members_patient_id" ON "synthetic"."care_team_members" ("patient_id");
CREATE INDEX IF NOT EXISTS "idx_care_team_members_physician_id" ON "synthetic"."care_team_members" ("physician_id");

-- Table: synthetic.patient_consents
CREATE TABLE IF NOT EXISTS "synthetic"."patient_consents" (
    "consent_id" SERIAL PRIMARY KEY,
    "patient_id" INTEGER NOT NULL,
    "consent_type" VARCHAR(100) NOT NULL,
    "consent_date" DATE NOT NULL,
    "expiration_date" DATE,
    "granted_by" VARCHAR(200),
    "status" VARCHAR(50) DEFAULT 'active',
    "document_url" VARCHAR(500),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_patient_consents_patient_id" FOREIGN KEY ("patient_id") REFERENCES "synthetic"."patients" ("patient_id")
);
CREATE INDEX IF NOT EXISTS "idx_patient_consents_patient_id" ON "synthetic"."patient_consents" ("patient_id");

-- ============================================================================
-- Domain: PROJECT MANAGEMENT AND TASK TRACKING
-- ============================================================================


-- Table: synthetic.project_portfolio
CREATE TABLE IF NOT EXISTS "synthetic"."project_portfolio" (
    "portfolio_id" SERIAL PRIMARY KEY,
    "portfolio_name" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "owner_id" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.pm_projects
CREATE TABLE IF NOT EXISTS "synthetic"."pm_projects" (
    "project_id" SERIAL PRIMARY KEY,
    "project_code" VARCHAR(50) UNIQUE,
    "project_name" VARCHAR(200) NOT NULL,
    "portfolio_id" INTEGER,
    "description" TEXT,
    "start_date" DATE,
    "target_end_date" DATE,
    "actual_end_date" DATE,
    "status" VARCHAR(50) DEFAULT 'planning',
    "priority" VARCHAR(20),
    "project_manager_id" INTEGER,
    "budget" DECIMAL(15,2),
    "actual_cost" DECIMAL(15,2) DEFAULT 0,
    "percent_complete" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_pm_projects_portfolio_id" FOREIGN KEY ("portfolio_id") REFERENCES "synthetic"."project_portfolio" ("portfolio_id")
);
CREATE INDEX IF NOT EXISTS "idx_pm_projects_portfolio_id" ON "synthetic"."pm_projects" ("portfolio_id");

-- Table: synthetic.project_phases
CREATE TABLE IF NOT EXISTS "synthetic"."project_phases" (
    "phase_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "phase_name" VARCHAR(200) NOT NULL,
    "phase_order" INTEGER,
    "start_date" DATE,
    "end_date" DATE,
    "status" VARCHAR(50) DEFAULT 'not_started',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_phases_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_phases_project_id" ON "synthetic"."project_phases" ("project_id");

-- Table: synthetic.milestones
CREATE TABLE IF NOT EXISTS "synthetic"."milestones" (
    "milestone_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "phase_id" INTEGER,
    "milestone_name" VARCHAR(200) NOT NULL,
    "due_date" DATE,
    "completed_date" DATE,
    "status" VARCHAR(50) DEFAULT 'pending',
    "description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_milestones_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id"),
    CONSTRAINT "fk_milestones_phase_id" FOREIGN KEY ("phase_id") REFERENCES "synthetic"."project_phases" ("phase_id")
);
CREATE INDEX IF NOT EXISTS "idx_milestones_project_id" ON "synthetic"."milestones" ("project_id");
CREATE INDEX IF NOT EXISTS "idx_milestones_phase_id" ON "synthetic"."milestones" ("phase_id");

-- Table: synthetic.pm_tasks
CREATE TABLE IF NOT EXISTS "synthetic"."pm_tasks" (
    "task_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "phase_id" INTEGER,
    "milestone_id" INTEGER,
    "parent_task_id" INTEGER,
    "task_name" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "assigned_to" INTEGER,
    "start_date" DATE,
    "due_date" DATE,
    "completed_date" DATE,
    "estimated_hours" DECIMAL(8,2),
    "actual_hours" DECIMAL(8,2) DEFAULT 0,
    "priority" VARCHAR(20),
    "status" VARCHAR(50) DEFAULT 'todo',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_pm_tasks_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id"),
    CONSTRAINT "fk_pm_tasks_phase_id" FOREIGN KEY ("phase_id") REFERENCES "synthetic"."project_phases" ("phase_id"),
    CONSTRAINT "fk_pm_tasks_milestone_id" FOREIGN KEY ("milestone_id") REFERENCES "synthetic"."milestones" ("milestone_id"),
    CONSTRAINT "fk_pm_tasks_parent_task_id" FOREIGN KEY ("parent_task_id") REFERENCES "synthetic"."pm_tasks" ("task_id")
);
CREATE INDEX IF NOT EXISTS "idx_pm_tasks_project_id" ON "synthetic"."pm_tasks" ("project_id");
CREATE INDEX IF NOT EXISTS "idx_pm_tasks_phase_id" ON "synthetic"."pm_tasks" ("phase_id");
CREATE INDEX IF NOT EXISTS "idx_pm_tasks_milestone_id" ON "synthetic"."pm_tasks" ("milestone_id");
CREATE INDEX IF NOT EXISTS "idx_pm_tasks_parent_task_id" ON "synthetic"."pm_tasks" ("parent_task_id");

-- Table: synthetic.task_dependencies
CREATE TABLE IF NOT EXISTS "synthetic"."task_dependencies" (
    "dependency_id" SERIAL PRIMARY KEY,
    "task_id" INTEGER NOT NULL,
    "depends_on_task_id" INTEGER NOT NULL,
    "dependency_type" VARCHAR(50) DEFAULT 'finish_to_start',
    "lag_days" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_task_dependencies_task_id" FOREIGN KEY ("task_id") REFERENCES "synthetic"."pm_tasks" ("task_id"),
    CONSTRAINT "fk_task_dependencies_depends_on_task_id" FOREIGN KEY ("depends_on_task_id") REFERENCES "synthetic"."pm_tasks" ("task_id")
);
CREATE INDEX IF NOT EXISTS "idx_task_dependencies_task_id" ON "synthetic"."task_dependencies" ("task_id");
CREATE INDEX IF NOT EXISTS "idx_task_dependencies_depends_on_task_id" ON "synthetic"."task_dependencies" ("depends_on_task_id");

-- Table: synthetic.task_assignments
CREATE TABLE IF NOT EXISTS "synthetic"."task_assignments" (
    "assignment_id" SERIAL PRIMARY KEY,
    "task_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "role" VARCHAR(100),
    "allocation_percentage" INTEGER DEFAULT 100,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_task_assignments_task_id" FOREIGN KEY ("task_id") REFERENCES "synthetic"."pm_tasks" ("task_id")
);
CREATE INDEX IF NOT EXISTS "idx_task_assignments_task_id" ON "synthetic"."task_assignments" ("task_id");

-- Table: synthetic.time_entries
CREATE TABLE IF NOT EXISTS "synthetic"."time_entries" (
    "entry_id" SERIAL PRIMARY KEY,
    "task_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "entry_date" DATE NOT NULL,
    "hours_worked" DECIMAL(5,2) NOT NULL,
    "description" TEXT,
    "is_billable" BOOLEAN DEFAULT true,
    "billing_rate" DECIMAL(10,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_time_entries_task_id" FOREIGN KEY ("task_id") REFERENCES "synthetic"."pm_tasks" ("task_id")
);
CREATE INDEX IF NOT EXISTS "idx_time_entries_task_id" ON "synthetic"."time_entries" ("task_id");

-- Table: synthetic.project_members
CREATE TABLE IF NOT EXISTS "synthetic"."project_members" (
    "member_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "role" VARCHAR(100),
    "join_date" DATE,
    "leave_date" DATE,
    "hourly_rate" DECIMAL(10,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_members_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_members_project_id" ON "synthetic"."project_members" ("project_id");

-- Table: synthetic.project_risks
CREATE TABLE IF NOT EXISTS "synthetic"."project_risks" (
    "risk_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "risk_name" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "probability" VARCHAR(20),
    "impact" VARCHAR(20),
    "risk_score" INTEGER,
    "mitigation_plan" TEXT,
    "owner_id" INTEGER,
    "status" VARCHAR(50) DEFAULT 'identified',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_risks_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_risks_project_id" ON "synthetic"."project_risks" ("project_id");

-- Table: synthetic.project_issues
CREATE TABLE IF NOT EXISTS "synthetic"."project_issues" (
    "issue_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "issue_title" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "priority" VARCHAR(20),
    "severity" VARCHAR(20),
    "assigned_to" INTEGER,
    "reported_by" INTEGER,
    "status" VARCHAR(50) DEFAULT 'open',
    "resolution" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_issues_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_issues_project_id" ON "synthetic"."project_issues" ("project_id");

-- Table: synthetic.project_documents
CREATE TABLE IF NOT EXISTS "synthetic"."project_documents" (
    "document_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "document_name" VARCHAR(200) NOT NULL,
    "document_type" VARCHAR(50),
    "file_path" VARCHAR(500),
    "version" VARCHAR(20),
    "uploaded_by" INTEGER,
    "upload_date" TIMESTAMP,
    "description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_documents_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_documents_project_id" ON "synthetic"."project_documents" ("project_id");

-- Table: synthetic.project_comments
CREATE TABLE IF NOT EXISTS "synthetic"."project_comments" (
    "comment_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER,
    "task_id" INTEGER,
    "parent_comment_id" INTEGER,
    "comment_text" TEXT NOT NULL,
    "author_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_comments_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id"),
    CONSTRAINT "fk_project_comments_task_id" FOREIGN KEY ("task_id") REFERENCES "synthetic"."pm_tasks" ("task_id"),
    CONSTRAINT "fk_project_comments_parent_comment_id" FOREIGN KEY ("parent_comment_id") REFERENCES "synthetic"."project_comments" ("comment_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_comments_project_id" ON "synthetic"."project_comments" ("project_id");
CREATE INDEX IF NOT EXISTS "idx_project_comments_task_id" ON "synthetic"."project_comments" ("task_id");
CREATE INDEX IF NOT EXISTS "idx_project_comments_parent_comment_id" ON "synthetic"."project_comments" ("parent_comment_id");

-- Table: synthetic.sprints
CREATE TABLE IF NOT EXISTS "synthetic"."sprints" (
    "sprint_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "sprint_name" VARCHAR(100) NOT NULL,
    "sprint_number" INTEGER,
    "start_date" DATE,
    "end_date" DATE,
    "goal" TEXT,
    "status" VARCHAR(50) DEFAULT 'planning',
    "velocity" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_sprints_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_sprints_project_id" ON "synthetic"."sprints" ("project_id");

-- Table: synthetic.sprint_tasks
CREATE TABLE IF NOT EXISTS "synthetic"."sprint_tasks" (
    "sprint_task_id" SERIAL PRIMARY KEY,
    "sprint_id" INTEGER NOT NULL,
    "task_id" INTEGER NOT NULL,
    "story_points" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_sprint_tasks_sprint_id" FOREIGN KEY ("sprint_id") REFERENCES "synthetic"."sprints" ("sprint_id"),
    CONSTRAINT "fk_sprint_tasks_task_id" FOREIGN KEY ("task_id") REFERENCES "synthetic"."pm_tasks" ("task_id")
);
CREATE INDEX IF NOT EXISTS "idx_sprint_tasks_sprint_id" ON "synthetic"."sprint_tasks" ("sprint_id");
CREATE INDEX IF NOT EXISTS "idx_sprint_tasks_task_id" ON "synthetic"."sprint_tasks" ("task_id");

-- Table: synthetic.resource_calendar
CREATE TABLE IF NOT EXISTS "synthetic"."resource_calendar" (
    "calendar_id" SERIAL PRIMARY KEY,
    "user_id" INTEGER NOT NULL,
    "date" DATE NOT NULL,
    "available_hours" DECIMAL(4,2) DEFAULT 8,
    "is_working_day" BOOLEAN DEFAULT true,
    "notes" VARCHAR(500),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.project_budgets
CREATE TABLE IF NOT EXISTS "synthetic"."project_budgets" (
    "budget_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "category" VARCHAR(100),
    "budgeted_amount" DECIMAL(15,2) NOT NULL,
    "actual_amount" DECIMAL(15,2) DEFAULT 0,
    "variance" DECIMAL(15,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_budgets_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_budgets_project_id" ON "synthetic"."project_budgets" ("project_id");

-- Table: synthetic.change_requests
CREATE TABLE IF NOT EXISTS "synthetic"."change_requests" (
    "request_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "request_title" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "impact_analysis" TEXT,
    "requested_by" INTEGER,
    "request_date" DATE,
    "status" VARCHAR(50) DEFAULT 'submitted',
    "approved_by" INTEGER,
    "approval_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_change_requests_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_change_requests_project_id" ON "synthetic"."change_requests" ("project_id");

-- Table: synthetic.project_status_reports
CREATE TABLE IF NOT EXISTS "synthetic"."project_status_reports" (
    "report_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "report_date" DATE NOT NULL,
    "overall_status" VARCHAR(50),
    "schedule_status" VARCHAR(50),
    "budget_status" VARCHAR(50),
    "accomplishments" TEXT,
    "upcoming_tasks" TEXT,
    "issues_risks" TEXT,
    "submitted_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_project_status_reports_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_project_status_reports_project_id" ON "synthetic"."project_status_reports" ("project_id");

-- Table: synthetic.lessons_learned
CREATE TABLE IF NOT EXISTS "synthetic"."lessons_learned" (
    "lesson_id" SERIAL PRIMARY KEY,
    "project_id" INTEGER NOT NULL,
    "lesson_title" VARCHAR(500) NOT NULL,
    "category" VARCHAR(100),
    "description" TEXT,
    "recommendation" TEXT,
    "recorded_by" INTEGER,
    "record_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_lessons_learned_project_id" FOREIGN KEY ("project_id") REFERENCES "synthetic"."pm_projects" ("project_id")
);
CREATE INDEX IF NOT EXISTS "idx_lessons_learned_project_id" ON "synthetic"."lessons_learned" ("project_id");

-- ============================================================================
-- Domain: MARKETING AND DIGITAL ANALYTICS
-- ============================================================================


-- Table: synthetic.marketing_campaigns
CREATE TABLE IF NOT EXISTS "synthetic"."marketing_campaigns" (
    "campaign_id" SERIAL PRIMARY KEY,
    "campaign_name" VARCHAR(200) NOT NULL,
    "campaign_type" VARCHAR(50),
    "channel" VARCHAR(50),
    "status" VARCHAR(50) DEFAULT 'draft',
    "start_date" DATE,
    "end_date" DATE,
    "budget" DECIMAL(15,2),
    "actual_spend" DECIMAL(15,2) DEFAULT 0,
    "target_audience" TEXT,
    "goals" TEXT,
    "owner_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.email_campaigns
CREATE TABLE IF NOT EXISTS "synthetic"."email_campaigns" (
    "email_campaign_id" SERIAL PRIMARY KEY,
    "campaign_id" INTEGER,
    "subject_line" VARCHAR(500) NOT NULL,
    "from_name" VARCHAR(200),
    "from_email" VARCHAR(255),
    "reply_to" VARCHAR(255),
    "template_id" INTEGER,
    "scheduled_date" TIMESTAMP,
    "sent_date" TIMESTAMP,
    "status" VARCHAR(50) DEFAULT 'draft',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_email_campaigns_campaign_id" FOREIGN KEY ("campaign_id") REFERENCES "synthetic"."marketing_campaigns" ("campaign_id"),
    CONSTRAINT "fk_email_campaigns_template_id" FOREIGN KEY ("template_id") REFERENCES "synthetic"."email_templates" ("template_id")
);
CREATE INDEX IF NOT EXISTS "idx_email_campaigns_campaign_id" ON "synthetic"."email_campaigns" ("campaign_id");
CREATE INDEX IF NOT EXISTS "idx_email_campaigns_template_id" ON "synthetic"."email_campaigns" ("template_id");

-- Table: synthetic.email_templates
CREATE TABLE IF NOT EXISTS "synthetic"."email_templates" (
    "template_id" SERIAL PRIMARY KEY,
    "template_name" VARCHAR(200) NOT NULL,
    "subject" VARCHAR(500),
    "html_content" TEXT,
    "text_content" TEXT,
    "category" VARCHAR(100),
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.email_sends
CREATE TABLE IF NOT EXISTS "synthetic"."email_sends" (
    "send_id" SERIAL PRIMARY KEY,
    "email_campaign_id" INTEGER NOT NULL,
    "recipient_email" VARCHAR(255) NOT NULL,
    "contact_id" INTEGER,
    "sent_at" TIMESTAMP,
    "delivered_at" TIMESTAMP,
    "opened_at" TIMESTAMP,
    "clicked_at" TIMESTAMP,
    "bounced" BOOLEAN DEFAULT false,
    "bounce_type" VARCHAR(50),
    "unsubscribed" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_email_sends_email_campaign_id" FOREIGN KEY ("email_campaign_id") REFERENCES "synthetic"."email_campaigns" ("email_campaign_id")
);
CREATE INDEX IF NOT EXISTS "idx_email_sends_email_campaign_id" ON "synthetic"."email_sends" ("email_campaign_id");

-- Table: synthetic.email_clicks
CREATE TABLE IF NOT EXISTS "synthetic"."email_clicks" (
    "click_id" SERIAL PRIMARY KEY,
    "send_id" INTEGER NOT NULL,
    "link_url" VARCHAR(1000),
    "clicked_at" TIMESTAMP,
    "user_agent" VARCHAR(500),
    "ip_address" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_email_clicks_send_id" FOREIGN KEY ("send_id") REFERENCES "synthetic"."email_sends" ("send_id")
);
CREATE INDEX IF NOT EXISTS "idx_email_clicks_send_id" ON "synthetic"."email_clicks" ("send_id");

-- Table: synthetic.mailing_lists
CREATE TABLE IF NOT EXISTS "synthetic"."mailing_lists" (
    "list_id" SERIAL PRIMARY KEY,
    "list_name" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "is_active" BOOLEAN DEFAULT true,
    "subscriber_count" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.list_subscribers
CREATE TABLE IF NOT EXISTS "synthetic"."list_subscribers" (
    "subscriber_id" SERIAL PRIMARY KEY,
    "list_id" INTEGER NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "first_name" VARCHAR(100),
    "last_name" VARCHAR(100),
    "subscribed_at" TIMESTAMP,
    "unsubscribed_at" TIMESTAMP,
    "status" VARCHAR(50) DEFAULT 'active',
    "source" VARCHAR(100),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_list_subscribers_list_id" FOREIGN KEY ("list_id") REFERENCES "synthetic"."mailing_lists" ("list_id")
);
CREATE INDEX IF NOT EXISTS "idx_list_subscribers_list_id" ON "synthetic"."list_subscribers" ("list_id");

-- Table: synthetic.landing_pages
CREATE TABLE IF NOT EXISTS "synthetic"."landing_pages" (
    "page_id" SERIAL PRIMARY KEY,
    "campaign_id" INTEGER,
    "page_name" VARCHAR(200) NOT NULL,
    "url_slug" VARCHAR(200) UNIQUE,
    "html_content" TEXT,
    "meta_title" VARCHAR(200),
    "meta_description" TEXT,
    "status" VARCHAR(50) DEFAULT 'draft',
    "published_at" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_landing_pages_campaign_id" FOREIGN KEY ("campaign_id") REFERENCES "synthetic"."marketing_campaigns" ("campaign_id")
);
CREATE INDEX IF NOT EXISTS "idx_landing_pages_campaign_id" ON "synthetic"."landing_pages" ("campaign_id");

-- Table: synthetic.landing_page_conversions
CREATE TABLE IF NOT EXISTS "synthetic"."landing_page_conversions" (
    "conversion_id" SERIAL PRIMARY KEY,
    "page_id" INTEGER NOT NULL,
    "visitor_id" VARCHAR(100),
    "converted_at" TIMESTAMP,
    "conversion_type" VARCHAR(100),
    "conversion_value" DECIMAL(15,2),
    "source" VARCHAR(200),
    "medium" VARCHAR(100),
    "campaign" VARCHAR(200),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_landing_page_conversions_page_id" FOREIGN KEY ("page_id") REFERENCES "synthetic"."landing_pages" ("page_id")
);
CREATE INDEX IF NOT EXISTS "idx_landing_page_conversions_page_id" ON "synthetic"."landing_page_conversions" ("page_id");

-- Table: synthetic.web_analytics_sessions
CREATE TABLE IF NOT EXISTS "synthetic"."web_analytics_sessions" (
    "session_id" SERIAL PRIMARY KEY,
    "visitor_id" VARCHAR(100),
    "session_start" TIMESTAMP NOT NULL,
    "session_end" TIMESTAMP,
    "duration_seconds" INTEGER,
    "page_views" INTEGER DEFAULT 0,
    "source" VARCHAR(200),
    "medium" VARCHAR(100),
    "campaign" VARCHAR(200),
    "landing_page" VARCHAR(500),
    "exit_page" VARCHAR(500),
    "device_type" VARCHAR(50),
    "browser" VARCHAR(100),
    "country" VARCHAR(100),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.web_analytics_pageviews
CREATE TABLE IF NOT EXISTS "synthetic"."web_analytics_pageviews" (
    "pageview_id" SERIAL PRIMARY KEY,
    "session_id" INTEGER NOT NULL,
    "page_url" VARCHAR(500),
    "page_title" VARCHAR(500),
    "timestamp" TIMESTAMP,
    "time_on_page_seconds" INTEGER,
    "referrer" VARCHAR(500),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_web_analytics_pageviews_session_id" FOREIGN KEY ("session_id") REFERENCES "synthetic"."web_analytics_sessions" ("session_id")
);
CREATE INDEX IF NOT EXISTS "idx_web_analytics_pageviews_session_id" ON "synthetic"."web_analytics_pageviews" ("session_id");

-- Table: synthetic.web_events
CREATE TABLE IF NOT EXISTS "synthetic"."web_events" (
    "event_id" SERIAL PRIMARY KEY,
    "session_id" INTEGER,
    "visitor_id" VARCHAR(100),
    "event_name" VARCHAR(200) NOT NULL,
    "event_category" VARCHAR(100),
    "event_action" VARCHAR(100),
    "event_label" VARCHAR(500),
    "event_value" DECIMAL(15,2),
    "timestamp" TIMESTAMP,
    "page_url" VARCHAR(500),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_web_events_session_id" FOREIGN KEY ("session_id") REFERENCES "synthetic"."web_analytics_sessions" ("session_id")
);
CREATE INDEX IF NOT EXISTS "idx_web_events_session_id" ON "synthetic"."web_events" ("session_id");

-- Table: synthetic.social_accounts
CREATE TABLE IF NOT EXISTS "synthetic"."social_accounts" (
    "account_id" SERIAL PRIMARY KEY,
    "platform" VARCHAR(50) NOT NULL,
    "account_name" VARCHAR(200) NOT NULL,
    "account_handle" VARCHAR(100),
    "account_url" VARCHAR(500),
    "followers_count" INTEGER DEFAULT 0,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.social_posts
CREATE TABLE IF NOT EXISTS "synthetic"."social_posts" (
    "post_id" SERIAL PRIMARY KEY,
    "account_id" INTEGER NOT NULL,
    "campaign_id" INTEGER,
    "content" TEXT,
    "media_url" VARCHAR(500),
    "scheduled_at" TIMESTAMP,
    "published_at" TIMESTAMP,
    "status" VARCHAR(50) DEFAULT 'draft',
    "platform_post_id" VARCHAR(200),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_social_posts_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."social_accounts" ("account_id"),
    CONSTRAINT "fk_social_posts_campaign_id" FOREIGN KEY ("campaign_id") REFERENCES "synthetic"."marketing_campaigns" ("campaign_id")
);
CREATE INDEX IF NOT EXISTS "idx_social_posts_account_id" ON "synthetic"."social_posts" ("account_id");
CREATE INDEX IF NOT EXISTS "idx_social_posts_campaign_id" ON "synthetic"."social_posts" ("campaign_id");

-- Table: synthetic.social_metrics
CREATE TABLE IF NOT EXISTS "synthetic"."social_metrics" (
    "metric_id" SERIAL PRIMARY KEY,
    "post_id" INTEGER NOT NULL,
    "recorded_at" TIMESTAMP,
    "impressions" INTEGER DEFAULT 0,
    "reach" INTEGER DEFAULT 0,
    "likes" INTEGER DEFAULT 0,
    "comments" INTEGER DEFAULT 0,
    "shares" INTEGER DEFAULT 0,
    "clicks" INTEGER DEFAULT 0,
    "engagement_rate" DECIMAL(5,4),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_social_metrics_post_id" FOREIGN KEY ("post_id") REFERENCES "synthetic"."social_posts" ("post_id")
);
CREATE INDEX IF NOT EXISTS "idx_social_metrics_post_id" ON "synthetic"."social_metrics" ("post_id");

-- Table: synthetic.ad_campaigns
CREATE TABLE IF NOT EXISTS "synthetic"."ad_campaigns" (
    "ad_campaign_id" SERIAL PRIMARY KEY,
    "campaign_id" INTEGER,
    "platform" VARCHAR(50) NOT NULL,
    "ad_campaign_name" VARCHAR(200) NOT NULL,
    "objective" VARCHAR(100),
    "budget" DECIMAL(15,2),
    "daily_budget" DECIMAL(15,2),
    "bid_strategy" VARCHAR(100),
    "start_date" DATE,
    "end_date" DATE,
    "status" VARCHAR(50) DEFAULT 'paused',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_ad_campaigns_campaign_id" FOREIGN KEY ("campaign_id") REFERENCES "synthetic"."marketing_campaigns" ("campaign_id")
);
CREATE INDEX IF NOT EXISTS "idx_ad_campaigns_campaign_id" ON "synthetic"."ad_campaigns" ("campaign_id");

-- Table: synthetic.ad_groups
CREATE TABLE IF NOT EXISTS "synthetic"."ad_groups" (
    "ad_group_id" SERIAL PRIMARY KEY,
    "ad_campaign_id" INTEGER NOT NULL,
    "ad_group_name" VARCHAR(200) NOT NULL,
    "targeting" JSONB,
    "bid_amount" DECIMAL(10,2),
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_ad_groups_ad_campaign_id" FOREIGN KEY ("ad_campaign_id") REFERENCES "synthetic"."ad_campaigns" ("ad_campaign_id")
);
CREATE INDEX IF NOT EXISTS "idx_ad_groups_ad_campaign_id" ON "synthetic"."ad_groups" ("ad_campaign_id");

-- Table: synthetic.ads
CREATE TABLE IF NOT EXISTS "synthetic"."ads" (
    "ad_id" SERIAL PRIMARY KEY,
    "ad_group_id" INTEGER NOT NULL,
    "ad_name" VARCHAR(200),
    "ad_type" VARCHAR(50),
    "headline" VARCHAR(500),
    "description" TEXT,
    "display_url" VARCHAR(500),
    "final_url" VARCHAR(500),
    "image_url" VARCHAR(500),
    "video_url" VARCHAR(500),
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_ads_ad_group_id" FOREIGN KEY ("ad_group_id") REFERENCES "synthetic"."ad_groups" ("ad_group_id")
);
CREATE INDEX IF NOT EXISTS "idx_ads_ad_group_id" ON "synthetic"."ads" ("ad_group_id");

-- Table: synthetic.ad_performance
CREATE TABLE IF NOT EXISTS "synthetic"."ad_performance" (
    "performance_id" SERIAL PRIMARY KEY,
    "ad_id" INTEGER NOT NULL,
    "date" DATE NOT NULL,
    "impressions" INTEGER DEFAULT 0,
    "clicks" INTEGER DEFAULT 0,
    "conversions" INTEGER DEFAULT 0,
    "spend" DECIMAL(15,2) DEFAULT 0,
    "cpc" DECIMAL(10,4),
    "cpm" DECIMAL(10,4),
    "ctr" DECIMAL(6,4),
    "conversion_rate" DECIMAL(6,4),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_ad_performance_ad_id" FOREIGN KEY ("ad_id") REFERENCES "synthetic"."ads" ("ad_id")
);
CREATE INDEX IF NOT EXISTS "idx_ad_performance_ad_id" ON "synthetic"."ad_performance" ("ad_id");

-- Table: synthetic.keywords
CREATE TABLE IF NOT EXISTS "synthetic"."keywords" (
    "keyword_id" SERIAL PRIMARY KEY,
    "ad_group_id" INTEGER,
    "keyword" VARCHAR(500) NOT NULL,
    "match_type" VARCHAR(50),
    "bid_amount" DECIMAL(10,2),
    "quality_score" INTEGER,
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_keywords_ad_group_id" FOREIGN KEY ("ad_group_id") REFERENCES "synthetic"."ad_groups" ("ad_group_id")
);
CREATE INDEX IF NOT EXISTS "idx_keywords_ad_group_id" ON "synthetic"."keywords" ("ad_group_id");

-- Table: synthetic.keyword_performance
CREATE TABLE IF NOT EXISTS "synthetic"."keyword_performance" (
    "kw_perf_id" SERIAL PRIMARY KEY,
    "keyword_id" INTEGER NOT NULL,
    "date" DATE NOT NULL,
    "impressions" INTEGER DEFAULT 0,
    "clicks" INTEGER DEFAULT 0,
    "conversions" INTEGER DEFAULT 0,
    "spend" DECIMAL(15,2) DEFAULT 0,
    "avg_position" DECIMAL(4,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_keyword_performance_keyword_id" FOREIGN KEY ("keyword_id") REFERENCES "synthetic"."keywords" ("keyword_id")
);
CREATE INDEX IF NOT EXISTS "idx_keyword_performance_keyword_id" ON "synthetic"."keyword_performance" ("keyword_id");

-- Table: synthetic.content_pieces
CREATE TABLE IF NOT EXISTS "synthetic"."content_pieces" (
    "content_id" SERIAL PRIMARY KEY,
    "title" VARCHAR(500) NOT NULL,
    "content_type" VARCHAR(50),
    "body" TEXT,
    "author_id" INTEGER,
    "status" VARCHAR(50) DEFAULT 'draft',
    "published_at" TIMESTAMP,
    "url" VARCHAR(500),
    "featured_image" VARCHAR(500),
    "seo_title" VARCHAR(200),
    "seo_description" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.content_categories
CREATE TABLE IF NOT EXISTS "synthetic"."content_categories" (
    "category_id" SERIAL PRIMARY KEY,
    "category_name" VARCHAR(200) NOT NULL,
    "slug" VARCHAR(200) UNIQUE,
    "parent_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_content_categories_parent_id" FOREIGN KEY ("parent_id") REFERENCES "synthetic"."content_categories" ("category_id")
);
CREATE INDEX IF NOT EXISTS "idx_content_categories_parent_id" ON "synthetic"."content_categories" ("parent_id");

-- Table: synthetic.content_category_map
CREATE TABLE IF NOT EXISTS "synthetic"."content_category_map" (
    "map_id" SERIAL PRIMARY KEY,
    "content_id" INTEGER NOT NULL,
    "category_id" INTEGER NOT NULL,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_content_category_map_content_id" FOREIGN KEY ("content_id") REFERENCES "synthetic"."content_pieces" ("content_id"),
    CONSTRAINT "fk_content_category_map_category_id" FOREIGN KEY ("category_id") REFERENCES "synthetic"."content_categories" ("category_id")
);
CREATE INDEX IF NOT EXISTS "idx_content_category_map_content_id" ON "synthetic"."content_category_map" ("content_id");
CREATE INDEX IF NOT EXISTS "idx_content_category_map_category_id" ON "synthetic"."content_category_map" ("category_id");

-- Table: synthetic.utm_tracking
CREATE TABLE IF NOT EXISTS "synthetic"."utm_tracking" (
    "tracking_id" SERIAL PRIMARY KEY,
    "campaign_id" INTEGER,
    "utm_source" VARCHAR(200),
    "utm_medium" VARCHAR(100),
    "utm_campaign" VARCHAR(200),
    "utm_term" VARCHAR(500),
    "utm_content" VARCHAR(200),
    "destination_url" VARCHAR(500),
    "short_url" VARCHAR(200),
    "clicks" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_utm_tracking_campaign_id" FOREIGN KEY ("campaign_id") REFERENCES "synthetic"."marketing_campaigns" ("campaign_id")
);
CREATE INDEX IF NOT EXISTS "idx_utm_tracking_campaign_id" ON "synthetic"."utm_tracking" ("campaign_id");

-- ============================================================================
-- Domain: IT INFRASTRUCTURE AND ASSET MANAGEMENT
-- ============================================================================


-- Table: synthetic.it_assets
CREATE TABLE IF NOT EXISTS "synthetic"."it_assets" (
    "asset_id" SERIAL PRIMARY KEY,
    "asset_tag" VARCHAR(50) UNIQUE,
    "asset_name" VARCHAR(200) NOT NULL,
    "asset_type" VARCHAR(50),
    "manufacturer" VARCHAR(200),
    "model" VARCHAR(200),
    "serial_number" VARCHAR(100),
    "purchase_date" DATE,
    "purchase_price" DECIMAL(15,2),
    "warranty_expiry" DATE,
    "assigned_to" INTEGER,
    "location" VARCHAR(200),
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.servers
CREATE TABLE IF NOT EXISTS "synthetic"."servers" (
    "server_id" SERIAL PRIMARY KEY,
    "asset_id" INTEGER,
    "hostname" VARCHAR(200) NOT NULL UNIQUE,
    "ip_address" VARCHAR(50),
    "os" VARCHAR(100),
    "os_version" VARCHAR(50),
    "cpu_cores" INTEGER,
    "ram_gb" INTEGER,
    "storage_gb" INTEGER,
    "environment" VARCHAR(50),
    "role" VARCHAR(100),
    "status" VARCHAR(50) DEFAULT 'running',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_servers_asset_id" FOREIGN KEY ("asset_id") REFERENCES "synthetic"."it_assets" ("asset_id")
);
CREATE INDEX IF NOT EXISTS "idx_servers_asset_id" ON "synthetic"."servers" ("asset_id");

-- Table: synthetic.applications
CREATE TABLE IF NOT EXISTS "synthetic"."applications" (
    "app_id" SERIAL PRIMARY KEY,
    "app_name" VARCHAR(200) NOT NULL,
    "version" VARCHAR(50),
    "vendor" VARCHAR(200),
    "license_type" VARCHAR(50),
    "license_count" INTEGER,
    "license_expiry" DATE,
    "owner_id" INTEGER,
    "criticality" VARCHAR(20),
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.app_server_map
CREATE TABLE IF NOT EXISTS "synthetic"."app_server_map" (
    "map_id" SERIAL PRIMARY KEY,
    "app_id" INTEGER NOT NULL,
    "server_id" INTEGER NOT NULL,
    "environment" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_app_server_map_app_id" FOREIGN KEY ("app_id") REFERENCES "synthetic"."applications" ("app_id"),
    CONSTRAINT "fk_app_server_map_server_id" FOREIGN KEY ("server_id") REFERENCES "synthetic"."servers" ("server_id")
);
CREATE INDEX IF NOT EXISTS "idx_app_server_map_app_id" ON "synthetic"."app_server_map" ("app_id");
CREATE INDEX IF NOT EXISTS "idx_app_server_map_server_id" ON "synthetic"."app_server_map" ("server_id");

-- Table: synthetic.network_devices
CREATE TABLE IF NOT EXISTS "synthetic"."network_devices" (
    "device_id" SERIAL PRIMARY KEY,
    "asset_id" INTEGER,
    "device_name" VARCHAR(200) NOT NULL,
    "device_type" VARCHAR(50),
    "ip_address" VARCHAR(50),
    "mac_address" VARCHAR(20),
    "location" VARCHAR(200),
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_network_devices_asset_id" FOREIGN KEY ("asset_id") REFERENCES "synthetic"."it_assets" ("asset_id")
);
CREATE INDEX IF NOT EXISTS "idx_network_devices_asset_id" ON "synthetic"."network_devices" ("asset_id");

-- Table: synthetic.it_incidents
CREATE TABLE IF NOT EXISTS "synthetic"."it_incidents" (
    "incident_id" SERIAL PRIMARY KEY,
    "incident_number" VARCHAR(50) UNIQUE,
    "title" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "category" VARCHAR(100),
    "priority" VARCHAR(20),
    "severity" VARCHAR(20),
    "status" VARCHAR(50) DEFAULT 'new',
    "reported_by" INTEGER,
    "assigned_to" INTEGER,
    "affected_asset_id" INTEGER,
    "resolution" TEXT,
    "resolved_at" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_it_incidents_affected_asset_id" FOREIGN KEY ("affected_asset_id") REFERENCES "synthetic"."it_assets" ("asset_id")
);
CREATE INDEX IF NOT EXISTS "idx_it_incidents_affected_asset_id" ON "synthetic"."it_incidents" ("affected_asset_id");

-- Table: synthetic.change_tickets
CREATE TABLE IF NOT EXISTS "synthetic"."change_tickets" (
    "change_id" SERIAL PRIMARY KEY,
    "change_number" VARCHAR(50) UNIQUE,
    "title" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "change_type" VARCHAR(50),
    "risk_level" VARCHAR(20),
    "status" VARCHAR(50) DEFAULT 'draft',
    "requested_by" INTEGER,
    "assigned_to" INTEGER,
    "planned_start" TIMESTAMP,
    "planned_end" TIMESTAMP,
    "actual_start" TIMESTAMP,
    "actual_end" TIMESTAMP,
    "approved_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.service_requests
CREATE TABLE IF NOT EXISTS "synthetic"."service_requests" (
    "request_id" SERIAL PRIMARY KEY,
    "request_number" VARCHAR(50) UNIQUE,
    "title" VARCHAR(500) NOT NULL,
    "description" TEXT,
    "category" VARCHAR(100),
    "priority" VARCHAR(20),
    "status" VARCHAR(50) DEFAULT 'new',
    "requested_by" INTEGER,
    "assigned_to" INTEGER,
    "fulfilled_at" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.software_licenses
CREATE TABLE IF NOT EXISTS "synthetic"."software_licenses" (
    "license_id" SERIAL PRIMARY KEY,
    "app_id" INTEGER,
    "license_key" VARCHAR(500),
    "license_type" VARCHAR(50),
    "seats" INTEGER,
    "seats_used" INTEGER DEFAULT 0,
    "purchase_date" DATE,
    "expiry_date" DATE,
    "cost" DECIMAL(15,2),
    "vendor" VARCHAR(200),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_software_licenses_app_id" FOREIGN KEY ("app_id") REFERENCES "synthetic"."applications" ("app_id")
);
CREATE INDEX IF NOT EXISTS "idx_software_licenses_app_id" ON "synthetic"."software_licenses" ("app_id");

-- Table: synthetic.backup_jobs
CREATE TABLE IF NOT EXISTS "synthetic"."backup_jobs" (
    "job_id" SERIAL PRIMARY KEY,
    "job_name" VARCHAR(200) NOT NULL,
    "server_id" INTEGER,
    "backup_type" VARCHAR(50),
    "schedule" VARCHAR(100),
    "retention_days" INTEGER,
    "destination" VARCHAR(500),
    "is_active" BOOLEAN DEFAULT true,
    "last_run" TIMESTAMP,
    "last_status" VARCHAR(50),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_backup_jobs_server_id" FOREIGN KEY ("server_id") REFERENCES "synthetic"."servers" ("server_id")
);
CREATE INDEX IF NOT EXISTS "idx_backup_jobs_server_id" ON "synthetic"."backup_jobs" ("server_id");

-- Table: synthetic.backup_history
CREATE TABLE IF NOT EXISTS "synthetic"."backup_history" (
    "history_id" SERIAL PRIMARY KEY,
    "job_id" INTEGER NOT NULL,
    "start_time" TIMESTAMP,
    "end_time" TIMESTAMP,
    "status" VARCHAR(50),
    "size_mb" DECIMAL(15,2),
    "error_message" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_backup_history_job_id" FOREIGN KEY ("job_id") REFERENCES "synthetic"."backup_jobs" ("job_id")
);
CREATE INDEX IF NOT EXISTS "idx_backup_history_job_id" ON "synthetic"."backup_history" ("job_id");

-- Table: synthetic.monitoring_alerts
CREATE TABLE IF NOT EXISTS "synthetic"."monitoring_alerts" (
    "alert_id" SERIAL PRIMARY KEY,
    "alert_name" VARCHAR(200) NOT NULL,
    "server_id" INTEGER,
    "app_id" INTEGER,
    "severity" VARCHAR(20),
    "message" TEXT,
    "triggered_at" TIMESTAMP,
    "acknowledged_at" TIMESTAMP,
    "resolved_at" TIMESTAMP,
    "acknowledged_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_monitoring_alerts_server_id" FOREIGN KEY ("server_id") REFERENCES "synthetic"."servers" ("server_id"),
    CONSTRAINT "fk_monitoring_alerts_app_id" FOREIGN KEY ("app_id") REFERENCES "synthetic"."applications" ("app_id")
);
CREATE INDEX IF NOT EXISTS "idx_monitoring_alerts_server_id" ON "synthetic"."monitoring_alerts" ("server_id");
CREATE INDEX IF NOT EXISTS "idx_monitoring_alerts_app_id" ON "synthetic"."monitoring_alerts" ("app_id");

-- Table: synthetic.maintenance_windows
CREATE TABLE IF NOT EXISTS "synthetic"."maintenance_windows" (
    "window_id" SERIAL PRIMARY KEY,
    "title" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "start_time" TIMESTAMP NOT NULL,
    "end_time" TIMESTAMP NOT NULL,
    "affected_systems" TEXT,
    "status" VARCHAR(50) DEFAULT 'scheduled',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.deployment_history
CREATE TABLE IF NOT EXISTS "synthetic"."deployment_history" (
    "deployment_id" SERIAL PRIMARY KEY,
    "app_id" INTEGER,
    "server_id" INTEGER,
    "version" VARCHAR(50),
    "deployed_at" TIMESTAMP,
    "deployed_by" INTEGER,
    "status" VARCHAR(50),
    "rollback_version" VARCHAR(50),
    "notes" TEXT,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_deployment_history_app_id" FOREIGN KEY ("app_id") REFERENCES "synthetic"."applications" ("app_id"),
    CONSTRAINT "fk_deployment_history_server_id" FOREIGN KEY ("server_id") REFERENCES "synthetic"."servers" ("server_id")
);
CREATE INDEX IF NOT EXISTS "idx_deployment_history_app_id" ON "synthetic"."deployment_history" ("app_id");
CREATE INDEX IF NOT EXISTS "idx_deployment_history_server_id" ON "synthetic"."deployment_history" ("server_id");

-- Table: synthetic.ssl_certificates
CREATE TABLE IF NOT EXISTS "synthetic"."ssl_certificates" (
    "cert_id" SERIAL PRIMARY KEY,
    "domain" VARCHAR(255) NOT NULL,
    "issuer" VARCHAR(200),
    "issued_date" DATE,
    "expiry_date" DATE,
    "cert_type" VARCHAR(50),
    "server_id" INTEGER,
    "status" VARCHAR(50) DEFAULT 'active',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_ssl_certificates_server_id" FOREIGN KEY ("server_id") REFERENCES "synthetic"."servers" ("server_id")
);
CREATE INDEX IF NOT EXISTS "idx_ssl_certificates_server_id" ON "synthetic"."ssl_certificates" ("server_id");

-- ============================================================================
-- Domain: EDUCATION AND LEARNING MANAGEMENT
-- ============================================================================


-- Table: synthetic.students
CREATE TABLE IF NOT EXISTS "synthetic"."students" (
    "student_id" SERIAL PRIMARY KEY,
    "student_number" VARCHAR(20) UNIQUE,
    "first_name" VARCHAR(100) NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "email" VARCHAR(255) UNIQUE,
    "date_of_birth" DATE,
    "gender" VARCHAR(10),
    "enrollment_date" DATE,
    "graduation_date" DATE,
    "program_id" INTEGER,
    "advisor_id" INTEGER,
    "status" VARCHAR(50) DEFAULT 'active',
    "gpa" DECIMAL(3,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_students_program_id" FOREIGN KEY ("program_id") REFERENCES "synthetic"."programs" ("program_id"),
    CONSTRAINT "fk_students_advisor_id" FOREIGN KEY ("advisor_id") REFERENCES "synthetic"."instructors" ("instructor_id")
);
CREATE INDEX IF NOT EXISTS "idx_students_program_id" ON "synthetic"."students" ("program_id");
CREATE INDEX IF NOT EXISTS "idx_students_advisor_id" ON "synthetic"."students" ("advisor_id");

-- Table: synthetic.instructors
CREATE TABLE IF NOT EXISTS "synthetic"."instructors" (
    "instructor_id" SERIAL PRIMARY KEY,
    "employee_id" VARCHAR(20) UNIQUE,
    "first_name" VARCHAR(100) NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "email" VARCHAR(255),
    "department_id" INTEGER,
    "title" VARCHAR(100),
    "hire_date" DATE,
    "office_location" VARCHAR(100),
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_instructors_department_id" FOREIGN KEY ("department_id") REFERENCES "synthetic"."academic_departments" ("department_id")
);
CREATE INDEX IF NOT EXISTS "idx_instructors_department_id" ON "synthetic"."instructors" ("department_id");

-- Table: synthetic.academic_departments
CREATE TABLE IF NOT EXISTS "synthetic"."academic_departments" (
    "department_id" SERIAL PRIMARY KEY,
    "department_code" VARCHAR(10) UNIQUE,
    "department_name" VARCHAR(200) NOT NULL,
    "head_instructor_id" INTEGER,
    "building" VARCHAR(100),
    "phone" VARCHAR(20),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.programs
CREATE TABLE IF NOT EXISTS "synthetic"."programs" (
    "program_id" SERIAL PRIMARY KEY,
    "program_code" VARCHAR(20) UNIQUE,
    "program_name" VARCHAR(200) NOT NULL,
    "department_id" INTEGER,
    "degree_type" VARCHAR(50),
    "credit_hours_required" INTEGER,
    "description" TEXT,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_programs_department_id" FOREIGN KEY ("department_id") REFERENCES "synthetic"."academic_departments" ("department_id")
);
CREATE INDEX IF NOT EXISTS "idx_programs_department_id" ON "synthetic"."programs" ("department_id");

-- Table: synthetic.courses
CREATE TABLE IF NOT EXISTS "synthetic"."courses" (
    "course_id" SERIAL PRIMARY KEY,
    "course_code" VARCHAR(20) NOT NULL UNIQUE,
    "course_name" VARCHAR(200) NOT NULL,
    "department_id" INTEGER,
    "credit_hours" INTEGER,
    "description" TEXT,
    "prerequisites" TEXT,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_courses_department_id" FOREIGN KEY ("department_id") REFERENCES "synthetic"."academic_departments" ("department_id")
);
CREATE INDEX IF NOT EXISTS "idx_courses_department_id" ON "synthetic"."courses" ("department_id");

-- Table: synthetic.course_sections
CREATE TABLE IF NOT EXISTS "synthetic"."course_sections" (
    "section_id" SERIAL PRIMARY KEY,
    "course_id" INTEGER NOT NULL,
    "section_number" VARCHAR(10) NOT NULL,
    "term_id" INTEGER,
    "instructor_id" INTEGER,
    "room_id" INTEGER,
    "max_enrollment" INTEGER,
    "current_enrollment" INTEGER DEFAULT 0,
    "schedule" VARCHAR(200),
    "status" VARCHAR(50) DEFAULT 'open',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_course_sections_course_id" FOREIGN KEY ("course_id") REFERENCES "synthetic"."courses" ("course_id"),
    CONSTRAINT "fk_course_sections_term_id" FOREIGN KEY ("term_id") REFERENCES "synthetic"."academic_terms" ("term_id"),
    CONSTRAINT "fk_course_sections_instructor_id" FOREIGN KEY ("instructor_id") REFERENCES "synthetic"."instructors" ("instructor_id"),
    CONSTRAINT "fk_course_sections_room_id" FOREIGN KEY ("room_id") REFERENCES "synthetic"."classrooms" ("room_id")
);
CREATE INDEX IF NOT EXISTS "idx_course_sections_course_id" ON "synthetic"."course_sections" ("course_id");
CREATE INDEX IF NOT EXISTS "idx_course_sections_term_id" ON "synthetic"."course_sections" ("term_id");
CREATE INDEX IF NOT EXISTS "idx_course_sections_instructor_id" ON "synthetic"."course_sections" ("instructor_id");
CREATE INDEX IF NOT EXISTS "idx_course_sections_room_id" ON "synthetic"."course_sections" ("room_id");

-- Table: synthetic.academic_terms
CREATE TABLE IF NOT EXISTS "synthetic"."academic_terms" (
    "term_id" SERIAL PRIMARY KEY,
    "term_code" VARCHAR(20) UNIQUE,
    "term_name" VARCHAR(100) NOT NULL,
    "start_date" DATE,
    "end_date" DATE,
    "registration_start" DATE,
    "registration_end" DATE,
    "is_current" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.enrollments
CREATE TABLE IF NOT EXISTS "synthetic"."enrollments" (
    "enrollment_id" SERIAL PRIMARY KEY,
    "student_id" INTEGER NOT NULL,
    "section_id" INTEGER NOT NULL,
    "enrollment_date" DATE,
    "status" VARCHAR(50) DEFAULT 'enrolled',
    "grade" VARCHAR(5),
    "grade_points" DECIMAL(3,2),
    "credits_earned" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_enrollments_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id"),
    CONSTRAINT "fk_enrollments_section_id" FOREIGN KEY ("section_id") REFERENCES "synthetic"."course_sections" ("section_id")
);
CREATE INDEX IF NOT EXISTS "idx_enrollments_student_id" ON "synthetic"."enrollments" ("student_id");
CREATE INDEX IF NOT EXISTS "idx_enrollments_section_id" ON "synthetic"."enrollments" ("section_id");

-- Table: synthetic.classrooms
CREATE TABLE IF NOT EXISTS "synthetic"."classrooms" (
    "room_id" SERIAL PRIMARY KEY,
    "room_number" VARCHAR(20) NOT NULL,
    "building" VARCHAR(100),
    "capacity" INTEGER,
    "room_type" VARCHAR(50),
    "has_projector" BOOLEAN DEFAULT false,
    "has_whiteboard" BOOLEAN DEFAULT true,
    "is_available" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.assignments
CREATE TABLE IF NOT EXISTS "synthetic"."assignments" (
    "assignment_id" SERIAL PRIMARY KEY,
    "section_id" INTEGER NOT NULL,
    "assignment_name" VARCHAR(200) NOT NULL,
    "assignment_type" VARCHAR(50),
    "description" TEXT,
    "due_date" TIMESTAMP,
    "max_points" DECIMAL(6,2),
    "weight" DECIMAL(5,2),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_assignments_section_id" FOREIGN KEY ("section_id") REFERENCES "synthetic"."course_sections" ("section_id")
);
CREATE INDEX IF NOT EXISTS "idx_assignments_section_id" ON "synthetic"."assignments" ("section_id");

-- Table: synthetic.submissions
CREATE TABLE IF NOT EXISTS "synthetic"."submissions" (
    "submission_id" SERIAL PRIMARY KEY,
    "assignment_id" INTEGER NOT NULL,
    "student_id" INTEGER NOT NULL,
    "submitted_at" TIMESTAMP,
    "file_path" VARCHAR(500),
    "score" DECIMAL(6,2),
    "feedback" TEXT,
    "graded_at" TIMESTAMP,
    "graded_by" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_submissions_assignment_id" FOREIGN KEY ("assignment_id") REFERENCES "synthetic"."assignments" ("assignment_id"),
    CONSTRAINT "fk_submissions_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id")
);
CREATE INDEX IF NOT EXISTS "idx_submissions_assignment_id" ON "synthetic"."submissions" ("assignment_id");
CREATE INDEX IF NOT EXISTS "idx_submissions_student_id" ON "synthetic"."submissions" ("student_id");

-- Table: synthetic.attendance
CREATE TABLE IF NOT EXISTS "synthetic"."attendance" (
    "attendance_id" SERIAL PRIMARY KEY,
    "section_id" INTEGER NOT NULL,
    "student_id" INTEGER NOT NULL,
    "class_date" DATE NOT NULL,
    "status" VARCHAR(20),
    "notes" VARCHAR(500),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_attendance_section_id" FOREIGN KEY ("section_id") REFERENCES "synthetic"."course_sections" ("section_id"),
    CONSTRAINT "fk_attendance_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id")
);
CREATE INDEX IF NOT EXISTS "idx_attendance_section_id" ON "synthetic"."attendance" ("section_id");
CREATE INDEX IF NOT EXISTS "idx_attendance_student_id" ON "synthetic"."attendance" ("student_id");

-- Table: synthetic.tuition_fees
CREATE TABLE IF NOT EXISTS "synthetic"."tuition_fees" (
    "fee_id" SERIAL PRIMARY KEY,
    "fee_name" VARCHAR(200) NOT NULL,
    "fee_type" VARCHAR(50),
    "amount" DECIMAL(10,2) NOT NULL,
    "term_id" INTEGER,
    "is_required" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_tuition_fees_term_id" FOREIGN KEY ("term_id") REFERENCES "synthetic"."academic_terms" ("term_id")
);
CREATE INDEX IF NOT EXISTS "idx_tuition_fees_term_id" ON "synthetic"."tuition_fees" ("term_id");

-- Table: synthetic.student_accounts
CREATE TABLE IF NOT EXISTS "synthetic"."student_accounts" (
    "account_id" SERIAL PRIMARY KEY,
    "student_id" INTEGER NOT NULL,
    "term_id" INTEGER,
    "total_charges" DECIMAL(15,2) DEFAULT 0,
    "total_payments" DECIMAL(15,2) DEFAULT 0,
    "balance" DECIMAL(15,2) DEFAULT 0,
    "due_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_student_accounts_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id"),
    CONSTRAINT "fk_student_accounts_term_id" FOREIGN KEY ("term_id") REFERENCES "synthetic"."academic_terms" ("term_id")
);
CREATE INDEX IF NOT EXISTS "idx_student_accounts_student_id" ON "synthetic"."student_accounts" ("student_id");
CREATE INDEX IF NOT EXISTS "idx_student_accounts_term_id" ON "synthetic"."student_accounts" ("term_id");

-- Table: synthetic.student_payments
CREATE TABLE IF NOT EXISTS "synthetic"."student_payments" (
    "payment_id" SERIAL PRIMARY KEY,
    "account_id" INTEGER NOT NULL,
    "payment_date" DATE NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "payment_method" VARCHAR(50),
    "reference_number" VARCHAR(100),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_student_payments_account_id" FOREIGN KEY ("account_id") REFERENCES "synthetic"."student_accounts" ("account_id")
);
CREATE INDEX IF NOT EXISTS "idx_student_payments_account_id" ON "synthetic"."student_payments" ("account_id");

-- Table: synthetic.financial_aid
CREATE TABLE IF NOT EXISTS "synthetic"."financial_aid" (
    "aid_id" SERIAL PRIMARY KEY,
    "student_id" INTEGER NOT NULL,
    "term_id" INTEGER,
    "aid_type" VARCHAR(50),
    "aid_name" VARCHAR(200),
    "amount" DECIMAL(10,2),
    "status" VARCHAR(50) DEFAULT 'pending',
    "disbursed_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_financial_aid_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id"),
    CONSTRAINT "fk_financial_aid_term_id" FOREIGN KEY ("term_id") REFERENCES "synthetic"."academic_terms" ("term_id")
);
CREATE INDEX IF NOT EXISTS "idx_financial_aid_student_id" ON "synthetic"."financial_aid" ("student_id");
CREATE INDEX IF NOT EXISTS "idx_financial_aid_term_id" ON "synthetic"."financial_aid" ("term_id");

-- Table: synthetic.degree_requirements
CREATE TABLE IF NOT EXISTS "synthetic"."degree_requirements" (
    "requirement_id" SERIAL PRIMARY KEY,
    "program_id" INTEGER NOT NULL,
    "course_id" INTEGER,
    "requirement_type" VARCHAR(50),
    "credit_hours" INTEGER,
    "minimum_grade" VARCHAR(5),
    "is_required" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_degree_requirements_program_id" FOREIGN KEY ("program_id") REFERENCES "synthetic"."programs" ("program_id"),
    CONSTRAINT "fk_degree_requirements_course_id" FOREIGN KEY ("course_id") REFERENCES "synthetic"."courses" ("course_id")
);
CREATE INDEX IF NOT EXISTS "idx_degree_requirements_program_id" ON "synthetic"."degree_requirements" ("program_id");
CREATE INDEX IF NOT EXISTS "idx_degree_requirements_course_id" ON "synthetic"."degree_requirements" ("course_id");

-- Table: synthetic.transcripts
CREATE TABLE IF NOT EXISTS "synthetic"."transcripts" (
    "transcript_id" SERIAL PRIMARY KEY,
    "student_id" INTEGER NOT NULL,
    "request_date" DATE,
    "issue_date" DATE,
    "transcript_type" VARCHAR(50),
    "recipient" VARCHAR(500),
    "status" VARCHAR(50) DEFAULT 'pending',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_transcripts_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id")
);
CREATE INDEX IF NOT EXISTS "idx_transcripts_student_id" ON "synthetic"."transcripts" ("student_id");

-- Table: synthetic.academic_holds
CREATE TABLE IF NOT EXISTS "synthetic"."academic_holds" (
    "hold_id" SERIAL PRIMARY KEY,
    "student_id" INTEGER NOT NULL,
    "hold_type" VARCHAR(50) NOT NULL,
    "reason" TEXT,
    "placed_date" DATE,
    "released_date" DATE,
    "placed_by" INTEGER,
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_academic_holds_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id")
);
CREATE INDEX IF NOT EXISTS "idx_academic_holds_student_id" ON "synthetic"."academic_holds" ("student_id");

-- Table: synthetic.course_waitlist
CREATE TABLE IF NOT EXISTS "synthetic"."course_waitlist" (
    "waitlist_id" SERIAL PRIMARY KEY,
    "section_id" INTEGER NOT NULL,
    "student_id" INTEGER NOT NULL,
    "position" INTEGER,
    "added_date" TIMESTAMP,
    "status" VARCHAR(50) DEFAULT 'waiting',
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_course_waitlist_section_id" FOREIGN KEY ("section_id") REFERENCES "synthetic"."course_sections" ("section_id"),
    CONSTRAINT "fk_course_waitlist_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id")
);
CREATE INDEX IF NOT EXISTS "idx_course_waitlist_section_id" ON "synthetic"."course_waitlist" ("section_id");
CREATE INDEX IF NOT EXISTS "idx_course_waitlist_student_id" ON "synthetic"."course_waitlist" ("student_id");

-- Table: synthetic.course_materials
CREATE TABLE IF NOT EXISTS "synthetic"."course_materials" (
    "material_id" SERIAL PRIMARY KEY,
    "section_id" INTEGER NOT NULL,
    "material_name" VARCHAR(200) NOT NULL,
    "material_type" VARCHAR(50),
    "file_path" VARCHAR(500),
    "description" TEXT,
    "is_required" BOOLEAN DEFAULT false,
    "upload_date" TIMESTAMP,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_course_materials_section_id" FOREIGN KEY ("section_id") REFERENCES "synthetic"."course_sections" ("section_id")
);
CREATE INDEX IF NOT EXISTS "idx_course_materials_section_id" ON "synthetic"."course_materials" ("section_id");

-- Table: synthetic.office_hours
CREATE TABLE IF NOT EXISTS "synthetic"."office_hours" (
    "office_hour_id" SERIAL PRIMARY KEY,
    "instructor_id" INTEGER NOT NULL,
    "day_of_week" VARCHAR(20),
    "start_time" TIME,
    "end_time" TIME,
    "location" VARCHAR(100),
    "term_id" INTEGER,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_office_hours_instructor_id" FOREIGN KEY ("instructor_id") REFERENCES "synthetic"."instructors" ("instructor_id"),
    CONSTRAINT "fk_office_hours_term_id" FOREIGN KEY ("term_id") REFERENCES "synthetic"."academic_terms" ("term_id")
);
CREATE INDEX IF NOT EXISTS "idx_office_hours_instructor_id" ON "synthetic"."office_hours" ("instructor_id");
CREATE INDEX IF NOT EXISTS "idx_office_hours_term_id" ON "synthetic"."office_hours" ("term_id");

-- Table: synthetic.student_clubs
CREATE TABLE IF NOT EXISTS "synthetic"."student_clubs" (
    "club_id" SERIAL PRIMARY KEY,
    "club_name" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "advisor_id" INTEGER,
    "meeting_schedule" VARCHAR(200),
    "meeting_location" VARCHAR(100),
    "is_active" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_student_clubs_advisor_id" FOREIGN KEY ("advisor_id") REFERENCES "synthetic"."instructors" ("instructor_id")
);
CREATE INDEX IF NOT EXISTS "idx_student_clubs_advisor_id" ON "synthetic"."student_clubs" ("advisor_id");

-- Table: synthetic.club_memberships
CREATE TABLE IF NOT EXISTS "synthetic"."club_memberships" (
    "membership_id" SERIAL PRIMARY KEY,
    "club_id" INTEGER NOT NULL,
    "student_id" INTEGER NOT NULL,
    "role" VARCHAR(50),
    "join_date" DATE,
    "end_date" DATE,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_club_memberships_club_id" FOREIGN KEY ("club_id") REFERENCES "synthetic"."student_clubs" ("club_id"),
    CONSTRAINT "fk_club_memberships_student_id" FOREIGN KEY ("student_id") REFERENCES "synthetic"."students" ("student_id")
);
CREATE INDEX IF NOT EXISTS "idx_club_memberships_club_id" ON "synthetic"."club_memberships" ("club_id");
CREATE INDEX IF NOT EXISTS "idx_club_memberships_student_id" ON "synthetic"."club_memberships" ("student_id");

-- Table: synthetic.grade_scales
CREATE TABLE IF NOT EXISTS "synthetic"."grade_scales" (
    "scale_id" SERIAL PRIMARY KEY,
    "grade_letter" VARCHAR(5) NOT NULL,
    "min_percentage" DECIMAL(5,2),
    "max_percentage" DECIMAL(5,2),
    "grade_points" DECIMAL(3,2),
    "description" VARCHAR(100),
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: synthetic.academic_calendar
CREATE TABLE IF NOT EXISTS "synthetic"."academic_calendar" (
    "event_id" SERIAL PRIMARY KEY,
    "term_id" INTEGER,
    "event_name" VARCHAR(200) NOT NULL,
    "event_type" VARCHAR(50),
    "start_date" DATE NOT NULL,
    "end_date" DATE,
    "description" TEXT,
    "is_holiday" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fk_academic_calendar_term_id" FOREIGN KEY ("term_id") REFERENCES "synthetic"."academic_terms" ("term_id")
);
CREATE INDEX IF NOT EXISTS "idx_academic_calendar_term_id" ON "synthetic"."academic_calendar" ("term_id");

-- ============================================================================
-- Summary: 250 tables created in schema 'synthetic'
-- ============================================================================
