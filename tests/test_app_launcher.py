"""Contract tests for enabling the Cloudflare Access App Launcher."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AppLauncherTests(unittest.TestCase):
    def test_launcher_application_is_enabled_with_entra(self):
        hcl = (ROOT / "app-launcher.tf").read_text()
        self.assertIn('resource "cloudflare_zero_trust_access_application" "app_launcher"', hcl)
        self.assertRegex(hcl, r'type\s+=\s+"app_launcher"')
        self.assertIn('name       = "App Launcher"', hcl)
        self.assertIn('landing_page_design = {', hcl)
        self.assertIn('title = "Welcome!"', hcl)
        self.assertIn('cloudflare_zero_trust_access_identity_provider.entra[0].id', hcl)
        self.assertIn('cloudflare_zero_trust_access_identity_provider.one_time_pin[0].id', hcl)
        self.assertIn('cloudflare_zero_trust_access_policy.demo_user[0].id', hcl)
        self.assertIn('auto_redirect_to_identity = false', hcl)
        self.assertIn('prevent_destroy = false', hcl)

    def test_optional_rbi_bookmark_is_published_in_launcher(self):
        hcl = (ROOT / "rbi-bookmark.tf").read_text()
        variables = (ROOT / "variables.tf").read_text()
        example = (ROOT / "terraform.tfvars.example").read_text()
        outputs = (ROOT / "outputs.tf").read_text()

        self.assertIn('resource "cloudflare_zero_trust_access_application" "rbi_bookmark"', hcl)
        self.assertIn('local.deploy_ready && var.rbi_bookmark_url != ""', hcl)
        self.assertRegex(hcl, r'type\s+=\s+"bookmark"')
        self.assertRegex(hcl, r'domain\s+=\s+var\.rbi_bookmark_url')
        self.assertIn('app_launcher_visible = true', hcl)
        self.assertIn('cloudflare_zero_trust_access_policy.clientless_rbi[0].id', hcl)
        self.assertIn('resource "cloudflare_zero_trust_access_policy" "clientless_rbi"', hcl)
        self.assertIn('resource "cloudflare_zero_trust_access_application" "clientless_rbi"', hcl)
        self.assertIn('type       = "biso"', hcl)
        self.assertIn('ignore_changes = [session_duration]', hcl)
        self.assertIn('variable "rbi_bookmark_url"', variables)
        self.assertIn('"^https://[^[:space:]]+$"', variables)
        self.assertRegex(example, r'rbi_bookmark_url\s+=\s+""')
        self.assertIn('output "rbi_bookmark_url"', outputs)

    def test_local_rbi_is_disabled_while_provider_biso_creation_is_broken(self):
        tfvars = (ROOT / "terraform.tfvars").read_text()
        self.assertRegex(tfvars, r'rbi_bookmark_url\s+=\s+""')

    def test_clientless_rbi_uses_same_allowed_users_as_launcher(self):
        hcl = (ROOT / "rbi-bookmark.tf").read_text()
        self.assertIn("for email in local.allowed_user_emails", hcl)
        self.assertNotIn("rm@rm.ht", hcl)


if __name__ == "__main__":
    unittest.main()
