# After Task: Ordinal degeneracy detector-S2c — curvature and multi-start arms measured and eliminated

**Branch**: `claude/1097-ordinal-curvature-20260817`
**Date**: `2026-08-17`
**Roles (engaged)**: `Gauss / Rose / Fisher / Shannon`

## 1. Goal

Issue #897: `ordinal_probit` has no working degeneracy detector (239/239
degenerate fits unflagged, where the binomial screen catches 272/272). A
prior 315-fit calibration (`dev/ordinal-degeneracy/pass-criteria-ordinal.md`)
eliminated four loading/cutpoint-based candidate statistics plus a
dichotomisation-refit counterfactual (five approaches total), all working
from the fitted loading point estimate and cutpoint geometry. This task
pre-registers, runs, and independently scores exactly two more candidates
drawn from **different information sources**: the curvature of the fitted
objective around the loading block (Arm C), and disagreement across
multi-start optimisation restarts (Arm D). Both fail. This report lands the
result honestly, updates the design-doc record, and does not ship any
behaviour change.

## 2. Implemented

- A frozen pre-registration (`dev/ordinal-degeneracy/pass-criteria-curvature.md`)
  specifying two arms in closed form: **Arm C** — the Schur complement of
  the `theta_rr_B` loading block within `TMB::sdreport()`'s already-computed
  `cov.fixed` (`solve(cov.fixed[idx, idx])`, no full-matrix inversion), i.e.
  the loading-only curvature *profiled over every other fixed effect*
  (cutpoints, intercepts, dispersion), not the naive conditional block,
  which eigenvalue interlacing would let hide a joint loading–cutpoint flat
  direction; **Arm D** — the spread of the optimiser objective across
  `n_init = 5` restarts with scale-relative jitter
  (`0.5 * the cell's own DGP loading scale`, not a flat constant).
- The pre-registration went through one full adversarial review cycle
  (BLOCK verdict, four blocking + six should-fix findings) before freezing;
  every finding is recorded with a fix or an explicit, reasoned pushback in
  the document's own "Review history" / "Pushback" sections.
- **Frozen at 18:07** (filesystem-verifiable: `pass-criteria-curvature.md`
  mtime `18:07:31`), **before any scored fit ran**. A D-139 timing pilot
  (`campaign-curvature-pilot.R`) had already run at that point and is
  quarantined — its statistic *values* were inspected only for
  finiteness/sanity during design, never for what threshold they would
  imply, so freezing afterward does not launder any peeking at the answer.
- A 20-cell smoke check surfaced and fixed a real harness bug (a scoping
  defect from double-layered dynamic function extraction that broke
  `sim_ordinal_transport()`/`sim_ordinal_mixed()`'s lexical resolution of a
  bare `probe` reference — 8/20 cells failed with `object 'probe' not
  found` before the fix, 0/20 after). A second divergence (measured ~4x
  parallel efficiency vs. an assumed ~10x) was investigated, confirmed
  stable under both `mc.preschedule` settings, and reported rather than
  silently absorbed, before the full run was authorised.
- **Scored run started at 18:19** (12.68 min wall-clock, ending at the
  `campaign-curvature-scored.csv` mtime `18:32:27`) — **450/450**
  `gllvmTMB()` calls `status == "OK"`, coverage exactly matching the frozen
  Grid table (`scale_healthy` 140, `scale_boundary` 40, `scale_degenerate`
  120, `transport` 80, `mixed` 70; `n_init` 310×1 / 140×5).
- **Scored by an independent agent** that did not design the campaign and
  had no access to this design discussion, applying the frozen text
  verbatim (`dev/ordinal-degeneracy/results/scoring-verdict.md`).
- **Verdict: both arms FAIL.** Arm C sensitivity 1.1–5.3% (reading-dependent
  on a genuine scoring-rule ambiguity found and reported by the scorer, not
  resolved silently), Arm D 7.3%, exploratory `flag_C | flag_D` 7.3%
  (identical to Arm D alone — Arm C adds nothing incremental), all against
  a pre-registered ≥90% sensitivity target. The independence precondition
  (correlation against the already-eliminated `max_loading_unit`, refusal
  bar `|r| >= 0.8`) **PASSES for both** statistics (`r = 0.538`, `r =
  -0.452`) — the null is not a circularity artefact.
