-- =============================================================================
-- StencilPro Expert Enterprise
-- Module DB-003: PCB Assemblies & Components
-- File: DB003_Triggers.sql
-- PostgreSQL 16 / Supabase Compatible
-- =============================================================================
-- Run AFTER DB003_PCB.sql, DB003_Functions.sql, DB003_Indexes.sql
-- Prerequisites: DB001_Triggers.sql (fn_set_updated_at, fn_audit_trigger,
--               fn_set_created_updated_by, fn_soft_delete_check)
-- =============================================================================

BEGIN;

-- =============================================================================
-- pcb_surface_finishes  (reference data — updated_at + created_by only)
-- =============================================================================

DROP TRIGGER IF EXISTS tg_pcb_surface_finishes_updated_at ON pcb_surface_finishes;
CREATE TRIGGER tg_pcb_surface_finishes_updated_at
    BEFORE UPDATE ON pcb_surface_finishes
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_pcb_surface_finishes_created_by ON pcb_surface_finishes;
CREATE TRIGGER tg_pcb_surface_finishes_created_by
    BEFORE INSERT OR UPDATE ON pcb_surface_finishes
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- pcb_materials
-- =============================================================================

DROP TRIGGER IF EXISTS tg_pcb_materials_updated_at ON pcb_materials;
CREATE TRIGGER tg_pcb_materials_updated_at
    BEFORE UPDATE ON pcb_materials
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_pcb_materials_created_by ON pcb_materials;
CREATE TRIGGER tg_pcb_materials_created_by
    BEFORE INSERT OR UPDATE ON pcb_materials
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- pcb_thickness_options
-- =============================================================================

DROP TRIGGER IF EXISTS tg_pcb_thickness_options_updated_at ON pcb_thickness_options;
CREATE TRIGGER tg_pcb_thickness_options_updated_at
    BEFORE UPDATE ON pcb_thickness_options
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_pcb_thickness_options_created_by ON pcb_thickness_options;
CREATE TRIGGER tg_pcb_thickness_options_created_by
    BEFORE INSERT OR UPDATE ON pcb_thickness_options
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- board_manufacturers
-- =============================================================================

DROP TRIGGER IF EXISTS tg_board_manufacturers_updated_at ON board_manufacturers;
CREATE TRIGGER tg_board_manufacturers_updated_at
    BEFORE UPDATE ON board_manufacturers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_board_manufacturers_created_by ON board_manufacturers;
CREATE TRIGGER tg_board_manufacturers_created_by
    BEFORE INSERT OR UPDATE ON board_manufacturers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_board_manufacturers_audit ON board_manufacturers;
CREATE TRIGGER tg_board_manufacturers_audit
    AFTER INSERT OR UPDATE OR DELETE ON board_manufacturers
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- assembly_manufacturers
-- =============================================================================

DROP TRIGGER IF EXISTS tg_assembly_manufacturers_updated_at ON assembly_manufacturers;
CREATE TRIGGER tg_assembly_manufacturers_updated_at
    BEFORE UPDATE ON assembly_manufacturers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_assembly_manufacturers_created_by ON assembly_manufacturers;
CREATE TRIGGER tg_assembly_manufacturers_created_by
    BEFORE INSERT OR UPDATE ON assembly_manufacturers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_assembly_manufacturers_audit ON assembly_manufacturers;
CREATE TRIGGER tg_assembly_manufacturers_audit
    AFTER INSERT OR UPDATE OR DELETE ON assembly_manufacturers
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- pcb_assemblies
-- =============================================================================

DROP TRIGGER IF EXISTS tg_pcb_assemblies_updated_at ON pcb_assemblies;
CREATE TRIGGER tg_pcb_assemblies_updated_at
    BEFORE UPDATE ON pcb_assemblies
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_pcb_assemblies_created_by ON pcb_assemblies;
CREATE TRIGGER tg_pcb_assemblies_created_by
    BEFORE INSERT OR UPDATE ON pcb_assemblies
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_pcb_assemblies_audit ON pcb_assemblies;
CREATE TRIGGER tg_pcb_assemblies_audit
    AFTER INSERT OR UPDATE OR DELETE ON pcb_assemblies
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_pcb_assemblies_no_hard_delete ON pcb_assemblies;
CREATE TRIGGER tg_pcb_assemblies_no_hard_delete
    BEFORE DELETE ON pcb_assemblies
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

DROP TRIGGER IF EXISTS tg_pcb_assemblies_activity ON pcb_assemblies;
CREATE TRIGGER tg_pcb_assemblies_activity
    AFTER INSERT OR UPDATE ON pcb_assemblies
    FOR EACH ROW
    EXECUTE FUNCTION fn_pcb_assembly_activity();

-- =============================================================================
-- pcb_revisions
-- =============================================================================

