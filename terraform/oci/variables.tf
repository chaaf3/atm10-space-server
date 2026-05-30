variable "config_file_profile" {
  description = "OCI CLI config profile to use from ~/.oci/config."
  type        = string
  default     = "DEFAULT"
}

variable "auth" {
  description = "OCI provider auth mode. Use SecurityToken for browser-based OCI CLI sessions or APIKey for normal ~/.oci/config API keys."
  type        = string
  default     = "APIKey"
}

variable "region" {
  description = "OCI region identifier, for example us-ashburn-1."
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID. Used to look up availability domains."
  type        = string
}

variable "user_ocid" {
  description = "OCI user OCID for API-key authentication."
  type        = string
  default     = null
}

variable "fingerprint" {
  description = "Fingerprint for the OCI API signing public key uploaded to the user."
  type        = string
  default     = null
}

variable "private_key_path" {
  description = "Local path to the OCI API signing private key."
  type        = string
  default     = "~/.oci/atm10_oci_api_key.pem"
}

variable "compartment_ocid" {
  description = "OCI compartment OCID where resources should be created."
  type        = string
}

variable "availability_domain_index" {
  description = "Zero-based availability domain index. Try another index if Oracle reports A1 capacity unavailable."
  type        = number
  default     = 0
}

variable "name" {
  description = "Name prefix for OCI resources."
  type        = string
  default     = "atm10-space"
}

variable "instance_shape" {
  description = "OCI compute shape."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "Fixed OCPU count for the server. Guardrail caps this at the approved 6 OCPU ceiling."
  type        = number
  default     = 6

  validation {
    condition     = var.ocpus >= 1 && var.ocpus <= 6
    error_message = "Server capacity is locked: ocpus must stay between 1 and the approved 6 OCPU ceiling."
  }
}

variable "memory_gb" {
  description = "Fixed memory in GB for the server. Guardrail caps this at the approved 48 GB ceiling."
  type        = number
  default     = 48

  validation {
    condition     = var.memory_gb >= 6 && var.memory_gb <= 48
    error_message = "Server capacity is locked: memory_gb must stay between 6 and the approved 48 GB ceiling."
  }
}

variable "boot_volume_size_gb" {
  description = "Fixed boot volume size in GB. The server installs under /opt/atm10 on this volume."
  type        = number
  default     = 500

  validation {
    condition     = var.boot_volume_size_gb >= 50 && var.boot_volume_size_gb <= 500
    error_message = "Server capacity is locked: boot_volume_size_gb must stay between 50 and the approved 500 GB ceiling."
  }
}

variable "boot_volume_vpus_per_gb" {
  description = "OCI boot volume performance units per GB. 10 is Balanced."
  type        = number
  default     = 10
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key Terraform should install on the instance."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the instance. Prefer your public IP as x.x.x.x/32."
  type        = list(string)
}

variable "allowed_minecraft_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Minecraft TCP/25565."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vcn_cidr_block" {
  description = "VCN CIDR block."
  type        = string
  default     = "10.42.0.0/16"
}

variable "subnet_cidr_block" {
  description = "Public subnet CIDR block."
  type        = string
  default     = "10.42.1.0/24"
}

variable "atm10_version" {
  description = "ATM10 server pack version marker."
  type        = string
  default     = "7.0"
}

variable "atm10_server_zip_url" {
  description = "Direct URL for the ATM10 server files zip."
  type        = string
  default     = "https://edge.forgecdn.net/files/8094/893/ServerFiles-7.0.zip"
}

variable "memory_min" {
  description = "Minimum JVM heap size for the server."
  type        = string
  default     = "16G"
}

variable "memory_max" {
  description = "Maximum JVM heap size for the server."
  type        = string
  default     = "20G"
}

variable "motd" {
  description = "Minecraft server MOTD."
  type        = string
  default     = "ATM10 + Stellaris Space Server"
}

variable "minecraft_whitelist" {
  description = "Minecraft account names allowed to join. The server enforces this list with online-mode UUIDs."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for name in var.minecraft_whitelist : can(regex("^[A-Za-z0-9_]{3,16}$", name))])
    error_message = "Minecraft whitelist names must be 3-16 characters and contain only letters, numbers, and underscores."
  }
}

variable "freeform_tags" {
  description = "Extra OCI freeform tags."
  type        = map(string)
  default     = {}
}
