# Hub-and-Spoke Networking

## What Is Hub-and-Spoke?

Imagine you work at a company with 10 offices. Instead of every office running its own internet connection, security team, and firewall, you build one central office ("the hub") that handles all of that, and every other office ("the spokes") connects through it.

That's hub-and-spoke networking in Azure. The **hub VNet** is the central network that contains shared infrastructure — VPN gateways, firewalls, DNS servers. The **spoke VNets** are where your actual workloads (VMs, app services, databases) live. Spokes connect to the hub via VNet peering, which is a fast, low-latency private connection inside Azure's backbone.

The benefits:
- **Centralized security** — one place to inspect and filter all traffic
- **Shared services** — one VPN gateway that all spokes share instead of one per spoke
- **Simpler management** — security rules in one place, not scattered across 20 VNets

---

## What We Deployed

This repo deploys **two hub VNets** — one in `centralus` and one in `westus2`. Having a hub in each region means:

- Workloads in centralus connect to the centralus hub (low latency)
- Workloads in westus2 connect to the westus2 hub (low latency)
- The two hubs are **mesh-peered** to each other, so resources in centralus can talk to resources in westus2 through the hubs without going over the public internet

```
                    ┌─────────────────────────────┐
                    │       Azure Backbone         │
                    │                              │
          ┌─────────┴──────┐          ┌────────────┴──────┐
          │  Hub - centralus│◄────────►│  Hub - westus2    │
          │  VPN Gateway    │  Mesh    │  VPN Gateway      │
          └────────┬────────┘  Peer   └──────────┬────────┘
                   │                              │
          ┌────────┴────────┐          ┌──────────┴────────┐
          │  Spoke VNets    │          │  Spoke VNets       │
          │  (centralus     │          │  (westus2          │
          │   workloads)    │          │   workloads)       │
          └─────────────────┘          └────────────────────┘
```

Each hub currently contains only a **VPN Gateway**. A VPN Gateway lets you connect your on-premises network (your office, data center, or home lab) to Azure over an encrypted tunnel.

---

## What We Changed and Why

### File: `platform-landing-zone.auto.tfvars`

This is the main configuration file for the repo. Think of it like a settings file — it tells Terraform what to build without you having to write the actual building logic yourself.

#### `connectivity_type`

```hcl
# Before
connectivity_type = "none"

# After
connectivity_type = "hub_and_spoke_vnet"
```

This is the master switch. When it was `"none"`, Terraform completely skipped all connectivity resources. Changing it to `"hub_and_spoke_vnet"` tells Terraform to run the hub-and-spoke module. The third option (`"virtual_wan"`) is what we'll switch to later.

#### `hub_and_spoke_networks_settings`

```hcl
hub_and_spoke_networks_settings = {
  enabled_resources = {
    ddos_protection_plan = false
  }
}
```

This controls settings shared across **all** hubs. We disabled the DDoS Protection Plan here because it costs ~$2,944/month. It's a legitimate enterprise control, but for getting started it's overkill. The repo already has a policy that would flag missing DDoS protection — we disabled that policy assignment too (it was done in the `policy_assignments_to_modify` section earlier).

#### `hub_virtual_networks`

This is the main block that defines each hub. It's a **map** — meaning you can have as many hubs as you want by adding more entries. We have two: `hub_primary` and `hub_secondary`.

**Why use `$${starter_location_01}` instead of hardcoding `"centralus"`?**

The `$${...}` tokens are a templating feature built into this repo's config module. When Terraform runs, it replaces `$${starter_location_01}` with the first value from your `starter_locations` variable (`"centralus"`), and `$${starter_location_02}` with the second (`"westus2"`). Using tokens instead of hardcoded values means:

- If you ever change your primary region, you change it in **one place** (`starter_locations`) and everything updates automatically
- Resource names stay consistent — `vnet-hub-cus` (centralus short code) and `vnet-hub-wus2` (westus2 short code) are derived automatically

**`enabled_resources`**

```hcl
enabled_resources = {
  firewall                              = false
  firewall_policy                       = false
  bastion                               = false
  virtual_network_gateway_express_route = false
  virtual_network_gateway_vpn           = true
  private_dns_zones                     = false
  private_dns_resolver                  = false
}
```

