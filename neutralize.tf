# N is for Neutralize.
# Harmful input and output is filtered at the platform, before your code sees it.
# Prompt shields catch jailbreaks and indirect prompt injection from tool output.

resource "azurerm_cognitive_account_rai_policy" "agent" {
  name                 = "agent-strict"
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  base_policy_name     = "Microsoft.Default"

  # Harm categories, filtered on both the prompt and the completion.
  # "Low" is the strictest threshold: it blocks low severity and above.
  dynamic "content_filter" {
    for_each = {
      for pair in setproduct(["Hate", "Sexual", "Violence", "SelfHarm"], ["Prompt", "Completion"]) :
      "${pair[0]}-${pair[1]}" => { name = pair[0], source = pair[1] }
    }

    content {
      name               = content_filter.value.name
      source             = content_filter.value.source
      filter_enabled     = true
      block_enabled      = true
      severity_threshold = "Low"
    }
  }

  # Prompt shields. These have no severity threshold.
  content_filter {
    name           = "Jailbreak"
    source         = "Prompt"
    filter_enabled = true
    block_enabled  = true
  }

  # The one agents need most: instructions hidden inside documents and tool results.
  content_filter {
    name           = "Indirect Attack"
    source         = "Prompt"
    filter_enabled = true
    block_enabled  = true
  }

  content_filter {
    name           = "Protected Material Text"
    source         = "Completion"
    filter_enabled = true
    block_enabled  = true
  }

  content_filter {
    name           = "Protected Material Code"
    source         = "Completion"
    filter_enabled = true
    block_enabled  = false # Annotate rather than block, so code answers still flow.
  }
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.model_name
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  # The filter policy is bound to the deployment, not the app.
  # Every caller of this deployment gets the same guardrails.
  rai_policy_name = azurerm_cognitive_account_rai_policy.agent.name

  # Pin versions in production so a silent model upgrade can't change behavior.
  version_upgrade_option = "NoAutoUpgrade"

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  sku {
    name     = var.model_sku
    capacity = var.model_capacity
  }
}
