# Handover to Codex — gllvmTMB × GLLVM.jl twin (2026-06-16)

Written by Claude (Opus 4.8) for a complete pickup. Self-contained: you should
be able to act from this alone. Maintainer: Shinichi Nakagawa (itchyshin).

## 0. Read-first / do-first

- **Both repos are clean. NOTHING is pushed.** Two long-lived feature branches
  hold completed, verified work that is *not yet on either remote `main`*.
- **The work itself is done and green.** What remains is **landing it** (merges)
  and **two maintainer decisions** — not new features.
- **Hard rule: do NOT push or merge to any `main` without the maintainer's
  explicit go.** Surface decisions; do not make them. Stage files by name
  (never `git add -A`). End commit messages with the Co-Authored-By trailer.

## 1. The twin

- **gllvmTMB** (R) — the user surface + statistical oracle. `engine = "julia"`
  bridges to the Julia engine via JuliaCall → `bridge_fit`.
- **GLLVM.jl** (Julia) — the engine. The *live bridge runtime* is the separate
  worktree **GLLVM.jl-integration** (currently `1dc9e98`), NOT the `GLLVM.jl`
  board/dev branch.
- R-first: the R surface leads; Julia mirrors only rows the R ledger admits.

## 2. Exact repo state (verified 2026-06-16)

### gllvmTMB  (worktree: …/gllvmTMB)
- Branch **`engine-julia` @ `9e42631`**, clean. **71 commits ahead of
  `origin/engine-julia`** (all local, unpushed).
- **`origin/main` @ `9fc9b7f`** — `engine-julia` is **71 ahead / 18 behind**
  it. merge-base = `7a7e2096`.
