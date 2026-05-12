# Shannon Audit & Dispatch Queue: Legacy Co-opt / Adapt / Archive Map

**Trigger**: Codex posted a read-only "legacy excavation -> co-opt / adapt /
archive" map as a comment on PR #35 (the just-merged Shannon audit) on
2026-05-12 ~10:56 MT (link below). This audit translates Codex's findings
into a sequenced dispatch queue with role assignments and prerequisites,
matching the project's "Claude proposes / Codex implements" rhythm.

**Codex's source map**:
<https://github.com/itchyshin/gllvmTMB/issues/35#issuecomment-* (PR #35 comments)>

## Verdict on the map: agree with Codex's WARN

Codex flagged **WARN, not FAIL** because:

- the current main checkout (`codex/long-wide-example-sweep` local branch)
  has the long/wide reader-facing sweep dirty;
- `air-format` is failing advisory (expected -- the source has not been
  initial-reformatted yet);
- R-CMD-check on PR #35 was green pre-merge;
- the maintainer must not interleave a legacy-port edit into the
  long/wide branch.

**This audit takes the same line**: any legacy port begins on a fresh
branch, AFTER `codex/long-wide-example-sweep` either merges or is
explicitly parked.

## What is already co-opted (no further action)

Codex confirmed the current repo already has the byte-identical core
of the most valuable legacy machinery. Recorded here so the maintainer
can use this as the definitive list when reviewing legacy:

- **Two-U engine**: `R/fit-multi.R:335` carries
  `phylo_latent + phylo_unique -> phylo_rr + phylo_diag`.
- **Two-U cross-check extractor**: `R/extract-two-U-cross-check.R` is
  byte-identical to legacy.
- **Two-U test surface**: `tests/testthat/test-phylo-two-U.R`,
  `test-two-U-cross-check.R`, `test-pic-mom.R` are byte-identical to
  legacy.
- **Reference-support layer**: mixed-family dispatch, ordinal-probit
  family, profile-likelihood CIs, Fisher-z correlation CIs, bootstrap
  Sigma, the canonical extractor set, most family recovery tests.
- **Wide-format API (the `traits()` route)**: compact RHS expansion,
  tidyselect support, NA-cell drops, mixed-family pass-through,
  weights routing -- all in current `R/traits-keyword.R` and
  `docs/design/02-data-shape-and-weights.md`. The legacy
  Design-08 / Pat notes are now historical UX context, not current spec.

## Dispatch queue (priority order)

Each item names the prerequisite, the lead lane, supporting roles,
and the bounded deliverable. Items 1-4 are Codex's "adapt next" lanes
ordered by my read of dependency + leverage.

### #1 -- **Phylogenetic / two-U doc-validation branch** (highest leverage)

**Prerequisite**: `codex/long-wide-example-sweep` merges or is parked.
Codex's own sequencing rule: do not mix the legacy port into the sweep.

**Lead**: Codex (implementation), Claude review.

**Supporting roles**:
- **Noether + Gauss**: math & TMB mapping review
  (`Lambda_phy`, `S_phy`, `Lambda_non`, `S_non`, `q_sp`,
  `phylo_diag`). Catch any drift between legacy notation and
  current source.
- **Curie**: identifiability simulation recovery. Reuse legacy
  `dev/sim-two-U-identifiability.R`, `dev/two-U-analysis.R`, and
  `dev/design/11-identifiability-regime-map.md` as scaffolding;
  rewrite for current package vocabulary (`unit` / `trait` /
  `traits(...)` / current extractor names).
- **Boole**: formula grammar check (the two-U pattern uses
  `latent + unique` paired and `phylo_latent + phylo_unique`
  paired -- verify the syntax stays inside the 3 x 5 grid as
  documented in `AGENTS.md` and `CLAUDE.md`).
