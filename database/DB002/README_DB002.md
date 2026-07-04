# DB-002: Projects & Customers

**StencilPro Expert Enterprise**
**Module:** DB-002 — Projects & Customers
**PostgreSQL 16 / Supabase Compatible**
**Prerequisite:** DB-001 (Core System) must be fully applied first.

---

## Overview

DB-002 implements the complete Projects & Customers domain for StencilPro Expert Enterprise. This module provides the organizational container for all engineering work: customers, products, projects, project membership, revision history, notes, attachments, tags, activity streams, and project templates.

---

## Tables Introduced

| Table | Rows (Typical) | Versioned | Soft Delete | Append-Only | Audited |
|---|---|---|---|---|---|
| `customers` | 10–500 | No | Yes | No | Yes |
| `customer_contacts` | 20–2,000 | No | Yes | No | Yes |
| `products` | 10–1,000 | No | Yes | No | Yes |
| `projects` | 50–5,000 | No | Yes | No | Yes |
| `project_members` | 100–20,000 | No | No (removed_at) | No | Yes |
| `project_revisions` | 100–10,000 | Yes (snapshot) | No | Yes (on approval) | Yes |
| `project_notes` | 500–100,000 | No | No | **Yes** | Partial |
| `project_attachments` | 100–10,000 | No | Yes | No | Yes |
| `project_tags` | 10–200 | No | No | No | No |
| `project_tag_assignments` | 100–20,000 | No | No | No | No |
| `project_activity` | 10,000–1M+ | No | No | **Yes** | No |
| `project_templates` | 5–50 | No | No | No | No |

---

## File Execution Order

Run each file against your Supabase PostgreSQL instance **in this exact order**. All files are idempotent (safe to re-run on a clean or partially applied database).

```
1. DB002_Projects.sql     — Table definitions, constraints, CHECK rules
2. DB002_Functions.sql    — PL/pgSQL functions and SECURITY DEFINER helpers
3. DB002_Indexes.sql      — All indexes (run after tables exist)
4. DB002_Triggers.sql     — Business-rule triggers, audit hooks, immutability
5. DB002_RLS.sql          — Row Level Security enable + all policies
6. DB002_Seed.sql         — System project templates and application config
```

### Supabase Dashboard

SQL Editor → New Query → paste each file → Run

### psql CLI

```bash
export DATABASE_URL="postgresql://postgres:[password]@[host]:5432/postgres"

psql "$DATABASE_URL" -f DB002_Projects.sql
psql "$DATABASE_URL" -f DB002_Functions.sql
psql "$DATABASE_URL" -f DB002_Indexes.sql
psql "$DATABASE_URL" -f DB002_Triggers.sql
psql "$DATABASE_URL" -f DB002_RLS.sql
psql "$DATABASE_URL" -f DB002_Seed.sql
```

---

## Key Design Decisions

### 1. Project Notes are Append-Only

`project_notes` is an immutable audit log of engineering decisions. Once inserted, a note can never be modified or deleted. This is enforced at **three independent layers**:

- PostgreSQL `BEFORE UPDATE` and `BEFORE DELETE` triggers raise an exception
- RLS policies set `USING (FALSE)` for UPDATE and DELETE
- Application layer Repository enforces insert-only access

This table is the primary engineering decision audit trail required for IATF 16949, ISO 13485, and AS9100 regulatory audits.

### 2. Project Activity is Append-Only

`project_activity` is a high-resolution event stream. It uses `BIGSERIAL` (not UUID) as its primary key to guarantee strict chronological ordering. Direct INSERT is blocked by RLS; all writes go through the `fn_create_project_activity()` SECURITY DEFINER function.

### 3. Project Revisions are Immutable After Approval

Once `project_revisions.approved_at` is set, the row is permanently immutable. The `fn_project_revision_immutable()` trigger enforces this at the database layer. The `project_snapshot` JSONB column captures the complete project state at approval time, enabling full historical reconstruction.

