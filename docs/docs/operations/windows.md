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
  Critical updates. Templates additionally ship an HTTPS listener on 5986 — see
  [Security baseline](#security-baseline).
- **vTPM.** `windows-desktop-11` ships `vm_vtpm = true` → the VM gets a Virtual
  TPM, which requires a vCenter **Native Key Provider** (present; check with
  `govc kms.ls`).
- **`--only` filter.** Datacenter would otherwise build the `dexp` and `core`
  sources together; the matrix `only` field restricts each build to the
  Desktop-Experience source.

## Security baseline

`ansible/roles/harden` carries what *every* Windows machine in the fleet should
have. It is a separate role on purpose: `base`, `configure`, `clean` and `users`
are vendored from upstream, so keeping our additions out of them means an
upstream sync has nothing to conflict with.

**The scope boundary matters.** Application software must not go into a
template. Templates rebuild weekly, and a stateful application with databases,
licences and configuration cannot be meaningfully baked into a golden image.
The template hands over a correctly-configured, hardened OS; anything that makes
one box a particular application server belongs in that VM's own repository
(`LukeEvansTech/veeam-config` is the reference pattern).

| Layer | Scope | Lives in |
| --- | --- | --- |
| Template Ansible (bake time) | What every Windows Server should have | this repo, `ansible/roles/harden` |
| Per-VM Ansible (deploy time) | What makes one box an application server | e.g. `LukeEvansTech/veeam-config` |

### WinRM over HTTPS

Templates previously shipped a 5985 (HTTP) listener only, so every cloned VM
carried credentials and remote-management traffic across the LAN in plaintext.

The listener **cannot be baked into the template**. A certificate generated
during the build would carry the *build VM's* name, and every clone is renamed
by vSphere guest customisation — so the certificate would be wrong on all of
them, and every VM in the fleet would share one private key.

Instead the template ships `C:\ProgramData\PackerTemplate\Initialize-WinRMHttps.ps1`
and an `Initialize-WinRMHttps` scheduled task. The script:

- runs **at boot** (60s delay) and **daily at 03:00**;
- is idempotent — a no-op once the listener's certificate covers the current
  hostname and is outside the 30-day renewal window;
- regenerates the certificate when the machine is renamed, which is exactly what
  guest customisation does on first clone;
- deletes only certificates it created (matched on friendly name), so an
  operator- or application-installed certificate is never touched;
- **exits 0 unconditionally.** It runs at boot; a hardening step must never
  block a machine from starting. Failures land in
  `C:\ProgramData\PackerTemplate\Initialize-WinRMHttps.log`.

The build runs it once so a broken script fails in the Packer log rather than
silently leaving every future clone without HTTPS, and the Ansible run then
asserts the listener actually exists.

**5985 is deliberately left enabled.** Packer's own provisioning — including the
Ansible run that installs this script — connects over it, so removing it during
the build would break the build itself. Disabling plaintext is a deploy-time
decision, not one to bake into the template every Windows VM is cloned from. The
lever exists when you want it:

```yaml
harden_winrm_disable_http_listener: true
```

The script refuses to remove the HTTP listener unless an HTTPS listener is
actually present, so flipping this cannot lock a machine out of remote
management.

### PowerShell 7

Windows ships Windows PowerShell 5.1 only, and modern tooling increasingly
assumes 7+ (Veeam 13's PowerShell module is the case that surfaced this). The
MSI is installed from the pinned version in `ansible/roles/harden/defaults/main.yml`.

`harden_powershell_version` and `harden_powershell_msi_sha256` are a **matched
pair — bump both together**, or the checksum check fails the build:

```bash
curl -sLO https://github.com/PowerShell/PowerShell/releases/download/v<X>/PowerShell-<X>-win-x64.msi
sha256sum PowerShell-<X>-win-x64.msi
```

Renovate does not track this pin (it is a plain Ansible var, not a manifest
entry), so it is a manual bump.

### Verifying on a clone

```powershell
Test-NetConnection <vm> -Port 5986
Get-ChildItem WSMan:\localhost\Listener          # on the guest
& 'C:\Program Files\PowerShell\7\pwsh.exe' -Version
```

The certificate is self-signed, so a remote session needs to skip CA
validation:

```powershell
$so = New-PSSessionOption -SkipCACheck
Enter-PSSession -ComputerName <vm> -UseSSL -SessionOption $so -Credential (Get-Credential)
```

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
