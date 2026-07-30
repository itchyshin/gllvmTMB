# After-task — the gaussian arm of Slice 1, VGH pluralism lane

Date: 2026-07-30. Author: Claude (Claude Code). Lane: `claude/vgh-pluralism-20260730`,
worktree `/private/tmp/gllvmtmb-vgh-pluralism`. Plan:
`~/.claude/plans/gaussian-arm-of-slice-quirky-elephant.md`.

## 1. Goal

Run the gaussian arm of Slice 1: match the dispersion parameterisation across the Laplace and
VGH engines and score recovery against known truth, making **no accuracy claim in either
direction until the parameterisations match**. The arm was re-scoped mid-flight when the
premise turned out to be false (see §3a).

## 2. Implemented

**The re-scope, which is the substantive result.** On gaussian, Laplace is exact and the VGH
ELBO is exact, so **both engines optimise the same objective** — stated in
`dev/vgh/vgh-bench.R:2-3` and corroborated at `tests/testthat/test-vgh-oracle.R:54-60`. Two
consequences: "which estimator is more accurate" is not well-posed on gaussian (same objective
⇒ same MLE), and VGH's anti-degeneracy mechanism is **switched off** there (the ELBO is
`logLik − KL`; a tight bound means `KL = 0`, so the regulariser credited for VA's zero
degeneracy contributes nothing). The broad accuracy grid was cut as vacuous and replaced by
three cheaper, non-vacuous tests.

**The confound, quantified.** The reported `d_ll` of +6.23…+12.31 is what VGH's 19 extra
dispersion parameters buy. Models are nested (Laplace = VGH under `φ_1 = … = φ_T`), the bench
DGP is homoscedastic, both log-likelihoods exact ⇒ `2·d_ll ~ χ²₁₉`. Across 24 new cells: mean
9.396 (n=200) / 9.268 (n=800) against a null mean of 9.5, 0 of 24 individually significant,
KS p = 0.810 / 0.901.

**The collapse test** (`dev/vgh/gaussian-collapse.R`). A new `phi_pool` mode pools VGH's
per-trait dispersion to one shared estimated value, matching Laplace at 60 free parameters.
`d_ll` collapses from a median 9.96 to a max of 8.3e-07; the arms then agree on recovery
(0.1130 both), residual SD (0.9971 both, max diff 1.9e-06) and `Σ_B` (~5e-05 relative). This
doubles as the **cross-implementation check of the TMB gaussian path** that the settled-position
note names as VGH's one unexploited use.

**The degeneracy reachability result** (`dev/vgh/gaussian-degeneracy-reachability.R`). Slice B
asked whether gaussian VGH degenerates at Laplace's rate; that is vacuous unless gaussian
*Laplace* degenerates. It does not: across 59 gaussian fits (36 mine + 23 adversarial),
`max |Λ̂|` stayed **below each dataset's own largest trait SD** (max ratio 0.961). Mechanism
**derived**: the gaussian marginal log-likelihood is coercive in Λ.

**Three engine fixes**, each shipped with a test proven to fail against the defect:
`vgh_fit(d = 1)` crashed on an `apply()` shape collapse; `vgh_fit()$elbo` was stale by one sweep
on the convergence path; and `q = 1` for the production `.vgh_fit()` gained regression coverage
(it was correct but untested).

**Corrections** to four documents plus `dev/vgh/vgh-bench.R:3`, including two of my own claims
that an adversarial pass overturned (§9).

## 3a. Decisions and Rejected Alternatives

- **Match dispersion DOWNWARD (pool VGH), not upward.** Upward needs
  `PARAMETER(log_sigma_eps)` → `PARAMETER_VECTOR` in `src/gllvmTMB.cpp:568`, which
  `docs/design/108-va-parity-programme.md:194` already scopes as unbuilt roadmap work and
  `CLAUDE.md` reserves for maintainer sign-off.
- **Rejected: fixing Laplace's σ at truth** as a second matching direction (the maintainer's
  original preference). Not reachable from the public API — `log_sigma_eps` is mapped off only
  when no gaussian trait exists or a per-row diagonal term is present
  (`R/fit-multi.R:4613-4650`), and neither is a `gllvmTMBcontrol()` option. Replaced by the
  `d_ll`-collapse test, which is falsifiable rather than assumed.
- **Rejected: the 3×3 heteroscedasticity grid** from the approved plan. Once both engines were
  shown to share an MLE, comparing their accuracy was not a well-posed question, and the
  as-shipped VGH's extra parameters became a model-selection question rather than an engine
  comparison. Adaptive deviation, recorded here and in the re-scope doc.
