# DB-004A: Engineering Knowledge Core

**StencilPro Expert Enterprise**
**Module:** DB-004A — Engineering Knowledge Core
**PostgreSQL 16 / Supabase Compatible**
**Prerequisites:** DB-001 + DB-002 + DB-003

---

## Overview

DB-004A implements the complete Engineering Knowledge Core — the foundation of the Engineering Decision Studio. This module defines every engineering rule, its versioning, prioritization, conflict detection, comparison logic, what-if analysis storage, approval workflow, effectiveness tracking, and explainability records.

Every engineering decision made by StencilPro's Intelligence Engine traces to a record in this module. The rule evaluation pipeline (`fn_get_active_rules_for_context`), the confidence update system (`fn_rule_confidence_update`), the conflict resolver (`fn_resolve_rule_conflict`), the approval workflow (`fn_create_rule_approval_request`), and the what-if engine (`fn_create_what_if_scenario`, `fn_record_what_if_result`) are all implemented here.

---

## Tables Introduced (23 tables)

| Table | Rows (Typical) | Versioned | Append-Only | Audited |
|---|---|---|---|---|
| `knowledge_sources` | 6 | No | No | No |
| `engineering_rule_categories` | 22–60 | No | No | No |
| `engineering_rules` | 50–500 | Via versions | No | Yes |
| `engineering_rule_versions` | 50–2,000 | Yes (snapshot) | Yes (on approval) | Yes |
| `engineering_rule_conditions` | 100–5,000 | No | No | No |
| `engineering_rule_actions` | 50–1,000 | No | No | No |
| `engineering_rule_priorities` | 10–500 | No | No | Yes |
| `engineering_rule_references` | 50–500 | No | No | No |
| `rule_conflicts` | 100–10,000 | No | No | Yes |
| `rule_comparison_results` | 500–50,000 | No | No | No |
| `what_if_scenarios` | 500–20,000 | No | No | No |
| `what_if_parameters` | 1,000–100,000 | No | No | No |
| `what_if_results` | 500–20,000 | No | No | No |
| `what_if_defect_predictions` | 5,000–200,000 | No | **Yes** | No |
| `rule_approval_requests` | 100–5,000 | No | No | Yes |
| `rule_approvals` | 100–5,000 | No | No | Yes |
| `rule_effectiveness_history` | 500–20,000 | No | No | No |
| `customer_rule_profiles` | 10–200 | No | No | Yes |
| `company_rule_profiles` | 1–20 | No | No | No |
| `engineer_rule_profiles` | 1 per engineer | No | No | No |
| `ai_recommendation_profiles` | 1–5 per org | No | No | No |
| `decision_explanations` | 10,000–1M+ | No | **Yes** | No |
| `engineering_confidence_scores` | 500–50,000 | No | **Yes** | No |

---

## File Execution Order

All files are idempotent. Apply in exact order:

```
1. DB004A_Knowledge_Core.sql   — 23 table definitions
2. DB004A_Functions.sql        — 12 PL/pgSQL functions
3. DB004A_Indexes.sql          — 114 indexes
4. DB004A_Triggers.sql         — 55 trigger attachments
5. DB004A_RLS.sql              — 92 RLS policies
6. DB004A_Seed.sql             — 6 sources, 22 categories, 12 rules, 25 config entries
```

### psql CLI

```bash
export DATABASE_URL="postgresql://postgres:[password]@[host]:5432/postgres"
psql "$DATABASE_URL" -f DB004A_Knowledge_Core.sql
psql "$DATABASE_URL" -f DB004A_Functions.sql
psql "$DATABASE_URL" -f DB004A_Indexes.sql
psql "$DATABASE_URL" -f DB004A_Triggers.sql
psql "$DATABASE_URL" -f DB004A_RLS.sql
psql "$DATABASE_URL" -f DB004A_Seed.sql
```

---

## Rule Priority Model

The system implements a 6-tier priority hierarchy. Higher score = higher precedence in conflict resolution:

| Source | Priority Score | Code | Overridable |
|---|---|---|---|
| Project Override | 500 | `PROJECT_OVERRIDE` | No |
| Engineer Override | 400 | `ENGINEER_OVERRIDE` | No |
| Customer Rule | 300 | `CUSTOMER_RULE` | Yes |
| Company Rule | 200 | `COMPANY_RULE` | Yes |
| AI Recommendation | 150 | `AI_RECOMMENDATION` | Yes |
| IPC Standard | 100 | `IPC_STANDARD` | Yes |
| Default Rule | 0 | `DEFAULT_RULE` | Yes |

Priority is evaluated at runtime by `fn_evaluate_rule_priority()`, which checks `engineering_rule_priorities` for scope-specific overrides in order: project → engineer → customer → organization → base rule. This enables a customer to mandate a higher priority for a specific rule without modifying the rule itself.

