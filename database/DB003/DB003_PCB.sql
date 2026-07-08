-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-003: PCB Assemblies & Components
-- File: DB003_PCB.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Tables:
--   pcb_surface_finishes, pcb_materials, pcb_thickness_options,
--   board_manufacturers, assembly_manufacturers,
--   pcb_assemblies, pcb_revisions, pcb_layers, pcb_stackups,
--   assembly_variants, design_files,
--   electrical_nets, bom_revisions, bom_items,
--   components, component_revisions,
--   component_placements
-- =============================================================================
-- Prerequisites: DB001_Core_System.sql, DB002_Projects.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- REFERENCE / LOOKUP TABLES
-- (organization_id = NULL → system records available to all orgs)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: pcb_surface_finishes
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pcb_surface_finishes (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    name                    VARCHAR(100)    NOT NULL,
    abbreviation            VARCHAR(20)     NOT NULL,
    is_rohs_compliant       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_lead_free            BOOLEAN         NOT NULL DEFAULT TRUE,
    flatness_rating         VARCHAR(20)     NOT NULL DEFAULT 'good',
    coplanarity_um          NUMERIC(10,2)   NULL,
    shelf_life_months       INTEGER         NULL,
    solderability_rating    VARCHAR(20)     NOT NULL DEFAULT 'good',
    typical_thickness_um    NUMERIC(10,2)   NULL,
    wettability_notes       TEXT            NULL,
    ipc_specification       VARCHAR(50)     NULL,
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    is_system_record        BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_pcb_surface_finishes
        PRIMARY KEY (id),

    CONSTRAINT uq_pcb_surface_finishes_abbreviation
        UNIQUE (abbreviation),

    CONSTRAINT chk_pcb_surface_finishes_flatness
        CHECK (flatness_rating IN ('excellent','good','fair','poor')),

    CONSTRAINT chk_pcb_surface_finishes_solderability
        CHECK (solderability_rating IN ('excellent','good','fair','poor')),

    CONSTRAINT chk_pcb_surface_finishes_shelf_life
        CHECK (shelf_life_months IS NULL OR shelf_life_months > 0),

    CONSTRAINT chk_pcb_surface_finishes_coplanarity
        CHECK (coplanarity_um IS NULL OR coplanarity_um >= 0)
);

COMMENT ON TABLE pcb_surface_finishes IS
    'Reference lookup for PCB surface finish types and their engineering properties. '
    'Directly influences paste compatibility rules, paste volume recommendations, '
    'and wettability assessments in the Intelligence Engine. '
    'System records are read-only for all non-Super-Admin roles.';

COMMENT ON COLUMN pcb_surface_finishes.abbreviation IS 'Short technical code (e.g., ENIG, HASL-LF, ImAg, OSP, ENEPIG). Globally unique.';
COMMENT ON COLUMN pcb_surface_finishes.flatness_rating IS 'Surface planarity: excellent=ENIG/ENEPIG, good=ImAg, fair=ImSn, poor=HASL.';
COMMENT ON COLUMN pcb_surface_finishes.coplanarity_um IS 'Typical peak-to-valley surface height variation in micrometers. Critical for fine-pitch printing.';
COMMENT ON COLUMN pcb_surface_finishes.wettability_notes IS 'Engineering description of solder wetting behavior relevant to paste selection and reflow.';
COMMENT ON COLUMN pcb_surface_finishes.ipc_specification IS 'Governing IPC specification (e.g., IPC-4552 for ENIG, IPC-4553 for ImAg).';

-- ---------------------------------------------------------------------------
-- TABLE: pcb_materials
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pcb_materials (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    name                        VARCHAR(100)    NOT NULL,
    material_type               VARCHAR(30)     NOT NULL DEFAULT 'fr4',
    description                 TEXT            NULL,
    tg_min_c                    NUMERIC(6,2)    NULL,
    tg_max_c                    NUMERIC(6,2)    NULL,
    td_c                        NUMERIC(6,2)    NULL,
    cte_x_ppm_per_c             NUMERIC(8,4)    NULL,
    cte_z_ppm_per_c             NUMERIC(8,4)    NULL,
    dk_at_1ghz                  NUMERIC(8,4)    NULL,
    df_at_1ghz                  NUMERIC(8,4)    NULL,
    is_halogen_free             BOOLEAN         NOT NULL DEFAULT FALSE,
    is_rohs_compliant           BOOLEAN         NOT NULL DEFAULT TRUE,
    is_high_speed_rated         BOOLEAN         NOT NULL DEFAULT FALSE,
    max_operating_temp_c        NUMERIC(6,2)    NULL,
    typical_thickness_range     VARCHAR(50)     NULL,
    common_applications         TEXT            NULL,
    ipc_grade                   VARCHAR(20)     NULL,
    is_active                   BOOLEAN         NOT NULL DEFAULT TRUE,
    is_system_record            BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_pcb_materials
        PRIMARY KEY (id),

    CONSTRAINT uq_pcb_materials_name
        UNIQUE (name),

    CONSTRAINT chk_pcb_materials_type
        CHECK (material_type IN (
            'fr4','fr4_high_tg','rogers','polyimide','aluminum',
            'ceramic','ptfe','flex','rigid_flex','other'
        )),

    CONSTRAINT chk_pcb_materials_tg_range
        CHECK (tg_min_c IS NULL OR tg_max_c IS NULL OR tg_max_c >= tg_min_c)
);

COMMENT ON TABLE pcb_materials IS
    'Reference data for PCB laminate base materials. '
    'Properties drive thermal stress analysis and component compatibility checks. '
    'Tg (glass transition temperature) is critical for high-temperature reflow profiles.';

