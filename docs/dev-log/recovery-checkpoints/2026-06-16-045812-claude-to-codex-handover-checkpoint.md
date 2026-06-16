# Recovery checkpoint — Claude → Codex handover (gllvmTMB folder)

2026-06-16 04:58. Claude (Opus 4.8) handing the **gllvmTMB folder** to Codex.
Full pickup brief: `docs/dev-log/2026-06-16-codex-handover.md` (read it first).

## Current branch and `git status --short`

- Branch: **`engine-julia` @ `7c5bcde`**.
- `git status --short`: *empty* (working tree clean, nothing uncommitted,
  nothing untracked).
- **72 commits ahead of `origin/engine-julia`** — all local, **nothing pushed**.

## Changed files / `git diff --stat`

- Nothing uncommitted (`git diff --stat` is empty). All work is committed.
- The 72 unpushed commits implement + verify the `engine="julia"` bridge
  continuation (accessors, parity, guards, audits, NEWS/ledger). See the
  handover doc §3 for the commit story.

## Commands already run, with exact outcomes

- `testthat::test_local(".")` → **PASS 3151 / FAIL 0 / ERROR 0** (240 files).
  (Count `failed + error`, not `failed` alone — a prior summary that summed only
  `failed` hid a test-only error.)
- Live heavy+julia bridge — `GLLVM_JL_PATH=…/GLLVM.jl-integration
  GLLVMTMB_HEAVY_TESTS=1`, `options(gllvmTMB.julia_home="…/.juliaup/bin")`,
  `devtools::test(filter="julia-bridge")` → **841 / 0 / 0 / 0-skip** vs engine
  `1dc9e98`.
- Engine `Pkg.test()` (GLLVM.jl-integration) → 3943 / 0 (inherited; untouched).
- Remote check: `origin/main @ 9fc9b7f` is a **CRAN candidate** (--as-cran
  0E/2W/3N) already carrying the early `engine="julia"` bridge (PR #473).
  `engine-julia` is 71-ahead / 18-behind it; merge-base `7a7e2096`.

## Commands that still need to run (blocked on a maintainer decision)

- gllvmTMB merge `engine-julia` → `origin/main` (≈13 conflicts incl. R code;
  list in handover doc §4), **then** re-run `R CMD check --as-cran` and
  reconcile the 0E/2W/3N baseline before any push.
- (Separately) GLLVM.jl `codex/non-gaussian-fitter-gradients` vs the v0.3.0
  `main` — major reconciliation; **do not merge blind**.

## Next safest action

1. Read `docs/dev-log/2026-06-16-codex-handover.md` (complete state + decisions).
2. Surface decisions A–C to the maintainer; **do not push or merge to any
   `main` without explicit approval.**
3. If approved to back up the work without touching `main`, the safe step is to
   push `engine-julia` to `origin/engine-julia` (feature branch only).

## Blocking question for the maintainer

**CRAN timing:** does the full `engine="julia"` continuation go into *this*
CRAN submission (merge → re-check `--as-cran` → push) or the *next* one (keep
CRAN-main lean on the #473 bridge; push the feature branch / open a PR and hold
the main-merge)? The maintainer paused exactly here. Also pending: the
dispersion/cutpoint engine-alignment decision (handover doc §5).
