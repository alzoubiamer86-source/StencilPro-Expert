# DB-003: PCB Assemblies & Components

**StencilPro Expert Enterprise**
**Module:** DB-003 — PCB Assemblies & Components
**PostgreSQL 16 / Supabase Compatible**
**Prerequisites:** DB-001 (Core System) + DB-002 (Projects & Customers)

---

## Overview

DB-003 implements the complete PCB assembly and component data model for StencilPro Expert Enterprise. This module defines the engineering artifact at the heart of the stencil design process: the PCB assembly with its revisions, layer stack-up, component placements, BOM, and all associated design files.

Every stencil design in the system references a specific PCB revision defined in this module. The component placement data enables spatial proximity analysis, paste bridging risk assessment, and tombstoning prediction in the Intelligence Engine.

---

## Tables Introduced (17 tables)

| Table | Rows (Typical) | Versioned | Soft Delete | Audited |
|---|---|---|---|---|
| `pcb_surface_finishes` | 10–20 | No | No | No |
| `pcb_materials` | 8–30 | No | No | No |
| `pcb_thickness_options` | 9–20 | No | No | No |
| `board_manufacturers` | 10–200 | No | No | Yes |
| `assembly_manufacturers` | 5–100 | No | No | Yes |
| `pcb_assemblies` | 50–5,000 | No | Yes | Yes |
| `pcb_revisions` | 100–20,000 | Snapshot (fn) | No | Yes |
| `pcb_layers` | 200–50,000 | No | No | Yes |
| `pcb_stackups` | 50–5,000 | No | No | No |
| `assembly_variants` | 50–2,000 | No | No | No |
| `design_files` | 500–100,000 | No | Yes | Yes |
| `components` | 500–50,000 | Yes (revisions) | Yes | Yes |
| `component_revisions` | 500–50,000 | Yes (snapshot) | No | Yes |
| `electrical_nets` | 5,000–500,000 | No | No | No |
| `bom_revisions` | 100–10,000 | Yes (released→immutable) | No | Yes |
| `bom_items` | 5,000–500,000 | No | No | Yes |
| `component_placements` | 10,000–5,000,000 | No | No | Yes |

---

## File Execution Order

All files are idempotent. Apply in exact order:

```
1. DB003_PCB.sql        — Table definitions, CHECK constraints, partial unique indexes
2. DB003_Functions.sql  — PL/pgSQL business logic functions
3. DB003_Indexes.sql    — All indexes (87 total)
4. DB003_Triggers.sql   — Trigger attachments (50 triggers)
5. DB003_RLS.sql        — RLS enable, FORCE, helper functions, 68 policies
6. DB003_Seed.sql       — Reference data + application config
```

### psql CLI

```bash
export DATABASE_URL="postgresql://postgres:[password]@[host]:5432/postgres"
psql "$DATABASE_URL" -f DB003_PCB.sql
psql "$DATABASE_URL" -f DB003_Functions.sql
psql "$DATABASE_URL" -f DB003_Indexes.sql
psql "$DATABASE_URL" -f DB003_Triggers.sql
psql "$DATABASE_URL" -f DB003_RLS.sql
psql "$DATABASE_URL" -f DB003_Seed.sql
```

---

## Key Design Decisions

### 1. PCB Revision is the Stencil Anchor

All downstream engineering work — stencil designs, aperture designs, land patterns, component placements — references `pcb_revisions`, never `pcb_assemblies`. This ensures every engineering decision is traceable to a specific, immutable design state. When a PCB changes, a new revision is created; existing stencil designs remain linked to the revision they were designed against.

### 2. Single Current Revision Enforcement — Three Layers

Only one `pcb_revision` per assembly may have `is_current_revision = TRUE`. This is enforced by:
- `PARTIAL UNIQUE INDEX uq_pcb_revisions_current_revision` on `(pcb_assembly_id) WHERE is_current_revision = TRUE`
- `fn_pcb_revision_current_enforce()` BEFORE trigger that demotes all other revisions before setting the new current
- Application-layer validation before submitting the update

### 3. Component Placements Drive Intelligence

`component_placements` is the single largest table in the system at production scale (millions of rows for large organizations). It carries X/Y coordinates, rotation, and assembly side, enabling:
- Spatial proximity analysis for bridging risk between adjacent pads
- Tombstoning risk (volume imbalance between neighboring pads of chip components)
- Component height interference detection during board support planning
- Automated import via `fn_import_pick_place_row()` UPSERT function

### 4. Released BOM Revisions are Immutable

