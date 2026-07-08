-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-003: PCB Assemblies & Components
-- File: DB003_Functions.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB003_PCB.sql
-- Prerequisites: DB001_Functions.sql, DB002_Functions.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- FUNCTION: fn_pcb_revision_current_enforce
-- Ensures only one PCB revision per assembly has is_current_revision = TRUE.
-- When a new revision is marked current, all others are demoted.
-- Fired BEFORE INSERT OR UPDATE on pcb_revisions.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_pcb_revision_current_enforce()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_current_revision = TRUE THEN
        UPDATE pcb_revisions
        SET    is_current_revision = FALSE,
               updated_at          = NOW()
        WHERE  pcb_assembly_id     = NEW.pcb_assembly_id
          AND  id                 != NEW.id
          AND  is_current_revision = TRUE;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_pcb_revision_current_enforce() IS
    'BEFORE INSERT OR UPDATE trigger on pcb_revisions. '
    'When is_current_revision = TRUE is set on a revision, all other revisions '
    'for the same assembly are demoted to is_current_revision = FALSE. '
    'Enforces the single-current-revision invariant alongside the partial unique index.';

-- =============================================================================
-- FUNCTION: fn_bom_revision_current_enforce
-- Ensures only one BOM revision per assembly has is_current = TRUE.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_bom_revision_current_enforce()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_current = TRUE THEN
        UPDATE bom_revisions
        SET    is_current  = FALSE,
               updated_at  = NOW()
        WHERE  pcb_assembly_id = NEW.pcb_assembly_id
          AND  id             != NEW.id
          AND  is_current      = TRUE;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_bom_revision_current_enforce() IS
    'BEFORE INSERT OR UPDATE trigger on bom_revisions. '
    'Ensures only one BOM revision per PCB assembly has is_current = TRUE.';

-- =============================================================================
-- FUNCTION: fn_component_revision_current_enforce
-- Ensures only one component revision has is_current = TRUE per component.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_component_revision_current_enforce()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_current = TRUE THEN
        UPDATE component_revisions
        SET    is_current  = FALSE,
               updated_at  = NOW()
        WHERE  component_id = NEW.component_id
          AND  id          != NEW.id
          AND  is_current   = TRUE;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_component_revision_current_enforce() IS
    'BEFORE INSERT OR UPDATE trigger on component_revisions. '
    'Ensures only one component revision per component has is_current = TRUE.';

-- =============================================================================
-- FUNCTION: fn_bom_revision_immutable
-- Prevents modification of released BOM revisions.
-- Fired BEFORE UPDATE on bom_revisions.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_bom_revision_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.is_released = TRUE THEN
        -- Allow only is_current flag to change on released BOMs
        IF (OLD.pcb_assembly_id         != NEW.pcb_assembly_id OR
            OLD.pcb_revision_id         != NEW.pcb_revision_id OR
            OLD.revision_code           != NEW.revision_code OR
            OLD.revision_date           != NEW.revision_date OR
            OLD.total_line_items        != NEW.total_line_items OR
            OLD.total_component_quantity!= NEW.total_component_quantity OR
            OLD.unique_part_count       != NEW.unique_part_count OR
            OLD.released_by_engineer_id != NEW.released_by_engineer_id)
        THEN
            RAISE EXCEPTION
                'BOM revision % is released and immutable. '
                'Create a new BOM revision to record changes.',
                OLD.id
                USING ERRCODE = 'restrict_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_bom_revision_immutable() IS
    'BEFORE UPDATE trigger on bom_revisions. '
    'Prevents modification of released BOM revisions (is_released = TRUE). '
    'Only the is_current flag may be updated on released BOMs.';

-- =============================================================================
-- FUNCTION: fn_bom_counts_update
-- Maintains aggregate counts on bom_revisions when bom_items change.
-- Fired AFTER INSERT, UPDATE, or DELETE on bom_items.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_bom_counts_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_bom_revision_id   UUID;
    v_line_items        INTEGER;
    v_total_qty         INTEGER;
    v_unique_parts      INTEGER;
