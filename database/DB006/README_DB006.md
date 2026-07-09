# DB006 — Stencil Generation Engine

## Status
Complete. Continues the established StencilPro Expert Enterprise database architecture (DB001–DB005) with no redesign, no architectural deviation, and no alternative approaches introduced. This is the final major database module required before the first working application.

## Purpose
DB006 generates, stores, compares, approves, and versions stencil designs. It implements — as durable, traceable data structures — the decision engine, comparison engine, override model, validation model, and approval workflow defined in `STENCILPRO_V1_ENGINEERING_SPECIFICATION.md`. That specification is the authoritative source for this module's engineering logic; DB006 does not redesign it.

**Mission data flow implemented by this module:**

```
PCB Pads (DB005) → Engineering Rules (DB005) → Land Patterns (DB005)
→ Aperture Strategies (DB005) → Manufacturing Calculations (DB006, reusing DB005 formulas)
→ Approved Stencil Design (DB006)
```

DB006 does **not** generate Gerber files. It prepares the data structures required for a future Gerber/SVG/DXF/IPC-2581 generation module (Section 10).

## Files in this module

| File | Purpose |
|---|---|
| `DB006_StencilEngine.sql` | Core schema: 16 tables across Sections 1–7 |
| `DB006_Functions.sql` | Metric recomputation (reusing DB005 formulas), validation, decision recording, override application, comparison generation, revision snapshots, approval state machine |
| `DB006_Indexes.sql` | FK indexes, org-scoped composites, partial "current row" indexes, GIN indexes on revision/snapshot jsonb |
| `DB006_Triggers.sql` | Audit triggers, metric recomputation and validation triggers (ordered), revision-logging triggers, release-immutability enforcement, single-current-row enforcement, decision-change notifications |
| `DB006_RLS.sql` | Row-level security: organization isolation, split select/write policies on soft-deletable tables |
| `DB006_Seed.sql` | Fabrication capability reference data (minimum web width / aperture width / corner radius) per stencil technology |
| `README_DB006.md` | This file |

## Schema overview by section

### Section 1 — Stencil Projects
- `stencil_projects` — every stencil generated for a PCB revision; supports multiple revisions, thicknesses, and manufacturing variants (`PROTOTYPE`/`PRODUCTION`), gated by `release_status`
- `stencil_project_revisions` — append-only revision snapshots (jsonb)
- `stencil_project_approvals` — fully traceable log of every release-status state transition

### Section 2 — Stencil Layers
- `stencil_layers` — top/bottom layers per project; `layer_technology` (Laser Cut, Electroformed, Chemical Etched, Electropolished) supports future compatibility for multiple stencil manufacturing technologies
- `stencil_step_regions` — step-stencil regions within a layer, each with its own thickness
- `stencil_step_region_vertices` — explicit boundary polygon per step region, Gerber/DXF-export-ready

### Section 3 — Generated Apertures
- `generated_apertures` — every generated aperture, with the **complete traceability chain** the module was tasked to guarantee: pad, package family, land pattern (and the specific land pattern *revision* used), source aperture definition, engineering strategy (and the specific strategy *revision* used). Stores geometry, rotation, offset, reduction, paste %, and all Section 6 (Engineering Spec) computed metrics.
- `generated_aperture_polygon_vertices` — explicit vertex geometry for `CUSTOM_POLYGON` generated apertures
- `generated_aperture_revisions` — append-only revision snapshots

