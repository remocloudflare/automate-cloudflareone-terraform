locals {
  blocked_ip_lines = split("\n", file("${path.module}/files/blocked-ips.txt"))
  blocked_ips = sort(distinct([
    for line in local.blocked_ip_lines : trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ]))
}

check "blocked_ip_entries" {
  assert {
    condition = length(local.blocked_ips) > 0 && alltrue([
      for ip in local.blocked_ips :
      can(cidrhost(ip, 0)) || (
        !strcontains(ip, "/") && (
          can(cidrhost("${ip}/32", 0)) ||
          can(cidrhost("${ip}/128", 0))
        )
      )
    ])
    error_message = "files/blocked-ips.txt must contain at least one valid IPv4/IPv6 address or CIDR per line."
  }
}

resource "cloudflare_zero_trust_list" "blocked_ips" {
  count = local.deploy_ready ? 1 : 0

  account_id  = var.account_id
  name        = "terraform_demo_blocked_ips"
  description = "Terraform-managed reusable destination IP block list for the Cloudflare One demo."
  type        = "IP"

  items = [
    for ip in local.blocked_ips : {
      value       = ip
      description = "Blocked by Terraform demo policy"
    }
  ]

  depends_on = [terraform_data.deployment_gate]

  lifecycle {
    prevent_destroy = false
  }
}

resource "cloudflare_zero_trust_gateway_policy" "block_ips_network" {
  count = local.deploy_ready ? 1 : 0

  account_id  = var.account_id
  name        = "Terraform Demo: Block listed destination IPs (Network)"
  description = "Blocks network traffic to destination IPs in the Terraform-managed reusable list."
  precedence  = local.gateway_rule_priorities.network_ip
  enabled     = true
  action      = "block"
  filters     = ["l4"]
  traffic = format(
    "net.dst.ip in $%s",
    cloudflare_zero_trust_list.blocked_ips[0].id
  )

  rule_settings = {
    block_reason = "This destination IP is blocked by the Terraform demo Network policy."
  }

  depends_on = [cloudflare_zero_trust_list.blocked_ips]

  lifecycle {
    prevent_destroy = false
  }
}
