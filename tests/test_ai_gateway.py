"""Contract tests for the Terraform-managed AI Gateway demo."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AiGatewayTests(unittest.TestCase):
    def test_gateway_is_native_terraform_and_observable(self):
        hcl = (ROOT / "ai-gateway.tf").read_text()
        self.assertIn('resource "cloudflare_ai_gateway" "demo"', hcl)
        self.assertIn('id         = var.ai_gateway_id', hcl)
        self.assertIn('collect_logs               = true', hcl)
        self.assertIn('cache_ttl                  = 0', hcl)
        # Gateway auth is ON: Access/Entra protects the Worker, not the public
        # gateway endpoint. Without this, direct calls bypass the Worker and
        # land in the logs with no cf-aig-metadata (unattributable spend).
        self.assertIn('authentication          = true', hcl)
        self.assertIn('log_classification      = false', hcl)
        self.assertIn('log_management          = 10000000', hcl)
        self.assertIn('log_management_strategy = "DELETE_OLDEST"', hcl)
        self.assertNotRegex(hcl, r'store_id\s+=')
        self.assertIn('store_id,', hcl)
        self.assertIn('otel,', hcl)
        self.assertIn('spend_limits,', hcl)

    def test_gateway_auth_token_is_wired_end_to_end(self):
        """authentication = true is only safe if the Worker actually sends the
        token; otherwise the gateway 401s its own chat demo."""
        variables = (ROOT / "variables.tf").read_text()
        self.assertIn('variable "ai_gateway_token"', variables)
        self.assertRegex(
            variables,
            r'(?s)variable "ai_gateway_token" \{.*?sensitive   = true',
            msg="ai_gateway_token must be marked sensitive",
        )

        chat_tf = (ROOT / "corporate-ai-chat.tf").read_text()
        self.assertIn('name        = "AI_GATEWAY_TOKEN"', chat_tf)
        self.assertIn('text        = var.ai_gateway_token', chat_tf)

        worker = (ROOT / "worker" / "corporate-ai-chat.js").read_text()
        self.assertIn("'cf-aig-authorization'", worker)
        self.assertIn("env.AI_GATEWAY_TOKEN", worker)

        example = (ROOT / "terraform.tfvars.example").read_text()
        self.assertIn("ai_gateway_token", example)

    def test_gateway_blocks_sensitive_prompts(self):
        hcl = (ROOT / "ai-gateway.tf").read_text()
        self.assertIn('dlp = {', hcl)
        self.assertIn('action   = "BLOCK"', hcl)
        self.assertIn('check    = ["REQUEST"]', hcl)
        self.assertIn('"d658f520-6ecb-4a34-a725-ba37243c2d28"', hcl)
        self.assertRegex(hcl, r's7\s+=\s+"BLOCK"')

    def test_dlp_profile_has_ssn_detections_enabled(self):
        hcl = (ROOT / "ai-gateway.tf").read_text()
        # Predefined profile entries ship disabled; the gateway DLP policy cannot match without these.
        self.assertIn('resource "cloudflare_zero_trust_dlp_predefined_profile" "ssn"', hcl)
        self.assertIn("enabled_entries = local.ssn_dlp_enabled_entries", hcl)
        self.assertIn('"111b9d4b-a5c6-40f0-957d-9d53b25dd84a", # United States SSN Numeric Detection', hcl)
        self.assertIn('"aec08712-ee49-4109-9d9f-3b229c5b3dcd", # United States SSN Text', hcl)
        self.assertIn("profiles = [local.ssn_dlp_profile_id]", hcl)

    def test_gateway_has_stable_demo_defaults_and_output(self):
        variables = (ROOT / "variables.tf").read_text()
        outputs = (ROOT / "outputs.tf").read_text()
        self.assertIn('variable "ai_gateway_id"', variables)
        self.assertIn('default     = "terraform-cloudflare-one-demo"', variables)
        self.assertIn('output "ai_gateway_endpoint"', outputs)
        self.assertIn('gateway.ai.cloudflare.com', outputs)


if __name__ == "__main__":
    unittest.main()
