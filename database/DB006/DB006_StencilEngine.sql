-- =============================================================================
-- StencilPro Expert Enterprise
-- DB006: Stencil Generation Engine
-- File: DB006_StencilEngine.sql
-- Purpose: Core schema objects (tables, constraints) for DB006.
--
-- Scope:
--   Section 1  - Stencil Projects
--   Section 2  - Stencil Layers
--   Section 3  - Generated Apertures
--   Section 4  - Engineering Decisions
--   Section 5  - Comparison Engine
--   Section 6  - Manual Engineering Overrides
--   Section 7  - Stencil Validation
--   Section 8  - Approval Workflow
--   Section 9  - Revision History
--   Section 10 - Future Gerber Compatibility
--
-- Authoritative source: STENCILPRO_V1_ENGINEERING_SPECIFICATION.md.
-- This module implements that specification's decision engine, comparison
-- engine, override model, and validation model as durable, traceable data
-- structures. It does not redesign the specification's engineering logic
-- (Sections 6-9 of the spec) and does not generate Gerber output.
--
-- Dependencies on existing infrastructure (NOT redefined here):
--   - app.organizations(id)                          [DB001]
--   - app.current_engineer_id()                      [DB001]
--   - app.fn_apply_audit_columns()                    [DB001]
--   - app.fn_touch_updated_at()                        [DB001]
--   - app.fn_user_organization_id()                    [DB001]
--   - app.fn_notify_change()                            [DB001]
--   - app.projects(id)                                  [DB002]
--   - app.package_families(id)                          [DB005]
--   - app.pads(id)                                      [DB005]
--   - app.land_patterns(id), app.land_pattern_revisions(id)   [DB005]
--   - app.apertures(id), app.aperture_shape_types(id)    [DB005]
--   - app.engineering_strategies(id), app.engineering_strategy_revisions(id) [DB005]
--   - app.fn_db005_calculate_aperture_area / _perimeter / _area_ratio /
--     _aspect_ratio / _paste_volume / _transfer_efficiency /
--     _printability_index()                             [DB005 - reused directly]
--
-- Note on DB003 linkage:
--   Stencil projects reference the PCB revision they were generated for via
--   a soft reference (pcb_revision_reference), following the same
--   documented convention established in DB005 for pads.source_component_reference.
--   This is intentionally not FK-enforced pending confirmation of the exact
--   DB003 table/column name.
-- =============================================================================

SET search_path = app, public;

-- =============================================================================
-- SECTION 1: Stencil Projects
-- =============================================================================

CREATE TABLE app.stencil_projects (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    project_id                  uuid            NOT NULL,

    -- Soft reference only. Not enforced as FK in this release; see file header note.
    pcb_revision_reference       uuid           NULL,

    stencil_code                 text           NOT NULL,
    stencil_name                  text          NOT NULL,
    variant_type                   text         NOT NULL DEFAULT 'PRODUCTION',
    stencil_thickness_mm            numeric(6,4) NOT NULL,

    revision_number                 integer      NOT NULL DEFAULT 1,
    is_current                       boolean     NOT NULL DEFAULT true,
    release_status                    text       NOT NULL DEFAULT 'DRAFT',

    approved_by                     uuid          NULL,
    approved_at                     timestamptz   NULL,
    released_by                     uuid          NULL,
    released_at                     timestamptz   NULL,
    archived_at                     timestamptz   NULL,

    notes                           text          NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_stencil_projects PRIMARY KEY (id),
    CONSTRAINT fk_stencil_projects_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_stencil_projects_project FOREIGN KEY (project_id) REFERENCES app.projects (id),
    CONSTRAINT uq_stencil_projects_code UNIQUE (organization_id, stencil_code, revision_number),
    CONSTRAINT chk_stencil_projects_variant CHECK (variant_type IN ('PROTOTYPE', 'PRODUCTION')),
    CONSTRAINT chk_stencil_projects_release_status CHECK (release_status IN (
        'DRAFT', 'ENGINEERING_REVIEW', 'APPROVED', 'RELEASED', 'ARCHIVED'
    )),
    CONSTRAINT chk_stencil_projects_thickness CHECK (stencil_thickness_mm > 0)
);

