#!/usr/bin/env bash
# Install opencode at the version this project pins.
#
# The pin lives in .env.example (and .env, if present) rather than being
# repeated here, so the Codespace cannot drift from the Docker image.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read_pin() {
  local file="$1"
  [ -f "$file" ] || return 1
  sed -n 's/^[[:space:]]*OPENCODE_VERSION[[:space:]]*=[[:space:]]*"\{0,1\}\([^"[:space:]]*\)"\{0,1\}.*/\1/p' \
    "$file" | tail -1
}

VERSION="$(read_pin "$ROOT/.env" || true)"
[ -n "${VERSION:-}" ] || VERSION="$(read_pin "$ROOT/.env.example" || true)"

if [ -z "${VERSION:-}" ]; then
  echo "Could not read OPENCODE_VERSION from .env or .env.example; using latest." >&2
  VERSION="latest"
fi

echo "Installing opencode-ai@${VERSION}"
npm install -g "opencode-ai@${VERSION}"

opencode --version
