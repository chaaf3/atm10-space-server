variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for AWS resources."
  type        = string
  default     = "atm10-space"
}

variable "instance_type" {
  description = "EC2 instance type. Use m7a.2xlarge or larger for busier servers."
  type        = string
  default     = "m7a.xlarge"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key Terraform should install on the instance."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the instance. Prefer your public IP as x.x.x.x/32."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_minecraft_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Minecraft TCP/25565."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "volume_size_gb" {
  description = "Root disk size in GB."
  type        = number
  default     = 150
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
  default     = "8G"
}

variable "memory_max" {
  description = "Maximum JVM heap size for the server."
  type        = string
  default     = "12G"
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

variable "tags" {
  description = "Extra AWS tags."
  type        = map(string)
  default     = {}
}
