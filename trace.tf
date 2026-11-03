# T is for Trace.
# Every model call, every vault read, and every container log lands in one workspace.
# Ingestion and queries both require Entra ID. No shared keys anywhere.

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  local_authentication_enabled = false

  tags = local.tags
}

resource "azurerm_application_insights" "this" {
  name                = "appi-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "other"

  # Telemetry must be sent with an Entra ID token (see grant.tf).
  local_authentication_enabled = false

  tags = local.tags
}

# Route platform logs from every component into the same workspace.
locals {
  diagnostic_targets = {
    foundry  = azurerm_cognitive_account.foundry.id
    keyvault = azurerm_key_vault.agent.id
    cae      = azurerm_container_app_environment.this.id
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = local.diagnostic_targets

  name                       = "diag-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
