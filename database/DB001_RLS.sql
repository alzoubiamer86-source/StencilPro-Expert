-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-001: Core System & User Management
-- File: DB001_RLS.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB001_Core_System.sql, DB001_Indexes.sql, DB001_Functions.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE organizations                ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_settings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE application_config           ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineers                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles                        ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_roles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions             ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_sessions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications                ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences             ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags                ENABLE ROW LEVEL SECURITY;

-- Note: schema_migrations has no RLS (system table, service role only)
-- Note: audit_log is append-only; UPDATE/DELETE blocked by triggers also

-- =============================================================================
-- FORCE RLS even for table owners (critical for multi-tenancy security)
-- =============================================================================

ALTER TABLE organizations               FORCE ROW LEVEL SECURITY;
ALTER TABLE organization_settings       FORCE ROW LEVEL SECURITY;
ALTER TABLE engineers                   FORCE ROW LEVEL SECURITY;
ALTER TABLE roles                       FORCE ROW LEVEL SECURITY;
ALTER TABLE engineer_roles              FORCE ROW LEVEL SECURITY;
ALTER TABLE engineer_sessions           FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_log                   FORCE ROW LEVEL SECURITY;
ALTER TABLE activity_log                FORCE ROW LEVEL SECURITY;
ALTER TABLE notifications               FORCE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences    FORCE ROW LEVEL SECURITY;
ALTER TABLE user_preferences            FORCE ROW LEVEL SECURITY;

-- =============================================================================
-- organizations
-- =============================================================================

-- SELECT: engineers see only their own organization; super_admin sees all
CREATE POLICY pol_organizations_select
    ON organizations
    FOR SELECT
    TO authenticated
    USING (
        fn_is_super_admin()
        OR id = fn_get_current_organization_id()
    );

-- INSERT: super_admin only (organizations created via admin tooling)
CREATE POLICY pol_organizations_insert
    ON organizations
    FOR INSERT
    TO authenticated
    WITH CHECK (fn_is_super_admin());

-- UPDATE: org admins can update their own org; super_admin can update any
CREATE POLICY pol_organizations_update
    ON organizations
    FOR UPDATE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (id = fn_get_current_organization_id() AND fn_is_org_admin())
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (id = fn_get_current_organization_id() AND fn_is_org_admin())
    );

-- DELETE: blocked for all (soft delete only; hard delete prevented by trigger)
CREATE POLICY pol_organizations_delete
    ON organizations
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- organization_settings
-- =============================================================================

CREATE POLICY pol_org_settings_select
    ON organization_settings
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_org_settings_insert
    ON organization_settings
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_org_settings_update
    ON organization_settings
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_org_settings_delete
    ON organization_settings
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- application_config
-- =============================================================================

-- SELECT: all authenticated users can read application config
CREATE POLICY pol_application_config_select
    ON application_config
    FOR SELECT
    TO authenticated
    USING (TRUE);

-- INSERT/UPDATE/DELETE: super_admin only
CREATE POLICY pol_application_config_insert
    ON application_config
    FOR INSERT
    TO authenticated
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_application_config_update
    ON application_config
    FOR UPDATE
    TO authenticated
    USING (fn_is_super_admin())
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_application_config_delete
    ON application_config
    FOR DELETE
    TO authenticated
    USING (fn_is_super_admin());

-- =============================================================================
-- engineers
-- =============================================================================

-- SELECT: engineers can see all active engineers in their org (for dropdowns, etc.)
-- Super admin can see all.
CREATE POLICY pol_engineers_select
    ON engineers
    FOR SELECT
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND is_deleted = FALSE
        )
    );

-- INSERT: admin creates engineers in their own org; super_admin creates anywhere
CREATE POLICY pol_engineers_insert
    ON engineers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_org_admin()
        )
    );

-- UPDATE: engineers update own profile; admins update any in their org
CREATE POLICY pol_engineers_update
    ON engineers
    FOR UPDATE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND (
                id = fn_get_current_engineer_id()  -- own profile
                OR fn_is_org_admin()               -- admin managing others
            )
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND (
                id = fn_get_current_engineer_id()
                OR fn_is_org_admin()
            )
        )
    );

