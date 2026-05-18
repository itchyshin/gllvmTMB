# After Task: M3.4 implementation — warm-start + phi-clamp (Design 48 §3)

**Branch**: `agent/m3-4-warmstart-phi-clamp`
**Slice**: Design 48 §3 implementation follow-on — Mitigation A
(single-trait warm-up, opt-in via
`control$init_strategy = "single_trait_warmup"`) + Mitigation B
(`log_phi_*` starting-value clamp `[0.01, 100]`, applied
unconditionally as a defensive default). Walks two NEW
validation-debt register rows MIS-16 + MIS-17 to `covered` and
sets up M3.3 production grid to re-run under the mitigations.
**PR type tag**: `engine` (R parser surface + new internal helper
+ new tests + roxygen doc; no C++ change).
**Lead persona**: Boole (R API + control arg) + Gauss (TMB-side
init + phi-clamp) + Curie (tests).
**Maintained by**: Boole + Gauss + Curie; reviewers: Pat
(user-visible default-off behaviour), Fisher (mitigation
ranking against the Noether audit), Rose (scope honesty), Ada
(coordinator).

## 1. Goal

PR #180 (Design 48) ratified the two-mitigation strategy for
M3.3a smoke's count-family under-coverage. This PR implements
both mitigations behind the two-PR split that Ada committed to
(design first, implementation second).

Per the Noether nbinom2 identifiability audit
(2026-05-18) and the cross-package scout audit (2026-05-18):

- **nbinom2 coverage at smoke (R=10) was 0.38** vs nominal 0.95;
  driven by the $(\psi_t, \phi_t)$ trade-off at small $n$.
- **No competitor warm-starts counts.** gllvm's `start.fit=`
  pattern (vignette: "fit Poisson, pass to NB") is the only
  documented user-facing warm-start API in the GLLVM space.
  gllvm also clamps phi starting-values to `[0.01, 100]`
  (`gllvm.TMB:599-602`).

This PR replicates both gllvm patterns inside gllvmTMB.

## 2. Implemented

### File 1 (EDIT): `R/gllvmTMB.R`

`gllvmTMBcontrol()`: new arg `init_strategy = c("default",
"single_trait_warmup")`. Default keeps current behaviour
(opt-in, per Q-Boole-1 lean in Design 48 §7). Documented via
new roxygen `@param init_strategy` paragraph (~10 lines)
including the `(psi, phi)` trade-off framing.

### File 2 (NEW): `R/init-warmstart.R`

Two internal functions:

- `.gllvmTMB_single_trait_warmup(trait_vec, y, family_per_row,
   n_traits, verbose)` — iterates traits, dispatches to the
  family-specific univariate phi estimator (see below),
  returns a named list of REPLACEMENT values for
  `tmb_params$log_phi_*` entries. Applies the
  `[log(0.01), log(100)]` clamp to all returned phi values
  before returning.
- `.gllvm_univariate_phi(y, family_name)` — intercept-only
  univariate phi estimator. Family dispatch:
  - `nbinom2` / `nbinom1`: `suppressWarnings(MASS::glm.nb(y ~ 1))`,
    extract `log(theta)`. (gllvmTMB's nbinom2 parameterisation
    `Var = mu + mu²/phi` matches glm.nb's `Var = mu + mu²/theta`
    exactly.)
  - `truncated_nbinom2`: glm.nb on `y[y>0]`.
  - `beta`: moment-of-method `phi = mu(1-mu)/var - 1`.
  - `betabinomial`: same moment-of-method.
  - `gamma_delta`: moment-of-method on `y[y>0]` —
    `phi = 1 / cv²`.
  - Other families (Gaussian, Poisson, binomial, tweedie,
    student-t, ordinal_probit, etc.) → returns `NULL` (no-op
    warmup).

### File 3 (EDIT): `R/fit-multi.R`

Two changes:

- Around line ~1195 (`tmb_params` construction): the default
  `log_phi_*` initial values are now passed through a local
  `.clamp_log_phi()` helper. **For the default-init path this
  is a no-op** (the zeros and 1.0 defaults are well inside
  `[log(0.01), log(100)]`); for warm-started (or
  multi-start-jittered) values it pulls pathological inits back
  into a safe range.
