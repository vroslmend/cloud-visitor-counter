variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix for all resources"
  type        = string
  default     = "portfolio-counter"
}

variable "allowed_origins" {
  description = "Origins allowed to call the API (CORS)"
  type        = list(string)
  default     = ["https://ammarhassan.dev", "http://localhost:3000"]
}

variable "github_repo" {
  description = "owner/name of the GitHub repo allowed to assume the CI role via OIDC"
  type        = string
  default     = "vroslmend/cloud-visitor-counter"
}

variable "alert_email" {
  description = "Where budget alerts go. AWS sends a subscription confirmation here once."
  type        = string
  default     = "ammarhassan.amr@gmail.com"
}

variable "budget_limit_usd" {
  description = "Monthly spend that trips the alert. This stack should cost cents."
  type        = string
  default     = "1"
}

# Real traffic is a few hundred requests a day. These are set orders of
# magnitude above that, and low enough that a bot hammering the endpoint costs
# pennies rather than hundreds. Raise them if legitimate traffic ever sees 429s.
variable "throttle_rate_limit" {
  description = "Sustained requests per second the API will serve before returning 429"
  type        = number
  default     = 2
}

variable "throttle_burst_limit" {
  description = "Requests served in an instantaneous burst before the rate limit applies"
  type        = number
  default     = 10
}
