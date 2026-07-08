-- =============================================================================
-- StencilPro Expert Enterprise
-- DB005: Land Pattern & Aperture Intelligence Engine
-- File: DB005_Seed.sql
-- Purpose: Reference/seed data for DB005: global lookups (shapes, defects,
--          surface finishes) plus a representative starter set of package
--          families and engineering strategies as specified in the module
--          requirements (QFN thermal pad, BGA, 0402 passive).
--
-- Global lookup tables (aperture_shape_types, stencil_defect_types,
-- surface_finish_types) are organization-agnostic and seeded once.
-- Organization-scoped seed rows below use a placeholder organization_id
-- variable resolved via the existing default-organization convention from
-- DB001; replace app.fn_default_seed_organization_id() with the actual
-- seeding helper if it differs from prior modules.
-- =============================================================================

SET search_path = app, public;

-- -----------------------------------------------------------------------------
-- Section 3: Aperture Shape Types
-- -----------------------------------------------------------------------------

INSERT INTO app.aperture_shape_types (shape_code, shape_name, requires_radius, requires_segment_config, requires_polygon_geometry, description) VALUES
('RECTANGLE',              'Rectangle',                false, false, false, 'Standard rectangular aperture, most common opening for chip and IC leads.'),
('ROUNDED_RECTANGLE',      'Rounded Rectangle',         true,  false, false, 'Rectangle with rounded corners; improves paste release versus sharp corners.'),
('SQUARE',                 'Square',                    false, false, false, 'Equal-sided rectangular aperture, typically for square pads.'),
('CIRCLE',                 'Circle',                    false, false, false, 'Round aperture, common for round pads and via-in-pad applications.'),
('OVAL',                   'Oval',                      false, false, false, 'Elongated round aperture for oblong pads.'),
('HOME_PLATE',             'Home Plate',                false, false, false, 'Five-sided pentagon aperture used to reduce solder wicking on gull-wing leads.'),
('INVERTED_HOME_PLATE',    'Inverted Home Plate',       false, false, false, 'Home plate geometry mirrored to reduce paste at the lead toe.'),
('WINDOW_PANE',            'Window Pane',               false, true,  false, 'Thermal pad subdivided into a grid of smaller openings to manage paste volume and outgassing.'),
('SEGMENTED_THERMAL_PAD',  'Segmented Thermal Pad',     false, true,  false, 'Thermal pad subdivided into parallel strips, primary strategy for large QFN/DFN thermal pads.'),
('CROSS',                  'Cross',                     false, false, false, 'Cross-shaped aperture reducing center paste volume while maintaining edge contact.'),
('DOG_BONE',               'Dog Bone',                  false, false, false, 'Narrow-waisted aperture connecting two wider ends, used for very fine-pitch leads.'),
('D_SHAPE',                'D Shape',                   false, false, false, 'Half-oval aperture used for polarized or asymmetric pad geometries.'),
('CUSTOM_POLYGON',         'Custom Polygon',            false, false, true,  'Arbitrary vertex-defined polygon for non-standard or highly optimized apertures.');

-- -----------------------------------------------------------------------------
-- Section 5: Stencil Defect Types
-- -----------------------------------------------------------------------------

INSERT INTO app.stencil_defect_types (defect_code, defect_name, description, default_severity, default_confidence) VALUES
('BRIDGING',            'Solder Bridging',        'Adjacent paste deposits merge during reflow, forming an unwanted electrical short.',       'CRITICAL', 85),
('INSUFFICIENT_PASTE',  'Insufficient Paste',     'Too little paste is deposited, risking open joints or weak solder connections.',            'HIGH',     80),
('EXCESS_PASTE',        'Excess Paste',           'Too much paste is deposited, increasing bridging and solder ball risk.',                    'MEDIUM',   75),
('POOR_PASTE_RELEASE',  'Poor Paste Release',     'Paste sticks to the aperture wall instead of transferring fully to the pad.',                'MEDIUM',   70),
('APERTURE_CLOGGING',   'Aperture Clogging',      'Paste accumulates and hardens inside small or high-aspect-ratio apertures over repeated prints.', 'MEDIUM', 65),
('PASTE_SMEARING',      'Paste Smearing',         'Paste is dragged across the board surface, typically from stencil separation issues.',      'MEDIUM',   70),
('PASTE_BEADING',       'Paste Beading',          'Small satellite paste deposits form outside the intended aperture boundary.',                'LOW',      60),
('THERMAL_PAD_VOIDING', 'Thermal Pad Voiding',    'Trapped gas or uneven paste deposition creates voids under large thermal pads.',             'HIGH',     75),
('SLUMPING',            'Paste Slumping',         'Deposited paste spreads laterally before reflow, risking bridging between fine-pitch pads.', 'MEDIUM',   65);

