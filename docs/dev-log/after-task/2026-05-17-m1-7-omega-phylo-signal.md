# After Task: M1.7 — extract_Omega cross-tier + extract_phylo_signal on mixed-family + phylo

**Branch**: `agent/m1-7-omega-phylo-signal`
**Slice**: M1.7
**PR type tag**: `validation` (new tests; no R/ change)
**Lead persona**: Emmy (extractor architecture)
**Maintained by**: Emmy + Boole; reviewers: Fisher (phylo-signal partition), Rose (test discipline), Ada (close gate)

## 1. Goal

Seventh M1 deliverable. Walks register row **MIX-07**
(extract_Omega cross-tier mixed-family) and the relevant subset
of **EXT-07** (extract_phylo_signal on mixed-family + phylo fit)
from `partial` to `covered`. Both extractors inherit mixed-family
awareness via `extract_Sigma → link_residual_per_trait` (M1.1
audit §3); M1.7 is **tests-only**, no R/ change.

## 2. Implemented

**Mathematical contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change.

New test file
`tests/testthat/test-m1-7-extract-omega-phylo-signal-mixed-family.R`
(3 tests, ~140 lines).

The test fixture is built locally with `ape::rcoal()` + a 20-species
tree + 25 crossed sites × species + 3 traits (Gaussian + binomial
+ Poisson). The M1.2 cached fixture is not used here because (a) it
has no phylo structure and (b) it has no site × species
replication for `unique(species)` identifiability.

### Tests

1. **extract_Omega shape + PSD + tier presence** on phylo + mixed-
   family fit (T = 3): `Omega` is 3×3 symmetric PSD; `tiers` list
   includes `"phy"`.
2. **Cross-tier identity**: `extract_Omega` equals the manual sum
   $\Sigma_{\text{phy}} + \Sigma_B + \mathrm{diag}(\text{link\_resid})$
   to numerical precision. Verifies that the per-tier Σ's (with
   `link_residual = "none"`) sum correctly + the link residual is
   added **once at the Omega level** (not per-tier — the function
   comment explicitly notes this to avoid double-counting).
3. **extract_phylo_signal partition**: returns $H^2$, $C^2_{\text{non}}$,
   $\psi$ in $[0, 1]$; the three proportions sum to 1 per trait
   (per the function's docstring contract); $V_\eta > 0$ for all
   traits.

## 3. Files Changed

```
Added:
  tests/testthat/test-m1-7-extract-omega-phylo-signal-mixed-family.R   (3 tests, ~140 lines)
  docs/dev-log/after-task/2026-05-17-m1-7-omega-phylo-signal.md          (this file)
```

No R/, NAMESPACE, generated Rd, register-row-status, or
`_pkgdown.yml` change.

## 4. Checks Run

- **15 / 15 tests pass** (NOT_CRAN=true).
- 1 warning during run: a `level = "B"` deprecation from
  `extract_Omega` calling `extract_Sigma(level = tier)` internally
  with `"B"` (the legacy tier alias). This is a **pre-existing
  internal call** in `R/extract-omega.R:215` — not introduced by
  M1.7 — and the deprecation is non-fatal (the legacy alias still
  works). Flagged as a small future cleanup PR.
- `pkgdown::check_pkgdown()` → ✔ No problems found.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **Rule 1** (would have failed before fix): cross-tier identity
  test would have failed if `extract_Omega` were double-counting
  the link residual (e.g., adding it inside each tier loop and
  also at the Omega level). The function comment at
  `R/extract-omega.R:209` explicitly says *"Adding [the link
  residual] inside the per-tier loop would double-count it"* —
  the test verifies this by reconstructing Omega manually with
  link_residual added **once** and matching to numerical
  precision.
- **Rule 2** (boundary): the partition sum-to-1 test probes the
  3-component decomposition's normalisation boundary. If any
  component were biased (e.g., $V_\eta$ underestimated), the
  proportions wouldn't sum to 1.
- **Rule 3** (feature combination): phylo × mixed-family ×
  cross-tier integration — three independent extractor surfaces
  jointly exercised by one fixture.

## 6. Consistency Audit

- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" tests/testthat/test-m1-7-*` → 0 hits.
- Test labels cite MIX-07 + EXT-07 register IDs (skill check 14).
- `skip_on_cran()` + `skip_if_not_installed("ape")` gates present.

