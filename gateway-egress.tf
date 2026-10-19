locals {
  egress_email_lines = split("\n", file("${path.module}/files/egress-emails.txt"))
  egress_emails = sort(distinct([
    for line in local.egress_email_lines : lower(trimspace(line))
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ]))
}

check "egress_email_entries" {
  assert {
    condition = (
      length(local.egress_emails) > 0 &&
      alltrue([
        for email in local.egress_emails :
        can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))
      ])
    )
    error_message = "files/egress-emails.txt must contain at least one valid email address, one per line."
  }
}

resource "cloudflare_zero_trust_list" "egress_emails" {
  count = local.deploy_ready ? 1 : 0

  account_id  = var.account_id
  name        = "terraform_demo_egress_emails"
  description = "Terraform-managed reusable email list for the default Cloudflare egress policy."
  type        = "EMAIL"

  items = [
    for email in local.egress_emails : {
      value       = email
      description = "Uses Cloudflare default egress"
    }
  ]

  depends_on = [terraform_data.deployment_gate]

  lifecycle {
    prevent_destroy = false
  }
}

resource "cloudflare_zero_trust_gateway_policy" "email_default_egress" {
  count = local.deploy_ready ? 1 : 0

  account_id  = var.account_id
  name        = "Terraform Demo: Email list default Cloudflare egress"
  description = "Routes listed Gateway identities through Cloudflare's shared default egress range."
  precedence  = local.gateway_rule_priorities.egress
  enabled     = true
  action      = "egress"
  filters     = ["egress"]
  traffic     = "net.protocol in {\"tcp\" \"udp\"}"
  identity = format(
    "identity.email in $%s",
    cloudflare_zero_trust_list.egress_emails[0].id
  )

  depends_on = [cloudflare_zero_trust_list.egress_emails]

  lifecycle {
    prevent_destroy = false
  }
}
