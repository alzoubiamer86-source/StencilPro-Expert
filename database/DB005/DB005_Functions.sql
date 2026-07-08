-- =============================================================================
-- StencilPro Expert Enterprise
-- DB005: Land Pattern & Aperture Intelligence Engine
-- File: DB005_Functions.sql
-- Purpose: Module-specific functions. Standard shared infrastructure
--          (app.fn_apply_audit_columns, app.fn_touch_updated_at,
--          app.fn_user_organization_id, app.fn_notify_change,
--          app.current_engineer_id) is assumed to already exist from DB001
--          and is referenced here, not redefined.
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- Section 6: Engineering Calculations
-- -----------------------------------------------------------------------------

-- Aperture area (mm^2) by shape. Uses IPC-style approximations per shape family.
-- Custom polygons are computed from stored vertices via the shoelace formula.
CREATE OR REPLACE FUNCTION app.fn_db005_calculate_aperture_area(
    p_shape_code    text,
    p_length_mm     numeric,
    p_width_mm      numeric,
    p_radius_mm     numeric DEFAULT 0,
    p_segment_count integer DEFAULT NULL,
    p_segment_gap_mm numeric DEFAULT NULL,
    p_aperture_id   uuid DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_area numeric;
    v_corner_loss numeric;
BEGIN
    CASE p_shape_code
        WHEN 'RECTANGLE', 'HOME_PLATE', 'INVERTED_HOME_PLATE', 'CROSS', 'DOG_BONE' THEN
            v_area := p_length_mm * p_width_mm;

        WHEN 'SQUARE' THEN
            v_area := p_length_mm * p_length_mm;

        WHEN 'ROUNDED_RECTANGLE' THEN
            v_corner_loss := (4 - pi()) * power(coalesce(p_radius_mm, 0), 2);
            v_area := (p_length_mm * p_width_mm) - v_corner_loss;

        WHEN 'CIRCLE' THEN
            v_area := pi() * power(p_length_mm / 2.0, 2);

        WHEN 'OVAL', 'D_SHAPE' THEN
            v_area := pi() * (p_length_mm / 2.0) * (p_width_mm / 2.0);

        WHEN 'WINDOW_PANE', 'SEGMENTED_THERMAL_PAD' THEN
            v_area := (p_length_mm * p_width_mm)
                      - (coalesce(p_segment_count, 1) - 1) * coalesce(p_segment_gap_mm, 0) * p_width_mm;

        WHEN 'CUSTOM_POLYGON' THEN
            IF p_aperture_id IS NULL THEN
                RAISE EXCEPTION 'aperture_id is required to compute area for CUSTOM_POLYGON shapes';
            END IF;
            SELECT abs(sum(
                       (v.x_mm * lead_v.y_mm) - (lead_v.x_mm * v.y_mm)
                   )) / 2.0
              INTO v_area
              FROM app.aperture_polygon_vertices v
              JOIN LATERAL (
                  SELECT x_mm, y_mm
                    FROM app.aperture_polygon_vertices v2
                   WHERE v2.aperture_id = v.aperture_id
                   ORDER BY (v2.vertex_index - v.vertex_index + 1) % (
                       SELECT count(*) FROM app.aperture_polygon_vertices v3 WHERE v3.aperture_id = v.aperture_id
                   )
                   LIMIT 1
              ) lead_v ON true
             WHERE v.aperture_id = p_aperture_id;

        ELSE
            v_area := p_length_mm * p_width_mm;
    END CASE;

    RETURN round(v_area, 6);
END;
$$;

COMMENT ON FUNCTION app.fn_db005_calculate_aperture_area IS
    'DB005 Section 6: computes aperture area (mm^2) per shape strategy; CUSTOM_POLYGON uses stored vertices via shoelace formula.';

-- Aperture perimeter (mm) by shape.
CREATE OR REPLACE FUNCTION app.fn_db005_calculate_aperture_perimeter(
    p_shape_code    text,
    p_length_mm     numeric,
    p_width_mm      numeric,
    p_radius_mm     numeric DEFAULT 0
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_perimeter numeric;
BEGIN
    CASE p_shape_code
        WHEN 'CIRCLE' THEN
            v_perimeter := pi() * p_length_mm;

        WHEN 'OVAL', 'D_SHAPE' THEN
            v_perimeter := pi() * (
                (3 * (p_length_mm / 2.0 + p_width_mm / 2.0))
                - sqrt((3 * p_length_mm / 2.0 + p_width_mm / 2.0) * (p_length_mm / 2.0 + 3 * p_width_mm / 2.0))
            );

        WHEN 'ROUNDED_RECTANGLE' THEN
            v_perimeter := 2 * (p_length_mm + p_width_mm) - (8 * coalesce(p_radius_mm, 0)) + (2 * pi() * coalesce(p_radius_mm, 0));

        WHEN 'SQUARE' THEN
            v_perimeter := 4 * p_length_mm;

        ELSE
            v_perimeter := 2 * (p_length_mm + p_width_mm);
    END CASE;

    RETURN round(v_perimeter, 4);
END;
$$;

COMMENT ON FUNCTION app.fn_db005_calculate_aperture_perimeter IS
    'DB005 Section 6: computes aperture perimeter (mm) per shape strategy.';

-- IPC-7525 style area ratio: aperture area / (aperture perimeter * stencil thickness)
CREATE OR REPLACE FUNCTION app.fn_db005_calculate_area_ratio(
    p_area_mm2       numeric,
    p_perimeter_mm   numeric,
    p_thickness_mm   numeric
)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN p_perimeter_mm IS NULL OR p_thickness_mm IS NULL OR p_perimeter_mm * p_thickness_mm = 0
            THEN NULL
        ELSE round(p_area_mm2 / (p_perimeter_mm * p_thickness_mm), 4)
    END;
$$;

COMMENT ON FUNCTION app.fn_db005_calculate_area_ratio IS
    'DB005 Section 6: IPC-7525 style area ratio = aperture area / (aperture perimeter * stencil thickness).';

-- Aspect ratio: aperture width / aperture length (IPC convention, smaller / larger opening dimension)
CREATE OR REPLACE FUNCTION app.fn_db005_calculate_aspect_ratio(
    p_length_mm numeric,
    p_width_mm  numeric
)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN p_length_mm IS NULL OR p_length_mm = 0 THEN NULL
        ELSE round(least(p_length_mm, p_width_mm) / greatest(p_length_mm, p_width_mm), 4)
    END;
$$;

COMMENT ON FUNCTION app.fn_db005_calculate_aspect_ratio IS
    'DB005 Section 6: aspect ratio = smaller opening dimension / larger opening dimension.';

-- Paste volume: aperture area * stencil thickness
CREATE OR REPLACE FUNCTION app.fn_db005_calculate_paste_volume(
    p_area_mm2     numeric,
    p_thickness_mm numeric
)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN p_area_mm2 IS NULL OR p_thickness_mm IS NULL THEN NULL
        ELSE round(p_area_mm2 * p_thickness_mm, 6)
    END;
$$;

COMMENT ON FUNCTION app.fn_db005_calculate_paste_volume IS
    'DB005 Section 6: paste volume (mm^3) = aperture area * stencil thickness.';

-- Transfer efficiency estimate, IPC-7525 empirical curve:
-- TE(%) = (AR / (AR + 0.20)) * 100, clamped to [0, 100]
CREATE OR REPLACE FUNCTION app.fn_db005_calculate_transfer_efficiency(
    p_area_ratio numeric
)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN p_area_ratio IS NULL THEN NULL
        ELSE round(least(greatest((p_area_ratio / (p_area_ratio + 0.20)) * 100, 0), 100), 2)
    END;
$$;

COMMENT ON FUNCTION app.fn_db005_calculate_transfer_efficiency IS
    'DB005 Section 6: estimated paste transfer efficiency (%) from area ratio, using IPC-7525 empirical curve.';

-- Printability index: composite score combining area ratio and aspect ratio,
-- normalized against the IPC-recommended minimum area ratio of 0.66.
CREATE OR REPLACE FUNCTION app.fn_db005_calculate_printability_index(
    p_area_ratio    numeric,
    p_aspect_ratio  numeric
)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN p_area_ratio IS NULL OR p_aspect_ratio IS NULL THEN NULL
        ELSE round(
            least(1.0, p_area_ratio / 0.66) * 0.6
            + least(1.0, p_aspect_ratio / 0.60) * 0.4
        , 4)
    END;
$$;

COMMENT ON FUNCTION app.fn_db005_calculate_printability_index IS
    'DB005 Section 6: composite printability index (0-1) weighting area ratio (60%) against IPC minimum 0.66, and aspect ratio (40%) against reference 0.60.';

-- Orchestrator: recomputes all Section 6 metrics for a given aperture row
-- and writes them onto app.apertures, then inserts a traceable snapshot
-- into app.pad_engineering_calculations.
CREATE OR REPLACE FUNCTION app.fn_db005_recompute_aperture_metrics(
    p_aperture_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    r_aperture      app.apertures%ROWTYPE;
    v_shape_code    text;
    v_area          numeric;
    v_perimeter     numeric;
    v_area_ratio    numeric;
    v_aspect_ratio  numeric;
    v_paste_volume  numeric;
    v_transfer_eff  numeric;
    v_printability  numeric;
BEGIN
    SELECT * INTO r_aperture FROM app.apertures WHERE id = p_aperture_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'aperture % not found', p_aperture_id;
    END IF;

    SELECT shape_code INTO v_shape_code
      FROM app.aperture_shape_types
     WHERE id = r_aperture.shape_type_id;

    v_area := app.fn_db005_calculate_aperture_area(
        v_shape_code, r_aperture.length_mm, r_aperture.width_mm,
        r_aperture.corner_radius_mm, r_aperture.segment_count,
        r_aperture.segment_gap_mm, r_aperture.id
    );

    v_perimeter := app.fn_db005_calculate_aperture_perimeter(
        v_shape_code, r_aperture.length_mm, r_aperture.width_mm, r_aperture.corner_radius_mm
    );

    v_area_ratio   := app.fn_db005_calculate_area_ratio(v_area, v_perimeter, r_aperture.stencil_thickness_mm);
    v_aspect_ratio := app.fn_db005_calculate_aspect_ratio(r_aperture.length_mm, r_aperture.width_mm);
    v_paste_volume := app.fn_db005_calculate_paste_volume(v_area, r_aperture.stencil_thickness_mm);
    v_transfer_eff := app.fn_db005_calculate_transfer_efficiency(v_area_ratio);
    v_printability := app.fn_db005_calculate_printability_index(v_area_ratio, v_aspect_ratio);

    UPDATE app.apertures
       SET computed_area_mm2 = v_area,
           computed_perimeter_mm = v_perimeter,
           area_ratio = v_area_ratio,
           aspect_ratio = v_aspect_ratio,
           paste_volume_mm3 = v_paste_volume,
           transfer_efficiency_pct = v_transfer_eff,
           printability_index = v_printability
     WHERE id = p_aperture_id;

    INSERT INTO app.pad_engineering_calculations (
        organization_id, pad_id, aperture_id, area_ratio, aspect_ratio,
        paste_volume_mm3, aperture_area_mm2, aperture_perimeter_mm,
        stencil_thickness_mm, transfer_efficiency_pct, printability_index,
        calculation_method
    ) VALUES (
        r_aperture.organization_id, r_aperture.pad_id, r_aperture.id, v_area_ratio, v_aspect_ratio,
        v_paste_volume, v_area, v_perimeter,
        r_aperture.stencil_thickness_mm, v_transfer_eff, v_printability,
        'STANDARD_IPC'
    );
END;
$$;

COMMENT ON FUNCTION app.fn_db005_recompute_aperture_metrics IS
    'DB005 Section 6: recomputes all engineering metrics for an aperture and records a traceable calculation snapshot. Invoked by trigger on insert/update of dimension-affecting columns.';

-- -----------------------------------------------------------------------------
-- Section 1 / 3 / 4: Revision snapshot helpers
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db005_snapshot_land_pattern(p_land_pattern_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT to_jsonb(lp.*) FROM app.land_patterns lp WHERE lp.id = p_land_pattern_id;
$$;

COMMENT ON FUNCTION app.fn_db005_snapshot_land_pattern IS
    'DB005 Section 1 / Section 7: serializes current land pattern row state for revision history.';

CREATE OR REPLACE FUNCTION app.fn_db005_snapshot_aperture(p_aperture_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT to_jsonb(a.*) FROM app.apertures a WHERE a.id = p_aperture_id;
$$;

COMMENT ON FUNCTION app.fn_db005_snapshot_aperture IS
    'DB005 Section 3 / Section 7: serializes current aperture row state for revision history.';

CREATE OR REPLACE FUNCTION app.fn_db005_snapshot_engineering_strategy(p_strategy_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT to_jsonb(es.*) FROM app.engineering_strategies es WHERE es.id = p_strategy_id;
$$;

COMMENT ON FUNCTION app.fn_db005_snapshot_engineering_strategy IS
    'DB005 Section 4 / Section 7: serializes current engineering strategy row state for revision history.';

-- -----------------------------------------------------------------------------
-- Section 1: Approval workflow helpers
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db005_request_land_pattern_approval(
    p_land_pattern_id uuid,
    p_requested_by    uuid DEFAULT app.current_engineer_id()
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_approval_id uuid;
    v_org_id      uuid;
BEGIN
    SELECT organization_id INTO v_org_id FROM app.land_patterns WHERE id = p_land_pattern_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'land pattern % not found', p_land_pattern_id;
    END IF;

    UPDATE app.land_patterns
       SET status = 'PENDING_APPROVAL'
     WHERE id = p_land_pattern_id;

    INSERT INTO app.land_pattern_approvals (
        organization_id, land_pattern_id, requested_by, approval_status
    ) VALUES (
        v_org_id, p_land_pattern_id, p_requested_by, 'PENDING'
    )
    RETURNING id INTO v_approval_id;

    PERFORM app.fn_notify_change('land_pattern_approval_requested', v_approval_id);

    RETURN v_approval_id;
END;
$$;

COMMENT ON FUNCTION app.fn_db005_request_land_pattern_approval IS
    'DB005 Section 1: opens an approval workflow instance and moves the land pattern to PENDING_APPROVAL.';

CREATE OR REPLACE FUNCTION app.fn_db005_decide_land_pattern_approval(
    p_approval_id     uuid,
    p_approver_id     uuid,
    p_approved        boolean,
    p_approval_notes  text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_land_pattern_id uuid;
BEGIN
    SELECT land_pattern_id INTO v_land_pattern_id
      FROM app.land_pattern_approvals
     WHERE id = p_approval_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'approval request % not found', p_approval_id;
    END IF;

    UPDATE app.land_pattern_approvals
       SET approval_status = CASE WHEN p_approved THEN 'APPROVED' ELSE 'REJECTED' END,
           approver_id = p_approver_id,
           approval_notes = p_approval_notes,
           decided_at = now(),
           updated_at = now(),
           updated_by = p_approver_id
     WHERE id = p_approval_id;

    UPDATE app.land_patterns
       SET status = CASE WHEN p_approved THEN 'APPROVED' ELSE 'DRAFT' END,
           approved_by = CASE WHEN p_approved THEN p_approver_id ELSE approved_by END,
           approved_at = CASE WHEN p_approved THEN now() ELSE approved_at END
     WHERE id = v_land_pattern_id;

    PERFORM app.fn_notify_change('land_pattern_approval_decided', p_approval_id);
END;
$$;

COMMENT ON FUNCTION app.fn_db005_decide_land_pattern_approval IS
    'DB005 Section 1: records an approval decision and updates the parent land pattern status accordingly.';
