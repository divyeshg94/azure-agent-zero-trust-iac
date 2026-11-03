# E is for Encrypt.
# Every data path stays on the Microsoft backbone over TLS.
# No public endpoints on Foundry or Key Vault. The agent runs inside the VNet.

resource "azurerm_key_vault" "agent" {
  name                = "kv-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Required in azurerm 5.x. RBAC instead of access policies.
  rbac_authorization_enabled = true

  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = local.tags
}

resource "azurerm_private_endpoint" "foundry" {
  name                = "pe-foundry-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "foundry"
    private_connection_resource_id = azurerm_cognitive_account.foundry.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  # One endpoint, three DNS zones. Miss one and some calls leave the VNet.
  private_dns_zone_group {
    name = "foundry"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.this["cognitive"].id,
      azurerm_private_dns_zone.this["openai"].id,
      azurerm_private_dns_zone.this["foundry"].id,
    ]
  }
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-kv-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "keyvault"
    private_connection_resource_id = azurerm_key_vault.agent.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault"
    private_dns_zone_ids = [azurerm_private_dns_zone.this["keyvault"].id]
  }
}

resource "azurerm_container_app_environment" "this" {
  name                = "cae-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  infrastructure_subnet_id       = azurerm_subnet.apps.id
  internal_load_balancer_enabled = var.internal_only

  # Logs go to Azure Monitor and are routed by a diagnostic setting (see trace.tf).
  # This avoids handing the environment a Log Analytics shared key.
  logs_destination = "azure-monitor"

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = local.tags
}
