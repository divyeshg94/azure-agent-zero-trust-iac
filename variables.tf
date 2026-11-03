variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region. Pick one where your chosen model is available."
  type        = string
  default     = "eastus2"
}

variable "prefix" {
  description = "Short prefix for resource names (lowercase letters and numbers)."
  type        = string
  default     = "agent"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.prefix))
    error_message = "prefix must be 3 to 10 lowercase letters or numbers."
  }
}

variable "vnet_address_space" {
  description = "Address space for the virtual network. Must be RFC 1918."
  type        = string
  default     = "10.40.0.0/16"
}

variable "model_name" {
  description = "Model to deploy. Check availability with: az cognitiveservices model list --location <region>"
  type        = string
  default     = "gpt-4.1-mini"
}

variable "model_version" {
  description = "Model version. Leave null to use the current default version."
  type        = string
  default     = null
}

variable "model_sku" {
  description = "Deployment SKU, for example GlobalStandard or DataZoneStandard."
  type        = string
  default     = "GlobalStandard"
}

variable "model_capacity" {
  description = "Capacity in thousands of tokens per minute."
  type        = number
  default     = 10
}

variable "container_image" {
  description = "Agent container image. The default is a hello-world placeholder."
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "internal_only" {
  description = "When true, the agent is reachable only from inside the virtual network."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
