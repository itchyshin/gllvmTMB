# Design Doc 41 — Binary completeness (M2 milestone scope)

**Status**: Design note for the M2 milestone (Phase 1 function-first sequence).
**Maintained by**: Boole + Emmy (M2.1 lead authors).
**Reviewers**: Fisher (statistical inference), Pat (reader UX),
Rose (overpromise prevention), Ada (close gate).
**Cross-refs**:
[`docs/design/00-vision.md`](00-vision.md) item 5 (vision rule:
binary is the second family validated after Gaussian);
[`docs/design/35-validation-debt-register.md`](35-validation-debt-register.md);
[`docs/dev-log/audits/2026-05-16-phase0c-rewrite-prep.md`](../dev-log/audits/2026-05-16-phase0c-rewrite-prep.md)
(M2.5 rewrite contract); the M1 close after-phase report at
[`docs/dev-log/after-phase/2026-05-17-m1-close.md`](../dev-log/after-phase/2026-05-17-m1-close.md).

## 1. Goal

M2 — **Binary completeness** — validates every binary
capability end-to-end at the depth M1 validated the
Gaussian + mixed-family surface at. Vision item 5 from
[`docs/design/00-vision.md`](00-vision.md) names binary as the
second family validated after Gaussian; M2 delivers that walk.

After M2 closes, the validation-debt register will mark:

- **FAM-02** (binomial-logit), **FAM-03** (binomial-probit),
  **FAM-04** (binomial-cloglog) at *deep* coverage (parameter
  recovery + CI accuracy at scale, not just smoke).
- **FAM-14** (`ordinal_probit`) walked from `partial` to
  `covered` (binary IRT pedagogy makes ordinal-probit a
  member of the binary-completeness cluster).
- **LAM-03** (`lambda_constraint` on binary IRT) `covered` with
  recovery study at `n_items ∈ {10, 20, 50} × d ∈ {1, 2, 3}`.
- **LAM-04** (`suggest_lambda_constraint()`) `covered` with a
  documented reliability regime.

After M2 closes, the Preview banners on
[`vignettes/articles/lambda-constraint.Rmd`](../../vignettes/articles/lambda-constraint.Rmd),
[`vignettes/articles/psychometrics-irt.Rmd`](../../vignettes/articles/psychometrics-irt.Rmd),
and [`vignettes/articles/ordinal-probit.Rmd`](../../vignettes/articles/ordinal-probit.Rmd)
are removed; `psychometrics-irt.Rmd` is re-authored against
validated machinery per the M2.5 rewrite contract.

### What M2 is NOT

- **M2 is not empirical-coverage validation.** That is M3.3 work
  (`coverage_study()` at R = 200 on binomial / ordinal-probit
  cells). M2 establishes parameter recovery + nominal CI
  behaviour on simulated data; M3 establishes empirical coverage.
- **M2 does not add new families.** Other families
  (Gamma, Beta, Tweedie, delta / hurdle, nbinom1, betabinomial,
  truncated) stay `partial` until post-CRAN family-by-family
  validation.
- **M2 does not add new keywords.** The 3 × 5 covariance keyword
  grid stays as-is. Random slopes (`(1 + x | g)`) and
  latent × observed interaction stay deferred to Phase 1c-slope
  and post-CRAN.
- **M2 does not establish cross-package empirical agreement.**
  That is Phase 5.5 work. M2.5 includes a `mirt::mirt()`
  cross-check on a single IRT fixture as a sanity check, not
  as the full grid.

## 2. Baseline — what M1 already gives us for binary

The M1 milestone (closed 2026-05-17) already validated the
extractor machinery on `family = list(...)` fits that *include*
binomial rows. Specifically:

