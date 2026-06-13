# Architecture & Pipeline

How a golden image goes from `ci/matrix.json` to a promoted vSphere template.

## Components

| Piece | Where | Role |
|---|---|---|
| `ci/matrix.json` | this repo | Single source of truth — one entry per OS line. |
| `build-templates.yml` | `.github/workflows` | The build pipeline (weekly cron + manual dispatch). |
| `build.sh` | this repo | Wraps `packer init/validate/build` per OS line. |
| `packer-runner` image | `ghcr.io/codelooks-com/packer-runner` | Pinned toolchain (Packer, Ansible, govc, mise). |
| ARC scale set `packer-vsphere` | `LukeEvansTech/talos-cluster` | Ephemeral runner pods (`min 0 / max 3`). |
| `validate.yml` / `upload-isos.yml` | `.github/workflows` | PR validation of every entry; staging ISOs to the datastore. |

## The matrix

Each line in `ci/matrix.json` carries: `key`, `enabled`, `os`/`dist`/`version`,
`build_dir`, `config`, `base_name`, `iso_datastore_path`, and either ISO
discovery fields (`iso_url`/`sums_url`/`discover` for Linux) or manual-media
fields (Windows). Windows entries also carry `edition`, `only`
(restrict to one Packer source), and `timeout_minutes`.

The **plan** job filters the matrix:

```bash
jq -c --arg sel "$SELECTED" \
  '[ .[] | select((($sel == "all") and .enabled) or ($sel == .key)) ]' \
  ci/matrix.json
```

- A **named dispatch key** (`-f os=windows-server-2025`) builds exactly that
  line — even one shipped `enabled: false`.
- **`all`** / the weekly cron build every line with `enabled: true`.

## Scheduling

- **Build:** weekly, Saturday **02:00 UTC** (`build-templates.yml`), `all`
  enabled lines, `max-parallel: 2` (at most two build VMs hold a DHCP lease at
  once). Runs serialize via the `build-templates` concurrency group.
- **ISO currency:** `check-iso-updates.yml`, Monday **06:00 UTC** — opens a PR
  when a newer Linux ISO is published (discovery via the matrix `discover` block).

## Build flow

1. **Runner spins up** — ARC scales the `packer-vsphere` set from 0; the pod
   runs the `packer-runner` image (digest-pinned in talos-cluster).
2. **`build.sh`** derives the per-OS var-files and runs `packer build` for the
   matrix entry (Windows uses `--edition` + `--only` to build a single source).
3. **Install** — media is mounted from the datastore as a CD
   (`common_data_source=disk`); the guest installs unattended (cloud-init /
   kickstart / preseed for Linux, `autounattend.xml` on a cidata CD for Windows).
   The pod needs only **egress** (vCenter 443, SSH 22 / WinRM 5985) — no inbound.
4. **Provision** — the Ansible provisioner connects (SSH for Linux, WinRM for
   Windows), applies updates and base config.
5. **Convert + promote** — Packer converts the VM to a template named
   `<base>-build`; the **promote** step renames it into the stable `<base>` that
   Terraform clones, rolling the previous generation to `<base>-prev`:

   ```text
   <base>-prev   (deleted)
   <base>        → <base>-prev   (rollback kept)
   <base>-build  → <base>        (new template live)
   ```

   Success-only: a failed build never touches the stable `<base>`.

## Triage tooling

- **Console screenshots** (the decisive tool): `govc vm.console -capture out.png
  <vm>` as **administrator** (the `svc-packer` service account lacks
  console-interact). Run while the build is in flight.
- **Guest state:** `govc vm.info -json <vm>` →
  `runtime.powerState` / `guest.ipAddress` / `guest.toolsRunningStatus`.
- **Packer log:** `PACKER_LOG=1` writes `packer-build.log`, uploaded as a
  (secret-scrubbed) artifact on failure only.

See **[Windows Templates](windows.md)** for the Windows-specific path and its
gotchas.
