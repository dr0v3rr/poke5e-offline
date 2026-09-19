-- Give the service roles (pre-created by the supabase/postgres image) their
-- login passwords. Runs once, at first DB init.
--
-- NOTE: only roles that exist at init time on supabase/postgres:15.8.1.085 are
-- listed. supabase_functions_admin is deliberately omitted: on this image it is
-- created lazily by the pg_net event trigger (never installed in this trimmed
-- stack), so ALTERing it would abort init under ON_ERROR_STOP. Nothing here
-- connects as that role (the edge runtime uses the postgres user).
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER pgbouncer WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
