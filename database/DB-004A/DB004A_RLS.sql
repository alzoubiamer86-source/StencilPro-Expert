-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-004A: Engineering Knowledge Core
-- File: DB004A_RLS.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB004A_Knowledge_Core.sql, DB004A_Functions.sql,
--          DB004A_Indexes.sql, DB004A_Triggers.sql
-- Prerequisites: DB001_RLS.sql, DB002_RLS.sql, DB003_RLS.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE knowledge_sources              ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_categories    ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineering_rules              ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_versions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_conditions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_actions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_priorities    ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_references    ENABLE ROW LEVEL SECURITY;
ALTER TABLE rule_conflicts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE rule_comparison_results        ENABLE ROW LEVEL SECURITY;
ALTER TABLE what_if_scenarios              ENABLE ROW LEVEL SECURITY;
ALTER TABLE what_if_parameters             ENABLE ROW LEVEL SECURITY;
ALTER TABLE what_if_results                ENABLE ROW LEVEL SECURITY;
ALTER TABLE what_if_defect_predictions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE rule_approval_requests         ENABLE ROW LEVEL SECURITY;
ALTER TABLE rule_approvals                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE rule_effectiveness_history     ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_rule_profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_rule_profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_rule_profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_recommendation_profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE decision_explanations          ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineering_confidence_scores  ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- FORCE RLS (applies even to table owners)
-- =============================================================================

ALTER TABLE knowledge_sources              FORCE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_categories    FORCE ROW LEVEL SECURITY;
ALTER TABLE engineering_rules              FORCE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_versions      FORCE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_conditions    FORCE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_actions       FORCE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_priorities    FORCE ROW LEVEL SECURITY;
ALTER TABLE engineering_rule_references    FORCE ROW LEVEL SECURITY;
ALTER TABLE rule_conflicts                 FORCE ROW LEVEL SECURITY;
ALTER TABLE rule_comparison_results        FORCE ROW LEVEL SECURITY;
ALTER TABLE what_if_scenarios              FORCE ROW LEVEL SECURITY;
ALTER TABLE what_if_parameters             FORCE ROW LEVEL SECURITY;
ALTER TABLE what_if_results                FORCE ROW LEVEL SECURITY;
ALTER TABLE what_if_defect_predictions     FORCE ROW LEVEL SECURITY;
ALTER TABLE rule_approval_requests         FORCE ROW LEVEL SECURITY;
ALTER TABLE rule_approvals                 FORCE ROW LEVEL SECURITY;
ALTER TABLE rule_effectiveness_history     FORCE ROW LEVEL SECURITY;
ALTER TABLE customer_rule_profiles         FORCE ROW LEVEL SECURITY;
ALTER TABLE company_rule_profiles          FORCE ROW LEVEL SECURITY;
ALTER TABLE engineer_rule_profiles         FORCE ROW LEVEL SECURITY;
ALTER TABLE ai_recommendation_profiles     FORCE ROW LEVEL SECURITY;
ALTER TABLE decision_explanations          FORCE ROW LEVEL SECURITY;
ALTER TABLE engineering_confidence_scores  FORCE ROW LEVEL SECURITY;

-- =============================================================================
-- knowledge_sources  (reference data — all authenticated can read)
-- =============================================================================

CREATE POLICY pol_knowledge_sources_select
    ON knowledge_sources FOR SELECT TO authenticated
    USING (TRUE);

CREATE POLICY pol_knowledge_sources_insert
    ON knowledge_sources FOR INSERT TO authenticated
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_knowledge_sources_update
    ON knowledge_sources FOR UPDATE TO authenticated
    USING (fn_is_super_admin())
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_knowledge_sources_delete
    ON knowledge_sources FOR DELETE TO authenticated
    USING (fn_is_super_admin());

-- =============================================================================
-- engineering_rule_categories  (reference data)
-- =============================================================================

