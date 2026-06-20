# Upstream contribution plan — NousResearch/hermes-agent

A plan to turn what we discovered (and fixed) during the Railway deployment work
into accepted contributions to the **original** Hermes repo. Written to be
iterated on before we fork + code.

> Status: DRAFT for discussion. Nothing pushed upstream yet.

---

## 1. What we have to offer (evidence in hand)

Through deploying + cloning Hermes on Railway we hit real, reproducible problems
and built working fixes. Each is backed by measurements, not opinions:

| Finding | Evidence we gathered | Upstream issue |
|---|---|---|
| **`hermes profile export` bloats** — it stages the *entire* `HERMES_HOME` (tool venvs, 123 MB `state.db`, caches) into `/tmp` before tarring | On a live container: **3.1 GB `/tmp` staging + 265 MB tarball**. Our lean identity tar = **31 KB**. | open **#6078** (no clean migration); related to **#11560** |
| **`hermes profile --clone-all` crashes** with `RecursionError` on venv symlinks | The agent's `.venv-codex`/`.venv-gcal` contain parent symlinks → `shutil.copytree` (no `symlinks=True`) infinite-recurses | open **#11560** / **#4306** (PRs #11829/#11573 reportedly incomplete) |
| **Gateway RSS doesn't return to the OS** after heavy runs (native-allocator residual) | Container peaked ~431 MB anon heap; a restart dropped it to ~120 MB; `tracemalloc` undercounts vs RSS (glibc retention). Setting `MALLOC_ARENA_MAX=2` is the standard mitigation. | closed **#19251** (object fix #41975) + open **#48287** (residual) |

We also built, and validated live, the **lean/selective export + private-network
clone** flow (`scripts/identity-export.sh`, `identity-import.sh`, `clone-agent.sh`)
— the practical pattern #6078 is asking for.

---

## 2. How they accept contributions (their rules)

- **Priority order** (from `CONTRIBUTING.md`): 1) bug fixes, 2) cross-platform,
  3) security, 4) **performance/robustness**, 5) skills, 6) tools, 7) docs.
- **Issue first**, then a PR that links it. PR template wants: clear *what/why*,
  `Fixes #`, change type, file-level changes, and a **How to Test** with
  reproduction + proof-of-fix, plus a checklist.
- **Dev setup**: Python 3.11 venv → `uv pip install -e '.[all]'` → symlink `hermes`.
- **Tests**: `scripts/run_tests.sh` (matches CI: hermetic, no network, xdist) or
  `pytest tests/ -v`. New tests are hermetic (use `monkeypatch`/`tmp_path`), and
  cross-platform: symlink/file-mode tests guard with `@pytest.mark.skipif`.
- **Lint/type**: `ruff` + `ty` (both pinned in the `dev` extra).
- **No CLA/DCO** found — lowers the barrier.
- They care a lot about **cross-platform** (macOS/Linux/WSL) and **no network in
  tests** — design fixes accordingly.

---

## 3. Contribution candidates → sequence

Lead with a small, high-signal change to learn their process and build rapport,
then the flagship.

### Phase 0 — setup (no upstream interaction yet)
1. Fork `NousResearch/hermes-agent`; clone; create the 3.11 venv; `uv pip install
   -e '.[all]'`; run `scripts/run_tests.sh` to confirm a **green baseline**.
2. Skim a recently *merged* PR (e.g. the memory fix **#41975**) to match tone,
   commit style, and test expectations.

### Phase 1 — warm-up PR: `MALLOC_ARENA_MAX` (performance/robustness, tiny)
- **Why it's a good first PR**: one-line, low-risk, directly tied to open memory
  issues, and we have measurements. Aligns with priority #4.
- **Issue**: comment on **#48287** (and #19251) with our data — the residual is
  *native-allocator retention*, and `MALLOC_ARENA_MAX` caps glibc's per-thread
  arenas. Propose setting it in the official image.
- **Change**: add `ENV MALLOC_ARENA_MAX=2` to `docker/Dockerfile` (the published
  image). Optionally a follow-up: call `ctypes` `malloc_trim(0)` after a gateway
  turn completes (bigger, needs care — keep separate).
- **How to test**: before/after RSS under a heavy run; note it's a Docker env, so
  it's verified empirically (no unit test needed) + a `docs/` note.
- **Risk/peer**: maintainers may want to weigh the small multi-thread-alloc
  throughput tradeoff — be ready with the "I/O-bound gateway" argument.

### Phase 2 — flagship: lean / selective `profile export` (addresses #6078)
- **Issue**: comment on **#6078** with our measurements (265 MB + 3.1 GB staging
  → 31 KB) and the proposed design; ask the maintainers which shape they prefer.
- **Design options** (decide *with* them before coding):
  - **(a) Don't stage the whole home** — tar selected paths directly (no `/tmp`
    full-copy), and **exclude regenerable dirs by default** (the `.venv*`, caches,
    `state-snapshots/`, `backups/`). They already exclude `state.db`/`sessions`
    for `--clone-all`; extend that exclusion set to `export` and add the venvs.
  - **(b) A selective flag**: `hermes profile export --identity` (memories, SOUL,
    config, skills, cron) with opt-in `--with-secrets` / `--with-state`. Mirrors
    our `identity-export.sh` flag design.
  - Likely answer: **(a) as the default fix + (b) for control.**
- **Where**: the export implementation in `hermes_cli/profiles.py` (+ the parser
  in `hermes_cli/subcommands/profile.py`). Confirm the staging code on `@main`
  first.
- **Tests**: `tests/` — build a fake `HERMES_HOME` with a `tmp_path`, include a
  recursive **symlink** + a fake big file, assert the export (1) excludes them,
  (2) stays small, (3) doesn't crash. Guard symlink creation with the Windows
  skip. Hermetic, no network.
- **Bonus**: this naturally also fixes/relieves **#11560** (no more copytree over
  venvs) — mention it.

### Phase 3 — optional: direct fix for `#11560` (bug fix, priority #1)
- If still open/unfixed after Phase 2: a focused `symlinks=True` (or pre-filter)
  in the clone path + a regression test (recursive symlink → no `RecursionError`).
  Note the prior PRs (#11829/#11573/#6163) so we don't duplicate.

---

## 4. What each PR contains (template-ready)

For every PR, fill the upstream template:
- **What/why** — the problem + our measured evidence.
- **Related Issue** — `Fixes #` (Phase 1 → #48287; Phase 2 → #6078; Phase 3 → #11560).
- **Type** — Phase 1: 🎯 performance / 📝; Phase 2: ✨ feature (+ ♻️); Phase 3: 🐛 bug.
- **How to Test** — exact repro (our numbers) + the new test command
  (`scripts/run_tests.sh tests/test_<x>.py -q`).
- **Checklist** — ran `scripts/run_tests.sh`, `ruff`, `ty`; cross-platform guards.

---

## 5. Immediate next actions
1. **Decide the lead**: Phase 1 (MALLOC, fast) first — agreed? Or go straight to
   the flagship (#6078)?
2. **Confirm `@main` code**: read the real `profile export` staging in
   `hermes_cli/profiles.py` on the latest `main` (our local copy is v0.16.0).
3. **Draft the issue comments** (#48287 and/or #6078) with our evidence — get a
   maintainer signal *before* writing the PR code.
4. Fork + green baseline + branch.

> Open question for you: do you want to **co-author under your GitHub handle**
> (yuting1214) and keep our template repo private as the "lab", contributing only
> the upstream-relevant diffs? (Recommended — keep the Railway template ours,
> upstream just the Hermes-core fixes.)
