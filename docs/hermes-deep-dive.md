# Hermes deep-dive — sessions, personas, capabilities & safety

A top-1%-operator guide to how Hermes actually works, grounded in the source
(hermes-agent **v0.16.0**). File:line citations point at the installed tree
(`~/.hermes/hermes-agent/…`); line numbers are approximate and version-specific —
re-grep if you upgrade. Everything here was verified against a live Railway
deployment of the slim template (see `hermes-railway-bringup.md`).

> Mental model used throughout:
> **Control plane** = `railway ssh` / `hermes` CLI / Railway variables — where *you*
> configure the agent. **Data plane** = the chat (Telegram, …) — where the agent is
> *used*. Keep secrets and config on the control plane; keep the chat for use.

---

## 1. Conversations & sessions — what persists, what resets

Hermes uses a **two-level** model. Don't conflate the two.

### Session **key** — stable identity per chat
`gateway/session.py:617 build_session_key()` deterministically derives a routing
key per conversation surface:
```
agent:main:telegram:dm:<chat_id>          # your 1:1 DM — never changes
agent:main:telegram:dm:<chat_id>:<thread> # threaded
```
This is the durable "mailbox". Group/thread isolation is controlled by
`group_sessions_per_user` (default **True** = each user isolated) and
`thread_sessions_per_user` (`session.py:608,637`).

### Session **id** — the concrete conversation instance
The key maps to **one active session id** at a time, formatted
`YYYYMMDD_HHMMSS_<8hex>` (e.g. `20260615_114323_e6975ed5`). This is the transcript
with accumulating history, stored in `state.db` + `sessions/` on the volume.

### When does the session id roll over? (the reset policy)
On every inbound message `get_or_create_session()` (`session.py:~890`) reuses the
current session **unless `_should_reset` fires**. Defaults (`config.py:285-287`):

| Knob | Default | Meaning |
|---|---|---|
| `mode` | **`both`** | idle **or** daily reset |
| `idle_minutes` | **1440 (24h)** | inactivity → fresh session next message |
| daily | optional | reset at `SESSION_RESET_HOUR` |
| `reset_triggers` | `["/new","/reset"]` | manual fresh session (`config.py:514`) |
| `/stop` | — | breaks a stuck/looping session (`session.py:496`) |

Override via env: `SESSION_IDLE_MINUTES`, `SESSION_RESET_HOUR` (`config.py:1997+`),
or set `mode: none` to never auto-reset (rely only on compaction).

### Long sessions don't overflow — compaction, not reset
With `mode: none`, context is *"managed only by compression"* (`config.py:283`).
The compressor summarizes older turns when usage crosses a threshold
(`compression.threshold ≈ 0.50`, `protect_last_n 20`). Stable prefixes also get
**prompt-cached** — live logs showed `cache=12288/12569 (98%)`.

### Restarts/redeploys resume — they don't reset
`resume_pending` (`session.py:501-509`) preserves the session id and auto-continues
the transcript after a restart (`resume_reason="restart_timeout"`). Combined with
`state.db` on the volume, a `railway redeploy` **resumes** your conversation.

**Takeaway:** one stable key per chat → a session that persists continuously until
24h-idle / daily / `/new` / `/reset`; long chats survive via compaction; restarts
resume. In-chat controls: `/new`, `/reset`, `/compress`, `/usage`, `/model`
(`gateway/slash_commands.py`).

---

## 2. Personas & multi-agent — one bot vs many

### A persona **is** a profile
A profile bundles the identity: `SOUL.md` (the persona prompt), `config.yaml`
(model + harness), `skills/`, and `memories/` — which `profiles.py:59-64` calls
*"the agent's curated identity."* Profiles live at `~/.hermes/profiles/<name>/`
(the bare `HERMES_HOME` is the implicit `default` profile).

### A gateway is **per-profile**; a bot token is **per-gateway**
`hermes_cli/gateway.py:74 class ProfileGatewayProcess`; the s6 image supervises
*"per-profile gateways"*. A Telegram token = one bot = one poller, so:
**one persona → one profile → one gateway → one bot token.** You cannot share a
token across two gateways (Telegram returns 409 "terminated by other getUpdates
request"; Hermes retries 5× then declares `telegram_polling_conflict`).

### Two ways to run multiple personas

**A) One service per persona (full isolation, simplest).** Each container = its own
`/data` volume = its own SOUL/memory/token. Deploy the slim template once per
persona. Pros: total isolation, independent uptime. Cons: ~one extra base
footprint per container.

