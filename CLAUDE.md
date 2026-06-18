# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A fork of [`vmware/packer-examples-for-vsphere`](https://github.com/vmware/packer-examples-for-vsphere)
that builds multi-OS golden-image vSphere templates on the Talos cluster's
**ephemeral ARC (Actions Runner Controller) runners** — no pinned build VM.
Templates are consumed downstream by `codelooks-com/terraform-vsphere`. Docs are
published at <https://codelooks-com.github.io/packer-vsphere/>.

## Single source of truth: `ci/matrix.json`

`ci/matrix.json` defines exactly which OS lines the project builds (9: six Linux
with a `discover` block for ISO auto-bumping, three Windows with manual media).
Each entry's `key` (e.g. `ubuntu-2404`, `debian-12`, `windows-server-2025`) is
reused verbatim as the `os` choice input of the `build-templates` and
`upload-isos` workflows — keep them in sync. The vendored engine supports many
more OSes; the matrix is what we actually build.

## CI pipeline (`.github/workflows/`)

- **`build-templates.yml`** — weekly (Sat 02:00 UTC) + manual dispatch. A `plan`
  job filters the matrix; a `build` job on the self-hosted `packer-vsphere` ARC
  runner runs `build.sh --ci` → `packer vsphere-iso` → Ansible → converts the VM
  to `<base>-build` → **promote** renames it to the stable `<base>` Terraform
  clones and rolls the prior generation to `<base>-prev` (success-only).
- **`check-iso-updates.yml`** — weekly (Mon 06:00 UTC). `ci/scripts/check_iso_updates.py`
  detects new Linux point releases and **commits the bump straight to `main`
  (no PR, no approval gate)**, then dispatches `upload-isos` for each bumped
  line. Do not "fix" this into a PR/merge-gate flow — it is intentional.
- **`upload-isos.yml`** — dispatch-only; downloads/verifies/uploads ISOs to the
  datastore from the self-hosted runner (`ci/scripts/upload-isos.sh`).
- **`validate.yml`** — `packer fmt -check` + `packer validate` (all matrix lines)
  on PRs **and** pushes to `main` (path-filtered).
- **`docs.yml`** — builds the Zensical site on PRs, deploys to GitHub Pages on
  push to `main`.
- **`lint.yml`** (super-linter), **`security-scans.yaml`** (Checkov + Trivy),
  **`build-runner-image.yml`**, **`release.yml`**.

## Runner image & tooling

The runner image `ghcr.io/codelooks-com/packer-runner` (`runner/Dockerfile`) is
digest-pinned and runs as an ARC scale-set pod defined in
`LukeEvansTech/talos-cluster` (min 0 / max 3). **`.mise.toml` is the single
source of truth for tool versions** (packer, ansible-core, gomplate, terraform,
jq, govc, goss, gh) and pins the runner image too — keep them in lockstep.
Install locally with `mise install`. When a version changes (e.g. Renovate
bumps a tool), also update the `.mise.md` table by hand — super-linter only
lints changed files, so it will not flag the drift.

## Two config trees — do not confuse

- **`ci/config/*.pkrvars.hcl`** — the CI per-line var-files referenced by
  `ci/matrix.json`. This is what the pipeline builds from.
- **`config/`** — created by `./config.sh` from `builds/*.example` for **local**
  `./build.sh` runs only.

## Common commands

```bash
mise install                              # install pinned toolchain

# Local build (vendored upstream path)
./build.sh                                # interactive menu
./build.sh --os Linux --dist "Ubuntu Server" --version "24.04 LTS" --auto-continue

# Template-render tests (Bats golden-file diffs; needs bats-core + packer)
cd tests/network && bats test            # also: cd tests/storage && bats test

python3 ci/scripts/check_iso_updates.py  # detect Linux ISO bumps locally

# Docs (Zensical site under docs/; make docs-serve / make docs-build wrap these)
cd docs && pip install -r requirements.txt && zensical serve   # preview
cd docs && zensical build                                       # build to docs/site

# Drive CI
gh workflow run build-templates.yml -f os=ubuntu-2404
gh workflow run upload-isos.yml -f os=debian-12
```

`zensical` must be **>= 0.0.45**; older releases silently render `mermaid` fenced
blocks and other `pymdownx.superfences` custom fences as literal code blocks.

## Conventions & gotchas

- **Vendored upstream files carry minimal surgical diffs** and are excluded from
  house-style lint: `build.sh`, `download.sh`, `config.sh`, `set-envvars.sh`,
  `config/`, `*.pkrtpl.hcl`, and `docs/` (the docs site is validated by
  `zensical build`, not super-linter).
- **super-linter only checks changed, non-excluded files.** Root Markdown
  (`README.md`, `.mise.md`) gets prettier **and** textlint terminology rules
  (e.g. `Git`, not `git`).
- **Renovate** (`.renovaterc.json5`) extends the shared
  `github>LukeEvansTech/renovate-config` preset and is written in `json5`.
  super-linter lints it through prettier's json5 parser (inferred from the
  extension), which wants **unquoted keys + a trailing comma** — run
  `prettier --write .renovaterc.json5` after editing, or `JSONC_PRETTIER`
  fails. The preset enables `docker:pinDigests`; the self-built
  `ghcr.io/codelooks-com/packer-runner` image is excluded via `packageRules`
  because it is a build/push target, not a pulled dependency (a digest there
  would make `${IMAGE}:latest` in `build-runner-image.yml` an invalid ref).
- **`gh` may resolve to the upstream `vmware` remote** — pass
  `-R codelooks-com/packer-vsphere` or run `gh repo set-default`.
- **Scheduled workflows**: GitHub cron is best-effort (often delayed) and
  auto-disables after ~60 days of repository inactivity.
- **Docs scope**: `docs/docs/operations/` + `runbooks/` document _our_ pipeline;
  `getting-started/` is the upstream local-build reference.
- **Windows builds** have hard-won, documented gotchas (`vm_inst_os_eval=false`
  for GVLK, `ansible_shell_type=cmd`, `win_updates` reboot handling, vTPM Native
  Key Provider, 60m `ip_wait_timeout`) — see `docs/docs/operations/windows.md`.
- **Credentials** live in 1Password → External Secrets in the cluster; rotation
  is manual (`docs/docs/runbooks/rotate-credentials.md`). Build target: vSAN
  Cluster · `vsanDatastore` · `VM Network` · `Templates` folder; SSO domain
  `core.codelooks.com`.