- **Rejected: the brief's own suggested stale-ELBO fix** ("set `prev <- e$value` before the
  break test"). Measured in a scratch copy: it makes the predicate compare a value to itself, so
  every fit breaks at sweep 1 and `tol` becomes inert — ~70 ELBO units lost. Adopted instead the
  idiom already in `R/va-vgh.R:596`.
- **Rejected: fixing `R/va-vgh.R` or the Heywood gate.** Both were implicated by findings here
  but are outside this lane. Raised via a directed `check-log.md` note and two spawned tasks.
- **Compute: local.** 24 collapse cells + 36 reachability fits at ≤127 s per multi-start Laplace
  fit; the Totoro escalation trigger (60 s/fit single-start) was measured at 6.4 s and never
  fired. Results stay local (D-50).

## 4. Files Touched

Created:
- `docs/dev-log/2026-07-30-gaussian-arm-rescope.md`
- `docs/dev-log/2026-07-30-gaussian-has-no-degeneracy-tail.md`
- `docs/dev-log/2026-07-30-gaussian-collapse-test-result.md`
- `docs/dev-log/after-task/2026-07-30-gaussian-arm-vgh-pluralism.md` (this file)
- `dev/vgh/gaussian-collapse.R`, `dev/vgh/gaussian-collapse.csv`,
  `dev/vgh/gaussian-collapse-smoke.csv`, `dev/vgh/gaussian-collapse-analyse.R`
- `dev/vgh/gaussian-degeneracy-reachability.R`, `dev/vgh/gaussian-degeneracy-reachability.csv`
- `tests/testthat/test-vgh-pooled-phi.R`

Modified:
- `dev/vgh/vgh-engine.R` — `phi_pool` mode + `phi_floor`; the `d = 1` fix; the stale-`$elbo` fix
- `tests/testthat/test-vgh-oracle.R` — `q = 1` coverage (purely additive: 55 insertions, 0 deletions)
- `dev/vgh/vgh-bench.R` — the C-exact figure corrected in its header comment (comment only)
- `docs/dev-log/2026-07-30-vgh-pluralism-lane-brief.md` — engine mis-attribution, range, quantification
- `docs/dev-log/2026-07-29-vgh-report.md`, `docs/dev-log/2026-07-29-vgh-variational-speed-probe.md` — addenda
- `docs/dev-log/handover/2026-07-30-claude-handover.md` — resume command marked superseded
- `docs/dev-log/check-log.md` — directed cross-lane note + its correction
- `~/shinichi-brain/memory/VGH in gllvmTMB — the settled position…md` — the KL scope limit

**Not touched, deliberately:** `R/`, `src/`, `NEWS.md`, `check_gllvmTMB()`. `git diff --stat -- R/ src/`
is empty. Codex lanes (`codex/va-*`, `codex/hvt1-*`, `codex/design86-*`) untouched.

Commits: `193d035f`, `69f96642`, `22ee3fa6`, `fc701f29`, `cdeb57a3`, `909666f0`, `c5845a22`,
`f6fb724d`, `b3dd4f93`, `929d3b6d` — all pushed to `origin/claude/vgh-pluralism-20260730`.

## 5. Checks Run

| check | result |
|---|---|
| `test-vgh-oracle.R` (via `devtools::load_all()`) | 12 tests, 51 pass, 0 fail / 0 error / 0 skip |
| `test-vgh-warmstart.R` | 7 tests, 19 pass, 0 fail / 0 error / 0 skip |
| `test-vgh-pooled-phi.R` | 3 tests, 35 pass, 0 fail / 0 error / 0 skip |
| S0 comparability gate | PASS — Laplace 60 params (`20 + 39 + 1`), VGH 79 identified, difference exactly 19 |
| `extract_Sigma_B()` == `Λ̂Λ̂'` | max abs diff **0**, bit-identical, confirmed three ways incl. a C++-side check |
| collapse-test integrity (24 cells) | yardstick `abs(exact_ll − logLik)` = 2.0e-10; counts matched 24/24; pooled φ flat 24/24; 0 sweep-cap hits; 0 non-convergences |
| Laplace timing (Totoro trigger) | 6.4 s single-start at n=200 — trigger (60 s) never fired |

**Not run:** `devtools::check()`, `pkgdown`, the full `devtools::test()` suite. Two workflows and
a background campaign were concurrently active, so a full-suite run would have mixed their
in-flight edits into the result; the narrow runs above are the honest scope. **This is a gap a
release would have to close.**

## 6. Tests of the Tests

Every fix shipped a test **demonstrated to fail against the defect**, not merely to pass:

