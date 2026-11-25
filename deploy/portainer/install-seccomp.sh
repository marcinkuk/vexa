#!/bin/sh
# Install the seccomp profile that lets a meeting bot's Chromium keep its
# sandbox. Docker resolves a seccomp path on the daemon, so it must live at an
# absolute host path — run this on the host, then set SECCOMP_PROFILE in the
# Portainer stack environment.
set -e

DEST=${1:-/opt/vexa/seccomp-userns.json}
SRC=$(dirname "$0")/seccomp-userns.json

mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"
chmod 0644 "$DEST"
echo "installed $DEST"
echo "set in the Portainer stack environment: SECCOMP_PROFILE=$DEST"
