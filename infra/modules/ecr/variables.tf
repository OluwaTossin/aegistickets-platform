variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "AegisTickets"
    ManagedBy   = "Terraform"
  }
}
