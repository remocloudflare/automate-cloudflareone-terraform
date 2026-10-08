resource "cloudflare_zero_trust_access_identity_provider" "entra" {
  count = local.deploy_ready ? 1 : 0

  account_id = var.account_id
  name       = var.entra_idp_name
  type       = "azureAD"

  config = {
    client_id        = var.entra_client_id
    client_secret    = var.entra_client_secret
    directory_id     = var.entra_directory_id
    support_groups   = true
    pkce_enabled     = true
    email_claim_name = "preferred_username"
  }

  depends_on = [terraform_data.deployment_gate]

  lifecycle {
    prevent_destroy = false

    precondition {
      condition = (
        var.entra_client_id != "" &&
        var.entra_client_secret != "" &&
        var.entra_directory_id != ""
      )
      error_message = "Entra client ID, client secret, and directory ID are required when the MCP portal is enabled."
    }
  }
}

resource "cloudflare_zero_trust_access_identity_provider" "one_time_pin" {
  count = local.deploy_ready ? 1 : 0

  account_id = var.account_id
  name       = "One-time PIN"
  type       = "onetimepin"
  config     = {}

  lifecycle {
    prevent_destroy = false
  }
}