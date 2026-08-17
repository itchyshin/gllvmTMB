# After Task: Categorical paper alignment (Mizuno et al. 2025) and the categorical degeneracy detector

**Branch**: `claude/categorical-paper-alignment-20260817`
**Date**: `2026-08-17`
**Roles (engaged)**: `Ada (orchestration) / Pat (R-package engineering) / Rose (validation-debt + after-task QA) / Grace (statistical review of the pre-registrations)`

## 1. Goal

Two joined questions. First (**paper alignment, PA1-PA5**): map Mizuno,
Drobniak, Williams, Lagisz & Nakagawa (2025, *J. Evol. Biol.* 38:1699-1715,
doi 10.1093/jeb/voaf116) — the methods reference for phylogenetic ordinal and
nominal PGLMMs — equation by equation onto `gllvmTMB()` calls, and close the
gaps that map exposes rather than recording them as aspirational. Second
(**detector, issue #897**): `ordinal_probit()` had *no* degeneracy screen at
all (239/239 degenerate fits unflagged, where the binomial screen caught
272/272) and `multinomial()` had none either — the Design 123 campaigns had
been producing fits that converged with a positive-definite Hessian while
reporting a collapsed variance or a railed correlation, silently. Build the
screens, but set their thresholds on each family's own evidence, and report
what the calibration actually measures.

## 2. Implemented

**Paper alignment**

- **PA1** — a 20-row equation-by-equation alignment table in
  `docs/design/123-multinomial-structured-surface.md`, plus the Box-2
  cutpoint-parameterisation note (gllvmTMB follows Hadfield's fixed-first-
  cutpoint convention, i.e. MCMCglmm's, not brms's).
- **PA2** — `extract_phylo_signal()` returned **`H2 = 1.0` for every
  categorical trait and contrast** before this arc: the fixed liability
  residual never entered the denominator, so a signal the paper reports around
  0.37/0.35/0.27/0.41 read as 1. Fixed with `link_residual = c("none",
  "auto")`: `"auto"` gives `V_a/(V_a + 1)` per ordinal trait (eq 18) and
  `V_a(k)/(V_a(k) + pi^2/3)` **per multinomial contrast** (eq 19), never
  collapsed to a scalar, hand-verified to 1e-10; live MCMCglmm comparator
  0.357 vs 0.436 (band 0.15, truth 0.5). The default is unchanged and
  byte-identical to the old behaviour.
- **PA3** — the ordinal x kernel/animal engine identities are **measured**, not
  inferred: 5 cells, matched TMB objective at each other's converged parameters
  in both directions (1e-6) and matched phy-tier `extract_Sigma` (1e-4).
- **PA4** — the paper's eq 38-46 combined phylogenetic + non-phylogenetic
  species model **runs for both categorical families**. **Ordinal PASSES** all
  four component gates (medians est/true 0.77 / 0.82 / 1.04 / 0.96).
  **Multinomial FAILS its rail gate (12/20)** while its components recover
  (0.97 / 0.56 / 0.90 / 0.69) — so the admitted claim is components-only, with
  no rho claim under a competing species tier.

**Detector**

- **S0** — a structural false positive, live-confirmed and fixed: a healthy
  mixed `multinomial()` + `gaussian()` fit WARNed `near_zero_psi_unit` purely
  because the auto-Psi skip block pins each contrast pseudo-trait at
  `log(1e-6)` while the C++ still REPORTs `sd_B` for it (the free trait's sd
  was 0.312 — healthy). Predates this arc.
- **S1** — the mechanism question #897 flagged as unknown is **SETTLED:
  category-level separation, not link saturation**. 60-fit grid, 24 degenerate:
  flat-row share **exactly 0 on all 24** (the cutpoint underflow is never
  reached — saturation refuted, not merely unsupported); **24/24** dichotomised
  refits fire the existing binomial detector; the pathology is a
  **single-column runaway** (loading 44.2 against a true `max|Lambda|` 4.79).
- **Multinomial arms armed**: M1 (`collapse_floor = 1e-10`), M2 (`rail_thresh
  = 0.99`, rank-≥2 tiers only), M3 (`range_collapse_thresh = 0.02`).
- **Ordinal arms armed at 40**: O1 (`runaway_loading`) and O2
  (`extreme_magnitude`), on 315 fits across four pre-registered arms.
- **Diagonal-V replication rider (FAM-20D)** — pre-registered before results,
  **FAILS its gates, and the failure is the finding**: replication does not
  rescue the diagonal-V mode.

## 3. Files Changed

**R (behaviour)**

- `R/diagnose.R` — `.gllvmTMB_multinomial_degeneracy_row()` (M1/M2/M3),
  `.gllvmTMB_ordinal_degeneracy_row()` (O1/O2),
  `.gllvmTMB_ordinal_cutpoint_span_by_trait()`, the shared row scaffolding, the
  `near_zero_psi_unit` pinned-entry fix (S0), and the M3 engine-route fix.
- `R/extract-omega.R` — `extract_phylo_signal(link_residual = )`, the
  categorical advisory, and two typed refusals
  (`gllvmTMB_phylo_signal_ci_link_residual_unsupported`,
  `gllvmTMB_phylo_signal_no_phylo_tier`).

**Tests**

- `tests/testthat/test-sanity-categorical.R` (new, 639 lines) — both detector
  rows, both families.
- `tests/testthat/test-phylo-signal-categorical.R` (new, 369 lines) — mocked
  hand-computed cells, typed refusals, live ordinal star-tree fit, live
  one-draw multinomial wiring cell, MCMCglmm comparator.
- `tests/testthat/test-matrix-ordinal-kernel-animal.R` (new, 386 lines) — PA3's
  five cells.
- `tests/testthat/test-sanity-multi.R` — additions for the shared scaffolding
  and the S0 fix.

**Docs**

- `docs/design/123-multinomial-structured-surface.md` — the paper-alignment
  section (PA1), the PA2/PA3/PA4 outcomes, §4's diagonal-V verdict, and the new
  **§8 Detector coverage**.
- `docs/design/35-validation-debt-register.md` — FAM-14, FAM-20 root,
  FAM-20C/20D/20E/20F, DIA-08, PHY-07.
- `NEWS.md` — the H^2 defect, both armed screens with measured numbers, the S0
  fix, the M3 scope fix.
- `docs/dev-log/issue-897-closeout-draft.md` (new) — ready-to-post comment,
  **not posted**.
- `man/` — `check_gllvmTMB.Rd`, `extract_phylo_signal.Rd`, and the two new
  internal row `.Rd` files, all regenerated.

**Pre-registrations, campaigns and artifacts (dev/)**

- `dev/ordinal-degeneracy/` — `probe-criteria.md` (S1 rule, frozen at
  `e932cf37`), `probe-mechanism.R`, `run-ordinal-grid.R`,
  `campaign-ordinal-calibration.R`, `pass-criteria-ordinal.md`, `results/`.
- `dev/multinomial-structured/` — `pass-criteria-detector-mn.md` (frozen at
  `f6552ee9`), `detector-calibration-mn.R`,
  `pass-criteria-diagonal-v-replication.md` (frozen at `1925bc24`),
  `m3-scope-fix-plan.md`, `results/`.
- `dev/categorical-replication/` — `pass-criteria-pa4.md` (frozen at
  `78507518`, signed at `6db3296d`), the two DGPs, the two campaign scripts,
  `verify-admission-pa4.R`, `results/`.

**Commits (arc order)**: `120fc58c` (S0) · `98b01cda` (PA1) · `78507518` ·
`04a3af4b` (PA3) · `7e931c79` · `a50760a2` + `da3eb3f6` (PA2) · `6db3296d` ·
`e932cf37` · `f9fe7d3c` (PA4 verdicts) · `8f233231` (S2a) · `f6552ee9` ·
`b33d3b90` (S1 verdict) · `6f34568e` (S3 verdict) · `1925bc24` · `af3cb453`
(S2b) · `5e745dcd` (diagonal-V verdict) · `3e6296ac` · `1a92ab1f` · `52be4cbd`
· `fc6988c1` · `860a91c0` (M3 fix) · `2a5dbb54` (ordinal arming) · `144e369b`
(design 123) · `aa151927` (register) · `a182b43c` (NEWS).

## 3a. Decisions and Rejected Alternatives

- **Decision: no saturation arm for ordinal.** *Rationale*: the S1 probe
  measured flat-row share **exactly 0 across all 24 degenerate fits** — the
  suspected mechanism never fires. *Rejected alternative*: build the arm #897
  hypothesised anyway, "for completeness". *Confidence*: high — the refutation
  is a measurement, not an absence of evidence.
- **Decision: ordinal thresholds set on ordinal evidence (40), not inherited
  from binomial (6).** *Rationale*: at 6 the ordinal screen measures 100%
  sensitivity and **24% false positives**, reproducing the exact defect #897
  reports in binomial (25%). *Rejected alternative*: reuse binomial's number
  for consistency — that would have shipped the defect the issue asks us to
  fix. *Confidence*: high.
- **Decision: arm the ordinal arms at 40 rather than take the pre-registered
  ship-disarmed fallback.** *Rationale*: the frozen conjunction (sensitivity
  ≥ 90% **and** zero FP) was not achievable at any threshold; #897's own stated
  priority is that a screen crying wolf gets switched off, so specificity
  binds. At 40 the screen has 0.0% FP on the plain healthy arm and 0.0% on the
  adversarial transport arm while catching ~60-70%. Against 0/239 detection
  that is a strict improvement. *Rejected alternative*: ship disarmed and leave
  #897 fully open. *Confidence*: medium-high — sensitivity below the frozen
  target is a real miss and is recorded as one.
- **Decision: the multinomial FP denominator is 40, not 56.** *Rationale*: the
  s4 `re_int` cell's 20 fits emit no detector row at all (a bare `(1 | group)`
  fit has no loading tier), so they carry zero specificity information;
  counting them would inflate the denominator and understate the bound.
  *Rejected alternative*: the flattering 0/56. *Confidence*: high.
