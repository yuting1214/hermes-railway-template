---
name: hermes-clone
description: >-
  Clone a running Hermes agent on Railway into a brand-new container in the same
  project — copying its memory, skills, persona, and config (NOT its bloat),
  verifying byte-for-byte, and leaving a correctly-supervised gateway. Use this
  whenever the user wants to clone / duplicate / fork / replicate / mirror a
  Hermes agent, spin up a "sibling"/"twin"/"copy" agent, create a new agent
  "based on" an existing one, or migrate a Hermes agent to a new Railway service
  — even if they don't say the word "clone" (e.g. "make another bot like my
  current one", "spin up a second hermes that knows what this one knows",
  "duplicate hermes-prod into hermes-dev"). Do NOT use plain `hermes profile
  export` for this — it stages the whole HERMES_HOME (venvs, 100+MB state.db,
  caches) into /tmp and bloats to GBs; this skill is the lean, reproducible way.
---

# Hermes agent clone (Railway)

Reproducibly stand up a **new Hermes agent** that inherits an existing one's
**identity** — memory (`MEMORY.md`/`USER.md`), persona (`SOUL.md`), cultivated
`skills/`, `config.yaml`, and `cron/` — in a fresh Railway service, then verify
the copy is exact and bring the gateway up correctly.

## Why not `hermes profile export`
The upstream export copies the **entire** `HERMES_HOME` into a `/tmp` staging dir
before tarring — including the tool virtualenvs the agent built, the 100+ MB
`state.db` conversation history, and caches. It balloons to **gigabytes** (and
`--clone-all` crashes on venv symlinks). This skill instead copies **only the
identity** (~tens of KB to a couple hundred KB) and transfers it over Railway's
**private network**, so the data never leaves Railway.

## What gets copied
| Always (default) | Opt-in (`--auth`) | Opt-in (`--state`) | Never |
|---|---|---|---|
| `memories/`, `SOUL.md`, `config.yaml`, `skills/`, `cron/` | `auth.json` + `google_*` + `pairing/` (secrets) | `state.db*` (full chat history) | venvs, caches, task scratch |

Default is **identity only, no auth** — the clone *knows* the user but does its
own provider login. Add `--auth` only if the user explicitly wants the clone to
share the source's credentials (same ChatGPT/Codex sub ⇒ shared rate limits).

## The reproducible procedure

### Preflight
1. `railway whoami` (logged in) and the working dir is **linked to the target
   project** (`railway status` shows the right project). Run from inside the
   `hermes-agent` repo so script paths resolve.
2. Decide: **SRC** (source service, e.g. `hermes`), **NEW** (new service name),
   and whether to pass `--auth`. Confirm the new service's `HERMES_HOME`
   (`/data` for slim, `/opt/data` for full).

### One command (preferred)
```bash
cd hermes-agent/variants/slim          # any linked dir works; this links the project
SRC=hermes NEW=hermes-clone2 bash ../../scripts/clone-agent.sh        # identity only
#   add --auth to also copy credentials; --state for a full history mirror
```
`scripts/clone-agent.sh` runs all five steps and **verifies md5 byte-equality**
at the end. If it reports `MISMATCH`, stop and investigate before relying on the
clone. (See the script header for env vars: `SRC_HOME`, `NEW_HOME`, `VARIANT`, `WAIT`.)

### Or step-by-step (same thing, for transparency / debugging)
```bash
# 1) service + volume + memory fix
railway add --service "$NEW"
railway volume add -m /data                  # attaches to the just-linked NEW service
railway variable set 'MALLOC_ARENA_MAX=2' -s "$NEW" --skip-deploys

# 2) deploy the slim image (hardened entrypoint)
cd hermes-agent/variants/slim && railway up -s "$NEW" -d   # wait ~90s for first boot

# 3) lean identity clone over the private network
SRC=hermes DST="$NEW" bash ../../scripts/identity-import.sh     # add --auth/--state as needed

# 4) restart so NEW adopts the cloned config
railway redeploy -s "$NEW" -y

# 5) verify (must match on both)
for f in SOUL.md config.yaml memories/MEMORY.md memories/USER.md; do
  railway ssh -s hermes  -- md5sum /data/$f
  railway ssh -s "$NEW"  -- md5sum /data/$f
done
```

### Finish setup on the clone (the user does this, or guide them)
```bash
# Codex (device flow — note: upstream removed `hermes login`, it's `auth add` now):
railway ssh -s "$NEW" -- hermes auth add openai-codex --type oauth --no-browser
# Telegram — a NEW BotFather token (NEVER reuse SRC's token → Telegram 409):
railway ssh -s "$NEW"                 # then inside:  hermes gateway setup
railway redeploy -s "$NEW" -y         # entrypoint auto-starts the SUPERVISED gateway
```

## Guarantees & gotchas (why each step matters)
- **Lean, never bloats** — `identity-import.sh` tars only selected paths on the
  source (no `HERMES_HOME` staging). Don't substitute `hermes profile export`.
- **Data stays in Railway** — transfer is `SRC` serving over the private network
  (`<service>.railway.internal`, IPv6) and `NEW` `curl`-ing it. No public host,
  and it sidesteps `railway ssh`'s inability to stream files *into* a container.
- **`MALLOC_ARENA_MAX=2`** caps glibc arenas so heavy agent runs don't retain
  gigabytes of heap (a known upstream gateway-memory issue). Set it before first
  deploy.
- **Never reuse the Telegram bot token** between the source and clone — one token
  = one poller; two ⇒ 409 "terminated by other getUpdates". Always a fresh
  BotFather token per agent.
- **Supervised gateway** — the slim entrypoint runs the gateway as PID-1 (auto
  restart + survives redeploys) whenever a messaging token is configured, whether
  via a Railway var **or** via `hermes gateway setup` (it greps `$HERMES_HOME/.env`).
  So after `gateway setup` + a redeploy, the clone's bot is robust, not a fragile
  manual process.
- **`state.db` is history, not memory** — the agent's knowledge lives in
  `memories/MEMORY.md`/`USER.md`; `state.db` is the raw transcript log. Omit it
  (default) for a clean sibling; add `--state` only for an exact running mirror.

## Bundled / referenced scripts (in the repo `scripts/` dir)
- `scripts/clone-agent.sh` — the one-command orchestrator (this skill's main tool).
- `scripts/identity-import.sh` — lean private-network identity transfer (SRC→DST).
- `scripts/identity-export.sh` — pull a lean identity tarball to your machine
  (for off-Railway backup; same selection flags).

For deeper background (sessions, profiles, the memory-vs-state.db distinction),
see `docs/hermes-deep-dive.md` and `docs/hermes-railway-bringup.md`.
