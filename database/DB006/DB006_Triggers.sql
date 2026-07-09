-- =============================================================================
-- StencilPro Expert Enterprise
-- DB006: Stencil Generation Engine
-- File: DB006_Triggers.sql
-- Purpose: Trigger wiring for DB006.
--
-- Reuses existing shared trigger functions (NOT redefined here):
--   - app.fn_apply_audit_columns()   [DB001]
--   - app.fn_notify_change()          [DB001]
--
-- All triggers use DROP TRIGGER IF EXISTS before creation for idempotency.
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- Standard audit triggers
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'stencil_projects', 'stencil_layers', 'stencil_step_regions',
        'generated_apertures', 'aperture_decisions', 'stencil_fabrication_capabilities'
    ])
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS tg_%1$s_audit ON app.%1$s', t);
        EXECUTE format(
            'CREATE TRIGGER tg_%1$s_audit BEFORE INSERT OR UPDATE ON app.%1$s
             FOR EACH ROW EXECUTE FUNCTION app.fn_apply_audit_columns()', t
        );
    END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- Section 3 / Section 6 (Engineering Spec): recompute metrics on geometry change
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db006_generated_apertures_recompute_metrics()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT'
       OR NEW.length_mm IS DISTINCT FROM OLD.length_mm
       OR NEW.width_mm IS DISTINCT FROM OLD.width_mm
       OR NEW.corner_radius_mm IS DISTINCT FROM OLD.corner_radius_mm
       OR NEW.segment_count IS DISTINCT FROM OLD.segment_count
       OR NEW.segment_gap_mm IS DISTINCT FROM OLD.segment_gap_mm
       OR NEW.stencil_thickness_mm IS DISTINCT FROM OLD.stencil_thickness_mm
       OR NEW.shape_type_id IS DISTINCT FROM OLD.shape_type_id
    THEN
        PERFORM app.fn_db006_recompute_generated_aperture_metrics(NEW.id);
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db006_generated_apertures_recompute_metrics IS
    'DB006 Section 3: recomputes engineering metrics whenever aperture geometry-affecting columns change (insert or update).';

DROP TRIGGER IF EXISTS tg_generated_apertures_1_recompute_metrics ON app.generated_apertures;
CREATE TRIGGER tg_generated_apertures_1_recompute_metrics
    AFTER INSERT OR UPDATE ON app.generated_apertures
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db006_generated_apertures_recompute_metrics();

-- -----------------------------------------------------------------------------
-- Section 7 (Engineering Spec): validate after metrics are recomputed
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db006_generated_apertures_validate()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM app.fn_db006_validate_generated_aperture(NEW.id);
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db006_generated_apertures_validate IS
    'DB006 Section 7: re-runs validation whenever a generated aperture is inserted or its metrics are recomputed.';

DROP TRIGGER IF EXISTS tg_generated_apertures_2_validate ON app.generated_apertures;
CREATE TRIGGER tg_generated_apertures_2_validate
    AFTER INSERT OR UPDATE ON app.generated_apertures
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db006_generated_apertures_validate();

