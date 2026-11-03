output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "foundry_account_name" {
  value = azurerm_cognitive_account.foundry.name
}

output "foundry_project_endpoint" {
  value = local.project_endpoint
}

output "foundry_project_endpoints" {
  description = "All endpoints Azure reports for the project."
  value       = azurerm_cognitive_account_project.agent.endpoints
}

output "model_deployment_name" {
  value = azurerm_cognitive_deployment.chat.name
}

output "agent_identity_client_id" {
  value = azurerm_user_assigned_identity.agent.client_id
}

output "agent_fqdn" {
  description = "Resolvable only inside the VNet when internal_only is true."
  value       = azurerm_container_app.agent.ingress[0].fqdn
}

output "key_vault_uri" {
  value = azurerm_key_vault.agent.vault_uri
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}
