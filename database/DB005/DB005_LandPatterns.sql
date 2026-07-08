-- =============================================================================
-- StencilPro Expert Enterprise
-- DB005: Land Pattern & Aperture Intelligence Engine
-- File: DB005_LandPatterns.sql
-- Purpose: Core schema objects (tables, constraints) for DB005.
--
-- Scope:
--   Section 1 - Land Pattern Library
--   Section 2 - Pad Intelligence
--   Section 3 - Stencil Aperture Library
--   Section 4 - Engineering Strategy Library
--   Section 5 - Stencil Defect Knowledge
--   Section 6 - Engineering Calculations
--   Section 7 - Revision History
--   Section 8 - Future Compatibility (Gerber generation readiness)
--
-- Architectural principle (established this module):
--   DB003 answers "what exists on the PCB?"
--   DB005 answers "how should each pad be manufactured using a stencil?"
--
-- Dependencies on existing infrastructure (NOT redefined here):
--   - app.organizations(id)                        [DB001]
--   - app.current_engineer_id()                     [DB001]
--   - app.fn_apply_audit_columns()                  [DB001 - standard audit trigger]
--   - app.fn_touch_updated_at()                     [DB001 - standard trigger helper]
--   - app.fn_user_organization_id()                 [DB001 - standard RLS helper]
--   - app.fn_notify_change()                        [DB001 - standard notification helper]
--   - app.customers(id)                             [DB002]
--
-- Note on DB003 linkage:
--   The canonical Pad entity (Section 2) stores a soft reference
--   (source_component_reference) back to the originating PCB component /
--   placement record owned by DB003. This is intentionally NOT a hard FK in
--   this release, pending confirmation of the exact DB003 table/column name.
--   This preserves the architectural separation: DB003 owns "what exists on
--   the PCB", DB005 owns "how it is manufactured".
-- =============================================================================

SET search_path = app, public;

-- =============================================================================
-- SECTION 3 (lookup, defined early - referenced by Sections 1 and 2)
-- Stencil Aperture Shape Types
-- =============================================================================

CREATE TABLE app.aperture_shape_types (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    shape_code                  text            NOT NULL,
    shape_name                  text            NOT NULL,
    requires_radius             boolean         NOT NULL DEFAULT false,
    requires_segment_config     boolean         NOT NULL DEFAULT false,
    requires_polygon_geometry   boolean         NOT NULL DEFAULT false,
    description                 text            NULL,
    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_aperture_shape_types PRIMARY KEY (id),
    CONSTRAINT uq_aperture_shape_types_code UNIQUE (shape_code),
    CONSTRAINT chk_aperture_shape_types_code CHECK (shape_code IN (
        'RECTANGLE', 'ROUNDED_RECTANGLE', 'SQUARE', 'CIRCLE', 'OVAL',
        'HOME_PLATE', 'INVERTED_HOME_PLATE', 'WINDOW_PANE',
        'SEGMENTED_THERMAL_PAD', 'CROSS', 'DOG_BONE', 'D_SHAPE', 'CUSTOM_POLYGON'
    ))
);

COMMENT ON TABLE app.aperture_shape_types IS
    'DB005 Section 3: canonical stencil aperture shape lookup, shared by pad geometry and aperture geometry.';

-- =============================================================================
-- SECTION 5 (lookup, defined early - referenced by Section 4 link tables)
-- Stencil Defect Type catalog
-- =============================================================================

