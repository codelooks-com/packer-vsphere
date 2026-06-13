/*
    CI config — Windows Server 2025 build (datacenter-dexp source only via
    the matrix 'only' filter). Keys are PUBLIC Microsoft GVLK client keys —
    activation happens against a KMS host at clone time, not at build.
    Both edition keys must hold values: all sources' locals interpolate
    eagerly even when -only excludes them.
    iso_file is set to the user's licensed media filename (Task 2).
*/

// Installation Operating System Metadata
vm_inst_os_key_standard   = "TVRH6-WHNXV-R9WG3-9XRFY-MY832"
vm_inst_os_key_datacenter = "D764K-2NDRG-47T6Q-P8T8W-YP6DF"

// Licensed install (NOT evaluation). The autounattend only writes the
// <ProductKey> (the GVLK above) when this is false; at the default (true)
// the key is omitted and Server 2025's new Setup stalls at the
// "Choose a licensing method" screen waiting for product-key input.
vm_inst_os_eval = false

// Virtual Machine Guest Operating System Setting
vm_guest_os_type = "windows2022srvNext_64Guest"

// Virtual Machine Hardware Settings
vm_firmware = "efi-secure"

// Boot/Provisioning Timing Override
// Windows reports its IP only after install + the first-logon VMware Tools
// setup (much later than Linux cloud-init), so the shared 20m
// common_ip_wait_timeout (ci/config/common.pkrvars.hcl) times out. Per-OS
// var-files load AFTER common.pkrvars.hcl, so this overrides it for Windows
// builds only.
common_ip_wait_timeout = "60m"

// Removable Media Settings
iso_datastore_path       = "iso/windows/windows-server/2025/amd64"
iso_content_library_item = "windows-server-2025"
iso_file                 = "windows-server-2025.iso"
