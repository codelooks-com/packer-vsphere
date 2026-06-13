<!-- markdownlint-disable first-line-h1 no-inline-html -->

<img src="docs/docs/assets/images/icon-color.svg" alt="vSphere" width="120">

# Packer vSphere Golden Images

A fork of [`vmware/packer-examples-for-vsphere`][upstream], customised to build
multi-OS golden-image templates on the Talos cluster's **ephemeral ARC runners**
(no pinned build VM). Templates are consumed downstream by
`codelooks-com/terraform-vsphere`.

## What it builds

Nine template lines build on a weekly schedule (and on demand), each converted to
a vSphere template, patched at build time, and promoted into the `Templates/`
folder with a one-generation `-prev` rollback:

| Family | Lines |
|:--|:--|
| **Linux** | Ubuntu 24.04 / 22.04 · Debian 12 / 13 · Rocky 9 · AlmaLinux 9 |
| **Windows** | Server 2025 & 2022 (Datacenter, Desktop Experience) · Windows 11 (Enterprise) |

The vendored engine supports many more OSes; `ci/matrix.json` is the single
source of truth for the lines we actually build.

## How it works

`ci/matrix.json` → `build-templates.yml` (GitHub Actions) → an ARC runner pod
running the `ghcr.io/codelooks-com/packer-runner` image → `build.sh` →
`packer vsphere-iso` → Ansible provisioning → convert + promote.

Build target: **vSAN Cluster** · `vsanDatastore` · `VM Network` · `Templates`
folder · SSO domain `core.codelooks.com`.

## Documentation

Internal docs live in [`docs/`](docs/) and are built with
[Zensical](https://zensical.org/) — **not published**, build/preview locally:

```bash
cd docs
pip install -r requirements.txt
zensical serve   # http://localhost:8000
```

Start with the [Architecture & Pipeline](docs/docs/operations/architecture.md)
and [Windows Templates](docs/docs/operations/windows.md) pages.

## Upstream & License

Based on [`vmware/packer-examples-for-vsphere`][upstream] (tracked via
`upstream/develop` → `main`). Provided under the Simplified BSD License.

© Broadcom. All Rights Reserved. The term “Broadcom” refers to Broadcom Inc.
and/or its subsidiaries.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the conditions of the [BSD-2-Clause license](docs/docs/license.md)
are met. THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND.

[upstream]: https://github.com/vmware/packer-examples-for-vsphere
