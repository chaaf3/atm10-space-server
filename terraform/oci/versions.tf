terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  auth                = var.auth
  config_file_profile = var.config_file_profile
  fingerprint         = var.fingerprint
  private_key_path    = var.private_key_path
  region              = var.region
  tenancy_ocid        = var.tenancy_ocid
  user_ocid           = var.user_ocid
}
