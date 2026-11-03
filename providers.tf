provider "azurerm" {
  subscription_id = var.subscription_id

  # azurerm 5.x registers no resource providers by default.
  # Register only what this stack needs, nothing more.
  resource_providers_to_register = [
    "Microsoft.App",
    "Microsoft.CognitiveServices",
    "Microsoft.Insights",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
  ]

  features {}
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result
  name   = "${var.prefix}-${local.suffix}"

  tags = merge(var.tags, {
    framework = "AGENT"
    managedBy = "terraform"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}