- **Pat / Darwin**: applied-user clarity. Does a new applied
  reader (ecology / evolution PhD) understand the model from the
  rewritten article? Two-U is famously confusing; the article
  needs to explain *which* trait covariance is phylogenetic vs
  non-phylogenetic without burying the reader in math.
- **Rose**: cross-file consistency between the new article, the
  design doc, the `extract-two-U-cross-check.R` roxygen, and the
  pkgdown reference. The current repo already has the *machinery*;
  the article rewrite must say so honestly and test it visibly.

**Bounded deliverable**:
1. A new article `vignettes/articles/phylogenetic-gllvm.Rmd` (or
   reuse the slug from legacy) that follows the long+wide pattern,
   uses `unit` / `trait`, and runs against current `traits()` /
   `gllvmTMB_wide()`.
2. A new article `vignettes/articles/two-U-phylogeny.Rmd` adapted
   from legacy, using current vocabulary.
3. A new design note `docs/design/03-phylogenetic-gllvm.md`
   adapted from legacy `dev/design/03-phylogenetic-gllvm-rewrite.md`,
   updated to match current grammar and naming.
4. A `tests/testthat/test-phylo-two-U-recovery.R` (or extend
   existing) running a focused simulation recovery on the current
   code path, not the legacy one.
5. After-task report at branch start, drmTMB-style with
   Mathematical Contract, Consistency Audit, Tests Of The Tests
   (linking what each new test would catch), and Team Learning
   by role per the protocol.

**Source files to port (adapt, not dump)**:
- `vignettes/articles/phylogenetic-gllvm.Rmd` (legacy)
- `vignettes/articles/two-U-phylogeny.Rmd` (legacy)
- `dev/design/03-phylogenetic-gllvm-rewrite.md` (legacy)
- `dev/design/11-identifiability-regime-map.md` (legacy)
- `dev/sim-two-U-identifiability.R` (legacy)
- `dev/two-U-analysis.R` (legacy)
- `dev/two-U-rewrite-plan.md` (legacy)

**Source files to skip**:
- Legacy single-response sdmTMB inheritance (R/fit.R, R/predict.R,
  R/residuals.R, etc.) -- not the multivariate surface.
- Legacy `dev/standalone-cut-list.md` cut decisions other than
  the row that confirms two-U inheritance is gone.

### #2 -- **Reference article salvage (Tier-2 selective port)**

**Prerequisite**: #1 in progress or merged; this depends on the
public surface having the two-shape framing stable.

**Lead**: Claude (audit which articles to port and why), Codex
implements the ports.

