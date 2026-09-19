#!/bin/sh
# Idempotent migrator: applies poke5e's DB migrations in filename order,
# tracking which have run so it is safe to re-run after an upstream update.
# Seeds sample data only on the very first initialization.
set -e

export PGPASSWORD="$POSTGRES_PASSWORD"
DB_HOST="${POSTGRES_HOST:-db}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-postgres}"
PSQL="psql -v ON_ERROR_STOP=1 -h $DB_HOST -p $DB_PORT -U postgres -d $DB_NAME"

echo "[migrator] waiting for database..."
until $PSQL -c 'select 1' >/dev/null 2>&1; do sleep 2; done

echo "[migrator] ensuring migration ledger..."
$PSQL -c "CREATE SCHEMA IF NOT EXISTS _offline_meta;
          CREATE TABLE IF NOT EXISTS _offline_meta.applied_migrations (
            version    text PRIMARY KEY,
            applied_at timestamptz NOT NULL DEFAULT now()
          );"

PRIOR=$($PSQL -tAc "select count(*) from _offline_meta.applied_migrations")
echo "[migrator] $PRIOR migration(s) already applied."

for f in $(ls /migrations/*.sql 2>/dev/null | sort); do
  v=$(basename "$f")
  applied=$($PSQL -tAc "select 1 from _offline_meta.applied_migrations where version = '$v'")
  if [ "$applied" = "1" ]; then
    echo "[migrator] skip   $v"
    continue
  fi
  echo "[migrator] apply  $v"
  $PSQL --single-transaction -f "$f"
  $PSQL -c "insert into _offline_meta.applied_migrations(version) values ('$v')"
done

if [ "$PRIOR" = "0" ] && [ -f /seed.sql ]; then
  echo "[migrator] seeding sample data (first init only)..."
  $PSQL --single-transaction -f /seed.sql || echo "[migrator] seed skipped/failed (non-fatal)"
fi

echo "[migrator] done."