Once `bom_revisions.is_released = TRUE`, the BOM is locked for regulatory traceability. Immutability is enforced by:
- `fn_bom_revision_immutable()` BEFORE UPDATE trigger (blocks most field changes, allows only `is_current` flag)
- `fn_prevent_bom_item_modification_released()` BEFORE trigger on `bom_items`
- Application-layer enforcement in the BOM management UI

### 5. Future FK Constraints (Not Yet Applied)

Two FK constraints are intentionally deferred to later modules:

| Column | References | Applied In |
|---|---|---|
| `components.package_id` | `smt_packages(id)` | DB-004 |
| `component_placements.land_pattern_id` | `land_patterns(id)` | DB-005 |

These are stored as nullable UUID columns. The FK `ALTER TABLE` statements will be added in their respective modules.

### 6. BOM Counts are Denormalized

`bom_revisions.total_line_items`, `total_component_quantity`, and `unique_part_count` are maintained by the `fn_bom_counts_update()` AFTER trigger on `bom_items`. This denormalization avoids expensive COUNT queries on the BOM display screen, which may have thousands of line items.

### 7. Component Placement Counts on PCB Revisions

`pcb_revisions.component_count`, `smt_component_count`, and `unique_package_count` are maintained by the `fn_component_placement_counts_update()` AFTER trigger on `component_placements`. These drive:
- Dashboard summary statistics
- Intelligence Engine ProcessContext metadata
- Rule group activation decisions (e.g., "this revision has BGAs")

---

## Functions Reference

| Function | Signature | Purpose |
|---|---|---|
| `fn_pcb_revision_current_enforce` | `() → TRIGGER` | Demotes other revisions when new current is set |
| `fn_bom_revision_current_enforce` | `() → TRIGGER` | Demotes other BOMs when new current is set |
| `fn_component_revision_current_enforce` | `() → TRIGGER` | Single current component revision |
| `fn_bom_revision_immutable` | `() → TRIGGER` | Blocks released BOM mutations |
| `fn_bom_counts_update` | `() → TRIGGER` | Maintains BOM aggregate counts |
| `fn_prevent_bom_item_modification_released` | `() → TRIGGER` | Blocks BOM item changes on released BOMs |
| `fn_pcb_revision_notify_stencil` | `() → TRIGGER` | Creates project_activity when revision set current |
| `fn_component_placement_counts_update` | `() → TRIGGER` | Maintains PCB revision placement counts |
| `fn_pcb_assembly_activity` | `() → TRIGGER` | Logs assembly creation/deletion to project_activity |
| `fn_get_pcb_revision_summary` | `(UUID) → JSONB` | JSONB summary for Intelligence Engine ProcessContext |
| `fn_get_placements_for_revision` | `(UUID) → TABLE` | Full placement list with component data for analysis |
| `fn_validate_pcb_assembly_integrity` | `(UUID) → JSONB` | Pre-stencil-design readiness check |
| `fn_import_pick_place_row` | `(UUID,UUID,VARCHAR,...) → UUID` | UPSERT single placement from import |
| `fn_pcb_assembly_in_org` | `(UUID) → BOOLEAN` | RLS helper: assembly in current engineer's org |
| `fn_pcb_revision_in_org` | `(UUID) → BOOLEAN` | RLS helper: revision in current engineer's org |

---

## RLS Policy Summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `pcb_surface_finishes` | All | Super Admin | Super Admin | Super Admin |
| `pcb_materials` | All | Super Admin | Super Admin | Super Admin |
| `pcb_thickness_options` | All | Super Admin | Super Admin | Super Admin |
| `board_manufacturers` | Org + System | Admin / Super | Admin / Super | Admin (custom only) |
| `assembly_manufacturers` | Org + System | Admin / Super | Admin / Super | Admin (custom only) |
| `pcb_assemblies` | Org | Engineer+ | Lead/Admin | Blocked |
| `pcb_revisions` | Org | Engineer+ | Org members | Blocked |
| `pcb_layers` | Org | Org members | Org members | Admin |
| `pcb_stackups` | Org | Org members | Org members | Admin |
| `assembly_variants` | Org | Org members | Org members | Admin |
| `design_files` | Org | Engineer+ | Uploader/Admin | Blocked |
| `components` | Org | material.manage | material.manage | Blocked |
| `component_revisions` | Org | material.manage | Senior+ | Blocked |
| `electrical_nets` | Org | Org members | Org members | Admin |
| `bom_revisions` | Org | Engineer+ | Org / Admin | Admin (unreleased) |
| `bom_items` | Org | Engineer+ | Engineer+ | Engineer+ |
| `component_placements` | Org | Engineer+ | Engineer+ | Engineer+ |

---

## Seed Data Summary

