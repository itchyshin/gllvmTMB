# After-task — resolve #505 auto-Psi heavy-test regressions

**Date:** 2026-06-20 · **Author:** Claude (Ada) · **Branch:**
`claude/psi-heavy-fixes-20260620` → **PR #509 (HELD)** · **Scope:** two distinct
heavy-test regressions introduced by the #505 `latent()` auto-Psi default, both
on merged `main` (581af50).

## Why this work exists

A belt-and-suspenders combined-`main` verification (after merging #505 / #506 /
#507) found that merged `main` regressed the heavy suite relative to the pre-#505
baseline (92e246b), even though each individual PR's CI was green — the heavy
recovery/coverage tests are gated behind `GLLVMTMB_HEAVY_TESTS` and do not run on
routine PR CI. Two independent root causes were isolated.

## Root cause 1 — binary auto-Psi reaches the B tier (unidentified)

`latent()` now emits a default between-unit Psi companion (`diag` over the unit
tier carrying `.auto_residual = TRUE`). For **single-trial Bernoulli / binomial**
traits this between-unit Psi is **unidentified**: each (trait, unit) cell is one
0/1 observation, and the probit/logit link's implicit scale is itself the
between-unit residual (2026-06-12 per-family design table; Nakagawa & Schielzeth
2010). The pre-existing off-family gate only dropped the auto-Psi when *every*
trait was ordinal_probit / delta (all-or-nothing); binary slipped through, and the
W-tier OLRE skip only fires at the per-row tier. So the default Psi reached the
B tier on binary traits and made the fit non-identified.

**Symptoms (merged main):** m2-3 binary IRT non-convergence; loading-ci `cov_rate`
NA.

**Fix** (`R/fit-multi.R`, +67, commit `35f8d67`): a per-trait B-tier auto-Psi
family gate that mirrors the existing W-tier OLRE skip. For single-trial binary
traits it pins `theta_diag_B[t]` near zero and maps both it and the `s_B` row off;
free (identified) traits keep the auto-Psi; `diag_B_common` is honoured.
**Explicit** `unique()` / `indep()` diagonals are untouched — the gate fires only
on the default auto-Psi (`auto_psi_B`, keyed on the `.auto_residual` marker). A
cli message reports the skip and the multi-trial / explicit-`unique()` escape
hatch. A pure-binary fit ends with every B-tier trait skipped — the per-trait
equivalent of dropping the auto-Psi entirely.

## Root cause 2 — profile correlation CI does not contain its estimate at the boundary

Independent of root cause 1 (proven byte-identical on the m1-4 fixture with and
without the binary fix; affects Gaussian–Poisson pairs too).
`profile_ci_correlation()` computes the point estimate `rho_hat` from
`extract_Sigma(link_residual = "none")` — the **latent-scale** correlation, which
for a rank-1 latent block (`d = 1`, `Sigma = Lambda Lambda^T` rank-deficient) is
**exactly ±1**. The refit profile grid is floored/ceiled just inside ±0.999 (to
avoid `atanh(±1) = ±Inf`), so it cannot represent an MLE at the boundary; the
boundary-side bound was returned as the grid edge (±0.999), landing on the *wrong
side* of the estimate. The pre-#505 baseline survived only by luck — the profile
returned a one-sided (NA) bound, so the test's finite-rows bracket check skipped
those rows. The #505 auto-Psi default changed the profile curvature so both bounds
now resolve finite, exposing the latent boundary bug.

**Symptoms (merged main, NOT caused by the binary fix):** m1-4
`extract_correlations(method = "profile")` 3-family fixture — 5 bracket-invariant
failures (`lower <= correlation <= upper`).

**Fix** (`R/profile-derived.R`, commit `5bb6d66`): a boundary guarantee — clamp
finite bounds so `lower <= estimate <= upper` always holds. When the MLE is at the
natural boundary the boundary side collapses to `rho_hat = ±1`, the standard
pinned-parameter CI semantic. No effect on non-boundary CIs (the min/max are
no-ops when the bounds already bracket the estimate).

## Checks (`GLLVMTMB_HEAVY_TESTS=1`, `NOT_CRAN=true`)

| test | baseline 92e246b | merged main 581af50 | PR #509 |
|---|---|---|---|
| m2-3-lambda-constraint-binary | PASS | FAIL 3 (non-convergence) | **11/0** |
| loading-ci | PASS | FAIL (NA cov_rate) | **89/0** |
| m2-3-mirt-cross-check | PASS | — | **4/0** |
| m2-3-galamm-cross-check | PASS | — | **5/0** |
| m1-4-extract-correlations | PASS (vacuous) | FAIL 6→5 | **108/0** |

**Full heavy suite (binary fix only, 581af50 + `35f8d67`):** 243 files, **9575
PASS / 5 FAIL** / 51 SKIP — the *only* 5 failures are the m1-4 profile tests, all
cleared by the profile fix (m1-4 = 108/0 with both fixes). Combined-branch
single-run confirmation: **FAIL 0** (see check-log).

**Three-way m1-4 localisation** (same compiled engine, R toggled via stash):
premerge 92e246b → ±1 point, one-sided NA bounds (PASS, vacuous); merged main
581af50 → ±1 point, two-sided finite bounds (FAIL); merged main + binary fix →
**identical** to 581af50 (binary fix orthogonal).

**Adversarial verification** (workflow w6uht65fe): confirmed the binary skip does
**not** drop identified-family (Gaussian/Poisson) Psi (shared `Lambda Lambda^T`
byte-identical across versions; map = `1,NA,2` keeping Gaussian + Poisson free),
leaves explicit `unique()` diagonals nonzero, and the m1-4 residual is a boundary
artifact, not binary-specific.

## Open notes for the maintainer (not fixed here)

1. **`link_residual` inconsistency in the profile method.** fisher-z / wald report
   the residual-adjusted correlation (`link_residual = "auto"`); the profile method
   reports the latent-scale correlation (`link_residual = "none"`). Same
   `correlation` column, different meaning by method. Left as-is (a larger
   extractor-semantics decision).
2. **Degenerate 3-family fixture.** T = 3, d = 1, one trait per family yields a
   rank-1 latent block → ±1 latent correlations. Mathematically correct, but a poor
   stress test for correlation-CI shape. A future fixture refresh (d = 2 or larger
   loadings spread) would make the profile bracket test exercise interior values.
3. **m1-4 warning volume.** The profile refits on the degenerate fixture emit a
   large warning count (~54k); profiling noise, not a failure.

## Register / promotion

No validation-debt register row promoted (maintainer-gated). The binary-skip
behaviour should be reflected in the per-family Psi documentation when the Psi
doctrine doc is next revised.
