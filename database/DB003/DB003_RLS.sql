-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-003: PCB Assemblies & Components
-- File: DB003_RLS.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB003_PCB.sql, DB003_Functions.sql,
--          DB003_Indexes.sql, DB003_Triggers.sql
-- Prerequisites: DB001_RLS.sql, DB002_RLS.sql (helper functions must exist)
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE pcb_surface_finishes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcb_materials            ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcb_thickness_options    ENABLE ROW LEVEL SECURITY;
ALTER TABLE board_manufacturers      ENABLE ROW LEVEL SECURITY;
ALTER TABLE assembly_manufacturers   ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcb_assemblies           ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcb_revisions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcb_layers               ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcb_stackups             ENABLE ROW LEVEL SECURITY;
ALTER TABLE assembly_variants        ENABLE ROW LEVEL SECURITY;
ALTER TABLE design_files             ENABLE ROW LEVEL SECURITY;
ALTER TABLE components               ENABLE ROW LEVEL SECURITY;
ALTER TABLE component_revisions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE electrical_nets          ENABLE ROW LEVEL SECURITY;
ALTER TABLE bom_revisions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE bom_items                ENABLE ROW LEVEL SECURITY;
ALTER TABLE component_placements     ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- FORCE RLS (applies even to table owners)
-- =============================================================================

ALTER TABLE pcb_surface_finishes     FORCE ROW LEVEL SECURITY;
ALTER TABLE pcb_materials            FORCE ROW LEVEL SECURITY;
ALTER TABLE pcb_thickness_options    FORCE ROW LEVEL SECURITY;
ALTER TABLE board_manufacturers      FORCE ROW LEVEL SECURITY;
ALTER TABLE assembly_manufacturers   FORCE ROW LEVEL SECURITY;
ALTER TABLE pcb_assemblies           FORCE ROW LEVEL SECURITY;
ALTER TABLE pcb_revisions            FORCE ROW LEVEL SECURITY;
ALTER TABLE pcb_layers               FORCE ROW LEVEL SECURITY;
ALTER TABLE pcb_stackups             FORCE ROW LEVEL SECURITY;
ALTER TABLE assembly_variants        FORCE ROW LEVEL SECURITY;
ALTER TABLE design_files             FORCE ROW LEVEL SECURITY;
ALTER TABLE components               FORCE ROW LEVEL SECURITY;
ALTER TABLE component_revisions      FORCE ROW LEVEL SECURITY;
ALTER TABLE electrical_nets          FORCE ROW LEVEL SECURITY;
ALTER TABLE bom_revisions            FORCE ROW LEVEL SECURITY;
ALTER TABLE bom_items                FORCE ROW LEVEL SECURITY;
ALTER TABLE component_placements     FORCE ROW LEVEL SECURITY;

-- =============================================================================
-- HELPER: fn_pcb_assembly_in_org
-- Returns TRUE if the given pcb_assembly_id belongs to the current engineer's org.
-- Used by child-table policies that do not carry organization_id directly.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_pcb_assembly_in_org(p_pcb_assembly_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM   pcb_assemblies pa
        WHERE  pa.id              = p_pcb_assembly_id
          AND  fn_engineer_org_matches(pa.organization_id)
          AND  pa.is_deleted      = FALSE
    );
$$;

COMMENT ON FUNCTION fn_pcb_assembly_in_org(UUID) IS
    'Returns TRUE if the given pcb_assembly belongs to the current engineer''s organization '
    'or the current engineer is a Super Admin. '
    'Used by RLS policies on tables that inherit organization scope from pcb_assemblies.';

-- =============================================================================
-- HELPER: fn_pcb_revision_in_org
-- Returns TRUE if the given pcb_revision_id belongs to the current org.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_pcb_revision_in_org(p_pcb_revision_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM   pcb_revisions  pr
        JOIN   pcb_assemblies pa ON pa.id = pr.pcb_assembly_id
        WHERE  pr.id                    = p_pcb_revision_id
          AND  fn_engineer_org_matches(pa.organization_id)
          AND  pa.is_deleted            = FALSE
    );
$$;

COMMENT ON FUNCTION fn_pcb_revision_in_org(UUID) IS
    'Returns TRUE if the given pcb_revision belongs to the current engineer''s organization '
    'via its parent pcb_assembly. Used by RLS policies on revision-child tables.';

-- =============================================================================
-- pcb_surface_finishes  (reference data — all authenticated can read)
-- =============================================================================

CREATE POLICY pol_pcb_surface_finishes_select
    ON pcb_surface_finishes
    FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY pol_pcb_surface_finishes_insert
    ON pcb_surface_finishes
    FOR INSERT
    TO authenticated
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_pcb_surface_finishes_update
    ON pcb_surface_finishes
    FOR UPDATE
    TO authenticated
    USING (fn_is_super_admin())
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_pcb_surface_finishes_delete
    ON pcb_surface_finishes
    FOR DELETE
    TO authenticated
    USING (fn_is_super_admin());

-- =============================================================================
-- pcb_materials  (reference data)
-- =============================================================================