-- -----------------------------------------------------------------------------
-- Section 2: Surface Finish Types
-- -----------------------------------------------------------------------------

INSERT INTO app.surface_finish_types (finish_code, finish_name, description) VALUES
('ENIG',              'Electroless Nickel Immersion Gold', 'Flat, solderable finish widely used for fine-pitch and BGA applications.'),
('HASL',              'Hot Air Solder Leveling (Leaded)',   'Traditional tin-lead finish, uneven surface, less suited to fine pitch.'),
('LEAD_FREE_HASL',    'Lead-Free HASL',                     'RoHS-compliant HASL variant with similar surface characteristics.'),
('OSP',               'Organic Solderability Preservative', 'Thin organic coating, flat surface, limited shelf life.'),
('IMMERSION_TIN',     'Immersion Tin',                       'Flat matte finish, good solderability, tin whisker considerations.'),
('IMMERSION_SILVER',  'Immersion Silver',                    'Flat finish with good solderability, sensitive to tarnishing/handling.'),
('ENEPIG',            'Electroless Nickel Electroless Palladium Immersion Gold', 'Premium finish for wire bonding and fine-pitch reliability.'),
('HARD_GOLD',         'Hard Gold',                           'Wear-resistant finish typically used on edge connectors/contacts.');

-- -----------------------------------------------------------------------------
-- Section 5 satellite data: root causes, prevention methods, recommended
-- apertures per defect (representative, expandable by engineers over time)
-- -----------------------------------------------------------------------------

INSERT INTO app.stencil_defect_root_causes (organization_id, defect_type_id, root_cause_description, likelihood)
SELECT app.fn_default_seed_organization_id(), dt.id, rc.description, rc.likelihood
FROM app.stencil_defect_types dt
JOIN (VALUES
    ('BRIDGING', 'Excessive paste volume relative to pad pitch', 'HIGH'),
    ('BRIDGING', 'Aperture width too close to adjacent pad clearance', 'MEDIUM'),
    ('INSUFFICIENT_PASTE', 'Area ratio below IPC-recommended 0.66 minimum', 'HIGH'),
    ('INSUFFICIENT_PASTE', 'Poor paste release from high-aspect-ratio aperture', 'MEDIUM'),
    ('EXCESS_PASTE', 'Stencil thickness too great for pad geometry', 'HIGH'),
    ('POOR_PASTE_RELEASE', 'Aperture wall angle too steep for stencil thickness', 'HIGH'),
    ('APERTURE_CLOGGING', 'Aperture too small relative to paste particle size', 'MEDIUM'),
    ('PASTE_SMEARING', 'Poor stencil separation speed or angle during print stroke', 'MEDIUM'),
    ('PASTE_BEADING', 'Stencil understside contamination or poor cleaning cycle', 'MEDIUM'),
    ('THERMAL_PAD_VOIDING', 'Single large aperture trapping outgassing under thermal pad', 'HIGH'),
    ('SLUMPING', 'Excess paste volume combined with fine pad pitch', 'MEDIUM')
) AS rc(defect_code, description, likelihood) ON rc.defect_code = dt.defect_code;

INSERT INTO app.stencil_defect_prevention_methods (organization_id, defect_type_id, prevention_method, effectiveness_rating)
SELECT app.fn_default_seed_organization_id(), dt.id, pm.method, pm.effectiveness
FROM app.stencil_defect_types dt
JOIN (VALUES
    ('BRIDGING', 'Apply aperture reduction percentage on fine-pitch leads', 'HIGH'),
    ('INSUFFICIENT_PASTE', 'Increase aperture area ratio above 0.66 where pad geometry allows', 'HIGH'),
    ('EXCESS_PASTE', 'Reduce stencil thickness or apply local aperture reduction', 'HIGH'),
    ('POOR_PASTE_RELEASE', 'Use trapezoidal (laser-cut, electropolished) aperture walls', 'HIGH'),
    ('APERTURE_CLOGGING', 'Select paste particle type (e.g. Type 4/5) matched to aperture size', 'MEDIUM'),
    ('PASTE_SMEARING', 'Optimize stencil separation speed and under-stencil cleaning frequency', 'MEDIUM'),
    ('PASTE_BEADING', 'Increase under-stencil wipe frequency', 'MEDIUM'),
    ('THERMAL_PAD_VOIDING', 'Use segmented thermal pad or window pane aperture strategy', 'HIGH'),
    ('SLUMPING', 'Apply aperture reduction and confirm paste rheology/shelf life', 'MEDIUM')
) AS pm(defect_code, method, effectiveness) ON pm.defect_code = dt.defect_code;

