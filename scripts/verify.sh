#!/usr/bin/env bash
# Prove the AGENT controls are actually in place, not just declared.
# Run after `terraform apply` from a machine signed in with `az login`.
set -euo pipefail

# Git Bash on Windows rewrites arguments that start with "/" into Windows paths,
# which mangles Azure resource IDs. Turn that off.
export MSYS_NO_PATHCONV=1

RG=$(terraform output -raw resource_group_name)
FOUNDRY=$(terraform output -raw foundry_account_name)

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
FAILED=0

echo "Authenticate"
local_auth=$(az cognitiveservices account show -g "$RG" -n "$FOUNDRY" --query "properties.disableLocalAuth" -o tsv)
[[ "$local_auth" == "true" ]] && pass "Foundry API keys are disabled" || fail "Foundry still accepts API keys"

echo "Grant"
id_principal=$(az identity list -g "$RG" --query "[0].principalId" -o tsv)
count=$(az role assignment list --assignee "$id_principal" --all --query "length(@)" -o tsv)
[[ "$count" -eq 3 ]] && pass "Agent identity holds exactly 3 role assignments" || fail "Agent identity holds $count role assignments (expected 3)"
owner=$(az role assignment list --assignee "$id_principal" --all --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='Contributor'] | length(@)" -o tsv)
[[ "$owner" -eq 0 ]] && pass "No Owner or Contributor on the agent identity" || fail "Agent identity has broad control-plane roles"

echo "Encrypt"
pna=$(az cognitiveservices account show -g "$RG" -n "$FOUNDRY" --query "properties.publicNetworkAccess" -o tsv)
[[ "$pna" == "Disabled" ]] && pass "Foundry public network access is disabled" || fail "Foundry is publicly reachable"
KV_NAME=$(az keyvault list -g "$RG" --query "[0].name" -o tsv)
kv_pna=$(az keyvault show -n "$KV_NAME" --query "properties.publicNetworkAccess" -o tsv)
[[ "$kv_pna" == "Disabled" ]] && pass "Key Vault public network access is disabled" || fail "Key Vault public network access is '$kv_pna'"

# An anonymous request gets 401 before network rules are checked, which proves nothing.
# Make an authenticated data-plane call instead. From outside the VNet it must be
# rejected by the network layer (ForbiddenByConnection), not by RBAC.
if kv_out=$(az keyvault secret list --vault-name "$KV_NAME" -o none 2>&1); then
  fail "Key Vault answered an authenticated data-plane call from outside the VNet"
elif grep -qiE "ForbiddenByConnection|public network access is disabled" <<<"$kv_out"; then
  pass "Key Vault blocks data-plane calls from outside the VNet"
else
  fail "Key Vault rejected the call for another reason: $(head -c 200 <<<"$kv_out")"
fi

echo "Neutralize"
policy=$(az cognitiveservices account deployment list -g "$RG" -n "$FOUNDRY" --query "[0].properties.raiPolicyName" -o tsv)
[[ "$policy" == "agent-strict" ]] && pass "Model deployment uses the agent-strict content filter" || fail "Model deployment uses '$policy'"

echo "Trace"
diag=$(az monitor diagnostic-settings list -g "$RG" --resource "$FOUNDRY" --resource-type "Microsoft.CognitiveServices/accounts" --query "length(@)" -o tsv)
[[ "$diag" -ge 1 ]] && pass "Foundry logs are routed to Log Analytics" || fail "Foundry has no diagnostic setting"

exit $FAILED