- **Decision: components-only claim for the combined multinomial model
  (PA4 Cell B).** *Rationale*: 12/20 rails against a frozen >6/20 threshold.
  *Rejected alternative*: quote the four in-band component medians as a pass.
  *Confidence*: high.
- **Decision: record the diagonal-V replication result as a FAILED gate rather
  than re-scoring it.** *Rationale*: the pre-registration was frozen at
  `1925bc24` before any results; the planted-near-zero rail criterion was
  mis-specified for a design where the correlation is undefined, and that
  interpretation is attached to the FAIL rather than replacing it. *Rejected
  alternative*: retro-fit the criterion. *Confidence*: high.
- **Decision: fit-time warnings are NOT wired for either family.**
  *Rationale*: turning a check row into an automatic warning is a behaviour
  change every existing user feels; it belongs to the maintainer, not to the
  lane that calibrated the row. *Confidence*: high.
- **Decision: binomial's own 25% FP rate is spun out, not fixed here.**
  *Rationale*: the ordinal campaign diagnoses it (the same absolute-threshold
  transport failure) but re-calibrating a shipped, load-bearing screen on
  evidence gathered for a different family would be exactly the inheritance
  error this arc refused. *Confidence*: high.

## 4. Checks Run

- `Rscript -e 'devtools::document()'` — clean; **no `man/` diff**, i.e. the
  roxygen shipped in `af3cb453`/`2a5dbb54`/`860a91c0` was already documented.
  (Three pre-existing roxygen warnings about missing `@export` tags on
  `AIC`/`BIC`/`anova.gllvmTMB_multi` in `R/aghq-report.R` are untouched by this
  arc and were present before it.)
