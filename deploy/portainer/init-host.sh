#!/bin/sh
# One-time host preparation for the Portainer stack. Run ON the host:
#   sh deploy/portainer/init-host.sh
# Idempotent: existing secrets are kept, missing ones are minted.
set -e

DIR=${VEXA_HOST_DIR:-/data/vexa}
SECRETS=$DIR/stack.secrets.env
PROFILE=$DIR/seccomp-userns.json

mkdir -p "$DIR"
chmod 700 "$DIR"

if [ ! -f "$SECRETS" ]; then
  printf 'DB_PASSWORD=\nADMIN_TOKEN=\nMINIO_ACCESS_KEY=\nMINIO_SECRET_KEY=\n' > "$SECRETS"
fi
chmod 600 "$SECRETS"

mint() {
  key=$1; bytes=$2
  cur=$(grep -E "^$key=" "$SECRETS" | head -1 | cut -d= -f2-)
  case "$cur" in
    ""|changeme|change-me|CHANGE-ME|default|secret|password|postgres|vexa-internal-secret|lite-internal-secret|vexa-access-key|vexa-secret-key)
      new=$(openssl rand -hex "$bytes")
      if grep -qE "^$key=" "$SECRETS"; then
        sed -i.bak "s|^$key=.*|$key=$new|" "$SECRETS" && rm -f "$SECRETS.bak"
      else
        printf '%s=%s\n' "$key" "$new" >> "$SECRETS"
      fi
      echo "minted $key";;
    *) echo "kept existing $key";;
  esac
}

mint DB_PASSWORD 32
mint ADMIN_TOKEN 32
mint MINIO_ACCESS_KEY 16
mint MINIO_SECRET_KEY 32

# Docker resolves a seccomp profile path on the daemon, so it must be an
# absolute host path. Vendored copy ships in this directory.
SRC=$(dirname "$0")/seccomp-userns.json
if [ -f "$SRC" ]; then cp "$SRC" "$PROFILE"; else curl -fsSL -o "$PROFILE" https://raw.githubusercontent.com/marcinkuk/vexa/main/deploy/portainer/seccomp-userns.json; fi
chmod 0644 "$PROFILE"

echo "done:"
echo "  secrets  $SECRETS (0600)"
echo "  seccomp  $PROFILE"
echo "Portainer stack env should set: SECCOMP_PROFILE=$PROFILE"
