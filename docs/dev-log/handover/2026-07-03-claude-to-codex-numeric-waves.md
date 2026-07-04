# Claude → Codex handoff: numeric / twin / Julia issue waves

**From:** Claude (issue-clearing campaign, 2026-07-03). **To:** Codex (live R/TMB + Julia toolchain).
**Context:** Twin code review filed 160 issues. Claude is clearing the LOW-RISK R fixes in files
byte-identical to `origin/main` (PR #707 plotting guards; `fix/dead-code-cleanup` batch 2). This
brief hands Codex the work that needs the live toolchain, touches Codex-churned files, or is
HIGH-RISK (likelihood/family/grammar/C++/Julia numerics).

## Rules
- DoD: simulation-recovery test for any likelihood/family/keyword/estimator change; roxygen+man;
  check-log; after-task; close each issue with `Fixes #NNN`.
- HIGH-RISK (grammar/likelihood/family/C++/Julia numerics) → maintainer checkpoint before merge.
- Twin divergences (Part C) are GATED on the maintainer's canonical-side ruling (matrix in
  `~/.claude/plans/indexed-skipping-tower.md`). Do not implement a side before the ruling.

## Part A — gllvmTMB correctness/robustness in Codex-churned files (no canonical ruling needed)
These are unambiguous R bugs, but they live in files Codex is actively editing
(`fit-multi.R`, `z-confint-gllvmTMB.R`, `extract-omega.R`, `extract-sigma*.R`,
`methods-gllvmTMB.R`, `output-methods.R`, `julia-bridge.R`, `extract-correlations.R`,
`kernel-helpers.R`, `plot-covariance-tables.R`), so Claude did not touch them to avoid collision.
Fix on Codex's tree:
- #615 output-methods.R — VP() adds σ_eps² for non-Gaussian traits (only add residual for Gaussian/lognormal).
- #620/#621 z-confint-gllvmTMB.R — Wald Sigma diagonal CI uses residual ψ under latent(); add the `rr_used` guard the profile path already has.
- #677 extract-omega.R — extract_phylo_signal per-trait zero denominator → NaN; make the `sum(V_eta)>0` guard per-trait.
- #678 methods-gllvmTMB.R — `as.integer(median(fid))` truncates to wrong family; use round()/majority.
- #679 profile-derived-curves.R — deviance baseline differs (joint MLE vs grid min); standardise to `fit$opt$objective`.
- #681 extract-omega.R — extract_proportions() NaN for zero-variance trait.
- #682 extract-sigma.R — correlation matrix nulled entirely on any single zero diagonal; null only that row/col.
- #683 extractors.R — extract_ICC_site 0/0 when vB+vW=0; guard.
- #695 z-confint-gllvmTMB.R — pinned Lambda entry under method='profile' returns all-NA with no 'pinned' status.
- #696 julia-bridge.R — dispersion vector silently → NA on length mismatch; error instead.
- #610 fit-multi.R — mixed-family list matched by sorted order, ignoring list names.
- #612 fit-multi.R — sparse Ainv `[levs,levs]` subset = conditional not marginal precision.
- #614 methods-gllvmTMB.R — lognormal predict() returns median not conditional mean.
- #645 methods-gllvmTMB.R — predict() newdata aligns coefs by position not name.
- #596 methods-gllvmTMB.R — propto phylo RE simulated with lam_phy² not lam_phy.
- #588 extract-sigma-table.R — cannot reach cluster2/kernel tiers.
- #632/#587/#663 extract-omega.R — non-conformable crash / spurious deprecation warning / wide-format returns absolute not proportion.
- #586/#631/#670 extract-correlations.R — tier dropped on bootstrap fallback / magic-30 effective-N / refit-per-tier.
- #608 brms-sugar.R — augmented latent(1+x|unit) ignores `residual=`, no Psi companion. (HIGH-RISK: parser.)
- #664 extract-sigma-table.R — part="unique" spurious off-diagonal zero Psi rows.
- #672/#673/#674 fit-multi.R — dead has_int / A_proj overwrite / redundant grepl (cleanup).
- #634/#635/#636 fit-multi.R — betabinomial weights misused / residual-SD NaN floor / propto subsets precision not covariance. (HIGH-RISK: likelihood.)
- #640/#641/#642 julia-bridge.R — empty-family→ordinal / residuals() global abort / duplicate (trait,unit) collapse.
- #643 kernel-helpers.R — profile_cross_rho length>1 best_rho on ties.
- #650 plot-covariance-tables.R — correlation fill not clamped to scale limits.

### HIGH-RISK C++ (src/gllvmTMB.cpp) — needs tmb-likelihood-review + recovery test
- #658 — AD-unsafe ternary probability clipping frozen at tape construction.
- #659 — no positivity guard for lognormal (fid 3) / Gamma (fid 4) responses.
- #622 — Gamma dispersion aliased to shared σ_eps (TWIN, see Part C).

## Part B — GLLVM.jl REAL issues (37, all Julia lane) — see /tmp/gjl.json for bodies
Confirmed REAL (A2 verify): all of #128–#164 except INTENDED #142 (NaN-on-flat by design),
#148 (global-φ deliberate — TWIN, maintainer decides), and ALREADY-FIXED #144.
Grouping: bug/correctness twin math (#128,#129,#130,#131,#132,#133,#134,#135,#136,#137) — see Part C;
robustness (#138–#155 guards: exception swallowing, non-converged bootstrap inclusion, div-by-zero,
OOB, RNG reproducibility, workspace aliasing, boundary guards); convention (#156–#159);
cleanup (#160–#164). Each needs a Julia test (`julia --project=. test/runtests.jl`, never Pkg.test).

## Part C — Twin divergences (GATED on maintainer canonical-side ruling)
Implement the chosen side on BOTH trackers together. Recommended sides (maintainer confirms):
- #611 phylo log-det sign → fix R (+sum(log(dii))).
- #622 Gamma dispersion coupling → fix R to Julia's independent-shape design.
- #132 NB2 / #148 Beta dispersion granularity → fix Julia to R's per-trait vector (NOTE #148 verify flagged Julia global-φ as possibly deliberate — maintainer decides).
- #135 W-tier cross-trait covariance → fix Julia to C++ shared-latent.
- #128 phylo_signal H2 denominator → fix Julia to total-variance.
- #129 sigma_phy Wald/profile scale → fix Julia to log-SD both.
- #136 phylo_unique SD link → fix Julia to C++ log link.
- #131 communality denominator → maintainer decides (recommend Julia→R tier-local).
- #680↔#133 ordinal probit+per-trait (R) vs logit+shared (Julia) → maintainer decides (verify: R probit is DELIBERATE/documented; recommend R canonical). #680 is INTENDED on the R side.
