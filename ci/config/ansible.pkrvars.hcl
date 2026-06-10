/*
    CI config — ansible guest account (second local account baked into the
    template). The matching PRIVATE key lives in 1Password
    (op://Talos/vsphere-packer/ANSIBLE_PRIVATE_KEY). Packer's SSH communicator
    connects as build_username through Packer's SSH proxy — it does NOT
    authenticate with this key. The ansible role only writes the public key
    into the template's authorized_keys for post-deployment access.
*/

ansible_username = "ansible"
ansible_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSvh5B1O5OQsu5NN9uU2AyhRwxWUUdfeEg3C6JIbV8M ansible@codelooks.com"
