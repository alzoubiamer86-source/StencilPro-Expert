-- =============================================================================
-- StencilPro Expert Enterprise
-- DB006: Stencil Generation Engine
-- File: DB006_Functions.sql
-- Purpose: Module-specific functions supporting the workflow defined in
--          STENCILPRO_V1_ENGINEERING_SPECIFICATION.md Sections 6-10.
--
-- Reuses existing shared infrastructure (NOT redefined here):
--   - app.fn_apply_audit_columns(), app.fn_touch_updated_at()      [DB001]
--   - app.fn_user_organization_id(), app.fn_notify_change()        [DB001]
--   - app.current_engineer_id()                                     [DB001]
--
-- Reuses DB005 engineering calculation functions DIRECTLY (NOT redefined):
--   - app.fn_db005_calculate_aperture_area()
--   - app.fn_db005_calculate_aperture_perimeter()
--   - app.fn_db005_calculate_area_ratio()
--   - app.fn_db005_calculate_aspect_ratio()
--   - app.fn_db005_calculate_paste_volume()
--   - app.fn_db005_calculate_transfer_efficiency()
--   - app.fn_db005_calculate_printability_index()
--
-- These formulas are defined once in DB005 (Engineering Spec Section 6) and
-- are the same formulas whether the aperture in question is a DB005 library
-- aperture or a DB006 generated aperture. DB006 does not redefine them; it
-- only supplies a CUSTOM_POLYGON area helper against generated_aperture_
-- polygon_vertices, since DB005's CUSTOM_POLYGON path reads from a
-- different (DB005-owned) vertex table.
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- Section 3 / Section 6 (Engineering Spec): area for generated CUSTOM_POLYGON
-- apertures, sourced from generated_aperture_polygon_vertices.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db006_calculate_generated_polygon_area(
    p_generated_aperture_id uuid
)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT round(abs(sum(
               (v.x_mm * lead_v.y_mm) - (lead_v.x_mm * v.y_mm)
           )) / 2.0, 6)
      FROM app.generated_aperture_polygon_vertices v
      JOIN LATERAL (
          SELECT x_mm, y_mm
            FROM app.generated_aperture_polygon_vertices v2
           WHERE v2.generated_aperture_id = v.generated_aperture_id
           ORDER BY (v2.vertex_index - v.vertex_index + 1) % (
               SELECT count(*) FROM app.generated_aperture_polygon_vertices v3
                WHERE v3.generated_aperture_id = v.generated_aperture_id
           )
           LIMIT 1
      ) lead_v ON true
     WHERE v.generated_aperture_id = p_generated_aperture_id;
$$;

COMMENT ON FUNCTION app.fn_db006_calculate_generated_polygon_area IS
    'DB006 Section 3: shoelace-formula area for CUSTOM_POLYGON generated apertures, mirroring the DB005 CUSTOM_POLYGON path but sourced from generated_aperture_polygon_vertices.';

CREATE OR REPLACE FUNCTION app.fn_db006_calculate_generated_polygon_perimeter(
    p_generated_aperture_id uuid
)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT round(sum(
               sqrt(power(lead_v.x_mm - v.x_mm, 2) + power(lead_v.y_mm - v.y_mm, 2))
           ), 4)
      FROM app.generated_aperture_polygon_vertices v
      JOIN LATERAL (
          SELECT x_mm, y_mm
            FROM app.generated_aperture_polygon_vertices v2
           WHERE v2.generated_aperture_id = v.generated_aperture_id
           ORDER BY (v2.vertex_index - v.vertex_index + 1) % (
               SELECT count(*) FROM app.generated_aperture_polygon_vertices v3
                WHERE v3.generated_aperture_id = v.generated_aperture_id
           )
           LIMIT 1
      ) lead_v ON true
     WHERE v.generated_aperture_id = p_generated_aperture_id;
$$;

COMMENT ON FUNCTION app.fn_db006_calculate_generated_polygon_perimeter IS
    'DB006 Section 3: perimeter (sum of consecutive vertex distances) for CUSTOM_POLYGON generated apertures.';

