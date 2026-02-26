output "windots_url" {
  description = "Branded installer URL for windots."
  value       = "https://${local.windots_fqdn}/install"
}

output "redirect_target" {
  description = "Current redirect target URL."
  value       = var.redirect_target
}

output "dns_record_ids" {
  description = "Cloudflare DNS record IDs for windots placeholders."
  value = {
    a    = cloudflare_dns_record.windots_placeholder_a.id
    aaaa = cloudflare_dns_record.windots_placeholder_aaaa.id
  }
}