-- DELETE: blocked (soft delete only; hard delete prevented by trigger)
CREATE POLICY pol_engineers_delete
    ON engineers
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- roles
-- =============================================================================

-- SELECT: all authenticated users can see system roles + their org's custom roles
CREATE POLICY pol_roles_select
    ON roles
    FOR SELECT
    TO authenticated
    USING (
        organization_id IS NULL                            -- system roles
        OR fn_engineer_org_matches(organization_id)        -- org-custom roles
    );

-- INSERT: admin can create custom roles for their org; super_admin creates system roles
CREATE POLICY pol_roles_insert
    ON roles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_org_admin()
            AND is_system_role = FALSE
        )
    );

-- UPDATE: super_admin updates system roles; admin updates own org custom roles only
CREATE POLICY pol_roles_update
    ON roles
    FOR UPDATE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_org_admin()
            AND is_system_role = FALSE
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            organization_id = fn_get_current_organization_id()
            AND fn_is_org_admin()
            AND is_system_role = FALSE
        )
    );

-- DELETE: cannot delete system roles; admin can delete org custom roles
CREATE POLICY pol_roles_delete
    ON roles
    FOR DELETE
    TO authenticated
    USING (
        is_system_role = FALSE
        AND (
            fn_is_super_admin()
            OR (
                organization_id = fn_get_current_organization_id()
                AND fn_is_org_admin()
            )
        )
    );

-- =============================================================================
-- permissions
-- =============================================================================

-- SELECT: all authenticated engineers can read all permissions
CREATE POLICY pol_permissions_select
    ON permissions
    FOR SELECT
    TO authenticated
    USING (TRUE);

-- INSERT/UPDATE/DELETE: super_admin only (permissions are system-defined)
CREATE POLICY pol_permissions_insert
    ON permissions
    FOR INSERT
    TO authenticated
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_permissions_update
    ON permissions
    FOR UPDATE
    TO authenticated
    USING (fn_is_super_admin())
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_permissions_delete
    ON permissions
    FOR DELETE
    TO authenticated
    USING (fn_is_super_admin());

-- =============================================================================
-- engineer_roles
-- =============================================================================

-- SELECT: engineers see their own assignments; admins see all in their org
CREATE POLICY pol_engineer_roles_select
    ON engineer_roles
    FOR SELECT
    TO authenticated
    USING (
        fn_is_super_admin()
        OR engineer_id = fn_get_current_engineer_id()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM engineers e
                WHERE e.id = engineer_roles.engineer_id
                  AND e.organization_id = fn_get_current_organization_id()
            )
        )
    );

-- INSERT: admin assigns roles to engineers in their org
CREATE POLICY pol_engineer_roles_insert
    ON engineer_roles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM engineers e
                WHERE e.id = engineer_roles.engineer_id
                  AND e.organization_id = fn_get_current_organization_id()
            )
        )
    );

-- UPDATE: admin updates role assignments in their org
CREATE POLICY pol_engineer_roles_update
    ON engineer_roles
    FOR UPDATE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM engineers e
                WHERE e.id = engineer_roles.engineer_id
                  AND e.organization_id = fn_get_current_organization_id()
            )
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM engineers e
                WHERE e.id = engineer_roles.engineer_id
                  AND e.organization_id = fn_get_current_organization_id()
            )
        )
    );

-- DELETE: admin removes role assignments (trigger enforces last-admin rule)
CREATE POLICY pol_engineer_roles_delete
    ON engineer_roles
    FOR DELETE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM engineers e
                WHERE e.id = engineer_roles.engineer_id
                  AND e.organization_id = fn_get_current_organization_id()
            )
        )
    );

-- =============================================================================
-- role_permissions
-- =============================================================================

-- SELECT: all authenticated users can see role-permission mappings
CREATE POLICY pol_role_permissions_select
    ON role_permissions
    FOR SELECT
    TO authenticated
    USING (TRUE);

-- INSERT/UPDATE/DELETE: super_admin only (for system roles); admin for custom roles
CREATE POLICY pol_role_permissions_insert
    ON role_permissions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM roles r
                WHERE r.id = role_permissions.role_id
                  AND r.is_system_role = FALSE
                  AND r.organization_id = fn_get_current_organization_id()
            )
        )
    );