- `origin/main` is a **CRAN candidate**: `cran-comments.md` carries a real
  `R CMD check --as-cran` tally of **0 errors / 2 warnings / 3 notes**, plus an
  **early `engine="julia"` bridge already merged via PR #473** (`fa2bf71`,
  `238af7e`, `b4a84fb`, `7a7e209`) and bridge exports registered in
  NAMESPACE/NEWS (#486/#487). The `engine-julia` branch is the *far more
  advanced* version of that same bridge.

### GLLVM.jl  (worktree: …/GLLVM.jl — board/dev)
- Branch **`codex/non-gaussian-fitter-gradients` @ `1b42e35`**, clean.
  **50 ahead of its origin**; **119 ahead / 29 behind `origin/main` (`9406e22`)**.
- `origin/main` is a **v0.3.0 release** (two-part fitters, analytic-grad
  default, unified `gllvm()` API, Conway–Maxwell–Poisson; PRs #81–#90). The
  codex branch diverged earlier and may be **largely superseded** by v0.3.0.

## 3. What was completed (the engine="julia" bridge continuation)

All on `gllvmTMB@engine-julia`, local-only, verified. Recent commits
(`78d887b`→`9e42631`): `extract_cutpoints()`, `extract_Sigma_B()`,
**`trait_families.gllvmTMB_julia`** (fixed a false "done" — it was multi-only),
`tidy(effects="cutpoint")`, regression tests locking phylo/structured-term +
multi-rr refusal, NEWS + ledger. Plus the broader pre-existing bridge surface
(Pearson residuals, ordinal `predict(prob/class)`, getResidualCov/Cor, mixed +
masked + fixed-X parity for Gaussian/Poisson/Binomial, NB/Beta/Gamma/ordinal
point fits, Gaussian REML no-X, CI-status strings).

**Two independent audits:** claim-surface honesty (1 LOW → fixed; surface is
honest) and a completeness-critic gap-audit (verdict **EXHAUSTED** — every
remaining accessor is degenerate/unwired by design, no `bridge_capabilities`
contract mismatch). The safe, in-scope bridge surface is **complete**.

**Verification (all green):**
- gllvmTMB canonical `testthat::test_local()` → **PASS 3151 / FAIL 0 / ERROR 0**
  (240 files). Use `failed + error`, not `failed` alone.
- Live heavy+julia bridge (`GLLVM_JL_PATH=…/GLLVM.jl-integration
  GLLVMTMB_HEAVY_TESTS=1`, `options(gllvmTMB.julia_home="…/.juliaup/bin")`,
  `devtools::test(filter="julia-bridge")`) → **841 / 0 / 0 / 0-skip** vs engine
  `1dc9e98`.
- Engine `Pkg.test()` → 3943 / 0 (inherited; bridge work did not touch it).

## 4. The merge situation (actionable)

### gllvmTMB: `engine-julia` → `origin/main`
- Target is **`origin/main`** (NOT the stale local `main`).
- A trial merge of `origin/main` into `engine-julia` flags **~13 conflict
  candidates** (changed on both sides since `7a7e2096`): `NAMESPACE`, `NEWS.md`,
  `R/extract-correlations.R`, `R/gllvmTMB.R`, `R/output-methods.R`,
  `R/z-confint-gllvmTMB.R`, `README.md`, `cran-comments.md`,
  `docs/dev-log/check-log.md`, `man/confint.gllvmTMB_multi.Rd`,
  `man/extract_correlations.Rd`, `man/gllvm_julia_fit.Rd`,
  `man/gllvm_julia_setup.Rd`. Mostly additive overlaps (export/NEWS/man +
  bridge-docstring edits) — tractable but real R-code conflicts.
- **`check-log.md` resolution pattern:** both sides are append-only logs; take
  the **union in chronological order** (no content dropped).
- **CRAN gate:** because `origin/main` is a submission candidate, after any
  merge re-run `R CMD check --as-cran` and reconcile the 0E/2W/3N baseline
  before considering a push.

### GLLVM.jl: `codex/non-gaussian-fitter-gradients` vs `origin/main` (v0.3.0)
- **18 conflict candidates incl. core engine source** (`src/GLLVM.jl`,
  `src/families/{beta,binomial,gamma,laplace,negbin,ordinal,poisson}.jl`,
  `src/confint_profile.jl`, `test/runtests.jl`, + docs). This is a **major
  reconciliation**, and v0.3.0 likely supersedes much of the branch. **First
  question for the maintainer: reconcile or abandon the branch?** Do not merge
  blind.

## 5. Open decisions — surface to the maintainer, do NOT decide

1. **gllvmTMB CRAN timing.** Does the full `engine-julia` continuation go into
   *this* CRAN submission (merge → re-run `--as-cran` → push, larger surface) or
   the *next* one (keep CRAN-main lean on the #473 bridge; push `engine-julia`
   as a feature branch / PR and hold the main-merge)? The maintainer was
   weighing exactly this and asked to pause.
2. **Dispersion / ordinal-cutpoint engine alignment (the headline twin-fidelity
   gap).** `GLLVM.jl` uses a **single shared scalar** dispersion (and shared
   ordinal cutpoints) where native `gllvmTMB` estimates **one per trait** → df
   differ by `n_traits − 1`, so NB2/NB1/Beta/Gamma/ordinal **cannot point-parity
   until the engines align**. Not transform-fixable. Two options (maintainer's
   call), see `docs/dev-log/2026-06-15-dispersion-structure-divergence.md`.
3. **GLLVM.jl branch fate** vs the v0.3.0 `main` (§4).

## 6. Binding constraints (the 7 amendments — still in force)

1. R-first sequencing. 2. **REML = Gaussian-only** (no non-Gaussian/Laplace
REML, no REML CIs). 3. Mixed-family bridge = complete-balanced, trait-aligned,
**no-X / no-mask / no-CI point fits only**, capped `partial`. 4. **NB1
fixed-effect-X excluded.** 5. Non-Gaussian-X CIs → **CI-status strings**, never
endpoints. 6. **Masked-response CIs & simulations rejected** (point fits +
in-sample post-fit only). 7. **Status vocabulary** covered/partial/experimental/
planned/unsupported — **no "full"/"complete"/"full parity"** claims.
Plus: no push without approval; stage by name; one concern per commit; verify
(`failed + error`) before claiming; honest reporting; Co-Authored-By trailer.

## 7. Where to read more

- `docs/dev-log/2026-06-15-overnight-capability-run.md` — full continuation
  ledger (commit table, parity matrix, audits, verification tallies).
- `docs/dev-log/2026-06-15-dispersion-structure-divergence.md` — the headline
  finding + the two alignment options.
- gllvmTMB `NEWS.md` (dev section) — honest user-facing changelog of the bridge.
- GLLVM.jl `docs/dev-log/coordination-board.md`, `capability-bridge-matrix.md` —
  Codex's governing board + capability ledger.

## 8. Out of scope — do NOT attempt without the maintainer

- Engine-algorithm work (per-trait dispersion/cutpoints, structured-dependence/
  phylo bridge, O(p) sparse-grad, mi-FIML). **#92 phylo-signal CI is fit-level
  blocked** (the bridge rejects phylo terms at dispatch) — gated behind the
  structured-dependence track, locked in a test.
- Amendment-held cells (§6 items 3–6).
- Articles / vignettes / visuals — **deferred; done with the maintainer.**