COMMENT ON COLUMN pcb_materials.tg_min_c IS 'Minimum glass transition temperature in °C (lower bound of grade range).';
COMMENT ON COLUMN pcb_materials.tg_max_c IS 'Maximum glass transition temperature in °C (upper bound of grade range).';
COMMENT ON COLUMN pcb_materials.td_c IS 'Decomposition temperature in °C. Should be well above reflow peak temperature.';
COMMENT ON COLUMN pcb_materials.cte_x_ppm_per_c IS 'Coefficient of thermal expansion in X-axis (ppm/°C). Affects BGA reliability.';
COMMENT ON COLUMN pcb_materials.cte_z_ppm_per_c IS 'Coefficient of thermal expansion in Z-axis (ppm/°C). Affects via barrel stress.';
COMMENT ON COLUMN pcb_materials.dk_at_1ghz IS 'Dielectric constant at 1 GHz. Relevant for high-speed signal integrity.';
COMMENT ON COLUMN pcb_materials.df_at_1ghz IS 'Dissipation factor at 1 GHz. Lower is better for high-frequency applications.';
COMMENT ON COLUMN pcb_materials.ipc_grade IS 'IPC-4101 laminate grade designation (e.g., /21, /24, /98, /99).';

-- ---------------------------------------------------------------------------
-- TABLE: pcb_thickness_options
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pcb_thickness_options (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    thickness_mm                NUMERIC(10,4)   NOT NULL,
    thickness_label             VARCHAR(20)     NOT NULL,
    is_standard                 BOOLEAN         NOT NULL DEFAULT TRUE,
    warpage_risk                VARCHAR(20)     NOT NULL DEFAULT 'low',
    typical_layer_count_range   VARCHAR(30)     NULL,
    smt_support_notes           TEXT            NULL,
    is_active                   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_pcb_thickness_options
        PRIMARY KEY (id),

    CONSTRAINT uq_pcb_thickness_options_thickness
        UNIQUE (thickness_mm),

    CONSTRAINT chk_pcb_thickness_options_thickness
        CHECK (thickness_mm > 0 AND thickness_mm <= 10.0),

    CONSTRAINT chk_pcb_thickness_options_warpage_risk
        CHECK (warpage_risk IN ('low','medium','high','very_high'))
);

COMMENT ON TABLE pcb_thickness_options IS
    'Standard PCB board thickness values. '
    'Board thickness affects stencil support strategy during printing, '
    'warpage risk during reflow, and via aspect ratio limitations.';

COMMENT ON COLUMN pcb_thickness_options.thickness_mm IS 'Board total finished thickness in millimeters.';
COMMENT ON COLUMN pcb_thickness_options.thickness_label IS 'Common label (e.g., 0.8mm, 1.6mm, 2.4mm, 3.2mm).';
COMMENT ON COLUMN pcb_thickness_options.warpage_risk IS 'Relative warpage risk during reflow: thin boards (<1.0mm) warp more.';
COMMENT ON COLUMN pcb_thickness_options.smt_support_notes IS 'Engineering notes on board support requirements during paste printing for this thickness.';

-- ---------------------------------------------------------------------------
-- TABLE: board_manufacturers
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS board_manufacturers (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id     UUID            NULL,
    name                VARCHAR(255)    NOT NULL,
    code                VARCHAR(20)     NULL,
    country             VARCHAR(2)      NULL,
    website_url         TEXT            NULL,
    technical_contact   VARCHAR(255)    NULL,
    contact_email       VARCHAR(255)    NULL,
    notes               TEXT            NULL,
    is_approved         BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    is_system_record    BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_board_manufacturers
        PRIMARY KEY (id),

    CONSTRAINT fk_board_manufacturers_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_board_manufacturers_country
        CHECK (country IS NULL OR LENGTH(country) = 2),

    CONSTRAINT chk_board_manufacturers_email
        CHECK (
            contact_email IS NULL OR
            contact_email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'
        )
);

COMMENT ON TABLE board_manufacturers IS
    'PCB fabrication house registry. organization_id = NULL means a system-level entry '
    'available to all organizations. is_approved tracks customer or quality-system approval status.';

COMMENT ON COLUMN board_manufacturers.is_approved IS 'TRUE if this manufacturer is on the approved vendor list for the owning organization.';
COMMENT ON COLUMN board_manufacturers.code IS 'Short internal code for this manufacturer used in part numbers and file naming.';

-- ---------------------------------------------------------------------------
-- TABLE: assembly_manufacturers
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS assembly_manufacturers (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id     UUID            NULL,
    name                VARCHAR(255)    NOT NULL,
    code                VARCHAR(20)     NULL,
    country             VARCHAR(2)      NULL,
    website_url         TEXT            NULL,
    technical_contact   VARCHAR(255)    NULL,
    contact_email       VARCHAR(255)    NULL,
    notes               TEXT            NULL,
    is_approved         BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    is_system_record    BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_assembly_manufacturers
        PRIMARY KEY (id),

    CONSTRAINT fk_assembly_manufacturers_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_assembly_manufacturers_country
        CHECK (country IS NULL OR LENGTH(country) = 2),

    CONSTRAINT chk_assembly_manufacturers_email
        CHECK (
            contact_email IS NULL OR
            contact_email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'
        )
);

COMMENT ON TABLE assembly_manufacturers IS
    'EMS (Electronics Manufacturing Services) and CM (Contract Manufacturer) registry. '
    'Tracks which assembly houses are approved for production of boards in this organization.';

