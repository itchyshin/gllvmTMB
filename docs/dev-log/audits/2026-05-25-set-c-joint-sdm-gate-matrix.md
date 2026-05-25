# Set C joint-SDM restoration: read-only gate matrix

**Date:** 2026-05-25
**Maintained by:** Pat (applied-user clarity), Darwin (biology-first
framing), Rose (scope honesty), Curie (fixture/simulation fidelity),
Fisher (inference-method honesty), Emmy (S3 / extractor coverage),
Shannon (cross-team coordination).
**Status:** Audit only. **No prose written, no chunks rewritten, no
fixtures added, no `joint-sdm.Rmd` edited.** Verdicts below are
gates against future restoration work — not authorisation to start it.
**Scope:** `vignettes/articles/joint-sdm.Rmd` (428 lines, currently in
the `internal` pkgdown tier per `_pkgdown.yml:71`).
**Related:** Set C = the restoration set for articles that were
trimmed or hidden during the 2026-05-15 overpromise reset. The other
Set C members (`mixed-response.Rmd`, `cross-package-validation.Rmd`,
`simulation-recovery.Rmd`) remain in `dev/workshop-articles/` and are
out of scope for this gate.

## 1. Purpose

The maintainer's hard boundary on Set C is: *"Do not revive
joint-sdm prose before the fixture and validation evidence are
real."* This memo answers the prior question: **what counts as
"real" evidence, per row of the article, against the current
validation-debt register?** It is a scoping memo for the eventual
restoration slice; it does not start that slice.

## 2. Scope at audit time

`joint-sdm.Rmd` is currently in the `internal` tier of
`_pkgdown.yml` (line 71 of the `internal:` block). It renders, but
the public articles dropdown does not surface it. "Restoration"
in this audit means moving the article out of `internal` into a
public tier (Worked examples or Methods + validation), not adding
new prose.

The article's currently-advertised scope is **pure-binary JSDM,
long format, single-family binomial**. The 2026-05-15 reset
removed a "Mixed-family fits" section; the article does not
currently claim mixed-family coverage. **Rose lens (2026-05-25):**
this is the scope this gate matrix audits. Any future expansion
back into mixed-family territory re-binds the article to
validation-debt rows CI-10 and MIX-10, both of which are still
`partial` or `blocked`, and is therefore out of scope here.

## 3. Component-level gate matrix

Verdict vocabulary: **KEEP** = already evidence-backed at the
register row depth; **REWRITE** = concept sound, current prose
relies on partial-status registers and needs honest reframing or a
footnote; **DEFER** = depends on machinery / fixture not yet
landed; **DISCARD** = overpromise with no path to honest version;
**NEW** = must be added before restoration. Test-evidence column
cites validation-debt-register rows from
[`docs/design/35-validation-debt-register.md`](../../design/35-validation-debt-register.md).

