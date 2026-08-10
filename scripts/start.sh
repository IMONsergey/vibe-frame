#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="${BENCH_DIR:-/home/frappe/frappe-bench}"
SITE="${FRAPPE_SITE:-builder.localhost}"
LOG_FILE="${VIBE_FRAME_LOG:-/tmp/vibe-frame-bench.log}"

if [ ! -d "$BENCH_DIR/apps/frappe" ]; then
  echo "Bench is not provisioned yet. Run /workspace/scripts/init.sh first." >&2
  exit 1
fi

if pgrep -f "bench serve" >/dev/null 2>&1 || pgrep -f "honcho start" >/dev/null 2>&1; then
  echo "Vibe Frame bench is already running."
  exit 0
fi

cd "$BENCH_DIR"
nohup bench start >"$LOG_FILE" 2>&1 &

echo "Starting Vibe Frame..."
for attempt in $(seq 1 90); do
  if curl -fsS -H "Host: $SITE" "http://127.0.0.1:8000/builder" >/dev/null 2>&1; then
    echo "Vibe Frame is responding on port 8000."
    exit 0
  fi

  if ! pgrep -f "bench serve" >/dev/null 2>&1 && ! pgrep -f "honcho start" >/dev/null 2>&1; then
    echo "Bench exited while starting. Last log lines:" >&2
    tail -n 120 "$LOG_FILE" >&2 || true
    exit 1
  fi

  sleep 2
done

echo "Timed out waiting for Vibe Frame. Last log lines:" >&2
tail -n 120 "$LOG_FILE" >&2 || true
exit 1
