# Random-Slope Board Correction Notes

Source: `dev/rand-slope-truth-ledger.md` (3-column extraction: CODED =
`.augmented_slope_family_contract()` in `R/fit-multi.R:453`; VALIDATED =
`docs/design/35-validation-debt-register.md`; ADVERTISED =
`docs/dev-log/capability-surface.html`). Five of the ledger's nine mismatches
are fixed here. Four (IDs 0 gaussian, 2 poisson, 5 nbinom2, 15 nbinom1) are
DELIBERATELY left untouched — see "Cells deliberately NOT changed" below.

All edits are to the "Rand. slope" column of the per-family table in
`docs/dev-log/capability-surface.html`. No ✓ (green checkmark) was created by
any of these edits — every changed cell uses the `partial` tag class
(`t-avail`, same visual weight as gaussian/poisson/nbinom2/nbinom1's existing
`partial` cells) or keeps the `no` class with a corrected annotation.

## Cells changed

### ID 7 — Beta (line ~405)
- **Old:** `<td class="no">—</td>`
- **New:** `<td><span class="tag t-avail">partial</span></td>`
- **Licensing register row:** PHY-15 — `phylo_indep(1 + x | sp)` augmented
  slope under Beta is `covered` (`test-phylo-indep-slope-nongaussian.R`,
  ≥5/6 healthy seeds, pooled intercept/slope relative error ≤0.45). Contract
  basis is `route_specific` (same tier as poisson/nbinom2/nbinom1), so it is
  set to `partial` — matching the board's own deliberate policy (gap box,
  ~line 471) that random slopes are shown as `partial`, not ✓, board-wide
  regardless of register status. No C1 caveat is needed because PHY-15 is a
  full `covered` route, not a C1 admission.

### ID 4 — Gamma (line ~412)
- **Old:** `<td class="no">—</td>`
- **New:** `<td><span class="tag t-avail">partial</span></td>`
- **Licensing register row:** PHY-14 — `phylo_indep(1 + x | sp)` augmented
  slope under Gamma is `covered` (`test-phylo-indep-slope-nongaussian.R`,
  ≥5/6 healthy seeds, pooled intercept/slope variances within a factor-4
  band). Contract basis `route_specific`. Same reasoning as Beta above: set
  to `partial`, not ✓, per the board's blanket random-slope policy.

### ID 9 — student (line ~426)
- **Old:** `<td class="no">—</td>`
- **New:** `<td><span class="tag t-avail">partial</span> <span style="font-size:10px">C1 phylo_indep single-seed</span></td>`
- **Licensing register row:** RE-14 — student-t (runtime family id 9) is
  admitted at the six family-agnostic augmented-slope guard sites via
  `.augmented_slope_family_contract()` (contract basis `c1_partial`).
  Evidence is one adequate-N `phylo_indep(1 + x | species)` seed with
  convergence, finite-positive reported SDs, and pooled slope-SD ratio in
  [0.5, 1.7] — no fixed-effect recovery, PD-Hessian/gradient check, per-trait
  recovery, replicated seeds, interval calibration, or direct
  phylo-dep/latent/spatial recovery (RE-14, FAM-12, PHY-17, SPA-09, SPA-10 all
  concur). Annotation style mirrors the existing betabinomial precedent
  (`C1 phylo_indep large-N`), but says "single-seed" rather than "large-N"
  because RE-14's evidence for student-t is one seed at ordinary N, not the
  large-N (`n_sp = 200`, trials = 15) regime specific to betabinomial's
  multi-trial DGP.

### ID 3 — lognormal (line ~433)
- **Old:** `<td class="no">—</td>`
- **New:** `<td><span class="tag t-avail">partial</span> <span style="font-size:10px">C1 phylo_indep single-seed</span></td>`
- **Licensing register row:** RE-14 — lognormal (runtime family id 3) is
  admitted on the same C1 basis as student-t above (contract basis
  `c1_partial`). One `phylo_indep(1 + x | species)` seed, pooled slope-SD
  plausibility only (RE-14, FAM-11, PHY-17, SPA-09, SPA-10). Same annotation
  as student-t for the same reason (one seed, ordinary N, not the
  betabinomial large-N multi-trial regime).

### ID 14 — ordinal_probit (line ~447)
- **Old:** `<td class="no">— <span style="font-size:10px">ordinal RE not implemented</span></td>`
- **New:** `<td class="no">— <span style="font-size:10px">PHY-16: 3/6 converged PD-Hessian fits (min_good=4) — recovery not admissible</span></td>`
- **Why the old text was false:** family id 14 (ordinal_probit) IS present in
  `.augmented_slope_family_contract()` (link_0 = TRUE, `route_specific`
  basis) and augmented slopes construct and fit for it — the runtime feature
  exists.
- **Licensing register row:** PHY-16 — the `phylo_indep(1 + x | sp)`
  augmented slope under ordinal_probit is `partial`. The `2T` structural
  route, `3T` free-parameter count, and cross-block-zero contract are
  exercised, but the frozen fixture records only 3/6 converged
  positive-definite-Hessian fits against `min_good = 4`, so the test
  deliberately skips recovery. No ordinal variance or within-trait-correlation
  recovery claim is admissible. The `no`/`—` cell class is kept (not upgraded
  to `partial`) because PHY-16's evidence is weaker than the other four cells
  fixed here — it does not even clear the register's own convergence
  threshold — so a `partial` tag would overstate it.

## Cells deliberately NOT changed

IDs 0 (gaussian), 2 (poisson), 5 (nbinom2), 15 (nbinom1) keep their existing
`partial` board cells even though their register rows include a `covered`
status (RE-02, PHY-12, PHY-13, PHY-18 respectively). This is intentional, per
the board's own gap-box text (`docs/dev-log/capability-surface.html`, ~line
471): *"Random slopes (≥1) are unfinished. In development / diagnostic-grade
even for Gaussian — not a finished capability. Shown as `partial`, not ✓."*
The "Rand. slope" column asks whether the ≥1-slope capability is FINISHED —
a stricter bar than any single register row's `covered` status for one route.
Raising these four to anything stronger than `partial` would be an
over-claim relative to the board's own stated standard. No edits were made
to these four rows.

## No ✓ created

Verified: none of the five edits above introduces a `<span class="yes">✓</span>`
element. Every changed cell uses `t-avail`/`partial` or the existing `no`
class with a corrected annotation.

## Also fixed: `docs/design/61-capability-status.md`

Line 176 (Article Restoration Queue table) claimed *"Future structured
random-slope guide | deferred; the validation-led article was retired from
pkgdown"*. Verified false: `vignettes/articles/random-slopes-nongaussian.Rmd`
is present in `_pkgdown.yml`'s nav (line 150), and commit `60318d482e7ee`
("feat(docs): pre-run results, slope article unhidden with rewords, Design 66
one-pager", 2026-08-16) explicitly unhid it. The article is `tier: 3` /
"under-audit" (a Developer Note), not deferred or retired. The row was
corrected to reflect the live, tier-3 status and to reference the article by
its actual filename, without rewriting the rest of the document.
