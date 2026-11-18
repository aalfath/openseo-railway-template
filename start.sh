#!/bin/bash
# Starts the OpenSEO runtime (celld), runs upstream's init (secrets on first
# start, app load, D1 migrations), then the crawl gateway and Nginx on $PORT.
# If any of them stops, the container exits and Railway restarts it.
set -euo pipefail

# Railway Bucket (or any S3 store that passes `celld diagnose`).
: "${S3_ENDPOINT:?Set S3_ENDPOINT (the template sets it from the Railway Bucket)}"
: "${CELLD_BUCKET:?Set CELLD_BUCKET (the template sets it from the Railway Bucket)}"
: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY}"
export AWS_REGION="${AWS_REGION:-auto}"
[ -n "$AWS_REGION" ] || export AWS_REGION=auto

# Upstream's Compose defaults for the runtime.
export AUTH_MODE="${AUTH_MODE:-password}"
export CELLD_MAX_RSS_MB="${CELLD_MAX_RSS_MB:-1536}"
export CELLD_MAX_RESIDENT_CELLS="${CELLD_MAX_RESIDENT_CELLS:-64}"
export CELLD_V8_HEAP_LIMIT_MB="${CELLD_V8_HEAP_LIMIT_MB:-256}"
export CELLD_MAX_REQUEST_BODY_BYTES="${CELLD_MAX_REQUEST_BODY_BYTES:-33554432}"
export RUST_LOG="${RUST_LOG:-warn,cell_console=info}"

if [ -z "${BETTER_AUTH_URL:-}" ] || [ "$BETTER_AUTH_URL" = "https://" ]; then
  if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    export BETTER_AUTH_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
  else
    echo "Set BETTER_AUTH_URL to the public https:// address, or add a Railway domain." >&2
    exit 1
  fi
fi

# 8080, 8081 and 8090 are taken inside the container.
PORT="${PORT:-3001}"
case "$PORT" in 8080|8081|8090) PORT=3001 ;; esac
export PORT

pids=()
cleanup() { kill -TERM "${pids[@]}" 2>/dev/null || true; wait || true; }
trap cleanup TERM INT

sh /opt/railway/run.sh &
pids+=($!)

if ! sh /opt/railway/init.sh; then
  echo "OpenSEO init failed; see the lines above." >&2
  cleanup
  exit 1
fi

node /opt/standalone/crawl-gateway.mjs &
pids+=($!)

mkdir -p /tmp/nginx
sed "s#__PORT__#${PORT}#g" /opt/railway/site.conf.in > /tmp/nginx/site.conf
nginx -c /opt/railway/nginx.conf -g 'daemon off;' &
pids+=($!)
echo "OpenSEO is listening on port ${PORT} (${BETTER_AUTH_URL})."

set +e
wait -n "${pids[@]}"
status=$?
echo "An OpenSEO process exited (status ${status}); stopping the container." >&2
cleanup
exit "$status"