INSERT INTO app.stencil_defect_recommended_apertures (organization_id, defect_type_id, shape_type_id, recommended_reduction_percent, recommended_expansion_percent, notes)
SELECT app.fn_default_seed_organization_id(), dt.id, st.id, ra.reduction, ra.expansion, ra.notes
FROM app.stencil_defect_types dt
JOIN (VALUES
    ('BRIDGING', 'ROUNDED_RECTANGLE', 10.0, 0.0, 'Rounded corners plus reduction lowers bridging risk on fine-pitch leads.'),
    ('THERMAL_PAD_VOIDING', 'SEGMENTED_THERMAL_PAD', 12.0, 0.0, 'Primary QFN/DFN thermal pad strategy; allows outgassing between segments.'),
    ('THERMAL_PAD_VOIDING', 'WINDOW_PANE', 12.0, 0.0, 'Alternative to segmented strips for very large thermal pads.'),
    ('INSUFFICIENT_PASTE', 'RECTANGLE', 0.0, 5.0, 'Slight expansion where clearance allows, to raise area ratio above 0.66.')
) AS ra(defect_code, shape_code, reduction, expansion, notes)
    ON ra.defect_code = dt.defect_code
JOIN app.aperture_shape_types st ON st.shape_code = ra.shape_code;

-- -----------------------------------------------------------------------------
-- Section 1 / 4: Representative Package Families and Engineering Strategies
-- -----------------------------------------------------------------------------

INSERT INTO app.package_families (organization_id, family_code, family_name, category, description, typical_pin_count_min, typical_pin_count_max, has_thermal_pad, standard_reference, status)
VALUES
(app.fn_default_seed_organization_id(), '0402', '0402 Chip Passive', 'PASSIVE', 'Two-terminal chip resistor/capacitor, imperial 0402 size.', 2, 2, false, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), '0603', '0603 Chip Passive', 'PASSIVE', 'Two-terminal chip resistor/capacitor, imperial 0603 size.', 2, 2, false, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), '0805', '0805 Chip Passive', 'PASSIVE', 'Two-terminal chip resistor/capacitor, imperial 0805 size.', 2, 2, false, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'SOT23', 'SOT-23', 'DISCRETE', 'Small outline transistor package, typically 3-6 leads.', 3, 6, false, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'SOIC', 'SOIC', 'IC_LEADED', 'Small outline IC, gull-wing leaded package.', 8, 28, false, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'QFP', 'QFP', 'IC_LEADED', 'Quad flat package, gull-wing leads on all four sides.', 32, 256, false, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'QFN', 'QFN', 'IC_LEADLESS', 'Quad flat no-lead package, typically with an exposed thermal pad.', 8, 68, true, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'DFN', 'DFN', 'IC_LEADLESS', 'Dual flat no-lead package, typically with an exposed thermal pad.', 6, 22, true, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'BGA', 'BGA', 'BGA_CSP', 'Ball grid array package, area-array solder balls.', 24, 2500, false, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'CSP', 'Chip Scale Package', 'BGA_CSP', 'Area-array package approximately the size of the die.', 8, 400, false, 'IPC-7351', 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'CONNECTOR', 'Connector', 'CONNECTOR', 'Board-to-board or board-to-wire connector footprint.', 2, 200, false, NULL, 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'LED', 'LED', 'LED', 'Surface mount light-emitting diode package.', 2, 6, false, NULL, 'ACTIVE'),
(app.fn_default_seed_organization_id(), 'CRYSTAL', 'Crystal/Oscillator', 'CRYSTAL_OSCILLATOR', 'Surface mount crystal or oscillator package.', 2, 6, false, NULL, 'ACTIVE');

INSERT INTO app.engineering_strategies (
    organization_id, strategy_code, strategy_name, primary_package_family_id,
    recommended_shape_type_id, recommended_reduction_percent, recommended_expansion_percent,
    rationale, expected_benefit, status
)
SELECT
    app.fn_default_seed_organization_id(),
    s.strategy_code,
    s.strategy_name,
    pf.id,
    st.id,
    s.reduction,
    s.expansion,
    s.rationale,
    s.expected_benefit,
    'ACTIVE'
