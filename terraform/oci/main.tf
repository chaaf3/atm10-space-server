data "oci_identity_availability_domains" "available" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  availability_domain = data.oci_identity_availability_domains.available.availability_domains[var.availability_domain_index].name

  common_tags = merge(var.freeform_tags, {
    Project = var.name
  })

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    provision_script_b64 = filebase64("${path.module}/../../scripts/provision-atm10.sh")
    atm10_version        = var.atm10_version
    atm10_server_zip_url = var.atm10_server_zip_url
    minecraft_whitelist  = join(",", var.minecraft_whitelist)
    memory_min           = var.memory_min
    memory_max           = var.memory_max
    motd                 = var.motd
  })
}

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr_block
  display_name   = "${var.name}-vcn"
  dns_label      = "atm10space"
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name}-igw"
  enabled        = true
  freeform_tags  = local.common_tags
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name}-public-rt"
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_security_list" "minecraft" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name}-security-list"
  freeform_tags  = local.common_tags

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  dynamic "ingress_security_rules" {
    for_each = var.allowed_minecraft_cidr_blocks

    content {
      description = "Minecraft"
      protocol    = "6"
      source      = ingress_security_rules.value

      tcp_options {
        min = 25565
        max = 25565
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.ssh_cidr_blocks

    content {
      description = "SSH"
      protocol    = "6"
      source      = ingress_security_rules.value

      tcp_options {
        min = 22
        max = 22
      }
    }
  }
}

resource "oci_core_subnet" "public" {
  availability_domain        = local.availability_domain
  cidr_block                 = var.subnet_cidr_block
  compartment_id             = var.compartment_ocid
  display_name               = "${var.name}-public-subnet"
  dns_label                  = "mc"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.minecraft.id]
  vcn_id                     = oci_core_vcn.main.id
  freeform_tags              = local.common_tags
}

resource "oci_core_instance" "server" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = var.name
  shape               = var.instance_shape
  freeform_tags       = local.common_tags

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gb
  }

  create_vnic_details {
    assign_public_ip = true
    display_name     = "${var.name}-vnic"
    hostname_label   = "server"
    subnet_id        = oci_core_subnet.public.id
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(var.ssh_public_key_path))
    user_data           = base64encode(local.user_data)
  }

  source_details {
    source_id               = data.oci_core_images.ubuntu.images[0].id
    source_type             = "image"
    boot_volume_size_in_gbs = var.boot_volume_size_gb
    boot_volume_vpus_per_gb = var.boot_volume_vpus_per_gb
  }
}

data "oci_core_vnic_attachments" "server" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.server.id
}

data "oci_core_vnic" "server" {
  vnic_id = data.oci_core_vnic_attachments.server.vnic_attachments[0].vnic_id
}
