#!/bin/bash
# =============================================================================
# Local Preview for the GitHub Pages Learner Portal
# =============================================================================
# Purpose: Build and serve materials/docs locally so you can verify how the
#          learner portal (and any Pages content you edit) actually renders
#          through Jekyll + the minima theme, before pushing to GitHub Pages.
#
# Why this script exists (gotchas it works around):
#   - webrick is NOT bundled with Ruby 3.1+, so `jekyll serve` crashes with
#     "cannot load such file -- webrick". We `gem install webrick` first.
#   - Docker bind mounts do not deliver inotify events, so live reload needs
#     `--force_polling`.
#   - _config.yml references GitHub Pages-only plugins
#     (jekyll-optional-front-matter, jekyll-readme-index, jekyll-relative-links)
#     that are not in the jekyll/jekyll image. For a faithful *visual* preview
#     we build with a minimal config (theme: minima). The look is identical;
#     only the convenience plugins are skipped.
#
# The authoritative build is always the GitHub Actions workflow
# (.github/workflows/pages.yml). Use this script for fast local iteration.
#
# Requirements: Docker Desktop running.
#
# Usage:
#   ./scripts/preview-pages.sh           # build + serve at http://localhost:4000
#   ./scripts/preview-pages.sh start     # same as above
#   ./scripts/preview-pages.sh build     # one-off build only (no server)
#   ./scripts/preview-pages.sh stop      # stop and remove the preview container
#   PORT=8080 ./scripts/preview-pages.sh # serve on a custom port
#
# After it is running, open http://localhost:4000 and click through the TOC.
# Stop it with: ./scripts/preview-pages.sh stop
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="${REPO_ROOT}/materials/docs"
IMAGE="jekyll/jekyll:4.2.2"
CONTAINER="aiw-preview"
PORT="${PORT:-4000}"

# Minimal config that renders the same look without GitHub Pages-only plugins.
# (Written inside the container at runtime.)
MINIMAL_CONFIG='title: Local Preview\ntheme: minima\nexclude:\n  - archive/\n'

# --- Helpers -----------------------------------------------------------------
require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed or not on PATH." >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running. Start Docker Desktop and retry." >&2
    exit 1
  fi
}

stop_preview() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
  echo "Preview container '${CONTAINER}' stopped and removed."
}

# --- Commands ----------------------------------------------------------------
cmd_build() {
  require_docker
  echo "Building materials/docs with Jekyll (minima)..."
  docker run --rm -v "${DOCS_DIR}":/srv/jekyll "${IMAGE}" sh -c "
    gem install webrick -N >/dev/null 2>&1
    printf '${MINIMAL_CONFIG}' > /tmp/cfg.yml
    jekyll build --config /tmp/cfg.yml -d /tmp/site
  "
  echo "Build OK. (Output stays inside the container; use 'start' to view it.)"
}

cmd_start() {
  require_docker
  stop_preview
  echo "Starting preview at http://localhost:${PORT} ..."
  docker run -d --name "${CONTAINER}" -p "${PORT}:4000" \
    -v "${DOCS_DIR}":/srv/jekyll "${IMAGE}" sh -c "
      gem install webrick -N >/dev/null 2>&1
      printf '${MINIMAL_CONFIG}' > /tmp/cfg.yml
      exec jekyll serve --config /tmp/cfg.yml -d /tmp/site \
        --host 0.0.0.0 --force_polling
    " >/dev/null

  # Wait for the first build + HTTP to come up.
  printf "Waiting for the site to build"
  for _ in $(seq 1 30); do
    if curl -s -o /dev/null "http://localhost:${PORT}/"; then
      echo ""
      echo "Ready: http://localhost:${PORT}"
      echo "Edit files under materials/docs and refresh the browser."
      echo "Stop with: ./scripts/preview-pages.sh stop"
      return 0
    fi
    printf "."
    sleep 2
  done

  echo ""
  echo "ERROR: site did not respond in time. Recent logs:" >&2
  docker logs "${CONTAINER}" 2>&1 | tail -20 >&2
  exit 1
}

# --- Entry point -------------------------------------------------------------
case "${1:-start}" in
  start) cmd_start ;;
  build) cmd_build ;;
  stop)  stop_preview ;;
  *)
    echo "Usage: $0 [start|build|stop]" >&2
    exit 2
    ;;
esac