CREATE POLICY pol_engineering_rule_categories_select
    ON engineering_rule_categories FOR SELECT TO authenticated
    USING (TRUE);

CREATE POLICY pol_engineering_rule_categories_insert
    ON engineering_rule_categories FOR INSERT TO authenticated
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_engineering_rule_categories_update
    ON engineering_rule_categories FOR UPDATE TO authenticated
    USING (fn_is_super_admin())
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_engineering_rule_categories_delete
    ON engineering_rule_categories FOR DELETE TO authenticated
    USING (fn_is_super_admin());

-- =============================================================================
-- engineering_rules
-- System rules (organization_id IS NULL): readable by all, editable by Super Admin.
-- Org rules: readable by org members, editable by Senior Engineer+.
-- =============================================================================

CREATE POLICY pol_engineering_rules_select
    ON engineering_rules FOR SELECT TO authenticated
    USING (
        is_deleted = FALSE
        AND (
            organization_id IS NULL
            OR fn_engineer_org_matches(organization_id)
        )
    );

CREATE POLICY pol_engineering_rules_insert
    ON engineering_rules FOR INSERT TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
            AND fn_current_engineer_has_permission('rule_set.create')
        )
    );

CREATE POLICY pol_engineering_rules_update
    ON engineering_rules FOR UPDATE TO authenticated
    USING (
        is_deleted = FALSE
        AND (
            fn_is_super_admin()
            OR (
                organization_id = fn_get_current_organization_id()
                AND fn_is_senior_or_above()
                AND fn_current_engineer_has_permission('rule_set.edit')
            )
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

-- Hard delete blocked; soft delete via UPDATE
CREATE POLICY pol_engineering_rules_delete
    ON engineering_rules FOR DELETE TO authenticated
    USING (FALSE);

-- =============================================================================
-- engineering_rule_versions
-- =============================================================================

CREATE POLICY pol_engineering_rule_versions_select
    ON engineering_rule_versions FOR SELECT TO authenticated
    USING (
        organization_id IS NULL
        OR fn_engineer_org_matches(organization_id)
    );

CREATE POLICY pol_engineering_rule_versions_insert
    ON engineering_rule_versions FOR INSERT TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

-- Only is_current and effective_until may be updated on approved versions (trigger enforces)
CREATE POLICY pol_engineering_rule_versions_update
    ON engineering_rule_versions FOR UPDATE TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

-- No delete (version history is permanent)
CREATE POLICY pol_engineering_rule_versions_delete
    ON engineering_rule_versions FOR DELETE TO authenticated
    USING (FALSE);

-- =============================================================================
-- engineering_rule_conditions
-- =============================================================================

CREATE POLICY pol_engineering_rule_conditions_select
    ON engineering_rule_conditions FOR SELECT TO authenticated
    USING (
        organization_id IS NULL
        OR fn_engineer_org_matches(organization_id)
    );

CREATE POLICY pol_engineering_rule_conditions_insert
    ON engineering_rule_conditions FOR INSERT TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

CREATE POLICY pol_engineering_rule_conditions_update
    ON engineering_rule_conditions FOR UPDATE TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

CREATE POLICY pol_engineering_rule_conditions_delete
    ON engineering_rule_conditions FOR DELETE TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

-- =============================================================================
-- engineering_rule_actions
-- =============================================================================

CREATE POLICY pol_engineering_rule_actions_select
    ON engineering_rule_actions FOR SELECT TO authenticated
    USING (
        organization_id IS NULL
        OR fn_engineer_org_matches(organization_id)
    );

CREATE POLICY pol_engineering_rule_actions_insert
    ON engineering_rule_actions FOR INSERT TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

CREATE POLICY pol_engineering_rule_actions_update
    ON engineering_rule_actions FOR UPDATE TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

CREATE POLICY pol_engineering_rule_actions_delete
    ON engineering_rule_actions FOR DELETE TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_senior_or_above()
        )
    );

-- =============================================================================
-- engineering_rule_priorities
-- =============================================================================

