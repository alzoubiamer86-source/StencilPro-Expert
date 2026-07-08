-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-004A: Engineering Knowledge Core
-- File: DB004A_Functions.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB004A_Knowledge_Core.sql
-- Prerequisites: DB001_Functions.sql, DB002_Functions.sql, DB003_Functions.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- FUNCTION: fn_rule_version_current_enforce
-- Ensures only one version per rule has is_current = TRUE.
-- Fired BEFORE INSERT OR UPDATE on engineering_rule_versions.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_rule_version_current_enforce()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_current = TRUE THEN
        UPDATE engineering_rule_versions
        SET    is_current  = FALSE,
               updated_at  = NOW()
        WHERE  rule_id     = NEW.rule_id
          AND  id         != NEW.id
          AND  is_current  = TRUE;

        -- Set effective_until on the previously current version
        UPDATE engineering_rule_versions
        SET    effective_until = NOW(),
               updated_at     = NOW()
        WHERE  rule_id         = NEW.rule_id
          AND  id             != NEW.id
          AND  effective_until IS NULL
          AND  is_current      = FALSE;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_rule_version_current_enforce() IS
    'BEFORE INSERT OR UPDATE trigger on engineering_rule_versions. '
    'When is_current = TRUE is set on a new version, all prior versions for the same rule '
    'are demoted and their effective_until is set to NOW(). '
    'Enforces single-current-version invariant alongside the partial unique index.';

-- =============================================================================
-- FUNCTION: fn_rule_version_immutable
-- Approved rule versions cannot be modified.
-- Fired BEFORE UPDATE on engineering_rule_versions.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_rule_version_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.approved_at IS NOT NULL THEN
        -- Allow only is_current and effective_until to change on approved versions
        IF (OLD.rule_id                 != NEW.rule_id OR
            OLD.version_number          != NEW.version_number OR
            OLD.rule_snapshot           != NEW.rule_snapshot OR
            OLD.authored_by_engineer_id != NEW.authored_by_engineer_id OR
            OLD.approved_by_engineer_id != NEW.approved_by_engineer_id)
        THEN
            RAISE EXCEPTION
                'Approved rule version % is immutable. '
                'Create a new version to record changes.',
                OLD.id
                USING ERRCODE = 'restrict_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_rule_version_immutable() IS
    'BEFORE UPDATE trigger on engineering_rule_versions. '
    'Prevents modification of approved versions (approved_at IS NOT NULL). '
    'Only is_current and effective_until may be updated after approval.';

-- =============================================================================
-- FUNCTION: fn_approval_request_status_update
-- Updates rule_approval_requests.status when a decision is recorded
-- in rule_approvals. Handles single and multi-approver workflows.
-- Fired AFTER INSERT on rule_approvals.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_approval_request_status_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_decisions   INTEGER;
    v_approved_count    INTEGER;
    v_rejected_count    INTEGER;
    v_request           rule_approval_requests%ROWTYPE;
