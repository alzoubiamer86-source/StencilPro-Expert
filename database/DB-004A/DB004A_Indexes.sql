-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-004A: Engineering Knowledge Core
-- File: DB004A_Indexes.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB004A_Knowledge_Core.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- knowledge_sources
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_knowledge_sources_code
    ON knowledge_sources (code)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_knowledge_sources_priority
    ON knowledge_sources (base_priority DESC)
    WHERE is_active = TRUE;

-- =============================================================================
-- engineering_rule_categories
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineering_rule_categories_code
    ON engineering_rule_categories (code)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_categories_parent
    ON engineering_rule_categories (parent_category_id)
    WHERE parent_category_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_categories_domain
    ON engineering_rule_categories (domain)
    WHERE is_active = TRUE;

-- GIN for applies_to array membership
CREATE INDEX IF NOT EXISTS idx_engineering_rule_categories_applies_to_gin
    ON engineering_rule_categories USING GIN (applies_to);

-- =============================================================================
-- engineering_rules
-- =============================================================================

-- Primary lookups
CREATE INDEX IF NOT EXISTS idx_engineering_rules_organization_id
    ON engineering_rules (organization_id)
    WHERE is_deleted = FALSE AND organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_system_rules
    ON engineering_rules (knowledge_source_id, is_active)
    WHERE is_deleted = FALSE AND organization_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_category_id
    ON engineering_rules (category_id)
    WHERE is_deleted = FALSE AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_knowledge_source_id
    ON engineering_rules (knowledge_source_id)
    WHERE is_deleted = FALSE AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_severity
    ON engineering_rules (severity, is_active)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_rule_type
    ON engineering_rules (rule_type)
    WHERE is_deleted = FALSE AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_ipc_class_scope
    ON engineering_rules (ipc_class_scope)
    WHERE is_deleted = FALSE AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rules_priority_score
    ON engineering_rules (priority_score DESC)
    WHERE is_deleted = FALSE AND is_active = TRUE;

-- Rule code lookup (used by rule engine)
CREATE INDEX IF NOT EXISTS idx_engineering_rules_rule_code
    ON engineering_rules (rule_code)
    WHERE is_deleted = FALSE;

-- Active non-deprecated rules (primary rule engine query)
CREATE INDEX IF NOT EXISTS idx_engineering_rules_active_current
    ON engineering_rules (organization_id, knowledge_source_id, category_id, severity)
    WHERE is_active = TRUE AND is_deleted = FALSE AND deprecated_at IS NULL;

-- Supersession chain
CREATE INDEX IF NOT EXISTS idx_engineering_rules_superseded_by
    ON engineering_rules (superseded_by_rule_id)
    WHERE superseded_by_rule_id IS NOT NULL;

-- Engineer-created rules
CREATE INDEX IF NOT EXISTS idx_engineering_rules_created_by_engineer
    ON engineering_rules (created_by_engineer_id)
    WHERE created_by_engineer_id IS NOT NULL;

-- GIN for related defect codes array
CREATE INDEX IF NOT EXISTS idx_engineering_rules_defect_codes_gin
    ON engineering_rules USING GIN (related_defect_type_codes);

-- GIN for related rule IDs array
CREATE INDEX IF NOT EXISTS idx_engineering_rules_related_ids_gin
    ON engineering_rules USING GIN (related_rule_ids);

-- Full-text search on rule name + rationale
CREATE INDEX IF NOT EXISTS idx_engineering_rules_fts
    ON engineering_rules USING GIN (
        to_tsvector('english',
            COALESCE(rule_code, '') || ' ' ||
            COALESCE(name, '') || ' ' ||
            COALESCE(engineering_rationale, '')
        )
    );

-- =============================================================================
-- engineering_rule_versions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineering_rule_versions_rule_id
    ON engineering_rule_versions (rule_id);

CREATE INDEX IF NOT EXISTS idx_engineering_rule_versions_organization_id
    ON engineering_rule_versions (organization_id)
    WHERE organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_versions_current
    ON engineering_rule_versions (rule_id, is_current)
    WHERE is_current = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_versions_authored_by
    ON engineering_rule_versions (authored_by_engineer_id);

