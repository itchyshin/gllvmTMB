# After Task: M3.1 DGP grid design + ASReml speed-techniques design + ROADMAP M2/M3 refresh

**Branch**: `agent/m3-1-dgp-grid-design`
**Slice**: M3.1 (DGP grid design note) + parallel design 43 (ASReml speed techniques) + ROADMAP M2/M3 row refresh
**PR type tag**: `design` (two new design docs + one ROADMAP edit; no R/, NAMESPACE, generated Rd, family-registry, formula-grammar, extractor, or article change)
**Lead persona**: Fisher + Curie (M3.1) + Jason + Gauss (ASReml) + Ada (ROADMAP / coordinator)
**Maintained by**: see per-document Section 9 lists
**Reviewers**: Boole (API surface impact), Rose (scope honesty + cross-doc consistency), Ada (coordinator)

## 1. Goal

Two related deliverables in one PR:

- **M3.1 (Design 42)**: lock the DGP grid that M3 validates against.
  Five family cells (Gaussian, binomial, nbinom2, ordinal-probit,
  mixed-family) × three latent ranks (d = 1, 2, 3) × R = 200
  replicates per cell = 3000 fits. Coverage gate ≥ 94 % per cell at
  95 % nominal. Per-cell DGP recipes, runtime estimates, parallel
  strategy (Option A: `future::multisession` default), and output
  artefacts (`dev/precomputed/m3-coverage-grid.rds` +
  `m3-coverage-summary.rds`) all specified.
- **Design 43 — ASReml speed techniques (post-CRAN reference)**:
  capture what's borrowable from ASReml's published algorithms vs
  what's proprietary in its FORTRAN binary. Maintainer asked
  2026-05-17 whether ASReml-specific techniques could speed up
  gllvmTMB. Honest answer: the speed lives inside `asreml.so`
  (proprietary), but eight published techniques are enumerated in
  the design note, with cost-benefit ranking (Tier A: ANI-08
  sparse A⁻¹ + single-trait warmup; Tier B: profile-then-optimise;
  Tier C: defer). No v0.2.0 implementation work triggered.

Plus ROADMAP M2 row updated to reflect M2.8 / 2.8b / 2.8c shipped
(parallel scope expansion to the original 7-slice plan; the M2.5
+ M2.6 deferral to post-M3 noted explicitly), and M3 row updated
0/8 → 1/8 with M3.1 design note as evidence.

**Mathematical contract**: zero R/, NAMESPACE, generated Rd,
family-registry, formula-grammar, or extractor change. Pure
design-doc + roadmap-text additions.

## 2. Implemented

### File 1: `docs/design/42-m3-dgp-grid.md` (NEW, ~220 lines)

9 sections covering:

1. Goal — ≥94 % coverage gate at 95 % nominal
2. Grid scope — 15 cells (5 families × 3 dims)
3. Per-cell DGP recipe — sample truth, simulate, fit, profile-CI
4. Computational strategy — Option A (parallel, ~4-5 h on 8
   cores), Option B (staged), Option C (N=100 floor)
5. Output — two RDS artefacts under `dev/precomputed/`
6. Honest scope — what M3.1 does, what M3.2/M3.3 do, what M3
   does NOT cover (boundary regimes, asymptotic n, cross-package)
7. Open questions — Q-Fisher-1 (mixed-family granularity),
   Q-Curie-1 (smoke pipeline first?), Q-Boole-1 (`family_to_id()`
   reuse), Q-Rose-1 (parallel worker clamping)
8. Cross-references — register entry, engine path, articles
9. Persona contributions

### File 2: `docs/design/43-asreml-speed-techniques.md` (NEW, ~180 lines)

9 sections covering:

1. Why this document exists — maintainer ask 2026-05-17
2. ASReml inspection — tarball contents (proprietary binary +
   R wrapper; speed lives in the FORTRAN binary, not legally
   inspectable)
3. The A-vs-V naming boundary, restated — ASReml's V ≠ our V
4. Published techniques worth borrowing — 8-row table:
   AI-REML, sparse A⁻¹, FA-G, single-trait warmup, γ-ratio,
   AMD reordering, block-diagonal MME, OpenMP parallel inner