CREATE POLICY pol_role_permissions_update
    ON role_permissions
    FOR UPDATE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM roles r
                WHERE r.id = role_permissions.role_id
                  AND r.is_system_role = FALSE
                  AND r.organization_id = fn_get_current_organization_id()
            )
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM roles r
                WHERE r.id = role_permissions.role_id
                  AND r.is_system_role = FALSE
                  AND r.organization_id = fn_get_current_organization_id()
            )
        )
    );

CREATE POLICY pol_role_permissions_delete
    ON role_permissions
    FOR DELETE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM roles r
                WHERE r.id = role_permissions.role_id
                  AND r.is_system_role = FALSE
                  AND r.organization_id = fn_get_current_organization_id()
            )
        )
    );

-- =============================================================================
-- engineer_sessions
-- =============================================================================

-- SELECT: engineers see only their own sessions; admins see all in their org
CREATE POLICY pol_engineer_sessions_select
    ON engineer_sessions
    FOR SELECT
    TO authenticated
    USING (
        fn_is_super_admin()
        OR engineer_id = fn_get_current_engineer_id()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM engineers e
                WHERE e.id = engineer_sessions.engineer_id
                  AND e.organization_id = fn_get_current_organization_id()
            )
        )
    );

-- INSERT: engineers create their own sessions; system also inserts via auth flow
CREATE POLICY pol_engineer_sessions_insert
    ON engineer_sessions
    FOR INSERT
    TO authenticated
    WITH CHECK (engineer_id = fn_get_current_engineer_id());

-- UPDATE: engineers update only their own sessions (last_active_at, ended_at)
CREATE POLICY pol_engineer_sessions_update
    ON engineer_sessions
    FOR UPDATE
    TO authenticated
    USING (
        engineer_id = fn_get_current_engineer_id()
        OR fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM engineers e
                WHERE e.id = engineer_sessions.engineer_id
                  AND e.organization_id = fn_get_current_organization_id()
            )
        )
    )
    WITH CHECK (
        engineer_id = fn_get_current_engineer_id()
        OR fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND EXISTS (
                SELECT 1 FROM engineers e
                WHERE e.id = engineer_sessions.engineer_id
                  AND e.organization_id = fn_get_current_organization_id()
            )
        )
    );

-- DELETE: engineers may delete (logout) their own sessions only
CREATE POLICY pol_engineer_sessions_delete
    ON engineer_sessions
    FOR DELETE
    TO authenticated
    USING (
        engineer_id = fn_get_current_engineer_id()
        OR fn_is_super_admin()
    );

-- =============================================================================
-- audit_log
-- =============================================================================

-- SELECT: admin sees their org's audit log; super_admin sees all
CREATE POLICY pol_audit_log_select
    ON audit_log
    FOR SELECT
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND (
                organization_id = fn_get_current_organization_id()
                OR organization_id IS NULL  -- system events
            )
        )
    );

-- INSERT: only via trigger function (SECURITY DEFINER); no direct insert
-- We allow INSERT for service role only to support the trigger approach.
-- Regular authenticated users cannot INSERT directly.
CREATE POLICY pol_audit_log_insert
    ON audit_log
    FOR INSERT
    TO authenticated
    WITH CHECK (FALSE);  -- Triggers use SECURITY DEFINER; direct inserts blocked

-- UPDATE: blocked for all (append-only; also blocked by trigger)
CREATE POLICY pol_audit_log_update
    ON audit_log
    FOR UPDATE
    TO authenticated
    USING (FALSE);

-- DELETE: blocked for all (7-year retention requirement)
CREATE POLICY pol_audit_log_delete
    ON audit_log
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- activity_log
-- =============================================================================

-- SELECT: engineers see their own org's activity; super_admin sees all
CREATE POLICY pol_activity_log_select
    ON activity_log
    FOR SELECT
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
        )
    );

-- INSERT: engineers log their own org's activity via fn_log_activity()
CREATE POLICY pol_activity_log_insert
    ON activity_log
    FOR INSERT
    TO authenticated
    WITH CHECK (FALSE);  -- Only via fn_log_activity() SECURITY DEFINER function

-- UPDATE/DELETE: blocked (append-only)
CREATE POLICY pol_activity_log_update
    ON activity_log
    FOR UPDATE
    TO authenticated
    USING (FALSE);