- `Rscript -e 'devtools::test(filter = "sanity|multinomial|ordinal")'` —
  **`[ FAIL 0 | WARN 1 | SKIP 30 | PASS 617 ]`**. The single WARN is the
  pre-existing `aghq`-requested-but-not-run advisory in
  `test-multinomial-fence.R:594` (ordinary `latent()` carries a per-trait Psi,
  which makes the fit ineligible for AGHQ Stage 1a) — unrelated to this arc.
  The 30 skips are the heavy recovery/matrix cells gated behind
  `GLLVMTMB_HEAVY_TESTS=1`, and include PA3's five cells, which were run
  separately and non-skipped (below).
- Campaign runs, each against criteria frozen before the run:
  - S1 mechanism probe — 60 fits, 24 degenerate (`b33d3b90`).
  - S3 multinomial detector calibration — 128 fits, 122 conv+PD (`6f34568e`);
    M3 re-measurement, 20 seeds, after `860a91c0`.
  - S2b ordinal calibration — 315 fits, `n = 100/400`, 9.0 min on 10 cores
    (`2a5dbb54`).
  - Diagonal-V replication — 20 seeds main + 10 planted-near-zero (`5e745dcd`).
  - PA4 — 20 seeds ordinal (`n_sp = 150` x 5 reps) and 20 seeds multinomial
    (`n_sp = 300` x 5 reps), both 20/20 conv+PD (`f9fe7d3c`).