**B) One container, multiple profiles (resource-efficient).** Use the **full/s6
image** — `hermes_cli/container_boot.py:reconcile_profile_gateways` walks
`$HERMES_HOME/profiles/*/` (each marked by its `SOUL.md`), registers an s6 slot
`gateway-<profile>`, and **auto-starts those whose last state was `running`** — so
once started, each persona's gateway survives redeploys. Each profile reads its own
`.env` (own token), `SOUL.md`, model, memory. Setup:
```bash
hermes profile create oracle && hermes profile create coach   # edit each SOUL.md
hermes -p oracle config set telegram.allow_from <userX>       # own token in oracle/.env
hermes -p coach  config set telegram.allow_from <userY>
hermes -p oracle gateway start    # s6-supervised, persists
hermes -p coach  gateway start
hermes gateway list
```
Cost reality on Railway: billing is **RAM·time + CPU·time**, not per-container.
Codex inference is network-bound (compute is on the provider), so CPU is light;
the saving from consolidating is ~one container's base RAM. With the dashboard
**off**, the full image's *runtime* RAM ≈ slim + small s6 overhead (its 2-3 GB is
disk/cold-start, a one-time cost — not your monthly bill). Trade-off: **shared
fate** (one crash/redeploy = all personas blink) and **shared Codex quota** if
profiles log in with the same ChatGPT account.

### One bot, lighter variation — `channel_prompts`
`telegram.channel_prompts` (`config.py:978-983`, `run.py:619`) gives different
system prompts **per chat/channel on a single bot**. But it's prompt-only: shared
model, skills, and memory. Good for "same agent, different framing per group";
**not** a substitute for separate personas with separate memory.

