---
icon: octicons/verified-24
---

# Environment Requirements

!!! note "Upstream local-build reference"

    The **Getting Started** pages cover the **local / manual** build path
    (`./build.sh`, `./download.sh`) inherited from upstream and span more
    operating systems than we build. Day-to-day, golden images are produced by
    the **CI pipeline** — see
    [Operations → Architecture & Pipeline](../operations/architecture.md).

## :octicons-cloud-24: &nbsp; Platform

The project is tested on the following platforms:

::spantable::
| Platform        | Version                |
| --------------- | ---------------------- |
| VMware vSphere  | 9.0 or later           |
| VMware vSphere  | 8.0 Update 3h or later |
::end-spantable::

## :octicons-stack-24: &nbsp; Operating Systems

The project is tested on the following operating systems for the Packer host [^1] :

::spantable::
| Operating System   | Version | Architecture  |
| :----------------- | :------ | :------------ |
| VMware Photon OS   | 5.0     | `amd64`       |
| Ubuntu Server      | 24.04   | `amd64`       |
| macOS              | Tahoe   | `arm64`       |
::end-spantable::

## :octicons-package-dependencies-24: &nbsp; Tooling

All build tools are managed with [mise] — versions are pinned in
[`.mise.toml`][mise-toml] (the single source of truth) and summarised in
[`.mise.md`][mise-md]. Install them with:

```shell
mise install
```

This provides Packer, Ansible (`ansible-core`), Terraform, gomplate, jq, govc,
goss, and gh at their pinned versions. The Packer plugins (Ansible, vSphere,
Git) are downloaded and initialized automatically by `./build.sh` /
`packer init`; for disconnected sites, pre-place them next to the Packer binary
(`/usr/local/bin`) or in `$HOME/.packer.d/plugins`.

!!! note "System packages"

    `git` and `xorriso` (Linux only) come from the system package manager, not
    mise. On macOS, also install `coreutils` (`brew install coreutils`).

[^1]:
    The project may work on other operating systems and versions, but has not been tested by the
    maintainers.

[//]: Links
[mise]: https://mise.jdx.dev/
[mise-toml]: https://github.com/codelooks-com/packer-vsphere/blob/main/.mise.toml
[mise-md]: https://github.com/codelooks-com/packer-vsphere/blob/main/.mise.md
