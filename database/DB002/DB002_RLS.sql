-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-002: Projects & Customers
-- File: DB002_RLS.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB002_Projects.sql, DB002_Functions.sql,
--          DB002_Indexes.sql, DB002_Triggers.sql
-- Prerequisites: DB001_RLS.sql (RLS helper functions must exist)
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE customers                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_contacts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE products                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members             ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_revisions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_notes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_attachments         ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_tags                ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_tag_assignments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_activity            ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_templates           ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- FORCE RLS (applies even to table owners)
-- =============================================================================

ALTER TABLE customers                   FORCE ROW LEVEL SECURITY;
ALTER TABLE customer_contacts           FORCE ROW LEVEL SECURITY;
ALTER TABLE products                    FORCE ROW LEVEL SECURITY;
ALTER TABLE projects                    FORCE ROW LEVEL SECURITY;
ALTER TABLE project_members             FORCE ROW LEVEL SECURITY;
ALTER TABLE project_revisions           FORCE ROW LEVEL SECURITY;
ALTER TABLE project_notes               FORCE ROW LEVEL SECURITY;
ALTER TABLE project_attachments         FORCE ROW LEVEL SECURITY;
ALTER TABLE project_tags                FORCE ROW LEVEL SECURITY;
ALTER TABLE project_tag_assignments     FORCE ROW LEVEL SECURITY;
ALTER TABLE project_activity            FORCE ROW LEVEL SECURITY;
ALTER TABLE project_templates           FORCE ROW LEVEL SECURITY;

-- =============================================================================
-- HELPER: fn_engineer_on_project
-- Returns TRUE if the current engineer is the lead or an active member
-- of the given project. Used to restrict project-level data access.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_engineer_on_project(p_project_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        -- Is lead engineer
        SELECT 1 FROM projects p
        WHERE  p.id              = p_project_id
          AND  p.lead_engineer_id = fn_get_current_engineer_id()
          AND  p.is_deleted      = FALSE
        UNION ALL
        -- Is active project member
        SELECT 1 FROM project_members pm
        WHERE  pm.project_id   = p_project_id
          AND  pm.engineer_id  = fn_get_current_engineer_id()
          AND  pm.removed_at   IS NULL
    );
$$;

COMMENT ON FUNCTION fn_engineer_on_project(UUID) IS
    'Returns TRUE if the current engineer is the project lead or an active project member. '
    'Used by RLS policies for project-scoped data tables.';

-- =============================================================================
-- customers
-- =============================================================================

CREATE POLICY pol_customers_select
    ON customers
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_customers_insert
    ON customers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_customers_update
    ON customers
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

-- Hard delete blocked; soft delete via UPDATE handled above
CREATE POLICY pol_customers_delete
    ON customers
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- customer_contacts
-- =============================================================================

CREATE POLICY pol_customer_contacts_select
    ON customer_contacts
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_customer_contacts_insert
    ON customer_contacts
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_customer_contacts_update
    ON customer_contacts
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

CREATE POLICY pol_customer_contacts_delete
    ON customer_contacts
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- products
-- =============================================================================

CREATE POLICY pol_products_select
    ON products
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_products_insert
    ON products
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

CREATE POLICY pol_products_update
    ON products
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

CREATE POLICY pol_products_delete
    ON products
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- projects
-- Policy hierarchy:
--   SELECT: all engineers in org (for project list, cross-project search)
--   INSERT: engineer or above
--   UPDATE: project lead, project members with contributor role, admin
--   DELETE: blocked (soft delete only)
-- =============================================================================

CREATE POLICY pol_projects_select
    ON projects
    FOR SELECT
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
    );

CREATE POLICY pol_projects_insert
    ON projects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.create')
    );

CREATE POLICY pol_projects_update
    ON projects
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
        AND (
            fn_is_org_admin()
            OR lead_engineer_id = fn_get_current_engineer_id()
            OR fn_engineer_on_project(id)
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR lead_engineer_id = fn_get_current_engineer_id()
            OR fn_engineer_on_project(id)
        )
    );

CREATE POLICY pol_projects_delete
    ON projects
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- project_members
-- =============================================================================

CREATE POLICY pol_project_members_select
    ON project_members
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_project_members_insert
    ON project_members
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR EXISTS (
                SELECT 1 FROM projects p
                WHERE p.id = project_members.project_id
                  AND p.lead_engineer_id = fn_get_current_engineer_id()
                  AND p.is_deleted = FALSE
            )
        )
    );

CREATE POLICY pol_project_members_update
    ON project_members
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR EXISTS (
                SELECT 1 FROM projects p
                WHERE p.id = project_members.project_id
                  AND p.lead_engineer_id = fn_get_current_engineer_id()
                  AND p.is_deleted = FALSE
            )
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR EXISTS (
                SELECT 1 FROM projects p
                WHERE p.id = project_members.project_id
                  AND p.lead_engineer_id = fn_get_current_engineer_id()
                  AND p.is_deleted = FALSE
            )
        )
    );