- `link_residual_per_trait()` in
  [`R/extract-sigma.R`](../../R/extract-sigma.R) computes the
  per-trait latent-scale residual via the registry in
  [`docs/design/02-family-registry.md`](02-family-registry.md):
  - binomial-logit → $\pi^2/3 \approx 3.29$ (Dempster-Lerner
    threshold-model convention; population-scale)
  - binomial-probit → $1$ (by construction; the probit latent
    is unit-Gaussian)
  - binomial-cloglog → $\pi^2/6 \approx 1.64$ (the cloglog
    latent is a standard-extreme-value variate)
  - ordinal-probit → $1$ (probit latent is unit-Gaussian);
    `gllvmTMB_auto_residual_ordinal_probit_overcount` warning
    if the user passes `link_residual = "auto"` on a
    mixed-family fit where one trait is ordinal-probit, since
    the standardisation is already baked in.
- The M1.2 three-tier fixture
  ([`R/data-mixed-family.R`](../../R/data-mixed-family.R))
  includes binomial rows in both the 3-family fixture
  (gaussian + binomial + poisson) and the 5-family fixture
  (gaussian + binomial + poisson + Gamma + nbinom2). M1 tests
  therefore exercise binomial *as part of a mixed-family fit*.
- The M1.8 `.draw_y_per_family()` dispatcher
  ([`R/methods-gllvmTMB.R`](../../R/methods-gllvmTMB.R))
  handles binomial draws per row (logit / probit / cloglog
  via the per-row `link_id_vec`); `bootstrap_Sigma()` and
  `simulate.gllvmTMB_multi()` therefore work correctly on
  fits that contain binomial rows.

**What this means for M2**: the *extractor surface* + the
*resample surface* for binomial is already mixed-family-tested.
The remaining M2 gap is at the **single-family deep-validation
level** — parameter recovery, CI accuracy, and IRT-specific
machinery (`lambda_constraint`) that M1 did not exercise.

## 3. Gap analysis — what M2 must add

Per slice (mirroring the M1 slice contract pattern in ROADMAP):

### M2.2 — Binary extractor + CI validation

| Capability | Today | M2.2 deliverable |
|---|---|---|
| FAM-02 binomial(logit) parameter recovery | `covered` smoke only | Recovery study at $n_\text{units} \in \{50, 200\} \times d \in \{1, 2\}$; loadings + variances within 10 % RMSE of truth |
| FAM-03 binomial(probit) recovery | `partial` smoke | Same grid; probit identification convention ($\sigma^2 = 1$ baked in) tested explicitly |
| FAM-04 binomial(cloglog) recovery | `partial` smoke | Same grid; cloglog link residual $\pi^2/6$ checked |
| FAM-14 ordinal-probit recovery | `partial` smoke | Threshold-parameter identifiability + per-category recovery |
| CI-01..03 on binary fits | `covered` (Gaussian baseline) | Wald + profile + bootstrap each tested on a binomial fit; profile shape (quadratic vs skewed) noted |
| `extract_correlations()` on binary fits | `covered` via M1.4 mixed-family | Single-family binomial fit tested; both Fisher-z and Wald paths |
| `extract_repeatability()` on binary fits | `covered` via M1.6 mixed-family | Single-family binomial fit tested; verify `vW` includes $\pi^2/3$ residual (M1.6 fix) |

### M2.3 — `lambda_constraint` validation on binary IRT

| Capability | Today | M2.3 deliverable |
|---|---|---|
| LAM-03 binary IRT recovery | `partial` smoke | Recovery study at $n_\text{items} \in \{10, 20, 50\} \times d \in \{1, 2, 3\}$ |
| Confirmatory loadings: pin $\Lambda_{ij} = c$ | accepts; not deep | Verify the engine respects the pin; recover the free entries to truth |
| `mirt::mirt()` cross-check on shared fixture | n/a | One $n_\text{items} = 20, d = 1$ fixture fit by both packages; report parameter-disagreement table |
| Probit IRT 2PL recovery | n/a | Standard probit IRT model fit; recover slopes + intercepts |

### M2.4 — `suggest_lambda_constraint()` reliability

| Capability | Today | M2.4 deliverable |
|---|---|---|
| LAM-04 `suggest_lambda_constraint` smoke | `partial` smoke | Reliability regime documented across $n_\text{items} \in \{10, 20, 50\} \times d \in \{1, 2, 3\}$ |
| Identifiability at $d = 3, n_\text{items} = 10$ boundary | unknown | Document the regime where it fails or returns dubious suggestions |
| Suggestion-vs-truth comparison | n/a | On a known-DGP fixture, show the suggester picks a constraint matrix that yields a fit matching truth (modulo rotation) |

