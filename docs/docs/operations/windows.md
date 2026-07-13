# Windows Templates

The Windows lines (Server 2025 / 2022 Datacenter Desktop Experience, Windows 11
Enterprise) build on the same pipeline as Linux but with a different install and
provisioning path. This page documents that path and the gotchas that were
expensive to find.

## Build path

- **Licensed media (manual).** Windows ISOs are uploaded by hand to
  `vsanDatastore` under stable names (`iso/windows/.../windows-server-2025.iso`,
  etc.) so monthly media refreshes overwrite the same path without a config
  change. Configs live in `ci/config/windows-*.pkrvars.hcl`.
- **GVLK product keys.** Public KMS-client keys are committed in the configs
  (`vm_inst_os_key_*`). Activation happens against a KMS host at clone time, not
  during the build.
- **`autounattend.xml`** is rendered onto a `cidata` CD; the VMware Tools ISO
  comes from the ESXi product locker (`[] /vmimages/tools-isoimages/windows.iso`)
  — no staging.
- **WinRM 5985** is the Ansible connection; `win_updates` applies Security +
  Critical updates.
- **vTPM.** `windows-desktop-11` ships `vm_vtpm = true` → the VM gets a Virtual
  TPM, which requires a vCenter **Native Key Provider** (present; check with
  `govc kms.ls`).
- **`--only` filter.** Datacenter would otherwise build the `dexp` and `core`
  sources together; the matrix `only` field restricts each build to the
  Desktop-Experience source.

## Gotchas (in the order they bite)

These are all fixed in-repo now; the notes explain *why*, so a new Windows line
doesn't re-discover them.

1. **`vm_inst_os_eval = false` is mandatory for licensed builds.** The
   autounattend only writes the `<ProductKey>` (the GVLK) when this is `false`.
   It defaults to `true`, which drops the key — and Server 2025's redesigned
   Setup then stalls on the **"Choose a licensing method"** (Azure pay-as-you-go)
   screen forever, surfacing as *"timeout waiting for IP"*. Set it in each
   `ci/config/windows-*.pkrvars.hcl`.

2. **pywinrm on the control node — a pinned digest is necessary but not
   sufficient.** pywinrm is pip-installed into Ansible's own venv as a
   post-`mise install` Docker layer; Ansible's WinRM connection plugin imports it
   at runtime. If it is missing, every Windows leg fails ~7 min in with *"No
   module named 'winrm'"* (Linux uses SSH — unaffected). There are two
   independent ways it goes missing, each with its own defense:
   - **Stale cache** — a mutable `:latest` with no `imagePullPolicy` lets ARC
     nodes run an old image whose venv lacks pywinrm. Fixed by digest-pinning the
     image in the talos-cluster helmrelease.
   - **A pinned-but-broken image** — the 2026-06 outage: the pinned image *itself*
     lacked a working pywinrm (a `mise`/pipx venv reshuffle orphaned the graft),
     so the pin faithfully served a broken image and all Windows builds were red
     for two weeks. Now guarded by (a) installing pywinrm via the venv's own
     `python` in `runner/Dockerfile` (robust against shim/shebang drift) and
     (b) a **Preflight** step in `build-templates.yml` that imports `winrm`
     through Ansible's real interpreter before Packer starts — failing in seconds
     with a clear message instead of deep in a provisioning trace.

3. **`ansible_shell_type: cmd`** (set in `ansible/windows-playbook.yml`).
   ansible-core 2.21 + pywinrm 0.5 default the WinRM shell to `powershell`, which
   mangles the `-EncodedCommand` payload (*"not properly encoded"*) and fails at
   *Gathering Facts*. Ansible itself warns to use `cmd`.

4. **`win_updates` must survive the update reboot.** The reboot drops WinRM
   (*Connection refused*) and the async task's WS-Man shell goes stale
   (*InvalidSelectors*). Mitigations (shared playbook + `base` role): raise WinRM
   timeouts (`operation_timeout_sec=120` / `read_timeout_sec=150`), a
   pre-`win_reboot` to clear pending reboots, and `reboot_timeout=3600` on
   `win_updates`.

5. **`ip_wait_timeout` headroom.** Windows reports its IP only *after* install →
   first-logon VMware Tools, well past Linux's 20 min. The windows configs
   override `common_ip_wait_timeout = "60m"`.

6. **`ansible-galaxy` can hit a transient *"Network is unreachable"*.** Collections
   are baked into the image, so this is a one-off blip — retry. If it recurs,
   disable the provisioner's redundant galaxy re-download.

## Diagnosing a Windows build

The console screenshot is the fastest signal — it reveals a stuck Setup screen
that the run log mis-reports as an IP timeout:

```bash
# admin creds from the machine-local config/vsphere.pkrvars.hcl
govc vm.console -capture /tmp/shot.png windows-server-2025-datacenter-dexp-main-build
govc vm.info -json windows-server-2025-datacenter-dexp-main-build \
  | jq '.virtualMachines[0].guest | {ip: .ipAddress, tools: .toolsRunningStatus}'
```

A healthy run reaches a booted desktop/lock screen with a guest IP and
`guestToolsRunning` ~7–8 min in, then spends the bulk of its time in
`win_updates`.
