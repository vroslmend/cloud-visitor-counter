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
