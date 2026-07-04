-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-002: Projects & Customers
-- File: DB002_Triggers.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB002_Projects.sql, DB002_Functions.sql, DB002_Indexes.sql
-- Prerequisites: DB001_Triggers.sql (fn_set_updated_at, fn_audit_trigger,
--               fn_set_created_updated_by, fn_soft_delete_check)
-- =============================================================================

BEGIN;

-- =============================================================================
-- customers
-- =============================================================================

DROP TRIGGER IF EXISTS tg_customers_updated_at ON customers;
CREATE TRIGGER tg_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_customers_created_by ON customers;
CREATE TRIGGER tg_customers_created_by
    BEFORE INSERT OR UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_customers_audit ON customers;
CREATE TRIGGER tg_customers_audit
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_customers_no_hard_delete ON customers;
CREATE TRIGGER tg_customers_no_hard_delete
    BEFORE DELETE ON customers
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- customer_contacts
-- =============================================================================

DROP TRIGGER IF EXISTS tg_customer_contacts_updated_at ON customer_contacts;
CREATE TRIGGER tg_customer_contacts_updated_at
    BEFORE UPDATE ON customer_contacts
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_customer_contacts_created_by ON customer_contacts;
CREATE TRIGGER tg_customer_contacts_created_by
    BEFORE INSERT OR UPDATE ON customer_contacts
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_customer_contacts_audit ON customer_contacts;
CREATE TRIGGER tg_customer_contacts_audit
    AFTER INSERT OR UPDATE OR DELETE ON customer_contacts
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_customer_contacts_no_hard_delete ON customer_contacts;
CREATE TRIGGER tg_customer_contacts_no_hard_delete
    BEFORE DELETE ON customer_contacts
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- products
-- =============================================================================

DROP TRIGGER IF EXISTS tg_products_updated_at ON products;
CREATE TRIGGER tg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_products_created_by ON products;
CREATE TRIGGER tg_products_created_by
    BEFORE INSERT OR UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_products_audit ON products;
CREATE TRIGGER tg_products_audit
    AFTER INSERT OR UPDATE OR DELETE ON products
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_products_no_hard_delete ON products;
CREATE TRIGGER tg_products_no_hard_delete
    BEFORE DELETE ON products
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- projects
-- =============================================================================

DROP TRIGGER IF EXISTS tg_projects_updated_at ON projects;
CREATE TRIGGER tg_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_projects_created_by ON projects;
CREATE TRIGGER tg_projects_created_by
    BEFORE INSERT OR UPDATE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- IPC class enforcement: BEFORE INSERT OR UPDATE
DROP TRIGGER IF EXISTS tg_projects_ipc_class ON projects;
CREATE TRIGGER tg_projects_ipc_class
    BEFORE INSERT OR UPDATE OF customer_id, ipc_class ON projects
    FOR EACH ROW
    EXECUTE FUNCTION fn_enforce_project_ipc_class();

-- Status change note: AFTER UPDATE (when status field changes)
DROP TRIGGER IF EXISTS tg_projects_status_note ON projects;
CREATE TRIGGER tg_projects_status_note
    AFTER UPDATE OF status ON projects
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION fn_project_status_note();

-- Activity log: AFTER INSERT OR UPDATE
DROP TRIGGER IF EXISTS tg_projects_activity ON projects;
CREATE TRIGGER tg_projects_activity
    AFTER INSERT OR UPDATE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION fn_project_activity_log();

-- Audit: AFTER INSERT OR UPDATE OR DELETE (critical — project decisions)
DROP TRIGGER IF EXISTS tg_projects_audit ON projects;
CREATE TRIGGER tg_projects_audit
    AFTER INSERT OR UPDATE OR DELETE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- Prevent hard delete (soft delete only)
DROP TRIGGER IF EXISTS tg_projects_no_hard_delete ON projects;
CREATE TRIGGER tg_projects_no_hard_delete
    BEFORE DELETE ON projects
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- project_members
-- =============================================================================

DROP TRIGGER IF EXISTS tg_project_members_updated_at ON project_members;
CREATE TRIGGER tg_project_members_updated_at
    BEFORE UPDATE ON project_members
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_project_members_created_by ON project_members;
CREATE TRIGGER tg_project_members_created_by
    BEFORE INSERT OR UPDATE ON project_members
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- Activity log: AFTER INSERT (member added) or AFTER UPDATE (member removed)
DROP TRIGGER IF EXISTS tg_project_members_activity ON project_members;
CREATE TRIGGER tg_project_members_activity
    AFTER INSERT OR UPDATE ON project_members
    FOR EACH ROW
    EXECUTE FUNCTION fn_project_member_activity();

DROP TRIGGER IF EXISTS tg_project_members_audit ON project_members;
CREATE TRIGGER tg_project_members_audit
    AFTER INSERT OR UPDATE OR DELETE ON project_members
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- project_revisions
-- =============================================================================

DROP TRIGGER IF EXISTS tg_project_revisions_updated_at ON project_revisions;
CREATE TRIGGER tg_project_revisions_updated_at
    BEFORE UPDATE ON project_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_project_revisions_created_by ON project_revisions;
