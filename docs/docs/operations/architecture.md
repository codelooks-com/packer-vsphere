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
| `validate.yml` / `upload-isos.yml` | `.github/workflows` | `packer validate` every entry (PRs + pushes to `main`); staging ISOs to the datastore. |

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
- **ISO currency:** `check-iso-updates.yml`, Monday **06:00 UTC** — when a newer
  Linux point release is published (discovery via the matrix `discover` block),
  it commits the `iso_url`/`sums_url` + `iso_file` bump **straight to `main`**
  (no PR, no approval gate) and dispatches `upload-isos` for each bumped line, so
  the datastore is staged before Saturday's rebuild. `validate.yml` re-runs
  `packer validate` on the push to `main`, so the bump is still checked.

!!! note "GitHub scheduler caveats"
    Neither is an approval gate, but both affect unattended runs:

    - **Timing is best-effort.** Cron is frequently delayed under load — runs
      have started hours after the nominal time. Don't rely on the exact minute.
    - **60-day auto-disable.** GitHub disables scheduled workflows after ~60 days
      with no repository activity; re-enable from the **Actions** tab if it
      happens. The Monday ISO commit to `main` normally keeps the repo active
      enough to prevent this.

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

   ```mermaid
   flowchart TB
       S1["destroy &lt;base&gt;-prev<br>(old rollback)"]
       S2["rename &lt;base&gt; → &lt;base&gt;-prev<br>(rollback kept)"]
       S3["rename &lt;base&gt;-build → &lt;base&gt;<br>(new template live)"]
       S1 --> S2 --> S3
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
