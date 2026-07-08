# DB005 — Land Pattern & Aperture Intelligence Engine

## Status
Complete. Continues the established StencilPro Expert Enterprise database architecture (DB001–DB004A) with no redesign, no architectural deviation, and no alternative approaches introduced.

## Purpose
DB005 transforms PCB pads into manufacturing-ready stencil apertures. It is the complete Land Pattern & Aperture Intelligence Engine — not a simple pad database.

**Architectural principle (established this module):**
- DB003 answers: *"What exists on the PCB?"*
- DB005 answers: *"How should each pad be manufactured using a stencil?"*

This separation is intentional. DB003 owns PCB assemblies, revisions, components and placements. DB005 owns the canonical Package Family library, the canonical Pad entity, and all stencil-manufacturing intelligence built on top of them.

## Files in this module

| File | Purpose |
|---|---|
| `DB005_LandPatterns.sql` | Core schema: all 24 tables across Sections 1–6 |
| `DB005_Functions.sql` | Engineering calculation functions, revision snapshot helpers, approval workflow functions |
| `DB005_Indexes.sql` | Indexing strategy: FK indexes, org-scoped composites, partial "current row" indexes, GIN indexes on revision snapshots |
| `DB005_Triggers.sql` | Audit triggers, metric recomputation trigger, revision-logging triggers, approval notification trigger, single-current-row enforcement triggers |
| `DB005_RLS.sql` | Row-level security: organization isolation, global reference-table policies |
| `DB005_Seed.sql` | Aperture shapes, defect catalog, surface finishes, representative package families, and the three example engineering strategies (QFN thermal pad, BGA, 0402 passive) |
| `README_DB005.md` | This file |

## Schema overview by section

### Section 1 — Land Pattern Library
- `package_families` — canonical, DB005-owned master Package Family library (0402, 0603, SOT23, SOIC, QFP, QFN, DFN, BGA, CSP, Connector, LED, Crystal, etc.)
- `land_patterns` — IPC, company, and customer land patterns; versioned; approval-gated via `status`
- `land_pattern_pads` — per-pad position/geometry within a land pattern
- `land_pattern_revisions` — append-only revision snapshots (jsonb)
- `land_pattern_approvals` — engineer approval workflow instances

### Section 2 — Pad Intelligence
- `surface_finish_types` — global lookup (ENIG, HASL, OSP, Immersion Tin/Silver, ENEPIG, Hard Gold, etc.)
- `pad_surface_finish_compatibility` — compatibility rating per package family
- `pads` — the canonical Pad entity. Stores shape, width, height, corner radius, rotation, paste mask expansion, solder mask type/expansion, via information, surface finish, and package family relationship. **The stencil engine operates from this table.**

### Section 3 — Stencil Aperture Library
- `aperture_shape_types` — global lookup covering all 13 required shapes (Rectangle, Rounded Rectangle, Square, Circle, Oval, Home Plate, Inverted Home Plate, Window Pane, Segmented Thermal Pad, Cross, Dog Bone, D Shape, Custom Polygon)
- `apertures` — aperture instances per pad; stores dimensions, radius, rotation, and all Section 6 computed metrics
- `aperture_polygon_vertices` — explicit vertex geometry for `CUSTOM_POLYGON` apertures (Section 8 Gerber-readiness)
- `aperture_revisions` — append-only revision snapshots

### Section 4 — Engineering Strategy Library
- `engineering_strategies` — reusable strategies (e.g. QFN thermal pad → Window Pane, 12% reduction)
- `engineering_strategy_package_families` — supported families (many-to-many, beyond the primary family)
- `engineering_strategy_defects` — defects a strategy addresses
- `engineering_strategy_references` — citations/references
- `engineering_strategy_revisions` — append-only revision snapshots

### Section 5 — Stencil Defect Knowledge
- `stencil_defect_types` — global catalog of the 9 stencil-specific defects (Bridging, Insufficient Paste, Excess Paste, Poor Paste Release, Aperture Clogging, Paste Smearing, Paste Beading, Thermal Pad Voiding, Slumping), each with a default severity and confidence
- `stencil_defect_root_causes`, `stencil_defect_prevention_methods`, `stencil_defect_recommended_apertures`, `stencil_defect_recommended_strategies`, `stencil_defect_package_families` — satellite knowledge tables