CREATE TABLE app.stencil_defect_types (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    defect_code                  text           NOT NULL,
    defect_name                  text           NOT NULL,
    description                   text          NULL,
    default_severity              text          NOT NULL,
    default_confidence             numeric(5,2) NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_stencil_defect_types PRIMARY KEY (id),
    CONSTRAINT uq_stencil_defect_types_code UNIQUE (defect_code),
    CONSTRAINT chk_stencil_defect_types_code CHECK (defect_code IN (
        'BRIDGING', 'INSUFFICIENT_PASTE', 'EXCESS_PASTE', 'POOR_PASTE_RELEASE',
        'APERTURE_CLOGGING', 'PASTE_SMEARING', 'PASTE_BEADING',
        'THERMAL_PAD_VOIDING', 'SLUMPING'
    )),
    CONSTRAINT chk_stencil_defect_types_severity CHECK (default_severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_stencil_defect_types_confidence CHECK (
        default_confidence IS NULL OR (default_confidence >= 0 AND default_confidence <= 100)
    )
);

COMMENT ON TABLE app.stencil_defect_types IS
    'DB005 Section 5: canonical stencil-related defect catalog (print-process defects only, not SPI/AOI outcomes). Defined early in file for FK ordering; see Section 5 grouping below for its satellite tables.';

-- =============================================================================
-- SECTION 1: Land Pattern Library
-- =============================================================================

-- Master canonical Package Family library (DB005-owned, per architecture directive).
CREATE TABLE app.package_families (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    family_code                 text            NOT NULL,
    family_name                 text            NOT NULL,
    category                    text            NOT NULL,
    description                 text            NULL,
    typical_pin_count_min       integer         NULL,
    typical_pin_count_max       integer         NULL,
    has_thermal_pad             boolean         NOT NULL DEFAULT false,
    standard_reference          text            NULL,
    version                     integer         NOT NULL DEFAULT 1,
    is_current                  boolean         NOT NULL DEFAULT true,
    status                      text            NOT NULL DEFAULT 'ACTIVE',

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_package_families PRIMARY KEY (id),
    CONSTRAINT fk_package_families_org FOREIGN KEY (organization_id)
        REFERENCES app.organizations (id),
    CONSTRAINT uq_package_families_code UNIQUE (organization_id, family_code),
    CONSTRAINT chk_package_families_category CHECK (category IN (
        'PASSIVE', 'DISCRETE', 'IC_LEADED', 'IC_LEADLESS', 'BGA_CSP',
        'CONNECTOR', 'ELECTROMECHANICAL', 'CRYSTAL_OSCILLATOR', 'LED', 'OTHER'
    )),
    CONSTRAINT chk_package_families_status CHECK (status IN ('DRAFT', 'ACTIVE', 'DEPRECATED')),
    CONSTRAINT chk_package_families_pin_range CHECK (
        typical_pin_count_min IS NULL OR typical_pin_count_max IS NULL
        OR typical_pin_count_min <= typical_pin_count_max
    )
);

COMMENT ON TABLE app.package_families IS
    'DB005: canonical engineering Package Family library used across land patterns, apertures, strategies and defect knowledge. Owned by DB005, not DB003.';

CREATE TABLE app.land_patterns (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    package_family_id           uuid            NOT NULL,
    customer_id                 uuid            NULL,
    source_type                 text            NOT NULL,
    land_pattern_code           text            NOT NULL,
    land_pattern_name           text            NOT NULL,
    ipc_reference               text            NULL,
    pitch_mm                    numeric(8,4)    NULL,
    span_x_mm                   numeric(8,4)    NULL,
    span_y_mm                   numeric(8,4)    NULL,
    pad_count                   integer         NOT NULL,
    version                     integer         NOT NULL DEFAULT 1,
    is_current                  boolean         NOT NULL DEFAULT true,
    status                      text            NOT NULL DEFAULT 'DRAFT',
    approved_by                 uuid            NULL,
    approved_at                 timestamptz     NULL,
    notes                       text            NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_land_patterns PRIMARY KEY (id),
    CONSTRAINT fk_land_patterns_org FOREIGN KEY (organization_id)
        REFERENCES app.organizations (id),
    CONSTRAINT fk_land_patterns_package_family FOREIGN KEY (package_family_id)
        REFERENCES app.package_families (id),
    CONSTRAINT fk_land_patterns_customer FOREIGN KEY (customer_id)
        REFERENCES app.customers (id),
    CONSTRAINT uq_land_patterns_code UNIQUE (organization_id, land_pattern_code, version),
    CONSTRAINT chk_land_patterns_source_type CHECK (source_type IN ('IPC', 'COMPANY', 'CUSTOMER')),
    CONSTRAINT chk_land_patterns_status CHECK (status IN ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'DEPRECATED')),
    CONSTRAINT chk_land_patterns_pad_count CHECK (pad_count > 0),
    CONSTRAINT chk_land_patterns_customer_source CHECK (
        (source_type = 'CUSTOMER' AND customer_id IS NOT NULL)
        OR (source_type <> 'CUSTOMER')
    )
);