---

## Key Design Decisions

### 1. Rules are Never Edited In Place

Every change to an engineering rule creates a new row in `engineering_rule_versions`. The parent `engineering_rules` row contains the current working values; `engineering_rule_versions` provides the immutable audit history. Once a version is approved (`approved_at IS NOT NULL`), it becomes permanently immutable — enforced by `fn_rule_version_immutable()` BEFORE UPDATE trigger. Rule check runs (in a future module) reference specific version IDs to enable historical replay: "what did the rule engine say on date X with version Y?"

### 2. Append-Only Tables

Three tables are strictly append-only with no UPDATE or DELETE permitted at the DB layer:

- **`what_if_defect_predictions`** — Defect risk snapshots for a what-if result. Immutable after creation.
- **`decision_explanations`** — Explainability records. Never modified once generated by the Intelligence Engine.
- **`engineering_confidence_scores`** — Learning System audit trail. Every confidence update is recorded; no overwriting. RLS policies set `USING (FALSE)` for UPDATE/DELETE. Direct INSERT is also blocked — all writes go through `fn_rule_confidence_update()` SECURITY DEFINER.

### 3. Confidence Score Updates

The Learning Engine updates `engineering_rules.base_confidence_pct` through `fn_rule_confidence_update()`. The formula:

```
new_confidence = CLAMP(old + (delta × evidence_strength × learning_rate), 0.10, 0.99)
```

Where `learning_rate = 0.05` (configurable). Every call writes to `engineering_confidence_scores` before returning. This creates a complete temporal audit trail of how the system's confidence in each rule has evolved.

### 4. Rule Comparison — 5 Sources in Parallel

`rule_comparison_results` stores side-by-side outcomes from all five rule sources (IPC, customer, company, engineer, AI) for a single design context. This powers the Rule Comparison UI (FRS Module 4.11). The JSONB helper `fn_get_rule_comparison_summary()` assembles the full comparison object for the UI in a single query.

### 5. What-If Analysis Storage

A complete what-if analysis run generates:
- 1 `what_if_scenarios` row (the scenario definition)
- N `what_if_parameters` rows (each modified parameter)
- 1 `what_if_results` row (full Intelligence Engine output)
- 12 `what_if_defect_predictions` rows (one per defect type)

The `fn_create_what_if_scenario()` and `fn_record_what_if_result()` SECURITY DEFINER functions handle creation. `fpy_delta_pct` and `score_delta` show improvement relative to the baseline context, enabling the engineer to see at a glance whether the scenario improves or degrades the design.

### 6. Approval Workflow

The `fn_create_rule_approval_request()` function:
1. Validates that justification is ≥50 characters (FRS BR-205)
2. Creates the `rule_approval_requests` row with status `pending`
3. Sends an in-app notification to the target approver

When an approver records a decision in `rule_approvals`, the `fn_approval_request_status_update()` AFTER INSERT trigger fires:
- Any `rejected` decision immediately sets the request status to `rejected`
- Any `approved` or `approved_with_conditions` closes the request as `approved`
- Notification is sent to the requester in both cases

The approver cannot be the same engineer as the requester — enforced at the RLS INSERT policy on `rule_approvals`.

### 7. Three Append-Only Enforcement Layers for decision_explanations

1. RLS `USING (FALSE)` on UPDATE and DELETE
2. No UPDATE triggers attached (by design)
3. Application-layer Repository enforces insert-only access

---

## Functions Reference

| Function | Signature | Purpose |
|---|---|---|
| `fn_rule_version_current_enforce` | `() → TRIGGER` | Demotes prior versions when new current is set; sets effective_until |
| `fn_rule_version_immutable` | `() → TRIGGER` | Blocks modification of approved rule versions |
| `fn_approval_request_status_update` | `() → TRIGGER` | Updates request status and sends notification after approval decision |
| `fn_what_if_scenario_activity` | `() → TRIGGER` | Logs project_activity on scenario create/complete |
| `fn_rule_confidence_update` | `(UUID,UUID,NUMERIC,VARCHAR,VARCHAR,NUMERIC,VARCHAR,UUID) → NUMERIC` | Learning Engine: update confidence + log to confidence_scores |
| `fn_evaluate_rule_priority` | `(UUID,UUID,UUID,UUID,UUID) → INTEGER` | Returns effective priority for a rule in a given context |
| `fn_get_active_rules_for_context` | `(UUID,UUID,UUID,UUID,VARCHAR,TEXT[]) → TABLE` | Returns all active rules for context, sorted by priority |
| `fn_create_what_if_scenario` | `(UUID,UUID,UUID,UUID,VARCHAR,VARCHAR,TEXT,JSONB) → UUID` | Creates a what-if scenario with context snapshot |
| `fn_record_what_if_result` | `(UUID,UUID,UUID,JSONB,...) → UUID` | Stores complete Intelligence Engine output for a what-if run |
| `fn_create_rule_approval_request` | `(UUID,UUID,UUID,VARCHAR,UUID,UUID,VARCHAR,TEXT,TEXT,VARCHAR) → UUID` | Creates approval request with notification; enforces 50-char justification |
| `fn_resolve_rule_conflict` | `(UUID,VARCHAR,TEXT,UUID,BOOLEAN,UUID) → VOID` | Records conflict resolution strategy and winning rule |
| `fn_get_rule_comparison_summary` | `(UUID) → JSONB` | Returns structured JSONB comparison across all 5 rule sources |
| `fn_rule_effectiveness_compute` | `(UUID,UUID,DATE,DATE) → VOID` | Computes and upserts effectiveness stats for a rule period |

