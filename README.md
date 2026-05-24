# Azure Databricks — Unity Catalog (Terraform)

Deploys a fully governed Azure Databricks environment with Unity Catalog
in a single `terraform apply`. No manual portal steps required after initial
service principal setup.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_resource_group` | Container for all Databricks resources |
| `azurerm_storage_account` | ADLS Gen2 backing store for metastore (GRS, HNS enabled) |
| `azurerm_storage_container` | Metastore root container |
| `azurerm_databricks_access_connector` | Managed identity bridge to ADLS |
| `azurerm_role_assignment` | Storage Blob Data Contributor → access connector |
| `azurerm_databricks_workspace` | Premium workspace (required for Unity Catalog) |
| `databricks_metastore` | Account-level metadata store (one per region) |
| `databricks_metastore_data_access` | Credential link: metastore → ADLS via managed identity |
| `databricks_metastore_assignment` | Attaches metastore to workspace |
| `databricks_catalog` | One catalog per entry in `catalog_configs` |
| `databricks_schema` | Default schema in each catalog |
| `databricks_grants` | Admin and reader privileges per catalog |

## Prerequisites

1. **Azure subscription** with Owner or Contributor role.

2. **Service principal** with:
   - `Contributor` role on the Azure subscription
   - `Account Admin` in the Databricks account console
     (accounts.azuredatabricks.net → Settings → Admins)

3. **Register `Microsoft.Databricks`** resource provider:
   ```bash
   az provider register --namespace Microsoft.Databricks --wait
   ```

4. **Databricks account** (not workspace) created at accounts.azuredatabricks.net.

## Quickstart

```bash
# 1. Clone and enter the directory
cd databricks-unity-catalog

# 2. Create your variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your real values

# 3. Authenticate Azure CLI
az login
az account set --subscription "<your-subscription-id>"

# 4. Initialize Terraform
terraform init

# 5. Preview changes
terraform plan

# 6. Deploy (takes ~8-12 minutes)
terraform apply
```

## Adding a new catalog

In `terraform.tfvars`, add an entry to `catalog_configs`:

```hcl
catalog_configs = {
  # ... existing catalogs ...
  ml_features = {
    comment      = "Feature store for ML models."
    data_admins  = ["ml-engineers"]
    data_readers = ["data-scientists"]
  }
}
```

Then run `terraform apply` — it adds only the new catalog without touching existing ones.

## File layout

```
.
├── providers.tf          # AzureRM + two Databricks provider aliases
├── variables.tf          # All input variable declarations
├── locals.tf             # Computed locals (naming, tags)
├── main.tf               # Resource group, storage, access connector, workspace
├── unity_catalog.tf      # Metastore, data access, assignment, catalogs, grants
├── outputs.tf            # Workspace URL, metastore ID, catalog names
├── terraform.tfvars.example  # Template — copy to terraform.tfvars
└── .gitignore            # Excludes state files and secrets
```

## Important notes

- **One metastore per region** — if your region already has a metastore in the
  Databricks account, `terraform apply` will fail. Import the existing metastore
  with `terraform import databricks_metastore.this <metastore-id>`.

- **`force_destroy = false`** on the metastore — intentional. Destroying a metastore
  with live catalogs would delete all metadata. Set to `true` only for ephemeral
  dev environments where data loss is acceptable.

- **State file security** — the tfstate file contains sensitive resource IDs.
  Use the commented-out `backend "azurerm"` block in `providers.tf` to store
  state in Azure Blob Storage with encryption at rest.