CREATE POLICY pol_pcb_materials_select
    ON pcb_materials
    FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY pol_pcb_materials_insert
    ON pcb_materials
    FOR INSERT
    TO authenticated
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_pcb_materials_update
    ON pcb_materials
    FOR UPDATE
    TO authenticated
    USING (fn_is_super_admin())
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_pcb_materials_delete
    ON pcb_materials
    FOR DELETE
    TO authenticated
    USING (fn_is_super_admin());

-- =============================================================================
-- pcb_thickness_options  (reference data)
-- =============================================================================

CREATE POLICY pol_pcb_thickness_options_select
    ON pcb_thickness_options
    FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY pol_pcb_thickness_options_insert
    ON pcb_thickness_options
    FOR INSERT
    TO authenticated
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_pcb_thickness_options_update
    ON pcb_thickness_options
    FOR UPDATE
    TO authenticated
    USING (fn_is_super_admin())
    WITH CHECK (fn_is_super_admin());

CREATE POLICY pol_pcb_thickness_options_delete
    ON pcb_thickness_options
    FOR DELETE
    TO authenticated
    USING (fn_is_super_admin());

-- =============================================================================
-- board_manufacturers
-- organization_id = NULL → system record, readable by all
-- organization_id populated → org-scoped, admin manages
-- =============================================================================

CREATE POLICY pol_board_manufacturers_select
    ON board_manufacturers
    FOR SELECT
    TO authenticated
    USING (
        organization_id IS NULL
        OR fn_engineer_org_matches(organization_id)
    );

CREATE POLICY pol_board_manufacturers_insert
    ON board_manufacturers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
        )
    );

CREATE POLICY pol_board_manufacturers_update
    ON board_manufacturers
    FOR UPDATE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
        )
    );

CREATE POLICY pol_board_manufacturers_delete
    ON board_manufacturers
    FOR DELETE
    TO authenticated
    USING (
        is_system_record = FALSE
        AND (
            fn_is_super_admin()
            OR (
                fn_is_org_admin()
                AND organization_id = fn_get_current_organization_id()
            )
        )
    );

-- =============================================================================
-- assembly_manufacturers  (same pattern as board_manufacturers)
-- =============================================================================

CREATE POLICY pol_assembly_manufacturers_select
    ON assembly_manufacturers
    FOR SELECT
    TO authenticated
    USING (
        organization_id IS NULL
        OR fn_engineer_org_matches(organization_id)
    );

CREATE POLICY pol_assembly_manufacturers_insert
    ON assembly_manufacturers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
        )
    );

CREATE POLICY pol_assembly_manufacturers_update
    ON assembly_manufacturers
    FOR UPDATE
    TO authenticated
    USING (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
        )
    )
    WITH CHECK (
        fn_is_super_admin()
        OR (
            fn_is_org_admin()
            AND organization_id = fn_get_current_organization_id()
        )
    );

CREATE POLICY pol_assembly_manufacturers_delete
    ON assembly_manufacturers
    FOR DELETE
    TO authenticated
    USING (
        is_system_record = FALSE
        AND (
            fn_is_super_admin()
            OR (
                fn_is_org_admin()
                AND organization_id = fn_get_current_organization_id()
            )
        )
    );

-- =============================================================================
-- pcb_assemblies
-- =============================================================================

CREATE POLICY pol_pcb_assemblies_select
    ON pcb_assemblies
    FOR SELECT
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
    );

CREATE POLICY pol_pcb_assemblies_insert
    ON pcb_assemblies
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

CREATE POLICY pol_pcb_assemblies_update
    ON pcb_assemblies
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
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

-- Hard delete blocked; soft delete via UPDATE
CREATE POLICY pol_pcb_assemblies_delete
    ON pcb_assemblies
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- pcb_revisions
-- =============================================================================

CREATE POLICY pol_pcb_revisions_select
    ON pcb_revisions
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_pcb_revisions_insert
    ON pcb_revisions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

CREATE POLICY pol_pcb_revisions_update
    ON pcb_revisions
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR fn_pcb_assembly_in_org(pcb_assembly_id)
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR fn_pcb_assembly_in_org(pcb_assembly_id)
        )
    );

-- No hard delete
CREATE POLICY pol_pcb_revisions_delete
    ON pcb_revisions
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- pcb_layers
-- =============================================================================

CREATE POLICY pol_pcb_layers_select
    ON pcb_layers
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_pcb_layers_insert
    ON pcb_layers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    );

CREATE POLICY pol_pcb_layers_update
    ON pcb_layers
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    );

CREATE POLICY pol_pcb_layers_delete
    ON pcb_layers
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- pcb_stackups
-- =============================================================================

CREATE POLICY pol_pcb_stackups_select
    ON pcb_stackups
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_pcb_stackups_insert
    ON pcb_stackups
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    );

CREATE POLICY pol_pcb_stackups_update
    ON pcb_stackups
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    );

