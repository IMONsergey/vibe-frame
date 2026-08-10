#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="${BENCH_DIR:-/home/frappe/frappe-bench}"
REPO_DIR="${VIBE_FRAME_REPO:-/workspace}"
SITE="${FRAPPE_SITE:-builder.localhost}"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"
ADMIN_PASSWORD="${FRAPPE_ADMIN_PASSWORD:-admin}"

if [ ! -d "$REPO_DIR/builder" ] || [ ! -f "$REPO_DIR/pyproject.toml" ]; then
  echo "Vibe Frame source was not mounted at $REPO_DIR" >&2
  exit 1
fi

if [ -s /home/frappe/.nvm/nvm.sh ]; then
  # shellcheck disable=SC1091
  source /home/frappe/.nvm/nvm.sh
  nvm install 18 >/dev/null
  nvm alias default 18 >/dev/null
  nvm use 18
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
bench set-mariadb-host mariadb
bench set-redis-cache-host "redis-cache:6379"
bench set-redis-queue-host "redis-queue:6379"
bench set-redis-socketio-host "redis-socketio:6379"
sed -i '/redis/d' ./Procfile

# Refresh the app from the repository mounted by Codespaces. This prevents
# accidental use of the upstream frappe/builder package.
if [ -e "$BENCH_DIR/apps/builder" ]; then
  rm -rf "$BENCH_DIR/apps/builder"
fi
bench get-app --skip-assets builder "$REPO_DIR"

if [ ! -d "$BENCH_DIR/sites/$SITE" ]; then
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
bench build --app builder

echo "Codespace provisioned. Vibe Frame will be served on port 8000."
