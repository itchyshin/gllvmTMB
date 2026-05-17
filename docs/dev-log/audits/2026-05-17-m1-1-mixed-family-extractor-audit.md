# M1.1 audit — per-extractor mixed-family handling

**Date**: 2026-05-17
**Lead**: Boole + Emmy
**Reviewers**: Fisher (inference path); Rose (audit trail); Ada (close gate)
**Source**: M1.1 slice contract in `ROADMAP.md`
(`Phase 1 milestones → M1`, slice M1.1).

This audit is the **first M1 deliverable**. No code edits in
this PR — it's pure read-only inspection of the extractor
surface to identify which paths handle `family = list(...)`
fits correctly today and which need M1.3..M1.8 work.

Inputs read: `R/extract-sigma.R`, `R/extract-correlations.R`,
`R/extract-omega.R`, `R/extract-repeatability.R`,
`R/extractors.R`, `R/bootstrap-sigma.R`,
`R/extract-cutpoints.R`, plus the cross-checking helpers
`link_residual_per_trait()` (in `R/extract-sigma.R:99–...`)
and `fit$tmb_data$family_id_vec`.

Existing mixed-family tests:
`tests/testthat/test-mixed-family-extractor.R` (4 tests),
`tests/testthat/test-mixed-response-sigma.R` (4 tests),
`tests/testthat/test-mixed-family-olre.R` (4 tests),
`tests/testthat/test-stage37-mixed-family.R` (2 tests),
`tests/testthat/test-link-residual-15-family-fixture.R`
(15+ tests on the helper).

## Headline finding

