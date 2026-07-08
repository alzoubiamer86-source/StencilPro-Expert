-- =============================================================================
-- StencilPro Expert Enterprise
-- DB005: Land Pattern & Aperture Intelligence Engine
-- File: DB005_RLS.sql
-- Purpose: Row-level security for DB005, following the organization-isolation
--          model established in DB001-DB004A.
--
-- Reuses existing shared helper (NOT redefined here):
--   - app.fn_user_organization_id()  [DB001 standard RLS helper: returns the
--                                     calling user's organization_id]
--
-- Lookup tables shared across all tenants (aperture_shape_types,
-- stencil_defect_types, surface_finish_types) are readable by all
-- authenticated users and writable only by service-role, consistent with
-- how global reference data was handled in DB004A.
--
-- Policy design note: Postgres combines multiple PERMISSIVE policies for the
-- same command with OR. To avoid a soft-deleted row becoming visible again
-- through a separately-OR'd policy, tables carrying is_deleted use a single
-- SELECT policy that combines org isolation AND the soft-delete filter, and
-- separate policies for INSERT/UPDATE/DELETE that carry org isolation only.
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- Global reference tables (read-all, service-role write)
-- -----------------------------------------------------------------------------

ALTER TABLE app.aperture_shape_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pol_aperture_shape_types_select ON app.aperture_shape_types;
CREATE POLICY pol_aperture_shape_types_select ON app.aperture_shape_types
    FOR SELECT USING (is_deleted = false);
DROP POLICY IF EXISTS pol_aperture_shape_types_insert ON app.aperture_shape_types;
CREATE POLICY pol_aperture_shape_types_insert ON app.aperture_shape_types
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
DROP POLICY IF EXISTS pol_aperture_shape_types_update ON app.aperture_shape_types;
CREATE POLICY pol_aperture_shape_types_update ON app.aperture_shape_types
    FOR UPDATE USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
DROP POLICY IF EXISTS pol_aperture_shape_types_delete ON app.aperture_shape_types;
CREATE POLICY pol_aperture_shape_types_delete ON app.aperture_shape_types
    FOR DELETE USING (auth.role() = 'service_role');

ALTER TABLE app.stencil_defect_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pol_stencil_defect_types_select ON app.stencil_defect_types;
CREATE POLICY pol_stencil_defect_types_select ON app.stencil_defect_types
    FOR SELECT USING (true);
DROP POLICY IF EXISTS pol_stencil_defect_types_insert ON app.stencil_defect_types;
CREATE POLICY pol_stencil_defect_types_insert ON app.stencil_defect_types
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
DROP POLICY IF EXISTS pol_stencil_defect_types_update ON app.stencil_defect_types;
CREATE POLICY pol_stencil_defect_types_update ON app.stencil_defect_types
    FOR UPDATE USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
DROP POLICY IF EXISTS pol_stencil_defect_types_delete ON app.stencil_defect_types;
CREATE POLICY pol_stencil_defect_types_delete ON app.stencil_defect_types
    FOR DELETE USING (auth.role() = 'service_role');

ALTER TABLE app.surface_finish_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pol_surface_finish_types_select ON app.surface_finish_types;
CREATE POLICY pol_surface_finish_types_select ON app.surface_finish_types
    FOR SELECT USING (true);
DROP POLICY IF EXISTS pol_surface_finish_types_insert ON app.surface_finish_types;
CREATE POLICY pol_surface_finish_types_insert ON app.surface_finish_types
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
DROP POLICY IF EXISTS pol_surface_finish_types_update ON app.surface_finish_types;
CREATE POLICY pol_surface_finish_types_update ON app.surface_finish_types
    FOR UPDATE USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
DROP POLICY IF EXISTS pol_surface_finish_types_delete ON app.surface_finish_types;
CREATE POLICY pol_surface_finish_types_delete ON app.surface_finish_types
    FOR DELETE USING (auth.role() = 'service_role');

-- -----------------------------------------------------------------------------
-- Organization-isolated tables WITHOUT is_deleted column
-- (satellite / link / append-only tables): single FOR ALL policy is safe here
-- since there is no soft-delete filter to be defeated by policy OR-combination.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'land_pattern_pads', 'land_pattern_revisions', 'land_pattern_approvals',
        'pad_surface_finish_compatibility',
        'aperture_polygon_vertices', 'aperture_revisions',
        'engineering_strategy_package_families', 'engineering_strategy_defects',
        'engineering_strategy_references', 'engineering_strategy_revisions',
        'stencil_defect_root_causes', 'stencil_defect_prevention_methods',
        'stencil_defect_recommended_apertures', 'stencil_defect_recommended_strategies',
        'stencil_defect_package_families',
        'pad_engineering_calculations'
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
-- (org isolation AND not-deleted) from write commands (org isolation only,
-- since soft-delete is itself performed as an UPDATE by the application).
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'package_families', 'land_patterns', 'pads', 'apertures', 'engineering_strategies'
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
