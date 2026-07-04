-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-002: Projects & Customers
-- File: DB002_Seed.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Seed data for:
--   - Project templates (system-level)
--   - Application config additions for project module
--   - Default project tag suggestions (org-independent reference data)
-- =============================================================================
-- Fixed UUID strategy: 00000002-{table}-{sequence}
-- =============================================================================

BEGIN;

-- =============================================================================
-- APPLICATION CONFIG — Project module settings
-- =============================================================================

INSERT INTO application_config (
    id, config_key, config_value, config_type, environment, description,
    created_at, updated_at
) VALUES

-- Project number format (default — overridden per org in organization_settings)
('00000002-0001-0001-0001-000000000001',
 'project.number_format',
 '{ORG}-{YEAR}-{SEQ:04d}',
 'string', 'all',
 'Default project number format. Tokens: {ORG}=org code, {YEAR}=4-digit year, '
 '{SEQ:04d}=zero-padded 4-digit sequence. Override per org in organization_settings.',
 NOW(), NOW()),

-- Project number sequence start
('00000002-0001-0001-0001-000000000002',
 'project.number_sequence_start',
 '1',
 'integer', 'all',
 'Starting sequence number for auto-generated project numbers.',
 NOW(), NOW()),

-- Maximum tags per project
('00000002-0001-0001-0001-000000000003',
 'project.max_tags',
 '20',
 'integer', 'all',
 'Maximum number of tags that can be assigned to a single project.',
 NOW(), NOW()),

-- Maximum attachments per project
('00000002-0001-0001-0001-000000000004',
 'project.max_attachments',
 '100',
 'integer', 'all',
 'Maximum number of attachments per project.',
 NOW(), NOW()),

-- Attachment max size
('00000002-0001-0001-0001-000000000005',
 'project.attachment_max_size_bytes',
 '104857600',
 'integer', 'all',
 'Maximum file size for project attachments (100 MB).',
 NOW(), NOW()),

-- Auto-archive after completion
('00000002-0001-0001-0001-000000000006',
 'project.auto_archive_days_after_completion',
 '365',
 'integer', 'all',
 'Number of days after actual_completion_date before a project is auto-archived. '
 '0 = never auto-archive.',
 NOW(), NOW()),

-- Status transition rules (JSON definition)
('00000002-0001-0001-0001-000000000007',
 'project.status_transitions',
 '{"draft":["active","archived"],'
 '"active":["on_hold","in_review","completed","archived"],'
 '"on_hold":["active","archived"],'
 '"in_review":["active","approved","archived"],'
 '"approved":["active","completed","archived"],'
 '"completed":["archived"],'
 '"archived":[]}',
 'json', 'all',
 'Allowed project status transition map. Key = current status, value = list of permitted next statuses.',
 NOW(), NOW()),

-- Phase transition default order
('00000002-0001-0001-0001-000000000008',
 'project.phase_order',
 '["npi","pre_production","production","eco","sustaining","end_of_life"]',
 'json', 'all',
 'Logical phase progression order for display and validation.',
 NOW(), NOW()),

-- Minimum override justification length (project-specific override)
('00000002-0001-0001-0001-000000000009',
 'project.note_min_content_chars',
 '10',
 'integer', 'all',
 'Minimum character count for project note content.',
 NOW(), NOW()),

-- Activity feed page size
('00000002-0001-0001-0001-000000000010',
 'project.activity_feed_page_size',
 '50',
 'integer', 'all',
 'Number of activity entries per page in the project activity feed.',
 NOW(), NOW())

ON CONFLICT (config_key, environment) DO NOTHING;

-- =============================================================================
-- PROJECT TEMPLATES — System templates
-- organization_id = NULL → available to all organizations
-- =============================================================================

INSERT INTO project_templates (
    id, organization_id, name, description,
    default_phase, default_ipc_class, default_tags,
    template_settings, is_system_template, is_active,
    usage_count, created_at, updated_at
) VALUES

-- Template 1: New Product Introduction
(
    '00000002-0002-0001-0001-000000000001',
    NULL,
    'New Product Introduction (NPI)',
    'Standard template for new product introduction projects. '
    'Activates full engineering validation suite including fine-pitch, BGA, '
    'and thermal pad rule groups. Requires IPC Class 2 minimum.',
    'npi',
    'class_2',
    ARRAY['npi','new-product','engineering-validation'],
    jsonb_build_object(
        'require_full_rule_check_before_approval', TRUE,
        'require_spi_data_before_closure',         FALSE,
        'suggested_ipc_rule_sets',                 ARRAY['IPC-7525B-APERTURE','IPC-7093-THERMAL'],
        'checklist_items', jsonb_build_array(
            'PCB Assembly defined with surface finish',
            'All component land patterns defined',
            'Stencil design created and rule check passed',
            'Print parameter set validated',
            'SPI data collected for first article',
            'Stencil Design Report generated and signed',
            'Customer approved stencil specification'
        )
    ),
    TRUE, TRUE, 0, NOW(), NOW()
),

