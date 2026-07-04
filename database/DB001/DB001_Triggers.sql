-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-001: Core System & User Management
-- File: DB001_Triggers.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB001_Core_System.sql and DB001_Indexes.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- TRIGGER FUNCTION: fn_set_updated_at
-- Defined in DB001_Core_System.sql — referenced here for documentation only.
-- =============================================================================

-- =============================================================================
-- TRIGGER FUNCTION: fn_audit_trigger
-- Generic audit trigger. Writes to audit_log on INSERT, UPDATE, DELETE.
-- Reads engineer identity from app.current_engineer_id session variable.
-- The application MUST call:
--   SET LOCAL app.current_engineer_id = '<uuid>';
-- at the start of each transaction before any DML.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_engineer_id   UUID;
    v_org_id        UUID;
    v_old_values    JSONB;
    v_new_values    JSONB;
    v_changed       TEXT[];
    v_key           TEXT;
BEGIN
    -- Safely read current engineer from session variable (set by app layer)
    BEGIN
        v_engineer_id := current_setting('app.current_engineer_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_engineer_id := NULL;
    END;

    -- Extract organization_id from the row where applicable
    IF TG_OP = 'DELETE' THEN
        BEGIN
            v_org_id := (row_to_json(OLD) ->> 'organization_id')::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_org_id := NULL;
        END;
    ELSE
        BEGIN
            v_org_id := (row_to_json(NEW) ->> 'organization_id')::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_org_id := NULL;
        END;
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_old_values := NULL;
        v_new_values := to_jsonb(NEW);
        v_changed    := NULL;

    ELSIF TG_OP = 'UPDATE' THEN
        v_old_values := to_jsonb(OLD);
        v_new_values := to_jsonb(NEW);

        -- Compute list of changed column names
        v_changed := ARRAY[]::TEXT[];
        FOR v_key IN
            SELECT key
            FROM jsonb_each(to_jsonb(NEW))
            WHERE to_jsonb(NEW) -> key IS DISTINCT FROM to_jsonb(OLD) -> key
        LOOP
            v_changed := v_changed || v_key;
        END LOOP;

        -- Skip trivial updates where only updated_at changed
        IF v_changed = ARRAY['updated_at'] OR
           v_changed = ARRAY['updated_at','updated_by'] THEN
            RETURN NEW;
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        v_old_values := to_jsonb(OLD);
        v_new_values := NULL;
        v_changed    := NULL;
    END IF;

    INSERT INTO audit_log (
        organization_id,
        engineer_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values,
        changed_fields,
        occurred_at
    ) VALUES (
        v_org_id,
        v_engineer_id,
        TG_OP,
        TG_TABLE_NAME,
        CASE
            WHEN TG_OP = 'DELETE' THEN (row_to_json(OLD) ->> 'id')::UUID
            ELSE (row_to_json(NEW) ->> 'id')::UUID
        END,
        v_old_values,
        v_new_values,
        v_changed,
        NOW()
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_audit_trigger() IS
    'Generic AFTER trigger function. Writes INSERT/UPDATE/DELETE events to audit_log. '
    'Reads engineer identity from session variable app.current_engineer_id. '
    'Skips trivial updates that only modify updated_at.';

-- =============================================================================
-- TRIGGER FUNCTION: fn_prevent_audit_log_modification
-- Prevents any UPDATE or DELETE on audit_log and activity_log.
-- These tables are strictly append-only.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_prevent_audit_log_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Modification of % is not permitted. This table is append-only.',
        TG_TABLE_NAME
        USING ERRCODE = 'restrict_violation';
END;
$$;

COMMENT ON FUNCTION fn_prevent_audit_log_modification() IS
    'Trigger function that raises an exception on any UPDATE or DELETE '
    'on append-only audit tables. Enforces immutability at the database layer.';

-- =============================================================================
-- TRIGGER FUNCTION: fn_prevent_notification_preferences_delete
-- Notification preferences can be deleted (own record only), but the RLS
-- policy handles that. This function handles the DB-level protection of
-- other users' preferences.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_soft_delete_check()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- If engineer is trying to hard-delete a soft-deletable record, block it
    -- Hard deletes are handled in RLS; this is a belt-and-suspenders check
    RAISE EXCEPTION
        'Hard deletion of % records is not permitted. Use soft delete (is_deleted = TRUE).',
        TG_TABLE_NAME
        USING ERRCODE = 'restrict_violation';
END;
$$;

COMMENT ON FUNCTION fn_soft_delete_check() IS
    'Prevents hard DELETE on tables that use soft delete. '
    'Applied as a BEFORE DELETE trigger on organizations and engineers.';

-- =============================================================================
-- TRIGGER FUNCTION: fn_engineers_last_login
-- Updates last_login_at on engineer_sessions INSERT (when a new session starts).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_engineer_session_start()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE engineers
    SET    last_login_at = NOW(),
           updated_at    = NOW()
    WHERE  id = NEW.engineer_id;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_engineer_session_start() IS
    'Updates engineers.last_login_at when a new engineer session is inserted.';

-- =============================================================================
-- TRIGGER FUNCTION: fn_notification_mark_read
-- Ensures read_at is set when is_read transitions to TRUE.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_notification_mark_read()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_read = TRUE AND OLD.is_read = FALSE AND NEW.read_at IS NULL THEN
        NEW.read_at := NOW();
    END IF;
    IF NEW.is_read = FALSE THEN
        NEW.read_at := NULL;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_notification_mark_read() IS
    'Automatically sets read_at = NOW() when is_read transitions TRUE. '
    'Clears read_at when is_read is set back to FALSE.';

-- =============================================================================
-- TRIGGER FUNCTION: fn_enforce_last_admin
-- Prevents removing the last Admin role from an organization.
-- Fired BEFORE DELETE on engineer_roles or BEFORE UPDATE on engineers (is_active).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_enforce_last_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_role_code     TEXT;
    v_org_id        UUID;
    v_admin_count   INTEGER;
BEGIN
    -- Get the role code for the role being removed
    SELECT code INTO v_role_code
    FROM   roles
    WHERE  id = OLD.role_id;

    IF v_role_code = 'admin' THEN
        -- Find the organization of the engineer
        SELECT organization_id INTO v_org_id
        FROM   engineers
        WHERE  id = OLD.engineer_id;

        -- Count remaining active admin assignments for this org
        SELECT COUNT(*) INTO v_admin_count
        FROM   engineer_roles er
        JOIN   roles          r  ON r.id = er.role_id
        JOIN   engineers      e  ON e.id = er.engineer_id
        WHERE  r.code            = 'admin'
          AND  e.organization_id = v_org_id
          AND  e.is_active       = TRUE
          AND  e.is_deleted      = FALSE
          AND  er.id            != OLD.id
          AND  (er.expires_at IS NULL OR er.expires_at > NOW());

        IF v_admin_count = 0 THEN
            RAISE EXCEPTION
                'Cannot remove the last administrator role from organization %. '
                'Promote another engineer to Admin before removing this assignment.',
                v_org_id
                USING ERRCODE = 'restrict_violation';
        END IF;
    END IF;

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION fn_enforce_last_admin() IS
    'Prevents deletion of the last active admin role assignment within an organization. '
    'Fired BEFORE DELETE on engineer_roles.';

-- =============================================================================
-- ATTACH TRIGGERS
-- =============================================================================

-- ---- organizations: updated_at ----
DROP TRIGGER IF EXISTS tg_organizations_updated_at ON organizations;
CREATE TRIGGER tg_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- organizations: audit ----
DROP TRIGGER IF EXISTS tg_organizations_audit ON organizations;
CREATE TRIGGER tg_organizations_audit
    AFTER INSERT OR UPDATE OR DELETE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- ---- organizations: prevent hard delete ----
DROP TRIGGER IF EXISTS tg_organizations_no_hard_delete ON organizations;
CREATE TRIGGER tg_organizations_no_hard_delete
    BEFORE DELETE ON organizations
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- ---- organization_settings: updated_at ----
DROP TRIGGER IF EXISTS tg_org_settings_updated_at ON organization_settings;
CREATE TRIGGER tg_org_settings_updated_at
    BEFORE UPDATE ON organization_settings
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- application_config: updated_at ----
DROP TRIGGER IF EXISTS tg_application_config_updated_at ON application_config;
CREATE TRIGGER tg_application_config_updated_at
    BEFORE UPDATE ON application_config
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- engineers: updated_at ----
DROP TRIGGER IF EXISTS tg_engineers_updated_at ON engineers;
CREATE TRIGGER tg_engineers_updated_at
    BEFORE UPDATE ON engineers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- engineers: audit (critical — user management changes) ----
DROP TRIGGER IF EXISTS tg_engineers_audit ON engineers;
CREATE TRIGGER tg_engineers_audit
    AFTER INSERT OR UPDATE OR DELETE ON engineers
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- ---- engineers: prevent hard delete ----
DROP TRIGGER IF EXISTS tg_engineers_no_hard_delete ON engineers;
CREATE TRIGGER tg_engineers_no_hard_delete
    BEFORE DELETE ON engineers
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- ---- roles: updated_at ----
DROP TRIGGER IF EXISTS tg_roles_updated_at ON roles;
CREATE TRIGGER tg_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- roles: audit ----
DROP TRIGGER IF EXISTS tg_roles_audit ON roles;
CREATE TRIGGER tg_roles_audit
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- ---- permissions: updated_at ----
DROP TRIGGER IF EXISTS tg_permissions_updated_at ON permissions;
CREATE TRIGGER tg_permissions_updated_at
    BEFORE UPDATE ON permissions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- engineer_roles: updated_at ----
DROP TRIGGER IF EXISTS tg_engineer_roles_updated_at ON engineer_roles;
CREATE TRIGGER tg_engineer_roles_updated_at
    BEFORE UPDATE ON engineer_roles
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- engineer_roles: audit (critical — permission changes) ----
DROP TRIGGER IF EXISTS tg_engineer_roles_audit ON engineer_roles;
CREATE TRIGGER tg_engineer_roles_audit
    AFTER INSERT OR UPDATE OR DELETE ON engineer_roles
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- ---- engineer_roles: enforce last admin ----
DROP TRIGGER IF EXISTS tg_engineer_roles_last_admin ON engineer_roles;
CREATE TRIGGER tg_engineer_roles_last_admin
    BEFORE DELETE ON engineer_roles
    FOR EACH ROW
    EXECUTE FUNCTION fn_enforce_last_admin();

-- ---- role_permissions: updated_at ----
DROP TRIGGER IF EXISTS tg_role_permissions_updated_at ON role_permissions;
CREATE TRIGGER tg_role_permissions_updated_at
    BEFORE UPDATE ON role_permissions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- role_permissions: audit ----
DROP TRIGGER IF EXISTS tg_role_permissions_audit ON role_permissions;
CREATE TRIGGER tg_role_permissions_audit
    AFTER INSERT OR UPDATE OR DELETE ON role_permissions
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- ---- engineer_sessions: updated_at ----
DROP TRIGGER IF EXISTS tg_engineer_sessions_updated_at ON engineer_sessions;
CREATE TRIGGER tg_engineer_sessions_updated_at
    BEFORE UPDATE ON engineer_sessions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- engineer_sessions: update last_login_at on new session ----
DROP TRIGGER IF EXISTS tg_engineer_session_start ON engineer_sessions;
CREATE TRIGGER tg_engineer_session_start
    AFTER INSERT ON engineer_sessions
    FOR EACH ROW
    EXECUTE FUNCTION fn_engineer_session_start();

-- ---- audit_log: PREVENT modification (append-only) ----
DROP TRIGGER IF EXISTS tg_audit_log_no_update ON audit_log;
CREATE TRIGGER tg_audit_log_no_update
    BEFORE UPDATE ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_audit_log_modification();

DROP TRIGGER IF EXISTS tg_audit_log_no_delete ON audit_log;
CREATE TRIGGER tg_audit_log_no_delete
    BEFORE DELETE ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_audit_log_modification();

-- ---- activity_log: PREVENT modification (append-only) ----
DROP TRIGGER IF EXISTS tg_activity_log_no_update ON activity_log;
CREATE TRIGGER tg_activity_log_no_update
    BEFORE UPDATE ON activity_log
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_audit_log_modification();

DROP TRIGGER IF EXISTS tg_activity_log_no_delete ON activity_log;
CREATE TRIGGER tg_activity_log_no_delete
    BEFORE DELETE ON activity_log
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_audit_log_modification();

-- ---- notifications: updated_at ----
DROP TRIGGER IF EXISTS tg_notifications_updated_at ON notifications;
CREATE TRIGGER tg_notifications_updated_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- notifications: auto-set read_at ----
DROP TRIGGER IF EXISTS tg_notifications_mark_read ON notifications;
CREATE TRIGGER tg_notifications_mark_read
    BEFORE UPDATE ON notifications
    FOR EACH ROW
    WHEN (NEW.is_read IS DISTINCT FROM OLD.is_read)
    EXECUTE FUNCTION fn_notification_mark_read();

-- ---- notification_preferences: updated_at ----
DROP TRIGGER IF EXISTS tg_notification_preferences_updated_at ON notification_preferences;
CREATE TRIGGER tg_notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- user_preferences: updated_at ----
DROP TRIGGER IF EXISTS tg_user_preferences_updated_at ON user_preferences;
CREATE TRIGGER tg_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---- feature_flags: updated_at ----
DROP TRIGGER IF EXISTS tg_feature_flags_updated_at ON feature_flags;
CREATE TRIGGER tg_feature_flags_updated_at
    BEFORE UPDATE ON feature_flags
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

COMMIT;
