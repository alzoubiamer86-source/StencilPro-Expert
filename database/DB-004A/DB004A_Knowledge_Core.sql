-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-004A: Engineering Knowledge Core
-- File: DB004A_Knowledge_Core.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Tables:
--   knowledge_sources, engineering_rule_categories,
--   engineering_rules, engineering_rule_versions,
--   engineering_rule_conditions, engineering_rule_actions,
--   engineering_rule_priorities, engineering_rule_references,
--   rule_conflicts, rule_comparison_results,
--   what_if_scenarios, what_if_parameters, what_if_results,
--   what_if_defect_predictions,
--   rule_approval_requests, rule_approvals,
--   rule_effectiveness_history,
--   customer_rule_profiles, company_rule_profiles,
--   engineer_rule_profiles, ai_recommendation_profiles,
--   decision_explanations, engineering_confidence_scores
-- =============================================================================
-- Prerequisites: DB001, DB002, DB003
-- =============================================================================

BEGIN;

-- =============================================================================
-- SECTION 1: RULE SOURCE & CATEGORY FOUNDATION
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: knowledge_sources
-- Defines the origin types of engineering knowledge in the system.
-- Each rule traces to exactly one knowledge source.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge_sources (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    code                VARCHAR(30)     NOT NULL,
    name                VARCHAR(100)    NOT NULL,
    description         TEXT            NOT NULL,
    base_priority       INTEGER         NOT NULL DEFAULT 0,
    is_overridable      BOOLEAN         NOT NULL DEFAULT TRUE,
    color_hex           VARCHAR(7)      NULL,
    icon_name           VARCHAR(50)     NULL,
    sort_order          INTEGER         NOT NULL DEFAULT 0,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    is_system_record    BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_knowledge_sources
        PRIMARY KEY (id),

    CONSTRAINT uq_knowledge_sources_code
        UNIQUE (code),

    CONSTRAINT chk_knowledge_sources_base_priority
        CHECK (base_priority >= 0 AND base_priority <= 1000),

    CONSTRAINT chk_knowledge_sources_color_hex
        CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

COMMENT ON TABLE knowledge_sources IS
    'Defines the origin classification of every engineering rule in the system. '
    'The base_priority establishes the default evaluation precedence: '
    'project_override(500) > engineer(400) > customer(300) > company(200) > ai(150) > ipc(100) > default(0). '
    'Higher priority rules supersede lower-priority rules when conflicts exist.';

COMMENT ON COLUMN knowledge_sources.code IS 'Machine identifier (e.g., IPC_STANDARD, CUSTOMER_RULE, ENGINEER_OVERRIDE, AI_RECOMMENDATION).';
COMMENT ON COLUMN knowledge_sources.base_priority IS 'Default priority weight for rules from this source. Used in conflict resolution.';
COMMENT ON COLUMN knowledge_sources.is_overridable IS 'Whether rules from this source can be overridden by higher-priority sources.';

-- ---------------------------------------------------------------------------
-- TABLE: engineering_rule_categories
-- Hierarchical classification of engineering rules by domain.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineering_rule_categories (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    parent_category_id  UUID            NULL,
    code                VARCHAR(50)     NOT NULL,
    name                VARCHAR(100)    NOT NULL,
    description         TEXT            NULL,
    domain              VARCHAR(30)     NOT NULL DEFAULT 'stencil',
    applies_to          TEXT[]          NOT NULL DEFAULT '{}',
    sort_order          INTEGER         NOT NULL DEFAULT 0,
    icon_name           VARCHAR(50)     NULL,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    is_system_record    BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_engineering_rule_categories
        PRIMARY KEY (id),

    CONSTRAINT uq_engineering_rule_categories_code
        UNIQUE (code),

    CONSTRAINT fk_engineering_rule_categories_parent
        FOREIGN KEY (parent_category_id)
        REFERENCES engineering_rule_categories (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_engineering_rule_categories_domain
        CHECK (domain IN (
            'stencil','aperture','paste','material','thermal',
            'process','inspection','reflow','placement','environmental','general'
        ))
);

COMMENT ON TABLE engineering_rule_categories IS
    'Hierarchical classification tree for engineering rules. '
    'Supports parent-child nesting for category grouping (e.g., Aperture Geometry → Area Ratio). '
    'applies_to is an array of entity types this category governs '
    '(e.g., {aperture_designs, stencil_designs, component_placements}).';

COMMENT ON COLUMN engineering_rule_categories.parent_category_id IS 'Parent category for nested hierarchy. NULL = top-level category.';
COMMENT ON COLUMN engineering_rule_categories.domain IS 'Primary engineering domain: stencil, aperture, paste, material, thermal, process, inspection, reflow, placement, environmental, general.';
COMMENT ON COLUMN engineering_rule_categories.applies_to IS 'Array of DB table names this category applies to (e.g., {aperture_designs, stencil_designs}).';

-- =============================================================================
-- SECTION 2: CORE RULE TABLES
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: engineering_rules
-- The master rule definition. Each rule is a versioned engineering assertion
-- that can be evaluated against a ProcessContext.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineering_rules (
    id                              UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id                 UUID            NULL,
    knowledge_source_id             UUID            NOT NULL,
    category_id                     UUID            NOT NULL,
    rule_code                       VARCHAR(50)     NOT NULL,
    name                            VARCHAR(255)    NOT NULL,
    description                     TEXT            NOT NULL,
    rule_type                       VARCHAR(30)     NOT NULL DEFAULT 'threshold',
    severity                        VARCHAR(20)     NOT NULL DEFAULT 'major',
    ipc_class_scope                 VARCHAR(20)     NOT NULL DEFAULT 'all',
    parameter_name                  VARCHAR(100)    NULL,
    condition_operator              VARCHAR(30)     NULL,
    threshold_value                 NUMERIC(16,6)   NULL,
    threshold_min                   NUMERIC(16,6)   NULL,
    threshold_max                   NUMERIC(16,6)   NULL,
    threshold_list                  TEXT[]          NULL,
    threshold_unit                  VARCHAR(30)     NULL,
    condition_tree                  JSONB           NULL,
    precondition_tree               JSONB           NULL,
    exception_tree                  JSONB           NULL,
    base_confidence_pct             NUMERIC(6,4)    NOT NULL DEFAULT 0.8500,
    confidence_basis                VARCHAR(30)     NOT NULL DEFAULT 'well_established',
    confidence_modifiers            JSONB           NULL,
    message_pass                    TEXT            NOT NULL,
    message_fail                    TEXT            NOT NULL,
    message_warning                 TEXT            NULL,
    message_skipped                 TEXT            NULL,
    engineering_rationale           TEXT            NOT NULL,
    consequence_of_violation        TEXT            NOT NULL,
    expected_improvement_if_fixed   TEXT            NULL,
    ipc_reference                   VARCHAR(100)    NULL,
    related_defect_type_codes       TEXT[]          NOT NULL DEFAULT '{}',
    related_rule_ids                UUID[]          NOT NULL DEFAULT '{}',
    is_overridable                  BOOLEAN         NOT NULL DEFAULT TRUE,
    override_requires_approval      BOOLEAN         NOT NULL DEFAULT TRUE,
    override_justification_prompt   TEXT            NULL,
    priority_score                  INTEGER         NOT NULL DEFAULT 100,
    is_active                       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_deleted                      BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at                      TIMESTAMPTZ     NULL,
    deprecated_at                   TIMESTAMPTZ     NULL,
    superseded_by_rule_id           UUID            NULL,
    created_by_source               VARCHAR(20)     NOT NULL DEFAULT 'system',
    created_by_engineer_id          UUID            NULL,
    created_at                      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                      UUID            NULL,
    updated_by                      UUID            NULL,

    CONSTRAINT pk_engineering_rules
        PRIMARY KEY (id),

    CONSTRAINT fk_engineering_rules_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rules_knowledge_source
        FOREIGN KEY (knowledge_source_id)
        REFERENCES knowledge_sources (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rules_category
        FOREIGN KEY (category_id)
        REFERENCES engineering_rule_categories (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rules_created_by_engineer
        FOREIGN KEY (created_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rules_superseded_by
        FOREIGN KEY (superseded_by_rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_engineering_rules_rule_type
        CHECK (rule_type IN (
            'threshold','range','enumeration','conditional',
            'relational','composite','advisory','formula',
            'ai_recommendation','customer_standard','company_standard'
        )),

    CONSTRAINT chk_engineering_rules_severity
        CHECK (severity IN ('critical','major','minor','advisory','informational')),

    CONSTRAINT chk_engineering_rules_ipc_class_scope
        CHECK (ipc_class_scope IN ('all','class_1','class_2','class_3','class_2_and_3','class_3_only')),

    CONSTRAINT chk_engineering_rules_condition_operator
        CHECK (condition_operator IS NULL OR condition_operator IN (
            'gte','lte','gt','lt','eq','neq',
            'between','not_between','in_list','not_in_list',
            'formula','composite'
        )),

    CONSTRAINT chk_engineering_rules_confidence
        CHECK (base_confidence_pct >= 0 AND base_confidence_pct <= 1.0),

    CONSTRAINT chk_engineering_rules_confidence_basis
        CHECK (confidence_basis IN (
            'well_established','probable','emerging',
            'theoretical','doe_result','customer_requirement','ai_derived'
        )),

    CONSTRAINT chk_engineering_rules_priority_score
        CHECK (priority_score >= 0 AND priority_score <= 1000),

    CONSTRAINT chk_engineering_rules_created_by_source
        CHECK (created_by_source IN ('system','engineer','customer','ai','import')),

    CONSTRAINT chk_engineering_rules_soft_delete
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL) OR
            (is_deleted = TRUE  AND deleted_at IS NOT NULL)
        ),

    CONSTRAINT chk_engineering_rules_threshold_range
        CHECK (
            threshold_min IS NULL OR threshold_max IS NULL OR
            threshold_max >= threshold_min
        )
);

COMMENT ON TABLE engineering_rules IS
    'Master rule definition table. Every engineering assertion — IPC standard, '
    'customer requirement, company practice, engineer judgment, or AI recommendation — '
    'is represented as an engineering_rule. Rules are versioned (via engineering_rule_versions), '
    'never edited in place. The condition_tree JSONB supports full Boolean '
    'IF/AND/OR/NOT/NESTED/FORMULA logic as defined in the Engineering Intelligence Specification. '
    'organization_id = NULL means a system-level (IPC) rule available to all organizations.';

COMMENT ON COLUMN engineering_rules.rule_code IS 'Human-readable rule identifier (e.g., IPC7525-001, CUST-FORD-042, ENG-SMITH-007). Unique per organization scope.';
COMMENT ON COLUMN engineering_rules.knowledge_source_id IS 'Which knowledge source this rule originates from (IPC, customer, company, engineer, AI).';
COMMENT ON COLUMN engineering_rules.rule_type IS 'Evaluation strategy: threshold, range, enumeration, conditional, relational, composite, advisory, formula, ai_recommendation, customer_standard, company_standard.';
COMMENT ON COLUMN engineering_rules.priority_score IS 'Effective evaluation priority (0–1000). Higher score = higher precedence. Set from knowledge_source.base_priority + context adjustments.';
COMMENT ON COLUMN engineering_rules.condition_tree IS 'JSONB Boolean condition tree for complex multi-condition rules. Used when rule_type = composite or conditional.';
COMMENT ON COLUMN engineering_rules.precondition_tree IS 'JSONB tree of conditions that must be true before this rule is evaluated. If false, result = SKIPPED.';
COMMENT ON COLUMN engineering_rules.exception_tree IS 'JSONB tree of conditions under which a failure is suppressed (contextual exceptions).';
COMMENT ON COLUMN engineering_rules.base_confidence_pct IS 'Base confidence 0.0–1.0. Updated by Learning Engine after production outcomes.';
COMMENT ON COLUMN engineering_rules.engineering_rationale IS 'WHY this rule exists — the physics, chemistry, or regulatory basis. Displayed in Level 2/3 explanations.';
COMMENT ON COLUMN engineering_rules.consequence_of_violation IS 'What goes wrong when this rule is violated. Used in recommendation cards.';
COMMENT ON COLUMN engineering_rules.superseded_by_rule_id IS 'When a rule is replaced by a new version, points to the successor rule.';
COMMENT ON COLUMN engineering_rules.deprecated_at IS 'When this rule version was retired. NULL = still active.';

-- ---------------------------------------------------------------------------
-- TABLE: engineering_rule_versions
-- Immutable version history for each rule. Every edit creates a new version row.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineering_rule_versions (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    rule_id                 UUID            NOT NULL,
    organization_id         UUID            NULL,
    version_number          INTEGER         NOT NULL,
    version_label           VARCHAR(20)     NOT NULL,
    change_summary          TEXT            NOT NULL,
    change_type             VARCHAR(30)     NOT NULL DEFAULT 'minor_update',
    rule_snapshot           JSONB           NOT NULL,
    authored_by_engineer_id UUID            NOT NULL,
    approved_by_engineer_id UUID            NULL,
    approved_at             TIMESTAMPTZ     NULL,
    effective_from          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    effective_until         TIMESTAMPTZ     NULL,
    is_current              BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_engineering_rule_versions
        PRIMARY KEY (id),

    CONSTRAINT uq_engineering_rule_versions_rule_number
        UNIQUE (rule_id, version_number),

    CONSTRAINT fk_engineering_rule_versions_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rule_versions_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rule_versions_authored_by
        FOREIGN KEY (authored_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rule_versions_approved_by
        FOREIGN KEY (approved_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_engineering_rule_versions_change_type
        CHECK (change_type IN (
            'initial_release','minor_update','major_update',
            'threshold_change','confidence_update','deprecation',
            'ai_refinement','customer_revision'
        )),

    CONSTRAINT chk_engineering_rule_versions_number
        CHECK (version_number > 0),

    CONSTRAINT chk_engineering_rule_versions_approval
        CHECK (
            (approved_at IS NULL AND approved_by_engineer_id IS NULL) OR
            (approved_at IS NOT NULL AND approved_by_engineer_id IS NOT NULL)
        )
);

COMMENT ON TABLE engineering_rule_versions IS
    'Immutable version history for engineering rules. '
    'Every change to a rule creates a new version row rather than modifying the parent rule. '
    'rule_snapshot is a JSONB copy of the complete rule state at this version, '
    'enabling historical rule evaluation: "what did rule IPC7525-001 say in 2024?" '
    'Rule check runs record the version IDs of all rules evaluated.';

COMMENT ON COLUMN engineering_rule_versions.rule_snapshot IS 'Complete JSONB copy of the engineering_rules row at this version. Immutable after creation.';
COMMENT ON COLUMN engineering_rule_versions.is_current IS 'TRUE for the most recent active version. Partial unique index enforces one current version per rule.';
COMMENT ON COLUMN engineering_rule_versions.effective_from IS 'When this version became active.';
COMMENT ON COLUMN engineering_rule_versions.effective_until IS 'When this version was superseded. NULL = still active.';

-- Partial unique index: one current version per rule
CREATE UNIQUE INDEX IF NOT EXISTS uq_engineering_rule_versions_current
    ON engineering_rule_versions (rule_id)
    WHERE is_current = TRUE;

-- ---------------------------------------------------------------------------
-- TABLE: engineering_rule_conditions
-- Individual condition rows for complex rules with AND/OR chains.
-- Supplements the condition_tree JSONB with queryable structured rows.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineering_rule_conditions (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    rule_id                 UUID            NOT NULL,
    organization_id         UUID            NULL,
    condition_type          VARCHAR(20)     NOT NULL DEFAULT 'evaluation',
    parameter_name          VARCHAR(100)    NOT NULL,
    operator                VARCHAR(30)     NOT NULL,
    value_text              TEXT            NULL,
    value_numeric           NUMERIC(16,6)   NULL,
    value_list              TEXT[]          NULL,
    logic_operator          VARCHAR(5)      NOT NULL DEFAULT 'AND',
    group_id                INTEGER         NULL,
    parent_condition_id     UUID            NULL,
    description             TEXT            NULL,
    sort_order              INTEGER         NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_engineering_rule_conditions
        PRIMARY KEY (id),

    CONSTRAINT fk_engineering_rule_conditions_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_engineering_rule_conditions_parent
        FOREIGN KEY (parent_condition_id)
        REFERENCES engineering_rule_conditions (id)
        ON DELETE CASCADE,

    CONSTRAINT chk_engineering_rule_conditions_type
        CHECK (condition_type IN ('precondition','evaluation','exception')),

    CONSTRAINT chk_engineering_rule_conditions_operator
        CHECK (operator IN (
            'gte','lte','gt','lt','eq','neq',
            'between','not_between','in_list','not_in_list',
            'is_true','is_false','exists','not_exists',
            'formula','regex'
        )),

    CONSTRAINT chk_engineering_rule_conditions_logic
        CHECK (logic_operator IN ('AND','OR','NOT'))
);

COMMENT ON TABLE engineering_rule_conditions IS
    'Individual queryable condition rows for complex engineering rules. '
    'Supplements condition_tree JSONB for rules that benefit from structured row-level condition storage. '
    'Supports unlimited nesting via parent_condition_id self-reference. '
    'condition_type: precondition (when rule applies), evaluation (the test), exception (suppress on true).';

COMMENT ON COLUMN engineering_rule_conditions.parameter_name IS 'ProcessContext field being evaluated (e.g., area_ratio, lead_pitch_mm, stencil_material_type).';
COMMENT ON COLUMN engineering_rule_conditions.group_id IS 'Integer group ID for AND/OR grouping of sibling conditions at the same nesting level.';

-- ---------------------------------------------------------------------------
-- TABLE: engineering_rule_actions
-- What the system does when a rule fires (fail, warn, recommend, notify).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineering_rule_actions (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    rule_id                 UUID            NOT NULL,
    organization_id         UUID            NULL,
    action_type             VARCHAR(30)     NOT NULL DEFAULT 'flag_result',
    trigger_on              VARCHAR(20)     NOT NULL DEFAULT 'fail',
    action_payload          JSONB           NOT NULL DEFAULT '{}',
    recommendation_template TEXT            NULL,
    notification_type       VARCHAR(50)     NULL,
    blocks_approval         BOOLEAN         NOT NULL DEFAULT FALSE,
    requires_override       BOOLEAN         NOT NULL DEFAULT FALSE,
    sort_order              INTEGER         NOT NULL DEFAULT 0,
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_engineering_rule_actions
        PRIMARY KEY (id),

    CONSTRAINT fk_engineering_rule_actions_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE CASCADE,

    CONSTRAINT chk_engineering_rule_actions_type
        CHECK (action_type IN (
            'flag_result','generate_recommendation','send_notification',
            'block_approval','require_override','log_activity',
            'trigger_calculation','update_score'
        )),

    CONSTRAINT chk_engineering_rule_actions_trigger_on
        CHECK (trigger_on IN ('fail','warning','pass','any','skipped'))
);

COMMENT ON TABLE engineering_rule_actions IS
    'Actions executed by the Rule Engine when a rule result is produced. '
    'A single rule may have multiple actions (e.g., flag result AND generate recommendation '
    'AND block approval for critical failures). action_payload is JSONB carrying '
    'action-specific parameters (e.g., recommendation template variables, notification recipients).';

COMMENT ON COLUMN engineering_rule_actions.trigger_on IS 'Which result status triggers this action: fail, warning, pass, any, skipped.';
COMMENT ON COLUMN engineering_rule_actions.blocks_approval IS 'TRUE if this action prevents stencil design approval until resolved.';
COMMENT ON COLUMN engineering_rule_actions.requires_override IS 'TRUE if an engineer override is required before the result can be acknowledged.';

-- ---------------------------------------------------------------------------
-- TABLE: engineering_rule_priorities
-- Per-context priority overrides for rules within specific scopes
-- (project, customer, company, or organization).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineering_rule_priorities (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    rule_id             UUID            NOT NULL,
    organization_id     UUID            NOT NULL,
    scope_type          VARCHAR(20)     NOT NULL DEFAULT 'organization',
    scope_id            UUID            NULL,
    priority_score      INTEGER         NOT NULL,
    override_reason     TEXT            NULL,
    set_by_engineer_id  UUID            NOT NULL,
    effective_from      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    effective_until     TIMESTAMPTZ     NULL,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_engineering_rule_priorities
        PRIMARY KEY (id),

    CONSTRAINT uq_engineering_rule_priorities_scope
        UNIQUE (rule_id, organization_id, scope_type, scope_id),

    CONSTRAINT fk_engineering_rule_priorities_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rule_priorities_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_rule_priorities_set_by
        FOREIGN KEY (set_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_engineering_rule_priorities_scope_type
        CHECK (scope_type IN ('organization','customer','project','engineer')),

    CONSTRAINT chk_engineering_rule_priorities_score
        CHECK (priority_score >= 0 AND priority_score <= 1000)
);

COMMENT ON TABLE engineering_rule_priorities IS
    'Context-specific priority overrides for engineering rules. '
    'Allows an organization to elevate or demote a rule''s priority for a specific '
    'customer, project, or engineer scope without modifying the base rule. '
    'scope_type + scope_id identifies the context (e.g., scope_type=customer, scope_id=customer_uuid).';

-- ---------------------------------------------------------------------------
-- TABLE: engineering_rule_references
-- Links rules to IPC standards, papers, and other authoritative sources.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineering_rule_references (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    rule_id             UUID            NOT NULL,
    reference_type      VARCHAR(30)     NOT NULL DEFAULT 'ipc_standard',
    reference_code      VARCHAR(100)    NOT NULL,
    reference_title     VARCHAR(255)    NOT NULL,
    section_number      VARCHAR(30)     NULL,
    section_title       VARCHAR(255)    NULL,
    publication_year    INTEGER         NULL,
    url                 TEXT            NULL,
    summary             TEXT            NULL,
    is_normative        BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_engineering_rule_references
        PRIMARY KEY (id),

    CONSTRAINT fk_engineering_rule_references_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE CASCADE,

    CONSTRAINT chk_engineering_rule_references_type
        CHECK (reference_type IN (
            'ipc_standard','academic_paper','industry_guideline',
            'customer_spec','company_procedure','doe_report','ai_training_source'
        ))
);

COMMENT ON TABLE engineering_rule_references IS
    'Authoritative source references for engineering rules. '
    'A rule may cite multiple references (e.g., IPC-7525B Section 4.2 AND an internal DOE report). '
    'is_normative = TRUE means this reference is a mandatory requirement; '
    'FALSE means informative/supporting context.';

-- =============================================================================
-- SECTION 3: RULE CONFLICT & COMPARISON
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: rule_conflicts
-- Records detected conflicts between rules when multiple rules evaluate
-- the same parameter with contradictory requirements.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rule_conflicts (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             UUID            NOT NULL,
    stencil_design_id           UUID            NULL,
    rule_a_id                   UUID            NOT NULL,
    rule_b_id                   UUID            NOT NULL,
    conflict_type               VARCHAR(30)     NOT NULL DEFAULT 'directional',
    conflict_description        TEXT            NOT NULL,
    parameter_name              VARCHAR(100)    NOT NULL,
    rule_a_requirement          TEXT            NOT NULL,
    rule_b_requirement          TEXT            NOT NULL,
    resolution_strategy         VARCHAR(30)     NOT NULL DEFAULT 'priority_hierarchy',
    resolution_description      TEXT            NULL,
    winning_rule_id             UUID            NULL,
    requires_engineer_decision  BOOLEAN         NOT NULL DEFAULT FALSE,
    is_resolved                 BOOLEAN         NOT NULL DEFAULT FALSE,
    resolved_by_engineer_id     UUID            NULL,
    resolved_at                 TIMESTAMPTZ     NULL,
    resolution_notes            TEXT            NULL,
    detected_at                 TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_rule_conflicts
        PRIMARY KEY (id),

    CONSTRAINT fk_rule_conflicts_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_conflicts_rule_a
        FOREIGN KEY (rule_a_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_conflicts_rule_b
        FOREIGN KEY (rule_b_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_conflicts_winning_rule
        FOREIGN KEY (winning_rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_conflicts_resolved_by
        FOREIGN KEY (resolved_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_rule_conflicts_type
        CHECK (conflict_type IN (
            'directional','resource','material','spatial',
            'severity','threshold','scope','customer_vs_ipc'
        )),

    CONSTRAINT chk_rule_conflicts_resolution_strategy
        CHECK (resolution_strategy IN (
            'priority_hierarchy','pareto_optimal','step_stencil',
            'geometry_reshape','engineer_decision','customer_override',
            'suppressed','escalated'
        )),

    CONSTRAINT chk_rule_conflicts_resolved
        CHECK (
            (is_resolved = FALSE AND resolved_at IS NULL) OR
            (is_resolved = TRUE  AND resolved_at IS NOT NULL)
        )
);

COMMENT ON TABLE rule_conflicts IS
    'Records conflicts detected between engineering rules during rule evaluation. '
    'The Conflict Resolution Engine (Engineering Intelligence Spec Section 11) '
    'populates this table when two rules make incompatible requirements on the same parameter. '
    'Conflicts are auto-resolved by priority hierarchy where possible; '
    'requires_engineer_decision = TRUE flags those needing human judgment.';

COMMENT ON COLUMN rule_conflicts.conflict_type IS 'Classification: directional (opposite directions), resource (different parameters force each other out), material (material exclusivity), spatial (neighboring component impact), severity, threshold, scope, customer_vs_ipc.';
COMMENT ON COLUMN rule_conflicts.resolution_strategy IS 'How the conflict was resolved: priority_hierarchy (higher priority wins), pareto_optimal (calculated optimum), step_stencil, geometry_reshape, engineer_decision, customer_override, suppressed, escalated.';

-- ---------------------------------------------------------------------------
-- TABLE: rule_comparison_results
-- Side-by-side comparison of rule outcomes across multiple rule sources
-- for the same design context (IPC vs Customer vs Company vs AI).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rule_comparison_results (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             UUID            NOT NULL,
    stencil_design_id           UUID            NULL,
    aperture_design_id          UUID            NULL,
    comparison_context          JSONB           NOT NULL DEFAULT '{}',
    compared_at                 TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    compared_by_engineer_id     UUID            NOT NULL,

    -- IPC Standard result
    ipc_result_status           VARCHAR(20)     NULL,
    ipc_yield_prediction_pct    NUMERIC(6,3)    NULL,
    ipc_bridging_risk           NUMERIC(5,4)    NULL,
    ipc_voiding_risk            NUMERIC(5,4)    NULL,
    ipc_insufficient_paste_risk NUMERIC(5,4)    NULL,
    ipc_printability_score      NUMERIC(5,2)    NULL,
    ipc_transfer_efficiency_pct NUMERIC(6,3)    NULL,
    ipc_overall_score           NUMERIC(5,2)    NULL,
    ipc_recommendation_summary  TEXT            NULL,

    -- Customer Rule result
    customer_result_status          VARCHAR(20)     NULL,
    customer_yield_prediction_pct   NUMERIC(6,3)    NULL,
    customer_bridging_risk          NUMERIC(5,4)    NULL,
    customer_voiding_risk           NUMERIC(5,4)    NULL,
    customer_insufficient_paste_risk NUMERIC(5,4)   NULL,
    customer_printability_score     NUMERIC(5,2)    NULL,
    customer_transfer_efficiency_pct NUMERIC(6,3)   NULL,
    customer_overall_score          NUMERIC(5,2)    NULL,
    customer_recommendation_summary TEXT            NULL,
    customer_rejection_reasons      TEXT[]          NOT NULL DEFAULT '{}',

    -- Company Rule result
    company_result_status           VARCHAR(20)     NULL,
    company_yield_prediction_pct    NUMERIC(6,3)    NULL,
    company_bridging_risk           NUMERIC(5,4)    NULL,
    company_voiding_risk            NUMERIC(5,4)    NULL,
    company_insufficient_paste_risk NUMERIC(5,4)    NULL,
    company_printability_score      NUMERIC(5,2)    NULL,
    company_transfer_efficiency_pct NUMERIC(6,3)    NULL,
    company_overall_score           NUMERIC(5,2)    NULL,
    company_recommendation_summary  TEXT            NULL,
    company_rejection_reasons       TEXT[]          NOT NULL DEFAULT '{}',

    -- Engineer Rule result
    engineer_result_status          VARCHAR(20)     NULL,
    engineer_yield_prediction_pct   NUMERIC(6,3)    NULL,
    engineer_bridging_risk          NUMERIC(5,4)    NULL,
    engineer_voiding_risk           NUMERIC(5,4)    NULL,
    engineer_insufficient_paste_risk NUMERIC(5,4)   NULL,
    engineer_printability_score     NUMERIC(5,2)    NULL,
    engineer_transfer_efficiency_pct NUMERIC(6,3)   NULL,
    engineer_overall_score          NUMERIC(5,2)    NULL,
    engineer_recommendation_summary TEXT            NULL,

    -- AI Optimized result
    ai_result_status                VARCHAR(20)     NULL,
    ai_yield_prediction_pct         NUMERIC(6,3)    NULL,
    ai_bridging_risk                NUMERIC(5,4)    NULL,
    ai_voiding_risk                 NUMERIC(5,4)    NULL,
    ai_insufficient_paste_risk      NUMERIC(5,4)    NULL,
    ai_printability_score           NUMERIC(5,2)    NULL,
    ai_transfer_efficiency_pct      NUMERIC(6,3)    NULL,
    ai_overall_score                NUMERIC(5,2)    NULL,
    ai_recommendation_summary       TEXT            NULL,
    ai_confidence_pct               NUMERIC(6,3)    NULL,

    -- Selected recommendation
    selected_source                 VARCHAR(30)     NULL,
    selection_reason                TEXT            NULL,
    engineer_accepted_at            TIMESTAMPTZ     NULL,

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by      UUID            NULL,
    updated_by      UUID            NULL,

    CONSTRAINT pk_rule_comparison_results
        PRIMARY KEY (id),

    CONSTRAINT fk_rule_comparison_results_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_comparison_results_compared_by
        FOREIGN KEY (compared_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_rule_comparison_results_ipc_status
        CHECK (ipc_result_status IS NULL OR
               ipc_result_status IN ('pass','fail','warning','not_applicable')),

    CONSTRAINT chk_rule_comparison_results_selected_source
        CHECK (selected_source IS NULL OR selected_source IN (
            'ipc','customer','company','engineer','ai','hybrid'
        ))
);

COMMENT ON TABLE rule_comparison_results IS
    'Side-by-side comparison of rule outcomes across all knowledge sources for the same context. '
    'The Rule Comparison feature (FRS Module 4.11) populates this table when an engineer '
    'triggers a multi-source comparison. Stores yield prediction, defect risks, '
    'printability score, and transfer efficiency from each rule source, '
    'enabling the engineer to choose the most appropriate standard to design against.';

COMMENT ON COLUMN rule_comparison_results.comparison_context IS 'JSONB snapshot of the ProcessContext at the time of comparison.';
COMMENT ON COLUMN rule_comparison_results.selected_source IS 'Which rule source the engineer chose to apply: ipc, customer, company, engineer, ai, hybrid.';

-- =============================================================================
-- SECTION 4: WHAT-IF ANALYSIS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: what_if_scenarios
-- An engineer-defined what-if scenario: a named set of parameter changes
-- to test against a stencil design context.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS what_if_scenarios (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id         UUID            NOT NULL,
    project_id              UUID            NULL,
    stencil_design_id       UUID            NULL,
    created_by_engineer_id  UUID            NOT NULL,
    name                    VARCHAR(255)    NOT NULL,
    description             TEXT            NULL,
    scenario_type           VARCHAR(30)     NOT NULL DEFAULT 'aperture_geometry',
    base_context_snapshot   JSONB           NOT NULL DEFAULT '{}',
    status                  VARCHAR(20)     NOT NULL DEFAULT 'draft',
    is_saved                BOOLEAN         NOT NULL DEFAULT FALSE,
    is_deleted              BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at              TIMESTAMPTZ     NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_what_if_scenarios
        PRIMARY KEY (id),

    CONSTRAINT fk_what_if_scenarios_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_what_if_scenarios_project
        FOREIGN KEY (project_id)
        REFERENCES projects (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_what_if_scenarios_created_by
        FOREIGN KEY (created_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_what_if_scenarios_type
        CHECK (scenario_type IN (
            'aperture_geometry','paste_reduction','stencil_thickness',
            'stencil_material','stencil_coating','aperture_shape',
            'thermal_pad','process_parameter','combined'
        )),

    CONSTRAINT chk_what_if_scenarios_status
        CHECK (status IN ('draft','running','complete','error','archived')),

    CONSTRAINT chk_what_if_scenarios_soft_delete
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL) OR
            (is_deleted = TRUE  AND deleted_at IS NOT NULL)
        )
);

COMMENT ON TABLE what_if_scenarios IS
    'Engineer-defined what-if analysis scenarios. A scenario captures a named set of '
    'parameter modifications (e.g., "35% paste reduction + home plate aperture + 6mil stencil") '
    'to be evaluated against the current design context. '
    'base_context_snapshot is a JSONB copy of the ProcessContext before parameter changes. '
    'Results are stored in what_if_results.';

COMMENT ON COLUMN what_if_scenarios.scenario_type IS 'Primary type of parameter being varied: aperture_geometry, paste_reduction, stencil_thickness, stencil_material, stencil_coating, aperture_shape, thermal_pad, process_parameter, combined.';

-- ---------------------------------------------------------------------------
-- TABLE: what_if_parameters
-- Individual parameter changes within a what-if scenario.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS what_if_parameters (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    scenario_id         UUID            NOT NULL,
    organization_id     UUID            NOT NULL,
    parameter_name      VARCHAR(100)    NOT NULL,
    parameter_label     VARCHAR(255)    NOT NULL,
    parameter_unit      VARCHAR(20)     NULL,
    parameter_category  VARCHAR(50)     NOT NULL DEFAULT 'geometry',
    original_value      TEXT            NULL,
    modified_value      TEXT            NOT NULL,
    modification_type   VARCHAR(30)     NOT NULL DEFAULT 'absolute',
    modification_pct    NUMERIC(8,3)    NULL,
    is_enabled          BOOLEAN         NOT NULL DEFAULT TRUE,
    sort_order          INTEGER         NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          UUID            NULL,
    updated_by          UUID            NULL,

    CONSTRAINT pk_what_if_parameters
        PRIMARY KEY (id),

    CONSTRAINT fk_what_if_parameters_scenario
        FOREIGN KEY (scenario_id)
        REFERENCES what_if_scenarios (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_what_if_parameters_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_what_if_parameters_category
        CHECK (parameter_category IN (
            'geometry','shape','material','coating','thickness',
            'process','thermal','paste','inspection','other'
        )),

    CONSTRAINT chk_what_if_parameters_modification_type
        CHECK (modification_type IN (
            'absolute','percentage_reduction','percentage_increase',
            'replacement','toggle','formula'
        ))
);

COMMENT ON TABLE what_if_parameters IS
    'Individual parameter modifications within a what-if scenario. '
    'Each row represents one change (e.g., aperture_length_mm = 0.32 instead of 0.40, '
    'stencil_coating_type = nano instead of none, aperture_shape = home_plate instead of rectangle). '
    'modification_type distinguishes absolute value changes from percentage adjustments.';

COMMENT ON COLUMN what_if_parameters.parameter_name IS 'ProcessContext field being modified (e.g., area_ratio, stencil_thickness_mm, aperture_shape, coating_type).';
COMMENT ON COLUMN what_if_parameters.modification_pct IS 'For percentage modifications: the change percentage (e.g., -35.0 for 35% reduction).';

-- ---------------------------------------------------------------------------
-- TABLE: what_if_results
-- The calculated output of evaluating a what-if scenario.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS what_if_results (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    scenario_id                 UUID            NOT NULL,
    organization_id             UUID            NOT NULL,
    evaluated_at                TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    evaluated_by_engineer_id    UUID            NOT NULL,
    modified_context_snapshot   JSONB           NOT NULL DEFAULT '{}',
    rule_check_status           VARCHAR(30)     NOT NULL DEFAULT 'not_run',
    rules_passed                INTEGER         NOT NULL DEFAULT 0,
    rules_failed                INTEGER         NOT NULL DEFAULT 0,
    rules_warned                INTEGER         NOT NULL DEFAULT 0,
    area_ratio                  NUMERIC(8,4)    NULL,
    aspect_ratio                NUMERIC(8,4)    NULL,
    paste_volume_mm3            NUMERIC(12,6)   NULL,
    transfer_efficiency_pct     NUMERIC(6,3)    NULL,
    aperture_to_aperture_gap_mm NUMERIC(10,4)   NULL,
    predicted_fpy_pct           NUMERIC(6,3)    NULL,
    fpy_delta_pct               NUMERIC(6,3)    NULL,
    engineering_score           NUMERIC(5,2)    NULL,
    score_delta                 NUMERIC(6,2)    NULL,
    stencil_score               NUMERIC(5,2)    NULL,
    manufacturability_score     NUMERIC(5,2)    NULL,
    printability_score          NUMERIC(5,2)    NULL,
    overall_confidence_pct      NUMERIC(6,3)    NULL,
    recommendation_summary      TEXT            NULL,
    tradeoffs_summary           TEXT            NULL,
    rule_check_details          JSONB           NOT NULL DEFAULT '[]',
    calculation_details         JSONB           NOT NULL DEFAULT '{}',
    engineer_notes              TEXT            NULL,
    was_applied_to_design       BOOLEAN         NOT NULL DEFAULT FALSE,
    applied_at                  TIMESTAMPTZ     NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_what_if_results
        PRIMARY KEY (id),

    CONSTRAINT fk_what_if_results_scenario
        FOREIGN KEY (scenario_id)
        REFERENCES what_if_scenarios (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_what_if_results_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_what_if_results_evaluated_by
        FOREIGN KEY (evaluated_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_what_if_results_rule_check_status
        CHECK (rule_check_status IN (
            'not_run','pass','pass_with_warnings','fail','critical_fail'
        )),

    CONSTRAINT chk_what_if_results_applied
        CHECK (
            (was_applied_to_design = FALSE AND applied_at IS NULL) OR
            (was_applied_to_design = TRUE  AND applied_at IS NOT NULL)
        )
);

COMMENT ON TABLE what_if_results IS
    'Calculated output of a what-if scenario evaluation. '
    'Stores the full Intelligence Engine output — rule check summary, '
    'calculated metrics (area ratio, paste volume, transfer efficiency), '
    'yield prediction, engineering scores, and recommendation summary — '
    'for the modified parameter set. fpy_delta_pct and score_delta show '
    'the improvement relative to the baseline (unmodified) context. '
    'was_applied_to_design tracks whether the engineer applied this scenario to the actual design.';

COMMENT ON COLUMN what_if_results.fpy_delta_pct IS 'Change in predicted FPY vs baseline (positive = improvement).';
COMMENT ON COLUMN what_if_results.score_delta IS 'Change in overall engineering score vs baseline (positive = improvement).';
COMMENT ON COLUMN what_if_results.rule_check_details IS 'JSONB array of individual rule results for this scenario context.';

-- ---------------------------------------------------------------------------
-- TABLE: what_if_defect_predictions
-- Per-defect risk predictions for each what-if result.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS what_if_defect_predictions (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    what_if_result_id           UUID            NOT NULL,
    organization_id             UUID            NOT NULL,
    defect_type_code            VARCHAR(20)     NOT NULL,
    defect_name                 VARCHAR(100)    NOT NULL,
    baseline_risk_score         NUMERIC(5,4)    NOT NULL DEFAULT 0.0,
    modified_risk_score         NUMERIC(5,4)    NOT NULL DEFAULT 0.0,
    risk_delta                  NUMERIC(5,4)    NOT NULL DEFAULT 0.0,
    risk_band_baseline          VARCHAR(20)     NOT NULL DEFAULT 'negligible',
    risk_band_modified          VARCHAR(20)     NOT NULL DEFAULT 'negligible',
    primary_risk_driver         VARCHAR(100)    NULL,
    improvement_explanation     TEXT            NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_what_if_defect_predictions
        PRIMARY KEY (id),

    CONSTRAINT fk_what_if_defect_predictions_result
        FOREIGN KEY (what_if_result_id)
        REFERENCES what_if_results (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_what_if_defect_predictions_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_what_if_defect_predictions_risk_scores
        CHECK (
            baseline_risk_score >= 0 AND baseline_risk_score <= 1.0 AND
            modified_risk_score >= 0 AND modified_risk_score <= 1.0
        ),

    CONSTRAINT chk_what_if_defect_predictions_risk_band
        CHECK (risk_band_baseline IN ('negligible','low','moderate','high','critical') AND
               risk_band_modified IN ('negligible','low','moderate','high','critical'))
);

COMMENT ON TABLE what_if_defect_predictions IS
    'Per-defect risk predictions for a what-if result. '
    'Each of the 12 defect types (solder bridge, voiding, insufficient paste, etc.) '
    'gets a row showing how its risk score changes from baseline to the modified scenario. '
    'risk_delta is positive when risk increases, negative when risk decreases.';

COMMENT ON COLUMN what_if_defect_predictions.defect_type_code IS 'Defect code matching defect_types.defect_code in the knowledge base (e.g., DEF-011, DEF-022).';
COMMENT ON COLUMN what_if_defect_predictions.risk_delta IS 'Change in risk score: modified_risk_score - baseline_risk_score. Negative = improvement.';

-- =============================================================================
-- SECTION 5: RULE APPROVAL WORKFLOW
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: rule_approval_requests
-- Formal request to approve a new or modified engineering rule.
-- Also covers rule override approval requests from engineers.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rule_approval_requests (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             UUID            NOT NULL,
    rule_id                     UUID            NOT NULL,
    rule_version_id             UUID            NULL,
    request_type                VARCHAR(30)     NOT NULL DEFAULT 'new_rule',
    requested_by_engineer_id    UUID            NOT NULL,
    target_approver_id          UUID            NULL,
    title                       VARCHAR(255)    NOT NULL,
    justification               TEXT            NOT NULL,
    impact_summary              TEXT            NULL,
    affected_project_ids        UUID[]          NOT NULL DEFAULT '{}',
    priority_level              VARCHAR(10)     NOT NULL DEFAULT 'normal',
    status                      VARCHAR(20)     NOT NULL DEFAULT 'pending',
    due_date                    DATE            NULL,
    is_deleted                  BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at                  TIMESTAMPTZ     NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_rule_approval_requests
        PRIMARY KEY (id),

    CONSTRAINT fk_rule_approval_requests_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_approval_requests_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_approval_requests_version
        FOREIGN KEY (rule_version_id)
        REFERENCES engineering_rule_versions (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_approval_requests_requested_by
        FOREIGN KEY (requested_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_approval_requests_target_approver
        FOREIGN KEY (target_approver_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_rule_approval_requests_type
        CHECK (request_type IN (
            'new_rule','rule_update','rule_override',
            'rule_deprecation','priority_change','customer_adoption'
        )),

    CONSTRAINT chk_rule_approval_requests_status
        CHECK (status IN (
            'pending','under_review','approved',
            'rejected','withdrawn','expired'
        )),

    CONSTRAINT chk_rule_approval_requests_priority
        CHECK (priority_level IN ('low','normal','high','urgent')),

    CONSTRAINT chk_rule_approval_requests_soft_delete
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL) OR
            (is_deleted = TRUE  AND deleted_at IS NOT NULL)
        )
);

COMMENT ON TABLE rule_approval_requests IS
    'Formal approval requests for new rules, rule updates, rule overrides, or priority changes. '
    'request_type = rule_override is created when an engineer requests to override a critical rule '
    'on a specific aperture or stencil design (FRS Workflow-03). '
    'request_type = new_rule is created when an investigation generates a new rule. '
    'Approval decisions are recorded in rule_approvals.';

COMMENT ON COLUMN rule_approval_requests.justification IS 'Mandatory engineering justification. Minimum character count enforced by application (50 chars for overrides).';
COMMENT ON COLUMN rule_approval_requests.affected_project_ids IS 'Array of project UUIDs that will be affected by this rule change.';

-- ---------------------------------------------------------------------------
-- TABLE: rule_approvals
-- Individual approval/rejection decisions on a rule_approval_request.
-- Supports multi-approver workflows.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rule_approvals (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    approval_request_id     UUID            NOT NULL,
    organization_id         UUID            NOT NULL,
    approver_engineer_id    UUID            NOT NULL,
    decision                VARCHAR(20)     NOT NULL,
    decision_notes          TEXT            NULL,
    conditions_imposed      TEXT            NULL,
    decided_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by              UUID            NULL,
    updated_by              UUID            NULL,

    CONSTRAINT pk_rule_approvals
        PRIMARY KEY (id),

    CONSTRAINT uq_rule_approvals_request_approver
        UNIQUE (approval_request_id, approver_engineer_id),

    CONSTRAINT fk_rule_approvals_approval_request
        FOREIGN KEY (approval_request_id)
        REFERENCES rule_approval_requests (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_approvals_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_approvals_approver
        FOREIGN KEY (approver_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_rule_approvals_decision
        CHECK (decision IN ('approved','rejected','deferred','approved_with_conditions'))
);

COMMENT ON TABLE rule_approvals IS
    'Individual approval or rejection decisions on a rule_approval_request. '
    'An approval request may require multiple approvers (e.g., both a Senior Engineer '
    'and the Quality Manager). Each approver generates one row. '
    'The request status is updated to approved only when all required approvers have approved.';

COMMENT ON COLUMN rule_approvals.conditions_imposed IS 'Optional conditions attached to an approval (e.g., "Approved for this project only — re-evaluate for production release").';

-- =============================================================================
-- SECTION 6: RULE EFFECTIVENESS & LEARNING
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: rule_effectiveness_history
-- Tracks the real-world effectiveness of rules over time.
-- Fed by the Learning Engine when production outcomes are recorded.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS rule_effectiveness_history (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    rule_id                     UUID            NOT NULL,
    organization_id             UUID            NOT NULL,
    evaluation_period_start     DATE            NOT NULL,
    evaluation_period_end       DATE            NOT NULL,
    times_evaluated             INTEGER         NOT NULL DEFAULT 0,
    times_passed                INTEGER         NOT NULL DEFAULT 0,
    times_failed                INTEGER         NOT NULL DEFAULT 0,
    times_warned                INTEGER         NOT NULL DEFAULT 0,
    times_overridden            INTEGER         NOT NULL DEFAULT 0,
    override_justified_count    INTEGER         NOT NULL DEFAULT 0,
    override_unjustified_count  INTEGER         NOT NULL DEFAULT 0,
    defect_prevented_count      INTEGER         NOT NULL DEFAULT 0,
    defect_missed_count         INTEGER         NOT NULL DEFAULT 0,
    false_positive_count        INTEGER         NOT NULL DEFAULT 0,
    avg_confidence_pct          NUMERIC(6,4)    NULL,
    effectiveness_score         NUMERIC(5,4)    NOT NULL DEFAULT 0.5000,
    yield_impact_avg_pct        NUMERIC(6,3)    NULL,
    notes                       TEXT            NULL,
    computed_at                 TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_rule_effectiveness_history
        PRIMARY KEY (id),

    CONSTRAINT uq_rule_effectiveness_history_period
        UNIQUE (rule_id, organization_id, evaluation_period_start, evaluation_period_end),

    CONSTRAINT fk_rule_effectiveness_history_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rule_effectiveness_history_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_rule_effectiveness_history_counts
        CHECK (
            times_evaluated >= 0 AND times_passed >= 0 AND
            times_failed >= 0 AND times_warned >= 0 AND
            times_overridden >= 0 AND defect_prevented_count >= 0 AND
            defect_missed_count >= 0 AND false_positive_count >= 0
        ),

    CONSTRAINT chk_rule_effectiveness_history_effectiveness
        CHECK (effectiveness_score >= 0 AND effectiveness_score <= 1.0),

    CONSTRAINT chk_rule_effectiveness_history_dates
        CHECK (evaluation_period_end >= evaluation_period_start)
);

COMMENT ON TABLE rule_effectiveness_history IS
    'Periodic effectiveness summaries for engineering rules, fed by the Learning Engine. '
    'Tracks how often a rule fires, how often it is overridden, and whether its '
    'predictions matched real production outcomes. '
    'effectiveness_score (0.0–1.0) is updated by the Learning System and feeds back '
    'into the rule''s base_confidence_pct.';

COMMENT ON COLUMN rule_effectiveness_history.false_positive_count IS 'Times the rule fired (fail/warning) but no defect was found in production — the rule was overly conservative.';
COMMENT ON COLUMN rule_effectiveness_history.effectiveness_score IS '0.0–1.0 composite effectiveness. Updated by Learning Engine. Feeds back to engineering_rules.base_confidence_pct.';

-- =============================================================================
-- SECTION 7: PROFILE TABLES
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: customer_rule_profiles
-- Associates a customer with the rule sets and standards they require.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS customer_rule_profiles (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             UUID            NOT NULL,
    customer_id                 UUID            NOT NULL,
    profile_name                VARCHAR(255)    NOT NULL,
    description                 TEXT            NULL,
    required_rule_ids           UUID[]          NOT NULL DEFAULT '{}',
    prohibited_rule_ids         UUID[]          NOT NULL DEFAULT '{}',
    required_ipc_class          VARCHAR(10)     NOT NULL DEFAULT 'class_2',
    require_signed_reports      BOOLEAN         NOT NULL DEFAULT FALSE,
    require_spi_validation      BOOLEAN         NOT NULL DEFAULT FALSE,
    require_xray_for_bga        BOOLEAN         NOT NULL DEFAULT FALSE,
    custom_thresholds           JSONB           NOT NULL DEFAULT '{}',
    effective_from              DATE            NOT NULL DEFAULT CURRENT_DATE,
    effective_until             DATE            NULL,
    approved_by_engineer_id     UUID            NULL,
    approved_at                 TIMESTAMPTZ     NULL,
    is_active                   BOOLEAN         NOT NULL DEFAULT TRUE,
    is_deleted                  BOOLEAN         NOT NULL DEFAULT FALSE,
    deleted_at                  TIMESTAMPTZ     NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_customer_rule_profiles
        PRIMARY KEY (id),

    CONSTRAINT fk_customer_rule_profiles_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_customer_rule_profiles_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_customer_rule_profiles_approved_by
        FOREIGN KEY (approved_by_engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_customer_rule_profiles_ipc_class
        CHECK (required_ipc_class IN ('class_1','class_2','class_3')),

    CONSTRAINT chk_customer_rule_profiles_soft_delete
        CHECK (
            (is_deleted = FALSE AND deleted_at IS NULL) OR
            (is_deleted = TRUE  AND deleted_at IS NOT NULL)
        ),

    CONSTRAINT chk_customer_rule_profiles_dates
        CHECK (effective_until IS NULL OR effective_until >= effective_from)
);

COMMENT ON TABLE customer_rule_profiles IS
    'Maps a customer to their engineering rule requirements. '
    'required_rule_ids lists rules the customer mandates (in addition to IPC base). '
    'prohibited_rule_ids lists rules the customer disallows (e.g., waived IPC requirements). '
    'custom_thresholds JSONB allows customer-specific threshold overrides: '
    '{area_ratio_minimum: 0.70, max_bridging_risk: 0.30}. '
    'Applied when the Rule Engine processes a design under this customer.';

COMMENT ON COLUMN customer_rule_profiles.custom_thresholds IS 'JSONB map of parameter name to customer-required threshold: {"area_ratio_minimum": 0.70, "max_void_pct": 20}.';

-- ---------------------------------------------------------------------------
-- TABLE: company_rule_profiles
-- Organization-level standard rule configurations.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS company_rule_profiles (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             UUID            NOT NULL,
    profile_name                VARCHAR(255)    NOT NULL,
    description                 TEXT            NULL,
    profile_type                VARCHAR(30)     NOT NULL DEFAULT 'default',
    required_rule_ids           UUID[]          NOT NULL DEFAULT '{}',
    prohibited_rule_ids         UUID[]          NOT NULL DEFAULT '{}',
    default_ipc_class           VARCHAR(10)     NOT NULL DEFAULT 'class_2',
    default_stencil_material_type VARCHAR(30)   NULL,
    default_rule_set_priorities JSONB           NOT NULL DEFAULT '{}',
    custom_thresholds           JSONB           NOT NULL DEFAULT '{}',
    is_default                  BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active                   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_company_rule_profiles
        PRIMARY KEY (id),

    CONSTRAINT fk_company_rule_profiles_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_company_rule_profiles_type
        CHECK (profile_type IN (
            'default','high_reliability','automotive',
            'medical','aerospace','consumer','prototype'
        )),

    CONSTRAINT chk_company_rule_profiles_ipc_class
        CHECK (default_ipc_class IN ('class_1','class_2','class_3'))
);

COMMENT ON TABLE company_rule_profiles IS
    'Organization-level standard rule configurations for different product types. '
    'A company may have multiple profiles (e.g., "High Reliability", "Standard Consumer", "Prototype"). '
    'The default profile is applied when no customer or project-specific profile exists. '
    'default_rule_set_priorities JSONB overrides priority scores for specific rules within this profile.';

-- ---------------------------------------------------------------------------
-- TABLE: engineer_rule_profiles
-- Per-engineer rule preferences and personal overrides.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineer_rule_profiles (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    engineer_id                 UUID            NOT NULL,
    organization_id             UUID            NOT NULL,
    profile_name                VARCHAR(100)    NOT NULL DEFAULT 'Default',
    preferred_rule_sources      TEXT[]          NOT NULL DEFAULT '{ipc_standard,company_rule}',
    trusted_ai_recommendations  BOOLEAN         NOT NULL DEFAULT TRUE,
    default_ipc_class           VARCHAR(10)     NOT NULL DEFAULT 'class_2',
    show_advisory_rules         BOOLEAN         NOT NULL DEFAULT TRUE,
    auto_run_analysis           BOOLEAN         NOT NULL DEFAULT TRUE,
    saved_what_if_limit         INTEGER         NOT NULL DEFAULT 20,
    custom_thresholds           JSONB           NOT NULL DEFAULT '{}',
    is_active                   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_engineer_rule_profiles
        PRIMARY KEY (id),

    CONSTRAINT uq_engineer_rule_profiles_engineer
        UNIQUE (engineer_id, organization_id),

    CONSTRAINT fk_engineer_rule_profiles_engineer
        FOREIGN KEY (engineer_id)
        REFERENCES engineers (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_engineer_rule_profiles_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_engineer_rule_profiles_ipc_class
        CHECK (default_ipc_class IN ('class_1','class_2','class_3')),

    CONSTRAINT chk_engineer_rule_profiles_saved_limit
        CHECK (saved_what_if_limit > 0 AND saved_what_if_limit <= 100)
);

COMMENT ON TABLE engineer_rule_profiles IS
    'Per-engineer rule evaluation preferences. '
    'preferred_rule_sources is an ordered array indicating which knowledge sources '
    'the engineer trusts and in what order. custom_thresholds allows personal threshold '
    'adjustments (within approved bounds) for exploratory work. '
    'One profile per engineer per organization.';

-- ---------------------------------------------------------------------------
-- TABLE: ai_recommendation_profiles
-- Configuration for AI-generated rule recommendations per organization.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ai_recommendation_profiles (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             UUID            NOT NULL,
    profile_name                VARCHAR(100)    NOT NULL,
    model_version               VARCHAR(50)     NULL,
    min_confidence_threshold    NUMERIC(6,4)    NOT NULL DEFAULT 0.7500,
    auto_apply_threshold        NUMERIC(6,4)    NULL,
    require_approval_above      NUMERIC(6,4)    NULL,
    enabled_recommendation_types TEXT[]         NOT NULL DEFAULT '{}',
    disabled_rule_categories    TEXT[]          NOT NULL DEFAULT '{}',
    learning_enabled            BOOLEAN         NOT NULL DEFAULT TRUE,
    feedback_weight             NUMERIC(5,4)    NOT NULL DEFAULT 0.0500,
    is_active                   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by                  UUID            NULL,
    updated_by                  UUID            NULL,

    CONSTRAINT pk_ai_recommendation_profiles
        PRIMARY KEY (id),

    CONSTRAINT uq_ai_recommendation_profiles_org
        UNIQUE (organization_id, profile_name),

    CONSTRAINT fk_ai_recommendation_profiles_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_ai_recommendation_profiles_confidence
        CHECK (min_confidence_threshold >= 0 AND min_confidence_threshold <= 1.0),

    CONSTRAINT chk_ai_recommendation_profiles_feedback_weight
        CHECK (feedback_weight >= 0 AND feedback_weight <= 1.0)
);

COMMENT ON TABLE ai_recommendation_profiles IS
    'Configuration for AI-generated rule recommendations within an organization. '
    'min_confidence_threshold: minimum AI confidence before showing a recommendation. '
    'auto_apply_threshold: confidence above which AI recommendations are auto-applied (NULL = never auto-apply). '
    'feedback_weight: how strongly engineer feedback adjusts AI confidence scores (Learning System).';

-- =============================================================================
-- SECTION 8: EXPLAINABILITY & CONFIDENCE
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: decision_explanations
-- Stores the full multi-level explanation for every significant
-- engineering decision made by the Intelligence Engine.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS decision_explanations (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    organization_id             UUID            NOT NULL,
    decision_type               VARCHAR(30)     NOT NULL DEFAULT 'rule_result',
    source_entity_type          VARCHAR(50)     NOT NULL,
    source_entity_id            UUID            NOT NULL,
    rule_id                     UUID            NULL,
    engineer_id                 UUID            NULL,
    explanation_level_1         TEXT            NOT NULL,
    explanation_level_2         TEXT            NULL,
    explanation_level_3         TEXT            NULL,
    ipc_references              TEXT[]          NOT NULL DEFAULT '{}',
    theory_card_codes           TEXT[]          NOT NULL DEFAULT '{}',
    related_defect_codes        TEXT[]          NOT NULL DEFAULT '{}',
    tradeoffs                   TEXT            NULL,
    expected_improvement        TEXT            NULL,
    confidence_pct              NUMERIC(6,4)    NOT NULL DEFAULT 0.8000,
    is_system_generated         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_decision_explanations
        PRIMARY KEY (id),

    CONSTRAINT fk_decision_explanations_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_decision_explanations_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_decision_explanations_engineer
        FOREIGN KEY (engineer_id)
        REFERENCES engineers (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_decision_explanations_type
        CHECK (decision_type IN (
            'rule_result','recommendation','score_component',
            'defect_risk','yield_prediction','conflict_resolution',
            'what_if_result','override_justification'
        )),

    CONSTRAINT chk_decision_explanations_confidence
        CHECK (confidence_pct >= 0 AND confidence_pct <= 1.0)
);

COMMENT ON TABLE decision_explanations IS
    'Multi-level explanations for every significant Intelligence Engine decision. '
    'Implements the Explainability Engine (Engineering Intelligence Spec Section 8). '
    'explanation_level_1: one-paragraph summary for fast reading. '
    'explanation_level_2: full engineering detail with physics/chemistry rationale. '
    'explanation_level_3: complete knowledge-depth treatise with academic references. '
    'Append-only — explanations are never modified after creation.';

COMMENT ON COLUMN decision_explanations.explanation_level_1 IS 'Summary explanation: actionable, plain language, 1–3 sentences. Shown in default view.';
COMMENT ON COLUMN decision_explanations.explanation_level_2 IS 'Engineering detail: physics/chemistry rationale, quantified improvement, alternative options. Shown in expanded view.';
COMMENT ON COLUMN decision_explanations.explanation_level_3 IS 'Full knowledge depth: academic references, IPC section text, DOE data, case study links. Shown in knowledge base view.';

-- ---------------------------------------------------------------------------
-- TABLE: engineering_confidence_scores
-- Tracks confidence score history for rules, enabling temporal analysis
-- of how the Learning Engine has updated rule confidence over time.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineering_confidence_scores (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    rule_id                 UUID            NOT NULL,
    organization_id         UUID            NOT NULL,
    previous_confidence     NUMERIC(6,4)    NOT NULL,
    new_confidence          NUMERIC(6,4)    NOT NULL,
    delta                   NUMERIC(6,4)    NOT NULL,
    update_reason           VARCHAR(50)     NOT NULL,
    evidence_type           VARCHAR(30)     NOT NULL DEFAULT 'production_observation',
    evidence_strength       NUMERIC(4,2)    NOT NULL DEFAULT 0.50,
    source_entity_type      VARCHAR(50)     NULL,
    source_entity_id        UUID            NULL,
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_engineering_confidence_scores
        PRIMARY KEY (id),

    CONSTRAINT fk_engineering_confidence_scores_rule
        FOREIGN KEY (rule_id)
        REFERENCES engineering_rules (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_engineering_confidence_scores_organization
        FOREIGN KEY (organization_id)
        REFERENCES organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_engineering_confidence_scores_values
        CHECK (
            previous_confidence >= 0 AND previous_confidence <= 1.0 AND
            new_confidence >= 0 AND new_confidence <= 1.0
        ),

    CONSTRAINT chk_engineering_confidence_scores_evidence_strength
        CHECK (evidence_strength >= 0 AND evidence_strength <= 1.0),

    CONSTRAINT chk_engineering_confidence_scores_update_reason
        CHECK (update_reason IN (
            'corrective_action_validated','rule_override_outcome',
            'experiment_conclusion','spi_correlation',
            'defect_investigation_closed','manual_adjustment',
            'ai_calibration','confidence_decay'
        )),

    CONSTRAINT chk_engineering_confidence_scores_evidence_type
        CHECK (evidence_type IN (
            'controlled_experiment','production_validation',
            'production_observation','single_event',
            'expert_review','ai_analysis'
        ))
);

COMMENT ON TABLE engineering_confidence_scores IS
    'Immutable audit trail of confidence score updates made by the Learning Engine. '
    'Every change to engineering_rules.base_confidence_pct is recorded here '
    'with full context: why it changed, by how much, and what evidence drove it. '
    'Enables temporal analysis: "how has this rule''s confidence evolved over 2 years?"';

COMMENT ON COLUMN engineering_confidence_scores.evidence_strength IS '0.0–1.0 weight of evidence driving this update. Controlled experiment = 1.0, single event = 0.2.';
COMMENT ON COLUMN engineering_confidence_scores.delta IS 'new_confidence - previous_confidence. Positive = confidence increased; negative = decreased.';

COMMIT;
