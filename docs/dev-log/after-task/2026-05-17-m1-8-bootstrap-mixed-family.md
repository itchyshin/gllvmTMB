# After Task: M1.8 — family-aware simulate + bootstrap_Sigma mixed-family (the substantive M1 code fix)

**Branch**: `agent/m1-8-bootstrap-sigma`
**Slices**: M1.8 (bootstrap_Sigma mixed-family) + MIS-05 (simulate family-aware redraws, pulled into M1.8 per maintainer 2026-05-17)
**PR type tag**: **engine** + `validation` (~150-line family-aware simulate; preserved family list; refit fix)
**Lead persona**: Curie (DGP/simulate); Fisher (inference path); Boole (engine surface)
**Maintained by**: Curie + Fisher + Boole; reviewers: Gauss (per-family draw correctness), Rose (test + audit discipline), Ada (close gate)

## 1. Goal

Eighth M1 deliverable. Walks **MIX-08** (bootstrap_Sigma per-row
family preservation in resamples) and **MIS-05**
(simulate.gllvmTMB_multi family-aware redraws) from `partial` to
`covered`. The maintainer 2026-05-17 ratified pulling MIS-05 into
M1.8 because the bootstrap symptom from M1.4 (degenerate ±1 CIs
on rank-1 latent fits) traces to simulate being family-blind, not
to a link_residual propagation gap.

## 2. Implemented

### Root-cause finding

Two latent bugs combined:

1. **`simulate.gllvmTMB_multi()` was family-blind** ([R/methods-gllvmTMB.R:670](R/methods-gllvmTMB.R:670) pre-fix): applied `eta + rnorm(n, sigma)` to all rows regardless of per-row family. Mixed-family bootstrap refits received simulated data with continuous values for binomial / Poisson rows → likelihood collapse → degenerate $\Lambda$.
2. **`fit$family` only stored the first family** ([R/fit-multi.R:174](R/fit-multi.R:174)): for mixed-family input, `family <- family[[1]]` truncated the list. `bootstrap_Sigma`'s refit_one read `family <- fit$family` and got `gaussian()` — so even after the simulate fix, refits were single-family Gaussian regardless of original spec.

Both bugs had to be fixed for bootstrap on mixed-family to work.

### Code changes

**[R/methods-gllvmTMB.R](R/methods-gllvmTMB.R)** — new internal `.draw_y_per_family()` (~100 lines) dispatches per-row by `family_id_vec` + `link_id_vec`:

| Family (fid) | Link (lid) | Draw |
|---|---|---|
| gaussian (0) | identity | `rnorm(1, eta, sigma_eps)` |
| binomial (1) | logit (0) / probit (1) / cloglog (2) | `rbinom(1, 1, plogis/pnorm/cloglog(eta))` |
| poisson (2) | log | `rpois(1, exp(eta))` |
| lognormal (3) | log | `exp(eta + rnorm(1, sigma_eps))` |
| Gamma (4) | log | `rgamma(1, shape = 1/sigma_eps^2, scale = mu * sigma_eps^2)` |
| nbinom2 (5) | log | `rnbinom(1, mu = exp(eta), size = phi_nbinom2[trait])` |
| others (6–14) | — | fall-back: Gaussian-on-link-scale + one-shot warn (`gllvmTMB_simulate_unsupported_family` class). M2/M3 family-completeness slices add these. |

`simulate.gllvmTMB_multi()` now calls `.draw_y_per_family()` on both Path 1 (newdata / `condition_on_RE`) and Path 2 (unconditional bootstrap). Path 1 with `newdata` still uses the old Gaussian fallback (family lookup on newdata is M2 work) with a one-shot warning (`gllvmTMB_simulate_newdata_gaussian_fallback`).

**[R/fit-multi.R](R/fit-multi.R)** — new `family_input` field on the fit list:

- For mixed-family input, `family_input <- family` (the list with `family_var` attribute) is captured **before** the `family <- family[[1]]` truncation at line 174.
- For single-family input, `family_input == family` (same object).
- `family_input` ships in the fit list alongside `family`; pre-M1.8 fits have `family_input = NULL` and downstream callers fall back to `family`.

**[R/bootstrap-sigma.R](R/bootstrap-sigma.R)** — refit_one reads `family_input` first, falls back to `family` for pre-M1.8 fits. Passes the original list (preserving `family_var` attribute) back to `gllvmTMB()` in refits.

### Tests

`tests/testthat/test-m1-8-bootstrap-mixed-family.R` (5 tests, ~150 lines):

