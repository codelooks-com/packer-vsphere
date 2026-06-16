# Packer vSphere Golden Images — Documentation

This directory is the documentation site, built with
[Zensical](https://zensical.org/) and published to
[GitHub Pages](https://codelooks-com.github.io/packer-vsphere/). Build and
preview it locally with the steps below.

## Development

### Prerequisites

- Python 3.x
- pip

### Setup

1. Create and activate a virtual environment:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

2. Install Zensical:
   ```bash
   pip install -r requirements.txt
   ```

### Local Development

Start the development server (live reload):
```bash
zensical serve
```

The site is served at `http://localhost:8000`.

### Build

Build the static site into `site/`:
```bash
zensical build
```

Use `zensical build --clean` to rebuild from scratch.

## Layout

- `zensical.toml` — site configuration (theme, nav, markdown extensions).
- `docs/` — the Markdown content.
- `docs/assets/` — images and stylesheets.
- `site/` — generated output (git-ignored).

## Hosting

Published to **GitHub Pages** at
<https://codelooks-com.github.io/packer-vsphere/> by
[`.github/workflows/docs.yml`](../.github/workflows/docs.yml) on every push to
`main` that touches `docs/`. The `site/` build output stays git-ignored — Pages
rebuilds it from source in CI. Use `zensical serve` for local preview.
