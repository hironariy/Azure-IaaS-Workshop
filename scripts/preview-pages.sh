#!/bin/bash
# =============================================================================
# Faithful Local Preview for the GitHub Pages Learner Portal
# =============================================================================
# Purpose: Build and serve materials/docs locally with the SAME stack GitHub
#          Pages uses, so what you see locally matches production. Use this to
#          verify how the learner portal and any Pages content render before
#          you push.
#
# Why the github-pages gem (and not plain `jekyll`):
#   GitHub Pages builds with the `github-pages` gem, which pins Jekyll 3.10
#   and minima 2.5.1. An earlier version of this script used a plain Jekyll 4
#   image with a minimal config; its minima CSS differed from production, which
#   masked a real CSS specificity bug (dark code blocks rendered fine locally
#   but were white on Pages). Building with `github-pages` reproduces Pages'
#   exact CSS cascade and would have caught it. Always preview with this.
#
# Gotchas this script handles:
#   - webrick is not bundled with Ruby 3.1+, so `jekyll serve` needs it added.
#   - Docker bind mounts do not deliver inotify events, so live reload needs
#     `--force_polling`.
#   - The github-pages dependency tree now requires Ruby >= 3.0, so we use the
#     ruby:3.1 image (not the older 2.7 that github-pages docs once suggested).
#   - Gems are cached in a named Docker volume so repeat runs start quickly.
#   - Output goes to /tmp/site inside the container, so the repo working tree
#     stays clean (no _site / .jekyll-cache written into materials/docs).
#
# The authoritative build/deploy is still .github/workflows/pages.yml.
#
# Requirements: Docker Desktop running. First run downloads ruby:3.1 and
#               installs the github-pages gem (a few minutes); later runs are
#               fast thanks to the cached gem volume.
#
# Usage:
#   ./scripts/preview-pages.sh           # build + serve at http://localhost:4000
#   ./scripts/preview-pages.sh start     # same as above
#   ./scripts/preview-pages.sh build     # one-off build only (no server)
#   ./scripts/preview-pages.sh stop      # stop and remove the preview container
#   ./scripts/preview-pages.sh clean     # stop and also drop the cached gem volume
#   PORT=8080 ./scripts/preview-pages.sh # serve on a custom port
#
# After it is running, open http://localhost:4000 and click through the TOC.
# Stop it with: ./scripts/preview-pages.sh stop
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="${REPO_ROOT}/materials/docs"
IMAGE="ruby:3.1"
CONTAINER="aiw-preview"
GEM_VOLUME="aiw-pages-gems"
PORT="${PORT:-4000}"

# Ephemeral Gemfile (written inside the container) that mirrors GitHub Pages.
# webrick is added because Ruby 3.1 no longer bundles it.
GEMFILE_BODY='source "https://rubygems.org"\ngem "github-pages", group: :jekyll_plugins\ngem "webrick"\n'

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

ensure_volume() {
  docker volume inspect "${GEM_VOLUME}" >/dev/null 2>&1 || docker volume create "${GEM_VOLUME}" >/dev/null
}

stop_preview() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
  echo "Preview container '${CONTAINER}' stopped and removed."
}

# --- Commands ----------------------------------------------------------------
cmd_build() {
  require_docker
  ensure_volume
  echo "Building materials/docs with the github-pages gem (Jekyll 3.10 + minima)..."
  docker run --rm \
    -v "${DOCS_DIR}":/srv/jekyll \
    -v "${GEM_VOLUME}":/usr/local/bundle \
    -w /srv/jekyll "${IMAGE}" bash -c "
      printf '${GEMFILE_BODY}' > /tmp/Gemfile
      export BUNDLE_GEMFILE=/tmp/Gemfile
      bundle install
      bundle exec jekyll build -d /tmp/site
    "
  echo "Build OK. (Output stays inside the container; use 'start' to view it.)"
}

cmd_start() {
  require_docker
  ensure_volume
  stop_preview
  echo "Starting faithful preview at http://localhost:${PORT} ..."
  echo "(First run installs the github-pages gem; this can take a few minutes.)"
  docker run -d --name "${CONTAINER}" -p "${PORT}:4000" \
    -v "${DOCS_DIR}":/srv/jekyll \
    -v "${GEM_VOLUME}":/usr/local/bundle \
    -w /srv/jekyll "${IMAGE}" bash -c "
      printf '${GEMFILE_BODY}' > /tmp/Gemfile
      export BUNDLE_GEMFILE=/tmp/Gemfile
      bundle install
      exec bundle exec jekyll serve -d /tmp/site --host 0.0.0.0 --force_polling
    " >/dev/null

  # Wait for the gem install + first build + HTTP to come up (up to ~5 min).
  printf "Waiting for the site to build"
  for _ in $(seq 1 90); do
    if curl -s -o /dev/null "http://localhost:${PORT}/"; then
      echo ""
      echo "Ready: http://localhost:${PORT}"
      echo "Edit files under materials/docs and refresh the browser."
      echo "Stop with: ./scripts/preview-pages.sh stop"
      return 0
    fi
    # Surface early crashes instead of waiting the full timeout.
    if ! docker ps --filter "name=${CONTAINER}" --format '{{.Names}}' | grep -q "${CONTAINER}"; then
      echo ""
      echo "ERROR: preview container exited during startup. Recent logs:" >&2
      docker logs "${CONTAINER}" 2>&1 | tail -20 >&2
      exit 1
    fi
    printf "."
    sleep 4
  done

  echo ""
  echo "ERROR: site did not respond in time. Recent logs:" >&2
  docker logs "${CONTAINER}" 2>&1 | tail -20 >&2
  exit 1
}

cmd_clean() {
  stop_preview
  docker volume rm "${GEM_VOLUME}" >/dev/null 2>&1 || true
  echo "Cached gem volume '${GEM_VOLUME}' removed."
}

# --- Entry point -------------------------------------------------------------
case "${1:-start}" in
  start) cmd_start ;;
  build) cmd_build ;;
  stop)  stop_preview ;;
  clean) cmd_clean ;;
  *)
    echo "Usage: $0 [start|build|stop|clean]" >&2
    exit 2
    ;;
esac
