-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-001: Core System & User Management
-- File: DB001_Indexes.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB001_Core_System.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- organizations
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_organizations_code
    ON organizations (code);

CREATE INDEX IF NOT EXISTS idx_organizations_is_active
    ON organizations (is_active)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_organizations_subscription_tier
    ON organizations (subscription_tier)
    WHERE is_deleted = FALSE AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_organizations_industry_segment
    ON organizations (industry_segment)
    WHERE is_deleted = FALSE;

-- =============================================================================
-- organization_settings
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_org_settings_organization_id
    ON organization_settings (organization_id);

CREATE INDEX IF NOT EXISTS idx_org_settings_key
    ON organization_settings (setting_key);

-- =============================================================================
-- application_config
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_application_config_key
    ON application_config (config_key);

CREATE INDEX IF NOT EXISTS idx_application_config_environment
    ON application_config (environment);

-- =============================================================================
-- engineers
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineers_organization_id
    ON engineers (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_engineers_email
    ON engineers (email);

CREATE INDEX IF NOT EXISTS idx_engineers_is_active
    ON engineers (organization_id, is_active)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_engineers_last_login_at
    ON engineers (organization_id, last_login_at DESC)
    WHERE is_deleted = FALSE AND is_active = TRUE;

-- Trigram index for full-name search
CREATE INDEX IF NOT EXISTS idx_engineers_full_name_trgm
    ON engineers USING GIN (full_name gin_trgm_ops);

-- =============================================================================
-- roles
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_roles_organization_id
    ON roles (organization_id);

CREATE INDEX IF NOT EXISTS idx_roles_code
    ON roles (code);

CREATE INDEX IF NOT EXISTS idx_roles_is_system
    ON roles (is_system_role)
    WHERE is_active = TRUE;

-- =============================================================================
-- permissions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_permissions_module
    ON permissions (module)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_permissions_code
    ON permissions (code);

-- =============================================================================
-- engineer_roles
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineer_roles_engineer_id
    ON engineer_roles (engineer_id);

CREATE INDEX IF NOT EXISTS idx_engineer_roles_role_id
    ON engineer_roles (role_id);

CREATE INDEX IF NOT EXISTS idx_engineer_roles_assigned_by
    ON engineer_roles (assigned_by_engineer_id);

-- Partial index for active (non-expired) role assignments
CREATE INDEX IF NOT EXISTS idx_engineer_roles_active
    ON engineer_roles (engineer_id, role_id)
    WHERE expires_at IS NULL OR expires_at > NOW();

-- =============================================================================
-- role_permissions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id
    ON role_permissions (role_id);

CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id
    ON role_permissions (permission_id);

-- =============================================================================
-- engineer_sessions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_engineer_sessions_engineer_id
    ON engineer_sessions (engineer_id);

CREATE INDEX IF NOT EXISTS idx_engineer_sessions_active
    ON engineer_sessions (engineer_id, last_active_at DESC)
    WHERE ended_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_engineer_sessions_token_hash
    ON engineer_sessions (session_token_hash);

-- =============================================================================
-- audit_log
-- =============================================================================

-- Note: audit_log is partitioned — indexes are created on the parent table
-- and inherited by each partition automatically in PostgreSQL 11+.

CREATE INDEX IF NOT EXISTS idx_audit_log_organization_occurred
    ON audit_log (organization_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_table_record
    ON audit_log (table_name, record_id);

CREATE INDEX IF NOT EXISTS idx_audit_log_engineer_occurred
    ON audit_log (engineer_id, occurred_at DESC)
    WHERE engineer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_audit_log_action
    ON audit_log (action, occurred_at DESC);

-- GIN index for JSONB searching within old/new values
CREATE INDEX IF NOT EXISTS idx_audit_log_new_values_gin
    ON audit_log USING GIN (new_values);

CREATE INDEX IF NOT EXISTS idx_audit_log_old_values_gin
    ON audit_log USING GIN (old_values);

-- =============================================================================
-- activity_log
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_activity_log_organization_occurred
    ON activity_log (organization_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_log_engineer_occurred
    ON activity_log (engineer_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_log_activity_type
    ON activity_log (activity_type, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_log_entity
    ON activity_log (entity_type, entity_id)
    WHERE entity_type IS NOT NULL;

-- =============================================================================
-- notifications
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
    ON notifications (recipient_engineer_id, created_at DESC)
    WHERE is_read = FALSE;

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_all
    ON notifications (recipient_engineer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_organization_id
    ON notifications (organization_id);

CREATE INDEX IF NOT EXISTS idx_notifications_entity
    ON notifications (entity_type, entity_id)
    WHERE entity_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_type
    ON notifications (notification_type, created_at DESC);

-- =============================================================================
-- notification_preferences
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_notification_preferences_engineer_id
    ON notification_preferences (engineer_id);

-- =============================================================================
-- user_preferences
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_user_preferences_engineer_id
    ON user_preferences (engineer_id);

-- =============================================================================
-- feature_flags
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_feature_flags_key
    ON feature_flags (flag_key);

CREATE INDEX IF NOT EXISTS idx_feature_flags_global
    ON feature_flags (is_enabled_globally)
    WHERE is_enabled_globally = TRUE;

-- GIN index for UUID array membership queries
CREATE INDEX IF NOT EXISTS idx_feature_flags_org_ids_gin
    ON feature_flags USING GIN (enabled_for_org_ids);

COMMIT;