CREATE POLICY pol_project_members_delete
    ON project_members
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- project_revisions
-- =============================================================================

CREATE POLICY pol_project_revisions_select
    ON project_revisions
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_project_revisions_insert
    ON project_revisions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

-- Only allow update of non-approved revisions (trigger enforces immutability)
CREATE POLICY pol_project_revisions_update
    ON project_revisions
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR fn_engineer_on_project(project_id)
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR fn_engineer_on_project(project_id)
        )
    );

CREATE POLICY pol_project_revisions_delete
    ON project_revisions
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- project_notes  (APPEND-ONLY: SELECT and INSERT only)
-- =============================================================================

CREATE POLICY pol_project_notes_select
    ON project_notes
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

-- INSERT: any engineer who can see the project
CREATE POLICY pol_project_notes_insert
    ON project_notes
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.view')
    );

-- UPDATE: blocked by RLS (also blocked by trigger)
CREATE POLICY pol_project_notes_update
    ON project_notes
    FOR UPDATE
    TO authenticated
    USING (FALSE);

-- DELETE: blocked by RLS (also blocked by trigger)
CREATE POLICY pol_project_notes_delete
    ON project_notes
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- project_attachments
-- =============================================================================

CREATE POLICY pol_project_attachments_select
    ON project_attachments
    FOR SELECT
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
    );

CREATE POLICY pol_project_attachments_insert
    ON project_attachments
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

CREATE POLICY pol_project_attachments_update
    ON project_attachments
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
        AND (
            fn_is_org_admin()
            OR uploaded_by_engineer_id = fn_get_current_engineer_id()
            OR fn_engineer_on_project(project_id)
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR uploaded_by_engineer_id = fn_get_current_engineer_id()
            OR fn_engineer_on_project(project_id)
        )
    );

-- Hard delete blocked; soft delete via UPDATE
CREATE POLICY pol_project_attachments_delete
    ON project_attachments
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- project_tags
-- =============================================================================

CREATE POLICY pol_project_tags_select
    ON project_tags
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_project_tags_insert
    ON project_tags
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

CREATE POLICY pol_project_tags_update
    ON project_tags
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

CREATE POLICY pol_project_tags_delete
    ON project_tags
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- project_tag_assignments
-- =============================================================================

CREATE POLICY pol_project_tag_assignments_select
    ON project_tag_assignments
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_project_tag_assignments_insert
    ON project_tag_assignments
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR fn_engineer_on_project(project_id)
        )
    );

CREATE POLICY pol_project_tag_assignments_update
    ON project_tag_assignments
    FOR UPDATE
    TO authenticated
    USING (fn_engineer_org_matches(organization_id))
    WITH CHECK (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_project_tag_assignments_delete
    ON project_tag_assignments
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR fn_engineer_on_project(project_id)
        )
    );

-- =============================================================================
-- project_activity  (APPEND-ONLY: SELECT only for authenticated)
-- =============================================================================

CREATE POLICY pol_project_activity_select
    ON project_activity
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

-- INSERT only via fn_create_project_activity() SECURITY DEFINER function
CREATE POLICY pol_project_activity_insert
    ON project_activity
    FOR INSERT
    TO authenticated
    WITH CHECK (FALSE);

-- UPDATE and DELETE: blocked (append-only; also enforced by trigger)
CREATE POLICY pol_project_activity_update
    ON project_activity
    FOR UPDATE
    TO authenticated
    USING (FALSE);

CREATE POLICY pol_project_activity_delete
    ON project_activity
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- project_templates
-- =============================================================================

-- SELECT: all authenticated engineers see system templates + their org's custom templates
CREATE POLICY pol_project_templates_select
    ON project_templates
    FOR SELECT
    TO authenticated
    USING (
        organization_id IS NULL                         -- system templates
        OR fn_engineer_org_matches(organization_id)     -- org-custom templates
    );

-- INSERT: admin creates org-specific templates; super_admin creates system templates
CREATE POLICY pol_project_templates_insert
    ON project_templates
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
            AND is_system_template = FALSE
        )
    );

-- UPDATE: admin updates org templates; super_admin updates system templates
CREATE POLICY pol_project_templates_update
    ON project_templates
    FOR UPDATE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
            AND is_system_template = FALSE
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
            AND is_system_template = FALSE
        )
    );

-- DELETE: admin deletes org-custom templates only; system templates cannot be deleted
CREATE POLICY pol_project_templates_delete
    ON project_templates
    FOR DELETE
    TO authenticated
    USING (
        is_system_template = FALSE
        AND (
            fn_is_super_admin()
            OR (
                fn_is_org_admin()
                AND organization_id = fn_get_current_organization_id()
            )
        )
    );

COMMIT;