| Extractor | Mixed-family path | Status today | M1 slice | Action needed |
|---|---|---|---|---|
| **`extract_Sigma`** | Direct: `family_id_vec` + `link_residual_per_trait` at L568/594/617 | partial (some tests) | **M1.3** | Validate on fixture; test per-family diagonal correctness |
| **`extract_correlations`** | Direct: `family_id_vec` at L186 (PR #101 `link_residual = "auto"`) | partial (Fisher-z + Wald only) | **M1.4** | Test profile + bootstrap on mixed-family |
| **`extract_communality`** | Delegates → `extract_Sigma` (inherits) | partial (point + bootstrap) | **M1.5** | Validate partition $H^2 + C^2 + \psi^2 = 1$ |
| **`extract_repeatability`** | **NONE — omits `sigma2_d`** (see §1 below) | **BUG / partial** | **M1.6** | Add per-family `sigma2_d` to `vW`; verify Gaussian backward-compat; test mixed-family |
| **`extract_phylo_signal`** | Indirect: via `extract_proportions` → `link_residual_per_trait` at L488 | partial | **M1.6** | Test on mixed-family + phylo fixture |
| **`extract_Omega`** | Direct: `link_residual_per_trait` at L227 | partial (one test in test-mixed-response-sigma.R) | **M1.7** | Cross-tier integration test on mixed-family |
| **`extract_residual_split`** | Direct: `link_residual_per_trait` at L129 | partial | folded into **M1.7** | Test on mixed-family |
| **`bootstrap_Sigma`** | Indirect: via `simulate()` + refit + delegating `.extract_summaries()` | partial (no mixed-family test) | **M1.8** | Verify per-row family preservation across resamples |
| **`extract_Sigma_B / Sigma_W`** (legacy) | Delegates → `extract_Sigma` (inherits) | OK once M1.3 closes | — | No new work |
| **`extract_ICC_site`** (legacy) | Delegates → `extract_Sigma` (B + W tiers) | OK once M1.3 closes | — | No new work |
| **`extract_ordination`** | Reads `fit$report$Lambda_B/W` directly; family-agnostic by design | OK | — | No gap — Lambda is rotation-variant but not family-dependent |
| **`extract_cutpoints`** | Ordinal-probit-only | M2 scope | — | Not M1 work |
| **`extract_proportions`** | Delta-family blocked | post-CRAN | — | Not M1 work |

## §1 — The `extract_repeatability` correctness gap (M1.6)

This is the **only correctness bug surfaced by the audit**.
Every other "partial" status is a test-coverage gap, not a
formula gap.

The function computes per-trait repeatability
$R_t = v_{B,t} / (v_{B,t} + v_{W,t})$. Its definition of
$v_{B,t}$ and $v_{W,t}$ at `R/extract-repeatability.R:126–127` is:

```r
vB <- diag(Lambda_B %*% t(Lambda_B)) + sd_B^2
vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2
```

For a Gaussian fit, this is correct: the implicit residual
variance is the W-tier `sd_W^2`. For a **non-Gaussian fit**,
this is **incomplete** — the canonical
Nakagawa & Schielzeth (2010) latent-scale repeatability
adds the per-family link residual $\sigma^2_d$ (the
$\pi^2/3$ for binomial-logit, $\log(1 + 1/\hat\mu_t)$ for
Poisson, the trigamma terms for NB2 / Beta / Gamma, etc.) to
the W-tier denominator. Without that addition, the W-tier
variance is **systematically under-estimated** for non-
Gaussian families, which biases repeatability upward (toward 1).

For a **mixed-family fit**, the bias is per-trait: Gaussian
traits unaffected, non-Gaussian traits over-estimated.

**M1.6 fix sketch** (not in this PR — flagged for M1.6 PR):

```r
sigma2_d <- link_residual_per_trait(fit)   # per-trait, 0 for Gaussian
vB <- diag(Lambda_B %*% t(Lambda_B)) + sd_B^2
vW <- diag(Lambda_W %*% t(Lambda_W)) + sd_W^2 + sigma2_d
```

Backward-compat: Gaussian behaviour unchanged because
`link_residual_per_trait()` returns 0 for Gaussian. Tests
on the M1.2 mixed-family fixture should show: (a) Gaussian-only
fit recovers byte-identical repeatability to current
behaviour; (b) non-Gaussian + mixed-family fits get the
canonical Nakagawa & Schielzeth (2010) latent-scale value.

This bug is **silent** today: the function does not error;
it just returns a biased estimate. Discovery surface: any
non-Gaussian repeatability claim a user makes today is
biased; documentation should call this out until M1.6 lands.

## §2 — Existing test coverage map (what to keep, what to extend)

| Test file | Covers | Status |
|---|---|---|
| `test-stage37-mixed-family.R` | Engine accepts `family = list(...)` → `family_id_vec` dispatch (MIX-01, MIX-02) | ✅ covered |
| `test-mixed-family-extractor.R` (4 tests) | `extract_Sigma()` × mixed-family; `extract_correlations(link_residual = "auto")`; `extract_Sigma(part = "unique")` zero-Psi diagonal | partial — point estimate only |
| `test-mixed-response-sigma.R` (4 tests) | `link_residual_per_trait()` per-family vector; `extract_Sigma()` mixed-family; `extract_Omega()` + `extract_proportions()` per-trait residuals; backward-compat for single-family | covers MIX-03, MIX-07 partial |
| `test-link-residual-15-family-fixture.R` (15+ tests) | The helper `link_residual_per_trait()` on each of the 15 families | ✅ covered (MIX-09) |
| `test-mixed-family-olre.R` (4 tests) | OLRE behaviour in mixed-family (parameter-map suppression) | covered (MIX-07) |

**Tests missing for M1**:

- `extract_communality()` on mixed-family with full partition
  identity (M1.5).
- `extract_repeatability()` on mixed-family — both correctness
  fix verification AND test (M1.6).
- `extract_phylo_signal()` on mixed-family + phylo fixture
  (M1.6).
- `extract_Omega()` cross-tier integration on mixed-family
  beyond the existing single test (M1.7).
- `bootstrap_Sigma()` mixed-family — per-row family
  preservation across n_boot resamples (M1.8).
- `extract_correlations()` profile + bootstrap on mixed-family
  (M1.4 — Fisher-z + Wald exist; profile + bootstrap need
  coverage).

## §3 — Mixed-family-aware vs mixed-family-blind extractors

**Aware** (use `family_id_vec` and/or `link_residual_per_trait()`
directly):

- `extract_Sigma` — at extract-sigma.R:568, 594, 617
- `extract_correlations` — at extract-correlations.R:186
- `extract_Omega` — at extract-omega.R:227
- `extract_residual_split` — at extract-omega.R:129
- `extract_proportions` — at extract-omega.R:488 (delta-blocked
  for now)

**Inherit awareness via delegation**:

- `extract_communality` — calls `extract_Sigma(level, part)`
  twice
- `extract_Sigma_B`, `extract_Sigma_W` — legacy aliases to
  `extract_Sigma(level = "unit" / "unit_obs")`
- `extract_ICC_site` — calls `extract_Sigma(level = "unit")`
  + `extract_Sigma(level = "unit_obs")`
- `extract_phylo_signal` — calls `extract_proportions()`
  internally (which is aware)

**Aware via separate path** (simulate + refit):

- `bootstrap_Sigma` — uses `simulate(fit)` + refit +
  delegating `.extract_summaries()`. Per-row family is passed
  through `fit$family` → `family = family` in the refit.
  Needs a test to confirm this preservation under resampling.

**Family-agnostic by design**:

- `extract_ordination` — returns raw $\Lambda_B$ and $\Lambda_W$
  loadings + scores; no per-family mixing needed (Lambda is
  rotation-variant but family-blind).

**Mixed-family-blind (the gap)**:

- `extract_repeatability` — see §1.

## §4 — M1 slice routing implications

The audit confirms the M1.3..M1.8 slice routing from the
ROADMAP:

- **M1.3** `extract_Sigma()`: tests, not refactor. Path is
  already mixed-family-aware; M1.3 adds the fixture + coverage.
- **M1.4** `extract_correlations()`: tests on profile +
  bootstrap methods on mixed-family. Fisher-z + Wald already
  partially covered.
- **M1.5** `extract_communality()`: tests via delegation
  inheritance; verify $H^2 + C^2 + \psi^2 = 1$ partition.
- **M1.6** `extract_repeatability` + `extract_phylo_signal`:
  **the only slice with a code change** — add `sigma2_d` to
  `vW` in extract_repeatability; verify backward-compat;
  test mixed-family.
- **M1.7** `extract_Omega` cross-tier: existing single test
  extended.
- **M1.8** `bootstrap_Sigma` per-row family preservation: new
  test against M1.2 fixture.

The audit also confirms the M1.2 fixture design is broadly
correct (3-family + 5-family fits with known DGP). The Curie
lead on M1.2 should ensure the fixture includes at least one
non-Gaussian + one Gaussian trait so the per-trait
`link_residual_per_trait()` paths fire differently across
traits (Gaussian → 0; non-Gaussian → non-zero).

## §5 — Recommended Day-1 plan adjustment

The original Day-1 plan
(`docs/dev-log/audits/2026-05-17-day1-plan.md`) batched
M1.3 + M1.4 in `M1-PR-B1` and M1.5 + M1.6 in `M1-PR-B2`.
The audit confirms this batching is sound **with one caveat**:

- **M1.6 has a code change** (the `extract_repeatability`
  formula fix), not just tests. The batched PR should be
  named `M1-PR-B2 (code fix + tests for ratio extractors)`
  to flag this, and the after-task report should call out
  the formula change explicitly + verify backward-compat.

All other slices remain tests-only.

## Decisions (maintainer ratification before M1.2 dispatches)

1. **Ratify the M1.6 formula fix scope**: add `sigma2_d` from
   `link_residual_per_trait(fit)` to `vW` in
   `extract_repeatability` at L127. Backward-compat preserved
   because Gaussian returns 0. **(a) approve / (b) discuss**
2. **Confirm M1.2 fixture design**: 3-family (Gaussian +
   binomial + Poisson, 60 sites, 3 traits) + 5-family
   (add Gamma + nbinom2). Curie lead. **(a) approve / (b)
   adjust**
3. **Confirm Day-1 batching**: M1-PR-A1 audit (this PR) →
   M1-PR-A2 fixture → M1-PR-B1 (Σ + corr) → M1-PR-B2 (ratio
   + repeatability fix). **(a) approve / (b) adjust**

## Cross-references

- `ROADMAP.md` — M1 slice table (PR #147).
- `docs/design/35-validation-debt-register.md` — rows
  MIX-03..MIX-08 (this audit's deliverable list).
- `docs/dev-log/audits/2026-05-17-day1-plan.md` — Day-1 plan.
- `R/extract-sigma.R:99` — `link_residual_per_trait()` helper
  (the canonical per-family link-residual lookup).
- `tests/testthat/test-link-residual-15-family-fixture.R` —
  per-family `sigma2_d` correctness (already `covered`).
