-- =============================================================================
-- StencilPro Expert Enterprise
-- DB006: Stencil Generation Engine
-- File: DB006_Indexes.sql
-- Purpose: Indexing strategy for DB006, consistent with DB001-DB005 conventions.
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- stencil_projects / stencil_project_revisions / stencil_project_approvals
-- -----------------------------------------------------------------------------

CREATE INDEX idx_stencil_projects_org ON app.stencil_projects (organization_id) WHERE is_deleted = false;
CREATE INDEX idx_stencil_projects_project ON app.stencil_projects (project_id) WHERE is_deleted = false;
CREATE INDEX idx_stencil_projects_pcb_revision ON app.stencil_projects (pcb_revision_reference) WHERE pcb_revision_reference IS NOT NULL;
CREATE INDEX idx_stencil_projects_status ON app.stencil_projects (organization_id, release_status) WHERE is_deleted = false;
CREATE INDEX idx_stencil_projects_current ON app.stencil_projects (stencil_code, is_current) WHERE is_deleted = false AND is_current = true;
CREATE INDEX idx_stencil_projects_variant ON app.stencil_projects (organization_id, variant_type) WHERE is_deleted = false;

CREATE INDEX idx_spr_stencil_project ON app.stencil_project_revisions (stencil_project_id, revision_number DESC);
CREATE INDEX idx_spr_snapshot_gin ON app.stencil_project_revisions USING gin (snapshot);

CREATE INDEX idx_spa_stencil_project ON app.stencil_project_approvals (stencil_project_id, transitioned_at DESC);
CREATE INDEX idx_spa_to_status ON app.stencil_project_approvals (organization_id, to_status);

-- -----------------------------------------------------------------------------
-- stencil_layers / stencil_step_regions / stencil_step_region_vertices
-- -----------------------------------------------------------------------------

CREATE INDEX idx_stencil_layers_project ON app.stencil_layers (stencil_project_id) WHERE is_deleted = false;
CREATE INDEX idx_stencil_layers_org ON app.stencil_layers (organization_id) WHERE is_deleted = false;

CREATE INDEX idx_stencil_step_regions_layer ON app.stencil_step_regions (stencil_layer_id, region_order);

CREATE INDEX idx_ssrv_region ON app.stencil_step_region_vertices (stencil_step_region_id, vertex_index);

-- -----------------------------------------------------------------------------
-- generated_apertures / generated_aperture_polygon_vertices / generated_aperture_revisions
-- -----------------------------------------------------------------------------

CREATE INDEX idx_ga_org ON app.generated_apertures (organization_id) WHERE is_deleted = false;
CREATE INDEX idx_ga_stencil_layer ON app.generated_apertures (stencil_layer_id) WHERE is_deleted = false;
CREATE INDEX idx_ga_step_region ON app.generated_apertures (stencil_step_region_id) WHERE stencil_step_region_id IS NOT NULL;
CREATE INDEX idx_ga_pad ON app.generated_apertures (pad_id) WHERE is_deleted = false;
CREATE INDEX idx_ga_package_family ON app.generated_apertures (package_family_id) WHERE is_deleted = false;
CREATE INDEX idx_ga_land_pattern ON app.generated_apertures (land_pattern_id) WHERE land_pattern_id IS NOT NULL;
CREATE INDEX idx_ga_land_pattern_revision ON app.generated_apertures (land_pattern_revision_id) WHERE land_pattern_revision_id IS NOT NULL;
CREATE INDEX idx_ga_source_aperture ON app.generated_apertures (source_aperture_definition_id) WHERE source_aperture_definition_id IS NOT NULL;
CREATE INDEX idx_ga_strategy ON app.generated_apertures (engineering_strategy_id) WHERE engineering_strategy_id IS NOT NULL;
CREATE INDEX idx_ga_strategy_revision ON app.generated_apertures (engineering_strategy_revision_id) WHERE engineering_strategy_revision_id IS NOT NULL;
CREATE INDEX idx_ga_shape_type ON app.generated_apertures (shape_type_id);
CREATE INDEX idx_ga_status ON app.generated_apertures (organization_id, status) WHERE is_deleted = false;
CREATE INDEX idx_ga_current ON app.generated_apertures (pad_id, stencil_layer_id, is_current) WHERE is_deleted = false AND is_current = true;

CREATE INDEX idx_gapv_aperture ON app.generated_aperture_polygon_vertices (generated_aperture_id, vertex_index);

CREATE INDEX idx_gar_aperture ON app.generated_aperture_revisions (generated_aperture_id, revision_number DESC);
CREATE INDEX idx_gar_snapshot_gin ON app.generated_aperture_revisions USING gin (snapshot);

-- -----------------------------------------------------------------------------
-- aperture_recommendations / aperture_decisions / aperture_decision_history
-- -----------------------------------------------------------------------------

CREATE INDEX idx_ar_aperture ON app.aperture_recommendations (generated_aperture_id, recommendation_rank);
CREATE INDEX idx_ar_selected ON app.aperture_recommendations (generated_aperture_id) WHERE is_selected = true;
CREATE INDEX idx_ar_shape_type ON app.aperture_recommendations (shape_type_id);
CREATE INDEX idx_ar_precedence ON app.aperture_recommendations (organization_id, rule_precedence_level);

CREATE INDEX idx_ad_aperture ON app.aperture_decisions (generated_aperture_id);
CREATE INDEX idx_ad_status ON app.aperture_decisions (organization_id, decision_status);
CREATE INDEX idx_ad_recommendation ON app.aperture_decisions (selected_recommendation_id) WHERE selected_recommendation_id IS NOT NULL;

CREATE INDEX idx_adh_aperture ON app.aperture_decision_history (generated_aperture_id, decided_at DESC);
CREATE INDEX idx_adh_decided_by ON app.aperture_decision_history (decided_by);

-- -----------------------------------------------------------------------------
-- aperture_comparisons / aperture_overrides / aperture_validations
-- -----------------------------------------------------------------------------

CREATE INDEX idx_ac_aperture ON app.aperture_comparisons (generated_aperture_id, created_at DESC);
CREATE INDEX idx_ac_baseline_aperture ON app.aperture_comparisons (baseline_aperture_id) WHERE baseline_aperture_id IS NOT NULL;
CREATE INDEX idx_ac_type ON app.aperture_comparisons (organization_id, comparison_type);

CREATE INDEX idx_ao_aperture ON app.aperture_overrides (generated_aperture_id, overridden_at DESC);
CREATE INDEX idx_ao_field ON app.aperture_overrides (organization_id, override_field);
CREATE INDEX idx_ao_engineer ON app.aperture_overrides (engineer_id);

CREATE INDEX idx_av_aperture ON app.aperture_validations (generated_aperture_id);
CREATE INDEX idx_av_status ON app.aperture_validations (organization_id, status) WHERE status IN ('WARNING', 'ERROR');
CREATE INDEX idx_av_risk_level ON app.aperture_validations (organization_id, risk_level);

-- -----------------------------------------------------------------------------
-- stencil_fabrication_capabilities
-- -----------------------------------------------------------------------------

CREATE INDEX idx_sfc_org ON app.stencil_fabrication_capabilities (organization_id);
