# ═══════════════════════════════════════════════════════════════
# UNITY CATALOG METASTORE
#
# The metastore is an account-level object — one per region.
# It is the root of the entire Unity Catalog hierarchy and stores:
#   • Table and view definitions (schema/metadata)
#   • Access control policies (who can do what)
#   • Data lineage records
#   • Storage credential references
#   • Audit log pointers
#
# All resources below use the "account" provider alias because
# they live at the Databricks account level, above any workspace.
# ═══════════════════════════════════════════════════════════════
resource "databricks_metastore" "this" {
  provider = databricks.account

  name   = "metastore-${var.location}"
  region = var.location

  # Root ADLS Gen2 path where Unity Catalog stores managed data.
  # Format: abfss://<container>@<account>.dfs.core.windows.net/<path>
  storage_root = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.metastore.name,
    azurerm_storage_account.metastore.name
  )

  # Prevent destroying a metastore that may have catalogs/tables in it.
  # Remove this only when intentionally tearing down.
  force_destroy = false

  depends_on = [azurerm_role_assignment.access_connector_storage]
}

# ─────────────────────────────────────────────
# STORAGE CREDENTIAL (data access configuration)
#
# Links the metastore to the managed identity so Databricks
# knows which Azure credential to use when reading/writing
# the managed storage root. Without this, the metastore
# cannot access its own ADLS Gen2 backing store.
# ─────────────────────────────────────────────
resource "databricks_metastore_data_access" "this" {
  provider     = databricks.account
  metastore_id = databricks_metastore.this.id
  name         = "dac-${local.prefix}-uc"
  is_default   = true   # Sets this as the default credential for the metastore

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.unity_catalog.id
  }

  depends_on = [databricks_metastore.this]
}

# ─────────────────────────────────────────────
# METASTORE ASSIGNMENT
#
# Attaches the metastore to the workspace.
# A metastore can serve multiple workspaces in the same region.
# A workspace can only be assigned to ONE metastore.
# ─────────────────────────────────────────────
resource "databricks_metastore_assignment" "this" {
  provider             = databricks.account
  metastore_id         = databricks_metastore.this.id
  workspace_id         = azurerm_databricks_workspace.this.workspace_id
  default_catalog_name = "main"   # The default catalog opened in the workspace UI

  depends_on = [databricks_metastore_data_access.this]
}

# ═══════════════════════════════════════════════════════════════
# CATALOGS
#
# Catalogs are the top-level namespace inside Unity Catalog.
# They contain schemas (databases) which contain tables and views.
# We create one catalog per entry in var.catalog_configs.
#
# Uses the "workspace" provider because catalogs are created
# through the workspace API, even though they're governed by
# the account-level metastore.
# ═══════════════════════════════════════════════════════════════
resource "databricks_catalog" "this" {
  provider = databricks.workspace

  for_each = var.catalog_configs

  name    = each.key
  comment = each.value.comment

  # Isolate each catalog in its own subdirectory of the metastore root
  storage_root = format(
    "abfss://%s@%s.dfs.core.windows.net/%s",
    azurerm_storage_container.metastore.name,
    azurerm_storage_account.metastore.name,
    each.key
  )

  depends_on = [databricks_metastore_assignment.this]
}

# ─────────────────────────────────────────────
# CATALOG-LEVEL GRANTS — admin groups
#
# data_admins get: USE CATALOG, CREATE SCHEMA,
#                  CREATE TABLE, CREATE VIEW
# ─────────────────────────────────────────────
resource "databricks_grants" "catalog_admins" {
  provider = databricks.workspace

  for_each = {
    for item in flatten([
      for cat_name, cat in var.catalog_configs : [
        for group in cat.data_admins : {
          key      = "${cat_name}::${group}"
          catalog  = cat_name
          group    = group
        }
      ]
    ]) : item.key => item
  }

  catalog = databricks_catalog.this[each.value.catalog].name

  grant {
    principal  = each.value.group
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "CREATE_TABLE", "CREATE_VIEW"]
  }
}

# ─────────────────────────────────────────────
# CATALOG-LEVEL GRANTS — reader groups
#
# data_readers get: USE CATALOG, USE SCHEMA, SELECT
# Schema and table-level SELECT is inherited via
# Unity Catalog's privilege inheritance model.
# ─────────────────────────────────────────────
resource "databricks_grants" "catalog_readers" {
  provider = databricks.workspace

  for_each = {
    for item in flatten([
      for cat_name, cat in var.catalog_configs : [
        for group in cat.data_readers : {
          key     = "${cat_name}::${group}"
          catalog = cat_name
          group   = group
        }
      ]
    ]) : item.key => item
  }

  catalog = databricks_catalog.this[each.value.catalog].name

  grant {
    principal  = each.value.group
    privileges = ["USE_CATALOG"]
  }
}

# ─────────────────────────────────────────────
# METASTORE-LEVEL GRANTS — admin groups
#
# Metastore admins can manage all objects, create
# storage credentials, and assign workspaces.
# ─────────────────────────────────────────────
resource "databricks_grants" "metastore_admins" {
  provider = databricks.account

  for_each = toset(var.metastore_admins)

  metastore = databricks_metastore.this.id

  grant {
    principal  = each.value
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
}

# ═══════════════════════════════════════════════════════════════
# DEFAULT SCHEMAS inside each catalog
#
# Creates a "default" schema in every catalog so users have
# a ready-to-use namespace without manual setup.
# ═══════════════════════════════════════════════════════════════
resource "databricks_schema" "default" {
  provider     = databricks.workspace
  for_each     = var.catalog_configs
  catalog_name = databricks_catalog.this[each.key].name
  name         = "default"
  comment      = "Default schema — auto-created by Terraform."
}