DROP TRIGGER IF EXISTS tg_pcb_revisions_updated_at ON pcb_revisions;
CREATE TRIGGER tg_pcb_revisions_updated_at
    BEFORE UPDATE ON pcb_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_pcb_revisions_created_by ON pcb_revisions;
CREATE TRIGGER tg_pcb_revisions_created_by
    BEFORE INSERT OR UPDATE ON pcb_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- Enforce single current revision BEFORE insert/update
DROP TRIGGER IF EXISTS tg_pcb_revisions_current_enforce ON pcb_revisions;
CREATE TRIGGER tg_pcb_revisions_current_enforce
    BEFORE INSERT OR UPDATE OF is_current_revision ON pcb_revisions
    FOR EACH ROW
    WHEN (NEW.is_current_revision = TRUE)
    EXECUTE FUNCTION fn_pcb_revision_current_enforce();

-- Notify linked stencil designs AFTER current revision changes
DROP TRIGGER IF EXISTS tg_pcb_revisions_notify_stencil ON pcb_revisions;
CREATE TRIGGER tg_pcb_revisions_notify_stencil
    AFTER UPDATE OF is_current_revision ON pcb_revisions
    FOR EACH ROW
    WHEN (OLD.is_current_revision IS DISTINCT FROM NEW.is_current_revision)
    EXECUTE FUNCTION fn_pcb_revision_notify_stencil();

DROP TRIGGER IF EXISTS tg_pcb_revisions_audit ON pcb_revisions;
CREATE TRIGGER tg_pcb_revisions_audit
    AFTER INSERT OR UPDATE OR DELETE ON pcb_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- pcb_layers
-- =============================================================================

DROP TRIGGER IF EXISTS tg_pcb_layers_updated_at ON pcb_layers;
CREATE TRIGGER tg_pcb_layers_updated_at
    BEFORE UPDATE ON pcb_layers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_pcb_layers_created_by ON pcb_layers;
CREATE TRIGGER tg_pcb_layers_created_by
    BEFORE INSERT OR UPDATE ON pcb_layers
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_pcb_layers_audit ON pcb_layers;
CREATE TRIGGER tg_pcb_layers_audit
    AFTER INSERT OR UPDATE OR DELETE ON pcb_layers
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- pcb_stackups
-- =============================================================================

DROP TRIGGER IF EXISTS tg_pcb_stackups_updated_at ON pcb_stackups;
CREATE TRIGGER tg_pcb_stackups_updated_at
    BEFORE UPDATE ON pcb_stackups
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_pcb_stackups_created_by ON pcb_stackups;
CREATE TRIGGER tg_pcb_stackups_created_by
    BEFORE INSERT OR UPDATE ON pcb_stackups
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- assembly_variants
-- =============================================================================

DROP TRIGGER IF EXISTS tg_assembly_variants_updated_at ON assembly_variants;
CREATE TRIGGER tg_assembly_variants_updated_at
    BEFORE UPDATE ON assembly_variants
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_assembly_variants_created_by ON assembly_variants;
CREATE TRIGGER tg_assembly_variants_created_by
    BEFORE INSERT OR UPDATE ON assembly_variants
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- design_files
-- =============================================================================

DROP TRIGGER IF EXISTS tg_design_files_updated_at ON design_files;
CREATE TRIGGER tg_design_files_updated_at
    BEFORE UPDATE ON design_files
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_design_files_created_by ON design_files;
CREATE TRIGGER tg_design_files_created_by
    BEFORE INSERT OR UPDATE ON design_files
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_design_files_audit ON design_files;
CREATE TRIGGER tg_design_files_audit
    AFTER INSERT OR UPDATE OR DELETE ON design_files
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_design_files_no_hard_delete ON design_files;
CREATE TRIGGER tg_design_files_no_hard_delete
    BEFORE DELETE ON design_files
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- components
-- =============================================================================

DROP TRIGGER IF EXISTS tg_components_updated_at ON components;
CREATE TRIGGER tg_components_updated_at
    BEFORE UPDATE ON components
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_components_created_by ON components;
CREATE TRIGGER tg_components_created_by
    BEFORE INSERT OR UPDATE ON components
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_components_audit ON components;
CREATE TRIGGER tg_components_audit
    AFTER INSERT OR UPDATE OR DELETE ON components
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

DROP TRIGGER IF EXISTS tg_components_no_hard_delete ON components;
CREATE TRIGGER tg_components_no_hard_delete
    BEFORE DELETE ON components
    FOR EACH ROW
    WHEN (OLD.is_deleted = FALSE)
    EXECUTE FUNCTION fn_soft_delete_check();

-- =============================================================================
-- component_revisions
-- =============================================================================

DROP TRIGGER IF EXISTS tg_component_revisions_updated_at ON component_revisions;
CREATE TRIGGER tg_component_revisions_updated_at
    BEFORE UPDATE ON component_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_component_revisions_created_by ON component_revisions;
