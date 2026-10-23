# After Task: random-slope surface — truth ledger, board correction, interval feasibility, campaign design (D-113 track 6)

**Branch**: `claude/rand-slope-surface-20260818`
**Worktree**: `/private/tmp/gllvmtmb-randslope`
**Date**: `2026-08-18`
**Roles (engaged)**: `Curie-S0 (recon) · Curie-S1 (board) · Gauss-S2 (interval probe) · Curie-S3 (campaign costing) · Rose-S4 (adversarial review) · Rose/Melissa (this closeout)`

## 1. Goal

Answer three questions Shinichi asked about random slopes, framed as D-113 track 6
(2026-08-01: "at least one random slope for each distribution"; 2026-08-08 clarifying
note: propose a test programme and STOP FOR APPROVAL, do not bump `DESCRIPTION`):

1. Can random slopes work for all distributions?
2. Can we at least get them tested with intervals feasible?
3. Is the capability board correct, or does it need updating?

## 2. Implemented

- **Truth ledger** (`dev/rand-slope-truth-ledger.md`): a three-column extraction —
  CODED (`.augmented_slope_family_contract()`, `R/fit-multi.R:453`), VALIDATED
  (`docs/design/35-validation-debt-register.md` register rows), ADVERTISED
  (`docs/dev-log/capability-surface.html` per-family table) — across all 16 family ids.
  9 of 16 rows disagreed across the three columns.
- **Board correction** (`dev/board-correction-notes.md` + edits to
  `docs/dev-log/capability-surface.html`): 5 of the 9 mismatches corrected (Beta,
  Gamma, student, lognormal, and — after the adversarial-review correction below —
  ordinal_probit) to `partial`, never `✓`. The remaining 4 (gaussian, poisson,
  nbinom2, nbinom1) were left untouched **deliberately**: the board's own gap-box text
  caps the whole Rand. slope column at `partial` even for families whose register rows
  say `covered`, because the ≥1-slope capability is diagnostic-grade board-wide. A
  drive-by false claim in `docs/design/61-capability-status.md:176` (that the
  structured-slope article was "retired from pkgdown") was also corrected — it is live
  in `_pkgdown.yml` nav at tier 3 ("under-audit").
- **Interval feasibility probe** (`dev/slope-interval-feasibility.R` /
  `-RESULTS.md` / `-OUTPUT.log`): checked whether a slope-variance confidence interval
  is computable today, on a healthy Gaussian `phylo_indep(1 + x | species)` fit, via
  both the `theta_dep_chol` (Route A) and `theta_diag_B_slope` (Route B) parameterisations.
  Verdict: **computable on both routes** (`sd_report` populated by default, both blocks
  present in `par.fixed`/`cov.fixed`, no existing exported extractor) — **not** a
  calibration or coverage claim.
- **Campaign design** (`docs/design/128-slope-per-family-campaign.md`): a COSTING-ONLY
  document for the three still-open D-113 track-6 family ids (tweedie 6,
  truncated_poisson 10, truncated_nbinom2 11). Nothing was run to produce it. It
  recommends truncated_poisson first (cheapest, no dispersion parameter, cited
  intercept-recovery floor N=250) with truncated_nbinom2 as a follow-on, and separates
  out tweedie as a distinct research question (a documented ~44% slope-SD bias that
  survives fixing `p`, not an N problem) rather than folding it into the same PR.
