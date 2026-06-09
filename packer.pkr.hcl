/*
  Root-level packer block so `packer init .` can pre-install plugins
  inside the runner image.  Full build configs live under builds/.
*/

packer {
  required_version = ">= 1.15.0"
  required_plugins {
    vsphere = {
      source  = "github.com/vmware/vsphere"
      version = ">= 2.1.1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.4"
    }
    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.6.5"
    }
  }
}
