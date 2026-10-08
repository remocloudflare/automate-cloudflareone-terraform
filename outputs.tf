output "portal_url" {
  description = "MCP client endpoint after this stack has been deployed."
  value       = local.deploy_ready ? "https://${var.portal_hostname}/mcp" : null
}

output "clientless_app_url" {
  description = "Browser-only Access demo shown in the App Launcher after deployment."
  value       = local.deploy_ready ? "https://${var.clientless_app_hostname}" : null
}

output "ai_gateway_endpoint" {
  description = "Workers AI OpenAI-compatible endpoint routed through the Terraform-managed AI Gateway."
  value       = local.deploy_ready ? "https://gateway.ai.cloudflare.com/v1/${var.account_id}/${var.ai_gateway_id}/workers-ai/v1" : null
}

output "active_server_ids" {
  description = "Stable IDs of servers requested in the portal. Not proof of sync or access."
  value       = local.deploy_ready ? sort(keys(local.active_mcp_servers)) : []
}

output "opencode_mcp_config" {
  description = "Rendered OpenCode MCP client configuration using portal_hostname."
  value = local.deploy_ready ? templatefile("${path.module}/files/opencode-mcp.example.jsonc", {
    portal_hostname = var.portal_hostname
  }) : null
}

output "opencode_ai_gateway_config" {
  description = "Rendered OpenCode MCP and AI Gateway configuration using deployment variables."
  value = local.deploy_ready ? templatefile("${path.module}/files/opencode-with-ai-gateway.example.jsonc", {
    portal_hostname = var.portal_hostname
    account_id      = var.account_id
    ai_gateway_id   = var.ai_gateway_id
  }) : null
}

output "claude_code_mcp_config" {
  description = "Rendered Claude Code MCP client configuration using portal_hostname."
  value = local.deploy_ready ? templatefile("${path.module}/files/claude-code-mcp.example.json", {
    portal_hostname = var.portal_hostname
  }) : null
}