1. `simulate()` family-correct values on 3-family fixture (binomial → 0/1; poisson → non-negative integers; gaussian → continuous).
2. Same for 5-family fixture (+ Gamma → positive continuous; + nbinom2 → non-negative integer).
3. `bootstrap_Sigma()` converges on mixed-family fit; `n_failed ≤ 5/15`; point + CI matrices finite + 3×3.
4. **M1.4 follow-up**: `extract_correlations(method = "bootstrap")` on mixed-family no longer returns degenerate ±1; CI brackets the point estimate; not all CIs are ±1.
5. Backward-compat: pure Gaussian simulate unchanged.
6. `fit$family_input` preserves the original list for mixed-family fits; `fit$family` stays the first family.

### Audit doc

`docs/dev-log/audits/2026-05-17-profile-correlation-surface.md`
(~150 lines): documents that `profile_ci_correlation()` operates on $\Sigma_\text{shared}$ (rotation-invariant rank-$d$ target) while fisher-z / wald / bootstrap operate on $\Sigma_\text{total}$. The rank-1 latent ±1 profile point estimates are mathematically correct for what they target but disagree with what users typically expect ("the correlation on the observable scale"). Recommends: keep current behaviour for M1.8, reimplement profile on $\Sigma_\text{total}$ at M3 inference-completeness.

## 3. Files Changed

```
Modified:
  R/methods-gllvmTMB.R                                              (~120 lines: .draw_y_per_family + simulate wire-in)
  R/fit-multi.R                                                     (~10 lines: family_input field)
  R/bootstrap-sigma.R                                               (~6 lines: read family_input)

Added:
  tests/testthat/test-m1-8-bootstrap-mixed-family.R                 (5 tests, ~150 lines)
  docs/dev-log/audits/2026-05-17-profile-correlation-surface.md     (~150 lines)
  docs/dev-log/after-task/2026-05-17-m1-8-bootstrap-mixed-family.md (this file)
```

No NAMESPACE change (helpers are internal); no `_pkgdown.yml`
change; existing roxygen for `simulate.gllvmTMB_multi` remains
accurate (the public contract — "draws `nsim` new response
vectors" — is unchanged; the per-family dispatch is an
implementation detail visible only when called on mixed-family
fits).

## 4. Checks Run