**Bounded deliverable**:
1. A Claude audit doc enumerating each legacy reference article
   with verdict: **port to Tier-2** / **port to internal-only docs/** /
   **leave archived**. Format: one row per article.
2. After Claude's audit + maintainer approval, Codex ports each
   approved article one-PR-per-article.

**Candidate articles** (per Codex's flag, in legacy):
- `mixed-response.Rmd` -- mixed-family fits, mid-leverage Tier-2
- `response-families.Rmd` -- reference for all supported families
- `ordinal-probit.Rmd` -- ordinal-probit deep dive
- `profile-likelihood-ci.Rmd` -- profile-CI mechanics
- `lambda-constraint.Rmd` -- Lambda identifiability constraint
- `api-keyword-grid.Rmd` -- the 3 x 5 grid as a reference page

**Source files to skip**:
- Legacy Tier-3 articles (cross-package-validation, simulation-recovery
  reports, the long stacked-trait-gllvm essay) -- cross-link from a
  Tier-1/Tier-2 page if needed, do not re-publish in the navbar.

### #3 -- **Long/wide cleanup input (low-cost wording mine)**

**Prerequisite**: none; can run any time after sweep merges.

**Lead**: Claude (mine legacy Pat/Design 08 for *phrasing*, not
todo items -- the current code has fixed the substantive gaps).

**Bounded deliverable**:
- A small Claude PR that lifts useful sentences from legacy
  Pat / Design 08 into the current `docs/design/02-data-shape-and-weights.md`
  and `README.md` "Two shapes" sections. **Not** a re-introduction
  of `traits()` as a public surface (that's still issue #34
  territory).

This is the lowest-priority item; can wait until after #1 and #2
settle.

### #4 -- **Identifiability simulation recovery deep-dive** (Curie lane)

**Prerequisite**: #1 lands so the doc framing is in place; this
becomes the *validation* counterpart of #1.

**Lead**: Codex (run simulations), Curie review.

**Bounded deliverable**:
- A `dev/sim-two-U-identifiability-current.R` script (kept under
  `dev/`, not exported) that runs the legacy identifiability sims
  against the current code path. The output goes into a check-log
  entry recording the simulation outcomes -- not a public-facing
  article.

## What stays archived (record in `decisions.md` so it isn't re-litigated)

Per Codex's "Leave archived unless explicitly requested":

| Item | Reason for archive |
|---|---|
| Legacy single-response sdmTMB code (`R/fit.R`, `R/predict.R`, `R/residuals.R`, `R/dharma.R`, `R/emmeans.R`, `R/visreg.R`, `R/index.R`) | Not the multivariate surface. Belongs in `pbs-assess/sdmTMB` if a user needs it. |
| Legacy `test-1-*`, `test-2-*`, DHARMa, emmeans, forecasting, projection, cross-validation tests | Single-response test surface, irrelevant to multivariate stacked-trait. |
| PIC-MOM as a public extractor path | Keep as hidden / internal diagnostic context. `compare_dep_vs_two_U()` and `compare_indep_vs_two_U()` are the canonical user-facing checks. |
| Legacy Tier-3 articles: `cross-package-validation.Rmd`, `simulation-recovery.Rmd`, `stacked-trait-gllvm.Rmd`, `morphometric-phylogeny.Rmd` (when separate from `morphometrics.Rmd`), other long essays | Not Tier-1/Tier-2 worked examples; cross-link from focused pages if needed. |

A separate Claude PR can append these as a single `decisions.md`
entry once the maintainer ratifies this audit's recommendations.

## Suggested overall sequence

1. **Finish or park** `codex/long-wide-example-sweep`. (Codex is
   currently working there with 18 modified files; the sweep
   produces the article cleanup that PR #32 + #33 set up.)
2. **Open the two-U / phylo doc-validation branch** (item #1
   above) as the next Codex-lane bounded task.
3. **In parallel**: Claude opens the Tier-2 article-salvage audit
   doc (item #2's first deliverable).
4. **After #1 lands**: Curie identifiability sim (#4).
5. **Any time, low priority**: long/wide wording mine (#3).
6. **Issue #34** (parser sugar) remains parked unless the
   maintainer wants to revisit; not blocked or unblocked by any
   of the above.

## Shannon checklist (state at this audit's time)

| # | Check | Result |
|---|---|---|
| 1 | PR + after-task pairing | ✅ all six 2026-05-12 merges paired; Codex's sweep has its branch-start report at `2026-05-12-long-wide-reader-sweep.md` |
| 2 | Working-tree hygiene | ⚠️ Main checkout still on `codex/long-wide-example-sweep` with 18 modified files (Codex's active work, do not touch) |
| 3 | Cross-PR file overlap | ✅ This audit doc lives in `docs/dev-log/shannon-audits/`; no overlap with Codex's sweep |
| 4 | Branch / PR census | 0 open PRs at audit start (PR #35 just merged); 1 active local Codex branch unpushed |
| 5 | Rule-vs-practice drift | ✅ Codex's "do not mix legacy port into sweep" instruction is exactly the rule (collaboration stops on broad article rewrites without explicit maintainer dispatch) |
| 6 | Sequencing | ✅ Codex's queue (finish sweep first, then narrow phylo branch) respects the codified order |

**Verdict: PASS** with the WARN that Codex flagged about not mixing
lanes. This audit's dispatch queue is the maintainer-facing
translation of Codex's map.