CREATE POLICY pol_engineering_rule_priorities_select
    ON engineering_rule_priorities FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_engineering_rule_priorities_insert
    ON engineering_rule_priorities FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_senior_or_above()
    );

CREATE POLICY pol_engineering_rule_priorities_update
    ON engineering_rule_priorities FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_senior_or_above()
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_senior_or_above()
    );

CREATE POLICY pol_engineering_rule_priorities_delete
    ON engineering_rule_priorities FOR DELETE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- engineering_rule_references
-- =============================================================================

CREATE POLICY pol_engineering_rule_references_select
    ON engineering_rule_references FOR SELECT TO authenticated
    USING (TRUE);

CREATE POLICY pol_engineering_rule_references_insert
    ON engineering_rule_references FOR INSERT TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR fn_is_senior_or_above()
    );

CREATE POLICY pol_engineering_rule_references_update
    ON engineering_rule_references FOR UPDATE TO authenticated
    USING (
        fn_is_super_admin()
        OR fn_is_senior_or_above()
    )
    WITH CHECK (
        fn_is_super_admin()
        OR fn_is_senior_or_above()
    );

CREATE POLICY pol_engineering_rule_references_delete
    ON engineering_rule_references FOR DELETE TO authenticated
    USING (fn_is_super_admin() OR fn_is_org_admin());

-- =============================================================================
-- rule_conflicts
-- =============================================================================

CREATE POLICY pol_rule_conflicts_select
    ON rule_conflicts FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_rule_conflicts_insert
    ON rule_conflicts FOR INSERT TO authenticated
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_rule_conflicts_update
    ON rule_conflicts FOR UPDATE TO authenticated
    USING (fn_engineer_org_matches(organization_id))
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_rule_conflicts_delete
    ON rule_conflicts FOR DELETE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- rule_comparison_results
-- =============================================================================

CREATE POLICY pol_rule_comparison_results_select
    ON rule_comparison_results FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_rule_comparison_results_insert
    ON rule_comparison_results FOR INSERT TO authenticated
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_rule_comparison_results_update
    ON rule_comparison_results FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            compared_by_engineer_id = fn_get_current_engineer_id()
            OR fn_is_org_admin()
        )
    )
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_rule_comparison_results_delete
    ON rule_comparison_results FOR DELETE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- what_if_scenarios
-- =============================================================================

CREATE POLICY pol_what_if_scenarios_select
    ON what_if_scenarios FOR SELECT TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
    );

CREATE POLICY pol_what_if_scenarios_insert
    ON what_if_scenarios FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('analysis.run')
    );

CREATE POLICY pol_what_if_scenarios_update
    ON what_if_scenarios FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
        AND (
            created_by_engineer_id = fn_get_current_engineer_id()
            OR fn_is_org_admin()
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            created_by_engineer_id = fn_get_current_engineer_id()
            OR fn_is_org_admin()
        )
    );

-- Hard delete blocked; soft delete via UPDATE
CREATE POLICY pol_what_if_scenarios_delete
    ON what_if_scenarios FOR DELETE TO authenticated
    USING (FALSE);

-- =============================================================================
-- what_if_parameters
-- =============================================================================

CREATE POLICY pol_what_if_parameters_select
    ON what_if_parameters FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_what_if_parameters_insert
    ON what_if_parameters FOR INSERT TO authenticated
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_what_if_parameters_update
    ON what_if_parameters FOR UPDATE TO authenticated
    USING (fn_engineer_org_matches(organization_id))
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_what_if_parameters_delete
    ON what_if_parameters FOR DELETE TO authenticated
    USING (fn_engineer_org_matches(organization_id));

-- =============================================================================
-- what_if_results
-- =============================================================================