-- -----------------------------------------------------------------------------
-- Orchestrator: recomputes all engineering metrics for a generated aperture,
-- reusing DB005 formulas, and records a revision snapshot.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db006_recompute_generated_aperture_metrics(
    p_generated_aperture_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    r_ga            app.generated_apertures%ROWTYPE;
    v_shape_code    text;
    v_area          numeric;
    v_perimeter     numeric;
    v_area_ratio    numeric;
    v_aspect_ratio  numeric;
    v_paste_volume  numeric;
    v_transfer_eff  numeric;
    v_printability  numeric;
BEGIN
    SELECT * INTO r_ga FROM app.generated_apertures WHERE id = p_generated_aperture_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'generated aperture % not found', p_generated_aperture_id;
    END IF;

    SELECT shape_code INTO v_shape_code
      FROM app.aperture_shape_types
     WHERE id = r_ga.shape_type_id;

    IF v_shape_code = 'CUSTOM_POLYGON' THEN
        v_area := app.fn_db006_calculate_generated_polygon_area(r_ga.id);
        v_perimeter := app.fn_db006_calculate_generated_polygon_perimeter(r_ga.id);
    ELSE
        v_area := app.fn_db005_calculate_aperture_area(
            v_shape_code, r_ga.length_mm, r_ga.width_mm,
            r_ga.corner_radius_mm, r_ga.segment_count, r_ga.segment_gap_mm, NULL
        );
        v_perimeter := app.fn_db005_calculate_aperture_perimeter(
            v_shape_code, r_ga.length_mm, r_ga.width_mm, r_ga.corner_radius_mm
        );
    END IF;

    v_area_ratio   := app.fn_db005_calculate_area_ratio(v_area, v_perimeter, r_ga.stencil_thickness_mm);
    v_aspect_ratio := app.fn_db005_calculate_aspect_ratio(r_ga.length_mm, r_ga.width_mm);
    v_paste_volume := app.fn_db005_calculate_paste_volume(v_area, r_ga.stencil_thickness_mm);
    v_transfer_eff := app.fn_db005_calculate_transfer_efficiency(v_area_ratio);
    v_printability := app.fn_db005_calculate_printability_index(v_area_ratio, v_aspect_ratio);

    UPDATE app.generated_apertures
       SET computed_area_mm2 = v_area,
           computed_perimeter_mm = v_perimeter,
           area_ratio = v_area_ratio,
           aspect_ratio = v_aspect_ratio,
           paste_volume_mm3 = v_paste_volume,
           transfer_efficiency_pct = v_transfer_eff,
           printability_index = v_printability
     WHERE id = p_generated_aperture_id;
END;
$$;

COMMENT ON FUNCTION app.fn_db006_recompute_generated_aperture_metrics IS
    'DB006 Section 3: recomputes area, perimeter, area ratio, aspect ratio, paste volume, transfer efficiency and printability index for a generated aperture, reusing DB005 formula functions directly. Invoked by trigger on geometry change.';

-- -----------------------------------------------------------------------------
-- Section 7 (Engineering Spec): Stencil Validation
-- -----------------------------------------------------------------------------

-- Helper predicate: does this shape type use webbing (Window Pane / Segmented Thermal Pad)?
CREATE OR REPLACE FUNCTION app.fn_db006_shape_requires_web(p_shape_type_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT shape_code IN ('WINDOW_PANE', 'SEGMENTED_THERMAL_PAD')
      FROM app.aperture_shape_types
     WHERE id = p_shape_type_id;
$$;

COMMENT ON FUNCTION app.fn_db006_shape_requires_web IS
    'DB006 Section 7: true when the given aperture shape type subdivides its opening with webbing (Window Pane, Segmented Thermal Pad), the only shapes for which MIN_WEB_WIDTH validation applies.';

CREATE OR REPLACE FUNCTION app.fn_db006_validate_generated_aperture(
    p_generated_aperture_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    r_ga            app.generated_apertures%ROWTYPE;
    r_layer         app.stencil_layers%ROWTYPE;
    r_cap           app.stencil_fabrication_capabilities%ROWTYPE;
    v_min_dimension numeric;
BEGIN
    SELECT * INTO r_ga FROM app.generated_apertures WHERE id = p_generated_aperture_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'generated aperture % not found', p_generated_aperture_id;
    END IF;

    SELECT * INTO r_layer FROM app.stencil_layers WHERE id = r_ga.stencil_layer_id;

    SELECT * INTO r_cap FROM app.stencil_fabrication_capabilities
     WHERE organization_id = r_ga.organization_id AND layer_technology = r_layer.layer_technology;

    -- Clear prior validation results for this aperture before re-validating.
    DELETE FROM app.aperture_validations WHERE generated_aperture_id = p_generated_aperture_id;

    -- AREA_RATIO: IPC-7525 minimum 0.66 (Engineering Spec Section 6.3)
    INSERT INTO app.aperture_validations (
        organization_id, generated_aperture_id, validation_type, result_value, threshold_value,
        risk_level, status, message
    ) VALUES (
        r_ga.organization_id, r_ga.id, 'AREA_RATIO', r_ga.area_ratio, 0.66,
        CASE WHEN r_ga.area_ratio IS NULL THEN 'MEDIUM'
             WHEN r_ga.area_ratio < 0.66 THEN 'HIGH'
             WHEN r_ga.area_ratio < 0.75 THEN 'MEDIUM'
             ELSE 'LOW' END,
        CASE WHEN r_ga.area_ratio IS NULL THEN 'WARNING'
             WHEN r_ga.area_ratio < 0.66 THEN 'ERROR'
             ELSE 'PASS' END,
        CASE WHEN r_ga.area_ratio IS NULL THEN 'Area ratio not yet computed.'
             WHEN r_ga.area_ratio < 0.66 THEN 'Area ratio below IPC-7525 minimum of 0.66; insufficient paste release risk.'
             ELSE 'Area ratio meets or exceeds IPC-7525 minimum of 0.66.' END
    );

    -- ASPECT_RATIO: IPC-7525 minimum 0.60 (Engineering Spec Section 6.4)
    INSERT INTO app.aperture_validations (
        organization_id, generated_aperture_id, validation_type, result_value, threshold_value,
        risk_level, status, message
    ) VALUES (
        r_ga.organization_id, r_ga.id, 'ASPECT_RATIO', r_ga.aspect_ratio, 0.60,
        CASE WHEN r_ga.aspect_ratio IS NULL THEN 'MEDIUM'
             WHEN r_ga.aspect_ratio < 0.60 THEN 'HIGH'
             WHEN r_ga.aspect_ratio < 0.70 THEN 'MEDIUM'
             ELSE 'LOW' END,
        CASE WHEN r_ga.aspect_ratio IS NULL THEN 'WARNING'
             WHEN r_ga.aspect_ratio < 0.60 THEN 'ERROR'
             ELSE 'PASS' END,
        CASE WHEN r_ga.aspect_ratio IS NULL THEN 'Aspect ratio not yet computed.'
             WHEN r_ga.aspect_ratio < 0.60 THEN 'Aspect ratio below IPC-7525 minimum of 0.60; independent release risk regardless of area ratio.'
             ELSE 'Aspect ratio meets or exceeds IPC-7525 minimum of 0.60.' END
    );

    -- MIN_APERTURE_WIDTH: fabrication capability check (Section 7 Aperture Clogging)
    v_min_dimension := least(r_ga.length_mm, r_ga.width_mm);
    INSERT INTO app.aperture_validations (
        organization_id, generated_aperture_id, validation_type, result_value, threshold_value,
        risk_level, status, message
    ) VALUES (
        r_ga.organization_id, r_ga.id, 'MIN_APERTURE_WIDTH', v_min_dimension, r_cap.min_aperture_width_mm,
        CASE WHEN r_cap.min_aperture_width_mm IS NULL THEN 'MEDIUM'
             WHEN v_min_dimension < r_cap.min_aperture_width_mm THEN 'HIGH'
             ELSE 'LOW' END,
        CASE WHEN r_cap.min_aperture_width_mm IS NULL THEN 'WARNING'
             WHEN v_min_dimension < r_cap.min_aperture_width_mm THEN 'ERROR'
             ELSE 'PASS' END,
        CASE WHEN r_cap.min_aperture_width_mm IS NULL THEN 'No fabrication capability record found for this layer technology.'
             WHEN v_min_dimension < r_cap.min_aperture_width_mm THEN 'Minimum aperture dimension is below the fabricator''s minimum aperture width; clogging risk (Engineering Spec Section 7.5).'
             ELSE 'Minimum aperture dimension meets fabrication capability.' END
    );

    -- MIN_WEB_WIDTH: only meaningful for subdivided apertures (Window Pane / Segmented Thermal Pad)
    IF app.fn_db006_shape_requires_web(r_ga.shape_type_id) AND r_ga.segment_gap_mm IS NOT NULL THEN
        INSERT INTO app.aperture_validations (
            organization_id, generated_aperture_id, validation_type, result_value, threshold_value,
            risk_level, status, message
        ) VALUES (
            r_ga.organization_id, r_ga.id, 'MIN_WEB_WIDTH', r_ga.segment_gap_mm, r_cap.min_web_width_mm,
            CASE WHEN r_cap.min_web_width_mm IS NULL THEN 'MEDIUM'
                 WHEN r_ga.segment_gap_mm < r_cap.min_web_width_mm THEN 'HIGH'
                 ELSE 'LOW' END,
            CASE WHEN r_cap.min_web_width_mm IS NULL THEN 'WARNING'
                 WHEN r_ga.segment_gap_mm < r_cap.min_web_width_mm THEN 'ERROR'
                 ELSE 'PASS' END,
            CASE WHEN r_cap.min_web_width_mm IS NULL THEN 'No fabrication capability record found for this layer technology.'
                 WHEN r_ga.segment_gap_mm < r_cap.min_web_width_mm THEN 'Segment webbing gap is below the fabricator''s minimum web width; webbing may tear during handling.'
                 ELSE 'Webbing gap meets fabrication capability.' END
        );
    END IF;
END;
$$;

COMMENT ON FUNCTION app.fn_db006_validate_generated_aperture IS
    'DB006 Section 7: computes and stores validation results (area ratio, aspect ratio, minimum aperture width, minimum web width) for a generated aperture against IPC-7525 minimums and organization fabrication capabilities.';

-- -----------------------------------------------------------------------------
-- Section 4 (Engineering Spec Section 10): decisions and approval history
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db006_record_decision(
    p_generated_aperture_id     uuid,
    p_decision_status           text,
    p_selected_recommendation_id uuid DEFAULT NULL,
    p_engineer_comments          text DEFAULT NULL,
    p_decision_reason             text DEFAULT NULL,
    p_explanation                  text DEFAULT NULL,
    p_decided_by                    uuid DEFAULT app.current_engineer_id()
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_org_id           uuid;
    v_confidence        numeric(5,2);
BEGIN
    SELECT organization_id INTO v_org_id FROM app.generated_apertures WHERE id = p_generated_aperture_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'generated aperture % not found', p_generated_aperture_id;
    END IF;

    IF p_selected_recommendation_id IS NOT NULL THEN
        SELECT confidence_score INTO v_confidence
          FROM app.aperture_recommendations
         WHERE id = p_selected_recommendation_id;
    END IF;

    INSERT INTO app.aperture_decisions (
        organization_id, generated_aperture_id, decision_status, selected_recommendation_id,
        engineer_comments, decision_reason, confidence_score, explanation, decided_by, decided_at
    ) VALUES (
        v_org_id, p_generated_aperture_id, p_decision_status, p_selected_recommendation_id,
        p_engineer_comments, p_decision_reason, v_confidence, p_explanation, p_decided_by, now()
    )
    ON CONFLICT (generated_aperture_id) DO UPDATE SET
        decision_status = EXCLUDED.decision_status,
        selected_recommendation_id = EXCLUDED.selected_recommendation_id,
        engineer_comments = EXCLUDED.engineer_comments,
        decision_reason = EXCLUDED.decision_reason,
        confidence_score = EXCLUDED.confidence_score,
        explanation = EXCLUDED.explanation,
        decided_by = EXCLUDED.decided_by,
        decided_at = EXCLUDED.decided_at,
        updated_at = now(),
        updated_by = EXCLUDED.decided_by;

    INSERT INTO app.aperture_decision_history (
        organization_id, generated_aperture_id, decision_status, selected_recommendation_id,
        engineer_comments, decision_reason, confidence_score, decided_by, decided_at
    ) VALUES (
        v_org_id, p_generated_aperture_id, p_decision_status, p_selected_recommendation_id,
        p_engineer_comments, p_decision_reason, v_confidence, p_decided_by, now()
    );

    IF p_decision_status = 'APPROVED' THEN
        UPDATE app.generated_apertures SET status = 'APPROVED' WHERE id = p_generated_aperture_id;
    ELSIF p_decision_status = 'REJECTED' THEN
        UPDATE app.generated_apertures SET status = 'REJECTED' WHERE id = p_generated_aperture_id;
    END IF;

    PERFORM app.fn_notify_change('aperture_decision_recorded', p_generated_aperture_id);
END;
$$;

COMMENT ON FUNCTION app.fn_db006_record_decision IS
    'DB006 Section 4: records or updates the current decision for a generated aperture and appends an immutable entry to the approval history log (Section 8/9).';

-- -----------------------------------------------------------------------------
-- Section 6 (Engineering Spec Section 10): manual overrides
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db006_apply_override(
    p_generated_aperture_id uuid,
    p_override_field        text,
    p_previous_value         jsonb,
    p_new_value               jsonb,
    p_override_reason          text,
    p_engineer_id                uuid DEFAULT app.current_engineer_id()
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_org_id     uuid;
    v_override_id uuid;
BEGIN
    SELECT organization_id INTO v_org_id FROM app.generated_apertures WHERE id = p_generated_aperture_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'generated aperture % not found', p_generated_aperture_id;
    END IF;

    INSERT INTO app.aperture_overrides (
        organization_id, generated_aperture_id, override_field, previous_value, new_value,
        override_reason, engineer_id
    ) VALUES (
        v_org_id, p_generated_aperture_id, p_override_field, p_previous_value, p_new_value,
        p_override_reason, p_engineer_id
    )
    RETURNING id INTO v_override_id;

    -- Apply the new value to the target column, matching the overridden field.
    CASE p_override_field
        WHEN 'SHAPE' THEN
            UPDATE app.generated_apertures SET shape_type_id = (p_new_value ->> 'shape_type_id')::uuid
             WHERE id = p_generated_aperture_id;
        WHEN 'REDUCTION' THEN
            UPDATE app.generated_apertures SET reduction_percent = (p_new_value ->> 'reduction_percent')::numeric
             WHERE id = p_generated_aperture_id;
        WHEN 'ROTATION' THEN
            UPDATE app.generated_apertures SET rotation_degrees = (p_new_value ->> 'rotation_degrees')::numeric
             WHERE id = p_generated_aperture_id;
        WHEN 'DIMENSIONS' THEN
            UPDATE app.generated_apertures
               SET length_mm = (p_new_value ->> 'length_mm')::numeric,
                   width_mm = (p_new_value ->> 'width_mm')::numeric
             WHERE id = p_generated_aperture_id;
        WHEN 'PASTE_PERCENT' THEN
            UPDATE app.generated_apertures SET paste_coverage_percent = (p_new_value ->> 'paste_coverage_percent')::numeric
             WHERE id = p_generated_aperture_id;
        WHEN 'CORNER_RADIUS' THEN
            UPDATE app.generated_apertures SET corner_radius_mm = (p_new_value ->> 'corner_radius_mm')::numeric
             WHERE id = p_generated_aperture_id;
        WHEN 'WINDOW_COUNT' THEN
            UPDATE app.generated_apertures SET window_count = (p_new_value ->> 'window_count')::integer
             WHERE id = p_generated_aperture_id;
        WHEN 'SEGMENTATION' THEN
            UPDATE app.generated_apertures
               SET segment_count = (p_new_value ->> 'segment_count')::integer,
                   segment_gap_mm = (p_new_value ->> 'segment_gap_mm')::numeric
             WHERE id = p_generated_aperture_id;
    END CASE;

    -- Recompute metrics and re-validate against the new geometry.
    PERFORM app.fn_db006_recompute_generated_aperture_metrics(p_generated_aperture_id);
    PERFORM app.fn_db006_validate_generated_aperture(p_generated_aperture_id);

    -- Record the override event as a comparison against the pre-override state.
    INSERT INTO app.aperture_comparisons (
        organization_id, generated_aperture_id, comparison_type, baseline_reference_type,
        geometry_delta_summary
    ) VALUES (
        v_org_id, p_generated_aperture_id, 'GENERATED_VS_ENGINEER_MODIFIED', 'APERTURE',
        format('Engineer override of %s: %s -> %s', p_override_field, p_previous_value, p_new_value)
    );

    RETURN v_override_id;
END;
$$;

COMMENT ON FUNCTION app.fn_db006_apply_override IS
    'DB006 Section 6: applies a manual engineering override to a generated aperture, logs it immutably, recomputes engineering metrics, re-validates, and records a comparison entry.';

-- -----------------------------------------------------------------------------
-- Section 5 (Engineering Spec Section 9): comparisons
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db006_compare_pad_to_generated(
    p_generated_aperture_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    r_ga        app.generated_apertures%ROWTYPE;
    r_pad       app.pads%ROWTYPE;
    v_pad_area  numeric;
    v_comparison_id uuid;
BEGIN
    SELECT * INTO r_ga FROM app.generated_apertures WHERE id = p_generated_aperture_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'generated aperture % not found', p_generated_aperture_id;
    END IF;

    SELECT * INTO r_pad FROM app.pads WHERE id = r_ga.pad_id;

    v_pad_area := r_pad.width_mm * r_pad.height_mm;

    INSERT INTO app.aperture_comparisons (
        organization_id, generated_aperture_id, comparison_type, baseline_reference_type,
        geometry_delta_summary, area_delta_mm2
    ) VALUES (
        r_ga.organization_id, r_ga.id, 'PAD_VS_GENERATED', 'PAD',
        format('Pad %s x %s vs aperture %s x %s (reduction %s%%)',
               r_pad.width_mm, r_pad.height_mm, r_ga.width_mm, r_ga.length_mm, r_ga.reduction_percent),
        coalesce(r_ga.computed_area_mm2, 0) - v_pad_area
    )
    RETURNING id INTO v_comparison_id;

    RETURN v_comparison_id;
END;
$$;

COMMENT ON FUNCTION app.fn_db006_compare_pad_to_generated IS
    'DB006 Section 5: records a comparison between the original pad geometry and the generated aperture, per Engineering Spec Section 9 baseline-vs-scenario comparison pattern.';

CREATE OR REPLACE FUNCTION app.fn_db006_compare_to_previous_revision(
    p_generated_aperture_id uuid,
    p_previous_aperture_id  uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    r_current   app.generated_apertures%ROWTYPE;
    r_previous  app.generated_apertures%ROWTYPE;
    v_comparison_id uuid;
BEGIN
    SELECT * INTO r_current FROM app.generated_apertures WHERE id = p_generated_aperture_id;
    SELECT * INTO r_previous FROM app.generated_apertures WHERE id = p_previous_aperture_id;

    IF r_current.id IS NULL OR r_previous.id IS NULL THEN
        RAISE EXCEPTION 'one or both generated apertures not found (% , %)', p_generated_aperture_id, p_previous_aperture_id;
    END IF;

    INSERT INTO app.aperture_comparisons (
        organization_id, generated_aperture_id, comparison_type, baseline_reference_type,
        baseline_aperture_id, area_delta_mm2, paste_volume_delta_mm3, area_ratio_delta,
        transfer_efficiency_delta_pct
    ) VALUES (
        r_current.organization_id, r_current.id, 'CURRENT_VS_PREVIOUS_REVISION', 'APERTURE',
        r_previous.id,
        coalesce(r_current.computed_area_mm2, 0) - coalesce(r_previous.computed_area_mm2, 0),
        coalesce(r_current.paste_volume_mm3, 0) - coalesce(r_previous.paste_volume_mm3, 0),
        coalesce(r_current.area_ratio, 0) - coalesce(r_previous.area_ratio, 0),
        coalesce(r_current.transfer_efficiency_pct, 0) - coalesce(r_previous.transfer_efficiency_pct, 0)
    )
    RETURNING id INTO v_comparison_id;

    RETURN v_comparison_id;
END;
$$;

COMMENT ON FUNCTION app.fn_db006_compare_to_previous_revision IS
    'DB006 Section 5: records a comparison between the current generated aperture and a prior revision of the same aperture lineage.';

-- -----------------------------------------------------------------------------
-- Section 9 (Engineering Spec): revision snapshot helpers
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db006_snapshot_stencil_project(p_stencil_project_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT to_jsonb(sp.*) FROM app.stencil_projects sp WHERE sp.id = p_stencil_project_id;
$$;

COMMENT ON FUNCTION app.fn_db006_snapshot_stencil_project IS
    'DB006 Section 9: serializes current stencil project row state for revision history.';

CREATE OR REPLACE FUNCTION app.fn_db006_snapshot_generated_aperture(p_generated_aperture_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT to_jsonb(ga.*) FROM app.generated_apertures ga WHERE ga.id = p_generated_aperture_id;
$$;

COMMENT ON FUNCTION app.fn_db006_snapshot_generated_aperture IS
    'DB006 Section 9: serializes current generated aperture row state for revision history.';

-- -----------------------------------------------------------------------------
-- Section 8 (Engineering Spec Section 10): approval workflow / state transitions
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION app.fn_db006_transition_stencil_status(
    p_stencil_project_id uuid,
    p_new_status          text,
    p_notes                text DEFAULT NULL,
    p_transitioned_by        uuid DEFAULT app.current_engineer_id()
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_status text;
    v_allowed        boolean := false;
BEGIN
    SELECT release_status INTO v_current_status FROM app.stencil_projects WHERE id = p_stencil_project_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'stencil project % not found', p_stencil_project_id;
    END IF;

    -- Allowed forward transitions per Engineering Spec Section 10 approval workflow,
    -- plus a rejection path back to DRAFT from ENGINEERING_REVIEW.
    v_allowed := (v_current_status, p_new_status) IN (
        ('DRAFT', 'ENGINEERING_REVIEW'),
        ('ENGINEERING_REVIEW', 'APPROVED'),
        ('ENGINEERING_REVIEW', 'DRAFT'),
        ('APPROVED', 'RELEASED'),
        ('APPROVED', 'DRAFT'),
        ('RELEASED', 'ARCHIVED')
    );

    IF NOT v_allowed THEN
        RAISE EXCEPTION 'illegal stencil status transition from % to %', v_current_status, p_new_status;
    END IF;

    UPDATE app.stencil_projects
       SET release_status = p_new_status,
           approved_by = CASE WHEN p_new_status = 'APPROVED' THEN p_transitioned_by ELSE approved_by END,
           approved_at = CASE WHEN p_new_status = 'APPROVED' THEN now() ELSE approved_at END,
           released_by = CASE WHEN p_new_status = 'RELEASED' THEN p_transitioned_by ELSE released_by END,
           released_at = CASE WHEN p_new_status = 'RELEASED' THEN now() ELSE released_at END,
           archived_at = CASE WHEN p_new_status = 'ARCHIVED' THEN now() ELSE archived_at END
     WHERE id = p_stencil_project_id;

    INSERT INTO app.stencil_project_approvals (
        organization_id, stencil_project_id, from_status, to_status, transitioned_by, notes
    )
    SELECT organization_id, id, v_current_status, p_new_status, p_transitioned_by, p_notes
      FROM app.stencil_projects WHERE id = p_stencil_project_id;

    PERFORM app.fn_notify_change('stencil_project_status_changed', p_stencil_project_id);
END;
$$;

COMMENT ON FUNCTION app.fn_db006_transition_stencil_status IS
    'DB006 Section 8: enforces the allowed release-status state machine (Draft -> Engineering Review -> Approved -> Released -> Archived, with a rejection path back to Draft) and logs every transition immutably.';

CREATE OR REPLACE FUNCTION app.fn_db006_create_next_stencil_revision(
    p_stencil_project_id uuid,
    p_change_summary       text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    r_current    app.stencil_projects%ROWTYPE;
    v_new_id     uuid;
BEGIN
    SELECT * INTO r_current FROM app.stencil_projects WHERE id = p_stencil_project_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'stencil project % not found', p_stencil_project_id;
    END IF;

    UPDATE app.stencil_projects SET is_current = false WHERE id = p_stencil_project_id;

    INSERT INTO app.stencil_projects (
        organization_id, project_id, pcb_revision_reference, stencil_code, stencil_name,
        variant_type, stencil_thickness_mm, revision_number, is_current, release_status, notes
    ) VALUES (
        r_current.organization_id, r_current.project_id, r_current.pcb_revision_reference,
        r_current.stencil_code, r_current.stencil_name, r_current.variant_type,
        r_current.stencil_thickness_mm, r_current.revision_number + 1, true, 'DRAFT',
        coalesce(p_change_summary, 'New revision created from ' || r_current.revision_number)
    )
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$;

COMMENT ON FUNCTION app.fn_db006_create_next_stencil_revision IS
    'DB006 Section 9: creates a new stencil project revision (always starting at DRAFT), since a released/archived stencil is immutable and all further modification must occur on a new revision.';
