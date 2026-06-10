/*
    CI config — Rocky Linux 9 build.
    vm_guest_os_version pinned to the major version for a stable template
    name (linux-rocky-9-main). vm_network_device feeds kickstart's
    'network --device=': "link" selects the first NIC with link up (the
    guest names ours ens33 — PCI slot 33 — not the engine-default ens192).
    vm_firmware "efi" (not efi-secure) per the upstream example.
*/

// Guest Operating System Metadata
vm_guest_os_name    = "rocky"
vm_guest_os_version = "9"

// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "rockylinux_64Guest"

// Virtual Machine Hardware Settings
vm_firmware = "efi"

// Network Settings
vm_network_device = "link"

// Removable Media Settings
iso_datastore_path       = "iso/linux/rocky-linux/9/amd64"
iso_content_library_item = "Rocky-9.8-x86_64-dvd"
iso_file                 = "Rocky-9.8-x86_64-dvd.iso"