COMMENT ON TABLE app.land_patterns IS
    'DB005 Section 1: IPC, company and customer land patterns, versioned with approval workflow.';

CREATE TABLE app.land_pattern_pads (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    land_pattern_id             uuid            NOT NULL,
    pad_index                   integer         NOT NULL,
    pad_role                    text            NOT NULL DEFAULT 'SIGNAL',
    x_offset_mm                 numeric(8,4)    NOT NULL,
    y_offset_mm                 numeric(8,4)    NOT NULL,
    pad_width_mm                numeric(8,4)    NOT NULL,
    pad_height_mm               numeric(8,4)    NOT NULL,
    pad_shape_type_id           uuid            NOT NULL,
    rotation_degrees            numeric(6,2)    NOT NULL DEFAULT 0,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_land_pattern_pads PRIMARY KEY (id),
    CONSTRAINT fk_land_pattern_pads_org FOREIGN KEY (organization_id)
        REFERENCES app.organizations (id),
    CONSTRAINT fk_land_pattern_pads_land_pattern FOREIGN KEY (land_pattern_id)
        REFERENCES app.land_patterns (id),
    CONSTRAINT fk_land_pattern_pads_shape_type FOREIGN KEY (pad_shape_type_id)
        REFERENCES app.aperture_shape_types (id),
    CONSTRAINT uq_land_pattern_pads_index UNIQUE (land_pattern_id, pad_index),
    CONSTRAINT chk_land_pattern_pads_role CHECK (pad_role IN ('SIGNAL', 'THERMAL', 'GROUND', 'MECHANICAL', 'NC'))
);

COMMENT ON TABLE app.land_pattern_pads IS
    'DB005 Section 1: individual pad positions and geometry within a land pattern definition.';

CREATE TABLE app.land_pattern_revisions (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    land_pattern_id             uuid            NOT NULL,
    revision_number             integer         NOT NULL,
    snapshot                    jsonb           NOT NULL,
    change_summary              text            NULL,
    previous_status             text            NULL,
    new_status                  text            NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_land_pattern_revisions PRIMARY KEY (id),
    CONSTRAINT fk_land_pattern_revisions_org FOREIGN KEY (organization_id)
        REFERENCES app.organizations (id),
    CONSTRAINT fk_land_pattern_revisions_land_pattern FOREIGN KEY (land_pattern_id)
        REFERENCES app.land_patterns (id),
    CONSTRAINT uq_land_pattern_revisions_number UNIQUE (land_pattern_id, revision_number)
);

COMMENT ON TABLE app.land_pattern_revisions IS
    'DB005 Section 1 / Section 7: append-only revision history for land patterns.';

CREATE TABLE app.land_pattern_approvals (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    land_pattern_id             uuid            NOT NULL,
    requested_by                uuid            NOT NULL DEFAULT app.current_engineer_id(),
    requested_at                timestamptz     NOT NULL DEFAULT now(),
    approver_id                 uuid            NULL,
    approval_status             text            NOT NULL DEFAULT 'PENDING',
    approval_notes              text            NULL,
    decided_at                  timestamptz     NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_land_pattern_approvals PRIMARY KEY (id),
    CONSTRAINT fk_land_pattern_approvals_org FOREIGN KEY (organization_id)
        REFERENCES app.organizations (id),
    CONSTRAINT fk_land_pattern_approvals_land_pattern FOREIGN KEY (land_pattern_id)
        REFERENCES app.land_patterns (id),
    CONSTRAINT chk_land_pattern_approvals_status CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED'))
);