- **The pre-registered ship-disarmed fallback applies.** Both arms remain
  unimplemented; `ordinal_liability_loading`'s existing `O1`/`O2` arms are
  untouched by this task and stay at `Inf`/`Inf` exactly as before. No
  export, no threshold, no behaviour change.
- A post-hoc amendment (in `pass-criteria-curvature.md`, clearly separated
  from and not editing the frozen Scoring rule text) records the three
  scoring ambiguities the independent scorer found, with a recommended fix
  for a future pre-registration.
- `docs/design/35-validation-debt-register.md` (FAM-14 row) and
  `docs/design/123-multinomial-structured-surface.md` (new §8.2a) updated
  to record the two new eliminations. The eliminated-candidate count for
  ordinal degeneracy detection is now **seven**, not five.

## 3. Files Changed

**Design / evidence:**
- `dev/ordinal-degeneracy/pass-criteria-curvature.md` — new (frozen
  pre-registration, review history, scored verdict, post-hoc amendment)
- `docs/design/35-validation-debt-register.md` — FAM-14 row appended
- `docs/design/123-multinomial-structured-surface.md` — new §8.2a, §8.5
  list item added

**Campaign scripts:**
- `dev/ordinal-degeneracy/campaign-curvature-pilot.R` — new (precondition
  checks + timing pilot; reuses `.load_probe_defs()`/DGP from
  `campaign-ordinal-calibration.R`/`probe-mechanism.R` verbatim via a
  parse-and-eval-named-defs extraction, never forking the DGP)
- `dev/ordinal-degeneracy/campaign-curvature-scored.R` — new (frozen-grid
  runner; smoke + continue stages; writes the scored CSV at a path
  distinct from every quarantined pilot file)

**Data (quarantined pilot, never scored):**
- `dev/ordinal-degeneracy/results/pilot-curvature-precondition.csv`
- `dev/ordinal-degeneracy/results/pilot-curvature-timing.csv`

**Data (scored track):**
- `dev/ordinal-degeneracy/results/campaign-curvature-scored-smoke20.csv`
  (first 20 cells; merged into, not duplicated in, the final scored file)
- `dev/ordinal-degeneracy/results/campaign-curvature-scored.csv` (450 rows,
  the scored dataset)
- `dev/ordinal-degeneracy/results/scoring-verdict.md` (independent scorer's
  output)

**This report and the check-log:**
- `docs/dev-log/after-task/2026-08-17-ordinal-curvature-multistart-eliminated.md`
- `docs/dev-log/check-log.md` — appended

No `R/`, `src/`, `NAMESPACE`, or test file was touched. No export changed.
No `gllvmTMB()` call behaves differently after this PR than before it.

## 3a. Decisions and Rejected Alternatives

- **Decision: FP denominator excludes the `scale_boundary` stratum
  (`sigma_lambda ∈ {1.2, 2.0}`) from scoring, reported only.** Rationale:
  the adversarial pre-freeze review found that including this stratum in
  the FP-scored pool would have made the zero-FP target **unattainable by
  construction** — the S1 probe had already measured ~10–13% of
  `sigma_lambda = 0.7` fits as genuinely `rel_frob > 10`, so pooling a
  wider, more-contaminated range into a "zero FP, arm-level" denominator
  would guarantee failure regardless of detector quality, an uninterpretable
  null. Carving out `scale_boundary` as reported-but-unscored is what keeps
  the eventual null result honest and interpretable rather than manufactured
  by an impossible target. Rejected alternative: score `scale_boundary` in
  the FP pool anyway and accept a nonzero-FP-by-construction result — 
  rejected because it would have made this task's own null indistinguishable
  from a design artefact, precisely the failure mode the coordinator's
  review process exists to catch.
- **Decision: primary Arm C statistic is the Schur complement
  (`solve(cov.fixed[idx, idx])`), not the naive conditional block
  (`obj$he()` restricted to the loading indices) and not a full-matrix
  inversion (`solve(cov.fixed)` then subset).** Rationale: the naive
  conditional block cannot see a joint loading–cutpoint flat direction
  (eigenvalue interlacing hides it); a full-matrix inversion round-trips
  through the whole, potentially ill-conditioned fixed-effect Hessian,
  amplifying numerical error exactly in the small eigenvalues Arm C targets.
  The Schur-complement route resolves both concerns simultaneously by
  inverting only the small, already-isolated loading submatrix of the
  already-computed `cov.fixed`. Rejected alternative (explicitly proposed by
  the adversarial reviewer): use `obj$he()` as the primary route — rejected
  because it reintroduces the conditional-block defect the same review found
  in a companion finding; kept as a pilot-only cross-check instead.