### Who may talk to a persona
`telegram.allow_from` → `TELEGRAM_ALLOWED_USERS` (`gateway/authz_mixin.py:228`).
With no allowlist, the gateway **denies everyone** (you'll see the warning at boot)
and unknown DMs follow `unauthorized_dm_behavior` (default `pair` → `hermes pairing
list/approve <code>`). Lock a persona to you with:
```bash
hermes config set telegram.allow_from <your_user_id>
```

---

## 3. Capabilities & safety — it has a shell, running 24/7

### Control plane vs data plane (the golden rule)
Grant tools and set credentials from the **CLI/Railway side**, never by typing keys
into chat. Two grounded reasons:
1. Credentialed tools read **process env** — `tools/web_tools.py:1406`
   (`os.getenv("FIRECRAWL_API_KEY")`), `tools/tool_backend_helpers.py:172`
   (`os.getenv("FAL_KEY")`). Railway injects every variable into the container env,
   which the gateway inherits → a Railway variable just works.
2. A key typed into chat lands in the transcript (`state.db`), the model context,
   and logs. "Secret redaction: ENABLED" is best-effort scrubbing — don't rely on
   it for your own secrets.

### Granting a credentialed tool (the pattern)
```bash
# 1) credential as an encrypted Railway variable (in process env, never in chat)
railway variable set 'FIRECRAWL_API_KEY=fc-...' -s hermes     # web search
railway variable set 'FAL_KEY=...'             -s hermes       # image gen
railway redeploy -s hermes -y
# 2) enable the toolset for the surface (per CLI/Telegram/Discord)
railway ssh -s hermes -- hermes tools enable web
railway ssh -s hermes -- hermes tools list
```
`hermes tools` enables/disables/lists tools per surface; built-ins use plain names
(`web`, `image`, `memory`), MCP tools use `server:tool`. Credentialed backends and
their keys (grounded in `tools/lazy_deps.py`): `search.exa`→`EXA_API_KEY`,
`search.firecrawl`→`FIRECRAWL_API_KEY`, `image.fal`→`FAL_KEY`,
`tts.elevenlabs`→`ELEVENLABS_API_KEY`. Deps are **lazy-installed** at first use, so
keep the always-on bot reliable by either pre-installing extras in the image or
accepting a one-time install on first call.

> Note: the slim entrypoint mirrors a fixed key list into `/data/.env`, but because
> tools read `os.getenv`, **any** Railway variable works even if unmirrored. Add
> keys to the mirror only if you want the volume fully self-contained for backups.

### Performance levers (what actually makes it better)
- **Tools**: `web`, `image`, `memory`, plus **MCP servers** (`mcp.json`) for real
  integrations (GitHub, etc.).
- **Skills**: Hermes self-evolves skills into `skills/` during use, *and* you can
  install curated bundles (`hermes bundles` / `hermes skills`).
- **Memory**: cultivate `memories/MEMORY.md` + `USER.md` (the agent's long-term
  identity — persists across session resets).
- **Model/harness**: `hermes config set model …`, `agent.max_turns`, compression.

### Safety when unattended (verified behavior)
- **Default `approvals.mode = "manual"`** (`config.py:2021`). Ordinary commands run;
  **dangerous** ones (matched vs `DANGEROUS_PATTERNS` + the **tirith** pre-exec
  scanner, combined guard at `approval.py:1203`) require approval.
- **In a chat**, a dangerous command becomes a **pending approval** you resolve with
  **`/approve` / `/deny`** (`/approve all` for the queue) — `approval.py:682-685`.
- **Unattended = safe by default**: a pending approval **times out (~60s) → `deny`**
  (`approval.py:802`). It does not silently run.
- **Cron never uses interactive approval** — it follows `approvals.cron_mode`,
  default **`"deny"`** (`config.py:2023`), so scheduled tasks can't run dangerous
  commands by default.
- **Hard floor**: truly catastrophic commands are blocked unconditionally —
  *"not even with --yolo"* (`approval.py:223,352`).
- **Footgun**: do **not** enable YOLO (`HERMES_YOLO_MODE`, frozen at import
  `approval.py:29`) on the remote agent — it bypasses approvals.

### The strategic security win
**The Railway container is your blast radius.** Locally, the agent's terminal could
touch your real files; on Railway it's an isolated, disposable container — a
*benefit* of remote deployment. Corollary — **least privilege**: the agent can
`printenv` inside its own container, so only put credentials there that you're
comfortable it possessing. Don't hand a chat persona production cloud keys.

### Recommended baseline for an unattended persona
`approvals.mode = manual` (or `smart` to auto-approve low-risk), `cron_mode = deny`,
**tirith on**, **yolo off**, allowlist locked to you, and credentials scoped to the
minimum that persona needs — all set from the control plane.

---

## Quick command map (control plane)

| Goal | Command |
|---|---|
| Inspect a session/profile | `hermes profile show <name>` · `hermes gateway status` |
| Force a fresh chat | send `/new` or `/reset` in the chat |
| New persona | `hermes profile create <name>` → edit its `SOUL.md` |
| Run a persona's gateway | `hermes -p <name> gateway start` (s6) |
| Lock persona to a user | `hermes config set telegram.allow_from <id>` |
| Add a tool credential | `railway variable set 'KEY=...' -s <svc>` → redeploy |
| Enable/inspect tools | `hermes tools enable <name>` · `hermes tools list` |
| Add MCP server | edit `mcp.json` (or `hermes mcp …`) |
| Cultivate memory | edit `memories/MEMORY.md` / `USER.md` |
| Approve a risky cmd | reply `/approve` / `/deny` in the chat |
| Back up the persona | `scripts/backup-pull.sh` (excludes secrets) |

## Source map (verify after upgrades)
`gateway/session.py` (keys, ids, reset, resume) · `gateway/config.py` (reset policy,
approvals, channel_prompts) · `gateway/authz_mixin.py` (allowlists) ·
`hermes_cli/container_boot.py` (per-profile gateway reconcile) ·
`hermes_cli/gateway.py` (ProfileGatewayProcess) · `tools/approval.py` (approvals,
tirith, yolo floor) · `tools/lazy_deps.py` (credentialed backends) ·
`tools/web_tools.py` / `tools/tool_backend_helpers.py` (env-read keys) ·
`hermes_cli/profiles.py` (profile identity files).
