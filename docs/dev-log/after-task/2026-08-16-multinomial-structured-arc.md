# After Task: multinomial() structured-dependency arc (Slices 0-5, Design 108/123)

**Branch**: `claude/multinomial-structured-20260816`
**Date**: `2026-08-16`
**Roles (engaged)**: Claude Fable 5 (implementation, Slices 4-5), Shinichi Nakagawa (campaign execution/sign-off, Slices s1b/s3/9e4d2d07)

## 1. Goal

Take `multinomial()` (family_id 16) from a fixed-effects-only, leak-prone
fence (the state after the original Slice-0 adversarial-review repair) to a
bounded, campaign-gated structured-term surface: decide, cell by cell,
which of the deferred keywords (`dep()`, explicit `unique()`/`indep()`,
`phylo_*()`, `animal_*()`, `kernel_*()`, `spatial_*()`, the
`cluster`/`cluster2`/`unit_obs` grouping tiers, generic `(1 | group)`
random intercepts) should be admitted, run a signed recovery campaign
against each admission, and consolidate the result into one authoritative
design document, register rows, roxygen, and a capability-board row that
say only what the evidence supports — no softening a FAIL, no
strengthening a PASS.

## 2. Implemented

Five build slices landed on this branch (chronological commit order was
0, 1, 2, 4, 3, 5 — the design doc's numbering is by DESIGN SLICE, not
commit order, and states this explicitly):

- **Slice 0** (prior session): the covstruct-keyed admission fence itself
  (`R/multinomial-fence.R`), closing several silent-leak paths an
  adversarial Opus review found.
- **Slice 1**: admitted loadings-only `animal_latent()`/single-name
  `kernel_latent()` as pure engine sugar over the already-admitted
  `phylo_latent()` route.
- **Slice 2**: admitted the phylo MODE axis — `phylo_dep()` (full
  unstructured V) and `phylo_indep()`/standalone `phylo_unique()`
  (diagonal V) — plus their animal/kernel twins.
- **Slice 4** (this task, first half): admitted a generic `(1 | group)`
  random intercept and the non-phylogenetic `cluster`/`cluster2` diagonal
  tier, with a new whole-fit OLRE guard.
- **Slice 3** (landed after Slice 4 in this worktree despite its number):
  admitted the spatial (SPDE) mode axis — `spatial_latent()`,
  `spatial_indep()`, `spatial_dep()` — with an `A_proj` pre-expansion gate
  check run FIRST.
