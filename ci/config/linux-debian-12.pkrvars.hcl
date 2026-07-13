/*
    CI config — Debian 12 (Bookworm) build.
    vm_guest_os_version is pinned to the major version: it feeds the
    template name (linux-debian-12-main), which must stay stable across
    point releases for Terraform consumers.
    vm_network_device feeds preseed netcfg/choose_interface: "auto" makes
    the installer pick the live NIC (ens33 in this vCenter — PCI slot 33 —
    not the engine-default ens192).
*/

// Guest Operating System Metadata
vm_guest_os_name    = "debian"
vm_guest_os_version = "12"

// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "debian12_64Guest"

// Virtual Machine Hardware Settings
vm_firmware = "efi-secure"

// Network Settings
vm_network_device = "auto"

// Removable Media Settings
iso_datastore_path       = "iso/linux/debian/12/amd64"
iso_content_library_item = "debian-12.15.0-amd64-netinst"
iso_file                 = "debian-12.15.0-amd64-netinst.iso"