COMMENT ON TABLE app.stencil_projects IS
    'DB006 Section 1: every stencil generated for a PCB revision. Supports multiple revisions, thicknesses, variants (prototype/production), and the release approval workflow (Section 8).';

CREATE TABLE app.stencil_project_revisions (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    stencil_project_id          uuid            NOT NULL,
    revision_number              integer         NOT NULL,
    snapshot                     jsonb           NOT NULL,
    change_summary                text          NULL,
    previous_status                 text        NULL,
    new_status                      text        NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_stencil_project_revisions PRIMARY KEY (id),
    CONSTRAINT fk_spr_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_spr_stencil_project FOREIGN KEY (stencil_project_id) REFERENCES app.stencil_projects (id),
    CONSTRAINT uq_spr_revision UNIQUE (stencil_project_id, revision_number)
);

COMMENT ON TABLE app.stencil_project_revisions IS
    'DB006 Section 9: append-only revision history for stencil projects. Every stencil revision is immutable after release; all modifications create a new revision, snapshotted here.';

CREATE TABLE app.stencil_project_approvals (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    stencil_project_id          uuid            NOT NULL,
    from_status                  text           NULL,
    to_status                     text          NOT NULL,
    transitioned_by                uuid         NOT NULL DEFAULT app.current_engineer_id(),
    transitioned_at                 timestamptz NOT NULL DEFAULT now(),
    notes                            text        NULL,

    CONSTRAINT pk_stencil_project_approvals PRIMARY KEY (id),
    CONSTRAINT fk_spa_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_spa_stencil_project FOREIGN KEY (stencil_project_id) REFERENCES app.stencil_projects (id),
    CONSTRAINT chk_spa_to_status CHECK (to_status IN (
        'DRAFT', 'ENGINEERING_REVIEW', 'APPROVED', 'RELEASED', 'ARCHIVED'
    )),
    CONSTRAINT chk_spa_from_status CHECK (from_status IS NULL OR from_status IN (
        'DRAFT', 'ENGINEERING_REVIEW', 'APPROVED', 'RELEASED', 'ARCHIVED'
    ))
);

COMMENT ON TABLE app.stencil_project_approvals IS
    'DB006 Section 8: fully traceable log of every release-status state transition for a stencil project (Draft -> Engineering Review -> Approved -> Released -> Archived).';

-- =============================================================================
-- SECTION 2: Stencil Layers
-- =============================================================================

CREATE TABLE app.stencil_layers (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    stencil_project_id          uuid            NOT NULL,
    layer_side                   text           NOT NULL,
    layer_technology              text          NOT NULL DEFAULT 'LASER_CUT',
    default_thickness_mm            numeric(6,4) NOT NULL,
    is_step_stencil                  boolean     NOT NULL DEFAULT false,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_stencil_layers PRIMARY KEY (id),
    CONSTRAINT fk_stencil_layers_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_stencil_layers_project FOREIGN KEY (stencil_project_id) REFERENCES app.stencil_projects (id),
    CONSTRAINT uq_stencil_layers_side UNIQUE (stencil_project_id, layer_side),
    CONSTRAINT chk_stencil_layers_side CHECK (layer_side IN ('TOP', 'BOTTOM')),
    CONSTRAINT chk_stencil_layers_technology CHECK (layer_technology IN (
        'LASER_CUT', 'ELECTROFORMED', 'CHEMICAL_ETCHED', 'ELECTROPOLISHED'
    )),
    CONSTRAINT chk_stencil_layers_thickness CHECK (default_thickness_mm > 0)
);

COMMENT ON TABLE app.stencil_layers IS
    'DB006 Section 2: top/bottom stencil layers per project. layer_technology supports future compatibility for multiple stencil manufacturing technologies.';

CREATE TABLE app.stencil_step_regions (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    stencil_layer_id            uuid            NOT NULL,
    region_name                  text           NOT NULL,
    thickness_mm                   numeric(6,4) NOT NULL,
    region_order                    integer      NOT NULL DEFAULT 1,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_stencil_step_regions PRIMARY KEY (id),
    CONSTRAINT fk_ssr_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_ssr_layer FOREIGN KEY (stencil_layer_id) REFERENCES app.stencil_layers (id),
    CONSTRAINT uq_ssr_region_name UNIQUE (stencil_layer_id, region_name),
    CONSTRAINT chk_ssr_thickness CHECK (thickness_mm > 0)
);