COMMENT ON TABLE app.land_pattern_approvals IS
    'DB005 Section 1: engineer approval workflow instances for land pattern promotion.';

-- =============================================================================
-- SECTION 2: Pad Intelligence
-- =============================================================================

CREATE TABLE app.surface_finish_types (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    finish_code                 text            NOT NULL,
    finish_name                 text            NOT NULL,
    description                 text            NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_surface_finish_types PRIMARY KEY (id),
    CONSTRAINT uq_surface_finish_types_code UNIQUE (finish_code),
    CONSTRAINT chk_surface_finish_types_code CHECK (finish_code IN (
        'ENIG', 'HASL', 'LEAD_FREE_HASL', 'OSP', 'IMMERSION_TIN',
        'IMMERSION_SILVER', 'ENEPIG', 'HARD_GOLD'
    ))
);

COMMENT ON TABLE app.surface_finish_types IS
    'DB005 Section 2: PCB surface finish lookup used for pad compatibility analysis.';

CREATE TABLE app.pad_surface_finish_compatibility (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    package_family_id           uuid            NOT NULL,
    surface_finish_id           uuid            NOT NULL,
    compatibility_rating        text            NOT NULL,
    notes                       text            NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_pad_surface_finish_compatibility PRIMARY KEY (id),
    CONSTRAINT fk_psfc_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_psfc_package_family FOREIGN KEY (package_family_id) REFERENCES app.package_families (id),
    CONSTRAINT fk_psfc_surface_finish FOREIGN KEY (surface_finish_id) REFERENCES app.surface_finish_types (id),
    CONSTRAINT uq_psfc_family_finish UNIQUE (package_family_id, surface_finish_id),
    CONSTRAINT chk_psfc_rating CHECK (compatibility_rating IN ('PREFERRED', 'COMPATIBLE', 'NOT_RECOMMENDED'))
);

COMMENT ON TABLE app.pad_surface_finish_compatibility IS
    'DB005 Section 2: surface finish compatibility rating per package family.';

-- Canonical Pad entity. DB005 owns this model; DB003 does not define a pad entity.
CREATE TABLE app.pads (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,

    -- Soft reference only. Not enforced as FK in this release; see file header note.
    source_component_reference  uuid            NULL,

    land_pattern_pad_id         uuid            NULL,
    package_family_id           uuid            NOT NULL,
    pad_role                    text            NOT NULL DEFAULT 'SIGNAL',

    shape_type_id                uuid           NOT NULL,
    width_mm                     numeric(8,4)   NOT NULL,
    height_mm                    numeric(8,4)   NOT NULL,
    corner_radius_mm              numeric(8,4)  NOT NULL DEFAULT 0,
    rotation_degrees              numeric(6,2)  NOT NULL DEFAULT 0,

    paste_mask_expansion_mm       numeric(8,4)  NOT NULL DEFAULT 0,
    solder_mask_type               text         NULL,
    solder_mask_expansion_mm       numeric(8,4) NOT NULL DEFAULT 0,

    has_via                        boolean      NOT NULL DEFAULT false,
    via_type                       text         NULL,
    via_diameter_mm                numeric(8,4) NULL,
    via_tented                     boolean      NOT NULL DEFAULT false,

    surface_finish_id               uuid        NULL,

    version                         integer     NOT NULL DEFAULT 1,
    is_current                      boolean     NOT NULL DEFAULT true,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_pads PRIMARY KEY (id),
    CONSTRAINT fk_pads_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_pads_land_pattern_pad FOREIGN KEY (land_pattern_pad_id) REFERENCES app.land_pattern_pads (id),
    CONSTRAINT fk_pads_package_family FOREIGN KEY (package_family_id) REFERENCES app.package_families (id),
    CONSTRAINT fk_pads_shape_type FOREIGN KEY (shape_type_id) REFERENCES app.aperture_shape_types (id),
    CONSTRAINT fk_pads_surface_finish FOREIGN KEY (surface_finish_id) REFERENCES app.surface_finish_types (id),
    CONSTRAINT chk_pads_role CHECK (pad_role IN ('SIGNAL', 'THERMAL', 'GROUND', 'MECHANICAL', 'NC')),
    CONSTRAINT chk_pads_solder_mask_type CHECK (solder_mask_type IS NULL OR solder_mask_type IN ('SMD', 'NSMD')),
    CONSTRAINT chk_pads_via_type CHECK (via_type IS NULL OR via_type IN (
        'THROUGH', 'MICROVIA', 'VIA_IN_PAD', 'TENTED', 'PLUGGED'
    )),
    CONSTRAINT chk_pads_via_consistency CHECK (
        (has_via = false AND via_type IS NULL AND via_diameter_mm IS NULL)
        OR (has_via = true)
    )
);

