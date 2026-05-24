output "resource_group_name" {
  description = "Name of the Azure resource group."
  value       = azurerm_resource_group.this.name
}

output "workspace_url" {
  description = "URL to open the Databricks workspace."
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "workspace_id" {
  description = "Numeric workspace ID used in the Databricks account console."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "metastore_id" {
  description = "Unity Catalog metastore ID."
  value       = databricks_metastore.this.id
}

output "metastore_storage_root" {
  description = "ADLS Gen2 path used as the metastore root."
  value = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.metastore.name,
    azurerm_storage_account.metastore.name
  )
}

output "storage_account_name" {
  description = "Name of the ADLS Gen2 storage account backing the metastore."
  value       = azurerm_storage_account.metastore.name
}

output "access_connector_id" {
  description = "Resource ID of the Databricks Access Connector."
  value       = azurerm_databricks_access_connector.unity_catalog.id
}

output "catalog_names" {
  description = "Names of all Unity Catalog catalogs created."
  value       = [for c in databricks_catalog.this : c.name]
}