BEGIN
    SELECT * INTO v_request
    FROM   rule_approval_requests
    WHERE  id = NEW.approval_request_id;

    SELECT
        COUNT(*)::INTEGER,
        COUNT(*) FILTER (WHERE decision IN ('approved','approved_with_conditions'))::INTEGER,
        COUNT(*) FILTER (WHERE decision = 'rejected')::INTEGER
    INTO v_total_decisions, v_approved_count, v_rejected_count
    FROM rule_approvals
    WHERE approval_request_id = NEW.approval_request_id;

    -- Any rejection immediately rejects the request
    IF v_rejected_count > 0 THEN
        UPDATE rule_approval_requests
        SET    status     = 'rejected',
               updated_at = NOW()
        WHERE  id = NEW.approval_request_id;

        -- Notify requester
        PERFORM fn_create_notification(
            v_request.organization_id,
            v_request.requested_by_engineer_id,
            'rule_override_rejected',
            FORMAT('Rule approval request rejected: %s', v_request.title),
            FORMAT(
                'Your rule approval request "%s" has been rejected. '
                'Review the approver''s notes for details.',
                v_request.title
            ),
            'rule_approval_requests',
            NEW.approval_request_id,
            NOW() + INTERVAL '30 days'
        );
        RETURN NEW;
    END IF;

    -- Single approver approval (target_approver_id set) or all required approved
    IF v_approved_count >= 1 THEN
        UPDATE rule_approval_requests
        SET    status     = 'approved',
               updated_at = NOW()
        WHERE  id = NEW.approval_request_id;

        PERFORM fn_create_notification(
            v_request.organization_id,
            v_request.requested_by_engineer_id,
            'rule_override_approved',
            FORMAT('Rule approval request approved: %s', v_request.title),
            FORMAT(
                'Your rule approval request "%s" has been approved.',
                v_request.title
            ),
            'rule_approval_requests',
            NEW.approval_request_id,
            NOW() + INTERVAL '30 days'
        );
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_approval_request_status_update() IS
    'AFTER INSERT trigger on rule_approvals. '
    'Updates the parent rule_approval_request status based on approval decisions. '
    'Any rejection immediately closes the request as rejected. '
    'Any approval closes as approved (single-approver workflow). '
    'Sends in-app notification to the requester on decision.';

-- =============================================================================
-- FUNCTION: fn_what_if_scenario_activity
-- Logs project_activity when a what-if scenario is created or applied.
-- Fired AFTER INSERT OR UPDATE on what_if_scenarios.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_what_if_scenario_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_engineer_id   UUID;
    v_activity_type VARCHAR(100);
    v_summary       VARCHAR(500);