- **`phi_pool`** — making `pool = TRUE` behave as `FALSE` made the test fail on two substantive
  assertions. Instructive detail: `expect_true(fit$phi_pool)` did **not** fail, because a
  metadata flag records only what was *requested*. The value checks are load-bearing.
- **`d = 1`** — the new test failed 9 of 21 expectations against a sha256-verified pre-fix
  engine, and passed 21/21 after. No skip fired in either direction.
- **stale `$elbo`** — failed against the pre-fix engine with literal deltas −0.15 (gaussian) and
  −0.123 (poisson); both cells genuinely *converged* (sweeps 13 and 6 of 200), so the regime that
  exposes the defect is the one tested. On the `maxit`-exhausted path the fix is provably a no-op
  — which is exactly how the bug hid.
- **`q = 1`** — **both** guard sites were broken independently via `assignInNamespace()` (never
  editing `R/`), and each break errored both q=1 tests while all q=2 controls passed. Honest
  limitation the verifier surfaced: each break kills *both* tests, so a single test cannot
  attribute failure to a site; the separate injections are what prove each guard individually
  load-bearing.
- **Discrimination measured, not assumed.** The q=1 tightness oracle has 7.7e5× headroom
  (observed rel diff 1.3e-16 against `tolerance = 1e-10`), so its discrimination was tested
  directly: a relative Λ perturbation of 1e-4 fails, 1e-6 passes — it detects q=1 algebra errors
  at ~3e-5 relative.
- **Backward compatibility, bitwise.** `identical()` on `Beta`/`Lambda`/`phi`/`amean`/`Avec`/
  `elbo_path`/`sweeps` against the pre-change engine: 8 cases for the `d=1` fix, 135 pre/post
  pairs (sweeps) and 81 whole-object comparisons for the `$elbo` fix. A live campaign was using
  the engine at `d = 2` throughout.

## 7a. Issue Ledger

| item | state |
|---|---|
| `vgh_fit(d = 1)` non-conformable crash | **FIXED** (`909666f0`) |
| `vgh_fit()$elbo` stale by one sweep on convergence | **FIXED** (`f6fb724d`) |
| `q = 1` untested for production `.vgh_fit()` | **FIXED** — coverage added, both guards pinned |
| Lane brief named the wrong engine for fixed dispersion | **FIXED** |
| `d_ll` range "+6.2 to +10.0" stale (CSV runs 6.23–12.31) | **FIXED** |
| C-exact figure 1.3e-12 was 70% stale-ELBO artifact → 3.76e-13 | **FIXED at source + 2 docs** |
| My "2.77 vs threshold 6" headline invalid | **WITHDRAWN and replaced** |
| My 24/24-sign explanation directionally wrong | **CORRECTED** |
| `loading_absolute_thresh` is binomial-gated — no gaussian absolute criterion | **RAISED** to the LA/AGHQ/ridge lane; not mine to change |
| `ψ_j → 0` (the real gaussian Heywood boundary) unexplored | **DEFERRED**, documented |
| Research metrics `rel_frob`/`atten_F` false-positive at small true Λ | **DOCUMENTED**; 4 independent re-definitions exist in `dev/` |
| VGH cannot be multi-started (no start argument) | **DEFERRED**; worked around in scratch for verification |

Spawned as separate tasks: `task_e259873a` (stale `$elbo` — since completed here),
`task_a8684792` (q=1 coverage — since completed here), `task_aa3594e7` (`d=1` — since completed
here).

## 8. Consistency Audit

**The class, not the instance.** The `d = 1` crash prompted a repo-wide sweep for the
`t(apply(M, 1L, f))` shape-collapse pattern: **10 sites**. Only `dev/vgh/vgh-engine.R:275` was a
real bug; two are unguarded but unreachable (`d` hardcoded to 2 in `binom-tuning.R:35` and a test
fixture); the rest are correctly guarded. **No production code carries the pattern.**

**The sibling engine.** I raised an alarm that `R/va-vgh.R:162/:259` shared the defect. **It did
not** — verified by *running* `q = 1` fits, not reading. It is safe for a precise reason worth
recording: `:161` uses an early `return()` before the risky `apply()`, and `:258` folds the guard
into a single `if/else` **expression**, so R never evaluates the untaken branch. Same algebra,
correct idiom. That alarm not panning out is what surfaced the genuine finding — no `q = 1`
coverage at all.

**Two other engines checked** for the same class: `R/va-r3-proto.R` and `R/eva-proto.R` use only
`vapply` (shape-safe), and both take `gaussian_sd` as fixed `DATA_SCALAR`.