The hub-and-spoke module can deploy a lot of things — Azure Firewall, Bastion (secure VM access), ExpressRoute gateways, VPN gateways, private DNS zones. We're only enabling the VPN Gateway right now. Everything else is `false`. This keeps costs minimal and the configuration simple for the initial deployment.

**`hub_virtual_network`**

```hcl
hub_virtual_network = {
  name                 = "vnet-hub-$${starter_location_01_short}"
  address_space        = ["<CENTRALUS_HUB_CIDR>"]
  mesh_peering_enabled = true
}
```

- `address_space` is the IP range for the hub VNet. All subnets inside it must be smaller ranges carved out of this space. You need to fill in your own CIDR here.
- `mesh_peering_enabled = true` tells the module to automatically peer the two hubs together. Without this, the hubs would be isolated islands.

**`virtual_network_gateways`**

```hcl
virtual_network_gateways = {
  subnet_address_prefix = "<CENTRALUS_GATEWAYSUBNET_CIDR>"
  vpn = {
    name                      = "vpngw-hub-$${starter_location_01_short}"
    sku                       = "VpnGw1AZ"
    vpn_active_active_enabled = false
    vpn_bgp_enabled           = false
  }
}
```

- `subnet_address_prefix` — Azure VPN Gateways require a dedicated subnet called `GatewaySubnet`. The module creates this automatically from the CIDR you provide. It must be at least a `/27` (32 IPs).
- `sku = "VpnGw1AZ"` — The `AZ` suffix means zone-redundant. The gateway is spread across Azure Availability Zones so a single datacenter failure doesn't take down your VPN. `VpnGw1` is the entry-level performance tier (~$280/mo per gateway).
- `vpn_active_active_enabled = false` — Active-active means two gateway instances run simultaneously for higher availability and throughput, but doubles the cost. Disabled for now.
- `vpn_bgp_enabled = false` — BGP is a routing protocol used when you need dynamic route exchange with on-premises equipment. Disabled until you have an on-premises device to connect.

### File: `terraform.tfvars.json`

```json
// Removed:
"hub_and_spoke_networks_settings": {},
"hub_virtual_networks": {},
```

These two empty objects were removed because Terraform does not allow the same variable to be set in two different files. Both `platform-landing-zone.auto.tfvars` and `terraform.tfvars.json` are loaded automatically — if both tried to set `hub_virtual_networks`, Terraform would error out with "variable already defined." Since we now set these in `platform-landing-zone.auto.tfvars`, they had to be removed from the JSON file.

---

## Fill In Before Deploying

Before pushing this to GitHub, replace the four CIDR placeholders in `platform-landing-zone.auto.tfvars`:

| Placeholder | What it is | Rules |
|---|---|---|
| `<CENTRALUS_HUB_CIDR>` | centralus hub VNet range | e.g. `10.10.0.0/16` |
| `<CENTRALUS_GATEWAYSUBNET_CIDR>` | centralus GatewaySubnet | Must be /27 or larger, must be inside the hub CIDR |
| `<WESTUS2_HUB_CIDR>` | westus2 hub VNet range | Must not overlap with centralus hub |
| `<WESTUS2_GATEWAYSUBNET_CIDR>` | westus2 GatewaySubnet | Must be /27 or larger, must be inside the westus2 hub CIDR |

Example using 10.10.x and 10.20.x ranges:
```
centralus  hub:          10.10.0.0/16
centralus  GatewaySubnet: 10.10.0.0/27

westus2    hub:          10.20.0.0/16
westus2    GatewaySubnet: 10.20.0.0/27
```

---

## Deployment Expectations

When you merge this to `main`, the CD pipeline runs. Expect it to take **35–50 minutes**. VPN Gateways are one of the slowest Azure resources to provision — Azure is deploying redundant gateway infrastructure across availability zones under the hood.

The pipeline won't appear stuck — it's just Azure being slow. The CD template already accounts for this with a 60-minute retry timeout on the Azure API provider.

