-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-004A: Engineering Knowledge Core
-- File: DB004A_Triggers.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB004A_Knowledge_Core.sql, DB004A_Functions.sql, DB004A_Indexes.sql
-- Prerequisites: DB001_Triggers.sql (fn_set_updated_at, fn_audit_trigger,
--               fn_set_created_updated_by, fn_soft_delete_check)
-- =============================================================================

BEGIN;

-- =============================================================================
-- knowledge_sources
-- =============================================================================

DROP TRIGGER IF EXISTS tg_knowledge_sources_updated_at ON knowledge_sources;
CREATE TRIGGER tg_knowledge_sources_updated_at
    BEFORE UPDATE ON knowledge_sources
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_knowledge_sources_created_by ON knowledge_sources;
CREATE TRIGGER tg_knowledge_sources_created_by
    BEFORE INSERT OR UPDATE ON knowledge_sources
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- engineering_rule_categories
-- =============================================================================

DROP TRIGGER IF EXISTS tg_engineering_rule_categories_updated_at ON engineering_rule_categories;
CREATE TRIGGER tg_engineering_rule_categories_updated_at
    BEFORE UPDATE ON engineering_rule_categories
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_engineering_rule_categories_created_by ON engineering_rule_categories;
CREATE TRIGGER tg_engineering_rule_categories_created_by
    BEFORE INSERT OR UPDATE ON engineering_rule_categories
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- engineering_rules
-- =============================================================================

DROP TRIGGER IF EXISTS tg_engineering_rules_updated_at ON engineering_rules;
CREATE TRIGGER tg_engineering_rules_updated_at
    BEFORE UPDATE ON engineering_rules
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_engineering_rules_created_by ON engineering_rules;
CREATE TRIGGER tg_engineering_rules_created_by
    BEFORE INSERT OR UPDATE ON engineering_rules
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_engineering_rules_audit ON engineering_rules;
CREATE TRIGGER tg_engineering_rules_audit
    AFTER INSERT OR UPDATE OR DELETE ON engineering_rules
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_engineering_rules_no_hard_delete ON engineering_rules;
CREATE TRIGGER tg_engineering_rules_no_hard_delete
    BEFORE DELETE ON engineering_rules
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- engineering_rule_versions
-- =============================================================================

DROP TRIGGER IF EXISTS tg_engineering_rule_versions_updated_at ON engineering_rule_versions;
CREATE TRIGGER tg_engineering_rule_versions_updated_at
    BEFORE UPDATE ON engineering_rule_versions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_engineering_rule_versions_created_by ON engineering_rule_versions;
CREATE TRIGGER tg_engineering_rule_versions_created_by
    BEFORE INSERT OR UPDATE ON engineering_rule_versions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- Enforce single current version BEFORE insert/update
DROP TRIGGER IF EXISTS tg_engineering_rule_versions_current_enforce ON engineering_rule_versions;
CREATE TRIGGER tg_engineering_rule_versions_current_enforce
    BEFORE INSERT OR UPDATE OF is_current ON engineering_rule_versions
    FOR EACH ROW
    WHEN (NEW.is_current = TRUE)
    EXECUTE FUNCTION fn_rule_version_current_enforce();

-- Block modification of approved versions
DROP TRIGGER IF EXISTS tg_engineering_rule_versions_immutable ON engineering_rule_versions;
CREATE TRIGGER tg_engineering_rule_versions_immutable
    BEFORE UPDATE ON engineering_rule_versions
    FOR EACH ROW
    WHEN (OLD.approved_at IS NOT NULL)
    EXECUTE FUNCTION fn_rule_version_immutable();

DROP TRIGGER IF EXISTS tg_engineering_rule_versions_audit ON engineering_rule_versions;
CREATE TRIGGER tg_engineering_rule_versions_audit
    AFTER INSERT OR UPDATE OR DELETE ON engineering_rule_versions
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- engineering_rule_conditions
-- =============================================================================

DROP TRIGGER IF EXISTS tg_engineering_rule_conditions_updated_at ON engineering_rule_conditions;
CREATE TRIGGER tg_engineering_rule_conditions_updated_at
    BEFORE UPDATE ON engineering_rule_conditions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_engineering_rule_conditions_created_by ON engineering_rule_conditions;
CREATE TRIGGER tg_engineering_rule_conditions_created_by
    BEFORE INSERT OR UPDATE ON engineering_rule_conditions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- engineering_rule_actions
-- =============================================================================

DROP TRIGGER IF EXISTS tg_engineering_rule_actions_updated_at ON engineering_rule_actions;
CREATE TRIGGER tg_engineering_rule_actions_updated_at
    BEFORE UPDATE ON engineering_rule_actions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_engineering_rule_actions_created_by ON engineering_rule_actions;
CREATE TRIGGER tg_engineering_rule_actions_created_by
    BEFORE INSERT OR UPDATE ON engineering_rule_actions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- engineering_rule_priorities