- **Decision: Arm D scored as a single statistic
  (`obj_spread_per_obs`), not a claimed ratio+absolute pair.** Rationale:
  the package's existing multi-start machinery (`n_init`/`init_jitter`)
  does not expose each restart's own fitted loading matrix, only its
  objective value — building that exposure is new package plumbing outside
  a calibration pre-registration's scope. A secondary, honestly-disclosed
  non-independent companion statistic (`n_modes_frac`) is reported for
  interpretability but not claimed as satisfying the ratio/absolute design
  guard. Rejected alternative: manufacture a second "ratio" derived from
  the same underlying spread to claim guard compliance — rejected as
  cosmetic per the reviewer's own framing.
- **Decision: the three scoring-rule ambiguities the independent scorer
  found are recorded as a post-hoc amendment, never as edits to the frozen
  Scoring rule text.** Rationale: the frozen text is exactly what was
  scored; silently tightening it after seeing the scorer's readings would
  destroy the audit trail that makes the null result admissible. Confidence:
  high — this mirrors `pass-criteria-ordinal.md`'s own established
  correction-notice convention in this programme.

## 4. Checks Run

- **Precondition check** (`campaign-curvature-pilot.R --stage precondition`,
  `OPENBLAS_NUM_THREADS=1`): verified `identical(rownames(fit$sd_report$cov.fixed),
  names(fit$tmb_obj$par))` on a real fit (TRUE; 7 `theta_rr_B` entries,
  matching `rr_theta_len(4,2) = 7`); exercised the `length(idx) == 0` guard
  and positional-name fallback directly (both behave as specified — fallback
  fires cleanly, double-stripped case returns `FALSE`, never `Inf`/`-Inf`);
  confirmed Arm C and Arm D statistics are finite on a real single fit and a
  real 3-restart fit. Output: `dev/ordinal-degeneracy/results/pilot-curvature-precondition.csv`.
- **Timing pilot** (`--stage timing`, 9 cells spanning `sigma_lambda` up to
  8.0 and `n_init = 5`): measured mean 1.69s (single-start) / 32.21s
  (`n_init=5`, weighted toward the pricier `n = 400` cells) per cell.
  Output: `dev/ordinal-degeneracy/results/pilot-curvature-timing.csv`.
- **Smoke check** (`campaign-curvature-scored.R --stage smoke`, interleaved
  first 20 cells across all 5 sub-arms and both `n_init` regimes,
  `mc.cores = 10`): first attempt 8/20 ERROR (`object 'probe' not found`,
  every `transport`/`mixed` cell); root-caused to a lexical-scoping defect
  in a second layer of dynamic function extraction, fixed (rebind `probe`/
  `camp` at true top level), re-run 20/20 OK. Verified: non-empty, all
  Arm C statistics finite, 20/20 distinct `cond_LL` values, all 5 sub-arms
  and both `n_init` values represented.
- **Parallel-scaling divergence check**: naive linear projection ~19s vs.
  actual 85.0s (10-core); re-ran the identical 20 cells with
  `mc.preschedule = FALSE` (81.8s, same ~4x realized speedup) to rule out a
  scheduling/load-imbalance artefact before proceeding — confirmed a
  genuine, roughly stable ~4x parallel efficiency on this machine rather
  than a fixable scheduling issue. Reported to the coordinator before
  committing further compute; coordinator confirmed "just run it" (measured
  ~17–21 min projection stays under the 30-minute D-139 line) rather than
  spending further compute characterising the hardware cause.
- **Full scored run** (`--stage continue`, `OPENBLAS_NUM_THREADS=1`,
  `mc.cores = 10`, run in background with a watchdog polling for
  completion/error/a 35-minute abort condition): 760.7s (12.68 min),
  well under the 35-minute abort line; no abort triggered. Output:
  `dev/ordinal-degeneracy/results/campaign-curvature-scored.csv`, verified
  450/450 rows, `cell_index` 1..450 with no duplicates and none dropped
  (smoke cells merged from `campaign-curvature-scored-smoke20.csv`, not
  re-run), `status == "OK"` throughout, coverage cross-tabulated against
  the frozen Grid table by sub-arm × `n_init` and confirmed to match
  exactly. 12 non-finite `cond_LL`/`min_eig_raw` cells and 4
  `curvature_available == FALSE` cells were individually traced (not
  assumed) to the frozen functional's own designed guard behaviour (a
  non-positive-definite Schur block, or `cov.fixed` itself unavailable),
  matching the mechanism already verified in the pilot — not a harness
  defect.
