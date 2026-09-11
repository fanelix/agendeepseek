#!/usr/bin/env bash
# Run the opencode web UI against DeepSeek without Docker.
#
# Same server and same config as `docker compose up`, just installed with npm
# on this machine. Use it when you do not want a container, or to check that a
# problem is opencode's rather than Docker's.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .env supplies DEEPSEEK_API_KEY, PORT and OPENCODE_VERSION. A value already
# exported into this shell wins over the file, so `PORT=4200 ./run-local.sh`
# overrides it for one run. Sourcing the file with `set -a` would do the
# opposite and silently ignore that PORT, so read it key by key instead.
if [ -f "$ROOT/.env" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}                      # tolerate CRLF line endings
    line=${line#export }
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *=*) ;; *) continue ;; esac

    key=${line%%=*}
    case "$key" in ''|*[!A-Za-z0-9_]*) continue ;; esac

    value=${line#*=}
    case "$value" in                        # drop optional surrounding quotes
      \"*\") value=${value#\"}; value=${value%\"} ;;
      \'*\') value=${value#\'}; value=${value%\'} ;;
    esac

    if [ -z "${!key+set}" ]; then
      export "$key=$value"
    fi
  done < "$ROOT/.env"
fi

PORT="${PORT:-4096}"
OPENCODE_VERSION="${OPENCODE_VERSION:-1.18.30}"

# Loopback only. The server has no password and can run shell commands in the
# workspace, so it must not be reachable from the network by default. See
# "Security" in README.md before overriding this.
BIND="${BIND:-127.0.0.1}"

# The project opencode opens. Point it at your own code to work on something
# outside this repository.
WORKSPACE_DIR="${WORKSPACE:-$ROOT/workspace}"

if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
  echo "DEEPSEEK_API_KEY is not set." >&2
  echo "Copy .env.example to .env and put your key in it, or export it here." >&2
  exit 1
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "opencode is not on PATH. Install the pinned version with:" >&2
  echo "  npm install -g opencode-ai@${OPENCODE_VERSION}" >&2
  exit 1
fi

installed="$(opencode --version 2>/dev/null || echo unknown)"
if [ "$installed" != "$OPENCODE_VERSION" ]; then
  echo "Note: opencode ${installed} is installed, but this project pins ${OPENCODE_VERSION}."
fi

mkdir -p "$WORKSPACE_DIR"

# Point opencode at this repository's config instead of the one in the user's
# home directory, so a local run and a container run read the same settings.
export OPENCODE_CONFIG="$ROOT/opencode.json"

echo "Workspace:     $WORKSPACE_DIR"
echo "Web interface: http://${BIND}:${PORT}/"
echo "Server authentication is disabled; keep this bound to loopback."
echo

# `serve` embeds the same web UI as `opencode web` but does not try to launch a
# browser, which keeps the output clean on headless machines.
cd "$WORKSPACE_DIR"
exec opencode serve --hostname "$BIND" --port "$PORT"
