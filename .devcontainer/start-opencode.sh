#!/usr/bin/env bash
# Start opencode in the background and wait until the port really answers.
#
# postStartCommand blocks the Codespace from finishing startup, so this must
# return rather than run the server in the foreground. It reuses run-local.sh
# so the Codespace and a local run share one code path.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4096}"
LOG="/tmp/opencode-web.log"

if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
  cat >&2 <<'MSG'
DEEPSEEK_API_KEY is not set, so opencode was not started.

Add it under Settings > Codespaces > Secrets, grant this repository access,
then rebuild the Codespace. See "Running it in a Codespace" in README.md.
MSG
  exit 1
fi

# A resumed Codespace runs this again. Re-using the live server avoids a second
# process fighting for the port and losing.
if curl -fsS --max-time 2 "http://127.0.0.1:${PORT}/global/health" >/dev/null 2>&1; then
  echo "opencode is already listening on ${PORT}."
  exit 0
fi

# Open the repository checked out in this Codespace, so the agent works on your
# code. run-local.sh would otherwise default to the workspace/ subdirectory.
export WORKSPACE="${WORKSPACE:-$ROOT}"

# run-local.sh binds loopback by default, which is what Codespaces forwards
# from. Nothing here should listen on a public interface; the forwarded port is
# the only way in, and the server has no password.
nohup bash "$ROOT/run-local.sh" > "$LOG" 2>&1 &

for _ in $(seq 1 45); do
  if curl -fsS --max-time 2 "http://127.0.0.1:${PORT}/global/health" >/dev/null 2>&1; then
    echo "opencode is listening on ${PORT}."
    echo "Open it from the Ports panel. Keep that port Private: the server has"
    echo "no password, and anyone who reaches it can run commands in this repo."
    exit 0
  fi
  sleep 1
done

echo "ERROR: opencode did not become ready on port ${PORT}." >&2
echo "--- $LOG ---" >&2
tail -40 "$LOG" >&2 2>/dev/null
exit 1
