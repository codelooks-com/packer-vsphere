/*
    CI config — common build behavior. This file encodes three design decisions:
    - common_data_source = "disk": install config delivered on a cidata CD-ROM,
      so the runner pod needs NO inbound networking (spec decision #7).
    - Folder-template output (common_template_conversion = true), NOT Content
      Library output — svc-packer lacks the global permission Content Library
      operations require (403).
    - ISO read from a DATASTORE path, not the Content Library, for the same 403
      reason. common_iso_content_library must still hold a value because the
      build's locals interpolate it eagerly even when unused.
*/

// Virtual Machine Settings
common_vm_version           = 21
common_tools_upgrade_policy = true
common_remove_cdrom         = true

// Template and Content Library Settings
common_template_conversion     = true
common_content_library_enabled = false

// Removable Media Settings
common_iso_datastore               = "vsanDatastore"
common_iso_content_library         = "Content Library"
common_iso_content_library_enabled = false

// Boot and Provisioning Settings
common_data_source = "disk"
// http ports are unused with data_source=disk but the vars have no defaults
common_http_port_min    = 8000
common_http_port_max    = 8099
common_ip_wait_timeout  = "20m"
common_shutdown_timeout = "15m"
