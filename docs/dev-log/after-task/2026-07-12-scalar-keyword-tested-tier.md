# scalar() keyword + honest capability surface — gllvmTMB (2026-07-12)

**Author:** Claude (opus-4.8) · **Branch:** `claude/release-0.5.0`
**Arc:** the safe, non-breaking slice of the covariance-mode-taxonomy campaign
(ultra-plan `~/.claude/plans/glistening-skipping-anchor.md`).

## Scope

The session established a canonical covariance-mode taxonomy (Design 79: two
orthogonal axes — mode × `|`/`||` correlation coupling) and ran a fit-verified
census (S0). This arc landed only the **non-breaking** part: the `scalar()`
keyword, the honest "tested" tier on the widget, and the doc refreshes. All
breaking / new-engine work is explicitly deferred behind a stats checkpoint.

## Outcome

- **`scalar()` (no-prefix, intercept-only)** — new exported keyword. Desugars
  byte-identically to `indep(0 + trait | g, common = TRUE)`:
  \eqn{\Sigma_T = \sigma^2 I_T}, one shared variance tied across traits. Fills
  the grid's `none/scalar` cell. `scalar(1 + x | g)` (slope) fails loud — the
  augmented form is a later, gated slice. Non-breaking (new symbol only).
  Commit `45c9fdc9`.
- **Design 79** — canonical taxonomy spec; supersedes Design 55 §5; §7 records
  the fit-verified engine-name shift. Commit `154a22db`.
- **Capability widget** — new light-green **tested** tier (passing tests, no
  article); phylo (scalar/indep/dep), all animal, all spatial, and
  `kernel_latent` flipped amber→tested (recovery tests already existed — the
  label was stale); `none/scalar` now live. Redeployed to the same artifact URL.
  Commit `039171c6`.
- **Design 61** — dated delta block refreshing the covariance-grid layer from
  Design 79 + the census. Commit `b50b5aa6`.

## Checks run

- `devtools::document()` — clean; `export(scalar)` added, `man/scalar.Rd`
  generated (NAMESPACE diff = the one export line, no spurious churn).
- Desugar probe: `scalar(0+trait|site)` **byte-identical** to
  `indep(0+trait|site, common=TRUE)`; `scalar(1+x|site)` errors cleanly.
- `devtools::test()` on the parser/grammar surface:
  `test-canonical-keywords.R` 116 pass / 0 fail (incl. 5 new scalar tests),
  `test-formula-grammar-smoke.R` 28 pass / 0 fail. **Total 144 pass / 0 fail.**
- Fit test: `scalar()` converges and reports one shared `sd_B` across all traits
  (all equal to <1e-10), objective byte-identical to `indep(common=TRUE)`.

Not run this arc: full `R CMD check --as-cran` (changes are a new keyword +
docs; the goal was "--as-cran unaffected", and the parser suite is green). Worth
a confirmatory `--as-cran` at the next checkpoint.

## Working-tree classification

Committed this arc (local, **not yet pushed** past `872a7f2d` at time of
writing — push pending): `154a22db`, `45c9fdc9`, `039171c6`, `b50b5aa6`.
Pre-existing held files untouched (`.Rbuildignore`, `pkgdown.yaml`,
`CONTRIBUTING.md`, `ROADMAP.md` — Shinichi's disposition).

## Follow-up (precise next steps)

Gated behind the **stats-member checkpoint** (breaking / new engine), per
Design 79 §7 and the plan:
1. **`indep(1+x|g)` → per-trait correlated (3T)** — the genuine new engine;
   changes what `*_indep(1+x)` fits today (shared-2 → per-trait). Needs a
   deprecation/migration story; likely C++ + Totoro recovery validation.
2. **`dep(1+x||g)`** (block Σ_int⊕Σ_slope) and the **`||` engine** for indep/dep
   (parser refuses standalone slope-only terms today — not free sugar).
3. **`*_scalar(1+x|g)` slope routing** — cheap (routes to the existing
   `*_unique` / `*_indep` augmented engines), non-breaking; can land ahead of #1.
4. **`kernel_scalar()`** — needs a formula-LHS grammar redesign.
5. **S1 stretch (cheap, non-gated):** `kernel_indep`/`kernel_dep` recovery tests
   and a binomial `phylo_latent` intercept-only test → flip those amber cells.
6. **S3/S4:** land the Design 79 §8 reader section in `api-keyword-grid.Rmd`
   once the slope engines exist; draft the drmTMB `|`/`||` coordination issue.
