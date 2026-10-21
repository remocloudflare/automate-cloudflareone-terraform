"""Contract tests for reusable Gateway domain blocking."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GatewayDomainBlockTests(unittest.TestCase):
    def test_reusable_domain_file_contains_example(self):
        domains = [
            line.strip()
            for line in (ROOT / "files/blocked-domains.txt").read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(domains, ["777.com", "www2.pnwx.com"])

    def test_dns_and_http_rules_share_managed_domain_list(self):
        hcl = (ROOT / "gateway-domain-block.tf").read_text()
        self.assertIn('resource "cloudflare_zero_trust_list" "blocked_domains"', hcl)
        self.assertIn('type        = "DOMAIN"', hcl)
        self.assertIn('resource "cloudflare_zero_trust_gateway_policy" "block_domains_dns"', hcl)
        self.assertIn('filters     = ["dns"]', hcl)
        self.assertIn('any(dns.domains[*] in $%s)', hcl)
        self.assertIn('resource "cloudflare_zero_trust_gateway_policy" "block_domains_network"', hcl)
        self.assertIn('filters     = ["l4"]', hcl)
        self.assertIn('any(net.sni.domains[*] in $%s)', hcl)
        self.assertIn('resource "cloudflare_zero_trust_gateway_policy" "block_domains_http"', hcl)
        self.assertIn('filters     = ["http"]', hcl)
        self.assertIn('any(http.request.domains[*] in $%s)', hcl)

    def test_rule_priorities_are_derived_from_one_programmatic_sequence(self):
        domain_hcl = (ROOT / "gateway-domain-block.tf").read_text()
        ip_hcl = (ROOT / "gateway-ip-block.tf").read_text()
        egress_hcl = (ROOT / "gateway-egress.tf").read_text()
        combined = domain_hcl + ip_hcl + egress_hcl

        self.assertIn("gateway_rule_priority_base = 1000", domain_hcl)
        self.assertIn("gateway_rule_priority_step = 100", domain_hcl)
        self.assertIn("egress         = local.gateway_rule_priority_base", domain_hcl)
        self.assertIn("dns_domain     = local.gateway_rule_priority_base + local.gateway_rule_priority_step", domain_hcl)
        self.assertIn("network_domain = local.gateway_rule_priority_base + (2 * local.gateway_rule_priority_step)", domain_hcl)
        self.assertIn("network_ip     = local.gateway_rule_priority_base + (3 * local.gateway_rule_priority_step)", domain_hcl)
        self.assertIn("http_domain    = local.gateway_rule_priority_base + (4 * local.gateway_rule_priority_step)", domain_hcl)
        self.assertIn("precedence  = local.gateway_rule_priorities.dns_domain", domain_hcl)
        self.assertIn("precedence  = local.gateway_rule_priorities.network_domain", domain_hcl)
        self.assertIn("precedence  = local.gateway_rule_priorities.http_domain", domain_hcl)
        self.assertIn("precedence  = local.gateway_rule_priorities.network_ip", ip_hcl)
        self.assertIn("precedence  = local.gateway_rule_priorities.egress", egress_hcl)
        self.assertNotIn("precedence  = 1000", combined)
        self.assertNotIn("precedence  = 1100", combined)
        self.assertNotIn("precedence  = 1200", combined)
        self.assertNotIn("precedence  = 1300", combined)
        self.assertNotIn("precedence  = 1400", combined)

    def test_ip_file_contains_documentation_examples(self):
        ips = [
            line.strip()
            for line in (ROOT / "files/blocked-ips.txt").read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(ips, ["192.0.2.10", "2001:db8::10"])

    def test_network_rule_uses_managed_ip_list(self):
        hcl = (ROOT / "gateway-ip-block.tf").read_text()
        self.assertIn('resource "cloudflare_zero_trust_list" "blocked_ips"', hcl)
        self.assertIn('type        = "IP"', hcl)
        self.assertIn('resource "cloudflare_zero_trust_gateway_policy" "block_ips_network"', hcl)
        self.assertIn('filters     = ["l4"]', hcl)
        self.assertIn('net.dst.ip in $%s', hcl)

    def test_ip_file_validates_ipv4_ipv6_and_cidrs(self):
        hcl = (ROOT / "gateway-ip-block.tf").read_text()
        self.assertIn('check "blocked_ip_entries"', hcl)
        self.assertIn('can(cidrhost(ip, 0))', hcl)
        self.assertIn('can(cidrhost("${ip}/32", 0))', hcl)
        self.assertIn('can(cidrhost("${ip}/128", 0))', hcl)

    def test_user_scoped_default_egress_rule(self):
        hcl = (ROOT / "gateway-egress.tf").read_text()
        self.assertIn('resource "cloudflare_zero_trust_gateway_policy" "email_default_egress"', hcl)
        self.assertIn('file("${path.module}/${var.egress_emails_file}")', hcl)
        self.assertIn('egress_emails_file       = "files/egress-emails.local.txt"', (ROOT / "terraform.tfvars.example").read_text())
        self.assertIn('check "egress_email_entries"', hcl)
        self.assertIn('resource "cloudflare_zero_trust_list" "egress_emails"', hcl)
        self.assertIn('name        = "terraform_demo_egress_emails"', hcl)
        self.assertIn('type        = "EMAIL"', hcl)
        self.assertIn('cloudflare_zero_trust_list.egress_emails[0].id', hcl)
        self.assertIn('identity.email in $%s', hcl)
        self.assertNotIn('identity.email in {%s}', hcl)
        self.assertNotIn('local.egress_email_identity_values', hcl)
        self.assertIn('action      = "egress"', hcl)
        self.assertIn('filters     = ["egress"]', hcl)
        self.assertIn('traffic     = "net.protocol in {\\"tcp\\" \\"udp\\"}"', hcl)
        self.assertNotIn('\\"icmp\\"', hcl)
        self.assertNotIn('\\"icmpv6\\"', hcl)
        self.assertNotIn("rule_settings", hcl)
        self.assertNotIn("remo@itlinux.cc", hcl)

    def test_egress_email_file_is_reusable_and_explicit(self):
        email_file = ROOT / "files" / "egress-emails.txt"
        self.assertTrue(email_file.exists())
        emails = [
            line.strip()
            for line in email_file.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        self.assertEqual(emails, ["egress-user@example.com"])
        self.assertNotIn("rm@itlinux.cc", emails)

    def test_domain_file_rejects_urls_paths_ports_and_wildcards(self):
        hcl = (ROOT / "gateway-domain-block.tf").read_text()
        self.assertIn('check "blocked_domain_entries"', hcl)
        self.assertIn('can(regex(', hcl)
        self.assertIn('length(local.blocked_domains) > 0', hcl)


if __name__ == "__main__":
    unittest.main()