-- =============================================================================

DROP TRIGGER IF EXISTS tg_engineering_rule_priorities_updated_at ON engineering_rule_priorities;
CREATE TRIGGER tg_engineering_rule_priorities_updated_at
    BEFORE UPDATE ON engineering_rule_priorities
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_engineering_rule_priorities_created_by ON engineering_rule_priorities;
CREATE TRIGGER tg_engineering_rule_priorities_created_by
    BEFORE INSERT OR UPDATE ON engineering_rule_priorities
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_engineering_rule_priorities_audit ON engineering_rule_priorities;
CREATE TRIGGER tg_engineering_rule_priorities_audit
    AFTER INSERT OR UPDATE OR DELETE ON engineering_rule_priorities
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- engineering_rule_references
-- =============================================================================

DROP TRIGGER IF EXISTS tg_engineering_rule_references_updated_at ON engineering_rule_references;
CREATE TRIGGER tg_engineering_rule_references_updated_at
    BEFORE UPDATE ON engineering_rule_references
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_engineering_rule_references_created_by ON engineering_rule_references;
CREATE TRIGGER tg_engineering_rule_references_created_by
    BEFORE INSERT OR UPDATE ON engineering_rule_references
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- rule_conflicts
-- =============================================================================

DROP TRIGGER IF EXISTS tg_rule_conflicts_updated_at ON rule_conflicts;
CREATE TRIGGER tg_rule_conflicts_updated_at
    BEFORE UPDATE ON rule_conflicts
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_rule_conflicts_created_by ON rule_conflicts;
CREATE TRIGGER tg_rule_conflicts_created_by
    BEFORE INSERT OR UPDATE ON rule_conflicts
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_rule_conflicts_audit ON rule_conflicts;
CREATE TRIGGER tg_rule_conflicts_audit
    AFTER INSERT OR UPDATE OR DELETE ON rule_conflicts
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- rule_comparison_results
-- =============================================================================

DROP TRIGGER IF EXISTS tg_rule_comparison_results_updated_at ON rule_comparison_results;
CREATE TRIGGER tg_rule_comparison_results_updated_at
    BEFORE UPDATE ON rule_comparison_results
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_rule_comparison_results_created_by ON rule_comparison_results;
CREATE TRIGGER tg_rule_comparison_results_created_by
    BEFORE INSERT OR UPDATE ON rule_comparison_results
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- what_if_scenarios
-- =============================================================================

DROP TRIGGER IF EXISTS tg_what_if_scenarios_updated_at ON what_if_scenarios;
CREATE TRIGGER tg_what_if_scenarios_updated_at
    BEFORE UPDATE ON what_if_scenarios
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_what_if_scenarios_created_by ON what_if_scenarios;
CREATE TRIGGER tg_what_if_scenarios_created_by
    BEFORE INSERT OR UPDATE ON what_if_scenarios
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_what_if_scenarios_activity ON what_if_scenarios;
CREATE TRIGGER tg_what_if_scenarios_activity
    AFTER INSERT OR UPDATE OF status ON what_if_scenarios
    FOR EACH ROW
    EXECUTE FUNCTION fn_what_if_scenario_activity();

DROP TRIGGER IF EXISTS tg_what_if_scenarios_no_hard_delete ON what_if_scenarios;
CREATE TRIGGER tg_what_if_scenarios_no_hard_delete
    BEFORE DELETE ON what_if_scenarios
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- what_if_parameters
-- =============================================================================

DROP TRIGGER IF EXISTS tg_what_if_parameters_updated_at ON what_if_parameters;
CREATE TRIGGER tg_what_if_parameters_updated_at
    BEFORE UPDATE ON what_if_parameters
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_what_if_parameters_created_by ON what_if_parameters;
CREATE TRIGGER tg_what_if_parameters_created_by
    BEFORE INSERT OR UPDATE ON what_if_parameters
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- what_if_results
-- =============================================================================

DROP TRIGGER IF EXISTS tg_what_if_results_updated_at ON what_if_results;
CREATE TRIGGER tg_what_if_results_updated_at
    BEFORE UPDATE ON what_if_results
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_what_if_results_created_by ON what_if_results;
CREATE TRIGGER tg_what_if_results_created_by
    BEFORE INSERT OR UPDATE ON what_if_results
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- what_if_defect_predictions  (append-only — no UPDATE or DELETE)
-- =============================================================================

-- No updated_at trigger (append-only — no UPDATE permitted on this table)
-- Enforce append-only via RLS policies (SELECT + INSERT only)

-- =============================================================================
-- rule_approval_requests
-- =============================================================================

