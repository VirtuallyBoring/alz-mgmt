# Federated Identity Credential Case-Sensitivity Bug

## Background

The ALZ Accelerator provisions user-assigned managed identities for GitHub Actions OIDC authentication. During setup, federated identity credentials are created on these identities with a `subject` claim that Azure AD matches against the assertion presented by GitHub Actions at runtime.

In August 2024, Microsoft began enforcing **case-sensitive** matching of federated identity credential subjects (previously case-insensitive). Around the same time (or possibly always, but masked by the case-insensitive matching), GitHub Actions began sending the org/repo name in its **actual casing** (e.g. `VirtuallyBoring`) in the `repo:` portion of the OIDC subject claim, rather than normalizing it to lowercase.

## The Problem

The ALZ Accelerator creates federated identity credential subjects using an **all-lowercase** org name in the `repo:` segment, e.g.:

```
repo:virtuallyboring/alz-mgmt:environment:alz-mgmt-plan:job_workflow_ref:virtuallyboring/alz-mgmt-templates/.github/workflows/ci-template.yaml@refs/heads/main
```

GitHub Actions now presents the assertion with the **actual casing** of the GitHub organization name:

```
repo:VirtuallyBoring/alz-mgmt:environment:alz-mgmt-plan:job_workflow_ref:virtuallyboring/alz-mgmt-templates/.github/workflows/ci-template.yaml@refs/heads/main
```

Note: the `job_workflow_ref` segment (the reusable workflow template repo) remains lowercase — only the `repo:` segment (the calling repo) uses actual casing.

Azure AD's case-sensitive matching then fails with:

```
AADSTS7002138: No matching federated identity record found for presented assertion subject
'repo:VirtuallyBoring/alz-mgmt:environment:alz-mgmt-plan:...'.
The subject matches with case-insensitive comparison, but not with case-sensitive comparison.
```

## Affected Resources

Three federated identity credentials were created by the ALZ Accelerator, all with the same lowercase `repo:` casing bug:

| Managed Identity | Credential Name | Environment |
|---|---|---|
| `id-alz-mgmt-centralus-plan-001` | `alz-mgmt-centralus-001-ci-plan` | `alz-mgmt-plan` |
| `id-alz-mgmt-centralus-plan-001` | `alz-mgmt-centralus-001-cd-plan` | `alz-mgmt-plan` |
| `id-alz-mgmt-centralus-apply-001` | `alz-mgmt-centralus-001-cd-apply` | `alz-mgmt-apply` |

## The Fix

Update each federated credential's `subject` to use the correctly-cased GitHub organization name in the `repo:` segment.

### Critical: Use delete + recreate, not update

`az identity federated-credential update` writes to the ARM layer but **does not propagate to Azure AD (Entra ID)**. Azure AD is what actually validates OIDC tokens at runtime, and it reads from its own datastore (queryable via Microsoft Graph), not directly from ARM.

The symptom of this ARM/Graph sync failure: the `az identity federated-credential list` command shows the correct updated subject, but the GitHub Action continues to fail with the same error. Querying Graph directly reveals the old credential is still there:

```bash
# Query what Azure AD actually sees (not ARM)
az rest \
  --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/<service-principal-object-id>/federatedIdentityCredentials" \
  --query "value[].{name:name, subject:subject}"
```

The only reliable fix is to **delete the credential and recreate it**. This forces a clean write that properly propagates to Azure AD.

### Commands Applied

```bash
# CI plan credential — delete and recreate
az identity federated-credential delete \
  --identity-name id-alz-mgmt-centralus-plan-001 \
  --resource-group rg-alz-mgmt-identity-centralus-001 \
  --name alz-mgmt-centralus-001-ci-plan --yes

az identity federated-credential create \
  --identity-name id-alz-mgmt-centralus-plan-001 \
  --resource-group rg-alz-mgmt-identity-centralus-001 \
  --name alz-mgmt-centralus-001-ci-plan \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:VirtuallyBoring/alz-mgmt:environment:alz-mgmt-plan:job_workflow_ref:virtuallyboring/alz-mgmt-templates/.github/workflows/ci-template.yaml@refs/heads/main" \
  --audiences "api://AzureADTokenExchange"

# CD plan credential — delete and recreate
az identity federated-credential delete \
  --identity-name id-alz-mgmt-centralus-plan-001 \
  --resource-group rg-alz-mgmt-identity-centralus-001 \
  --name alz-mgmt-centralus-001-cd-plan --yes

az identity federated-credential create \
  --identity-name id-alz-mgmt-centralus-plan-001 \
  --resource-group rg-alz-mgmt-identity-centralus-001 \
  --name alz-mgmt-centralus-001-cd-plan \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:VirtuallyBoring/alz-mgmt:environment:alz-mgmt-plan:job_workflow_ref:virtuallyboring/alz-mgmt-templates/.github/workflows/cd-template.yaml@refs/heads/main" \
  --audiences "api://AzureADTokenExchange"

# CD apply credential — delete and recreate
az identity federated-credential delete \
  --identity-name id-alz-mgmt-centralus-apply-001 \
  --resource-group rg-alz-mgmt-identity-centralus-001 \
  --name alz-mgmt-centralus-001-cd-apply --yes

az identity federated-credential create \
  --identity-name id-alz-mgmt-centralus-apply-001 \
  --resource-group rg-alz-mgmt-identity-centralus-001 \
  --name alz-mgmt-centralus-001-cd-apply \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:VirtuallyBoring/alz-mgmt:environment:alz-mgmt-apply:job_workflow_ref:virtuallyboring/alz-mgmt-templates/.github/workflows/cd-template.yaml@refs/heads/main" \
  --audiences "api://AzureADTokenExchange"
```