- PA3 heavy run — `GLLVMTMB_HEAVY_TESTS=1`, 5 cells, **0 fail, 0 skip**
  (`04a3af4b`).
- D-139 compliance: every campaign was time-estimated from a timing fit before
  it ran; the one estimate that would have breached 30 minutes (the ordinal
  three-`n` grid) was trimmed rather than run — see §10.

## 5. Tests of the Tests

- **Failure-before-fix, S0**: the `near_zero_psi_unit` false positive was
  reproduced on a live healthy mixed multinomial + gaussian fit *before* the
  fix (WARN with a free-trait sd of 0.312), and the same fit passes after.
- **Failure-before-fix, M3**: measured 0/3 on the labeled collapse cell and
  0/20 rows emitted before the scope fix, 3/3 and 20/20 after — the same 20
  seeds.
- **Out-of-sample, M1**: 7/7 collapse seeds flagged and 0/13 healthy flagged on
  the diagonal-V cell, which the detector had never seen during calibration.
- **Out-of-sample, M2 suppression**: 0/20 on healthy rank-1 fits where
  `|rho| = 1` holds by row proportionality — the arm's known failure mode,
  tested directly.
- **Adversarial arm**: the ordinal calibration's *transport* arm (10-30x
  per-trait scale spread) was pre-registered specifically to break an absolute
  threshold, and it did (78.6% FP at 6) — the arm earned its keep rather than
  padding the pass rate.
- **Hand-computed oracle**: PA2's mocked cells verify the H^2 arithmetic to
  1e-10 independently of any fit; the live cells and the MCMCglmm comparator
  are separate.
- **Boundary**: `K = 2` ordinal traits (no free cutpoint) return `NA` for
  `cutpoint_span` rather than dividing by zero.

## 6. Consistency Audit

- `rg "family_id == 1L" R/diagnose.R` — the binomial-only gate remains, as it
  should; the two categorical rows are separate functions, not a widened gate.
- `rg "897" docs/design/35-validation-debt-register.md docs/design/123-*.md NEWS.md`
  — the issue is cited in FAM-14, FAM-20, DIA-08, §8 and NEWS, and no surface
  still says ordinal has no detector.
- `rg "UNTESTED for the diagonal-V"` — zero hits: the caveat is closed in both
  the register and the design doc, in the same direction (negative result).
- `rg -n "disarmed" NEWS.md` — one hit,
  `multinomial_collapse_rel_thresh` (line 27), which is correct; the two
  "disarmed by default (`Inf`) pending a calibration campaign" claims that
  described the now-armed arms are gone.
- `rg "extract_phylo_signal" docs/design/35-validation-debt-register.md` —
  PHY-07 and EXT-07 both exist; the defect note is on PHY-07, and EXT-07's
  older #677 claim is untouched and still true.