Scope note: this catalog is limited to stencil print-process defects. It intentionally excludes SPI/AOI inspection outcomes, which are out of Version 1 scope.

### Section 6 — Engineering Calculations
- `pad_engineering_calculations` — append-only, fully traceable calculation history (area ratio, aspect ratio, paste volume, aperture area, aperture perimeter, stencil thickness, transfer efficiency, printability index) per pad/aperture pair
- Current computed values are also denormalized onto `apertures` for fast read access; `pad_engineering_calculations` is the audit trail of every recomputation

### Section 7 — Revision History
Implemented via the `*_revisions` append-only tables (land patterns, apertures, engineering strategies), each populated automatically by trigger on insert/update, following the same revision-history pattern as prior modules.

### Section 8 — Future Compatibility
`aperture_polygon_vertices` stores explicit, ordered (x, y) vertex coordinates so a future Gerber-generation module can emit `CUSTOM_POLYGON` apertures directly without re-deriving geometry. All aperture and pad dimensions are stored in millimeters with consistent precision to support direct coordinate export.

## Key engineering calculations implemented

| Metric | Formula basis |
|---|---|
| Aperture area | Per-shape formula (rectangle, rounded rectangle, circle, oval, window pane/segmented thermal pad, custom polygon via shoelace formula) |
| Aperture perimeter | Per-shape formula |
| Area ratio | IPC-7525: aperture area / (aperture perimeter × stencil thickness) |
| Aspect ratio | smaller opening dimension / larger opening dimension |
| Paste volume | aperture area × stencil thickness |
| Transfer efficiency | IPC-7525 empirical curve: (AR / (AR + 0.20)) × 100 |
| Printability index | Composite: 60% weight on area ratio vs. IPC minimum 0.66, 40% weight on aspect ratio vs. reference 0.60 |

All five functions are pure/stable and independently callable; `app.fn_db005_recompute_aperture_metrics()` orchestrates them and is invoked automatically by trigger whenever aperture geometry changes.

## Dependencies on existing infrastructure (DB001–DB004A), referenced not redefined
- `app.organizations(id)`
- `app.current_engineer_id()`
- `app.fn_apply_audit_columns()` — standard audit trigger
- `app.fn_touch_updated_at()` — standard trigger helper
- `app.fn_user_organization_id()` — standard RLS helper
- `app.fn_notify_change()` — standard notification helper
- `app.customers(id)` (DB002)

## Documented architectural decisions requiring follow-up

1. **`pads.source_component_reference`** is a soft reference (plain `uuid`, no FK constraint) to the originating DB003 component/placement record. It is intentionally not FK-enforced in this release pending confirmation of the exact DB003 table and column name. This preserves the DB003/DB005 separation of concerns and can be upgraded to a hard FK in a follow-up migration once confirmed.

2. **`app.fn_default_seed_organization_id()`** is referenced in `DB005_Seed.sql` as the seeding convention for a default/demo organization. If a different helper name or mechanism was used for organization-scoped seed data in DB001–DB004A, replace this reference before running the seed script.

## Design decisions within established conventions
- All 24 tables follow the established UUID PK, audit column, and naming conventions (`pk_`, `uq_`, `fk_`, `chk_`, `idx_`, `tg_`, `pol_`, `fn_` prefixes).
- `package_families` and `pads` are introduced as new canonical entities in this module per explicit architectural direction, not as a redesign of DB003.
- Shape/defect/surface-finish lookups use `CHECK` constraints rather than native Postgres enums, consistent with prior module style.
- Only one `is_current = true` row is permitted per land-pattern version chain and per pad's active aperture, enforced by trigger, mirroring the versioning discipline established in earlier modules.
- Global reference tables (`aperture_shape_types`, `stencil_defect_types`, `surface_finish_types`) are readable by all tenants and writable only by `service_role`, consistent with how shared engineering knowledge was handled in DB004A.

## Next module
DB006 — Stencil Design, next in the implementation queue.