- **Independent scoring** (`dev/ordinal-degeneracy/results/scoring-verdict.md`,
  a separate agent, no design context, quarantined pilot files excluded):
  cross-checked the scoring script's Arm C/D functionals against the frozen
  document's "Exact functional" text (match confirmed, `degenerate_label`
  vs. `rel_frob > 10` verified with zero mismatches); computed all four
  readings of the threshold-selection ambiguity and confirmed the verdict
  is identical under every one.
- `git status --short` before commit: confirmed only the files listed in
  §3 are new/modified; nothing else in the worktree was touched.

## 5. Tests of the Tests

No `testthat` tests were added or modified (this task is a calibration
campaign and design-doc update, not an implementation change). The
harness's own correctness was exercised the way this project treats a
calibration script: the smoke check is itself the failure-mode probe (it
caught a real, silent-corruption-shaped bug — 8/20 cells returning an
`ERROR` status rather than a plausible-looking wrong number, which is the
better failure mode but still had to be caught by checking *coverage*, not
just row counts, per this project's own house rule "existence is not
validation, exercise a capability"). The parallel-scaling divergence check
is the equivalent probe for the timing estimate: confirmed with a second,
differently-scheduled run rather than accepted on the first measurement.

## 6. Consistency Audit

```sh
rg -n "ordinal_liability_loading|ordinal_loading_runaway_thresh|ordinal_loading_absolute_thresh" R/ docs/design
```
Verdict: unchanged from before this task — both control arguments still
default to `Inf` in `R/diagnose.R`; this task added no new occurrence
anywhere in `R/`, confirming no code path was touched.

```sh
rg -n "dev/ordinal-degeneracy/pass-criteria-curvature" docs/design docs/dev-log
```
Verdict: three references found (FAM-14 row, §8.2a, this after-task
report) — the design-doc trail is internally consistent and points to the
same frozen document.

```sh
rg -c "eliminated" dev/ordinal-degeneracy/pass-criteria-curvature.md docs/design/123-multinomial-structured-surface.md
```
Verdict: both files use the word in the intended sense (candidate
statistics tested and refused), not as a claim about the detection problem
itself being closed.

## 7. Roadmap Tick

N/A — this task does not change `ROADMAP.md`; issue #897 (the detector
gap) remains open, and no capability crossed a roadmap milestone.

## 7a. GitHub Issue Ledger

- **#897** (`ordinal_probit has no degeneracy detector`) — inspected
  (`gh issue view 897`), confirmed OPEN. **Not commented, not closed** by
  this task: both arms tested here failed, so the gap #897 reports is
  unchanged in substance (still 0 working arms for a default fit), and the
  coordinator is opening the PR that will carry this update to the issue
  thread. Seven candidate statistics are now eliminated (§8.2a); the issue
  should stay open pending either a genuinely new information source or a
  fresh dataset for re-testing any of them.
- No other open issue judged relevant to this task's scope.

## 8. What Did Not Go Smoothly

