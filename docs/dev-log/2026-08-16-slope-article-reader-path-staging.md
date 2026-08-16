# Slope-article reader-path staging checklist -- 2026-08-16

## Context

Maintainer standing directive (2026-08-01): "at least one random slope for
each distribution." The only article that speaks to this directive is
`vignettes/articles/random-slopes-nongaussian.Rmd`, deleted at commit
`eacbd0f6` (2026-07-12, "docs: finalize public article estate for 0.5.0") and
recovered 2026-08-16 to `dev/held-articles/random-slopes-nongaussian.Rmd`
(490 lines; parked, **not** in the pkgdown build). A commit-stat search for a
sibling slope/reaction-norm article deleted in the same commit
(`git show eacbd0f6 --stat -- 'vignettes/articles/*'`) found none -- 15
articles were cut that day, only one of them slope-shaped.

This checklist maps every capability/evidence claim in the recovered article
to the governing row in `docs/design/35-validation-debt-register.md` and
marks each KEEP (claim matches or understates the evidence) / REWORD (claim
exceeds the evidence -- reworded to match) / CUT (no supporting row, or the
cited test does not support the specific number claimed). It exists so the
directive above can be served honestly: the article is the only slope
worked-example candidate, but several of its claims were written against an
earlier register state and do not hold up against the current one.

## Register rows consulted

- **RE-02** -- one random slope (`s = 1`), core families: `covered`.
- **RE-03** -- two-or-more random slopes (`s >= 2`): Gaussian `phylo_dep(1 +
  x1 + x2 | sp)` `covered`; non-Gaussian `s >= 2` `reserved`/guarded.
- **RE-14** -- lognormal/Student-t/betabinomial augmented-slope family
  generality: `partial`, C1 runtime admission only (one seed, no recovery,
  no PD-Hessian evidence, no interval calibration).
- **PHY-11** -- `phylo_indep(1 + x | sp)` under binomial: `partial`,
  "structural contract only ... Replicated variance recovery, correlation
  recovery, intervals, and calibrated inference remain open."
- **PHY-12/13/14/15** -- `phylo_indep` under poisson / nbinom2 / Gamma /
  Beta: `covered` (family-specific recovery gates, not interval calibration).
- **PHY-16** -- `phylo_indep(1 + x | sp)` under ordinal_probit: `partial`,
  "the frozen fixture records only 3/6 converged positive-definite-Hessian
  fits against `min_good = 4` and therefore deliberately skips recovery. No
  ordinal variance or within-trait-correlation recovery claim is
  admissible."
- **PHY-17/18** -- `phylo_latent` / `phylo_dep` under non-Gaussian families:
  `covered` for the cited family-by-route cells (gaussian, binomial,
  poisson, nbinom1/2, Gamma, Beta, ordinal-probit), lognormal/Student-t
  `partial` under RE-14.
- **SPA-08/09/10** -- spatial analogues: `covered` for "registered
  Gaussian/core cells," lognormal/Student-t `partial` under RE-14. (The
  cited non-Gaussian test file's own header narrows this further -- see
  Claim 8 below.)
- **CI-08/CI-10** -- interval calibration: `partial`/`blocked`; only two
  narrow Gaussian cells clear a pre-registered 0.94 floor, "never nominal
  95%."

## Claim-by-claim map

### 1. "The structured random-slope grid now covers them [non-Gaussian responses]." (L61-63)

> "Non-Gaussian responses. Counts, proportions, bounded scores, and ordinal
> categories are the rule, not the exception, in trait data. The structured
> random-slope grid now covers them."

Governs: PHY-11, PHY-12-15, PHY-16, PHY-17, PHY-18. **REWORD** -- "covers"
reads as a blanket claim. `indep` mode recovery is established for poisson,
nbinom1/nbinom2, Gamma, and Beta (PHY-12-15), and `latent`/`dep` modes
recover across the full family list including binomial and ordinal_probit
(PHY-17, PHY-18); but `indep` mode for binomial and ordinal_probit is
structural-contract-only, with recovery explicitly not established (PHY-11,
PHY-16).

**Reword:** "The structured random-slope grid now reaches them: recovery is
established for the diagonal (`indep`) mode under poisson, nbinom1/nbinom2,
Gamma, and Beta, and for the `latent` and `dep` modes across the full family
list including binomial and ordinal_probit. Binomial and ordinal_probit
under the diagonal `indep` mode remain structural-contract-only, with
recovery not yet established."

### 2. "The full grid ... is now validated." (L70-81)

> "The full grid -- every core family (poisson, nbinom1, nbinom2, Gamma,
> Beta, binomial, ordinal_probit) crossed with the phylogenetic and spatial
> sources, across the indep, latent, and dep correlation modes -- is now
> validated ... This article is the worked tour of that grid."

Governs: same rows as Claim 1. **REWORD** -- same overclaim, now stated as
a single flat "validated" over the whole 7-family x 2-source x 3-mode grid.