CREATE INDEX IF NOT EXISTS idx_engineering_rule_versions_approved_by
    ON engineering_rule_versions (approved_by_engineer_id)
    WHERE approved_by_engineer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_versions_effective_range
    ON engineering_rule_versions (rule_id, effective_from DESC, effective_until);

-- =============================================================================
-- engineering_rule_conditions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineering_rule_conditions_rule_id
    ON engineering_rule_conditions (rule_id);

CREATE INDEX IF NOT EXISTS idx_engineering_rule_conditions_type
    ON engineering_rule_conditions (rule_id, condition_type);

CREATE INDEX IF NOT EXISTS idx_engineering_rule_conditions_parameter
    ON engineering_rule_conditions (parameter_name);

CREATE INDEX IF NOT EXISTS idx_engineering_rule_conditions_parent
    ON engineering_rule_conditions (parent_condition_id)
    WHERE parent_condition_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_conditions_group
    ON engineering_rule_conditions (rule_id, group_id)
    WHERE group_id IS NOT NULL;

-- =============================================================================
-- engineering_rule_actions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineering_rule_actions_rule_id
    ON engineering_rule_actions (rule_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_actions_type
    ON engineering_rule_actions (action_type)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_actions_trigger_on
    ON engineering_rule_actions (rule_id, trigger_on)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_actions_blocks_approval
    ON engineering_rule_actions (rule_id, blocks_approval)
    WHERE blocks_approval = TRUE AND is_active = TRUE;

-- =============================================================================
-- engineering_rule_priorities
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineering_rule_priorities_rule_id
    ON engineering_rule_priorities (rule_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_priorities_organization_id
    ON engineering_rule_priorities (organization_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_priorities_scope
    ON engineering_rule_priorities (organization_id, scope_type, scope_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineering_rule_priorities_rule_scope
    ON engineering_rule_priorities (rule_id, organization_id, scope_type)
    WHERE is_active = TRUE AND (effective_until IS NULL OR effective_until > NOW());

-- =============================================================================
-- engineering_rule_references
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineering_rule_references_rule_id
    ON engineering_rule_references (rule_id);

CREATE INDEX IF NOT EXISTS idx_engineering_rule_references_type
    ON engineering_rule_references (reference_type);

CREATE INDEX IF NOT EXISTS idx_engineering_rule_references_code
    ON engineering_rule_references (reference_code);

-- =============================================================================
-- rule_conflicts
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_rule_conflicts_organization_id
    ON rule_conflicts (organization_id);

CREATE INDEX IF NOT EXISTS idx_rule_conflicts_stencil_design_id
    ON rule_conflicts (stencil_design_id)
    WHERE stencil_design_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_rule_conflicts_rule_a_id
    ON rule_conflicts (rule_a_id);

CREATE INDEX IF NOT EXISTS idx_rule_conflicts_rule_b_id
    ON rule_conflicts (rule_b_id);

CREATE INDEX IF NOT EXISTS idx_rule_conflicts_unresolved
    ON rule_conflicts (organization_id, is_resolved, detected_at DESC)
    WHERE is_resolved = FALSE;

CREATE INDEX IF NOT EXISTS idx_rule_conflicts_requires_decision
    ON rule_conflicts (organization_id, requires_engineer_decision)
    WHERE requires_engineer_decision = TRUE AND is_resolved = FALSE;

CREATE INDEX IF NOT EXISTS idx_rule_conflicts_conflict_type
    ON rule_conflicts (organization_id, conflict_type);

-- =============================================================================
-- rule_comparison_results
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_rule_comparison_results_organization_id
    ON rule_comparison_results (organization_id);

CREATE INDEX IF NOT EXISTS idx_rule_comparison_results_stencil_design_id
    ON rule_comparison_results (stencil_design_id)
    WHERE stencil_design_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_rule_comparison_results_aperture_design_id
    ON rule_comparison_results (aperture_design_id)
    WHERE aperture_design_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_rule_comparison_results_compared_by
    ON rule_comparison_results (compared_by_engineer_id);

CREATE INDEX IF NOT EXISTS idx_rule_comparison_results_compared_at
    ON rule_comparison_results (organization_id, compared_at DESC);

CREATE INDEX IF NOT EXISTS idx_rule_comparison_results_selected_source
    ON rule_comparison_results (organization_id, selected_source)
    WHERE selected_source IS NOT NULL;

-- =============================================================================
-- what_if_scenarios
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_what_if_scenarios_organization_id
    ON what_if_scenarios (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_what_if_scenarios_project_id
    ON what_if_scenarios (project_id)
    WHERE project_id IS NOT NULL AND is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_what_if_scenarios_stencil_design_id
    ON what_if_scenarios (stencil_design_id)
    WHERE stencil_design_id IS NOT NULL AND is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_what_if_scenarios_created_by
    ON what_if_scenarios (created_by_engineer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_what_if_scenarios_status
    ON what_if_scenarios (organization_id, status)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_what_if_scenarios_type
    ON what_if_scenarios (organization_id, scenario_type)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_what_if_scenarios_saved
    ON what_if_scenarios (organization_id, is_saved, created_at DESC)
    WHERE is_deleted = FALSE AND is_saved = TRUE;

-- =============================================================================
-- what_if_parameters
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_what_if_parameters_scenario_id
    ON what_if_parameters (scenario_id);

CREATE INDEX IF NOT EXISTS idx_what_if_parameters_organization_id
    ON what_if_parameters (organization_id);

CREATE INDEX IF NOT EXISTS idx_what_if_parameters_parameter_name
    ON what_if_parameters (scenario_id, parameter_name);

CREATE INDEX IF NOT EXISTS idx_what_if_parameters_category
    ON what_if_parameters (scenario_id, parameter_category);

-- =============================================================================
-- what_if_results
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_what_if_results_scenario_id
    ON what_if_results (scenario_id);

CREATE INDEX IF NOT EXISTS idx_what_if_results_organization_id
    ON what_if_results (organization_id);

CREATE INDEX IF NOT EXISTS idx_what_if_results_evaluated_by
    ON what_if_results (evaluated_by_engineer_id);

CREATE INDEX IF NOT EXISTS idx_what_if_results_evaluated_at
    ON what_if_results (scenario_id, evaluated_at DESC);

CREATE INDEX IF NOT EXISTS idx_what_if_results_applied
    ON what_if_results (scenario_id, was_applied_to_design)
    WHERE was_applied_to_design = TRUE;

CREATE INDEX IF NOT EXISTS idx_what_if_results_rule_check_status
    ON what_if_results (organization_id, rule_check_status);

-- =============================================================================
-- what_if_defect_predictions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_what_if_defect_predictions_result_id
    ON what_if_defect_predictions (what_if_result_id);

CREATE INDEX IF NOT EXISTS idx_what_if_defect_predictions_organization_id
    ON what_if_defect_predictions (organization_id);

CREATE INDEX IF NOT EXISTS idx_what_if_defect_predictions_defect_code
    ON what_if_defect_predictions (defect_type_code);

CREATE INDEX IF NOT EXISTS idx_what_if_defect_predictions_risk_bands
    ON what_if_defect_predictions (what_if_result_id, risk_band_modified);

-- =============================================================================
-- rule_approval_requests
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_rule_approval_requests_organization_id
    ON rule_approval_requests (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_rule_approval_requests_rule_id
    ON rule_approval_requests (rule_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_rule_approval_requests_requested_by
    ON rule_approval_requests (requested_by_engineer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_rule_approval_requests_target_approver
    ON rule_approval_requests (target_approver_id)
    WHERE target_approver_id IS NOT NULL AND is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_rule_approval_requests_status
    ON rule_approval_requests (organization_id, status)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_rule_approval_requests_pending
    ON rule_approval_requests (organization_id, created_at DESC)
    WHERE status = 'pending' AND is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_rule_approval_requests_type
    ON rule_approval_requests (organization_id, request_type)
    WHERE is_deleted = FALSE;

-- =============================================================================
-- rule_approvals
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_rule_approvals_approval_request_id
    ON rule_approvals (approval_request_id);

CREATE INDEX IF NOT EXISTS idx_rule_approvals_organization_id
    ON rule_approvals (organization_id);

CREATE INDEX IF NOT EXISTS idx_rule_approvals_approver_engineer_id
    ON rule_approvals (approver_engineer_id);

CREATE INDEX IF NOT EXISTS idx_rule_approvals_decision
    ON rule_approvals (approval_request_id, decision);

-- =============================================================================
-- rule_effectiveness_history
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_rule_effectiveness_history_rule_id
    ON rule_effectiveness_history (rule_id);

CREATE INDEX IF NOT EXISTS idx_rule_effectiveness_history_organization_id
    ON rule_effectiveness_history (organization_id);

CREATE INDEX IF NOT EXISTS idx_rule_effectiveness_history_period
    ON rule_effectiveness_history (rule_id, evaluation_period_start DESC);

CREATE INDEX IF NOT EXISTS idx_rule_effectiveness_history_score
    ON rule_effectiveness_history (organization_id, effectiveness_score DESC);

-- =============================================================================
-- customer_rule_profiles
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_customer_rule_profiles_organization_id
    ON customer_rule_profiles (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_customer_rule_profiles_customer_id
    ON customer_rule_profiles (customer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_customer_rule_profiles_active
    ON customer_rule_profiles (customer_id, is_active)
    WHERE is_deleted = FALSE AND is_active = TRUE;

-- GIN for required_rule_ids array
CREATE INDEX IF NOT EXISTS idx_customer_rule_profiles_required_rules_gin
    ON customer_rule_profiles USING GIN (required_rule_ids);

CREATE INDEX IF NOT EXISTS idx_customer_rule_profiles_prohibited_rules_gin
    ON customer_rule_profiles USING GIN (prohibited_rule_ids);

-- =============================================================================
-- company_rule_profiles
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_company_rule_profiles_organization_id
    ON company_rule_profiles (organization_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_company_rule_profiles_type
    ON company_rule_profiles (organization_id, profile_type)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_company_rule_profiles_default
    ON company_rule_profiles (organization_id, is_default)
    WHERE is_active = TRUE AND is_default = TRUE;

-- =============================================================================
-- engineer_rule_profiles
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineer_rule_profiles_engineer_id
    ON engineer_rule_profiles (engineer_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_engineer_rule_profiles_organization_id
    ON engineer_rule_profiles (organization_id)
    WHERE is_active = TRUE;

-- =============================================================================
-- ai_recommendation_profiles
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_ai_recommendation_profiles_organization_id
    ON ai_recommendation_profiles (organization_id)
    WHERE is_active = TRUE;

-- =============================================================================
-- decision_explanations
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_decision_explanations_organization_id
    ON decision_explanations (organization_id);

CREATE INDEX IF NOT EXISTS idx_decision_explanations_source_entity
    ON decision_explanations (source_entity_type, source_entity_id);

CREATE INDEX IF NOT EXISTS idx_decision_explanations_rule_id
    ON decision_explanations (rule_id)
    WHERE rule_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_decision_explanations_decision_type
    ON decision_explanations (organization_id, decision_type);

CREATE INDEX IF NOT EXISTS idx_decision_explanations_created_at
    ON decision_explanations (organization_id, created_at DESC);

-- Full-text on explanation level 1 (most frequently searched)
CREATE INDEX IF NOT EXISTS idx_decision_explanations_fts
    ON decision_explanations USING GIN (
        to_tsvector('english',
            COALESCE(explanation_level_1, '') || ' ' ||
            COALESCE(explanation_level_2, '')
        )
    );

-- =============================================================================
-- engineering_confidence_scores
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineering_confidence_scores_rule_id
    ON engineering_confidence_scores (rule_id);

CREATE INDEX IF NOT EXISTS idx_engineering_confidence_scores_organization_id
    ON engineering_confidence_scores (organization_id);

CREATE INDEX IF NOT EXISTS idx_engineering_confidence_scores_updated_at
    ON engineering_confidence_scores (rule_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_engineering_confidence_scores_update_reason
    ON engineering_confidence_scores (update_reason);

CREATE INDEX IF NOT EXISTS idx_engineering_confidence_scores_source_entity
    ON engineering_confidence_scores (source_entity_type, source_entity_id)
    WHERE source_entity_id IS NOT NULL;

COMMIT;