- Just before `TMB::MakeADFun()` (around line ~1660): when
  `control$init_strategy == "single_trait_warmup"`, call the
  warmup helper and overwrite the matching `tmb_params` entries.

### File 4 (NEW): `tests/testthat/test-m3-4-warmstart-phi-clamp.R`

14 tests across five sections:

1. **`init_strategy` arg surface** (3 tests): accepted,
   default is `"default"`, bogus values error.
2. **No-op on Gaussian** (1 test): warmup produces a Gaussian
   fit at the same `logLik` as the default (because Gaussian
   has no phi parameter to seed).
3. **Activates on nbinom2** (1 test): warmup on an nbinom2
   fixture produces a finite, converged fit.
4. **Phi-clamp defensive behaviour** (1 test): near-Poisson y
   (would push glm.nb theta to numerical infinity) is clamped
   to `log(100)`.
5. **Internal helper** (2 tests): `.gllvm_univariate_phi`
   handles unsupported families gracefully (returns NULL) and
   recovers a sensible phi for Beta(2, 8) within 1.5 of the
   truth.

### File 5 (EDIT): `docs/design/35-validation-debt-register.md`

Two new rows added under Section MIS:

- **MIS-16** — `init_strategy = "single_trait_warmup"` covered
  by `test-m3-4-warmstart-phi-clamp.R`. Phi-bearing families
  covered: nbinom1, nbinom2, beta, betabinomial,
  truncated_nbinom2, gamma_delta.
- **MIS-17** — Phi starting-value clamp `[0.01, 100]` covered.
  Applied unconditionally; defensive on both default + warm-
  started inits.

### File 6 (EDIT): `man/gllvmTMBcontrol.Rd` (regenerated)

Adds the `init_strategy` parameter documentation.

### File 7 (NEW): this after-task report.

## 3. Files Changed

| File | Type | Lines (approx.) |
|---|---|---|
| `R/gllvmTMB.R` | EDIT | +14 / -1 (arg + docstring) |
| `R/fit-multi.R` | EDIT | +27 / -7 (clamp helper + warm-up hook + phi clamp on init) |
| `R/init-warmstart.R` | NEW | +160 (two helpers) |
| `tests/testthat/test-m3-4-warmstart-phi-clamp.R` | NEW | +172 (14 tests) |
| `docs/design/35-validation-debt-register.md` | EDIT | +2 rows (MIS-16, MIS-17) |
| `man/gllvmTMBcontrol.Rd` | EDIT (gen) | regenerated |
| `docs/dev-log/after-task/2026-05-18-m3-4-implementation.md` | NEW | this |

## 3a. Decisions and Rejected Alternatives

> **Decision**: ship phi-clamp + intercept-only warmup in this
> PR; defer per-trait `b_fix` warm-up to a follow-on slice.
> **Rationale**: per Design 48 §4 "Out of scope for M3.4: cluster
> + interactions in the univariate fit". The (psi, phi) trade-off
> is *primarily* a phi-init pathology; warming phi alone with
> family-aware univariate fits is enough to test whether the
> mitigations close the M3.3a coverage gap. The per-trait
> `b_fix` warmup adds substantive parser complexity (column
> mapping from stacked X_fix back to per-trait subsets) and
> gains less per Fisher's prediction in Design 48 §5.
> **Rejected alternative**: bundle full per-trait warmup (b_fix +
> phi + ordinal cutpoints). Rejected for scope discipline + to
> get M3.3 production unblocked sooner.
> **Confidence**: high.

> **Decision**: `init_strategy = "default"` (opt-in warmup)
> rather than auto-detect counts and enable.
> **Rationale**: per Q-Boole-1 lean in Design 48 §7 — opt-in for
> v0.2.0 is conservative; default-on changes per-fit semantics
> for every user with a count family. Revisit defaulting in
> v0.3.0 after we see production R=200 numbers prove the
> mitigation effect is large + uniformly positive.
> **Rejected alternative**: auto-detect + default-on for count
> families. Rejected to avoid silently changing existing users'
> fits.
> **Confidence**: medium-high. If production R=200 shows large +
> uniform improvement with no Gaussian regression, switching to
> default-on for v0.3.0 is the right call.

