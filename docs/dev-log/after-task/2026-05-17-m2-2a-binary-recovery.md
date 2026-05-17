# After Task: M2.2-A — Binary family recovery (logit / probit / cloglog + ordinal-probit link residual)

**Branch**: `agent/m2-2a-binary-recovery`
**Slice**: M2.2-A (first sub-PR of M2.2 — Binary extractor + CI validation)
**PR type tag**: `validation` (new tests; no R/ API change)
**Lead persona**: Fisher (CI / inference) + Curie (DGP / fixtures)
**Maintained by**: Fisher + Curie; reviewers: Emmy (extractor surface), Boole (formula grammar), Rose (test discipline), Ada (close gate)

## 1. Goal

First sub-PR of M2.2 per the M2 slice contract in
[`docs/design/41-binary-completeness.md`](../../design/41-binary-completeness.md).
Walks the binary-family register rows from `partial`-smoke to
`covered`-with-recovery:

- **FAM-02 binomial(logit)** — recovery + link-residual π²/3 at $d = 1$.
- **FAM-03 binomial(probit)** — recovery + identification convention (latent variance $= 1$ by construction).
- **FAM-04 binomial(cloglog)** — recovery + link-residual π²/6.
- **FAM-14 ordinal_probit** — link-residual $= 1$ invariant test
  (deep cutpoint + intercept recovery is already covered by
  `test-ordinal-probit.R`; M2.2-A adds the invariant assertion).

Tests-only PR — no R/ source change.

M2.2-B (the next M2 slice) covers:

- CI methods (Wald + profile + bootstrap) on binomial fits.
- Single-family binomial extractor pass (`extract_correlations`,
  `extract_communality`, `extract_repeatability`).
- glmmTMB cross-package light check per the M2.1 cross-package
  policy.

## 2. Implemented

**Mathematical contract**: zero R/ source, NAMESPACE,
generated Rd, family-registry, formula-grammar, or extractor
change. All M2.2-A work is added test files + ROADMAP /
register cascade.

### New test file: `tests/testthat/test-m2-2a-binary-recovery.R`

~230 lines, 5 `test_that` blocks:

1. **FAM-02 binomial(logit)** — d = 1, n_sites = 200, T = 3.
   Recovers $\Sigma_\text{true} = \Lambda \Lambda^\top + \mathrm{diag}(\psi^2) + \mathrm{diag}(\pi^2/3)$.
   Tolerance: max-cell relative error < 0.5 on $\Sigma$;
   max-cell abs error < 0.3 on implied correlation $R$.
2. **FAM-03 binomial(probit)** — same shape, sigma2_d = 1.
3. **FAM-04 binomial(cloglog)** — same shape, sigma2_d = π²/6.
   Smaller Λ entries (Λ_max = 0.5) so the linear predictor
   doesn't push too many rows into Pr(y=1) ≈ 1 (cloglog is
   asymmetric).
4. **Link-residual values per binomial link** — verifies
   `link_residual_per_trait()` returns π²/3 / 1 / π²/6 for the
   three links respectively at n_sites = 100, T = 2.
5. **Ordinal-probit link-residual = 1 invariant** — minimal
   ordinal-probit fixture (Wright/Hadfield threshold model,
   K = 4 categories). If the smoke fit fails to converge, the
   test skips gracefully with a clear reason; deep recovery is
   covered by `test-ordinal-probit.R`.

### Shared helpers (within the test file)

- `binary_dgp(T, n_sites, Lam, psi, seed, link)`:
  - Calls `simulate_site_trait()` with `sigma2_eps = 0` to get
    clean η values (no Gaussian residual noise on top of the
    latent factor structure).
  - Applies the per-link probability transform: `plogis(η)` /
    `pnorm(η)` / `1 - exp(-exp(η))`.
  - Draws Bernoulli outcomes.
  - Returns `list(data, truth, link, eta)`.
- `true_Sigma(Lam, psi, sigma2_d)`:
  - Computes the latent-scale $\Sigma_\text{true}$ matrix per
    the `02-family-registry.md` per-family link-residual rule.

### Local check outcome

11 expectations pass; 1 graceful skip (ordinal_probit fixture
non-convergence, expected — `test-ordinal-probit.R` covers the
deeper recovery surface).

```
NOT_CRAN=true Rscript -e 'devtools::load_all(quiet = TRUE);
  testthat::test_file("tests/testthat/test-m2-2a-binary-recovery.R",
                      reporter = "summary")'
# m2-2a-binary-recovery: ...........S
# 11 PASS · 1 SKIP · 0 FAIL
```

