#!/usr/bin/env bash
# Back up ALL poke5e-offline data — database + uploaded Pokémon/fakemon images +
# trainer avatars — into a local, restorable snapshot under ./backups/.
#
# It briefly stops the stack so the snapshot is perfectly consistent, then
# restarts it. Nothing leaves your machine.
#
#   sh scripts/backup.sh              # snapshot labelled with the current date/time
#   sh scripts/backup.sh before-update   # snapshot with your own label
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=poke5e-offline
VOLUMES="db_data minio_data storage_data"
LABEL="${1:-$(date +%Y%m%d-%H%M%S)}"
DEST="backups/$LABEL"

for v in $VOLUMES; do
  docker volume inspect "${PROJECT}_${v}" >/dev/null 2>&1 || {
    echo "Volume ${PROJECT}_${v} not found — has the stack been set up yet?" >&2
    exit 1
  }
done

RUNNING=$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ')

mkdir -p "$DEST"
echo "==> Pausing the stack for a consistent snapshot..."
docker compose stop

echo "==> Snapshotting data volumes -> $DEST"
for v in $VOLUMES; do
  echo "    - $v"
  docker run --rm \
    -v "${PROJECT}_${v}:/data:ro" \
    -v "$PWD/$DEST:/backup" \
    alpine tar czf "/backup/${v}.tar.gz" --numeric-owner -C /data .
done

{
  echo "created:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "poke5e_ref: $(grep -E '^POKE5E_REF=' .env 2>/dev/null | cut -d= -f2-)"
  echo "volumes:    $VOLUMES"
} > "$DEST/MANIFEST.txt"

if [ "$RUNNING" -gt 0 ]; then
  echo "==> Restarting the stack..."
  docker compose start
else
  echo "==> Stack was not running before backup; leaving it stopped."
fi

echo ""
echo "==> Backup complete: $DEST"
echo "    Restore it later with:  sh scripts/restore.sh $LABEL"
