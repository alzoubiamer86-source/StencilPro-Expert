# StencilPro Expert Enterprise
## Functional Requirements Specification
### How Engineers Interact With the System

**Document Version:** 1.0.0
**Status:** Approved for Development
**Classification:** Core Requirements Document
**Depends On:**
- ARCHITECTURE.md v1.0.0
- ENGINEERING_DOMAIN_SPECIFICATION.md v1.0.0
- ENGINEERING_INTELLIGENCE_SPECIFICATION.md v1.0.0
- DATABASE_SPECIFICATION.md v1.0.0
**Date:** 2026-06-26

---

## Table of Contents

1. [Document Purpose & Scope](#1-document-purpose--scope)
2. [User Roles & Permissions](#2-user-roles--permissions)
3. [Application Shell & Navigation Model](#3-application-shell--navigation-model)
4. [Module Specifications](#4-module-specifications)
   - 4.01 [Dashboard](#401-dashboard)
   - 4.02 [Project Management](#402-project-management)
   - 4.03 [PCB Assembly & Revision Manager](#403-pcb-assembly--revision-manager)
   - 4.04 [Package & Component Library](#404-package--component-library)
   - 4.05 [Land Pattern & Pad Manager](#405-land-pattern--pad-manager)
   - 4.06 [Stencil Design Workspace](#406-stencil-design-workspace)
   - 4.07 [Stencil Design Wizard](#407-stencil-design-wizard)
   - 4.08 [Aperture Design Assistant](#408-aperture-design-assistant)
   - 4.09 [Thermal Pad Optimizer](#409-thermal-pad-optimizer)
   - 4.10 [Engineering Calculators](#410-engineering-calculators)
   - 4.11 [Rule Engine Manager](#411-rule-engine-manager)
   - 4.12 [Materials Library](#412-materials-library)
   - 4.13 [Process & Equipment Registry](#413-process--equipment-registry)
   - 4.14 [Inspection Data Manager](#414-inspection-data-manager)
   - 4.15 [Defect Library & Investigation](#415-defect-library--investigation)
   - 4.16 [Intelligence Dashboard](#416-intelligence-dashboard)
   - 4.17 [Recommendation Viewer](#417-recommendation-viewer)
   - 4.18 [Knowledge Base](#418-knowledge-base)
   - 4.19 [Image Library](#419-image-library)
   - 4.20 [Report Generator](#420-report-generator)
   - 4.21 [Customer & Organization Manager](#421-customer--organization-manager)
   - 4.22 [User & Access Manager](#422-user--access-manager)
   - 4.23 [Application Settings](#423-application-settings)
5. [Cross-Module User Workflows](#5-cross-module-user-workflows)
6. [Global Search Requirements](#6-global-search-requirements)
7. [Notification System](#7-notification-system)
8. [Error Handling Requirements](#8-error-handling-requirements)
9. [Security Requirements](#9-security-requirements)
10. [Audit Requirements](#10-audit-requirements)
11. [Performance Requirements](#11-performance-requirements)
12. [Offline Requirements](#12-offline-requirements)
13. [Report Specifications](#13-report-specifications)
14. [Business Rules Reference](#14-business-rules-reference)
15. [Future Expansion Requirements](#15-future-expansion-requirements)

---

## 1. Document Purpose & Scope

### 1.1 Purpose

This Functional Requirements Specification (FRS) defines the complete behavioral contract between StencilPro Expert Enterprise and its users. It specifies every interaction, workflow, validation rule, output, and constraint that the system must support.

This document is the primary input for:
- UI screen design and implementation
- Controller and service layer development
- API endpoint design (current and future)
- Integration and end-to-end test authoring
- User documentation

### 1.2 Scope

This specification covers the PySide6 desktop application, Phases 1 through 4 of the development roadmap. FastAPI service layer features (Phase 5) are noted where relevant but not fully specified here.

### 1.3 Specification Conventions

Throughout this document, the following conventions apply:

| Convention | Meaning |
|---|---|
| **MUST** | Mandatory requirement — system will not ship without this |
| **SHOULD** | Strongly recommended — omission requires documented justification |
| **MAY** | Optional — implement if time allows |
| `[FR-XXX-NNN]` | Functional Requirement identifier — cross-referenced in tests |
| `{field}` | A specific data field the user interacts with |
| `«Action»` | A user-initiated action (button press, menu item, keyboard shortcut) |

### 1.4 Assumptions

- The user has a working internet connection for cloud sync (offline mode is a Phase 2 feature)
- The user operates on Windows 10/11, macOS 12+, or Ubuntu 22.04+
- Display resolution minimum: 1280 × 800
- The user has basic familiarity with SMT process engineering concepts

---

## 2. User Roles & Permissions

### 2.1 Role Definitions

StencilPro defines five system roles. Organizations may not create custom roles in v1.0; custom roles are a Phase 4+ feature.

---

#### ROLE: Viewer

**Purpose:** Read-only access for stakeholders who need to view engineering data without the ability to modify it. Suitable for quality managers, customers (if access is granted), or management.

**Capabilities:**
- View all project data, stencil designs, and reports belonging to their organization
- View the defect library and knowledge base
- View inspection results and SPI data
- Generate and download existing reports (not create new ones)
- View engineering scores and recommendations (cannot dismiss or implement)

**Restrictions:**
- Cannot create, edit, or delete any record
- Cannot run rule checks or analysis
- Cannot approve stencil revisions
- Cannot access User & Access Manager

**Navigation Access:** Dashboard, Projects (read-only), Knowledge Base, Image Library, Reports (view/download only)

---

#### ROLE: Engineer

**Purpose:** The primary working role for SMT process engineers. Covers the complete design and investigation workflow.

**Capabilities:** All Viewer capabilities, plus:
- Create and edit Projects, PCB Assemblies, Stencil Designs, Aperture Designs
- Add and configure Land Patterns and Pads
- Run rule checks and engineering analyses
- Create and manage Defect Records and Investigations
- Author Case Studies and Engineering Notes
- Generate Reports
- Add and update Inspection Data (SPI, AOI, X-Ray)
- Create and run Engineering Calculations
- Manage own user preferences
- Upload and annotate Images

**Restrictions:**
- Cannot approve Stencil Revisions (requires Senior Engineer or above)
- Cannot edit System Rule Sets or System Materials
- Cannot manage other users
- Cannot override critical rules without approval

---

#### ROLE: Senior Engineer

**Purpose:** Experienced engineers who own design decisions and hold approval authority.

**Capabilities:** All Engineer capabilities, plus:
- Approve Stencil Revisions (four-eyes principle — cannot approve own designs)
- Override engineering rules (with mandatory justification)
- Approve rule overrides submitted by Engineers
- Create and edit organization-specific custom rules
- Edit and approve Experiments
- Publish Case Studies to organization knowledge base
- Close Defect Investigations

**Restrictions:**
- Cannot manage users or roles
- Cannot modify system (IPC) rule sets
- Cannot access system administration settings

---

#### ROLE: Admin

**Purpose:** Organization administrator responsible for system configuration, user management, and governance.

**Capabilities:** All Senior Engineer capabilities, plus:
- Create and manage Engineer accounts
- Assign and revoke roles
- Configure organization settings and defaults
- Manage the organization's Approved Materials List
- Create, edit, and activate/deactivate custom rule sets
- View and export Audit Logs
- Configure report templates
- Manage Customer records

**Restrictions:**
- Cannot modify system (IPC) rule sets or system packages
- Cannot access other organizations' data

---

#### ROLE: Super Admin

**Purpose:** Anthropic/system administrator. Cross-organization access for support and maintenance.

**Capabilities:** All Admin capabilities across all organizations, plus:
- Edit system rule sets, system packages, and system reference data
- Manage organizations (create, suspend, configure)
- Access system-wide audit logs
- Manage feature flags
- Deploy database migrations

**Note:** Super Admin accounts are never assigned to customer engineers. This role is internal only.

---

### 2.2 Permission Matrix

| Capability | Viewer | Engineer | Senior Eng | Admin | Super Admin |
|---|---|---|---|---|---|
| View projects & designs | ✓ | ✓ | ✓ | ✓ | ✓ |
| Create/edit projects | — | ✓ | ✓ | ✓ | ✓ |
| Create stencil designs | — | ✓ | ✓ | ✓ | ✓ |
| Run rule check | — | ✓ | ✓ | ✓ | ✓ |
| Approve stencil revision | — | — | ✓ | ✓ | ✓ |
| Override critical rule | — | ✗ Request | ✓ Approve | ✓ | ✓ |
| Create defect investigation | — | ✓ | ✓ | ✓ | ✓ |
| Close defect investigation | — | — | ✓ | ✓ | ✓ |
| Edit custom rule sets | — | — | ✓ | ✓ | ✓ |
| Edit system rule sets | — | — | — | — | ✓ |
| Manage users | — | — | — | ✓ | ✓ |
| View audit log | — | — | — | ✓ | ✓ |
| Generate reports | — | ✓ | ✓ | ✓ | ✓ |
| Publish case studies | — | Draft only | ✓ | ✓ | ✓ |
| Configure organization | — | — | — | ✓ | ✓ |
| Manage feature flags | — | — | — | — | ✓ |

---

### 2.3 Role Assignment Rules

`[FR-ROLE-001]` An engineer may hold multiple roles simultaneously. The highest-privilege role applies.

`[FR-ROLE-002]` At least one Admin must exist in every organization at all times. The system MUST prevent the removal of the last Admin role.

`[FR-ROLE-003]` Role assignment changes MUST be logged in the audit log with the assigning engineer's identity.

`[FR-ROLE-004]` Role changes take effect on the engineer's next authentication. Active sessions retain old permissions until re-login.

`[FR-ROLE-005]` Temporary role assignments MAY include an expiry date. The system MUST automatically downgrade the role at expiry.

---

## 3. Application Shell & Navigation Model

### 3.1 Application Window Structure

The desktop application uses a single main window with the following persistent regions:

```
┌─────────────────────────────────────────────────────────────┐
│  TITLE BAR: "StencilPro Expert Enterprise — [Project Name]" │
├──────────┬──────────────────────────────────────────────────┤
│          │  TOOLBAR: Quick actions for current context       │
│  LEFT    ├──────────────────────────────────────────────────┤
│  NAV     │                                                   │
│  PANEL   │           MAIN CONTENT AREA                      │
│  (fixed  │           (context-dependent view)               │
│  width,  │                                                   │
│  scroll) │                                                   │
│          │                                                   │
├──────────┴──────────────────────────────────────────────────┤
│  STATUS BAR: Connection status | Active project | Engineer  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Left Navigation Panel

The navigation panel is always visible. It is organized into sections that expand/collapse:

```
LEFT NAVIGATION PANEL

  [Organization logo + name]
  [Logged-in engineer name + role badge]

  ─── WORKSPACE ───────────────────────────────
  🏠 Dashboard
  📋 Projects
      └── [Recently opened projects — up to 5]
  
  ─── ACTIVE PROJECT ──────────────────────────
  [Visible only when a project is open]
  📐 PCB Assembly
  🔵 Stencil Design
      └── [Active stencil designs list]
  🧪 Inspection Data
  🔍 Defect Investigations
  📊 Reports

  ─── MASTER DATA ─────────────────────────────
  📦 Package Library
  🧲 Materials Library
  ⚙️  Process & Equipment
  
  ─── KNOWLEDGE BASE ──────────────────────────
  📚 IPC References
  🔧 Rule Manager
  🧮 Calculators
  📖 Case Studies
  🖼️  Image Library
  
  ─── ADMINISTRATION ──────────────────────────
  [Visible only to Admin role and above]
  👥 Users & Access
  🏢 Organization
  🔑 Customers
  📋 Audit Log
  ⚙️  Settings
```

### 3.3 Navigation Rules

`[FR-NAV-001]` The navigation panel MUST always show the currently active project name and status when a project is open.

`[FR-NAV-002]` Sections without content (e.g., no stencil designs yet) MUST still be visible but show an empty state with a call-to-action.

`[FR-NAV-003]` The "ACTIVE PROJECT" section MUST be hidden when no project is open.

`[FR-NAV-004]` Navigation items the user does not have permission to access MUST be hidden — not shown disabled.

`[FR-NAV-005]` The application MUST remember the last active navigation item and restore it on next launch.

`[FR-NAV-006]` «Ctrl+1» through «Ctrl+9» MUST activate the first nine navigation items in order.

`[FR-NAV-007]` Keyboard shortcut «Ctrl+P» MUST open the Project selector at any time.

### 3.4 Status Bar

The status bar is always visible at the bottom of the window and displays:

| Region | Content |
|---|---|
| Left | Connection indicator: 🟢 Connected / 🟡 Syncing / 🔴 Offline |
| Center-left | Active project: "[Project Number] — [Project Name]" or "No project open" |
| Center-right | Active stencil design (if any) and its rule check status badge |
| Right | Logged-in engineer name and role |

`[FR-STATUS-001]` The connection indicator MUST update within 5 seconds of a connectivity change.

`[FR-STATUS-002]` Clicking the connection indicator MUST open a sync status panel showing last sync time and any pending operations.

### 3.5 Toolbar

The toolbar shows context-sensitive actions for the current view. It always includes:
- «Save» (where applicable — auto-save is the default)
- «Run Analysis» (when a stencil design is active)
- «Generate Report» (when context supports it)
- Global Search field

Context-specific toolbar buttons are defined in each module specification below.

### 3.6 Application Menu

The application MUST provide a standard menu bar on all platforms:

```
File
  New Project...          Ctrl+Shift+N
  Open Project...         Ctrl+O
  Recent Projects ▶
  Close Project           Ctrl+W
  ─────────────────
  Save                    Ctrl+S
  ─────────────────
  Generate Report...      Ctrl+Shift+R
  ─────────────────
  Preferences...          Ctrl+,
  ─────────────────
  Quit                    Ctrl+Q

Edit
  Undo                    Ctrl+Z
  Redo                    Ctrl+Y
  ─────────────────
  Find...                 Ctrl+F
  Global Search           Ctrl+G

View
  Toggle Navigation Panel Ctrl+\
  Zoom In                 Ctrl++
  Zoom Out                Ctrl+-
  Reset Zoom              Ctrl+0
  ─────────────────
  Dark Mode / Light Mode
  ─────────────────
  Refresh                 F5

Tools
  Engineering Calculators  Ctrl+Shift+C
  Rule Manager
  Package Library
  Materials Library

Help
  User Guide               F1
  IPC Reference Guide
  Keyboard Shortcuts       Ctrl+Shift+?
  ─────────────────
  Check for Updates
  Send Feedback
  ─────────────────
  About StencilPro
```

---

## 4. Module Specifications

---

### 4.01 Dashboard

**Purpose:** The landing screen after login. Provides an at-a-glance view of active work, recent activity, and engineering alerts requiring attention.

**Related Database Tables:** `projects`, `stencil_designs`, `defect_records`, `recommendations`, `notifications`, `knowledge_review_flags`, `design_score_cards`

---

#### Features

**F-DASH-01: Active Projects Panel**
Displays the engineer's active projects with key status indicators.

**F-DASH-02: Engineering Alerts Panel**
Shows items requiring engineering attention: critical rule failures, pending approvals, open investigations, and knowledge review flags. This is the highest-priority section.

**F-DASH-03: Recent Activity Feed**
Chronological list of the engineer's recent actions across the system.

**F-DASH-04: Organization Metrics Panel**
Summary statistics for the organization: total active projects, stencils pending approval, open defect investigations, average design score this month.

**F-DASH-05: Quick Actions**
One-click access to the most common starting actions.

---

#### Screen Specification: Dashboard

**Active Projects Panel:**

| Display Element | Source | Format |
|---|---|---|
| Project number | `projects.project_number` | Text |
| Project name | `projects.name` | Text |
| Customer name | `customers.name` | Text |
| Project status | `projects.status` | Colored badge |
| Active stencil design name | `stencil_designs.name` | Text |
| Overall design score | `stencil_designs.overall_design_score` | Score pill (0–100 with color grade) |
| Predicted FPY | `stencil_designs.predicted_fpy_pct` | Percentage |
| Rule check status | `stencil_designs.overall_rule_check_status` | Icon badge |
| Last activity date | `projects.updated_at` | Relative time ("2 hours ago") |

Displays maximum 5 most recently active projects. «View All Projects» opens the Projects module.

**Engineering Alerts Panel (sorted by severity):**

| Alert Type | Trigger Condition | Priority |
|---|---|---|
| Critical rule failure | Any aperture with `rule_check_status = 'fail'` and severity critical | CRITICAL |
| Stencil pending your approval | `stencil_designs.status = 'in_review'` AND `approved_by = current_engineer` (if designated) | HIGH |
| Open defect investigation | `defect_investigations.status IN ('open', 'in_progress')` owned by engineer | HIGH |
| Knowledge review flag | `knowledge_review_flags.severity = 'action_required'` | HIGH |
| Stencil design not yet analyzed | `stencil_designs.overall_rule_check_status = 'not_run'` | MEDIUM |
| SPI data available for correlation | New `spi_measurements` linked to design without correlation run | MEDIUM |

**Quick Actions:**
- «New Project» — opens New Project dialog
- «Open Recent» — dropdown of last 5 projects
- «Run Calculators» — opens Calculator module
- «Search Knowledge Base» — focuses global search on knowledge entities

---

#### User Actions

`[FR-DASH-001]` Clicking any project card MUST open that project in the Project Management module.

`[FR-DASH-002]` Clicking any alert card MUST navigate directly to the relevant screen (e.g., clicking a critical rule failure navigates to that aperture in the Stencil Design Workspace).

`[FR-DASH-003]` Each alert MUST show: what the issue is, which project/design it affects, and when it was detected.

`[FR-DASH-004]` The dashboard MUST auto-refresh every 5 minutes when the application is active.

`[FR-DASH-005]` Engineers MUST be able to dismiss advisory-level alerts from the dashboard. Dismissal is logged.

---

#### Validation Rules

`[FR-DASH-VAL-001]` If the engineer has no active projects, the Active Projects Panel MUST display an empty state with a «Create Your First Project» call-to-action.

`[FR-DASH-VAL-002]` If there are no engineering alerts, the Alerts Panel MUST display "No engineering issues requiring attention" — never hide the panel entirely.

---

### 4.02 Project Management

**Purpose:** Create, organize, and manage engineering projects. A project is the container for all work on a specific PCB assembly's stencil engineering.

**Related Database Tables:** `projects`, `project_engineers`, `project_notes`, `customers`, `products`, `pcb_assemblies`, `stencil_designs`

**Related Engineering Rules:** IPC class hierarchy enforcement, customer approval constraints

---

#### Features

**F-PROJ-01: Project List View**
Filterable, sortable table of all projects the engineer has access to.

**F-PROJ-02: Project Create/Edit Form**
Guided form for creating and editing project metadata.

**F-PROJ-03: Project Detail View**
Complete view of a project including all linked assemblies, stencil designs, and investigations.

**F-PROJ-04: Project Timeline**
Chronological audit trail (rendered from `project_notes`) showing all events on the project.

**F-PROJ-05: Project Team Management**
Add and remove engineers from a project, assign roles.

---

#### Screen Specification: Project List

Display columns (all sortable):

| Column | Source | Default Sort |
|---|---|---|
| Project Number | `projects.project_number` | Ascending |
| Project Name | `projects.name` | — |
| Customer | `customers.name` | — |
| Status | `projects.status` | — |
| Phase | `projects.phase` | — |
| IPC Class | `projects.ipc_class` | — |
| Lead Engineer | `engineers.full_name` | — |
| Last Modified | `projects.updated_at` | Descending |
| Stencil Count | Derived count | — |
| Overall Score | Best score across active stencils | — |

Filter options: Status, Customer, IPC Class, Phase, Lead Engineer, Date Range, Tags

`[FR-PROJ-001]` The list MUST support multi-column sorting.

`[FR-PROJ-002]` The list MUST persist filter and sort state for the session.

`[FR-PROJ-003]` Double-clicking a row MUST open the Project Detail View.

---

#### Screen Specification: New Project Form

**Required fields (MUST be provided before save):**

| Field | Input Type | Validation | Source |
|---|---|---|---|
| Project Name | Text | 1–255 chars, not blank | `projects.name` |
| Customer | Dropdown / search | Must select existing customer | `projects.customer_id` |
| Lead Engineer | Dropdown | Defaults to current engineer | `projects.lead_engineer_id` |
| IPC Class | Radio (Class 1 / 2 / 3) | Must be ≥ customer's required class | `projects.ipc_class` |
| Phase | Dropdown | npi, pre_production, production, eco, sustaining | `projects.phase` |

**Optional fields:**

| Field | Input Type | Validation | Source |
|---|---|---|---|
| Description | Multiline text | Max 5,000 chars | `projects.description` |
| Product | Dropdown / search | Must be product owned by selected customer | `projects.product_id` |
| Target Yield % | Number | 0–100, 3 decimal places | `projects.target_yield_pct` |
| Start Date | Date picker | Cannot be in the past (warning, not error) | `projects.start_date` |
| Target Completion | Date picker | Must be after start date | `projects.target_completion_date` |
| Tags | Tag input | Each tag: 1–50 chars, lowercase | `projects.tags` |

**Auto-populated (not user-entered):**
- Project Number (generated per org format)
- Status (defaults to "draft")
- Created At, Updated At
- Organization ID (from session)

---

#### User Actions

`[FR-PROJ-004]` «Save Project» MUST create the project and navigate to the Project Detail View.

`[FR-PROJ-005]` «Archive Project» MUST require confirmation. Archived projects become read-only. A system `project_note` is automatically created: "Project archived by [Engineer] on [Date]."

`[FR-PROJ-006]` «Clone Project» MUST create a new draft project with the same metadata (customer, IPC class, tags) but no stencil designs or assemblies. The clone notes its source project in the description.

`[FR-PROJ-007]` «Add Engineer to Project» MUST allow selecting any active engineer in the organization and assigning a project role (lead, reviewer, contributor, observer).

`[FR-PROJ-008]` «Add Note» MUST open a note form with type selection (Decision, Comment, Milestone, Warning) and a text field. Notes are immediately saved and cannot be edited after saving.

`[FR-PROJ-009]` «Change Status» MUST record a system-generated `project_note` with the old and new status, the engineer who changed it, and the timestamp.

---

#### Validation Rules

`[FR-PROJ-VAL-001]` Project IPC class MUST be equal to or stricter than the selected customer's `required_ipc_class`. If the engineer selects a lower class, display: "This customer requires a minimum of IPC Class [X]. Your selection has been upgraded to Class [X]." Auto-correct or block submission.

`[FR-PROJ-VAL-002]` A project with status "completed" or "archived" MUST NOT allow creating new stencil designs. Display: "This project is [completed/archived]. Create a new project or reactivate this project to add new designs."

`[FR-PROJ-VAL-003]` Deleting a project MUST only be permitted if it contains zero stencil designs, zero defect investigations, and zero generated reports. Otherwise, only archiving is permitted.

`[FR-PROJ-VAL-004]` When a project's customer has an `approved_paste_ids` list, any stencil design in this project that uses a non-approved paste MUST trigger a visible warning in the Project Detail View.

---

### 4.03 PCB Assembly & Revision Manager

**Purpose:** Define the physical PCB and its revision history. All stencil engineering work links to a specific PCB revision.

**Related Database Tables:** `pcb_assemblies`, `pcb_revisions`, `surface_finishes`, `component_placements`, `land_patterns`, `pads`

---

#### Features

**F-PCB-01: PCB Assembly Form**
Define the physical and electrical characteristics of the PCB.

**F-PCB-02: Revision Manager**
Create and track PCB design revisions. Mark the current revision.

**F-PCB-03: Component Placement List**
View all component placements for a revision. Import from file or enter manually.

**F-PCB-04: Revision Comparison**
Side-by-side comparison of two revisions showing what changed.

---

#### Screen Specification: PCB Assembly Form

**Required fields:**

| Field | Input Type | Validation |
|---|---|---|
| Assembly Name | Text | 1–255 chars |
| Surface Finish | Dropdown | Must select from `surface_finishes` |
| Solder Mask Color | Dropdown | green, red, blue, black, white, yellow, purple |
| Assembly Sides | Radio | top_only, bottom_only, double_sided |
| Base Material | Dropdown | fr4, rogers, polyimide, aluminum, ceramic, other |

**Optional fields (grouped by category):**

*Physical Dimensions:*
- Board Length (mm), Board Width (mm), Board Thickness (mm)
- Min Feature Size (mm), Min Via Drill (mm)

*Electrical Properties:*
- Layer Count, Outer Copper Weight (oz), Tg Temperature (°C)

*Special Features:*
- Has Press-Fit Connectors (checkbox)
- Has Edge Connectors (checkbox)
- Has Castellated Holes (checkbox)

*Files:*
- Gerber/ODB++ upload (stored to Supabase Storage)
- BOM file upload

**Intelligence Triggers:** The following fields feed directly into the Intelligence Engine's ProcessContext. They MUST be present before a full rule check can run:
- `surface_finish_id` (affects paste compatibility rules)
- `assembly_sides` (determines stencil count)
- `board_thickness_mm` (affects printing support rules)

---

#### Screen Specification: PCB Revision Form

**Required fields:**

| Field | Input Type | Validation |
|---|---|---|
| Revision Code | Text | 1–20 chars, unique per assembly |
| Revision Date | Date | Required |
| Released By | Engineer selector | Defaults to current engineer |
| Change Type | Dropdown | initial_release, minor_change, major_change, eco, prototype |

**Smart-populated fields (engineer may override):**
These fields MUST be auto-populated when available from imported design data, or entered manually:

| Field | Input Type | Intelligence Use |
|---|---|---|
| Min Pitch (mm) | Number | Activates fine-pitch / ultra-fine-pitch rule groups |
| Has BGAs | Checkbox | Activates BGA rule group |
| Has QFNs | Checkbox | Activates thermal pad rule group |
| Has 01005 Components | Checkbox | Activates 01005 rule group |

`[FR-PCB-001]` Only one revision per assembly may be marked `is_current_revision = true`. Marking a new revision as current MUST automatically unmark the previous current revision and create a `project_note`.

`[FR-PCB-002]` When `change_type = 'major_change'` or `'eco'`, the system MUST create an alert in the active stencil design's Engineering Alerts panel: "PCB revision has a major change. Stencil design review recommended."

`[FR-PCB-003]` Deleting a PCB revision MUST be blocked if any `stencil_designs` or `component_placements` reference it.

---

#### Validation Rules

`[FR-PCB-VAL-001]` If `has_bgAs = true` AND `has_qfns = true`, the system MUST display an advisory: "This assembly contains both BGA and QFN components. Both thermal pad optimization and BGA voiding rules will be activated."

`[FR-PCB-VAL-002]` `board_thickness_mm` outside the range 0.4–6.35 MUST display a warning (not block save): "Board thickness [X]mm is outside the typical SMT assembly range of 0.4–6.35mm. Verify this value."

`[FR-PCB-VAL-003]` If `min_pitch_mm < 0.4` AND `has_01005_components = false`, display an advisory: "Min pitch of [X]mm suggests ultra-fine-pitch components. Verify that 01005 or similar components are not present."

---

### 4.04 Package & Component Library

**Purpose:** Manage the organization's library of SMT component packages and approved components. The foundation for all land pattern and aperture design work.

**Related Database Tables:** `package_families`, `smt_packages`, `components`, `component_libraries`, `component_library_members`

---

#### Features

**F-PKG-01: Package Browser**
Searchable, filterable browser of all SMT packages (system + organization custom).

**F-PKG-02: Package Detail View**
Complete package specification with geometry, thermal properties, and engineering notes.

**F-PKG-03: Custom Package Creator**
Form for creating organization-specific package definitions.

**F-PKG-04: Component Library Manager**
Create and manage versioned approved parts lists.

**F-PKG-05: Component Detail View**
Full component specification linked to its package and library history.

---

#### Screen Specification: Package Browser

**Filter Panel:**

| Filter | Options |
|---|---|
| Package Family | Multi-select from `package_families` |
| IPC Density Level | Most, Nominal, Least |
| Pitch Range | Min/Max sliders (0.1–2.5mm) |
| Has Thermal Pad | Yes / No / Any |
| Lead Count | Min/Max number inputs |
| Source | System, Custom, All |
| Search Text | Full-text across ipc_name, common_name |

**Results Table Columns:**
IPC Name, Common Name, Family, Pitch (mm), Lead Count, Body (L×W mm), Has Thermal Pad, Density Level, Source (System/Custom)

`[FR-PKG-001]` Package search MUST use full-text search supporting partial matches (e.g., "SOT" returns "SOT-23", "SOT-323", "SOT-23-5").

`[FR-PKG-002]` System packages (is_system_record = true) MUST be visually distinguished from organization custom packages (e.g., badge or icon).

`[FR-PKG-003]` System packages MUST show a read-only view. «Create Custom Override» MUST allow creating an organization-specific variant based on the system package.

---

#### Screen Specification: Custom Package Creator

The form creates a new `smt_packages` record with `organization_id` populated and `is_system_package = false`.

**Required fields:**
- Common Name (e.g., "MY-QFN-24-3x3")
- Package Family (dropdown from `package_families`)
- IPC Density Level

**Geometry fields** (all in mm, NUMERIC(10,4)):
- Body Length, Body Width, Body Height
- Lead Pitch, Lead Count, Lead Width, Lead Length
- Standoff Height
- Has Thermal Pad (checkbox — reveals thermal pad section if checked)

**Thermal Pad fields** (visible when Has Thermal Pad = true):
- Thermal Pad Length (mm), Thermal Pad Width (mm)
- Recommended Paste Coverage % (advisory field — Optimizer will calculate)

**Validation:**
`[FR-PKG-VAL-001]` Lead Pitch MUST be > 0.05mm (minimum realistic SMT pitch).
`[FR-PKG-VAL-002]` Lead Count MUST be > 0.
`[FR-PKG-VAL-003]` If Has Thermal Pad = true, Thermal Pad dimensions MUST be provided and MUST be < Body dimensions.
`[FR-PKG-VAL-004]` Lead Pitch ≤ 0.4mm MUST display: "Ultra-fine pitch detected. T5 or finer solder paste and electroform or nano-coated stencil will be required."

---

### 4.05 Land Pattern & Pad Manager

**Purpose:** Define the copper pad geometry on the PCB for each component placement. The direct driver of aperture design.

**Related Database Tables:** `land_patterns`, `pads`, `thermal_pads`, `pad_groups`, `smt_packages`

---

#### Features

**F-LP-01: Land Pattern Browser**
View all land patterns associated with a PCB revision.

**F-LP-02: Land Pattern Form**
Create or edit a land pattern for a specific package.

**F-LP-03: Pad Editor**
Add, edit, or remove individual pads within a land pattern.

**F-LP-04: Thermal Pad Configurator**
Specialized sub-form for thermal pad parameters (linked to Thermal Pad Optimizer).

**F-LP-05: IPC-7351 Land Pattern Calculator**
Given a package geometry, automatically calculate IPC-7351 Nominal land pattern dimensions.

---

#### Screen Specification: Pad Editor

The pad editor displays a tabular list of all pads in the land pattern. Each row is editable inline.

**Pad Columns:**
Pad Number, Function, Shape, Length (mm), Width (mm), X Offset (mm), Y Offset (mm), Rotation (°), Paste Reduction (%), Net Name

**Pad Function values:** signal, power, ground, thermal, no_connect, fiducial

**Pad Shape values:** rectangle, rounded_rectangle, oval, circle, polygon, d_shape

`[FR-LP-001]` «Calculate IPC Nominal» MUST auto-populate all pad dimensions from the linked package geometry using IPC-7351 formulas. The engineer may then edit individual values.

`[FR-LP-002]` Any change to pad dimensions MUST automatically invalidate (mark stale) any linked `aperture_designs` for this land pattern and display: "Pad geometry changed. Aperture designs for this land pattern require re-evaluation."

`[FR-LP-003]` Ground and power pads MUST default to `paste_reduction_pct = 0` unless the engineer specifies otherwise. (Thermal reduction is handled in the Thermal Pad Configurator.)

`[FR-LP-VAL-001]` Pad Length and Width MUST be > 0.01mm.
`[FR-LP-VAL-002]` Corner radius for rounded_rectangle MUST be ≤ min(length, width) / 2.
`[FR-LP-VAL-003]` Paste reduction MUST be 0–100%.

---

### 4.06 Stencil Design Workspace

**Purpose:** The primary engineering workspace for designing, evaluating, and approving stencil designs. The central module of StencilPro.

**Related Database Tables:** `stencil_designs`, `stencil_revisions`, `aperture_designs`, `aperture_shapes`, `stencil_materials`, `stencil_thickness_options`, `stencil_coatings`, `rule_check_runs`, `rule_results`, `design_score_cards`, `defect_risk_assessments`, `yield_predictions`, `recommendations`

**Related Engineering Rules:** All rule groups — geometry_fundamentals, material_compatibility, thermal_pad, fine_pitch, ultra_fine_pitch, bga_lga, mixed_technology, inspection_requirements, process_environment

---

#### Features

**F-STD-01: Stencil Design Header Panel**
Top-level stencil configuration (material, thickness, coating, paste, assembly side).

**F-STD-02: Aperture Design Table**
Complete list of all apertures in the design with live calculated metrics.

**F-STD-03: Intelligence Panel (Right Side)**
Live display of the Intelligence Engine output: rule results, recommendations, scores, defect risk.

**F-STD-04: Aperture Detail Panel**
Detailed view and editor for a single selected aperture.

**F-STD-05: Stencil Revision History**
View all approved revisions with comparison capability.

**F-STD-06: Design Actions Toolbar**
Run Analysis, Approve Revision, Export, Print Parameter Sets.

---

#### Screen Specification: Stencil Design Header

| Field | Input Type | Required | Intelligence Use |
|---|---|---|---|
| Stencil Name | Text | Yes | — |
| Assembly Side | Dropdown | Yes | ProcessContext.assembly_side |
| Stencil Material | Dropdown + search | Yes | ProcessContext.stencil_material |
| Stencil Thickness | Dropdown | Yes | ProcessContext.thickness_mm |
| Stencil Coating | Dropdown | Yes | ProcessContext.coating_type |
| Default Solder Paste | Dropdown + search | Recommended | ProcessContext.paste_* |
| Design Intent | Multiline text | Optional | Audit trail |

When all required fields are populated and the design has at least one aperture, «Run Analysis» becomes enabled.

---

#### Screen Specification: Aperture Design Table

This table is the engineering core of the application. It displays one row per aperture design.

**Columns (in display order):**

| Column | Source | Color Coding |
|---|---|---|
| Ref Des | `component_placements.reference_designator` | — |
| Pin # | `pads.pad_number` | — |
| Package | `smt_packages.common_name` | — |
| Shape | `aperture_shapes.code` | — |
| Length (mm) | `aperture_designs.length_mm` | — |
| Width (mm) | `aperture_designs.width_mm` | — |
| Area Ratio | `aperture_designs.area_ratio` | 🟢 ≥0.80, 🟡 0.66–0.79, 🔴 <0.66 |
| Aspect Ratio | `aperture_designs.aspect_ratio` | 🟢 ≥2.0, 🟡 1.5–1.99, 🔴 <1.5 |
| Paste Vol (mm³) | `aperture_designs.paste_volume_mm3` | — |
| Transfer Eff. % | `aperture_designs.transfer_efficiency_pct` | 🟢 ≥85, 🟡 75–84, 🔴 <75 |
| Gap (mm) | `aperture_designs.aperture_to_aperture_gap_mm` | 🟢 ≥0.20, 🟡 0.10–0.19, 🔴 <0.10 |
| Rule Status | `aperture_designs.rule_check_status` | ✅ Pass, ⚠️ Warning, ❌ Fail, ⬜ Not Run |
| Override | `aperture_designs.engineer_override` | 🔒 if true |

**Table Behaviors:**
- Clicking a row MUST select it and populate the Aperture Detail Panel
- Double-clicking a row MUST open the Aperture Detail Panel in full edit mode
- Columns MUST be resizable and reorderable
- Right-clicking MUST show context menu: Edit, Duplicate, Reset to IPC Default, View Rule Results, Add Note
- «Filter» MUST allow filtering by: rule status, area ratio band, ref des, package name
- «Sort» on any column header
- Rows with `engineer_override = true` MUST display a lock icon and tooltip with override justification

`[FR-STD-001]` Area ratio, aspect ratio, paste volume, and transfer efficiency MUST update in real-time as the engineer edits aperture dimensions (without requiring a full analysis run).

`[FR-STD-002]` The total aperture count, critical failure count, and warning count MUST be shown as summary statistics above the table.

`[FR-STD-003]` «Select All Failing» MUST select all rows with `rule_check_status = 'fail'`.

`[FR-STD-004]` «Bulk Edit» on a selection MUST allow changing: shape, length offset (±%), width offset (±%), or coating override for all selected apertures simultaneously.

---

#### Screen Specification: Intelligence Panel

The Intelligence Panel is displayed alongside the aperture table and updates after each analysis run.

**Section 1 — Design Score Card:**
```
OVERALL SCORE:  73 / 100  [Grade: C+]

  Stencil Design:       68/100  ████████░░░░
  Manufacturability:    76/100  █████████░░░
  Paste Compatibility:  85/100  ██████████░░
  Inspection Coverage:  72/100  ████████░░░░
  IPC Compliance:       81/100  ██████████░░

  Predicted FPY: 94.2%  [90.1% – 97.1% at 90% CI]
```

**Section 2 — Engineering Alerts (from rule results):**
Grouped by severity: CRITICAL → MAJOR → WARNINGS → ADVISORY
Each entry shows: rule code, affected aperture, evaluated value vs threshold, one-line message.
Clicking an entry MUST highlight the affected aperture in the table and open its detail panel.

**Section 3 — Defect Risk Matrix:**
12 defect types with risk band indicator:
```
  Solder Bridge:        ████░░  HIGH (0.71)
  Insufficient Solder:  ██░░░░  MODERATE (0.45)
  Voiding:              ████░░  HIGH (0.68)  [3 thermal pads]
  Tombstoning:          █░░░░░  LOW (0.18)
  Head-in-Pillow:       ░░░░░░  NEGLIGIBLE (0.04)
  ...
```

**Section 4 — Recommendations (prioritized):**
Top 5 recommendations shown with title, priority badge, confidence %, and one-line summary. «View All» expands the Recommendation Viewer.

`[FR-STD-005]` The Intelligence Panel MUST display a "Last analyzed: [timestamp]" indicator. If the design has changed since the last analysis, it MUST display "⚠️ Changes since last analysis — re-run recommended."

`[FR-STD-006]` Clicking any defect risk entry MUST open the Defect Library entry for that defect type.

---

#### Screen Specification: Aperture Detail Panel

Displays when an aperture is selected in the table.

**Display Sections:**

*1. Identity*
- Reference Designator, Pin Number, Package, Land Pattern
- Current aperture shape (with shape diagram)

*2. Geometry Editor*
Editable fields: Length (mm), Width (mm), Corner Radius (mm), X Offset (mm), Y Offset (mm), Rotation (°)

*3. Calculated Metrics (live update)*
| Metric | Value | IPC Threshold | Status |
|---|---|---|---|
| Area Ratio | 0.683 | ≥ 0.66 | ✅ PASS |
| Aspect Ratio | 4.55 | ≥ 1.50 | ✅ PASS |
| Aperture Area | 0.1024 mm² | — | — |
| Paste Volume | 0.01536 mm³ | — | — |
| Transfer Efficiency | 83% | — | — |
| Min Gap to Neighbor | 0.17mm | ≥ 0.15mm | ⚠️ WARNING |

*4. Rule Results for This Aperture*
Table of rules evaluated for this aperture: Rule Code, Description, Status, Evaluated Value, Threshold.

*5. Override Section*
Visible only if `engineer_override = true` or if engineer is clicking «Request Override»:
- Override justification (text)
- Approved by (engineer selector)
- Approval status

*6. Recommendations for This Aperture*
Any recommendations targeting this specific aperture.

`[FR-STD-007]` Geometry changes in the Aperture Detail Panel MUST update the parent table row in real-time.

`[FR-STD-008]` «Reset to IPC Default» MUST recalculate the aperture dimensions from the IPC-7351 land pattern for the linked package and density level, and display the before/after comparison before applying.

---

#### Stencil Revision Approval Workflow

`[FR-STD-009]` «Submit for Approval» MUST be enabled only when `overall_rule_check_status` is `pass` or `pass_with_warnings`.

`[FR-STD-010]` When submitted, the stencil design status changes to `in_review` and a notification is sent to the designated approver (or all Senior Engineers if no specific approver is designated).

`[FR-STD-011]` The approver MUST see: the stencil design summary, rule check results, design scores, all recommendations and their statuses, and any engineer-noted justifications.

`[FR-STD-012]` «Approve Revision» MUST: create an immutable `stencil_revisions` snapshot, set `stencil_designs.status = 'approved'`, set `approved_by_engineer_id`, set `approved_at`, and create a `project_note`.

`[FR-STD-013]` «Reject Revision» MUST require a rejection reason. Status returns to `draft`. A `project_note` is created with the rejection reason.

`[FR-STD-014]` The approver CANNOT be the same engineer as `designed_by_engineer_id` (when the four-eyes principle is enabled in organization settings).

---

#### User Actions Summary

| Action | Trigger | Outcome |
|---|---|---|
| «Run Analysis» | Button / Ctrl+Enter | Full Intelligence Engine run; updates all panels |
| «Add Aperture» | Button / Ins key | Opens aperture creator for a selected pad |
| «Delete Aperture» | Del key on selection | Soft-delete with confirmation |
| «Bulk Add from Land Patterns» | Button | Creates apertures for all pads without one |
| «Export to DXF» | File menu | Generates stencil DXF file |
| «Export to Gerber» | File menu | Generates stencil Gerber file |
| «Submit for Approval» | Button | Begins approval workflow |
| «Approve Revision» | Button (Senior+ only) | Creates revision snapshot |
| «Compare with Revision» | Dropdown | Side-by-side revision comparison |
| «Generate Report» | Button | Opens report generator for this design |

---

### 4.07 Stencil Design Wizard

**Purpose:** A guided, multi-step workflow for engineers who are creating a new stencil design from scratch. Particularly useful for less-experienced engineers or new product introductions.

**Related Database Tables:** All stencil design entities, plus package and material libraries.

---

#### Wizard Steps

The Wizard creates a complete `stencil_design` record and all `aperture_designs` through a guided process.

**Step 1 of 7: Project & PCB Selection**
- Select the project (dropdown/search)
- Select the PCB revision (dropdown, filtered to selected project)
- Displays: PCB summary (dimensions, component count, min pitch, IPC class)
- Intelligence Preview: Shows which rule groups will be activated based on PCB characteristics

**Step 2 of 7: Stencil Configuration**
- Assembly side selection
- Stencil material (filtered dropdown with engineering guidance text per selection)
- Stencil thickness (dropdown; system highlights recommended thickness based on min pitch with explanation)
- Stencil coating (dropdown with engineering guidance)
- Design name and design intent text

**Intelligence Assistance at Step 2:**
When thickness is selected, display immediately:
```
Recommended for your design:
  Min pitch: 0.5mm → Maximum recommended thickness: 0.15mm
  Selected: 0.15mm → ✅ Appropriate for pitch range
  
  At 0.15mm thickness, the minimum area ratio threshold is 0.66.
  Components with aperture width < 0.10mm will require special attention.
```

**Step 3 of 7: Paste Selection**
- Solder paste (filtered dropdown; filtered by: not blocked by customer, compatible with selected stencil coating)
- Paste compatibility check runs automatically when selection changes:
  - Particle size vs narrowest aperture check
  - Flux type vs surface finish compatibility
  - Shows compatibility status for each check

**Step 4 of 7: Aperture Design Method**

Engineer selects design approach:
- **Option A: IPC-7351 Automatic** — System generates all apertures from IPC Nominal land patterns. Engineer reviews results.
- **Option B: Manufacturer Recommended** — System applies manufacturer-recommended aperture adjustments where available.
- **Option C: Manual** — Engineer defines each aperture individually (opens to Stencil Design Workspace directly after wizard).

For Options A and B, display a preview table of proposed aperture dimensions for 5–10 sample apertures with their calculated area ratios.

**Step 5 of 7: Thermal Pad Configuration**
Visible only if `has_thermal_pad = true` for any package in the assembly.

For each thermal pad found:
- Shows package name and thermal pad dimensions
- Shows Optimizer recommendation (pre-calculated): coverage %, segmentation strategy, segment count
- Engineer may accept recommendation or open the full Thermal Pad Optimizer for this pad

**Step 6 of 7: Preview & Rule Check**
- Displays the complete aperture table (abbreviated view)
- Displays summary statistics: total apertures, estimated rule check preview (area ratio distribution chart)
- «Run Preliminary Check» — fast rule check (geometry rules only, no defect prediction)
- Shows any critical failures immediately with the count of each severity

**Step 7 of 7: Review & Create**
- Summary of all configuration choices
- Confirmation of rule check status
- Design intent text (pre-populated with key decisions made in the wizard)
- «Create Stencil Design» — creates the record and all apertures, then navigates to the Stencil Design Workspace

`[FR-WIZ-001]` The wizard MUST allow navigation back to previous steps without losing data already entered.

`[FR-WIZ-002]` Progress MUST be savable at any step. The engineer MUST be able to close and resume the wizard.

`[FR-WIZ-003]` If the wizard is closed without completing, the partially created stencil design MUST be saved as a draft with status "wizard_in_progress" (or equivalent).

`[FR-WIZ-004]` Intelligence guidance text MUST appear next to each material/thickness/coating selection explaining the engineering implications of that choice.

---

### 4.08 Aperture Design Assistant

**Purpose:** A focused tool for optimizing a specific aperture that has rule failures or borderline metrics. Provides interactive, real-time engineering guidance.

**Related Database Tables:** `aperture_designs`, `rule_results`, `recommendations`, `calculation_results`

---

#### Features

**F-ADA-01: Interactive Aperture Editor**
Real-time geometry editor with live metric calculations.

**F-ADA-02: Optimization Sliders**
Sliders for Length and Width that show how metric values change as dimensions are adjusted.

**F-ADA-03: Rule Compliance Visualizer**
Visual display showing how current values relate to thresholds (like a target with the current value plotted).

**F-ADA-04: Shape Comparison**
Side-by-side comparison of different aperture shapes (rectangular, home plate, oval) for the same pad geometry, showing which shape achieves the best area ratio.

**F-ADA-05: Neighboring Aperture Awareness**
Displays the nearest neighboring apertures and the gap distances, updating as dimensions change to show bridging risk.

---

#### Screen Specification: Aperture Design Assistant

The assistant opens for a specific aperture (selected from the Stencil Design Workspace).

**Left panel — Geometry Editor:**
Interactive sliders for Length (0.05–20.00mm) and Width (0.05–20.00mm), with a numeric input also available. Corner radius if shape is rounded_rectangle.

**Center panel — Live Metrics Dashboard:**

```
APERTURE METRICS (updates as you adjust geometry)

Area Ratio:           0.683  ████████░░  ✅ PASS (min: 0.66)
Aspect Ratio:         4.55   ██████████  ✅ PASS (min: 1.50)
Paste Volume:         0.0154 mm³
Transfer Efficiency:  83%    (target: >85%)
Aperture Area:        0.1024 mm²
Nearest Gap:          0.17mm ⚠️  (min recommended: 0.20mm)

DEFECT RISK PREVIEW
  Bridge Risk:        ████░░  0.68 → HIGH
  Insufficient Sol.:  ██░░░░  0.34 → LOW
```

**Right panel — Optimization Guidance:**
The top recommendation for this aperture, with the option to «Apply Recommended Geometry» which sets the length and width to the system-recommended values.

`[FR-ADA-001]` All metrics MUST update within 100ms of a slider or input change.

`[FR-ADA-002]` «Apply» MUST update the aperture in the parent Stencil Design Workspace without closing the Assistant (allowing iterative refinement).

`[FR-ADA-003]` «Undo Last Apply» MUST be available to revert the last applied geometry.

---

### 4.09 Thermal Pad Optimizer

**Purpose:** Engineering tool for calculating and optimizing the paste aperture design for exposed thermal pads (QFN, LLP, DFN packages). Directly implements IPC-7093 requirements.

**Related Database Tables:** `thermal_pads`, `aperture_designs`, `calculation_results`, `recommendations`

**Related Engineering Rules:** thermal_pad rule group, IPC-7093

---

#### Features

**F-TPO-01: Thermal Pad Parameter Input**
Input form for thermal pad geometry and via configuration.

**F-TPO-02: Coverage Calculator**
Calculates optimal paste coverage percentage per IPC-7093.

**F-TPO-03: Segmentation Designer**
Interactive tool for selecting and configuring aperture segmentation.

**F-TPO-04: Voiding Risk Assessment**
Predicts voiding risk based on coverage and segmentation strategy.

**F-TPO-05: Output Summary**
Generates the complete aperture design parameters for the thermal pad.

---

#### Screen Specification: Thermal Pad Optimizer

**Input Section:**

| Field | Input | Notes |
|---|---|---|
| Thermal Pad Length (mm) | Number | From land pattern |
| Thermal Pad Width (mm) | Number | From land pattern |
| Via Count | Integer | 0 if no vias |
| Via Drill Diameter (mm) | Number | If vias present |
| Via Pitch (mm) | Number | If vias present |
| Via Tenting | Dropdown | none, top, bottom, both, filled, filled_capped |
| IPC Class | Radio | Inherited from project — adjustable |
| Max Allowable Voiding % | Number | IPC-7093 default per class (Class 3: 25%) |

**Calculation Output (displayed immediately on input):**

```
THERMAL PAD ANALYSIS

  Pad Area:            16.00 mm²
  Via Area (excluded): 1.54 mm²
  Net Paste Area:      14.46 mm²

  COVERAGE RECOMMENDATION (IPC-7093)
  ────────────────────────────────────
  Minimum Coverage:    50.0%  (thermal performance floor)
  Maximum Coverage:    80.0%  (package floating limit)
  ★ Recommended:       65.0%  (optimized for void reduction)
  
  Target Aperture Area: 9.40 mm²

SEGMENTATION RECOMMENDATION
  Strategy:  Window-Pane (3×3)
  Segments:  9 apertures of 0.97mm × 0.97mm each
  Gap Width: 0.20mm between segments
  Actual Coverage: 65.3% ✅ (within IPC-7093 range)

VOIDING PREDICTION
  Without segmentation:  35–55% voiding (⛔ IPC Class 3 FAIL)
  With recommended seg:  8–18% voiding  (✅ IPC Class 3 PASS)
```

**Segmentation Strategy Selector:**
- None (single aperture)
- 2×2 Grid
- 3×3 Grid (Window Pane) — recommended for most cases
- 4×4 Grid (for very large thermal pads)
- Stripe-X (horizontal stripes)
- Stripe-Y (vertical stripes)
- Custom (engineer enters segment dimensions manually)

When a strategy is selected, the calculated segment dimensions and actual coverage percentage update immediately.

`[FR-TPO-001]` «Apply to Aperture Design» MUST create or update the `aperture_designs` record for the thermal pad with the calculated parameters and segment structure.

`[FR-TPO-002]` If via tenting is `none` and via count > 0, the system MUST display: "⚠️ Untented vias under the thermal pad create paste bleed-through risk. Consider via fill or tenting, or account for paste loss in coverage calculation."

`[FR-TPO-003]` The optimizer MUST display the IPC-7093 section number for every recommendation, with a «View Standard Reference» link.

---

### 4.10 Engineering Calculators

**Purpose:** A standalone calculation suite for SMT engineering calculations, usable independently of any specific project or design.

**Related Database Tables:** `calculation_templates`, `calculation_results`

---

#### Features

The calculators are organized as tabs within the Calculators module:

**CALC-01: Area Ratio Calculator**
Inputs: Aperture shape, length, width (and shape-specific parameters), stencil thickness
Outputs: Area ratio, aspect ratio, pass/fail status vs IPC-7525B, transfer efficiency estimate
Formula shown: Changes dynamically based on selected shape

**CALC-02: Paste Volume Calculator**
Inputs: Aperture length, width, stencil thickness
Outputs: Paste volume (mm³), solder volume (mm³), estimated sphere diameter (mm)

**CALC-03: Transfer Efficiency Estimator**
Inputs: Area ratio
Outputs: Transfer efficiency % (from lookup curve), paste volume @ given TE

**CALC-04: Thermal Pad Coverage Calculator**
Inputs: Thermal pad length, width, via count, via diameter, max voiding %, IPC class
Outputs: Recommended coverage %, target aperture area, segmentation recommendation

**CALC-05: Minimum Stencil Thickness Calculator**
Inputs: Minimum aperture width, largest component paste volume requirement
Outputs: Recommended thickness, min thickness (AR floor), max thickness (aspect ratio ceiling), step stencil recommendation

**CALC-06: Paste Bead Life Calculator**
Inputs: Paste product (dropdown), ambient temperature, ambient humidity, time since print start
Outputs: Remaining tack life, remaining floor life, risk assessment, recommendation

**CALC-07: Solder Joint Volume Estimator**
Inputs: Paste volume, metal content %, pad area, lead geometry
Outputs: Estimated solder volume, approximate joint height, adequacy assessment

**CALC-08: Bridging Risk Quick Check**
Inputs: Aperture width, aperture-to-aperture gap, paste slump resistance, stencil thickness
Outputs: Bridging risk score with contributing factor breakdown

---

#### Screen Specification: Calculator Common Layout

Each calculator follows this layout:

```
[Calculator Name]     [IPC Reference]   [Theory Card Link]

INPUTS
──────────────────────────────────────────
  [Input fields with unit labels]
  [Validation warnings shown inline]

CALCULATE    CLEAR    SAVE RESULT

RESULTS
──────────────────────────────────────────
  [Result values with units]
  [Pass/Fail indicators where applicable]
  [Interpretation text from explanation engine]

FORMULA USED
──────────────────────────────────────────
  [Human-readable formula]
  [Source: IPC-XXXX Section X.X]

SAVE TO PROJECT (optional)
──────────────────────────────────────────
  [Project selector]    [Note text]
  SAVE AS CALCULATION RECORD
```

`[FR-CALC-001]` All input fields MUST show their unit label as a suffix (e.g., "0.15 mm", "245.5 °C").

`[FR-CALC-002]` Input validation MUST occur on field blur (not on every keystroke) to avoid interrupting data entry.

`[FR-CALC-003]` Out-of-range inputs MUST show a warning message but not block calculation (allowing engineers to test theoretical scenarios).

`[FR-CALC-004]` «Save Result» MUST create a `calculation_results` record with the input values, output values, and an optional link to a project.

`[FR-CALC-005]` Each calculator MUST display the IPC reference for its formula and a «View Theory Card» link.

---

### 4.11 Rule Engine Manager

**Purpose:** Administrative interface for viewing, editing, and managing engineering rule sets. Critical for customizing the expert system to organizational requirements.

**Related Database Tables:** `rule_sets`, `engineering_rules`, `rule_conditions`, `rule_groups`, `rule_set_memberships`

**Access:** Senior Engineer (view only), Admin (full edit of custom rules), Super Admin (full edit including system rules)

---

#### Features

**F-REM-01: Rule Set Browser**
List all rule sets (system and custom) with version, status, and rule count.

**F-REM-02: Rule Browser**
Filter and browse rules within a rule set.

**F-REM-03: Rule Detail View**
Complete rule specification including condition tree, engineering rationale, and confidence.

**F-REM-04: Custom Rule Creator**
Form for creating organization-specific engineering rules.

**F-REM-05: Rule Version History**
View all versions of a rule with diff comparison.

**F-REM-06: Rule Check Run History**
View past rule check runs for any stencil design.

---

#### Screen Specification: Rule Browser

**Filter options:** Category, Severity, Source, IPC Class Scope, Active Only, Search Text

**Results columns:** Rule Code, Name, Category, Severity, Confidence %, Source, Version, Active, Last Modified

`[FR-REM-001]` System rule sets MUST be clearly labeled "System — IPC Standard" and shown with a read-only indicator for Engineer and Senior Engineer roles.

`[FR-REM-002]` Each rule MUST show its `engineering_rationale` and `consequence_of_violation` in the detail view — never just the condition and threshold.

`[FR-REM-003]` «View Affected Apertures» on a rule MUST show a list of all aperture designs in the current project that are evaluated by this rule, with their pass/fail status.

`[FR-REM-004]` Custom rule creation MUST walk through: rule code, name, category, severity, the condition definition (with a visual condition builder for non-technical users), engineering rationale, consequence, IPC reference, override policy.

`[FR-REM-005]` The condition builder MUST support: parameter name (dropdown of ProcessContext fields), operator, threshold value, AND/OR grouping, nested conditions. It MUST show a plain-language preview: "This rule will FAIL when area_ratio is less than 0.66 AND aperture_shape is rectangle."

---

### 4.12 Materials Library

**Purpose:** Browse, search, and manage the materials used in stencil design: stencil materials, coatings, thicknesses, and solder pastes.

**Related Database Tables:** `stencil_materials`, `stencil_thickness_options`, `stencil_coatings`, `solder_pastes`, `paste_manufacturers`, `material_compatibility_rules`

---

#### Features

**F-MAT-01: Material Browser (tabbed)**
Separate tabs for: Stencil Materials, Coatings, Thicknesses, Solder Pastes.

**F-MAT-02: Material Comparison**
Side-by-side comparison of 2–4 materials on selected properties.

**F-MAT-03: Compatibility Checker**
Enter a material combination (paste + coating + stencil material) and see compatibility status.

**F-MAT-04: Custom Material Creator**
For Admin role: add organization-specific materials.

---

#### Screen Specification: Solder Paste Detail View

The paste detail view is the most complex material view. It displays:

*Identity:* Product name, manufacturer, part number
*Alloy:* Alloy code, composition, liquidus temp, solidus temp
*Flux:* Flux type, IPC J-STD-004B classification, activity level, halogen-free flag
*Particle Size:* IPC class (T3–T8), size range (µm)
*Rheology:* Viscosity (cP), slump resistance, tack force (g), tack life (hours)
*Compatibility:* Compatible stencil coatings, compatible surface finishes (both displayed as green/yellow/red matrix)
*Process:* Storage temp range, shelf life, floor life hours
*Documentation:* Datasheet link, SDS link, notes

`[FR-MAT-001]` The Compatibility Checker MUST show a 3-way matrix: paste × coating × surface finish, with green (compatible), yellow (conditional), red (incompatible) for each combination.

`[FR-MAT-002]` When viewing a paste used in the active project, a banner MUST show: "This paste is used in [N] stencil designs in your active project."

`[FR-MAT-003]` For pastes, the field `floor_life_hours` MUST be prominently displayed with a visual indicator: "This paste must be used within [X] hours of removing from refrigeration."


---

### 4.13 Process & Equipment Registry

**Purpose:** Maintain the organization's inventory of SMT production equipment and validated process parameter sets.

**Related Database Tables:** `printers`, `placement_machines`, `reflow_ovens`, `reflow_profiles`, `print_parameter_sets`, `process_environments`

---

#### Features

**F-PEQ-01: Equipment Registry**
Tabbed view of all registered equipment: Printers, Placement Machines, Reflow Ovens.

**F-PEQ-02: Reflow Profile Manager**
Create, edit, and validate reflow profiles for specific paste and oven combinations.

**F-PEQ-03: Print Parameter Set Manager**
Create and manage validated printing parameter sets for specific stencil/printer/paste combinations.

**F-PEQ-04: Environmental Log**
View and add ambient condition records for the print floor.

---

#### Screen Specification: Reflow Profile Form

**Required fields:**

| Field | Input | Validation |
|---|---|---|
| Profile Name | Text | Required |
| Solder Paste | Dropdown | Required — must select existing paste |
| Alloy Type | Dropdown | sac305, sac405, snpb, low_temp_bismuth |
| Preheat Min Temp (°C) | Number | 50–200°C |
| Preheat Max Temp (°C) | Number | > Preheat Min |
| Preheat Time (s) | Number | 10–300s |
| Soak Min Temp (°C) | Number | > Preheat Max |
| Soak Max Temp (°C) | Number | > Soak Min |
| Soak Time (s) | Number | 30–300s |
| Peak Min Temp (°C) | Number | > Liquidus |
| Peak Max Temp (°C) | Number | ≤ component max reflow temp |
| Time Above Liquidus (s) | Number | IPC-7530: 30–90s |
| Cooling Rate Max (°C/s) | Number | Typically ≤ 4°C/s |

**Intelligence validation (run on save):**
`[FR-PEQ-001]` If TAL < 30s: CRITICAL warning — "Time above liquidus is below IPC-7530 minimum of 30 seconds. Cold joint risk is HIGH."
`[FR-PEQ-002]` If TAL > 90s: WARNING — "Time above liquidus exceeds IPC-7530 maximum of 90 seconds. Excessive IMC growth risk."
`[FR-PEQ-003]` If Cooling Rate > 4°C/s: WARNING — "Cooling rate exceeds 4°C/s. Thermal stress cracking risk in ceramic components."

---

#### Screen Specification: Print Parameter Set Form

**Required fields:**

| Field | Input | Source |
|---|---|---|
| Name | Text | |
| Printer | Dropdown | `printers` |
| Solder Paste | Dropdown | `solder_pastes` |
| Squeegee Speed (mm/s) | Number | |
| Squeegee Pressure (kg) | Number | |
| Squeegee Angle (°) | Number | |
| Squeegee Type | Dropdown | metal, polyurethane |
| Separation Speed (mm/s) | Number | |
| Separation Distance (mm) | Number | |
| Print Gap (mm) | Number | |
| Cleaning Frequency (prints) | Integer | |
| Cleaning Mode | Dropdown | |
| Board Support Type | Dropdown | |

**Intelligence Triggers:**
`[FR-PEQ-004]` Separation speed > 3.0mm/s for any stencil with pitch ≤ 0.5mm MUST display: "Separation speed of [X]mm/s may cause paste drag on [min_pitch]mm pitch apertures. Recommend ≤ 2.0mm/s."
`[FR-PEQ-005]` Squeegee pressure outside 3–12kg MUST display a range warning.
`[FR-PEQ-006]` If paste floor life is 4 hours and cleaning frequency is 200 prints (which could take 4+ hours), display: "Verify that cleaning frequency allows completion within paste floor life of [X] hours."

---

### 4.14 Inspection Data Manager

**Purpose:** Import, view, and manage inspection data (SPI, AOI, X-Ray) linked to stencil designs. The feedback loop from production back to design.

**Related Database Tables:** `spi_measurements`, `spi_deposit_measurements`, `aoi_results`, `aoi_defect_findings`, `xray_results`, `inspection_equipment`

---

#### Features

**F-INS-01: Inspection Session List**
All inspection sessions for the active stencil design, sorted by date.

**F-INS-02: SPI Data Importer**
Import SPI measurement files from common SPI machine formats or manual CSV entry.

**F-INS-03: SPI Results Viewer**
Visualize paste deposit measurements: volume distribution chart, per-aperture status table, Cpk analysis.

**F-INS-04: AOI Result Logger**
Log AOI session results and individual defect findings.

**F-INS-05: X-Ray Result Logger**
Log X-ray inspection results with voiding measurements.

**F-INS-06: SPI-to-Design Correlation**
Correlation analysis comparing measured SPI volumes against predicted volumes from aperture design.

---

#### Screen Specification: SPI Results Viewer

**Summary Header:**
- Session date, board serial, printer used, pass/fail overall
- Total deposits: [N] — Passed: [N] — Failed: [N] — Marginal: [N]

**Volume Distribution Chart:**
Histogram of `measured_volume_pct` values across all deposits. Reference lines at ±25% (typical SPI limits), ±10% (process control limits), 100% (nominal). The distribution shape immediately communicates systematic under/over-deposition vs. random variation.

**Per-Aperture Status Table:**
| Column | Source |
|---|---|
| Ref Des | `spi_deposit_measurements.reference_designator` |
| Pad # | `spi_deposit_measurements.pad_number` |
| Volume % | `spi_deposit_measurements.measured_volume_pct` |
| Height % | `spi_deposit_measurements.measured_height_pct` |
| X Offset (mm) | `spi_deposit_measurements.x_offset_mm` |
| Y Offset (mm) | `spi_deposit_measurements.y_offset_mm` |
| Status | `spi_deposit_measurements.pass_fail` |
| Failure Code | `spi_deposit_measurements.failure_code` |
| Designed AR | From linked `aperture_designs.area_ratio` |

**Correlation Analysis Panel:**
For each aperture design with measured data:
- Designed area ratio vs. measured transfer efficiency (volume% / 100)
- Scatter plot: x = area_ratio, y = measured_volume_pct
- Deviation from predicted transfer efficiency (from CALC-TE)

`[FR-INS-001]` If measured average volume for any aperture group is consistently below 75% across 3+ boards, the system MUST create a Learning Event and display: "Systematic paste volume deficit detected on [N] consecutive boards. Aperture design review recommended."

`[FR-INS-002]` «Correlate with Design» MUST generate a full SPI-to-design correlation report showing predicted vs. actual transfer efficiency per aperture, ranked by deviation.

`[FR-INS-003]` SPI data import MUST support: CSV (generic column mapping), manual entry per aperture. Vendor-specific format support is Phase 4+.

---

### 4.15 Defect Library & Investigation

**Purpose:** Two-function module: (1) browse the engineering defect knowledge library; (2) manage defect records and conduct structured investigations.

**Related Database Tables:** `defect_categories`, `defect_types`, `failure_mechanisms`, `root_causes`, `corrective_actions`, `preventive_actions`, `defect_records`, `defect_investigations`, `case_studies`

---

#### Features

**F-DEF-01: Defect Library Browser**
Browsable, searchable encyclopedia of SMT defect types with full engineering detail.

**F-DEF-02: Defect Detail View**
Complete defect profile: description, failure mechanisms, root causes, corrective actions, related images, case studies.

**F-DEF-03: Defect Record Logger**
Log a defect occurrence found during inspection or production.

**F-DEF-04: Defect Investigation Workspace**
Structured 5-Why / 8D investigation workspace with knowledge base integration.

**F-DEF-05: Investigation Closure & Knowledge Capture**
Structured form for closing an investigation and capturing lessons learned.

---

#### Screen Specification: Defect Library Browser

**Left panel — Category Tree:**
```
Paste Volume Defects
  ├── Insufficient Solder (DEF-003)
  ├── Excess Solder (DEF-008)
  └── Missing Deposit (DEF-012)
Alignment Defects
  ├── Component Skew (DEF-015)
  └── Offset Placement (DEF-016)
Reflow Defects
  ├── Solder Bridge (DEF-011)
  ├── Tombstone (DEF-019)
  ├── Head-in-Pillow (DEF-022)
  ├── Mid-Chip Solder Ball (DEF-025)
  ├── Component Float (DEF-028)
  └── Voiding (DEF-031)
Joint Quality Defects
  ├── Cold Joint (DEF-035)
  ├── Non-Wet Open (DEF-038)
  └── Solder Open (DEF-040)
[additional categories...]
```

**Right panel — Defect Detail:**

*When a defect is selected, show:*
- Name, code, severity badge, IPC acceptance criteria per class
- IPC reference
- Visual description (text)
- Process stage origin badge
- Contributing factor tags: [Stencil Design] [Paste] [Reflow]
- Detection methods list

*Tabs within defect detail:*
- **Failure Mechanisms** — Physical/chemical explanation of how this defect forms
- **Root Causes** — All known root causes, sorted by `frequency_as_primary`
  - Each root cause shows: category, description, process variable, typical direction
  - Sub-tabs: Corrective Actions, Preventive Actions
- **Prediction Model** — The defect's risk factors and their weights (from Defect Prediction Engine)
- **Case Studies** — Org case studies tagged with this defect type
- **Images** — Reference images for this defect type
- **Your History** — Org's historical defect records for this type

`[FR-DEF-001]` Searching within the Defect Library MUST match on: defect name, aliases, visual description text, IPC reference, root cause descriptions.

`[FR-DEF-002]` From any Defect detail view, «Log This Defect» MUST pre-populate the Defect Record form with the defect type.

---

#### Screen Specification: Defect Investigation Workspace

The investigation workspace is a structured analysis environment.

**Header Section:**
- Title, status badge, lead engineer, opened date
- Problem Statement (large text field)
- Root Cause Analysis Method selector (5-Why, 8D, Ishikawa, Fault Tree)

**5-Why Analysis Panel:**
```
Why 1: [text field — What is the immediate cause?]
  Why 2: [text field — Why did Why 1 occur?]
    Why 3: [text field — Why did Why 2 occur?]
      Why 4: [text field — Why did Why 3 occur?]
        Why 5: [text field — Why did Why 4 occur?]
          Root Cause: [system suggests from knowledge base]
```

When each "Why" is entered, the system searches the knowledge base for matching `root_causes` and displays suggestions:
```
KNOWLEDGE BASE SUGGESTIONS for "paste did not release from aperture":
  ★ Low area ratio (0.58) — Confidence: 91% — 43% of similar cases
  ★ Stencil aperture wall roughness — Confidence: 72% — 28% of cases
  ○ Paste tack degradation — Confidence: 45% — 18% of cases
```

**Containment Actions (D2):**
Free text field for documenting immediate containment. «Mark as Contained» button.

**Corrective Actions Panel:**
When a root cause is confirmed («Set as Confirmed Root Cause»), the system displays all `corrective_actions` linked to that root cause, with effectiveness scores and implementation effort indicators. Engineer checks off actions taken.

**Investigation Closure Form (Senior Engineer only):**
- Effectiveness Verification (text)
- Lessons Learned (text)
- Yield Before/After % (numbers — triggers Learning Event)
- «Generate New Rule from This Investigation» checkbox
  - If checked: opens New Rule form pre-populated from investigation findings
- «Create Case Study» checkbox
  - If checked: opens Case Study form pre-populated from investigation data

`[FR-DEF-003]` When a root cause is confirmed, the system MUST immediately display: "Based on [N] past investigations with this root cause in your organization, the average yield improvement from corrective actions was [X]%."

`[FR-DEF-004]` Investigation closure MUST create a Learning Event that updates the `effectiveness_score` on the confirmed `corrective_actions`.

`[FR-DEF-005]` Open investigations MUST appear in the Engineering Alerts on the Dashboard and the Project detail view.

---

### 4.16 Intelligence Dashboard

**Purpose:** A dedicated view of the Engineering Intelligence Engine's full output for the active stencil design. The "senior engineer's analysis report" rendered as a live screen.

**Related Database Tables:** `design_score_cards`, `defect_risk_assessments`, `yield_predictions`, `rule_check_runs`, `rule_results`, `recommendations`, `process_context_snapshots`

---

#### Features

**F-INT-01: Full Design Scorecard**
Complete scorecard with drill-down into each sub-score component.

**F-INT-02: Defect Risk Matrix**
All 12 defect types with full risk breakdowns.

**F-INT-03: Yield Prediction Panel**
FPY prediction with confidence interval and yield-killer analysis.

**F-INT-04: Process Context Inspector**
View the exact ProcessContext that was used for the last analysis run.

**F-INT-05: Analysis Run History**
Chronological list of all analysis runs for this design, showing score progression over time.

---

#### Screen Specification: Intelligence Dashboard

**Score Card Drill-down:**
Each sub-score is expandable. When expanded, shows:
- The weighted components of that score
- Which specific findings drove the score up or down
- Comparison to previous run ("↑ +8 points from last run")

**Yield Prediction Panel:**
```
PREDICTED FIRST-PASS YIELD

  Point Estimate:    94.2%
  90% Confidence:    [90.1% ─────────────────── 97.1%]
  
  If all recommendations implemented:  97.8% (potential improvement: +3.6%)

YIELD IMPACT BY DEFECT TYPE
  Solder Bridge:          contributes 2.1% yield loss
  Insufficient Solder:    contributes 1.4% yield loss
  Voiding (Class 3):      contributes 1.2% yield loss
  All other defects:      contributes 1.1% yield loss

UNCERTAINTY SOURCES
  ⚠ Limited historical data for this package combination (< 5 similar designs)
  ⚠ Process parameters not fully specified (some context fields missing)
```

**Process Context Inspector:**
A tree view of the complete `ProcessContext` used for the last analysis run. Allows engineers to verify what data the Intelligence Engine saw. Displays:
- Context completeness: 83% (what's missing and why it matters)
- Each context section expandable with field names and values
- Missing fields highlighted in orange

`[FR-INT-001]` The Intelligence Dashboard MUST be read-only — no editing occurs here. It is a display/analysis screen only.

`[FR-INT-002]` «Re-run Analysis» on the Intelligence Dashboard MUST re-run the complete Intelligence Engine pipeline and refresh all panels.

`[FR-INT-003]` «Export Analysis Report» MUST generate a PDF report of the Intelligence Dashboard content (separate from the formal stencil design report).

`[FR-INT-004]` The Analysis Run History MUST show a mini-score trend chart (sparkline) showing overall score progression across runs.

---

### 4.17 Recommendation Viewer

**Purpose:** Full-detail view of all recommendations for the active stencil design, with engineer workflow for reviewing, implementing, and dismissing recommendations.

**Related Database Tables:** `recommendations`, `recommendation_options`, `recommendation_conflicts`, `rule_results`

---

#### Features

**F-RCV-01: Prioritized Recommendation List**
All recommendations sorted by priority score with severity badges.

**F-RCV-02: Recommendation Detail**
Full recommendation card: Why, What, How, Expected Improvement, Tradeoffs, Options.

**F-RCV-03: Option Comparison Table**
Side-by-side comparison of recommendation options (A, B, C).

**F-RCV-04: Conflict Report**
Display of any detected conflicting recommendations and their resolutions.

**F-RCV-05: Engineer Response Workflow**
Actions for each recommendation: Implement, Defer, Dismiss, Request More Info.

---

#### Screen Specification: Recommendation Detail

Each recommendation is displayed as a full card:

```
══════════════════════════════════════════════════════════════
[#1]  ⬛ CRITICAL  |  Confidence: 92%  |  Priority Score: 0.94
TITLE: Increase Aperture Area Ratio — U1 Pin 3

WHY THIS IS FLAGGED:
  [Content from recommendations.why]

ENGINEERING THEORY:
  [Theory card content — expandable]  [Theory Card TC-001 ▼]

IPC REFERENCE:
  IPC-7525B Section 4.2 — [View Reference ►]

WHAT TO DO:
  [Content from recommendations.what]

HOW TO IMPLEMENT:
  [Content from recommendations.how]

OPTIONS COMPARISON:
  ┌────────────────┬──────────────┬──────────────┬──────────────┐
  │                │ Option A ★  │ Option B     │ Option C     │
  ├────────────────┼──────────────┼──────────────┼──────────────┤
  │ AR Improvement │ +0.13        │ +0.14        │ +0.05*       │
  │ Bridge Risk    │ ↑ Moderate   │ ↓ All pads   │ ↓ Slight     │
  │ Cost           │ Low          │ Medium       │ Medium       │
  │ Effort         │ Minutes      │ Days         │ Fast         │
  │ Confidence     │ 91%          │ 88%          │ 75%          │
  └────────────────┴──────────────┴──────────────┴──────────────┘

EXPECTED IMPROVEMENT (Option A):
  [Content from recommendations.expected_improvement]

TRADEOFFS:
  [Content from recommendations.tradeoffs]

RELATED DEFECTS:  [Insufficient Solder ►]  [Solder Opens ►]

ENGINEER ACTIONS:
  [Apply Option A]  [Apply Option B]  [Apply Option C]
  [Defer]  [Dismiss with reason]  [Navigate to Aperture ►]
══════════════════════════════════════════════════════════════
```

`[FR-RCV-001]` «Apply Option [X]» for a geometry change MUST directly update the `aperture_designs` record and trigger a recalculation of area ratio and related metrics.

`[FR-RCV-002]` «Apply Option [X]» for a material change MUST navigate to the stencil header and pre-select the recommended material, prompting the engineer to confirm.

`[FR-RCV-003]` «Dismiss» MUST require one of: "Not applicable", "Already implemented", "Accepted risk", "Engineering judgment". The dismissal reason is stored in `recommendations.engineer_feedback`.

`[FR-RCV-004]` Once the engineer marks a recommendation as «Implemented», the system MUST: set `engineer_status = 'implemented'`, flag it for Learning Event creation (pending outcome measurement), and move it to the bottom of the list with a green badge.

`[FR-RCV-005]` The Conflict Report section MUST appear at the top of the Recommendation Viewer if any `recommendation_conflicts` exist. Each conflict shows: what conflicted, how it was resolved (or that engineer decision is needed).

---

### 4.18 Knowledge Base

**Purpose:** Searchable repository of engineering knowledge: IPC standards, theory cards, case studies, and experiments.

**Related Database Tables:** `ipc_standards`, `ipc_references`, `theory_cards`, `case_studies`, `experiments`

---

#### Features

**F-KB-01: IPC Standards Browser**
Browse IPC standards and drill into specific sections.

**F-KB-02: Theory Cards Library**
Browse and search engineering theory explanations at three depth levels.

**F-KB-03: Case Studies Browser**
Browse published case studies with filter by defect type, package family, tags.

**F-KB-04: Experiment Registry**
View completed experiments with conclusions and generated rules.

**F-KB-05: Global Knowledge Search**
Full-text search across all knowledge entities.

---

#### Screen Specification: Case Study Detail

A case study is rendered as a structured technical document:

| Section | Source Field | Display |
|---|---|---|
| Title | `case_studies.title` | Header |
| Abstract | `case_studies.abstract` | Highlighted summary box |
| Problem | `case_studies.problem_description` | Full text |
| Assembly Context | `case_studies.assembly_context` | Text with package tags |
| Investigation | `case_studies.investigation_approach` | Full text |
| Root Causes | `case_studies.root_causes_identified` | Text with links to RootCause records |
| Solution | `case_studies.solution_implemented` | Full text |
| Results | `case_studies.results_achieved` | Highlighted — quantified improvement |
| Lessons Learned | `case_studies.lessons_learned` | Callout box |
| Related Defects | `case_studies.defect_type_ids` | Tags with links |
| Related Images | Linked `image_records` | Thumbnail gallery |

`[FR-KB-001]` Case studies authored within the organization and marked `is_published = true` MUST be visible to all engineers in the organization.

`[FR-KB-002]` Draft case studies (not published) MUST be visible only to the author and Admin role.

`[FR-KB-003]` «Was this helpful?» thumbs up/down MUST be available on every case study and theory card, updating the `helpful_votes` count.

`[FR-KB-004]` The Knowledge Base search MUST return results across all entity types (IPC references, theory cards, case studies, defect types, root causes, corrective actions) with results clearly labeled by type.

`[FR-KB-005]` «Create Case Study» MUST be available from: closed DefectInvestigations, completed Experiments, and directly from the Knowledge Base. Pre-population from source investigation is supported.

---

### 4.19 Image Library

**Purpose:** Manage and search all engineering images: inspection photos, defect evidence, package drawings, microscope images, and reference images.

**Related Database Tables:** `image_records`, `image_annotations`, `image_tags`

---

#### Features

**F-IMG-01: Image Gallery**
Grid or list view of images with filter/search.

**F-IMG-02: Image Upload**
Upload images with metadata entry and auto-tagging assistance.

**F-IMG-03: Image Viewer**
Full-resolution viewer with annotation tools.

**F-IMG-04: Annotation Editor**
Add/edit/delete annotations on images.

**F-IMG-05: Image Linker**
Link images to entities (defect types, case studies, aperture designs, etc.).

---

#### Screen Specification: Image Gallery

**Filter Panel:**
- Image Type (multi-select: SPI, AOI, X-Ray, Microscope, etc.)
- Subject Type (defect, package, aperture, etc.)
- Linked Entity (search by ref des, defect type, package name)
- Quality Rating (Acceptable and above / All)
- Date Range
- Engineer (who uploaded)
- Tags (multi-select)
- Has Annotations (Yes/No/Any)
- Magnification Range (for microscope images)

**Gallery Grid:**
Each image card shows:
- Thumbnail (200×200)
- Title
- Image type badge
- Subject type badge
- Quality rating stars
- Annotation count indicator
- Linked entity tag (e.g., "DEF-011", "U3", "QFN-32")
- Upload date

`[FR-IMG-001]` Images MUST be displayed as thumbnails loaded from Supabase Storage, not full-resolution on load.

`[FR-IMG-002]` The Image Viewer MUST support: zoom in/out (mouse wheel), pan (drag), fit to screen, actual size.

`[FR-IMG-003]` Annotations MUST be displayed as overlays on the image. Clicking an annotation shows its label and description.

`[FR-IMG-004]` «Add Region Annotation» MUST allow the engineer to draw a rectangle on the image, then enter a label and description. The region coordinates are stored as percentage offsets.

`[FR-IMG-005]` Image upload MUST accept: PNG, JPEG, TIFF, BMP, SVG. Maximum file size: 50MB per image.

`[FR-IMG-006]` On upload, the engineer MUST be required to select: Image Type, Subject Type, and Title. All other metadata is optional.

---

### 4.20 Report Generator

**Purpose:** Generate professional engineering reports for stencil designs, defect investigations, projects, and analysis results.

**Related Database Tables:** `report_templates`, `generated_reports`, `stencil_designs`, `defect_investigations`, `projects`

---

#### Features

**F-RPT-01: Report Type Selector**
Choose the report type and the entity to report on.

**F-RPT-02: Report Configurator**
Configure report options: sections to include, date range, engineer signature.

**F-RPT-03: Report Preview**
In-app preview before generating the final PDF.

**F-RPT-04: Report Generation**
Generate PDF/XLSX and store to Supabase Storage.

**F-RPT-05: Report History**
View all previously generated reports for the current project.

---

#### Screen Specification: Report Configuration

**Step 1 — Select Report Type:**

| Report Type | Primary Entity | Formats |
|---|---|---|
| Stencil Design Report | Stencil Design | PDF |
| Area Ratio Analysis | Stencil Design | PDF + XLSX |
| Paste Volume Analysis | Stencil Design | PDF + XLSX |
| Defect Investigation Report | Investigation | PDF |
| Project Summary | Project | PDF |
| Experiment Results | Experiment | PDF |
| Intelligence Analysis Report | Stencil Design | PDF |
| SPI Correlation Report | SPI Measurement Session | PDF + XLSX |

**Step 2 — Configure:**
- Report title (pre-populated, editable)
- Engineer signature (checkbox — requires `signature_storage_path` to be set)
- Sections to include/exclude (checkboxes per section)
- Logo in header (checkbox — requires org logo to be set)
- Date/time stamp format

**Step 3 — Generate:**
«Generate PDF» or «Generate XLSX» — shows progress indicator, then download prompt.

`[FR-RPT-001]` Generated reports MUST be stored in Supabase Storage and a `generated_reports` record created.

`[FR-RPT-002]` Every report MUST include a footer with: application version, rule set version used, generation timestamp, and generating engineer's name.

`[FR-RPT-003]` Reports MUST include the IPC class for the project and which rule set was applied.

`[FR-RPT-004]` Signed reports (when `is_signed = true`) MUST embed the engineer's signature image and name in the signature block.

`[FR-RPT-005]` Previously generated reports MUST be listed in Report History with download links. Reports are never regenerated in place — each generation creates a new report record.

---

### 4.21 Customer & Organization Manager

**Purpose:** Manage customer records, organization-level settings, and approved materials lists.

**Related Database Tables:** `customers`, `products`, `organizations`, `organization_settings`

**Access:** Admin and above.

---

#### Features

**F-CUS-01: Customer List**
Manage customer records with contact information and engineering requirements.

**F-CUS-02: Customer Detail**
Full customer profile including required IPC class, approved materials, and regulatory requirements.

**F-CUS-03: Approved Materials Manager**
Manage the per-customer approved paste and stencil material lists.

**F-CUS-04: Organization Settings**
Configure organization-level defaults and behaviors.

---

#### Screen Specification: Organization Settings

Key configurable settings (stored in `organization_settings`):

| Setting | Type | Description |
|---|---|---|
| Default IPC Class | Dropdown | Class 1/2/3 — floor for all projects |
| Default Units | Radio | Metric / Imperial |
| Project Number Format | Text pattern | e.g., "{ORG}-{YEAR}-{SEQ:04d}" |
| Stencil Number Format | Text pattern | |
| Report Number Format | Text pattern | |
| Four-Eyes Approval | Boolean | Require different engineer to approve stencil |
| Rule Override Approval | Boolean | Require Senior+ to approve rule overrides |
| Auto-Run Analysis on Save | Boolean | Trigger analysis when aperture changes |
| Default Rule Set | Dropdown | Which rule set applies to new designs |
| Organization Logo | File upload | PNG/SVG for reports |

`[FR-CUS-001]` Changing `default_ipc_class` MUST display: "Changing the default IPC class will not affect existing projects. New projects will use the new default."

`[FR-CUS-002]` The Approved Materials Manager MUST show, for each approved paste: product name, manufacturer, flux type, particle class, and a badge showing how many active designs use it.

---

### 4.22 User & Access Manager

**Purpose:** Manage engineer accounts, role assignments, and access control for the organization.

**Related Database Tables:** `engineers`, `roles`, `permissions`, `engineer_roles`, `role_permissions`

**Access:** Admin and above.

---

#### Features

**F-USR-01: Engineer List**
View all engineers in the organization with their roles and last activity.

**F-USR-02: Invite Engineer**
Send email invitation to a new engineer (integrates with Supabase Auth).

**F-USR-03: Engineer Profile Editor**
Edit engineer details and role assignments.

**F-USR-04: Role Manager**
View role definitions and their permission assignments.

---

#### Screen Specification: Engineer List

Columns: Name, Email, Title, Roles, IPC Certifications, Last Login, Status (Active/Inactive)

Actions:
- «Invite Engineer» — sends invitation email
- Click on engineer → Engineer Profile Editor
- «Deactivate» — sets `is_active = false`, revokes active sessions
- «Reassign Projects» — when deactivating, reassigns owned projects to another engineer

`[FR-USR-001]` Deactivating the last Admin MUST be blocked with: "Cannot deactivate the last administrator. Promote another engineer to Admin first."

`[FR-USR-002]` Role changes MUST take effect on the engineer's next login. The engineer is notified by in-app notification.

`[FR-USR-003]` Engineer profile changes (name, title) MUST be reflected in all future reports but MUST NOT retroactively change the author attribution on historical records.

---

### 4.23 Application Settings

**Purpose:** Per-engineer preferences for application behavior, display, and defaults.

**Related Database Tables:** `user_preferences`, `feature_flags`, `notification_preferences`

---

#### Screen Specification: Settings Panel (tabbed)

**Tab 1 — General:**
- Preferred Units: Metric (mm) / Imperial (inch)
- Default IPC Class: dropdown (personal default, overrides org default)
- Language: English (v1.0 only; localization is Phase 4+)
- Auto-save interval: 30s / 1min / 2min / Manual only
- Confirm before delete: Yes / No

**Tab 2 — Display:**
- Theme: Light / Dark / System Default
- Font Size: Small / Medium / Large / Extra Large
- Decimal places for measurements: 2 / 3 / 4
- Number format: 0.1234 / 0,1234 (locale)
- Color-blind mode: None / Deuteranopia / Protanopia (replaces red/green with accessible colors)

**Tab 3 — Notifications:**
Per notification type, toggle: In-App / Email

Notification types:
- Design approved / rejected
- Rule check critical failure
- Defect investigation assigned
- Knowledge review flag raised
- Stencil revision approval requested
- Project status change

**Tab 4 — Engineering Defaults:**
- Default stencil material (for new designs)
- Default stencil thickness
- Default solder paste
- Default printer
- Default rule set

**Tab 5 — About:**
- Application version
- Database schema version
- License information
- «Check for Updates»
- «Export My Data» (personal data export for GDPR compliance)

`[FR-SET-001]` All settings MUST be saved immediately on change (no explicit Save button for settings).

`[FR-SET-002]` «Reset to Organization Defaults» MUST be available on the General and Engineering Defaults tabs.

---

## 5. Cross-Module User Workflows

This section describes complete end-to-end workflows that span multiple modules.

### WORKFLOW-01: New Product Introduction (NPI) — Complete Stencil Engineering

**Actors:** Engineer (primary), Senior Engineer (approver)
**Duration:** Typically 2–5 working days

**Steps:**

```
STAGE 1: PROJECT SETUP
  1.1  Engineer creates new Project (Module 4.02)
       → Selects customer, sets IPC Class 3, phase = NPI
  1.2  Engineer creates PCB Assembly (Module 4.03)
       → Enters board dimensions, surface finish, assembly sides
  1.3  Engineer creates PCB Revision A (Module 4.03)
       → Marks as current revision
       → Checks: has_bgAs, has_qfns, min_pitch_mm

STAGE 2: COMPONENT LIBRARY SETUP
  2.1  Engineer verifies required packages in Package Library (Module 4.04)
       → Creates custom packages if any are missing
  2.2  Engineer defines Land Patterns for each unique package (Module 4.05)
       → Uses IPC-7351 Nominal calculator as starting point
       → Engineer reviews and adjusts paste mask expansion per package

STAGE 3: STENCIL DESIGN
  3.1  Engineer opens Stencil Design Wizard (Module 4.07)
       → Selects PCB revision
       → System activates: fine_pitch, bga_lga, thermal_pad rule groups
       → Engineer selects: 0.15mm electroform stencil + nano coating + SAC305 T4
       → Wizard generates IPC-7351 Nominal apertures for all pads
  3.2  Thermal Pad Optimizer runs automatically for all QFN components
       → Engineer reviews and accepts segmentation recommendations
  3.3  Engineer reviews aperture table in Stencil Design Workspace (Module 4.06)
       → Sorts by rule_check_status to find failures
       → Uses Aperture Design Assistant to optimize failing apertures

STAGE 4: ANALYSIS & REVIEW
  4.1  Engineer runs full analysis (Module 4.06: «Run Analysis»)
       → Intelligence Panel updates with: score, defect risks, recommendations
  4.2  Engineer reviews Recommendation Viewer (Module 4.17)
       → Implements Priority 1 and 2 recommendations
       → Re-runs analysis to confirm score improvement
  4.3  Engineer adds Design Intent note explaining key decisions

STAGE 5: APPROVAL
  5.1  Engineer submits for approval (Module 4.06: «Submit for Approval»)
       → Senior Engineer receives notification
  5.2  Senior Engineer reviews in Module 4.06
       → Reviews rule results, scores, recommendations
       → May add comments as stencil design notes
       → Approves revision → StencilRevision snapshot created

STAGE 6: REPORTING
  6.1  Engineer generates Stencil Design Report (Module 4.20)
       → Signs report (requires signature on profile)
       → Report stored in Supabase Storage
       → Report number assigned: PRJ-2026-0042-STN-001

STAGE 7: PRODUCTION FEEDBACK
  7.1  After first production run, SPI data imported (Module 4.14)
       → System correlates with design predictions
       → Learning Events created
  7.2  Any defects found → Defect Records logged (Module 4.15)
```

---

### WORKFLOW-02: Defect Investigation & Corrective Action

**Actors:** Engineer (lead), Senior Engineer (closer)
**Trigger:** Defect found in production or inspection

```
  1.  Defect Record logged in Module 4.15
      → Defect type selected
      → Quantity, board serial, ref des recorded
      → Linked to stencil design
  
  2.  «Open Investigation» creates DefectInvestigation
      → Status: open, lead engineer assigned
      → Dashboard alert created for lead engineer
  
  3.  Engineer navigates to Investigation Workspace
      → Selects analysis method (5-Why)
      → Enters problem statement
      → Enters why chain
      → Knowledge base suggests matching root causes

  4.  Engineer confirms root cause
      → System shows related corrective actions + effectiveness scores
      → Engineer documents containment actions (D2)
      → Engineer implements corrective action on stencil design
         (navigates to Aperture Design Assistant)
  
  5.  Re-run Analysis on corrected stencil design
      → New score card shows improvement
      → New prediction shows reduced defect risk
  
  6.  Engineer documents corrective actions taken in investigation
  
  7.  Senior Engineer closes investigation
      → Enters yield before/after
      → Enters effectiveness verification
      → Enters lessons learned
      → Selects «Create Case Study»
  
  8.  Learning System processes closure
      → Corrective action effectiveness score updated
      → Pattern record updated
      → Case study created in Knowledge Base
      → Confidence adjustments logged
```

---

### WORKFLOW-03: Rule Override Request & Approval

**Trigger:** Engineer determines a rule failure is acceptable in context

```
  1.  Engineer selects a failing aperture in Stencil Design Workspace
  
  2.  In Aperture Detail Panel, engineer clicks «Request Override»
      on a specific rule failure
  
  3.  Override form opens showing:
      - Rule code and description
      - Engineering rationale for the rule
      - Consequence of violation
      - Override justification prompt
  
  4.  Engineer enters justification text (mandatory, minimum 50 chars)
  
  5.  If override_requires_approval = true for this rule:
      → Request submitted; stencil design locked for this aperture
      → Notification sent to Senior Engineers
      → Status: "Override Pending Approval"
  
  6.  Senior Engineer reviews in notification panel:
      → Sees rule, evaluated value, justification
      → Can approve (with optional comment) or reject
  
  7.  If approved:
      → aperture_designs.engineer_override = true
      → override_justification = engineer's text
      → override_approved_by_id = approving engineer
      → ProjectNote created: "Rule [code] overridden by [eng], approved by [eng]. Justification: [text]"
      → AuditLog entry created
  
  8.  If rejected:
      → Notification sent to engineer with rejection reason
      → Override request cleared; aperture remains in fail state
```

---

## 6. Global Search Requirements

**Purpose:** Engineers must be able to find any piece of information in the system from a single search interface, accessible from any screen.

### 6.1 Search Access

`[FR-SRC-001]` Global Search MUST be accessible via: search field in the toolbar, keyboard shortcut «Ctrl+G», and from the Edit menu.

`[FR-SRC-002]` The search field MUST be visible in the toolbar at all times.

### 6.2 Search Scope

Global Search queries across all of the following entity types simultaneously:

| Entity Type | Searchable Fields |
|---|---|
| Projects | project_number, name, description, tags |
| Stencil Designs | stencil_number, name |
| PCB Assemblies | name, part_number |
| SMT Packages | ipc_name, common_name |
| Components | manufacturer_part_number, description |
| Defect Types | name, aliases, visual_description |
| Case Studies | title, abstract, lessons_learned |
| Root Causes | name, description |
| Corrective Actions | name, description |
| Engineering Rules | rule_code, name, engineering_rationale |
| IPC References | section_title, summary |
| Theory Cards | title, summary_text |
| Solder Pastes | product_name, part_number |
| Engineers | full_name, email |
| Customers | name, code |

### 6.3 Search Behavior

`[FR-SRC-003]` Search MUST return results within 500ms for typical queries.

`[FR-SRC-004]` Results MUST be grouped by entity type with a count badge per group.

`[FR-SRC-005]` Each result MUST show: entity type label, primary display name, a brief excerpt with the search term highlighted, and last modified date.

`[FR-SRC-006]` Clicking a result MUST navigate directly to the detail view of that entity.

`[FR-SRC-007]` Search MUST support partial word matching (e.g., "bridge" matches "bridging", "solder bridge", "unbridged").

`[FR-SRC-008]` Search MUST be scoped to the current organization's data only. System reference data is also included.

`[FR-SRC-009]` «Advanced Search» MUST allow filtering results by entity type, date range, and engineer.

`[FR-SRC-010]` Recent searches (last 10) MUST be stored and shown when the search field is focused without text.

### 6.4 Contextual Search

In addition to global search, each module provides contextual search within its own scope:
- Package Library: search within packages only, with package-specific filters
- Defect Library: search within defects only
- Image Library: search with image metadata filters
- Knowledge Base: search within knowledge entities with type filters

---

## 7. Notification System

### 7.1 In-App Notification Panel

`[FR-NTF-001]` A notification bell icon in the application header MUST display the count of unread notifications.

`[FR-NTF-002]` Clicking the bell MUST open a notification panel sliding in from the right, showing the most recent 20 notifications.

`[FR-NTF-003]` Each notification MUST show: type icon, title, brief description, timestamp, and a «Go to» link.

`[FR-NTF-004]` Notifications MUST be marked as read when the engineer clicks «Go to» or manually marks them read.

`[FR-NTF-005]` «Mark All Read» MUST be available in the notification panel.

### 7.2 Notification Types and Triggers

| Notification Type | Trigger | Recipients | Priority |
|---|---|---|---|
| `design_approval_requested` | Stencil submitted for approval | Senior Engineers (or designated approver) | HIGH |
| `design_approved` | Stencil revision approved | Design author + project team | MEDIUM |
| `design_rejected` | Stencil revision rejected | Design author | HIGH |
| `rule_override_requested` | Override request submitted | Senior Engineers | HIGH |
| `rule_override_approved` | Override approved | Requesting engineer | MEDIUM |
| `rule_override_rejected` | Override rejected | Requesting engineer | HIGH |
| `defect_investigation_assigned` | Investigation assigned | Lead engineer | HIGH |
| `investigation_closed` | Investigation closed | Project team | MEDIUM |
| `knowledge_review_flag` | Learning system raises a flag | Senior Engineers | MEDIUM |
| `critical_rule_failure` | Analysis run finds critical failure | Design author | HIGH |
| `spi_correlation_available` | New SPI data imported | Design author | LOW |
| `role_changed` | Engineer's role changed | Affected engineer | MEDIUM |
| `project_status_changed` | Project status changes | Project team | LOW |

### 7.3 Email Notifications

`[FR-NTF-006]` Email notifications MUST be sent for HIGH priority notifications when the engineer has email notifications enabled for that type.

`[FR-NTF-007]` Email notifications MUST include a direct link to the relevant screen in the application.

`[FR-NTF-008]` Email notifications MUST use the organization name and branding in the email header.

`[FR-NTF-009]` Engineers MUST be able to configure per-type notification preferences (Module 4.23, Settings Tab 3). In-app is always on; email is configurable.

---

## 8. Error Handling Requirements

### 8.1 Error Classification

| Error Class | Description | User Impact | Handling |
|---|---|---|---|
| VALIDATION | User input fails validation | Field-level warning; cannot save | Show inline message; keep form open |
| BUSINESS_RULE | Operation violates a business rule | Operation blocked | Show dialog with explanation and options |
| NETWORK | Cannot reach Supabase | Data cannot sync | Show banner; queue operation if offline mode active |
| AUTH | Session expired or unauthorized | Screen locked | Show re-login dialog; preserve unsaved work |
| NOT_FOUND | Referenced entity no longer exists | Broken link | Show "not found" message with navigation options |
| SYSTEM | Unexpected application error | Operation failed | Show error dialog with reference code; log to error tracking |

### 8.2 Validation Error Display

`[FR-ERR-001]` Field-level validation errors MUST appear directly below the field that failed, in red text.

`[FR-ERR-002]` Form-level validation errors MUST appear at the top of the form as a summary list before the «Save» action is blocked.

`[FR-ERR-003]` Validation MUST be triggered on field blur (leaving a field), not on every keystroke.

`[FR-ERR-004]` Required fields MUST be marked with a red asterisk (*) label.

### 8.3 Destructive Action Confirmation

`[FR-ERR-005]` Any action that cannot be undone MUST require a confirmation dialog. The dialog MUST describe specifically what will be deleted or changed and the consequences.

`[FR-ERR-006]` For critical destructive actions (delete project, deactivate user), the engineer MUST type a confirmation phrase (e.g., the project number) before the action is permitted.

### 8.4 Auto-Save and Recovery

`[FR-ERR-007]` The application MUST auto-save work in progress every 60 seconds (configurable).

`[FR-ERR-008]` If the application closes unexpectedly, on next launch MUST show: "Unsaved changes detected from your previous session. Would you like to recover them?"

`[FR-ERR-009]` Network errors during save MUST result in: (a) local save to recovery file, (b) user notification "Save failed — data preserved locally. Will retry when connection is restored."

### 8.5 System Errors

`[FR-ERR-010]` Unexpected system errors MUST display a user-friendly message (not a stack trace) with a unique error reference code.

`[FR-ERR-011]` Error reference codes MUST be logged with full stack trace and context to the application's error logging service.

`[FR-ERR-012]` «Copy Error Reference» MUST be available in the error dialog for support purposes.

---

## 9. Security Requirements

### 9.1 Authentication

`[FR-SEC-001]` Authentication MUST use Supabase Auth (email/password). OAuth (Google, Microsoft) is a Phase 4+ feature.

`[FR-SEC-002]` Sessions MUST be stored in the OS keyring (not in files, environment variables, or the application database).

`[FR-SEC-003]` Session tokens MUST be refreshed automatically before expiry. If refresh fails, the user is shown the login dialog without losing unsaved work.

`[FR-SEC-004]` Sessions MUST have a maximum idle timeout of 8 hours (configurable by Admin, up to 24 hours).

`[FR-SEC-005]` Failed login attempts MUST be rate-limited after 5 consecutive failures (30-second lockout, then exponential backoff). This is enforced by Supabase Auth.

### 9.2 Authorization

`[FR-SEC-006]` Every data access operation MUST be validated against the user's role before execution. Client-side role checks are supplementary; server-side RLS is the enforcement layer.

`[FR-SEC-007]` Supabase Row-Level Security MUST be enabled on all organizational data tables. No organizational data MUST be accessible without a valid JWT.

`[FR-SEC-008]` The `organization_id` claim MUST be embedded in the Supabase JWT and MUST NOT be modifiable by the client application.

### 9.3 Data Privacy

`[FR-SEC-009]` Engineers MUST only see data belonging to their organization. Cross-organizational data access MUST be impossible at the database layer.

`[FR-SEC-010]` Deleted records (soft delete) MUST still be inaccessible to engineers of other organizations, regardless of their deletion status.

`[FR-SEC-011]` Engineer email addresses MUST NOT be exposed in any exported report or public-facing output without explicit opt-in.

### 9.4 Sensitive Data

`[FR-SEC-012]` No passwords, API keys, or secret tokens MUST ever be stored in the application database or log files.

`[FR-SEC-013]` Supabase service role keys MUST NOT be embedded in the desktop application binary.

`[FR-SEC-014]` The application MUST use the Supabase anon key + user JWT for all data operations. Service role is only for server-side scripts.

### 9.5 Audit Security

`[FR-SEC-015]` The audit log MUST be append-only and MUST NOT be modifiable by any engineer role, including Admin. Only Super Admin may export the audit log.

`[FR-SEC-016]` Audit log access MUST itself be logged (who viewed the audit log, when, what filters were applied).

### 9.6 File Upload Security

`[FR-SEC-017]` Uploaded files MUST be validated for MIME type and file extension before storage.

`[FR-SEC-018]` Uploaded files MUST be scanned for malware before being made accessible (via Supabase Storage virus scanning, when enabled).

`[FR-SEC-019]` Maximum file upload size MUST be enforced: 50MB for images, 100MB for CAD files, 25MB for documents.

---

## 10. Audit Requirements

### 10.1 What Must Be Audited

`[FR-AUD-001]` The following actions MUST generate an `audit_log` entry:

| Action Category | Specific Actions |
|---|---|
| Authentication | Login, logout, failed login, session timeout, token refresh |
| User Management | Engineer created, deactivated, role assigned, role revoked |
| Project Lifecycle | Project created, status changed, archived, team member added/removed |
| Stencil Design | Design created, submitted for approval, approved, rejected, revision created |
| Aperture Design | Aperture created, modified, deleted, rule overridden, override approved/rejected |
| Rule Management | Rule created, updated (new version), deactivated, rule set activated/deactivated |
| Defect Investigation | Investigation opened, root cause confirmed, investigation closed |
| Knowledge | Case study published, experiment concluded, new rule created from investigation |
| Report Generation | Report generated, signed, downloaded |
| Administration | Organization settings changed, customer added/edited |
| Data Export | Any data export action |

### 10.2 Audit Entry Content

Each audit entry MUST contain:

`[FR-AUD-002]` Engineer identity (`engineer_id`, `full_name` at time of action)
`[FR-AUD-003]` Organization identity (`organization_id`)
`[FR-AUD-004]` Action type and timestamp (UTC)
`[FR-AUD-005]` Affected entity type and ID
`[FR-AUD-006]` Previous values (for UPDATE actions)
`[FR-AUD-007]` New values (for INSERT and UPDATE actions)
`[FR-AUD-008]` Session ID (linking to `engineer_sessions`)
`[FR-AUD-009]` Client IP address (for security audit purposes)

### 10.3 Audit Log Access

`[FR-AUD-010]` The Audit Log viewer (Module 4.22) MUST support filtering by: date range, engineer, action type, entity type. Admin role and above only.

`[FR-AUD-011]` Audit log entries MUST be exportable to CSV for external compliance tools.

`[FR-AUD-012]` Audit log MUST be retained for a minimum of 7 years (regulatory requirement for automotive and medical customers).

### 10.4 Project Notes as Engineering Audit

`[FR-AUD-013]` The `project_notes` table serves as the engineering decision audit trail. System-generated notes MUST be created for: status changes, stencil approvals, rule overrides, investigation outcomes, and milestone completions.

`[FR-AUD-014]` Project notes MUST be display-accessible to all engineers on the project, in chronological order, in the Project Timeline view.

---

## 11. Performance Requirements

### 11.1 Response Time Requirements

| Operation | Target Response Time | Maximum Acceptable |
|---|---|---|
| Application startup (login to dashboard) | < 3 seconds | 5 seconds |
| Navigation between modules | < 500ms | 1 second |
| Project list load (up to 50 projects) | < 1 second | 2 seconds |
| Aperture table load (up to 500 apertures) | < 1 second | 2 seconds |
| Area ratio calculation (single aperture) | < 50ms | 100ms |
| Area ratio update on dimension change (live) | < 100ms | 200ms |
| Full rule check run (500 apertures, 50 rules) | < 5 seconds | 10 seconds |
| Intelligence Engine full run | < 10 seconds | 20 seconds |
| Global search (typical query) | < 500ms | 1 second |
| Image thumbnail load (20 thumbnails) | < 2 seconds | 4 seconds |
| Report PDF generation | < 15 seconds | 30 seconds |
| Save aperture change | < 1 second | 2 seconds |

### 11.2 Scalability Requirements

`[FR-PERF-001]` The system MUST support a stencil design with up to 2,000 apertures without performance degradation beyond the stated targets.

`[FR-PERF-002]` The rule check engine MUST support up to 200 active rules without performance degradation.

`[FR-PERF-003]` The image library MUST support browsing and filtering across up to 10,000 images per organization.

`[FR-PERF-004]` The project list MUST load within target times for up to 500 projects per organization.

### 11.3 Concurrency Requirements

`[FR-PERF-005]` Multiple engineers MUST be able to work in the same project simultaneously. Conflicting edits to the same record MUST be detected and resolved (last-write-wins with notification, or optimistic locking with conflict dialog).

`[FR-PERF-006]` An engineer making changes to one stencil design MUST NOT block another engineer from working on a different stencil design in the same project.

### 11.4 Resource Requirements

`[FR-PERF-007]` The desktop application MUST function on hardware with: 8GB RAM, quad-core CPU, 2GB available disk for local cache.

`[FR-PERF-008]` The application MUST NOT consume more than 1GB RAM during normal operation (excluding OS and other applications).

`[FR-PERF-009]` The local SQLite cache (Phase 2) MUST NOT exceed 2GB in size. Cache eviction MUST maintain this limit.

---

## 12. Offline Requirements

**Note:** Offline mode is a Phase 2 feature. Phase 1 requires active internet connectivity. This section defines the full offline requirements for Phase 2 implementation planning.

### 12.1 Offline Capability Scope

`[FR-OFF-001]` In Phase 2, the following MUST be available offline:
- Read access to all reference data (packages, materials, IPC references, theory cards)
- Read access to current project data (last synchronized state)
- Engineering Calculators (all 8 calculators — no network dependency)
- Defect Library browser (read-only)
- Engineering notes and image viewing (cached data)

`[FR-OFF-002]` The following MUST require connectivity:
- Saving new records to the server
- Running the full Intelligence Engine (computation is server-assisted in Phase 5+)
- Generating PDF reports (requires Supabase Storage access)
- Uploading images
- Sending notifications

### 12.2 Sync Behavior

`[FR-OFF-003]` Write operations performed offline MUST be queued in the local sync queue.

`[FR-OFF-004]` On reconnection, the sync queue MUST be processed automatically. The engineer MUST be shown a sync status indicator.

`[FR-OFF-005]` Sync conflicts (server data changed while offline) MUST be surfaced to the engineer with: the conflicting values, who changed what, and options to keep local or accept server version.

`[FR-OFF-006]` The status bar connection indicator MUST clearly distinguish: 🟢 Connected, 🟡 Syncing, 🟠 Offline (with queued changes), 🔴 Offline (no queued changes).

### 12.3 Local Cache Management

`[FR-OFF-007]` The local SQLite cache MUST be stored in the user's application data directory (OS-appropriate location).

`[FR-OFF-008]` Engineers MUST be able to manually trigger a full cache refresh from Settings.

`[FR-OFF-009]` Cache freshness indicators MUST show "Last synced: [relative time]" for each module.

---

## 13. Report Specifications

### REPORT-01: Stencil Design Report

**Purpose:** The primary engineering deliverable — a complete, signed stencil specification for manufacturing.

**Format:** PDF

**Sections:**

1. **Cover Page**
   - Organization logo, organization name
   - Report title: "Stencil Design Report"
   - Stencil number, revision, date
   - Project number, project name, customer name
   - IPC class
   - Designed by, Approved by (with signature if enabled)
   - Report number, generated date, app version, rule set version

2. **Executive Summary**
   - Overall design score and grade
   - Predicted FPY
   - IPC compliance status
   - Key design decisions (from `stencil_designs.design_intent`)

3. **PCB Assembly Summary**
   - Board dimensions, surface finish, layer count
   - Min pitch, component statistics (from PCB revision metadata)

4. **Stencil Specification**
   - Material, thickness, coating
   - Total aperture count, critical aperture count

5. **Aperture Design Table**
   - All apertures with: Ref Des, Pin, Shape, L×W (mm), AR, Aspect Ratio, Paste Volume, Rule Status
   - Color-coded AR values per threshold

6. **Rule Check Results**
   - Summary: total rules, passed, failed, warned, skipped
   - Detailed table: all failures and warnings with rule code, description, value, threshold

7. **Engineering Scores**
   - Full score card with sub-scores and grade

8. **Defect Risk Assessment**
   - All 12 defect types with risk score and primary driver

9. **Recommendations Summary**
   - All pending recommendations with priority and title

10. **Thermal Pad Analysis** (if applicable)
    - Per thermal pad: coverage %, segmentation strategy, voiding risk

11. **Revision History**
    - Table of all approved revisions

12. **Sign-off Block**
    - Designed by: [name, title, date, signature]
    - Approved by: [name, title, date, signature]
    - Compliance statement

---

### REPORT-02: Area Ratio Analysis Report

**Purpose:** Detailed per-aperture area ratio analysis for process engineering review.

**Formats:** PDF (narrative) + XLSX (data table)

**PDF Sections:**
- Summary statistics: min AR, max AR, mean AR, % passing IPC minimum
- Histogram: distribution of area ratio values
- Risk profile: apertures by AR band (color-coded)
- Recommendations specific to AR failures

**XLSX Sheets:**
- Sheet 1: All apertures with AR, aspect ratio, paste volume, status
- Sheet 2: Summary statistics
- Sheet 3: Failed/warning apertures only

---

### REPORT-03: Defect Investigation Report

**Purpose:** Formal documentation of a defect investigation for quality system records.

**Format:** PDF

**Sections:**
1. Header (investigation number, date, project, product, IPC class)
2. Problem Statement (D1)
3. Containment Actions (D2)
4. Root Cause Analysis (whichever method was used, with full analysis tree)
5. Confirmed Root Cause (with knowledge base reference)
6. Corrective Actions Implemented
7. Preventive Actions Planned
8. Effectiveness Verification (D7)
9. Lessons Learned (D8)
10. Yield Data (before/after)
11. Sign-off (lead engineer + closer)

---

### REPORT-04: Project Summary Report

**Purpose:** Executive-level summary of all engineering work in a project.

**Format:** PDF

**Sections:**
1. Project overview (timeline, team, IPC class, customer)
2. PCB assembly summary
3. Stencil designs summary table (all designs, status, scores)
4. Active defect investigations summary
5. Key milestones (from project notes)
6. Generated reports list

---

## 14. Business Rules Reference

This section consolidates all business rules across modules for implementors.

### BR-GENERAL

| ID | Rule | Module |
|---|---|---|
| BR-001 | Organization_id is always inherited from the logged-in engineer's JWT | All modules |
| BR-002 | Soft-deleted records are never displayed in normal queries | All modules |
| BR-003 | System records (is_system_record=true) are read-only for all non-Super-Admin roles | All modules |
| BR-004 | All timestamps are stored as UTC and displayed in the engineer's local timezone | All modules |

### BR-PROJECTS

| ID | Rule | Module |
|---|---|---|
| BR-101 | Project IPC class must be ≥ customer required IPC class | 4.02 |
| BR-102 | Archived projects are read-only — no new stencils, defects, or reports | 4.02 |
| BR-103 | Project status transitions must be logged as project_notes | 4.02 |
| BR-104 | A project with stencil designs cannot be physically deleted (soft delete only) | 4.02 |

### BR-STENCIL

| ID | Rule | Module |
|---|---|---|
| BR-201 | Stencil design status cannot advance to 'approved' if any critical rule failures remain unresolved | 4.06 |
| BR-202 | Approver cannot be the same engineer as designer (when four-eyes is enabled) | 4.06 |
| BR-203 | Approved stencil revisions are immutable — no modifications permitted | 4.06 |
| BR-204 | Area ratio, aspect ratio, paste volume must be recalculated when any aperture dimension or stencil thickness changes | 4.06 |
| BR-205 | Engineer override requires justification text (minimum 50 characters) | 4.06 |
| BR-206 | Critical rule overrides require Senior Engineer approval | 4.06 |

### BR-RULES

| ID | Rule | Module |
|---|---|---|
| BR-301 | Rule changes create a new version — existing rules are never edited in place | 4.11 |
| BR-302 | Deprecated rules remain in the database with deprecated_at timestamp | 4.11 |
| BR-303 | Rule check runs record the exact rule set version active at time of run | 4.11 |
| BR-304 | System IPC rule sets cannot be modified by Engineer, Senior Engineer, or Admin roles | 4.11 |

### BR-MATERIALS

| ID | Rule | Module |
|---|---|---|
| BR-401 | Customer-approved paste list, when populated, limits paste selection for all projects under that customer | 4.12 |
| BR-402 | Paste particle max size must be ≤ 1/5 of aperture minimum width (industry rule of 5) | 4.12 |
| BR-403 | Floor life warning must be shown for pastes within 25% of their floor life limit | 4.12 |

### BR-KNOWLEDGE

| ID | Rule | Module |
|---|---|---|
| BR-501 | Case studies require Senior Engineer approval before publication | 4.18 |
| BR-502 | Experiments that generate rules automatically create a draft rule pending Senior Engineer review | 4.18 |
| BR-503 | Learning events may only update confidence scores within the clamped range [10%, 99%] | All |

### BR-AUDIT

| ID | Rule | Module |
|---|---|---|
| BR-601 | Project notes are append-only — UPDATE and DELETE are blocked by RLS | 4.02 |
| BR-602 | Stencil revision records are immutable on creation | 4.06 |
| BR-603 | Audit log records cannot be modified or deleted by any role | 4.22 |
| BR-604 | Confidence adjustment records are immutable | Learning system |

---

## 15. Future Expansion Requirements

These requirements are NOT in scope for the initial release but MUST be considered in architecture decisions to ensure future compatibility.

### FX-01: FastAPI Web Service Layer (Phase 5)

`[FR-FX-001]` All business logic MUST be implemented in the domain and application layers (not in the UI layer) so that a FastAPI service can expose the same logic via REST API without duplication.

`[FR-FX-002]` All data access MUST go through repository interfaces, enabling the same repositories to be used by both the desktop app and the future web service.

### FX-02: Web Browser Client (Phase 5+)

`[FR-FX-003]` The UI layer MUST be cleanly separable from the application logic layer so that a web client (React or similar) can be built against the same API.

`[FR-FX-004]` All ViewModels MUST be serializable to JSON without modification.

### FX-03: AI Assistant Integration (Phase 5)

`[FR-FX-005]` The Intelligence Panel in the Stencil Design Workspace MUST include a designated region for AI Assistant interaction. In Phase 1, this region displays a "Coming Soon" placeholder. Its dimensions and position MUST be finalized now to avoid UI restructuring.

`[FR-FX-006]` The ProcessContext model MUST be designed so it can be serialized and passed as context to an LLM API call without restructuring.

`[FR-FX-007]` All AI conversation logs MUST reference the `stencil_design_id` or project entity they relate to, enabling retrieval of historical AI-assisted designs.

### FX-04: Multi-Site / Enterprise Deployment (Phase 4+)

`[FR-FX-008]` Organization settings MUST support site-level sub-organizations (e.g., "ACME — Site A", "ACME — Site B") while sharing a common organization knowledge base. Schema already supports this via `organization_settings`; application-level support requires Phase 4.

`[FR-FX-009]` Cross-site knowledge sharing (case studies, rules) MUST be designed as a permission layer on top of the existing `is_community_published` flag. No schema changes should be required.

### FX-05: IPC-2581 and ODB++ Import (Phase 3)

`[FR-FX-010]` The PCB Assembly and Land Pattern modules MUST be designed to accept auto-populated data from file import. All manually entered fields MUST be editable after import. Import pipeline adds `import_job_id` to `component_placements` and `pads` records.

`[FR-FX-011]` Import validation MUST be a separate step from import execution, showing the engineer what will be created/updated before the import runs.

### FX-06: SPI Machine Integration (Phase 4)

`[FR-FX-012]` The SPI Data Importer MUST be designed as a pluggable parser architecture. Phase 3 supports CSV. Phase 4 supports direct machine format parsers (Koh Young .kya, Saki .spi, Mirtec .mrt). The import UI MUST NOT need to change when new parsers are added.

### FX-07: Localization (Phase 4)

`[FR-FX-013]` All user-visible strings MUST be defined in string resource files (not hardcoded in UI code) from Phase 1 development. This is a code-quality requirement, not a feature requirement. It enables Phase 4 localization without code changes.

`[FR-FX-014]` All physical measurements displayed in the UI MUST pass through a units formatter that respects `engineer.preferred_units`. Imperial display is Phase 4 but the formatter hook MUST exist from Phase 1.

### FX-08: Regulatory Compliance Export (Phase 4+)

`[FR-FX-015]` The audit log and stencil revision history MUST be exportable in a format suitable for IATF 16949, ISO 13485, and AS9100 audit evidence packages. The export format is an open design question for Phase 4.

---

*End of Functional Requirements Specification v1.0.0*
*StencilPro Expert Enterprise*
*Classification: Core Requirements Document*
*Next Document: MODULE_001_IMPLEMENTATION.md — begin development*
