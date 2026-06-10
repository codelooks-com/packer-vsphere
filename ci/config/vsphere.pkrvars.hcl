/*
    CI config — vSphere.
    INTENTIONALLY contains no credentials or placement values: vsphere_endpoint,
    vsphere_username, vsphere_password, vsphere_insecure_connection,
    vsphere_datacenter, vsphere_cluster, vsphere_datastore, vsphere_network and
    vsphere_folder all arrive as PKR_VAR_* env from 1Password (External Secrets
    on the runner pod). A key present here would silently override that env —
    Packer precedence puts -var-file ABOVE environment variables. Do not add keys.
*/

vsphere_set_host_for_datastore_uploads = false
