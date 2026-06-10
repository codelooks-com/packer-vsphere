# Credential rotation runbook

On-demand rotation for the three credential sets the pipeline depends on.
No automation by design: nothing in the cluster holds 1Password write
access. Commands never echo secret values — pipe `op read` straight into
consumers. Run from a machine with `op` (signed in), `mise`, and `gh`.

After any 1Password change, the runner pods pick it up via External
Secrets on its refresh interval; to force it immediately:

```bash
export KUBECONFIG=~/GIT/LukeEvansTech/talos-cluster/kubeconfig
kubectl annotate externalsecret -n actions-runner-system packer-vsphere-creds \
  force-sync=$(date +%s) --overwrite
```

(The runner registration secret uses ExternalSecret `packer-runner`; rotate
that one the same way after updating `github-codelooks` in 1Password.)

## 1. svc-packer vSphere SSO password

Constraints: SSO policy (domain `core.codelooks.com`) — max 20 chars, needs
upper/lower/digit/special.

```bash
# generate (16 chars + 4-char suffix = 20, policy-safe); never printed
NEW_PW="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 16)!Aa1"
export GOVC_URL="https://$(op read 'op://Talos/vsphere-packer/VSPHERE_ENDPOINT')"
export GOVC_USERNAME="$(op read 'op://Talos/vsphere-packer/VSPHERE_USERNAME')"
export GOVC_PASSWORD="$(op read 'op://Talos/vsphere-packer/VSPHERE_PASSWORD')"
export GOVC_INSECURE=true
mise exec "aqua:vmware/govmomi/govc@0.49.0" -- \
  govc sso.user.update -p "$NEW_PW" svc-packer
op item edit vsphere-packer --vault Talos "VSPHERE_PASSWORD=$NEW_PW"
unset NEW_PW
# verify: re-export GOVC_PASSWORD from op read, then `govc about`
```

Then force-sync the ExternalSecret (above) and dispatch a build to prove
the runner works:

```bash
gh workflow run build-templates --repo codelooks-com/packer-vsphere -f os=ubuntu-2404
```

## 2. BUILD_* credentials (in-guest packer user + ansible SSH keypair)

```bash
# password + its SHA-512 crypt for the autoinstall/kickstart user
NEW_PW="$(openssl rand -base64 18)"
NEW_HASH="$(openssl passwd -6 "$NEW_PW")"
op item edit vsphere-packer --vault Talos "BUILD_PASSWORD=$NEW_PW" \
  "BUILD_PASSWORD_ENCRYPTED=$NEW_HASH"
unset NEW_PW NEW_HASH

# ansible SSH keypair (public key -> BUILD_KEY, private -> escrow)
ssh-keygen -t ed25519 -N "" -C "packer-ansible" -f ~/.ssh/packer-ansible_ed25519
op item edit vsphere-packer --vault Talos \
  "BUILD_KEY=$(cat ~/.ssh/packer-ansible_ed25519.pub)"
op item edit vsphere-packer --vault Talos \
  "ANSIBLE_PRIVATE_KEY=$(cat ~/.ssh/packer-ansible_ed25519)"
```

Force-sync `packer-vsphere-creds`, then rebuild ALL lines (templates bake
the old key until rebuilt):

```bash
gh workflow run build-templates --repo codelooks-com/packer-vsphere -f os=all
```

## 3. GitHub App key (codelooks-arc-runner, App ID 4009320)

Web actions (the `gh` token lacks `admin:org`):

1. `github.com` → Settings → Developer settings → GitHub Apps →
   `codelooks-arc-runner` → generate a NEW private key (a `.pem` downloads).
1. Store it in 1Password (check the field label first):

```bash
op item get github-codelooks --vault Talos --format json \
  | jq -r '.fields[].label'
op item edit github-codelooks --vault Talos \
  "ACTIONS_RUNNER_PRIVATE_KEY=$(cat ~/Downloads/codelooks-arc-runner.*.private-key.pem)"
```

1. Force-sync the runner-registration ExternalSecret:

```bash
export KUBECONFIG=~/GIT/LukeEvansTech/talos-cluster/kubeconfig
kubectl annotate externalsecret -n actions-runner-system packer-runner \
  force-sync=$(date +%s) --overwrite
```

1. Wait for a runner pod to register (dispatch any job), THEN revoke the
   old key in the same App settings page. Delete the local `.pem`.

## Old-ISO cleanup (housekeeping, not a credential)

After an ISO bump PR merges and the new ISO is staged, delete the old one:

```bash
govc datastore.ls -ds vsanDatastore 'iso/linux/<os>/<ver>/amd64'
govc datastore.rm -ds vsanDatastore 'iso/linux/<os>/<ver>/amd64/<old-file>.iso'
```

A crashed upload may also leave a `.partial` object next to the ISO —
safe to delete the same way.
