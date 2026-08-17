# Slice-2 pass criteria — multinomial structured random effects (phylo_dep / phylo_indep)

**STATUS: SIGNED (Shinichi, 2026-08-16, in-session).** This is a pre-registered criteria
block copied verbatim into this file so the aggregation logic cannot drift from
what was agreed before results exist. Do not weaken or add cells to this
block after seeing the `--mode full` output; any change after that point needs
a fresh dated note explaining why, not a silent edit.

---

## `phylo_dep` cell (full unstructured (K-1)x(K-1) V)

Reuses `pass-criteria-s1.md`'s band verbatim — `phylo_dep(0 + trait |
species)` populates the SAME `phylo_rr`/`theta_rr_phy` slot as `phylo_latent(d
= n_traits)` (the S1 comparator), verified numerically equivalent at the V
level in `test-matrix-multinomial-phylo.R` (task item 3, tolerance 1e-4,
matched TMB objective both directions), so the same recovery band applies:

> 20 seeds; fits enter the aggregate only if convergence==0 and PD Hessian
> (non-PD → counted+reported, excluded); rail rate = seeds with any
> |rho_hat|>0.99, reported separately, >6/20 rails = FAIL; direction-correct
> rate for rho_hat ≥ 16/20 non-railed; median rho_hat ∈ [0.30, 0.60]; median
> contrast-SD ratio ∈ [0.5, 2.0].

## `phylo_indep` cell (diagonal V, no among-category correlation)

20 seeds, same DGP (`rho_true = 0.6`, `sd_true = c(0.8, 0.8)`, `n_sp = 800`);
fits enter the aggregate only if convergence==0 and PD Hessian (non-PD →
counted+reported, excluded); a fit whose EITHER per-contrast variance is
below `1e-6` is a degenerate near-zero collapse (a documented failure mode of
one-species-per-tip phylogenetic recovery, not a bug in the diagonal route,
task item 4 in `test-matrix-multinomial-phylo.R`) → counted+reported as
`collapsed`, excluded from the ratio aggregate but NOT from the denominator.
Median per-contrast variance ratio (`var_hat / var_true`, pooled across both
contrast dimensions and all non-collapsed seeds) ∈ **[0.33, 3.0]**. >6/20
collapsed seeds = FAIL (mirrors S1's >6/20 rail-rate threshold, the
diagonal-route analogue of railing).

### Planted-zero cross-check (task item 4)

On a SEPARATE null-correlation DGP (`rho_true = 0`, same `sd_true`, same
`n_sp`), for every seed where `phylo_indep()` converges non-degenerately:
refit `phylo_latent(species, d = K - 1)` on the SAME data and record
`rho_hat`. **Median `|rho_hat|` across those refits < 0.35.** This checks
that the shared low-rank ordination does not invent spurious among-category
correlation on data generated with none -- narrower than the single-seed
smoke-level `< 0.6` bound used in the per-commit test (this is a 20-seed
median, not a one-seed sanity check).

---

## Notes (not part of the pre-registered block above)

- "contrast-SD ratio" / "per-contrast variance ratio" = `sd_hat / sd_true` /
  `var_hat / var_true` per contrast dimension (2 values per fit at K = 3); the
  criterion is on the median across all (seed, contrast) cells for that
  keyword.
- Criteria are evaluated **per keyword** (`phylo_dep`, `phylo_indep`)
  separately, matching S1's convention -- they are separate admission
  questions, not one pooled claim.
- The MEASURED timing fit for this campaign (D-139, this task, 2026-08-16):
  `--mode timing` (n_sp = 800, phylo_dep, seed = 1): **elapsed 10.37 sec**,
  convergence = 0, pdHess = TRUE, `rho_hat = -1` (a rail on the FIRST seed --
  an early red flag the rail-rate criterion above is designed to count, not
  evidence against running `--mode full`; projected 40-fit full run ≈ 6.9 min
  on the timing fit's own rate, well under the 30-min line). `--mode smoke`
  (n_sp = 60, 2 seeds x 2 keywords, 4 fits): all convergence = 0, pdHess =
  TRUE; `phylo_indep()` collapsed to near-zero variance on BOTH seeds
  (`V_hat` diagonal ~1e-11 to 1e-14) and `phylo_dep()` railed
  (`rho_hat` = ±1) on BOTH seeds -- consistent with S1's own smoke-mode
  observation on `animal_latent()`/`kernel_latent()` and with Design 84's
  documented data-hungry caveat; n_sp = 60 is far below the n_sp = 800
  this campaign's `--mode full` uses.
- The null-DGP probe (`dev/multinomial-structured/probe-scalar-null.R`, task
  item 5, run as part of this task): on genuinely NULL data (`V_true = 0`, n_sp
  = 200, 5 seeds), `phylo_indep()` correctly recovered near-zero variance in
  ALL 5 seeds (median scalar-like mean variance 2.3e-12), but `phylo_dep()`
  reported `|rho_hat|` near 1 (median 0.966, range 0.765-1) in 4 of 5 seeds
  DESPITE `pdHess = TRUE` and a stationary gradient -- a near-zero-variance
  correlation-railing pathology, the same shape as the S1 README's own
  single-seed rail observation, now reproduced under a KNOWN-zero truth. This
  is evidence for the rail-rate criterion above (both cells), not a reason to
  change the pre-registered bands.
- `--mode full` was **NOT run** as part of the ORIGINAL task that drafted
  this file -- staged only, at that time. **Update: the full campaign HAS
  since run to completion under these signed criteria** (results:
  `dev/multinomial-structured/results/s2-summary-20260816-183632.csv`,
  `s2-indep-corrected-summary.csv`); the verdict is BOTH cells FAILED,
  recorded in `docs/design/35-validation-debt-register.md`'s FAM-20D row
  and `docs/design/122-multinomial-structured-surface.md` §1/§4 -- this
  bullet is left as the historical pre-run note rather than deleted.

**Amendment (D-43 completion panel R6, 2026-08-16, dated below the frozen
block above -- the frozen block itself is unedited):** STATUS updated from
DRAFT to SIGNED to match the register's FAM-20D row, which already
reported this campaign's verdict as signed. The criteria numbers above
were not touched.
