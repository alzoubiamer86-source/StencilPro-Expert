-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-003: PCB Assemblies & Components
-- File: DB003_Seed.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Seed data for:
--   pcb_surface_finishes  (10 standard finishes)
--   pcb_materials         (8 standard laminate types)
--   pcb_thickness_options (9 standard thicknesses)
--   application_config    (PCB module settings)
-- =============================================================================
-- Fixed UUID strategy: 00000003-{table_seq}-{record_seq}
-- =============================================================================

BEGIN;

-- =============================================================================
-- PCB SURFACE FINISHES
-- =============================================================================

INSERT INTO pcb_surface_finishes (
    id, name, abbreviation,
    is_rohs_compliant, is_lead_free,
    flatness_rating, coplanarity_um,
    shelf_life_months, solderability_rating,
    typical_thickness_um, wettability_notes, ipc_specification,
    is_active, is_system_record,
    created_at, updated_at
) VALUES

-- ENIG — most common high-reliability finish
(
    '00000003-0001-0001-0001-000000000001',
    'Electroless Nickel Immersion Gold',
    'ENIG',
    TRUE, TRUE,
    'excellent', 1.5,
    12, 'excellent',
    0.1,
    'Superior flatness and excellent solderability. Gold dissolves into solder during reflow, '
    'leaving nickel as the primary soldering surface. Susceptible to black pad defect if phosphorus '
    'content in nickel is not controlled. Best choice for fine-pitch and BGA applications.',
    'IPC-4552',
    TRUE, TRUE, NOW(), NOW()
),

-- HASL Lead-Free
(
    '00000003-0001-0001-0001-000000000002',
    'Hot Air Solder Leveling (Lead-Free)',
    'HASL-LF',
    TRUE, TRUE,
    'poor', 15.0,
    12, 'good',
    15.0,
    'Poor surface planarity due to meniscus formation during leveling. Not suitable for fine-pitch '
    'components (pitch < 0.65mm) or BGAs. Lower cost than ENIG. Uses SAC alloy. '
    'Coplanarity variation is the primary limitation for SMT paste printing.',
    'IPC-A-610',
    TRUE, TRUE, NOW(), NOW()
),

-- HASL Lead (legacy / non-RoHS)
(
    '00000003-0001-0001-0001-000000000003',
    'Hot Air Solder Leveling (Leaded)',
    'HASL',
    FALSE, FALSE,
    'poor', 15.0,
    12, 'excellent',
    15.0,
    'Traditional SnPb HASL. Excellent solderability but poor planarity. '
    'Not RoHS compliant. Use restricted to exempted military, aerospace, or legacy applications. '
    'Same coplanarity limitations as lead-free HASL.',
    'IPC-A-610',
    TRUE, TRUE, NOW(), NOW()
),

-- OSP
(
    '00000003-0001-0001-0001-000000000004',
    'Organic Solderability Preservative',
    'OSP',
    TRUE, TRUE,
    'excellent', 1.0,
    6, 'good',
    0.5,
    'Excellent flatness — copper surface with thin organic coating. '
    'Very short shelf life (6 months) and degrades rapidly at elevated temperatures. '
    'Requires tight time-to-reflow control and nitrogen atmosphere for best results. '
    'Not suitable for multiple reflow cycles or boards requiring ICT bed-of-nails test. '
    'Lowest cost among lead-free options.',
    'IPC-4553',
    TRUE, TRUE, NOW(), NOW()
),

-- Immersion Silver
(
    '00000003-0001-0001-0001-000000000005',
    'Immersion Silver',
    'ImAg',
    TRUE, TRUE,
    'excellent', 1.5,
    6, 'excellent',
    0.25,
    'Excellent flatness and solderability. Silver can tarnish (creep corrosion) in sulfur-rich '
    'environments. Shelf life is 6 months in sealed packaging. Suitable for fine-pitch and BGAs. '
    'May show silver migration concerns in high-humidity environments if flux residues are present.',
    'IPC-4553',
    TRUE, TRUE, NOW(), NOW()
),

