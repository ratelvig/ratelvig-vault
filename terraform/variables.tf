variable "pm_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "ct_password" {
  type        = string
  sensitive   = true
  description = "CT password"
}

variable "ssh_key" {
  type        = string
  description = "SSH key allowed for CT"
}