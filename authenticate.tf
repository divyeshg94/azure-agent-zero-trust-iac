# A is for Authenticate.
# The agent gets one user-assigned managed identity and nothing else.
# No API keys, no connection strings with secrets, no client secrets.

resource "azurerm_user_assigned_identity" "agent" {
  name                = "id-agent-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_cognitive_account" "foundry" {
  name                = "ais-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  kind                = "AIServices"
  sku_name            = "S0"

  # Required for Entra ID token auth and for private endpoints.
  custom_subdomain_name = "ais-${local.name}"

  # Turns this account into a Foundry resource that can hold projects.
  project_management_enabled = true

  # The single most important line in this file.
  # With local auth off, API keys stop working. Entra ID is the only way in.
  local_auth_enabled = false

  # Encrypt pillar: no public endpoint.
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_cognitive_account_project" "agent" {
  name                 = "proj-agent"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  location             = azurerm_resource_group.this.location
  display_name         = "Zero-trust agent"
  description          = "Project provisioned by the AGENT framework reference stack."

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}
