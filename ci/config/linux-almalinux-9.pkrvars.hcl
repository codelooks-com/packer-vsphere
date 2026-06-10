/*
    CI config — AlmaLinux OS 9 build.
    vm_guest_os_version pinned to the major version for a stable template
    name (linux-almalinux-9-main). vm_network_device=link: see rocky 9.
*/

// Guest Operating System Metadata
vm_guest_os_name    = "almalinux"
vm_guest_os_version = "9"

// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "almalinux_64Guest"

// Virtual Machine Hardware Settings
vm_firmware = "efi-secure"

// Network Settings
vm_network_device = "link"

// Removable Media Settings
iso_datastore_path       = "iso/linux/almalinux-os/9/amd64"
iso_content_library_item = "AlmaLinux-9.8-x86_64-dvd"
iso_file                 = "AlmaLinux-9.8-x86_64-dvd.iso"
