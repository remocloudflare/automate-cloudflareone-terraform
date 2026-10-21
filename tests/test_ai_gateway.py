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
        self.assertIn('authentication             = false', hcl)
        self.assertIn('log_classification         = false', hcl)
        self.assertIn('log_management             = 10000000', hcl)
        self.assertIn('log_management_strategy    = "DELETE_OLDEST"', hcl)
        self.assertNotRegex(hcl, r'store_id\s+=')
        self.assertIn('store_id,', hcl)
        self.assertIn('otel,', hcl)
        self.assertIn('spend_limits,', hcl)

    def test_gateway_blocks_sensitive_prompts(self):
        hcl = (ROOT / "ai-gateway.tf").read_text()
        self.assertIn('dlp = {', hcl)
        self.assertIn('action   = "BLOCK"', hcl)
        self.assertIn('check    = ["REQUEST"]', hcl)
        self.assertIn('"d658f520-6ecb-4a34-a725-ba37243c2d28"', hcl)
        self.assertRegex(hcl, r's7\s+=\s+"BLOCK"')

    def test_gateway_has_stable_demo_defaults_and_output(self):
        variables = (ROOT / "variables.tf").read_text()
        outputs = (ROOT / "outputs.tf").read_text()
        self.assertIn('variable "ai_gateway_id"', variables)
        self.assertIn('default     = "terraform-cloudflare-one-demo"', variables)
        self.assertIn('output "ai_gateway_endpoint"', outputs)
        self.assertIn('gateway.ai.cloudflare.com', outputs)


if __name__ == "__main__":
    unittest.main()