**Reword:** "The full grid ... is now largely reachable: the `latent` and
`dep` modes recover across the full family list, and the diagonal `indep`
mode recovers for poisson, nbinom2, Gamma, and Beta. Binomial and
ordinal_probit under `indep` remain structural-contract-only, with recovery
evidence not yet established. This article is the worked tour of that grid,
flagged where evidence stops short of recovery."
*(Analysis anchors, not for the article text: latent/dep = PHY-17/PHY-18 +
SPA-09/SPA-10; indep recovery = PHY-12-15; the two partial cells = PHY-11,
PHY-16. Standing rule: no register codes on any reader-facing surface —
maintainer removed 14 such sites at `42d7452f`.)*

### 3. Scope table, row 1: "Covered for the core phylogenetic, spatial, and animal-model grid" (L87)

Governs: RE-02, PHY-11, PHY-16. **REWORD** -- same masking of the two
`partial` indep cells behind a blanket "Covered."

**Reword:** "Covered for `latent`/`dep` modes across the core grid, and for
`indep` mode under poisson/nbinom/Gamma/Beta; `indep`-mode binomial and
ordinal_probit remain structural-only, their recovery evidence still
pending." *(Anchors for the analysis only: PHY-11, PHY-16 — no codes in the
article text.)*

### 4. Scope table, row 2: "Gaussian phylo_dep(1 + x1 + x2 | species) (s = 2) | Covered for the structured phylogenetic dependent path" (L88)

Governs: RE-03 ("Gaussian `phylo_dep(1 + x1 + x2 | sp)` **covered**: ...
s = 2 recovers the full (1+s)T x (1+s)T Sigma_b within the inherited s = 1
bands"). **KEEP** -- matches the register exactly.

### 5. Scope table, row 3: "Non-Gaussian phylo_dep(..., s >= 2) | Partial; fail-loud guarded while diagnostics continue" (L89)

Governs: RE-03 ("Non-Gaussian s >= 2 stays **reserved** behind a dedicated
RE-03 runtime guard ... the guard rejects those fits until a separate s = 2
sweep clears"). **REWORD** -- the row's bolded lead word "**Partial**" reads
to a user as "partly works," but the register status is `reserved` and the
guard REJECTS the fit outright; only the trailing "fail-loud guarded" is
accurate.

**Reword:** "**Blocked** (reserved); the fit is refused with a clear error
until the evidence sweep clears."

### 6. Scope table, row 5: "Confidence intervals on slope variances | Not calibrated here" (L91)

Governs: CI-08, CI-10. **KEEP** -- correctly declines to claim coverage.

### 7. Poisson `phylo_dep` validation-cell paragraph (L367-374)

> "In the validation cell (Poisson, phylo_dep, n_species = 150, 2 traits, 10
> reps), the engine converges with a positive-definite Hessian and recovers
> the per-trait slope variances inside the mean-dependent-family band
> (within a factor of about 4 of truth ...)."

Governs: PHY-18, verified directly against
`tests/testthat/test-matrix-slope-phylo-dep.R` (PHY-18 poisson VALIDATION
cell, `n_sp = 150`, `var_band = 4`, asserts `fit$opt$convergence == 0` and
`pd_hessian`/`pdHess`). **KEEP** -- every specific number in this sentence
(150 species, factor-of-4 band, PD Hessian, convergence) is present in the
cited test.

### 8. Poisson `spatial_indep` validation-cell paragraph (L424-432)

> "In the validation cell (Poisson, spatial_indep, 300 sites), the fit
> converges with a positive-definite Hessian, the diagonal indep contract
> holds (the cross-field correlation is pinned to exactly 0), and both the
> intercept-field and slope-field BLUPs correlate with their simulated
> truth above 0.8."

Governs: SPA-08, checked directly against
`tests/testthat/test-spatial-indep-slope-nongaussian.R`. That file's own
header states: "These are STRUCTURAL cells: convergence + the per-trait
engine ... across the core non-Gaussian families. Full per-family variance
recovery (with the SPDE kappa normalisation) is a follow-up," and its
`make_spatial_eta()` DGP helper defaults to `n_sites = 150L`, not 300. The
poisson test itself (`.expect_per_trait_spatial()`) asserts only column
counts, free-parameter counts, and `sd_spde_b` length -- **no assertion of
convergence, PD Hessian, or any BLUP-truth correlation exists anywhere in
the cited test.** **CUT** -- this is the article's most over-claiming
sentence; see below.

**Reword (if a claim is kept at all):** "In the structural cell (Poisson,
spatial_indep, 150 sites), the fit routes to the correct per-trait engine
(2T augmented columns, 3T free block-diagonal parameters, correctly sized
`sd_spde_b`) -- this is wiring evidence, not recovery evidence. Convergence,
Hessian positive-definiteness, and BLUP correlation with simulated truth are
not yet measured for this cell (the cited test's own header records full
non-Gaussian recovery as 'a follow-up')."

### 9. "Full grid at a glance" table (L447-457)

> | Source | indep | latent | dep |
> | phylo_*(1 + x \| species) | validated | validated | validated |
> | spatial_*(1 + x \| coords) | validated | validated | validated |
> Families covered for each cell: gaussian, poisson, nbinom1, nbinom2,
> Gamma, Beta, binomial (incl. multi-trial), and ordinal_probit.