FROM (VALUES
    ('QFN_THERMAL_WINDOW_PANE', 'QFN Thermal Pad - Window Pane', 'QFN', 'WINDOW_PANE', 12.0, 0.0,
     'Subdividing the QFN thermal pad aperture into a window-pane grid controls paste volume and allows trapped gas to escape during reflow, reducing void formation.',
     'Reduces thermal pad voiding and improves thermal/ground connection reliability.'),
    ('BGA_ROUNDED_RECTANGLE', 'BGA - Rounded Rectangle', 'BGA', 'ROUNDED_RECTANGLE', 0.0, 0.0,
     'Rounded rectangle apertures improve paste release consistency across the area array compared to sharp-cornered rectangles, supporting uniform ball formation.',
     'More consistent paste transfer efficiency across the array, reducing insufficient-paste defects.'),
    ('PASSIVE_0402_REDUCTION', '0402 Passive - Reduction', '0402', 'RECTANGLE', 5.0, 0.0,
     'A modest reduction on 0402 apertures compensates for the tight pad pitch and lowers bridging risk without dropping the area ratio below the IPC-recommended minimum.',
     'Lowers bridging risk on tightly spaced 0402 passives while maintaining adequate paste volume.')
) AS s(strategy_code, strategy_name, family_code, shape_code, reduction, expansion, rationale, expected_benefit)
JOIN app.package_families pf ON pf.family_code = s.family_code AND pf.organization_id = app.fn_default_seed_organization_id()
JOIN app.aperture_shape_types st ON st.shape_code = s.shape_code;

-- Link strategies to their addressed defects
INSERT INTO app.engineering_strategy_defects (organization_id, engineering_strategy_id, defect_type_id, relationship_note)
SELECT app.fn_default_seed_organization_id(), es.id, dt.id, link.note
FROM app.engineering_strategies es
JOIN (VALUES
    ('QFN_THERMAL_WINDOW_PANE', 'THERMAL_PAD_VOIDING', 'Primary mitigation strategy for thermal pad voiding on QFN packages.'),
    ('BGA_ROUNDED_RECTANGLE', 'INSUFFICIENT_PASTE', 'Improves paste release consistency, reducing insufficient paste occurrences.'),
    ('PASSIVE_0402_REDUCTION', 'BRIDGING', 'Reduction lowers solder bridging risk between adjacent 0402 pads.')
) AS link(strategy_code, defect_code, note) ON link.strategy_code = es.strategy_code
JOIN app.stencil_defect_types dt ON dt.defect_code = link.defect_code;

-- Reference citations for seeded strategies
INSERT INTO app.engineering_strategy_references (organization_id, engineering_strategy_id, reference_type, reference_citation, reference_url)
SELECT app.fn_default_seed_organization_id(), es.id, 'IPC_STANDARD', ref.citation, NULL
FROM app.engineering_strategies es
JOIN (VALUES
    ('QFN_THERMAL_WINDOW_PANE', 'IPC-7525 Stencil Design Guidelines - thermal pad aperture subdivision recommendations'),
    ('BGA_ROUNDED_RECTANGLE', 'IPC-7525 Stencil Design Guidelines - area array aperture geometry recommendations'),
    ('PASSIVE_0402_REDUCTION', 'IPC-7525 Stencil Design Guidelines - fine-pitch passive aperture reduction guidance')
) AS ref(strategy_code, citation) ON ref.strategy_code = es.strategy_code;

-- Link defects to package families most susceptible
INSERT INTO app.stencil_defect_package_families (organization_id, defect_type_id, package_family_id, susceptibility_rating)
SELECT app.fn_default_seed_organization_id(), dt.id, pf.id, link.rating
FROM app.stencil_defect_types dt
JOIN (VALUES
    ('THERMAL_PAD_VOIDING', 'QFN', 'HIGH'),
    ('THERMAL_PAD_VOIDING', 'DFN', 'HIGH'),
    ('BRIDGING', '0402', 'MEDIUM'),
    ('BRIDGING', 'SOIC', 'LOW'),
    ('INSUFFICIENT_PASTE', 'BGA', 'MEDIUM'),
    ('SLUMPING', '0402', 'MEDIUM')
) AS link(defect_code, family_code, rating) ON link.defect_code = dt.defect_code
JOIN app.package_families pf ON pf.family_code = link.family_code AND pf.organization_id = app.fn_default_seed_organization_id();

-- Link recommended strategies per defect (traceable confidence)
INSERT INTO app.stencil_defect_recommended_strategies (organization_id, defect_type_id, engineering_strategy_id, confidence)
SELECT app.fn_default_seed_organization_id(), dt.id, es.id, link.confidence
FROM app.stencil_defect_types dt
JOIN (VALUES
    ('THERMAL_PAD_VOIDING', 'QFN_THERMAL_WINDOW_PANE', 90.0),
    ('INSUFFICIENT_PASTE', 'BGA_ROUNDED_RECTANGLE', 75.0),
    ('BRIDGING', 'PASSIVE_0402_REDUCTION', 80.0)
) AS link(defect_code, strategy_code, confidence) ON link.defect_code = dt.defect_code
JOIN app.engineering_strategies es ON es.strategy_code = link.strategy_code;
