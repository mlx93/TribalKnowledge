# Synthetic 250-Table Database Schema

Generated: 2025-12-12 20:48:39

## Overview

- **Schema**: `synthetic`
- **Total Tables**: 250

## Tables by Domain

### HR (25 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `employees` | 14 | 3 |
| `departments` | 7 | 2 |
| `job_titles` | 7 | 0 |
| `office_locations` | 10 | 0 |
| `salary_history` | 8 | 2 |
| `benefits_plans` | 9 | 0 |
| `employee_benefits` | 7 | 2 |
| `time_off_requests` | 9 | 2 |
| `time_off_balances` | 7 | 1 |
| `performance_reviews` | 10 | 2 |
| `performance_goals` | 9 | 1 |
| `training_courses` | 9 | 0 |
| `employee_training` | 8 | 2 |
| `skills` | 4 | 0 |
| `employee_skills` | 7 | 2 |
| `job_postings` | 14 | 4 |
| `job_applicants` | 8 | 0 |
| `job_applications` | 7 | 2 |
| `interviews` | 10 | 2 |
| `employee_documents` | 8 | 1 |
| `emergency_contacts` | 8 | 1 |
| `expense_reports` | 10 | 2 |
| `expense_items` | 8 | 1 |
| `org_announcements` | 9 | 2 |
| `org_policies` | 9 | 0 |

### FINANCE (29 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `chart_of_accounts` | 8 | 1 |
| `fiscal_periods` | 8 | 0 |
| `journal_entries` | 10 | 1 |
| `journal_entry_lines` | 7 | 2 |
| `vendors` | 14 | 0 |
| `invoices_payable` | 11 | 1 |
| `invoice_payable_lines` | 8 | 2 |
| `vendor_payments` | 10 | 2 |
| `payment_allocations` | 4 | 2 |
| `bank_accounts` | 10 | 1 |
| `bank_transactions` | 9 | 1 |
| `bank_reconciliations` | 8 | 1 |
| `budgets` | 8 | 0 |
| `budget_lines` | 6 | 3 |
| `fixed_assets` | 14 | 0 |
| `depreciation_schedule` | 8 | 2 |
| `tax_rates` | 9 | 0 |
| `currencies` | 5 | 0 |
| `exchange_rates` | 6 | 2 |
| `cost_centers` | 6 | 1 |
| `projects_financial` | 10 | 0 |
| `project_costs` | 8 | 1 |
| `audit_trail` | 9 | 0 |
| `financial_reports` | 8 | 1 |
| `intercompany_accounts` | 5 | 1 |
| `intercompany_transactions` | 7 | 1 |
| `payment_terms` | 7 | 0 |
| `credit_memos` | 8 | 2 |
| `recurring_entries` | 8 | 1 |

### ECOMMERCE (33 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `customers` | 15 | 0 |
| `customer_addresses` | 10 | 1 |
| `product_categories` | 10 | 1 |
| `brands` | 7 | 0 |
| `products` | 19 | 2 |
| `product_variants` | 8 | 1 |
| `product_attributes` | 5 | 0 |
| `product_attribute_values` | 4 | 2 |
| `product_images` | 7 | 2 |
| `product_reviews` | 9 | 2 |
| `shopping_carts` | 8 | 1 |
| `cart_items` | 7 | 3 |
| `wishlists` | 4 | 1 |
| `wishlist_items` | 6 | 3 |
| `orders` | 17 | 4 |
| `order_items` | 11 | 3 |
| `order_status_history` | 6 | 1 |
| `shipping_methods` | 8 | 0 |
| `shipments` | 8 | 1 |
| `shipment_items` | 4 | 2 |
| `order_returns` | 10 | 1 |
| `return_items` | 6 | 2 |
| `coupons` | 13 | 0 |
| `coupon_usage` | 6 | 3 |
| `gift_cards` | 11 | 1 |
| `payment_transactions` | 11 | 1 |
| `product_tags` | 3 | 0 |
| `product_tag_map` | 3 | 2 |
| `related_products` | 5 | 2 |
| `product_bundles` | 4 | 1 |
| `bundle_items` | 5 | 2 |
| `promotions` | 10 | 0 |
| `promotion_products` | 4 | 3 |