-- Immersion Tin
(
    '00000003-0001-0001-0001-000000000006',
    'Immersion Tin',
    'ImSn',
    TRUE, TRUE,
    'good', 2.5,
    6, 'good',
    1.0,
    'Good flatness. Tin whisker growth is a known reliability concern in certain environments. '
    'Tin pest can occur at temperatures below -13°C. Suitable for press-fit connectors. '
    'Shelf life 6 months. May form tin-copper IMC under pads during storage, reducing solderability.',
    'IPC-4554',
    TRUE, TRUE, NOW(), NOW()
),

-- ENEPIG
(
    '00000003-0001-0001-0001-000000000007',
    'Electroless Nickel Electroless Palladium Immersion Gold',
    'ENEPIG',
    TRUE, TRUE,
    'excellent', 1.0,
    12, 'excellent',
    0.2,
    'Premium finish combining advantages of ENIG with palladium barrier layer. '
    'Eliminates black pad defect risk. Excellent for wire bonding and soldering. '
    'Higher cost than ENIG. Best choice for mixed-technology boards requiring both '
    'SMT soldering and wire bonding. Palladium layer prevents nickel oxidation.',
    'IPC-4556',
    TRUE, TRUE, NOW(), NOW()
),

-- Hard Gold
(
    '00000003-0001-0001-0001-000000000008',
    'Hard Gold (Electrolytic)',
    'Hard-Au',
    TRUE, TRUE,
    'excellent', 0.5,
    24, 'fair',
    1.27,
    'Used primarily for edge connectors and contact areas requiring wear resistance. '
    'Not recommended as primary solderable surface — gold thickness inhibits solder wetting '
    'and gold embrittlement can occur. Gold content in solder joint should be < 3% by weight. '
    'Excellent shelf life (24 months). Typically applied selectively to contact areas only.',
    NULL,
    TRUE, TRUE, NOW(), NOW()
),

-- Direct Immersion Gold (DIG)
(
    '00000003-0001-0001-0001-000000000009',
    'Direct Immersion Gold',
    'DIG',
    TRUE, TRUE,
    'excellent', 1.0,
    12, 'good',
    0.08,
    'Thin gold layer directly on copper. No nickel barrier. Lower cost than ENIG. '
    'Suitable for simple assemblies. Gold layer is very thin (< 0.1 µm) — '
    'solderability depends on clean copper surface. Not suitable for long storage.',
    NULL,
    TRUE, TRUE, NOW(), NOW()
),

-- ENIG + wire bond
(
    '00000003-0001-0001-0001-000000000010',
    'Electroless Nickel Immersion Gold (Wire Bond Grade)',
    'ENIG-WB',
    TRUE, TRUE,
    'excellent', 1.0,
    12, 'excellent',
    0.15,
    'ENIG with tighter gold thickness specification for wire bonding compatibility. '
    'Gold thickness 0.05–0.15 µm for soldering; 0.1–0.3 µm for wire bonding. '
    'Dual-use: SMT soldering on component pads and wire bonding on die pads.',
    'IPC-4552',
    TRUE, TRUE, NOW(), NOW()
)

ON CONFLICT (abbreviation) DO NOTHING;

-- =============================================================================
-- PCB MATERIALS
-- =============================================================================

INSERT INTO pcb_materials (
    id, name, material_type, description,
    tg_min_c, tg_max_c, td_c,
    cte_x_ppm_per_c, cte_z_ppm_per_c,
    dk_at_1ghz, df_at_1ghz,
    is_halogen_free, is_rohs_compliant, is_high_speed_rated,
    max_operating_temp_c, typical_thickness_range,
    common_applications, ipc_grade,
    is_active, is_system_record,
    created_at, updated_at
) VALUES

