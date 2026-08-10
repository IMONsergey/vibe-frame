#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="${BENCH_DIR:-/home/frappe/frappe-bench}"
REPO_DIR="${VIBE_FRAME_REPO:-/workspace/vibe-frame}"
SITE="${FRAPPE_SITE:-builder.localhost}"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"
ADMIN_PASSWORD="${FRAPPE_ADMIN_PASSWORD:-admin}"

if [ ! -d "$REPO_DIR/builder" ] || [ ! -f "$REPO_DIR/pyproject.toml" ]; then
  echo "Vibe Frame source was not mounted at $REPO_DIR" >&2
  exit 1
fi

if [ ! -d "$BENCH_DIR/apps/frappe" ]; then
  echo "Creating Frappe bench on $FRAPPE_BRANCH..."
  cd "$(dirname "$BENCH_DIR")"
  bench init \
    --skip-redis-config-generation \
    --frappe-branch "$FRAPPE_BRANCH" \
    "$(basename "$BENCH_DIR")"
fi

cd "$BENCH_DIR"

echo "Configuring compose services..."
bench set-mariadb-host mariadb
bench set-redis-cache-host "redis://redis:6379"
bench set-redis-queue-host "redis://redis:6379"
bench set-redis-socketio-host "redis://redis:6379"
sed -i '/redis/d' ./Procfile

# Always refresh Builder from this repository so a container restart cannot
# silently fall back to frappe/builder or an older checkout.
if [ -e "$BENCH_DIR/apps/builder" ]; then
  rm -rf "$BENCH_DIR/apps/builder"
fi
bench get-app --skip-assets builder "$REPO_DIR"

if [ ! -d "$BENCH_DIR/sites/$SITE" ]; then
  echo "Creating site $SITE..."
  bench new-site "$SITE" \
    --mariadb-root-password 123 \
    --admin-password "$ADMIN_PASSWORD" \
    --no-mariadb-socket
fi

if ! bench --site "$SITE" list-apps | grep -qx builder; then
  bench --site "$SITE" install-app builder
fi

bench --site "$SITE" set-config developer_mode 1
bench --site "$SITE" set-config mute_emails 1
bench --site "$SITE" clear-cache
bench use "$SITE"

# get-app is intentionally run with --skip-assets so the build step is explicit
# and failures are visible in Docker/Actions logs.
bench build --app builder

echo "Vibe Frame is ready on http://builder.localhost:8000"
exec bench start
