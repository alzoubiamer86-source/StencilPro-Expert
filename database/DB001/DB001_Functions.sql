-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-001: Core System & User Management
-- File: DB001_Functions.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB001_Core_System.sql
-- Helper functions used by application layer and RLS policies.
-- =============================================================================

BEGIN;

-- =============================================================================
-- FUNCTION: fn_get_current_engineer_id
-- Returns the UUID of the currently authenticated engineer from the JWT.
-- Used throughout RLS policies.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_current_engineer_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT auth.uid();
$$;

COMMENT ON FUNCTION fn_get_current_engineer_id() IS
    'Returns the Supabase Auth UID of the current user. '
    'Engineers.id = auth.uid() by design. Used in RLS policies.';

-- =============================================================================
-- FUNCTION: fn_get_current_organization_id
-- Returns the organization_id of the currently authenticated engineer.
-- Reads from the JWT claim set during login.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_current_organization_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT COALESCE(
        (auth.jwt() ->> 'organization_id')::UUID,
        (
            SELECT organization_id
            FROM   engineers
            WHERE  id = auth.uid()
        )
    );
$$;

COMMENT ON FUNCTION fn_get_current_organization_id() IS
    'Returns the organization_id of the currently authenticated engineer. '
    'Prefers the JWT claim; falls back to a DB lookup if claim is absent. '
    'Used in all organization-scoped RLS policies.';

-- =============================================================================
-- FUNCTION: fn_current_engineer_has_role
-- Returns TRUE if the current engineer holds the given role code.
-- Handles multi-role engineers and expired assignments.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_current_engineer_has_role(p_role_code TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM   engineer_roles er
        JOIN   roles          r ON r.id = er.role_id
        WHERE  er.engineer_id = auth.uid()
          AND  r.code         = p_role_code
          AND  r.is_active    = TRUE
          AND  (er.expires_at IS NULL OR er.expires_at > NOW())
    );
$$;

COMMENT ON FUNCTION fn_current_engineer_has_role(TEXT) IS
    'Returns TRUE if the authenticated engineer currently holds the specified role code. '
    'Respects role expiry. '
    'Usage: fn_current_engineer_has_role(''admin'')';

-- =============================================================================
-- FUNCTION: fn_current_engineer_has_permission
-- Returns TRUE if the current engineer has the given permission code
-- via any of their active role assignments.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_current_engineer_has_permission(p_permission_code TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM   engineer_roles  er
        JOIN   roles            r  ON r.id = er.role_id
        JOIN   role_permissions rp ON rp.role_id = r.id
        JOIN   permissions      p  ON p.id = rp.permission_id
        WHERE  er.engineer_id = auth.uid()
          AND  p.code         = p_permission_code
          AND  r.is_active    = TRUE
          AND  p.is_active    = TRUE
          AND  (er.expires_at IS NULL OR er.expires_at > NOW())
    );
$$;

COMMENT ON FUNCTION fn_current_engineer_has_permission(TEXT) IS
    'Returns TRUE if the authenticated engineer has the specified permission code '
    'through any of their active, non-expired role assignments. '
    'Usage: fn_current_engineer_has_permission(''stencil.approve'')';

-- =============================================================================
-- FUNCTION: fn_is_super_admin
-- Returns TRUE if current engineer has the super_admin role.
-- Super admins bypass organization_id filtering.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT fn_current_engineer_has_role('super_admin');
$$;

COMMENT ON FUNCTION fn_is_super_admin() IS
    'Returns TRUE if the current engineer is a Super Admin. '
    'Super Admins have cross-organization access and bypass org-scoped RLS.';

