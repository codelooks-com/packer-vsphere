/*
    CI config — Ubuntu Server 24.04 LTS build.
    iso_datastore_path + iso_file must match the object uploaded to
    vsanDatastore (see the ISO staging step in the Plan 2 runbook).
    iso_content_library_item is unused (CL disabled) but must hold a value —
    the build's locals interpolate it eagerly.
*/

// Guest Operating System Metadata
vm_guest_os_name    = "ubuntu"
vm_guest_os_version = "24.04-lts"

// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "ubuntu64Guest"

// Virtual Machine Hardware Settings
vm_firmware = "efi-secure"

// Removable Media Settings
iso_datastore_path       = "iso/linux/ubuntu-server/24-04-lts/amd64"
iso_content_library_item = "ubuntu-24.04.4-live-server-amd64"
iso_file                 = "ubuntu-24.04.4-live-server-amd64.iso"