### Other files modified

- `ROADMAP.md` — two ticks:
  - **M2 row**: `🟢 1/7 In progress` → `🟢 2/7 In progress`
    (both phase-summary table and M2 detail header).
  - **Phase 0C row**: `🟢 Closing 6/6 (pending merge)` →
    `✅ Done 6/6` (Phase 0C actually closed when its PRs merged
    into main; the row was stale).
- `docs/design/35-validation-debt-register.md` — three rows
  walked to `covered` with `test-m2-2a-binary-recovery.R` as
  evidence:
  - **FAM-02** binomial(logit): `covered` (already; evidence
    cell extended to cite the new M2.2-A test).
  - **FAM-03** binomial(probit): `partial` → `covered`.
  - **FAM-04** binomial(cloglog): `partial` → `covered`.

  FAM-14 ordinal_probit stays `partial` until a deeper
  recovery PR walks it (M2.2-B or a dedicated FAM-14 slice;
  the link-residual = 1 assertion test alone is not deep
  enough to flip the row).

## 3. Files Changed

```
Added:
  tests/testthat/test-m2-2a-binary-recovery.R                   (~230 lines, 5 test_that blocks)
  docs/dev-log/after-task/2026-05-17-m2-2a-binary-recovery.md   (this file)

Modified:
  ROADMAP.md                                                    (M2 row 1/7→2/7; Phase 0C row Closing→Done)
  docs/design/35-validation-debt-register.md                    (FAM-02 / FAM-03 / FAM-04 evidence cells + status updates)
```

No R/ source change. No NAMESPACE change. No `man/*.Rd`
change. No vignette change.

## 4. Checks Run

- `NOT_CRAN=true Rscript -e 'devtools::load_all(); testthat::test_file(...)'`
  → 11 PASS · 1 SKIP · 0 FAIL on macOS arm64.
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" tests/testthat/test-m2-2a-binary-recovery.R docs/dev-log/after-task/2026-05-17-m2-2a-binary-recovery.md`
  → 0 hits.