### M2.5 — `psychometrics-irt.Rmd` re-author

Per the [Phase 0C rewrite-prep handoff](../dev-log/audits/2026-05-16-phase0c-rewrite-prep.md):

- Re-authored against M2.3-validated `lambda_constraint` + M2.2-validated binomial-probit.
- Live `mirt::mirt()` cross-check chunk on a shared fixture.
- Audit-2 A1 "Stay Laplacian" pedagogy note: the engine uses
  Laplace approximation throughout; AGHQ for IRT is post-CRAN
  research-grade work, not the production path.
- Preview banner removed.

### M2.6 — `joint-sdm.Rmd` binary section restoration

- Restore long + wide pair following the
  [`morphometrics.Rmd`](../../vignettes/articles/morphometrics.Rmd) +
  [`behavioural-syndromes.Rmd`](../../vignettes/articles/behavioural-syndromes.Rmd)
  template.
- Cross-reference `suggest_lambda_constraint()` for users who
  want to identify their loadings on binary JSDM.
- Audit-2 A1 Laplace note inline (single paragraph).
- No "Mixed-family fits" section (that lives in
  [`mixed-family-extractors.Rmd`](../../vignettes/articles/mixed-family-extractors.Rmd)
  shipped in M1.9).

### M2.7 — M2 close gate

- After-phase report at `docs/dev-log/after-phase/YYYY-MM-DD-m2-close.md`.
- Shannon coordination audit.
- ROADMAP M2 row → ✅ Done.
- Validation-debt register cascade: FAM-02 deep, FAM-03, FAM-04,
  FAM-14, LAM-03, LAM-04 → `covered`.
- Preview banners removed from `lambda-constraint.Rmd`,
  `psychometrics-irt.Rmd`, `ordinal-probit.Rmd`.

## 4. Per-family identification conventions (audit)

The conventions below are already implemented in the engine
([`src/gllvmTMB.cpp`](../../src/gllvmTMB.cpp) +
[`R/extract-sigma.R`](../../R/extract-sigma.R)). M2.2 surfaces
them in tests; this section is the design record.

### Binomial-logit

- Latent scale: logistic, with residual variance $\pi^2/3$.
- Identification: the residual is the *population-scale*
  latent variance under the Dempster-Lerner threshold-model
  convention. Variance components in `extract_*()` outputs are
  reported on this scale.
- Link residual cascade applies on `extract_Sigma()`,
  `extract_communality()`, `extract_repeatability()`,
  `extract_correlations()` per the M1.6 fix.

### Binomial-probit

- Latent scale: standard normal, with residual variance $1$ by
  construction.
- Identification: the probit transform fixes $\sigma^2 = 1$
  on the latent residual. No free dispersion parameter.
- M2.2 test: verify the engine does NOT estimate a free
  $\sigma^2$ on probit rows (would be unidentified). Verify
  `link_residual_per_trait()` returns $1$ for probit rows.

### Binomial-cloglog

- Latent scale: standard extreme-value (Gumbel-like), with
  residual variance $\pi^2/6$.
- Identification: the cloglog transform of a log-rate model.
- M2.2 test: verify `link_residual_per_trait()` returns
  $\pi^2/6$ for cloglog rows.

### Ordinal-probit

- Latent scale: standard normal, with residual variance $1$
  by construction. K-1 threshold parameters (cutpoints) on
  the same scale; one is fixed (typically the first) for
  identification.
- Identification: thresholds are estimated as free parameters
  subject to the ordering constraint and one fixed reference.
- M2 + auto-residual warning:
  `gllvmTMB_auto_residual_ordinal_probit_overcount` fires
  when an ordinal-probit trait appears in a mixed-family fit
  with `link_residual = "auto"`; users should pass
  `link_residual = "none"` (or just exclude ordinal-probit
  from the auto-residual cascade) since the latent scale is
  already unit-variance.
