locals {
  corporate_ai_chat_script_name        = "terraform-corporate-ai-chat"
  corporate_ai_chat_compatibility_date = "2026-10-21"
}

# The Workers API rejects re-sending a bootstrap Durable Object migration once the script is at
# that tag (10079) and rejects the class without it on a fresh script. Applying the one-time
# migration here (idempotent script) keeps cloudflare_workers_script free of migrations, so its
# config never changes between runs and plan is empty after every apply.
# Re-runs whenever the Worker would be replaced (account or name change) or on full destroy/apply.
# If the Worker is deleted out of band, run: terraform apply -replace='terraform_data.corporate_ai_chat_do_migration[0]'
resource "terraform_data" "corporate_ai_chat_do_migration" {
  count = local.deploy_ready && var.corporate_ai_chat_hostname != "" ? 1 : 0

  triggers_replace = [var.account_id, local.corporate_ai_chat_script_name, "GlobalRateLimiter", "v1"]

  provisioner "local-exec" {
    command = "sh ${path.module}/scripts/bootstrap-do-migration.sh"
    environment = {
      CF_TOKEN           = var.cloudflare_api_token
      ACCOUNT_ID         = var.account_id
      SCRIPT_NAME        = local.corporate_ai_chat_script_name
      CLASS_NAME         = "GlobalRateLimiter"
      MIGRATION_TAG      = "v1"
      COMPATIBILITY_DATE = local.corporate_ai_chat_compatibility_date
    }
  }

  depends_on = [terraform_data.deployment_gate]
}

resource "cloudflare_workers_script" "corporate_ai_chat" {
  count = local.deploy_ready && var.corporate_ai_chat_hostname != "" ? 1 : 0

  account_id         = var.account_id
  script_name        = local.corporate_ai_chat_script_name
  content            = file("${path.module}/worker/corporate-ai-chat.js")
  main_module        = "corporate-ai-chat.js"
  compatibility_date = local.corporate_ai_chat_compatibility_date
  compatibility_flags = [
    "nodejs_compat",
  ]

  # Durable Object migration v1 (new_sqlite_classes = GlobalRateLimiter) is applied by
  # terraform_data.corporate_ai_chat_do_migration; never send migrations from here.

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
    {
      # Sent as cf-aig-authorization on every upstream call. Verified against a
      # live gateway with authentication = true: a valid Cloudflare API token
      # satisfies the gateway (a bogus one returns 401 AiGatewayError 2009), so
      # this defaults to cloudflare_api_token. Set ai_gateway_token only if you
      # mint a dedicated gateway token and want to use that instead.
      name        = "AI_GATEWAY_TOKEN"
      type        = "secret_text"
      secret_name = "AI_GATEWAY_TOKEN"
      text        = var.ai_gateway_token != "" ? var.ai_gateway_token : var.cloudflare_api_token
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
    terraform_data.corporate_ai_chat_do_migration,
    cloudflare_ai_gateway.demo,
  ]

  # Cloudflare fills these read-only/normalized fields after upload. Keep source,
  # runtime settings, bindings, and migrations managed while ignoring metadata.
  # NOTE: these are POSITIONAL indexes into bindings[] -- adding or reordering a
  # binding shifts them and reintroduces permanent plan drift. Current order:
  # 0 AI_GATEWAY_URL, 1 WORKERS_AI_MODEL, 2 MODEL_REQUESTS_PER_MINUTE,
  # 3 GLOBAL_RATE_LIMITER, 4 CLOUDFLARE_API_TOKEN, 5 AI_GATEWAY_TOKEN.
  lifecycle {
    ignore_changes = [
      annotations,
      bindings[3].namespace_id,
      bindings[4].secret_name,
      bindings[5].secret_name,
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
