resource "cloudflare_zero_trust_access_application" "app_launcher" {
  count = local.deploy_ready ? 1 : 0

  account_id = var.account_id
  name       = "App Launcher"
  type       = "app_launcher"

  # Declare the API default so its readback is stable across plans.
  landing_page_design = {
    title = "Welcome!"
  }

  allowed_idps = [
    cloudflare_zero_trust_access_identity_provider.entra[0].id,
    cloudflare_zero_trust_access_identity_provider.one_time_pin[0].id,
  ]
  auto_redirect_to_identity = false
  policies = [{
    id = cloudflare_zero_trust_access_policy.demo_user[0].id
  }]
  session_duration = var.access_session_duration

  depends_on = [cloudflare_zero_trust_access_application.clientless_demo]

  lifecycle {
    prevent_destroy = false
  }
}
