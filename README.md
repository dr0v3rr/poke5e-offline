# poke5e-offline

Run [poke5e.app](https://poke5e.app) — the Pokémon 5e trainer/team manager and
reference — **entirely on your own machine** with Docker. No hosted Supabase, no
account, no internet needed once it's built.

This repo is just the recipe. It clones poke5e's source and stands up a complete
self-hosted backend (database, API, file storage, edge functions) behind a
single web address.

---

## 1. What you need

| Requirement | Notes |
|---|---|
| **Docker Desktop** (or Docker Engine + Compose v2) | macOS, Windows, or Linux. Must be running before you start. |
| **git** | To clone this repo (and it clones poke5e for you). |
| **~5 GB free disk** | ~2 GB images + ~2 GB poke5e source + room for your data. |
| **~1 GB free RAM** | It idles around 450 MB. |
| **Internet — first build only** | To download images and dependencies. After that it runs offline. |

Check Docker is ready:

```bash
docker --version && docker compose version
```

---

## 2. Install and run

```bash
git clone https://github.com/dr0v3rr/poke5e-offline.git
cd poke5e-offline
sh scripts/setup.sh
```

That's it. `setup.sh` clones the poke5e source, creates your config, and builds
and starts everything. **The first run takes a few minutes** (downloading and
building). Watch it with `docker compose logs -f` if you like.

When it's done, open:

### 👉 http://localhost:9000

You'll see the poke5e site, fully working — create a trainer, build a team, add
Pokémon and fakemon, upload images. Everything is stored locally.

---

## 3. Everyday commands

Run these from inside the `poke5e-offline` folder.

| I want to… | Command |
|---|---|
| **Stop** it (keeps all data) | `docker compose down` |
| **Start** it again | `docker compose up -d` |
| **See status** | `docker compose ps` |
| **View logs** | `docker compose logs -f` |
| **Update** to the latest poke5e | `sh scripts/update.sh latest` |
| **Reset everything** (⚠️ deletes all data) | `docker compose down -v` then `sh scripts/setup.sh` |

> **Your data is safe across `docker compose down` and restarts.** It only gets
> erased by `docker compose down -v` (note the `-v`). Everything lives in Docker
> volumes, independent of the containers.

---

## 4. Updating

The build is pinned to a known-good poke5e version so it always builds cleanly.
To move to a newer version:

```bash
sh scripts/update.sh latest     # newest poke5e
sh scripts/update.sh v1.2.3     # a specific release tag
sh scripts/update.sh 9eb2ca8    # a specific commit (fully reproducible)
sh scripts/update.sh            # just rebuild the current pinned version
```

It fetches the new source, rebuilds, applies only the **new** database changes
(your existing data is kept), and restarts. Safe to run any time.

---

## 5. Using it from other devices (optional)

By default it's reachable only at `localhost:9000`. To open it to other devices
on your home network:

1. Find your machine's IP (e.g. `192.168.1.50`).
2. Edit `.env` and set `APP_ORIGIN=http://192.168.1.50:9000`.
3. Run `sh scripts/update.sh`.

Now anyone on your network can reach it at `http://192.168.1.50:9000`.

> ⚠️ There is no login or password wall — poke5e protects data with per-trainer
> keys, not accounts. Keep this on a trusted network. **Do not expose port 9000
> to the public internet.**

---

## 6. Security / secrets

`.env` ships with **default development secrets** so it works out of the box on
your own machine. If you put this anywhere beyond localhost, rotate them first:

```bash
sh scripts/generate-keys.sh --update-env
```

Do this **before** the first `setup.sh` (the database locks in its password on
first run). Your real `.env` is never committed to git.

---

## 7. How it works (for the curious)

Everything is served from one web address (`:9000`) by an nginx gateway that
also proxies the backend, so there's no cross-origin setup:

```
browser ──▶ :9000 (nginx) ──┬─ /            the poke5e website
                            ├─ /rest,/auth,/storage,/functions → Supabase services
                            └─ /user-assets  → MinIO (uploaded images)
                                     │
                              Postgres + MinIO (your data)
```

- **Database + API:** Postgres with PostgREST (poke5e's data model).
- **File storage:** MinIO (S3-compatible) for uploaded Pokémon/fakemon art;
  Supabase Storage for trainer avatars.
- **Edge functions:** poke5e's `user-assets` function on Deno.
- **Source is cloned, never copied in here**, which is why this repo is tiny and
  why updating is just "pull new source and rebuild."

---

## Disclaimer & license

poke5e is unofficial fan content and is not affiliated with Wizards of the
Coast, Game Freak, or Nintendo. This repo contains **none** of that content — it
clones it onto your machine at setup. Keep your instance private (your own
table), not re-published.

poke5e's code is © Timothy Foster, ISC-licensed
([Auroratide/poke5e](https://github.com/Auroratide/poke5e)). This deployment
framework is provided as-is.