-- Standard FR4
(
    '00000003-0002-0001-0001-000000000001',
    'Standard FR4 (Tg 130°C)',
    'fr4',
    'Standard epoxy glass laminate. Most common PCB substrate material. '
    'Suitable for most consumer and industrial applications. '
    'Not suitable for high-frequency designs or applications requiring Tg > 130°C.',
    125, 135, 300,
    14.0, 60.0,
    4.5, 0.020,
    FALSE, TRUE, FALSE,
    125, '0.2mm – 4.0mm',
    'Consumer electronics, industrial controls, general purpose',
    '/21',
    TRUE, TRUE, NOW(), NOW()
),

-- High Tg FR4
(
    '00000003-0002-0001-0001-000000000002',
    'High Tg FR4 (Tg 170°C)',
    'fr4_high_tg',
    'High glass transition temperature epoxy glass laminate. '
    'Required for lead-free reflow (peak temps > 240°C) where board must withstand '
    'repeated thermal cycling. Lower Z-axis CTE reduces via barrel cracking risk.',
    165, 180, 330,
    13.0, 45.0,
    4.4, 0.018,
    FALSE, TRUE, FALSE,
    170, '0.2mm – 6.0mm',
    'Lead-free assembly, automotive, industrial, high-density interconnect',
    '/98',
    TRUE, TRUE, NOW(), NOW()
),

-- Halogen-Free FR4
(
    '00000003-0002-0001-0001-000000000003',
    'Halogen-Free FR4 (Tg 150°C)',
    'fr4',
    'FR4 laminate with halogen-free flame retardant system (phosphorus/nitrogen based). '
    'IPC-4101 /92 or /94 grade. Required for REACH compliance. '
    'Slightly higher Dk and Df than standard FR4.',
    145, 160, 320,
    14.0, 50.0,
    4.6, 0.022,
    TRUE, TRUE, FALSE,
    150, '0.2mm – 4.0mm',
    'Consumer electronics (RoHS + REACH), European market products',
    '/92',
    TRUE, TRUE, NOW(), NOW()
),

-- Rogers 4003C
(
    '00000003-0002-0001-0001-000000000004',
    'Rogers RO4003C',
    'rogers',
    'Thermoset ceramic-filled hydrocarbon laminate. Low loss tangent for RF/microwave applications. '
    'Dimensionally stable. Compatible with standard FR4 PCB processes. '
    'Not suitable for multiple reflow cycles without careful profile management.',
    280, 280, 425,
    11.0, 46.0,
    3.55, 0.0027,
    TRUE, TRUE, TRUE,
    200, '0.2mm – 3.0mm',
    'RF/microwave circuits, antennas, power amplifiers, 5G base stations',
    NULL,
    TRUE, TRUE, NOW(), NOW()
),

-- Rogers 4350B
(
    '00000003-0002-0001-0001-000000000005',
    'Rogers RO4350B',
    'rogers',
    'Low loss ceramic-filled PTFE composite. Higher Dk than RO4003C. '
    'Excellent for impedance-controlled designs requiring tighter dimensional tolerances. '
    'Lead-free process compatible.',
    280, 280, 390,
    11.0, 46.0,
    3.48, 0.0037,
    TRUE, TRUE, TRUE,
    200, '0.2mm – 3.0mm',
    'Automotive radar (77GHz), satellite communication, high-frequency RF',
    NULL,
    TRUE, TRUE, NOW(), NOW()
),

-- Polyimide (Kapton-based)
(
    '00000003-0002-0001-0001-000000000006',
    'Polyimide (High Temperature)',
    'polyimide',
    'Polyimide glass laminate. Excellent thermal stability and flexibility. '
    'Used in high-temperature applications and flexible circuits. '
    'Higher cost than FR4. Excellent chemical resistance.',
    250, 270, 400,
    12.0, 50.0,
    4.2, 0.015,
    TRUE, TRUE, FALSE,
    260, '0.05mm – 2.0mm',
    'Aerospace, military, high-temperature industrial, flexible circuits',
    '/79',
    TRUE, TRUE, NOW(), NOW()
),