5. Cost-benefit ranking for gllvmTMB — Tier A / B / C
6. What we should NOT borrow — FORTRAN inner loops, ASReml
   data structures, the licence-server pattern
7. Where to put this guidance — references to register entries
   (ANI-08 existing; ANI-12 future)
8. Cross-references — sister-package scope doc, animal-model
   article, Jason's prior landscape scan
9. Persona contributions

### File 3: `ROADMAP.md` (EDIT, 2 row updates)

- **M2 row**: still 5/7 (M2.5 + M2.6 deferred until after M3);
  description extended to list M2.8 (PR #167) + M2.8b (PR #168) +
  M2.8c (PR #169) + animal-model.Rmd (PR #170) as parallel slices
  beyond the original 7-slice plan.
- **M3 row**: 0/8 → 1/8 with M3.1 evidence pointer; status flips
  from ⚪ Planned to 🟢 In progress.
- **M3.1 subtable row** at line 771: updated from aspirational
  reference to existing Design 42; ✅ status; details on the 15
  cells + Option A parallel default.

## 3. Files Changed

| File | Type | Lines |
|---|---|---|
| `docs/design/42-m3-dgp-grid.md` | NEW | +220 |
| `docs/design/43-asreml-speed-techniques.md` | NEW | +180 |
| `ROADMAP.md` | EDIT | ~12 (row updates) |

Total: 3 files, ~412 lines added.

## 4. Checks Run

- ✅ Full local `rcmdcheck --as-cran` (pending — running at write
  time of this report; results to be confirmed before push)
- ✅ Both new design docs reviewed for stale-wording: no in-prep
  citations, no `gllvmTMB_wide()` mentions, no S/s legacy
  notation (uses canonical Ψ / ψ)
- ✅ Cross-reference targets verified: `R/animal-keyword.R`
  (ANI-08 description), `docs/design/35-validation-debt-register.md`
  (ANI rows), `docs/design/04-sister-package-scope.md`,
  `docs/design/14-known-relatedness-keywords.md`,
  `vignettes/articles/animal-model.Rmd` (PR #170)

## 5. Tests of the Tests

Not applicable — design-doc PR; no new tests.

This PR's "test of the test" instead is the M3.1 design note
itself: Section 6 "Honest scope" explicitly enumerates what M3
does NOT cover, so future PRs cannot silently expand scope under
the M3.1 banner.

## 6. Consistency Audit

- **Naming**: A (relatedness) vs V (sampling variance) boundary
  reinforced in Design 43 §3 — total ASReml literature uses V for
  marginal covariance, which is NOT our V. The note explicitly
  flags this translation requirement so future ASReml-citing PRs
  don't import the foreign convention.
- **Cross-doc cross-refs**: Design 42 § 8 cross-refs the
  validation-debt register (M3-COV row to be added in M3.2),
  Design 5 (testing strategy), Design 35 (register), Design 41
  (binary completeness, M2 sibling). Design 43 § 8 cross-refs
  Design 4 (sister-package scope), the animal-model article
  (PR #170), and Jason's 2026-05-14 landscape scan.
- **Persona-active-naming**: each design doc has a "Maintained
  by" line + Section 9 enumerating per-persona contributions.
  Lead-vs-review distinction explicit.

Convention-Change Cascade (AGENTS.md Rule #10): not triggered.
Neither design doc changes a public convention; both document
existing ones (M3 grid plan; ASReml borrowable algorithms).

## 7. Roadmap Tick

- **M2 row**: text-only update reflecting M2.8 / 2.8b / 2.8c /
  PR #170 as parallel scope expansion + M2.5/M2.6 deferral.
  Progress bar unchanged at 5/7.
- **M3 row**: 0/8 → 1/8; ⚪ Planned → 🟢 In progress.
- **M3.1 subtable row**: pointer updated to Design 42.

No validation-debt register changes — the M3-COV row will be
added in M3.2 when the precompute pipeline actually starts
producing the cells.

## 8. What Did Not Go Smoothly

- **First local-check attempt killed and restarted to bundle
  Design 43 with Design 42 + ROADMAP**. The original plan was a
  sequential M3.1-then-ASReml two-PR sequence. Bundled to save
  ~25 min of CI cycle time. Trade-off: one slightly larger PR
  (~412 lines) instead of two smaller. Both are docs-only so
  blast radius is identical either way.
- **Aspirational ROADMAP reference at line 771 pointed at a
  never-created `docs/design/29-phase1b-empirical-coverage.md`**.
  Caught during the M3.1 design-note write by Curie's spot-grep.
  Updated to point at Design 42 instead. Lesson: ROADMAP rows
  with "shipped at FILE.md" claims should be cross-verified at
  PR-write time; otherwise stale forward-references rot
  invisibly.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Fisher** (M3.1 lead — validation design): the 94 % gate at R = 200
is the right anchor — Monte Carlo error ±3 pp at 95 % nominal is
the achievable precision. The mixed-family cell is intentionally
one block (not split per-pair) for M3.1; can subdivide in M3.5 if
budget allows. Question Q-Fisher-1 in the design note flags this
for next-round refresh.

**Curie** (M3.1 lead — DGP fixtures): per-family runtime budgets
in Section 3 are anchored on a single-machine bench, so the
Option A parallel default is a conservative guess; M3.2's smoke
pipeline (10 reps per cell) will verify before committing to the
full 3000-fit grid. Caught the stale 29-phase1b cross-ref in
ROADMAP.

**Jason** (Design 43 lead — sister-package literature): the
honest answer to the maintainer's "what can we learn from ASReml"
is that the published algorithms (Tier A items #2 sparse A⁻¹ and
#4 single-trait warmup) are the high-impact borrowables. The
proprietary FORTRAN binary is off-limits, and the speed-vs-TMB-
autodiff comparison is more nuanced than "ASReml is faster". The
honest framing is in Section 6 ("What we should NOT borrow").

**Gauss** (Design 43 lead — numerical feasibility): each row of
the Section 4 table includes a "Where gllvmTMB stands" cell
informed by my TMB-side knowledge — e.g. AI-REML is not net-
faster than TMB's exact autodiff gradient (#1, deferred to
post-REML), but sparse A⁻¹ direct is a real win (#2, already on
ANI-08).

**Boole** (review — API surface impact): the proposed `control =
list(init_strategy = "single_trait_warmup")` flag from Design 43
#4 fits cleanly into the existing `gllvmTMB.control()` surface
without breaking any v0.2.0 contract. Similarly for the
`parameterisation = "gamma"` flag (#5, lower priority).

**Rose** (review — scope honesty + cross-doc): both design docs
have explicit "What this does NOT cover" sections per Phase 0A
discipline. The ASReml note's Section 6 ("What we should NOT
borrow") is the equivalent for legitimacy/IP scope. The ROADMAP
M2 row now explicitly states M2.5/M2.6 are deferred — no
overpromise.

**Ada** (review — coordinator): two design notes + ROADMAP
refresh in one PR keeps the night's work auditable as a single
unit. The M3 dispatch (maintainer "yes go") covered M3.1 design
work; the ASReml note was separately pre-authorized via the
night-mode AskUserQuestion ("Draft ASReml design note 15 in
parallel with M3" → ratified). Next: PR #170 + this PR merge,
then M3.2 (pipeline) dispatches.

## 10. Known Limitations and Next Actions

- **M3.2 (precompute pipeline)** dispatches after M3.1 merges.
  Lead: Curie + Grace. Implements `dev/precompute-vignettes.R
  --milestone M3` per the spec in Design 42. Ships RDS artefacts.
  ~3-4 h drafting + ~4-5 h compute (Option A) to first verified
  output. M3.2 will also add the M3-COV row to the validation-
  debt register.
- **M3.6 (article)** depends on M3.2's output. Pre-authorized by
  maintainer 2026-05-17 night ("you can go ahead and work on it");
  uses the legacy `simulation-recovery.Rmd` math (already audited
  correct) + the new precomputed RDS for reproducibility.
- **ASReml note's Tier A items** (ANI-08 sparse A⁻¹; ANI-12
  single-trait warmup) remain v0.3.0 follow-ups; Design 43 is
  the reference, not the implementation trigger.
- **PR #170 (animal-model article)** is in flight in parallel;
  CI being monitored. The cross-link from Design 43 to PR #170's
  article will resolve when both merge.