### 4. IPC Class Enforcement

The `fn_enforce_project_ipc_class()` trigger fires `BEFORE INSERT OR UPDATE` on `projects`. It compares `project.ipc_class` against `customer.required_ipc_class` using a rank map (`class_1=1, class_2=2, class_3=3`). If the project class is lower than the customer minimum, the operation is rejected with a `check_violation` error code.

### 5. fn_engineer_on_project

The RLS helper function `fn_engineer_on_project(project_id UUID)` is defined in `DB002_RLS.sql` and used across all project-scoped table policies. It returns TRUE if the current engineer is either the `lead_engineer_id` of the project or an active (not removed) `project_members` entry.

### 6. Tag Usage Count

`project_tags.usage_count` is maintained by the `fn_project_tag_usage_count()` trigger on `project_tag_assignments`. This denormalized count enables fast display of popular tags and identification of unused tags for cleanup. The `GREATEST(0, ...)` guard prevents negative counts from concurrent deletes.

---

## RLS Policy Summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `customers` | Org members | Admin | Admin | Blocked |
| `customer_contacts` | Org members | Admin | Admin | Blocked |
| `products` | Org members | Admin | Admin | Blocked |
| `projects` | Org members | Engineer+ | Lead / Member / Admin | Blocked |
| `project_members` | Org members | Lead / Admin | Lead / Admin | Admin |
| `project_revisions` | Org members | Engineer+ | Member / Admin | Blocked |
| `project_notes` | Org members | Any org member | **Blocked** | **Blocked** |
| `project_attachments` | Org members | Engineer+ | Uploader / Lead / Admin | Blocked |
| `project_tags` | Org members | Engineer+ | Admin | Admin |
| `project_tag_assignments` | Org members | Lead / Admin | Org members | Lead / Admin |
| `project_activity` | Org members | **Blocked (fn only)** | **Blocked** | **Blocked** |
| `project_templates` | All org + system | Admin / Super Admin | Admin / Super Admin | Admin (custom only) |

---

## Functions Reference

| Function | Signature | Purpose |
|---|---|---|
| `fn_enforce_project_ipc_class` | `() → TRIGGER` | Rejects projects with IPC class below customer minimum |
| `fn_project_status_note` | `() → TRIGGER` | Auto-creates project_note on status change |
| `fn_project_activity_log` | `() → TRIGGER` | Writes project_activity on project INSERT/UPDATE |
| `fn_project_member_activity` | `() → TRIGGER` | Writes project_activity on member add/remove |
| `fn_project_note_activity` | `() → TRIGGER` | Writes project_activity on engineer-authored notes |
| `fn_prevent_project_note_modification` | `() → TRIGGER` | Blocks UPDATE/DELETE on project_notes |
| `fn_prevent_project_activity_modification` | `() → TRIGGER` | Blocks UPDATE/DELETE on project_activity |
| `fn_project_revision_immutable` | `() → TRIGGER` | Blocks mutation of approved project_revisions |
| `fn_project_tag_usage_count` | `() → TRIGGER` | Maintains project_tags.usage_count |
| `fn_project_template_usage_count` | `() → TRIGGER` | Increments template usage_count on project INSERT |
| `fn_create_project_activity` | `(UUID, UUID, UUID, VARCHAR, VARCHAR, VARCHAR, UUID, JSONB) → VOID` | Application-callable activity insert |
| `fn_soft_delete_project` | `(UUID, UUID) → VOID` | Safe project soft-delete with note creation |
| `fn_get_project_summary` | `(UUID) → JSONB` | Returns JSONB project snapshot for revisions |
| `fn_create_project_revision` | `(UUID, VARCHAR, VARCHAR, TEXT, VARCHAR, UUID) → UUID` | Creates versioned project revision with snapshot |
| `fn_engineer_on_project` | `(UUID) → BOOLEAN` | RLS helper: is current engineer on this project? |

