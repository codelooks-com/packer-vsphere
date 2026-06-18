# syntax=docker/dockerfile:1@sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89
# Base on the same ARC runner image the cluster already runs.
# Renovate manages this digest.
FROM ghcr.io/home-operations/actions-runner:2.335.1@sha256:3d544e5eed58722c0b6a97212a31eada0f9f2e99f189c41911a5573a23d7386a

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# OS packages Packer/ansible/CD-build need that aren't in mise:
#  - xorriso: ISO generation for cd_content/removable media on Linux
#  - genisoimage: fallback ISO tooling
#  - openssh-client: SSH provisioning to Linux build VMs
#  - python3/python3-pip/python3-venv/pipx: interpreter + venv support for the
#    mise-managed ansible-core install (mise's pipx backend execs the pipx binary)
#  - sshpass: password SSH used by some build flows
#  - ca-certificates, curl, git, unzip: tool bootstrap
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      xorriso genisoimage openssh-client sshpass \
      python3 python3-pip python3-venv pipx ca-certificates curl git unzip \
 && rm -rf /var/lib/apt/lists/*

USER runner
ENV MISE_DATA_DIR=/home/runner/.local/share/mise \
    PATH=/home/runner/.local/share/mise/shims:/home/runner/.local/bin:$PATH

# Install mise, then resolve the pinned toolchain from the repo's .mise.toml.
RUN curl -fsSL https://mise.run | sh
COPY --chown=runner:runner .mise.toml /home/runner/.config/mise/config.toml
# github_token secret avoids anonymous GitHub API rate limits when mise
# fetches release assets (aqua/gh backends). Empty/absent token still works.
RUN --mount=type=secret,id=github_token,mode=0444 \
    GITHUB_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || true)" \
 && export GITHUB_TOKEN \
 && mise trust /home/runner/.config/mise/config.toml \
 && mise install \
 && mise reshim

# Inject pywinrm into ansible's own interpreter (the mise/pipx venv — NOT the
# system python3) so the WinRM connection plugin can import it at runtime.
RUN ANSIBLE_PY="$(sed -n '1s/^#!//p' "$(mise which ansible)")" \
 && "$ANSIBLE_PY" -m pip install --no-cache-dir pywinrm \
 && "$ANSIBLE_PY" -c "import winrm"

# Install the ansible galaxy collections the playbooks require.
# linux-requirements.yml + windows-requirements.yml (incl. ansible.windows) are
# both required — fail the build loudly if either is missing.
COPY --chown=runner:runner ansible/ /tmp/ansible/
RUN mise exec -- ansible-galaxy collection install -r /tmp/ansible/linux-requirements.yml \
 && mise exec -- ansible-galaxy collection install -r /tmp/ansible/windows-requirements.yml \
 && rm -rf /tmp/ansible

# Pre-install the Packer vSphere plugin so builds don't fetch it at runtime.
COPY --chown=runner:runner packer.pkr.hcl* /tmp/pkr/
RUN --mount=type=secret,id=github_token,mode=0444 \
    GITHUB_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || true)" \
 && export GITHUB_TOKEN \
 && if [ -f /tmp/pkr/packer.pkr.hcl ]; then mise exec -- packer init /tmp/pkr || true; fi

# CLI/runner image — no service to probe. (Checkov CKV_DOCKER_2)
HEALTHCHECK NONE