- **Slice 5** (this task, second half — the arc's consolidation slice):
  every admitted cell's recovery campaign was run to completion under
  SIGNED, pre-registered criteria (by the maintainer, commits `9e4d2d07`,
  `438a156f`, `47a71428`); this task consolidated those verbatim verdicts
  into `docs/design/123-multinomial-structured-surface.md` (promoted from
  stub to final design doc), the FAM-20C/D/E/F register rows, the
  `docs/design/02-family-registry.md` and capability-surface.html summary
  surfaces, and a roxygen sweep.

**The headline finding, stated without softening**: the entire
phylogenetic/relatedness among-category surface (FAM-20C/D) FAILS its
recovery gate at the native one-categorical-draw-per-species design (rail
rates 8/20 against a 6/20 threshold). A pre-registered replication rescue
(five draws per species) PASSES for the loadings-only and full-V cells but
is untested for the diagonal-V cell, whose own corrected rerun
independently FAILS. The spatial surface (FAM-20E) and the group-intercept
surface (FAM-20F) both PASS their signed gates outright. See §4 below and
`docs/design/123-multinomial-structured-surface.md` §1/§4 for every number.

## 3. Files Changed

**Design/register documents (Slice 5, this task's primary scope):**
- `docs/design/123-multinomial-structured-surface.md` — promoted from stub
  to final design doc: per-cell table (§1), engine identities (§2),
  identification frame (§3), data-hunger + replication rescue (§4), scalar
  refusal rationale (§5), out-of-scope list (§6), build log appendix (§7,
  the prior slice-by-slice sections preserved).
- `docs/design/35-validation-debt-register.md` — FAM-20 root row's BLOCKED
  list rewritten to the post-arc remainder; FAM-20C/D/E/F rows rewritten
  with final campaign verdicts.
- `docs/design/02-family-registry.md` — multinomial section's "Current
  status" paragraph rewritten (2026-08-16 supersedes 2026-07-21), prior
  text kept as "Prior status" for continuity; summary table row and the
  admission-fence paragraph updated.
- `docs/dev-log/capability-surface.html` — multinomial row: Modes
  `"limited"` → `"I D L · scalar refused"`; Structured `"—"` →
  `"phy spa ani ker"` with an inline hedge ("recovery needs per-species
  replication; point-only intervals") visible on the board itself.
- `NEWS.md` — extended the existing Slice-0 "Fixed" bullet with a new
  bullet covering Slices 1-4's admissions, the honest evidence (gates
  failed/passed, numbers), the scalar refusal, and behaviour changes
  (OLRE guard, `meta_V()`/`equalto()` fail-closed, cluster2 co-admission).

**Roxygen (Slice 5, this task):**
- `R/families.R` — `multinomial()`'s `@details` rewritten. Found and
  fixed a genuine self-contradiction the prior slices left behind: the
  "deferred" list still named `phylo_dep()`/`phylo_indep()`/
  `phylo_unique()` (admitted since Slice 2) and `spatial_*()` (admitted
  since Slice 3) as blocked, in the SAME roxygen block that separately
  described them as admitted a few paragraphs above. Rewrote the whole
  block into admitted / honest-evidence / refused / deferred sections.
- `R/extract-sigma.R` — `extract_Sigma()`'s `@param level` doc was missing
  `"cluster2"` from its enumerated list even though the code has accepted
  it for a while (pre-existing gap, unrelated to this arc's C++, exposed
  because Slice 4 made multinomial the first consumer that needed it
  documented accurately).
- `man/extract_Sigma.Rd`, `man/multinomial.Rd` — regenerated via
  `devtools::document()`.

**Slice 4 (this task, first half — see the separate prior report/commits
on this branch for full detail):** `R/multinomial-fence.R`,
`R/fit-multi.R`, `R/extract-sigma.R`, `R/families.R`,
`tests/testthat/test-matrix-multinomial-unit.R`,
`tests/testthat/test-multinomial-fence.R`, `tests/testthat/test-multinomial.R`,
`dev/multinomial-structured/dgp-multinomial-structured.R`,
`dev/multinomial-structured/campaign-s4-group-intercepts.R`,
`dev/multinomial-structured/pass-criteria-s4.md`.

**Slices 1-3 (prior sessions on this branch, not authored in this task):**
see the git log between `bf8368f1` and this task's start
(`d0846dea`/`48826a9c`/`fb9f22d4`/`8c4771ab` for Slice 3;
`bd4fbede`/`9e4d2d07`/`438a156f`/`47a71428` for the roxygen catch-up and
signed campaign results).

## 3a. Decisions and Rejected Alternatives

- **Decision:** report the FAM-20D `phylo_indep()` DGP mismatch openly in
  the register/design doc rather than quietly re-running and citing only
  the corrected number. **Rationale:** a silently-corrected mistake in a
  pre-registered campaign is exactly the kind of thing this arc's
  discipline exists to prevent; recording it costs one sentence and buys
  honesty about how the corrected number was obtained. **Rejected
  alternative:** cite only the corrected rerun's numbers. **Confidence:**
  high — this is a repo-wide convention already (see the other FAM-20
  rows' "correction to the original task brief" notes).
- **Decision:** record BOTH readings of FAM-20C's direction-correct
  criterion (15/16 = 94%, passes the proportion reading of "≥16/20"; one
  seed short of the strict count reading) rather than picking the
  favourable one. **Rationale:** the instruction was explicit ("no
  softening, no strengthening"); a criterion written as a count and read
  as a proportion is an ambiguity in the PRE-REGISTRATION, not a result to
  round in either direction. **Confidence:** high.
- **Decision:** keep `docs/design/122`'s prior per-slice "Status" sections
  as a "Build log" appendix (§7) rather than deleting them once the
  per-cell table (§1) supersedes their content. **Rationale:** they carry
  detailed engine-identity reasoning (e.g. the exact `.mn_classify_covstruct`
  branch logic) that the higher-level table intentionally compresses away;
  deleting them would lose that trail for a future slice's classifier
  changes. **Confidence:** medium — a future cleanup could trim these
  further once the arc is fully closed out.

## 4. Campaign verdicts

Originally recorded verbatim as handed off; **amended in the D-43
completion-panel repair round (same day) to fix two conflations and one
disclosure gap the panel caught** — see the annotations inline below and
§5's "Corrections made" for the fuller account.

- **FAM-20C** (`animal_latent()`/`kernel_latent()`, loadings-only):
  equivalence to `phylo_latent()` proven (matched objective to double
  precision, V to 1e-4). One-draw-per-species gate **FAILED**: rail rate
  8/20 (>6/20 threshold), identically for both keywords (engine identity).
  Non-railed median rho 0.695. Replication rescue (s1b, pre-registered
  before running) **PASSED**: n_sp=300 × n_rep=5 → rails 4/20, median rho
  0.680 ∈ [0.35,0.75] (non-railed filter; median over ALL 20 conv+PD
  seeds, unfiltered, is 0.696 — also in band, disclosed per D-43 R8), SD
  ratios 0.89/0.85, direction-correct 15/16 non-railed (94%; proportion
  reading passes "≥16/20", strict count reading is one short — both
  recorded). Tree-vs-star check: Δ logLik 29.7 (phylogeny genuinely
  enters).
- **FAM-20D** (`phylo_dep()`/`phylo_indep()` + twins): `phylo_dep()` gate
  **FAILED** (rails 8/20, median rho 0.781). `phylo_indep()` as-run had a
  DGP mismatch (correlated truth fed to the diagonal-truth cell — recorded
  openly); the corrected rerun (diagonal truth, sd 0.8/0.5) **FAILED**:
  larger variance fine (median ratio 0.78, 17/20 in band), smaller
  variance collapses (median ratio 0.24, 9/20 in band) — **7 of the 20
  seeds collapse the smaller variance to numerical zero (ratio ≤ 1e-9),
  every one with convergence = 0 AND a PD Hessian, and no runtime
  detector fires (D-43 R4; `R/diagnose.R`'s degeneracy gate is
  `family_id == 1`-only, issue #897's class)** — planted-zero criterion
  failed (full-V `phylo_latent()` refit on diagonal-truth data rails to
  median |rho|=1.0). The s1b replication rescue transfers to `phylo_dep()`
  EXACTLY (identical parameterisation); it does NOT cover `phylo_indep()`
  (replication rescue untested for the diagonal-V mode).
- **FAM-20E** (`spatial_latent()`/`indep()`/`dep()`): kappa/tau gate
  **PASSED all three cells** — median practical-range ratios 1.75 / 1.12 /
  1.75 among the 14 conv+PD seeds (band 0.33-3.0), rails 0, 3, 0 of those
  14 against the frozen threshold **>6/20** (D-43 R7: an earlier draft of
  this report mis-stated the denominator as ">6/14"; restored here),
  non-PD 6/20 per cell (reported, excluded per criteria). **Dispersion
  disclosed (D-43 R9):** 4 of 14 PD seeds fall outside [0.33,3.0] for
  `latent()`/`dep()` (worst ratio 4.56); `indep()`'s 3 rails sit at range
  ratios 2.3e-4 to 3.4e-4, and ALL THREE have `pdHess = TRUE`. Field
  correlation descriptive-only per the frozen criteria. `A_proj`
  usability finding: users must pre-expand coordinates before
  `make_mesh()`; `n_site = 300` was not calibrated against a prior spike.
- **FAM-20F**: **`(1 | group)` PASSED** — 20/20 conv+PD, median sigma
  ratio 0.947, range [0.60,1.51] ⊂ [0.5,2.0]. **This PASSED verdict does
  NOT extend to `cluster`/`cluster2`** (D-43 R3: an earlier draft of this
  report, and three docs surfaces, wrongly implied the same campaign
  covered both — the s4 summary CSV fit `re_int` exclusively, zero
  `cluster`/`cluster2` rows). `cluster`/`cluster2` are admitted with
  CONSTRUCTION-level evidence only (the fit constructs, `extract_Sigma()`
  returns a well-formed per-contrast diagonal); their recovery axis
  remains OPEN (`partial`), exactly as `pass-criteria-s4.md`'s own
  "Non-degenerate diagonal cell" section already stated (that file's own
  framing was correct throughout; the conflation was introduced only in
  the register/design-doc/NEWS/this-report surfaces). Baseline-vs-rest
  semantics + the corrected non-invariance claim stand as Slice 4 wrote
  them.
- **Slice-2 scalar refusal**: unchanged; null-probe evidence (`phylo_dep()`
  rails ±1 on zero-signal data 4/5 seeds with PD Hessians;
  `phylo_indep()` correctly ~0 in 5/5).
- **OLRE guard boundary (D-43 R10, note-level, no code change):** the
  guard fires only when EVERY level of a grouping factor is a categorical
  singleton (`all(n_obs_per_level == 1L)`); a mostly-singleton grouping
  passes silently. Recorded as a known boundary in `docs/design/122-
  multinomial-structured-surface.md` §3, not changed.
- **Maintainer decisions recorded**: `meta_V()`/`equalto()` is
  Gaussian-only → fid-16 fail-closed CONFIRMED; `cluster2` co-admission
  approved (identical engine math to `cluster`); campaigns signed
  2026-08-16.

## 5. Corrections made along the way (this task and its Slice-4 predecessor)

- **Baseline-invariance claim (Slice 4, corrected in this same task's
  first half, kept here for the arc record).** An early draft claimed
  refitting a `(1 | group)` model under a different `baseline` leaves
  predicted probabilities unchanged. A failing test caught this: it is
  FALSE for `(1 | group)` — re-labelling the baseline is not a
  reparameterisation of the same model (it constrains a DIFFERENT pair of
  categories' log-odds to be constant across groups). The TRUE, narrower
  invariant (odds between any two non-baseline categories, WITHIN one fit,
  across groups) replaced it everywhere the false claim had been written:
  `R/families.R`, `R/multinomial-fence.R`, `R/fit-multi.R`'s `cli_inform`,
  the design doc, the register row, and the pass-criteria notes.
- **`phylo_indep()` DGP mismatch (maintainer's campaign run, recorded in
  this task's consolidation).** The as-run FAM-20D `phylo_indep()` cell
  fed correlated-truth data into what should have been a diagonal-truth
  cell. The corrected rerun is what FAM-20D's FAILED verdict reports; the
  mismatch itself is stated openly in both the register row and the
  design doc rather than silently absorbed into "the corrected number."
- **`R/families.R` roxygen self-contradiction (found and fixed in this
  task).** The `multinomial()` `@details` block listed `phylo_dep()`/
  `phylo_indep()`/`phylo_unique()` and `spatial_*()` as "deferred" in its
  closing paragraph while separately describing them as admitted earlier
  in the SAME block — a leftover from Slices 2 and 3's admissions not
  being fully propagated through this file. Fixed as part of the roxygen
  sweep (§3).
- **PR body / description surface.** Not touched this task — PR #1057's
  title already reads "S0–S4"; no PR-body edit was made, since GitHub PR
  descriptions are not files in the repo and this task's scope was
  file-based consolidation. Flagged as a follow-up (§7) rather than done
  silently via the `gh` CLI without being asked.

### 5a. D-43 completion-panel repair round (same day, follow-on task)

The D-43 completion panel returned 2× NOT-DONE and 1× DONE on this arc's
Slice-5 consolidation, finding two CODE gaps and eight DOCS issues (one
already fixed and excluded from this list — the provenance-script finding,
`rerun-s2-indep-corrected.R`, committed `899dc9c7`):

- **R1 (code, blocking): `re_int` was tier-blind.** The classifier
  admitted a `(1 | group)` term for ANY grouping regardless of tier,
  discarding the tier it had already computed — a unit_obs-tier term
  classified ADMITTED and was only stopped, on SOME fixtures, by the
  coincidental OLRE guard (fixtures where every unit_obs level happened to
  be a categorical singleton). Fixed: the classifier now checks tier
  directly and blocks unit_obs. New table row + table-consistency
  coverage + a fit-level regression test using a NON-singleton unit_obs
  fixture (so the fix is pinned independently of the OLRE guard).
- **R2 (code, housekeeping): the admission table was not literally
  exhaustive.** `dep()`/`indep()`/`unique()` at the unit tier were blocked
  only via classifier fallthrough + fit-level tests, with no table row —
  inconsistent with the table's documented status as the single source of
  truth. Added explicit rows + `reprs` entries for all three.
- **R3 (docs, blocking): FAM-20F conflated `(1 | group)`'s signed PASS
  with `cluster`/`cluster2`'s construction-level-only evidence** across
  three surfaces (register, design-123, NEWS) and this report. Fixed
  everywhere; `pass-criteria-s4.md` itself never had this bug.
- **R4 (docs, blocking): the `phylo_indep()` 7/20 numerical-zero collapse
  was under-disclosed.** "Median ratio 0.24, 9/20 in band" did not state
  that 7 of those 20 seeds collapse to numerical zero with `convergence =
  0` AND a PD Hessian, invisible to every current diagnostic. Disclosed
  in FAM-20D, design-123, NEWS; the `#897`-class detector gap added to
  Known Limitations.
- **R5 (docs, should-fix): the capability-board hedge was uniform and
  partly wrong** ("recovery needs per-species replication" does not
  describe `phylo_indep()`'s actual failure mode, and is irrelevant to
  spatial, which passed outright). Reworded to name each axis's real
  status.
- **R6 (docs, should-fix): pass-criteria STATUS lines still read DRAFT**
  after the register already reported them SIGNED. Updated all four
  (s1-s4) with a dated amendment note below the frozen block (the frozen
  block itself untouched); s1b — whose file, DGP script, and results all
  landed in ONE commit — got an explicit "not git-verifiable" provenance
  note rather than an implied one.
- **R7 (docs, should-fix): the s3 frozen rail threshold was re-expressed
  as ">6/14"** in design-123 and NEWS; the pre-registered frozen wording
  is ">6/20". Restored in both places plus the register row, with the
  14-PD-seed context kept alongside rather than dropped.
- **R8 (docs, should-fix): s1b's non-railed-filter median (0.680) was
  reported without its unfiltered counterpart.** Disclosed: median over
  ALL 20 conv+PD seeds is 0.696, also in band — the PASS does not depend
  on which one is headlined.
- **R9 (docs, should-fix): spatial per-seed dispersion was absent.** Added
  to design-123/FAM-20E/NEWS: 4/14 PD seeds outside band for
  `latent()`/`dep()` (worst ratio 4.56); `indep()`'s 3 rails at range
  ratios 2.3e-4–3.4e-4, ALL with `pdHess = TRUE` — verified directly from
  `s3-summary-20260816-190701.csv`, which also corrected one sub-detail
  in the original finding (all three rails have `pdHess = TRUE` on
  re-verification, not two).
- **R10 (docs, note-level): the OLRE guard's all-or-nothing boundary**
  (fires only when EVERY level is a categorical singleton) recorded
  explicitly in design-123 §3 as a known boundary + follow-up, no code
  change.

## 6. Checks Run

- `Rscript -e 'devtools::document(roclets = c("rd"))'` — regenerated
  `man/extract_Sigma.Rd`, `man/multinomial.Rd`. (`man/predict_missing.Rd`
  also drifts on every `document()` run in this checkout — a pre-existing,
  unrelated roxygen/Rd staleness not touched by this arc; reverted both
  times it appeared rather than committed.)
- `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript -e 'devtools::test(filter = "multinomial")'`
  — 0 failures, 0 errors (one pre-existing, unrelated AGHQ warning, same
  as before this task). Covers `cross-family-multinomial`,
  `link-residual-multinomial`, `matrix-multinomial-phylo`,
  `matrix-multinomial-spatial`, `matrix-multinomial-unit`,
  `mspl-multinomial-phase4-oracles`, `multinomial-fence`,
  `multinomial-missing-response`, `multinomial`, `simulate-multinomial`.
- `NOT_CRAN=true Rscript -e 'devtools::test()'` (full local suite, the
  arc's exit check; `GLLVMTMB_HEAVY_TESTS` unset, so the heavy
  recovery/matrix/campaign tier is gated out per `tests/testthat/setup.R`'s
  fast/slow split — this is the routine-PR-CI-equivalent run, not the full
  heavy tier). **36.77 minutes elapsed. 3 failures, 8 warnings, 868 skips
  (honest, reason-given), across ~490 test files.** All 3 failures are
  PRE-EXISTING and UNRELATED to this arc — not fixed, per the instruction
  not to fix unrelated pre-existing failures:
  - `test-control-field-surface.R:40` — "gllvmTMBcontrol consumers ..."
    (`setdiff(used, internal)` vs `intersect(used, declared)` mismatch,
    needs `.internal_continuation`) — an AGHQ/VA continuation
    control-field surface consistency check; `gllvmTMBcontrol()` is not
    touched by this arc.
  - `test-mspl-poisson-phase4-oracles.R:414` and `:416` — "prepare public
    door ..." (`grepl("fam_ids %in% c\(0L, 1L, 2L\)", mspl_src)` false) —
    MSPL-lane work-in-progress on `R/mspl*`, explicitly out of this task's
    scope (the task brief says "no R/mspl*").
  The 8 warnings are informational, not failures (AGHQ ridge `logLik()`
  caveats on `test-aghq-missing-response.R`; a "rows full of zeros" note
  on the `gllvm` cross-package comparator, `test-comparator-gllvm.R`) —
  none touch multinomial or this arc's files. The `summary` reporter used
  does not print an aggregate pass count; the multinomial-scoped run above
  is the authoritative 0-failures evidence for this arc specifically.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row is tied to this arc by name; Design 123 and the
FAM-20 register rows are the tracked artifacts.

## 7a. GitHub Issue Ledger

No relevant open issue was inspected or created; this arc's tracking lives
entirely in `docs/design/122` and the FAM-20 register rows, per the
existing convention for other multinomial slices on this branch.

## 8. What Did Not Go Smoothly

- The `(1 | group)` baseline-invariance claim (§5) was wrong on first
  draft and only caught because the test that should have proven it
  instead failed with a large, unambiguous numeric mismatch — a genuine
  case of "write the test, trust the failure," not a near-miss.
- `man/predict_missing.Rd` drifts from its checked-in state on every
  `devtools::document()` run in this checkout, unrelated to any file this
  arc touches. It was reverted (not committed) both times it appeared;
  flagged as a pre-existing repo-hygiene item, not fixed here (out of
  this task's scope, per the "surgical changes" rule).
- Every edited file in this shared, multi-lane repo triggered a
  "LANE CHECK" hook warning naming dozens of other branches with
  unmerged work on the same path (`NEWS.md`, the two design docs,
  `capability-surface.html`, `families.R`, `extract-sigma.R`). All of
  these are large, high-traffic shared files touched by many concurrent
  lanes; every edit in this task was scoped to the multinomial-specific
  paragraph/row/section, so no cross-lane content conflict is expected,
  but the actual merge-time reconciliation was not attempted here (it
  belongs to PR review / the maintainer's merge-order call, not this
  slice).

## 9. Team Learning

**Claude Fable 5 (this task, Slice 4 + Slice 5):** the single most
valuable check in this arc was writing the baseline-invariance test
BEFORE trusting the plausible-sounding claim about `(1 | group)`
semantics — the claim read as obviously true (relabelling a factor level
should not change fitted probabilities) and was wrong in a way that only
a failing numeric assertion would have caught. Consolidating five slices'
worth of "staged, pending sign-off" language into final verdicts also
surfaced a real, load-bearing doc bug (`R/families.R`'s self-contradictory
admitted/deferred lists) that no single prior slice would have caught on
its own, because each slice's own edit was locally consistent — the
contradiction only existed across slices.

## 10. Known Limitations And Next Actions

- **Replication rescue is untested for the diagonal-V mode
  (`phylo_indep()`/`animal_indep()`/`kernel_indep()`).** This is the
  single most actionable open question this arc leaves: does `n_rep = 5`
  rescue the diagonal-V cell the way it rescued the full-V and
  loadings-only cells, or does its independent small-variance-collapse
  failure mode persist under replication? Needs its own s1b-style
  pre-registered campaign.
- **No fid-16 (multinomial) degeneracy detector exists (cf. #897).**
  7 of the 20 corrected `phylo_indep()` seeds collapse the smaller
  contrast variance to numerical zero (ratio ≤ 1e-9) with `convergence =
  0` AND a PD Hessian on every one -- a silent-looking pass by every
  currently-reported diagnostic. `R/diagnose.R`'s Heywood/degeneracy gate
  (`.gllvmTMB_binomial_prevalence_loading_row()`,
  `R/diagnose.R:433-484`) checks `family_id == 1` (binomial) only; issue
  #897 already tracks the analogous gap for `ordinal_probit`
  (`family_id == 14`), and this arc's evidence shows the same class of
  gap extends to `family_id == 16`. A fid-16 extension of that detector
  (or a dedicated one) is a concrete, scoped follow-up.
- **The OLRE guard's boundary condition is narrower than "mostly
  degenerate."** `.multinomial_reint_group_olre_guard()` fires only when
  EVERY level of the grouping factor has exactly one categorical
  observation (`all(n_obs_per_level == 1L)`); a grouping where MOST
  levels are singletons but a few are not passes the guard silently.
  Recorded as a known boundary in `docs/design/123-multinomial-
  structured-surface.md`'s §1 OLRE-guard row rather than changed here —
  a partial-degeneracy detector would need its own identifiability
  argument (some groups may be estimable even when most are not), not a
  mechanical tightening of the current all-or-nothing check.
- **`extract_Sigma(level = "spatial")` on a `spatial_indep()`-only fit
  still aborts** — a pre-existing, family-agnostic gap (not multinomial-
  specific, not introduced or fixed by this arc). A dedicated diagonal-SPDE
  extraction surface would need to span every family that carries
  `spatial_indep()`, not just multinomial.
- **`extract_correlations()`/other extractor "source labels"** were not
  audited across the newly-admitted spatial/group-intercept tiers in this
  task — worth a follow-up sweep to confirm every extractor that lists
  admitted tiers by name (not just `extract_Sigma()`) is current.
- **The INLA-environment note in FAM-20E is now moot for CI purposes**:
  this environment has `fmesher` but not `INLA`, and the gate-check +
  campaign both ran to completion without it — worth confirming the CI
  matrix reflects that `INLA` is not actually required for the admitted
  spatial cells before advertising them further.
- **`n_site = 300` (FAM-20E) was not calibrated against a prior spike**,
  unlike S1/S2's `n_sp = 800`. The PASS is real, but a future spike run
  would strengthen confidence that 300 is not an accidentally-favourable
  scale.
- **The diagonal-V replication gap plus the untested spatial/group-
  intercept interval calibration** together mean NO cell in this entire
  arc has a calibrated interval — every recovery number is a point-
  estimate campaign verdict. This is stated in the out-of-scope list
  (design doc §6) and should stay visible on the capability board (done,
  this task) rather than fade once the "admitted" label reads as done.

## Addendum — arc-close `--as-cran` check (Melissa's routed item, resolved)

`rcmdcheck::rcmdcheck(args = "--as-cran")` on the final rebased branch
(904e7d91): **0 ERRORS / 0 WARNINGS / 2 NOTES**. Notes: the standard
new-submission incoming-feasibility note, and a local untracked scratch log
(`.full-test-run.log`, not in git, not shipped). One test failure under CRAN
conditions is PRE-EXISTING and out of arc scope:
`test-mspl-simulation-contract.R` exercising the mspl lane's own
`inst/sim/lane-b/lane-b-b2-runner.R` (their commit 0d992c61) — this branch
touched neither file (`git diff origin/main...HEAD` empty on both), so the
failure reproduces identically on origin/main.
