# After Task: PR-0C.PULL — pull 3 overpromise articles to workshop

**Branch**: `agent/phase0c-pull`
**PR type tag**: `scope` (article surface cleanup; no R/ source, no NAMESPACE, no machinery change)
**Lead persona**: Rose (overpromise-removal discipline)
**Maintained by**: Rose + Pat; reviewers: Pat (triage author), Curie (test-coverage continuity), Ada (close gate)

## 1. Goal

Remove from the published article surface three vignettes whose
claims outrun the machinery validated in Phase 0B:

- `mixed-response.Rmd` — describes mixed-family extractor
  workflows (`extract_Sigma()`, `extract_correlations()`,
  `extract_communality()`, `extract_repeatability()`) on
  `family = list(...)` fits. The engine accepts the syntax
  (`MIX-01` / `MIX-02` covered) but extractor coverage is
  Section 7 `partial` (`MIX-03` through `MIX-08`). The article
  shows full extractor outputs as if they were validated.
- `simulation-recovery.Rmd` — reports parameter-recovery
  numbers from a single precomputed run; not reproducible
  without the cached object; no R = 200 grid backing the
  per-family coverage claims. This is M3 deliverable, not M0.
- `corvidae-two-stage.Rmd` — Gaussian meta-analytical two-stage
  workflow. `MET-04` is `partial` (no live cross-check fixture).
  Maintainer 2026-05-16: defer to later as an extra check;
  Gaussian meta-analytical is not the M0 critical path.

The "pull" verb is from Phase 0C triage
(`docs/dev-log/audits/2026-05-16-phase0c-article-triage.md`):
move out of the published article surface, but keep in repo
under a parked location for future restoration.

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change.
Pure article-surface scope change.

- Three `.Rmd` files moved from `vignettes/articles/` to
  `dev/workshop-articles/` (tracked in git; excluded from the
  source tarball via `^dev$` in `.Rbuildignore`; not scanned by
  pkgdown).
- Three corresponding entries removed from `_pkgdown.yml`
  (two from "Model guides", one from "Methods and validation").
- One row in the validation-debt register (`MET-04`,
  `corvidae-two-stage`) updated to reflect the article's
  new parked location and the maintainer's deferral note.

`_workshop/` was rejected as the park location because it is
fully gitignored (`.gitignore:77` + `_workshop/README.md`
declares "nothing here ever commits"). The pulled articles
need to survive in git for future restoration; `dev/` is the
correct home (tracked + in `.Rbuildignore` + not scanned by
pkgdown).

## 3. Files Changed

```
Renamed:
  vignettes/articles/mixed-response.Rmd        → dev/workshop-articles/mixed-response.Rmd
  vignettes/articles/simulation-recovery.Rmd   → dev/workshop-articles/simulation-recovery.Rmd
  vignettes/articles/corvidae-two-stage.Rmd    → dev/workshop-articles/corvidae-two-stage.Rmd

Modified:
  _pkgdown.yml                                 (3 lines removed)
  docs/design/35-validation-debt-register.md   (MET-04 note updated)

Added:
  docs/dev-log/after-task/2026-05-16-phase0c-pull.md   (this file)
```

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found.
- `git status --short` confirms the three renames are tracked
  in their new path (`git ls-files dev/workshop-articles/`
  lists all three).
- `_pkgdown.yml` article sections render as expected (7
  Model-guides articles, 2 Methods-and-validation articles).

Note: `R CMD check` not re-run; this PR touches no R/ source
and no documentation/help-file binding. The Phase 0A close-gate
3-OS CI already validated the surrounding state.

## 5. Tests of the Tests

The 3-rule contract from
`docs/design/10-after-task-protocol.md` is satisfied by Phase
0B's existing smoke coverage, not by new tests in this PR:

- The three pulled articles' machinery rows are already covered
  by `tests/testthat/test-formula-grammar-smoke.R` (PR-0B.2),
  `test-mixed-family-extractor.R`, `test-mixed-response-sigma.R`,
  and the Phase 0B walk that closed every `claimed` row. No new
  test is needed because no machinery changed.
- The pkgdown-config change is verified by
  `pkgdown::check_pkgdown()` returning clean (rule 1: would
  have failed before the `_pkgdown.yml` line removal, as
  initially seen during this PR when the articles were parked
  inside `vignettes/_workshop/`).

## 6. Consistency Audit

Stale-wording rg sweep on the PR diff:

- `rg "in prep|in preparation" docs vignettes` — no new hits
  introduced by this PR (legitimate engine-specific in-prep
  citations elsewhere are unchanged).