Convention-Change Cascade (AGENTS.md Rule #10): N/A — tests
only.

## 7. Roadmap Tick

- `ROADMAP.md` M1 row: now **7 / 10 done** (M1.1 + M1.2 + M1.3 +
  M1.4 + M1.5 + M1.6 + M1.7).
- **Validation-debt register walks**:
  - **MIX-07 → covered** (extract_Omega cross-tier mixed-family).
  - EXT-07 (extract_phylo_signal) was already broadly `covered`
    on Gaussian; M1.7 extends to phylo + mixed-family.

## 8. What Did Not Go Smoothly

- **Tier "B" deprecation warning in extract_Omega internals.**
  `extract_Omega` calls `extract_Sigma(fit, level = tier, ...)`
  where `tier ∈ {"phy", "B", "W"}`. The "B" and "W" labels are
  legacy aliases (canonical: "unit" and "unit_obs"). The
  `extract_Sigma` boundary translation fires a deprecation
  warning each call. This is pre-existing (not M1.7's fault);
  the warning shows up once per test that uses `extract_Omega`.
  **Cleanup PR scope** (low priority): inside `extract_Omega`,
  pass the canonical "unit" / "unit_obs" tier names to
  `extract_Sigma` and suppress the deprecation cascade. Logged.
- **Fixture compute cost**. The phylo + mixed-family fit takes
  ~10–25 s wall-clock (n_species = 20, n_sites = 25, 3 fitting
  TMB iterations × refit). Acceptable for `skip_on_cran` tests
  but pushes the M1.7 test file to ~30–40 s total. Documented
  as a CI-budget consideration; not a blocker.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Emmy** (lead, extractor architecture): the **cross-tier identity**
test (test 2) is the most valuable assertion in M1.7 — it pins
the function's "add link residual once at Omega level" contract
to a verifiable equation. If a future refactor reorganises the
tier-summation logic, this test catches double-counting at the
point where it would be introduced.

**Boole** (formula / API): the fit's formula
(`phylo_latent(species, d=1) + latent(0 + trait | site, d=1) + unique(0 + trait | site)`)
exercises three independent random-effect terms across two
clustering levels (site for `latent + unique`, species for
`phylo_latent`). This is a stress test of the formula parser
+ engine boundary that `make_phylo_mixed_family_fit` covers
incidentally.

**Fisher** (phylo-signal partition): the partition $H^2 +
C^2_{\text{non}} + \psi = 1$ in `extract_phylo_signal` is the
**species-level latent partition** (not the latent-scale
observable partition that the 2017 paper computes). This is by
design per the function's docstring — the gllvmTMB partition
describes what proportion of *species-level latent variance* is
due to phylogeny vs non-phylo shared vs trait-specific
unique. It does NOT include the observation-level link residual
in the denominator. M1.7 tests this contract; the **future
`extract_proportions()` extractor** (delta-family blocked,
post-CRAN) is the place to test the full latent-scale partition
that DOES include link_residual.

**Rose** (test discipline): tests cite MIX-07 + EXT-07 register
IDs in `test_that()` names per skill check 14. `skip_on_cran()`
+ `skip_if_not_installed("ape")` gates correct.

**Ada** (orchestration): 7 / 10 M1 slices done. Two remaining
substantive slices: M1.8 (bootstrap_Sigma mixed-family + the
link_residual propagation fix for
`extract_correlations(bootstrap)` + the profile-correlation
surface audit) and M1.9 (new article `mixed-family-extractors.Rmd`
+ banner removal on `covariance-correlation.Rmd`). M1.10 close
gate at the end.

## 10. Known Limitations and Next Actions

- **M1.8 dispatches next** — has the most substantive code
  changes remaining in M1: the `link_residual = "auto"`
  propagation fix in `bootstrap_Sigma`'s `.extract_summaries()`
  call to `extract_Sigma` (the gap M1.4 surfaced), plus tests
  for `bootstrap_Sigma` mixed-family per-row family preservation.
  Also: the profile-correlation surface audit (Σ_shared vs
  Σ_total) — likely a brief audit doc, not a code change.
- **Tier "B" deprecation cascade** (cleanup PR): inside
  `R/extract-omega.R:215`, use canonical "unit" / "unit_obs"
  tier names when calling `extract_Sigma`. Small follow-up;
  flagged in §8.
- **Phylo + mixed-family + W-tier**: M1.7 omits a W-tier
  (`unique(species)` for non-phylo species variance) because
  the audit on `test-phylo-q-decomposition.R` (referenced in
  the fixture comment) documents an identifiability concern
  when both `phylo_latent + unique(species)` co-exist. The
  M1.7 fit uses `phylo_latent + latent(site) + unique(site)`
  which sidesteps the question. A future audit could explore
  whether the W-tier (species-level non-phylo) decomposition
  is recoverable on mixed-family fits.
