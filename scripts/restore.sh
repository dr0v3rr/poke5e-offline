#!/usr/bin/env bash
# Restore a snapshot created by backup.sh.
#
# ⚠️  This REPLACES all current poke5e-offline data with the snapshot.
#
#   sh scripts/restore.sh            # list available snapshots
#   sh scripts/restore.sh <label>    # restore that snapshot (asks to confirm)
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=poke5e-offline
VOLUMES="db_data minio_data storage_data"

if [ $# -eq 0 ]; then
  echo "Available snapshots (in ./backups):"
  if [ -d backups ] && [ -n "$(ls -A backups 2>/dev/null)" ]; then
    for d in backups/*/; do
      [ -d "$d" ] && printf "  %-24s %s\n" "$(basename "$d")" "$(grep -h '^created:' "$d/MANIFEST.txt" 2>/dev/null | cut -d: -f2- | xargs || true)"
    done
  else
    echo "  (none yet — create one with: sh scripts/backup.sh)"
  fi
  echo ""
  echo "Usage: sh scripts/restore.sh <label>"
  exit 0
fi

LABEL="$1"
SRC="backups/$LABEL"
[ -d "$SRC" ] || { echo "Snapshot not found: $SRC" >&2; exit 1; }
for v in $VOLUMES; do
  [ -f "$SRC/${v}.tar.gz" ] || { echo "Snapshot is missing ${v}.tar.gz — aborting to avoid a partial restore." >&2; exit 1; }
done

echo "⚠️  This will REPLACE all current poke5e-offline data with snapshot '$LABEL'."
printf "Type 'yes' to continue: "
read -r CONFIRM
[ "$CONFIRM" = "yes" ] || { echo "Aborted — nothing changed."; exit 1; }

echo "==> Stopping the stack (volumes are kept, then overwritten)..."
docker compose down

echo "==> Restoring data volumes from $SRC"
for v in $VOLUMES; do
  echo "    - $v"
  docker volume create "${PROJECT}_${v}" >/dev/null
  docker run --rm \
    -v "${PROJECT}_${v}:/data" \
    -v "$PWD/$SRC:/backup:ro" \
    alpine sh -c 'rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; tar xzf "/backup/'"${v}"'.tar.gz" --numeric-owner -C /data'
done

echo "==> Starting the stack..."
docker compose up -d

echo ""
echo "==> Restore complete from '$LABEL'."
echo "    Live at $(grep -E '^APP_ORIGIN=' .env 2>/dev/null | cut -d= -f2- || echo 'http://localhost:9000')"