| Entity | Count | Notes |
|---|---|---|
| PCB surface finishes | 10 | ENIG, HASL-LF, HASL, OSP, ImAg, ImSn, ENEPIG, Hard-Au, DIG, ENIG-WB |
| PCB materials | 8 | Standard FR4, High-Tg FR4, Halogen-Free FR4, Rogers RO4003C/4350B, Polyimide, Aluminum, Ceramic |
| PCB thickness options | 9 | 0.4mm through 4.0mm (standard and non-standard) |
| Application config | 12 | PCB module configuration values |

---

## Index Count Summary

| Table | Index Count |
|---|---|
| `pcb_surface_finishes` | 3 |
| `pcb_materials` | 3 |
| `pcb_thickness_options` | 2 |
| `board_manufacturers` | 4 |
| `assembly_manufacturers` | 3 |
| `pcb_assemblies` | 12 |
| `pcb_revisions` | 9 |
| `pcb_layers` | 4 |
| `pcb_stackups` | 3 |
| `assembly_variants` | 4 |
| `design_files` | 6 |
| `components` | 9 |
| `component_revisions` | 4 |
| `electrical_nets` | 5 |
| `bom_revisions` | 7 |
| `bom_items` | 6 |
| `component_placements` | 13 |
| **Total** | **97** |

---

## Post-Install Verification

```sql
-- 1. All 17 tables exist
SELECT table_name
FROM   information_schema.tables
WHERE  table_schema = 'public'
  AND  table_name IN (
    'pcb_surface_finishes','pcb_materials','pcb_thickness_options',
    'board_manufacturers','assembly_manufacturers',
    'pcb_assemblies','pcb_revisions','pcb_layers','pcb_stackups',
    'assembly_variants','design_files',
    'components','component_revisions','electrical_nets',
    'bom_revisions','bom_items','component_placements'
  )
ORDER BY table_name;
-- Expected: 17 rows

-- 2. Surface finishes seeded
SELECT abbreviation, flatness_rating, is_rohs_compliant
FROM   pcb_surface_finishes
ORDER BY abbreviation;
-- Expected: 10 rows (DIG, ENIG, ENIG-WB, ENEPIG, Hard-Au, HASL, HASL-LF, ImAg, ImSn, OSP)

-- 3. PCB materials seeded
SELECT name, material_type, tg_min_c
FROM   pcb_materials
ORDER BY name;
-- Expected: 8 rows

-- 4. Thickness options seeded
SELECT thickness_mm, thickness_label, is_standard
FROM   pcb_thickness_options
ORDER BY thickness_mm;
-- Expected: 9 rows (0.40 through 4.00mm)

-- 5. Application config for PCB module
SELECT config_key, config_value
FROM   application_config
WHERE  config_key LIKE 'pcb.%'
ORDER BY config_key;
-- Expected: 12 rows

-- 6. Migration record present
SELECT version_num, applied_at
FROM   schema_migrations
ORDER BY applied_at;
-- Expected: 0001_db001, 0002_db002, 0003_db003_pcb_assemblies_components

-- 7. Partial unique index on current revision (verify constraint exists)
SELECT indexname, indexdef
FROM   pg_indexes
WHERE  tablename = 'pcb_revisions'
  AND  indexname = 'uq_pcb_revisions_current_revision';
-- Expected: 1 row with WHERE is_current_revision = true

-- 8. RLS enabled
SELECT tablename, rowsecurity, forcerowsecurity
FROM   pg_tables
WHERE  schemaname = 'public'
  AND  tablename IN ('pcb_assemblies','component_placements','bom_revisions');
-- Expected: rowsecurity = TRUE, forcerowsecurity = TRUE for all

-- 9. Test fn_get_pcb_revision_summary (returns NULL for non-existent ID)
SELECT fn_get_pcb_revision_summary('00000000-0000-0000-0000-000000000000');
-- Expected: NULL (no error)

-- 10. Test fn_validate_pcb_assembly_integrity (returns error JSONB for non-existent ID)
SELECT fn_validate_pcb_assembly_integrity('00000000-0000-0000-0000-000000000000');
-- Expected: {"valid": false, "issues": ["PCB Assembly not found or deleted."]}
```

---

## Dependencies on Future Modules

| Column | References (Future Module) | FK Applied In |
|---|---|---|
| `components.package_id` | `smt_packages(id)` | DB-004 |
| `component_placements.land_pattern_id` | `land_patterns(id)` | DB-005 |

These columns are present as nullable UUIDs. The FK `ALTER TABLE ... ADD CONSTRAINT` statements will be included in DB-004 and DB-005 respectively as forward references.

---

## Change Log

| Version | Date | Description |
|---|---|---|
| 1.0.0 | 2026-06-26 | Initial release — DB-003 complete |