| Component (joint-sdm.Rmd) | Current state | Register backing | Fixture / test gap | Verdict |
|---|---|---|---|---|
| Article metadata + setup chunk (`eval = TRUE` global) | Loads pkg, builds simulated 8-species × 100-site binary data via `simulate_site_trait()` + `gllvmTMB()` with `binomial()` | FAM-02 `covered`; MIX-01..02 `covered`; FG-01..04 `covered` | None | **KEEP** |
| Pure-binary JSDM fit (lines ~207–260: `latent(d=2)`, long format, no `unique()`) | Long-format fit; identification rests on logit Bernoulli σ²_d = π²/3 | FAM-02 `covered`; FG-04 `covered`; FG-06 `covered` (Gaussian baseline, paired-form behaviour on binary documented in §"Why drop unique()") | None — `test-m2-2a-binary-recovery.R` + `test-m2-2b-binary-cis-extractors.R` walk the path | **KEEP** |
| Wide-form equivalence chunk (lines 261–290: `jsdm-fit-wide`, **eval = FALSE**) | Marked dormant; reader-facing note explicitly defers to "Phase 1c article-port programme"; comment names absence-fill semantics as the open question | FG-03 `covered` (general wide path); **no binary-specific long↔wide parity test** | **Missing**: a binary-JSDM long↔wide byte-equivalence fixture that explicitly handles missing (site, species) → absence = 0 semantics | **DEFER** (stays `eval = FALSE` until the fixture exists) |
| Covariance theory section (lines 48–101: Σ_B vs Σ_total, per-family link-residual, π²/3 / 1 / log-mean formulas) | Mathematical exposition with no `eval = TRUE` claims tied to specific cells; reproduces the `link_residual_per_trait()` table | EXT-01 `covered`; MIX-09 `covered`; FAM-02..04 `covered` (link-residual evidence on 15-family fixture) | None — `test-link-residual-15-family-fixture.R` exercises every family entry | **KEEP** |
| "Why we drop `unique()` for pure binary" (lines 103–131: rationale table + Hessian / boundary discussion) | Pedagogical table comparing convergence / `sd_B` boundary across paired vs latent-only fits | FG-06 `covered` (Gaussian); RE-09 `partial` (binary `latent + unique` smoke only); FAM-02 `covered` | The "binary" rows of the comparison table rest on RE-09 `partial`, not `covered` | **REWRITE** (reframe as "pure-binary best practice given current evidence" + footnote citing RE-09 `partial`, not as an exhaustive comparative claim) |
| "What about `dep` and `indep` for binary?" (lines 133–166: empirical table) | Compares `latent(d=2)` vs `indep` vs `dep` on simulated binary data; reports per-keyword logL + Σ agreement | FG-07 / FG-08 `partial` (Gaussian only); FAM-02 `covered` | No pure-binary `indep` / `dep` recovery fixture; FG-07/08 status would prevent honest "covered" claim if reframed as comparative proof | **REWRITE** (reframe as "what the engine returns on this example" + footnote citing FG-07/08 `partial`, or replace table with a cross-ref to those debt rows) |
| `extract_Sigma()` dispatch table (lines 168–198: 15-family residual formulas) | Reference table; pedagogical | EXT-01 `covered`; MIX-03 `covered`; MIX-09 `covered` | None — `test-link-residual-15-family-fixture.R` + `test-m1-3-extract-sigma-mixed-family.R` | **KEEP** |
| Simulate + fit demo (lines 217–277) | Designed loadings → 4 niche quadrants → fit comparison | FAM-02 `covered`; FG-01 / FG-02 `covered` (long format) | None for long; wide deferred | **KEEP** (long only) |
| Latent-scale correlations + CIs (lines 292–340) | `extract_correlations()` Fisher-z call; mentions profile + bootstrap alternatives | EXT-04 `covered` (Fisher-z + Wald), `partial` (profile + bootstrap on mixed-family); CI-07 `covered`; CI-09 `covered` | None for pure-binary Fisher-z; profile / bootstrap on mixed-family stays `partial` but the article does not currently claim mixed-family CIs | **KEEP** |
| Σ heatmaps (`extract_Sigma_table()` + `plot_Sigma_heatmap()`) | Shared vs total side-by-side; visualises π²/3 diagonal addition | EXT-18 `covered`; EXT-19 `covered`; FAM-02 `covered` | None — `test-extract-sigma-table.R` + `test-plot-covariance-tables.R` | **KEEP** |
| Ordination biplot (lines 343–397: site scores, species loadings, arrow scaling) | `extract_ordination()` + base-R biplot; rotation-variant with caveat in §"See also" | EXT-09 `covered` (rotation-variant, warn) | None — `test-ordiplot-VP.R` + `test-ordiplot-multi.R`. Note: ordination tests cover mixed-family but not specifically pure-binary; smoke is implicit through `extract_ordination()` family-agnostic path. | **KEEP** (current scope honest; a one-line "rotation-variant; sign and order anchored per `rotate_loadings()` convention" sentence already present at line ~395 covers Rose) |
| `## See also` section (lines 398–402) | Cross-links to `phylogenetic-gllvm`, `behavioural-syndromes`, `lambda-constraint`, `data-shape-flowchart` | All four targets render; only `phylogenetic-gllvm` is in a public tier today | None — but if joint-sdm moves out of `internal`, the See-also links from those articles back to joint-sdm should be added in the same PR for symmetry (Pat lens) | **REWRITE** (small: add reciprocal See-also from `phylogenetic-gllvm` and `lambda-constraint` to joint-sdm in the restoration PR) |
| References (lines 403–428) | Niku et al. 2017, Nakagawa & Schielzeth 2010/2017, Warton et al. 2015 | n/a — citation-only | None — citations are authoritative for the in-scope claims | **KEEP** |
| **Diagnostic-table panel (NOT in current article)** | n/a | Depends on PR #265's `diagnostic_table()` helper (currently `MERGEABLE / CLEAN`, awaits #261 first) | Article does not currently advertise posterior-predictive diagnostics; per Design 51 scope, this is **not required for restoration** | **DEFER (not required)** — joint-sdm does not currently make pp-check / residual-diagnostic claims that would need PR #265 |