COMMENT ON TABLE app.pads IS
    'DB005 Section 2: canonical Pad Intelligence model. The stencil engine operates from this table. Answers "how should each pad be manufactured?"';

-- =============================================================================
-- SECTION 3: Stencil Aperture Library
-- =============================================================================

CREATE TABLE app.apertures (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    pad_id                       uuid           NOT NULL,
    shape_type_id                uuid           NOT NULL,

    length_mm                    numeric(8,4)   NOT NULL,
    width_mm                     numeric(8,4)   NOT NULL,
    corner_radius_mm              numeric(8,4)  NOT NULL DEFAULT 0,
    rotation_degrees              numeric(6,2)  NOT NULL DEFAULT 0,

    segment_count                 integer       NULL,
    segment_gap_mm                 numeric(8,4) NULL,
    window_count                   integer       NULL,

    reduction_percent               numeric(5,2) NOT NULL DEFAULT 0,
    expansion_percent               numeric(5,2) NOT NULL DEFAULT 0,
    stencil_thickness_mm            numeric(6,4) NOT NULL,

    -- Section 6: Engineering Calculations (current computed values)
    computed_area_mm2               numeric(12,6) NULL,
    computed_perimeter_mm            numeric(10,4) NULL,
    aspect_ratio                     numeric(8,4) NULL,
    area_ratio                       numeric(8,4) NULL,
    paste_volume_mm3                  numeric(12,6) NULL,
    transfer_efficiency_pct           numeric(5,2) NULL,
    printability_index                numeric(6,4) NULL,

    version                          integer      NOT NULL DEFAULT 1,
    is_current                       boolean      NOT NULL DEFAULT true,
    status                           text         NOT NULL DEFAULT 'DRAFT',

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_apertures PRIMARY KEY (id),
    CONSTRAINT fk_apertures_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_apertures_pad FOREIGN KEY (pad_id) REFERENCES app.pads (id),
    CONSTRAINT fk_apertures_shape_type FOREIGN KEY (shape_type_id) REFERENCES app.aperture_shape_types (id),
    CONSTRAINT chk_apertures_status CHECK (status IN ('DRAFT', 'APPROVED', 'DEPRECATED')),
    CONSTRAINT chk_apertures_reduction_range CHECK (reduction_percent >= -100 AND reduction_percent <= 100),
    CONSTRAINT chk_apertures_expansion_range CHECK (expansion_percent >= -100 AND expansion_percent <= 100),
    CONSTRAINT chk_apertures_stencil_thickness CHECK (stencil_thickness_mm > 0)
);

COMMENT ON TABLE app.apertures IS
    'DB005 Section 3: stencil aperture instances derived from pads, supporting all common aperture strategies.';

CREATE TABLE app.aperture_polygon_vertices (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    aperture_id                  uuid           NOT NULL,
    vertex_index                  integer       NOT NULL,
    x_mm                            numeric(8,4) NOT NULL,
    y_mm                            numeric(8,4) NOT NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_aperture_polygon_vertices PRIMARY KEY (id),
    CONSTRAINT fk_apv_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_apv_aperture FOREIGN KEY (aperture_id) REFERENCES app.apertures (id),
    CONSTRAINT uq_apv_index UNIQUE (aperture_id, vertex_index)
);

