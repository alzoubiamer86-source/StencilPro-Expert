-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-002: Projects & Customers
-- File: DB002_Indexes.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB002_Projects.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- customers
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_customers_organization_id
    ON customers (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_customers_code
    ON customers (organization_id, code)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_customers_is_active
    ON customers (organization_id, is_active)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_customers_industry_segment
    ON customers (organization_id, industry_segment)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_customers_required_ipc_class
    ON customers (organization_id, required_ipc_class)
    WHERE is_deleted = FALSE;

-- Trigram index for customer name search
CREATE INDEX IF NOT EXISTS idx_customers_name_trgm
    ON customers USING GIN (name gin_trgm_ops);

-- GIN index for approved_paste_ids array membership queries
CREATE INDEX IF NOT EXISTS idx_customers_approved_paste_ids_gin
    ON customers USING GIN (approved_paste_ids);

CREATE INDEX IF NOT EXISTS idx_customers_approved_stencil_material_ids_gin
    ON customers USING GIN (approved_stencil_material_ids);

-- =============================================================================
-- customer_contacts
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_customer_contacts_customer_id
    ON customer_contacts (customer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_customer_contacts_organization_id
    ON customer_contacts (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_customer_contacts_primary
    ON customer_contacts (customer_id, is_primary)
    WHERE is_deleted = FALSE AND is_primary = TRUE;

CREATE INDEX IF NOT EXISTS idx_customer_contacts_type
    ON customer_contacts (customer_id, contact_type)
    WHERE is_deleted = FALSE;

-- =============================================================================
-- products
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_products_organization_id
    ON products (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_products_customer_id
    ON products (customer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_products_market_segment
    ON products (organization_id, market_segment)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_products_part_number
    ON products (organization_id, part_number)
    WHERE is_deleted = FALSE AND part_number IS NOT NULL;

-- Trigram index for product name search
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
    ON products USING GIN (name gin_trgm_ops);

-- =============================================================================
-- projects
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_projects_organization_id
    ON projects (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_projects_customer_id
    ON projects (customer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_projects_product_id
    ON projects (product_id)
    WHERE is_deleted = FALSE AND product_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_projects_lead_engineer_id
    ON projects (lead_engineer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_projects_status
    ON projects (organization_id, status)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_projects_phase
    ON projects (organization_id, phase)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_projects_ipc_class
    ON projects (organization_id, ipc_class)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_projects_project_number
    ON projects (organization_id, project_number)
    WHERE is_deleted = FALSE;

-- Composite: status + phase for dashboard filtering
CREATE INDEX IF NOT EXISTS idx_projects_status_phase
    ON projects (organization_id, status, phase)
    WHERE is_deleted = FALSE;

-- Sort by most recently updated (dashboard active projects panel)
CREATE INDEX IF NOT EXISTS idx_projects_updated_at_desc
    ON projects (organization_id, updated_at DESC)
    WHERE is_deleted = FALSE;

-- Sort by created_at for chronological listing
CREATE INDEX IF NOT EXISTS idx_projects_created_at_desc
    ON projects (organization_id, created_at DESC)
    WHERE is_deleted = FALSE;

-- Target completion date for deadline tracking
CREATE INDEX IF NOT EXISTS idx_projects_target_completion
    ON projects (organization_id, target_completion_date)
    WHERE is_deleted = FALSE AND target_completion_date IS NOT NULL;

-- Trigram index for project name search
CREATE INDEX IF NOT EXISTS idx_projects_name_trgm
    ON projects USING GIN (name gin_trgm_ops);

-- GIN index for tags array membership queries
CREATE INDEX IF NOT EXISTS idx_projects_tags_gin
    ON projects USING GIN (tags);

-- Full-text search index on project name + description
CREATE INDEX IF NOT EXISTS idx_projects_fts
    ON projects USING GIN (
        to_tsvector('english',
            COALESCE(name, '') || ' ' ||
            COALESCE(project_number, '') || ' ' ||
            COALESCE(description, '')
        )
    );

-- =============================================================================
-- project_members
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_project_members_project_id
    ON project_members (project_id);

CREATE INDEX IF NOT EXISTS idx_project_members_engineer_id
    ON project_members (engineer_id);

CREATE INDEX IF NOT EXISTS idx_project_members_organization_id
    ON project_members (organization_id);

-- Active members only (not removed)
CREATE INDEX IF NOT EXISTS idx_project_members_active
    ON project_members (project_id, engineer_id)
    WHERE removed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_project_members_role
    ON project_members (project_id, role_on_project)
    WHERE removed_at IS NULL;

-- Find all projects an engineer is a member of
CREATE INDEX IF NOT EXISTS idx_project_members_engineer_active
    ON project_members (engineer_id, project_id)
    WHERE removed_at IS NULL;

-- =============================================================================
-- project_revisions
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_project_revisions_project_id
    ON project_revisions (project_id);

CREATE INDEX IF NOT EXISTS idx_project_revisions_organization_id
    ON project_revisions (organization_id);

CREATE INDEX IF NOT EXISTS idx_project_revisions_authored_by
    ON project_revisions (authored_by_engineer_id);

CREATE INDEX IF NOT EXISTS idx_project_revisions_approved_by
    ON project_revisions (approved_by_engineer_id)
    WHERE approved_by_engineer_id IS NOT NULL;

-- Current revision lookup (complements the partial unique index)
CREATE INDEX IF NOT EXISTS idx_project_revisions_current
    ON project_revisions (project_id, is_current)
    WHERE is_current = TRUE;

-- Chronological revision history
CREATE INDEX IF NOT EXISTS idx_project_revisions_number_desc
    ON project_revisions (project_id, revision_number DESC);

-- =============================================================================
-- project_notes
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_project_notes_project_id_created_at
    ON project_notes (project_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_notes_organization_id
    ON project_notes (organization_id);

CREATE INDEX IF NOT EXISTS idx_project_notes_engineer_id
    ON project_notes (engineer_id);

CREATE INDEX IF NOT EXISTS idx_project_notes_note_type
    ON project_notes (project_id, note_type);

CREATE INDEX IF NOT EXISTS idx_project_notes_system_generated
    ON project_notes (project_id, is_system_generated);

-- Polymorphic entity lookup (find notes about a specific entity)
CREATE INDEX IF NOT EXISTS idx_project_notes_linked_entity
    ON project_notes (linked_entity_type, linked_entity_id)
    WHERE linked_entity_type IS NOT NULL;

-- Full-text search on note content
CREATE INDEX IF NOT EXISTS idx_project_notes_content_fts
    ON project_notes USING GIN (
        to_tsvector('english',
            COALESCE(title, '') || ' ' ||
            COALESCE(content, '')
        )
    );

-- =============================================================================
-- project_attachments
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_project_attachments_project_id
    ON project_attachments (project_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_project_attachments_organization_id
    ON project_attachments (organization_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_project_attachments_uploaded_by
    ON project_attachments (uploaded_by_engineer_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_project_attachments_document_type
    ON project_attachments (project_id, document_type)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_project_attachments_created_at
    ON project_attachments (project_id, created_at DESC)
    WHERE is_deleted = FALSE;

-- =============================================================================
-- project_tags
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_project_tags_organization_id
    ON project_tags (organization_id);

CREATE INDEX IF NOT EXISTS idx_project_tags_name
    ON project_tags (organization_id, tag_name);

CREATE INDEX IF NOT EXISTS idx_project_tags_usage_count
    ON project_tags (organization_id, usage_count DESC);

-- Trigram for partial tag name search (autocomplete)
CREATE INDEX IF NOT EXISTS idx_project_tags_name_trgm
    ON project_tags USING GIN (tag_name gin_trgm_ops);

-- =============================================================================
-- project_tag_assignments
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_project_tag_assignments_project_id
    ON project_tag_assignments (project_id);

CREATE INDEX IF NOT EXISTS idx_project_tag_assignments_tag_id
    ON project_tag_assignments (tag_id);

CREATE INDEX IF NOT EXISTS idx_project_tag_assignments_organization_id
    ON project_tag_assignments (organization_id);

-- =============================================================================
-- project_activity
-- =============================================================================

-- Primary query: all activity for a project, newest first
CREATE INDEX IF NOT EXISTS idx_project_activity_project_id_occurred
    ON project_activity (project_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_activity_organization_occurred
    ON project_activity (organization_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_activity_engineer_id
    ON project_activity (engineer_id, occurred_at DESC)
    WHERE engineer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_project_activity_type
    ON project_activity (project_id, activity_type, occurred_at DESC);

-- Polymorphic entity lookup
CREATE INDEX IF NOT EXISTS idx_project_activity_entity
    ON project_activity (entity_type, entity_id)
    WHERE entity_type IS NOT NULL;

-- =============================================================================
-- project_templates
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_project_templates_organization_id
    ON project_templates (organization_id)
    WHERE is_active = TRUE AND organization_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_project_templates_system
    ON project_templates (is_system_template)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_project_templates_usage_count
    ON project_templates (usage_count DESC)
    WHERE is_active = TRUE;

COMMIT;
