-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-002: Projects & Customers
-- File: DB002_Functions.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB002_Projects.sql
-- Prerequisites: DB001_Functions.sql (fn_get_current_engineer_id, etc.)
-- =============================================================================

BEGIN;

-- =============================================================================
-- FUNCTION: fn_set_created_updated_by_db002
-- Reuses DB001's fn_set_created_updated_by() via trigger attachment below.
-- No new function needed — attach existing function to DB002 tables.
-- =============================================================================

-- =============================================================================
-- FUNCTION: fn_enforce_project_ipc_class
-- Ensures project.ipc_class >= customer.required_ipc_class.
-- IPC class hierarchy: class_1 < class_2 < class_3.
-- Fired BEFORE INSERT OR UPDATE on projects.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_enforce_project_ipc_class()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_class    VARCHAR(10);
    v_class_rank        INT;
    v_project_rank      INT;

    -- IPC class rank: higher number = stricter requirement
    v_rank_map          JSONB := '{"class_1": 1, "class_2": 2, "class_3": 3}'::JSONB;
BEGIN
    SELECT required_ipc_class INTO v_customer_class
    FROM   customers
    WHERE  id = NEW.customer_id;

    v_class_rank   := (v_rank_map ->> v_customer_class)::INT;
    v_project_rank := (v_rank_map ->> NEW.ipc_class)::INT;

    IF v_project_rank < v_class_rank THEN
        RAISE EXCEPTION
            'Project IPC class (%) is below the customer required minimum (%). '
            'Project IPC class must be equal to or stricter than customer requirement.',
            NEW.ipc_class, v_customer_class
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_enforce_project_ipc_class() IS
    'BEFORE INSERT OR UPDATE trigger on projects. '
    'Enforces that project.ipc_class >= customer.required_ipc_class. '
    'IPC hierarchy: class_1 < class_2 < class_3. '
    'Raises check_violation if the project class is below the customer minimum.';