**Every surface citing a corrected number was swept**, not just the one I noticed: the wrong
`d_ll` range appeared in **three** documents; the C-exact figure in **four** places.

**Memory receipt.** Loaded and used: the brain note *"VGH in gllvmTMB — the settled position"*
(its Q1–Q4 taxonomy shaped how the arm was scoped, and its `rel_frob` like-for-like caveat became
alignment problem A3); `docs/design/108-va-parity-programme.md` (which pre-scoped the
per-trait-dispersion work, so it was not re-derived); `CLAUDE.md`'s multi-lane fence and
likelihood-change rule. **Recall came before scouting**: two `search_notes` queries with
`search_all_projects: true` preceded the prior-work sweep, and the sweep receipt is in the plan
file. A durable delta was written back to the brain note (the KL scope limit) rather than left in
chat. Golden Set (`tools/memory_regression.py`) **not run** — no known-mistake class from that set
was in scope. Cross-repo guards that fired: *"to check a capability is present, USE it"* (the
`q = 1` fits and the `phi` estimation probe were run, not read), and *"state what a partial arc
does NOT cover"* (§12).

## 9. What Did Not Go Smoothly

**I acted on an inverted instruction before checking it.** The task prompt said "note VGH FIXES
rather than estimates the residual SD". That is true of `.vgh_fit()`/`gaussian_anchor` and false
of the `vgh_fit()` this arm used. The predecessor handover had it **right**; a one-word
compression (`gaussian_anchor` → "VGH's gaussian route") inverted it, and it reached me inside a
*resume command*, which I acted on before reading the evidence.

**I overcharged the prior work, then had to retract.** I accused the 2026-07-29 documents of a
category error and of silently dropping rows. Both wrong: they drew the correct conclusion on
every point and even named this slice as the missing run, and the "+6.2 to +10.0" range was
accurate when written (the same file records that n=2000/4000 had not completed). Stale, not
wrong. **I read the bench script and the lane brief but not the two intermediate documents that
had already handled it.**

**My own headline was refuted.** "max |Λ̂| = 2.77 against the shipped absolute threshold of 6" was
invalid in both halves — the threshold is binomial-gated and never evaluates on a gaussian fit,
and the adversarial pass exceeded 6 five times over (max 32.64), reaching 11.42 by *multiplying
`Y` by 10*. The scale-free statement that does support the conclusion was sitting next to it
unused.

**My explanation of the 24/24 sign was directionally wrong**, and I deferred a question that a
30-second tolerance sweep answers. At `tol = 1e-14` the sign reverses in 24/24.

**I nearly reported a rounding artifact as a result.** I parsed the driver's console log, which
prints `d_ll_pooled` with `%+9.5f`, and reported `max = 0.000e+00` — an *exactly* zero gap. The
true value is ~1e-7. Caught it myself and replaced log-parsing with a CSV analysis script that
documents the trap.

**Two design defects in my own scripts**, both found by the adversarial pass: `sim_cell()` does
not seed on `n`, so the 24 collapse cells carry only **12 truths**; and `sim()` does not seed on
regime, so the 36 reachability fits are **6 streams reused six ways**.

**A test-run environment error.** `test-vgh-oracle.R` needs `devtools::load_all()`; run against
the installed package it errors 11 of 12 tests. I nearly read that as a failure of the new tests.

## 10. Known Residuals

- **`devtools::check()` and the full `devtools::test()` were not run** — concurrent jobs would
  have contaminated the result. A release must close this.
- **Power, not calibration, bounds the χ² conclusion.** At 12 cells the 80%-power MDE is 2.74
  log-likelihood units, so a residual VGH advantage up to ~29% of the measured gap would pass
  unnoticed. **χ²₂₀ also fits the same data** (KS p = 0.256), so `df = 19` rests on the
  parameter-count argument, not on the measurement.
- **The `ψ_j → 0` boundary is unexplored.** It is the classic Heywood case and the gaussian
  likelihood is *not* coercive in ψ. All 36 reachability fits used `unique = FALSE`, so no
  per-trait ψ existed to collapse; a 9-fit ψ-model spot check found nothing (max 2.21).
- **The ~5e-05 template cross-check is a resolution, not a measured discrepancy.** The objective
  is flat enough that an error below ~1e-05 relative would be invisible.
- **VGH still cannot be multi-started** through its public interface.
- **The coercivity mechanism is derived but single-DGP-verified** (measured on one Λ→cΛ ladder).
- **The corrected C-exact figure is single-seed, single-DGP** (n=300, m=12, d=2).
- **`vgh_fit()` still has no input validation and no `$converged` field**; NA/Inf in `Y` makes its
  per-unit guards refuse every step silently.