CREATE POLICY pol_pcb_stackups_delete
    ON pcb_stackups
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- assembly_variants
-- =============================================================================

CREATE POLICY pol_assembly_variants_select
    ON assembly_variants
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_assembly_variants_insert
    ON assembly_variants
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    );

CREATE POLICY pol_assembly_variants_update
    ON assembly_variants
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_assembly_in_org(pcb_assembly_id)
    );

CREATE POLICY pol_assembly_variants_delete
    ON assembly_variants
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- design_files
-- =============================================================================

CREATE POLICY pol_design_files_select
    ON design_files
    FOR SELECT
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
    );

CREATE POLICY pol_design_files_insert
    ON design_files
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_revision_in_org(pcb_revision_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

CREATE POLICY pol_design_files_update
    ON design_files
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
        AND (
            fn_is_org_admin()
            OR uploaded_by_engineer_id = fn_get_current_engineer_id()
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR uploaded_by_engineer_id = fn_get_current_engineer_id()
        )
    );

-- Hard delete blocked; soft delete via UPDATE
CREATE POLICY pol_design_files_delete
    ON design_files
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- components
-- =============================================================================

CREATE POLICY pol_components_select
    ON components
    FOR SELECT
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
    );

CREATE POLICY pol_components_insert
    ON components
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('material.manage')
    );

CREATE POLICY pol_components_update
    ON components
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND is_deleted = FALSE
        AND fn_current_engineer_has_permission('material.manage')
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('material.manage')
    );

-- Hard delete blocked; soft delete via UPDATE
CREATE POLICY pol_components_delete
    ON components
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- component_revisions
-- =============================================================================

CREATE POLICY pol_component_revisions_select
    ON component_revisions
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_component_revisions_insert
    ON component_revisions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('material.manage')
    );

CREATE POLICY pol_component_revisions_update
    ON component_revisions
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_senior_or_above()
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_is_senior_or_above()
    );

-- No delete (version history is permanent)
CREATE POLICY pol_component_revisions_delete
    ON component_revisions
    FOR DELETE
    TO authenticated
    USING (FALSE);

-- =============================================================================
-- electrical_nets
-- =============================================================================

CREATE POLICY pol_electrical_nets_select
    ON electrical_nets
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_electrical_nets_insert
    ON electrical_nets
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_revision_in_org(pcb_revision_id)
    );

CREATE POLICY pol_electrical_nets_update
    ON electrical_nets
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_revision_in_org(pcb_revision_id)
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_revision_in_org(pcb_revision_id)
    );

CREATE POLICY pol_electrical_nets_delete
    ON electrical_nets
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
    );

-- =============================================================================
-- bom_revisions
-- =============================================================================

CREATE POLICY pol_bom_revisions_select
    ON bom_revisions
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_bom_revisions_insert
    ON bom_revisions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

-- Allow update only of non-released revisions (trigger blocks released mutations)
CREATE POLICY pol_bom_revisions_update
    ON bom_revisions
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR fn_pcb_assembly_in_org(pcb_assembly_id)
        )
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND (
            fn_is_org_admin()
            OR fn_pcb_assembly_in_org(pcb_assembly_id)
        )
    );

-- Released BOMs cannot be deleted
CREATE POLICY pol_bom_revisions_delete
    ON bom_revisions
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_is_org_admin()
        AND NOT EXISTS (
            SELECT 1 FROM bom_revisions br2
            WHERE br2.id = bom_revisions.id
              AND br2.is_released = TRUE
        )
    );

-- =============================================================================
-- bom_items
-- =============================================================================

CREATE POLICY pol_bom_items_select
    ON bom_items
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

-- INSERT blocked on released BOMs by trigger; RLS allows engineers to try
CREATE POLICY pol_bom_items_insert
    ON bom_items
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

CREATE POLICY pol_bom_items_update
    ON bom_items
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

CREATE POLICY pol_bom_items_delete
    ON bom_items
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

-- =============================================================================
-- component_placements
-- =============================================================================

CREATE POLICY pol_component_placements_select
    ON component_placements
    FOR SELECT
    TO authenticated
    USING (fn_engineer_org_matches(organization_id));

CREATE POLICY pol_component_placements_insert
    ON component_placements
    FOR INSERT
    TO authenticated
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_revision_in_org(pcb_revision_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

CREATE POLICY pol_component_placements_update
    ON component_placements
    FOR UPDATE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_revision_in_org(pcb_revision_id)
        AND fn_current_engineer_has_permission('project.edit')
    )
    WITH CHECK (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_revision_in_org(pcb_revision_id)
        AND fn_current_engineer_has_permission('project.edit')
    );

-- Placements can be deleted by project editors (e.g., after re-import)
CREATE POLICY pol_component_placements_delete
    ON component_placements
    FOR DELETE
    TO authenticated
    USING (
        fn_engineer_org_matches(organization_id)
        AND fn_pcb_revision_in_org(pcb_revision_id)
        AND (
            fn_is_org_admin()
            OR fn_current_engineer_has_permission('project.edit')
        )
    );

COMMIT;
