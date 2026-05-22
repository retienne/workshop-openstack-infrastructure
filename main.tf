terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {
  # Configuration is typically read from standard OS_ environment variables
}

locals {
  vars = yamldecode(file("${path.module}/ansible/group_vars/all.yml"))
}

resource "openstack_compute_keypair_v2" "workshop_key" {
  name       = local.vars.openstack_keypair
  public_key = file("${path.module}/.ssh/id_rsa_workshop.pub")
}

resource "openstack_networking_secgroup_v2" "workshop_sg" {
  name        = "workshop-sg"
  description = "Security group for modern database workshop"
}

resource "openstack_networking_secgroup_rule_v2" "workshop_sg_rule_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.workshop_sg.id
}

data "openstack_images_image_v2" "ubuntu" {
  name        = local.vars.openstack_image
  most_recent = true
}

resource "openstack_compute_instance_v2" "workshop_instance" {
  name            = "dataplatform-workshop"
  flavor_name     = local.vars.openstack_flavor
  key_pair        = local.vars.openstack_keypair
  security_groups = [openstack_networking_secgroup_v2.workshop_sg.name]

  network {
    name = local.vars.openstack_network_name
  }

  block_device {
    uuid                  = data.openstack_images_image_v2.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
    volume_size           = 80
  }
}

output "instance_ip" {
  value = openstack_compute_instance_v2.workshop_instance.access_ip_v4
}

output "instance_id" {
  value = openstack_compute_instance_v2.workshop_instance.id
}