Governs: PHY-11, PHY-16 (indep column, binomial/ordinal_probit cells) — and
the table's lead-in sentence at L451, "Every cell below now fits and
recovers within its honest band across the core families," which is a flat
recovery claim over all cells one sentence above the table.
**REWORD** -- the flat "validated" per cell, and the lead-in's blanket
"recovers", both hide the two `partial` family x indep combinations
documented above.

**Reword (lead-in, L451):** "Every cell below now fits; recovery within its
honest band is established for the named validated cells, while binomial
and ordinal traits under the diagonal mode remain structural-only."
**Reword (indep column note):** "`indep`: validated except binomial and
ordinal_probit, which remain structural-contract-only under `indep` with
recovery not yet established." *(Anchors for the analysis only: PHY-11,
PHY-16 — no codes in the article text.)*

### 10. Developer-note admonition box (L37-45)

> "It documents validated syntax and point-recovery evidence for structured
> single-slope models, but it reports point estimates and recovery bands,
> not calibrated confidence intervals, and is not yet a public worked
> example."

Governs: CI-08, CI-10, and the general point-vs-interval framing used
throughout the register. **KEEP** -- this framing is the article's most
honest passage and should survive any rewrite essentially unchanged.

### 11. Family-list sentence after the Poisson `phylo_indep` fit (L316-321)

> "The slope variance recovers under the count family. The structured-slope
> grid is validated across the other core families as well (nbinom1,
> nbinom2, Gamma, Beta, binomial, ordinal_probit) -- swap family = and keep
> the formula."

Governs: PHY-11, PHY-13, PHY-14, PHY-15, PHY-16 (this sentence follows a
`phylo_indep` fit, so "the other core families" reads as "also under
`indep`"). **REWORD** -- same binomial/ordinal_probit `indep` overclaim as
Claims 1/2/9.

**Reword:** "The structured-slope grid is validated across nbinom1,
nbinom2, Gamma, and Beta under this same diagonal (`indep`) route; binomial
and ordinal_probit are validated under the `latent` and `dep` modes but
remain structural-contract-only under `indep` -- recovery there is not yet
established." *(Anchors for the analysis only: PHY-11, PHY-16 — no codes in
the article text.)*

## Cross-link audit (reader-path)

- **DEAD LINK:** L430 links `[functional-biogeography](functional-biogeography.html)`
  — no such article exists in `vignettes/articles/`. Fix (retarget or drop)
  at unhide time; this alone blocks an as-is unhide.
- The other four cross-links resolve: `api-keyword-grid`,
  `convergence-start-values`, `profile-likelihood-ci`, `response-families`.

## Tallies

| Article | KEEP | REWORD | CUT |
|---|---|---|---|
| `random-slopes-nongaussian.Rmd` | 4 (Claims 4, 6, 7, 10) | 6 (Claims 1, 2, 3, 5, 9, 11) | 1 (Claim 8) |

No sibling article was recovered, so there is only one article's worth of
claims here. Suggested article prose above deliberately carries no internal
register codes (standing reader-surface rule; the maintainer removed 14 such
sites at `42d7452f`) — codes appear only in the analysis annotations.

## Single most over-claiming sentence

Claim 8, the Poisson `spatial_indep` validation paragraph (L424-432):

> "In the validation cell (Poisson, spatial_indep, 300 sites), the fit
> converges with a positive-definite Hessian, the diagonal indep contract
> holds (the cross-field correlation is pinned to exactly 0), and both the
> intercept-field and slope-field BLUPs correlate with their simulated
> truth above 0.8."

This asserts a specific quantitative recovery result (BLUP-truth
correlation above 0.8) and a specific sample size (300 sites) for a cell
whose actual cited test only checks structural wiring at `n_sites = 150`,
with no convergence, Hessian, or correlation assertion anywhere in the file
-- and whose own header explicitly disclaims non-Gaussian recovery as future
work. Reworded version above (Claim 8).

## Decision list for Shinichi

Standing context: the 2026-08-01 directive is "at least one random slope
for each distribution," and this is the only slope article recovered from
the 2026-07-12 estate cut -- there is no competing draft to choose between.
The three options:

1. **Unhide as-is.** Not recommended -- Claims 1, 2, 3, 5, 8, 9, 11 overclaim
   against the current register, and Claim 8 in particular states a
   fabricated recovery number.
2. **Unhide with the rewordings above.** The article's structure, worked
   examples, and honest framing (Claims 4, 6, 7, 10) are sound; six REWORDs
   and one CUT bring the remaining claims in line with PHY-11/PHY-16/RE-03/
   RE-14/CI-08/CI-10. This is the fastest path to serving the 2026-08-01
   directive with a real worked example, at the cost of a joint editing
   pass.
3. **Keep parked.** Defer until PHY-11/PHY-16 clear recovery (a binomial/
   ordinal_probit `phylo_indep` recovery gate) or until the directive is
   served some other way (e.g. a narrower single-family article per
   distribution instead of one grid-wide article).

This document is the input to that joint review; it does not itself decide.
