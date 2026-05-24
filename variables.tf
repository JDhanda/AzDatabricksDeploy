# ─────────────────────────────────────────────
# Azure identity
# ─────────────────────────────────────────────
variable "azure_subscription_id" {
  description = "Azure subscription ID where all resources will be deployed."
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure Entra ID (AAD) tenant ID."
  type        = string
}

# ─────────────────────────────────────────────
# Databricks account
# ─────────────────────────────────────────────
variable "databricks_account_id" {
  description = "Databricks account ID (found at accounts.azuredatabricks.net)."
  type        = string
  sensitive   = true
}

variable "databricks_sp_client_id" {
  description = "Client ID of the service principal used by both Databricks providers."
  type        = string
  sensitive   = true
}

variable "databricks_sp_client_secret" {
  description = "Client secret of the service principal."
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────
# Project / environment
# ─────────────────────────────────────────────
variable "project" {
  description = "Short project identifier used in all resource names (lowercase, no spaces)."
  type        = string
  default     = "analytics"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,12}$", var.project))
    error_message = "project must be 2-12 lowercase alphanumeric characters or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment: dev, staging, or prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region. Must match the Databricks metastore region."
  type        = string
  default     = "canadacentral"
}

# ─────────────────────────────────────────────
# Databricks workspace
# ─────────────────────────────────────────────
variable "databricks_sku" {
  description = "Databricks workspace pricing tier. Must be 'premium' for Unity Catalog."
  type        = string
  default     = "premium"

  validation {
    condition     = var.databricks_sku == "premium"
    error_message = "Unity Catalog requires the premium SKU."
  }
}

# ─────────────────────────────────────────────
# Unity Catalog
# ─────────────────────────────────────────────
variable "metastore_admins" {
  description = "List of Entra ID group names that will be metastore admins."
  type        = list(string)
  default     = []
}

variable "catalog_configs" {
  description = <<-EOT
    Map of Unity Catalog catalogs to create.
    Each key is the catalog name.
    'comment'   : human-readable description shown in the UI.
    'data_admins': groups granted USE_CATALOG + CREATE_SCHEMA + CREATE_TABLE.
    'data_readers': groups granted USE_CATALOG + USE_SCHEMA + SELECT.
  EOT
  type = map(object({
    comment      = string
    data_admins  = list(string)
    data_readers = list(string)
  }))

  default = {
    raw = {
      comment      = "Landing zone — raw ingested data, no transformations."
      data_admins  = []
      data_readers = []
    }
    silver = {
      comment      = "Cleaned and conformed data layer."
      data_admins  = []
      data_readers = []
    }
    gold = {
      comment      = "Business-ready aggregations and feature tables."
      data_admins  = []
      data_readers = []
    }
  }
}

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}