- **A real harness bug reached the smoke stage** (the `object 'probe' not
  found` scoping defect). It was caught because the smoke check verified
  per-sub-arm coverage, not merely a row count or an aggregate status — a
  block-ordered "first 20" (all one sub-arm) would very plausibly have
  missed it, since it happened to affect exactly two of five sub-arms. The
  smoke cell ordering was deliberately interleaved across sub-arms for
  this reason (disclosed as a deviation from a literal reading of "the
  first 20 cells", in service of the check's actual purpose).
- **The pre-pilot cost estimate (28.8 min at 10-core) was wrong**, by
  roughly 10x on the optimistic side — the true throughput, once measured
  with `OPENBLAS_NUM_THREADS=1` correctly pinned, was much faster per-fit
  than the borrowed anchor implied. This was surfaced and corrected in the
  document rather than left standing; the coordinator independently
  confirmed the correction on their side. A second, opposite-direction
  surprise (parallel efficiency measured at ~4x rather than the assumed
  ~10x) partially offset the first, and was investigated with one cheap
  extra diagnostic run before the full campaign was authorised, per this
  project's D-139 discipline ("stop and re-report rather than letting it
  run long").
- **The independent-scoring step found three genuine ambiguities** in the
  frozen Scoring rule text that this task's own drafting missed (a
  threshold-selection operator tension, whether `Inf` may set the
  mechanical threshold, and unaddressed `*_available == FALSE` rows). None
  changed the verdict, but a future campaign in this programme should not
  inherit them silently — the post-hoc amendment records concrete fixes.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss** (TMB likelihood + numerical reviewer, this task's primary role):
the central numerical finding worth carrying forward is that
`sd_report$cov.fixed`'s own block-inverse structure gives the Schur
complement of a parameter block "for free" (`solve(cov.fixed[idx, idx])`),
which is simultaneously cheaper (inverts only a small submatrix) and more
statistically correct (the profiled/marginal curvature, not the naive
conditional block) than the two more obvious routes — `obj$he()` restricted
to the block, or inverting the full fixed-effect Hessian and then
subsetting. This is a reusable pattern for any future curvature-based
diagnostic in this package, independent of whether it ever helps ordinal
degeneracy specifically.

**Rose** (after-task / handoff QA): the two-round adversarial review before
freezing (BLOCK, then a second pass confirming the fixes) is what made this
null admissible — a pre-registration that had shipped with the FP target
still unattainable by construction (the original `scale_boundary`-inclusive
design) would have produced a result indistinguishable from a manufactured
null, and no amount of careful scoring afterward could have rescued that.
The lesson for future campaigns in this programme: an adversarial review
pass on the pre-registration itself, before any fit runs, is worth the
calendar time it costs.

**Fisher** (statistical review persona): the independence precondition
(correlation against `max_loading_unit`) doing real, decisive work here is
worth naming explicitly — a null result on a candidate that turns out to be
`|r| = 0.9` against an already-eliminated statistic would have been
uninformative (just candidate #1 in a thin disguise); confirming `|r| =
0.538` and `-0.452` is what lets this null be read as "two new information
sources genuinely fail" rather than "one failure counted twice."

**Shannon** (cross-team audit persona, invoked informally for the lane/file
hotspot warnings surfaced by the pre-tool-use hook while editing
`docs/design/35-validation-debt-register.md` and `123-multinomial-structured-surface.md`):
both files carry concurrent work on other branches (41 and 1 refs
respectively). This task's edits are append-only, dated, and topically
disjoint from the concurrent branches' visible subject matter (a binomial
FP retune on a different row; an H² gap closure in a different section),
so no merge-conflict risk was taken on faith — but a future session
merging multiple of these branches into `main` should re-check this
specific file for conflicts before assuming a clean fast-forward.

## 10. Known Limitations And Next Actions

- **Both ordinal degeneracy arms (O1/O2) remain disarmed at `Inf`/`Inf`.**
  This task adds evidence, not coverage: a default ordinal fit still gets
  zero working degeneracy detection from this row.
- **Seven candidate statistics are now eliminated for ordinal degeneracy
  detection** (four loading/cutpoint-magnitude statistics, a
  dichotomisation-refit counterfactual, loading-block curvature, and
  multi-start objective disagreement). Per this programme's own
  multiple-testing discipline, none of the seven should be retested on an
  overlapping fit pool. A working detector needs either a genuinely
  different information source again, or a fresh, independently-generated
  dataset to test a new pre-registered candidate against.
- **The honest interpretation, stated precisely:** this task's measurement
  says loading-block curvature (correctly computed as the profiled Schur
  complement) and multi-start objective disagreement do not characterise a
  degenerate ordinal optimum, on the evidence measured here. It does **not**
  say no detector is possible — that would overclaim a much stronger and
  unproven statement from a two-arm negative result.
- **Not done, and explicitly out of scope for this task:** re-calibrating
  binomial's own ~25% false-positive rate (a separate, previously-diagnosed
  gap); any change to `ordinal_liability_loading`'s shipped defaults;
  opening the PR (the coordinator does this); a >=500-fit confirmatory
  campaign (moot, since neither arm cleared even the smaller pre-registered
  pool here).