CREATE POLICY pol_what_if_results_select
    ON what_if_results FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_what_if_results_insert
    ON what_if_results FOR INSERT TO authenticated
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_what_if_results_update
    ON what_if_results FOR UPDATE TO authenticated
    USING (fn_engineer_org_matches(organization_id))
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_what_if_results_delete
    ON what_if_results FOR DELETE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- what_if_defect_predictions  (append-only: SELECT + INSERT only)
-- =============================================================================

CREATE POLICY pol_what_if_defect_predictions_select
    ON what_if_defect_predictions FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_what_if_defect_predictions_insert
    ON what_if_defect_predictions FOR INSERT TO authenticated
    WITH CHECK (fn_engineer_org_matches(organization_id));

-- UPDATE blocked (append-only)
CREATE POLICY pol_what_if_defect_predictions_update
    ON what_if_defect_predictions FOR UPDATE TO authenticated
    USING (FALSE);

-- DELETE blocked (append-only)
CREATE POLICY pol_what_if_defect_predictions_delete
    ON what_if_defect_predictions FOR DELETE TO authenticated
    USING (FALSE);

-- =============================================================================
-- rule_approval_requests
-- =============================================================================

CREATE POLICY pol_rule_approval_requests_select
    ON rule_approval_requests FOR SELECT TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
        AND (
            -- Requester can see their own requests
            requested_by_engineer_id = fn_get_current_engineer_id()
            -- Target approver can see requests assigned to them
            OR target_approver_id = fn_get_current_engineer_id()
            -- Senior engineers and admins see all
            OR fn_is_senior_or_above()
        )
    );

CREATE POLICY pol_rule_approval_requests_insert
    ON rule_approval_requests FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('aperture.override')
    );

CREATE POLICY pol_rule_approval_requests_update
    ON rule_approval_requests FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
        AND (
            -- Requester can withdraw their own pending requests
            (requested_by_engineer_id = fn_get_current_engineer_id()
             AND status = 'pending')
            OR fn_is_org_admin()
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            requested_by_engineer_id = fn_get_current_engineer_id()
            OR fn_is_org_admin()
        )
    );

-- Hard delete blocked; soft delete via UPDATE
CREATE POLICY pol_rule_approval_requests_delete
    ON rule_approval_requests FOR DELETE TO authenticated
    USING (FALSE);

-- =============================================================================
-- rule_approvals
-- =============================================================================

-- All org members with appropriate role can see approval decisions
CREATE POLICY pol_rule_approvals_select
    ON rule_approvals FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

-- Only Senior Engineers and Admins can make approval decisions
CREATE POLICY pol_rule_approvals_insert
    ON rule_approvals FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_senior_or_above()
        -- Cannot approve own requests
        AND NOT EXISTS (
            SELECT 1 FROM rule_approval_requests rar
            WHERE rar.id = rule_approvals.approval_request_id
              AND rar.requested_by_engineer_id = fn_get_current_engineer_id()
        )
    );

-- Approvals are immutable after creation
CREATE POLICY pol_rule_approvals_update
    ON rule_approvals FOR UPDATE TO authenticated
    USING (FALSE);

CREATE POLICY pol_rule_approvals_delete
    ON rule_approvals FOR DELETE TO authenticated
    USING (FALSE);

-- =============================================================================
-- rule_effectiveness_history
-- =============================================================================

CREATE POLICY pol_rule_effectiveness_history_select
    ON rule_effectiveness_history FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

-- Only system/background jobs insert via fn_rule_effectiveness_compute()
CREATE POLICY pol_rule_effectiveness_history_insert
    ON rule_effectiveness_history FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_rule_effectiveness_history_update
    ON rule_effectiveness_history FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    )
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_rule_effectiveness_history_delete
    ON rule_effectiveness_history FOR DELETE TO authenticated
    USING (fn_is_super_admin());

-- =============================================================================
-- customer_rule_profiles
-- Visible only to the owning organization (never shared cross-org).
-- =============================================================================

CREATE POLICY pol_customer_rule_profiles_select
    ON customer_rule_profiles FOR SELECT TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
    );

