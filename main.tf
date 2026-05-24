# ═══════════════════════════════════════════════════════════════
# RESOURCE GROUP
# Single resource group for all Databricks + Unity Catalog assets
# ═══════════════════════════════════════════════════════════════
resource "azurerm_resource_group" "this" {
  name     = "rg-${local.prefix}-databricks"
  location = var.location
  tags     = local.common_tags
}

# ═══════════════════════════════════════════════════════════════
# ADLS GEN2 STORAGE — metastore root storage
#
# Unity Catalog stores all managed table data and metadata here.
# HNS (hierarchical namespace) is required for ADLS Gen2.
# ═══════════════════════════════════════════════════════════════
resource "azurerm_storage_account" "metastore" {
  name                     = local.metastore_sa_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "GRS"         # Geo-redundant for metastore durability
  account_kind             = "StorageV2"
  is_hns_enabled           = true          # Required for ADLS Gen2

  # Security hardening
  min_tls_version              = "TLS1_2"
  enable_https_traffic_only    = true
  allow_nested_items_to_be_public = false

  # Prevent accidental deletion of metastore storage
  blob_properties {
    delete_retention_policy {
      days = 30
    }
  }

  tags = local.common_tags
}

# Container that becomes the metastore root path
resource "azurerm_storage_container" "metastore" {
  name                  = "metastore"
  storage_account_name  = azurerm_storage_account.metastore.name
  container_access_type = "private"
}

# ═══════════════════════════════════════════════════════════════
# DATABRICKS ACCESS CONNECTOR (managed identity)
#
# This is the Azure-side bridge that lets Unity Catalog access
# ADLS Gen2 without storing credentials anywhere. Databricks
# uses this connector's system-assigned managed identity to
# authenticate to storage on behalf of the metastore.
# ═══════════════════════════════════════════════════════════════
resource "azurerm_databricks_access_connector" "unity_catalog" {
  name                = "ac-${local.prefix}-uc"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Grant the access connector "Storage Blob Data Contributor"
# on the metastore storage account.
# This is the minimum required role — it allows read/write/delete
# of blobs but not control-plane operations.
resource "azurerm_role_assignment" "access_connector_storage" {
  scope                = azurerm_storage_account.metastore.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.unity_catalog.identity[0].principal_id
}

# ═══════════════════════════════════════════════════════════════
# DATABRICKS WORKSPACE (Premium — required for Unity Catalog)
# ═══════════════════════════════════════════════════════════════
resource "azurerm_databricks_workspace" "this" {
  name                = "dbw-${local.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = var.databricks_sku   # Must be "premium"

  # Managed resource group where Databricks places VMs, VNets, etc.
  managed_resource_group_name = "rg-${local.prefix}-databricks-managed"

  tags = local.common_tags
}