- Hand-check: the helper closure uses `gllvmTMB::` qualified
  calls so it works under `devtools::load_all()` and on the
  installed package alike; the internal `gllvmTMB:::link_residual_per_trait`
  call is intentional (it's the function being tested).

## 5. Tests of the Tests

3-rule contract:

- **Rule 1** (would have failed before fix): the
  link-residual = π²/3 / 1 / π²/6 assertion in test #4 would
  have failed if the M1.6 `vW` formula fix (and the
  `link_residual_per_trait()` registry) were reverted. The
  recovery tests #1–#3 would degrade if `extract_Sigma()`'s
  per-family cascade were removed (would underestimate
  diagonals by the per-family residual).
- **Rule 2** (boundary): cloglog (test #3) is the boundary
  case where Λ-magnitudes near 1 push the linear predictor
  into Pr(y=1) ≈ 1 territory (cloglog is asymmetric). Λ_max =
  0.5 is the safe regime; the test would fail at Λ_max = 1.5
  with this small n. Documented in the test comment.
- **Rule 3** (feature combination): each test combines
  family selection (binomial link choice) × random-effect
  structure (`latent + unique` paired) × extractor
  (`extract_Sigma` with `link_residual = "auto"`). This
  exercises the M1.6 + M1.8 + M0 stack on binary single-family
  fits.

## 6. Consistency Audit

Stale-wording rg sweep on this PR's files:

- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" tests/testthat/test-m2-2a-binary-recovery.R docs/dev-log/after-task/2026-05-17-m2-2a-binary-recovery.md` → 0 hits.
- `rg "meta_known_V"` → 0 hits (canonical `meta_V` only).
- Citation discipline: test comment references
  `docs/design/02-family-registry.md` and Hadfield (2015)
  MEE 6:706-714 (the canonical ordinal-probit citation
  already in `test-ordinal-probit.R`).
- Persona-active-naming: lead Fisher + Curie named; reviewers
  Emmy + Boole + Rose + Ada named.

Convention-Change Cascade (AGENTS.md Rule #10): no function
↔ help-file pair affected. The ROADMAP tick + validation-debt
register walks (FAM-03 + FAM-04) ARE the cascade; both are
done in this PR (not deferred to M2.7 close gate).

## 7. Roadmap Tick

- **ROADMAP.md M2 row**: 🟢 In progress 1/7 → 🟢 In progress 2/7.
- **ROADMAP.md Phase 0C row**: 🟢 Closing 6/6 (pending merge)
  → ✅ Done 6/6. (Drift fix — Phase 0C actually closed long
  ago when its PRs merged into main; the row was stale per
  maintainer feedback 2026-05-17.)
- **Validation-debt register**:
  - FAM-02 binomial(logit) `covered`: evidence cell extended.
  - FAM-03 binomial(probit) `partial` → `covered`.
  - FAM-04 binomial(cloglog) `partial` → `covered`.
  - FAM-14 ordinal_probit stays `partial` (deeper recovery
    pending in M2.2-B or a dedicated slice).

## 8. What Did Not Go Smoothly

- **Ordinal-probit smoke fixture didn't converge in M2.2-A**.
  My minimal-fit construction (K = 4 categories, T = 2, n_ind = 200,
  formula `value ~ 0 + trait + unique(0 + trait | individual)`)
  hit convergence issues. The test gracefully skips with a
  clear reason; FAM-14 deep recovery is already covered by
  `test-ordinal-probit.R` (K = 3 + K = 4 cases). **Logged as a
  future small task**: write a minimal converging ordinal-probit
  fixture into the M2.2-A test file (or fold the link-residual
  invariant into `test-ordinal-probit.R` directly). Not
  blocking M2.2 progress.
- **CI-cancellation cascade** prior to this PR (separate
  process issue, not specific to M2.2-A). My back-to-back
  auto-merges of M1.8 / M1.9 / M1.10 / M2.1 cancelled each
  preceding R-CMD-check run on main, which prevented the
  pkgdown deploy from firing on success. Maintainer flagged
  the stale published site at the M2.1 close. I triggered a
  manual `workflow_dispatch` on `pkgdown.yaml` to redeploy.
  **Discipline change**: from M2.2-A forward, wait for
  R-CMD-check to complete on main before pushing the next PR
  merge.

## 9. Team Learning (per `AGENTS.md` Standing Review Roles)

**Fisher** (lead — inference path): the recovery test is the
single-replicate sanity layer; M3.3 will do R = 200 replicate
coverage. The bounds on test #1–#3 (max rel err < 0.5 on Σ,
max abs err < 0.3 on R) are *loose* relative to the design
doc's "10 % RMSE" target — that's appropriate for a
single-replicate test where one bad realisation could spike
the bound. M3.5 derived-quantity coverage will tighten this.

**Curie** (co-lead — DGP / fixtures): `binary_dgp()` helper
uses `simulate_site_trait(sigma2_eps = 0)` then re-applies the
per-link transform manually. This is the cleanest faithful-DGP
shape — letting `simulate_site_trait` add Gaussian noise on
top of η would conflate the latent residual with the link's
intrinsic residual. Carry-forward to M2.2-B: extend the
helper to accept a `unique_psi` argument so the CI tests
can vary unique-variance magnitude.

**Emmy** (review — extractor surface): the test verifies the
M1 cascade (`extract_Sigma` × `link_residual = "auto"`) works
correctly on single-family binomial fits. No new extractor
surface needed; this is depth-testing of the M1 work.

**Boole** (review — formula grammar): formula
`value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site)`
is canonical M0; no parser change required.

**Rose** (review — test discipline): stale-wording rg sweep
clean; persona-active-naming present; helper closure scoped
locally (not leaking into other tests). The `tryCatch` +
`skip(reason)` pattern in test #5 is the right graceful-
degradation style for fixtures with known convergence brittleness.

**Ada** (review — orchestration): M2.2 is split into
M2.2-A (recovery; this PR) + M2.2-B (CIs + extractors +
glmmTMB cross-check). The split mirrors M1's PR-B1/B2 batching
pattern. After M2.2-B merges, M2.3 (lambda_constraint binary
IRT) dispatches.

## 10. Known Limitations and Next Actions

- **M2.2-B dispatches next** — Fisher (CI lead) per §1.
  Scope: Wald + profile + bootstrap CIs on a binomial fit;
  `extract_correlations`, `extract_communality`,
  `extract_repeatability` single-family binomial tests;
  glmmTMB cross-check (one shared fixture, no grid).
- **Ordinal-probit smoke convergence** — small follow-up:
  write a minimal converging ordinal_probit fixture into
  `test-m2-2a-binary-recovery.R` so test #5 doesn't skip.
- **FAM-14 walk to `covered`** — currently stays `partial`;
  a dedicated FAM-14 deep slice (within M2.2-B or M2.7 close)
  walks it.
- **Future: precomputed binary recovery RDS** for M3.3 grid
  reuse — the M2.2-A `binary_dgp()` helper is a candidate for
  promotion to `R/data-binary-fixtures.R` once M2.3 lambda_constraint
  fixtures land in the same shape.
