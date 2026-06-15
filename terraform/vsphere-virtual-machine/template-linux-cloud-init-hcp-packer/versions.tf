##################################################################################
# VERSIONS
##################################################################################

terraform {
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.112.0"
    }
    vsphere = {
      source  = "vmware/vsphere"
      version = ">= 2.15.0"
    }
  }
  required_version = ">= 1.10.0"
}
