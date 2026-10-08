# A narrowly scoped demo-only Access policy is shared by portal and MCP servers.
# This policy is never sourced from another stack or customer account.
resource "cloudflare_zero_trust_access_policy" "demo_user" {
  count            = local.deploy_ready ? 1 : 0
  account_id       = var.account_id
  name             = "${var.portal_name}: allow demo user"
  decision         = "allow"
  session_duration = var.access_session_duration
  include = [
    for email in local.allowed_user_emails : {
      email = {
        email = email
      }
    }
  ]

  depends_on = [terraform_data.deployment_gate]

  lifecycle {
    prevent_destroy = false
  }
}

resource "cloudflare_zero_trust_access_application" "mcp_server" {
  for_each   = local.deployed_mcp_servers
  account_id = var.account_id
  name       = "${var.portal_name}: ${each.value.name}"
  type       = "mcp"
  destinations = [{
    type          = "via_mcp_server_portal"
    mcp_server_id = each.key
  }]
  policies = [{
    id = cloudflare_zero_trust_access_policy.demo_user[0].id
  }]
  session_duration = var.access_session_duration
  allowed_idps = [
    cloudflare_zero_trust_access_identity_provider.entra[0].id,
    cloudflare_zero_trust_access_identity_provider.one_time_pin[0].id,
  ]
  auto_redirect_to_identity = false

  depends_on = [cloudflare_zero_trust_access_ai_controls_mcp_server.catalog]

  lifecycle {
    prevent_destroy = false
  }
}

resource "cloudflare_zero_trust_access_application" "mcp_portal" {
  count      = local.deploy_ready ? 1 : 0
  account_id = var.account_id
  name       = "${var.portal_name}: portal"
  type       = "mcp_portal"
  domain     = var.portal_hostname
  destinations = [{
    type = "public"
    uri  = var.portal_hostname
  }]
  policies = [{
    id = cloudflare_zero_trust_access_policy.demo_user[0].id
  }]
  session_duration = var.access_session_duration
  allowed_idps = [
    cloudflare_zero_trust_access_identity_provider.entra[0].id,
    cloudflare_zero_trust_access_identity_provider.one_time_pin[0].id,
  ]
  auto_redirect_to_identity  = false
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  options_preflight_bypass   = false

  depends_on = [cloudflare_zero_trust_access_ai_controls_mcp_portal.demo]

  lifecycle {
    prevent_destroy = false
  }
}