CREATE POLICY pol_activity_log_delete
    ON activity_log
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- notifications
-- =============================================================================

-- SELECT: engineers see their own notifications
CREATE POLICY pol_notifications_select
    ON notifications
    FOR SELECT
    TO authenticated
    USING (
        fn_is_super_admin()
        OR recipient_engineer_id = fn_get_current_engineer_id()
    );

-- INSERT: application creates notifications via fn_create_notification(); direct blocked
CREATE POLICY pol_notifications_insert
    ON notifications
    FOR INSERT
    TO authenticated
    WITH CHECK (FALSE);  -- Only via fn_create_notification() SECURITY DEFINER function

-- UPDATE: engineers can mark their own notifications as read
CREATE POLICY pol_notifications_update
    ON notifications
    FOR UPDATE
    TO authenticated
    USING (
        recipient_engineer_id = fn_get_current_engineer_id()
        OR fn_is_super_admin()
    )
    WITH CHECK (
        recipient_engineer_id = fn_get_current_engineer_id()
        OR fn_is_super_admin()
    );

-- DELETE: engineers can delete their own expired/read notifications
CREATE POLICY pol_notifications_delete
    ON notifications
    FOR DELETE
    TO authenticated
    USING (
        recipient_engineer_id = fn_get_current_engineer_id()
        OR fn_is_super_admin()
    );

-- =============================================================================
-- notification_preferences
-- =============================================================================

-- SELECT: engineers see only their own preferences
CREATE POLICY pol_notification_preferences_select
    ON notification_preferences
    FOR SELECT
    TO authenticated
    USING (
        engineer_id = fn_get_current_engineer_id()
        OR fn_is_super_admin()
    );

-- INSERT: engineers create their own preferences
CREATE POLICY pol_notification_preferences_insert
    ON notification_preferences
    FOR INSERT
    TO authenticated
    WITH CHECK (engineer_id = fn_get_current_engineer_id());

-- UPDATE: engineers update their own preferences
CREATE POLICY pol_notification_preferences_update
    ON notification_preferences
    FOR UPDATE
    TO authenticated
    USING (engineer_id = fn_get_current_engineer_id())
    WITH CHECK (engineer_id = fn_get_current_engineer_id());

-- DELETE: engineers delete their own preferences
CREATE POLICY pol_notification_preferences_delete
    ON notification_preferences
    FOR DELETE
    TO authenticated
    USING (engineer_id = fn_get_current_engineer_id());

-- =============================================================================
-- user_preferences
-- =============================================================================

-- SELECT: engineers see only their own preferences
CREATE POLICY pol_user_preferences_select
    ON user_preferences
    FOR SELECT
    TO authenticated
    USING (
        engineer_id = fn_get_current_engineer_id()
        OR fn_is_super_admin()
    );

-- INSERT: engineers create their own preferences
CREATE POLICY pol_user_preferences_insert
    ON user_preferences
    FOR INSERT
    TO authenticated
    WITH CHECK (engineer_id = fn_get_current_engineer_id());

-- UPDATE: engineers update their own preferences
CREATE POLICY pol_user_preferences_update
    ON user_preferences
    FOR UPDATE
    TO authenticated
    USING (engineer_id = fn_get_current_engineer_id())
    WITH CHECK (engineer_id = fn_get_current_engineer_id());

-- DELETE: engineers delete their own preferences
CREATE POLICY pol_user_preferences_delete
    ON user_preferences
    FOR DELETE
    TO authenticated
    USING (engineer_id = fn_get_current_engineer_id());

-- =============================================================================
-- feature_flags
-- =============================================================================

-- SELECT: all authenticated users can read feature flags
CREATE POLICY pol_feature_flags_select
    ON feature_flags
    FOR SELECT
    TO authenticated
    USING (TRUE);

-- INSERT/UPDATE/DELETE: super_admin only
CREATE POLICY pol_feature_flags_insert
    ON feature_flags
    FOR INSERT
    TO authenticated
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_feature_flags_update
    ON feature_flags
    FOR UPDATE
    TO authenticated
    USING (fn_is_super_admin())
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_feature_flags_delete
    ON feature_flags
    FOR DELETE
    TO authenticated
    USING (fn_is_super_admin());

COMMIT;
