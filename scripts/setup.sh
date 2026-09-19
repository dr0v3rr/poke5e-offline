#!/usr/bin/env bash
# First-time setup: fetch poke5e source, create .env, build and start the stack.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then set -a; . ./.env; set +a; fi
REPO="${POKE5E_REPO:-https://github.com/Auroratide/poke5e.git}"
REF="${POKE5E_REF:-main}"

echo "==> Fetching poke5e source ($REF)"
if [ ! -d poke5e-src/.git ]; then
  git clone "$REPO" poke5e-src
fi
git -C poke5e-src fetch --all --tags --prune
git -C poke5e-src checkout "$REF"
git -C poke5e-src pull --ff-only origin "$REF" 2>/dev/null || true

if [ ! -f .env ]; then
  cp .env.example .env
  echo "==> Created .env from .env.example (edit APP_ORIGIN before LAN use)"
fi

echo "==> Building and starting the stack"
docker compose up -d --build

echo ""
echo "poke5e-offline is starting at ${APP_ORIGIN:-http://localhost:9000}"
echo "First run downloads images + Deno deps — give it a minute, then reload."
echo "Follow progress:  docker compose logs -f"