- **28 / 28 tests pass** in `test-m1-8-bootstrap-mixed-family.R` (NOT_CRAN=true).
- **43 / 43 tests pass** in `test-m1-4-extract-correlations-mixed-family.R` (no regression — M1.4's relaxed bracket check now passes more easily).
- Existing `test-profile-ci.R` Gaussian repeatability/communality paths unaffected.
- `pkgdown::check_pkgdown()` clean (audit doc lives in dev-log; not part of the pkgdown article surface).

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **Rule 1** (would have failed before fix): test 4 explicitly
  asserts `lower <= correlation <= upper` and `not all CIs are
  ±1`. Pre-M1.8, the 3-family fixture bootstrap CIs were
  exactly `[1, 1]` / `[-1, -1]` for all 3 pairs — the test
  would have failed on both the bracket assertion and the
  not-all-degenerate assertion. Post-M1.8, CIs are bounded
  intervals like `[-0.217, 0.483]` that bracket the point.
- **Rule 2** (boundary): test 1 + 2 probe the per-family
  domain boundaries (binomial → discrete 0/1; Poisson →
  non-negative integers; Gamma → strictly positive; nbinom2
  → non-negative integers). Each family's distribution
  constraint is asserted directly.
- **Rule 3** (feature combination): family-aware simulate ×
  mixed-family fit × bootstrap refit × CI extraction —
  three independent surfaces jointly exercised.

## 6. Consistency Audit

- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio" R/` on the diff → 0 hits.
- `rg "family_input" R/` → 3 hits (fit-multi.R definition; fit-multi.R single-family path; bootstrap-sigma.R reader). All cite the M1.8 (2026-05-17) date for traceability.
- Family-id values in `.draw_y_per_family` switch statement match `family_to_id()` in [R/fit-multi.R:42](R/fit-multi.R:42) (single source of truth for family_id assignments).

Convention-Change Cascade (AGENTS.md Rule #10): `family_input`
is a new field on the fit list. The cascade considerations:

- ✅ No existing field renamed or removed (`fit$family` unchanged).
- ✅ `bootstrap_Sigma` updated to read `family_input` with fallback to `family` for pre-M1.8 fits — backward compat preserved.
- ✅ Future callers (e.g., predict, simulate via newdata) can opt in to reading `family_input` as it becomes useful.
- ✅ NAMESPACE not affected (internal field, no `@export`).
- ✅ Generated Rd not affected (no docstring changes on user-facing functions).

## 7. Roadmap Tick

- `ROADMAP.md` M1 row: now **8 / 10 done** (M1.1 + M1.2 + M1.3 + M1.4 + M1.5 + M1.6 + M1.7 + M1.8).
- **Validation-debt register walks**:
  - **MIX-08 → covered** (bootstrap_Sigma per-row family preserved in resamples).
  - **MIS-05 → covered** (for the 5 families exercised by the M1.2 fixture: Gaussian + binomial + Poisson + Gamma + nbinom2 + lognormal). Other families (Tweedie, Beta, betabinomial, Student, truncated_*, delta_*, ordinal_probit) warn-and-fallback — those are M2 / M3 / post-CRAN family-completeness work.

## 8. What Did Not Go Smoothly

- **Two-step root cause**. M1.4 surfaced the bootstrap rank-1 degeneracy. M1.1 audit attributed it to a `link_residual` propagation gap in `bootstrap_Sigma`. The actual root cause was deeper: `simulate.gllvmTMB_multi` was family-blind AND `fit$family` only stored the first family (per a `family <- family[[1]]` reassignment in fit-multi.R). Both bugs cascaded into the symptom; either fix alone would have been insufficient. Lesson: when a symptom traces to a "single" root cause, audit the call stack one layer deeper before scoping the fix.
- **Scope expansion (MIS-05 pulled into M1.8)** — originally a discrete M2 slice. The maintainer ratified the merge mid-PR after the root-cause finding made the dependency explicit. Net positive: M1 closes with broader mixed-family infrastructure than originally scoped.
- **Profile-correlation surface divergence (audit-only)**. The audit doc explains why `profile_ci_correlation` operates on $\Sigma_\text{shared}$ vs the other methods' $\Sigma_\text{total}$. Reimplementing on $\Sigma_\text{total}$ is M3 inference-completeness work. The M1.4 finding becomes a designed surface choice, not a bug — but the docstring should explain this surface to users in a future small follow-up PR.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie** (DGP / simulate lead): the family-aware simulate
machinery is the M1 cornerstone for any future per-row family
work. `M2`/`M3` family-completeness slices can extend the
switch in `.draw_y_per_family()` one family at a time
(Tweedie, Beta, etc.) without revisiting the dispatch
architecture. The warning class
`gllvmTMB_simulate_unsupported_family` makes future scope-creep
auditable: every family not yet supported throws a recognisable
warning instead of silently degrading.

**Fisher** (inference): the M1.4 bootstrap-degeneracy + M1.8 root
cause is a textbook example of **symptom traceable to two
distinct latent bugs**. M3 inference-completeness work will
audit the rest of the inference surface for similar
double-fault patterns (profile-correlation on $\Sigma_\text{shared}$
is on that audit list).

**Boole** (engine surface): the `family_input` field on the fit
list is a small but **load-bearing addition** for downstream
callers that need the original family argument. The Convention-
Change Cascade analysis (§6) walks the surface to confirm no
unintended breakage. Lesson: when adding a new field to a
widely-read object, audit the read sites and document the
fallback semantics for pre-existing fits.

**Gauss** (per-family draw correctness): the Gamma draw uses
the `sigma_eps` interpretation as the coefficient of variation
(per C++ template at `src/gllvmTMB.cpp:760`): `shape = 1/sigma_eps^2`,
`scale = mu * sigma_eps^2`. nbinom2 uses `phi_nbinom2[trait]`
as the size parameter (per the `dnbinom_robust` parametrisation
at C++:771). Both checked against the engine's likelihood
evaluation. Other families left as warn-and-fallback;
extending requires the same engine-template cross-check.

**Rose** (test + audit discipline): test labels cite MIX-08 +
MIS-05 register IDs (skill check 14). The Rule-1 fix-
verification test (test 4 — "no longer returns degenerate ±1")
makes the bug-fix verifiable independently of the test
fixture's specific values. Audit doc `2026-05-17-profile-correlation-surface.md`
captures the surface choice for future maintainers.

**Ada** (orchestration, M1 close): 8 / 10 M1 slices done. M1.9
(new article `mixed-family-extractors.Rmd`) and M1.10 (close
gate) remain. M1 closes with mixed-family infrastructure
broader than originally scoped (MIX-03..MIX-08 + MIS-05 all
covered for the 5 common families).

## 10. Known Limitations and Next Actions

- **M1.9 next**: new article `mixed-family-extractors.Rmd` (with banner removal on `covariance-correlation.Rmd` per the M1.9 close gate). Uses the M1.2 fixture + the extractors validated in M1.3 / M1.4 / M1.5 / M1.6 / M1.7 / M1.8.
- **M1.10**: M1 close after-phase report + Shannon coordination audit + 3-OS CI green.
- **Profile-correlation reimplementation on $\Sigma_\text{total}$**: M3 follow-up per the audit doc filed today. Will require a Lagrange constraint with the link-residual derivative chain.
- **Family-aware simulate for newdata path**: M2/M3 work. Per-row family lookup from `newdata` needs design work (e.g., does newdata carry a `family` column? Or does the fit's family_var get applied via factor match?).
- **Extending `.draw_y_per_family()` to Tweedie / Beta / betabinomial / Student / truncated_* / delta_* / ordinal_probit**: M2/M3 family-completeness slices.
