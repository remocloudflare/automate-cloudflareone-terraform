resource "cloudflare_zero_trust_access_policy" "clientless_rbi" {
  count = local.deploy_ready && var.rbi_bookmark_url != "" ? 1 : 0

  account_id       = var.account_id
  name             = "Clientless Browser Isolation Policy"
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
}

resource "cloudflare_zero_trust_access_application" "clientless_rbi" {
  count = local.deploy_ready && var.rbi_bookmark_url != "" ? 1 : 0

  account_id = var.account_id
  name       = "Clientless Web Isolation"
  type       = "biso"
  domain     = "${var.access_team_name}.cloudflareaccess.com/browser"

  allowed_idps = [
    cloudflare_zero_trust_access_identity_provider.entra[0].id,
    cloudflare_zero_trust_access_identity_provider.one_time_pin[0].id,
  ]
  auto_redirect_to_identity = false
  policies = [{
    id = cloudflare_zero_trust_access_policy.clientless_rbi[0].id
  }]

  lifecycle {
    ignore_changes = [session_duration]

    precondition {
      condition     = var.access_team_name != ""
      error_message = "access_team_name must be set when rbi_bookmark_url enables Clientless Browser Isolation."
    }
  }
}

resource "cloudflare_zero_trust_access_application" "rbi_bookmark" {
  count = local.deploy_ready && var.rbi_bookmark_url != "" ? 1 : 0

  account_id = var.account_id
  name       = var.rbi_bookmark_name
  type       = "bookmark"
  domain     = var.rbi_bookmark_url

  app_launcher_visible = true
  policies = [{
    id = cloudflare_zero_trust_access_policy.clientless_rbi[0].id
  }]

  lifecycle {
    prevent_destroy = false
  }
}