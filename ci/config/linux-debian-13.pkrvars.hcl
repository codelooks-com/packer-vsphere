/*
    CI config — Debian 13 (Trixie) build.
    vm_guest_os_version pinned to the major version for a stable template
    name (linux-debian-13-main). vm_network_device=auto: see debian 12.
    vm_guest_os_type per upstream example: vSphere has no debian13 guest id
    at vm_version 21, so other6xLinux64Guest.
*/

// Guest Operating System Metadata
vm_guest_os_name    = "debian"
vm_guest_os_version = "13"

// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "other6xLinux64Guest"

// Virtual Machine Hardware Settings
vm_firmware = "efi-secure"

// Network Settings
vm_network_device = "auto"

// Removable Media Settings
iso_datastore_path       = "iso/linux/debian/13/amd64"
iso_content_library_item = "debian-13.6.0-amd64-netinst"
iso_file                 = "debian-13.6.0-amd64-netinst.iso"
