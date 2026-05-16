# Phase 0C — article triage (KEEP / TRIM / PREVIEW / PULL / REWRITE)

**Maintained by:** Rose (consistency audit lead) and Pat (applied-
user lens).
**Reviewers:** Darwin (biology-first framing), Boole (formula-
grammar correctness in articles), Ada (orchestrator ratifies).
**Status:** DRAFT — Pat + Rose review **before** any article edits
(vision rule #2). No article files touched in this PR; this is the
planning artefact.

## Purpose

Per `docs/dev-log/decisions.md` 2026-05-16 item 9, Phase 0C is the
**transition cleanup** phase:

> 0C: transition cleanup (revert overpromise articles; rewrite
> ROADMAP; Phase 1b empirical coverage artefact).

This audit triages every `vignettes/articles/*.Rmd` (24 files)
against the **post-Phase-0B** state:
- 19 `claimed` rows walked to `covered` in `01-formula-grammar.md`
- 9 new smoke tests landed via PR-0B.2 and PR-0B.4
- `meta_V` is now the canonical name (PR-0B.4)
- Validation-debt register updated where applicable

For each article: what capability it advertises → register row(s) →
status → recommended action → rationale.

Vision rule #2 compliance: this triage is the artefact Pat + Rose +
Darwin review **BEFORE** any article PR opens. Execution PRs (each
with its own per-article Pat + Rose review) follow only after this
audit is ratified.

## Action vocabulary

| Action | What it means |
|---|---|
| **KEEP** | Article's machinery is `covered` in the register; no edits needed. Cascade-sweep #2 will later apply Option A `trait =` to its example calls (separate PR after Phase 0C). |
| **TRIM-SECTION** | Article is mostly fine but contains one or more sections describing capabilities NOT yet validated. Trim or remove those sections; keep the validated parts. |
| **PREVIEW-BANNER** | Article describes a partial-coverage capability honestly but stays in the public surface. Add a "Preview / under validation" banner at the top pointing at the relevant phase (M1 / M2 / M3 / M5.5). |
| **PULL** | Article describes capabilities not yet validated end-to-end; remove from `_pkgdown.yml` `articles:` list and move file to `vignettes/_workshop/articles/` (or delete) until backing machinery validates. |
| **REWRITE-LATE** | Article is destined to be authored as the last PR of Phase 1 (after M1 / M2 / M3 land) — e.g. `choose-your-model.Rmd` decision tree. Keep current file or remove pending the rewrite. |
| **REVIEW-FIRST** | The article needs a closer reading before action can be decided. Flag for maintainer / persona consult. |

## The 24-article triage

Articles ordered by article tier / dependency. Tier-1 worked examples
first; then Tier-2 concepts; then methods/validation; then pedagogy.

### Tier-1 worked examples (10 articles)

| # | Article | Advertises | Register row(s) | Status | Action | Rationale |
|---|---------|-----------|-----------------|--------|--------|-----------|
| 1 | `morphometrics.Rmd` | Gaussian, single-level individual × trait | FAM-01 covered, FG-04..06 covered, EXT-01 covered (G) | covered | **KEEP** | Tier-1 Gaussian exemplar; matches M1 Gaussian-completeness scope. Already canonical. |
| 2 | `behavioural-syndromes.Rmd` | Gaussian two-level individual × session × trait | FG-06 covered, FG-10 covered, RE-04 covered | covered | **KEEP** | Per vision Phase 1 M1: keep Gaussian sections. |
| 3 | `phylogenetic-gllvm.Rmd` | Gaussian + paired phylo_latent + phylo_unique | PHY-01..03 covered, PHY-07..09 covered | covered | **KEEP** | Per vision Phase 1 M1: keep Gaussian + canonical phylo sections. |
| 4 | `joint-sdm.Rmd` | Binary JSDM + "Mixed-family fits" section | FAM-02 covered, MIX-01..02 covered, **MIX-03..08 partial** | mixed | **TRIM-SECTION** | Keep the binary JSDM body. Remove the "Mixed-family fits" section (MIX-03..08 still partial; mixed-family extractor rigour is M1 work). Per vision Phase 1 M2. |
| 5 | `corvidae-two-stage.Rmd` | `meta_V` two-stage workflow | MET-01 covered (post-0B.4), MET-02 covered | covered | **KEEP** | meta_V single-V + block-V both now `covered` post-0B.4. The article's two-stage pattern uses both forms; no trim needed. |
| 6 | `functional-biogeography.Rmd` | Capstone six-piece kitchen-sink fit (unit + unit_obs + phylo + spatial + meta) | covered components individually; capstone composite is **M3 work** | partial composite | **PREVIEW-BANNER** | Each component is `covered`, but the capstone's identifiability + interpretability on real data is M3+ work (R≥200 empirical coverage gate). Article already has honest "do not promote beyond …" caveat; add a Preview banner pointing at M3. |
| 7 | `psychometrics-irt.Rmd` | Binary IRT + `lambda_constraint` (confirmatory loadings) | FAM-02 covered, **LAM-03 partial** (binary; M2.3) | partial (binary) | **REWRITE-LATE in M2** | Per vision Phase 1 M2: "psychometrics-irt.Rmd ... gets re-written using validated machinery". Until M2.3 validates `lambda_constraint` on binary at scale, the current article is preview. PULL from `_pkgdown.yml` for now? OR PREVIEW-BANNER until M2.3? **DECISION NEEDED.** |
| 8 | `mixed-response.Rmd` | Mixed-family extractor workflows | **MIX-03..MIX-08 partial** (extractors); engine accepts `family = list(...)` (MIX-01 covered) | partial | **PULL** | Article describes the unparalleled-capability differentiator (vision item 5), but extractor coverage for mixed-family is M1 work. Per vision: *"Articles that describe machinery beyond what is currently validated are either pulled (per the validation-debt register) or marked 'Preview' with a clear pointer to the relevant phase."* Recommend PULL until M1 validates MIX-03..08. After M1: re-author as `mixed-family-extractors.Rmd` (new article, validated). |
| 9 | `stacked-trait-gllvm.Rmd` | Foundational stacked-trait grammar | FG-04..06 covered, FG-10 covered | covered | **KEEP** | Foundational article; the grammar it documents is all `covered`. |
| 10 | `ordinal-probit.Rmd` | `ordinal_probit` family | **FAM-14 partial** (smoke only) | partial | **PREVIEW-BANNER** | The family exists and works in smoke; full per-cell validation is M2 work (FAM-14 → covered after M2). Keep the article with a banner: "Preview: ordinal-probit validation is part of the M2 Binary completeness milestone." |

### Concepts (pedagogy + lambda-constraint + decision tree) (6 articles)

| # | Article | Advertises | Register row(s) | Status | Action | Rationale |
|---|---------|-----------|-----------------|--------|--------|-----------|
| 11 | `lambda-constraint.Rmd` | `lambda_constraint` confirmatory loadings | LAM-01 covered, **LAM-02 partial** (Gaussian deep validation), LAM-03 partial (binary) | partial | **PREVIEW-BANNER** | The Gaussian-path validation (test-lambda-constraint.R with 7 substantive assertions) is now `covered` per PR-0B.3 row #18 walk. Binary IRT is M2.3 work. Banner: "Validated on Gaussian; binary IRT validation is M2.3 milestone work." Keep article. |
| 12 | `data-shape-flowchart.Rmd` | Pedagogy — long/wide decision tree | n/a (pedagogy) | n/a | **KEEP** | Concept article. No machinery claims. |
| 13 | `gllvm-vocabulary.Rmd` | Pedagogy — glossary | n/a (pedagogy) | n/a | **KEEP** | Concept article. |
| 14 | `simulation-verification.Rmd` | Pedagogy — simulation discipline | n/a (pedagogy) | n/a | **KEEP** | Concept article; the engine-side `simulate_site_trait()` and `coverage_study()` are already covered. |
| 15 | `troubleshooting-profile.Rmd` | Pedagogy — profile-CI failure modes | CI-04..07 covered, DIA-07 covered | covered | **KEEP** | Concept article backed by Phase 1b PRs. |
| 16 | `covariance-correlation.Rmd` | Concepts — Σ vs correlation; latent/unique decomposition | EXT-01 covered, EXT-04 covered (Gaussian) | covered | **KEEP** | Phase 0A Option C variance-share framing already applied. |

### Methods / validation tier (3 articles)

| # | Article | Advertises | Register row(s) | Status | Action | Rationale |
|---|---------|-----------|-----------------|--------|--------|-----------|
| 17 | `profile-likelihood-ci.Rmd` | Profile CI methods (Wald / profile / bootstrap) on direct + derived quantities | CI-02..07 covered (Gaussian) | covered | **KEEP** | Phase 1b PRs (#105, #109, #120, #121, #122) closed the validation. M3 extends to mixed-family. |
| 18 | `cross-package-validation.Rmd` | Cross-package agreement runs (glmmTMB, gllvm, galamm, sdmTMB, MCMCglmm, Hmsc) | live glmmTMB + gllvm agreement covered; **queued Phase 5.5 comparators partial** | partial | **TRIM-SECTION** | Keep the live `glmmTMB::glmmTMB()` + `gllvm::gllvm()` agreement runs. **Remove the queued-comparator sections** (sdmTMB, galamm, MCMCglmm, Hmsc, brms) — those are Phase 5.5 external-validation-sprint work, not 0.2.0. After Phase 5.5: a NEW article `cross-package-agreement-runs.Rmd` ships with the full grid. |
| 19 | `simulation-recovery.Rmd` | R≥200 reproducible coverage runs | **CI-08 partial** (smoke fixture only) | partial | **PULL** | Article uses hard-coded recovery numbers from one precomputed run; not reproducible. M3 milestone delivers the reproducible R=200 pipeline (`dev/precompute-vignettes.R` + cached RDS). After M3: NEW article `simulation-recovery-validated.Rmd` ships. PULL current file until then. |

### Reference / decision-tree (4 articles)

| # | Article | Advertises | Register row(s) | Status | Action | Rationale |
|---|---------|-----------|-----------------|--------|--------|-----------|
| 20 | `api-keyword-grid.Rmd` | Reference — 3×5 keyword grid | All keyword rows now covered post-0B | covered | **KEEP** | Tier-2 reference; matches the post-0B status map. |
| 21 | `response-families.Rmd` | Family table (all 15 advertised) | mixed: 3 families `covered` (FAM-01, 02, 06, 08), 12 families `partial`, 10 delta variants `blocked` | mixed | **REVIEW-FIRST** | The current article likely advertises all 15 families equally; reality is per-family validation tier. Recommend: **TRIM-SECTION** for the 10 delta-family rows (per vision item 5: deferred post-CRAN); ADD per-family status badges from the register; ADD scope-boundary statement per AGENTS.md Writing Style. Open question to Pat: should this article keep one-row-per-family or be reorganised by status (covered first, partial section, deferred section)? |
| 22 | `pitfalls.Rmd` | Concepts — common identifiability / interpretation errors | mostly n/a (pedagogy); references covered machinery | n/a | **KEEP + AUDIT PROSE** | Concept article. Some prose may reference machinery beyond current 0.2.0 scope; Rose audit checks for stale claims (e.g. mentions of `gllvmTMB_wide()` as current API, mentions of `meta_known_V` as primary name, in-prep citations on foundational results). |
| 23 | `choose-your-model.Rmd` | Decision tree → specific articles by data shape | mixed | mixed | **REWRITE-LATE (Phase 1f per vision)** | Per vision Phase 1f: "Choose-your-model rewrite (last PR of Phase 1)". Keep current article in place for now; rewrite happens AFTER M1 / M2 / M3 land. **DECISION NEEDED**: keep current article unchanged in 0C (it'll be replaced in Phase 1f), or PREVIEW-BANNER it now? |

### Site-only article (1 article)

| # | Article | Advertises | Register row(s) | Status | Action | Rationale |
|---|---------|-----------|-----------------|--------|--------|-----------|
| 24 | `roadmap.Rmd` | Roadmap rendering | n/a (sourced from `ROADMAP.md`) | n/a | **REWRITE in same PR as ROADMAP** | The article is a thin wrapper that renders `ROADMAP.md`. Phase 0C's ROADMAP rewrite (to milestone format M1 / M2 / M3 / M5 / M5.5 per decisions.md item 9) is a separate work item; the article itself doesn't need editing — only the underlying ROADMAP.md does. |

## Action summary

| Action | Count | Articles |
|--------|-------|---------|
| **KEEP** (no edits in 0C) | 12 | #1, #2, #3, #5, #9, #12, #13, #14, #15, #16, #17, #20 |
| **KEEP + audit prose** | 1 | #22 |
| **TRIM-SECTION** | 2 | #4 (joint-sdm Mixed-family section), #18 (cross-package queued comparators) |
| **PREVIEW-BANNER** | 3 | #6 (functional-biogeography), #10 (ordinal-probit), #11 (lambda-constraint) |
| **PULL** | 2 | #8 (mixed-response), #19 (simulation-recovery) |
| **REWRITE-LATE** | 2 | #7 (psychometrics-irt — Phase 1 M2.5; OR PREVIEW until then), #23 (choose-your-model — Phase 1f) |
| **REVIEW-FIRST** | 1 | #21 (response-families — reorganise by status?) |
| **Synchronous with ROADMAP rewrite** | 1 | #24 (roadmap.Rmd auto-renders from ROADMAP.md) |

**Net article work in Phase 0C**:
- 2 PULL operations (move files out of pkgdown nav)
- 3 PREVIEW-BANNER additions (~5 lines per article)
- 2 TRIM-SECTION edits (~20-40 lines removed per article)
- 1 KEEP+audit-prose pass (Rose audit)
- 1 REVIEW-FIRST consultation (response-families restructure)

Plus the **ROADMAP.md rewrite** (Phase 0C's other big deliverable per decisions.md).

Plus the **Phase 1b empirical coverage artefact** (the R=200 coverage_study script + cached RDS). This may belong in a separate sub-PR.

## Open questions for reviewers

**Pat (applied-user legibility)**:
- For #7 (`psychometrics-irt`): PULL until M2.5 ships the rewritten version, OR PREVIEW-BANNER it now? Trade-off: PULL = applied users can't find it via the site (cleaner); PREVIEW = they can read the current draft with a caveat (more discoverable but invites overpromise).
- For #21 (`response-families`): keep one-row-per-family, or reorganise by status tier (covered / partial / deferred)?
- For #23 (`choose-your-model`): PREVIEW-BANNER now, or leave alone until the Phase 1f rewrite?

**Rose (consistency audit)**:
- Are any `KEEP` articles secretly overpromising? Cross-check each `covered` claim in each article against the register.
- For #22 (`pitfalls`): scan for stale terms (`gllvmTMB_wide()`, `meta_known_V` as primary name, in-prep citations on foundational results).
- Are any articles missing from this triage? (24 in `vignettes/articles/`; check against `_pkgdown.yml` to verify.)

**Darwin (biology-first framing)**:
- For #6 (`functional-biogeography`): the capstone is the flagship Tier-1 article. Is the Preview banner the right disposition, or should the capstone composite be more aggressively trimmed until M3 validates identifiability?
- For #21 (`response-families`): if reorganised, what's the biology-first ordering? (Gaussian, then binomial, then count, then continuous-positive, then ordinal, then delta-deferred?)

**Boole (parser-syntax / formula-grammar correctness)**:
- For #4 (`joint-sdm`): the "Mixed-family fits" section uses `family = list(...)`. Confirm trimming removes the family-list demonstration but keeps the binary JSDM body.
- Any articles referencing `meta_known_V` as primary (rather than `meta_V`)? Note for cascade-sweep #2.

**Ada (orchestrator)**:
- Phase 0C work plan: should this be ONE big revert/trim PR, or ONE PR per action group (PULL PR; TRIM PR; PREVIEW PR; etc.)?
- The ROADMAP rewrite (decisions.md item 9): separate PR? Same PR as the article cleanup? Recommend separate — ROADMAP rewrite is its own design decision and gets its own Pat + Rose review.
- The Phase 1b empirical coverage artefact: separate sub-PR? Or merged with the smoke-test work that already landed in PR #137?

## Out of scope for Phase 0C (these are M1 / M2 / M3 / M5.5 work)

- M1 Gaussian completeness: random slopes (capped at 1); full extractor validation on Gaussian; R≥94% coverage gate.
- M2 Binary completeness: `lambda_constraint` + `suggest_lambda_constraint` on binary IRT; M2.3 + M2.4.
- M3: R=200 reproducible coverage grid → `simulation-recovery-validated.Rmd`.
- M5.5 External validation sprint: cross-package comparator runs → `cross-package-agreement-runs.Rmd`.
- Mixed-family extractor rigour (MIX-03..08 walks to `covered`): M1 work.

## Cross-references

- `docs/design/00-vision.md` — function-first sequencing; "What we will NOT do" rule #2 (Pat + Rose review BEFORE edits).
- `docs/dev-log/decisions.md` 2026-05-16 item 9 — Phase 0A / 0B / 0C sequencing.
- `docs/design/35-validation-debt-register.md` — per-row status for every advertised claim.
- `docs/design/01-formula-grammar.md` — post-0B status map (zero `claimed` rows).
- `AGENTS.md` Writing Style — scope-boundary statement template.
- `_pkgdown.yml` — the `articles:` list governs what's surfaced on the rendered site.

## Persona engagement (read order)

1. **Pat** first: applied-user lens on the per-article triage; answers the open questions on PULL-vs-PREVIEW trade-offs (#7), restructure question (#21), and #23 timing.
2. **Rose** second: consistency cross-check; flags any `KEEP` articles that secretly overpromise.
3. **Darwin** third: biology-first framing on the capstone (#6) and the family table (#21).
4. **Boole** fourth: parser-syntax correctness in trimmed sections (#4) and any cascade-sweep-#2 prep notes.
5. **Ada** ratifies last: PR-shape (one big PR vs per-action-group); decides ROADMAP timing; ratifies the audit.

After ratification: per-action-group execution PRs follow, **each with its own per-article Pat + Rose review** per vision rule #2.