## 11. Team Learning

**A resume command is executable instruction, not prose.** A one-word compression inside one is a
defect the next session acts on *before* it reads the evidence. Keep engine names exact there,
even at the cost of brevity. This is the transferable lesson of the whole arc.

**Quote a numerical agreement with its tolerance.** "1.3e-12" read as a fixed property of the
ELBO and so became the cited justification for a structural claim; it was 70% a convergence
artifact. The claim was sound — it rests on a theorem — but the number was not the evidence.

**Check whether a threshold applies before comparing to it.** I compared a gaussian quantity to a
constant that is binomial-gated and logit-scaled. The reviewer's one-line refutation ("rescale a
trait") would have come from the first reader.

**A metadata flag proves nothing about the math.** `expect_true(fit$phi_pool)` survived a
deliberate break that inverted the behaviour it names.

**Before accusing prior work, read the intermediate documents.** I went from the source script to
the current brief and skipped the two that had already handled the issue correctly.

**When a ratio metric flags a pathology, check the absolute magnitude.** If it is not elevated,
the flag is a denominator artifact. Here the "degenerate" fits had loadings *half* the size of
the healthy ones.

Written back to `~/shinichi-brain/memory/VGH in gllvmTMB — the settled position…md`: the KL
argument's **gaussian scope limit** (tight bound ⇒ no implicit regularisation ⇒ no protection),
which materially qualifies a claim that note previously made unconditionally.

## 12. Cross-Product Coverage

The cross-cutting things this arc touched, and the negative space for each.

**`phi_pool` (new argument on `vgh_fit()`).** Covers ✓ gaussian (the only family with
`has_phi = TRUE`); the default `FALSE` path bit-for-bit identical to before. **It does NOT
cover** ✗ poisson or binomial (no dispersion parameter to pool — the flag is inert), ✗ the
production `.vgh_fit()` (a separate engine whose gaussian dispersion is fixed, not estimated),
✗ any structured tier (phylo/spatial/animal — the dev engine admits none), ✗ per-trait covariates
(`X` must be constant within unit), ✗ `d = 1` combined with pooling under families other than
gaussian.

**The `d = 1` fix.** Covers ✓ `vgh_update_model()` at d=1 for gaussian, poisson and binomial,
verified across 5 shapes each including `m = 2`, plus `d = 2,3,4` bit-for-bit unchanged. **Does
NOT cover** ✗ `d = 1` in the production `.vgh_fit()` (separately pinned by the new q=1 tests),
✗ `maxit < 1` (errors identically before and after, from an unrelated `Avec = v$Avec`),
✗ `d > 6`.

**The stale-`$elbo` fix.** Covers ✓ the convergence path for all three families and
`d = 1,2,3`, and the `maxit`-exhausted path (where it is provably a no-op). **Does NOT cover**
✗ any consumer that stored a *previously computed* `$elbo` — `dev/vgh/vgh-validate.R`'s recorded
figure changed and was corrected, and four other `dev/` scripts read `$elbo` from the dev engine
and were checked (`crosscheck-va-r3.R` is structurally immune; it never calls `vgh_fit()`),
✗ the production engine (already fixed), ✗ multi-seed confirmation of the corrected figure.

**The `q = 1` coverage.** Covers ✓ both q==1 guards in `R/va-vgh.R`, each independently
demonstrated load-bearing; the gaussian tightness oracle and three-family monotonicity at q=1.
**Does NOT cover** ✗ `q = 1` for `warmstart` (`test-vgh-warmstart.R` still uses `rank = 2L` only),
✗ `q = 1` for the va-r3 or EVA prototypes, ✗ whether Λ is the MLE (the oracle certifies bound
tightness at the fitted parameters, the same limitation as the q=2 test it mirrors),
✗ attribution of a failure to a specific guard from a single test.

**The gaussian conclusions.** Cover ✓ gaussian identity link, T=20, d=2, homoscedastic,
n ∈ {200, 800}, `unique = FALSE`, intercept-only, complete data. **They do NOT cover** ✗ binomial
or poisson, where the bound is loose and the engines genuinely differ (the 0/148-vs-50/148
degeneracy gap stands untouched), ✗ heteroscedastic truth (cut when the arm was re-scoped),
✗ any `ψ` model, ✗ covariates, missing data, or any structured tier, ✗ n > 800 or T ≠ 20,
✗ mixed-family fits, ✗ the lognormal family (which shares the same scalar `sigma_eps`),
✗ `check_gllvmTMB()`'s shipped statistics (never touched; none use truth).
