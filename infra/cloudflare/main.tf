locals {
  windots_fqdn = "${var.windots_hostname}.${var.zone_name}"
}

resource "cloudflare_dns_record" "windots_placeholder_a" {
  zone_id = var.zone_id
  name    = var.windots_hostname
  type    = "A"
  content = "192.0.2.1"
  ttl     = 1
  proxied = true

  comment = "Originless host for redirect rules"
}

resource "cloudflare_dns_record" "windots_placeholder_aaaa" {
  zone_id = var.zone_id
  name    = var.windots_hostname
  type    = "AAAA"
  content = "100::"
  ttl     = 1
  proxied = true

  comment = "Originless host for redirect rules"
}

resource "cloudflare_ruleset" "windots_redirect" {
  zone_id     = var.zone_id
  name        = "windots-redirects"
  description = "Redirect windots host to installer script"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [
    {
      ref         = "windots_install_redirect"
      enabled     = true
      description = "windots host -> install.ps1"
      expression  = "(http.host eq \"${local.windots_fqdn}\")"
      action      = "redirect"

      action_parameters = {
        from_value = {
          status_code = var.redirect_status_code
          target_url = {
            value = var.redirect_target
          }
          preserve_query_string = true
        }
      }
    }
  ]
}
