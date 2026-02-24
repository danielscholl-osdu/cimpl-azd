# Documentation (Local Development)

This directory contains the [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) documentation site for cimpl-azd, built with [Zensical](https://zensical.org/).

## Quick Start (Docker)

No Python required — just Docker:

```bash
cd docs
docker compose up
```

The site will be available at `http://localhost:8000` with hot-reload on file changes.

## Alternative: Python Virtual Environment

```bash
cd docs
python3 -m venv .venv
source .venv/bin/activate
pip install zensical mkdocs-material
zensical serve
```

## Structure

```
docs/
+-- mkdocs.yml          # Site configuration (Material for MkDocs)
+-- Dockerfile          # Docs container image
+-- docker-compose.yml  # One-command local dev
+-- src/                # Source root (docs_dir)
|   +-- index.md        # Landing page
|   +-- getting-started/
|   +-- architecture/
|   +-- operations/
|   +-- decisions/
|   +-- stylesheets/
|   +-- javascripts/
+-- diagrams/           # Excalidraw diagrams (not published)
+-- plans/              # Internal planning docs (not published)
```

## Deployment

Documentation is deployed to GitHub Pages automatically when changes are pushed to `main`. See `.github/workflows/squad-docs.yml`.