### INVENTORY (24 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `warehouses` | 11 | 0 |
| `warehouse_zones` | 8 | 1 |
| `storage_locations` | 10 | 1 |
| `inventory_items` | 11 | 2 |
| `inventory_lots` | 8 | 1 |
| `inventory_transactions` | 9 | 1 |
| `suppliers` | 12 | 0 |
| `supplier_products` | 8 | 1 |
| `purchase_orders` | 14 | 2 |
| `purchase_order_lines` | 7 | 1 |
| `receiving_orders` | 8 | 2 |
| `receiving_lines` | 9 | 3 |
| `stock_transfers` | 9 | 2 |
| `stock_transfer_lines` | 6 | 3 |
| `inventory_counts` | 9 | 1 |
| `inventory_count_lines` | 8 | 2 |
| `inventory_adjustments` | 8 | 1 |
| `adjustment_lines` | 6 | 2 |
| `pick_orders` | 9 | 1 |
| `pick_lines` | 7 | 3 |
| `pack_orders` | 9 | 1 |
| `packages` | 8 | 1 |
| `abc_analysis` | 7 | 1 |
| `reorder_rules` | 9 | 1 |

### CRM (29 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `accounts` | 15 | 1 |
| `contacts` | 15 | 1 |
| `leads` | 20 | 2 |
| `opportunities` | 17 | 3 |
| `opportunity_stages` | 6 | 0 |
| `opportunity_products` | 9 | 1 |
| `quotes` | 17 | 3 |
| `quote_lines` | 10 | 1 |
| `sales_orders` | 16 | 4 |
| `sales_order_lines` | 8 | 1 |
| `activities` | 12 | 0 |
| `tasks` | 11 | 0 |
| `events` | 10 | 0 |
| `event_attendees` | 6 | 2 |
| `call_logs` | 10 | 0 |
| `campaigns` | 14 | 0 |
| `campaign_members` | 7 | 3 |
| `territories` | 4 | 1 |
| `territory_assignments` | 5 | 2 |
| `sales_teams` | 4 | 0 |
| `team_members` | 5 | 1 |
| `forecasts` | 8 | 0 |
| `price_books` | 5 | 0 |
| `price_book_entries` | 5 | 1 |
| `contracts` | 13 | 1 |
| `cases` | 13 | 2 |
| `case_comments` | 5 | 1 |
| `solutions` | 6 | 0 |
| `case_solutions` | 3 | 2 |

### HEALTHCARE (24 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `patients` | 16 | 2 |
| `physicians` | 12 | 1 |
| `medical_departments` | 6 | 0 |
| `appointments` | 11 | 2 |
| `encounters` | 9 | 3 |
| `diagnoses` | 8 | 1 |
| `prescriptions` | 13 | 4 |
| `medications` | 9 | 0 |
| `allergies` | 8 | 1 |
| `lab_orders` | 8 | 3 |
| `lab_tests` | 7 | 0 |
| `lab_results` | 10 | 2 |
| `vital_signs` | 14 | 2 |
| `immunizations` | 10 | 1 |
| `insurance_policies` | 11 | 1 |
| `medical_claims` | 12 | 3 |
| `claim_lines` | 8 | 1 |
| `procedures` | 9 | 3 |
| `referrals` | 9 | 3 |
| `medical_history` | 8 | 1 |
| `family_history` | 6 | 1 |
| `care_plans` | 9 | 2 |
| `care_team_members` | 7 | 2 |
| `patient_consents` | 8 | 1 |