After deployment, in the Azure Portal you should see:
- Two new VNets in the connectivity subscription (`vnet-hub-cus` and `vnet-hub-wus2`)
- Two VPN Gateways (`vpngw-hub-cus` and `vpngw-hub-wus2`)
- A VNet peering on each hub pointing to the other

---

## What's Next: Adding Spoke VNets

A hub without spokes doesn't do much yet. Spoke VNets are typically managed **outside this repo** — each workload team creates their own spoke and requests peering to the hub. The hub VNet resource IDs are available as Terraform outputs after deployment:

```
hub_and_spoke_vnet_virtual_network_resource_ids
```

Use those IDs when configuring spoke peering connections.

---

## Future Migration: Hub-and-Spoke → Virtual WAN

When you're ready to migrate to Azure Virtual WAN (VWAN), here's what changes conceptually and in this repo.

### What Is Virtual WAN?

Virtual WAN is Microsoft's managed network backbone. Instead of you building and managing hub VNets, peerings, and gateways, Azure does it for you inside a **Virtual Hub** — a managed router that Microsoft operates. You connect spokes and on-premises sites to it, and Azure handles the routing automatically.

**Hub-and-spoke vs. Virtual WAN:**

| | Hub-and-Spoke | Virtual WAN |
|---|---|---|
| Hub management | You own the hub VNet | Microsoft manages the hub |
| Routing | You configure route tables | Automated by Azure |
| Any-to-any connectivity | Manual peerings needed | Built in |
| Pricing model | Pay per gateway, peering | Pay per vHub + data processed |
| Best for | Familiar model, full control | Scale, simplicity, automated routing |

### How to Migrate in This Repo

The migration is a configuration change, not a code rewrite. The repo already has full Virtual WAN support built in — it's just switched off.

**Step 1: Update `platform-landing-zone.auto.tfvars`**

Change the connectivity type:
```hcl
connectivity_type = "virtual_wan"
```

Remove the `hub_and_spoke_networks_settings` and `hub_virtual_networks` blocks entirely.

Add `virtual_wan_settings` and `virtual_hubs` blocks instead:
```hcl
virtual_wan_settings = {
  # Global VWAN settings (name, resource group, etc.)
}

virtual_hubs = {
  hub_primary = {
    location       = "$${starter_location_01}"
    address_prefix = "<VHUB_CENTRALUS_CIDR>"   # /23 minimum, e.g. "10.100.0.0/23"
    # VPN, ExpressRoute, firewall configuration goes here
  }
  hub_secondary = {
    location       = "$${starter_location_02}"
    address_prefix = "<VHUB_WESTUS2_CIDR>"
  }
}
```

**Step 2: Update `terraform.tfvars.json`**

Move the empty placeholders back — remove `hub_virtual_networks` and `hub_and_spoke_networks_settings` (already done), and the `virtual_hubs` and `virtual_wan_settings` keys are already present as empty objects ready to be populated.

**Step 3: Handle spoke VNet reconnection**

Spokes that were peered to the old hub VNets need to be re-peered to the Virtual Hub. Azure VWAN uses a different peering mechanism (managed by the VWAN service) so existing spoke peerings will need to be updated. Plan for a maintenance window.

**Step 4: Decommission old hub VNets**

Once all spokes are reconnected and traffic is flowing through the Virtual Hubs, remove the old hub VNet configuration. Terraform will destroy the old hub VNets, VPN gateways, and peerings when you apply.

### Key Differences to Watch For

- **Address space:** Virtual Hub address prefixes must be a `/23` or larger (VWAN reserves IPs internally)
- **Routing:** VWAN manages routing automatically — custom route tables work differently than in hub-and-spoke
- **Spoke peering cost:** VWAN charges for data processed through the hub; hub-and-spoke charges for peering bandwidth. At scale, VWAN is often cheaper; at small scale it can be more expensive
- **DNS:** If you add private DNS zones later, the resolver configuration changes between hub-and-spoke and VWAN

### The Variables File for VWAN

The full VWAN variable schema is in [variables.connectivity.virtual.wan.tf](variables.connectivity.virtual.wan.tf) — it mirrors the hub-and-spoke variable file in structure, so if you understand the hub-and-spoke config above, VWAN will feel familiar.
