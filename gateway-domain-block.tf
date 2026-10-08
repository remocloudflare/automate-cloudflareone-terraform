locals {
  blocked_domain_lines = split("\n", file("${path.module}/files/blocked-domains.txt"))
  blocked_domains = sort(distinct([
    for line in local.blocked_domain_lines : lower(trimspace(line))
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ]))
}

check "blocked_domain_entries" {
  assert {
    condition = length(local.blocked_domains) > 0 && alltrue([
      for domain in local.blocked_domains :
      can(regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$", domain))
    ])
    error_message = "files/blocked-domains.txt must contain at least one bare domain per line; schemes, paths, ports, and wildcards are not allowed."
  }
}

resource "cloudflare_zero_trust_list" "blocked_domains" {
  count = local.deploy_ready ? 1 : 0

  account_id  = var.account_id
  name        = "terraform_demo_blocked_domains"
  description = "Terraform-managed reusable domain block list for the Cloudflare One demo."
  type        = "DOMAIN"

  items = [
    for domain in local.blocked_domains : {
      value       = domain
      description = "Blocked by Terraform demo policy"
    }
  ]

  depends_on = [terraform_data.deployment_gate]

  lifecycle {
    prevent_destroy = false
  }
}

resource "cloudflare_zero_trust_gateway_policy" "block_domains_dns" {
  count = local.deploy_ready ? 1 : 0

  account_id  = var.account_id
  name        = "Terraform Demo: Block listed domains (DNS)"
  description = "Blocks DNS queries for domains in the Terraform-managed reusable list."
  precedence  = 1000
  enabled     = true
  action      = "block"
  filters     = ["dns"]
  traffic = format(
    "any(dns.domains[*] in $%s)",
    cloudflare_zero_trust_list.blocked_domains[0].id
  )

  rule_settings = {
    block_page_enabled = true
    block_reason       = "This domain is blocked by the Terraform demo DNS policy."
  }

  depends_on = [cloudflare_zero_trust_list.blocked_domains]

  lifecycle {
    prevent_destroy = false
  }
}

resource "cloudflare_zero_trust_gateway_policy" "block_domains_http" {
  count = local.deploy_ready ? 1 : 0

  account_id  = var.account_id
  name        = "Terraform Demo: Block listed domains (HTTP)"
  description = "Blocks HTTP requests for domains in the Terraform-managed reusable list."
  precedence  = 2000
  enabled     = true
  action      = "block"
  filters     = ["http"]
  traffic = format(
    "any(http.request.domains[*] in $%s)",
    cloudflare_zero_trust_list.blocked_domains[0].id
  )

  rule_settings = {
    block_reason = "This domain is blocked by the Terraform demo HTTP policy."
  }

  depends_on = [cloudflare_zero_trust_list.blocked_domains]

  lifecycle {
    prevent_destroy = false
  }
}
