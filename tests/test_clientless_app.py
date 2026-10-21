"""Contract tests for the clientless Access demo application."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ClientlessAccessAppTests(unittest.TestCase):
    def test_worker_and_custom_domain_are_managed(self):
        hcl = (ROOT / "clientless-app.tf").read_text()
        self.assertIn('resource "cloudflare_workers_script" "clientless_demo"', hcl)
        self.assertIn('resource "cloudflare_workers_custom_domain" "clientless_demo"', hcl)
        self.assertIn('hostname   = var.clientless_app_hostname', hcl)

    def test_worker_ignores_only_provider_normalized_metadata(self):
        hcl = (ROOT / "clientless-app.tf").read_text()
        self.assertIn("ignore_changes = [", hcl)
        self.assertIn("annotations,", hcl)
        self.assertIn("bindings,", hcl)
        self.assertIn("observability.traces,", hcl)
        self.assertIn("placement,", hcl)
        self.assertIn("tail_consumers,", hcl)
        self.assertNotIn("content,", hcl.split("ignore_changes = [", 1)[1].split("]", 1)[0])

    def test_access_app_is_clientless_and_launcher_visible(self):
        hcl = (ROOT / "clientless-app.tf").read_text()
        self.assertRegex(hcl, r'type\s+=\s+"self_hosted"')
        self.assertIn('app_launcher_visible      = true', hcl)
        self.assertIn('auto_redirect_to_identity = false', hcl)
        self.assertIn('cloudflare_zero_trust_access_identity_provider.entra[0].id', hcl)
        self.assertIn('cloudflare_zero_trust_access_identity_provider.one_time_pin[0].id', hcl)
        self.assertIn('cloudflare_zero_trust_access_policy.demo_user[0].id', hcl)

    def test_default_hostname_is_documented_outside_tfvars(self):
        variables = (ROOT / "variables.tf").read_text()
        example = (ROOT / "terraform.tfvars.example").read_text()
        self.assertIn('variable "clientless_app_hostname"', variables)
        block = variables.split('variable "clientless_app_hostname"', 1)[1].split("}\n\nvariable", 1)[0]
        self.assertIn('default     = "app.demotf.itlinux.cc"', block)
        self.assertNotIn("clientless_app_hostname =", example)

    def test_worker_explains_authenticated_clientless_access(self):
        source = (ROOT / "worker/clientless-demo.js").read_text()
        self.assertIn("Clientless Access Demo", source)
        self.assertIn("CF-Access-Authenticated-User-Email", source)
        self.assertIn("no-store", source)


if __name__ == "__main__":
    unittest.main()
