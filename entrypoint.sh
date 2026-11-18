#!/bin/sh
# Runs as root only to prepare the volume, then drops to the image's node user.
set -eu
STATE_DIR=/var/lib/openseo
mkdir -p "$STATE_DIR/config" "$STATE_DIR/data"
chown node:node "$STATE_DIR" "$STATE_DIR/config" "$STATE_DIR/data"
chmod 0700 "$STATE_DIR/config"
exec setpriv --reuid=node --regid=node --init-groups --inh-caps=-all /opt/railway/start.sh