## 4. Dependencies that gate the restoration PR

| Dependency | Why it matters | Status | Blocks restoration? |
|---|---|---|---|
| #261 (Codex, diagnostic teaching reset) | Touches `ROADMAP.md` + `check-log.md`; restoration PR also touches `ROADMAP.md` (Set C tracking) | MERGEABLE / CLEAN; awaits CI gate | **Yes (sequencing only)** — restoration PR sequences after #261 to avoid rebase on those two files |
| #265 (Codex, `diagnostic_table()` helper) | Article does not currently use `diagnostic_table()`; restoration scope does not require pp-check chunks | MERGEABLE / CLEAN; sequences after #261 | **No** — restoration scope independent of #265 |
| Binary long↔wide absence-fill fixture | The wide-form chunk on lines 261–290 stays `eval = FALSE` until this exists | Missing | **No for KEEP-scope restoration**; **yes** if the eventual scope grows to include a live wide-form example |
| r200 evidence on CI-08 / CI-10 | Article does not currently claim coverage on mixed-family; restoration scope does not bind to these rows | r200 not yet authorised; CI-08 / CI-10 `partial` per Design 50 §9 | **No** — the article's pure-binary scope is not gated by CI-08 / CI-10. **Restoration must not silently expand scope back into mixed-family without re-auditing against these rows.** (Rose) |

## 5. Headline

- **The pure-binary JSDM scope is restorable in principle**: every
  KEEP-verdict row above is backed by `covered` register evidence
  in [Section 6 (MIX), Section 7 (EXT), and Section 11 (CI) of the
  validation-debt register](../../design/35-validation-debt-register.md).
  No fixture is missing for this scope.
- **Two REWRITE items gate restoration**: (a) "Why drop
  `unique()`" rests on RE-09 `partial`; needs a footnote, not an
  exhaustive claim. (b) "`dep` vs `indep` vs `latent` for binary"
  rests on FG-07 / FG-08 `partial`; needs reframing or replacement
  with a cross-ref. Both fixes are prose-only, ≤ 30 lines each.
- **One DEFER item stays dormant**: the wide-form chunk
  (`jsdm-fit-wide`, `eval = FALSE`) is honestly gated by the
  missing binary long↔wide absence-fill fixture. Restoration can
  ship with this chunk dormant exactly as written today.
- **Rose-style scope guard**: restoration must not silently
  re-introduce a "Mixed-family fits" section. If the eventual
  restoration PR proposes that, the gate matrix must be re-run
  against CI-10 and MIX-10 first.
- **No engine work required**: this is not an engine-readiness
  gate; it is a prose-and-pkgdown-tier gate. The R/ surface is
  untouched.

## 6. What this memo does NOT do

- **No prose written, no chunks edited, no `joint-sdm.Rmd`
  changed.** This is a scoping audit; the restoration PR is a
  separate slice.
- **No fixture added.** The missing binary long↔wide absence-fill
  fixture is named but not built.
- **No `_pkgdown.yml` change.** Moving joint-sdm out of the
  `internal` tier is a restoration-PR action, not an audit
  action.
- **No CI-08 / CI-10 register edit.** Those rows stay `partial`
  per Design 50 §9; nothing in this gate matrix changes that.
- **No claim about the other Set C members** (`mixed-response`,
  `cross-package-validation`, `simulation-recovery`). They stay
  in `dev/workshop-articles/`; their gate matrices are separate
  audits.