-- Aluminum (IMS)
(
    '00000003-0002-0001-0001-000000000007',
    'Aluminum (Insulated Metal Substrate)',
    'aluminum',
    'Metal core PCB with aluminum base for superior thermal management. '
    'Dielectric layer bonded to aluminum substrate. '
    'Used where thermal dissipation is critical. '
    'Limited to single or double-sided designs. Drilling requires special tooling.',
    130, 150, NULL,
    20.0, NULL,
    NULL, NULL,
    FALSE, TRUE, FALSE,
    150, '0.8mm – 3.0mm',
    'LED lighting, power electronics, motor drives, automotive lighting',
    NULL,
    TRUE, TRUE, NOW(), NOW()
),

-- Ceramic (LTCC/HTCC)
(
    '00000003-0002-0001-0001-000000000008',
    'Ceramic (Low-Temperature Co-fired)',
    'ceramic',
    'LTCC (Low-Temperature Co-fired Ceramic) substrate. '
    'Very low CTE closely matched to silicon devices. '
    'Excellent high-frequency performance. '
    'Hermetic packaging capability. Very high cost. '
    'Used in RF modules, military, medical implants.',
    NULL, NULL, 1000,
    6.0, 6.0,
    7.8, 0.002,
    TRUE, TRUE, TRUE,
    300, '0.1mm – 2.0mm',
    'RF modules, medical implants, military, aerospace sensor packages',
    NULL,
    TRUE, TRUE, NOW(), NOW()
)

ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- PCB THICKNESS OPTIONS
-- =============================================================================

INSERT INTO pcb_thickness_options (
    id, thickness_mm, thickness_label,
    is_standard, warpage_risk,
    typical_layer_count_range, smt_support_notes,
    is_active, created_at, updated_at
) VALUES

(
    '00000003-0003-0001-0001-000000000001',
    0.40, '0.4mm',
    FALSE, 'very_high',
    '1–2 layers',
    'Very thin board. Requires full underside support tooling during paste printing. '
    'Significant warpage risk during reflow. Panel printing strongly recommended.',
    TRUE, NOW(), NOW()
),
(
    '00000003-0003-0001-0001-000000000002',
    0.60, '0.6mm',
    FALSE, 'high',
    '1–4 layers',
    'Thin board. Requires support tooling. Warpage during reflow is a concern for larger boards.',
    TRUE, NOW(), NOW()
),
(
    '00000003-0003-0001-0001-000000000003',
    0.80, '0.8mm',
    TRUE, 'medium',
    '2–6 layers',
    'Common thin board thickness. Support tooling recommended for boards > 100mm on any side.',
    TRUE, NOW(), NOW()
),
(
    '00000003-0003-0001-0001-000000000004',
    1.00, '1.0mm',
    TRUE, 'low',
    '2–8 layers',
    'Standard thin board. Suitable for most SMT processes with standard support.',
    TRUE, NOW(), NOW()
),
(
    '00000003-0003-0001-0001-000000000005',
    1.60, '1.6mm',
    TRUE, 'low',
    '2–16 layers',
    'Most common PCB thickness. Standard SMT printing support is adequate for most board sizes. '
    'Good stiffness for most component weights.',
    TRUE, NOW(), NOW()
),
(
    '00000003-0003-0001-0001-000000000006',
    2.00, '2.0mm',
    TRUE, 'low',
    '4–20 layers',
    'Heavy-duty standard thickness. Minimal warpage risk. Good for large boards and heavy connectors.',
    TRUE, NOW(), NOW()
),
(
    '00000003-0003-0001-0001-000000000007',
    2.40, '2.4mm',
    TRUE, 'low',
    '6–24 layers',
    'Thick board. Excellent stiffness. Consider via aspect ratio for blind/buried vias.',
    TRUE, NOW(), NOW()
),
(
    '00000003-0003-0001-0001-000000000008',
    3.20, '3.2mm',
    TRUE, 'low',
    '8–32 layers',
    'Heavy industrial board. Minimal warpage. High thermal mass — ensure reflow profile '
    'accounts for extended time to reach liquidus at all component locations.',
    TRUE, NOW(), NOW()
),
(
    '00000003-0003-0001-0001-000000000009',
    4.00, '4.0mm',
    FALSE, 'low',
    '12–40 layers',
    'Very thick specialty board. Very high thermal mass. '
    'Reflow profile must be carefully profiled with thermocouples at multiple locations. '
    'Drill aspect ratios for through-hole vias can be challenging.',
    TRUE, NOW(), NOW()
)

