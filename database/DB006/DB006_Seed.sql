-- =============================================================================
-- StencilPro Expert Enterprise
-- DB006: Stencil Generation Engine
-- File: DB006_Seed.sql
-- Purpose: Reference/seed data for DB006.
--
-- DB006 is primarily a transactional workflow module (stencil projects,
-- generated apertures, decisions, overrides, validations) rather than a
-- knowledge-library module, so it introduces very little seed data. State
-- fields (release_status, layer_side, layer_technology, decision_status,
-- validation_type, override_field, comparison_type) are CHECK-constrained
-- enumerations, consistent with the DB005 convention of using CHECK
-- constraints rather than lookup tables for simple state values.
--
-- The one genuine engineering reference dataset this module owns is
-- fabrication capability limits (minimum web width, minimum aperture width,
-- minimum corner radius) per stencil technology, used by
-- app.fn_db006_validate_generated_aperture() (Engineering Spec Section 7).
-- Values below are representative industry-typical starting points for a
-- laser-cut stencil (the Version 1 default technology) and should be
-- reviewed and adjusted by an engineer against the fabricator's actual
-- qualified process capability.
--
-- Uses the same seeding convention referenced in DB005_Seed.sql:
--   app.fn_default_seed_organization_id()
-- Replace with the actual seeding helper if DB001-DB004A used a different one.
-- =============================================================================

SET search_path = app, public;

INSERT INTO app.stencil_fabrication_capabilities (
    organization_id, layer_technology, min_web_width_mm, min_aperture_width_mm, min_corner_radius_mm, notes
) VALUES
(app.fn_default_seed_organization_id(), 'LASER_CUT',        0.075, 0.100, 0.025, 'Representative starting values for standard laser-cut stainless stencil foil. Review against qualified process capability.'),
(app.fn_default_seed_organization_id(), 'ELECTROFORMED',    0.050, 0.075, 0.015, 'Electroforming supports finer web and aperture widths than laser cutting; representative starting values only.'),
(app.fn_default_seed_organization_id(), 'CHEMICAL_ETCHED',  0.100, 0.125, 0.030, 'Chemical etching has the widest minimum feature requirements of the supported technologies; representative starting values only.'),
(app.fn_default_seed_organization_id(), 'ELECTROPOLISHED',  0.075, 0.100, 0.020, 'Electropolished finish applied after laser cutting; feature minimums driven by the underlying cut process, improved release from polishing.');