CREATE POLICY pol_customer_rule_profiles_insert
    ON customer_rule_profiles FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_customer_rule_profiles_update
    ON customer_rule_profiles FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
        AND fn_is_org_admin()
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- Hard delete blocked
CREATE POLICY pol_customer_rule_profiles_delete
    ON customer_rule_profiles FOR DELETE TO authenticated
    USING (FALSE);

-- =============================================================================
-- company_rule_profiles
-- =============================================================================

CREATE POLICY pol_company_rule_profiles_select
    ON company_rule_profiles FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_company_rule_profiles_insert
    ON company_rule_profiles FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_company_rule_profiles_update
    ON company_rule_profiles FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_company_rule_profiles_delete
    ON company_rule_profiles FOR DELETE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- engineer_rule_profiles
-- =============================================================================

-- Engineers see only their own profile; admins see all in org
CREATE POLICY pol_engineer_rule_profiles_select
    ON engineer_rule_profiles FOR SELECT TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            engineer_id = fn_get_current_engineer_id()
            OR fn_is_org_admin()
        )
    );

CREATE POLICY pol_engineer_rule_profiles_insert
    ON engineer_rule_profiles FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND engineer_id = fn_get_current_engineer_id()
    );

CREATE POLICY pol_engineer_rule_profiles_update
    ON engineer_rule_profiles FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            engineer_id = fn_get_current_engineer_id()
            OR fn_is_org_admin()
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            engineer_id = fn_get_current_engineer_id()
            OR fn_is_org_admin()
        )
    );

CREATE POLICY pol_engineer_rule_profiles_delete
    ON engineer_rule_profiles FOR DELETE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            engineer_id = fn_get_current_engineer_id()
            OR fn_is_org_admin()
        )
    );

-- =============================================================================
-- ai_recommendation_profiles
-- =============================================================================

CREATE POLICY pol_ai_recommendation_profiles_select
    ON ai_recommendation_profiles FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_ai_recommendation_profiles_insert
    ON ai_recommendation_profiles FOR INSERT TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_ai_recommendation_profiles_update
    ON ai_recommendation_profiles FOR UPDATE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_ai_recommendation_profiles_delete
    ON ai_recommendation_profiles FOR DELETE TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- decision_explanations  (append-only: SELECT + INSERT only)
-- =============================================================================

CREATE POLICY pol_decision_explanations_select
    ON decision_explanations FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_decision_explanations_insert
    ON decision_explanations FOR INSERT TO authenticated
    WITH CHECK (fn_engineer_org_matches(organization_id));

-- Append-only: UPDATE and DELETE blocked
CREATE POLICY pol_decision_explanations_update
    ON decision_explanations FOR UPDATE TO authenticated
    USING (FALSE);

CREATE POLICY pol_decision_explanations_delete
    ON decision_explanations FOR DELETE TO authenticated
    USING (FALSE);

-- =============================================================================
-- engineering_confidence_scores  (append-only: SELECT + INSERT only)
-- All writes go through fn_rule_confidence_update() SECURITY DEFINER.
-- =============================================================================

CREATE POLICY pol_engineering_confidence_scores_select
    ON engineering_confidence_scores FOR SELECT TO authenticated
    USING (fn_engineer_org_matches(organization_id));

-- Direct INSERT blocked; only via fn_rule_confidence_update() SECURITY DEFINER
CREATE POLICY pol_engineering_confidence_scores_insert
    ON engineering_confidence_scores FOR INSERT TO authenticated
    WITH CHECK (FALSE);

-- Append-only: UPDATE and DELETE blocked
CREATE POLICY pol_engineering_confidence_scores_update
    ON engineering_confidence_scores FOR UPDATE TO authenticated
    USING (FALSE);

CREATE POLICY pol_engineering_confidence_scores_delete
    ON engineering_confidence_scores FOR DELETE TO authenticated
    USING (FALSE);

COMMIT;
