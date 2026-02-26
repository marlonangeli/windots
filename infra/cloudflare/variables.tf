variable "zone_id" {
  description = "Cloudflare zone ID for ilegna.dev."
  type        = string
}

variable "zone_name" {
  description = "Cloudflare zone apex domain name."
  type        = string
  default     = "ilegna.dev"
}

variable "windots_hostname" {
  description = "Hostname label under zone_name for the redirect host."
  type        = string
  default     = "windots"
}

variable "redirect_target" {
  description = "Target URL for windots redirect."
  type        = string
  default     = "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1"
}

variable "redirect_status_code" {
  description = "Redirect status code to use at Cloudflare edge."
  type        = number
  default     = 302

  validation {
    condition     = contains([301, 302, 307, 308], var.redirect_status_code)
    error_message = "redirect_status_code must be one of 301, 302, 307, or 308."
  }
}