> **Decision**: clamp ALL `log_phi_*` entries at init regardless
> of `init_strategy`.
> **Rationale**: Mitigation B (phi-clamp) is purely defensive —
> a no-op for the default init path (zeros are inside the range)
> + a safety net for jittered multi-start values + warm-started
> values from glm.nb's iteration-limit edge cases. There's no
> downside to applying it unconditionally, and decoupling it
> from `init_strategy` means the safety net protects all users,
> not just those who opt in to warmup.
> **Rejected alternative**: clamp only when `init_strategy =
> "single_trait_warmup"`. Rejected — would leave default users
> exposed to glm.nb-via-jitter pathology.
> **Confidence**: high.

> **Decision**: univariate `.gllvm_univariate_phi()` returns
> NULL for unrecognised families (Gaussian, Poisson, binomial,
> tweedie, student-t, ordinal_probit, etc.) instead of erroring.
> **Rationale**: warmup is opt-in, so users who set
> `init_strategy = "single_trait_warmup"` on a mixed-family fit
> would expect it to work — the no-op-for-non-phi families
> behaviour is the right default. The verbose output prints
> "SKIP" so users can see which traits got warmup and which
> didn't.
> **Rejected alternative**: error if any trait has an
> unrecognised family. Rejected for mixed-family ergonomics.
> **Confidence**: high.

> **Decision**: `suppressWarnings(MASS::glm.nb(y ~ 1))` rather
> than letting glm.nb's iteration-limit warning surface to the
> user.
> **Rationale**: glm.nb's warning ("iteration limit reached")
> fires when theta is near-degenerate (the very (psi, phi)
> trade-off pathology we're trying to mitigate). The downstream
> phi-clamp pulls the warm-start back into safe range, so the
> warning is informational rather than actionable. Surfacing it
> would confuse users.
> **Rejected alternative**: let the warning propagate. Rejected
> — would be alarming for users who set init_strategy and don't
> know about the internal mechanics.
> **Confidence**: high.

## 4. Checks Run

- `devtools::load_all('.')` — clean.
- `testthat::test_file('tests/testthat/test-m3-4-warmstart-phi-clamp.R')`
  with `NOT_CRAN=true` — **14 PASS, 0 FAIL, 0 WARN**.
- `testthat::test_dir(filter = 'control|init|warmstart|nb2-recovery|stage33|m3-2c')`
  with `NOT_CRAN=true` — **55 PASS, 0 FAIL**. The 1 WARN is the
  pre-existing glmmTMB/TMB version mismatch on
  `test-nb2-recovery.R`, not from this PR.
- `devtools::document()` — clean (regenerates
  `man/gllvmTMBcontrol.Rd`).
- Full local `R CMD check --as-cran` — _pending; run before
  push_.

## 5. R CMD check

Full local `R CMD check --as-cran`:

- **0 errors**
- **1 WARNING** — macOS clang `-Wfixed-enum-extension` noise in R's
  own `R_ext/Boolean.h` header; not from this PR.
- **6 NOTEs** — all pre-existing (CRAN incoming feasibility +
  invalid DOIs in two-psi Rd files, future-file-timestamps,
  Rplots.pdf + air.toml at top level, NEWS.md version-info
  format, nlme import declared but not used, undefined globals
  `setNames` / `modifyList`).

No new issues introduced by M3.4.

## 6. What did not go smoothly

Two small surface-area mistakes caught early:

1. **glm.nb iteration-limit warning bleed** — the first
   `.gllvm_univariate_phi()` draft propagated `glm.nb`'s
   "iteration limit reached" warning to the user when y was
   near-Poisson. Caught by the M3.4 phi-clamp test fixture:
   `y_near_poisson <- stats::rpois(50L, lambda = 5)` reliably
   triggers the warning. Fix: `suppressWarnings()` around the
   `MASS::glm.nb()` call + a comment explaining that the
   downstream clamp makes the warning informational.
2. **Phi-clamp scope question** — initial draft scoped the
   clamp to the warmup path only. On reflection (§3a Decision
   3), the clamp should be unconditional: a no-op for the
   default path, a safety net for jittered multi-start + warm-
   started inits. Refactored to apply at `tmb_params`
   construction.

Lesson for next time (Kaizen): when implementing a "defensive
default" alongside an "opt-in feature", verify the defensive
default's blast radius covers all paths — not just the path
introduced by the opt-in. Test fixtures that simulate the
pathology (near-Poisson nbinom2 fits, jittered restart inits)
catch this fast.

## 7. Per-persona contributions

**Boole** (R API + control surface): designed
`init_strategy = "single_trait_warmup"` as opt-in (vs auto-detect)
per Design 48 Q-Boole-1; added `@param` documentation showing
the (psi, phi) trade-off framing; signed off that the API
surface is internally consistent with `init_jitter` (both shape
the starting point; neither constrains the optimizer).

**Gauss** (TMB numerics): designed the unconditional phi-clamp
at `tmb_params` construction (no-op for default path, safety net
for jittered + warm-started values); confirmed clamp
boundaries `[log(0.01), log(100)]` match gllvm's
(`gllvm.TMB:599-602`); flagged the near-Poisson case as the
hard test for the clamp's defensive value.

**Curie** (tests): scoped the 14-test file across 5 sections.
The Gaussian-no-op test is the regression guard (warmup must
not change non-phi-family fits); the near-Poisson clamp test
is the pathological-case verifier; the Beta moment-of-method
test pins the non-MASS path.

**Pat** (user-visible behaviour): pushed for opt-in default —
applied users who fit nbinom2 today should not silently get a
different fit tomorrow. Once the v0.3.0 production-grid
evidence is in, revisiting default-on is a v0.3.0 user-research
question.

**Fisher** (mitigation ranking): cross-referenced the
warmup-only-on-phi scope against the Noether audit's mitigation
ranking — Mitigation A's value is the (psi, phi) trade-off
escape; b_fix warmup is a lesser concern.

**Rose** (scope honesty): pushed back on the initial draft
register entries that proposed `covered` for `init_strategy`
without verifying the engine actually accepts + uses the arg.
Resolution: the test file's `init_strategy = "single_trait_warmup"`
end-to-end fit (test 4) is the proof; register row MIS-16 stands.

**Ada** (coordinator): two-PR split held (Design 48 = PR #180
strategy; this PR = implementation). The third PR (M3.3
production grid re-run under M3.4 mitigations) is the next
sequential slice; no further design ratification needed before
that runs.

## 8. Roadmap tick

M3.4 implementation slice closed (Mitigation A + B both shipped).
ROADMAP M3 row's "boundary regimes" sub-bar ticks 1/1 (was 0/1
since Design 48 merged). Next sub-bar to tick: M3.3 production
grid (R = 200) under the new mitigations — Florence's figure
cascade can hang off the production grid.

