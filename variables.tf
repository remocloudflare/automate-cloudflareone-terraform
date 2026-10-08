variable "cloudflare_api_token" {
  description = "Scoped token for this demo. Set in ignored terraform.tfvars or leave empty to use CLOUDFLARE_API_TOKEN. Never commit a real token."
  type        = string
  sensitive   = true
  default     = ""
}

variable "account_id" {
  description = "Disposable demo Cloudflare account ID (never a customer account)."
  type        = string
  default     = ""

  validation {
    condition     = var.account_id == "" || can(regex("^[a-fA-F0-9]{32}$", var.account_id))
    error_message = "account_id must be empty during offline development or a 32-character hex Cloudflare account ID."
  }
}

variable "zone_id" {
  description = "Active Cloudflare zone ID containing portal_hostname."
  type        = string
  default     = ""

  validation {
    condition     = var.zone_id == "" || can(regex("^[a-fA-F0-9]{32}$", var.zone_id))
    error_message = "zone_id must be empty during offline development or a 32-character hex Cloudflare zone ID."
  }
}

variable "portal_hostname" {
  description = "Portal FQDN on the active demo zone (no protocol or path)."
  type        = string
  default     = ""

  validation {
    condition     = var.portal_hostname == "" || can(regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$", var.portal_hostname))
    error_message = "portal_hostname must be empty during offline development or a lowercase FQDN."
  }
}

variable "clientless_app_hostname" {
  description = "Public hostname in zone_id for the Worker-backed clientless Access demo shown in the App Launcher."
  type        = string
  default     = "app.demotf.itlinux.cc"

  validation {
    condition     = var.clientless_app_hostname == "" || can(regex("^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$", var.clientless_app_hostname))
    error_message = "clientless_app_hostname must be empty during offline development or a lowercase FQDN without a protocol or path."
  }
}

variable "ai_gateway_id" {
  description = "Stable ID for the Terraform-managed AI Gateway demo."
  type        = string
  default     = "terraform-cloudflare-one-demo"

  validation {
    condition     = can(regex("^[a-z0-9]+(?:-[a-z0-9]+)*$", var.ai_gateway_id))
    error_message = "ai_gateway_id must be lowercase letters/numbers separated by hyphens."
  }
}


variable "enable_mcp_portal" {
  description = "Create the MCP portal and its supporting resources."
  type        = bool
  default     = true
}

variable "portal_id" {
  description = "Stable unique portal ID; set per deployment and change only through an explicit migration."
  type        = string
  default     = ""

  validation {
    condition     = var.portal_id == "" || can(regex("^[a-z0-9]+(?:-[a-z0-9]+)*$", var.portal_id))
    error_message = "portal_id must be lowercase letters/numbers separated by hyphens."
  }
}

variable "portal_name" {
  description = "Human-readable name used for the portal, Access apps and policy."
  type        = string
  default     = "MCP Tool Demo"

  validation {
    condition     = length(trimspace(var.portal_name)) > 0
    error_message = "portal_name cannot be empty."
  }
}

variable "access_session_duration" {
  description = "Access session lifetime for the demo policy and MCP applications."
  type        = string
  default     = "8h"
}

variable "entra_client_id" {
  description = "Application/client ID for the Microsoft Entra app registration."
  type        = string
  default     = ""
}

variable "entra_client_secret" {
  description = "Client secret for the Microsoft Entra app registration. Store only in ignored terraform.tfvars or inject through TF_VAR_entra_client_secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "entra_directory_id" {
  description = "Microsoft Entra tenant/directory ID."
  type        = string
  default     = ""
}

variable "entra_idp_name" {
  description = "Display name for the Microsoft Entra identity provider."
  type        = string
  default     = "Microsoft Entra ID"
}
