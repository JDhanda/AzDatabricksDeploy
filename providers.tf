terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.45"
    }
  }

  # Recommended: store state in Azure Blob Storage
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stterraformstate"
  #   container_name       = "tfstate"
  #   key                  = "databricks-unity-catalog.tfstate"
  # }
}

# ─────────────────────────────────────────────
# Azure provider
# ─────────────────────────────────────────────
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}

# ─────────────────────────────────────────────
# Databricks ACCOUNT-level provider
# Used for: metastore, metastore_data_access,
#           metastore_assignment, account users
# ─────────────────────────────────────────────
provider "databricks" {
  alias      = "account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id

  # Authentication: Azure CLI (recommended for CI/CD use service principal below)
  azure_tenant_id       = var.azure_tenant_id
  azure_client_id       = var.databricks_sp_client_id
  azure_client_secret   = var.databricks_sp_client_secret
}

# ─────────────────────────────────────────────
# Databricks WORKSPACE-level provider
# Used for: catalogs, schemas, grants, clusters
# Depends on the workspace being created first
# ─────────────────────────────────────────────
provider "databricks" {
  alias = "workspace"
  host  = azurerm_databricks_workspace.this.workspace_url

  azure_tenant_id     = var.azure_tenant_id
  azure_client_id     = var.databricks_sp_client_id
  azure_client_secret = var.databricks_sp_client_secret
}
