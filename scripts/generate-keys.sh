#!/bin/sh
# Generate a fresh, internally-consistent secret set (JWT secret + matching
# anon/service_role API keys + DB and MinIO passwords).
#
#   sh scripts/generate-keys.sh              # print only
#   sh scripts/generate-keys.sh --update-env # print and write into .env
#
# IMPORTANT: role passwords are set at first DB init. If you rotate
# POSTGRES_PASSWORD AFTER the first run you must reset the database
# (docker compose down -v, which DELETES data). Rotate before first setup,
# or accept the data reset.
set -e

command -v openssl >/dev/null 2>&1 || { echo "openssl is required." >&2; exit 1; }

b64url() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
gen_token() {
  p=$(printf %s "$1" | b64url)
  h=$(printf %s '{"alg":"HS256","typ":"JWT"}' | b64url)
  s=$(printf %s "$h.$p" | openssl dgst -binary -sha256 -hmac "$jwt_secret" | b64url)
  printf '%s.%s.%s' "$h" "$p" "$s"
}

jwt_secret=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n')
iat=$(date +%s)
exp=$((iat + 60 * 60 * 24 * 365 * 5))
anon=$(gen_token "{\"role\":\"anon\",\"iss\":\"poke5e-offline\",\"iat\":$iat,\"exp\":$exp}")
svc=$(gen_token "{\"role\":\"service_role\",\"iss\":\"poke5e-offline\",\"iat\":$iat,\"exp\":$exp}")
pgpass=$(openssl rand -hex 16)
miniopass=$(openssl rand -hex 16)

echo "JWT_SECRET=$jwt_secret"
echo "ANON_KEY=$anon"
echo "SERVICE_ROLE_KEY=$svc"
echo "POSTGRES_PASSWORD=$pgpass"
echo "MINIO_ROOT_PASSWORD=$miniopass"

if [ "${1:-}" = "--update-env" ]; then
  cd "$(dirname "$0")/.."
  [ -f .env ] || cp .env.example .env
  sed -i.bak \
    -e "s|^JWT_SECRET=.*|JWT_SECRET=$jwt_secret|" \
    -e "s|^ANON_KEY=.*|ANON_KEY=$anon|" \
    -e "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$svc|" \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$pgpass|" \
    -e "s|^MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=$miniopass|" \
    .env
  echo ""
  echo "Wrote new secrets to .env (backup at .env.bak)."
fi
