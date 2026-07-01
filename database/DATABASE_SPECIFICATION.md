# StencilPro Expert Enterprise
## Database Specification
### Complete PostgreSQL / Supabase Schema Design

**Document Version:** 1.0.0
**Status:** Approved for Implementation
**Classification:** Core Infrastructure Design Document
**Depends On:**
- ARCHITECTURE.md v1.0.0
- ENGINEERING_DOMAIN_SPECIFICATION.md v1.0.0
- ENGINEERING_INTELLIGENCE_SPECIFICATION.md v1.0.0
**Date:** 2026-06-26

---

## Table of Contents

1. [Database Design Philosophy](#1-database-design-philosophy)
2. [Naming Conventions](#2-naming-conventions)
3. [Data Type Standards](#3-data-type-standards)
4. [Module Map — All Tables](#4-module-map--all-tables)
5. [Module 01 — Core System & Tenancy](#5-module-01--core-system--tenancy)
6. [Module 02 — User Management & Security](#6-module-02--user-management--security)
7. [Module 03 — Projects & Customers](#7-module-03--projects--customers)
8. [Module 04 — PCB & Assembly](#8-module-04--pcb--assembly)
9. [Module 05 — Component & Package Library](#9-module-05--component--package-library)
10. [Module 06 — Land Patterns & Pads](#10-module-06--land-patterns--pads)
11. [Module 07 — Stencil Design](#11-module-07--stencil-design)
12. [Module 08 — Materials Library](#12-module-08--materials-library)
13. [Module 09 — Process & Equipment](#13-module-09--process--equipment)
14. [Module 10 — Inspection](#14-module-10--inspection)
15. [Module 11 — Defect & Failure Knowledge](#15-module-11--defect--failure-knowledge)
16. [Module 12 — Rule Engine](#16-module-12--rule-engine)
17. [Module 13 — Engineering Calculations](#17-module-13--engineering-calculations)
18. [Module 14 — Recommendation Engine](#18-module-14--recommendation-engine)
19. [Module 15 — Intelligence & Scoring](#19-module-15--intelligence--scoring)
20. [Module 16 — Learning System](#20-module-16--learning-system)
21. [Module 17 — Knowledge Base](#21-module-17--knowledge-base)
22. [Module 18 — Images & Media](#22-module-18--images--media)
23. [Module 19 — Reports & Documents](#23-module-19--reports--documents)
24. [Module 20 — Audit, Activity & Notifications](#24-module-20--audit-activity--notifications)
25. [Module 21 — Application Settings](#25-module-21--application-settings)
26. [Module 22 — Future AI Layer](#26-module-22--future-ai-layer)
27. [Cross-Cutting Concerns](#27-cross-cutting-concerns)
28. [Performance Strategy](#28-performance-strategy)
29. [Versioning, Soft Delete & Audit](#29-versioning-soft-delete--audit)
30. [Image Storage Strategy](#30-image-storage-strategy)
31. [Backup, Migration & Schema Versioning](#31-backup-migration--schema-versioning)
32. [Supabase-Specific Design](#32-supabase-specific-design)
33. [Open Design Questions](#33-open-design-questions)

---

## 1. Database Design Philosophy

### Guiding Principles

**1. The Database Is the Contract**
Every table definition is a permanent engineering commitment. Column names, data types, and constraints chosen today will be read by Python code, SQL views, Supabase RLS policies, and future AI models. They must be precise, self-documenting, and unambiguous.

**2. Normalize First, Denormalize Deliberately**
Data is normalized to avoid update anomalies and support long-term maintainability. Where denormalization is chosen (JSONB snapshots, calculated columns), it is documented explicitly with the rationale.

**3. Units Are Always Explicit**
Every physical measurement column carries its unit in the column name. `width` is never acceptable. `width_mm` is required. This applies uniformly across all tables.

**4. Engineering Knowledge Is Versioned, Never Deleted**
Rules, materials, packages, and templates are never physically deleted. They are versioned and soft-deleted. A stencil approved under rule set v2.1 must always be re-evaluable under rule set v2.1, even after v3.0 is released.

**5. The Schema Supports the Intelligence Layer**
Every table that feeds the Engineering Intelligence Layer is designed with the ProcessContext model in mind. Fields used by the Rule Engine, Defect Prediction Engine, and Recommendation Engine are treated as first-class schema citizens — not optional extras.

**6. Audit Trail Is Mandatory**
Every mutation of significant data is logged. Engineers, timestamps, and previous values are preserved. This is a regulatory requirement for automotive (IATF 16949), medical (ISO 13485), and aerospace (AS9100) customers.

**7. Multi-Tenancy by Design**
Every non-reference table carries an `organization_id` foreign key. Row-Level Security (RLS) in Supabase enforces this at the database layer — not just in application code. No tenant can ever read another tenant's data, regardless of application bugs.

**8. The Schema Must Survive 10 Years**
Column names chosen today will appear in reports generated in 2036. UUID primary keys, immutable audit records, and soft deletes ensure backward compatibility across major version changes.

---

## 2. Naming Conventions

### 2.1 Table Names

| Convention | Rule | Example |
|---|---|---|
| Case | `snake_case`, always lowercase | `stencil_designs` |
| Plurality | Plural nouns | `packages`, `aperture_designs` |
| Module prefix | None — module is expressed by FK relationships | `spi_measurements` not `inspection_spi_measurements` |
| Junction tables | Both entity names, alphabetical, singular | `rule_defect_types` |
| Reference/lookup tables | Suffix `_types` or `_categories` | `defect_categories` |
| Audit tables | Suffix `_history` | `engineering_rules_history` |

### 2.2 Column Names

| Column Type | Convention | Example |
|---|---|---|
| Primary key | `id` | `id UUID PRIMARY KEY` |
| Foreign key | `{referenced_table_singular}_id` | `organization_id`, `package_id` |
| Physical measurement | `{name}_{unit}` | `width_mm`, `thickness_um`, `volume_mm3` |
| Temperature | `{name}_temp_c` | `peak_temp_c`, `storage_temp_min_c` |
| Percentage | `{name}_pct` | `coverage_pct`, `metal_content_pct` |
| Boolean | `is_{state}` or `has_{feature}` | `is_active`, `has_thermal_pad`, `is_deleted` |
| Timestamp created | `created_at` | `created_at TIMESTAMPTZ` |
| Timestamp updated | `updated_at` | `updated_at TIMESTAMPTZ` |
| Timestamp deleted | `deleted_at` | `deleted_at TIMESTAMPTZ` (nullable — null = not deleted) |
| Timestamp event | `{event}_at` | `approved_at`, `released_at`, `closed_at` |
| Enum column | `{name}` — enum type named `{table}_{column}_enum` | `status`, type `stencil_designs_status_enum` |
| JSONB snapshot | `{name}_snapshot` | `stencil_data_snapshot`, `context_snapshot` |
| JSONB structured | `{name}_data` | `five_why_data`, `results_data` |
| Count | `{name}_count` | `aperture_count`, `layer_count` |
| Free text | `notes` (short) or `description` (medium) or `content` (long) | |
| Version string | `version` | `version VARCHAR(20)` |
| URL/path | `{name}_url` or `{name}_path` | `datasheet_url`, `storage_path` |

### 2.3 Primary Keys

All primary keys are **UUID v4**, generated by the application layer (not the database `gen_random_uuid()`). This ensures:
- Keys are generated before database insert (enables offline operation)
- Keys are globally unique across tenants
- Keys are safe to expose in URLs and APIs

```
Convention: id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY
Exception:  Reference/lookup tables with stable codes may use VARCHAR code as PK
            (e.g., ipc_standards: standard_code VARCHAR(20) PRIMARY KEY)
```

### 2.4 Foreign Keys

```
Convention: {singular_referenced_table_name}_id UUID [NOT NULL | NULL]
Examples:   organization_id UUID NOT NULL
            approved_by_engineer_id UUID NULL   (nullable FK uses full prefix)
            superseded_by_rule_id UUID NULL
            
Constraint name: fk_{table}_{column}
Example:    CONSTRAINT fk_stencil_designs_organization
              FOREIGN KEY (organization_id) REFERENCES organizations(id)
```

### 2.5 Indexes

```
Convention: idx_{table}_{column(s)}
Examples:   idx_stencil_designs_project_id
            idx_aperture_designs_stencil_design_id
            idx_rule_results_rule_check_run_id
            idx_defect_records_project_id_created_at
            
Unique indexes: uq_{table}_{column(s)}
Examples:   uq_organizations_code
            uq_engineers_email
```

### 2.6 Constraints

```
Check constraints:    chk_{table}_{description}
Example:              chk_aperture_designs_area_ratio_positive
                      CHECK (area_ratio > 0)

Unique constraints:   uq_{table}_{column(s)}
Not null:             Expressed inline in column definition
```

### 2.7 Enum Type Names

```
Convention: {table_singular}_{column}_enum
Examples:   organization_ipc_class_enum        ('class_1', 'class_2', 'class_3')
            stencil_design_status_enum          ('draft', 'in_review', 'approved', ...)
            engineering_rule_severity_enum      ('critical', 'major', 'minor', 'advisory')
            
Shared enums (used across multiple tables):
            ipc_class_enum                      ('class_1', 'class_2', 'class_3')
            assembly_side_enum                  ('top', 'bottom', 'both')
            pass_fail_enum                      ('pass', 'fail', 'warning', 'not_run')
```

---

## 3. Data Type Standards

### 3.1 Type Selection Guide

| Data Category | Recommended Type | Rationale |
|---|---|---|
| Primary keys | `UUID` | Globally unique, offline-safe, no sequence collisions |
| Foreign keys | `UUID` | Matches primary keys |
| Short identifiers | `VARCHAR(50)` | Codes, abbreviations, version strings |
| Names / titles | `VARCHAR(255)` | Display names, bounded but generous |
| Long descriptions | `TEXT` | Engineering notes, rationale, content — unbounded |
| Physical measurements | `NUMERIC(10,4)` | 4 decimal places sufficient for mm precision; avoids float rounding |
| Percentages | `NUMERIC(6,3)` | e.g., 99.875 — 3 decimal places |
| Counts | `INTEGER` | Component counts, layer counts, pin counts |
| Large counts | `BIGINT` | Audit log sequence numbers, print cycle counts |
| Flags | `BOOLEAN` | is_active, has_thermal_pad — never use 0/1 integers |
| Status / type | `VARCHAR(50)` with CHECK constraint or Postgres `ENUM` | See enum strategy below |
| Timestamps | `TIMESTAMPTZ` | Always with timezone — stored as UTC |
| Dates only | `DATE` | Release dates, commissioning dates |
| Structured data | `JSONB` | Snapshots, formula inputs/outputs, rule condition trees |
| Arrays | `TEXT[]` or `UUID[]` | Tags, lists of IDs — use junction table for complex relationships |
| Large text | `TEXT` | No VARCHAR limit needed for engineering content |
| Storage paths | `TEXT` | Supabase storage paths — unbounded |
| URLs | `TEXT` | Datasheet URLs — unbounded |
| Currency | `NUMERIC(12,4)` | Future cost tracking |
| Sequence numbers | `SERIAL` or `BIGSERIAL` | Human-readable document numbers only |

### 3.2 ENUM vs VARCHAR Strategy

**Use PostgreSQL native ENUM when:**
- Values are fixed and defined at schema design time
- Values will appear in dozens of tables
- Type safety at the database level is critical
- Examples: `ipc_class_enum`, `assembly_side_enum`, `pass_fail_enum`

**Use VARCHAR(50) with CHECK constraint when:**
- Values may need to be extended by configuration (not migration)
- The list is long but finite
- Examples: per-table status enums, category codes

**Use lookup/reference table when:**
- Values carry additional metadata (display name, description, sort order)
- Values may be user-configurable
- Examples: `defect_categories`, `inspection_methods`, `surface_finishes`

### 3.3 JSONB Usage Policy

JSONB is used in exactly four scenarios:

| Scenario | Example | Rationale |
|---|---|---|
| **Immutable snapshots** | `stencil_data_snapshot`, `context_snapshot` | Preserve exact state at a point in time |
| **Flexible structured data** | `formula_inputs`, `formula_outputs`, `variables_tested` | Schema varies per record type |
| **Condition trees** | `rule_condition_tree` | Recursive tree structure unsuited to relational model |
| **Result aggregates** | `rule_check_results_summary`, `five_why_data` | Denormalized for read performance |

JSONB is **never** used as a substitute for proper normalization of stable, queryable data.

### 3.4 Physical Measurement Precision

All physical measurements follow these precision standards:

| Measurement | Type | Unit Suffix | Precision | Example |
|---|---|---|---|---|
| Length/width/height | `NUMERIC(10,4)` | `_mm` | 0.0001 mm | `width_mm = 0.3048` |
| Micro-scale | `NUMERIC(10,2)` | `_um` | 0.01 µm | `roughness_ra_um = 0.45` |
| Volume | `NUMERIC(12,6)` | `_mm3` | 0.000001 mm³ | `paste_volume_mm3 = 0.002340` |
| Area | `NUMERIC(12,6)` | `_mm2` | 0.000001 mm² | `aperture_area_mm2 = 0.135000` |
| Temperature | `NUMERIC(6,2)` | `_temp_c` | 0.01°C | `peak_temp_c = 245.50` |
| Percentage | `NUMERIC(6,3)` | `_pct` | 0.001% | `coverage_pct = 67.500` |
| Ratio | `NUMERIC(8,4)` | (none — dimensionless) | 0.0001 | `area_ratio = 0.6623` |
| Pressure | `NUMERIC(8,3)` | `_kg` | 0.001 kg | `squeegee_pressure_kg = 7.500` |
| Speed | `NUMERIC(8,3)` | `_mm_per_s` | 0.001 mm/s | `squeegee_speed_mm_per_s = 25.000` |
| Weight | `NUMERIC(10,6)` | `_g` | 0.000001 g | `weight_g = 0.000120` |

---

## 4. Module Map — All Tables

The following 95 tables are organized into 22 functional modules. This is the complete table inventory.

```
MODULE 01 — CORE SYSTEM & TENANCY (4 tables)
  organizations
  organization_settings
  schema_migrations
  application_config

MODULE 02 — USER MANAGEMENT & SECURITY (6 tables)
  engineers
  roles
  permissions
  engineer_roles
  role_permissions
  engineer_sessions

MODULE 03 — PROJECTS & CUSTOMERS (6 tables)
  customers
  products
  projects
  project_engineers
  project_notes
  project_tags

MODULE 04 — PCB & ASSEMBLY (4 tables)
  pcb_assemblies
  pcb_revisions
  surface_finishes
  component_placements

MODULE 05 — COMPONENT & PACKAGE LIBRARY (5 tables)
  package_families
  smt_packages
  component_libraries
  components
  component_library_members

MODULE 06 — LAND PATTERNS & PADS (4 tables)
  land_patterns
  pads
  thermal_pads
  pad_groups

MODULE 07 — STENCIL DESIGN (5 tables)
  stencil_designs
  stencil_revisions
  aperture_designs
  aperture_shapes
  stencil_design_notes

MODULE 08 — MATERIALS LIBRARY (6 tables)
  stencil_materials
  stencil_thickness_options
  stencil_coatings
  solder_pastes
  paste_manufacturers
  material_compatibility_rules

MODULE 09 — PROCESS & EQUIPMENT (6 tables)
  printers
  placement_machines
  reflow_ovens
  reflow_profiles
  print_parameter_sets
  process_environments

MODULE 10 — INSPECTION (7 tables)
  inspection_methods
  inspection_equipment
  spi_measurements
  spi_deposit_measurements
  aoi_results
  aoi_defect_findings
  xray_results

MODULE 11 — DEFECT & FAILURE KNOWLEDGE (8 tables)
  defect_categories
  defect_types
  failure_mechanisms
  root_causes
  corrective_actions
  preventive_actions
  defect_records
  defect_investigations

MODULE 12 — RULE ENGINE (7 tables)
  rule_sets
  engineering_rules
  rule_conditions
  rule_groups
  rule_set_memberships
  rule_check_runs
  rule_results

MODULE 13 — ENGINEERING CALCULATIONS (3 tables)
  calculation_templates
  calculation_inputs
  calculation_results

MODULE 14 — RECOMMENDATION ENGINE (4 tables)
  recommendation_templates
  recommendations
  recommendation_options
  recommendation_conflicts

MODULE 15 — INTELLIGENCE & SCORING (4 tables)
  design_score_cards
  defect_risk_assessments
  yield_predictions
  process_context_snapshots

MODULE 16 — LEARNING SYSTEM (4 tables)
  learning_events
  pattern_records
  confidence_adjustments
  knowledge_review_flags

MODULE 17 — KNOWLEDGE BASE (5 tables)
  ipc_standards
  ipc_references
  case_studies
  experiments
  theory_cards

MODULE 18 — IMAGES & MEDIA (3 tables)
  image_records
  image_annotations
  image_tags

MODULE 19 — REPORTS & DOCUMENTS (4 tables)
  report_templates
  generated_reports
  engineering_notes
  document_attachments

MODULE 20 — AUDIT, ACTIVITY & NOTIFICATIONS (4 tables)
  audit_log
  activity_log
  notifications
  notification_preferences

MODULE 21 — APPLICATION SETTINGS (3 tables)
  app_settings
  user_preferences
  feature_flags

MODULE 22 — FUTURE AI LAYER (3 tables)
  ai_feedback_records
  ai_conversation_logs
  ai_model_versions

TOTAL: 106 tables
```

---

## 5. Module 01 — Core System & Tenancy

---

### TABLE: `organizations`

**Purpose:** Top-level tenant entity. Every piece of user data in the system belongs to an organization. This is the root of the multi-tenancy model.

**Description:** Represents a company, plant, or department using StencilPro. All engineers, projects, customized rules, and knowledge records are scoped to an organization. Supabase RLS policies enforce that users can only access records belonging to their own organization.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(255) | NOT NULL | Full organization name |
| `code` | VARCHAR(20) | NOT NULL | Short unique code for reports (e.g., "ACME") |
| `industry_segment` | VARCHAR(50) | NOT NULL | automotive, medical, consumer, industrial, aerospace, defense, mixed |
| `default_ipc_class` | VARCHAR(10) | NOT NULL | class_1, class_2, class_3 |
| `default_units` | VARCHAR(10) | NOT NULL | metric, imperial |
| `default_currency` | VARCHAR(3) | NOT NULL | ISO 4217 code (e.g., "USD") |
| `logo_storage_path` | TEXT | NULL | Supabase Storage path for logo image |
| `timezone` | VARCHAR(50) | NOT NULL | IANA timezone string (e.g., "America/New_York") |
| `address_line1` | VARCHAR(255) | NULL | |
| `address_city` | VARCHAR(100) | NULL | |
| `address_country` | VARCHAR(2) | NULL | ISO 3166-1 alpha-2 |
| `subscription_tier` | VARCHAR(50) | NOT NULL | standard, professional, enterprise |
| `max_engineers` | INTEGER | NULL | License seat limit (NULL = unlimited) |
| `is_active` | BOOLEAN | NOT NULL | False = suspended/cancelled |
| `is_deleted` | BOOLEAN | NOT NULL | Soft delete flag |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_organizations_code` on `(code)`

**Indexes:**
- `idx_organizations_code` on `(code)` — lookup by code in reports
- `idx_organizations_is_active` on `(is_active)` where `is_deleted = false`

**Business Rules:**
- `code` must be globally unique across all organizations (not just within tenant)
- `default_ipc_class` sets the floor for all projects under this org
- When `is_deleted = true`, all child records become read-only via application logic

**Lifecycle:** Created at account setup. Never physically deleted. Soft-deleted on cancellation.

**Typical Record Count:** 1–5,000 (multi-tenant SaaS scenario)

**Archive Strategy:** Soft delete. Retain data for 7 years after deletion for regulatory compliance.

---

### TABLE: `organization_settings`

**Purpose:** Key-value configuration store for per-organization settings that don't fit in the main organizations table.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `setting_key` | VARCHAR(100) | NOT NULL | Setting identifier (e.g., "report.header.show_logo") |
| `setting_value` | TEXT | NULL | Setting value as string |
| `setting_type` | VARCHAR(20) | NOT NULL | string, boolean, integer, json |
| `description` | TEXT | NULL | What this setting controls |
| `updated_by_engineer_id` | UUID | NULL | FK → engineers |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_org_settings_org_key` on `(organization_id, setting_key)`

---

### TABLE: `schema_migrations`

**Purpose:** Tracks which database migration scripts have been applied. Managed by Alembic.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `version_num` | VARCHAR(32) | NOT NULL | Alembic revision ID |
| `applied_at` | TIMESTAMPTZ | NOT NULL | When migration was applied |

**Primary Key:** `version_num`

---

### TABLE: `application_config`

**Purpose:** System-wide configuration values that are not organization-specific. Read-only in production; modified only by administrators.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `config_key` | VARCHAR(100) | NOT NULL | Configuration key |
| `config_value` | TEXT | NOT NULL | Configuration value |
| `config_type` | VARCHAR(20) | NOT NULL | string, boolean, integer, json |
| `environment` | VARCHAR(20) | NOT NULL | all, development, production, test |
| `description` | TEXT | NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_app_config_key_env` on `(config_key, environment)`

---

## 6. Module 02 — User Management & Security

---

### TABLE: `engineers`

**Purpose:** Represents a human user of the system. Stores engineering identity, credentials, and preferences. Linked to Supabase Auth.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key — matches Supabase Auth user ID |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `email` | VARCHAR(255) | NOT NULL | Login email — matches Supabase Auth |
| `full_name` | VARCHAR(255) | NOT NULL | Display name |
| `title` | VARCHAR(100) | NULL | Job title |
| `employee_id` | VARCHAR(50) | NULL | Internal employee number |
| `ipc_certifications` | TEXT[] | NOT NULL | Array of IPC cert codes — default empty array |
| `default_ipc_class` | VARCHAR(10) | NULL | Override for org default |
| `preferred_units` | VARCHAR(10) | NOT NULL | metric, imperial |
| `signature_storage_path` | TEXT | NULL | Path to signature image in storage |
| `avatar_storage_path` | TEXT | NULL | Path to avatar image in storage |
| `phone` | VARCHAR(30) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | False = cannot login |
| `is_deleted` | BOOLEAN | NOT NULL | Soft delete |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `last_login_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_engineers_email` on `(email)`

**Indexes:**
- `idx_engineers_organization_id` on `(organization_id)`
- `idx_engineers_email` on `(email)`

**Foreign Keys:**
- `organization_id` → `organizations(id)`

**Business Rules:**
- `id` must equal the Supabase Auth UUID for this user — enforced at registration
- Email changes must be synchronized with Supabase Auth
- Deleted engineers retain all authored records (for audit trail) — names still displayed

---

### TABLE: `roles`

**Purpose:** Defines the set of roles available within the system. Roles group permissions.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NULL | NULL = system role; populated = org-custom role |
| `name` | VARCHAR(100) | NOT NULL | Role display name |
| `code` | VARCHAR(50) | NOT NULL | Machine code (e.g., "senior_engineer") |
| `description` | TEXT | NULL | Role description |
| `is_system_role` | BOOLEAN | NOT NULL | True = cannot be deleted |
| `is_active` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

**System Roles (seeded at install):**
- `viewer` — read-only access
- `engineer` — create and edit project data
- `senior_engineer` — approve stencil revisions, override rules
- `admin` — full access including rule set editing and user management
- `super_admin` — cross-organization access (Anthropic internal only)

---

### TABLE: `permissions`

**Purpose:** Atomic permission definitions. Each permission controls a specific system capability.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `code` | VARCHAR(100) | NOT NULL | Permission code (e.g., "stencil.approve") |
| `module` | VARCHAR(50) | NOT NULL | Which module this permission covers |
| `description` | TEXT | NOT NULL | Human description of what is permitted |
| `is_active` | BOOLEAN | NOT NULL | |

**Unique Constraints:** `uq_permissions_code` on `(code)`

**Sample Permission Codes:**
```
project.create, project.edit, project.delete, project.view
stencil.create, stencil.edit, stencil.approve, stencil.view
rule_set.edit, rule_set.view
engineer.manage
report.generate, report.view
defect.investigate, defect.close
experiment.create, experiment.close
knowledge.edit, knowledge.view
admin.full_access
```

---

### TABLE: `engineer_roles`

**Purpose:** Junction table assigning roles to engineers within an organization.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `role_id` | UUID | NOT NULL | FK → roles |
| `assigned_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `assigned_at` | TIMESTAMPTZ | NOT NULL | |
| `expires_at` | TIMESTAMPTZ | NULL | Optional — for temporary role assignments |

**Unique Constraints:** `uq_engineer_roles_engineer_role` on `(engineer_id, role_id)`

---

### TABLE: `role_permissions`

**Purpose:** Junction table mapping permissions to roles.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `role_id` | UUID | NOT NULL | FK → roles |
| `permission_id` | UUID | NOT NULL | FK → permissions |

**Unique Constraints:** `uq_role_permissions_role_permission` on `(role_id, permission_id)`

---

### TABLE: `engineer_sessions`

**Purpose:** Tracks active desktop application sessions for activity monitoring and security.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `session_token_hash` | VARCHAR(64) | NOT NULL | SHA-256 hash of session token (never store plaintext) |
| `app_version` | VARCHAR(20) | NOT NULL | Desktop app version |
| `os_platform` | VARCHAR(50) | NULL | Windows, macOS, Linux |
| `started_at` | TIMESTAMPTZ | NOT NULL | |
| `last_active_at` | TIMESTAMPTZ | NOT NULL | |
| `ended_at` | TIMESTAMPTZ | NULL | NULL = still active |
| `ended_reason` | VARCHAR(50) | NULL | logout, timeout, forced |

---

## 7. Module 03 — Projects & Customers

---

### TABLE: `customers`

**Purpose:** External customers or internal business units for whom assemblies are manufactured.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `name` | VARCHAR(255) | NOT NULL | Customer company name |
| `code` | VARCHAR(20) | NOT NULL | Short code for file naming |
| `industry_segment` | VARCHAR(50) | NOT NULL | automotive, medical, consumer, etc. |
| `required_ipc_class` | VARCHAR(10) | NOT NULL | Minimum IPC class required |
| `regulatory_requirements` | TEXT[] | NOT NULL | e.g., ["RoHS", "REACH", "MIL-STD-2000"] |
| `requires_signed_reports` | BOOLEAN | NOT NULL | |
| `approved_paste_ids` | UUID[] | NOT NULL | FK list → solder_pastes |
| `approved_stencil_material_ids` | UUID[] | NOT NULL | FK list → stencil_materials |
| `special_requirements_notes` | TEXT | NULL | Free-form |
| `contact_name` | VARCHAR(255) | NULL | Primary technical contact |
| `contact_email` | VARCHAR(255) | NULL | |
| `contact_phone` | VARCHAR(30) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_customers_org_code` on `(organization_id, code)`

**Indexes:** `idx_customers_organization_id` on `(organization_id)`

**Business Rules:**
- `required_ipc_class` is a constraint — project IPC class must be ≥ this value
- `approved_paste_ids` is checked by Rule Engine when a paste is selected for a project

---

### TABLE: `products`

**Purpose:** The end-product (device) containing PCB assemblies. Connects assemblies to commercial product context.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `customer_id` | UUID | NOT NULL | FK → customers |
| `name` | VARCHAR(255) | NOT NULL | Product name |
| `part_number` | VARCHAR(100) | NULL | Customer part number |
| `product_family` | VARCHAR(100) | NULL | Product line grouping |
| `market_segment` | VARCHAR(50) | NOT NULL | consumer, industrial, medical, automotive, aerospace, defense |
| `regulatory_requirements` | TEXT[] | NOT NULL | Inherited from customer + additions |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `projects`

**Purpose:** Primary organizational container for all work related to a specific PCB assembly's stencil engineering.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `customer_id` | UUID | NOT NULL | FK → customers |
| `product_id` | UUID | NULL | FK → products |
| `lead_engineer_id` | UUID | NOT NULL | FK → engineers |
| `project_number` | VARCHAR(50) | NOT NULL | Auto-generated human number |
| `name` | VARCHAR(255) | NOT NULL | Descriptive project name |
| `description` | TEXT | NULL | Scope and context |
| `status` | VARCHAR(30) | NOT NULL | draft, active, on_hold, completed, archived |
| `phase` | VARCHAR(30) | NOT NULL | npi, pre_production, production, eco, sustaining |
| `ipc_class` | VARCHAR(10) | NOT NULL | class_1, class_2, class_3 |
| `target_yield_pct` | NUMERIC(6,3) | NULL | Target first-pass yield |
| `start_date` | DATE | NULL | |
| `target_completion_date` | DATE | NULL | |
| `actual_completion_date` | DATE | NULL | |
| `tags` | TEXT[] | NOT NULL | Freeform classification tags |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_projects_org_number` on `(organization_id, project_number)`

**Indexes:**
- `idx_projects_organization_id` on `(organization_id)`
- `idx_projects_customer_id` on `(customer_id)`
- `idx_projects_lead_engineer_id` on `(lead_engineer_id)`
- `idx_projects_status` on `(status)` where `is_deleted = false`

**Check Constraints:**
- `chk_projects_ipc_class` ensures ipc_class >= customer.required_ipc_class (enforced in application)

**Business Rules:**
- `project_number` format is configurable per organization (e.g., "PROJ-{YEAR}-{SEQ}")
- Status transitions are logged as `project_notes` records automatically

---

### TABLE: `project_engineers`

**Purpose:** Junction table for assigning additional engineers to a project beyond the lead.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `project_id` | UUID | NOT NULL | FK → projects |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `role_on_project` | VARCHAR(50) | NOT NULL | lead, reviewer, contributor, observer |
| `assigned_at` | TIMESTAMPTZ | NOT NULL | |
| `assigned_by_engineer_id` | UUID | NOT NULL | FK → engineers |

**Unique Constraints:** `uq_project_engineers_project_engineer` on `(project_id, engineer_id)`

---

### TABLE: `project_notes`

**Purpose:** Append-only chronological audit log of events, decisions, and comments on a project.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `project_id` | UUID | NOT NULL | FK → projects |
| `engineer_id` | UUID | NOT NULL | FK → engineers (author) |
| `note_type` | VARCHAR(50) | NOT NULL | decision, comment, status_change, rule_override, milestone, warning, system |
| `title` | VARCHAR(255) | NOT NULL | Short summary |
| `content` | TEXT | NOT NULL | Full note content |
| `is_system_generated` | BOOLEAN | NOT NULL | True = created by system automatically |
| `linked_entity_type` | VARCHAR(100) | NULL | Table name of referenced entity |
| `linked_entity_id` | UUID | NULL | PK of referenced entity |
| `created_at` | TIMESTAMPTZ | NOT NULL | Immutable — never updated |

**Indexes:**
- `idx_project_notes_project_id_created_at` on `(project_id, created_at DESC)`

**Business Rules:**
- Records are **append-only** — no UPDATE or DELETE permitted
- `created_at` is set once and never changed
- Supabase RLS policy: INSERT allowed; UPDATE and DELETE denied for all roles

---

### TABLE: `project_tags`

**Purpose:** Normalized tag management for projects. Enables organization-wide tag standardization.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `tag_name` | VARCHAR(50) | NOT NULL | Lowercase tag text |
| `tag_color` | VARCHAR(7) | NULL | Hex color for UI display |
| `usage_count` | INTEGER | NOT NULL | Updated by trigger |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_project_tags_org_name` on `(organization_id, tag_name)`

---

## 8. Module 04 — PCB & Assembly

---

### TABLE: `pcb_assemblies`

**Purpose:** Represents a specific PCB design — the physical board that drives all stencil design decisions.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `product_id` | UUID | NULL | FK → products |
| `project_id` | UUID | NOT NULL | FK → projects |
| `name` | VARCHAR(255) | NOT NULL | Assembly name |
| `part_number` | VARCHAR(100) | NULL | Internal part number |
| `board_length_mm` | NUMERIC(10,4) | NULL | X dimension |
| `board_width_mm` | NUMERIC(10,4) | NULL | Y dimension |
| `board_thickness_mm` | NUMERIC(10,4) | NULL | Typical 0.8–3.2 mm |
| `layer_count` | INTEGER | NULL | Total copper layers |
| `base_material` | VARCHAR(50) | NOT NULL | fr4, rogers, polyimide, aluminum, ceramic, other |
| `tg_temperature_c` | NUMERIC(6,2) | NULL | Glass transition temperature |
| `outer_copper_weight_oz` | NUMERIC(6,3) | NULL | Outer layer copper weight |
| `surface_finish_id` | UUID | NOT NULL | FK → surface_finishes |
| `solder_mask_color` | VARCHAR(20) | NOT NULL | green, red, blue, black, white, yellow, purple |
| `assembly_sides` | VARCHAR(20) | NOT NULL | top_only, bottom_only, double_sided |
| `min_feature_size_mm` | NUMERIC(10,4) | NULL | Smallest copper feature |
| `min_via_drill_mm` | NUMERIC(10,4) | NULL | Minimum via drill diameter |
| `has_press_fit_connectors` | BOOLEAN | NOT NULL | |
| `has_edge_connectors` | BOOLEAN | NOT NULL | |
| `has_castellated_holes` | BOOLEAN | NOT NULL | |
| `gerber_storage_path` | TEXT | NULL | Path to Gerber/ODB++ in storage |
| `bom_storage_path` | TEXT | NULL | Path to BOM file in storage |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:** `idx_pcb_assemblies_project_id` on `(project_id)`

---

### TABLE: `pcb_revisions`

**Purpose:** A specific revision of a PCB design. All stencil engineering work attaches to a revision, never the assembly directly.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `pcb_assembly_id` | UUID | NOT NULL | FK → pcb_assemblies |
| `revision_code` | VARCHAR(20) | NOT NULL | e.g., "A", "B", "Rev3" |
| `revision_date` | DATE | NOT NULL | Release date |
| `released_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `change_summary` | TEXT | NULL | What changed from previous |
| `change_type` | VARCHAR(30) | NOT NULL | initial_release, minor_change, major_change, eco, prototype |
| `component_count` | INTEGER | NULL | Total component count |
| `smt_component_count` | INTEGER | NULL | SMT-only count |
| `unique_package_count` | INTEGER | NULL | Unique package types |
| `min_pitch_mm` | NUMERIC(10,4) | NULL | Smallest component pitch |
| `has_bgAs` | BOOLEAN | NOT NULL | Contains BGA components |
| `has_qfns` | BOOLEAN | NOT NULL | Contains QFN/LLP components |
| `has_01005_components` | BOOLEAN | NOT NULL | Contains 01005 passives |
| `has_step_stencil_requirement` | BOOLEAN | NOT NULL | Requires step stencil |
| `is_current_revision` | BOOLEAN | NOT NULL | Active design revision |
| `design_data_storage_path` | TEXT | NULL | Revision-specific Gerber/ODB++ |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_pcb_revisions_assembly_code` on `(pcb_assembly_id, revision_code)`

**Indexes:**
- `idx_pcb_revisions_pcb_assembly_id` on `(pcb_assembly_id)`
- `idx_pcb_revisions_is_current` on `(pcb_assembly_id)` where `is_current_revision = true`

**Business Rules:**
- Only one revision per assembly may have `is_current_revision = true` — enforced by partial unique index

---

### TABLE: `surface_finishes`

**Purpose:** Reference lookup table for PCB surface finish types and their engineering properties.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(100) | NOT NULL | e.g., "ENIG", "HASL Lead-Free" |
| `abbreviation` | VARCHAR(20) | NOT NULL | e.g., "ENIG", "HASL-LF" |
| `is_rohs_compliant` | BOOLEAN | NOT NULL | |
| `is_lead_free` | BOOLEAN | NOT NULL | |
| `flatness_rating` | VARCHAR(20) | NOT NULL | excellent, good, fair, poor |
| `coplanarity_um` | NUMERIC(10,2) | NULL | Typical surface height variation |
| `shelf_life_months` | INTEGER | NULL | Before finish degrades |
| `solderability_rating` | VARCHAR(20) | NOT NULL | excellent, good, fair |
| `typical_thickness_um` | NUMERIC(10,2) | NULL | Finish deposit thickness |
| `wettability_notes` | TEXT | NULL | Engineering notes on wetting |
| `ipc_specification` | VARCHAR(50) | NULL | Applicable IPC spec |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | True = shipped with app |

**Lifecycle:** Reference data. Seeded at install. New types added by admin only.

---

### TABLE: `component_placements`

**Purpose:** Records the placement of a specific component at a specific location on a specific PCB revision.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `pcb_revision_id` | UUID | NOT NULL | FK → pcb_revisions |
| `component_id` | UUID | NOT NULL | FK → components |
| `land_pattern_id` | UUID | NOT NULL | FK → land_patterns |
| `reference_designator` | VARCHAR(20) | NOT NULL | e.g., "U1", "C12", "R47" |
| `x_position_mm` | NUMERIC(10,4) | NOT NULL | Board centroid X |
| `y_position_mm` | NUMERIC(10,4) | NOT NULL | Board centroid Y |
| `rotation_degrees` | NUMERIC(8,4) | NOT NULL | 0–359.9999 |
| `assembly_side` | VARCHAR(10) | NOT NULL | top, bottom |
| `is_dnp` | BOOLEAN | NOT NULL | Do Not Populate |
| `dnp_reason` | VARCHAR(255) | NULL | |
| `notes` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_component_placements_revision_refdes` on `(pcb_revision_id, reference_designator)`

**Indexes:**
- `idx_component_placements_pcb_revision_id` on `(pcb_revision_id)`
- `idx_component_placements_component_id` on `(component_id)`

---

## 9. Module 05 — Component & Package Library

---

### TABLE: `package_families`

**Purpose:** Top-level grouping of SMT package types. Reference data — seeded from IPC standards.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(100) | NOT NULL | e.g., "Chip", "SOT", "QFP", "BGA", "QFN" |
| `ipc_family_code` | VARCHAR(20) | NULL | IPC-7351 family code |
| `termination_type` | VARCHAR(50) | NOT NULL | gull_wing, j_lead, lcc, bga, castellated, bottom_only, through_hole |
| `package_technology` | VARCHAR(20) | NOT NULL | smt, through_hole, mixed, press_fit |
| `general_pitch_range` | VARCHAR(50) | NULL | e.g., "0.4–0.8 mm" |
| `thermal_considerations` | TEXT | NULL | Family-level thermal notes |
| `inspection_difficulty` | VARCHAR(20) | NOT NULL | easy, moderate, difficult, very_difficult |
| `x_ray_typically_required` | BOOLEAN | NOT NULL | |
| `description` | TEXT | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `sort_order` | INTEGER | NOT NULL | Display sort order |

---

### TABLE: `smt_packages`

**Purpose:** A fully-defined SMT component package type — the geometric template from which land patterns and aperture designs are derived. One of the most important master data entities.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NULL | NULL = system package |
| `package_family_id` | UUID | NOT NULL | FK → package_families |
| `ipc_name` | VARCHAR(100) | NOT NULL | IPC-7351 canonical name |
| `common_name` | VARCHAR(100) | NOT NULL | Human-readable name |
| `manufacturer_name` | VARCHAR(100) | NULL | If package-specific |
| `ipc_density_level` | VARCHAR(5) | NOT NULL | most, nominal, least |
| `body_length_mm` | NUMERIC(10,4) | NULL | Package body X |
| `body_width_mm` | NUMERIC(10,4) | NULL | Package body Y |
| `body_height_mm` | NUMERIC(10,4) | NULL | Package height (Z) |
| `body_length_tolerance_mm` | NUMERIC(10,4) | NULL | |
| `body_width_tolerance_mm` | NUMERIC(10,4) | NULL | |
| `lead_pitch_mm` | NUMERIC(10,4) | NULL | Center-to-center lead spacing |
| `lead_count` | INTEGER | NULL | Total leads/balls/pads |
| `lead_width_mm` | NUMERIC(10,4) | NULL | Individual lead width |
| `lead_length_mm` | NUMERIC(10,4) | NULL | Individual lead length |
| `lead_thickness_mm` | NUMERIC(10,4) | NULL | |
| `standoff_height_mm` | NUMERIC(10,4) | NULL | Standoff from PCB surface |
| `has_thermal_pad` | BOOLEAN | NOT NULL | Exposed thermal pad |
| `thermal_pad_length_mm` | NUMERIC(10,4) | NULL | |
| `thermal_pad_width_mm` | NUMERIC(10,4) | NULL | |
| `thermal_pad_coverage_pct` | NUMERIC(6,3) | NULL | Recommended paste coverage % |
| `weight_g` | NUMERIC(10,6) | NULL | Component weight |
| `datasheet_url` | TEXT | NULL | |
| `ipc_land_pattern_storage_path` | TEXT | NULL | IPC reference drawing |
| `is_system_package` | BOOLEAN | NOT NULL | Shipped with app |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `notes` | TEXT | NULL | |
| `created_by_engineer_id` | UUID | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:**
- `idx_smt_packages_package_family_id` on `(package_family_id)`
- `idx_smt_packages_ipc_name` on `(ipc_name)`
- `idx_smt_packages_common_name` on `(common_name)` — for search

**Full-Text Search:** Create GIN index on `to_tsvector('english', ipc_name || ' ' || common_name)`

---

### TABLE: `component_libraries`

**Purpose:** A versioned, owned collection of approved components (Approved Parts List).

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `name` | VARCHAR(255) | NOT NULL | Library name |
| `version` | VARCHAR(20) | NOT NULL | Library version string |
| `description` | TEXT | NULL | |
| `is_default` | BOOLEAN | NOT NULL | Default for new projects |
| `is_locked` | BOOLEAN | NOT NULL | Prevents modifications |
| `released_at` | TIMESTAMPTZ | NULL | When approved for use |
| `released_by_engineer_id` | UUID | NULL | FK → engineers |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `components`

**Purpose:** A specific electronic component (manufacturer part number) linked to its package.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `package_id` | UUID | NOT NULL | FK → smt_packages |
| `manufacturer_name` | VARCHAR(100) | NOT NULL | |
| `manufacturer_part_number` | VARCHAR(100) | NOT NULL | MPN |
| `description` | VARCHAR(255) | NOT NULL | Function description |
| `component_category` | VARCHAR(50) | NOT NULL | resistor, capacitor, ic, connector, crystal, diode, transistor, module, other |
| `is_moisture_sensitive` | BOOLEAN | NOT NULL | |
| `moisture_sensitivity_level` | VARCHAR(5) | NULL | msl_1, msl_2, msl_2a, msl_3, msl_4, msl_5, msl_5a, msl_6 |
| `max_reflow_temp_c` | NUMERIC(6,2) | NULL | Maximum junction temperature |
| `has_special_paste_requirements` | BOOLEAN | NOT NULL | |
| `paste_requirement_notes` | TEXT | NULL | |
| `is_rohs_compliant` | BOOLEAN | NOT NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_components_org_mpn` on `(organization_id, manufacturer_part_number)`

---

### TABLE: `component_library_members`

**Purpose:** Junction table adding components to component libraries.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `component_library_id` | UUID | NOT NULL | FK → component_libraries |
| `component_id` | UUID | NOT NULL | FK → components |
| `added_at` | TIMESTAMPTZ | NOT NULL | |
| `added_by_engineer_id` | UUID | NOT NULL | FK → engineers |

**Unique Constraints:** `uq_component_library_members` on `(component_library_id, component_id)`

---

## 10. Module 06 — Land Patterns & Pads

---

### TABLE: `land_patterns`

**Purpose:** The copper pad geometry on the PCB that a component is soldered to. Direct driver of aperture design.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `package_id` | UUID | NOT NULL | FK → smt_packages |
| `pcb_revision_id` | UUID | NULL | NULL = reusable pattern not revision-specific |
| `name` | VARCHAR(100) | NOT NULL | Human-readable identifier |
| `ipc_density_level` | VARCHAR(10) | NOT NULL | most, nominal, least |
| `total_pad_count` | INTEGER | NOT NULL | |
| `courtyard_length_mm` | NUMERIC(10,4) | NULL | |
| `courtyard_width_mm` | NUMERIC(10,4) | NULL | |
| `paste_mask_expansion_mm` | NUMERIC(10,4) | NOT NULL | Default 0.00 |
| `source` | VARCHAR(30) | NOT NULL | ipc_7351, manufacturer, custom, calculated |
| `has_thermal_pad` | BOOLEAN | NOT NULL | |
| `drawing_storage_path` | TEXT | NULL | Land pattern drawing |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `created_by_engineer_id` | UUID | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `pads`

**Purpose:** A single copper pad within a land pattern. Atomic unit of solder joint geometry.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `land_pattern_id` | UUID | NOT NULL | FK → land_patterns |
| `pad_number` | INTEGER | NOT NULL | Pin/pad number |
| `pad_function` | VARCHAR(20) | NOT NULL | signal, power, ground, thermal, no_connect, fiducial |
| `shape` | VARCHAR(30) | NOT NULL | rectangle, rounded_rectangle, oval, circle, polygon, d_shape |
| `length_mm` | NUMERIC(10,4) | NOT NULL | Pad length (X) |
| `width_mm` | NUMERIC(10,4) | NOT NULL | Pad width (Y) |
| `corner_radius_mm` | NUMERIC(10,4) | NULL | For rounded rectangles |
| `x_offset_mm` | NUMERIC(10,4) | NOT NULL | From land pattern origin |
| `y_offset_mm` | NUMERIC(10,4) | NOT NULL | |
| `rotation_degrees` | NUMERIC(8,4) | NOT NULL | Pad rotation |
| `paste_mask_expansion_mm` | NUMERIC(10,4) | NULL | Override for this pad only |
| `paste_reduction_pct` | NUMERIC(6,3) | NULL | Percentage reduction |
| `is_paste_defined` | BOOLEAN | NOT NULL | vs copper-defined |
| `net_name` | VARCHAR(50) | NULL | Electrical net |
| `side` | VARCHAR(10) | NOT NULL | top, bottom |

**Unique Constraints:** `uq_pads_pattern_number` on `(land_pattern_id, pad_number)`

**Indexes:** `idx_pads_land_pattern_id` on `(land_pattern_id)`

---

### TABLE: `thermal_pads`

**Purpose:** Specialized entity for exposed thermal pads (QFN, LLP, DFN). Requires its own model due to unique paste, via, and thermal engineering requirements.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `land_pattern_id` | UUID | NOT NULL | FK → land_patterns |
| `length_mm` | NUMERIC(10,4) | NOT NULL | Overall thermal pad length |
| `width_mm` | NUMERIC(10,4) | NOT NULL | Overall thermal pad width |
| `area_mm2` | NUMERIC(12,6) | NOT NULL | Calculated |
| `recommended_paste_coverage_pct` | NUMERIC(6,3) | NULL | IPC-7093 recommended (50–80%) |
| `min_paste_coverage_pct` | NUMERIC(6,3) | NOT NULL | Minimum for thermal performance |
| `max_paste_coverage_pct` | NUMERIC(6,3) | NOT NULL | Maximum to prevent floating |
| `via_count` | INTEGER | NOT NULL | Thermal vias in pad |
| `via_drill_mm` | NUMERIC(10,4) | NULL | Thermal via drill diameter |
| `via_pitch_mm` | NUMERIC(10,4) | NULL | Via-to-via spacing |
| `via_tenting` | VARCHAR(30) | NULL | none, top, bottom, both, filled, filled_capped |
| `segmentation_strategy` | VARCHAR(30) | NOT NULL | none, grid, stripe_x, stripe_y, window_pane, custom |
| `segment_count_x` | INTEGER | NULL | Segments in X direction |
| `segment_count_y` | INTEGER | NULL | Segments in Y direction |
| `segment_gap_mm` | NUMERIC(10,4) | NULL | Gap between segments |
| `ipc_7093_compliant` | BOOLEAN | NULL | NULL = not yet evaluated |
| `voiding_risk` | VARCHAR(20) | NULL | low, medium, high, very_high |
| `engineering_notes` | TEXT | NULL | |
| `calculated_at` | TIMESTAMPTZ | NULL | When optimizer last ran |

**Unique Constraints:** `uq_thermal_pads_land_pattern` on `(land_pattern_id)` — one per land pattern

---

### TABLE: `pad_groups`

**Purpose:** Groups pads that share engineering characteristics (e.g., all signal pads on one side of a QFP, or the ground pad ring of a thermal pad). Used for batch aperture design rules.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `land_pattern_id` | UUID | NOT NULL | FK → land_patterns |
| `name` | VARCHAR(100) | NOT NULL | Group name |
| `group_type` | VARCHAR(50) | NOT NULL | signal_row, thermal_segment, power_ring, fiducials |
| `pad_ids` | UUID[] | NOT NULL | Array of pad IDs in this group |
| `shared_aperture_rule` | TEXT | NULL | Engineering rule applied to all pads in group |
| `notes` | TEXT | NULL | |


---

## 11. Module 07 — Stencil Design

---

### TABLE: `stencil_designs`

**Purpose:** The top-level container for all stencil engineering decisions for a specific PCB revision. The primary output of the stencil engineering process.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `project_id` | UUID | NOT NULL | FK → projects |
| `pcb_revision_id` | UUID | NOT NULL | FK → pcb_revisions |
| `stencil_material_id` | UUID | NULL | FK → stencil_materials |
| `stencil_coating_id` | UUID | NULL | FK → stencil_coatings |
| `stencil_thickness_option_id` | UUID | NULL | FK → stencil_thickness_options |
| `designed_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `approved_by_engineer_id` | UUID | NULL | FK → engineers |
| `stencil_number` | VARCHAR(50) | NOT NULL | Auto-generated stencil ID |
| `name` | VARCHAR(255) | NOT NULL | Descriptive name |
| `assembly_side` | VARCHAR(10) | NOT NULL | top, bottom, combined |
| `status` | VARCHAR(30) | NOT NULL | draft, in_review, approved, superseded, rejected |
| `design_intent` | TEXT | NULL | Engineering rationale for key decisions |
| `overall_rule_check_status` | VARCHAR(30) | NOT NULL | not_run, pass, pass_with_warnings, fail |
| `last_rule_check_at` | TIMESTAMPTZ | NULL | |
| `last_rule_check_rule_set_version` | VARCHAR(50) | NULL | |
| `area_ratio_min` | NUMERIC(8,4) | NULL | Calculated minimum AR |
| `area_ratio_avg` | NUMERIC(8,4) | NULL | Calculated average AR |
| `area_ratio_worst_aperture_id` | UUID | NULL | FK → aperture_designs |
| `aperture_count` | INTEGER | NULL | Total apertures — calculated |
| `critical_aperture_count` | INTEGER | NULL | Failing rule check — calculated |
| `overall_design_score` | NUMERIC(5,2) | NULL | 0–100 from Scoring Engine |
| `stencil_score` | NUMERIC(5,2) | NULL | |
| `manufacturability_score` | NUMERIC(5,2) | NULL | |
| `paste_score` | NUMERIC(5,2) | NULL | |
| `inspection_score` | NUMERIC(5,2) | NULL | |
| `ipc_compliance_score` | NUMERIC(5,2) | NULL | |
| `predicted_fpy_pct` | NUMERIC(6,3) | NULL | From Yield Prediction Model |
| `approved_at` | TIMESTAMPTZ | NULL | |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_stencil_designs_org_number` on `(organization_id, stencil_number)`

**Indexes:**
- `idx_stencil_designs_project_id` on `(project_id)`
- `idx_stencil_designs_pcb_revision_id` on `(pcb_revision_id)`
- `idx_stencil_designs_status` on `(status)` where `is_deleted = false`

**Business Rules:**
- `overall_rule_check_status` must be `pass` or `pass_with_warnings` before status can advance to `approved`
- `approved_by_engineer_id` cannot equal `designed_by_engineer_id` (four-eyes principle, configurable per org)
- Score columns are calculated fields — updated by the Intelligence Engine after every significant change

---

### TABLE: `stencil_revisions`

**Purpose:** A point-in-time immutable snapshot of a StencilDesign at each approval state. The version history.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `revision_number` | INTEGER | NOT NULL | Sequential: 1, 2, 3… |
| `revision_code` | VARCHAR(10) | NOT NULL | Human code: "A", "B", "C" |
| `revision_type` | VARCHAR(30) | NOT NULL | initial, minor_change, major_change, emergency_change |
| `change_summary` | TEXT | NOT NULL | What changed and why |
| `change_reason` | VARCHAR(50) | NOT NULL | pcb_change, process_problem, cost_reduction, customer_request, defect_correction |
| `authored_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `approved_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `approved_at` | TIMESTAMPTZ | NOT NULL | |
| `stencil_data_snapshot` | JSONB | NOT NULL | Full aperture parameter snapshot |
| `rule_check_summary` | JSONB | NOT NULL | Rule results at approval time |
| `design_scores_snapshot` | JSONB | NOT NULL | All scores at approval time |
| `stencil_file_storage_path` | TEXT | NULL | Gerber/DXF file in storage |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_stencil_revisions_design_number` on `(stencil_design_id, revision_number)`

**Business Rules:**
- Once created, a `stencil_revision` record is **never modified** — immutable by RLS policy

---

### TABLE: `aperture_designs`

**Purpose:** The engineering specification for a single stencil aperture. The fundamental unit of stencil engineering.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `pad_id` | UUID | NOT NULL | FK → pads |
| `aperture_shape_id` | UUID | NOT NULL | FK → aperture_shapes |
| `design_method` | VARCHAR(30) | NOT NULL | ipc_default, engineer_defined, optimized, manufacturer_recommended |
| `length_mm` | NUMERIC(10,4) | NOT NULL | Aperture opening length |
| `width_mm` | NUMERIC(10,4) | NOT NULL | Aperture opening width |
| `corner_radius_mm` | NUMERIC(10,4) | NULL | For trapezoidal/rounded |
| `x_offset_mm` | NUMERIC(10,4) | NOT NULL | Offset from pad center |
| `y_offset_mm` | NUMERIC(10,4) | NOT NULL | |
| `rotation_degrees` | NUMERIC(8,4) | NOT NULL | |
| `area_ratio` | NUMERIC(8,4) | NULL | Calculated |
| `aspect_ratio` | NUMERIC(8,4) | NULL | Calculated |
| `aperture_area_mm2` | NUMERIC(12,6) | NULL | Calculated |
| `paste_volume_mm3` | NUMERIC(12,6) | NULL | Calculated |
| `transfer_efficiency_pct` | NUMERIC(6,3) | NULL | Estimated from area ratio |
| `aperture_to_aperture_gap_mm` | NUMERIC(10,4) | NULL | Min gap to nearest neighbor |
| `bridging_risk_score` | NUMERIC(5,4) | NULL | 0.0–1.0 from Defect Engine |
| `insufficient_paste_risk_score` | NUMERIC(5,4) | NULL | 0.0–1.0 |
| `rule_check_status` | VARCHAR(30) | NOT NULL | not_run, pass, warning, fail |
| `rule_check_summary` | JSONB | NULL | Last rule check for this aperture |
| `engineer_override` | BOOLEAN | NOT NULL | |
| `override_justification` | TEXT | NULL | Mandatory if override = true |
| `override_approved_by_id` | UUID | NULL | FK → engineers |
| `override_approved_at` | TIMESTAMPTZ | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `notes` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:**
- `idx_aperture_designs_stencil_design_id` on `(stencil_design_id)`
- `idx_aperture_designs_pad_id` on `(pad_id)`
- `idx_aperture_designs_rule_check_status` on `(stencil_design_id, rule_check_status)`

**Check Constraints:**
- `chk_aperture_designs_area_ratio` CHECK (area_ratio IS NULL OR area_ratio > 0)
- `chk_aperture_designs_override` CHECK (engineer_override = false OR override_justification IS NOT NULL)

---

### TABLE: `aperture_shapes`

**Purpose:** Reference lookup for supported aperture geometric shapes and their area ratio calculation methods.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(50) | NOT NULL | e.g., "Rectangle", "Circle", "Home Plate" |
| `code` | VARCHAR(20) | NOT NULL | Short code (e.g., "RECT", "CIRC", "HOMEPLATE") |
| `area_formula_description` | TEXT | NOT NULL | Human-readable formula |
| `area_formula_variables` | JSONB | NOT NULL | Variable names and units |
| `area_ratio_formula_description` | TEXT | NOT NULL | IPC AR formula description |
| `ipc_reference` | VARCHAR(50) | NULL | |
| `typical_use_case` | TEXT | NULL | |
| `laser_cut_difficulty` | VARCHAR(20) | NOT NULL | standard, moderate, complex, premium |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `sort_order` | INTEGER | NOT NULL | |

**Unique Constraints:** `uq_aperture_shapes_code` on `(code)`

---

### TABLE: `stencil_design_notes`

**Purpose:** Engineering notes specific to a stencil design — append-only, like project_notes.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `note_type` | VARCHAR(50) | NOT NULL | decision, comment, override_justification, system, milestone |
| `title` | VARCHAR(255) | NOT NULL | |
| `content` | TEXT | NOT NULL | |
| `linked_aperture_id` | UUID | NULL | FK → aperture_designs (if aperture-specific note) |
| `is_system_generated` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | Immutable |

---

## 12. Module 08 — Materials Library

---

### TABLE: `stencil_materials`

**Purpose:** Master data for stencil foil materials and their engineering properties.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NULL | NULL = system material |
| `name` | VARCHAR(100) | NOT NULL | e.g., "Laser-Cut SS 304" |
| `manufacturer` | VARCHAR(100) | NULL | |
| `material_type` | VARCHAR(30) | NOT NULL | stainless_steel, electroform_nickel, nickel_palladium, composite, plastic |
| `fabrication_method` | VARCHAR(30) | NOT NULL | laser_cut, electroform, chemical_etch, hybrid |
| `thickness_range_min_mm` | NUMERIC(10,4) | NOT NULL | |
| `thickness_range_max_mm` | NUMERIC(10,4) | NOT NULL | |
| `surface_roughness_ra_um` | NUMERIC(10,2) | NULL | Average Ra roughness |
| `grain_structure` | VARCHAR(20) | NULL | smooth, standard, rough |
| `aperture_wall_smoothness` | VARCHAR(20) | NOT NULL | excellent, good, fair |
| `chemical_resistance` | VARCHAR(20) | NOT NULL | excellent, good, fair, poor |
| `cleaning_compatibility` | TEXT[] | NOT NULL | Compatible chemistries |
| `estimated_print_life_cycles` | INTEGER | NULL | |
| `min_aperture_width_mm` | NUMERIC(10,4) | NULL | Smallest reliable aperture |
| `is_rohs_compliant` | BOOLEAN | NOT NULL | |
| `relative_cost` | VARCHAR(10) | NOT NULL | low, medium, high, premium |
| `area_ratio_threshold_override` | NUMERIC(8,4) | NULL | If material allows lower AR threshold |
| `datasheet_url` | TEXT | NULL | |
| `notes` | TEXT | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `stencil_thickness_options`

**Purpose:** Reference data for standard stencil foil thickness values and their engineering implications.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `thickness_mm` | NUMERIC(10,4) | NOT NULL | Foil thickness |
| `thickness_um` | INTEGER | NOT NULL | Same in micrometers |
| `common_name` | VARCHAR(20) | NULL | e.g., "4-mil", "5-mil" |
| `ipc_class_suitability` | VARCHAR(20) | NOT NULL | class_1_2, class_2_3, class_3 |
| `min_recommended_pitch_mm` | NUMERIC(10,4) | NULL | Minimum pitch this thickness serves |
| `max_recommended_pitch_mm` | NUMERIC(10,4) | NULL | |
| `typical_paste_volume_factor` | NUMERIC(6,4) | NULL | Relative volume (0.15mm = 1.0) |
| `area_ratio_impact` | TEXT | NULL | Engineering explanation |
| `bridging_risk` | VARCHAR(10) | NOT NULL | low, medium, high |
| `is_suitable_for_01005` | BOOLEAN | NOT NULL | |
| `is_suitable_for_fine_pitch` | BOOLEAN | NOT NULL | pitch <= 0.5mm |
| `is_suitable_for_ultra_fine_pitch` | BOOLEAN | NOT NULL | pitch <= 0.4mm |
| `step_stencil_candidate` | BOOLEAN | NOT NULL | |
| `notes` | TEXT | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |

**Unique Constraints:** `uq_stencil_thickness_mm` on `(thickness_mm)`

---

### TABLE: `stencil_coatings`

**Purpose:** Master data for stencil surface coating types and their paste release performance effects.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NULL | NULL = system record |
| `name` | VARCHAR(100) | NOT NULL | e.g., "Nano-coating", "PTFE" |
| `coating_type` | VARCHAR(30) | NOT NULL | none, nano, ptfe, electroless_nickel, nickel_boron, polymer, proprietary |
| `manufacturer` | VARCHAR(100) | NULL | |
| `contact_angle_degrees` | NUMERIC(6,2) | NULL | Contact angle with paste |
| `paste_release_improvement` | VARCHAR(20) | NOT NULL | none, slight, moderate, significant |
| `life_expectancy_prints` | INTEGER | NULL | |
| `recoatable` | BOOLEAN | NULL | |
| `compatible_paste_flux_types` | TEXT[] | NOT NULL | |
| `incompatible_paste_flux_types` | TEXT[] | NOT NULL | |
| `cleaning_compatibility` | TEXT[] | NOT NULL | |
| `cost_adder_pct` | NUMERIC(6,3) | NULL | Cost increase over uncoated |
| `recommended_for_tags` | TEXT[] | NOT NULL | e.g., ["fine_pitch", "no_clean"] |
| `notes` | TEXT | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |

---

### TABLE: `solder_pastes`

**Purpose:** Master data for solder paste products and their engineering-relevant properties. One of the most complex material entities.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NULL | NULL = system record |
| `paste_manufacturer_id` | UUID | NOT NULL | FK → paste_manufacturers |
| `product_name` | VARCHAR(100) | NOT NULL | e.g., "SAC305 T4 No-Clean" |
| `part_number` | VARCHAR(50) | NOT NULL | Manufacturer part number |
| `solder_alloy` | VARCHAR(30) | NOT NULL | sac305, sac405, snpb63_37, snbi, sac_low, bismuth, in_ag, custom |
| `alloy_composition` | VARCHAR(100) | NULL | e.g., "Sn96.5/Ag3.0/Cu0.5" |
| `liquidus_temp_c` | NUMERIC(6,2) | NOT NULL | Alloy liquidus temperature |
| `solidus_temp_c` | NUMERIC(6,2) | NOT NULL | Alloy solidus temperature |
| `flux_type` | VARCHAR(30) | NOT NULL | no_clean, water_soluble, rosin_rma, low_residue |
| `flux_activity` | VARCHAR(5) | NOT NULL | L0, L1, L2 per IPC J-STD-004B |
| `ipc_flux_classification` | VARCHAR(10) | NULL | e.g., "REL0", "ROL1" |
| `metal_content_pct` | NUMERIC(6,3) | NOT NULL | Metal % by weight |
| `particle_size_class` | VARCHAR(5) | NOT NULL | T3, T4, T4.5, T5, T6, T7, T8 |
| `particle_size_min_um` | NUMERIC(8,2) | NOT NULL | |
| `particle_size_max_um` | NUMERIC(8,2) | NOT NULL | |
| `viscosity_cp` | NUMERIC(10,2) | NULL | Typical viscosity |
| `viscosity_test_method` | VARCHAR(100) | NULL | |
| `slump_resistance` | VARCHAR(20) | NOT NULL | excellent, good, fair |
| `tack_force_g` | NUMERIC(8,2) | NULL | |
| `tack_life_hours` | NUMERIC(6,2) | NULL | |
| `is_halogen_free` | BOOLEAN | NOT NULL | |
| `is_rohs_compliant` | BOOLEAN | NOT NULL | |
| `storage_temp_min_c` | NUMERIC(6,2) | NOT NULL | |
| `storage_temp_max_c` | NUMERIC(6,2) | NOT NULL | |
| `shelf_life_refrigerated_months` | INTEGER | NOT NULL | |
| `floor_life_hours` | INTEGER | NOT NULL | |
| `spi_measurability` | VARCHAR(20) | NOT NULL | excellent, good, fair |
| `datasheet_url` | TEXT | NULL | |
| `sds_url` | TEXT | NULL | Safety data sheet |
| `notes` | TEXT | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:** `idx_solder_pastes_paste_manufacturer_id` on `(paste_manufacturer_id)`

---

### TABLE: `paste_manufacturers`

**Purpose:** Reference lookup for solder paste manufacturers.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(100) | NOT NULL | e.g., "Henkel", "Indium Corporation" |
| `website_url` | TEXT | NULL | |
| `technical_support_email` | VARCHAR(255) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |

---

### TABLE: `material_compatibility_rules`

**Purpose:** Explicit compatibility and incompatibility declarations between material combinations. Consumed by the Rule Engine's material_compatibility rule group.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NULL | NULL = system rule |
| `rule_type` | VARCHAR(30) | NOT NULL | compatible, incompatible, requires_validation |
| `material_a_type` | VARCHAR(50) | NOT NULL | Table name of material A (e.g., "stencil_coatings") |
| `material_a_id` | UUID | NULL | NULL = applies to all of material_a_type |
| `material_a_attribute` | VARCHAR(50) | NULL | Specific attribute to match |
| `material_a_value` | VARCHAR(100) | NULL | Attribute value to match |
| `material_b_type` | VARCHAR(50) | NOT NULL | Table name of material B |
| `material_b_id` | UUID | NULL | |
| `material_b_attribute` | VARCHAR(50) | NULL | |
| `material_b_value` | VARCHAR(100) | NULL | |
| `severity` | VARCHAR(20) | NOT NULL | critical, warning, advisory |
| `description` | TEXT | NOT NULL | Engineering explanation |
| `ipc_reference` | VARCHAR(100) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |

---

## 13. Module 09 — Process & Equipment

---

### TABLE: `printers`

**Purpose:** Equipment registry for solder paste printers.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `manufacturer` | VARCHAR(100) | NOT NULL | e.g., "DEK", "MPM", "Ekra" |
| `model` | VARCHAR(100) | NOT NULL | |
| `serial_number` | VARCHAR(50) | NULL | |
| `asset_id` | VARCHAR(50) | NULL | Internal asset ID |
| `max_board_length_mm` | NUMERIC(10,4) | NULL | |
| `max_board_width_mm` | NUMERIC(10,4) | NULL | |
| `has_integrated_spi` | BOOLEAN | NOT NULL | |
| `print_accuracy_um` | NUMERIC(8,2) | NULL | Specified accuracy |
| `vision_system_model` | VARCHAR(100) | NULL | |
| `location` | VARCHAR(100) | NULL | Physical location |
| `commissioning_date` | DATE | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `notes` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `placement_machines`

**Purpose:** Equipment registry for SMT component placement machines.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `manufacturer` | VARCHAR(100) | NOT NULL | e.g., "Fuji", "Panasonic", "Yamaha" |
| `model` | VARCHAR(100) | NOT NULL | |
| `machine_type` | VARCHAR(50) | NOT NULL | high_speed_chip, flexible, high_accuracy, multi_function |
| `serial_number` | VARCHAR(50) | NULL | |
| `asset_id` | VARCHAR(50) | NULL | |
| `placement_accuracy_um` | NUMERIC(8,2) | NULL | Specified Cpk |
| `min_component_size_mm` | NUMERIC(10,4) | NULL | |
| `max_component_size_mm` | NUMERIC(10,4) | NULL | |
| `nozzle_types_available` | TEXT[] | NOT NULL | |
| `feeder_capacity` | INTEGER | NULL | |
| `location` | VARCHAR(100) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `reflow_ovens`

**Purpose:** Equipment registry for reflow ovens.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `manufacturer` | VARCHAR(100) | NOT NULL | e.g., "Heller", "BTU", "Vitronics" |
| `model` | VARCHAR(100) | NOT NULL | |
| `zone_count` | INTEGER | NULL | Number of heating zones |
| `has_nitrogen_atmosphere` | BOOLEAN | NOT NULL | |
| `conveyor_width_mm` | NUMERIC(10,4) | NULL | |
| `serial_number` | VARCHAR(50) | NULL | |
| `asset_id` | VARCHAR(50) | NULL | |
| `location` | VARCHAR(100) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `reflow_profiles`

**Purpose:** Defines a solder reflow oven temperature profile — the thermal recipe for a specific paste and oven combination.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `reflow_oven_id` | UUID | NULL | FK → reflow_ovens |
| `paste_id` | UUID | NOT NULL | FK → solder_pastes |
| `name` | VARCHAR(100) | NOT NULL | |
| `alloy_type` | VARCHAR(30) | NOT NULL | sac305, sac405, snpb, low_temp_bismuth |
| `preheat_temp_min_c` | NUMERIC(6,2) | NOT NULL | |
| `preheat_temp_max_c` | NUMERIC(6,2) | NOT NULL | |
| `preheat_time_s` | NUMERIC(8,2) | NOT NULL | |
| `soak_temp_min_c` | NUMERIC(6,2) | NOT NULL | |
| `soak_temp_max_c` | NUMERIC(6,2) | NOT NULL | |
| `soak_time_s` | NUMERIC(8,2) | NOT NULL | |
| `peak_temp_min_c` | NUMERIC(6,2) | NOT NULL | |
| `peak_temp_max_c` | NUMERIC(6,2) | NOT NULL | |
| `time_above_liquidus_s` | NUMERIC(8,2) | NOT NULL | TAL |
| `time_above_liquidus_min_s` | NUMERIC(8,2) | NOT NULL | IPC minimum |
| `time_above_liquidus_max_s` | NUMERIC(8,2) | NOT NULL | IPC maximum |
| `cooling_rate_max_c_per_s` | NUMERIC(6,3) | NOT NULL | |
| `delta_t_max_c` | NUMERIC(6,2) | NULL | Max temp difference across board |
| `ipc_class_compliance` | VARCHAR(10) | NOT NULL | class_1, class_2, class_3 |
| `profile_storage_path` | TEXT | NULL | Profile data file |
| `is_validated` | BOOLEAN | NOT NULL | |
| `validated_by_engineer_id` | UUID | NULL | FK → engineers |
| `validated_at` | TIMESTAMPTZ | NULL | |
| `notes` | TEXT | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `print_parameter_sets`

**Purpose:** The solder paste printing process parameters for a specific stencil design and printer combination.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `printer_id` | UUID | NOT NULL | FK → printers |
| `paste_id` | UUID | NOT NULL | FK → solder_pastes |
| `name` | VARCHAR(100) | NOT NULL | |
| `squeegee_speed_mm_per_s` | NUMERIC(8,3) | NOT NULL | |
| `squeegee_pressure_kg` | NUMERIC(8,3) | NOT NULL | |
| `squeegee_angle_degrees` | NUMERIC(6,2) | NOT NULL | |
| `squeegee_type` | VARCHAR(20) | NOT NULL | metal, polyurethane |
| `separation_speed_mm_per_s` | NUMERIC(8,3) | NOT NULL | |
| `separation_distance_mm` | NUMERIC(10,4) | NOT NULL | |
| `snap_off_mode` | VARCHAR(30) | NOT NULL | fixed_gap, controlled_separation, zero_gap |
| `print_stroke` | VARCHAR(20) | NOT NULL | unidirectional, bidirectional |
| `print_gap_mm` | NUMERIC(10,4) | NOT NULL | |
| `cleaning_frequency_prints` | INTEGER | NOT NULL | |
| `cleaning_mode` | VARCHAR(30) | NOT NULL | dry, wet, vacuum, combination |
| `board_support_type` | VARCHAR(30) | NOT NULL | none, pin_support, tooling_plate, vacuum |
| `vision_system_enabled` | BOOLEAN | NOT NULL | |
| `ambient_temp_c` | NUMERIC(6,2) | NULL | Required ambient |
| `ambient_humidity_pct` | NUMERIC(6,3) | NULL | Required relative humidity |
| `is_validated` | BOOLEAN | NOT NULL | |
| `validated_by_engineer_id` | UUID | NULL | FK → engineers |
| `validated_at` | TIMESTAMPTZ | NULL | |
| `notes` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `process_environments`

**Purpose:** Records of actual measured process environment conditions during a print session. Enables correlation of environment with process outcomes.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `printer_id` | UUID | NOT NULL | FK → printers |
| `recorded_at` | TIMESTAMPTZ | NOT NULL | |
| `ambient_temp_c` | NUMERIC(6,2) | NOT NULL | Measured temperature |
| `ambient_humidity_pct` | NUMERIC(6,3) | NOT NULL | Measured humidity |
| `is_within_spec` | BOOLEAN | NOT NULL | Within paste/stencil spec |
| `out_of_spec_notes` | TEXT | NULL | |

---

## 14. Module 10 — Inspection

---

### TABLE: `inspection_methods`

**Purpose:** Reference lookup for SMT inspection technologies and their capabilities.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(100) | NOT NULL | e.g., "3D SPI", "Post-Reflow AOI", "AXI" |
| `abbreviation` | VARCHAR(20) | NOT NULL | |
| `inspection_type` | VARCHAR(30) | NOT NULL | spi, aoi, xray, axi, manual, ict, cross_section |
| `inspection_stage` | VARCHAR(30) | NOT NULL | post_print, post_placement, post_reflow, final |
| `can_detect_volume_defects` | BOOLEAN | NOT NULL | |
| `can_detect_position_defects` | BOOLEAN | NOT NULL | |
| `can_detect_bridging` | BOOLEAN | NOT NULL | |
| `can_detect_voiding` | BOOLEAN | NOT NULL | |
| `can_detect_opens` | BOOLEAN | NOT NULL | |
| `is_destructive` | BOOLEAN | NOT NULL | |
| `coverage_pct_typical` | NUMERIC(6,3) | NULL | |
| `description` | TEXT | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |

---

### TABLE: `inspection_equipment`

**Purpose:** Equipment registry for all inspection machines across all types.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `inspection_method_id` | UUID | NOT NULL | FK → inspection_methods |
| `manufacturer` | VARCHAR(100) | NOT NULL | e.g., "Koh Young", "Mirtec", "Saki" |
| `model` | VARCHAR(100) | NOT NULL | |
| `serial_number` | VARCHAR(50) | NULL | |
| `asset_id` | VARCHAR(50) | NULL | |
| `location` | VARCHAR(100) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `commissioned_date` | DATE | NULL | |
| `notes` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `spi_measurements`

**Purpose:** Records a Solder Paste Inspection measurement session for a specific print event.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `print_parameter_set_id` | UUID | NULL | FK → print_parameter_sets |
| `inspection_equipment_id` | UUID | NULL | FK → inspection_equipment |
| `measurement_date` | TIMESTAMPTZ | NOT NULL | |
| `board_serial_number` | VARCHAR(50) | NULL | |
| `panel_position` | VARCHAR(20) | NULL | |
| `pass_fail_overall` | VARCHAR(10) | NOT NULL | pass, fail, marginal |
| `total_deposits_measured` | INTEGER | NOT NULL | |
| `deposits_passed` | INTEGER | NOT NULL | |
| `deposits_failed` | INTEGER | NOT NULL | |
| `deposits_marginal` | INTEGER | NOT NULL | |
| `measurement_file_storage_path` | TEXT | NULL | Raw SPI data file |
| `notes` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:** `idx_spi_measurements_stencil_design_id` on `(stencil_design_id)`

---

### TABLE: `spi_deposit_measurements`

**Purpose:** Individual SPI measurement for a single paste deposit (one aperture location). High-volume table.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `spi_measurement_id` | UUID | NOT NULL | FK → spi_measurements |
| `aperture_design_id` | UUID | NOT NULL | FK → aperture_designs |
| `reference_designator` | VARCHAR(20) | NOT NULL | |
| `pad_number` | INTEGER | NOT NULL | |
| `measured_volume_pct` | NUMERIC(8,3) | NOT NULL | % of nominal |
| `measured_height_pct` | NUMERIC(8,3) | NOT NULL | |
| `measured_area_pct` | NUMERIC(8,3) | NOT NULL | |
| `x_offset_mm` | NUMERIC(10,4) | NOT NULL | Position offset from pad |
| `y_offset_mm` | NUMERIC(10,4) | NOT NULL | |
| `pass_fail` | VARCHAR(10) | NOT NULL | pass, fail, warning |
| `failure_code` | VARCHAR(20) | NULL | insufficient, excessive, offset, missing, shape |

**Indexes:**
- `idx_spi_deposit_measurements_spi_id` on `(spi_measurement_id)`
- `idx_spi_deposit_measurements_aperture_id` on `(aperture_design_id)`

**Partitioning Strategy:** Partition by `spi_measurement_id` range or by `created_at` monthly — this table grows at ~500 rows per board inspected.

---

### TABLE: `aoi_results`

**Purpose:** Records post-reflow AOI inspection results for a PCB.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `inspection_equipment_id` | UUID | NULL | FK → inspection_equipment |
| `inspection_date` | TIMESTAMPTZ | NOT NULL | |
| `board_serial_number` | VARCHAR(50) | NULL | |
| `inspection_stage` | VARCHAR(30) | NOT NULL | post_placement, post_reflow |
| `pass_fail_overall` | VARCHAR(10) | NOT NULL | |
| `defects_detected` | INTEGER | NOT NULL | |
| `false_calls_confirmed` | INTEGER | NOT NULL | |
| `result_file_storage_path` | TEXT | NULL | AOI output file |
| `notes` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `aoi_defect_findings`

**Purpose:** Individual defect finding from an AOI inspection. Links back to aperture designs and defect types.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `aoi_result_id` | UUID | NOT NULL | FK → aoi_results |
| `aperture_design_id` | UUID | NULL | FK → aperture_designs |
| `reference_designator` | VARCHAR(20) | NULL | |
| `defect_type_id` | UUID | NULL | FK → defect_types |
| `finding_type` | VARCHAR(20) | NOT NULL | defect, false_call, marginal |
| `x_position_mm` | NUMERIC(10,4) | NULL | Board position |
| `y_position_mm` | NUMERIC(10,4) | NULL | |
| `image_storage_path` | TEXT | NULL | AOI image of this finding |
| `disposition` | VARCHAR(30) | NULL | confirmed, false_call, reworked, scrapped |
| `notes` | TEXT | NULL | |

---

### TABLE: `xray_results`

**Purpose:** Records X-ray or AXI inspection results, particularly for BGA voiding and hidden joint analysis.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `inspection_equipment_id` | UUID | NULL | FK → inspection_equipment |
| `inspection_date` | TIMESTAMPTZ | NOT NULL | |
| `board_serial_number` | VARCHAR(50) | NULL | |
| `inspection_scope` | VARCHAR(20) | NOT NULL | spot_check, sample, full_coverage |
| `voiding_measurements` | JSONB | NULL | Per-component voiding data |
| `max_voiding_pct_measured` | NUMERIC(6,3) | NULL | Worst-case voiding |
| `ipc_voiding_limit_pct` | NUMERIC(6,3) | NULL | Applicable IPC limit |
| `pass_fail_overall` | VARCHAR(10) | NOT NULL | |
| `result_file_storage_path` | TEXT | NULL | |
| `notes` | TEXT | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

---

## 15. Module 11 — Defect & Failure Knowledge

---

### TABLE: `defect_categories`

**Purpose:** Top-level classification of SMT defect types. Reference data.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(100) | NOT NULL | e.g., "Paste Volume Defects" |
| `code` | VARCHAR(20) | NOT NULL | Short code |
| `process_stage` | VARCHAR(30) | NOT NULL | printing, placement, reflow, post_reflow, cleaning |
| `description` | TEXT | NULL | |
| `ipc_reference` | VARCHAR(50) | NULL | |
| `sort_order` | INTEGER | NOT NULL | |
| `is_active` | BOOLEAN | NOT NULL | |

---

### TABLE: `defect_types`

**Purpose:** A specific, named SMT defect with full engineering description, visual criteria, and known failure mechanisms. Central knowledge entity.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `defect_category_id` | UUID | NOT NULL | FK → defect_categories |
| `name` | VARCHAR(100) | NOT NULL | e.g., "Solder Bridge", "Head-in-Pillow" |
| `common_aliases` | TEXT[] | NOT NULL | Other industry names |
| `defect_code` | VARCHAR(20) | NOT NULL | Internal code e.g., "DEF-011" |
| `severity` | VARCHAR(20) | NOT NULL | critical, major, minor, cosmetic |
| `ipc_class_1_acceptance` | VARCHAR(30) | NOT NULL | accept, reject, process_indicator |
| `ipc_class_2_acceptance` | VARCHAR(30) | NOT NULL | |
| `ipc_class_3_acceptance` | VARCHAR(30) | NOT NULL | |
| `ipc_reference` | VARCHAR(100) | NULL | e.g., "IPC-A-610G Section 7.3.2" |
| `visual_description` | TEXT | NOT NULL | How to visually identify |
| `detection_methods` | TEXT[] | NOT NULL | Which inspection methods detect this |
| `process_stage_origin` | VARCHAR(30) | NOT NULL | Where in process this originates |
| `stencil_related` | BOOLEAN | NOT NULL | Stencil is primary contributing factor |
| `paste_related` | BOOLEAN | NOT NULL | |
| `placement_related` | BOOLEAN | NOT NULL | |
| `reflow_related` | BOOLEAN | NOT NULL | |
| `board_related` | BOOLEAN | NOT NULL | |
| `frequency_in_industry` | VARCHAR(20) | NOT NULL | rare, occasional, common, very_common |
| `repair_possible` | BOOLEAN | NOT NULL | |
| `repair_difficulty` | VARCHAR(20) | NULL | easy, moderate, difficult, not_recommended |
| `is_latent_failure` | BOOLEAN | NOT NULL | May pass test but fail in field |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_defect_types_code` on `(defect_code)`

---

### TABLE: `failure_mechanisms`

**Purpose:** The physical or chemical mechanism by which a defect occurs. The "physics level" explanation.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `defect_type_id` | UUID | NOT NULL | FK → defect_types |
| `name` | VARCHAR(100) | NOT NULL | |
| `mechanism_type` | VARCHAR(30) | NOT NULL | thermal, chemical, mechanical, metallurgical, geometric |
| `description` | TEXT | NOT NULL | Full engineering description |
| `process_variables_involved` | TEXT[] | NOT NULL | Which process variables drive this |
| `theory_card_id` | UUID | NULL | FK → theory_cards |
| `reference_papers` | TEXT[] | NULL | Academic/industry references |
| `ipc_reference` | VARCHAR(100) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |

---

### TABLE: `root_causes`

**Purpose:** A specific, actionable root cause for a defect type — linked to a process variable and corrective direction.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `defect_type_id` | UUID | NOT NULL | FK → defect_types |
| `name` | VARCHAR(255) | NOT NULL | |
| `root_cause_category` | VARCHAR(30) | NOT NULL | stencil_design, material, process_parameter, equipment, pcb_design, component, environment |
| `description` | TEXT | NOT NULL | Full engineering description |
| `process_variable` | VARCHAR(100) | NOT NULL | Specific variable name |
| `typical_direction` | VARCHAR(30) | NOT NULL | too_high, too_low, out_of_tolerance, missing, wrong_selection |
| `confidence_level` | VARCHAR(30) | NOT NULL | well_established, probable, theoretical |
| `frequency_as_primary` | VARCHAR(20) | NOT NULL | rare, sometimes, often, usually |
| `investigation_method` | TEXT | NULL | How to confirm this root cause |
| `ipc_reference` | VARCHAR(100) | NULL | |
| `effectiveness_score` | NUMERIC(5,4) | NOT NULL | 0.0–1.0, updated by Learning Engine |
| `confirmation_count` | INTEGER | NOT NULL | Times confirmed by investigations |
| `is_active` | BOOLEAN | NOT NULL | |

---

### TABLE: `corrective_actions`

**Purpose:** Specific corrective actions to address a confirmed root cause.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `root_cause_id` | UUID | NOT NULL | FK → root_causes |
| `name` | VARCHAR(255) | NOT NULL | |
| `action_type` | VARCHAR(30) | NOT NULL | immediate_fix, parameter_adjustment, design_change, material_change, process_change |
| `description` | TEXT | NOT NULL | |
| `parameter_to_change` | VARCHAR(100) | NULL | |
| `direction` | VARCHAR(20) | NULL | increase, decrease, replace, eliminate, add |
| `typical_magnitude` | VARCHAR(100) | NULL | e.g., "Increase AR by 0.05–0.10" |
| `expected_improvement` | TEXT | NOT NULL | |
| `implementation_effort` | VARCHAR(20) | NOT NULL | minutes, hours, days, weeks |
| `risk_of_new_defect` | VARCHAR(10) | NOT NULL | none, low, medium, high |
| `new_defect_risk_description` | TEXT | NULL | |
| `validation_method` | TEXT | NULL | |
| `ipc_reference` | VARCHAR(100) | NULL | |
| `effectiveness_score` | NUMERIC(5,4) | NOT NULL | 0.0–1.0, updated by Learning Engine |
| `validation_count` | INTEGER | NOT NULL | Times outcome was measured |
| `is_active` | BOOLEAN | NOT NULL | |

---

### TABLE: `preventive_actions`

**Purpose:** Proactive engineering actions to prevent defects from occurring.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `root_cause_id` | UUID | NOT NULL | FK → root_causes |
| `name` | VARCHAR(255) | NOT NULL | |
| `prevention_category` | VARCHAR(30) | NOT NULL | design_rule, material_selection, process_control, training, inspection |
| `description` | TEXT | NOT NULL | |
| `design_stage` | VARCHAR(30) | NOT NULL | pcb_design, stencil_design, process_setup, production |
| `implementation_cost` | VARCHAR(20) | NOT NULL | negligible, low, medium, high |
| `effectiveness` | VARCHAR(20) | NOT NULL | partial, good, excellent |
| `ipc_reference` | VARCHAR(100) | NULL | |
| `is_active` | BOOLEAN | NOT NULL | |

---

### TABLE: `defect_records`

**Purpose:** An instance of a specific defect found during production, inspection, or field return.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `project_id` | UUID | NOT NULL | FK → projects |
| `stencil_design_id` | UUID | NULL | FK → stencil_designs |
| `defect_type_id` | UUID | NOT NULL | FK → defect_types |
| `discovery_stage` | VARCHAR(30) | NOT NULL | spi, aoi, xray, visual, ict, functional_test, field_return |
| `discovery_date` | TIMESTAMPTZ | NOT NULL | |
| `board_serial_number` | VARCHAR(50) | NULL | |
| `reference_designator` | VARCHAR(20) | NULL | |
| `pad_number` | INTEGER | NULL | |
| `confirmed_root_cause_id` | UUID | NULL | FK → root_causes |
| `quantity_affected` | INTEGER | NOT NULL | |
| `disposition` | VARCHAR(30) | NOT NULL | scrap, rework, use_as_is, under_investigation |
| `is_investigated` | BOOLEAN | NOT NULL | |
| `defect_investigation_id` | UUID | NULL | FK → defect_investigations |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:**
- `idx_defect_records_project_id` on `(project_id)`
- `idx_defect_records_defect_type_id` on `(defect_type_id)`
- `idx_defect_records_stencil_design_id` on `(stencil_design_id)`

---

### TABLE: `defect_investigations`

**Purpose:** A structured engineering investigation capturing 8D/5-Why analysis and linking findings to the knowledge base.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `project_id` | UUID | NOT NULL | FK → projects |
| `lead_engineer_id` | UUID | NOT NULL | FK → engineers |
| `title` | VARCHAR(255) | NOT NULL | |
| `status` | VARCHAR(30) | NOT NULL | open, in_progress, root_cause_identified, closed |
| `problem_statement` | TEXT | NOT NULL | D1 description |
| `containment_actions` | TEXT | NULL | D2 immediate containment |
| `root_cause_analysis_method` | VARCHAR(30) | NOT NULL | five_why, eight_d, ishikawa, fault_tree, doe |
| `five_why_data` | JSONB | NULL | Structured 5-Why analysis |
| `confirmed_root_cause_id` | UUID | NULL | FK → root_causes |
| `corrective_actions_taken` | JSONB | NULL | What was done and when |
| `preventive_actions_planned` | JSONB | NULL | |
| `effectiveness_verification` | TEXT | NULL | D7 verification |
| `lessons_learned` | TEXT | NULL | D8 |
| `yield_before_pct` | NUMERIC(6,3) | NULL | First-pass yield before fix |
| `yield_after_pct` | NUMERIC(6,3) | NULL | First-pass yield after fix |
| `generated_new_rule` | BOOLEAN | NOT NULL | |
| `new_rule_id` | UUID | NULL | FK → engineering_rules |
| `opened_at` | TIMESTAMPTZ | NOT NULL | |
| `closed_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |


---

## 16. Module 12 — Rule Engine

---

### TABLE: `rule_sets`

**Purpose:** A named, versioned collection of EngineeringRules. The deployable unit of the rule engine.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NULL | NULL = system rule set |
| `name` | VARCHAR(255) | NOT NULL | e.g., "IPC-7525B Aperture Rules" |
| `code` | VARCHAR(50) | NOT NULL | Short code |
| `version` | VARCHAR(20) | NOT NULL | Rule set version |
| `description` | TEXT | NULL | |
| `rule_set_type` | VARCHAR(30) | NOT NULL | ipc_standard, industry_practice, custom, customer_specific |
| `is_system_rule_set` | BOOLEAN | NOT NULL | Cannot be deleted |
| `is_active` | BOOLEAN | NOT NULL | |
| `effective_date` | DATE | NULL | |
| `supersedes_rule_set_id` | UUID | NULL | FK → rule_sets |
| `created_by_engineer_id` | UUID | NULL | FK → engineers |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_rule_sets_code_version` on `(code, version)`

---

### TABLE: `engineering_rules`

**Purpose:** A single evaluable engineering rule. The atomic unit of the expert system. One of the most important tables in the entire schema.

**Primary Key:** `id UUID`

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `rule_code` | VARCHAR(50) | NOT NULL | e.g., "IPC7525-001" |
| `version` | VARCHAR(20) | NOT NULL | Rule version |
| `name` | VARCHAR(255) | NOT NULL | |
| `category` | VARCHAR(50) | NOT NULL | aperture_geometry, material_compatibility, paste, thermal, clearance, process, inspection, environmental |
| `ipc_class_scope` | VARCHAR(20) | NOT NULL | all, class_2_and_3, class_3_only |
| `severity` | VARCHAR(20) | NOT NULL | critical, major, minor, advisory |
| `source` | VARCHAR(30) | NOT NULL | ipc_standard, industry_practice, doe_result, customer_requirement, internal |
| `priority` | INTEGER | NOT NULL | 1–100 (lower = higher priority) |
| `parameter_name` | VARCHAR(100) | NULL | Simple rule: which parameter to evaluate |
| `condition_operator` | VARCHAR(30) | NULL | gte, lte, gt, lt, eq, neq, between, not_between, in_list, not_in_list |
| `threshold_value` | NUMERIC(12,6) | NULL | For simple numeric rules |
| `threshold_min` | NUMERIC(12,6) | NULL | For "between" rules |
| `threshold_max` | NUMERIC(12,6) | NULL | For "between" rules |
| `threshold_list` | TEXT[] | NULL | For "in_list" rules |
| `threshold_unit` | VARCHAR(30) | NULL | Unit of threshold |
| `condition_tree` | JSONB | NULL | For complex compound conditions |
| `precondition_tree` | JSONB | NULL | When this rule applies |
| `exception_tree` | JSONB | NULL | When to suppress despite failure |
| `base_confidence_pct` | NUMERIC(6,3) | NOT NULL | 0–100 |
| `confidence_basis` | VARCHAR(30) | NOT NULL | well_established, probable, emerging, theoretical |
| `confidence_modifiers` | JSONB | NULL | Context-based adjustment rules |
| `message_pass` | TEXT | NOT NULL | Template for passing result |
| `message_fail` | TEXT | NOT NULL | Template for failing result |
| `message_warning` | TEXT | NULL | Template for warning result |
| `message_skipped` | TEXT | NULL | Template when skipped |
| `engineering_rationale` | TEXT | NOT NULL | WHY this rule exists |
| `consequence_of_violation` | TEXT | NOT NULL | What goes wrong |
| `ipc_reference` | VARCHAR(100) | NULL | Full IPC citation |
| `is_overridable` | BOOLEAN | NOT NULL | |
| `override_requires_approval` | BOOLEAN | NOT NULL | |
| `override_justification_prompt` | TEXT | NULL | Prompt shown to engineer |
| `related_defect_type_ids` | UUID[] | NOT NULL | Which defects this prevents |
| `related_rule_ids` | UUID[] | NOT NULL | Interacting rules |
| `is_active` | BOOLEAN | NOT NULL | |
| `deprecated_at` | TIMESTAMPTZ | NULL | |
| `superseded_by_rule_id` | UUID | NULL | FK → engineering_rules |
| `created_by` | VARCHAR(20) | NOT NULL | system, engineer |
| `created_by_engineer_id` | UUID | NULL | FK → engineers |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Versioning Note:** When a rule changes, a new row is inserted with incremented version and the old row gets `deprecated_at` set. Rows are never updated in place.

**Indexes:**
- `idx_engineering_rules_rule_code` on `(rule_code)` — for version lookup
- `idx_engineering_rules_category_severity` on `(category, severity)` where `is_active = true`
- `idx_engineering_rules_priority` on `(priority)` where `is_active = true`

---

### TABLE: `rule_conditions`

**Purpose:** Stores individual conditions for complex multi-condition rules, supporting full AND/OR/NOT nesting.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `rule_id` | UUID | NOT NULL | FK → engineering_rules |
| `condition_type` | VARCHAR(20) | NOT NULL | precondition, activation_trigger, exception |
| `parameter_name` | VARCHAR(100) | NOT NULL | Context parameter to evaluate |
| `operator` | VARCHAR(30) | NOT NULL | |
| `value` | TEXT | NULL | Threshold as string |
| `logic_operator` | VARCHAR(5) | NOT NULL | AND, OR |
| `group_id` | INTEGER | NULL | For grouping AND/OR |
| `parent_condition_id` | UUID | NULL | FK → rule_conditions (nesting) |
| `description` | TEXT | NULL | Human explanation |
| `sort_order` | INTEGER | NOT NULL | Evaluation order |

---

### TABLE: `rule_groups`

**Purpose:** Logical groupings of rules that share evaluation characteristics and short-circuit behavior.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(100) | NOT NULL | e.g., "geometry_fundamentals" |
| `code` | VARCHAR(50) | NOT NULL | |
| `description` | TEXT | NULL | |
| `priority_range_min` | INTEGER | NOT NULL | |
| `priority_range_max` | INTEGER | NOT NULL | |
| `short_circuit_on_critical` | BOOLEAN | NOT NULL | |
| `activation_condition` | TEXT | NULL | Context condition that activates this group |
| `sort_order` | INTEGER | NOT NULL | |
| `is_active` | BOOLEAN | NOT NULL | |

---

### TABLE: `rule_set_memberships`

**Purpose:** Junction table mapping rules to rule sets, supporting a rule appearing in multiple sets.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `rule_set_id` | UUID | NOT NULL | FK → rule_sets |
| `rule_id` | UUID | NOT NULL | FK → engineering_rules |
| `rule_group_id` | UUID | NULL | FK → rule_groups |
| `is_active_in_set` | BOOLEAN | NOT NULL | Can disable a rule in this set without deleting |
| `added_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_rule_set_memberships` on `(rule_set_id, rule_id)`

---

### TABLE: `rule_check_runs`

**Purpose:** An immutable historical record of a single rule check execution. Append-only.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `run_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `triggered_by` | VARCHAR(30) | NOT NULL | design_change, manual, spi_import, schedule |
| `rule_set_ids` | UUID[] | NOT NULL | Which rule sets were evaluated |
| `rule_set_version_string` | VARCHAR(100) | NOT NULL | Combined version for reporting |
| `total_rules_evaluated` | INTEGER | NOT NULL | |
| `rules_passed` | INTEGER | NOT NULL | |
| `rules_failed` | INTEGER | NOT NULL | |
| `rules_warned` | INTEGER | NOT NULL | |
| `rules_skipped` | INTEGER | NOT NULL | |
| `overall_status` | VARCHAR(30) | NOT NULL | pass, pass_with_warnings, fail, critical_fail |
| `context_snapshot` | JSONB | NOT NULL | All input parameters at time of run |
| `results_summary` | JSONB | NOT NULL | Aggregated results data |
| `run_duration_ms` | INTEGER | NULL | Execution time |
| `run_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:** `idx_rule_check_runs_stencil_design_id_run_at` on `(stencil_design_id, run_at DESC)`

---

### TABLE: `rule_results`

**Purpose:** The evaluation result of a single EngineeringRule against a single target.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `rule_check_run_id` | UUID | NOT NULL | FK → rule_check_runs |
| `rule_id` | UUID | NOT NULL | FK → engineering_rules |
| `rule_code` | VARCHAR(50) | NOT NULL | Denormalized for query performance |
| `rule_version` | VARCHAR(20) | NOT NULL | Denormalized for audit |
| `target_entity_type` | VARCHAR(50) | NOT NULL | Table name: aperture_designs, stencil_designs |
| `target_entity_id` | UUID | NOT NULL | PK of the evaluated entity |
| `status` | VARCHAR(20) | NOT NULL | pass, fail, warning, skipped, error |
| `evaluated_value` | NUMERIC(16,6) | NULL | Actual value tested |
| `evaluated_value_text` | TEXT | NULL | For non-numeric comparisons |
| `threshold_value` | NUMERIC(16,6) | NULL | Threshold tested against |
| `confidence_pct` | NUMERIC(6,3) | NOT NULL | Final confidence after modifiers |
| `message` | TEXT | NOT NULL | Human-readable result message |
| `is_overridden` | BOOLEAN | NOT NULL | |
| `override_justification` | TEXT | NULL | |
| `override_approved_by_id` | UUID | NULL | FK → engineers |
| `recommendation_id` | UUID | NULL | FK → recommendations |

**Indexes:** `idx_rule_results_rule_check_run_id` on `(rule_check_run_id)`

---

## 17. Module 13 — Engineering Calculations

---

### TABLE: `calculation_templates`

**Purpose:** Defines a reusable engineering calculation — its formula, inputs, outputs, and IPC reference.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `name` | VARCHAR(255) | NOT NULL | |
| `code` | VARCHAR(30) | NOT NULL | e.g., "CALC-AR-RECT" |
| `version` | VARCHAR(20) | NOT NULL | |
| `category` | VARCHAR(50) | NOT NULL | area_ratio, paste_volume, transfer_efficiency, thermal, clearance, via_design, reflow_thermal |
| `description` | TEXT | NOT NULL | |
| `formula_description` | TEXT | NOT NULL | Human-readable formula |
| `formula_latex` | TEXT | NULL | LaTeX representation |
| `formula_source` | VARCHAR(30) | NOT NULL | ipc_standard, academic_paper, industry_practice, internal_doe |
| `ipc_reference_id` | UUID | NULL | FK → ipc_references |
| `paper_reference` | TEXT | NULL | Academic citation |
| `inputs_schema` | JSONB | NOT NULL | [{name, unit, description, min, max, required}] |
| `outputs_schema` | JSONB | NOT NULL | [{name, unit, description, pass_threshold, fail_threshold}] |
| `applicable_shapes` | TEXT[] | NULL | Which aperture shapes |
| `limitations` | TEXT | NULL | Known limitations |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_calculation_templates_code_version` on `(code, version)`

---

### TABLE: `calculation_inputs`

**Purpose:** Validation schema for each input parameter of a calculation template. Enables input validation before calculation execution.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `calculation_template_id` | UUID | NOT NULL | FK → calculation_templates |
| `parameter_name` | VARCHAR(50) | NOT NULL | |
| `display_name` | VARCHAR(100) | NOT NULL | |
| `unit` | VARCHAR(20) | NOT NULL | |
| `data_type` | VARCHAR(20) | NOT NULL | float, integer, string, boolean, enum |
| `min_valid_value` | NUMERIC(16,6) | NULL | Physical lower limit |
| `max_valid_value` | NUMERIC(16,6) | NULL | Physical upper limit |
| `min_warn_value` | NUMERIC(16,6) | NULL | Warning threshold |
| `max_warn_value` | NUMERIC(16,6) | NULL | Warning threshold |
| `is_required` | BOOLEAN | NOT NULL | |
| `default_value` | TEXT | NULL | |
| `enum_values` | TEXT[] | NULL | For enum type |
| `description` | TEXT | NOT NULL | |
| `sort_order` | INTEGER | NOT NULL | |

---

### TABLE: `calculation_results`

**Purpose:** Historical record of every calculation performed. The audit trail of engineering computation.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `calculation_template_id` | UUID | NOT NULL | FK → calculation_templates |
| `calculation_code` | VARCHAR(30) | NOT NULL | Denormalized for query |
| `performed_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `context_entity_type` | VARCHAR(50) | NULL | What entity triggered this |
| `context_entity_id` | UUID | NULL | |
| `input_values` | JSONB | NOT NULL | Actual input values |
| `output_values` | JSONB | NOT NULL | Calculated outputs |
| `pass_fail_status` | VARCHAR(20) | NOT NULL | pass, warning, fail, not_applicable |
| `notes` | TEXT | NULL | |
| `calculated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:**
- `idx_calculation_results_template_id` on `(calculation_template_id)`
- `idx_calculation_results_context` on `(context_entity_type, context_entity_id)`

---

## 18. Module 14 — Recommendation Engine

---

### TABLE: `recommendation_templates`

**Purpose:** Parameterized templates for generating recommendations, keyed by rule_id or defect_type_id.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `trigger_type` | VARCHAR(30) | NOT NULL | rule_failure, defect_risk, advisory, pattern_match |
| `trigger_rule_id` | UUID | NULL | FK → engineering_rules |
| `trigger_defect_type_id` | UUID | NULL | FK → defect_types |
| `title_template` | TEXT | NOT NULL | Jinja2 template string |
| `why_template` | TEXT | NOT NULL | |
| `what_template` | TEXT | NOT NULL | |
| `how_template` | TEXT | NOT NULL | |
| `expected_improvement_template` | TEXT | NOT NULL | |
| `tradeoffs_template` | TEXT | NOT NULL | |
| `related_defect_type_ids` | UUID[] | NOT NULL | |
| `related_ipc_reference_ids` | UUID[] | NOT NULL | |
| `base_confidence_pct` | NUMERIC(6,3) | NOT NULL | |
| `base_priority` | INTEGER | NOT NULL | 1–100 |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `recommendations`

**Purpose:** A generated recommendation — the populated, context-specific output of a recommendation template. Stored for audit and engineer review.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `recommendation_template_id` | UUID | NULL | FK → recommendation_templates |
| `rule_result_id` | UUID | NULL | FK → rule_results (if triggered by rule) |
| `defect_risk_assessment_id` | UUID | NULL | FK → defect_risk_assessments |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `target_aperture_id` | UUID | NULL | FK → aperture_designs (if aperture-specific) |
| `recommendation_type` | VARCHAR(50) | NOT NULL | aperture_optimization, material_selection, process_parameter, defect_prevention, inspection_strategy |
| `trigger_type` | VARCHAR(30) | NOT NULL | rule_failure, defect_risk, advisory, pattern_match |
| `title` | TEXT | NOT NULL | Populated title |
| `why` | TEXT | NOT NULL | |
| `what` | TEXT | NOT NULL | |
| `how` | TEXT | NOT NULL | |
| `expected_improvement` | TEXT | NOT NULL | |
| `tradeoffs` | TEXT | NOT NULL | |
| `severity` | VARCHAR(20) | NOT NULL | critical, major, minor, advisory |
| `priority_score` | NUMERIC(6,4) | NOT NULL | 0.0–1.0 composite score |
| `display_rank` | INTEGER | NOT NULL | Final display order |
| `confidence_pct` | NUMERIC(6,3) | NOT NULL | |
| `yield_impact_estimate_pct` | NUMERIC(6,3) | NULL | Predicted yield improvement |
| `is_system_generated` | BOOLEAN | NOT NULL | |
| `engineer_status` | VARCHAR(20) | NOT NULL | pending, acknowledged, implemented, dismissed, deferred |
| `engineer_feedback` | TEXT | NULL | Engineer's response |
| `outcome_recorded_at` | TIMESTAMPTZ | NULL | When engineer recorded outcome |
| `is_resolved` | BOOLEAN | NOT NULL | |
| `generated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:**
- `idx_recommendations_stencil_design_id` on `(stencil_design_id)`
- `idx_recommendations_priority_score` on `(stencil_design_id, priority_score DESC)`

---

### TABLE: `recommendation_options`

**Purpose:** Multiple resolution options for a single recommendation (Option A, Option B, Option C with comparative analysis).

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `recommendation_id` | UUID | NOT NULL | FK → recommendations |
| `option_label` | VARCHAR(5) | NOT NULL | "A", "B", "C" |
| `title` | VARCHAR(255) | NOT NULL | |
| `description` | TEXT | NOT NULL | |
| `parameter_changes` | JSONB | NOT NULL | What specifically changes |
| `predicted_new_value` | NUMERIC(12,6) | NULL | Predicted metric after change |
| `predicted_improvement_pct` | NUMERIC(6,3) | NULL | |
| `confidence_pct` | NUMERIC(6,3) | NOT NULL | |
| `risk_introduced` | TEXT | NULL | New risks from this option |
| `cost_impact` | VARCHAR(20) | NULL | negligible, low, medium, high |
| `effort_to_implement` | VARCHAR(20) | NOT NULL | minutes, hours, days, weeks |
| `is_preferred` | BOOLEAN | NOT NULL | Is this the recommended option? |
| `engineer_selected` | BOOLEAN | NOT NULL | Did engineer choose this option? |
| `sort_order` | INTEGER | NOT NULL | |

---

### TABLE: `recommendation_conflicts`

**Purpose:** Records detected conflicts between recommendations and their resolution.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `recommendation_a_id` | UUID | NOT NULL | FK → recommendations |
| `recommendation_b_id` | UUID | NOT NULL | FK → recommendations |
| `conflict_type` | VARCHAR(30) | NOT NULL | directional, resource, material, spatial, severity |
| `description` | TEXT | NOT NULL | What conflict was detected |
| `resolution_strategy` | VARCHAR(30) | NOT NULL | pareto_optimal, step_stencil, priority_hierarchy, geometry_reshape, escalated |
| `resolution_description` | TEXT | NULL | How it was resolved |
| `is_resolved` | BOOLEAN | NOT NULL | |
| `resolved_recommendation_id` | UUID | NULL | FK → recommendations (composite resolution) |
| `requires_engineer_decision` | BOOLEAN | NOT NULL | |
| `detected_at` | TIMESTAMPTZ | NOT NULL | |

---

## 19. Module 15 — Intelligence & Scoring

---

### TABLE: `design_score_cards`

**Purpose:** The complete multi-dimensional score card for a stencil design evaluation run.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `rule_check_run_id` | UUID | NOT NULL | FK → rule_check_runs |
| `overall_score` | NUMERIC(5,2) | NOT NULL | 0–100 |
| `overall_grade` | VARCHAR(5) | NOT NULL | A+, A, B+, B, C+, C, D, D-, F |
| `stencil_score` | NUMERIC(5,2) | NOT NULL | |
| `manufacturability_score` | NUMERIC(5,2) | NOT NULL | |
| `paste_compatibility_score` | NUMERIC(5,2) | NOT NULL | |
| `inspection_coverage_score` | NUMERIC(5,2) | NOT NULL | |
| `ipc_compliance_score` | NUMERIC(5,2) | NOT NULL | |
| `score_components` | JSONB | NOT NULL | Full breakdown of sub-scores with weights |
| `score_drivers` | JSONB | NOT NULL | What drove each score (positive and negative) |
| `previous_overall_score` | NUMERIC(5,2) | NULL | Previous run score for delta |
| `score_delta` | NUMERIC(6,2) | NULL | Change from previous run |
| `generated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:** `idx_design_score_cards_stencil_design_id_generated_at` on `(stencil_design_id, generated_at DESC)`

---

### TABLE: `defect_risk_assessments`

**Purpose:** The computed defect risk scores for all 12 defect types for a given design evaluation.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `rule_check_run_id` | UUID | NOT NULL | FK → rule_check_runs |
| `defect_type_id` | UUID | NOT NULL | FK → defect_types |
| `risk_score` | NUMERIC(5,4) | NOT NULL | 0.0000–1.0000 |
| `risk_band` | VARCHAR(20) | NOT NULL | negligible, low, moderate, high, critical |
| `primary_risk_driver` | VARCHAR(100) | NOT NULL | Which factor drives this risk |
| `secondary_risk_driver` | VARCHAR(100) | NULL | |
| `risk_factor_breakdown` | JSONB | NOT NULL | Per-factor weights and values |
| `confidence_pct` | NUMERIC(6,3) | NOT NULL | |
| `compound_risk_score` | NUMERIC(5,4) | NULL | Combined risk with interacting defects |
| `compound_interaction_ids` | UUID[] | NULL | Other defect_risk_assessment IDs involved |
| `ipc_class_implication` | TEXT | NULL | What this risk means for IPC class |
| `assessed_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `yield_predictions`

**Purpose:** The statistical first-pass yield forecast for a stencil design.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `stencil_design_id` | UUID | NOT NULL | FK → stencil_designs |
| `rule_check_run_id` | UUID | NOT NULL | FK → rule_check_runs |
| `predicted_fpy_pct` | NUMERIC(6,3) | NOT NULL | Point estimate |
| `confidence_lower_pct` | NUMERIC(6,3) | NOT NULL | 90% CI lower bound |
| `confidence_upper_pct` | NUMERIC(6,3) | NOT NULL | 90% CI upper bound |
| `confidence_interval_level` | NUMERIC(5,3) | NOT NULL | 0.90 = 90% CI |
| `dominant_yield_killer_defect_id` | UUID | NULL | FK → defect_types |
| `dominant_yield_killer_contribution_pct` | NUMERIC(6,3) | NULL | |
| `yield_by_defect_type` | JSONB | NOT NULL | Per-defect yield impact |
| `yield_if_recommendations_implemented_pct` | NUMERIC(6,3) | NULL | |
| `uncertainty_sources` | JSONB | NOT NULL | What makes this uncertain |
| `historical_data_used` | BOOLEAN | NOT NULL | Was org history used? |
| `similar_designs_found` | INTEGER | NOT NULL | How many comparable designs |
| `predicted_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `process_context_snapshots`

**Purpose:** The complete ProcessContext assembled for a rule check run. Enables full reproducibility of any past analysis.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `rule_check_run_id` | UUID | NOT NULL | FK → rule_check_runs |
| `context_completeness_pct` | NUMERIC(6,3) | NOT NULL | |
| `geometry_context` | JSONB | NOT NULL | Aperture and pad geometry |
| `stencil_context` | JSONB | NOT NULL | Material, thickness, coating |
| `paste_context` | JSONB | NOT NULL | Paste properties |
| `package_context` | JSONB | NOT NULL | Package characteristics |
| `pcb_context` | JSONB | NOT NULL | Board properties |
| `process_context` | JSONB | NOT NULL | Print, placement, reflow parameters |
| `historical_context` | JSONB | NOT NULL | Organization's history |
| `missing_fields` | TEXT[] | NOT NULL | What was absent from context |
| `captured_at` | TIMESTAMPTZ | NOT NULL | |

---

## 20. Module 16 — Learning System

---

### TABLE: `learning_events`

**Purpose:** Records every outcome that the Learning System uses to update confidence scores and pattern records.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `event_type` | VARCHAR(50) | NOT NULL | corrective_action_outcome, rule_override_outcome, experiment_conclusion, spi_correlation |
| `source_entity_type` | VARCHAR(50) | NOT NULL | Table name of the source |
| `source_entity_id` | UUID | NOT NULL | FK to source record |
| `outcome` | VARCHAR(30) | NOT NULL | confirms_rule, contradicts_rule, inconclusive, partial |
| `evidence_strength` | VARCHAR(20) | NOT NULL | controlled_experiment, production_validation, production_observation, single_event |
| `evidence_strength_numeric` | NUMERIC(4,2) | NOT NULL | 0.20–1.00 |
| `confidence_delta_applied` | NUMERIC(6,4) | NULL | How much confidence changed |
| `target_entity_type` | VARCHAR(50) | NOT NULL | What was updated (rule, root_cause, corrective_action) |
| `target_entity_id` | UUID | NOT NULL | |
| `context_snapshot` | JSONB | NOT NULL | Context at time of learning event |
| `processed` | BOOLEAN | NOT NULL | Has Learning Engine processed this? |
| `processed_at` | TIMESTAMPTZ | NULL | |
| `notes` | TEXT | NULL | |
| `occurred_at` | TIMESTAMPTZ | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:** `idx_learning_events_target` on `(target_entity_type, target_entity_id)`

---

### TABLE: `pattern_records`

**Purpose:** Accumulated organizational patterns — "situations like X have led to outcomes like Y."

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `context_signature` | VARCHAR(64) | NOT NULL | SHA-256 hash of key context parameters |
| `context_key_params` | JSONB | NOT NULL | The key parameters that define this pattern |
| `defect_type_id` | UUID | NOT NULL | FK → defect_types |
| `occurrence_count` | INTEGER | NOT NULL | Times this context was seen |
| `defect_confirmed_count` | INTEGER | NOT NULL | Times defect actually occurred |
| `defect_prevented_count` | INTEGER | NOT NULL | Times recommendation followed + no defect |
| `defect_rate` | NUMERIC(6,5) | NOT NULL | defect_confirmed / occurrence_count |
| `first_seen_at` | TIMESTAMPTZ | NOT NULL | |
| `last_seen_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_pattern_records_org_signature_defect` on `(organization_id, context_signature, defect_type_id)`

---

### TABLE: `confidence_adjustments`

**Purpose:** Immutable log of every confidence score change made by the Learning Engine. Audit trail.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `learning_event_id` | UUID | NOT NULL | FK → learning_events |
| `target_entity_type` | VARCHAR(50) | NOT NULL | |
| `target_entity_id` | UUID | NOT NULL | |
| `target_field` | VARCHAR(50) | NOT NULL | e.g., "base_confidence_pct", "effectiveness_score" |
| `previous_value` | NUMERIC(8,4) | NOT NULL | |
| `adjustment_delta` | NUMERIC(8,4) | NOT NULL | |
| `new_value` | NUMERIC(8,4) | NOT NULL | |
| `reason` | TEXT | NOT NULL | |
| `adjusted_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `knowledge_review_flags`

**Purpose:** Flags raised by the Learning System when patterns conflict, confidence decays, or rules need review.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `flag_type` | VARCHAR(50) | NOT NULL | confidence_decay, pattern_conflict, override_pattern, rule_needs_update |
| `severity` | VARCHAR(20) | NOT NULL | info, warning, action_required |
| `title` | VARCHAR(255) | NOT NULL | |
| `description` | TEXT | NOT NULL | |
| `related_entity_type` | VARCHAR(50) | NULL | |
| `related_entity_id` | UUID | NULL | |
| `is_resolved` | BOOLEAN | NOT NULL | |
| `resolved_by_engineer_id` | UUID | NULL | FK → engineers |
| `resolved_at` | TIMESTAMPTZ | NULL | |
| `resolution_notes` | TEXT | NULL | |
| `raised_at` | TIMESTAMPTZ | NOT NULL | |

---

## 21. Module 17 — Knowledge Base

---

### TABLE: `ipc_standards`

**Purpose:** Master reference for IPC standards used throughout the system.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `standard_number` | VARCHAR(20) | NOT NULL | e.g., "IPC-7525", "IPC-A-610", "J-STD-001" |
| `standard_title` | VARCHAR(255) | NOT NULL | Full standard title |
| `current_revision` | VARCHAR(10) | NOT NULL | e.g., "B", "G", "H" |
| `publication_year` | INTEGER | NOT NULL | |
| `scope` | TEXT | NULL | What this standard covers |
| `is_active_standard` | BOOLEAN | NOT NULL | Not superseded |
| `superseded_by_standard_id` | UUID | NULL | FK → ipc_standards |
| `is_system_record` | BOOLEAN | NOT NULL | |

**Unique Constraints:** `uq_ipc_standards_number_revision` on `(standard_number, current_revision)`

---

### TABLE: `ipc_references`

**Purpose:** Specific section-level references within IPC standards. Linked to rules, recommendations, and calculations.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `ipc_standard_id` | UUID | NOT NULL | FK → ipc_standards |
| `section_number` | VARCHAR(30) | NOT NULL | e.g., "4.2.3" |
| `section_title` | VARCHAR(255) | NOT NULL | |
| `summary` | TEXT | NOT NULL | Plain-language summary |
| `applicability` | TEXT | NULL | When this applies |
| `ipc_class_1_text` | TEXT | NULL | Class 1 requirement |
| `ipc_class_2_text` | TEXT | NULL | Class 2 requirement |
| `ipc_class_3_text` | TEXT | NULL | Class 3 requirement |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |

---

### TABLE: `case_studies`

**Purpose:** Documented engineering case studies capturing real problem-solution-lesson narratives. The institutional knowledge vault.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `authored_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `defect_investigation_id` | UUID | NULL | FK → defect_investigations (source) |
| `title` | VARCHAR(255) | NOT NULL | |
| `abstract` | TEXT | NOT NULL | 2–3 sentence summary |
| `problem_description` | TEXT | NOT NULL | |
| `assembly_context` | TEXT | NULL | PCB and assembly characteristics |
| `defect_type_ids` | UUID[] | NOT NULL | |
| `investigation_approach` | TEXT | NOT NULL | |
| `root_causes_identified` | TEXT | NOT NULL | |
| `solution_implemented` | TEXT | NOT NULL | |
| `results_achieved` | TEXT | NOT NULL | Quantified improvement |
| `lessons_learned` | TEXT | NOT NULL | |
| `applicable_package_family_ids` | UUID[] | NOT NULL | |
| `tags` | TEXT[] | NOT NULL | |
| `is_published` | BOOLEAN | NOT NULL | Available to all org engineers |
| `view_count` | INTEGER | NOT NULL | |
| `helpful_votes` | INTEGER | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Full-Text Search:** GIN index on `to_tsvector('english', title || ' ' || abstract || ' ' || lessons_learned)`

---

### TABLE: `experiments`

**Purpose:** Structured record of controlled engineering experiments and DOE studies.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `project_id` | UUID | NOT NULL | FK → projects |
| `led_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `title` | VARCHAR(255) | NOT NULL | |
| `hypothesis` | TEXT | NOT NULL | |
| `experiment_type` | VARCHAR(30) | NOT NULL | doe, characterization, comparison, validation, screening |
| `variables_tested` | JSONB | NOT NULL | Independent variables and levels |
| `response_variables` | JSONB | NOT NULL | What was measured |
| `pcb_revision_id` | UUID | NULL | FK → pcb_revisions |
| `stencil_material_id` | UUID | NULL | FK → stencil_materials |
| `paste_id` | UUID | NULL | FK → solder_pastes |
| `number_of_runs` | INTEGER | NULL | |
| `number_of_replicates` | INTEGER | NULL | |
| `results_summary` | TEXT | NULL | |
| `statistical_analysis` | JSONB | NULL | DOE analysis results |
| `conclusions` | TEXT | NULL | |
| `confidence_level` | VARCHAR(20) | NULL | preliminary, moderate, high, very_high |
| `generates_rule` | BOOLEAN | NOT NULL | |
| `new_rule_id` | UUID | NULL | FK → engineering_rules |
| `data_file_storage_path` | TEXT | NULL | |
| `status` | VARCHAR(20) | NOT NULL | planned, in_progress, completed, cancelled |
| `started_at` | DATE | NULL | |
| `completed_at` | DATE | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `theory_cards`

**Purpose:** Reusable engineering theory explanations attached to rules, recommendations, and the IPC Knowledge Base.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `code` | VARCHAR(20) | NOT NULL | e.g., "TC-001" |
| `title` | VARCHAR(255) | NOT NULL | |
| `category` | VARCHAR(50) | NOT NULL | |
| `summary_text` | TEXT | NOT NULL | Level 1 explanation |
| `engineering_detail_text` | TEXT | NOT NULL | Level 2 explanation |
| `knowledge_depth_text` | TEXT | NULL | Level 3 full treatise |
| `formula_latex` | TEXT | NULL | Mathematical formula |
| `related_ipc_reference_ids` | UUID[] | NOT NULL | |
| `tags` | TEXT[] | NOT NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `is_system_record` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_theory_cards_code` on `(code)`

---

## 22. Module 18 — Images & Media

---

### TABLE: `image_records`

**Purpose:** Master record for every image stored in the system. Carries full engineering metadata.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `uploaded_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `image_type` | VARCHAR(30) | NOT NULL | spi, aoi, xray, cross_section, microscope, package_drawing, stencil_aperture, defect_evidence, reference, experiment |
| `subject_type` | VARCHAR(30) | NOT NULL | defect, package, aperture, stencil, board, paste_deposit, solder_joint, equipment, other |
| `title` | VARCHAR(255) | NOT NULL | |
| `description` | TEXT | NULL | |
| `original_filename` | VARCHAR(255) | NOT NULL | |
| `storage_path` | TEXT | NOT NULL | Full Supabase Storage path |
| `thumbnail_storage_path` | TEXT | NULL | |
| `storage_bucket` | VARCHAR(100) | NOT NULL | Bucket name |
| `file_format` | VARCHAR(10) | NOT NULL | png, jpeg, tiff, bmp, svg |
| `file_size_bytes` | BIGINT | NOT NULL | |
| `image_width_px` | INTEGER | NULL | |
| `image_height_px` | INTEGER | NULL | |
| `magnification` | NUMERIC(10,2) | NULL | e.g., 40.0 = 40× |
| `scale_bar_um` | NUMERIC(10,2) | NULL | Scale bar in micrometers |
| `capture_equipment` | VARCHAR(100) | NULL | |
| `capture_date` | TIMESTAMPTZ | NULL | |
| `linked_entity_type` | VARCHAR(50) | NULL | Table name of linked entity |
| `linked_entity_id` | UUID | NULL | |
| `quality_rating` | VARCHAR(15) | NULL | poor, acceptable, good, excellent |
| `is_public_reference` | BOOLEAN | NOT NULL | |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:**
- `idx_image_records_organization_id` on `(organization_id)`
- `idx_image_records_linked_entity` on `(linked_entity_type, linked_entity_id)`
- `idx_image_records_image_type` on `(image_type)` where `is_deleted = false`

**Note:** Binary image data is stored in Supabase Storage, NEVER in PostgreSQL.

---

### TABLE: `image_annotations`

**Purpose:** Non-destructive, data-stored annotations on images.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `image_record_id` | UUID | NOT NULL | FK → image_records |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `annotation_type` | VARCHAR(20) | NOT NULL | region, arrow, text, measurement, circle |
| `x_pct` | NUMERIC(8,4) | NOT NULL | X as % of image width |
| `y_pct` | NUMERIC(8,4) | NOT NULL | Y as % of image height |
| `width_pct` | NUMERIC(8,4) | NULL | For region annotations |
| `height_pct` | NUMERIC(8,4) | NULL | |
| `label` | VARCHAR(100) | NULL | |
| `description` | TEXT | NULL | |
| `color_hex` | VARCHAR(7) | NOT NULL | e.g., "#FF3300" |
| `measurement_value` | NUMERIC(12,4) | NULL | For measurement annotations |
| `measurement_unit` | VARCHAR(10) | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `image_tags`

**Purpose:** Normalized tag management for images.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `image_record_id` | UUID | NOT NULL | FK → image_records |
| `tag` | VARCHAR(50) | NOT NULL | |
| `tagged_at` | TIMESTAMPTZ | NOT NULL | |
| `tagged_by_engineer_id` | UUID | NOT NULL | FK → engineers |

**Unique Constraints:** `uq_image_tags_image_tag` on `(image_record_id, tag)`

---

## 23. Module 19 — Reports & Documents

---

### TABLE: `report_templates`

**Purpose:** Defines a report type — its structure, required data, and Jinja2 template reference.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NULL | NULL = system template |
| `name` | VARCHAR(255) | NOT NULL | |
| `report_type` | VARCHAR(50) | NOT NULL | stencil_design, area_ratio_analysis, defect_investigation, project_summary, experiment_results, case_study, paste_volume |
| `output_format` | VARCHAR(10) | NOT NULL | pdf, xlsx, pdf_xlsx |
| `template_storage_path` | TEXT | NOT NULL | Jinja2 template path in storage |
| `required_entities` | TEXT[] | NOT NULL | Entity types that must be populated |
| `sections_definition` | JSONB | NOT NULL | Report section structure |
| `is_system_template` | BOOLEAN | NOT NULL | |
| `is_active` | BOOLEAN | NOT NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `generated_reports`

**Purpose:** Immutable historical record of every generated report.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `report_template_id` | UUID | NOT NULL | FK → report_templates |
| `project_id` | UUID | NOT NULL | FK → projects |
| `generated_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `report_number` | VARCHAR(50) | NOT NULL | Auto-generated |
| `title` | VARCHAR(255) | NOT NULL | |
| `description` | TEXT | NULL | |
| `linked_entity_type` | VARCHAR(50) | NULL | What entity this covers |
| `linked_entity_id` | UUID | NULL | |
| `app_version` | VARCHAR(20) | NOT NULL | App version at generation |
| `rule_set_version` | VARCHAR(50) | NULL | Rule set version used |
| `report_storage_path` | TEXT | NOT NULL | Generated file in storage |
| `report_format` | VARCHAR(10) | NOT NULL | pdf, xlsx |
| `file_size_bytes` | BIGINT | NULL | |
| `is_signed` | BOOLEAN | NOT NULL | |
| `signed_by_engineer_id` | UUID | NULL | FK → engineers |
| `signed_at` | TIMESTAMPTZ | NULL | |
| `generated_at` | TIMESTAMPTZ | NOT NULL | Immutable |

---

### TABLE: `engineering_notes`

**Purpose:** Free-form engineering notes attachable to any entity. General-purpose annotation store.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `entity_type` | VARCHAR(50) | NOT NULL | Which table this note is about |
| `entity_id` | UUID | NOT NULL | PK of referenced record |
| `title` | VARCHAR(255) | NULL | |
| `content` | TEXT | NOT NULL | |
| `is_pinned` | BOOLEAN | NOT NULL | Show prominently |
| `created_at` | TIMESTAMPTZ | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Indexes:** `idx_engineering_notes_entity` on `(entity_type, entity_id)`

---

### TABLE: `document_attachments`

**Purpose:** File attachments linked to any entity (datasheets, test reports, customer specifications).

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `uploaded_by_engineer_id` | UUID | NOT NULL | FK → engineers |
| `entity_type` | VARCHAR(50) | NOT NULL | Which entity this belongs to |
| `entity_id` | UUID | NOT NULL | |
| `filename` | VARCHAR(255) | NOT NULL | |
| `document_type` | VARCHAR(50) | NULL | datasheet, test_report, customer_spec, photo, cad_file, other |
| `storage_path` | TEXT | NOT NULL | |
| `file_size_bytes` | BIGINT | NOT NULL | |
| `mime_type` | VARCHAR(100) | NOT NULL | |
| `description` | TEXT | NULL | |
| `is_deleted` | BOOLEAN | NOT NULL | |
| `deleted_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

---

## 24. Module 20 — Audit, Activity & Notifications

---

### TABLE: `audit_log`

**Purpose:** Immutable record of every significant data mutation in the system. Security and compliance requirement.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | BIGSERIAL | NOT NULL | Sequence-based PK for ordering |
| `organization_id` | UUID | NULL | NULL for system-level events |
| `engineer_id` | UUID | NULL | NULL for system actions |
| `action` | VARCHAR(20) | NOT NULL | INSERT, UPDATE, DELETE |
| `table_name` | VARCHAR(100) | NOT NULL | |
| `record_id` | UUID | NOT NULL | PK of affected record |
| `old_values` | JSONB | NULL | Previous values (for UPDATE/DELETE) |
| `new_values` | JSONB | NULL | New values (for INSERT/UPDATE) |
| `changed_fields` | TEXT[] | NULL | Which fields changed |
| `ip_address` | INET | NULL | Client IP |
| `session_id` | UUID | NULL | FK → engineer_sessions |
| `occurred_at` | TIMESTAMPTZ | NOT NULL | |

**Partitioning:** Partition by `occurred_at` — monthly partitions. This table grows continuously.

**Indexes:**
- `idx_audit_log_organization_id_occurred_at` on `(organization_id, occurred_at DESC)`
- `idx_audit_log_table_record` on `(table_name, record_id)`

**Archive Strategy:** Partitions older than 7 years are archived to cold storage. Never physically deleted.

---

### TABLE: `activity_log`

**Purpose:** User activity tracking for usage analytics and engineer contribution metrics.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | BIGSERIAL | NOT NULL | Sequence PK |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `activity_type` | VARCHAR(50) | NOT NULL | login, view_project, run_rule_check, create_stencil, generate_report, etc. |
| `entity_type` | VARCHAR(50) | NULL | |
| `entity_id` | UUID | NULL | |
| `metadata` | JSONB | NULL | Activity-specific context |
| `occurred_at` | TIMESTAMPTZ | NOT NULL | |

**Partitioning:** Monthly partitions.

---

### TABLE: `notifications`

**Purpose:** In-app notifications for engineers about relevant events on their projects and designs.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `recipient_engineer_id` | UUID | NOT NULL | FK → engineers |
| `notification_type` | VARCHAR(50) | NOT NULL | rule_check_complete, design_approved, defect_assigned, review_requested, knowledge_flag |
| `title` | VARCHAR(255) | NOT NULL | |
| `content` | TEXT | NOT NULL | |
| `entity_type` | VARCHAR(50) | NULL | Related entity |
| `entity_id` | UUID | NULL | |
| `is_read` | BOOLEAN | NOT NULL | |
| `read_at` | TIMESTAMPTZ | NULL | |
| `expires_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `notification_preferences`

**Purpose:** Per-engineer preferences for which notification types to receive and via which channels.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `notification_type` | VARCHAR(50) | NOT NULL | |
| `in_app_enabled` | BOOLEAN | NOT NULL | |
| `email_enabled` | BOOLEAN | NOT NULL | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_notification_preferences_engineer_type` on `(engineer_id, notification_type)`

---

## 25. Module 21 — Application Settings

---

### TABLE: `app_settings`

**Purpose:** Global application configuration values managed by super-administrators.

*(Defined in Module 01 as `application_config` — this is an alias view for UX purposes)*

---

### TABLE: `user_preferences`

**Purpose:** Per-engineer application preferences for UI behavior, defaults, and personalization.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `preference_key` | VARCHAR(100) | NOT NULL | |
| `preference_value` | TEXT | NULL | |
| `preference_type` | VARCHAR(20) | NOT NULL | string, boolean, integer, json |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_user_preferences_engineer_key` on `(engineer_id, preference_key)`

---

### TABLE: `feature_flags`

**Purpose:** Feature toggle system for progressive feature rollout.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `flag_key` | VARCHAR(100) | NOT NULL | e.g., "ai_assistant_enabled" |
| `description` | TEXT | NOT NULL | |
| `is_enabled_globally` | BOOLEAN | NOT NULL | Default for all orgs |
| `enabled_for_org_ids` | UUID[] | NOT NULL | Specific org overrides |
| `enabled_for_tiers` | TEXT[] | NOT NULL | Subscription tiers that get this |
| `rollout_percentage` | INTEGER | NULL | 0–100 for gradual rollout |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

**Unique Constraints:** `uq_feature_flags_key` on `(flag_key)`

---

## 26. Module 22 — Future AI Layer

---

### TABLE: `ai_feedback_records`

**Purpose:** Captures engineer feedback on AI Assistant responses, used to fine-tune future outputs.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `conversation_log_id` | UUID | NOT NULL | FK → ai_conversation_logs |
| `response_index` | INTEGER | NOT NULL | Which response in the conversation |
| `feedback_type` | VARCHAR(20) | NOT NULL | helpful, not_helpful, incorrect, missing_context |
| `feedback_notes` | TEXT | NULL | Engineer's free-form feedback |
| `correct_answer` | TEXT | NULL | If engineer provided correction |
| `related_entity_type` | VARCHAR(50) | NULL | |
| `related_entity_id` | UUID | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

---

### TABLE: `ai_conversation_logs`

**Purpose:** Stores AI assistant conversation history for context continuity and audit.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `organization_id` | UUID | NOT NULL | FK → organizations |
| `engineer_id` | UUID | NOT NULL | FK → engineers |
| `session_id` | UUID | NOT NULL | Conversation session |
| `context_entity_type` | VARCHAR(50) | NULL | What design was being worked on |
| `context_entity_id` | UUID | NULL | |
| `messages` | JSONB | NOT NULL | Full conversation [{role, content, timestamp}] |
| `model_version_id` | UUID | NULL | FK → ai_model_versions |
| `total_input_tokens` | INTEGER | NULL | |
| `total_output_tokens` | INTEGER | NULL | |
| `started_at` | TIMESTAMPTZ | NOT NULL | |
| `ended_at` | TIMESTAMPTZ | NULL | |
| `created_at` | TIMESTAMPTZ | NOT NULL | |

**Data Retention:** AI conversation logs are retained for 90 days by default (configurable). PII minimization applies.

---

### TABLE: `ai_model_versions`

**Purpose:** Tracks which AI model versions have been used, enabling reproducibility and audit.

**Columns:**

| Column | Type | Nullable | Description |
|---|---|---|---|
| `id` | UUID | NOT NULL | Primary key |
| `model_provider` | VARCHAR(50) | NOT NULL | e.g., "anthropic" |
| `model_name` | VARCHAR(100) | NOT NULL | e.g., "claude-sonnet-4-6" |
| `model_version` | VARCHAR(50) | NOT NULL | |
| `capabilities` | JSONB | NULL | What this model can do |
| `deployed_at` | TIMESTAMPTZ | NOT NULL | When StencilPro started using it |
| `deprecated_at` | TIMESTAMPTZ | NULL | |
| `is_current` | BOOLEAN | NOT NULL | |


---

## 27. Cross-Cutting Concerns

### 27.1 Standard Column Set (Applied to All Major Tables)

Every table that carries organizational data includes this baseline column set. Deviations are explicitly documented per table.

```
MANDATORY COLUMNS — ORGANIZATIONAL DATA TABLES
───────────────────────────────────────────────
id              UUID        NOT NULL    PRIMARY KEY
organization_id UUID        NOT NULL    FK → organizations
created_at      TIMESTAMPTZ NOT NULL    DEFAULT now()
updated_at      TIMESTAMPTZ NOT NULL    DEFAULT now()

MANDATORY COLUMNS — SOFT-DELETABLE TABLES
──────────────────────────────────────────
is_deleted      BOOLEAN     NOT NULL    DEFAULT false
deleted_at      TIMESTAMPTZ NULL

MANDATORY COLUMNS — SYSTEM/REFERENCE TABLES
────────────────────────────────────────────
is_active       BOOLEAN     NOT NULL    DEFAULT true
is_system_record BOOLEAN    NOT NULL    DEFAULT false
  (is_system_record = true → cannot be edited or deleted by engineers)
```

### 27.2 Polymorphic Relationships

Several tables use `(entity_type, entity_id)` pairs to link to any entity:

| Table | Polymorphic Columns | Usage |
|---|---|---|
| `engineering_notes` | `entity_type`, `entity_id` | Notes on any entity |
| `document_attachments` | `entity_type`, `entity_id` | Files on any entity |
| `image_records` | `linked_entity_type`, `linked_entity_id` | Images of any entity |
| `project_notes` | `linked_entity_type`, `linked_entity_id` | Notes referring to any entity |
| `audit_log` | `table_name`, `record_id` | Audit of any table |
| `activity_log` | `entity_type`, `entity_id` | Activity on any entity |
| `notifications` | `entity_type`, `entity_id` | Notification about any entity |
| `learning_events` | `source_entity_type/id`, `target_entity_type/id` | Learning from/to any entity |

**Convention:** `entity_type` stores the exact PostgreSQL table name as a string (e.g., `'stencil_designs'`, `'aperture_designs'`). Application-level validation ensures only valid table names are stored.

### 27.3 Timestamp Automation

All `created_at` and `updated_at` columns are managed by PostgreSQL triggers:

```
TRIGGER PATTERN (applied to every table with updated_at):
  BEFORE UPDATE: SET updated_at = now()
  BEFORE INSERT: SET created_at = now(), updated_at = now()

APPEND-ONLY TABLES (no updated_at trigger):
  project_notes, stencil_revisions, rule_check_runs, audit_log,
  activity_log, confidence_adjustments, learning_events
```

### 27.4 Row-Level Security (RLS) Pattern

Supabase Row-Level Security enforces multi-tenancy at the database layer. The pattern is consistent across all organizational data tables:

```
RLS POLICY PATTERN — SELECT:
  organization_id = auth.jwt() → 'organization_id'

RLS POLICY PATTERN — INSERT:
  organization_id = auth.jwt() → 'organization_id'
  AND engineer has required permission for this table

RLS POLICY PATTERN — UPDATE:
  organization_id = auth.jwt() → 'organization_id'
  AND engineer has required permission
  AND record is not locked/immutable

RLS POLICY PATTERN — DELETE:
  DENIED for most tables (soft delete via UPDATE is_deleted = true)
  PERMITTED only for: user_preferences, notification_preferences,
                      engineer_sessions (own session only)

APPEND-ONLY TABLE POLICY (project_notes, audit_log, etc.):
  SELECT: permitted per organization
  INSERT: permitted per organization and permission
  UPDATE: DENIED — enforced by RLS regardless of role
  DELETE: DENIED — enforced by RLS regardless of role

SYSTEM RECORDS POLICY:
  is_system_record = true records are readable by all authenticated users
  but cannot be modified by any engineer role
```

### 27.5 Computed / Derived Column Strategy

Calculated fields that appear in tables (e.g., `area_ratio`, `aperture_area_mm2`, `overall_design_score`) follow this policy:

| Field Type | Strategy | Rationale |
|---|---|---|
| Real-time geometry (AR, aspect ratio) | Stored in DB, recalculated on change | Fast read performance; history preserved |
| Score fields on `stencil_designs` | Stored, updated by Intelligence Engine | Enables sorting/filtering without recalculation |
| Aggregate counts (`aperture_count`) | Maintained by trigger on child table | Always current; cheap to read |
| Snapshot JSONB fields | Written once at snapshot time, never updated | Immutable history |
| `pattern_records.defect_rate` | Computed column or trigger-maintained | Cross-record calculation |

---

## 28. Performance Strategy

### 28.1 Indexing Strategy

**Primary Index Patterns:**

```
PATTERN 1 — Foreign Key Indexes (every FK column gets an index)
  Rationale: All FK columns are JOIN targets; PostgreSQL does not
             auto-index FK columns.
  Naming: idx_{table}_{fk_column}

PATTERN 2 — Filter Indexes (columns used in WHERE clauses)
  idx_stencil_designs_status on (status) WHERE is_deleted = false
  idx_engineering_rules_category_severity on (category, severity)
             WHERE is_active = true
  idx_aperture_designs_rule_check_status on (stencil_design_id, rule_check_status)

PATTERN 3 — Sort Indexes (columns used in ORDER BY)
  idx_project_notes_project_id_created_at on (project_id, created_at DESC)
  idx_rule_check_runs_stencil_design_id_run_at on (stencil_design_id, run_at DESC)

PATTERN 4 — Composite Lookup Indexes (multi-column WHERE)
  idx_defect_records_project_type on (project_id, defect_type_id)
  idx_pattern_records_org_signature on (organization_id, context_signature)

PATTERN 5 — Full-Text Search Indexes (GIN)
  smt_packages: GIN on to_tsvector('english', ipc_name || ' ' || common_name)
  case_studies: GIN on to_tsvector('english', title || ' ' || abstract || ' ' || lessons_learned)
  defect_types: GIN on to_tsvector('english', name || ' ' || visual_description)
  theory_cards: GIN on to_tsvector('english', title || ' ' || summary_text)

PATTERN 6 — JSONB Indexes (GIN on frequently queried JSONB)
  engineering_rules.condition_tree: GIN index for rule lookup
  process_context_snapshots.geometry_context: GIN (if queried frequently)
```

### 28.2 Partitioning Strategy

High-volume tables are partitioned to maintain query performance as data grows:

| Table | Partition Strategy | Partition Key | Retention |
|---|---|---|---|
| `audit_log` | Range by month | `occurred_at` | 7 years |
| `activity_log` | Range by month | `occurred_at` | 2 years |
| `spi_deposit_measurements` | Range by month | created implicitly via `spi_measurement_id` join | 5 years active |
| `rule_results` | Range by month | `rule_check_run_id` join date | 5 years active |
| `ai_conversation_logs` | Range by month | `started_at` | 90 days |

### 28.3 Views

```
VIEW: v_active_stencil_designs
  SELECT sd.*, pr.revision_code as pcb_revision_code, p.name as project_name,
         e.full_name as designed_by_name
  FROM stencil_designs sd
  JOIN pcb_revisions pr ON pr.id = sd.pcb_revision_id
  JOIN projects p ON p.id = sd.project_id
  JOIN engineers e ON e.id = sd.designed_by_engineer_id
  WHERE sd.is_deleted = false AND sd.status != 'archived'

VIEW: v_aperture_designs_with_risk
  SELECT ad.*, sd.stencil_number, sd.overall_rule_check_status,
         dra_bridge.risk_score as bridging_risk,
         dra_insuff.risk_score as insufficient_paste_risk
  FROM aperture_designs ad
  JOIN stencil_designs sd ON sd.id = ad.stencil_design_id
  -- (joined to latest risk assessments per aperture)

VIEW: v_defect_knowledge_summary
  SELECT dt.name, dt.defect_code, dt.severity,
         COUNT(dr.id) as occurrence_count,
         COUNT(di.id) as investigation_count,
         AVG(di.yield_after_pct - di.yield_before_pct) as avg_yield_improvement
  FROM defect_types dt
  LEFT JOIN defect_records dr ON dr.defect_type_id = dt.id
  LEFT JOIN defect_investigations di ON di.confirmed_root_cause_id IN (
    SELECT id FROM root_causes WHERE defect_type_id = dt.id)
  GROUP BY dt.id

VIEW: v_organization_knowledge_metrics
  Reports per-organization counts of rules, case studies, experiments,
  defect investigations, and pattern records — for dashboard display.
```

### 28.4 Materialized Views

```
MATERIALIZED VIEW: mv_package_risk_profile
  Pre-computes historical defect rates per package family per organization.
  Used by the Defect Prediction Engine's pattern lookup.
  Refresh: Nightly, or on demand after bulk data imports.

MATERIALIZED VIEW: mv_stencil_design_summary
  Pre-aggregates aperture statistics per stencil design:
  min_area_ratio, avg_area_ratio, critical_aperture_count.
  Refresh: On trigger from aperture_designs INSERT/UPDATE.

MATERIALIZED VIEW: mv_engineer_contribution_scores
  Pre-computes knowledge contribution metrics per engineer.
  Refresh: Weekly.
```

### 28.5 Caching Strategy

```
APPLICATION-LEVEL CACHE (in-memory, per session):

  L1 CACHE — Session lifetime:
    Active rule sets (loaded once at login)
    Aperture shapes reference data
    Surface finishes reference data
    Package families reference data
    Stencil materials reference data
    IPC standards reference data
    Theory cards
    (All reference/lookup tables — changes rarely, safe to cache)

  L2 CACHE — Project lifetime:
    Current project's stencil designs and aperture designs
    Current PCB revision land patterns and pads
    Component library for current project

  CACHE INVALIDATION:
    Rule set changes → invalidate rule set cache for all sessions
    Reference data changes → notify connected sessions to refresh
    Project data changes → invalidate project-scope cache

  LOCAL SQLITE CACHE (Phase 2 — offline support):
    All reference data
    Current project data
    Last 30 days of read-only history
```

### 28.6 Full-Text Search

StencilPro requires full-text search across engineering knowledge:

```
SEARCH SCOPE TABLE:
  Table                | Searchable Columns
  ─────────────────────────────────────────────────
  smt_packages         | ipc_name, common_name, notes
  defect_types         | name, visual_description, common_aliases
  case_studies         | title, abstract, lessons_learned
  theory_cards         | title, summary_text, engineering_detail_text
  ipc_references       | section_title, summary
  root_causes          | name, description
  corrective_actions   | name, description, expected_improvement
  engineering_rules    | name, engineering_rationale, consequence_of_violation
  recommendations      | title, why, what, how
  engineering_notes    | title, content

IMPLEMENTATION:
  PostgreSQL tsvector columns (generated, stored) per table
  GIN indexes on tsvector columns
  pg_trgm extension for fuzzy/partial matching (typo tolerance)
  search_vector column added to each searchable table:
    search_vector TSVECTOR GENERATED ALWAYS AS (
      to_tsvector('english', coalesce(name,'') || ' ' || coalesce(description,''))
    ) STORED
```

---

## 29. Versioning, Soft Delete & Audit

### 29.1 Table Versioning Classification

| Versioning Type | Tables | Mechanism |
|---|---|---|
| **Row versioning** (new row per version) | `engineering_rules`, `calculation_templates`, `rule_sets` | `version` column + `deprecated_at` + `superseded_by_*_id` |
| **Snapshot versioning** (JSONB snapshot) | `stencil_revisions`, `rule_check_runs`, `process_context_snapshots` | JSONB snapshot column at point of approval |
| **Soft delete only** | `stencil_designs`, `projects`, `smt_packages`, `components` | `is_deleted` + `deleted_at` |
| **Append-only (no edit/delete)** | `project_notes`, `audit_log`, `stencil_revisions`, `confidence_adjustments` | RLS enforces no UPDATE/DELETE |
| **No versioning needed** | Reference data, lookup tables | `is_active` flag only |

### 29.2 Soft Delete Policy

```
SOFT DELETE IMPLEMENTATION:
  Column: is_deleted BOOLEAN NOT NULL DEFAULT false
  Column: deleted_at TIMESTAMPTZ NULL

  All application queries filter: WHERE is_deleted = false
  Supabase RLS views filter: WHERE is_deleted = false
  
  Hard deletes are NEVER performed on business data.
  
SOFT DELETE CASCADE POLICY:
  When a parent is soft-deleted, children are NOT automatically
  soft-deleted. Instead:
    - Child records become inaccessible via normal queries
      (they join to a deleted parent which is filtered out)
    - Child records retain is_deleted = false for potential restore
    - Exception: When a Project is soft-deleted, its StencilDesigns
      are also soft-deleted (cascading application logic, not DB cascade)

RESTORE POLICY:
  Admin role may restore soft-deleted records
  Restoration is logged in audit_log
  Restored records return is_deleted = false, deleted_at = NULL
```

### 29.3 Audit Strategy

```
AUDIT COVERAGE — TABLES REQUIRING FULL AUDIT:

  CRITICAL AUDIT (every INSERT/UPDATE logged with old+new values):
    engineering_rules           (knowledge changes)
    rule_sets                   (knowledge changes)
    stencil_designs             (approval status changes)
    stencil_revisions           (approval records)
    aperture_designs            (design decisions)
    defect_investigations       (investigation outcomes)
    corrective_actions          (effectiveness changes from Learning Engine)
    engineers                   (user management)
    engineer_roles              (permission changes)

  STANDARD AUDIT (INSERT/DELETE logged; UPDATE logs changed fields only):
    projects, customers, products
    smt_packages, components
    solder_pastes, stencil_materials
    reflow_profiles, print_parameter_sets

  NO AUDIT (high-volume, low-risk):
    spi_deposit_measurements    (too high volume; SPI file is source of truth)
    activity_log                (is itself an audit table)
    notifications               (transient operational data)
    user_preferences            (non-business data)

AUDIT IMPLEMENTATION:
  PostgreSQL AFTER INSERT/UPDATE/DELETE triggers on audited tables
  Writes to audit_log with old_values and new_values as JSONB
  Captures engineer_id from current_setting('app.current_engineer_id')
    (set by application at connection time)
```

### 29.4 Change Tracking for Knowledge Entities

Engineering knowledge entities (rules, materials, packages) require enhanced change tracking beyond the standard audit log:

```
KNOWLEDGE CHANGE TRACKING:

engineering_rules:
  - Every edit creates a NEW row (new version) rather than updating
  - Old row: deprecated_at = now(), is_active = false
  - New row: version incremented, supersedes_rule_id = old row id
  - RuleCheckRuns record exact version used
  - "Show History" query: SELECT all WHERE rule_code = X ORDER BY version

smt_packages:
  - System packages are immutable (is_system_record = true)
  - Organization overrides create a new row with organization_id set
    (does not modify the system record)
  - Version string tracks manual updates

stencil_materials, solder_pastes:
  - updated_at + full audit log entry on any change
  - No row versioning (changes are corrections, not engineering decisions)
```

---

## 30. Image Storage Strategy

### 30.1 Decision: Supabase Storage (Not PostgreSQL BYTEA)

**Images are stored in Supabase Storage. Binary data is never stored in PostgreSQL.**

**Rationale:**

| Consideration | PostgreSQL BYTEA | Supabase Storage |
|---|---|---|
| Performance | Bloats row size; slow for large files | Optimized CDN delivery |
| Backup | Images in DB backup (huge backups) | Separate from DB backup |
| Streaming | Full load before display | Streaming + presigned URLs |
| Thumbnails | Manual implementation | Native image transforms |
| Cost | Expensive database storage | Cheaper object storage |
| Access control | Via RLS on metadata row | Via Supabase Storage policies |
| Offline access | Cached separately | Cached via local file system |

### 30.2 Storage Bucket Architecture

```
SUPABASE STORAGE BUCKETS:

stencilpro-images (public: false, access via signed URLs)
│
├── reference/                          # System reference images
│   ├── defects/{defect_code}/          # Defect type reference photos
│   ├── packages/{package_family}/      # Package drawings
│   └── ipc/                            # IPC figure references
│
└── organizations/{org_id}/
    ├── projects/{project_id}/
    │   ├── stencil/                    # Stencil design images
    │   ├── inspection/
    │   │   ├── spi/
    │   │   ├── aoi/
    │   │   └── xray/
    │   └── defects/                    # Defect evidence images
    ├── experiments/{experiment_id}/
    ├── case_studies/{case_study_id}/
    └── engineers/{engineer_id}/
        └── signatures/                 # Signed report signatures

stencilpro-reports (public: false, access via signed URLs)
│
└── organizations/{org_id}/
    └── projects/{project_id}/
        └── reports/{report_id}.pdf

stencilpro-documents (public: false)
│
└── organizations/{org_id}/
    └── {entity_type}/{entity_id}/
        └── {filename}

stencilpro-cad (public: false)
│
└── organizations/{org_id}/
    └── projects/{project_id}/
        └── pcb_revisions/{revision_id}/
            └── {gerber_or_odb_files}
```

### 30.3 Image Metadata Strategy

Every image has a corresponding `image_records` row in PostgreSQL containing:
- All searchable metadata (type, subject, capture date, tags, magnification)
- The path in Supabase Storage (never the binary)
- Thumbnail path (separate storage path for the thumbnail)
- Linked entity reference

This separation means:
- Image search queries hit PostgreSQL (fast, indexed)
- Image display hits Supabase Storage CDN (fast, streaming)
- Image deletion = soft-delete the metadata row + delete from storage

### 30.4 Access Control for Images

```
IMAGE ACCESS CONTROL:

Reference images (is_public_reference = true):
  Accessible to any authenticated user of any organization

Organization images:
  Accessible only to engineers of the owning organization
  Enforced by: Supabase Storage policy + image_records RLS

Project images:
  Accessible to engineers assigned to the project
  (future: may restrict to project members only)

Signed URL Policy:
  Presigned URLs expire after 1 hour for sensitive images
  Thumbnails may use longer-lived signed URLs (24 hours)
  Engineers cannot generate signed URLs for other organizations' images
```

### 30.5 Thumbnail Strategy

```
THUMBNAIL GENERATION:
  Method: Supabase Storage image transforms (server-side)
  Trigger: On upload, generate thumbnails via storage transform API
  
  Standard sizes:
    icon:   64 × 64 px   (grid views, lists)
    card:   200 × 200 px (card views, search results)
    detail: 800 × 600 px (detail panel, side-by-side comparison)
  
  Thumbnail paths follow convention:
    Original: organizations/{org_id}/projects/{project_id}/spi/img_001.jpg
    Thumbnail: organizations/{org_id}/projects/{project_id}/spi/thumbs/img_001_200x200.jpg
  
  Thumbnails stored in same bucket as originals
  Thumbnail paths recorded in image_records.thumbnail_storage_path
```

---

## 31. Backup, Migration & Schema Versioning

### 31.1 Backup Strategy

```
BACKUP TIERS:

TIER 1 — Supabase Automatic Backups (included in plan):
  Full backup: Daily
  Point-in-time recovery: Last 7 days (Professional plan)
  Retention: Per Supabase plan

TIER 2 — Application-Level Logical Backups:
  pg_dump of schema + data: Weekly
  Stored in: AWS S3 or equivalent cold storage
  Retention: 7 years (regulatory requirement for automotive/medical)
  Encryption: AES-256 at rest

TIER 3 — Supabase Storage Backups:
  Images and documents versioned in Supabase Storage
  Weekly sync to cold storage bucket
  
TIER 4 — Schema-Only Backup:
  Alembic migrations represent the schema history
  Git repository is the authoritative schema source
  Tag each migration with app version

DISASTER RECOVERY:
  RTO target: < 4 hours (Recovery Time Objective)
  RPO target: < 24 hours (Recovery Point Objective)
  Tested annually: Full restore drill
```

### 31.2 Migration Strategy

```
MIGRATION TOOL: Alembic (Python)

MIGRATION PRINCIPLES:

1. Every schema change is a migration script — never modify production
   schema directly.

2. Migrations are sequential and atomic.
   Each migration runs in a transaction.
   If any step fails, the entire migration rolls back.

3. Migrations are forward-only in production.
   Rollback scripts are written but tested in staging.

4. Zero-downtime migrations for production:
   - Add columns as nullable first (no lock required)
   - Backfill data in a separate migration
   - Add NOT NULL constraint only after backfill

5. Migration naming convention:
   {sequence}_{description}.py
   Example: 0042_add_confidence_decay_field_to_rules.py

6. Every migration updates schema_migrations table on completion.

MIGRATION WORKFLOW:
  Development:
    1. Engineer writes migration in feature branch
    2. Migration tested locally against development database
    3. Migration reviewed in PR (special attention in code review)
    4. PR merged to develop

  Staging:
    5. Migration applied to staging automatically via CI/CD
    6. Integration tests run against migrated schema
    7. Performance tested if migration affects indexed columns

  Production:
    8. Migration applied during release window
    9. Rollback script ready and tested
    10. Post-migration health check runs automatically
```

### 31.3 Schema Versioning Policy

```
SCHEMA VERSION NUMBERING:
  Schema version aligns with application version (SemVer)
  schema_version is recorded in application_config table
  
  MAJOR schema change: breaking change to existing tables
    (columns removed, types changed, tables renamed)
    → Requires migration guide and client version check
    
  MINOR schema change: additive change
    (new columns with defaults, new tables)
    → Backward compatible; old clients continue working
    
  PATCH schema change: data corrections, index additions
    → No API or client impact

SCHEMA DOCUMENTATION:
  This document (Database_Specification.md) is updated in
  the same PR as the migration script that implements it.
  Version number in document header matches the schema version.

BREAKING CHANGE POLICY:
  Desktop app checks schema_version on startup.
  If schema_version > app's supported schema:
    Display upgrade prompt — app cannot run on newer schema.
  If schema_version < app's supported schema:
    Display warning but allow operation with limited features.
```

---

## 32. Supabase-Specific Design

### 32.1 Schema Organization

```
PostgreSQL SCHEMAS within Supabase:
  public          — All application tables (default)
  auth            — Supabase Auth (managed by Supabase)
  storage         — Supabase Storage metadata (managed by Supabase)
  extensions      — pg extensions (uuid-ossp, pg_trgm, unaccent)
  
FUTURE CONSIDERATION:
  If schema isolation per module is desired:
    core_schema        — organizations, engineers, roles
    knowledge_schema   — rules, defects, calculations
    project_schema     — projects, stencils, apertures
    intelligence_schema — scores, recommendations, learning
  (Not implemented in v1.0 — premature optimization)
```

### 32.2 PostgreSQL Extensions Required

```
REQUIRED EXTENSIONS:
  uuid-ossp           — UUID generation (gen_random_uuid())
  pg_trgm             — Trigram similarity for fuzzy search
  unaccent            — Accent-insensitive text search
  btree_gin           — Enables GIN indexes on standard types
  pgcrypto            — For session token hashing

OPTIONAL EXTENSIONS (future):
  pg_stat_statements  — Query performance monitoring
  timescaledb         — If SPI time-series data volume demands it
  postgis             — If board spatial coordinates become significant
```

### 32.3 Supabase Auth Integration

```
AUTH PATTERN:
  engineers.id = auth.users.id (exact match, enforced at registration)

  JWT CLAIMS added to Supabase JWT:
    organization_id: engineers.organization_id
    role_codes: ['engineer', 'senior_engineer']  (array of role codes)
    
  These claims enable RLS policies without a JOIN to the engineers table
  on every row access.

AUTH FLOW FOR DESKTOP APP:
  1. Engineer opens app → check for stored session (system keyring)
  2. If valid token → supabase.auth.setSession(stored_token)
  3. If expired → supabase.auth.refreshSession()
  4. If no token → show LoginDialog → supabase.auth.signInWithPassword()
  5. On successful auth → store token in OS keyring (not file, not env)
  6. Set app.current_engineer_id for audit triggers

LOGOUT:
  1. supabase.auth.signOut()
  2. Clear token from OS keyring
  3. Clear all in-memory caches
```

### 32.4 Realtime Subscriptions (Future)

```
SUPABASE REALTIME — Tables to enable for Phase 3+:

  notifications: 
    Engineers subscribe to their own notifications
    INSERT triggers push to connected desktop clients
    
  stencil_designs (status column only):
    For multi-user collaboration — see when a colleague approves
    
  project_notes:
    Live updates when a colleague adds a project note

REALTIME POLICY:
  Only subscribe to own organization's data
  Use filtered subscriptions: WHERE organization_id = {my_org_id}
  Realtime not enabled for high-volume tables (audit_log, spi_deposit_measurements)
```

### 32.5 Supabase Edge Functions (Future)

```
EDGE FUNCTIONS planned for future phases:

  run-rule-check:
    Trigger rule evaluation engine server-side
    Enables web client and API access without running Python locally
    
  generate-report:
    Trigger report PDF generation server-side
    Accepts report_template_id + entity_id → returns storage path
    
  sync-learning-events:
    Process queued learning events asynchronously
    Updates confidence scores without blocking user session
    
  notify-engineers:
    Send email notifications for critical events
    (design approval needed, investigation assigned)
```

### 32.6 Connection Pooling

```
CONNECTION POOL CONFIGURATION:
  Supabase uses PgBouncer for connection pooling.
  Desktop application uses: Transaction pooling mode
  Pool size: 10 connections per organization (configurable)
  
  SQLAlchemy pool settings:
    pool_size: 5
    max_overflow: 10
    pool_timeout: 30s
    pool_recycle: 1800s (30 minutes)
  
  For offline cache (SQLite):
    Single connection, WAL mode enabled
    No pooling required
```

---

## 33. Open Design Questions

The following architectural decisions require explicit discussion before implementation begins. Each is labeled with its urgency and impact.

---

### ODQ-001 — Multi-Aperture Thermal Pad Representation
**Impact:** HIGH | **Urgency:** Module 06

**Question:** A thermal pad segmented into a 3×3 grid creates 9 separate aperture openings, but they all belong to one "thermal pad aperture" from an engineering standpoint. Should each segment be a separate `aperture_designs` row, or should the thermal pad aperture be a single row with a `segmentation_data` JSONB column describing all segments?

**Option A:** 9 separate `aperture_designs` rows, each with a `thermal_pad_group_id` FK.
- Pro: Consistent data model; each aperture individually evaluable
- Con: Area ratio calculation is ambiguous (which segment is "the" area ratio?)

**Option B:** 1 `aperture_designs` row with `segmentation_data JSONB` + `is_segmented BOOLEAN`.
- Pro: Thermal pad is one design decision, not 9 independent ones
- Con: Breaks the "one aperture = one pad" relationship

**Recommended:** Option A with a `thermal_pad_segment_group_id` column and a rule that evaluates segment groups as a unit.

---

### ODQ-002 — Step Stencil Modeling
**Impact:** HIGH | **Urgency:** Module 07

**Question:** A step stencil has regions of different thickness. How should this be modeled? Should `aperture_designs` have an `actual_thickness_mm` that overrides the stencil design's global `stencil_thickness_option_id`? Or should a step stencil be modeled as two `stencil_designs` (one per thickness region)?

**Option A:** Override thickness per aperture (`aperture_designs.actual_thickness_mm`).
- Simple; all apertures in one stencil design

**Option B:** Two stencil designs linked by a `step_stencil_parent_id`.
- Reflects physical reality better; each region has its own rule check context

**Decision needed before:** Module 07 implementation.

---

### ODQ-003 — Component Placement Import vs Manual Entry
**Impact:** MEDIUM | **Urgency:** Module 04

**Question:** Will `component_placements` and `pads` be populated manually by engineers, or will there be an import pipeline from Gerber/ODB++/IPC-2581 files? The answer determines whether the schema needs import staging tables.

**If import is planned:**
- Need `pcb_import_jobs` staging table
- Need import status tracking per revision
- Need conflict resolution when import data differs from manually entered data

**Recommendation:** Design for import from the start (add `import_job_id` FK to `component_placements` and `pads`), even if the import feature ships in a later module.

---

### ODQ-004 — Rule Engine: YAML Files vs Database-Only Rules
**Impact:** HIGH | **Urgency:** Module 12

**Question:** The Architecture document specifies rules stored in YAML files (committed to Git). The domain specification stores rules in the `engineering_rules` table. Should rules live in:

**Option A:** YAML files only (loaded into memory at startup; not in DB).
- Pro: Version-controlled with code; diff-friendly in PRs
- Con: Cannot be edited by engineers in the UI; no history in DB

**Option B:** Database only (seeded from YAML at install; edited via UI).
- Pro: Full DB history; editable by admin engineers; RLS enforced
- Con: Schema migrations needed when rule structure changes

**Option C:** YAML as source of truth → seeded into DB → engineers edit DB → DB is authoritative.
- Pro: Best of both; YAML is the "factory reset" state
- Con: Complexity in keeping YAML and DB in sync

**Recommended:** Option C — YAML files seed the system rules on install. The DB is the live authoritative source. Edited DB rules can be exported back to YAML for version control (future admin feature).

---

### ODQ-005 — SPI Data Volume and Retention
**Impact:** MEDIUM | **Urgency:** Module 10

**Question:** At 500 deposit measurements per board and potentially 500 boards per day in a high-volume facility, `spi_deposit_measurements` grows at 250,000 rows/day (91M rows/year). 

- Should raw SPI data be stored at this granularity in PostgreSQL?
- Or should only summary statistics be stored (per-aperture average, Cpk), with raw files in object storage?
- When does data become "historical" and move to cold storage?

**Recommended approach for v1.0:**
- Store summary statistics per aperture in `spi_deposit_measurements`
- Store raw SPI data file reference in `spi_measurements.measurement_file_storage_path`
- Partition `spi_deposit_measurements` monthly
- Archive partitions older than 18 months

---

### ODQ-006 — Organization Isolation vs Shared Knowledge Base
**Impact:** HIGH | **Urgency:** Module 01

**Question:** Some entities are designated as "system records" (`is_system_record = true`) and shared across all organizations. But what about industry-level shared knowledge that isn't quite "system" — e.g., a well-documented corrective action contributed by one organization that would benefit others?

- Should there be a concept of "published to community" for case studies, corrective actions, and experiments?
- If yes, what privacy implications exist? A corrective action may contain proprietary process parameters.
- Should a separate `is_community_published` flag be added to knowledge entities?

**Recommendation:** Add `is_community_published BOOLEAN DEFAULT false` to `case_studies`, `experiments`, and `corrective_actions`. Community-published records are readable by all organizations but remain owned by the originating organization. Implement in Phase 4+.

---

### ODQ-007 — Confidence Score Precision and Clamping
**Impact:** MEDIUM | **Urgency:** Module 12

**Question:** Confidence scores appear in `engineering_rules`, `root_causes`, `corrective_actions`, `recommendations`, and `defect_risk_assessments`. Should these all use the same scale (0–100 as NUMERIC(6,3)) or should some use 0.0–1.0 (NUMERIC(5,4))?

**Current spec:** `engineering_rules.base_confidence_pct NUMERIC(6,3)` (0–100)

**Issue:** The Learning System spec uses multipliers like `confidence × 0.05`. If confidence is stored as 0–100, the multiplier math becomes awkward. If stored as 0.0–1.0, percentage display requires ×100.

**Recommendation:** Store all confidence values as `NUMERIC(6,4)` representing 0.0000–1.0000 (i.e., 0.9500 = 95%). Display layer multiplies by 100 for "95%" display. Column name remains `_pct` suffix for clarity of intent, but value range is 0–1.

---

### ODQ-008 — Audit Log: Trigger vs Application-Level
**Impact:** MEDIUM | **Urgency:** Module 20

**Question:** Should the audit log be written by:

**Option A:** PostgreSQL triggers (automatic, cannot be bypassed).
- Pro: Audit is guaranteed regardless of application code path
- Con: Cannot access engineer_id easily in trigger without session variable

**Option B:** Application-level (Repository layer writes to audit_log).
- Pro: Full context (engineer_id, session) available
- Con: Can be accidentally bypassed if developer writes a raw query

**Recommended:** Hybrid — PostgreSQL triggers write to audit_log for critical tables (rules, stencil approvals, user management), capturing `current_setting('app.current_engineer_id')` set by the Repository layer. Application writes to activity_log for behavioral tracking.

---

### ODQ-009 — Offline Mode Schema
**Impact:** MEDIUM | **Urgency:** Phase 2

**Question:** The Architecture document mentions a local SQLite cache for offline operation. Should the SQLite schema be:

**Option A:** A complete mirror of the PostgreSQL schema (same tables, fewer rows).
- Pro: Same ORM models; no translation layer
- Con: SQLite has fewer data types; JSONB becomes TEXT; UUIDs as TEXT

**Option B:** A simplified read-only cache with only frequently accessed tables.
- Pro: Smaller footprint; simpler sync logic
- Con: Limited offline capability

**Option C:** A sync queue table + selective table cache (hybrid).
- Write operations go to sync queue; reads use cached data

**Recommendation:** Option C for Phase 2. Add `sync_queue` table to local SQLite:
```
sync_queue (id, table_name, operation, record_id, payload, created_at, synced_at)
```
Cache reference tables and current project data. Sync on reconnect.

---

### ODQ-010 — `aperture_to_aperture_gap_mm` Calculation and Storage
**Impact:** MEDIUM | **Urgency:** Module 07

**Question:** The `aperture_designs.aperture_to_aperture_gap_mm` field requires spatial proximity queries across all apertures in a stencil design — potentially hundreds of apertures. Should this be:

**Option A:** Calculated at design time and stored (current approach).
- When: Recalculated every time any aperture in the design changes
- Problem: N² update complexity for large designs

**Option B:** Calculated on demand by the Rule Engine (not stored).
- Pro: Always fresh; no stale data risk
- Con: Slower rule check for large designs

**Option C:** Stored with a `gap_last_calculated_at` timestamp; marked stale when neighbors change.
- Pro: Balance of performance and freshness
- Con: More complex invalidation logic

**Recommendation:** Option C — store the value, track staleness, recalculate as part of the rule check run rather than on every individual aperture save.

---

### ODQ-011 — Report Number Format
**Impact:** LOW | **Urgency:** Module 19

**Question:** The `projects.project_number` and `generated_reports.report_number` need auto-generation. Should these be:
- Global sequential (`PROJ-00042`)
- Per-organization sequential (`ACME-2026-00042`)
- UUID-based short codes
- Date-based (`2026-06-26-001`)

**Recommendation:** Per-organization sequential with configurable format stored in `organization_settings`. Default: `{ORG_CODE}-{YEAR}-{SEQ:04d}`. Sequence stored in a `sequences` table or PostgreSQL sequence object per organization.

---

### ODQ-012 — IPC Class Enforcement: Database or Application?
**Impact:** HIGH | **Urgency:** Module 03

**Question:** The business rule states: "a project's IPC class must be ≥ the customer's required IPC class." Should this be enforced by:

**Option A:** PostgreSQL CHECK constraint.
- Pro: Guaranteed enforcement; cannot be bypassed
- Con: CHECK constraints cannot reference other tables; would require a trigger

**Option B:** Application-layer validation (Controller checks before INSERT/UPDATE).
- Pro: Better error messages; more context
- Con: Can be bypassed by raw SQL

**Recommendation:** Application-layer validation with a PostgreSQL trigger as a backstop on `projects` INSERT/UPDATE that verifies ipc_class rank against the customer's requirement. Document the trigger clearly so future developers understand why it exists.

---

*End of Open Design Questions*

---

## Appendix A — Complete Table Count by Module

| Module | Module Name | Table Count |
|---|---|---|
| 01 | Core System & Tenancy | 4 |
| 02 | User Management & Security | 6 |
| 03 | Projects & Customers | 6 |
| 04 | PCB & Assembly | 4 |
| 05 | Component & Package Library | 5 |
| 06 | Land Patterns & Pads | 4 |
| 07 | Stencil Design | 5 |
| 08 | Materials Library | 6 |
| 09 | Process & Equipment | 6 |
| 10 | Inspection | 7 |
| 11 | Defect & Failure Knowledge | 8 |
| 12 | Rule Engine | 7 |
| 13 | Engineering Calculations | 3 |
| 14 | Recommendation Engine | 4 |
| 15 | Intelligence & Scoring | 4 |
| 16 | Learning System | 4 |
| 17 | Knowledge Base | 5 |
| 18 | Images & Media | 3 |
| 19 | Reports & Documents | 4 |
| 20 | Audit, Activity & Notifications | 4 |
| 21 | Application Settings | 3 |
| 22 | Future AI Layer | 3 |
| **TOTAL** | | **106** |

---

## Appendix B — Tables by Versioning Classification

| Versioning Type | Tables |
|---|---|
| Row versioning (new row per version) | `engineering_rules`, `calculation_templates`, `rule_sets` |
| Snapshot versioning (JSONB) | `stencil_revisions`, `rule_check_runs`, `process_context_snapshots`, `design_score_cards` |
| Soft delete only | `stencil_designs`, `projects`, `customers`, `products`, `smt_packages`, `components`, `stencil_materials`, `solder_pastes`, `image_records`, `document_attachments` |
| Append-only | `project_notes`, `stencil_design_notes`, `audit_log`, `activity_log`, `confidence_adjustments`, `rule_results`, `spi_deposit_measurements` |
| Reference data (`is_active` only) | `surface_finishes`, `package_families`, `aperture_shapes`, `stencil_thickness_options`, `inspection_methods`, `defect_categories`, `ipc_standards`, `ipc_references`, `theory_cards` |

---

## Appendix C — Tables Requiring RLS Policies

```
RLS REQUIRED (organization_id scoped):
  All tables with organization_id column — 85+ tables

RLS SPECIAL CASES:
  engineers:
    Engineers can read their own row + others in same org
    Engineers can only update their own row
    Admin role required for create/delete

  engineering_rules (system records):
    All authenticated users can SELECT where is_system_record = true
    Only admin role can INSERT/UPDATE own org custom rules
    Nobody can modify system rules

  stencil_revisions:
    Organization-scoped SELECT
    INSERT permitted by engineer and senior_engineer
    UPDATE/DELETE: DENIED for all roles

  audit_log, activity_log:
    Admin-only SELECT
    System/trigger INSERT only
    UPDATE/DELETE: DENIED for all roles
```

---

*End of Database Specification v1.0.0*
*StencilPro Expert Enterprise*
*Classification: Core Infrastructure Design Document*
*Next Document: MODULE_001_SPECIFICATION.md or begin implementation*
