terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.15.1"
    }
  }
}

# Set env var VULTR_API_KEY
provider "vultr" {
  api_key     = var.vultr_api_key
  retry_limit = 3
  rate_limit = 100
}