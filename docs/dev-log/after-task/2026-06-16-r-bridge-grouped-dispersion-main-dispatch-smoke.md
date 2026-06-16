# After Task: R Bridge Grouped-Dispersion Main-Dispatch Smoke

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: `Ada / Shannon / Hopper / Karpinski / Gauss / Noether / Curie / Rose / Grace`

## 1. Goal

Close the immediate R-route evidence gap left by the grouped-dispersion payload slice: prove that `gllvmTMB(..., engine = "julia")` itself routes NB2, NB1, Beta, and Gamma no-X reduced-rank fits to the paired Julia grouped-dispersion payload, and add only the native objective parity assertions that the current R/TMB oracle can honestly support.

## 2. Implemented

- Added shared two-trait grouped-dispersion fixtures for NB2, NB1, Beta, and Gamma to `tests/testthat/test-julia-bridge.R`.
- Reused those fixtures in the existing low-level `gllvm_julia_fit()` grouped-dispersion test to avoid duplicated data literals.
- Added a live Julia main-dispatch test through `gllvmTMB(..., engine = "julia")` for all four grouped-dispersion families.
- Added selected native `engine = "tmb"` comparisons inside the same test: NB2 and Beta compare `df` and log-likelihood within fixture-specific tolerances; NB1 checks the native per-trait report shape but does not claim objective parity; Gamma remains route/shape-only because the native ordinary Gamma route still uses shared `sigma_eps`, not a per-trait `alpha` report slot.
- Updated validation-debt row `JUL-01` to record the new evidence and keep the row `partial`.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd, vignette, or pkgdown navigation change. The test contract is the current no-X reduced-rank bridge shape:

- R formula: `value ~ 0 + trait + latent(0 + trait | unit, d = 1)`.
- Julia route: one `p x n` response matrix, per-trait intercepts, rank-1 loadings, and grouped dispersion for NB2 (`r`), NB1 (`phi`), Beta (`phi`), and Gamma (`alpha`).
- Public-scale fields remain conversions, not engine parameters: NB2 `sigma = 1 / sqrt(r)`, NB2 `gllvm_phi = 1 / r`, NB1 `phi`, Beta `sigma = 1 / sqrt(phi)`, Gamma `sigma = 1 / sqrt(alpha)`.

## 4. Files Changed

- Tests: `tests/testthat/test-julia-bridge.R`
- Validation register: `docs/design/35-validation-debt-register.md`
- Dev log: `docs/dev-log/check-log.md`
- Recovery checkpoint: `docs/dev-log/recovery-checkpoints/2026-06-16-084756-codex-checkpoint.md`
- After-task report: `docs/dev-log/after-task/2026-06-16-r-bridge-grouped-dispersion-main-dispatch-smoke.md`

## 5. Checks Run

- Compaction recovery:
  `git status --short --branch` -> clean on `codex/r-bridge-grouped-dispersion`.
  `git diff --stat` -> no output before the checkpoint.
  `find docs/dev-log/recovery-checkpoints -type f -name '*.md' -print | sort | tail -n 1` -> only `docs/dev-log/recovery-checkpoints/README.md` before this slice.
  `tail -n 120 docs/dev-log/check-log.md` -> newest visible historical entries loaded.
- Pre-edit lane check:
  `gh pr list --state open --limit 20 --json number,title,headRefName,updatedAt,isDraft,url` -> `[]`.
  `git log --all --oneline --since="6 hours ago" -- tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/recovery-checkpoints`
  -> current Codex programme commits only, ending at `b4baed4 docs: add cross-twin wording contract`.
- Paired Julia checkout:
  `git status --short --branch && git log -1 --oneline` in `../GLLVM.jl-integration`
  -> `## codex/julia-per-trait-dispersion`; `2a07745 feat(bridge): add per-trait ordinal cutpoints`.
- Source inspection:
  `rg -n "phi_gamma|gamma|Gamma|phi_beta|phi_nbinom" R src tests/testthat`
  -> native ordinary Gamma uses `sigma_eps`; NB2/NB1/Beta have per-trait report slots.
  `sed -n '1,260p' tests/testthat/test-julia-bridge.R`;
  `sed -n '260,560p' tests/testthat/test-julia-bridge.R`;
  `sed -n '457,630p' R/julia-bridge.R`;
  `sed -n '1,130p' tests/testthat/test-matrix-gamma-unit.R`;
  `sed -n '160,210p' tests/testthat/test-crosspkg-nbinom2-glmmTMB.R`;
  `sed -n '250,390p' R/julia-bridge.R`;
  `sed -n '990,1025p' R/methods-gllvmTMB.R`;
  `sed -n '488,506p' docs/design/35-validation-debt-register.md`.