BEGIN
    BEGIN
        v_engineer_id := current_setting('app.current_engineer_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_engineer_id := NEW.created_by_engineer_id;
    END;

    IF TG_OP = 'INSERT' THEN
        v_activity_type := 'what_if.scenario_created';
        v_summary       := FORMAT('What-if scenario "%s" created (%s).', NEW.name, NEW.scenario_type);
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'complete' AND OLD.status != 'complete' THEN
        v_activity_type := 'what_if.scenario_completed';
        v_summary       := FORMAT('What-if scenario "%s" evaluation complete.', NEW.name);
    ELSE
        RETURN NEW;
    END IF;

    IF NEW.project_id IS NOT NULL THEN
        INSERT INTO project_activity (
            project_id, organization_id, engineer_id,
            activity_type, entity_type, entity_id,
            summary, metadata, occurred_at
        ) VALUES (
            NEW.project_id, NEW.organization_id, v_engineer_id,
            v_activity_type, 'what_if_scenarios', NEW.id,
            v_summary,
            jsonb_build_object(
                'scenario_name', NEW.name,
                'scenario_type', NEW.scenario_type,
                'status',        NEW.status
            ),
            NOW()
        );
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_what_if_scenario_activity() IS
    'AFTER INSERT OR UPDATE trigger on what_if_scenarios. '
    'Logs project_activity when a what-if scenario is created or completed.';

-- =============================================================================
-- FUNCTION: fn_rule_confidence_update
-- Updates engineering_rules.base_confidence_pct and logs to
-- engineering_confidence_scores when the Learning Engine fires.
-- Called by the application layer, not a trigger.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_rule_confidence_update(
    p_rule_id               UUID,
    p_organization_id       UUID,
    p_delta                 NUMERIC(6,4),
    p_update_reason         VARCHAR(50),
    p_evidence_type         VARCHAR(30),
    p_evidence_strength     NUMERIC(4,2),
    p_source_entity_type    VARCHAR(50)     DEFAULT NULL,
    p_source_entity_id      UUID            DEFAULT NULL
)
RETURNS NUMERIC(6,4)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_previous_confidence   NUMERIC(6,4);
    v_new_confidence        NUMERIC(6,4);
    v_learning_rate         NUMERIC(6,4) := 0.0500;
BEGIN
    SELECT base_confidence_pct INTO v_previous_confidence
    FROM   engineering_rules
    WHERE  id = p_rule_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rule % not found.', p_rule_id
            USING ERRCODE = 'no_data_found';
    END IF;

    -- Apply learning rate dampening: actual delta = delta * evidence_strength * learning_rate
    v_new_confidence := v_previous_confidence +
                        (p_delta * p_evidence_strength * v_learning_rate);

    -- Clamp to [0.10, 0.99]
    v_new_confidence := GREATEST(0.1000, LEAST(0.9900, v_new_confidence));

    UPDATE engineering_rules
    SET    base_confidence_pct = v_new_confidence,
           updated_at          = NOW()
    WHERE  id = p_rule_id;

    INSERT INTO engineering_confidence_scores (
        id, rule_id, organization_id,
        previous_confidence, new_confidence, delta,
        update_reason, evidence_type, evidence_strength,
        source_entity_type, source_entity_id,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        p_rule_id, p_organization_id,
        v_previous_confidence, v_new_confidence,
        v_new_confidence - v_previous_confidence,
        p_update_reason, p_evidence_type, p_evidence_strength,
        p_source_entity_type, p_source_entity_id,
        NOW()
    );

    RETURN v_new_confidence;
END;
$$;

COMMENT ON FUNCTION fn_rule_confidence_update(UUID,UUID,NUMERIC,VARCHAR,VARCHAR,NUMERIC,VARCHAR,UUID) IS
    'Updates engineering_rules.base_confidence_pct using the Learning Engine formula: '
    'new_confidence = old + (delta * evidence_strength * learning_rate). '
    'Clamps result to [0.10, 0.99] as per Intelligence Specification. '
    'Logs every change to engineering_confidence_scores for full audit trail. '
    'Returns the new confidence value.';

-- =============================================================================
-- FUNCTION: fn_evaluate_rule_priority
-- Returns the effective priority score for a rule in a given context
-- (organization + customer + project). Checks engineering_rule_priorities
-- for scope-specific overrides.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_evaluate_rule_priority(
    p_rule_id           UUID,
    p_organization_id   UUID,
    p_customer_id       UUID    DEFAULT NULL,
    p_project_id        UUID    DEFAULT NULL,
    p_engineer_id       UUID    DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_base_priority         INTEGER;
    v_project_override      INTEGER;
    v_engineer_override     INTEGER;
    v_customer_override     INTEGER;
    v_org_override          INTEGER;
BEGIN
    -- Get base priority from rule
    SELECT priority_score INTO v_base_priority
    FROM   engineering_rules
    WHERE  id = p_rule_id;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Check project-scope override (highest precedence)
    IF p_project_id IS NOT NULL THEN
        SELECT priority_score INTO v_project_override
        FROM   engineering_rule_priorities
        WHERE  rule_id       = p_rule_id
          AND  organization_id = p_organization_id
          AND  scope_type    = 'project'
          AND  scope_id      = p_project_id
          AND  is_active     = TRUE
          AND  (effective_until IS NULL OR effective_until > NOW())
        LIMIT 1;

        IF FOUND THEN RETURN v_project_override; END IF;
    END IF;

    -- Check engineer-scope override
    IF p_engineer_id IS NOT NULL THEN
        SELECT priority_score INTO v_engineer_override
        FROM   engineering_rule_priorities
        WHERE  rule_id       = p_rule_id
          AND  organization_id = p_organization_id
          AND  scope_type    = 'engineer'
          AND  scope_id      = p_engineer_id
          AND  is_active     = TRUE
          AND  (effective_until IS NULL OR effective_until > NOW())
        LIMIT 1;

        IF FOUND THEN RETURN v_engineer_override; END IF;
    END IF;

    -- Check customer-scope override
    IF p_customer_id IS NOT NULL THEN
        SELECT priority_score INTO v_customer_override
        FROM   engineering_rule_priorities
        WHERE  rule_id       = p_rule_id
          AND  organization_id = p_organization_id
          AND  scope_type    = 'customer'
          AND  scope_id      = p_customer_id
          AND  is_active     = TRUE
          AND  (effective_until IS NULL OR effective_until > NOW())
        LIMIT 1;

        IF FOUND THEN RETURN v_customer_override; END IF;
    END IF;

    -- Check organization-scope override
    SELECT priority_score INTO v_org_override
    FROM   engineering_rule_priorities
    WHERE  rule_id       = p_rule_id
      AND  organization_id = p_organization_id
      AND  scope_type    = 'organization'
      AND  scope_id      IS NULL
      AND  is_active     = TRUE
      AND  (effective_until IS NULL OR effective_until > NOW())
    LIMIT 1;

    IF FOUND THEN RETURN v_org_override; END IF;

    -- Return base priority from rule definition
    RETURN v_base_priority;
END;
$$;

COMMENT ON FUNCTION fn_evaluate_rule_priority(UUID,UUID,UUID,UUID,UUID) IS
    'Returns the effective priority score for a rule in a given context. '
    'Evaluates priority overrides in precedence order: '
    'project > engineer > customer > organization > base rule priority. '
    'Used by the Rule Engine to sort and resolve conflicts between rules.';

-- =============================================================================
-- FUNCTION: fn_get_active_rules_for_context
-- Returns all active engineering rules applicable to a given context,
-- with their effective priority scores. Used by the Rule Engine.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_active_rules_for_context(
    p_organization_id   UUID,
    p_customer_id       UUID    DEFAULT NULL,
    p_project_id        UUID    DEFAULT NULL,
    p_engineer_id       UUID    DEFAULT NULL,
    p_ipc_class         VARCHAR DEFAULT 'class_2',
    p_category_codes    TEXT[]  DEFAULT NULL
)
RETURNS TABLE (
    rule_id             UUID,
    rule_code           VARCHAR(50),
    name                VARCHAR(255),
    category_code       VARCHAR(50),
    rule_type           VARCHAR(30),
    severity            VARCHAR(20),
    knowledge_source    VARCHAR(30),
    effective_priority  INTEGER,
    base_confidence_pct NUMERIC(6,4),
    is_overridable      BOOLEAN,
    override_requires_approval BOOLEAN,
    condition_tree      JSONB,
    precondition_tree   JSONB,
    exception_tree      JSONB,
    parameter_name      VARCHAR(100),
    condition_operator  VARCHAR(30),
    threshold_value     NUMERIC(16,6),
    threshold_min       NUMERIC(16,6),
    threshold_max       NUMERIC(16,6),
    threshold_unit      VARCHAR(30),
    message_fail        TEXT,
    message_warning     TEXT,
    engineering_rationale TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        r.id,
        r.rule_code,
        r.name,
        rc.code                 AS category_code,
        r.rule_type,
        r.severity,
        ks.code                 AS knowledge_source,
        fn_evaluate_rule_priority(r.id, p_organization_id, p_customer_id, p_project_id, p_engineer_id),
        r.base_confidence_pct,
        r.is_overridable,
        r.override_requires_approval,
        r.condition_tree,
        r.precondition_tree,
        r.exception_tree,
        r.parameter_name,
        r.condition_operator,
        r.threshold_value,
        r.threshold_min,
        r.threshold_max,
        r.threshold_unit,
        r.message_fail,
        r.message_warning,
        r.engineering_rationale
    FROM  engineering_rules              r
    JOIN  engineering_rule_categories    rc ON rc.id = r.category_id
    JOIN  knowledge_sources              ks ON ks.id = r.knowledge_source_id
    WHERE r.is_active    = TRUE
      AND r.is_deleted   = FALSE
      AND r.deprecated_at IS NULL
      AND (r.organization_id IS NULL OR r.organization_id = p_organization_id)
      AND (
          r.ipc_class_scope = 'all'
          OR (r.ipc_class_scope = 'class_2_and_3' AND p_ipc_class IN ('class_2','class_3'))
          OR (r.ipc_class_scope = 'class_3_only'  AND p_ipc_class = 'class_3')
          OR  r.ipc_class_scope = p_ipc_class
      )
      AND (
          p_category_codes IS NULL
          OR rc.code = ANY(p_category_codes)
      )
    ORDER BY
        fn_evaluate_rule_priority(r.id, p_organization_id, p_customer_id, p_project_id, p_engineer_id) DESC,
        r.severity DESC,
        r.rule_code ASC;
$$;

COMMENT ON FUNCTION fn_get_active_rules_for_context(UUID,UUID,UUID,UUID,VARCHAR,TEXT[]) IS
    'Returns all active engineering rules applicable for the given context, '
    'with effective priority scores calculated via fn_evaluate_rule_priority(). '
    'Filters by: organization scope (system + org rules), IPC class compatibility, '
    'and optional category filter. Results sorted by effective priority descending. '
    'Called by the Rule Evaluation Engine before each rule check run.';

-- =============================================================================
-- FUNCTION: fn_create_what_if_scenario
-- Creates a what-if scenario with a captured base context snapshot.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_create_what_if_scenario(
    p_organization_id       UUID,
    p_project_id            UUID,
    p_stencil_design_id     UUID,
    p_engineer_id           UUID,
    p_name                  VARCHAR(255),
    p_scenario_type         VARCHAR(30),
    p_description           TEXT        DEFAULT NULL,
    p_base_context          JSONB       DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_scenario_id UUID;
BEGIN
    v_scenario_id := gen_random_uuid();

    INSERT INTO what_if_scenarios (
        id, organization_id, project_id, stencil_design_id,
        created_by_engineer_id, name, description,
        scenario_type, base_context_snapshot,
        status, is_saved, is_deleted,
        created_at, updated_at, created_by, updated_by
    ) VALUES (
        v_scenario_id,
        p_organization_id, p_project_id, p_stencil_design_id,
        p_engineer_id, p_name, p_description,
        p_scenario_type, p_base_context,
        'draft', FALSE, FALSE,
        NOW(), NOW(), p_engineer_id, p_engineer_id
    );

    RETURN v_scenario_id;
END;
$$;

COMMENT ON FUNCTION fn_create_what_if_scenario(UUID,UUID,UUID,UUID,VARCHAR,VARCHAR,TEXT,JSONB) IS
    'Creates a new what-if scenario with a captured base context snapshot. '
    'Returns the UUID of the created scenario. '
    'The base_context parameter should be the current ProcessContext JSONB '
    'from the active stencil design analysis.';

-- =============================================================================
-- FUNCTION: fn_record_what_if_result
-- Stores the Intelligence Engine output for a what-if scenario evaluation.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_record_what_if_result(
    p_scenario_id               UUID,
    p_organization_id           UUID,
    p_engineer_id               UUID,
    p_modified_context          JSONB,
    p_rule_check_status         VARCHAR(30),
    p_rules_passed              INTEGER,
    p_rules_failed              INTEGER,
    p_rules_warned              INTEGER,
    p_area_ratio                NUMERIC(8,4)    DEFAULT NULL,
    p_paste_volume_mm3          NUMERIC(12,6)   DEFAULT NULL,
    p_transfer_efficiency_pct   NUMERIC(6,3)    DEFAULT NULL,
    p_predicted_fpy_pct         NUMERIC(6,3)    DEFAULT NULL,
    p_fpy_delta_pct             NUMERIC(6,3)    DEFAULT NULL,
    p_engineering_score         NUMERIC(5,2)    DEFAULT NULL,
    p_score_delta               NUMERIC(6,2)    DEFAULT NULL,
    p_overall_confidence_pct    NUMERIC(6,3)    DEFAULT NULL,
    p_recommendation_summary    TEXT            DEFAULT NULL,
    p_tradeoffs_summary         TEXT            DEFAULT NULL,
    p_rule_check_details        JSONB           DEFAULT '[]',
    p_calculation_details       JSONB           DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result_id UUID;
BEGIN
    v_result_id := gen_random_uuid();

    INSERT INTO what_if_results (
        id, scenario_id, organization_id,
        evaluated_by_engineer_id, modified_context_snapshot,
        rule_check_status, rules_passed, rules_failed, rules_warned,
        area_ratio, paste_volume_mm3, transfer_efficiency_pct,
        predicted_fpy_pct, fpy_delta_pct,
        engineering_score, score_delta,
        overall_confidence_pct,
        recommendation_summary, tradeoffs_summary,
        rule_check_details, calculation_details,
        was_applied_to_design,
        evaluated_at, created_at, updated_at,
        created_by, updated_by
    ) VALUES (
        v_result_id,
        p_scenario_id, p_organization_id,
        p_engineer_id, p_modified_context,
        p_rule_check_status, p_rules_passed, p_rules_failed, p_rules_warned,
        p_area_ratio, p_paste_volume_mm3, p_transfer_efficiency_pct,
        p_predicted_fpy_pct, p_fpy_delta_pct,
        p_engineering_score, p_score_delta,
        p_overall_confidence_pct,
        p_recommendation_summary, p_tradeoffs_summary,
        p_rule_check_details, p_calculation_details,
        FALSE,
        NOW(), NOW(), NOW(),
        p_engineer_id, p_engineer_id
    );

    -- Update scenario status to complete
    UPDATE what_if_scenarios
    SET    status     = 'complete',
           updated_at = NOW()
    WHERE  id = p_scenario_id;

    RETURN v_result_id;
END;
$$;

COMMENT ON FUNCTION fn_record_what_if_result(UUID,UUID,UUID,JSONB,VARCHAR,INTEGER,INTEGER,INTEGER,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC,NUMERIC,TEXT,TEXT,JSONB,JSONB) IS
    'Stores the complete Intelligence Engine output for a what-if scenario evaluation. '
    'Returns the UUID of the created result. '
    'Automatically updates the parent scenario status to complete.';

-- =============================================================================
-- FUNCTION: fn_create_rule_approval_request
-- Creates a rule approval request and notifies target approvers.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_create_rule_approval_request(
    p_organization_id           UUID,
    p_rule_id                   UUID,
    p_rule_version_id           UUID,
    p_request_type              VARCHAR(30),
    p_requested_by_engineer_id  UUID,
    p_target_approver_id        UUID,
    p_title                     VARCHAR(255),
    p_justification             TEXT,
    p_impact_summary            TEXT        DEFAULT NULL,
    p_priority_level            VARCHAR(10) DEFAULT 'normal'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_id UUID;
BEGIN
    IF LENGTH(TRIM(p_justification)) < 50 THEN
        RAISE EXCEPTION
            'Override justification must be at least 50 characters. '
            'Provided: % characters.',
            LENGTH(TRIM(p_justification))
            USING ERRCODE = 'check_violation';
    END IF;

    v_request_id := gen_random_uuid();

    INSERT INTO rule_approval_requests (
        id, organization_id, rule_id, rule_version_id,
        request_type, requested_by_engineer_id, target_approver_id,
        title, justification, impact_summary,
        priority_level, status,
        created_at, updated_at,
        created_by, updated_by
    ) VALUES (
        v_request_id,
        p_organization_id, p_rule_id, p_rule_version_id,
        p_request_type, p_requested_by_engineer_id, p_target_approver_id,
        p_title, p_justification, p_impact_summary,
        p_priority_level, 'pending',
        NOW(), NOW(),
        p_requested_by_engineer_id, p_requested_by_engineer_id
    );

    -- Notify the target approver
    IF p_target_approver_id IS NOT NULL THEN
        PERFORM fn_create_notification(
            p_organization_id,
            p_target_approver_id,
            'rule_override_requested',
            FORMAT('Rule approval required: %s', p_title),
            FORMAT(
                'Engineer %s has requested approval for: "%s". '
                'Justification: %s',
                p_requested_by_engineer_id,
                p_title,
                LEFT(p_justification, 200)
            ),
            'rule_approval_requests',
            v_request_id,
            NOW() + INTERVAL '7 days'
        );
    END IF;

    RETURN v_request_id;
END;
$$;

COMMENT ON FUNCTION fn_create_rule_approval_request(UUID,UUID,UUID,VARCHAR,UUID,UUID,VARCHAR,TEXT,TEXT,VARCHAR) IS
    'Creates a rule approval request and sends an in-app notification to the target approver. '
    'Enforces minimum 50-character justification (per FRS Business Rule BR-205). '
    'Returns the UUID of the created approval request.';

-- =============================================================================
-- FUNCTION: fn_resolve_rule_conflict
-- Records the resolution of a rule conflict detected by the Conflict Resolution Engine.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_resolve_rule_conflict(
    p_conflict_id               UUID,
    p_resolution_strategy       VARCHAR(30),
    p_resolution_description    TEXT,
    p_winning_rule_id           UUID        DEFAULT NULL,
    p_requires_engineer_decision BOOLEAN    DEFAULT FALSE,
    p_resolved_by_engineer_id   UUID        DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE rule_conflicts
    SET    resolution_strategy          = p_resolution_strategy,
           resolution_description       = p_resolution_description,
           winning_rule_id              = p_winning_rule_id,
           requires_engineer_decision   = p_requires_engineer_decision,
           is_resolved                  = CASE WHEN p_requires_engineer_decision THEN FALSE ELSE TRUE END,
           resolved_by_engineer_id      = p_resolved_by_engineer_id,
           resolved_at                  = CASE WHEN p_requires_engineer_decision THEN NULL ELSE NOW() END,
           updated_at                   = NOW()
    WHERE  id = p_conflict_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rule conflict % not found.', p_conflict_id
            USING ERRCODE = 'no_data_found';
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_resolve_rule_conflict(UUID,VARCHAR,TEXT,UUID,BOOLEAN,UUID) IS
    'Records the resolution of a detected rule conflict. '
    'If requires_engineer_decision = TRUE, is_resolved remains FALSE '
    'until the engineer explicitly resolves it via the UI. '
    'Used by the Conflict Resolution Engine (Intelligence Spec Section 11).';

-- =============================================================================
-- FUNCTION: fn_get_rule_comparison_summary
-- Returns a structured JSONB comparison of rule outcomes across all sources
-- for a given design context. Used by the Rule Comparison UI.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_rule_comparison_summary(p_comparison_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT jsonb_build_object(
        'comparison_id',        r.id,
        'compared_at',          r.compared_at,
        'sources', jsonb_build_object(
            'ipc', jsonb_build_object(
                'status',               r.ipc_result_status,
                'yield_pct',            r.ipc_yield_prediction_pct,
                'bridging_risk',        r.ipc_bridging_risk,
                'voiding_risk',         r.ipc_voiding_risk,
                'insufficient_paste',   r.ipc_insufficient_paste_risk,
                'printability',         r.ipc_printability_score,
                'transfer_eff_pct',     r.ipc_transfer_efficiency_pct,
                'overall_score',        r.ipc_overall_score,
                'recommendation',       r.ipc_recommendation_summary
            ),
            'customer', jsonb_build_object(
                'status',               r.customer_result_status,
                'yield_pct',            r.customer_yield_prediction_pct,
                'bridging_risk',        r.customer_bridging_risk,
                'voiding_risk',         r.customer_voiding_risk,
                'insufficient_paste',   r.customer_insufficient_paste_risk,
                'printability',         r.customer_printability_score,
                'transfer_eff_pct',     r.customer_transfer_efficiency_pct,
                'overall_score',        r.customer_overall_score,
                'recommendation',       r.customer_recommendation_summary,
                'rejection_reasons',    r.customer_rejection_reasons
            ),
            'company', jsonb_build_object(
                'status',               r.company_result_status,
                'yield_pct',            r.company_yield_prediction_pct,
                'bridging_risk',        r.company_bridging_risk,
                'voiding_risk',         r.company_voiding_risk,
                'overall_score',        r.company_overall_score,
                'recommendation',       r.company_recommendation_summary
            ),
            'engineer', jsonb_build_object(
                'status',               r.engineer_result_status,
                'yield_pct',            r.engineer_yield_prediction_pct,
                'overall_score',        r.engineer_overall_score,
                'recommendation',       r.engineer_recommendation_summary
            ),
            'ai', jsonb_build_object(
                'status',               r.ai_result_status,
                'yield_pct',            r.ai_yield_prediction_pct,
                'bridging_risk',        r.ai_bridging_risk,
                'voiding_risk',         r.ai_voiding_risk,
                'overall_score',        r.ai_overall_score,
                'confidence_pct',       r.ai_confidence_pct,
                'recommendation',       r.ai_recommendation_summary
            )
        ),
        'selected_source',      r.selected_source,
        'selection_reason',     r.selection_reason,
        'engineer_accepted_at', r.engineer_accepted_at
    )
    FROM   rule_comparison_results r
    WHERE  r.id = p_comparison_id;
$$;

COMMENT ON FUNCTION fn_get_rule_comparison_summary(UUID) IS
    'Returns a structured JSONB object with all source comparison results '
    'for the given rule_comparison_results row. '
    'Used by the Rule Comparison UI panel to build the side-by-side display.';

-- =============================================================================
-- FUNCTION: fn_rule_effectiveness_compute
-- Computes and upserts effectiveness statistics for a rule over a date range.
-- Called by a scheduled background job (monthly).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_rule_effectiveness_compute(
    p_rule_id               UUID,
    p_organization_id       UUID,
    p_period_start          DATE,
    p_period_end            DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_times_evaluated   INTEGER;
    v_passed            INTEGER;
    v_failed            INTEGER;
    v_warned            INTEGER;
    v_overridden        INTEGER;
    v_effectiveness     NUMERIC(5,4);
BEGIN
    -- Aggregate from engineering_confidence_scores for this period
    SELECT
        COUNT(*)::INTEGER,
        0, 0, 0, 0  -- placeholder counts — actual counts come from rule_check_runs (future)
    INTO v_times_evaluated, v_passed, v_failed, v_warned, v_overridden;

    -- Compute effectiveness from confidence score deltas in the period
    SELECT COALESCE(AVG(
        CASE
            WHEN update_reason IN ('corrective_action_validated','spi_correlation') THEN 0.8
            WHEN update_reason = 'rule_override_outcome' THEN 0.6
            ELSE 0.5
        END
    ), 0.5)
    INTO v_effectiveness
    FROM engineering_confidence_scores
    WHERE rule_id         = p_rule_id
      AND organization_id = p_organization_id
      AND updated_at      BETWEEN p_period_start AND p_period_end;

    INSERT INTO rule_effectiveness_history (
        id, rule_id, organization_id,
        evaluation_period_start, evaluation_period_end,
        times_evaluated, times_passed, times_failed, times_warned,
        times_overridden, effectiveness_score,
        computed_at, created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        p_rule_id, p_organization_id,
        p_period_start, p_period_end,
        v_times_evaluated, v_passed, v_failed, v_warned,
        v_overridden, v_effectiveness,
        NOW(), NOW(), NOW()
    )
    ON CONFLICT (rule_id, organization_id, evaluation_period_start, evaluation_period_end)
    DO UPDATE SET
        effectiveness_score = EXCLUDED.effectiveness_score,
        computed_at         = NOW(),
        updated_at          = NOW();
END;
$$;

COMMENT ON FUNCTION fn_rule_effectiveness_compute(UUID, UUID, DATE, DATE) IS
    'Computes and upserts rule effectiveness statistics for a given time period. '
    'Intended to be called by a scheduled monthly background job. '
    'Aggregates confidence score updates as a proxy for effectiveness '
    'until full rule_check_run attribution is available in a later module.';

COMMIT;