-- Template 2: Engineering Change Order
(
    '00000002-0002-0001-0001-000000000002',
    NULL,
    'Engineering Change Order (ECO)',
    'Template for engineering change orders on existing products. '
    'Focuses on change impact assessment, differential rule checking, '
    'and revision documentation. Inherits IPC class from previous project.',
    'eco',
    'class_2',
    ARRAY['eco','engineering-change','revision'],
    jsonb_build_object(
        'require_full_rule_check_before_approval', TRUE,
        'require_change_impact_note',              TRUE,
        'require_prior_project_reference',         TRUE,
        'suggested_ipc_rule_sets',                 ARRAY['IPC-7525B-APERTURE'],
        'checklist_items', jsonb_build_array(
            'Change impact assessment documented in project notes',
            'Prior approved stencil revision referenced',
            'Modified apertures identified and re-evaluated',
            'Rule check run on changed apertures',
            'Updated Stencil Design Report generated',
            'Customer change approval documented'
        )
    ),
    TRUE, TRUE, 0, NOW(), NOW()
),

-- Template 3: Production Transfer
(
    '00000002-0002-0001-0001-000000000003',
    NULL,
    'Production Transfer',
    'Template for transferring an existing product from one manufacturing site to another. '
    'Emphasizes process parameter validation, equipment qualification, and '
    'SPI correlation against source site baseline.',
    'pre_production',
    'class_2',
    ARRAY['production-transfer','site-transfer','qualification'],
    jsonb_build_object(
        'require_full_rule_check_before_approval', TRUE,
        'require_spi_data_before_closure',         TRUE,
        'require_process_parameter_set',           TRUE,
        'suggested_ipc_rule_sets',                 ARRAY['IPC-7525B-APERTURE','IPC-7530-REFLOW'],
        'checklist_items', jsonb_build_array(
            'Source site stencil specification obtained',
            'Local equipment registered (printer, placement machine, oven)',
            'Process parameters validated on local equipment',
            'First article SPI data collected and correlated to source baseline',
            'Defect comparison report generated',
            'Production transfer approval received from customer'
        )
    ),
    TRUE, TRUE, 0, NOW(), NOW()
),

-- Template 4: IPC Class 3 / High Reliability
(
    '00000002-0002-0001-0001-000000000004',
    NULL,
    'High Reliability (IPC Class 3)',
    'Template for high-reliability assemblies requiring IPC Class 3 compliance. '
    'Activates the strictest rule sets, requires signed reports, and mandates '
    'X-ray inspection for BGA components. Suitable for aerospace, defense, and medical.',
    'npi',
    'class_3',
    ARRAY['class-3','high-reliability','aerospace','medical','defense'],
    jsonb_build_object(
        'require_full_rule_check_before_approval',  TRUE,
        'require_spi_data_before_closure',          TRUE,
        'require_signed_report',                    TRUE,
        'require_xray_for_bga',                     TRUE,
        'require_senior_engineer_approval',         TRUE,
        'suggested_ipc_rule_sets',                  ARRAY[
            'IPC-7525B-APERTURE','IPC-7093-THERMAL',
            'IPC-7530-REFLOW','IPC-A-610-CLASS3'
        ],
        'checklist_items', jsonb_build_array(
            'IPC Class 3 rule set activated',
            'Customer IPC Class 3 requirement confirmed',
            'Regulatory requirements documented',
            'All critical rule failures resolved (no waivers)',
            'X-ray inspection specified for BGA components',
            'SPI data collected with Class 3 limits applied',
            'Signed Stencil Design Report generated',
            'Senior Engineer approval obtained',
            'Quality records archived per customer requirements'
        )
    ),
    TRUE, TRUE, 0, NOW(), NOW()
),

-- Template 5: Prototype / Quick-Turn
(
    '00000002-0002-0001-0001-000000000005',
    NULL,
    'Prototype / Quick-Turn',
    'Streamlined template for prototype and quick-turn projects. '
    'Focuses on speed of execution with advisory-level engineering checks. '
    'Not suitable for production release without upgrade to a full NPI template.',
    'npi',
    'class_1',
    ARRAY['prototype','quick-turn','development'],
    jsonb_build_object(
        'require_full_rule_check_before_approval', FALSE,
        'require_spi_data_before_closure',         FALSE,
        'require_signed_report',                   FALSE,
        'advisory_only_rule_check',                TRUE,
        'checklist_items', jsonb_build_array(
            'PCB Assembly defined',
            'Stencil design created',
            'Advisory rule check reviewed',
            'Engineering notes document any known deviations'
        )
    ),
    TRUE, TRUE, 0, NOW(), NOW()
)

ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- MIGRATION RECORD
-- =============================================================================

INSERT INTO schema_migrations (version_num, applied_at)
VALUES ('0002_db002_projects_customers', NOW())
ON CONFLICT (version_num) DO NOTHING;

COMMIT;
