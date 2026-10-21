resource "cloudflare_workers_script" "corporate_ai_chat" {
  count = local.deploy_ready && var.corporate_ai_chat_hostname != "" ? 1 : 0

  account_id         = var.account_id
  script_name        = "terraform-corporate-ai-chat"
  content            = file("${path.module}/worker/corporate-ai-chat.js")
  main_module        = "corporate-ai-chat.js"
  compatibility_date = "2026-10-21"
  compatibility_flags = [
    "nodejs_compat",
  ]

  migrations = {
    old_tag = "v1"
    new_tag = "v2"
  }

  bindings = [
    {
      name = "AI_GATEWAY_URL"
      type = "plain_text"
      text = "https://gateway.ai.cloudflare.com/v1/${var.account_id}/${var.ai_gateway_id}/workers-ai/v1/chat/completions"
    },
    {
      name = "WORKERS_AI_MODEL"
      type = "plain_text"
      text = var.workers_ai_model
    },
    {
      name = "MODEL_REQUESTS_PER_MINUTE"
      type = "plain_text"
      text = "20"
    },
    {
      name       = "GLOBAL_RATE_LIMITER"
      type       = "durable_object_namespace"
      class_name = "GlobalRateLimiter"
    },
    {
      name        = "CLOUDFLARE_API_TOKEN"
      type        = "secret_text"
      secret_name = "CLOUDFLARE_API_TOKEN"
      text        = var.cloudflare_api_token
    },
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

  depends_on = [
    terraform_data.deployment_gate,
    cloudflare_ai_gateway.demo,
  ]

  # Cloudflare fills these read-only/normalized fields after upload. Keep source,
  # runtime settings, bindings, and migrations managed while ignoring metadata.
  lifecycle {
    ignore_changes = [
      annotations,
      bindings[3].namespace_id,
      bindings[4].secret_name,
      observability.traces,
      placement,
      tail_consumers,
    ]
  }

}

resource "cloudflare_workers_custom_domain" "corporate_ai_chat" {
  count = local.deploy_ready && var.corporate_ai_chat_hostname != "" ? 1 : 0

  account_id = var.account_id
  hostname   = var.corporate_ai_chat_hostname
  service    = cloudflare_workers_script.corporate_ai_chat[0].script_name
  zone_id    = var.zone_id
}

resource "cloudflare_workers_script_subdomain" "corporate_ai_chat" {
  count = local.deploy_ready && var.corporate_ai_chat_hostname != "" ? 1 : 0

  account_id       = var.account_id
  script_name      = cloudflare_workers_script.corporate_ai_chat[0].script_name
  enabled          = false
  previews_enabled = false
}

resource "cloudflare_zero_trust_access_application" "corporate_ai_chat" {
  count = local.deploy_ready && var.corporate_ai_chat_hostname != "" ? 1 : 0

  account_id = var.account_id
  name       = "Corporate AI Chat"
  type       = "self_hosted"
  domain     = var.corporate_ai_chat_hostname
  destinations = [{
    type = "public"
    uri  = var.corporate_ai_chat_hostname
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

  depends_on = [cloudflare_workers_custom_domain.corporate_ai_chat]
}
