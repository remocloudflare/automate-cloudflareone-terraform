resource "cloudflare_ai_gateway" "demo" {
  count = local.deploy_ready ? 1 : 0

  account_id = var.account_id
  id         = var.ai_gateway_id

  collect_logs               = true
  cache_ttl                  = 0
  cache_invalidate_on_update = false
  rate_limiting_interval     = 0
  rate_limiting_limit        = 0
  authentication             = false
  log_classification         = false
  log_management             = 10000000
  log_management_strategy    = "DELETE_OLDEST"
  logpush                    = false
  zdr                        = false

  retry_max_attempts = 2
  retry_delay        = 250
  retry_backoff      = "exponential"

  # Block sensitive identifiers in prompts with Cloudflare's predefined
  # Social Security, Insurance, Tax, and Identifier Numbers DLP profile.
  dlp = {
    enabled = true
    policies = [{
      id       = "block-sensitive-identifiers-in-prompts"
      enabled  = true
      action   = "BLOCK"
      check    = ["REQUEST"]
      profiles = ["d658f520-6ecb-4a34-a725-ba37243c2d28"]
    }]
  }

  # Guardrails S7 covers privacy-sensitive content. Flag other categories so
  # the demo produces useful security telemetry without broadly blocking use.
  guardrails = {
    prompt = {
      s1  = "FLAG"
      s2  = "FLAG"
      s3  = "FLAG"
      s4  = "FLAG"
      s5  = "FLAG"
      s6  = "FLAG"
      s7  = "BLOCK"
      s8  = "FLAG"
      s9  = "FLAG"
      s10 = "FLAG"
      s11 = "FLAG"
      s12 = "FLAG"
      s13 = "FLAG"
      p1  = "FLAG"
    }
    response = {
      s1  = "FLAG"
      s2  = "FLAG"
      s3  = "FLAG"
      s4  = "FLAG"
      s5  = "FLAG"
      s6  = "FLAG"
      s7  = "BLOCK"
      s8  = "FLAG"
      s9  = "FLAG"
      s10 = "FLAG"
      s11 = "FLAG"
      s12 = "FLAG"
      s13 = "FLAG"
      p1  = "FLAG"
    }
  }

  depends_on = [terraform_data.deployment_gate]

  lifecycle {
    prevent_destroy = false
    # The API supplies these empty computed collections after creation; the
    # provider otherwise plans to re-materialize them on every refresh.
    ignore_changes = [
      otel,
      spend_limits,
      store_id,
    ]
  }
}
