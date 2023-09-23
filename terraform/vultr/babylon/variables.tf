variable "region" {
  type = string
  default=""
  nullable = false
  description="The vultr region the node should be setup in. See https://www.vultr.com/api/#operation/list-regions"
}

variable "color" {
  type = string
  nullable = false
}

variable "env" {
  default = "prod"
  nullable = false
}

variable "vultr_api_key" {
  type      = string
  sensitive = true
  nullable = false
}

variable "firewall_allow_ports" {
  default = ["22", "443", "30000", "3000"]
  nullable = false
}