- M2.2 test: verify threshold parameters are identifiable
  (recover within 5 % RMSE) at $K \in \{3, 5\}$ categories.

## 5. `lambda_constraint` machinery audit (M2.3 + M2.4 prep)

[`R/lambda-constraint.R`](../../R/lambda-constraint.R) (78 LOC)
implements the user-facing argument: a matrix `M` with the same
shape as $\boldsymbol{\Lambda}$ whose entries are either `NA`
(free MLE target) or a numeric value (pinned). The packed
parameter vector `theta_rr_B` in the TMB template absorbs the
constraint via a map mechanism (set parameter to `factor(NA)`
for pinned entries; the TMB autodiff path treats them as
constants).

[`R/suggest-lambda-constraint.R`](../../R/suggest-lambda-constraint.R)
(187 LOC) provides a default constraint matrix that pins the
upper triangle of $\boldsymbol{\Lambda}$ to zero (the canonical
exploratory-factor-analysis identification). This resolves the
rotational ambiguity of the *implied covariance*
$\boldsymbol{\Lambda} \boldsymbol{\Lambda}^\top$ but not the
sign ambiguity of individual factor loadings — sign-pinning is
a user-side decision.

Current test depth
([`tests/testthat/test-lambda-constraint.R`](../../tests/testthat/test-lambda-constraint.R),
160 lines; smoke + parser):

- ✓ Parser accepts a constraint matrix.
- ✓ Pinned entries appear as constants in the fit object.
- ✓ Gaussian recovery at $d = 1$ on a small fixture.

What M2.3 + M2.4 add:

- Recovery at $d \in \{1, 2, 3\}$ on **binary** (logit + probit)
  fixtures at $n_\text{items} \in \{10, 20, 50\}$.
- Cross-check with `mirt::mirt()` on one shared fixture.
- `suggest_lambda_constraint()` reliability across the same
  grid — at which combinations does it produce a constraint
  matrix that yields a fit matching truth modulo rotation?

## 6. Tests of the tests (per `10-after-task-protocol.md`)

3-rule contract:

- **Rule 1** (would have failed before fix): the M2.2 binomial
  recovery study should fail if the per-family link residual
  is *removed* from `extract_repeatability()` (it was added
  in M1.6); the M2.3 LAM-03 recovery should fail if
  `lambda_constraint` were to be silently ignored by the
  parser (regression test).
- **Rule 2** (boundary): M2.4
  `suggest_lambda_constraint()` is tested at $d = 3, n_\text{items} = 10$
  where the suggestion is on the *boundary* of usefulness
  (parameter-counting limit). M2 documents whether the
  suggester degrades gracefully (issues a warning + still
  returns a matrix) or fails (errors with a typed message).
- **Rule 3** (feature combination): M2.5
  `psychometrics-irt.Rmd` exercises binomial-probit + `lambda_constraint`
  + `extract_correlations()` (Fisher-z) in one fit. If feasible,
  M2.5 also fits a mixed-family IRT example (binomial-logit
  + ordinal-probit), demonstrating that the M1 mixed-family
  extractor machinery + the M2 binary-IRT lambda machinery
  compose.

## 7. Persona assignment

| Slice | Lead | Reviewers |
|-------|------|-----------|
| M2.1 (this design note) | Boole + Emmy | Fisher, Pat, Rose, Ada |
| M2.2 (binary CI + extractor validation) | Fisher (CI) + Curie (DGP) + Emmy (extractor) | Boole, Gauss, Rose |
| M2.3 (`lambda_constraint` binary IRT) | Boole + Emmy | Fisher, Curie, Rose |
| M2.4 (`suggest_lambda_constraint` reliability) | Boole + Pat | Fisher, Emmy, Rose |
| M2.5 (`psychometrics-irt.Rmd` re-author) | Pat + Fisher + Darwin | Boole, Rose, Ada |
| M2.6 (`joint-sdm.Rmd` binary section) | Darwin + Pat | Boole, Rose, Ada |
| M2.7 (M2 close gate) | Ada | Shannon, Rose, Pat |

## 8. Deliverables checklist (end-to-end view)

