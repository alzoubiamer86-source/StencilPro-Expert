-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-003: PCB Assemblies & Components
-- File: DB003_Indexes.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB003_PCB.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- pcb_surface_finishes
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_pcb_surface_finishes_abbreviation
    ON pcb_surface_finishes (abbreviation)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_pcb_surface_finishes_rohs
    ON pcb_surface_finishes (is_rohs_compliant, is_lead_free)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_pcb_surface_finishes_flatness
    ON pcb_surface_finishes (flatness_rating)
    WHERE is_active = TRUE;

-- =============================================================================
-- pcb_materials
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_pcb_materials_type
    ON pcb_materials (material_type)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_pcb_materials_name_trgm
    ON pcb_materials USING GIN (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_pcb_materials_high_tg
    ON pcb_materials (tg_min_c, tg_max_c)
    WHERE is_active = TRUE AND tg_min_c IS NOT NULL;

-- =============================================================================
-- pcb_thickness_options
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_pcb_thickness_options_thickness
    ON pcb_thickness_options (thickness_mm)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_pcb_thickness_standard
    ON pcb_thickness_options (is_standard)
    WHERE is_active = TRUE AND is_standard = TRUE;

-- =============================================================================
-- board_manufacturers
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_board_manufacturers_organization_id
    ON board_manufacturers (organization_id)
    WHERE is_active = TRUE AND organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_board_manufacturers_approved
    ON board_manufacturers (organization_id, is_approved)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_board_manufacturers_name_trgm
    ON board_manufacturers USING GIN (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_board_manufacturers_country
    ON board_manufacturers (country)
    WHERE is_active = TRUE AND country IS NOT NULL;

-- =============================================================================
-- assembly_manufacturers
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_assembly_manufacturers_organization_id
    ON assembly_manufacturers (organization_id)
    WHERE is_active = TRUE AND organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_assembly_manufacturers_approved
    ON assembly_manufacturers (organization_id, is_approved)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_assembly_manufacturers_name_trgm
    ON assembly_manufacturers USING GIN (name gin_trgm_ops);

-- =============================================================================
-- pcb_assemblies
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_organization_id
    ON pcb_assemblies (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_project_id
    ON pcb_assemblies (project_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_product_id
    ON pcb_assemblies (product_id)
    WHERE is_deleted = FALSE AND product_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_surface_finish_id
    ON pcb_assemblies (surface_finish_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_base_material_id
    ON pcb_assemblies (base_material_id)
    WHERE is_deleted = FALSE AND base_material_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_board_manufacturer_id
    ON pcb_assemblies (board_manufacturer_id)
    WHERE is_deleted = FALSE AND board_manufacturer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_assembly_sides
    ON pcb_assemblies (organization_id, assembly_sides)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_part_number
    ON pcb_assemblies (organization_id, part_number)
    WHERE is_deleted = FALSE AND part_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_updated_at
    ON pcb_assemblies (organization_id, updated_at DESC)
    WHERE is_deleted = FALSE;

-- Trigram for name search
CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_name_trgm
    ON pcb_assemblies USING GIN (name gin_trgm_ops);

-- Full-text search on name + part_number + description
CREATE INDEX IF NOT EXISTS idx_pcb_assemblies_fts
    ON pcb_assemblies USING GIN (
        to_tsvector('english',
            COALESCE(name, '') || ' ' ||
            COALESCE(part_number, '') || ' ' ||
            COALESCE(description, '')
        )
    );

-- =============================================================================
-- pcb_revisions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_pcb_revisions_pcb_assembly_id
    ON pcb_revisions (pcb_assembly_id);

CREATE INDEX IF NOT EXISTS idx_pcb_revisions_organization_id
    ON pcb_revisions (organization_id);

CREATE INDEX IF NOT EXISTS idx_pcb_revisions_released_by
    ON pcb_revisions (released_by_engineer_id);

-- Current revision fast lookup
CREATE INDEX IF NOT EXISTS idx_pcb_revisions_current
    ON pcb_revisions (pcb_assembly_id, is_current_revision)
    WHERE is_current_revision = TRUE;

-- Revision date ordering
CREATE INDEX IF NOT EXISTS idx_pcb_revisions_revision_date_desc
    ON pcb_revisions (pcb_assembly_id, revision_date DESC);

-- Feature flags used by rule engine
CREATE INDEX IF NOT EXISTS idx_pcb_revisions_has_bgas
    ON pcb_revisions (organization_id, has_bgas)
    WHERE has_bgas = TRUE;

CREATE INDEX IF NOT EXISTS idx_pcb_revisions_has_qfns
    ON pcb_revisions (organization_id, has_qfns)
    WHERE has_qfns = TRUE;

CREATE INDEX IF NOT EXISTS idx_pcb_revisions_min_pitch
    ON pcb_revisions (min_pitch_mm)
    WHERE min_pitch_mm IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pcb_revisions_change_type
    ON pcb_revisions (pcb_assembly_id, change_type);

-- =============================================================================
-- pcb_layers
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_pcb_layers_pcb_assembly_id
    ON pcb_layers (pcb_assembly_id);

CREATE INDEX IF NOT EXISTS idx_pcb_layers_organization_id
    ON pcb_layers (organization_id);

CREATE INDEX IF NOT EXISTS idx_pcb_layers_layer_type
    ON pcb_layers (pcb_assembly_id, layer_type);

CREATE INDEX IF NOT EXISTS idx_pcb_layers_layer_side
    ON pcb_layers (pcb_assembly_id, layer_side);

-- =============================================================================
-- pcb_stackups
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_pcb_stackups_pcb_assembly_id
    ON pcb_stackups (pcb_assembly_id);

CREATE INDEX IF NOT EXISTS idx_pcb_stackups_organization_id
    ON pcb_stackups (organization_id);

CREATE INDEX IF NOT EXISTS idx_pcb_stackups_validated
    ON pcb_stackups (pcb_assembly_id, is_validated)
    WHERE is_validated = TRUE;

-- =============================================================================
-- assembly_variants
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_assembly_variants_pcb_assembly_id
    ON assembly_variants (pcb_assembly_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_assembly_variants_organization_id
    ON assembly_variants (organization_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_assembly_variants_default
    ON assembly_variants (pcb_assembly_id, is_default)
    WHERE is_default = TRUE AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_assembly_variants_code
    ON assembly_variants (pcb_assembly_id, variant_code)
    WHERE is_active = TRUE;

-- =============================================================================
-- design_files
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_design_files_pcb_revision_id
    ON design_files (pcb_revision_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_design_files_organization_id
    ON design_files (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_design_files_uploaded_by
    ON design_files (uploaded_by_engineer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_design_files_file_type
    ON design_files (pcb_revision_id, file_type)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_design_files_primary
    ON design_files (pcb_revision_id, file_type, is_primary)
    WHERE is_deleted = FALSE AND is_primary = TRUE;

CREATE INDEX IF NOT EXISTS idx_design_files_created_at
    ON design_files (pcb_revision_id, created_at DESC)
    WHERE is_deleted = FALSE;

-- =============================================================================
-- components
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_components_organization_id
    ON components (organization_id)
    WHERE is_deleted = FALSE;

-- MPN search: most common lookup pattern
CREATE INDEX IF NOT EXISTS idx_components_mpn
    ON components (organization_id, manufacturer_name, manufacturer_part_number)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_components_manufacturer_name
    ON components (organization_id, manufacturer_name)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_components_package_id
    ON components (package_id)
    WHERE is_deleted = FALSE AND package_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_components_category
    ON components (organization_id, component_category)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_components_msl
    ON components (organization_id, moisture_sensitivity_level)
    WHERE is_deleted = FALSE AND moisture_sensitivity_level IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_components_special_paste
    ON components (organization_id, has_special_paste_requirements)
    WHERE is_deleted = FALSE AND has_special_paste_requirements = TRUE;

-- Trigram on MPN for fuzzy search
CREATE INDEX IF NOT EXISTS idx_components_mpn_trgm
    ON components USING GIN (manufacturer_part_number gin_trgm_ops);

-- Full-text search on MPN + description
CREATE INDEX IF NOT EXISTS idx_components_fts
    ON components USING GIN (
        to_tsvector('english',
            COALESCE(manufacturer_name, '') || ' ' ||
            COALESCE(manufacturer_part_number, '') || ' ' ||
            COALESCE(description, '')
        )
    );

-- =============================================================================
-- component_revisions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_component_revisions_component_id
    ON component_revisions (component_id);

CREATE INDEX IF NOT EXISTS idx_component_revisions_organization_id
    ON component_revisions (organization_id);

CREATE INDEX IF NOT EXISTS idx_component_revisions_current
    ON component_revisions (component_id, is_current)
    WHERE is_current = TRUE;

CREATE INDEX IF NOT EXISTS idx_component_revisions_changed_by
    ON component_revisions (changed_by_engineer_id);

-- =============================================================================
-- electrical_nets
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_electrical_nets_pcb_revision_id
    ON electrical_nets (pcb_revision_id);

CREATE INDEX IF NOT EXISTS idx_electrical_nets_organization_id
    ON electrical_nets (organization_id);

CREATE INDEX IF NOT EXISTS idx_electrical_nets_power
    ON electrical_nets (pcb_revision_id, is_power_net)
    WHERE is_power_net = TRUE;

CREATE INDEX IF NOT EXISTS idx_electrical_nets_ground
    ON electrical_nets (pcb_revision_id, is_ground_net)
    WHERE is_ground_net = TRUE;

-- Net name trigram for search
CREATE INDEX IF NOT EXISTS idx_electrical_nets_name_trgm
    ON electrical_nets USING GIN (net_name gin_trgm_ops);

-- =============================================================================
-- bom_revisions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_bom_revisions_pcb_assembly_id
    ON bom_revisions (pcb_assembly_id);

CREATE INDEX IF NOT EXISTS idx_bom_revisions_organization_id
    ON bom_revisions (organization_id);

CREATE INDEX IF NOT EXISTS idx_bom_revisions_pcb_revision_id
    ON bom_revisions (pcb_revision_id);

CREATE INDEX IF NOT EXISTS idx_bom_revisions_released_by
    ON bom_revisions (released_by_engineer_id);

CREATE INDEX IF NOT EXISTS idx_bom_revisions_current
    ON bom_revisions (pcb_assembly_id, is_current)
    WHERE is_current = TRUE;

CREATE INDEX IF NOT EXISTS idx_bom_revisions_released
    ON bom_revisions (pcb_assembly_id, is_released)
    WHERE is_released = TRUE;

-- =============================================================================
-- bom_items
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_bom_items_bom_revision_id
    ON bom_items (bom_revision_id);

CREATE INDEX IF NOT EXISTS idx_bom_items_organization_id
    ON bom_items (organization_id);

CREATE INDEX IF NOT EXISTS idx_bom_items_component_id
    ON bom_items (component_id);

CREATE INDEX IF NOT EXISTS idx_bom_items_dnp
    ON bom_items (bom_revision_id, is_dnp)
    WHERE is_dnp = TRUE;

-- GIN for reference_designators array search
CREATE INDEX IF NOT EXISTS idx_bom_items_ref_des_gin
    ON bom_items USING GIN (reference_designators);

-- GIN for approved_alternates UUID array
CREATE INDEX IF NOT EXISTS idx_bom_items_approved_alternates_gin
    ON bom_items USING GIN (approved_alternates);

-- =============================================================================
-- component_placements
-- =============================================================================

-- Primary: all placements for a revision
CREATE INDEX IF NOT EXISTS idx_component_placements_pcb_revision_id
    ON component_placements (pcb_revision_id);

CREATE INDEX IF NOT EXISTS idx_component_placements_organization_id
    ON component_placements (organization_id);

CREATE INDEX IF NOT EXISTS idx_component_placements_component_id
    ON component_placements (component_id);

CREATE INDEX IF NOT EXISTS idx_component_placements_bom_item_id
    ON component_placements (bom_item_id)
    WHERE bom_item_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_component_placements_land_pattern_id
    ON component_placements (land_pattern_id)
    WHERE land_pattern_id IS NOT NULL;

-- Reference designator lookup
CREATE INDEX IF NOT EXISTS idx_component_placements_ref_des
    ON component_placements (pcb_revision_id, reference_designator);

-- Assembly side filter
CREATE INDEX IF NOT EXISTS idx_component_placements_side
    ON component_placements (pcb_revision_id, assembly_side);

-- DNP filter
CREATE INDEX IF NOT EXISTS idx_component_placements_dnp
    ON component_placements (pcb_revision_id, is_dnp)
    WHERE is_dnp = TRUE;

-- Fiducial filter
CREATE INDEX IF NOT EXISTS idx_component_placements_fiducial
    ON component_placements (pcb_revision_id, is_fiducial)
    WHERE is_fiducial = TRUE;

-- Import file lookup
CREATE INDEX IF NOT EXISTS idx_component_placements_import_file
    ON component_placements (import_file_id)
    WHERE import_file_id IS NOT NULL;

-- Spatial proximity queries (X/Y position range scans)
CREATE INDEX IF NOT EXISTS idx_component_placements_xy
    ON component_placements (pcb_revision_id, x_position_mm, y_position_mm);

-- Trigram on reference_designator for fuzzy search
CREATE INDEX IF NOT EXISTS idx_component_placements_ref_des_trgm
    ON component_placements USING GIN (reference_designator gin_trgm_ops);

COMMIT;
