# The agent itself. It wires the five pillars together.
# Notice what is NOT here: no keys, no secrets, no connection strings with credentials.

locals {
  # Foundry project endpoint format documented by Microsoft.
  project_endpoint = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.services.ai.azure.com/api/projects/${azurerm_cognitive_account_project.agent.name}"
}

resource "azurerm_container_app" "agent" {
  name                         = "ca-agent-${local.suffix}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agent.id]
  }

  ingress {
    # Internal environment plus external_enabled = true means "reachable from the VNet".
    # It does not mean "reachable from the internet" when internal_only is true.
    external_enabled           = true
    target_port                = 80
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "agent"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"

      # DefaultAzureCredential picks the user-assigned identity from this variable.
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.agent.client_id
      }

      env {
        name  = "FOUNDRY_PROJECT_ENDPOINT"
        value = local.project_endpoint
      }

      env {
        name  = "FOUNDRY_MODEL_DEPLOYMENT"
        value = azurerm_cognitive_deployment.chat.name
      }

      env {
        name  = "KEY_VAULT_URI"
        value = azurerm_key_vault.agent.vault_uri
      }

      # The connection string identifies the resource. It is not a credential.
      # The auth string tells the SDK to send telemetry with the managed identity.
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.this.connection_string
      }

      env {
        name  = "APPLICATIONINSIGHTS_AUTHENTICATION_STRING"
        value = "Authorization=AAD;ClientId=${azurerm_user_assigned_identity.agent.client_id}"
      }
    }
  }

  tags = local.tags

  # Role assignments must exist before the first revision starts calling services.
  depends_on = [
    azurerm_role_assignment.agent_foundry_user,
    azurerm_role_assignment.agent_kv_secrets_user,
    azurerm_role_assignment.agent_telemetry_publisher,
  ]
}
