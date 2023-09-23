resource "vultr_ssh_key" "node" {
  name    = "${var.region} ${var.color} key"
  ssh_key = file("~/.ssh/id_rsa_vultr.pub")
}

resource "vultr_firewall_group" "node" {}

resource "vultr_firewall_rule" "node" {
  for_each = toset(var.firewall_allow_ports)

  port              = each.value
  firewall_group_id = vultr_firewall_group.node.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
}

resource "vultr_instance" "node" {
  plan              = "voc-c-8c-16gb-300s-amd"
  region            = var.region
  os_id             = 1743 # Ubuntu 22.04 LTS x64
  hostname          = "RadixNode${var.color}-${var.env}-${var.region}"
  enable_ipv6       = false
  backups           = "disabled"
  ddos_protection   = false
  activation_email  = false
  firewall_group_id = vultr_firewall_group.node.id
  ssh_key_ids       = [vultr_ssh_key.node.id]
  label             = "RadixNode${var.color}"
  tags              = ["Babylon"]
}