- `rg -c "[Ff]it-time warning" NEWS.md docs/design/123-*.md docs/design/35-*.md`
  — 2 / 2 / 4 hits: the "not wired" statement appears on every surface that
  describes the rows (NEWS, Design 123 §8, and the register's FAM-14, FAM-20
  and DIA-08 rows).

## 7. Roadmap Tick

N/A — no ROADMAP row is scoped to the detector or the paper alignment. The
register rows (FAM-14, FAM-20/20C-F, DIA-08, PHY-07) are the ledger this arc
moves, and none of them changes *status*: this is diagnostic coverage and an
extractor fix, not a recovery-evidence promotion.

## 7a. GitHub Issue Ledger

- **#897** (`ordinal_probit` has no degeneracy detector) — the arc that answers
  it. A ready-to-post closeout comment is drafted at
  `docs/dev-log/issue-897-closeout-draft.md`; **it has not been posted**, and
  the issue is not closed by this lane. Recommended disposition: close on the
  mechanism + ordinal-screen half, and open a follow-up for the binomial
  re-calibration named below.
- **Follow-up to file (not filed by this lane)**: re-calibrate the binomial
  prevalence/loading screen's own ~25% false-positive rate. The ordinal
  campaign diagnosed the cause (an absolute threshold cannot transport across
  heterogeneous per-trait scales) but deliberately did not touch binomial's
  shipped defaults.
- No other open issue applies; no issue was closed or commented on from this
  session.

## 8. What Did Not Go Smoothly

- **M3 shipped blind and was caught only by calibration.** The arm was written
  against `Lambda_spde` and gated on it being readable — which is precisely the
  quantity the engine does *not* report on the `spatial_indep()` route the arm
  targets. It produced **no row at all** on the fits it existed for, and a
  detector that emits nothing looks exactly like a detector that finds nothing.
  Only a labeled-positive calibration cell distinguished the two.
- **A "healthy" cell contained four railed fits.** M2's apparent false
  positives on the s1b cell were true positives; refitting proved it. The
  lesson is about aggregate gates: s1b's rail rate of 4/20 *passed* its
  criteria while those four fits sat inside the arm we then labelled healthy.
  Cell-level labels are not fit-level truth.
- **A pre-registered parameter was unrunnable.** The diagonal-V rider froze
  `sd_true = c(0.8, 0)`; a zero variance makes `V` singular and the Cholesky
  fails. Substituting `c(0.8, 0.05)` was necessary and is recorded as an
  amendment rather than quietly applied.
- **The pre-registered ordinal grid did not fit the D-139 budget.** The three-`n`
  grid projected past 30 minutes, so `n = 1600` was dropped and the `n = 400`
  seed count halved. That is a real coverage hole, stated in every surface
  rather than absorbed.
- **A documentation session nearly disturbed another lane's parked work.** A
  `git stash` / `git stash pop` pair run to compare two versions of the
  register found nothing to stash (the tree was clean) and the `pop` therefore
  targeted a **pre-existing stash entry belonging to another lane**, leaving a
  conflicted `R/fit-multi.R` and two stray untracked files in this worktree.
  Both were reverted immediately (`git checkout HEAD -- R/fit-multi.R`, the
  stray files moved out of the tree) and the stash entry itself is intact and
  unpopped, so nothing was lost — but in a repository with a dozen parked
  stashes from other lanes, `git stash pop` is never a safe read-only tool.
  Use `git show <rev>:<path>` to compare versions instead.
- **The frozen ordinal conjunction was not achievable at all.** No threshold
  reaches 90% sensitivity with zero false positives, because the class
  distributions overlap in the tails (degenerate minimum 10.2, healthy maximum
  52.3). Discovering that a pre-registration was unsatisfiable is a better
  outcome than discovering it after quietly relaxing it, but it did mean the
  arming decision had to be made against the issue's stated priority rather
  than against the frozen rule.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Pat (R-package engineering)** — every new statistic is engine-route
  dependent. M3's bug was not arithmetic; it was reading a REPORTed object that
  one of two routes never populates. Any diagnostic over a tiered engine needs
  a per-route participation test before it needs a threshold, and "no row" must
  be distinguishable from "no problem" in the calibration design.