-- -----------------------------------------------------------------------------
-- Section 9 (Engineering Spec): revision history logging
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db006_stencil_projects_log_revision()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_revision integer;
BEGIN
    SELECT coalesce(max(revision_number), 0) + 1 INTO v_next_revision
      FROM app.stencil_project_revisions
     WHERE stencil_project_id = NEW.id;

    INSERT INTO app.stencil_project_revisions (
        organization_id, stencil_project_id, revision_number, snapshot,
        change_summary, previous_status, new_status, created_by
    ) VALUES (
        NEW.organization_id, NEW.id, v_next_revision, app.fn_db006_snapshot_stencil_project(NEW.id),
        'Automatic revision on save',
        CASE WHEN TG_OP = 'UPDATE' THEN OLD.release_status ELSE NULL END,
        NEW.release_status,
        NEW.updated_by
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db006_stencil_projects_log_revision IS
    'DB006 Section 9: writes an append-only revision snapshot on every stencil project insert/update.';

DROP TRIGGER IF EXISTS tg_stencil_projects_log_revision ON app.stencil_projects;
CREATE TRIGGER tg_stencil_projects_log_revision
    AFTER INSERT OR UPDATE ON app.stencil_projects
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db006_stencil_projects_log_revision();

CREATE OR REPLACE FUNCTION app.tg_db006_generated_apertures_log_revision()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_revision integer;
BEGIN
    SELECT coalesce(max(revision_number), 0) + 1 INTO v_next_revision
      FROM app.generated_aperture_revisions
     WHERE generated_aperture_id = NEW.id;

    INSERT INTO app.generated_aperture_revisions (
        organization_id, generated_aperture_id, revision_number, snapshot, change_summary, created_by
    ) VALUES (
        NEW.organization_id, NEW.id, v_next_revision, app.fn_db006_snapshot_generated_aperture(NEW.id),
        'Automatic revision on save', NEW.updated_by
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db006_generated_apertures_log_revision IS
    'DB006 Section 9: writes an append-only revision snapshot on every generated aperture insert/update. Runs after metrics recompute and validation so the snapshot reflects final computed state.';

DROP TRIGGER IF EXISTS tg_generated_apertures_3_log_revision ON app.generated_apertures;
CREATE TRIGGER tg_generated_apertures_3_log_revision
    AFTER INSERT OR UPDATE ON app.generated_apertures
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db006_generated_apertures_log_revision();

-- -----------------------------------------------------------------------------
-- Section 9: immutability after release/archive
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db006_stencil_projects_prevent_modify_after_release()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.release_status IN ('RELEASED', 'ARCHIVED') THEN
        -- Only a transition to ARCHIVED (from RELEASED) is permitted on a
        -- released/archived stencil; every other field is frozen. All other
        -- changes must go through app.fn_db006_create_next_stencil_revision().
        IF NOT (OLD.release_status = 'RELEASED' AND NEW.release_status = 'ARCHIVED'
                AND NEW.stencil_code = OLD.stencil_code
                AND NEW.revision_number = OLD.revision_number
                AND NEW.stencil_thickness_mm = OLD.stencil_thickness_mm)
        THEN
            RAISE EXCEPTION 'stencil project % is % and immutable; create a new revision via app.fn_db006_create_next_stencil_revision() instead of modifying it directly',
                OLD.id, OLD.release_status;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db006_stencil_projects_prevent_modify_after_release IS
    'DB006 Section 9: enforces that a released or archived stencil revision is immutable, per Engineering Spec Section 10.5 revision history requirements. The only permitted change is RELEASED -> ARCHIVED.';

DROP TRIGGER IF EXISTS tg_stencil_projects_prevent_modify_after_release ON app.stencil_projects;
CREATE TRIGGER tg_stencil_projects_prevent_modify_after_release
    BEFORE UPDATE ON app.stencil_projects
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db006_stencil_projects_prevent_modify_after_release();

-- -----------------------------------------------------------------------------
-- Enforce single is_current=true per stencil_code (stencil_projects) and per
-- (pad_id, stencil_layer_id) for generated_apertures, mirroring the
-- versioning discipline established in DB005.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db006_stencil_projects_enforce_single_current()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_current THEN
        UPDATE app.stencil_projects
           SET is_current = false
         WHERE stencil_code = NEW.stencil_code
           AND organization_id = NEW.organization_id
           AND id <> NEW.id
           AND is_current = true;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db006_stencil_projects_enforce_single_current IS
    'DB006 Section 1: ensures only one is_current=true row exists per stencil_code version chain.';

DROP TRIGGER IF EXISTS tg_stencil_projects_enforce_single_current ON app.stencil_projects;
CREATE TRIGGER tg_stencil_projects_enforce_single_current
    AFTER INSERT OR UPDATE OF is_current ON app.stencil_projects
    FOR EACH ROW
    WHEN (NEW.is_current = true)
    EXECUTE FUNCTION app.tg_db006_stencil_projects_enforce_single_current();

CREATE OR REPLACE FUNCTION app.tg_db006_generated_apertures_enforce_single_current()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_current THEN
        UPDATE app.generated_apertures
           SET is_current = false
         WHERE pad_id = NEW.pad_id
           AND stencil_layer_id = NEW.stencil_layer_id
           AND id <> NEW.id
           AND is_current = true;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db006_generated_apertures_enforce_single_current IS
    'DB006 Section 3: ensures only one is_current=true generated aperture exists per pad within a given stencil layer.';

DROP TRIGGER IF EXISTS tg_generated_apertures_enforce_single_current ON app.generated_apertures;
CREATE TRIGGER tg_generated_apertures_enforce_single_current
    AFTER INSERT OR UPDATE OF is_current ON app.generated_apertures
    FOR EACH ROW
    WHEN (NEW.is_current = true)
    EXECUTE FUNCTION app.tg_db006_generated_apertures_enforce_single_current();

-- -----------------------------------------------------------------------------
-- Notification on decision and status change
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db006_aperture_decisions_notify()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR NEW.decision_status IS DISTINCT FROM OLD.decision_status THEN
        PERFORM app.fn_notify_change('aperture_decision_status_changed', NEW.id);
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db006_aperture_decisions_notify IS
    'DB006 Section 4: notifies subscribers when an aperture decision status changes.';

DROP TRIGGER IF EXISTS tg_aperture_decisions_notify ON app.aperture_decisions;
CREATE TRIGGER tg_aperture_decisions_notify
    AFTER INSERT OR UPDATE ON app.aperture_decisions
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db006_aperture_decisions_notify();
