locals {
  # Consistent prefix for all resource names
  prefix = "${var.project}-${var.environment}"

  # Storage account names: 3-24 chars, lowercase alphanumeric only
  metastore_sa_name = substr(
    lower(replace("st${var.project}${var.environment}uc", "-", "")),
    0, 24
  )

  # Standard tags applied to every resource
  common_tags = merge(
    {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )
}
