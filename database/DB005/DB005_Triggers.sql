-- =============================================================================
-- StencilPro Expert Enterprise
-- DB005: Land Pattern & Aperture Intelligence Engine
-- File: DB005_Triggers.sql
-- Purpose: Trigger wiring for DB005.
--
-- Reuses existing shared trigger functions (NOT redefined here):
--   - app.fn_apply_audit_columns()   [DB001 standard audit trigger: sets
--                                     created_at/created_by/updated_at/updated_by]
--   - app.fn_touch_updated_at()      [DB001 standard trigger helper]
--   - app.fn_notify_change()         [DB001 standard notification helper]
--
-- All triggers use DROP TRIGGER IF EXISTS before creation for idempotency,
-- per established convention.
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- Standard audit triggers (all DB005 tables with audit columns)
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY[
        'aperture_shape_types', 'stencil_defect_types', 'package_families',
        'land_patterns', 'land_pattern_pads', 'land_pattern_approvals',
        'surface_finish_types', 'pad_surface_finish_compatibility', 'pads',
        'apertures', 'engineering_strategies', 'stencil_defect_root_causes',
        'stencil_defect_prevention_methods'
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
-- Section 6: recompute engineering metrics whenever aperture geometry changes
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db005_apertures_recompute_metrics()
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
        PERFORM app.fn_db005_recompute_aperture_metrics(NEW.id);
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db005_apertures_recompute_metrics IS
    'DB005 Section 6: triggers recomputation of area/aspect ratio, paste volume, transfer efficiency and printability index whenever aperture geometry-affecting columns change.';

DROP TRIGGER IF EXISTS tg_apertures_recompute_metrics ON app.apertures;
CREATE TRIGGER tg_apertures_recompute_metrics
    AFTER INSERT OR UPDATE ON app.apertures
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db005_apertures_recompute_metrics();

-- -----------------------------------------------------------------------------
-- Section 7: revision history logging (land patterns, apertures, strategies)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db005_land_patterns_log_revision()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_revision integer;
BEGIN
    SELECT coalesce(max(revision_number), 0) + 1 INTO v_next_revision
      FROM app.land_pattern_revisions
     WHERE land_pattern_id = NEW.id;

    INSERT INTO app.land_pattern_revisions (
        organization_id, land_pattern_id, revision_number, snapshot,
        change_summary, previous_status, new_status, created_by
    ) VALUES (
        NEW.organization_id, NEW.id, v_next_revision, app.fn_db005_snapshot_land_pattern(NEW.id),
        'Automatic revision on save',
        CASE WHEN TG_OP = 'UPDATE' THEN OLD.status ELSE NULL END,
        NEW.status,
        NEW.updated_by
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db005_land_patterns_log_revision IS
    'DB005 Section 1 / Section 7: writes an append-only revision snapshot on every land pattern insert/update.';

DROP TRIGGER IF EXISTS tg_land_patterns_log_revision ON app.land_patterns;
CREATE TRIGGER tg_land_patterns_log_revision
    AFTER INSERT OR UPDATE ON app.land_patterns
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db005_land_patterns_log_revision();

CREATE OR REPLACE FUNCTION app.tg_db005_apertures_log_revision()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_revision integer;
BEGIN
    SELECT coalesce(max(revision_number), 0) + 1 INTO v_next_revision
      FROM app.aperture_revisions
     WHERE aperture_id = NEW.id;

    INSERT INTO app.aperture_revisions (
        organization_id, aperture_id, revision_number, snapshot, change_summary, created_by
    ) VALUES (
        NEW.organization_id, NEW.id, v_next_revision, app.fn_db005_snapshot_aperture(NEW.id),
        'Automatic revision on save', NEW.updated_by
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db005_apertures_log_revision IS
    'DB005 Section 3 / Section 7: writes an append-only revision snapshot on every aperture insert/update.';

DROP TRIGGER IF EXISTS tg_apertures_log_revision ON app.apertures;
CREATE TRIGGER tg_apertures_log_revision
    AFTER INSERT OR UPDATE ON app.apertures
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db005_apertures_log_revision();

CREATE OR REPLACE FUNCTION app.tg_db005_engineering_strategies_log_revision()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_revision integer;
BEGIN
    SELECT coalesce(max(revision_number), 0) + 1 INTO v_next_revision
      FROM app.engineering_strategy_revisions
     WHERE engineering_strategy_id = NEW.id;

    INSERT INTO app.engineering_strategy_revisions (
        organization_id, engineering_strategy_id, revision_number, snapshot, change_summary, created_by
    ) VALUES (
        NEW.organization_id, NEW.id, v_next_revision, app.fn_db005_snapshot_engineering_strategy(NEW.id),
        'Automatic revision on save', NEW.updated_by
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db005_engineering_strategies_log_revision IS
    'DB005 Section 4 / Section 7: writes an append-only revision snapshot on every engineering strategy insert/update.';

DROP TRIGGER IF EXISTS tg_engineering_strategies_log_revision ON app.engineering_strategies;
CREATE TRIGGER tg_engineering_strategies_log_revision
    AFTER INSERT OR UPDATE ON app.engineering_strategies
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db005_engineering_strategies_log_revision();

-- -----------------------------------------------------------------------------
-- Notification on approval status change
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db005_land_pattern_approvals_notify()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
        PERFORM app.fn_notify_change('land_pattern_approval_status_changed', NEW.id);
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db005_land_pattern_approvals_notify IS
    'DB005 Section 1: notifies subscribers when a land pattern approval decision is recorded.';

DROP TRIGGER IF EXISTS tg_land_pattern_approvals_notify ON app.land_pattern_approvals;
CREATE TRIGGER tg_land_pattern_approvals_notify
    AFTER UPDATE ON app.land_pattern_approvals
    FOR EACH ROW
    EXECUTE FUNCTION app.tg_db005_land_pattern_approvals_notify();

-- -----------------------------------------------------------------------------
-- Enforce single is_current=true per (package_family_id) for land_patterns
-- and per (pad_id) for apertures, mirroring the versioning discipline used
-- in prior modules (only one current row per version chain).
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.tg_db005_land_patterns_enforce_single_current()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_current THEN
        UPDATE app.land_patterns
           SET is_current = false
         WHERE land_pattern_code = NEW.land_pattern_code
           AND organization_id = NEW.organization_id
           AND id <> NEW.id
           AND is_current = true;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db005_land_patterns_enforce_single_current IS
    'DB005 Section 1: ensures only one is_current=true row exists per land_pattern_code version chain.';

DROP TRIGGER IF EXISTS tg_land_patterns_enforce_single_current ON app.land_patterns;
CREATE TRIGGER tg_land_patterns_enforce_single_current
    AFTER INSERT OR UPDATE OF is_current ON app.land_patterns
    FOR EACH ROW
    WHEN (NEW.is_current = true)
    EXECUTE FUNCTION app.tg_db005_land_patterns_enforce_single_current();

CREATE OR REPLACE FUNCTION app.tg_db005_apertures_enforce_single_current()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_current THEN
        UPDATE app.apertures
           SET is_current = false
         WHERE pad_id = NEW.pad_id
           AND id <> NEW.id
           AND is_current = true;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION app.tg_db005_apertures_enforce_single_current IS
    'DB005 Section 3: ensures only one is_current=true aperture exists per pad.';

DROP TRIGGER IF EXISTS tg_apertures_enforce_single_current ON app.apertures;
CREATE TRIGGER tg_apertures_enforce_single_current
    AFTER INSERT OR UPDATE OF is_current ON app.apertures
    FOR EACH ROW
    WHEN (NEW.is_current = true)
    EXECUTE FUNCTION app.tg_db005_apertures_enforce_single_current();