- `rg "trait\\s*=\\s*\"trait\"" vignettes` — no hits in the
  surviving article surface.
- `rg "phylo\\(|gr\\(|meta\\(|block_V\\(|phylo_rr\\(" vignettes`
  — no deprecated keyword aliases appear in surviving articles.
- `rg "S_B\\b|S_W\\b" .` — no `S_B`/`S_W` legacy notation.

Convention-Change Cascade (AGENTS.md Rule #10): the rename
does not unbind any function ↔ help-file pair. `_pkgdown.yml`
reference index is unaffected. No `@export` removed.

## 7. Roadmap Tick

- `ROADMAP.md` row affected: Phase 0C "transition cleanup"
  slice. This is the first of the planned 0C execution PRs
  (PULL → TRIM → PREVIEW → REWRITE-PREP → ROADMAP → COVERAGE).
- Validation-debt register: `MET-04` note updated; no status
  change (still `partial`).

## 8. What Did Not Go Smoothly

- **First-pass park location wrong**. I initially moved articles
  to `vignettes/_workshop/articles/`, on the assumption that
  pkgdown skips leading-underscore subdirectories. It does not
  — pkgdown traverses all of `vignettes/` regardless of
  prefix, and `check_pkgdown()` failed with "3 vignettes
  missing from index". The fix was to re-park at
  `dev/workshop-articles/`, which `.Rbuildignore` and pkgdown
  both honour. Lesson: verify the exclusion mechanism before
  choosing a park location; do not assume the leading-
  underscore convention propagates from file-name to
  directory-name.
- **Initial choice of `_workshop/` was also wrong**: that
  directory at package root is fully gitignored
  (`.gitignore:77`), so the moved files would not have
  committed to the fresh repo. `git mv` will move files into
  a gitignored directory and keep them tracked in the index,
  which would have created a documentation discrepancy with
  `_workshop/README.md`'s "nothing here ever commits" claim.
  Caught and corrected before commit.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Rose** (audit / pre-publish): the pull reverses overpromise
introduced in 2026-05-15 article-port batch; the pulled articles
were the canonical examples from the 2026-05-15 audit. Process
lesson — pre-publish audit should always include a "does the
PR add articles whose machinery is `partial` / `blocked` in the
validation-debt register?" check. That check would have caught
the original overpromise at PR-time.

**Pat** (applied PhD user): the surviving article surface (7
Model guides + 4 Concepts + 2 Methods+validation) is the honest
M0 baseline. New readers will see exactly the capabilities the
package can validate. The pulled articles' restoration points
(M1 / M3 / future Gaussian meta-analytical) are documented in
the triage and the validation-debt register, so a reader who
asks "where did mixed-response go?" gets a coherent answer:
"it returns when M1 mixed-family extractor rigour is covered".

**Curie** (test fidelity): test coverage is unchanged. Every
test referenced by the pulled articles is in `tests/testthat/`
and still runs. The pull does not touch test machinery.

**Ada** (orchestration): first of the 6 planned Phase 0C
execution PRs. Next is PR-0C.TRIM (joint-sdm "Mixed-family
fits" section + cross-package-validation queued-comparator
section). After-task report templates are getting tighter for
small mechanical PRs (~150 lines vs Phase 0A's ~600), which
matches the PR-type-tag scaling rule from
`10-after-task-protocol.md`.

## 10. Known Limitations and Next Actions

- **PR-0C.TRIM** is next: remove the "Mixed-family fits"
  section from `joint-sdm.Rmd`, and the queued-comparator
  section from `cross-package-validation.Rmd`. These are
  in-article overpromise trims, not whole-article pulls.
- **PR-0C.PREVIEW** follows: preview banner on 5 articles
  (functional-biogeography, ordinal-probit, lambda-constraint,
  profile-likelihood-ci, covariance-correlation). Per
  maintainer 2026-05-16, the preview banner is the
  next-most-aggressive lever after pulls — it surfaces "this
  article will be rewritten once the machinery is validated"
  to readers without removing the article.
- **Restoration roadmap** for the three pulled articles:
  - `mixed-response.Rmd` → restore in M1 close PR (Gaussian
    completeness with random slopes; mixed-family rigour walk).
  - `simulation-recovery.Rmd` → restore in M3 close PR
    (R = 200 empirical-coverage grid).
  - `corvidae-two-stage.Rmd` → restore once a live cross-
    check fixture exists; not on the critical path; revisit
    after M3.
- **Skill upgrade deferred**: `rose-pre-publish-audit` should
  check every `@export` against `_pkgdown.yml`'s reference
  index. Deferred per maintainer 2026-05-16; will land as
  part of Phase 0C closeout.