- **Adversarial review** (`dev/S4-adversarial-review.md`, Rose, fresh context): verdict
  **CHANGES REQUIRED**, two required changes, both landed before this closeout:
  - **R1** — the first-pass ordinal_probit board annotation ("recovery not admissible")
    was itself a false, mis-scoped claim: the board's Rand. slope column is
    family-scoped, not route-scoped, and ordinal_probit's overall register evidence
    (RE-02, PHY-17, PHY-18, SPA-09, SPA-10 all `covered`) strictly exceeds the
    single-seed C1 basis that already earned lognormal/student their `partial` cells.
    Fixed in commit `f2a75761`: raised to `partial`, annotation narrowed to name the one
    weak route (`phylo_indep`, PHY-16, 3/6 PD-Hessian fits).
  - **R2** — the interval probe's Route A parameter indexing was wrong:
    `theta_dep_chol`'s 9 free entries pack as all 6 diagonals first, then 3 within-block
    off-diagonals column-major — not 3-entry `(int, slope, offdiag)` blocks per trait as
    the first pass assumed. Two of three "slope" rows were reading the wrong parameter
    (a different trait's intercept; a raw-scale off-diagonal). Fixed in commit
    `d5e9f198`: correct indices (diagonals at positions 2, 4, 6), and the marginal slope
    variance recomputed as `L21² + L22²` via a multivariate delta method (the
    within-trait intercept–slope Cholesky entry is free under `phylo_indep(1+x|g)`, so a
    univariate `exp()` on the diagonal alone was itself wrong, not just mis-indexed).

## 3. Files Changed

```
dev/board-correction-notes.md                | new
dev/rand-slope-truth-ledger.md                | new
dev/slope-interval-feasibility.R              | new
dev/slope-interval-feasibility-RESULTS.md     | new
dev/slope-interval-feasibility-OUTPUT.log     | new
dev/S4-adversarial-review.md                  | new
docs/design/128-slope-per-family-campaign.md  | new
docs/design/61-capability-status.md           | 1 line corrected
docs/dev-log/capability-surface.html          | 5 board cells corrected
.gitignore                                     | 1 line added (stray scratch-file ignore)
```

No file under `R/`, `src/`, `tests/`, `NAMESPACE`, `NEWS.md`, or `DESCRIPTION` was touched
(`git diff --name-only origin/main...HEAD -- R/ src/ NEWS.md DESCRIPTION tests/` is empty —
checked directly, not asserted).

## 3a. Decisions and Rejected Alternatives

- **Decision:** raise ordinal_probit to `partial` (family-scoped reading of the board
  column). **Rejected:** demoting lognormal/student back to `—` (would revert a landed,
  maintainer-approved precedent — betabinomial's identical C1 `partial` admission,
  2026-08-01); a route-scoped cell reading (the column has no route axis to hold one).
  **Confidence:** high — this is the only reading that keeps the five `partial` cells
  mutually coherent, per Rose's review.
- **Decision:** leave gaussian/poisson/nbinom2/nbinom1 untouched despite `covered`
  register rows. **Rationale:** the board's own gap-box text caps the entire column at
  `partial`, board-wide, because the ≥1-slope capability is not a finished capability
  even for gaussian. **Confidence:** high — this is the maintainer's own stated policy,
  not a new judgment call.
- **Decision:** exclude delta_lognormal/delta_gamma from the campaign design entirely
  rather than costing a cell for them. **Rationale:** they are fenced by semantics (two
  latent scales per family_id; the resolved delta convention restricts random structure
  to the positive submodel only), not by a missing-evidence gap — costing a cell would
  require a grammar/engine decision on which submodel the slope attaches to, which is a
  maintainer discussion checkpoint per `CLAUDE.md`, not a #388-style recovery-cell
  campaign. **Confidence:** high.
- **Decision:** recommend truncated_poisson over tweedie as the next D-113 track-6
  campaign cell. **Rationale:** tweedie's slope-SD bias (~44%) is documented to survive
  `p`-fixing — it is a known research question about a specific estimation mechanism,
  not an N-sweep; truncated_poisson has a cited intercept-recovery floor and no
  documented failure mode. **Confidence:** medium — this is a recommendation for
  Shinichi, not a decision this lane is authorized to make (see §7a Open Questions).

## 4. Checks Run

- `git diff origin/main...HEAD --stat` / `git log origin/main..HEAD --oneline` — read in
  full before any claim in this report.
- `git diff --name-only origin/main...HEAD -- R/ src/ NEWS.md DESCRIPTION tests/` → empty.
- `grep -n 'class="yes"' <diff of capability-surface.html>` → every `✓` in the diff sits
  in a column adjacent to, not inside, the Rand. slope cells that were edited; no `✓` was
  added to the Rand. slope column itself.
- `grep -in "all famil\|every famil\|works for all\|universal"` across the full
  `origin/main...HEAD` diff → no matches (no universal-capability claim anywhere).
- `grep -in "coverage\|calibrat"` across the full diff → every hit is an explicit
  disclaimer ("No coverage or calibration evidence", "Broad interval coverage is not
  certified", "D-112 forbids a coverage chase") — none is a coverage/calibration claim.
- Rose's S4 adversarial review independently re-derived every cited register line number,
  contract entry, and test-file assertion at source (not from producer paraphrase);
  verdict CHANGES REQUIRED, both required changes (R1, R2) verified landed in commits
  `f2a75761` and `d5e9f198` before this closeout.
- `docs/design/128-slope-per-family-campaign.md` §9 self-check: `git log --all
  --diff-filter=A -- 'docs/design/128-*'` empty at authoring time (design number free,
  not a collision).

No `devtools::check()`, `devtools::test()`, or `R CMD check` run this session — correctly,
since no `R/`, `src/`, or `tests/` file changed (checked above, not assumed).

## 5. Tests of the Tests

Not applicable in the usual sense — this lane added no `testthat` files. The one artifact
that functions like a test is the interval-feasibility probe script
(`dev/slope-interval-feasibility.R`), which is dev-only and not wired into the test suite.
Its own correctness was itself the subject of the adversarial review's R2 finding (a
genuine indexing bug caught and fixed, not a false negative in a formal test).

## 6. Consistency Audit

- `rg 'class="yes"' docs/dev-log/capability-surface.html` restricted to the diff hunks
  touching the Rand. slope column: zero matches inside those `<td>` cells across all 5
  edits (verified above under Checks Run).
- `rg "family_id = (10L|11L|6L)" R/fit-multi.R`: none of the three campaign-design
  families (tweedie, truncated_poisson, truncated_nbinom2) appear in
  `.augmented_slope_family_contract()` — confirming the campaign is costed, not run; no
  admission was granted.
- `rg "partial|—" dev/board-correction-notes.md` cross-checked against
  `docs/dev-log/capability-surface.html`'s actual post-edit cell text for all 5 changed
  ids: matches exactly (see §5 of the review and the ledger's mismatch-8 update).

## 7. Roadmap Tick

N/A — this is a planning/evidence/board-honesty lane against D-113 track 6, not a
`ROADMAP.md` row.

## 7a. Open Questions For Shinichi

1. **Campaign ordering:** truncated_poisson vs tweedie for the next D-113 track-6 slot.
   Design 128 recommends **truncated_poisson first** (cheapest, no dispersion parameter,
   cited N=250 floor, no documented failure mode) with truncated_nbinom2 as a
   near-immediate follow-on, and recommends scoping **tweedie separately** as its own
   research slice — it carries a documented ~44% slope-SD bias that survives fixing `p`,
   which is a different kind of problem than "run a cell and admit it."
2. **Slope-interval extractor:** now that computability is demonstrated on both routes
   (Route B is a two-line univariate delta method; Route A's slope coordinate needs a
   2x2 multivariate delta method because the within-trait intercept–slope Cholesky entry
   is free), should this lane's finding be turned into an exported extractor? No such
   extractor exists today (`grep -n 'B_slope' R/profile-targets.R` returns nothing), and
   building one is a scope decision the lane is not authorized to make unilaterally —
   it would be new public API surface.

No GitHub issue inspected, commented, closed, or created this session.

## 8. What Did Not Go Smoothly

- The interval probe (S2) needed three build passes before a clean, correct result: pass
  1 measured no slope parameters at all (wrong parameterisation assumed); pass 2 produced
  fits with a non-PD Hessian (uninformative about computability); pass 3 succeeded on a
  healthy fit but carried the Route A indexing bug that pass 4 (post-adversarial-review)
  fixed.
- The board-correction pass's own first attempt at the ordinal_probit cell replaced one
  false claim ("ordinal RE not implemented") with a narrower but still false one
  ("recovery not admissible" — true only of one route, stated as if true of the whole
  family). The adversarial review caught this; it would not have been caught by a
  self-review, since the mis-scoping was a genuine judgment-call error, not a citation
  error.
- No compute time or CI was spent on anything beyond local dev-script runs and one
  Gaussian probe fit; the campaign design was deliberately not run, per D-139's
  estimate-before-you-run discipline, and the pre-run test it specifies remains
  unexecuted pending Shinichi's ordering decision (§7a).

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Rose (S4 adversarial review):** the review earned its cost. Both required changes were
genuine, non-cosmetic defects: R1 was a judgment-call error (route- vs family-scoped
reading of a single-slot board column) that a same-session self-review was unlikely to
catch, and R2 was a parameter-indexing bug that, uncaught, would have shipped a false
"two-line univariate delta method" headline for half of Route A. Both were fixed exactly
as specified, verified against source before and after.

**Melissa (this closeout):** see the companion plan-vs-actual reconciliation,
`docs/dev-log/plan-actual/2026-08-18-rand-slope-surface.md`, for the six-axis comparison
and the adaptive/drift/unclear classification of the S2 three-pass rework and the S4
non-clean verdict.

## 10. Known Limitations And Next Actions

### What this does NOT cover

- **No coverage or calibration evidence anywhere in this lane.** The interval probe
  answers computability only ("can a number come out"), not whether that number would be
  well-calibrated. D-112 and Design 80 own that question as a separate arc.
- **Single seed throughout.** The interval probe ran one Gaussian fit, one seed. No
  averaging, no multi-seed replication.
- **Gaussian only for the interval probe.** No non-Gaussian family's slope-interval
  computability was checked — the finding does not transfer to binomial, poisson, or any
  other family without its own probe.
- **The campaign (Design 128) was costed, not run.** No fit, simulation, or probe was
  executed to produce it; every number in it is either a citation to a landed prior
  document or explicitly flagged as unestablished (§4/§5 of that document say so
  directly). tweedie, truncated_poisson, and truncated_nbinom2 remain `open (fenced)` /
  `open (gated)` in the ledger — none was admitted to
  `.augmented_slope_family_contract()`.
- **No new exports.** No R-level extractor for slope-variance intervals was built on
  either route, despite computability being demonstrated. `grep -n 'B_slope'
  R/profile-targets.R` returns nothing.
- **No `DESCRIPTION`/`NEWS.md` change.** Per the D-113 track-6 2026-08-08 clarifying
  note, this lane proposes and evidences; it does not bump a version or announce a
  capability change.
- **The four conservative board cells (gaussian, poisson, nbinom2, nbinom1) were left
  deliberately untouched**, even though their register rows include `covered` statuses —
  this is the board's own stated policy (the whole Rand. slope column is capped at
  `partial`), not an oversight this lane could or should fix.
- **Bare-bar `(1 + x | g)` slopes are still genuinely unimplemented** — the board's own
  Section 4 table records this as `reserved`; nothing in this lane changes that, and
  nothing in this lane claims otherwise.
- **No `✓` was added anywhere in the Rand. slope column** — every changed cell uses the
  `partial` tag, never the `yes`/`✓` class, matching the maintainer's own cap.
- **Never claimed:** "random slopes work for all families." The truth ledger and board
  correction are explicit that 3 of 16 family ids (tweedie, truncated_poisson,
  truncated_nbinom2) remain outside the contract entirely, and 2 more (delta_lognormal,
  delta_gamma) are recommended to stay out on semantic grounds.

### Next actions

- Shinichi decides the two open questions in §7a (campaign ordering; extractor scope).
- If truncated_poisson is chosen: run Design 128 §4's pre-run test (a single timed
  `Rscript` invocation, abort criterion ~5 min) before committing to the full admission
  cell.
- Tweedie's bias question, if pursued, needs its own scoping pass (replicate-or-redesign,
  Design 128 §2.3) — it is not a same-shaped decision as the two truncated families.
