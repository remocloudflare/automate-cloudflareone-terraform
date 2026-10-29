# The AI Gateway DLP policy below references this predefined profile. Its detection entries
# ship disabled, so without this resource the policy is attached but can never match.
# Enable only the US SSN detections used by the demo's fake-SSN prompt. Predefined profiles
# are account-wide: this also affects Gateway HTTP DLP rules that reference the same profile.
locals {
  ssn_dlp_profile_id = "d658f520-6ecb-4a34-a725-ba37243c2d28"
  ssn_dlp_enabled_entries = [
    "111b9d4b-a5c6-40f0-957d-9d53b25dd84a", # United States SSN Numeric Detection
    "aec08712-ee49-4109-9d9f-3b229c5b3dcd", # United States SSN Text
  ]
}

resource "cloudflare_zero_trust_dlp_predefined_profile" "ssn" {
  count = local.deploy_ready ? 1 : 0

  account_id      = var.account_id
  profile_id      = local.ssn_dlp_profile_id
  enabled_entries = local.ssn_dlp_enabled_entries

  depends_on = [terraform_data.deployment_gate]
}

resource "cloudflare_ai_gateway" "demo" {
  count = local.deploy_ready ? 1 : 0

  account_id = var.account_id
  id         = var.ai_gateway_id

  collect_logs               = true
  cache_ttl                  = 0
  cache_invalidate_on_update = false
  rate_limiting_interval     = 0
  rate_limiting_limit        = 0
  # Require cf-aig-authorization on every request to this gateway. Access/Entra
  # protects the Worker, not this endpoint: gateway.ai.cloudflare.com/... is a
  # public URL and would otherwise accept direct calls that bypass the Worker,
  # arriving with no cf-aig-metadata and leaving unattributable spend in the
  # logs. The Worker supplies the token via the AI_GATEWAY_TOKEN binding.
  authentication          = true
  log_classification      = false
  log_management          = 10000000
  log_management_strategy = "DELETE_OLDEST"
  logpush                 = false
  zdr                     = false

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
      profiles = [local.ssn_dlp_profile_id]
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

  depends_on = [
    terraform_data.deployment_gate,
    cloudflare_zero_trust_dlp_predefined_profile.ssn,
  ]

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
