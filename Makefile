# © Broadcom. All Rights Reserved.
# The term “Broadcom” refers to Broadcom Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-2-Clause

# Docs are a Zensical site under docs/ (published to GitHub Pages by
# .github/workflows/docs.yml). Prefer a virtualenv — see docs/README.md.
.PHONY: docs-install docs-serve docs-build
docs-install:
	pip install -r docs/requirements.txt

docs-serve:
	cd docs && zensical serve

docs-build:
	cd docs && zensical build

.PHONY: update-gitlab-ci

update-gitlab-ci:
	gomplate -c build-ci.yaml -f build-ci.tmpl -o .gitlab-ci.yml
