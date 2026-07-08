-- =============================================================================
-- StencilPro Expert Enterprise
-- DB005: Land Pattern & Aperture Intelligence Engine
-- File: DB005_Indexes.sql
-- Purpose: Indexing strategy for DB005, consistent with DB001-DB004A conventions:
--   - FK columns indexed to support join performance and RLS predicate pushdown
--   - organization_id included in composite indexes supporting tenant-scoped scans
--   - partial indexes on is_current / is_deleted for hot-path "current record" queries
--   - GIN indexes on jsonb revision snapshots for downstream inspection/audit tooling
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- aperture_shape_types / stencil_defect_types (lookups)
-- -----------------------------------------------------------------------------

CREATE INDEX idx_aperture_shape_types_code ON app.aperture_shape_types (shape_code) WHERE is_deleted = false;
CREATE INDEX idx_stencil_defect_types_code ON app.stencil_defect_types (defect_code);

-- -----------------------------------------------------------------------------
-- package_families
-- -----------------------------------------------------------------------------

CREATE INDEX idx_package_families_org ON app.package_families (organization_id) WHERE is_deleted = false;
CREATE INDEX idx_package_families_category ON app.package_families (organization_id, category) WHERE is_deleted = false;
CREATE INDEX idx_package_families_current ON app.package_families (organization_id, is_current) WHERE is_deleted = false AND is_current = true;

-- -----------------------------------------------------------------------------
-- land_patterns / land_pattern_pads / land_pattern_revisions / land_pattern_approvals
-- -----------------------------------------------------------------------------

CREATE INDEX idx_land_patterns_org ON app.land_patterns (organization_id) WHERE is_deleted = false;
CREATE INDEX idx_land_patterns_package_family ON app.land_patterns (package_family_id) WHERE is_deleted = false;
CREATE INDEX idx_land_patterns_customer ON app.land_patterns (customer_id) WHERE customer_id IS NOT NULL AND is_deleted = false;
CREATE INDEX idx_land_patterns_status ON app.land_patterns (organization_id, status) WHERE is_deleted = false;
CREATE INDEX idx_land_patterns_current ON app.land_patterns (package_family_id, is_current) WHERE is_deleted = false AND is_current = true;
CREATE INDEX idx_land_patterns_source_type ON app.land_patterns (organization_id, source_type) WHERE is_deleted = false;

CREATE INDEX idx_land_pattern_pads_land_pattern ON app.land_pattern_pads (land_pattern_id) WHERE is_deleted = false;
CREATE INDEX idx_land_pattern_pads_shape_type ON app.land_pattern_pads (pad_shape_type_id);

CREATE INDEX idx_land_pattern_revisions_land_pattern ON app.land_pattern_revisions (land_pattern_id, revision_number DESC);
CREATE INDEX idx_land_pattern_revisions_snapshot_gin ON app.land_pattern_revisions USING gin (snapshot);

CREATE INDEX idx_land_pattern_approvals_land_pattern ON app.land_pattern_approvals (land_pattern_id);
CREATE INDEX idx_land_pattern_approvals_status ON app.land_pattern_approvals (organization_id, approval_status);

-- -----------------------------------------------------------------------------
-- surface_finish_types / pad_surface_finish_compatibility
-- -----------------------------------------------------------------------------

CREATE INDEX idx_psfc_package_family ON app.pad_surface_finish_compatibility (package_family_id);
CREATE INDEX idx_psfc_surface_finish ON app.pad_surface_finish_compatibility (surface_finish_id);

-- -----------------------------------------------------------------------------
-- pads
-- -----------------------------------------------------------------------------

CREATE INDEX idx_pads_org ON app.pads (organization_id) WHERE is_deleted = false;
CREATE INDEX idx_pads_package_family ON app.pads (package_family_id) WHERE is_deleted = false;
CREATE INDEX idx_pads_land_pattern_pad ON app.pads (land_pattern_pad_id) WHERE land_pattern_pad_id IS NOT NULL;
CREATE INDEX idx_pads_shape_type ON app.pads (shape_type_id);
CREATE INDEX idx_pads_surface_finish ON app.pads (surface_finish_id) WHERE surface_finish_id IS NOT NULL;
CREATE INDEX idx_pads_source_component_reference ON app.pads (source_component_reference) WHERE source_component_reference IS NOT NULL;
CREATE INDEX idx_pads_current ON app.pads (package_family_id, is_current) WHERE is_deleted = false AND is_current = true;