---

## Session Variable

All trigger functions that write to `project_notes` or `project_activity` read the current engineer identity from:

```sql
current_setting('app.current_engineer_id', TRUE)::UUID
```

The Python application layer **must** set this at the start of every transaction:

```python
# In SQLAlchemy before any DML in a session:
session.execute(
    text("SET LOCAL app.current_engineer_id = :eid"),
    {"eid": str(current_engineer.id)}
)
```

If the variable is not set, functions fall back to `updated_by`, then `lead_engineer_id`. A NULL engineer ID in audit records indicates a system-initiated operation.

---

## Post-Install Verification

After applying all 6 files, run these queries to verify correct installation:

```sql
-- 1. All 12 DB-002 tables exist
SELECT table_name
FROM   information_schema.tables
WHERE  table_schema = 'public'
  AND  table_name IN (
    'customers','customer_contacts','products','projects',
    'project_members','project_revisions','project_notes',
    'project_attachments','project_tags','project_tag_assignments',
    'project_activity','project_templates'
  )
ORDER BY table_name;
-- Expected: 12 rows

-- 2. System project templates seeded
SELECT name, default_phase, default_ipc_class, is_system_template
FROM   project_templates
ORDER BY name;
-- Expected: 5 rows (NPI, ECO, Production Transfer, High Reliability, Prototype)

-- 3. Application config for project module
SELECT config_key, config_value
FROM   application_config
WHERE  config_key LIKE 'project.%'
ORDER BY config_key;
-- Expected: 10 rows

-- 4. Migration record present
SELECT version_num, applied_at
FROM   schema_migrations
ORDER BY applied_at;
-- Expected: 0001_db001_core_system, 0002_db002_projects_customers

-- 5. RLS enabled on all tables
SELECT tablename, rowsecurity, forcerowsecurity
FROM   pg_tables
WHERE  schemaname = 'public'
  AND  tablename IN (
    'customers','projects','project_notes','project_activity'
  );
-- Expected: rowsecurity = TRUE, forcerowsecurity = TRUE for all

-- 6. Append-only enforcement: attempt UPDATE on project_notes (must fail)
-- Run from a non-service-role session:
-- UPDATE project_notes SET title = 'test' WHERE FALSE;
-- Expected: ERROR: project_notes records are append-only...

-- 7. IPC class enforcement: attempt to create class_1 project for class_2 customer
-- (Run from application or test harness — requires a test customer record)
-- Expected: ERROR: Project IPC class (class_1) is below the customer required minimum (class_2)...
```

---

## Index Count Summary

| Table | Index Count |
|---|---|
| `customers` | 8 |
| `customer_contacts` | 4 |
| `products` | 5 |
| `projects` | 14 |
| `project_members` | 6 |
| `project_revisions` | 6 |
| `project_notes` | 7 |
| `project_attachments` | 5 |
| `project_tags` | 4 |
| `project_tag_assignments` | 3 |
| `project_activity` | 5 |
| `project_templates` | 3 |
| **Total** | **70** |

---

## Dependencies on Future Modules

The following foreign key columns in DB-002 tables reference tables that will be created in later modules. They are declared as columns with the correct UUID type but **without FK constraints** until the referenced tables exist:

| Column | References (Future Module) |
|---|---|
| `customers.approved_paste_ids[]` | `solder_pastes.id` (DB-008) |
| `customers.approved_stencil_material_ids[]` | `stencil_materials.id` (DB-008) |
| `project_templates.template_settings → default_paste_id` | `solder_pastes.id` (DB-008) |
| `project_templates.template_settings → default_rule_set_id` | `rule_sets.id` (DB-012) |

These are stored as `UUID[]` arrays or JSONB values. FK constraints will be added in the respective modules as `ALTER TABLE` statements.

---

## Change Log

| Version | Date | Description |
|---|---|---|
| 1.0.0 | 2026-06-26 | Initial release — DB-002 complete |