COMMENT ON TABLE app.aperture_polygon_vertices IS
    'DB005 Section 3 / Section 8: explicit vertex geometry for CUSTOM_POLYGON apertures, stored to enable direct Gerber generation by future modules.';

CREATE TABLE app.aperture_revisions (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    aperture_id                  uuid           NOT NULL,
    revision_number                integer       NOT NULL,
    snapshot                        jsonb        NOT NULL,
    change_summary                  text        NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_aperture_revisions PRIMARY KEY (id),
    CONSTRAINT fk_aperture_revisions_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_aperture_revisions_aperture FOREIGN KEY (aperture_id) REFERENCES app.apertures (id),
    CONSTRAINT uq_aperture_revisions_number UNIQUE (aperture_id, revision_number)
);

COMMENT ON TABLE app.aperture_revisions IS
    'DB005 Section 3 / Section 7: append-only revision history for apertures.';

-- =============================================================================
-- SECTION 4: Engineering Strategy Library
-- =============================================================================

CREATE TABLE app.engineering_strategies (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    strategy_code                text           NOT NULL,
    strategy_name                text           NOT NULL,
    primary_package_family_id     uuid          NOT NULL,
    recommended_shape_type_id     uuid          NOT NULL,
    recommended_reduction_percent  numeric(5,2) NULL,
    recommended_expansion_percent  numeric(5,2) NULL,
    rationale                    text           NOT NULL,
    expected_benefit              text          NULL,
    status                       text           NOT NULL DEFAULT 'ACTIVE',
    version                      integer        NOT NULL DEFAULT 1,
    is_current                   boolean        NOT NULL DEFAULT true,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,
    is_deleted                  boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_engineering_strategies PRIMARY KEY (id),
    CONSTRAINT fk_engineering_strategies_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_engineering_strategies_family FOREIGN KEY (primary_package_family_id) REFERENCES app.package_families (id),
    CONSTRAINT fk_engineering_strategies_shape FOREIGN KEY (recommended_shape_type_id) REFERENCES app.aperture_shape_types (id),
    CONSTRAINT uq_engineering_strategies_code UNIQUE (organization_id, strategy_code, version),
    CONSTRAINT chk_engineering_strategies_status CHECK (status IN ('DRAFT', 'ACTIVE', 'DEPRECATED'))
);

COMMENT ON TABLE app.engineering_strategies IS
    'DB005 Section 4: reusable engineering strategy library (e.g. QFN thermal pad -> window pane, 12% reduction).';

CREATE TABLE app.engineering_strategy_package_families (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    engineering_strategy_id      uuid           NOT NULL,
    package_family_id            uuid           NOT NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_espf PRIMARY KEY (id),
    CONSTRAINT fk_espf_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_espf_strategy FOREIGN KEY (engineering_strategy_id) REFERENCES app.engineering_strategies (id),
    CONSTRAINT fk_espf_family FOREIGN KEY (package_family_id) REFERENCES app.package_families (id),
    CONSTRAINT uq_espf_strategy_family UNIQUE (engineering_strategy_id, package_family_id)
);

COMMENT ON TABLE app.engineering_strategy_package_families IS
    'DB005 Section 4: supported package families for an engineering strategy (many-to-many).';

CREATE TABLE app.engineering_strategy_defects (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    engineering_strategy_id      uuid           NOT NULL,
    defect_type_id                uuid          NOT NULL,
    relationship_note             text          NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_esd PRIMARY KEY (id),
    CONSTRAINT fk_esd_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_esd_strategy FOREIGN KEY (engineering_strategy_id) REFERENCES app.engineering_strategies (id),
    CONSTRAINT fk_esd_defect FOREIGN KEY (defect_type_id) REFERENCES app.stencil_defect_types (id),
    CONSTRAINT uq_esd_strategy_defect UNIQUE (engineering_strategy_id, defect_type_id)
);