-- =============================================================================
-- FUNCTION: fn_engineer_org_matches
-- Returns TRUE if the given organization_id matches the current engineer's org.
-- Super admins always return TRUE (cross-org access).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_engineer_org_matches(p_organization_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        fn_is_super_admin()
        OR
        p_organization_id = fn_get_current_organization_id();
$$;

COMMENT ON FUNCTION fn_engineer_org_matches(UUID) IS
    'Returns TRUE if p_organization_id matches the current engineer''s organization, '
    'OR if the current engineer is a Super Admin. '
    'Core function used by all organization-scoped RLS policies.';

-- =============================================================================
-- FUNCTION: fn_is_org_admin
-- Returns TRUE if current engineer is admin or super_admin.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_is_org_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT fn_current_engineer_has_role('admin')
        OR fn_current_engineer_has_role('super_admin');
$$;

COMMENT ON FUNCTION fn_is_org_admin() IS
    'Returns TRUE if the current engineer holds the admin or super_admin role.';

-- =============================================================================
-- FUNCTION: fn_is_senior_or_above
-- Returns TRUE if current engineer is senior_engineer, admin, or super_admin.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_is_senior_or_above()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT fn_current_engineer_has_role('senior_engineer')
        OR fn_current_engineer_has_role('admin')
        OR fn_current_engineer_has_role('super_admin');
$$;

COMMENT ON FUNCTION fn_is_senior_or_above() IS
    'Returns TRUE if the current engineer holds senior_engineer, admin, or super_admin role. '
    'Used in RLS policies for approval-gated operations.';

-- =============================================================================
-- FUNCTION: fn_set_created_updated_by
-- BEFORE INSERT trigger function: sets created_by and updated_by
-- from the current Supabase Auth user.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_set_created_updated_by()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_by := auth.uid();
        NEW.updated_by := auth.uid();
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated_by := auth.uid();
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_set_created_updated_by() IS
    'BEFORE INSERT/UPDATE trigger: sets created_by and updated_by '
    'from auth.uid() (Supabase Auth current user).';

-- =============================================================================
-- ATTACH created_by / updated_by triggers to all DB-001 tables
-- =============================================================================

-- organizations
DROP TRIGGER IF EXISTS tg_organizations_created_by ON organizations;
CREATE TRIGGER tg_organizations_created_by
    BEFORE INSERT OR UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- organization_settings
DROP TRIGGER IF EXISTS tg_org_settings_created_by ON organization_settings;
CREATE TRIGGER tg_org_settings_created_by
    BEFORE INSERT OR UPDATE ON organization_settings
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- application_config
DROP TRIGGER IF EXISTS tg_application_config_created_by ON application_config;
CREATE TRIGGER tg_application_config_created_by
    BEFORE INSERT OR UPDATE ON application_config
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- engineers
DROP TRIGGER IF EXISTS tg_engineers_created_by ON engineers;
CREATE TRIGGER tg_engineers_created_by
    BEFORE INSERT OR UPDATE ON engineers
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- roles
DROP TRIGGER IF EXISTS tg_roles_created_by ON roles;
CREATE TRIGGER tg_roles_created_by
    BEFORE INSERT OR UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- permissions
DROP TRIGGER IF EXISTS tg_permissions_created_by ON permissions;
CREATE TRIGGER tg_permissions_created_by
    BEFORE INSERT OR UPDATE ON permissions
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- engineer_roles
DROP TRIGGER IF EXISTS tg_engineer_roles_created_by ON engineer_roles;
CREATE TRIGGER tg_engineer_roles_created_by
    BEFORE INSERT OR UPDATE ON engineer_roles
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- role_permissions
DROP TRIGGER IF EXISTS tg_role_permissions_created_by ON role_permissions;
CREATE TRIGGER tg_role_permissions_created_by
    BEFORE INSERT OR UPDATE ON role_permissions
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- engineer_sessions
DROP TRIGGER IF EXISTS tg_engineer_sessions_created_by ON engineer_sessions;
CREATE TRIGGER tg_engineer_sessions_created_by
    BEFORE INSERT OR UPDATE ON engineer_sessions
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- notifications
DROP TRIGGER IF EXISTS tg_notifications_created_by ON notifications;
CREATE TRIGGER tg_notifications_created_by
    BEFORE INSERT OR UPDATE ON notifications
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- notification_preferences
DROP TRIGGER IF EXISTS tg_notification_preferences_created_by ON notification_preferences;
CREATE TRIGGER tg_notification_preferences_created_by
    BEFORE INSERT OR UPDATE ON notification_preferences
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- user_preferences
DROP TRIGGER IF EXISTS tg_user_preferences_created_by ON user_preferences;
CREATE TRIGGER tg_user_preferences_created_by
    BEFORE INSERT OR UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- feature_flags
DROP TRIGGER IF EXISTS tg_feature_flags_created_by ON feature_flags;
CREATE TRIGGER tg_feature_flags_created_by
    BEFORE INSERT OR UPDATE ON feature_flags
    FOR EACH ROW EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- FUNCTION: fn_log_activity
-- Application-callable function to write an activity_log entry.
-- Called from the application layer (not a trigger).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_log_activity(
    p_organization_id   UUID,
    p_engineer_id       UUID,
    p_activity_type     VARCHAR(100),
    p_entity_type       VARCHAR(50)     DEFAULT NULL,
    p_entity_id         UUID            DEFAULT NULL,
    p_metadata          JSONB           DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO activity_log (
        organization_id,
        engineer_id,
        activity_type,
        entity_type,
        entity_id,
        metadata,
        occurred_at
    ) VALUES (
        p_organization_id,
        p_engineer_id,
        p_activity_type,
        p_entity_type,
        p_entity_id,
        p_metadata,
        NOW()
    );
END;
$$;

COMMENT ON FUNCTION fn_log_activity(UUID, UUID, VARCHAR, VARCHAR, UUID, JSONB) IS
    'Application-callable function to write activity_log entries. '
    'Called by the Python application layer after significant user actions. '
    'Parameters: organization_id, engineer_id, activity_type, '
    'optional entity_type, entity_id, metadata.';

-- =============================================================================
-- FUNCTION: fn_create_notification
-- Application-callable function to create a notification record.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_create_notification(
    p_organization_id           UUID,
    p_recipient_engineer_id     UUID,
    p_notification_type         VARCHAR(50),
    p_title                     VARCHAR(255),
    p_content                   TEXT,
    p_entity_type               VARCHAR(50)  DEFAULT NULL,
    p_entity_id                 UUID         DEFAULT NULL,
    p_expires_at                TIMESTAMPTZ  DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_notification_id UUID;
BEGIN
    v_notification_id := gen_random_uuid();

    INSERT INTO notifications (
        id,
        organization_id,
        recipient_engineer_id,
        notification_type,
        title,
        content,
        entity_type,
        entity_id,
        is_read,
        expires_at,
        created_at,
        updated_at
    ) VALUES (
        v_notification_id,
        p_organization_id,
        p_recipient_engineer_id,
        p_notification_type,
        p_title,
        p_content,
        p_entity_type,
        p_entity_id,
        FALSE,
        p_expires_at,
        NOW(),
        NOW()
    );

    RETURN v_notification_id;
END;
$$;

COMMENT ON FUNCTION fn_create_notification(UUID, UUID, VARCHAR, VARCHAR, TEXT, VARCHAR, UUID, TIMESTAMPTZ) IS
    'Application-callable function to create a notification for an engineer. '
    'Returns the UUID of the created notification.';

-- =============================================================================
-- FUNCTION: fn_get_engineer_role_codes
-- Returns an array of role codes held by the given engineer.
-- Used in application layer permission checks.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_engineer_role_codes(p_engineer_id UUID)
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT COALESCE(
        ARRAY_AGG(r.code ORDER BY r.code),
        ARRAY[]::TEXT[]
    )
    FROM   engineer_roles er
    JOIN   roles          r ON r.id = er.role_id
    WHERE  er.engineer_id = p_engineer_id
      AND  r.is_active    = TRUE
      AND  (er.expires_at IS NULL OR er.expires_at > NOW());
$$;

COMMENT ON FUNCTION fn_get_engineer_role_codes(UUID) IS
    'Returns an array of role codes currently held by the given engineer. '
    'Excludes expired assignments. Used by application layer at login to build JWT claims.';

-- =============================================================================
-- FUNCTION: fn_get_engineer_permission_codes
-- Returns an array of all permission codes held by the given engineer
-- through any of their active roles.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_engineer_permission_codes(p_engineer_id UUID)
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT COALESCE(
        ARRAY_AGG(DISTINCT p.code ORDER BY p.code),
        ARRAY[]::TEXT[]
    )
    FROM   engineer_roles  er
    JOIN   roles            r  ON r.id = er.role_id
    JOIN   role_permissions rp ON rp.role_id = r.id
    JOIN   permissions      p  ON p.id = rp.permission_id
    WHERE  er.engineer_id = p_engineer_id
      AND  r.is_active    = TRUE
      AND  p.is_active    = TRUE
      AND  (er.expires_at IS NULL OR er.expires_at > NOW());
$$;

COMMENT ON FUNCTION fn_get_engineer_permission_codes(UUID) IS
    'Returns all permission codes granted to the given engineer through their active roles. '
    'Used by the application layer to build the engineer''s permission set at login.';

-- =============================================================================
-- FUNCTION: fn_soft_delete_organization
-- Safely soft-deletes an organization and records audit entry.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_soft_delete_organization(
    p_organization_id   UUID,
    p_deleted_by        UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Must be super_admin to soft-delete an organization
    IF NOT fn_is_super_admin() THEN
        RAISE EXCEPTION 'Only Super Admins may soft-delete organizations.'
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    UPDATE organizations
    SET    is_deleted  = TRUE,
           deleted_at  = NOW(),
           is_active   = FALSE,
           updated_at  = NOW(),
           updated_by  = p_deleted_by
    WHERE  id          = p_organization_id
      AND  is_deleted  = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Organization % not found or already deleted.', p_organization_id
            USING ERRCODE = 'no_data_found';
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_soft_delete_organization(UUID, UUID) IS
    'Soft-deletes an organization. Requires Super Admin role. '
    'Sets is_deleted = TRUE, deleted_at = NOW(), is_active = FALSE.';

-- =============================================================================
-- FUNCTION: fn_soft_delete_engineer
-- Safely soft-deletes (deactivates) an engineer.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_soft_delete_engineer(
    p_engineer_id   UUID,
    p_deleted_by    UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_org_id        UUID;
    v_admin_count   INTEGER;
BEGIN
    SELECT organization_id INTO v_org_id
    FROM   engineers
    WHERE  id = p_engineer_id AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Engineer % not found or already deleted.', p_engineer_id
            USING ERRCODE = 'no_data_found';
    END IF;

    -- Check: are we removing the last admin?
    SELECT COUNT(*) INTO v_admin_count
    FROM   engineer_roles er
    JOIN   roles          r ON r.id = er.role_id
    JOIN   engineers      e ON e.id = er.engineer_id
    WHERE  r.code            = 'admin'
      AND  e.organization_id = v_org_id
      AND  e.is_active       = TRUE
      AND  e.is_deleted      = FALSE
      AND  e.id             != p_engineer_id
      AND  (er.expires_at IS NULL OR er.expires_at > NOW());

    IF v_admin_count = 0 THEN
        -- Check if the engineer being deleted is the last admin
        IF fn_current_engineer_has_role('admin') OR
           (SELECT COUNT(*) FROM engineer_roles er JOIN roles r ON r.id = er.role_id
            WHERE er.engineer_id = p_engineer_id AND r.code = 'admin') > 0
        THEN
            RAISE EXCEPTION
                'Cannot deactivate the last administrator. '
                'Promote another engineer to Admin first.'
                USING ERRCODE = 'restrict_violation';
        END IF;
    END IF;

    UPDATE engineers
    SET    is_deleted  = TRUE,
           is_active   = FALSE,
           deleted_at  = NOW(),
           updated_at  = NOW(),
           updated_by  = p_deleted_by
    WHERE  id          = p_engineer_id;

    -- Terminate all active sessions
    UPDATE engineer_sessions
    SET    ended_at     = NOW(),
           ended_reason = 'forced',
           updated_at   = NOW()
    WHERE  engineer_id  = p_engineer_id
      AND  ended_at IS NULL;
END;
$$;

COMMENT ON FUNCTION fn_soft_delete_engineer(UUID, UUID) IS
    'Soft-deletes an engineer and terminates all active sessions. '
    'Prevents deletion of the last admin in an organization.';

COMMIT;
