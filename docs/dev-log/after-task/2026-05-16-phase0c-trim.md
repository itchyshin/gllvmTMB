# After Task: PR-0C.TRIM — trim overpromise sections in joint-sdm + cross-package-validation

**Branch**: `agent/phase0c-trim`
**PR type tag**: `scope` (article surface trim; no R/ source, no NAMESPACE, no machinery change)
**Lead persona**: Rose (overpromise-removal discipline)
**Maintained by**: Rose + Pat; reviewers: Boole (formula-grammar wording), Fisher (cross-package framing), Ada (close gate)

## 1. Goal

Second of six planned Phase 0C execution PRs
(PULL ✅ → **TRIM** → PREVIEW → REWRITE-PREP → ROADMAP →
COVERAGE).

Trim two in-article overpromise surfaces called out by the
2026-05-16 Phase 0C triage (`docs/dev-log/audits/2026-05-16-phase0c-article-triage.md`,
row #4 and row #18):

- `joint-sdm.Rmd` — remove the `### Mixed-family fits` section
  (lines 170–187 in main). The section describes
  `family = list(...)` workflows; the engine accepts the syntax
  (MIX-01/02 `covered`) but extractor rigour is `partial`
  (MIX-03..MIX-08). The article body itself is a **pure binomial**
  JSDM; the deleted section was forward-looking M1 material. Also
  drop "and mixed-family" from the link-residual section heading
  and the trailing mixed-family-framed paragraph (technical
  content kept; framing generalised).
- `cross-package-validation.Rmd` — remove the
  `## Queued comparators (Phase 5.5 external validation sprint)`
  section (lines 330–371 in main) and the 5 queued rows from the
  Validation matrix. The live agreement against `glmmTMB::rr()`,
  `gllvm::gllvm()`, `glmmTMB::propto()`, `glmmTMB::equalto()`,
  and `glmmTMB::diag()` stays. Queued comparators (`MCMCglmm`,
  `Hmsc`, `sdmTMB`, `galamm`) are now mentioned only as a brief
  Phase-5.5-scope-boundary statement in the opening paragraph.

The pulled simulation-recovery.Rmd (PR-0C.PULL) had a cross-link
in cross-package-validation; that orphan link is repaired in
this PR as a cascade-cleanup. A pre-existing broken link to a
non-existent `spde-vs-glmmTMB.html` is also removed.

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change. Pure
article-surface trim.

### `joint-sdm.Rmd`

- Line 131–133 (bottom-line guidance after the binary `unique()`
  identifiability table): trimmed the "Keep it for mixed-family
  fits" addendum. Bottom line now: *"drop `unique()` for pure
  binary fits."*
- Lines 170–187 (entire `### Mixed-family fits` section):
  removed. Forward-looking M1 material.
- Line 189 heading: `### How extract_Sigma() handles non-Gaussian
  and mixed-family fits` → `### How extract_Sigma() handles
  non-Gaussian fits`. The per-family link-residual table (table
  remains; M0 covered machinery, MIX-09 covered) applies to
  single-family non-Gaussian and mixed-family alike — heading
  framing simplified.
- Lines 211–215 (trailing paragraph): generalised from
  *"For mixed-family fits, each trait gets the residual implied
  by its own family"* to *"Each trait gets the residual implied
  by its family"*. Added a one-paragraph honest-scope marker
  pointing at validation-debt MIX-03..MIX-08 for readers who
  want to know where mixed-family extractor rigour will land
  (M1 milestone).

### `cross-package-validation.Rmd`

- Title (line 2) + VignetteIndexEntry (line 8): drop
  *", and queued comparators"*. Article now describes the live
  set only.
- Opening paragraph: replaced the simulation-recovery cross-ref
  (orphan since PR-0C.PULL) with a brief Phase-5.5 scope-boundary
  statement.
- Validation matrix legend: dropped the `⏳ queued` bullet (no
  longer relevant).
- Validation matrix table: dropped 5 queued rows (MCMCglmm /
  galamm × 2 / sdmTMB / Hmsc). 5 live rows remain
  (glmmTMB `rr()` + `propto()` + `equalto()` + `diag()`; gllvm
  `num.lv`).
- Removed entire `## Queued comparators` section (42 lines).
- Rewrote See also: dropped the orphan simulation-recovery link;
  dropped a pre-existing broken link to a non-existent
  `spde-vs-glmmTMB.html`; the surviving 2-bullet list points at
  `phylogenetic-gllvm.html` (validated against `glmmTMB::propto`)
  and `profile-likelihood-ci.html`.
- References: removed Anderson 2025 (sdmTMB), Hadfield 2010
  (MCMCglmm), Hadfield & Nakagawa 2010 (sparse-$A^{-1}$),
  Tikhonov 2020 (Hmsc) — all four cited only by the removed
  queued section. Kept McGillycuddy 2025 (glmmTMB `rr()`), Niku
  2019 (gllvm), Sørensen 2023 (galamm — cited in the surviving
  *"Why gllvmTMB adds value over gllvm and galamm"* section).

## 3. Files Changed

```
Modified:
  vignettes/articles/joint-sdm.Rmd                  (4 edits; ~18 lines net deletion)
  vignettes/articles/cross-package-validation.Rmd   (5 edits; ~70 lines net deletion)

Added:
  docs/dev-log/after-task/2026-05-16-phase0c-trim.md   (this file)
```

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found.
- Section-heading audit on both articles (`grep "^## "`)
  confirms intact structure.
- Orphan-reference audit: only surviving references to
  `MCMCglmm` / `Hmsc` / `sdmTMB` are in the Phase-5.5 scope-
  boundary paragraph in `cross-package-validation.Rmd` (the
  intentional one). No surviving references to
  `simulation-recovery.html` or `spde-vs-glmmTMB.html` in the
  trimmed file.
- 3-OS CI not yet run; this PR touches no R/ source.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **Rule 1** (would have failed before fix): the broken
  cross-link to `simulation-recovery.html` survived PR-0C.PULL
  because the pre-publish audit there didn't sweep peer
  articles for cross-refs to the pulled file. This PR fixes
  it by removing the cross-ref. Lesson logged in §8.
- **Rule 2** (boundary): N/A (no new test files).
- **Rule 3** (feature combination): N/A (no new functionality).

The validation-debt register entries cited in the trimmed
articles (MIX-03..MIX-08, MET-01..MET-04) are already covered
by their respective test files; no new tests needed.

## 6. Consistency Audit

Stale-wording rg sweep on the PR diff:

- `rg "queued comparators" vignettes` — clean after trim (no
  surviving references in vignettes).
- `rg "simulation-recovery.html|spde-vs-glmmTMB.html" vignettes`
  — clean (both broken cross-refs removed).
- `rg "S_B\\b|S_W\\b" .` — clean.
- `rg "trait\\s*=\\s*\"trait\"" vignettes` — clean.

Convention-Change Cascade (AGENTS.md Rule #10): the trim
removes article surface; no function ↔ help-file pair affected;
no `@export` change; no NAMESPACE diff. `_pkgdown.yml`
reference index unaffected. The cross-link cleanup in this PR
*is* a cascade-fix for the article-pull that PR-0C.PULL should
have caught — see §8.

## 7. Roadmap Tick

- `ROADMAP.md` Phase 0C "transition cleanup" slice — TRIM PR
  (second of six).
- Validation-debt register: no status change; existing
  `partial` rows (MIX-03..MIX-08) are now correctly framed in
  the article surface (forward-looking, not over-claimed).

## 8. What Did Not Go Smoothly

- **Cascade gap from PR-0C.PULL**. PR #143 moved
  `simulation-recovery.Rmd` to `dev/workshop-articles/` but the
  pre-publish audit there didn't sweep peer articles for
  cross-refs to the pulled file. The orphan link in
  `cross-package-validation.Rmd` opening + See-also surfaced
  here and got fixed in the same PR (which is fine — but the
  catch should have been pre-merge on #143). Lesson: the
  Rose pre-publish audit checklist should add a *"if this PR
  removes or moves an article, grep all surviving articles
  for cross-refs to the removed slug"* step.
- **Pre-existing broken link**: `spde-vs-glmmTMB.html` was
  referenced in See-also but the article never existed
  (per `ls vignettes/articles/`). Predates this PR; fixed
  while in the area. Caught by section audit, not by
  `pkgdown::check_pkgdown()` (which checks vignette config,
  not free-form markdown links in body content).

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Rose** (audit / pre-publish): the trim follows the same
overpromise-removal discipline as PR-0C.PULL but operates on
article *sections* rather than whole files. Process lesson —
pre-publish audit on a PR that REMOVES an article should
include a cross-reference sweep across the surviving article
surface; the cascade-fix in this PR proves the gap. Adding
to the next rose-pre-publish-audit skill upgrade (Phase 0C
closeout).

**Pat** (applied PhD user): the trimmed articles now read as
*"this is what gllvmTMB has validated end-to-end"* rather than
*"this is what gllvmTMB will eventually do"*. The
cross-package-validation matrix in particular is much sharper
— 5 live rows, no inflation by 5 queued ones. The Phase-5.5
scope statement in the opening paragraph is the right level of
honesty for a 0.2.0 release: "more comparators ship later, in
their own article".

**Boole** (formula / API): the `family = list(...)` engine
syntax remains documented (in the Setup-style references
elsewhere) but no longer has a dedicated article section
promising mixed-family extractor rigour. The MIX-03..MIX-08
restoration on M1 close will re-introduce mixed-family as a
documented surface, with validated extractors backing the
claims.

**Fisher** (inference framing): the cross-package agreement
article keeps its inference-completeness angle (the
"Why gllvmTMB adds value over gllvm and galamm" section is
intact and now reads cleanly without the Phase-5.5 detour).
The 3-method confint surface remains the package's headline
inference differentiator.

**Ada** (orchestration): second of six Phase 0C PRs. After
this lands, next is **PR-0C.PREVIEW** — add Preview banners to
5 articles (functional-biogeography, ordinal-probit,
lambda-constraint, profile-likelihood-ci,
covariance-correlation). Lighter-weight than PULL/TRIM, but
needs careful banner wording that points at the right
milestone (M1 / M2 / M3 / post-CRAN).

## 10. Known Limitations and Next Actions

- **PR-0C.PREVIEW** is next (5 banners; see Ada paragraph
  above).
- **Restoration roadmap** for trimmed content:
  - `joint-sdm.Rmd` Mixed-family section → restored as a
    re-authored worked example on M1 close (mixed-family
    extractor rigour walks MIX-03..MIX-08 to `covered`).
  - `cross-package-validation.Rmd` Queued comparators →
    restored as a new article `cross-package-agreement-runs.Rmd`
    after Phase 5.5 external validation sprint.
- **rose-pre-publish-audit skill upgrade** (deferred per
  maintainer 2026-05-16): now needs to add the
  *"removed-article cross-reference sweep"* discipline lesson
  from §8.
