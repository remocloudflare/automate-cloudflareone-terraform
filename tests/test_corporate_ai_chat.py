import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class CorporateChatContractTests(unittest.TestCase):
    def test_worker_is_educational_corporate_chat(self):
        source = (ROOT / "worker" / "corporate-ai-chat.js").read_text()
        self.assertIn("Your corporate AI chat", source)
        self.assertIn("Employee", source)
        self.assertIn("AI Gateway", source)
        self.assertIn("DLP", source)
        self.assertIn("Guardrails", source)
        self.assertIn("Blocked by DLP", source)
        self.assertIn("/api/chat", source)
        self.assertNotIn("itlinux.cc", source)
        self.assertNotIn("Remo Mattei", source)
        self.assertNotIn("penguin.webp", source)
        self.assertNotRegex(source, r"815b94af8be996b270364b66fa166aad")

    def test_current_gateway_block_code_is_shown_as_dlp(self):
        source = (ROOT / "worker" / "corporate-ai-chat.js").read_text()
        # AI Gateway now returns internalCode 2016 with `error` as an array; 2030 is legacy.
        self.assertIn("[2016, 2030, '2016', '2030']", source)
        self.assertIn("security configuration", source)
        self.assertIn("code: gatewayCode(evidence)", source)

    def test_gateway_logs_are_tagged_with_access_user(self):
        source = (ROOT / "worker" / "corporate-ai-chat.js").read_text()
        self.assertIn("cf-access-authenticated-user-email", source)
        self.assertIn("'cf-aig-metadata': gatewayMetadata(request)", source)
        hcl = (ROOT / "corporate-ai-chat.tf").read_text()
        # The identity header is only trustworthy when workers.dev is off and Access fronts the domain.
        self.assertRegex(hcl, r'cloudflare_workers_script_subdomain"[\s\S]*?enabled\s*=\s*false')

    def test_terraform_manages_chat_worker_access_and_launcher(self):
        hcl = (ROOT / "corporate-ai-chat.tf").read_text()
        variables = (ROOT / "variables.tf").read_text()
        outputs = (ROOT / "outputs.tf").read_text()
        self.assertIn('resource "cloudflare_workers_script" "corporate_ai_chat"', hcl)
        # Idempotency: the DO migration is applied once out of band; the Worker never sends migrations,
        # so plan is empty after fresh create, updates, and destroy/recreate (avoids API 10079).
        self.assertIn('resource "terraform_data" "corporate_ai_chat_do_migration"', hcl)
        self.assertIn('scripts/bootstrap-do-migration.sh', hcl)
        self.assertIn('terraform_data.corporate_ai_chat_do_migration,', hcl)
        self.assertNotRegex(hcl, r"(?m)^\s*migrations\s*=")
        script = (ROOT / "scripts" / "bootstrap-do-migration.sh").read_text()
        self.assertIn('"new_sqlite_classes":["$CLASS_NAME"]', script)
        self.assertIn('already at migration tag', script)
        self.assertNotIn("set -x", script)
        self.assertIn('resource "cloudflare_workers_custom_domain" "corporate_ai_chat"', hcl)
        self.assertIn('resource "cloudflare_workers_script_subdomain" "corporate_ai_chat"', hcl)
        self.assertIn('enabled          = false', hcl)
        self.assertIn('previews_enabled = false', hcl)
        self.assertIn('resource "cloudflare_zero_trust_access_application" "corporate_ai_chat"', hcl)
        self.assertIn('app_launcher_visible      = true', hcl)
        self.assertIn('cloudflare_zero_trust_access_policy.demo_user[0].id', hcl)
        self.assertIn('variable "corporate_ai_chat_hostname"', variables)
        self.assertIn('output "corporate_ai_chat_url"', outputs)

    def test_live_configuration_enables_chat_without_rbi(self):
        tfvars = (ROOT / "terraform.tfvars").read_text()
        self.assertRegex(tfvars, r'corporate_ai_chat_hostname\s+=\s+"chat\.demotf\.itlinux\.cc"')
        self.assertRegex(tfvars, r'rbi_bookmark_url\s+=\s+""')


if __name__ == "__main__":
    unittest.main()