BEGIN
    v_bom_revision_id := COALESCE(NEW.bom_revision_id, OLD.bom_revision_id);

    SELECT
        COUNT(*)::INTEGER,
        COALESCE(SUM(quantity), 0)::INTEGER,
        COUNT(DISTINCT component_id)::INTEGER
    INTO
        v_line_items,
        v_total_qty,
        v_unique_parts
    FROM bom_items
    WHERE bom_revision_id = v_bom_revision_id;

    UPDATE bom_revisions
    SET    total_line_items         = v_line_items,
           total_component_quantity = v_total_qty,
           unique_part_count        = v_unique_parts,
           updated_at               = NOW()
    WHERE  id = v_bom_revision_id;

    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION fn_bom_counts_update() IS
    'AFTER INSERT OR UPDATE OR DELETE trigger on bom_items. '
    'Recalculates and updates the aggregate count columns on the parent bom_revision: '
    'total_line_items, total_component_quantity, unique_part_count.';

-- =============================================================================
-- FUNCTION: fn_pcb_revision_notify_stencil
-- Creates a project_activity entry when a PCB revision changes type = major.
-- Alerts that stencil designs linked to the old revision need review.
-- Fired AFTER UPDATE on pcb_revisions.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_pcb_revision_notify_stencil()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_engineer_id   UUID;
    v_project_id    UUID;
    v_org_id        UUID;