-- -----------------------------------------------------------------------------
-- apertures / aperture_polygon_vertices / aperture_revisions
-- -----------------------------------------------------------------------------

CREATE INDEX idx_apertures_org ON app.apertures (organization_id) WHERE is_deleted = false;
CREATE INDEX idx_apertures_pad ON app.apertures (pad_id) WHERE is_deleted = false;
CREATE INDEX idx_apertures_shape_type ON app.apertures (shape_type_id);
CREATE INDEX idx_apertures_status ON app.apertures (organization_id, status) WHERE is_deleted = false;
CREATE INDEX idx_apertures_current ON app.apertures (pad_id, is_current) WHERE is_deleted = false AND is_current = true;

CREATE INDEX idx_apv_aperture ON app.aperture_polygon_vertices (aperture_id, vertex_index);

CREATE INDEX idx_aperture_revisions_aperture ON app.aperture_revisions (aperture_id, revision_number DESC);
CREATE INDEX idx_aperture_revisions_snapshot_gin ON app.aperture_revisions USING gin (snapshot);

-- -----------------------------------------------------------------------------
-- engineering_strategies and satellites
-- -----------------------------------------------------------------------------

CREATE INDEX idx_engineering_strategies_org ON app.engineering_strategies (organization_id) WHERE is_deleted = false;
CREATE INDEX idx_engineering_strategies_family ON app.engineering_strategies (primary_package_family_id) WHERE is_deleted = false;
CREATE INDEX idx_engineering_strategies_shape ON app.engineering_strategies (recommended_shape_type_id);
CREATE INDEX idx_engineering_strategies_status ON app.engineering_strategies (organization_id, status) WHERE is_deleted = false;
CREATE INDEX idx_engineering_strategies_current ON app.engineering_strategies (primary_package_family_id, is_current) WHERE is_deleted = false AND is_current = true;

CREATE INDEX idx_espf_strategy ON app.engineering_strategy_package_families (engineering_strategy_id);
CREATE INDEX idx_espf_family ON app.engineering_strategy_package_families (package_family_id);

CREATE INDEX idx_esd_strategy ON app.engineering_strategy_defects (engineering_strategy_id);
CREATE INDEX idx_esd_defect ON app.engineering_strategy_defects (defect_type_id);

CREATE INDEX idx_esr_strategy ON app.engineering_strategy_references (engineering_strategy_id);

CREATE INDEX idx_esrev_strategy ON app.engineering_strategy_revisions (engineering_strategy_id, revision_number DESC);
CREATE INDEX idx_esrev_snapshot_gin ON app.engineering_strategy_revisions USING gin (snapshot);

-- -----------------------------------------------------------------------------
-- stencil_defect_* satellites
-- -----------------------------------------------------------------------------

CREATE INDEX idx_sdrc_defect ON app.stencil_defect_root_causes (defect_type_id);
CREATE INDEX idx_sdpm_defect ON app.stencil_defect_prevention_methods (defect_type_id);

CREATE INDEX idx_sdra_defect ON app.stencil_defect_recommended_apertures (defect_type_id);
CREATE INDEX idx_sdra_shape ON app.stencil_defect_recommended_apertures (shape_type_id);

CREATE INDEX idx_sdrs_defect ON app.stencil_defect_recommended_strategies (defect_type_id);
CREATE INDEX idx_sdrs_strategy ON app.stencil_defect_recommended_strategies (engineering_strategy_id);

CREATE INDEX idx_sdpf_defect ON app.stencil_defect_package_families (defect_type_id);
CREATE INDEX idx_sdpf_family ON app.stencil_defect_package_families (package_family_id);

-- -----------------------------------------------------------------------------
-- pad_engineering_calculations
-- -----------------------------------------------------------------------------

CREATE INDEX idx_pec_pad ON app.pad_engineering_calculations (pad_id, calculated_at DESC);
CREATE INDEX idx_pec_aperture ON app.pad_engineering_calculations (aperture_id, calculated_at DESC);
CREATE INDEX idx_pec_org ON app.pad_engineering_calculations (organization_id);