### PROJECTS (20 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `project_portfolio` | 5 | 0 |
| `pm_projects` | 14 | 1 |
| `project_phases` | 7 | 1 |
| `milestones` | 8 | 2 |
| `pm_tasks` | 15 | 4 |
| `task_dependencies` | 5 | 2 |
| `task_assignments` | 5 | 1 |
| `time_entries` | 8 | 1 |
| `project_members` | 7 | 1 |
| `project_risks` | 10 | 1 |
| `project_issues` | 10 | 1 |
| `project_documents` | 9 | 1 |
| `project_comments` | 6 | 3 |
| `sprints` | 9 | 1 |
| `sprint_tasks` | 4 | 2 |
| `resource_calendar` | 6 | 0 |
| `project_budgets` | 6 | 1 |
| `change_requests` | 10 | 1 |
| `project_status_reports` | 10 | 1 |
| `lessons_learned` | 8 | 1 |

### MARKETING (25 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `marketing_campaigns` | 12 | 0 |
| `email_campaigns` | 10 | 2 |
| `email_templates` | 7 | 0 |
| `email_sends` | 11 | 1 |
| `email_clicks` | 6 | 1 |
| `mailing_lists` | 5 | 0 |
| `list_subscribers` | 9 | 1 |
| `landing_pages` | 9 | 1 |
| `landing_page_conversions` | 9 | 1 |
| `web_analytics_sessions` | 14 | 0 |
| `web_analytics_pageviews` | 7 | 1 |
| `web_events` | 10 | 1 |
| `social_accounts` | 7 | 0 |
| `social_posts` | 9 | 2 |
| `social_metrics` | 10 | 1 |
| `ad_campaigns` | 11 | 1 |
| `ad_groups` | 6 | 1 |
| `ads` | 11 | 1 |
| `ad_performance` | 11 | 1 |
| `keywords` | 7 | 1 |
| `keyword_performance` | 8 | 1 |
| `content_pieces` | 11 | 0 |
| `content_categories` | 4 | 1 |
| `content_category_map` | 3 | 2 |
| `utm_tracking` | 10 | 1 |

### IT INFRA (15 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `it_assets` | 13 | 0 |
| `servers` | 12 | 1 |
| `applications` | 10 | 0 |
| `app_server_map` | 4 | 2 |
| `network_devices` | 8 | 1 |
| `it_incidents` | 13 | 1 |
| `change_tickets` | 14 | 0 |
| `service_requests` | 10 | 0 |
| `software_licenses` | 10 | 1 |
| `backup_jobs` | 10 | 1 |
| `backup_history` | 7 | 1 |
| `monitoring_alerts` | 10 | 2 |
| `maintenance_windows` | 7 | 0 |
| `deployment_history` | 9 | 2 |
| `ssl_certificates` | 8 | 1 |

### EDUCATION (26 tables)

| Table | Columns | Foreign Keys |
|-------|---------|--------------|
| `students` | 13 | 2 |
| `instructors` | 10 | 1 |
| `academic_departments` | 6 | 0 |
| `programs` | 8 | 1 |
| `courses` | 8 | 1 |
| `course_sections` | 10 | 4 |
| `academic_terms` | 8 | 0 |
| `enrollments` | 8 | 2 |
| `classrooms` | 8 | 0 |
| `assignments` | 8 | 1 |
| `submissions` | 9 | 2 |
| `attendance` | 6 | 2 |
| `tuition_fees` | 6 | 1 |
| `student_accounts` | 7 | 2 |
| `student_payments` | 6 | 1 |
| `financial_aid` | 8 | 2 |
| `degree_requirements` | 7 | 2 |
| `transcripts` | 7 | 1 |
| `academic_holds` | 8 | 1 |
| `course_waitlist` | 6 | 2 |
| `course_materials` | 8 | 1 |
| `office_hours` | 7 | 2 |
| `student_clubs` | 7 | 1 |
| `club_memberships` | 6 | 2 |
| `grade_scales` | 6 | 0 |
| `academic_calendar` | 8 | 1 |