COMMENT ON TABLE app.stencil_step_regions IS
    'DB006 Section 2: step-stencil regions within a layer, each with its own thickness (per Engineering Spec Section 9.1 step-stencil scenario).';

CREATE TABLE app.stencil_step_region_vertices (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    stencil_step_region_id       uuid           NOT NULL,
    vertex_index                   integer      NOT NULL,
    x_mm                             numeric(10,4) NOT NULL,
    y_mm                             numeric(10,4) NOT NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_ssrv PRIMARY KEY (id),
    CONSTRAINT fk_ssrv_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_ssrv_region FOREIGN KEY (stencil_step_region_id) REFERENCES app.stencil_step_regions (id),
    CONSTRAINT uq_ssrv_index UNIQUE (stencil_step_region_id, vertex_index)
);

COMMENT ON TABLE app.stencil_step_region_vertices IS
    'DB006 Section 2 / Section 10: explicit boundary polygon for a step-stencil region, stored to support future Gerber/DXF/IPC-2581 export.';

-- =============================================================================
-- SECTION 3: Generated Apertures
-- =============================================================================

CREATE TABLE app.generated_apertures (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,

    stencil_layer_id             uuid           NOT NULL,
    stencil_step_region_id        uuid          NULL,

    -- Full traceability chain (Mission statement: Pad -> Rules -> Land Pattern
    -- -> Aperture Strategy -> Manufacturing Calculations -> Approved Design)
    pad_id                        uuid          NOT NULL,
    package_family_id              uuid         NOT NULL,
    land_pattern_id                  uuid       NULL,
    land_pattern_revision_id          uuid       NULL,
    source_aperture_definition_id      uuid     NULL,
    engineering_strategy_id             uuid    NULL,
    engineering_strategy_revision_id     uuid   NULL,

    shape_type_id                         uuid  NOT NULL,
    length_mm                             numeric(8,4) NOT NULL,
    width_mm                              numeric(8,4) NOT NULL,
    corner_radius_mm                       numeric(8,4) NOT NULL DEFAULT 0,
    rotation_degrees                       numeric(6,2) NOT NULL DEFAULT 0,
    offset_x_mm                            numeric(8,4) NOT NULL DEFAULT 0,
    offset_y_mm                            numeric(8,4) NOT NULL DEFAULT 0,

    reduction_percent                      numeric(5,2) NOT NULL DEFAULT 0,
    expansion_percent                      numeric(5,2) NOT NULL DEFAULT 0,
    paste_coverage_percent                  numeric(5,2) NULL,

    segment_count                          integer      NULL,
    segment_gap_mm                          numeric(8,4) NULL,
    window_count                            integer      NULL,

    stencil_thickness_mm                    numeric(6,4) NOT NULL,

    -- Section 6 (Manufacturing Calculations)
    computed_area_mm2                       numeric(12,6) NULL,
    computed_perimeter_mm                    numeric(10,4) NULL,
    area_ratio                               numeric(8,4) NULL,
    aspect_ratio                             numeric(8,4) NULL,
    paste_volume_mm3                          numeric(12,6) NULL,
    transfer_efficiency_pct                   numeric(5,2) NULL,
    printability_index                        numeric(6,4) NULL,

    version                                   integer     NOT NULL DEFAULT 1,
    is_current                                 boolean    NOT NULL DEFAULT true,
    status                                     text       NOT NULL DEFAULT 'DRAFT',

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_generated_apertures PRIMARY KEY (id),
    CONSTRAINT fk_ga_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_ga_stencil_layer FOREIGN KEY (stencil_layer_id) REFERENCES app.stencil_layers (id),
    CONSTRAINT fk_ga_step_region FOREIGN KEY (stencil_step_region_id) REFERENCES app.stencil_step_regions (id),
    CONSTRAINT fk_ga_pad FOREIGN KEY (pad_id) REFERENCES app.pads (id),
    CONSTRAINT fk_ga_package_family FOREIGN KEY (package_family_id) REFERENCES app.package_families (id),
    CONSTRAINT fk_ga_land_pattern FOREIGN KEY (land_pattern_id) REFERENCES app.land_patterns (id),
    CONSTRAINT fk_ga_land_pattern_revision FOREIGN KEY (land_pattern_revision_id) REFERENCES app.land_pattern_revisions (id),
    CONSTRAINT fk_ga_source_aperture FOREIGN KEY (source_aperture_definition_id) REFERENCES app.apertures (id),
    CONSTRAINT fk_ga_strategy FOREIGN KEY (engineering_strategy_id) REFERENCES app.engineering_strategies (id),
    CONSTRAINT fk_ga_strategy_revision FOREIGN KEY (engineering_strategy_revision_id) REFERENCES app.engineering_strategy_revisions (id),
    CONSTRAINT fk_ga_shape_type FOREIGN KEY (shape_type_id) REFERENCES app.aperture_shape_types (id),
    CONSTRAINT chk_ga_status CHECK (status IN ('DRAFT', 'APPROVED', 'REJECTED', 'SUPERSEDED')),
    CONSTRAINT chk_ga_reduction_range CHECK (reduction_percent >= -100 AND reduction_percent <= 100),
    CONSTRAINT chk_ga_expansion_range CHECK (expansion_percent >= -100 AND expansion_percent <= 100),
    CONSTRAINT chk_ga_thickness CHECK (stencil_thickness_mm > 0)
);

