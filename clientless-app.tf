resource "cloudflare_workers_script" "clientless_demo" {
  count = local.deploy_ready ? 1 : 0

  account_id         = var.account_id
  script_name        = "terraform-clientless-access-demo"
  content            = file("${path.module}/worker/clientless-demo.js")
  main_module        = "clientless-demo.js"
  compatibility_date = "2026-10-06"
  compatibility_flags = [
    "nodejs_compat",
  ]

  observability = {
    enabled            = true
    head_sampling_rate = 1
    logs = {
      enabled            = true
      head_sampling_rate = 1
      invocation_logs    = true
    }
  }

  depends_on = [terraform_data.deployment_gate]

  # The Workers API normalizes these optional fields on every read. Ignore
  # only that server metadata; script content and runtime settings stay managed.
  lifecycle {
    ignore_changes = [
      annotations,
      bindings,
      observability.traces,
      placement,
      tail_consumers,
    ]
  }
}

resource "cloudflare_workers_custom_domain" "clientless_demo" {
  count = local.deploy_ready ? 1 : 0

  account_id = var.account_id
  hostname   = var.clientless_app_hostname
  service    = cloudflare_workers_script.clientless_demo[0].script_name
  zone_id    = var.zone_id
}

resource "cloudflare_zero_trust_access_application" "clientless_demo" {
  count = local.deploy_ready ? 1 : 0

  account_id = var.account_id
  name       = "Terraform Demo: Clientless Web App"
  type       = "self_hosted"
  domain     = var.clientless_app_hostname
  destinations = [{
    type = "public"
    uri  = var.clientless_app_hostname
  }]

  app_launcher_visible      = true
  auto_redirect_to_identity = false
  allowed_idps = [
    cloudflare_zero_trust_access_identity_provider.entra[0].id,
    cloudflare_zero_trust_access_identity_provider.one_time_pin[0].id,
  ]
  policies = [{
    id = cloudflare_zero_trust_access_policy.demo_user[0].id
  }]
  session_duration = var.access_session_duration

  depends_on = [cloudflare_workers_custom_domain.clientless_demo]

  lifecycle {
    prevent_destroy = false
  }
}