- Exploratory parity probe:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla - <<'RS' ...`
  -> NB2 and Beta had close native-vs-Julia log-likelihoods on the small no-X fixture; NB1 returned finite fits but objective drifted; Gamma returned finite fits but native `df = 5` because ordinary Gamma uses shared `sigma_eps` while Julia grouped Gamma has two `alpha` values.
- Whitespace:
  `git diff --check` -> clean.
- Targeted live bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 177` in 30.8 s.
- Targeted no-Julia bridge test:
  `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge")'`
  -> `FAIL 0 | WARN 0 | SKIP 4 | PASS 59` in 2.0 s.
- Stale-claim scans:
  `rg -n "full native parity|full parity|complete bridge|covered.*Julia|ci_no_x.*negbinomial|ci_no_x.*nb1|ci_no_x.*beta|ci_no_x.*gamma|native-vs-Julia parity" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-16-r-bridge-grouped-dispersion.md`
  -> expected historical and negative-scope hits only; no new full-parity or CI overclaim.
  `rg -n "Gamma.*per-trait|per-trait.*Gamma|sigma_eps|alpha|phi_gamma|phi_nbinom1|NB1|nb1" R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-16-r-bridge-grouped-dispersion.md`
  -> expected hits documenting NB1/Gamma grouped-dispersion scope and the native Gamma `sigma_eps` boundary.

Deliberately not run:

- Full `devtools::test()`, `devtools::check()`, `devtools::document()`, `pkgdown::check_pkgdown()`, and article renders were not run. This slice changed a targeted bridge test plus dev-log/validation prose; no roxygen, NAMESPACE, Rd, vignette, README, NEWS, or pkgdown navigation file changed.
- No GitHub issue was commented on or closed.

## 6. Tests Of The Tests

- Feature combination: the new test combines the Julia grouped-dispersion payload with the public `gllvmTMB()` main dispatch, rather than testing only the lower-level `gllvm_julia_fit()` wrapper.
- Boundary: the test intentionally separates rows with objective parity evidence from rows with only route/shape evidence. NB1 and Gamma are not forced green as native parity rows.
- The test would fail if the R dispatch kept blocking grouped-dispersion families, dropped trait/unit labels, returned scalar/shared dispersion for a two-trait grouped row, lost the public-scale conversion, or accidentally claimed `df`/log-likelihood parity for rows without current evidence.

## 7. Consistency Audit

`JUL-01` remains `partial` and now records the exact evidence tier: all four grouped-dispersion families pass the main-dispatch smoke; NB2 and Beta have selected small-fixture native objective parity; NB1 and Gamma stay scoped to route/shape evidence. No user-facing examples changed, so the AGENTS.md convention-change cascade is not triggered.

## 8. Roadmap Tick

No `ROADMAP.md` row changed. This is validation evidence under `JUL-01` and feeds the bridge gate-vs-engine drift issue lane (`gllvmTMB#488`).

## 8a. GitHub Issue Ledger

No issue was commented on or closed. `gllvmTMB#488` remains the right umbrella for this evidence, but issue action still needs a live `gh issue view`, linked local evidence, and Shannon/Rose signoff.

## 9. What Did Not Go Smoothly

The first broad `rg` in the paired Julia checkout walked generated `docs/node_modules` content and had to be interrupted. The focused follow-up used source/test/design files instead. The exploratory fit also exposed a sharper gap than expected: ordinary native Gamma is still shared-`sigma_eps`, so a per-trait Gamma parity claim would be premature.

## 10. Team Learning

- Ada: kept the slice at evidence hardening, not a capability promotion.
- Shannon: compaction recovery wrote a checkpoint before edits; pre-edit PR and recent-commit checks found no collision.
- Hopper: main-dispatch routing is now covered for NB2, NB1, Beta, and Gamma grouped-dispersion rows.
- Karpinski: paired runtime truth remains `GLLVM.jl-integration@2a07745` on `codex/julia-per-trait-dispersion`.
- Gauss / Noether: NB1 and Gamma are explicitly held out of broad native objective parity until parameterisation differences are resolved.
- Curie: the new test is an acceptance-case companion to the earlier payload test and catches R-route drift.
- Rose: validation wording says `partial`, separates route/shape evidence from native objective parity, and records exact stale-claim scans.
- Grace: targeted live bridge tests pass; broader package gates remain later release checks.

## 11. Known Limitations And Next Actions

- NB1 needs a focused native-vs-Julia parameterisation audit before objective parity can be asserted.
- Ordinary Gamma needs a maintainer decision: either native R/TMB grows per-trait Gamma shape/CV support, or the Julia bridge must label Gamma as non-oracle-matching until the R oracle changes.
- Grouped-dispersion CI endpoints remain unavailable.
- Response masks, non-Gaussian fixed-effect X through the main dispatch, mixed-family promotion, structured terms, and post-fit extractor parity remain gated.