COMMENT ON TABLE app.engineering_strategy_defects IS
    'DB005 Section 4: stencil defects addressed by a given engineering strategy.';

CREATE TABLE app.engineering_strategy_references (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    engineering_strategy_id      uuid           NOT NULL,
    reference_type                text          NOT NULL,
    reference_citation             text         NOT NULL,
    reference_url                   text         NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_esr PRIMARY KEY (id),
    CONSTRAINT fk_esr_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_esr_strategy FOREIGN KEY (engineering_strategy_id) REFERENCES app.engineering_strategies (id),
    CONSTRAINT chk_esr_type CHECK (reference_type IN ('IPC_STANDARD', 'INTERNAL_DOCUMENT', 'PUBLICATION', 'OTHER'))
);

COMMENT ON TABLE app.engineering_strategy_references IS
    'DB005 Section 4: supporting references/citations for an engineering strategy.';

CREATE TABLE app.engineering_strategy_revisions (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    engineering_strategy_id      uuid           NOT NULL,
    revision_number                integer       NOT NULL,
    snapshot                        jsonb        NOT NULL,
    change_summary                  text        NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_esrev PRIMARY KEY (id),
    CONSTRAINT fk_esrev_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_esrev_strategy FOREIGN KEY (engineering_strategy_id) REFERENCES app.engineering_strategies (id),
    CONSTRAINT uq_esrev_number UNIQUE (engineering_strategy_id, revision_number)
);

COMMENT ON TABLE app.engineering_strategy_revisions IS
    'DB005 Section 4 / Section 7: append-only revision history for engineering strategies.';

-- =============================================================================
-- SECTION 5: Stencil Defect Knowledge
-- (defined here structurally; FK ordering resolved via deferred creation above
--  for engineering_strategy_defects, which references stencil_defect_types)
-- =============================================================================

-- stencil_defect_types is created earlier in this file (immediately after
-- aperture_shape_types) so that Section 4's engineering_strategy_defects
-- link table can reference it. Satellite tables below complete Section 5.

CREATE TABLE app.stencil_defect_root_causes (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    defect_type_id                uuid          NOT NULL,
    root_cause_description        text          NOT NULL,
    likelihood                    text          NOT NULL DEFAULT 'MEDIUM',

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_sdrc PRIMARY KEY (id),
    CONSTRAINT fk_sdrc_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_sdrc_defect FOREIGN KEY (defect_type_id) REFERENCES app.stencil_defect_types (id),
    CONSTRAINT chk_sdrc_likelihood CHECK (likelihood IN ('LOW', 'MEDIUM', 'HIGH'))
);

COMMENT ON TABLE app.stencil_defect_root_causes IS
    'DB005 Section 5: root causes contributing to each stencil defect type.';

CREATE TABLE app.stencil_defect_prevention_methods (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    defect_type_id                uuid          NOT NULL,
    prevention_method              text         NOT NULL,
    effectiveness_rating           text         NOT NULL DEFAULT 'MEDIUM',

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_sdpm PRIMARY KEY (id),
    CONSTRAINT fk_sdpm_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_sdpm_defect FOREIGN KEY (defect_type_id) REFERENCES app.stencil_defect_types (id),
    CONSTRAINT chk_sdpm_effectiveness CHECK (effectiveness_rating IN ('LOW', 'MEDIUM', 'HIGH'))
);

COMMENT ON TABLE app.stencil_defect_prevention_methods IS
    'DB005 Section 5: prevention methods for each stencil defect type.';

CREATE TABLE app.stencil_defect_recommended_apertures (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    defect_type_id                uuid          NOT NULL,
    shape_type_id                  uuid         NOT NULL,
    recommended_reduction_percent   numeric(5,2) NULL,
    recommended_expansion_percent   numeric(5,2) NULL,
    notes                           text        NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_sdra PRIMARY KEY (id),
    CONSTRAINT fk_sdra_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_sdra_defect FOREIGN KEY (defect_type_id) REFERENCES app.stencil_defect_types (id),
    CONSTRAINT fk_sdra_shape FOREIGN KEY (shape_type_id) REFERENCES app.aperture_shape_types (id)
);

