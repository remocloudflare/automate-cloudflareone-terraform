"""Offline contract tests for the account-neutral MCP Terraform demo."""
import json
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CatalogTests(unittest.TestCase):
    def test_catalog_contains_enabled_cloudflare_docs_example(self):
        rows = json.loads((ROOT / "files/mcp-servers.json").read_text())
        self.assertEqual(rows[0], {
            "id": "cloudflare-docs",
            "name": "Cloudflare Documentation",
            "url": "https://docs.mcp.cloudflare.com/mcp",
            "auth_type": "unauthenticated",
            "enabled": True,
        })
        self.assertTrue(any(row["enabled"] for row in rows))

    def test_account_server_uses_per_user_oauth_and_bearer_support_stays_wired(self):
        rows = {r["id"]: r for r in json.loads((ROOT / "files/mcp-servers.json").read_text())}
        obs = rows["cloudflare-workers-observability"]
        self.assertEqual(obs["url"], "https://observability.mcp.cloudflare.com/mcp")
        self.assertEqual(obs["auth_type"], "oauth")
        self.assertIs(obs["on_behalf"], True)
        mcp = (ROOT / "mcp.tf").read_text()
        variables = (ROOT / "variables.tf").read_text()
        example = (ROOT / "terraform.tfvars.example").read_text()
        self.assertIn("local.mcp_bearer_token_by_id[each.key]", mcp)
        self.assertRegex(variables, r'variable "mcp_bearer_tokens"[\s\S]*?sensitive\s*=\s*true')
        self.assertIn("mcp_bearer_tokens", example)
        # The example may show a placeholder, but never a real-looking token.
        self.assertNotRegex(example, r'"cloudflare-workers-observability"\s*=\s*"(?!<)[^"]+"')
        # Never the full Cloudflare API server, which can change account state.
        self.assertNotIn("https://mcp.cloudflare.com/mcp", [r["url"] for r in rows.values()])
        for row in rows.values():
            if row["auth_type"] == "unauthenticated":
                self.assertFalse(row.get("on_behalf", False))
        hcl = (ROOT / "mcp.tf").read_text()
        self.assertIn("on_behalf        = try(local.deployed_mcp_servers[id].on_behalf, false)", hcl)

    def test_catalog_keys_servers_and_access_apps_by_stable_id(self):
        hcl = (ROOT / "mcp.tf").read_text()
        access = (ROOT / "mcp-access.tf").read_text()
        self.assertRegex(hcl, r"for_each\s*=\s*local\.deployed_mcp_servers")
        self.assertRegex(access, r"for_each\s*=\s*local\.deployed_mcp_servers")
        self.assertIn("sort(keys(local.deployed_mcp_servers))", hcl)
        self.assertIn("prevent_destroy = false", hcl)

    def test_portal_and_access_settings_are_variables(self):
        variables = (ROOT / "variables.tf").read_text()
        hcl = (ROOT / "mcp.tf").read_text()
        access = (ROOT / "mcp-access.tf").read_text()
        for name in ("portal_id", "portal_name", "access_session_duration"):
            self.assertIn(f'variable "{name}"', variables)
        self.assertIn("name       = var.portal_name", hcl)
        self.assertIn("session_duration = var.access_session_duration", access)
        self.assertNotIn('"CF1 MCP Tool Demo"', hcl)

    def test_incomplete_enablement_fails_before_cloudflare_changes(self):
        hcl = (ROOT / "catalog.tf").read_text()
        self.assertIn('resource "terraform_data" "deployment_gate"', hcl)
        self.assertIn("condition     = local.deploy_ready", hcl)
        self.assertIn("length(local.active_mcp_servers) > 0", hcl)

    def test_access_policy_accepts_multiple_explicit_emails(self):
        variables = (ROOT / "variables.tf").read_text()
        access = (ROOT / "mcp-access.tf").read_text()
        example = (ROOT / "terraform.tfvars.example").read_text()
        emails = (ROOT / "files/allowed-user-emails.txt").read_text()
        catalog = (ROOT / "catalog.tf").read_text()
        self.assertNotIn('variable "allowed_user_emails"', variables)
        self.assertIn('file("${path.module}/${var.allowed_user_emails_file}")', catalog)
        self.assertIn('allowed_user_emails_file = "files/allowed-user-emails.local.txt"', example)
        self.assertNotIn('allowed_user_emails =', example)
        self.assertIn("access-user@example.com", emails)
        self.assertNotIn("rm@itlinux.cc", emails)
        self.assertNotIn("remo@mattei.org", emails)
        self.assertNotIn("xx@xx.com", emails)
        self.assertNotIn("@rm.ht", example)
        self.assertNotIn("@itlinux.cc", example)
        self.assertNotIn("@cloudflare.com", example)

    def test_client_templates_use_terraform_portal_hostname(self):
        for filename in (
            "opencode-mcp.example.jsonc",
            "opencode-with-ai-gateway.example.jsonc",
            "claude-code-mcp.example.json",
        ):
            template = (ROOT / "files" / filename).read_text()
            self.assertIn('https://${portal_hostname}/mcp', template)
            self.assertNotIn("YOUR-PORTAL-HOSTNAME", template)

        outputs = (ROOT / "outputs.tf").read_text()
        self.assertIn('templatefile("${path.module}/files/opencode-mcp.example.jsonc"', outputs)
        self.assertIn("portal_hostname = var.portal_hostname", outputs)

        readme = (ROOT / "README.md").read_text()
        self.assertNotIn("YOUR-PORTAL-HOSTNAME", readme)
        self.assertIn("terraform output -raw opencode_mcp_config", readme)

if __name__ == "__main__":
    unittest.main()