CREATE TRIGGER tg_component_revisions_created_by
    BEFORE INSERT OR UPDATE ON component_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_component_revisions_current_enforce ON component_revisions;
CREATE TRIGGER tg_component_revisions_current_enforce
    BEFORE INSERT OR UPDATE OF is_current ON component_revisions
    FOR EACH ROW
    WHEN (NEW.is_current = TRUE)
    EXECUTE FUNCTION fn_component_revision_current_enforce();

DROP TRIGGER IF EXISTS tg_component_revisions_audit ON component_revisions;
CREATE TRIGGER tg_component_revisions_audit
    AFTER INSERT OR UPDATE OR DELETE ON component_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- electrical_nets
-- =============================================================================

DROP TRIGGER IF EXISTS tg_electrical_nets_updated_at ON electrical_nets;
CREATE TRIGGER tg_electrical_nets_updated_at
    BEFORE UPDATE ON electrical_nets
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_electrical_nets_created_by ON electrical_nets;
CREATE TRIGGER tg_electrical_nets_created_by
    BEFORE INSERT OR UPDATE ON electrical_nets
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- =============================================================================
-- bom_revisions
-- =============================================================================

DROP TRIGGER IF EXISTS tg_bom_revisions_updated_at ON bom_revisions;
CREATE TRIGGER tg_bom_revisions_updated_at
    BEFORE UPDATE ON bom_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_bom_revisions_created_by ON bom_revisions;
CREATE TRIGGER tg_bom_revisions_created_by
    BEFORE INSERT OR UPDATE ON bom_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

DROP TRIGGER IF EXISTS tg_bom_revisions_current_enforce ON bom_revisions;
CREATE TRIGGER tg_bom_revisions_current_enforce
    BEFORE INSERT OR UPDATE OF is_current ON bom_revisions
    FOR EACH ROW
    WHEN (NEW.is_current = TRUE)
    EXECUTE FUNCTION fn_bom_revision_current_enforce();

DROP TRIGGER IF EXISTS tg_bom_revisions_immutable ON bom_revisions;
CREATE TRIGGER tg_bom_revisions_immutable
    BEFORE UPDATE ON bom_revisions
    FOR EACH ROW
    WHEN (OLD.is_released = TRUE)
    EXECUTE FUNCTION fn_bom_revision_immutable();

DROP TRIGGER IF EXISTS tg_bom_revisions_audit ON bom_revisions;
CREATE TRIGGER tg_bom_revisions_audit
    AFTER INSERT OR UPDATE OR DELETE ON bom_revisions
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- bom_items
-- =============================================================================

DROP TRIGGER IF EXISTS tg_bom_items_updated_at ON bom_items;
CREATE TRIGGER tg_bom_items_updated_at
    BEFORE UPDATE ON bom_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_bom_items_created_by ON bom_items;
CREATE TRIGGER tg_bom_items_created_by
    BEFORE INSERT OR UPDATE ON bom_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- Block modifications when parent BOM is released
DROP TRIGGER IF EXISTS tg_bom_items_released_block ON bom_items;
CREATE TRIGGER tg_bom_items_released_block
    BEFORE INSERT OR UPDATE OR DELETE ON bom_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_bom_item_modification_released();

-- Maintain aggregate counts on bom_revisions
DROP TRIGGER IF EXISTS tg_bom_items_counts ON bom_items;
CREATE TRIGGER tg_bom_items_counts
    AFTER INSERT OR UPDATE OR DELETE ON bom_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_bom_counts_update();

DROP TRIGGER IF EXISTS tg_bom_items_audit ON bom_items;
CREATE TRIGGER tg_bom_items_audit
    AFTER INSERT OR UPDATE OR DELETE ON bom_items
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

-- =============================================================================
-- component_placements
-- =============================================================================

DROP TRIGGER IF EXISTS tg_component_placements_updated_at ON component_placements;
CREATE TRIGGER tg_component_placements_updated_at
    BEFORE UPDATE ON component_placements
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS tg_component_placements_created_by ON component_placements;
CREATE TRIGGER tg_component_placements_created_by
    BEFORE INSERT OR UPDATE ON component_placements
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_created_updated_by();

-- Maintain revision summary counts after placement changes
DROP TRIGGER IF EXISTS tg_component_placements_counts ON component_placements;
CREATE TRIGGER tg_component_placements_counts
    AFTER INSERT OR UPDATE OR DELETE ON component_placements
    FOR EACH ROW
    EXECUTE FUNCTION fn_component_placement_counts_update();

DROP TRIGGER IF EXISTS tg_component_placements_audit ON component_placements;
CREATE TRIGGER tg_component_placements_audit
    AFTER INSERT OR UPDATE OR DELETE ON component_placements
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_trigger();

COMMIT;