COMMENT ON TABLE app.stencil_defect_recommended_apertures IS
    'DB005 Section 5: recommended aperture shape and reduction/expansion strategy per defect type.';

CREATE TABLE app.stencil_defect_recommended_strategies (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    defect_type_id                uuid          NOT NULL,
    engineering_strategy_id       uuid          NOT NULL,
    confidence                     numeric(5,2) NULL,

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_sdrs PRIMARY KEY (id),
    CONSTRAINT fk_sdrs_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_sdrs_defect FOREIGN KEY (defect_type_id) REFERENCES app.stencil_defect_types (id),
    CONSTRAINT fk_sdrs_strategy FOREIGN KEY (engineering_strategy_id) REFERENCES app.engineering_strategies (id),
    CONSTRAINT uq_sdrs_defect_strategy UNIQUE (defect_type_id, engineering_strategy_id),
    CONSTRAINT chk_sdrs_confidence CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 100))
);

COMMENT ON TABLE app.stencil_defect_recommended_strategies IS
    'DB005 Section 5: engineering strategies recommended to mitigate a given defect type, with confidence.';

CREATE TABLE app.stencil_defect_package_families (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    defect_type_id                uuid          NOT NULL,
    package_family_id             uuid          NOT NULL,
    susceptibility_rating          text         NOT NULL DEFAULT 'MEDIUM',

    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_sdpf PRIMARY KEY (id),
    CONSTRAINT fk_sdpf_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_sdpf_defect FOREIGN KEY (defect_type_id) REFERENCES app.stencil_defect_types (id),
    CONSTRAINT fk_sdpf_family FOREIGN KEY (package_family_id) REFERENCES app.package_families (id),
    CONSTRAINT uq_sdpf_defect_family UNIQUE (defect_type_id, package_family_id),
    CONSTRAINT chk_sdpf_susceptibility CHECK (susceptibility_rating IN ('LOW', 'MEDIUM', 'HIGH'))
);

COMMENT ON TABLE app.stencil_defect_package_families IS
    'DB005 Section 5: package families most susceptible to a given stencil defect type.';

-- =============================================================================
-- SECTION 6: Engineering Calculations (traceable calculation history)
-- =============================================================================

CREATE TABLE app.pad_engineering_calculations (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             uuid            NOT NULL,
    pad_id                        uuid          NOT NULL,
    aperture_id                    uuid         NOT NULL,

    area_ratio                     numeric(8,4) NULL,
    aspect_ratio                   numeric(8,4) NULL,
    paste_volume_mm3                numeric(12,6) NULL,
    aperture_area_mm2               numeric(12,6) NULL,
    aperture_perimeter_mm            numeric(10,4) NULL,
    stencil_thickness_mm             numeric(6,4) NULL,
    transfer_efficiency_pct          numeric(5,2) NULL,
    printability_index               numeric(6,4) NULL,

    calculation_method              text         NOT NULL DEFAULT 'STANDARD_IPC',
    calculated_at                   timestamptz  NOT NULL DEFAULT now(),
    calculated_by                    uuid        NOT NULL DEFAULT app.current_engineer_id(),

    CONSTRAINT pk_pad_engineering_calculations PRIMARY KEY (id),
    CONSTRAINT fk_pec_org FOREIGN KEY (organization_id) REFERENCES app.organizations (id),
    CONSTRAINT fk_pec_pad FOREIGN KEY (pad_id) REFERENCES app.pads (id),
    CONSTRAINT fk_pec_aperture FOREIGN KEY (aperture_id) REFERENCES app.apertures (id)
);

COMMENT ON TABLE app.pad_engineering_calculations IS
    'DB005 Section 6: append-only, fully traceable calculation history per pad/aperture pair (area ratio, aspect ratio, paste volume, transfer efficiency, printability index, etc).';