DROP TRIGGER IF EXISTS tg_rule_approval_requests_updated_at ON rule_approval_requests;
CREATE TRIGGER tg_rule_approval_requests_updated_at
    BEFORE UPDATE ON rule_approval_requests
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_rule_approval_requests_created_by ON rule_approval_requests;
CREATE TRIGGER tg_rule_approval_requests_created_by
    BEFORE INSERT OR UPDATE ON rule_approval_requests
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_rule_approval_requests_audit ON rule_approval_requests;
CREATE TRIGGER tg_rule_approval_requests_audit
    AFTER INSERT OR UPDATE OR DELETE ON rule_approval_requests
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_rule_approval_requests_no_hard_delete ON rule_approval_requests;
CREATE TRIGGER tg_rule_approval_requests_no_hard_delete
    BEFORE DELETE ON rule_approval_requests
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- rule_approvals
-- =============================================================================

DROP TRIGGER IF EXISTS tg_rule_approvals_updated_at ON rule_approvals;
CREATE TRIGGER tg_rule_approvals_updated_at
    BEFORE UPDATE ON rule_approvals
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_rule_approvals_created_by ON rule_approvals;
CREATE TRIGGER tg_rule_approvals_created_by
    BEFORE INSERT OR UPDATE ON rule_approvals
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- Update parent approval request status after each decision
DROP TRIGGER IF EXISTS tg_rule_approvals_status_update ON rule_approvals;
CREATE TRIGGER tg_rule_approvals_status_update
    AFTER INSERT ON rule_approvals
    FOR EACH ROW
    EXECUTE FUNCTION fn_approval_request_status_update();

DROP TRIGGER IF EXISTS tg_rule_approvals_audit ON rule_approvals;
CREATE TRIGGER tg_rule_approvals_audit
    AFTER INSERT OR UPDATE OR DELETE ON rule_approvals
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- rule_effectiveness_history
-- =============================================================================

DROP TRIGGER IF EXISTS tg_rule_effectiveness_history_updated_at ON rule_effectiveness_history;
CREATE TRIGGER tg_rule_effectiveness_history_updated_at
    BEFORE UPDATE ON rule_effectiveness_history
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_rule_effectiveness_history_created_by ON rule_effectiveness_history;
CREATE TRIGGER tg_rule_effectiveness_history_created_by
    BEFORE INSERT OR UPDATE ON rule_effectiveness_history
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- customer_rule_profiles
-- =============================================================================

DROP TRIGGER IF EXISTS tg_customer_rule_profiles_updated_at ON customer_rule_profiles;
CREATE TRIGGER tg_customer_rule_profiles_updated_at
    BEFORE UPDATE ON customer_rule_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_customer_rule_profiles_created_by ON customer_rule_profiles;
CREATE TRIGGER tg_customer_rule_profiles_created_by
    BEFORE INSERT OR UPDATE ON customer_rule_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_customer_rule_profiles_audit ON customer_rule_profiles;
CREATE TRIGGER tg_customer_rule_profiles_audit
    AFTER INSERT OR UPDATE OR DELETE ON customer_rule_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_customer_rule_profiles_no_hard_delete ON customer_rule_profiles;
CREATE TRIGGER tg_customer_rule_profiles_no_hard_delete
    BEFORE DELETE ON customer_rule_profiles
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- company_rule_profiles
-- =============================================================================

DROP TRIGGER IF EXISTS tg_company_rule_profiles_updated_at ON company_rule_profiles;
CREATE TRIGGER tg_company_rule_profiles_updated_at
    BEFORE UPDATE ON company_rule_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_company_rule_profiles_created_by ON company_rule_profiles;
CREATE TRIGGER tg_company_rule_profiles_created_by
    BEFORE INSERT OR UPDATE ON company_rule_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- engineer_rule_profiles
-- =============================================================================

DROP TRIGGER IF EXISTS tg_engineer_rule_profiles_updated_at ON engineer_rule_profiles;
CREATE TRIGGER tg_engineer_rule_profiles_updated_at
    BEFORE UPDATE ON engineer_rule_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_engineer_rule_profiles_created_by ON engineer_rule_profiles;
CREATE TRIGGER tg_engineer_rule_profiles_created_by
    BEFORE INSERT OR UPDATE ON engineer_rule_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- ai_recommendation_profiles
-- =============================================================================

DROP TRIGGER IF EXISTS tg_ai_recommendation_profiles_updated_at ON ai_recommendation_profiles;
CREATE TRIGGER tg_ai_recommendation_profiles_updated_at
    BEFORE UPDATE ON ai_recommendation_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_ai_recommendation_profiles_created_by ON ai_recommendation_profiles;
CREATE TRIGGER tg_ai_recommendation_profiles_created_by
    BEFORE INSERT OR UPDATE ON ai_recommendation_profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- decision_explanations  (append-only)
-- =============================================================================

-- No update_at or created_by triggers: decision_explanations is append-only.
-- created_at is set once at insert. No updates permitted.

-- =============================================================================
-- engineering_confidence_scores  (append-only)
-- =============================================================================

-- Append-only: no update triggers. updated_at column not present.
-- All writes go through fn_rule_confidence_update() which handles the insert.

COMMIT;
