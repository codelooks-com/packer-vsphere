# Packer vSphere Golden Images — Documentation

This directory contains the **internal** documentation site, built with
[Zensical](https://zensical.org/). It is **not published** — build and preview
it locally.

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

Intentionally **internal-only**: there is no deploy workflow and the site is
never pushed to GitHub Pages. Share the built `site/` directory through an
internal channel if needed, or just run `zensical serve` locally.
