locals {
  # JSON list is editor-friendly; stable IDs become for_each keys regardless of row order.
  catalog_rows = jsondecode(file("${path.module}/files/mcp-servers.json"))
  catalog_ids  = [for server in local.catalog_rows : server.id]
  catalog_by_id = {
    for server in local.catalog_rows : server.id => server
  }
  # Bearer upstreams use an optional per-server token, else the same cloudflare_api_token from tfvars.
  mcp_bearer_token_by_id = {
    for id, server in local.catalog_by_id : id => (
      trimspace(lookup(var.mcp_bearer_tokens, id, "")) != "" ? trimspace(lookup(var.mcp_bearer_tokens, id, "")) : trimspace(var.cloudflare_api_token)
    ) if server.auth_type == "bearer"
  }
  # nonsensitive() exposes only "is every bearer token set" (a boolean), never a token value.
  bearer_tokens_ready = nonsensitive(alltrue([
    for id, server in local.catalog_by_id :
    !server.enabled || server.auth_type != "bearer" || length(lookup(local.mcp_bearer_token_by_id, id, "")) > 0
  ]))
  active_mcp_servers = {
    for id, server in local.catalog_by_id : id => server if server.enabled
  }
  allowed_user_emails = toset([
    for line in split("\n", file("${path.module}/${var.allowed_user_emails_file}")) : trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ])
  deploy_ready = (
    var.enable_mcp_portal && var.account_id != "" && var.zone_id != "" &&
    var.portal_hostname != "" && var.clientless_app_hostname != "" &&
    var.portal_id != "" && length(local.allowed_user_emails) > 0 &&
    length(local.active_mcp_servers) > 0 &&
    local.bearer_tokens_ready
  )
  deployed_mcp_servers = local.deploy_ready ? local.active_mcp_servers : {}
}

check "catalog_entries" {
  assert {
    condition = length(local.catalog_rows) <= 80 && length(local.catalog_ids) == length(distinct(local.catalog_ids)) && alltrue([
      for server in local.catalog_rows :
      length(setsubtract(toset(keys(server)), toset(["id", "name", "url", "auth_type", "on_behalf", "enabled"]))) == 0 &&
      can(regex("^[a-z0-9]+(?:-[a-z0-9]+)*$", server.id)) &&
      length(trimspace(server.name)) > 0 &&
      can(regex("^https://[^/]+/.+", server.url)) &&
      contains(["unauthenticated", "bearer", "oauth"], server.auth_type) &&
      # OAuth upstreams always use each user's own login; other types never claim on_behalf.
      (server.auth_type == "oauth" ? try(server.on_behalf, false) == true : try(server.on_behalf, false) == false) &&
      (server.enabled == true || server.enabled == false)
    ])
    error_message = "files/mcp-servers.json allows up to 80 unique stable IDs, nonempty names, HTTPS MCP URLs, explicit booleans, and auth_type unauthenticated/bearer (on_behalf omitted) or oauth (on_behalf = true)."
  }
}

check "bearer_tokens" {
  assert {
    condition     = local.bearer_tokens_ready
    error_message = "Every enabled auth_type=bearer server needs a token: set cloudflare_api_token in terraform.tfvars, or a per-server override in mcp_bearer_tokens."
  }
}

check "enabled_servers" {
  assert {
    condition     = !var.enable_mcp_portal || length(local.active_mcp_servers) > 0
    error_message = "Add at least one enabled server before deploying; disabling the last server requires an intentional migration."
  }
}

check "allowed_user_emails" {
  assert {
    condition = length(local.allowed_user_emails) > 0 && alltrue([
      for email in local.allowed_user_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))
    ])
    error_message = "The configured allowed_user_emails_file must contain at least one valid email address, one per line."
  }
}

# Precondition prevents an enabled plan with missing deployment identifiers.
resource "terraform_data" "deployment_gate" {
  count = var.enable_mcp_portal ? 1 : 0

  input = var.portal_id

  lifecycle {
    precondition {
      condition     = local.deploy_ready
      error_message = "To enable deployment, set account_id, zone_id, portal_hostname, clientless_app_hostname, portal_id, at least one valid email in allowed_user_emails_file, at least one enabled MCP server, and a mcp_bearer_tokens entry for every enabled bearer server."
    }
  }
}
