#!/usr/bin/env bash
# Update the running poke5e-offline to a newer (or specific) upstream version.
#
#   sh scripts/update.sh            # rebuild / roll out the ref currently pinned in .env
#   sh scripts/update.sh latest     # move to the tip of poke5e's main branch
#   sh scripts/update.sh <tag>      # move to a release tag
#   sh scripts/update.sh <sha>      # move to a specific commit (fully reproducible)
#
# What it does (data is always preserved):
#   1. re-fetches poke5e source and checks out the target ref
#   2. persists that ref to .env so future builds are reproducible
#   3. rebuilds the frontend / edge-function / MinIO images from the new source
#   4. applies any NEW database migrations idempotently (old ones are skipped)
#   5. rolls out the updated services
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d poke5e-src/.git ]; then
  echo "poke5e-src not found — run scripts/setup.sh first." >&2
  exit 1
fi
[ -f .env ] || cp .env.example .env
set -a; . ./.env; set +a

# Target ref: command-line arg wins, otherwise whatever is pinned in .env.
TARGET="${1:-${POKE5E_REF:-main}}"
[ "$TARGET" = "latest" ] && TARGET="main"

echo "==> Fetching poke5e source, target ref: $TARGET"
git -C poke5e-src fetch --all --tags --prune
git -C poke5e-src checkout "$TARGET"
git -C poke5e-src pull --ff-only 2>/dev/null || true   # no-op for tags/SHAs (detached HEAD)
RESOLVED=$(git -C poke5e-src rev-parse --short HEAD)
echo "==> Source now at $RESOLVED"

# Remember the choice so `up`/rebuild stays reproducible next time.
if grep -q '^POKE5E_REF=' .env; then
  sed -i.bak "s|^POKE5E_REF=.*|POKE5E_REF=$TARGET|" .env && rm -f .env.bak
else
  printf '\nPOKE5E_REF=%s\n' "$TARGET" >> .env
fi

echo "==> Rebuilding images from the new source (frontend + edge functions + MinIO)"
docker compose build gateway functions minio

echo "==> Bringing database + storage up (migrator dependencies)"
docker compose up -d --wait db storage

echo "==> Applying any new database migrations (idempotent)"
docker compose run --rm migrator

echo "==> Rolling out updated services"
docker compose up -d

echo ""
echo "==> Update complete — now running poke5e @ $TARGET ($RESOLVED). Data preserved."
echo "    Live at ${APP_ORIGIN:-http://localhost:9000}"
echo "    If upstream added a NEW edge-function dependency, add it to"
echo "    volumes/functions/deno.jsonc (the user-assets function is already covered)."
