-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-001: Core System & User Management
-- File: DB001_Seed.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Seed data for:
--   - System roles (5)
--   - All permissions (40)
--   - Role-permission mappings (per FRS permission matrix)
--   - Default application config
--   - Default feature flags
-- =============================================================================
-- IMPORTANT: This seed file uses fixed UUIDs for system records so that
-- subsequent modules can reference them without lookup.
-- All system record UUIDs follow the pattern:
--   00000001-0001-0001-0001-{12-digit-sequence}
-- =============================================================================

BEGIN;

-- =============================================================================
-- SYSTEM ROLES
-- Fixed UUIDs for cross-module referencing
-- =============================================================================

INSERT INTO roles (
    id, organization_id, name, code, description,
    is_system_role, is_active, created_at, updated_at
) VALUES
(
    '00000001-0001-0001-0001-000000000001',
    NULL,
    'Viewer',
    'viewer',
    'Read-only access. Can view all project data, designs, reports, and knowledge base. Cannot create or modify any records.',
    TRUE, TRUE, NOW(), NOW()
),
(
    '00000001-0001-0001-0001-000000000002',
    NULL,
    'Engineer',
    'engineer',
    'Primary working role for SMT process engineers. Full create and edit access to project data, stencil designs, defect investigations, and reports.',
    TRUE, TRUE, NOW(), NOW()
),
(
    '00000001-0001-0001-0001-000000000003',
    NULL,
    'Senior Engineer',
    'senior_engineer',
    'Experienced engineers with approval authority. Can approve stencil revisions, override rules with justification, publish case studies, and close investigations.',
    TRUE, TRUE, NOW(), NOW()
),
(
    '00000001-0001-0001-0001-000000000004',
    NULL,
    'Administrator',
    'admin',
    'Organization administrator. Full access including user management, custom rule editing, organization settings, and audit log access.',
    TRUE, TRUE, NOW(), NOW()
),
(
    '00000001-0001-0001-0001-000000000005',
    NULL,
    'Super Administrator',
    'super_admin',
    'System-level administrator. Cross-organization access. Manages system rule sets, reference data, organizations, and feature flags. Internal use only.',
    TRUE, TRUE, NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- PERMISSIONS
-- Fixed UUIDs. Code follows dot-notation: module.action
-- =============================================================================

INSERT INTO permissions (id, code, module, description, is_active, created_at, updated_at) VALUES

-- Project permissions
('00000001-0002-0001-0001-000000000001', 'project.view',   'projects', 'View all projects and their contents within the organization.',            TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000002', 'project.create', 'projects', 'Create new projects.',                                                      TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000003', 'project.edit',   'projects', 'Edit project metadata, status, and team membership.',                        TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000004', 'project.delete', 'projects', 'Soft-delete projects (only when no stencil designs or reports exist).',      TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000005', 'project.archive','projects', 'Archive completed or cancelled projects.',                                    TRUE, NOW(), NOW()),

-- Stencil permissions
('00000001-0002-0001-0001-000000000011', 'stencil.view',    'stencils', 'View stencil designs and aperture details.',                                 TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000012', 'stencil.create',  'stencils', 'Create new stencil designs and aperture configurations.',                   TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000013', 'stencil.edit',    'stencils', 'Edit stencil designs and aperture parameters.',                              TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000014', 'stencil.approve', 'stencils', 'Approve stencil revisions (Senior Engineer or above). Four-eyes enforced.', TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000015', 'stencil.delete',  'stencils', 'Soft-delete stencil designs.',                                              TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000016', 'stencil.export',  'stencils', 'Export stencil data to DXF or Gerber format.',                              TRUE, NOW(), NOW()),

-- Aperture permissions
('00000001-0002-0001-0001-000000000021', 'aperture.view',     'apertures', 'View aperture designs.',                                                  TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000022', 'aperture.edit',     'apertures', 'Create and edit aperture designs.',                                       TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000023', 'aperture.override', 'apertures', 'Override a failing engineering rule on an aperture (with justification).', TRUE, NOW(), NOW()),

-- Analysis permissions
('00000001-0002-0001-0001-000000000031', 'analysis.run',    'analysis', 'Trigger engineering rule check and intelligence analysis.',                   TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000032', 'analysis.view',   'analysis', 'View rule check results, scores, recommendations, and yield predictions.',   TRUE, NOW(), NOW()),

-- Rule set permissions
('00000001-0002-0001-0001-000000000041', 'rule_set.view',   'rules', 'View rule sets and individual rule definitions.',                               TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000042', 'rule_set.create', 'rules', 'Create custom rule sets for the organization.',                                 TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000043', 'rule_set.edit',   'rules', 'Edit existing custom rule sets and rule definitions.',                          TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000044', 'rule_set.delete', 'rules', 'Deactivate custom rule sets.',                                                  TRUE, NOW(), NOW()),

-- Defect and investigation permissions
('00000001-0002-0001-0001-000000000051', 'defect.view',        'defects', 'View defect records, defect library, and investigation history.',           TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000052', 'defect.log',         'defects', 'Log new defect records.',                                                  TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000053', 'defect.investigate', 'defects', 'Open and lead defect investigations.',                                     TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000054', 'defect.close',       'defects', 'Close defect investigations and capture lessons learned.',                  TRUE, NOW(), NOW()),

-- Report permissions
('00000001-0002-0001-0001-000000000061', 'report.view',     'reports', 'View and download generated reports.',                                         TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000062', 'report.generate', 'reports', 'Generate new PDF and XLSX reports.',                                           TRUE, NOW(), NOW()),

-- Knowledge base permissions
('00000001-0002-0001-0001-000000000071', 'knowledge.view',    'knowledge', 'View IPC references, theory cards, case studies, and experiments.',        TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000072', 'knowledge.create',  'knowledge', 'Create case studies and experiments.',                                     TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000073', 'knowledge.edit',    'knowledge', 'Edit and publish case studies to the organization knowledge base.',        TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000074', 'knowledge.delete',  'knowledge', 'Delete draft case studies and unpublished knowledge records.',             TRUE, NOW(), NOW()),

-- Image library permissions
('00000001-0002-0001-0001-000000000081', 'image.view',   'images', 'View and download images from the organization image library.',                     TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000082', 'image.upload', 'images', 'Upload new images and add metadata and annotations.',                              TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000083', 'image.delete', 'images', 'Soft-delete images from the library.',                                             TRUE, NOW(), NOW()),

-- Materials and equipment permissions
('00000001-0002-0001-0001-000000000091', 'material.view',   'materials', 'View the materials library (stencil materials, pastes, coatings, thicknesses).', TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000092', 'material.manage', 'materials', 'Add and edit custom materials and equipment records.',                             TRUE, NOW(), NOW()),

-- Inspection data permissions
('00000001-0002-0001-0001-000000000101', 'inspection.view',   'inspection', 'View SPI, AOI, and X-ray inspection results.',                            TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000102', 'inspection.import', 'inspection', 'Import and log inspection data (SPI files, AOI results, X-ray data).',    TRUE, NOW(), NOW()),

-- User management permissions
('00000001-0002-0001-0001-000000000111', 'engineer.view',   'admin', 'View engineer profiles and role assignments.',                                    TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000112', 'engineer.manage', 'admin', 'Create, edit, deactivate engineers and manage role assignments.',                 TRUE, NOW(), NOW()),

-- Administration permissions
('00000001-0002-0001-0001-000000000121', 'admin.audit_log',     'admin', 'View and export the organization audit log.',                                TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000122', 'admin.org_settings',  'admin', 'Configure organization settings, defaults, and approved materials list.',    TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000123', 'admin.customers',     'admin', 'Create and manage customer records.',                                        TRUE, NOW(), NOW()),
('00000001-0002-0001-0001-000000000124', 'admin.full_access',   'admin', 'Unrestricted administrative access within the organization.',                TRUE, NOW(), NOW())

ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- ROLE-PERMISSION MAPPINGS
-- Based on permission matrix in FRS Section 2.2
-- =============================================================================

-- Helper: insert role-permission safely
-- Viewer permissions
INSERT INTO role_permissions (id, role_id, permission_id, created_at, updated_at)
SELECT
    gen_random_uuid(),
    '00000001-0001-0001-0001-000000000001',  -- viewer
    id,
    NOW(), NOW()
FROM permissions
WHERE code IN (
    'project.view',
    'stencil.view',
    'aperture.view',
    'analysis.view',
    'rule_set.view',
    'defect.view',
    'report.view',
    'knowledge.view',
    'image.view',
    'material.view',
    'inspection.view',
    'engineer.view'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Engineer permissions (all viewer permissions + create/edit/generate)
INSERT INTO role_permissions (id, role_id, permission_id, created_at, updated_at)
SELECT
    gen_random_uuid(),
    '00000001-0001-0001-0001-000000000002',  -- engineer
    id,
    NOW(), NOW()
FROM permissions
WHERE code IN (
    'project.view',    'project.create',   'project.edit',   'project.archive',
    'stencil.view',    'stencil.create',   'stencil.edit',   'stencil.export',
    'aperture.view',   'aperture.edit',
    'analysis.run',    'analysis.view',
    'rule_set.view',
    'defect.view',     'defect.log',       'defect.investigate',
    'report.view',     'report.generate',
    'knowledge.view',  'knowledge.create',
    'image.view',      'image.upload',
    'material.view',   'material.manage',
    'inspection.view', 'inspection.import',
    'engineer.view'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Senior Engineer permissions (all engineer permissions + approval powers)
INSERT INTO role_permissions (id, role_id, permission_id, created_at, updated_at)
SELECT
    gen_random_uuid(),
    '00000001-0001-0001-0001-000000000003',  -- senior_engineer
    id,
    NOW(), NOW()
FROM permissions
WHERE code IN (
    'project.view',    'project.create',   'project.edit',   'project.archive',   'project.delete',
    'stencil.view',    'stencil.create',   'stencil.edit',   'stencil.approve',   'stencil.export', 'stencil.delete',
    'aperture.view',   'aperture.edit',    'aperture.override',
    'analysis.run',    'analysis.view',
    'rule_set.view',   'rule_set.create',  'rule_set.edit',
    'defect.view',     'defect.log',       'defect.investigate', 'defect.close',
    'report.view',     'report.generate',
    'knowledge.view',  'knowledge.create', 'knowledge.edit',  'knowledge.delete',
    'image.view',      'image.upload',     'image.delete',
    'material.view',   'material.manage',
    'inspection.view', 'inspection.import',
    'engineer.view'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Admin permissions (all senior engineer permissions + user/org management)
INSERT INTO role_permissions (id, role_id, permission_id, created_at, updated_at)
SELECT
    gen_random_uuid(),
    '00000001-0001-0001-0001-000000000004',  -- admin
    id,
    NOW(), NOW()
FROM permissions
WHERE code IN (
    'project.view',    'project.create',   'project.edit',     'project.archive',  'project.delete',
    'stencil.view',    'stencil.create',   'stencil.edit',     'stencil.approve',  'stencil.export', 'stencil.delete',
    'aperture.view',   'aperture.edit',    'aperture.override',
    'analysis.run',    'analysis.view',
    'rule_set.view',   'rule_set.create',  'rule_set.edit',    'rule_set.delete',
    'defect.view',     'defect.log',       'defect.investigate','defect.close',
    'report.view',     'report.generate',
    'knowledge.view',  'knowledge.create', 'knowledge.edit',   'knowledge.delete',
    'image.view',      'image.upload',     'image.delete',
    'material.view',   'material.manage',
    'inspection.view', 'inspection.import',
    'engineer.view',   'engineer.manage',
    'admin.audit_log', 'admin.org_settings','admin.customers',  'admin.full_access'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Super Admin permissions: all permissions
INSERT INTO role_permissions (id, role_id, permission_id, created_at, updated_at)
SELECT
    gen_random_uuid(),
    '00000001-0001-0001-0001-000000000005',  -- super_admin
    id,
    NOW(), NOW()
FROM permissions
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- =============================================================================
-- APPLICATION CONFIG — Default System Settings
-- =============================================================================

INSERT INTO application_config (id, config_key, config_value, config_type, environment, description, created_at, updated_at) VALUES

-- Schema version
('00000001-0003-0001-0001-000000000001',
 'schema.version', '1.0.0', 'string', 'all',
 'Current database schema version. Updated by each migration.',
 NOW(), NOW()),

-- Application metadata
('00000001-0003-0001-0001-000000000002',
 'app.name', 'StencilPro Expert Enterprise', 'string', 'all',
 'Application display name used in reports and email notifications.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000003',
 'app.version', '0.1.0-alpha.1', 'string', 'all',
 'Current application version (SemVer). Updated at each release.',
 NOW(), NOW()),

-- Session policy
('00000001-0003-0001-0001-000000000010',
 'security.session_idle_timeout_hours', '8', 'integer', 'all',
 'Maximum session idle time in hours before automatic logout. Default: 8 hours.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000011',
 'security.max_login_attempts', '5', 'integer', 'all',
 'Maximum consecutive failed login attempts before lockout. Enforced by Supabase Auth.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000012',
 'security.min_override_justification_chars', '50', 'integer', 'all',
 'Minimum character count required for an engineering rule override justification.',
 NOW(), NOW()),

-- Report settings
('00000001-0003-0001-0001-000000000020',
 'report.max_file_size_bytes', '52428800', 'integer', 'all',
 'Maximum generated report file size (50 MB). Reports exceeding this are split.',
 NOW(), NOW()),

-- IPC defaults
('00000001-0003-0001-0001-000000000030',
 'ipc.default_area_ratio_minimum', '0.66', 'string', 'all',
 'IPC-7525B minimum area ratio for stainless steel stencils. Used as default threshold.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000031',
 'ipc.electroform_area_ratio_minimum', '0.60', 'string', 'all',
 'Minimum area ratio for electroform stencils per IPC-7525B allowance.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000032',
 'ipc.default_aspect_ratio_minimum', '1.5', 'string', 'all',
 'IPC-7525B minimum aspect ratio (aperture width / stencil thickness).',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000033',
 'ipc.thermal_pad_max_coverage_pct', '80.0', 'string', 'all',
 'IPC-7093 maximum thermal pad paste coverage percentage to prevent package floating.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000034',
 'ipc.thermal_pad_min_coverage_pct', '50.0', 'string', 'all',
 'IPC-7093 minimum thermal pad paste coverage percentage for thermal performance.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000035',
 'ipc.reflow_tal_min_seconds', '30', 'integer', 'all',
 'IPC-7530 minimum time above liquidus (TAL) in seconds.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000036',
 'ipc.reflow_tal_max_seconds', '90', 'integer', 'all',
 'IPC-7530 maximum time above liquidus (TAL) in seconds.',
 NOW(), NOW()),

-- Storage buckets
('00000001-0003-0001-0001-000000000040',
 'storage.bucket.images', 'stencilpro-images', 'string', 'all',
 'Supabase Storage bucket name for all images.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000041',
 'storage.bucket.reports', 'stencilpro-reports', 'string', 'all',
 'Supabase Storage bucket name for generated PDF and XLSX reports.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000042',
 'storage.bucket.documents', 'stencilpro-documents', 'string', 'all',
 'Supabase Storage bucket name for document attachments.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000043',
 'storage.bucket.cad', 'stencilpro-cad', 'string', 'all',
 'Supabase Storage bucket name for CAD files (Gerber, ODB++, IPC-2581).',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000044',
 'storage.max_image_size_bytes', '52428800', 'integer', 'all',
 'Maximum image upload size in bytes (50 MB).',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000045',
 'storage.max_cad_file_size_bytes', '104857600', 'integer', 'all',
 'Maximum CAD file upload size in bytes (100 MB).',
 NOW(), NOW()),

-- Intelligence defaults
('00000001-0003-0001-0001-000000000050',
 'intelligence.confidence_min_pct', '10.0', 'string', 'all',
 'Minimum confidence score after learning adjustments (clamp floor).',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000051',
 'intelligence.confidence_max_pct', '99.0', 'string', 'all',
 'Maximum confidence score after learning adjustments (clamp ceiling).',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000052',
 'intelligence.learning_rate', '0.05', 'string', 'all',
 'Learning rate for confidence score updates from production outcomes.',
 NOW(), NOW()),

-- UI/UX defaults
('00000001-0003-0001-0001-000000000060',
 'ui.autosave_interval_seconds', '60', 'integer', 'all',
 'Auto-save interval in seconds for active design work.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000061',
 'ui.dashboard_refresh_interval_seconds', '300', 'integer', 'all',
 'Dashboard auto-refresh interval in seconds.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000062',
 'ui.max_recent_projects', '5', 'integer', 'all',
 'Number of recently opened projects to show in the navigation panel.',
 NOW(), NOW()),

('00000001-0003-0001-0001-000000000063',
 'ui.notification_count_max', '20', 'integer', 'all',
 'Maximum number of notifications shown in the notification panel.',
 NOW(), NOW())

ON CONFLICT (config_key, environment) DO NOTHING;

-- =============================================================================
-- FEATURE FLAGS — Initial State
-- All features default OFF; enabled as modules are deployed.
-- =============================================================================

INSERT INTO feature_flags (id, flag_key, description, is_enabled_globally, enabled_for_org_ids, enabled_for_tiers, rollout_percentage, created_at, updated_at) VALUES

('00000001-0004-0001-0001-000000000001',
 'module.project_management',
 'Enable Project Management module (Module 4.02). Core feature.',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000002',
 'module.stencil_design_workspace',
 'Enable Stencil Design Workspace (Module 4.06). Core feature.',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000003',
 'module.stencil_design_wizard',
 'Enable Stencil Design Wizard (Module 4.07). Core feature.',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000004',
 'module.rule_engine',
 'Enable Rule Engine evaluation and Rule Manager (Modules 4.11, 12).',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000005',
 'module.engineering_calculators',
 'Enable Engineering Calculators (Module 4.10).',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000006',
 'module.defect_library',
 'Enable Defect Library browser (Module 4.15).',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000007',
 'module.defect_investigation',
 'Enable Defect Investigation workspace (Module 4.15).',
 TRUE, '{}', '{"professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000008',
 'module.intelligence_dashboard',
 'Enable Intelligence Dashboard with full scoring and yield prediction (Module 4.16).',
 TRUE, '{}', '{"professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000009',
 'module.thermal_pad_optimizer',
 'Enable Thermal Pad Optimizer (Module 4.09).',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000010',
 'module.knowledge_base',
 'Enable Knowledge Base (IPC references, theory cards, case studies) (Module 4.18).',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000011',
 'module.image_library',
 'Enable Image Library with upload and annotation (Module 4.19).',
 TRUE, '{}', '{"professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000012',
 'module.report_generator',
 'Enable Report Generator for PDF and XLSX exports (Module 4.20).',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000013',
 'module.inspection_data',
 'Enable SPI, AOI, and X-ray data import and correlation (Module 4.14).',
 TRUE, '{}', '{"professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000014',
 'module.learning_system',
 'Enable Learning System — confidence updates from production outcomes.',
 TRUE, '{}', '{"enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000015',
 'module.ai_assistant',
 'Enable AI Assistant (Phase 5 feature — placeholder).',
 FALSE, '{}', '{"enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000016',
 'security.four_eyes_approval',
 'Require different engineer to approve stencil revisions (four-eyes principle). Configurable per org via organization_settings.',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000017',
 'security.rule_override_requires_approval',
 'Require Senior Engineer approval for engineering rule overrides.',
 TRUE, '{}', '{"standard","professional","enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000018',
 'experimental.offline_mode',
 'Enable Phase 2 offline mode with local SQLite cache and sync queue.',
 FALSE, '{}', '{"enterprise"}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000019',
 'experimental.gerber_import',
 'Enable Phase 3 Gerber/ODB++ import pipeline for component placements.',
 FALSE, '{}', '{}', NULL, NOW(), NOW()),

('00000001-0004-0001-0001-000000000020',
 'experimental.spi_machine_integration',
 'Enable Phase 4 direct SPI machine format parsers.',
 FALSE, '{}', '{}', NULL, NOW(), NOW())

ON CONFLICT (flag_key) DO NOTHING;

-- =============================================================================
-- MIGRATION RECORD
-- =============================================================================

INSERT INTO schema_migrations (version_num, applied_at)
VALUES ('0001_db001_core_system', NOW())
ON CONFLICT (version_num) DO NOTHING;

COMMIT;
