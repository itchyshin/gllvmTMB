# Phase 0C rewrite-prep handoff — `psychometrics-irt.Rmd` (M2.5) + `choose-your-model.Rmd` (Phase 1f)

**Date**: 2026-05-16
**Author**: Pat (decision tree + rewrite contract) + Boole (`lambda_constraint` binary IRT requirements) + Fisher (statistical-inference framing)
**Reviewers**: Rose (overpromise-removal alignment) + Darwin (audience framing) + Ada (close gate)

This document is the handoff contract for two articles that are
**slated for rewrite, not incremental cleanup**: they currently
describe machinery that will look fundamentally different once the
backing milestones close, so an in-place trim or banner is not
enough — the article has to be re-authored against validated
machinery. This file captures what the future re-author needs to
know.

It complements the validation-debt register
(`docs/design/35-validation-debt-register.md`), the Phase 0C
article triage (`2026-05-16-phase0c-article-triage.md`), and the
Nakagawa et al. paper-findings note
(`2026-05-16-phase0c-nakagawa-paper-notes.md`).

## 1. `psychometrics-irt.Rmd` → re-author in M2.5

### What the current article does

Confirmatory factor analysis (CFA) with mixed-response items
(Likert as Gaussian + binary). Uses `lambda_constraint` to pin
specific entries of $\boldsymbol{\Lambda}$ at hypothesised
values; treats the unpinned entries as free MLE targets.

### Why a rewrite (not a trim)

The current article exercises **binary IRT** with
`lambda_constraint`. The relevant validation-debt rows:

- **LAM-01** (`lambda_constraint` parser + map machinery,
  Gaussian) — `covered`.