CREATE TRIGGER tg_project_revisions_created_by
    BEFORE INSERT OR UPDATE ON project_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- Immutability: approved revisions cannot be modified
DROP TRIGGER IF EXISTS tg_project_revisions_immutable ON project_revisions;
CREATE TRIGGER tg_project_revisions_immutable
    BEFORE UPDATE ON project_revisions
    FOR EACH ROW
    WHEN (OLD.approved_at IS NOT NULL)
    EXECUTE FUNCTION fn_project_revision_immutable();

DROP TRIGGER IF EXISTS tg_project_revisions_audit ON project_revisions;
CREATE TRIGGER tg_project_revisions_audit
    AFTER INSERT OR UPDATE OR DELETE ON project_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- project_notes  (APPEND-ONLY)
-- =============================================================================

-- Prevent UPDATE on project_notes
DROP TRIGGER IF EXISTS tg_project_notes_no_update ON project_notes;
CREATE TRIGGER tg_project_notes_no_update
    BEFORE UPDATE ON project_notes
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_project_note_modification();

-- Prevent DELETE on project_notes
DROP TRIGGER IF EXISTS tg_project_notes_no_delete ON project_notes;
CREATE TRIGGER tg_project_notes_no_delete
    BEFORE DELETE ON project_notes
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_project_note_modification();

-- Activity log: AFTER INSERT (engineer-authored notes only)
DROP TRIGGER IF EXISTS tg_project_notes_activity ON project_notes;
CREATE TRIGGER tg_project_notes_activity
    AFTER INSERT ON project_notes
    FOR EACH ROW
    EXECUTE FUNCTION fn_project_note_activity();

-- Audit INSERT only (no UPDATE/DELETE to audit — they're blocked)
DROP TRIGGER IF EXISTS tg_project_notes_audit ON project_notes;
CREATE TRIGGER tg_project_notes_audit
    AFTER INSERT ON project_notes
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- project_attachments
-- =============================================================================

DROP TRIGGER IF EXISTS tg_project_attachments_updated_at ON project_attachments;
CREATE TRIGGER tg_project_attachments_updated_at
    BEFORE UPDATE ON project_attachments
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_project_attachments_created_by ON project_attachments;
CREATE TRIGGER tg_project_attachments_created_by
    BEFORE INSERT OR UPDATE ON project_attachments
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_project_attachments_audit ON project_attachments;
CREATE TRIGGER tg_project_attachments_audit
    AFTER INSERT OR UPDATE OR DELETE ON project_attachments
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_project_attachments_no_hard_delete ON project_attachments;
CREATE TRIGGER tg_project_attachments_no_hard_delete
    BEFORE DELETE ON project_attachments
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- project_tags
-- =============================================================================

DROP TRIGGER IF EXISTS tg_project_tags_updated_at ON project_tags;
CREATE TRIGGER tg_project_tags_updated_at
    BEFORE UPDATE ON project_tags
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_project_tags_created_by ON project_tags;
CREATE TRIGGER tg_project_tags_created_by
    BEFORE INSERT OR UPDATE ON project_tags
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- project_tag_assignments
-- =============================================================================

DROP TRIGGER IF EXISTS tg_project_tag_assignments_updated_at ON project_tag_assignments;
CREATE TRIGGER tg_project_tag_assignments_updated_at
    BEFORE UPDATE ON project_tag_assignments
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_project_tag_assignments_created_by ON project_tag_assignments;
CREATE TRIGGER tg_project_tag_assignments_created_by
    BEFORE INSERT OR UPDATE ON project_tag_assignments
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- Maintain project_tags.usage_count on insert/delete
DROP TRIGGER IF EXISTS tg_project_tag_assignments_usage_count ON project_tag_assignments;
CREATE TRIGGER tg_project_tag_assignments_usage_count
    AFTER INSERT OR DELETE ON project_tag_assignments
    FOR EACH ROW
    EXECUTE FUNCTION fn_project_tag_usage_count();

-- =============================================================================
-- project_activity  (APPEND-ONLY)
-- =============================================================================

-- Prevent UPDATE on project_activity
DROP TRIGGER IF EXISTS tg_project_activity_no_update ON project_activity;
CREATE TRIGGER tg_project_activity_no_update
    BEFORE UPDATE ON project_activity
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_project_activity_modification();

-- Prevent DELETE on project_activity
DROP TRIGGER IF EXISTS tg_project_activity_no_delete ON project_activity;
CREATE TRIGGER tg_project_activity_no_delete
    BEFORE DELETE ON project_activity
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_project_activity_modification();

-- =============================================================================
-- project_templates
-- =============================================================================

DROP TRIGGER IF EXISTS tg_project_templates_updated_at ON project_templates;
CREATE TRIGGER tg_project_templates_updated_at
    BEFORE UPDATE ON project_templates
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_project_templates_created_by ON project_templates;
CREATE TRIGGER tg_project_templates_created_by
    BEFORE INSERT OR UPDATE ON project_templates
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

COMMIT;
