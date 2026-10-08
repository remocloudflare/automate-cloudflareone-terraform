locals {
  # JSON list is editor-friendly; stable IDs become for_each keys regardless of row order.
  catalog_rows = jsondecode(file("${path.module}/files/mcp-servers.json"))
  catalog_ids  = [for server in local.catalog_rows : server.id]
  catalog_by_id = {
    for server in local.catalog_rows : server.id => server
  }
  active_mcp_servers = {
    for id, server in local.catalog_by_id : id => server if server.enabled
  }
  allowed_user_emails = toset([
    for line in split("\n", file("${path.module}/files/allowed-user-emails.txt")) : trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ])
  deploy_ready = (
    var.enable_mcp_portal && var.account_id != "" && var.zone_id != "" &&
    var.portal_hostname != "" && var.clientless_app_hostname != "" &&
    var.portal_id != "" && length(local.allowed_user_emails) > 0 &&
    length(local.active_mcp_servers) > 0
  )
  deployed_mcp_servers = local.deploy_ready ? local.active_mcp_servers : {}
}

check "catalog_entries" {
  assert {
    condition = length(local.catalog_rows) <= 80 && length(local.catalog_ids) == length(distinct(local.catalog_ids)) && alltrue([
      for server in local.catalog_rows :
      length(setsubtract(toset(keys(server)), toset(["id", "name", "url", "auth_type", "enabled"]))) == 0 &&
      can(regex("^[a-z0-9]+(?:-[a-z0-9]+)*$", server.id)) &&
      length(trimspace(server.name)) > 0 &&
      can(regex("^https://[^/]+/.+", server.url)) &&
      server.auth_type == "unauthenticated" &&
      (server.enabled == true || server.enabled == false)
    ])
    error_message = "files/mcp-servers.json allows up to 80 unique stable IDs, nonempty names, HTTPS MCP URLs, explicit booleans, and auth_type=unauthenticated."
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
    error_message = "files/allowed-user-emails.txt must contain at least one valid email address, one per line."
  }
}

# Precondition prevents an enabled plan with missing deployment identifiers.
resource "terraform_data" "deployment_gate" {
  count = var.enable_mcp_portal ? 1 : 0

  input = var.portal_id

  lifecycle {
    precondition {
      condition     = local.deploy_ready
      error_message = "To enable deployment, set account_id, zone_id, portal_hostname, clientless_app_hostname, portal_id, at least one valid email in files/allowed-user-emails.txt, and at least one enabled MCP server."
    }
  }
}