- **Rose (validation debt)** — the strongest evidence in this arc is the
  *out-of-sample* kind: M1's 7/7-and-0/13 on a cell built for another purpose,
  and M2's 0/20 on rank-1 fits. Calibration-set performance is a design check;
  a cell the detector never saw is the only thing that tests generalisation.
  Also: the register must be able to carry a closed-with-a-negative-result
  caveat (diagonal-V) without that reading as an open question.
- **Grace (statistical review)** — pre-registration paid twice here in ways
  that flatter nobody: it forced the ordinal miss to be reported rather than
  reframed, and it forced the planted-near-zero FAIL to stand with its
  interpretation attached instead of the criterion being rewritten around the
  answer. A pre-registration that only ever confirms is not doing work.
- **Ada (orchestration)** — the two halves of this arc were sequenced
  correctly: the mechanism probe *had* to settle saturation-vs-separation
  before any arm was written, and it deleted an arm rather than adding one. A
  measurement that removes planned work is the cheapest kind.

## 10. Known Limitations And Next Actions

**Known limits — stated, not buried**

1. **No ordinal evidence at `n = 1600`.** The pre-registered grid was
   `n in {100, 400, 1600}`; the largest arm was dropped and `n = 400`'s seeds
   halved for the D-139 budget. Nothing is known about how either ordinal arm
   behaves at that scale.
2. **Ordinal sensitivity is below the frozen 90%.** At the shipped threshold of
   40, O2 catches 60.2% overall (70.0% on homogeneous designs) and O1 catches
   37.8%. The pre-registered conjunction was not achieved at any threshold, and
   arming was a judgement call against #897's stated specificity priority — not
   a gate that passed.
3. **The false-positive rates are BOUNDS, not verified zeros.** Zero false
   alarms were observed, but the healthy pools give rule-of-three bounds of
   **~1.4%** (ordinal, 217 fits) and **~7.5%** (multinomial, 40 informative
   fits). Bounding either near 0.6% needs a ≥ 500-fit healthy arm; that is
   outstanding, not done.
4. **No rho claim for the combined multinomial model (PA4 Cell B).** The
   variance components recover; the among-category correlation rails on 12/20
   seeds once a non-phylogenetic species tier competes for liability variance.
   Whether a larger `n_rep` or `n_sp` restores it is untested, not ruled out.
5. **Replication does not rescue the diagonal-V mode**, and the register must
   not extrapolate the full-rank s1b pass to it in either direction.
6. **Fit-time warnings are unwired** for both categorical families. Everything
   here surfaces through `check_gllvmTMB()` only.
7. **Binomial's own ~25% false-positive rate is measured and diagnosed but not
   fixed.**
8. **The `cutpoint_span` / `loading_over_span` variant is calibration-only** —
   its circularity precondition (is the span confounded with the label it would
   screen for?) was not tested, so it is computed and reported but never wired
   into `flag`/`status`. The M1 relative/sibling sub-arm is likewise disarmed
   and untested.
9. **PA2 carries no calibrated intervals** for the liability-scale H^2 (the
   `ci = TRUE` + `"auto"` combination refuses, deliberately), and its live
   cells are single-seed.
10. **PA5 — the paper-companion vignette — is OPEN and is the maintainer's
    call.** The alignment table, the Box-2 translation, the H^2 route and the
    combined-model verdicts now exist as design-doc material; turning them into
    a reader-facing article is a scope decision (and would have to carry the
    multinomial components-only boundary on its face), not a gap this lane
    should close unasked.

**Next actions**

- 🔴 **Needs the maintainer**: (a) whether either categorical row should become
  a fit-time warning; (b) whether PA5 is in scope; (c) posting or amending the
  #897 closeout draft.
- Follow-up slice: re-calibrate the binomial screen on binomial evidence.
- Optional: a ≥ 500-fit healthy arm to tighten either FPR bound; an ordinal
  `n = 1600` arm; a multinomial combined-model design sweep to see whether rho
  is recoverable at any `n_rep`.
