# The catalog is keyed by immutable server ID; never use list indices as state addresses.
resource "cloudflare_zero_trust_access_ai_controls_mcp_server" "catalog" {
  for_each   = local.deployed_mcp_servers
  account_id = var.account_id
  id         = each.key
  name       = each.value.name
  hostname   = each.value.url
  auth_type  = each.value.auth_type

  depends_on = [terraform_data.deployment_gate]

  lifecycle {
    prevent_destroy = false
  }
}

resource "cloudflare_zero_trust_access_ai_controls_mcp_portal" "demo" {
  count      = local.deploy_ready ? 1 : 0
  account_id = var.account_id
  id         = var.portal_id
  name       = var.portal_name
  hostname   = var.portal_hostname

  # The API replaces the whole mapping. Keep every enabled server listed,
  # with deterministic membership and explicit mapping defaults.
  servers = [
    for id in sort(keys(local.deployed_mcp_servers)) : {
      server_id        = cloudflare_zero_trust_access_ai_controls_mcp_server.catalog[id].id
      default_disabled = false
      on_behalf        = false
    }
  ]

  lifecycle {
    prevent_destroy = false
  }
}

resource "cloudflare_dns_record" "mcp_portal" {
  count   = local.deploy_ready ? 1 : 0
  zone_id = var.zone_id
  name    = var.portal_hostname
  type    = "CNAME"
  content = "gateway.agents.cloudflare.com"
  proxied = true
  ttl     = 1
  comment = "${var.portal_name} portal"

  depends_on = [terraform_data.deployment_gate]

  lifecycle {
    prevent_destroy = false
  }
}
