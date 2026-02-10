# alz-mgmt
This repository contains the Azure Landing Zones (ALZ) management configuration for the **VirtuallyBoring** tenant. It uses [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) pattern modules with Bicep to deploy and manage the full ALZ platform, including management group hierarchy, governance policies, logging, and networking.Deployment is automated via GitHub Actions CI/CD pipelines that reference reusable workflow templates from the [alz-mgmt-templates](https://github.com/VirtuallyBoring/alz-mgmt-templates) repository.

## Repository Structure

```
alz-mgmt/
├── .github/
│   └── workflows/
│       ├── ci.yaml                          # CI - runs on PRs (validate & plan)
│       └── cd.yaml                          # CD - runs on push to main (plan & apply)
├── bicepconfig.json                         # Bicep linter and extension configuration
├── parameters.json                          # Global parameters (subscription IDs, locations, etc.)
├── README.md
└── templates/
    ├── core/
    │   ├── alzCoreType.bicep                # Shared type definition for governance modules
    │   ├── governance/
    │   │   ├── lib/
    │   │   │   └── alz/                     # ALZ library - policy/role definition JSON files
    │   │   ├── mgmt-groups/
    │   │   │   ├── int-root/                # Intermediate root management group
    │   │   │   ├── landingzones/            # Landing zones MG + children (corp, online)
    │   │   │   ├── platform/               # Platform MG + children (connectivity, identity, management, security)
    │   │   │   ├── sandbox/                # Sandbox management group
    │   │   │   └── decommissioned/         # Decommissioned management group
    │   │   └── tooling/
    │   │       ├── alz_library_metadata.json        # ALZ library version tracking
    │   │       └── Update-AlzLibraryReferences.ps1  # Script to update policy/role refs in Bicep files
    │   └── logging/
    │       ├── main.bicep                   # Log Analytics, Automation Account, DCRs
    │       └── main.bicepparam              # Logging parameter values
    └── networking/
        ├── hubnetworking/
        │   ├── main.bicep                   # Hub VNets, Firewall, Bastion, VPN/ER Gateways, DNS
        │   └── main.bicepparam              # Hub networking parameter values
        └── virtualwan/
            ├── main.bicep                   # Virtual WAN configuration (alternative to hub networking)
            └── main.bicepparam
```

## Customization Layers

The repo has three customization layers:

1. **Module references** (what gets deployed)
   - Defined in `main.bicep` files
   - References AVM pattern modules from the Bicep public registry (e.g., `br/public:avm/ptn/alz/empty`, `br/public:avm/res/operational-insights/workspace`)
   - You typically don't need to change these unless adding new resources

2. **Parameters** (how it is configured)
   - Defined in `main.bicepparam` files
   - **This is where 90% of your customization happens**
   - Controls resource names, locations, SKUs, policies, RBAC, and networking topology
   - Uses Bicep parameter file syntax (`using './main.bicep'`)

3. **Environment separation** (optional)
   - Multiple `.bicepparam` files per module (e.g., `dev.bicepparam`, `prod.bicepparam`)
   - Enables deploying different configurations to different environments

## Key Configuration Files

### `parameters.json`

Central parameter file containing tenant-level values used across the deployment:

| Parameter | Description |
|-----------|-------------|
| `MANAGEMENT_GROUP_ID` | Tenant root management group ID |
| `INTERMEDIATE_ROOT_MANAGEMENT_GROUP_ID` | ALZ intermediate root MG name |
| `SUBSCRIPTION_ID_MANAGEMENT` | Management subscription |
| `SUBSCRIPTION_ID_CONNECTIVITY` | Connectivity subscription |
| `SUBSCRIPTION_ID_IDENTITY` | Identity subscription |
| `NETWORK_TYPE` | `hubNetworking` or `virtualWan` |
| `LOCATION` / `LOCATION_PRIMARY` / `LOCATION_SECONDARY` | Azure regions |

### `bicepconfig.json`

Configures the Bicep linter rules and extensions. Current rules enforce:
- Use of recent API versions
- Use of recent module versions
- Warnings on unused parameters and variables

### ALZ Library (`templates/core/governance/lib/alz/`)

Contains JSON definitions sourced from the [Azure Landing Zones Library](https://github.com/Azure/Azure-Landing-Zones-Library). These are loaded into the governance `main.bicep` files via `loadJsonContent()` and include:
- **Policy definitions** (`*.alz_policy_definition.json`)
- **Policy set definitions / initiatives** (`*.alz_policy_set_definition.json`)
- **Policy assignments** (`*.alz_policy_assignment.json`)
- **Custom RBAC role definitions** (`*.alz_role_definition.json`)

The library version is tracked in `tooling/alz_library_metadata.json` (currently `2025.09.2`).

## Deployment Pipeline

### CI (`ci.yaml`)

- **Trigger**: Pull requests to `main` and manual dispatch
- **Action**: Validates and plans Bicep deployments (no changes applied)
- **Template**: Reuses `ci-template.yaml` from `VirtuallyBoring/alz-mgmt-templates`

### CD (`cd.yaml`)

- **Trigger**: Push to `main` and manual dispatch
- **Action**: Plans and applies Bicep deployments to Azure
- **Template**: Reuses `cd-template.yaml` from `VirtuallyBoring/alz-mgmt-templates`
- **Granular control**: Each deployment step can be toggled individually via workflow dispatch inputs:
  - Governance (int-root, landing zones, platform, sandbox, decommissioned, RBAC)
  - Core logging
  - Networking

## How to Make Changes

### Updating Parameters

1. Navigate to the relevant `main.bicepparam` file (e.g., `templates/core/logging/main.bicepparam`)
2. Modify parameter values as needed
3. Commit and push to a branch, then open a pull request
4. CI will validate your changes automatically
5. Merge to `main` to trigger the CD pipeline

### Updating the ALZ Policy Library

When a new version of the ALZ library is released:

1. Update the version in `templates/core/governance/tooling/alz_library_metadata.json`
2. Update the JSON files in `templates/core/governance/lib/alz/`
3. Run the update script to refresh Bicep references:

```powershell
cd templates/core/governance/tooling
.\Update-AlzLibraryReferences.ps1        # Apply changes
.\Update-AlzLibraryReferences.ps1 -WhatIf # Preview changes without applying
```

This script scans the ALZ library directory and updates the `loadJsonContent()` arrays in all governance `main.bicep` files, mapping each management group module to its corresponding library directory.

### Adding a New Management Group

1. Create a new directory under `templates/core/governance/mgmt-groups/`
2. Add `main.bicep` and `main.bicepparam` files following the existing pattern
3. The `main.bicep` should import the `alzCoreType` from `alzCoreType.bicep` and reference the `br/public:avm/ptn/alz/empty` module
4. Update the CD workflow to include the new deployment step

### Switching Network Topology

The repo supports two networking models:
- **Hub Networking** (`templates/networking/hubnetworking/`) - Traditional hub-spoke with VNet peering
- **Virtual WAN** (`templates/networking/virtualwan/`) - Azure Virtual WAN based topology

Set `NETWORK_TYPE` in `parameters.json` to either `hubNetworking` or `virtualWan`.

## Prerequisites

- Azure CLI with Bicep installed
- Appropriate Azure RBAC permissions (Owner or equivalent on the target management group hierarchy)
- GitHub repository secrets configured for workload identity federation (OIDC)

## Contributing

Fork the repository and submit a pull request with your changes. The CI pipeline will validate your Bicep templates automatically before merge.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.