-- =============================================================================
-- CORE PCB ENTITIES
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: pcb_assemblies
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pcb_assemblies (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             UUID            NOT NULL,
    project_id                  UUID            NOT NULL,
    product_id                  UUID            NULL,
    name                        VARCHAR(255)    NOT NULL,
    part_number                 VARCHAR(100)    NULL,
    description                 TEXT            NULL,
    board_length_mm             NUMERIC(10,4)   NULL,
    board_width_mm              NUMERIC(10,4)   NULL,
    board_thickness_mm          NUMERIC(10,4)   NULL,
    layer_count                 INTEGER         NULL,
    base_material_id            UUID            NULL,
    surface_finish_id           UUID            NULL,
    solder_mask_color           VARCHAR(20)     NOT NULL DEFAULT 'green',
    silkscreen_color            VARCHAR(20)     NOT NULL DEFAULT 'white',
    assembly_sides              VARCHAR(20)     NOT NULL DEFAULT 'top_only',
    outer_copper_weight_oz      NUMERIC(6,3)    NULL,
    inner_copper_weight_oz      NUMERIC(6,3)    NULL,
    tg_temperature_c            NUMERIC(6,2)    NULL,
    min_feature_size_mm         NUMERIC(10,4)   NULL,
    min_via_drill_mm            NUMERIC(10,4)   NULL,
    controlled_impedance        BOOLEAN         NOT NULL DEFAULT FALSE,
    has_press_fit_connectors    BOOLEAN         NOT NULL DEFAULT FALSE,
    has_edge_connectors         BOOLEAN         NOT NULL DEFAULT FALSE,
    has_castellated_holes       BOOLEAN         NOT NULL DEFAULT FALSE,
    has_blind_vias              BOOLEAN         NOT NULL DEFAULT FALSE,
    has_buried_vias             BOOLEAN         NOT NULL DEFAULT FALSE,
    has_back_drill              BOOLEAN         NOT NULL DEFAULT FALSE,
    board_manufacturer_id       UUID            NULL,
    gerber_storage_path         TEXT            NULL,
    odb_storage_path            TEXT            NULL,
    bom_storage_path            TEXT            NULL,
    is_deleted                  BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at                  TIMESTAMPTZ     NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_pcb_assemblies
        PRIMARY KEY (id),

    CONSTRAINT fk_pcb_assemblies_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_pcb_assemblies_project
        FOREIGN KEY (project_id)
        REFERENCES projects (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_pcb_assemblies_product
        FOREIGN KEY (product_id)
        REFERENCES products (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_pcb_assemblies_base_material
        FOREIGN KEY (base_material_id)
        REFERENCES pcb_materials (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_pcb_assemblies_surface_finish
        FOREIGN KEY (surface_finish_id)
        REFERENCES pcb_surface_finishes (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_pcb_assemblies_board_manufacturer
        FOREIGN KEY (board_manufacturer_id)
        REFERENCES board_manufacturers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_pcb_assemblies_solder_mask_color
        CHECK (solder_mask_color IN (
            'green','red','blue','black','white',
            'yellow','purple','orange','clear','other'
        )),

    CONSTRAINT chk_pcb_assemblies_silkscreen_color
        CHECK (silkscreen_color IN ('white','black','yellow','other')),

    CONSTRAINT chk_pcb_assemblies_assembly_sides
        CHECK (assembly_sides IN ('top_only','bottom_only','double_sided')),

    CONSTRAINT chk_pcb_assemblies_dimensions
        CHECK (
            board_length_mm IS NULL OR board_width_mm IS NULL OR
            (board_length_mm > 0 AND board_width_mm > 0)
        ),

    CONSTRAINT chk_pcb_assemblies_layer_count
        CHECK (layer_count IS NULL OR (layer_count > 0 AND layer_count <= 50)),

    CONSTRAINT chk_pcb_assemblies_copper_weight
        CHECK (outer_copper_weight_oz IS NULL OR outer_copper_weight_oz > 0),

    CONSTRAINT chk_pcb_assemblies_min_feature
        CHECK (min_feature_size_mm IS NULL OR min_feature_size_mm > 0),

    CONSTRAINT chk_pcb_assemblies_soft_delete
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL) OR
            (is_deleted = TRUE  AND deleted_at IS NOT NULL)
        )
);

COMMENT ON TABLE pcb_assemblies IS
    'Represents a specific PCB design — the physical board that drives all stencil engineering decisions. '
    'A PCB assembly is the engineering artifact that contains component placements, '
    'land patterns, and ultimately drives aperture design. '
    'All downstream stencil designs reference a specific PCB revision, not the assembly directly.';

COMMENT ON COLUMN pcb_assemblies.project_id IS 'Parent project. All assemblies must belong to a project.';
COMMENT ON COLUMN pcb_assemblies.part_number IS 'Internal engineering part number for this assembly.';
COMMENT ON COLUMN pcb_assemblies.board_length_mm IS 'Board X dimension in millimeters. Critical for stencil frame size selection.';
COMMENT ON COLUMN pcb_assemblies.board_width_mm IS 'Board Y dimension in millimeters.';
COMMENT ON COLUMN pcb_assemblies.board_thickness_mm IS 'Total finished board thickness in mm. Affects printing support and warpage risk.';
COMMENT ON COLUMN pcb_assemblies.assembly_sides IS 'Which sides carry SMT components: top_only, bottom_only, double_sided. Determines number of stencils required.';
COMMENT ON COLUMN pcb_assemblies.controlled_impedance IS 'TRUE if this PCB requires controlled impedance traces. Affects material and stack-up selection.';
COMMENT ON COLUMN pcb_assemblies.surface_finish_id IS 'PCB surface finish. Critical input to paste compatibility rules and wettability analysis.';
COMMENT ON COLUMN pcb_assemblies.gerber_storage_path IS 'Path in Supabase Storage to the Gerber file set for this assembly.';
COMMENT ON COLUMN pcb_assemblies.odb_storage_path IS 'Path in Supabase Storage to the ODB++ file for this assembly.';

-- ---------------------------------------------------------------------------
-- TABLE: pcb_revisions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pcb_revisions (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    pcb_assembly_id             UUID            NOT NULL,
    organization_id             UUID            NOT NULL,
    revision_code               VARCHAR(20)     NOT NULL,
    revision_date               DATE            NOT NULL DEFAULT CURRENT_DATE,
    released_by_engineer_id     UUID            NOT NULL,
    change_summary              TEXT            NULL,
    change_type                 VARCHAR(30)     NOT NULL DEFAULT 'minor_change',
    component_count             INTEGER         NULL,
    smt_component_count         INTEGER         NULL,
    unique_package_count        INTEGER         NULL,
    min_pitch_mm                NUMERIC(10,4)   NULL,
    has_bgas                    BOOLEAN         NOT NULL DEFAULT FALSE,
    has_qfns                    BOOLEAN         NOT NULL DEFAULT FALSE,
    has_01005_components        BOOLEAN         NOT NULL DEFAULT FALSE,
    has_0201_components         BOOLEAN         NOT NULL DEFAULT FALSE,
    has_step_stencil_requirement BOOLEAN        NOT NULL DEFAULT FALSE,
    has_mixed_technology        BOOLEAN         NOT NULL DEFAULT FALSE,
    has_paste_in_hole           BOOLEAN         NOT NULL DEFAULT FALSE,
    is_current_revision         BOOLEAN         NOT NULL DEFAULT TRUE,
    design_data_storage_path    TEXT            NULL,
    pick_place_storage_path     TEXT            NULL,
    notes                       TEXT            NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_pcb_revisions
        PRIMARY KEY (id),

    CONSTRAINT uq_pcb_revisions_assembly_code
        UNIQUE (pcb_assembly_id, revision_code),

    CONSTRAINT fk_pcb_revisions_pcb_assembly
        FOREIGN KEY (pcb_assembly_id)
        REFERENCES pcb_assemblies (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_pcb_revisions_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_pcb_revisions_released_by
        FOREIGN KEY (released_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_pcb_revisions_change_type
        CHECK (change_type IN (
            'initial_release','minor_change','major_change',
            'eco','prototype','production_release'
        )),

    CONSTRAINT chk_pcb_revisions_component_counts
        CHECK (
            component_count IS NULL OR component_count >= 0
        ),

    CONSTRAINT chk_pcb_revisions_smt_count
        CHECK (
            smt_component_count IS NULL OR
            component_count IS NULL OR
            smt_component_count <= component_count
        ),

    CONSTRAINT chk_pcb_revisions_min_pitch
        CHECK (min_pitch_mm IS NULL OR min_pitch_mm > 0)
);

COMMENT ON TABLE pcb_revisions IS
    'A specific revision of a PCB design. All stencil engineering work attaches to a '
    'PCB revision, never the PCB assembly directly. This ensures full traceability: '
    'every stencil design, component placement, and land pattern is anchored to '
    'an exact design state. '
    'Only one revision per assembly may have is_current_revision = TRUE (enforced by partial unique index).';

COMMENT ON COLUMN pcb_revisions.revision_code IS 'Human-readable revision code (e.g., A, B, C1, Rev3). Unique per assembly.';
COMMENT ON COLUMN pcb_revisions.change_type IS 'Classification of this revision relative to the previous one.';
COMMENT ON COLUMN pcb_revisions.min_pitch_mm IS 'Smallest component pin/ball pitch on this revision. Drives fine-pitch and ultra-fine-pitch rule group activation.';
COMMENT ON COLUMN pcb_revisions.has_bgas IS 'TRUE if any BGA package is present. Activates BGA rule group and X-ray inspection requirements.';
COMMENT ON COLUMN pcb_revisions.has_qfns IS 'TRUE if any QFN/LLP package is present. Activates thermal pad rule group.';
COMMENT ON COLUMN pcb_revisions.has_01005_components IS 'TRUE if 01005 passives are present. Activates ultra-fine-pitch and minimum stencil thickness rules.';
COMMENT ON COLUMN pcb_revisions.has_step_stencil_requirement IS 'TRUE if mixed pitch range requires a step stencil. Triggers step stencil design workflow.';
COMMENT ON COLUMN pcb_revisions.has_paste_in_hole IS 'TRUE if paste-in-hole (pin-in-paste) technique is required for any through-hole component.';
COMMENT ON COLUMN pcb_revisions.is_current_revision IS 'TRUE for the active design revision. Enforced unique via partial index.';
COMMENT ON COLUMN pcb_revisions.pick_place_storage_path IS 'Path in Supabase Storage to the pick-and-place (centroid) file for this revision.';

-- Partial unique index: only one current revision per PCB assembly
CREATE UNIQUE INDEX IF NOT EXISTS uq_pcb_revisions_current_revision
    ON pcb_revisions (pcb_assembly_id)
    WHERE is_current_revision = TRUE;

-- ---------------------------------------------------------------------------
-- TABLE: pcb_layers
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pcb_layers (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    pcb_assembly_id     UUID            NOT NULL,
    organization_id     UUID            NOT NULL,
    layer_number        INTEGER         NOT NULL,
    layer_name          VARCHAR(50)     NOT NULL,
    layer_type          VARCHAR(30)     NOT NULL DEFAULT 'signal',
    layer_side          VARCHAR(10)     NOT NULL DEFAULT 'inner',
    copper_weight_oz    NUMERIC(6,3)    NULL,
    dielectric_material VARCHAR(100)    NULL,
    dielectric_thickness_mm NUMERIC(10,4) NULL,
    copper_thickness_mm NUMERIC(10,4)   NULL,
    function_notes      TEXT            NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_pcb_layers
        PRIMARY KEY (id),

    CONSTRAINT uq_pcb_layers_assembly_number
        UNIQUE (pcb_assembly_id, layer_number),

    CONSTRAINT fk_pcb_layers_pcb_assembly
        FOREIGN KEY (pcb_assembly_id)
        REFERENCES pcb_assemblies (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_pcb_layers_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_pcb_layers_type
        CHECK (layer_type IN (
            'signal','power','ground','mixed',
            'dielectric','solder_mask','silkscreen','paste_mask'
        )),

    CONSTRAINT chk_pcb_layers_side
        CHECK (layer_side IN ('top','bottom','inner')),

    CONSTRAINT chk_pcb_layers_number
        CHECK (layer_number > 0 AND layer_number <= 50),

    CONSTRAINT chk_pcb_layers_copper_weight
        CHECK (copper_weight_oz IS NULL OR copper_weight_oz > 0)
);

COMMENT ON TABLE pcb_layers IS
    'Individual copper and dielectric layers within a PCB assembly. '
    'Supports full stack-up documentation for impedance calculations and '
    'manufacturing file verification.';

COMMENT ON COLUMN pcb_layers.layer_number IS 'Physical layer number from top (1) to bottom (N). Layer 1 is always the top copper layer.';
COMMENT ON COLUMN pcb_layers.layer_type IS 'Functional type of this layer: signal, power, ground, mixed, dielectric, solder_mask, silkscreen, paste_mask.';
COMMENT ON COLUMN pcb_layers.copper_weight_oz IS 'Copper foil weight in ounces per square foot. Typical: 0.5, 1.0, 2.0 oz.';

-- ---------------------------------------------------------------------------
-- TABLE: pcb_stackups
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pcb_stackups (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    pcb_assembly_id         UUID            NOT NULL,
    organization_id         UUID            NOT NULL,
    name                    VARCHAR(100)    NOT NULL DEFAULT 'Default Stack-up',
    total_thickness_mm      NUMERIC(10,4)   NULL,
    is_validated            BOOLEAN         NOT NULL DEFAULT FALSE,
    validated_by_engineer_id UUID           NULL,
    validated_at            TIMESTAMPTZ     NULL,
    stackup_data            JSONB           NOT NULL DEFAULT '[]',
    notes                   TEXT            NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_pcb_stackups
        PRIMARY KEY (id),

    CONSTRAINT fk_pcb_stackups_pcb_assembly
        FOREIGN KEY (pcb_assembly_id)
        REFERENCES pcb_assemblies (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_pcb_stackups_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_pcb_stackups_validated_by
        FOREIGN KEY (validated_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_pcb_stackups_total_thickness
        CHECK (total_thickness_mm IS NULL OR total_thickness_mm > 0),

    CONSTRAINT chk_pcb_stackups_validated
        CHECK (
            (is_validated = FALSE AND validated_by_engineer_id IS NULL AND validated_at IS NULL) OR
            (is_validated = TRUE  AND validated_by_engineer_id IS NOT NULL AND validated_at IS NOT NULL)
        )
);

COMMENT ON TABLE pcb_stackups IS
    'PCB layer stack-up definition. stackup_data JSONB stores the ordered list of layers '
    'with their material and thickness properties. Supports impedance calculation inputs '
    'and controlled impedance verification.';

COMMENT ON COLUMN pcb_stackups.stackup_data IS
    'JSONB array of layer definitions in physical order (top to bottom). '
    'Each element: {layer_type, material, thickness_mm, copper_weight_oz, er, target_impedance_ohm}.';

-- ---------------------------------------------------------------------------
-- TABLE: assembly_variants
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS assembly_variants (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    pcb_assembly_id         UUID            NOT NULL,
    organization_id         UUID            NOT NULL,
    variant_code            VARCHAR(30)     NOT NULL,
    name                    VARCHAR(100)    NOT NULL,
    description             TEXT            NULL,
    is_default              BOOLEAN         NOT NULL DEFAULT FALSE,
    dnp_reference_designators TEXT[]        NOT NULL DEFAULT '{}',
    substitution_rules      JSONB           NOT NULL DEFAULT '{}',
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_assembly_variants
        PRIMARY KEY (id),

    CONSTRAINT uq_assembly_variants_assembly_code
        UNIQUE (pcb_assembly_id, variant_code),

    CONSTRAINT fk_assembly_variants_pcb_assembly
        FOREIGN KEY (pcb_assembly_id)
        REFERENCES pcb_assemblies (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_assembly_variants_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT
);

COMMENT ON TABLE assembly_variants IS
    'Assembly variants of a PCB (e.g., low-cost variant with some components DNP, '
    'regional variant with substitute components). '
    'dnp_reference_designators is an array of reference designators not populated in this variant. '
    'substitution_rules JSONB maps original components to substitutes.';

COMMENT ON COLUMN assembly_variants.variant_code IS 'Short code identifying this variant (e.g., FULL, LITE, EU, JP).';
COMMENT ON COLUMN assembly_variants.dnp_reference_designators IS 'Array of reference designators marked Do Not Populate in this variant.';
COMMENT ON COLUMN assembly_variants.substitution_rules IS 'JSONB map of component substitutions: {ref_des: {from_component_id, to_component_id, reason}}.';

-- ---------------------------------------------------------------------------
-- TABLE: design_files
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS design_files (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    pcb_revision_id             UUID            NOT NULL,
    organization_id             UUID            NOT NULL,
    uploaded_by_engineer_id     UUID            NOT NULL,
    file_type                   VARCHAR(30)     NOT NULL,
    filename                    VARCHAR(255)    NOT NULL,
    storage_path                TEXT            NOT NULL,
    storage_bucket              VARCHAR(100)    NOT NULL DEFAULT 'stencilpro-cad',
    file_size_bytes             BIGINT          NOT NULL,
    mime_type                   VARCHAR(100)    NOT NULL,
    file_format_version         VARCHAR(30)     NULL,
    description                 TEXT            NULL,
    layer_name                  VARCHAR(50)     NULL,
    is_primary                  BOOLEAN         NOT NULL DEFAULT FALSE,
    checksum_sha256             VARCHAR(64)     NULL,
    is_deleted                  BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at                  TIMESTAMPTZ     NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_design_files
        PRIMARY KEY (id),

    CONSTRAINT fk_design_files_pcb_revision
        FOREIGN KEY (pcb_revision_id)
        REFERENCES pcb_revisions (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_design_files_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_design_files_uploaded_by
        FOREIGN KEY (uploaded_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_design_files_type
        CHECK (file_type IN (
            'gerber_copper','gerber_silkscreen','gerber_solder_mask',
            'gerber_paste_mask','gerber_drill','gerber_board_outline',
            'odb_plus_plus','ipc_2581','pick_and_place',
            'netlist','schematic','layout','bom',
            'step_3d','dxf','other'
        )),

    CONSTRAINT chk_design_files_file_size
        CHECK (file_size_bytes > 0),

    CONSTRAINT chk_design_files_storage_path
        CHECK (LENGTH(TRIM(storage_path)) > 0),

    CONSTRAINT chk_design_files_checksum
        CHECK (checksum_sha256 IS NULL OR LENGTH(checksum_sha256) = 64),

    CONSTRAINT chk_design_files_soft_delete
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL) OR
            (is_deleted = TRUE  AND deleted_at IS NOT NULL)
        )
);

COMMENT ON TABLE design_files IS
    'Engineering design files associated with a PCB revision. '
    'Stores Gerber, ODB++, IPC-2581, pick-and-place, netlist, and other files. '
    'Binary content is in Supabase Storage; this table stores metadata and path only. '
    'checksum_sha256 enables integrity verification of archived files.';

COMMENT ON COLUMN design_files.file_type IS 'Classification of the design file type. Drives which processing pipeline handles this file.';
COMMENT ON COLUMN design_files.is_primary IS 'TRUE for the primary file of a given type per revision (e.g., the primary ODB++ package).';
COMMENT ON COLUMN design_files.layer_name IS 'For individual Gerber layer files: the layer name (e.g., F.Cu, B.Cu, F.Paste).';
COMMENT ON COLUMN design_files.checksum_sha256 IS 'SHA-256 hash of the file content for integrity verification. 64 hex characters.';
COMMENT ON COLUMN design_files.file_format_version IS 'File format version string (e.g., RS-274X for Gerber, 7.0 for ODB++).';

-- =============================================================================
-- COMPONENT & BOM ENTITIES
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: components
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS components (
    id                              UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id                 UUID            NOT NULL,
    manufacturer_name               VARCHAR(100)    NOT NULL,
    manufacturer_part_number        VARCHAR(100)    NOT NULL,
    description                     VARCHAR(255)    NOT NULL,
    component_category              VARCHAR(50)     NOT NULL DEFAULT 'other',
    package_id                      UUID            NULL,
    is_moisture_sensitive           BOOLEAN         NOT NULL DEFAULT FALSE,
    moisture_sensitivity_level      VARCHAR(10)     NULL,
    max_reflow_temp_c               NUMERIC(6,2)    NULL,
    reflow_cycles_max               INTEGER         NULL,
    has_special_paste_requirements  BOOLEAN         NOT NULL DEFAULT FALSE,
    paste_requirement_notes         TEXT            NULL,
    is_rohs_compliant               BOOLEAN         NOT NULL DEFAULT TRUE,
    is_reach_compliant              BOOLEAN         NOT NULL DEFAULT TRUE,
    is_halogen_free                 BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active                       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_deleted                      BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at                      TIMESTAMPTZ     NULL,
    datasheet_url                   TEXT            NULL,
    notes                           TEXT            NULL,
    created_at                      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                      UUID            NULL,
    updated_by                      UUID            NULL,

    CONSTRAINT pk_components
        PRIMARY KEY (id),

    CONSTRAINT uq_components_org_manufacturer_mpn
        UNIQUE (organization_id, manufacturer_name, manufacturer_part_number),

    CONSTRAINT fk_components_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_components_category
        CHECK (component_category IN (
            'resistor','capacitor','inductor','ic','connector',
            'crystal','oscillator','diode','transistor','transformer',
            'relay','switch','fuse','sensor','module',
            'led','display','memory','processor','power',
            'mechanical','other'
        )),

    CONSTRAINT chk_components_msl
        CHECK (moisture_sensitivity_level IS NULL OR
               moisture_sensitivity_level IN (
                   'msl_1','msl_2','msl_2a','msl_3',
                   'msl_4','msl_5','msl_5a','msl_6'
               )),

    CONSTRAINT chk_components_max_reflow_temp
        CHECK (max_reflow_temp_c IS NULL OR max_reflow_temp_c > 0),

    CONSTRAINT chk_components_reflow_cycles
        CHECK (reflow_cycles_max IS NULL OR reflow_cycles_max > 0),

    CONSTRAINT chk_components_soft_delete
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL) OR
            (is_deleted = TRUE  AND deleted_at IS NOT NULL)
        )
);

COMMENT ON TABLE components IS
    'Specific electronic components (manufacturer part numbers) used in PCB assemblies. '
    'A component is distinct from a package: the package defines the physical geometry '
    'while the component is a specific commercial part that uses that package. '
    'package_id references smt_packages (DB-004). FK constraint added in DB-004.';

COMMENT ON COLUMN components.manufacturer_part_number IS 'MPN — the globally unique manufacturer part number. Combined with manufacturer_name, unique per organization.';
COMMENT ON COLUMN components.package_id IS 'References smt_packages (defined in DB-004). FK constraint will be added in DB-004 migration.';
COMMENT ON COLUMN components.moisture_sensitivity_level IS 'IPC/JEDEC J-STD-020 MSL classification. MSL 2+ requires floor life tracking.';
COMMENT ON COLUMN components.max_reflow_temp_c IS 'Maximum component junction temperature during reflow. Used to validate reflow profiles.';
COMMENT ON COLUMN components.reflow_cycles_max IS 'Maximum number of reflow cycles this component can withstand. Typically 2–3 for most SMT parts.';
COMMENT ON COLUMN components.has_special_paste_requirements IS 'TRUE if this component requires non-standard paste. Triggers mandatory engineering review before stencil design.';

-- ---------------------------------------------------------------------------
-- TABLE: component_revisions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS component_revisions (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    component_id            UUID            NOT NULL,
    organization_id         UUID            NOT NULL,
    revision_code           VARCHAR(20)     NOT NULL,
    change_summary          TEXT            NOT NULL,
    change_type             VARCHAR(30)     NOT NULL DEFAULT 'minor_change',
    changed_by_engineer_id  UUID            NOT NULL,
    effective_date          DATE            NOT NULL DEFAULT CURRENT_DATE,
    component_snapshot      JSONB           NOT NULL DEFAULT '{}',
    is_current              BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_component_revisions
        PRIMARY KEY (id),

    CONSTRAINT uq_component_revisions_component_code
        UNIQUE (component_id, revision_code),

    CONSTRAINT fk_component_revisions_component
        FOREIGN KEY (component_id)
        REFERENCES components (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_component_revisions_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_component_revisions_changed_by
        FOREIGN KEY (changed_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_component_revisions_change_type
        CHECK (change_type IN (
            'initial_release','minor_change','major_change',
            'eco','package_change','obsolescence'
        ))
);

COMMENT ON TABLE component_revisions IS
    'Version history for component records. Tracks changes to component specifications '
    'over time (e.g., package change, new MSL rating, updated reflow limits). '
    'component_snapshot is a JSONB copy of the component state at this revision.';

-- Partial unique index: one current revision per component
CREATE UNIQUE INDEX IF NOT EXISTS uq_component_revisions_current
    ON component_revisions (component_id)
    WHERE is_current = TRUE;

-- ---------------------------------------------------------------------------
-- TABLE: electrical_nets
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS electrical_nets (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    pcb_revision_id     UUID            NOT NULL,
    organization_id     UUID            NOT NULL,
    net_name            VARCHAR(100)    NOT NULL,
    net_class           VARCHAR(50)     NULL,
    is_power_net        BOOLEAN         NOT NULL DEFAULT FALSE,
    is_ground_net       BOOLEAN         NOT NULL DEFAULT FALSE,
    voltage_v           NUMERIC(8,3)    NULL,
    current_max_a       NUMERIC(8,3)    NULL,
    impedance_target_ohm NUMERIC(8,3)   NULL,
    notes               TEXT            NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_electrical_nets
        PRIMARY KEY (id),

    CONSTRAINT uq_electrical_nets_revision_name
        UNIQUE (pcb_revision_id, net_name),

    CONSTRAINT fk_electrical_nets_pcb_revision
        FOREIGN KEY (pcb_revision_id)
        REFERENCES pcb_revisions (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_electrical_nets_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_electrical_nets_voltage
        CHECK (voltage_v IS NULL OR voltage_v >= 0)
);

COMMENT ON TABLE electrical_nets IS
    'Electrical nets defined for a PCB revision. Nets are referenced by component pads '
    'to enable short-circuit detection and power analysis. '
    'Imported from CAD netlists or entered manually.';

COMMENT ON COLUMN electrical_nets.net_name IS 'Net name as defined in the EDA tool (e.g., VCC_3V3, GND, USB_D+). Unique per revision.';
COMMENT ON COLUMN electrical_nets.net_class IS 'Net class for design rule application (e.g., Power, Signal, Differential, High_Current).';

-- ---------------------------------------------------------------------------
-- TABLE: bom_revisions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS bom_revisions (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    pcb_assembly_id             UUID            NOT NULL,
    organization_id             UUID            NOT NULL,
    pcb_revision_id             UUID            NOT NULL,
    revision_code               VARCHAR(20)     NOT NULL,
    revision_date               DATE            NOT NULL DEFAULT CURRENT_DATE,
    released_by_engineer_id     UUID            NOT NULL,
    change_summary              TEXT            NULL,
    total_line_items            INTEGER         NOT NULL DEFAULT 0,
    total_component_quantity    INTEGER         NOT NULL DEFAULT 0,
    unique_part_count           INTEGER         NOT NULL DEFAULT 0,
    bom_storage_path            TEXT            NULL,
    is_released                 BOOLEAN         NOT NULL DEFAULT FALSE,
    released_at                 TIMESTAMPTZ     NULL,
    is_current                  BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_bom_revisions
        PRIMARY KEY (id),

    CONSTRAINT uq_bom_revisions_assembly_code
        UNIQUE (pcb_assembly_id, revision_code),

    CONSTRAINT fk_bom_revisions_pcb_assembly
        FOREIGN KEY (pcb_assembly_id)
        REFERENCES pcb_assemblies (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bom_revisions_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bom_revisions_pcb_revision
        FOREIGN KEY (pcb_revision_id)
        REFERENCES pcb_revisions (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bom_revisions_released_by
        FOREIGN KEY (released_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_bom_revisions_released
        CHECK (
            (is_released = FALSE AND released_at IS NULL) OR
            (is_released = TRUE  AND released_at IS NOT NULL)
        ),

    CONSTRAINT chk_bom_revisions_counts
        CHECK (
            total_line_items >= 0 AND
            total_component_quantity >= 0 AND
            unique_part_count >= 0
        )
);

COMMENT ON TABLE bom_revisions IS
    'Versioned Bill of Materials revisions for a PCB assembly. '
    'Each BOM revision links to a specific PCB revision and contains all BOM line items. '
    'Released BOMs are immutable. is_current tracks the active BOM version.';

COMMENT ON COLUMN bom_revisions.total_line_items IS 'Count of unique BOM line items. Maintained by trigger on bom_items.';
COMMENT ON COLUMN bom_revisions.total_component_quantity IS 'Sum of all quantities across all BOM line items.';

-- Partial unique index: one current BOM per assembly
CREATE UNIQUE INDEX IF NOT EXISTS uq_bom_revisions_current
    ON bom_revisions (pcb_assembly_id)
    WHERE is_current = TRUE;

-- ---------------------------------------------------------------------------
-- TABLE: bom_items
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS bom_items (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    bom_revision_id     UUID            NOT NULL,
    organization_id     UUID            NOT NULL,
    component_id        UUID            NOT NULL,
    line_item_number    INTEGER         NOT NULL,
    quantity            INTEGER         NOT NULL DEFAULT 1,
    reference_designators TEXT[]        NOT NULL DEFAULT '{}',
    is_dnp              BOOLEAN         NOT NULL DEFAULT FALSE,
    dnp_reason          TEXT            NULL,
    approved_alternates UUID[]          NOT NULL DEFAULT '{}',
    procurement_notes   TEXT            NULL,
    unit_cost           NUMERIC(12,4)   NULL,
    currency            VARCHAR(3)      NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_bom_items
        PRIMARY KEY (id),

    CONSTRAINT uq_bom_items_revision_line
        UNIQUE (bom_revision_id, line_item_number),

    CONSTRAINT fk_bom_items_bom_revision
        FOREIGN KEY (bom_revision_id)
        REFERENCES bom_revisions (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_bom_items_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_bom_items_component
        FOREIGN KEY (component_id)
        REFERENCES components (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_bom_items_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_bom_items_line_item_number
        CHECK (line_item_number > 0),

    CONSTRAINT chk_bom_items_unit_cost
        CHECK (unit_cost IS NULL OR unit_cost >= 0),

    CONSTRAINT chk_bom_items_currency
        CHECK (currency IS NULL OR LENGTH(currency) = 3)
);

COMMENT ON TABLE bom_items IS
    'Individual line items in a BOM revision. Each line item references one component '
    'and lists the reference designators that use it. '
    'reference_designators is a denormalized array for fast BOM display; '
    'the normalized placement data is in component_placements.';

COMMENT ON COLUMN bom_items.reference_designators IS 'Array of reference designators (e.g., {R1, R2, C5}) that use this component. Denormalized for BOM display.';
COMMENT ON COLUMN bom_items.approved_alternates IS 'Array of component UUIDs that are approved alternates for this line item.';
COMMENT ON COLUMN bom_items.line_item_number IS 'Sequential line number in the BOM (1, 2, 3...). Unique per BOM revision.';

-- ---------------------------------------------------------------------------
-- TABLE: component_placements
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS component_placements (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    pcb_revision_id             UUID            NOT NULL,
    organization_id             UUID            NOT NULL,
    component_id                UUID            NOT NULL,
    bom_item_id                 UUID            NULL,
    reference_designator        VARCHAR(20)     NOT NULL,
    x_position_mm               NUMERIC(12,6)   NOT NULL,
    y_position_mm               NUMERIC(12,6)   NOT NULL,
    rotation_degrees            NUMERIC(10,6)   NOT NULL DEFAULT 0.0,
    assembly_side               VARCHAR(10)     NOT NULL DEFAULT 'top',
    placement_origin            VARCHAR(20)     NOT NULL DEFAULT 'centroid',
    land_pattern_id             UUID            NULL,
    is_dnp                      BOOLEAN         NOT NULL DEFAULT FALSE,
    dnp_reason                  TEXT            NULL,
    is_fiducial                 BOOLEAN         NOT NULL DEFAULT FALSE,
    height_mm                   NUMERIC(10,4)   NULL,
    net_name_primary_pad        VARCHAR(100)    NULL,
    import_source               VARCHAR(30)     NULL,
    import_file_id              UUID            NULL,
    notes                       TEXT            NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_component_placements
        PRIMARY KEY (id),

    CONSTRAINT uq_component_placements_revision_refdes
        UNIQUE (pcb_revision_id, reference_designator),

    CONSTRAINT fk_component_placements_pcb_revision
        FOREIGN KEY (pcb_revision_id)
        REFERENCES pcb_revisions (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_component_placements_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_component_placements_component
        FOREIGN KEY (component_id)
        REFERENCES components (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_component_placements_bom_item
        FOREIGN KEY (bom_item_id)
        REFERENCES bom_items (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_component_placements_assembly_side
        CHECK (assembly_side IN ('top','bottom')),

    CONSTRAINT chk_component_placements_rotation
        CHECK (rotation_degrees >= 0 AND rotation_degrees < 360),

    CONSTRAINT chk_component_placements_origin
        CHECK (placement_origin IN ('centroid','pin_1','body_center')),

    CONSTRAINT chk_component_placements_height
        CHECK (height_mm IS NULL OR height_mm >= 0),

    CONSTRAINT chk_component_placements_import_source
        CHECK (import_source IS NULL OR import_source IN (
            'pick_place_csv','odb_plus_plus','ipc_2581',
            'gerber','manual','api'
        ))
);

COMMENT ON TABLE component_placements IS
    'The placement of a specific component at a specific location on a specific PCB revision. '
    'This is the "instance" record — the fact that U1 on revision B is placed at '
    'coordinates (45.2, 23.7) rotated 90°. '
    'Spatial position enables proximity analysis: component-to-component shadowing, '
    'paste bridging risk between closely spaced pads, and tombstoning risk assessment. '
    'land_pattern_id references land_patterns (DB-005). FK added in DB-005.';

COMMENT ON COLUMN component_placements.reference_designator IS 'Circuit reference designator (e.g., U1, C12, R47). Unique per PCB revision.';
COMMENT ON COLUMN component_placements.x_position_mm IS 'Component centroid X position in mm relative to board origin.';
COMMENT ON COLUMN component_placements.y_position_mm IS 'Component centroid Y position in mm relative to board origin.';
COMMENT ON COLUMN component_placements.rotation_degrees IS 'Component rotation in degrees, 0–359.999. 0° = manufacturer orientation per IPC-7351.';
COMMENT ON COLUMN component_placements.assembly_side IS 'PCB side where this component is placed: top or bottom.';
COMMENT ON COLUMN component_placements.placement_origin IS 'What point the X/Y coordinates reference: centroid (default), pin_1, or body_center.';
COMMENT ON COLUMN component_placements.land_pattern_id IS 'References land_patterns (DB-005). FK constraint will be added in DB-005 migration.';
COMMENT ON COLUMN component_placements.is_fiducial IS 'TRUE if this placement is a fiducial marker (not a component). Excluded from stencil aperture generation.';
COMMENT ON COLUMN component_placements.import_source IS 'How this placement was created: pick_place_csv, odb_plus_plus, ipc_2581, gerber, manual, api.';
COMMENT ON COLUMN component_placements.import_file_id IS 'References design_files.id if this placement was imported from a specific file.';

COMMIT;
