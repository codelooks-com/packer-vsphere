/*
    CI config — ansible guest account (second local account baked into the
    template). The matching PRIVATE key lives in 1Password
    (op://Talos/vsphere-packer/ANSIBLE_PRIVATE_KEY). Packer's ansible
    provisioner does NOT use this key at build time — it connects as
    build_username through Packer's SSH proxy.
*/

ansible_username = "ansible"
ansible_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSvh5B1O5OQsu5NN9uU2AyhRwxWUUdfeEg3C6JIbV8M ansible@codelooks.com"