---

## RLS Policy Summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `knowledge_sources` | All | Super Admin | Super Admin | Super Admin |
| `engineering_rule_categories` | All | Super Admin | Super Admin | Super Admin |
| `engineering_rules` | Org + System | Senior+ | Senior+ | Blocked |
| `engineering_rule_versions` | Org + System | Senior+ | Senior+ | Blocked |
| `engineering_rule_conditions` | Org + System | Senior+ | Senior+ | Senior+ |
| `engineering_rule_actions` | Org + System | Senior+ | Senior+ | Senior+ |
| `engineering_rule_priorities` | Org | Senior+ | Senior+ | Admin |
| `engineering_rule_references` | All | Senior+ | Senior+ | Admin |
| `rule_conflicts` | Org | Org | Org | Admin |
| `rule_comparison_results` | Org | Org | Owner/Admin | Admin |
| `what_if_scenarios` | Org | analysis.run | Owner/Admin | Blocked |
| `what_if_parameters` | Org | Org | Org | Org |
| `what_if_results` | Org | Org | Org | Admin |
| `what_if_defect_predictions` | Org | Org | **Blocked** | **Blocked** |
| `rule_approval_requests` | Owner/Target/Senior+ | aperture.override | Owner/Admin | Blocked |
| `rule_approvals` | Org | Senior+ (not own) | **Blocked** | **Blocked** |
| `rule_effectiveness_history` | Org | Admin | Admin | Super Admin |
| `customer_rule_profiles` | Org | Admin | Admin | Blocked |
| `company_rule_profiles` | Org | Admin | Admin | Admin |
| `engineer_rule_profiles` | Own/Admin | Own | Own/Admin | Own/Admin |
| `ai_recommendation_profiles` | Org | Admin | Admin | Admin |
| `decision_explanations` | Org | Org | **Blocked** | **Blocked** |
| `engineering_confidence_scores` | Org | **Blocked (fn only)** | **Blocked** | **Blocked** |

---

## Seed Data Summary

| Entity | Count | Notes |
|---|---|---|
| Knowledge sources | 6 | Default, IPC, AI, Company, Customer, Engineer Override |
| Rule categories | 22 | 11 top-level + 11 sub-categories |
| Engineering rules | 12 | 7 IPC, 1 AI, 1 Engineer Override example, 1 Customer example, 2 thermal |
| Rule versions | 12 | Auto-generated v1.0 for each seeded rule |
| Rule references | 8 | IPC-7525B, IPC-7093, IPC-7530, IPC J-STD-005A citations |
| Rule actions | 8 | Default actions for critical seeded rules |
| Application config | 25 | Rule engine thresholds, priority scores, learning parameters |

---

## Seeded IPC Rules

| Rule Code | Name | Category | Severity | Threshold |
|---|---|---|---|---|
| IPC7525B-001 | Minimum Area Ratio — Stainless | AREA_RATIO | critical | AR ≥ 0.66 |
| IPC7525B-002 | Minimum Aspect Ratio | ASPECT_RATIO | major | AR ≥ 1.5 |
| IPC7525B-003 | Min Aperture-to-Aperture Gap | APERTURE_SPACING | major | ≥ 0.15mm |
| IPC7525B-004 | Area Ratio — Electroform | AREA_RATIO | critical | AR ≥ 0.60 |
| IPC7093-001 | Thermal Pad Max Coverage | THERMAL_COVERAGE | critical | ≤ 80% |
| IPC7093-002 | Thermal Pad Min Coverage | THERMAL_COVERAGE | major | ≥ 50% |
| IPC7530-001 | Min Time Above Liquidus | REFLOW_PROCESS | critical | ≥ 30s |
| IPC7530-002 | Max Time Above Liquidus | REFLOW_PROCESS | major | ≤ 90s |
| IPC7092-001 | Paste Particle Rule of 5 | PASTE_COMPATIBILITY | major | ≤ 1/5 aperture width |
| AI-COAT-001 | Nano Coating for Fine Pitch | STENCIL_COATING | advisory | pitch ≤ 0.5mm |
| ENG-OVERRIDE-EXAMPLE-001 | Engineer Override Example | AREA_RATIO | advisory | AR ≥ 0.58 |
| CUST-GENERIC-001 | Customer AR 0.70 | AREA_RATIO | major | AR ≥ 0.70 |