COMMENT ON TABLE app.generated_apertures IS
    'DB006 Section 3: every generated aperture, fully traceable to its pad, package family, land pattern (and revision), source aperture definition, and engineering strategy (and revision) per Engineering Spec Section 8.1.';

CREATE TABLE app.generated_aperture_polygon_vertices (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    generated_aperture_id         uuid          NOT NULL,
    vertex_index                    integer     NOT NULL,
    x_mm                              numeric(8,4) NOT NULL,
    y_mm                              numeric(8,4) NOT NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_gapv PRIMARY KEY (id),
    CONSTRAINT fk_gapv_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_gapv_aperture FOREIGN KEY (generated_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT uq_gapv_index UNIQUE (generated_aperture_id, vertex_index)
);

COMMENT ON TABLE app.generated_aperture_polygon_vertices IS
    'DB006 Section 3 / Section 10: explicit vertex geometry for CUSTOM_POLYGON generated apertures, ready for future Gerber/SVG/DXF/IPC-2581 export.';

CREATE TABLE app.generated_aperture_revisions (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    generated_aperture_id         uuid          NOT NULL,
    revision_number                 integer     NOT NULL,
    snapshot                          jsonb     NOT NULL,
    change_summary                     text     NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_gar PRIMARY KEY (id),
    CONSTRAINT fk_gar_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_gar_aperture FOREIGN KEY (generated_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT uq_gar_revision UNIQUE (generated_aperture_id, revision_number)
);

COMMENT ON TABLE app.generated_aperture_revisions IS
    'DB006 Section 9: append-only revision history for generated apertures.';

-- =============================================================================
-- SECTION 4: Engineering Decisions
-- =============================================================================

CREATE TABLE app.aperture_recommendations (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    generated_aperture_id         uuid          NOT NULL,

    recommendation_rank            integer      NOT NULL DEFAULT 1,
    is_selected                     boolean     NOT NULL DEFAULT false,

    shape_type_id                     uuid      NOT NULL,
    length_mm                          numeric(8,4) NOT NULL,
    width_mm                           numeric(8,4) NOT NULL,
    corner_radius_mm                    numeric(8,4) NOT NULL DEFAULT 0,
    reduction_percent                    numeric(5,2) NOT NULL DEFAULT 0,
    expansion_percent                     numeric(5,2) NOT NULL DEFAULT 0,

    rule_precedence_level                  text    NOT NULL,
    rule_reference_type                     text   NULL,
    rule_reference_id                        uuid  NULL,

    rationale                                text  NOT NULL,

    confidence_score                          numeric(5,2) NULL,
    confidence_classification_component        numeric(5,2) NULL,
    confidence_rule_specificity_component       numeric(5,2) NULL,
    confidence_metric_margin_component           numeric(5,2) NULL,
    confidence_data_completeness_component        numeric(5,2) NULL,

    printability_index                             numeric(6,4) NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_aperture_recommendations PRIMARY KEY (id),
    CONSTRAINT fk_ar_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_ar_aperture FOREIGN KEY (generated_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT fk_ar_shape_type FOREIGN KEY (shape_type_id) REFERENCES app.aperture_shape_types (id),
    CONSTRAINT uq_ar_rank UNIQUE (generated_aperture_id, recommendation_rank),
    CONSTRAINT chk_ar_precedence CHECK (rule_precedence_level IN (
        'ENGINEER_OVERRIDE', 'CUSTOMER_RULE', 'COMPANY_RULE', 'DEFECT_PREVENTION_RULE',
        'PACKAGE_BASELINE', 'IPC_DEFAULT'
    )),
    CONSTRAINT chk_ar_reference_type CHECK (rule_reference_type IS NULL OR rule_reference_type IN (
        'LAND_PATTERN', 'ENGINEERING_STRATEGY', 'DEFECT_RULE', 'MANUAL'
    )),
    CONSTRAINT chk_ar_confidence CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 100))
);

COMMENT ON TABLE app.aperture_recommendations IS
    'DB006 Section 4: every candidate recommendation considered for a generated aperture (original, alternative), per Engineering Spec Section 8.5 scoring. rule_reference_id is intentionally polymorphic (see rule_reference_type) and not FK-enforced, since it may point to a land pattern, engineering strategy, defect rule, or a manual entry.';

CREATE TABLE app.aperture_decisions (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    generated_aperture_id         uuid          NOT NULL,

    decision_status                text         NOT NULL DEFAULT 'PENDING',
    selected_recommendation_id       uuid       NULL,

    engineer_comments                  text     NULL,
    decision_reason                     text    NULL,
    confidence_score                     numeric(5,2) NULL,
    explanation                           text  NULL,

    decided_by                            uuid  NULL,
    decided_at                            timestamptz NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_aperture_decisions PRIMARY KEY (id),
    CONSTRAINT fk_ad_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_ad_aperture FOREIGN KEY (generated_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT fk_ad_recommendation FOREIGN KEY (selected_recommendation_id) REFERENCES app.aperture_recommendations (id),
    CONSTRAINT uq_ad_aperture UNIQUE (generated_aperture_id),
    CONSTRAINT chk_ad_status CHECK (decision_status IN ('PENDING', 'APPROVED', 'REJECTED', 'OVERRIDDEN')),
    CONSTRAINT chk_ad_confidence CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 100))
);

