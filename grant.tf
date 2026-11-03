# G is for Grant.
# Least privilege, scoped to the smallest resource that works.
#
# Role definitions are referenced by GUID, not by name. Microsoft renamed the
# Azure AI roles to Foundry roles in 2026, and name-based lookups are exactly
# the kind of thing that breaks quietly during a rename. GUIDs don't change.

locals {
  role_ids = {
    # Foundry User (formerly Azure AI User): data-plane access to a project.
    foundry_user = "53ca6127-db72-4b80-b1b0-d745d6d5456d"

    # Key Vault Secrets User: read secret values, nothing else.
    key_vault_secrets_user = "4633458b-17de-408a-b874-0445c86b69e6"

    # Monitoring Metrics Publisher: send telemetry to Application Insights with Entra ID.
    monitoring_metrics_publisher = "3913510d-42f4-4e42-8a64-420c390055eb"
  }

  role_scope_prefix = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions"
}

# The agent can call models and agents in its own project, and only that project.
resource "azurerm_role_assignment" "agent_foundry_user" {
  scope              = azurerm_cognitive_account_project.agent.id
  role_definition_id = "${local.role_scope_prefix}/${local.role_ids.foundry_user}"
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
  description        = "AGENT/Grant: agent identity can use its Foundry project."
}

# The agent can read secrets from its own vault, and only that vault.
resource "azurerm_role_assignment" "agent_kv_secrets_user" {
  scope              = azurerm_key_vault.agent.id
  role_definition_id = "${local.role_scope_prefix}/${local.role_ids.key_vault_secrets_user}"
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
  description        = "AGENT/Grant: agent identity can read its own secrets."
}

# The agent can write telemetry, but can't read it back.
resource "azurerm_role_assignment" "agent_telemetry_publisher" {
  scope              = azurerm_application_insights.this.id
  role_definition_id = "${local.role_scope_prefix}/${local.role_ids.monitoring_metrics_publisher}"
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
  description        = "AGENT/Grant: agent identity can publish telemetry."
}