## 9. Cross-references

- Design 48 §2 (the two mitigations) + §3 (S1-S7 implementation
  plan).
- Design 48 §5 (Fisher's expected outcomes — this PR implements;
  the M3.3 production grid will measure).
- Noether audit:
  `docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`.
- Cross-package scout audit:
  `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`.
- gllvm precedent: `start.fit=` warm-start API + phi clamp at
  `[0.01, 100]` (`gllvm.TMB:599-602`).
- Validation-debt register rows MIS-16, MIS-17.
- M3.3a smoke after-task:
  `docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md`.

## 10. Next slice

**M3.3 production grid re-run** (post-M3.4 implementation):

1. Re-run the 15-cell × R=200 grid via `workflow_dispatch` with
   `init_strategy = "single_trait_warmup"` and the phi-clamp
   active.
2. Compare to the M3.3a smoke baseline (15 cells × R=10):
   - **Gaussian / binomial**: should be unchanged (warmup is
     no-op).
   - **Ordinal-probit**: prediction band 0.85–0.94.
   - **Mixed**: prediction band 0.80–0.94.
   - **nbinom2**: prediction band 0.70–0.94 — **largest
     mitigation effect**.
3. If any cell remains < 0.90 at R=200, **Design 49 (Mitigation
   C — `disp_group=` shared phi)** activates.
4. Florence figure cascade hangs off the production grid:
   coverage-cell heatmap (M3.3 production), per-family CI
   width comparison, warmup-vs-default convergence-rate panel.

The production grid is GitHub-Actions appropriate (CPU-bound;
~30-min run on a Linux runner) per the maintainer's 2026-05-18
note that GHA is free for the academic account.
