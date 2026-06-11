/*
    CI config — Windows 11 Desktop build (Enterprise source only).
    Keys are PUBLIC Microsoft GVLK client keys — activation happens against
    a KMS host at clone time, not at build.
    Both edition keys must hold values: all sources' locals interpolate
    eagerly even when -only excludes them.
    iso_file is set to the user's licensed media filename (Task 2).
*/

// Installation Operating System Metadata
vm_inst_os_key_pro = "W269N-WFGWX-YVC9B-4J6C9-T83GX"
vm_inst_os_key_ent = "NPPR9-FWDCX-D2C8J-H872K-2YT43"

// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "windows9_64Guest"

// Virtual Machine Hardware Settings
vm_firmware = "efi-secure"

// Removable Media Settings
iso_datastore_path       = "iso/windows/windows-desktop/11/amd64"
iso_content_library_item = "windows-desktop-11"
iso_file                 = "windows-desktop-11.iso"