### Verifying the fix via Graph

After recreating, wait ~15 seconds then confirm Azure AD has the correct values before retrying the GitHub Action:

```bash
az rest \
  --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/<service-principal-object-id>/federatedIdentityCredentials" \
  --query "value[].{name:name, subject:subject}"
```

Both credentials should show `repo:VirtuallyBoring/alz-mgmt` (correct casing) before triggering a fresh workflow run. Do **not** use "Rerun failed jobs" — always trigger a new workflow dispatch, as reruns may reuse cached token exchange state.

## What to Look for in the ALZ Accelerator Scripts

Search the accelerator codebase for where federated identity credential subjects are constructed. The bug is that the `repo:` segment is being generated with a lowercased org/repo name instead of preserving the original casing supplied by the user.

Look for patterns like:

- `.ToLower()`, `.toLower()`, `.lower()`, or similar case-normalization applied to the GitHub org or repo name before building the subject string
- String interpolation that constructs the OIDC subject claim (e.g. `"repo:${org}/${repo}:environment:..."`)
- Any use of the GitHub API to resolve the org/repo name where the response is lowercased before use

### Subject String Format for Reference

The correct format, preserving exact casing from the GitHub org/repo name input:

```
repo:<GitHubOrg>/<CallerRepo>:environment:<EnvironmentName>:job_workflow_ref:<TemplateOrg>/<TemplateRepo>/.github/workflows/<workflow-file>.yaml@refs/heads/main
```

- `<GitHubOrg>/<CallerRepo>` — must match the **exact casing** of the GitHub organization and repository name
- `<TemplateOrg>/<TemplateRepo>` — GitHub appears to send this in **lowercase** regardless; the credential should match that

## References

- [Microsoft breaking change notice (August 2024)](https://learn.microsoft.com/en-us/entra/identity-platform/reference-breaking-changes#august-2024)
- [Workload identity federation documentation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)

---

# Terraform State Storage Account — Public Network Access Disabled

## The Problem

Once the federated identity credential issue was resolved, the GitHub Actions CI job failed with a new error:

```
Error: Failed to get existing workspaces: listing blobs: executing request:
unexpected status 403 (403 This request is not authorized to perform this operation.)
with AuthorizationFailure: This request is not authorized to perform this operation.
```

The Terraform state storage account (`stoalzmgmcen001sjpo`) was deployed by the ALZ Accelerator with `publicNetworkAccess: Disabled`. GitHub Actions hosted runners run on the public internet and cannot reach the storage account at all — not even with correct RBAC permissions.

Storage account configuration at time of discovery:

```json
{
  "publicNetworkAccess": "Disabled",
  "defaultAction": "Allow",
  "bypass": "AzureServices",
  "ipRules": [],
  "virtualNetworkRules": []
}
```

`bypass: AzureServices` only covers first-party Microsoft services (e.g. Azure Monitor, Azure Backup). It does not cover GitHub Actions runners.

## Why This Is Confusing

The ALZ Accelerator wizard allows you to configure GitHub Actions as your CI/CD platform, which it provisions with GitHub-hosted runners by default. At the same time, it deploys the Terraform state storage account with public network access disabled. These two choices are contradictory — GitHub-hosted runners cannot reach a storage account with no public endpoint.

This suggests one of the following is true in the accelerator scripts:

1. The storage account should be deployed with public access enabled when GitHub-hosted runners are selected, and the accelerator has a bug where it always sets `publicNetworkAccess: Disabled` regardless
2. The accelerator is intended to be used with self-hosted runners inside the Azure VNet, and the wizard does not make this requirement clear
3. There is a post-deployment step to configure network access or a private endpoint that was not surfaced during setup

## What to Look for in the ALZ Accelerator Scripts

- Where the Terraform state storage account is provisioned — check whether `publicNetworkAccess` is hardcoded to `Disabled` or whether it is conditional on the runner type selected
- Whether there is a runner type input (GitHub-hosted vs self-hosted) that should influence the storage account network configuration
- Whether the accelerator is supposed to provision a private endpoint for the storage account and wire it to the VNet where self-hosted runners would live
- Whether there is documentation or a post-deployment checklist that mentions network access requirements for the state backend

## Options to Resolve

**Option A — Enable public network access** (quick, less secure): Set `publicNetworkAccess` to `Enabled` on the storage account. Optionally scope access to [GitHub's published IP ranges](https://api.github.com/meta) (field `actions`), though these change frequently.

```bash
az storage account update \
  --name stoalzmgmcen001sjpo \
  --resource-group rg-alz-mgmt-state-centralus-001 \
  --public-network-access Enabled
```

**Option B — Self-hosted runners inside the VNet** (correct long-term architecture): Deploy a self-hosted GitHub Actions runner inside the Azure VNet that has private connectivity to the storage account. This aligns with the private storage account configuration the accelerator deploys.
