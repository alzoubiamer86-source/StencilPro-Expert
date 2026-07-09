-- =============================================================================
-- StencilPro Expert Enterprise
-- DB006: Stencil Generation Engine
-- File: DB006_RLS.sql
-- Purpose: Row-level security for DB006, following the organization-isolation
--          model established in DB001-DB005.
--
-- Reuses existing shared helper (NOT redefined here):
--   - app.fn_user_organization_id()  [DB001]
--
-- Policy design note (established in DB005): tables carrying is_deleted use
-- a single SELECT policy that combines org isolation AND the soft-delete
-- filter, with separate write policies carrying org isolation only, to
-- avoid Postgres OR-combining a permissive FOR ALL policy with a narrower
-- FOR SELECT policy in a way that would defeat the soft-delete filter.
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- Organization-isolated tables WITHOUT is_deleted column: single FOR ALL
-- policy is safe here since there is no soft-delete filter to be defeated.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'stencil_project_revisions', 'stencil_project_approvals',
        'stencil_step_regions', 'stencil_step_region_vertices',
        'generated_aperture_polygon_vertices', 'generated_aperture_revisions',
        'aperture_recommendations', 'aperture_decisions', 'aperture_decision_history',
        'aperture_comparisons', 'aperture_overrides', 'aperture_validations',
        'stencil_fabrication_capabilities'
    ])
    LOOP
        EXECUTE format('ALTER TABLE app.%1$s ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('DROP POLICY IF EXISTS pol_%1$s_org_isolation ON app.%1$s', t);
        EXECUTE format(
            'CREATE POLICY pol_%1$s_org_isolation ON app.%1$s
             FOR ALL
             USING (organization_id = app.fn_user_organization_id())
             WITH CHECK (organization_id = app.fn_user_organization_id())',
            t
        );
    END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- Organization-isolated tables WITH is_deleted column: split SELECT
-- (org isolation AND not-deleted) from write commands (org isolation only).
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'stencil_projects', 'stencil_layers', 'generated_apertures'
    ])
    LOOP
        EXECUTE format('ALTER TABLE app.%1$s ENABLE ROW LEVEL SECURITY', t);

        EXECUTE format('DROP POLICY IF EXISTS pol_%1$s_select ON app.%1$s', t);
        EXECUTE format(
            'CREATE POLICY pol_%1$s_select ON app.%1$s
             FOR SELECT
             USING (organization_id = app.fn_user_organization_id() AND is_deleted = false)',
            t
        );

        EXECUTE format('DROP POLICY IF EXISTS pol_%1$s_insert ON app.%1$s', t);
        EXECUTE format(
            'CREATE POLICY pol_%1$s_insert ON app.%1$s
             FOR INSERT
             WITH CHECK (organization_id = app.fn_user_organization_id())',
            t
        );

        EXECUTE format('DROP POLICY IF EXISTS pol_%1$s_update ON app.%1$s', t);
        EXECUTE format(
            'CREATE POLICY pol_%1$s_update ON app.%1$s
             FOR UPDATE
             USING (organization_id = app.fn_user_organization_id())
             WITH CHECK (organization_id = app.fn_user_organization_id())',
            t
        );

        EXECUTE format('DROP POLICY IF EXISTS pol_%1$s_delete ON app.%1$s', t);
        EXECUTE format(
            'CREATE POLICY pol_%1$s_delete ON app.%1$s
             FOR DELETE
             USING (organization_id = app.fn_user_organization_id())',
            t
        );
    END LOOP;
END;
$$;