ON CONFLICT (thickness_mm) DO NOTHING;

-- =============================================================================
-- APPLICATION CONFIG — PCB module settings
-- =============================================================================

INSERT INTO application_config (
    id, config_key, config_value, config_type, environment,
    description, created_at, updated_at
) VALUES

('00000003-0004-0001-0001-000000000001',
 'pcb.max_design_files_per_revision',
 '200',
 'integer', 'all',
 'Maximum number of design files (Gerber layers, ODB++, etc.) per PCB revision.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000002',
 'pcb.max_component_placements_per_revision',
 '10000',
 'integer', 'all',
 'Maximum component placements per PCB revision. '
 'Designs exceeding this threshold trigger a performance warning.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000003',
 'pcb.design_file_max_size_bytes',
 '104857600',
 'integer', 'all',
 'Maximum size for a single design file upload (100 MB).',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000004',
 'pcb.fine_pitch_threshold_mm',
 '0.5',
 'string', 'all',
 'Pitch value in mm below which fine-pitch rule groups are activated '
 'in the Intelligence Engine.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000005',
 'pcb.ultra_fine_pitch_threshold_mm',
 '0.4',
 'string', 'all',
 'Pitch value in mm below which ultra-fine-pitch rule groups are activated.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000006',
 'pcb.min_pitch_for_01005_mm',
 '0.3',
 'string', 'all',
 'Minimum pitch threshold below which 01005 or smaller components are assumed present.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000007',
 'pcb.pick_place_import_batch_size',
 '500',
 'integer', 'all',
 'Number of placement rows processed per database transaction during pick-and-place import.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000008',
 'pcb.supported_pick_place_formats',
 '["pick_place_csv","odb_plus_plus","ipc_2581"]',
 'json', 'all',
 'List of supported pick-and-place file import formats.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000009',
 'pcb.default_placement_origin',
 'centroid',
 'string', 'all',
 'Default coordinate origin for component placements: centroid, pin_1, or body_center.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000010',
 'pcb.warpage_risk_thin_board_threshold_mm',
 '1.0',
 'string', 'all',
 'Board thickness at or below which warpage risk warnings are generated '
 'in the stencil design and reflow profile validation.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000011',
 'pcb.bom_max_line_items',
 '5000',
 'integer', 'all',
 'Maximum BOM line items per BOM revision.',
 NOW(), NOW()),

('00000003-0004-0001-0001-000000000012',
 'pcb.component_msl_floor_life_map',
 '{"msl_1":null,"msl_2":8760,"msl_2a":4380,"msl_3":168,"msl_4":72,"msl_5":48,"msl_5a":24,"msl_6":6}',
 'json', 'all',
 'IPC/JEDEC J-STD-020 floor life in hours by MSL level. '
 'null = unlimited. Used to generate paste floor life warnings on project timeline.',
 NOW(), NOW())

ON CONFLICT (config_key, environment) DO NOTHING;

-- =============================================================================
-- MIGRATION RECORD
-- =============================================================================

INSERT INTO schema_migrations (version_num, applied_at)
VALUES ('0003_db003_pcb_assemblies_components', NOW())
ON CONFLICT (version_num) DO NOTHING;

COMMIT;