- **LAM-02** (`lambda_constraint` deep validation, Gaussian) —
  `covered` (post-PR-0B.3 row #18 walk).
- **LAM-03** (`lambda_constraint` deep validation, binary IRT
  at scale) — `partial`.

Until **M2.3** validates LAM-03 (binary IRT with
`lambda_constraint` across `n_items ∈ {10, 20, 50} × d ∈ {1, 2, 3}`
regimes, per the Phase 1 M2 plan), the binary-IRT section of
`psychometrics-irt.Rmd` describes machinery whose recovery
characteristics are not empirically established. An in-place
trim of the binary section is possible, but it would leave a
Gaussian-only CFA article — which is closer to a fresh write
than a "preview" version of the existing one. The cleaner
discipline is: PREVIEW-banner the current article (done in
PR-0C.REWRITE-PREP), then re-author in M2.5 once the
machinery is validated.

### M2.5 rewrite contract

The re-authored `psychometrics-irt.Rmd` should:

1. **Use validated machinery only.** Every fit in the article
   uses `family = binomial(probit)` and / or
   `family = ordinal_probit()` items with
   `lambda_constraint = list(B = M)` pinning. The M2.3
   validation run (which lives in `tests/testthat/test-lambda-constraint-binary.R`
   or equivalent, per the M2.3 milestone) is the empirical
   backing for every claim the article makes about parameter
   recovery.
2. **Audit-2 A1 "Stay Laplacian" pedagogy note.** Per the
   external audit response 2026-05-15, the article should
   explicitly note that `gllvmTMB`'s Laplace approximation is
   the production inference path, and that adaptive Gauss-
   Hermite quadrature (AGHQ) is post-CRAN work. Readers
   coming from `mirt` (which uses AGHQ for low-d binary IRT)
   should know what to expect. Cross-link to the
   AGHQ-vs-Laplace background once it lives somewhere.
3. **Cross-check with `mirt`.** Include one live agreement run
   against `mirt::mirt()` on a small fixture (e.g. 10 items,
   3 factors, n = 200) to show parameter agreement within
   identifiability rotation. The `cross-package-validation.Rmd`
   live-comparison pattern is the template.
4. **Confirmatory loadings vs exploratory loadings.** The
   article should clearly distinguish the two regimes:
   exploratory factor analysis (no `lambda_constraint`,
   rotation-variant, suitable for `rotate_loadings()`); CFA
   (pinned `lambda_constraint`, identifies a unique
   $\boldsymbol{\Lambda}$ subject to scale + sign).
5. **Mixed-response.** The Likert (Gaussian) + binary (probit)
   per-row family list is M2.5 work, NOT M2.3 — `family = list(...)`
   on mixed-family fits with `lambda_constraint` requires
   MIX-03..MIX-08 (M1 mixed-family extractor rigour) AND
   LAM-03 (M2.3 binary IRT) AND a separate validation that
   `lambda_constraint` interacts correctly with per-row family
   dispatch. The M2.5 article assumes M1 + M2.3 have closed
   and adds this final validation as part of its rewrite.

### Sequencing dependencies

M1 close → M2.3 close → M2.5 rewrite of `psychometrics-irt.Rmd`.
Until then, the current article ships with the Preview banner
added in PR-0C.REWRITE-PREP. The banner explicitly names M2.5 as
the rewrite milestone.

## 2. `choose-your-model.Rmd` → re-author in Phase 1f

### What the current article does

A decision-tree article: five questions about the user's data,
each routing them to one of the worked examples
(`morphometrics`, `joint-sdm`, `behavioural-syndromes`,
`phylogenetic-gllvm`, `functional-biogeography`,
`psychometrics-irt`, `stacked-trait-gllvm`,
`ordinal-probit`, etc.).

### Why a rewrite (not a trim)

The decision tree branches to articles whose backing machinery
is partly `partial` in the validation-debt register. Some
branches in particular:

- "Mixed-family fits" → previously routed to `mixed-response.Rmd`
  (PULLED in PR-0C.PULL); the branch currently dead-ends.
- "Reproducible simulation recovery" → previously routed to
  `simulation-recovery.Rmd` (PULLED in PR-0C.PULL); the branch
  currently dead-ends.
- "Confirmatory factor analysis" → routes to
  `psychometrics-irt.Rmd`, which is Preview-banner + slated for
  M2.5 rewrite.
- "Joint-SDM with mixed-family responses" → previously routed to
  the `### Mixed-family fits` section of `joint-sdm.Rmd`
  (TRIMMED in PR-0C.TRIM); the branch terminates in a thinner
  binary-only article.
- "Capstone six-piece kitchen-sink fit" → routes to
  `functional-biogeography.Rmd`, which is Preview-banner + M3
  rewrite (composite validation gate).

A surgical fix would patch each dead-ending branch one at a
time — which is fragile (every Phase 0C cleanup, M1/M2/M3
close, and PR-0C.PULL/TRIM/PREVIEW changes the branch
destinations). The cleaner discipline is: PREVIEW-banner the
current article (done in PR-0C.REWRITE-PREP), then re-author in
Phase 1f once the package's article surface stabilises.

### Phase 1f rewrite contract

The re-authored `choose-your-model.Rmd` should:

1. **Branch only to articles whose machinery is `covered`.**
   Every branch's destination article has a fully-validated
   `covered` status in the validation-debt register at the
   time of Phase 1f rewrite. Specifically:
   - Mixed-family branch → new `mixed-family-extractors.Rmd`
     (M1 close deliverable).
   - Simulation-recovery branch → new
     `simulation-recovery-validated.Rmd` (M3 close deliverable).
   - CFA / IRT branch → re-authored
     `psychometrics-irt.Rmd` (M2.5 close deliverable).
   - Binary JSDM branch → trimmed `joint-sdm.Rmd` (already
     post-TRIM).
   - Capstone composite branch → re-authored
     `functional-biogeography.Rmd` (M3 close deliverable).
2. **Use the data-shape flowchart as the first decision.**
   `data-shape-flowchart.Rmd` (Pat's pedagogy article) is the
   foundation for the rewrite. The decision tree should start
   from data shape ("how is your data organised?") not from
   machinery ("which keyword do you want?").
3. **Apply audit-1 R8 "Capability boundary statement" template.**
   Every branch ends with a one-line statement of what the
   destination article validates and what its boundaries are.
4. **Cross-reference the validation-debt register.** At the
   end of the article, include a "What's in 0.2.0 vs what's
   coming" table referencing the validation-debt register
   row-by-row.

### Sequencing dependencies

M1 + M2 + M3 close → Phase 1f rewrite. Until then, the current
article ships with the Preview banner added in PR-0C.REWRITE-PREP.

## 3. Why these two articles are different from PR-0C.PREVIEW

PR-0C.PREVIEW added banners to 5 articles whose body content is
**internally correct** but whose claims need a one-paragraph
honest-scope marker so readers don't over-extrapolate:

- `functional-biogeography.Rmd` — each component covered; only
  the composite is M3 work.
- `ordinal-probit.Rmd` — family exists; full per-cell
  validation is M2 work.
- `lambda-constraint.Rmd` — Gaussian path covered; binary IRT
  is M2.3.
- `profile-likelihood-ci.Rmd` — Gaussian validated; mixed-family
  is M3.
- `covariance-correlation.Rmd` — Gaussian validated; mixed-family
  `extract_correlations()` is M1.

For those 5, the article body stands as-is after the banner.
The banner narrows reader expectation; no rewrite is implied.

For `psychometrics-irt.Rmd` and `choose-your-model.Rmd`, the
banner narrows reader expectation **AND** signals that the
article will be substantially re-authored at a future milestone.
The body cannot stand as-is forever: it either ages out (decision
tree branches dead-end as articles get pulled / re-authored) or
out-promises (binary IRT recovery characteristics in
`psychometrics-irt.Rmd`).

The "Preview — slated for re-authoring in <Mn>" wording is
intentional. Pat's reader UX framing: the reader sees one of
two banner shapes:

- **Preview — \<X\> validation is \<Mn\> milestone work.**
  (5 PREVIEW-PR articles.) Article body OK now; will get
  scope-expanded after Mn.
- **Preview — slated for re-authoring in \<Mn\> once \<X\> is
  validated.** (2 REWRITE-PREP articles.) Article body
  fundamentally changes after Mn; treat as preview.

The two shapes are deliberately distinct so a reader can tell
whether to trust the current body (the first shape) or treat it
as preview pedagogy that will be re-thought (the second shape).

## 4. Cross-references

- `docs/design/00-vision.md` — function-first sequencing; "What
  we will NOT do" rule #2 (Pat + Rose review BEFORE edits).
- `docs/design/35-validation-debt-register.md` — row-level
  status that the milestone walks are pegged to.
- `docs/dev-log/audits/2026-05-16-phase0c-article-triage.md` —
  the triage that flagged these two articles as REWRITE-LATE.
- `docs/dev-log/audits/2026-05-16-phase0c-nakagawa-paper-notes.md`
  — the Nakagawa et al. paper findings that informed the article
  triage.
- `docs/dev-log/decisions.md` 2026-05-16 item 9 — Phase 0A /
  0B / 0C sequencing.

## 5. Open questions

None. The rewrite contracts above are concrete enough that the
M2.5 and Phase 1f re-authors can start from this doc as their
brief.