### Section 4 — Engineering Decisions
- `aperture_recommendations` — every candidate recommendation considered for a generated aperture (original and alternatives), each carrying its `rule_precedence_level` (mirroring Engineering Spec Section 8.2's precedence order) and the **four individually stored confidence components** from Engineering Spec Section 8.4 (classification, rule specificity, metric margin, data completeness) — not a single opaque score
- `aperture_decisions` — current decision state (approved/rejected/overridden), selected recommendation, engineer comments, decision reason, explanation
- `aperture_decision_history` — append-only approval history log

### Section 5 — Comparison Engine
- `aperture_comparisons` — comparisons between original pad, generated aperture, engineer-modified aperture, and previous revision, storing geometry/area/paste-volume/area-ratio/transfer-efficiency deltas, per Engineering Spec Section 9's baseline-vs-scenario comparison pattern

### Section 6 — Manual Engineering Overrides
- `aperture_overrides` — append-only log of every manual override (shape, reduction, rotation, dimensions, paste %, corner radius, window count, segmentation), always recording engineer, timestamp, reason, previous value, and new value

### Section 7 — Stencil Validation
- `stencil_fabrication_capabilities` — organization-specific minimum web width / minimum aperture width / minimum corner radius per stencil technology, the concrete engineering reference validation is checked against
- `aperture_validations` — validation results (area ratio, aspect ratio, minimum web width, minimum aperture width, manufacturability, unsupported geometry) with risk level and pass/warning/error status

### Section 8 — Approval Workflow
Implemented via `stencil_projects.release_status` (Draft → Engineering Review → Approved → Released → Archived), enforced as a strict state machine by `app.fn_db006_transition_stencil_status()`, with every transition logged immutably in `stencil_project_approvals`.

### Section 9 — Revision History
- `stencil_project_revisions` and `generated_aperture_revisions` provide append-only, fully traceable revision history.
- **Immutability after release is enforced at the trigger level**, not just by convention: `tg_stencil_projects_prevent_modify_after_release` raises an exception on any attempt to modify a `RELEASED` or `ARCHIVED` stencil project other than the `RELEASED → ARCHIVED` transition. All further modification must go through `app.fn_db006_create_next_stencil_revision()`, which creates a new `DRAFT` revision rather than mutating the released one.

### Section 10 — Future Gerber Compatibility
No Gerber, SVG, DXF, or IPC-2581 generation is implemented in this module, per instruction. What is implemented: explicit, ordered vertex storage for step-stencil region boundaries and for `CUSTOM_POLYGON` generated apertures, and dimensionally consistent millimeter-based geometry throughout, so a future export module can consume these structures directly.

## Key engineering logic reused, not redefined

Per the Engineering Specification's own principle that the same physical formulas govern any aperture regardless of where it lives in the schema, DB006 calls DB005's calculation functions **directly**:

- `app.fn_db005_calculate_aperture_area()`
- `app.fn_db005_calculate_aperture_perimeter()`
- `app.fn_db005_calculate_area_ratio()`
- `app.fn_db005_calculate_aspect_ratio()`
- `app.fn_db005_calculate_paste_volume()`
- `app.fn_db005_calculate_transfer_efficiency()`
- `app.fn_db005_calculate_printability_index()`

The only new calculation logic DB006 introduces is a `CUSTOM_POLYGON` area/perimeter pair (`app.fn_db006_calculate_generated_polygon_area/perimeter`), required only because DB006's custom-polygon vertices live in a different table (`generated_aperture_polygon_vertices`) than DB005's (`aperture_polygon_vertices`) — the shoelace-formula logic itself is identical, not reinvented.

## Decision engine traceability (Engineering Spec Sections 1.3, 8, 10)

Every `aperture_recommendation` row is required to carry a non-null `rationale`, and `aperture_recommendations` stores the individual confidence components rather than a single number, so the "why" behind a recommendation — required by Engineering Spec Section 1.3 — is queryable data, not something reconstructed after the fact. `aperture_decisions` and `aperture_decision_history` together implement the human-approval philosophy from Engineering Spec Section 1.4: no recommendation reaches `APPROVED` status on `generated_apertures` without a decision record naming who decided and why.

## Dependencies on existing infrastructure, referenced not redefined

**DB001:** `app.organizations(id)`, `app.current_engineer_id()`, `app.fn_apply_audit_columns()`, `app.fn_touch_updated_at()`, `app.fn_user_organization_id()`, `app.fn_notify_change()`
**DB002:** `app.projects(id)`
**DB005:** `app.package_families(id)`, `app.pads(id)`, `app.land_patterns(id)`, `app.land_pattern_revisions(id)`, `app.apertures(id)`, `app.aperture_shape_types(id)`, `app.engineering_strategies(id)`, `app.engineering_strategy_revisions(id)`, and all seven `fn_db005_calculate_*` functions listed above

## Documented architectural decisions requiring follow-up

1. **`stencil_projects.pcb_revision_reference`** is a soft reference (plain `uuid`, no FK constraint) to the originating DB003 PCB revision record, following the same documented pattern established in DB005 for `pads.source_component_reference`. Not FK-enforced pending confirmation of the exact DB003 table/column name.
2. **`aperture_recommendations.rule_reference_id`** is intentionally polymorphic and not FK-enforced, since `rule_reference_type` may point to a land pattern, an engineering strategy, a defect rule, or a manual entry — four different tables. Application code (or a future `CHECK`-style validation function) is responsible for confirming the reference resolves against the table implied by `rule_reference_type`.
3. **`app.fn_default_seed_organization_id()`** is referenced in `DB006_Seed.sql`, consistent with its use in `DB005_Seed.sql`. Replace if a different seeding helper was used in DB001–DB004A.

## Design decisions within established conventions
- All 16 tables follow the established UUID PK, audit column, and naming conventions (`pk_`, `uq_`, `fk_`, `chk_`, `idx_`, `tg_`, `pol_`, `fn_` prefixes).
- `generated_apertures` and `stencil_projects` follow the same version/`is_current`/single-current-row-by-trigger pattern established for `land_patterns` and `apertures` in DB005.
- State enumerations (`release_status`, `layer_side`, `layer_technology`, `decision_status`, `validation_type`, `override_field`, `comparison_type`) use `CHECK` constraints rather than lookup tables, consistent with DB005's approach to simple state values; `stencil_fabrication_capabilities` is a genuine reference table (not just an enum) because it carries organization-specific numeric engineering data, not just a fixed label set.
- Trigger execution order on `generated_apertures` is made deterministic by naming (`..._1_recompute_metrics`, `..._2_validate`, `..._3_log_revision`), since Postgres fires same-timing triggers in name order and the revision snapshot must reflect post-computation, post-validation state.
- RLS follows the split select/write policy pattern established in DB005 to avoid a permissive `FOR ALL` policy silently defeating a soft-delete filter through OR-combination.

## Next steps
With DB001–DB006 complete, the core StencilPro Expert Enterprise database — core system, projects/customers, PCB assemblies, engineering knowledge, land pattern/aperture intelligence, and the stencil generation engine itself — is in place. This is the database foundation the first working application (Version 1 scope, per the engineering specification) will be built against. Future Gerber/SVG/DXF/IPC-2581 export, SPI/AOI integration, and any production-learning capability remain out of scope, per Engineering Spec Section 12, until explicitly assigned.