- [x] `docs/design/41-binary-completeness.md` (this file; M2.1).
- [ ] `tests/testthat/test-m2-2-binary-recovery.R` (FAM-02 / 03 / 04 recovery).
- [ ] `tests/testthat/test-m2-2-ordinal-probit-recovery.R` (FAM-14 recovery).
- [ ] `tests/testthat/test-m2-2-binary-cis.R` (Wald + profile + bootstrap on binomial fit).
- [ ] `tests/testthat/test-m2-3-lambda-constraint-binary.R` (LAM-03 recovery).
- [ ] `tests/testthat/test-m2-4-suggest-lambda-constraint.R` (LAM-04 reliability).
- [ ] `R/data-binary-irt.R` (M2.3 fixture — a known-DGP binary IRT 2PL fit).
- [ ] `vignettes/articles/psychometrics-irt.Rmd` re-authored at M2.5.
- [ ] `vignettes/articles/joint-sdm.Rmd` binary section restored at M2.6.
- [ ] `vignettes/articles/lambda-constraint.Rmd` Preview banner removed at M2.5.
- [ ] `vignettes/articles/psychometrics-irt.Rmd` Preview banner removed at M2.5.
- [ ] `vignettes/articles/ordinal-probit.Rmd` Preview banner removed at M2.7.
- [ ] Validation-debt register cascade at M2.7 (FAM-02 deep / FAM-03 / FAM-04 / FAM-14 / LAM-03 / LAM-04 → `covered`).
- [ ] ROADMAP M2 row → ✅ Done at M2.7.
- [ ] After-phase report + Shannon coordination audit at M2.7.

## 9. Open questions / decisions deferred

These are flagged for resolution during M2.2 / M2.3 / M2.4, not
in this M2.1 design note.

- **`mirt::mirt()` comparator scope**. For LAM-03 cross-check,
  do we run a single representative fixture (recommended for
  M2.3 to stay scope-narrow) or a grid? Defer to M2.3 author
  (Boole + Emmy) with Fisher review.
- **Probit identification regime**. Does the engine handle
  binomial-probit with `unique()` keyword (free per-trait
  residual variance) by erroring + suggesting `link_residual = "none"`,
  or by silently fixing? M2.2 audit should confirm and document.
- **Ordinal-probit cutpoint parameterisation**. The engine
  uses log-difference cumulative parameterisation; the article
  pedagogy should note this since `coef()` outputs may surprise
  readers expecting the bare cutpoints. Defer pedagogy
  decision to M2.5 author (Pat).
- **Mixed-family-with-ordinal-probit and `link_residual = "auto"`**.
  The `gllvmTMB_auto_residual_ordinal_probit_overcount` warning
  exists; M2.2 should add a test pinning this behaviour. The
  user-facing default behaviour stays as today.
- **AGHQ for binary IRT** (audit-2 A1 "Stay Laplacian"). Stays
  deferred to post-CRAN research-grade work. M2.5 article must
  acknowledge the Laplace approximation but should not promise
  AGHQ.
- **`lambda_constraint` sign-pinning**. The suggester pins
  upper-triangle zeros but does not pin signs. Sign-pinning is
  a user decision; the article should note this. Carry to M2.4
  + M2.5.

## 10. Honest scope boundary statement

After M2 closes:

> **Gaussian + binary** are end-to-end validated for
> single-family + mixed-family extractor machinery, parameter
> recovery, Wald + profile + bootstrap CIs, and binary IRT
> confirmatory loadings via `lambda_constraint`.
>
> **Other families** (Poisson, NB2, Gamma, Beta, Tweedie, delta
> / hurdle, nbinom1, betabinomial, truncated families) remain
> `partial` until post-CRAN family-by-family validation slices.
>
> **Empirical coverage at R = 200** stays M3 work for all
> families, including those validated in M1 + M2.
>
> **Cross-package empirical agreement** stays Phase 5.5 work.
> M2.5 includes a single `mirt::mirt()` cross-check on a
> shared IRT fixture as a sanity check, not as the full
> Phase 5.5 grid.
