# Zero-trust AI agents on Azure with Terraform

A reference stack that provisions a Microsoft Foundry agent on Azure Container Apps using the **AGENT framework**: five controls that every production AI agent should have before it touches real data.

| Pillar | Control | Where |
|---|---|---|
| **A**uthenticate | Managed identity only. Foundry API keys disabled. | [`authenticate.tf`](authenticate.tf) |
| **G**rant | Three role assignments, each scoped to one resource. Roles referenced by GUID. | [`grant.tf`](grant.tf) |
| **E**ncrypt | Private endpoints for Foundry and Key Vault. Agent runs inside the VNet. | [`network.tf`](network.tf), [`encrypt.tf`](encrypt.tf) |
| **N**eutralize | Strict content filter plus jailbreak and indirect-attack shields, bound to the model deployment. | [`neutralize.tf`](neutralize.tf) |
| **T**race | All platform logs in one Log Analytics workspace. Entra ID required for ingestion and query. | [`trace.tf`](trace.tf), [`queries/`](queries) |

The companion article walks through each file: *Zero-trust AI agents on Azure, provisioned with Terraform* on [Microsoft Azure in Practice](https://medium.com/@divyeshg94).

## What gets deployed

```
Resource group
├── Virtual network
│   ├── snet-apps (delegated to Container Apps)
│   └── snet-private-endpoints (NSG: 443 from snet-apps only)
├── Private DNS zones (cognitiveservices, openai, services.ai, vaultcore)
├── Foundry resource (AIServices, local auth off, public access off)
│   ├── Project
│   ├── Model deployment, bound to the agent-strict content filter
│   └── Private endpoint
├── Key Vault (RBAC, purge protection, public access off) + private endpoint
├── User-assigned managed identity for the agent
├── Container Apps environment (internal) + agent container app
└── Log Analytics workspace + Application Insights + diagnostic settings
```

## Requirements

- Terraform 1.11+ or OpenTofu 1.11+
- AzureRM provider 5.x. This stack uses 5.x property names (`rbac_authorization_enabled`, `logs_destination`, `private_dns_zone_id`, and `resource_providers_to_register`). It will not run on 4.x without changes.
- An Azure subscription where you can create role assignments (Owner, or Contributor plus Role Based Access Control Administrator)
- Model quota in your chosen region. Check with `az cognitiveservices model list --location <region>`.

## Deploy

```bash
az login
cp terraform.tfvars.example terraform.tfvars   # set subscription_id at minimum

terraform init
terraform plan -out tfplan
terraform apply tfplan
```

OpenTofu works the same way. Replace `terraform` with `tofu`.

## Prove it

Declaring a control isn't the same as having one. After apply, run:

```bash
./scripts/verify.sh
```

It checks each pillar against the live resources: API keys are disabled, the agent identity holds exactly three roles and none of them is Owner or Contributor, Foundry has no public access, Key Vault rejects outside traffic, the deployment uses the strict filter, and logs are flowing.

## Things that will surprise you

- **The Terraform runner can't read Key Vault secrets.** Public access is off, so data-plane operations from outside the VNet fail. That's the point. Create secrets from inside the network or from a pipeline agent that runs there.
- **The agent isn't reachable from the internet.** With `internal_only = true`, the Container Apps environment uses an internal load balancer. Set it to `false` for a demo, then set it back.
- **A Foundry resource needs three DNS zones, not one.** It answers on `cognitiveservices.azure.com`, `openai.azure.com`, and `services.ai.azure.com`. Skip one and some SDK calls quietly resolve to the public endpoint and fail.
- **Role names changed in 2026.** Azure AI User is now Foundry User. The IDs didn't change, which is why `grant.tf` uses them.
- **Content filter names have spaces.** `Indirect Attack` and `Protected Material Text` are the literal values.

## Swap in your own agent

The default image is a placeholder. Point `container_image` at your agent. It receives these environment variables, and none of them is a secret:

| Variable | Use |
|---|---|
| `AZURE_CLIENT_ID` | Lets `DefaultAzureCredential` pick the user-assigned identity |
| `FOUNDRY_PROJECT_ENDPOINT` | Foundry project endpoint |
| `FOUNDRY_MODEL_DEPLOYMENT` | Model deployment name |
| `KEY_VAULT_URI` | Vault for any third-party API keys your tools need |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Telemetry destination |
| `APPLICATIONINSIGHTS_AUTHENTICATION_STRING` | Tells the SDK to send telemetry with the managed identity |

## Clean up

```bash
terraform destroy
```

Key Vault has purge protection on, so its name stays reserved for 7 days after destroy. The random suffix means a redeploy won't collide.

## License

MIT