BEGIN
    IF OLD.is_current_revision = NEW.is_current_revision THEN
        RETURN NEW;
    END IF;

    IF NEW.is_current_revision = FALSE THEN
        RETURN NEW;
    END IF;

    BEGIN
        v_engineer_id := current_setting('app.current_engineer_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_engineer_id := NEW.released_by_engineer_id;
    END;

    SELECT p.id, p.organization_id
    INTO   v_project_id, v_org_id
    FROM   pcb_assemblies pa
    JOIN   projects       p  ON p.id = pa.project_id
    WHERE  pa.id = NEW.pcb_assembly_id
    LIMIT  1;

    IF v_project_id IS NOT NULL THEN
        INSERT INTO project_activity (
            project_id, organization_id, engineer_id,
            activity_type, entity_type, entity_id,
            summary, metadata, occurred_at
        ) VALUES (
            v_project_id, v_org_id, v_engineer_id,
            'pcb_revision.set_current',
            'pcb_revisions', NEW.id,
            FORMAT(
                'PCB revision %s set as current revision. '
                'Linked stencil designs should be reviewed for compatibility.',
                NEW.revision_code
            ),
            jsonb_build_object(
                'revision_code',  NEW.revision_code,
                'change_type',    NEW.change_type,
                'assembly_id',    NEW.pcb_assembly_id
            ),
            NOW()
        );
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_pcb_revision_notify_stencil() IS
    'AFTER UPDATE trigger on pcb_revisions. '
    'When a revision is marked as current (is_current_revision = TRUE), '
    'writes a project_activity entry alerting engineers to review '
    'linked stencil designs for compatibility with the new revision.';

-- =============================================================================
-- FUNCTION: fn_component_placement_counts_update
-- Updates pcb_revisions summary counts after placement INSERT/UPDATE/DELETE.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_component_placement_counts_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_pcb_revision_id       UUID;
    v_component_count       INTEGER;
    v_smt_count             INTEGER;
    v_unique_package_count  INTEGER;
    v_min_pitch             NUMERIC(10,4);
    v_has_bgas              BOOLEAN;
    v_has_qfns              BOOLEAN;
    v_has_01005             BOOLEAN;
    v_has_0201              BOOLEAN;
BEGIN
    v_pcb_revision_id := COALESCE(NEW.pcb_revision_id, OLD.pcb_revision_id);

    SELECT
        COUNT(cp.id)::INTEGER,
        COUNT(cp.id) FILTER (WHERE cp.is_fiducial = FALSE AND cp.is_dnp = FALSE)::INTEGER
    INTO v_component_count, v_smt_count
    FROM component_placements cp
    WHERE cp.pcb_revision_id = v_pcb_revision_id;

    -- Count unique packages via components (package_id may be NULL if DB-004 not yet applied)
    SELECT COUNT(DISTINCT c.package_id)::INTEGER
    INTO   v_unique_package_count
    FROM   component_placements cp
    JOIN   components c ON c.id = cp.component_id
    WHERE  cp.pcb_revision_id = v_pcb_revision_id
      AND  c.package_id IS NOT NULL;

    UPDATE pcb_revisions
    SET    component_count      = v_component_count,
           smt_component_count  = v_smt_count,
           unique_package_count = COALESCE(v_unique_package_count, unique_package_count),
           updated_at           = NOW()
    WHERE  id = v_pcb_revision_id;

    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION fn_component_placement_counts_update() IS
    'AFTER INSERT OR UPDATE OR DELETE trigger on component_placements. '
    'Updates the denormalized summary counts on pcb_revisions: '
    'component_count, smt_component_count, unique_package_count.';

-- =============================================================================
-- FUNCTION: fn_prevent_bom_item_modification_released
-- Prevents bom_items from being changed when the parent BOM is released.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_prevent_bom_item_modification_released()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_released BOOLEAN;
BEGIN
    SELECT is_released INTO v_is_released
    FROM   bom_revisions
    WHERE  id = COALESCE(
        CASE WHEN TG_OP = 'DELETE' THEN OLD.bom_revision_id
             ELSE NEW.bom_revision_id
        END
    );

    IF v_is_released = TRUE THEN
        RAISE EXCEPTION
            'Cannot modify BOM items in a released BOM revision. '
            'Create a new BOM revision first.',
            USING ERRCODE = 'restrict_violation';
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION fn_prevent_bom_item_modification_released() IS
    'BEFORE INSERT OR UPDATE OR DELETE trigger on bom_items. '
    'Blocks any modification to bom_items when the parent bom_revision.is_released = TRUE.';

-- =============================================================================
-- FUNCTION: fn_pcb_assembly_activity
-- Writes a project_activity entry after PCB assembly INSERT or status changes.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_pcb_assembly_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_engineer_id   UUID;
    v_project_id    UUID;
    v_org_id        UUID;
    v_summary       VARCHAR(500);
    v_activity_type VARCHAR(100);
BEGIN
    BEGIN
        v_engineer_id := current_setting('app.current_engineer_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_engineer_id := NEW.updated_by;
    END;

    v_project_id := NEW.project_id;
    v_org_id     := NEW.organization_id;

    IF TG_OP = 'INSERT' THEN
        v_activity_type := 'pcb_assembly.created';
        v_summary       := FORMAT('PCB Assembly "%s" created.', NEW.name);
    ELSIF TG_OP = 'UPDATE' AND OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
        v_activity_type := 'pcb_assembly.deleted';
        v_summary       := FORMAT('PCB Assembly "%s" soft-deleted.', NEW.name);
    ELSE
        RETURN NEW;
    END IF;

    INSERT INTO project_activity (
        project_id, organization_id, engineer_id,
        activity_type, entity_type, entity_id,
        summary, metadata, occurred_at
    ) VALUES (
        v_project_id, v_org_id, v_engineer_id,
        v_activity_type,
        'pcb_assemblies', NEW.id,
        v_summary,
        jsonb_build_object(
            'name',           NEW.name,
            'assembly_sides', NEW.assembly_sides,
            'layer_count',    NEW.layer_count
        ),
        NOW()
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_pcb_assembly_activity() IS
    'AFTER INSERT OR UPDATE trigger on pcb_assemblies. '
    'Writes a project_activity entry when an assembly is created or soft-deleted.';

-- =============================================================================
-- FUNCTION: fn_get_pcb_revision_summary
-- Returns a JSONB summary of a PCB revision.
-- Used by stencil design and intelligence engine.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_pcb_revision_summary(p_pcb_revision_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT jsonb_build_object(
        'id',                       pr.id,
        'revision_code',            pr.revision_code,
        'pcb_assembly_id',          pr.pcb_assembly_id,
        'pcb_assembly_name',        pa.name,
        'pcb_assembly_part_number', pa.part_number,
        'component_count',          pr.component_count,
        'smt_component_count',      pr.smt_component_count,
        'unique_package_count',     pr.unique_package_count,
        'min_pitch_mm',             pr.min_pitch_mm,
        'has_bgas',                 pr.has_bgas,
        'has_qfns',                 pr.has_qfns,
        'has_01005_components',     pr.has_01005_components,
        'has_step_stencil_requirement', pr.has_step_stencil_requirement,
        'has_mixed_technology',     pr.has_mixed_technology,
        'has_paste_in_hole',        pr.has_paste_in_hole,
        'surface_finish_name',      sf.name,
        'surface_finish_abbreviation', sf.abbreviation,
        'board_length_mm',          pa.board_length_mm,
        'board_width_mm',           pa.board_width_mm,
        'board_thickness_mm',       pa.board_thickness_mm,
        'layer_count',              pa.layer_count,
        'assembly_sides',           pa.assembly_sides,
        'solder_mask_color',        pa.solder_mask_color,
        'change_type',              pr.change_type,
        'is_current_revision',      pr.is_current_revision,
        'summary_at',               NOW()
    )
    FROM  pcb_revisions       pr
    JOIN  pcb_assemblies      pa ON pa.id = pr.pcb_assembly_id
    LEFT  JOIN pcb_surface_finishes sf ON sf.id = pa.surface_finish_id
    WHERE pr.id = p_pcb_revision_id;
$$;

COMMENT ON FUNCTION fn_get_pcb_revision_summary(UUID) IS
    'Returns a JSONB summary of a PCB revision with joined assembly and surface finish details. '
    'Used by the Intelligence Engine to build ProcessContext.pcb_context and '
    'by stencil design workflows to display PCB characteristics.';

-- =============================================================================
-- FUNCTION: fn_get_placements_for_revision
-- Returns component placement data for a PCB revision in a format
-- consumable by the Intelligence Engine ProcessContext builder.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_placements_for_revision(p_pcb_revision_id UUID)
RETURNS TABLE (
    placement_id            UUID,
    reference_designator    VARCHAR(20),
    component_id            UUID,
    manufacturer_part_number VARCHAR(100),
    component_category      VARCHAR(50),
    x_position_mm           NUMERIC(12,6),
    y_position_mm           NUMERIC(12,6),
    rotation_degrees        NUMERIC(10,6),
    assembly_side           VARCHAR(10),
    is_dnp                  BOOLEAN,
    is_fiducial             BOOLEAN,
    land_pattern_id         UUID,
    max_reflow_temp_c       NUMERIC(6,2),
    moisture_sensitivity_level VARCHAR(10),
    has_special_paste_requirements BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        cp.id,
        cp.reference_designator,
        cp.component_id,
        c.manufacturer_part_number,
        c.component_category,
        cp.x_position_mm,
        cp.y_position_mm,
        cp.rotation_degrees,
        cp.assembly_side,
        cp.is_dnp,
        cp.is_fiducial,
        cp.land_pattern_id,
        c.max_reflow_temp_c,
        c.moisture_sensitivity_level,
        c.has_special_paste_requirements
    FROM  component_placements cp
    JOIN  components           c  ON c.id = cp.component_id
    WHERE cp.pcb_revision_id = p_pcb_revision_id
    ORDER BY cp.reference_designator;
$$;

COMMENT ON FUNCTION fn_get_placements_for_revision(UUID) IS
    'Returns the full component placement list for a PCB revision with joined component data. '
    'Used by the Intelligence Engine ProcessContext assembly and the stencil design workspace '
    'to display all placements with their engineering attributes.';

-- =============================================================================
-- FUNCTION: fn_validate_pcb_assembly_integrity
-- Validates that a PCB assembly is complete enough for stencil design.
-- Returns a JSONB report of what is missing.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_validate_pcb_assembly_integrity(p_pcb_assembly_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_assembly      pcb_assemblies%ROWTYPE;
    v_current_rev   pcb_revisions%ROWTYPE;
    v_issues        JSONB := '[]'::JSONB;
    v_placement_count INTEGER;
BEGIN
    SELECT * INTO v_assembly
    FROM   pcb_assemblies
    WHERE  id = p_pcb_assembly_id AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', FALSE,
            'issues', jsonb_build_array('PCB Assembly not found or deleted.')
        );
    END IF;

    SELECT * INTO v_current_rev
    FROM   pcb_revisions
    WHERE  pcb_assembly_id   = p_pcb_assembly_id
      AND  is_current_revision = TRUE
    LIMIT  1;

    IF v_assembly.surface_finish_id IS NULL THEN
        v_issues := v_issues || '["Surface finish not specified — required for paste compatibility rules."]'::JSONB;
    END IF;

    IF v_assembly.board_thickness_mm IS NULL THEN
        v_issues := v_issues || '["Board thickness not specified — required for printing support rules."]'::JSONB;
    END IF;

    IF v_assembly.assembly_sides IS NULL THEN
        v_issues := v_issues || '["Assembly sides not specified."]'::JSONB;
    END IF;

    IF NOT FOUND THEN
        v_issues := v_issues || '["No current PCB revision exists — create a revision before designing a stencil."]'::JSONB;
    ELSE
        SELECT COUNT(*)::INTEGER INTO v_placement_count
        FROM   component_placements
        WHERE  pcb_revision_id = v_current_rev.id;

        IF v_placement_count = 0 THEN
            v_issues := v_issues || '["Current revision has no component placements — import or enter placements before designing a stencil."]'::JSONB;
        END IF;

        IF v_current_rev.min_pitch_mm IS NULL THEN
            v_issues := v_issues || '["Minimum pitch not specified on current revision — required for rule group activation."]'::JSONB;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'valid',        jsonb_array_length(v_issues) = 0,
        'assembly_id',  p_pcb_assembly_id,
        'issues',       v_issues,
        'checked_at',   NOW()
    );
END;
$$;

COMMENT ON FUNCTION fn_validate_pcb_assembly_integrity(UUID) IS
    'Validates that a PCB assembly has sufficient data to begin stencil design. '
    'Returns a JSONB object with valid (boolean) and issues (array of problem strings). '
    'Called by the application layer before allowing stencil design creation.';

-- =============================================================================
-- FUNCTION: fn_import_pick_place_row
-- Called by the application import pipeline to create or update a single
-- component_placements record from a parsed pick-and-place file row.
-- Returns the placement UUID.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_import_pick_place_row(
    p_pcb_revision_id       UUID,
    p_organization_id       UUID,
    p_reference_designator  VARCHAR(20),
    p_x_mm                  NUMERIC(12,6),
    p_y_mm                  NUMERIC(12,6),
    p_rotation_deg          NUMERIC(10,6),
    p_assembly_side         VARCHAR(10),
    p_component_id          UUID,
    p_import_source         VARCHAR(30),
    p_import_file_id        UUID,
    p_engineer_id           UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_placement_id  UUID;
BEGIN
    INSERT INTO component_placements (
        id, pcb_revision_id, organization_id,
        component_id, reference_designator,
        x_position_mm, y_position_mm, rotation_degrees,
        assembly_side, import_source, import_file_id,
        is_dnp, is_fiducial,
        created_at, updated_at,
        created_by, updated_by
    ) VALUES (
        gen_random_uuid(),
        p_pcb_revision_id, p_organization_id,
        p_component_id, p_reference_designator,
        p_x_mm, p_y_mm, p_rotation_deg,
        p_assembly_side, p_import_source, p_import_file_id,
        FALSE, FALSE,
        NOW(), NOW(),
        p_engineer_id, p_engineer_id
    )
    ON CONFLICT (pcb_revision_id, reference_designator)
    DO UPDATE SET
        x_position_mm    = EXCLUDED.x_position_mm,
        y_position_mm    = EXCLUDED.y_position_mm,
        rotation_degrees = EXCLUDED.rotation_degrees,
        assembly_side    = EXCLUDED.assembly_side,
        component_id     = EXCLUDED.component_id,
        import_source    = EXCLUDED.import_source,
        import_file_id   = EXCLUDED.import_file_id,
        updated_at       = NOW(),
        updated_by       = p_engineer_id
    RETURNING id INTO v_placement_id;

    RETURN v_placement_id;
END;
$$;

COMMENT ON FUNCTION fn_import_pick_place_row(UUID,UUID,VARCHAR,NUMERIC,NUMERIC,NUMERIC,VARCHAR,UUID,VARCHAR,UUID,UUID) IS
    'Upserts a single component placement from a pick-and-place import row. '
    'Uses ON CONFLICT to update existing placements if the reference designator '
    'already exists for this PCB revision. '
    'Called in a loop by the application import pipeline.';

COMMIT;