---

## Post-Install Verification

```sql
-- 1. All 23 tables exist
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'knowledge_sources','engineering_rule_categories',
    'engineering_rules','engineering_rule_versions',
    'engineering_rule_conditions','engineering_rule_actions',
    'engineering_rule_priorities','engineering_rule_references',
    'rule_conflicts','rule_comparison_results',
    'what_if_scenarios','what_if_parameters','what_if_results',
    'what_if_defect_predictions','rule_approval_requests','rule_approvals',
    'rule_effectiveness_history','customer_rule_profiles','company_rule_profiles',
    'engineer_rule_profiles','ai_recommendation_profiles',
    'decision_explanations','engineering_confidence_scores'
);
-- Expected: 23

-- 2. Knowledge sources seeded
SELECT code, base_priority FROM knowledge_sources ORDER BY base_priority;
-- Expected: 6 rows (DEFAULT_RULE=0, IPC_STANDARD=100, AI_RECOMMENDATION=150,
--           COMPANY_RULE=200, CUSTOMER_RULE=300, ENGINEER_OVERRIDE=400)

-- 3. IPC rules seeded
SELECT rule_code, severity, threshold_value
FROM   engineering_rules
WHERE  is_deleted = FALSE
ORDER BY rule_code;
-- Expected: 12 rows

-- 4. Rule versions created for all seeded rules
SELECT COUNT(*) FROM engineering_rule_versions WHERE is_current = TRUE;
-- Expected: 12 (one per seeded rule)

-- 5. Partial unique index on current version
SELECT indexname FROM pg_indexes
WHERE tablename = 'engineering_rule_versions'
  AND indexname = 'uq_engineering_rule_versions_current';
-- Expected: 1 row

-- 6. Test fn_evaluate_rule_priority (returns base priority for system rule)
SELECT fn_evaluate_rule_priority(
    '0000004a-0003-0001-0001-000000000001',
    gen_random_uuid()
);
-- Expected: 100

-- 7. Test fn_get_active_rules_for_context returns seeded IPC rules
SELECT rule_code, severity, effective_priority
FROM fn_get_active_rules_for_context(
    gen_random_uuid(), NULL, NULL, NULL, 'class_2', NULL
)
ORDER BY effective_priority DESC;
-- Expected: 10 active IPC rules (excluding inactive examples)

-- 8. Append-only: decision_explanations UPDATE must fail
-- (Run from non-service-role session)
-- UPDATE decision_explanations SET explanation_level_1 = 'test' WHERE FALSE;
-- Expected: ERROR from RLS USING (FALSE)

-- 9. Migration record
SELECT version_num FROM schema_migrations
WHERE version_num = '0004A_db004a_engineering_knowledge_core';
-- Expected: 1 row

-- 10. Application config rule engine entries
SELECT COUNT(*) FROM application_config
WHERE config_key LIKE 'rule_engine.%';
-- Expected: 25
```

---

## Session Variable Requirement

All trigger functions that write to `project_activity` read engineer identity from:

```sql
current_setting('app.current_engineer_id', TRUE)::UUID
```

The Python application MUST set this at the start of every transaction:

```python
session.execute(
    text("SET LOCAL app.current_engineer_id = :eid"),
    {"eid": str(current_engineer.id)}
)
```

---

## Dependencies on Future Modules

DB-004A references entity types that will be created in later modules. These are stored as `VARCHAR(50)` entity type strings or UUID columns without FK constraints until the referenced tables exist:

| Column | References | Applied In |
|---|---|---|
| `rule_conflicts.stencil_design_id` | `stencil_designs(id)` | DB-006 |
| `rule_comparison_results.stencil_design_id` | `stencil_designs(id)` | DB-006 |
| `rule_comparison_results.aperture_design_id` | `aperture_designs(id)` | DB-006 |
| `what_if_scenarios.stencil_design_id` | `stencil_designs(id)` | DB-006 |

FK `ALTER TABLE` statements will be added in DB-006.

---

## Change Log

| Version | Date | Description |
|---|---|---|
| 1.0.0 | 2026-06-26 | Initial release — DB-004A complete |
