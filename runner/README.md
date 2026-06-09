# Packer runner image

Custom GitHub Actions runner image used by the in-cluster ARC scale set
`packer-runner` (defined in `LukeEvansTech/talos-cluster`). It layers the
mise-pinned Packer toolchain (`.mise.toml`) plus ansible galaxy collections and
CD-generation tooling onto `ghcr.io/home-operations/actions-runner`.

- Published to: `ghcr.io/codelooks-com/packer-runner`
- Built by: `.github/workflows/build-runner-image.yml` (on changes to
  `runner/Dockerfile`, `.mise.toml`, `ansible/**`, or manual dispatch)
- Tool versions: edit `.mise.toml`; Renovate raises PRs for the base image and tools.

The scale set runs this image with `containerMode: kubernetes` (no dind) and
receives vCenter + build credentials as `PKR_VAR_*` env from 1Password via
External Secrets. See `docs/` in the talos-cluster repo for the deployment.