COMMENT ON TABLE app.aperture_decisions IS
    'DB006 Section 4: current engineering decision state for a generated aperture. One current decision per aperture; full change history is in aperture_decision_history (Section 8/9).';

CREATE TABLE app.aperture_decision_history (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    generated_aperture_id         uuid          NOT NULL,

    decision_status                 text         NOT NULL,
    selected_recommendation_id        uuid       NULL,
    engineer_comments                  text      NULL,
    decision_reason                     text     NULL,
    confidence_score                     numeric(5,2) NULL,

    decided_by                            uuid   NOT NULL DEFAULT app.current_engineer_id(),
    decided_at                             timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_adh PRIMARY KEY (id),
    CONSTRAINT fk_adh_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_adh_aperture FOREIGN KEY (generated_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT fk_adh_recommendation FOREIGN KEY (selected_recommendation_id) REFERENCES app.aperture_recommendations (id),
    CONSTRAINT chk_adh_status CHECK (decision_status IN ('PENDING', 'APPROVED', 'REJECTED', 'OVERRIDDEN'))
);

COMMENT ON TABLE app.aperture_decision_history IS
    'DB006 Section 4 / Section 9: append-only approval history log for every decision made on a generated aperture.';

-- =============================================================================
-- SECTION 5: Comparison Engine
-- =============================================================================

CREATE TABLE app.aperture_comparisons (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    generated_aperture_id         uuid          NOT NULL,

    comparison_type                text          NOT NULL,
    baseline_reference_type          text        NOT NULL,
    baseline_aperture_id               uuid      NULL,

    geometry_delta_summary               text    NULL,
    area_delta_mm2                        numeric(12,6) NULL,
    paste_volume_delta_mm3                 numeric(12,6) NULL,
    area_ratio_delta                        numeric(8,4) NULL,
    transfer_efficiency_delta_pct             numeric(5,2) NULL,
    risk_delta_notes                          text NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_aperture_comparisons PRIMARY KEY (id),
    CONSTRAINT fk_ac_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_ac_aperture FOREIGN KEY (generated_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT fk_ac_baseline_aperture FOREIGN KEY (baseline_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT chk_ac_comparison_type CHECK (comparison_type IN (
        'PAD_VS_GENERATED', 'GENERATED_VS_ENGINEER_MODIFIED', 'CURRENT_VS_PREVIOUS_REVISION'
    )),
    CONSTRAINT chk_ac_baseline_type CHECK (baseline_reference_type IN ('PAD', 'APERTURE'))
);

COMMENT ON TABLE app.aperture_comparisons IS
    'DB006 Section 5: comparison results between original pad, generated aperture, engineer-modified aperture, and previous revision, per Engineering Spec Section 9 What-If comparison structure.';

-- =============================================================================
-- SECTION 6: Manual Engineering Overrides
-- =============================================================================

CREATE TABLE app.aperture_overrides (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    generated_aperture_id         uuid          NOT NULL,

    override_field                  text         NOT NULL,
    previous_value                    jsonb      NOT NULL,
    new_value                          jsonb     NOT NULL,
    override_reason                     text     NOT NULL,

    engineer_id                          uuid    NOT NULL DEFAULT app.current_engineer_id(),
    overridden_at                         timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_aperture_overrides PRIMARY KEY (id),
    CONSTRAINT fk_ao_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_ao_aperture FOREIGN KEY (generated_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT chk_ao_field CHECK (override_field IN (
        'SHAPE', 'REDUCTION', 'ROTATION', 'DIMENSIONS', 'PASTE_PERCENT',
        'CORNER_RADIUS', 'WINDOW_COUNT', 'SEGMENTATION'
    ))
);

COMMENT ON TABLE app.aperture_overrides IS
    'DB006 Section 6: append-only log of every manual engineering override, recording engineer, timestamp, reason, previous value and new value.';

-- =============================================================================
-- SECTION 7: Stencil Validation
-- =============================================================================

CREATE TABLE app.stencil_fabrication_capabilities (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    layer_technology              text           NOT NULL,
    min_web_width_mm                numeric(6,4) NOT NULL,
    min_aperture_width_mm             numeric(6,4) NOT NULL,
    min_corner_radius_mm                numeric(6,4) NOT NULL DEFAULT 0,
    notes                                 text    NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_stencil_fabrication_capabilities PRIMARY KEY (id),
    CONSTRAINT fk_sfc_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT uq_sfc_technology UNIQUE (organization_id, layer_technology),
    CONSTRAINT chk_sfc_technology CHECK (layer_technology IN (
        'LASER_CUT', 'ELECTROFORMED', 'CHEMICAL_ETCHED', 'ELECTROPOLISHED'
    ))
);

COMMENT ON TABLE app.stencil_fabrication_capabilities IS
    'DB006 Section 7: minimum web width, minimum aperture width, and minimum corner radius the fabricator can reliably produce per stencil technology. Validation results are computed against these organization-specific capability limits.';

CREATE TABLE app.aperture_validations (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    generated_aperture_id         uuid          NOT NULL,

    validation_type                 text         NOT NULL,
    result_value                       numeric(12,6) NULL,
    threshold_value                     numeric(12,6) NULL,
    risk_level                            text    NOT NULL DEFAULT 'LOW',
    status                                  text  NOT NULL,
    message                                  text NULL,

    validated_at                  timestamptz     NOT NULL DEFAULT now(),
    validated_by                    uuid          NULL,

    CONSTRAINT pk_aperture_validations PRIMARY KEY (id),
    CONSTRAINT fk_av_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_av_aperture FOREIGN KEY (generated_aperture_id) REFERENCES app.generated_apertures (id),
    CONSTRAINT chk_av_type CHECK (validation_type IN (
        'AREA_RATIO', 'ASPECT_RATIO', 'MIN_WEB_WIDTH', 'MIN_APERTURE_WIDTH',
        'MANUFACTURABILITY', 'UNSUPPORTED_GEOMETRY'
    )),
    CONSTRAINT chk_av_risk_level CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_av_status CHECK (status IN ('PASS', 'WARNING', 'ERROR'))
);

COMMENT ON TABLE app.aperture_validations IS
    'DB006 Section 7: validation results for every generated aperture (area ratio, aspect ratio, minimum web width, minimum aperture width, manufacturability, unsupported geometry), each with a risk level and pass/warning/error status.';