-- =============================================================================
-- FUNCTION: fn_project_status_note
-- Creates a system project_note when project status changes.
-- Fired AFTER UPDATE on projects when status changes.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_project_status_note()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_engineer_id   UUID;
    v_note_title    VARCHAR(255);
    v_note_content  TEXT;
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    BEGIN
        v_engineer_id := current_setting('app.current_engineer_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_engineer_id := NEW.updated_by;
    END;

    IF v_engineer_id IS NULL THEN
        v_engineer_id := NEW.lead_engineer_id;
    END IF;

    v_note_title   := 'Status changed: ' || OLD.status || ' → ' || NEW.status;
    v_note_content := FORMAT(
        'Project status changed from "%s" to "%s". Phase: %s.',
        OLD.status, NEW.status, NEW.phase
    );

    INSERT INTO project_notes (
        id,
        project_id,
        organization_id,
        engineer_id,
        note_type,
        title,
        content,
        is_system_generated,
        linked_entity_type,
        linked_entity_id,
        created_at
    ) VALUES (
        gen_random_uuid(),
        NEW.id,
        NEW.organization_id,
        v_engineer_id,
        'status_change',
        v_note_title,
        v_note_content,
        TRUE,
        'projects',
        NEW.id,
        NOW()
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_project_status_note() IS
    'AFTER UPDATE trigger on projects. '
    'Creates a system-generated project_note when project.status changes. '
    'Uses app.current_engineer_id session variable; falls back to updated_by, then lead_engineer_id.';

-- =============================================================================
-- FUNCTION: fn_project_activity_log
-- Writes a project_activity entry after significant project-level mutations.
-- Fired AFTER INSERT OR UPDATE on projects.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_project_activity_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_engineer_id   UUID;
    v_activity_type VARCHAR(100);
    v_summary       VARCHAR(500);
    v_metadata      JSONB;
BEGIN
    BEGIN
        v_engineer_id := current_setting('app.current_engineer_id', TRUE)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_engineer_id := NEW.updated_by;
    END;

    IF TG_OP = 'INSERT' THEN
        v_activity_type := 'project.created';
        v_summary       := FORMAT('Project "%s" (%s) created.', NEW.name, NEW.project_number);
        v_metadata      := jsonb_build_object(
            'project_number', NEW.project_number,
            'status',         NEW.status,
            'phase',          NEW.phase,
            'ipc_class',      NEW.ipc_class
        );

    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status != NEW.status THEN
            v_activity_type := 'project.status_changed';
            v_summary       := FORMAT(
                'Project status changed from "%s" to "%s".',
                OLD.status, NEW.status
            );
            v_metadata := jsonb_build_object(
                'status_from', OLD.status,
                'status_to',   NEW.status
            );
        ELSIF OLD.phase != NEW.phase THEN
            v_activity_type := 'project.phase_changed';
            v_summary       := FORMAT(
                'Project phase changed from "%s" to "%s".',
                OLD.phase, NEW.phase
            );
            v_metadata := jsonb_build_object(
                'phase_from', OLD.phase,
                'phase_to',   NEW.phase
            );
        ELSE
            v_activity_type := 'project.updated';
            v_summary       := FORMAT('Project "%s" updated.', NEW.name);
            v_metadata      := NULL;
        END IF;
    END IF;

    INSERT INTO project_activity (
        project_id,
        organization_id,
        engineer_id,
        activity_type,
        entity_type,
        entity_id,
        summary,
        metadata,
        occurred_at
    ) VALUES (
        NEW.id,
        NEW.organization_id,
        v_engineer_id,
        v_activity_type,
        'projects',
        NEW.id,
        v_summary,
        v_metadata,
        NOW()
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_project_activity_log() IS
    'AFTER INSERT OR UPDATE trigger on projects. '
    'Writes a project_activity record for project creation and key field changes '
    '(status, phase). Uses app.current_engineer_id session variable.';

-- =============================================================================
-- FUNCTION: fn_project_member_activity
-- Records project_activity when members are added or removed.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_project_member_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_engineer_name VARCHAR(255);
    v_summary       VARCHAR(500);
    v_activity_type VARCHAR(100);
BEGIN
    SELECT full_name INTO v_engineer_name
    FROM   engineers
    WHERE  id = NEW.engineer_id;

    IF TG_OP = 'INSERT' THEN
        v_activity_type := 'project.member_added';
        v_summary       := FORMAT(
            'Engineer "%s" added to project as %s.',
            COALESCE(v_engineer_name, NEW.engineer_id::TEXT),
            NEW.role_on_project
        );
    ELSIF TG_OP = 'UPDATE' AND NEW.removed_at IS NOT NULL AND OLD.removed_at IS NULL THEN
        v_activity_type := 'project.member_removed';
        v_summary       := FORMAT(
            'Engineer "%s" removed from project.',
            COALESCE(v_engineer_name, NEW.engineer_id::TEXT)
        );
    ELSE
        RETURN NEW;
    END IF;

    INSERT INTO project_activity (
        project_id,
        organization_id,
        engineer_id,
        activity_type,
        entity_type,
        entity_id,
        summary,
        metadata,
        occurred_at
    ) VALUES (
        NEW.project_id,
        NEW.organization_id,
        NEW.assigned_by_engineer_id,
        v_activity_type,
        'project_members',
        NEW.id,
        v_summary,
        jsonb_build_object(
            'target_engineer_id',   NEW.engineer_id,
            'target_engineer_name', v_engineer_name,
            'role_on_project',      NEW.role_on_project
        ),
        NOW()
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_project_member_activity() IS
    'AFTER INSERT OR UPDATE trigger on project_members. '
    'Records project_activity when an engineer is added or removed from a project.';

-- =============================================================================
-- FUNCTION: fn_project_note_activity
-- Records project_activity when a note is added.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_project_note_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.is_system_generated = TRUE THEN
        RETURN NEW;
    END IF;

    INSERT INTO project_activity (
        project_id,
        organization_id,
        engineer_id,
        activity_type,
        entity_type,
        entity_id,
        summary,
        metadata,
        occurred_at
    ) VALUES (
        NEW.project_id,
        NEW.organization_id,
        NEW.engineer_id,
        'project.note_added',
        'project_notes',
        NEW.id,
        FORMAT('Note added: "%s" (%s).', NEW.title, NEW.note_type),
        jsonb_build_object('note_type', NEW.note_type, 'title', NEW.title),
        NOW()
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_project_note_activity() IS
    'AFTER INSERT trigger on project_notes. '
    'Records project_activity for engineer-authored notes only (skips system-generated notes).';

-- =============================================================================
-- FUNCTION: fn_prevent_project_note_modification
-- project_notes is append-only. No UPDATE or DELETE permitted.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_prevent_project_note_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'project_notes records are append-only. '
        'UPDATE and DELETE are not permitted on this table.',
        USING ERRCODE = 'restrict_violation';
END;
$$;

COMMENT ON FUNCTION fn_prevent_project_note_modification() IS
    'BEFORE UPDATE OR DELETE trigger on project_notes. '
    'Enforces append-only immutability at the database layer.';

-- =============================================================================
-- FUNCTION: fn_prevent_project_activity_modification
-- project_activity is append-only. No UPDATE or DELETE permitted.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_prevent_project_activity_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'project_activity records are append-only. '
        'UPDATE and DELETE are not permitted on this table.',
        USING ERRCODE = 'restrict_violation';
END;
$$;

COMMENT ON FUNCTION fn_prevent_project_activity_modification() IS
    'BEFORE UPDATE OR DELETE trigger on project_activity. '
    'Enforces append-only immutability at the database layer.';

-- =============================================================================
-- FUNCTION: fn_project_revision_immutable
-- Once a project_revision is approved (approved_at IS NOT NULL),
-- it becomes immutable — no fields may be changed.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_project_revision_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.approved_at IS NOT NULL THEN
        RAISE EXCEPTION
            'Project revision % is approved and immutable. '
            'Create a new revision to record changes.',
            OLD.id
            USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_project_revision_immutable() IS
    'BEFORE UPDATE trigger on project_revisions. '
    'Prevents modification of approved project revisions. '
    'Once approved_at is set, the revision is permanently immutable.';

-- =============================================================================
-- FUNCTION: fn_project_tag_usage_count
-- Maintains project_tags.usage_count on insert/delete from project_tag_assignments.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_project_tag_usage_count()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE project_tags
        SET    usage_count = usage_count + 1,
               updated_at  = NOW()
        WHERE  id = NEW.tag_id;

    ELSIF TG_OP = 'DELETE' THEN
        UPDATE project_tags
        SET    usage_count = GREATEST(0, usage_count - 1),
               updated_at  = NOW()
        WHERE  id = OLD.tag_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION fn_project_tag_usage_count() IS
    'AFTER INSERT OR DELETE trigger on project_tag_assignments. '
    'Maintains the denormalized usage_count on project_tags for efficient display. '
    'GREATEST(0, ...) prevents negative counts from race conditions.';

-- =============================================================================
-- FUNCTION: fn_project_template_usage_count
-- Increments project_templates.usage_count when a project is created from a template.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_project_template_usage_count()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_template_id UUID;
BEGIN
    v_template_id := (NEW.template_settings ->> 'source_template_id')::UUID;

    IF v_template_id IS NOT NULL THEN
        UPDATE project_templates
        SET    usage_count = usage_count + 1,
               updated_at  = NOW()
        WHERE  id = v_template_id;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_project_template_usage_count() IS
    'AFTER INSERT trigger on projects. '
    'Increments usage_count on the source template if the project was created from one. '
    'Template ID is read from projects.tags or a future template_id column. '
    'Currently reads from project template_settings JSON on projects (Phase 2 feature hook).';

-- =============================================================================
-- FUNCTION: fn_create_project_activity
-- Application-callable helper to write a project_activity record.
-- Mirrors fn_log_activity from DB001 but scoped to a project.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_create_project_activity(
    p_project_id        UUID,
    p_organization_id   UUID,
    p_engineer_id       UUID,
    p_activity_type     VARCHAR(100),
    p_summary           VARCHAR(500),
    p_entity_type       VARCHAR(50)     DEFAULT NULL,
    p_entity_id         UUID            DEFAULT NULL,
    p_metadata          JSONB           DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO project_activity (
        project_id,
        organization_id,
        engineer_id,
        activity_type,
        entity_type,
        entity_id,
        summary,
        metadata,
        occurred_at
    ) VALUES (
        p_project_id,
        p_organization_id,
        p_engineer_id,
        p_activity_type,
        p_entity_type,
        p_entity_id,
        p_summary,
        p_metadata,
        NOW()
    );
END;
$$;

COMMENT ON FUNCTION fn_create_project_activity(UUID, UUID, UUID, VARCHAR, VARCHAR, VARCHAR, UUID, JSONB) IS
    'Application-callable function to write a project_activity entry. '
    'Use this from the Python application layer instead of direct INSERT. '
    'SECURITY DEFINER ensures the insert bypasses the RLS append-only restriction.';

-- =============================================================================
-- FUNCTION: fn_soft_delete_project
-- Safely soft-deletes a project. Validates no blocking child records exist.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_soft_delete_project(
    p_project_id    UUID,
    p_deleted_by    UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_project   projects%ROWTYPE;
BEGIN
    SELECT * INTO v_project
    FROM   projects
    WHERE  id = p_project_id AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Project % not found or already deleted.', p_project_id
            USING ERRCODE = 'no_data_found';
    END IF;

    UPDATE projects
    SET    is_deleted  = TRUE,
           deleted_at  = NOW(),
           status      = 'archived',
           updated_at  = NOW(),
           updated_by  = p_deleted_by
    WHERE  id          = p_project_id;

    INSERT INTO project_notes (
        id, project_id, organization_id, engineer_id,
        note_type, title, content, is_system_generated,
        linked_entity_type, linked_entity_id, created_at
    ) VALUES (
        gen_random_uuid(),
        p_project_id,
        v_project.organization_id,
        p_deleted_by,
        'system',
        'Project archived and soft-deleted',
        FORMAT(
            'Project "%s" (%s) was soft-deleted and archived by engineer %s.',
            v_project.name, v_project.project_number, p_deleted_by
        ),
        TRUE,
        'projects',
        p_project_id,
        NOW()
    );
END;
$$;

COMMENT ON FUNCTION fn_soft_delete_project(UUID, UUID) IS
    'Soft-deletes a project: sets is_deleted = TRUE, status = archived, '
    'and creates a system project_note recording the deletion. '
    'Does not cascade to child records — those remain readable for audit.';

-- =============================================================================
-- FUNCTION: fn_get_project_summary
-- Returns a JSONB summary of a project for snapshots and exports.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_get_project_summary(p_project_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT jsonb_build_object(
        'id',                       p.id,
        'project_number',           p.project_number,
        'name',                     p.name,
        'status',                   p.status,
        'phase',                    p.phase,
        'ipc_class',                p.ipc_class,
        'target_yield_pct',         p.target_yield_pct,
        'start_date',               p.start_date,
        'target_completion_date',   p.target_completion_date,
        'tags',                     p.tags,
        'customer_name',            c.name,
        'customer_code',            c.code,
        'lead_engineer_name',       e.full_name,
        'organization_id',          p.organization_id,
        'snapshot_at',              NOW()
    )
    FROM  projects  p
    JOIN  customers c ON c.id = p.customer_id
    JOIN  engineers e ON e.id = p.lead_engineer_id
    WHERE p.id = p_project_id;
$$;

COMMENT ON FUNCTION fn_get_project_summary(UUID) IS
    'Returns a JSONB snapshot of a project with joined customer and engineer names. '
    'Used by fn_project_revision_snapshot to populate project_revisions.project_snapshot.';

-- =============================================================================
-- FUNCTION: fn_create_project_revision
-- Creates a new project revision with an automatic snapshot.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_create_project_revision(
    p_project_id            UUID,
    p_revision_code         VARCHAR(10),
    p_revision_type         VARCHAR(30),
    p_change_summary        TEXT,
    p_change_reason         VARCHAR(50),
    p_authored_by           UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_next_number   INTEGER;
    v_org_id        UUID;
    v_revision_id   UUID;
BEGIN
    SELECT organization_id INTO v_org_id
    FROM   projects
    WHERE  id = p_project_id AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Project % not found.', p_project_id
            USING ERRCODE = 'no_data_found';
    END IF;

    SELECT COALESCE(MAX(revision_number), 0) + 1
    INTO   v_next_number
    FROM   project_revisions
    WHERE  project_id = p_project_id;

    UPDATE project_revisions
    SET    is_current = FALSE,
           updated_at = NOW()
    WHERE  project_id = p_project_id
      AND  is_current = TRUE;

    v_revision_id := gen_random_uuid();

    INSERT INTO project_revisions (
        id, project_id, organization_id,
        revision_number, revision_code,
        revision_type, change_summary, change_reason,
        authored_by_engineer_id,
        project_snapshot,
        is_current,
        created_at, updated_at,
        created_by, updated_by
    ) VALUES (
        v_revision_id,
        p_project_id,
        v_org_id,
        v_next_number,
        p_revision_code,
        p_revision_type,
        p_change_summary,
        p_change_reason,
        p_authored_by,
        fn_get_project_summary(p_project_id),
        TRUE,
        NOW(), NOW(),
        p_authored_by,
        p_authored_by
    );

    INSERT INTO project_notes (
        id, project_id, organization_id, engineer_id,
        note_type, title, content, is_system_generated,
        linked_entity_type, linked_entity_id, created_at
    ) VALUES (
        gen_random_uuid(),
        p_project_id,
        v_org_id,
        p_authored_by,
        'milestone',
        FORMAT('Revision %s created', p_revision_code),
        FORMAT(
            'Project revision %s (Rev %s) created. Type: %s. Reason: %s. Summary: %s',
            v_next_number, p_revision_code,
            p_revision_type, p_change_reason, p_change_summary
        ),
        TRUE,
        'project_revisions',
        v_revision_id,
        NOW()
    );

    RETURN v_revision_id;
END;
$$;

COMMENT ON FUNCTION fn_create_project_revision(UUID, VARCHAR, VARCHAR, TEXT, VARCHAR, UUID) IS
    'Creates a new project revision with auto-incrementing number, '
    'JSONB project snapshot, sets is_current = TRUE (demoting previous current), '
    'and creates a system project_note. Returns the new revision UUID.';

COMMIT;
