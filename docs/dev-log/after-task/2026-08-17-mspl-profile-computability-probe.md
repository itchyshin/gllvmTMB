# After Task: internal MSPL profile-COMPUTABILITY probe (re-port; UNMERGED, awaiting G0)

**Branch**: `claude/mspl-interval-computable-pin`
**Date**: `2026-08-17`
**Roles (engaged)**: Ada / Emmy / Gauss / Curie / Fisher / Rose / Shannon / Melissa
**Workspace**: worktree `/private/tmp/gllvmtmb-interval-computable`
**State**: **PR open, NOT merged.** Blocked on a maintainer G0 — see §7.

## 1. Goal

Answer Shinichi's question — *"can we make it at least interval feasible / computable (not
calibrated)?"* — for binary LA-MSPL, and settle whether Kosmidis & Firth (2021)'s coverage caveat
extends to profiles.

## 2. Implemented

**(a) The KF2021 verdict — landed, [#1090](https://github.com/itchyshin/gllvmTMB/pull/1090).**
`docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md`. Verdict: the caveat
**does** extend to profiled penalised likelihood (§2.2, p. 5, read directly).

**(b) The probe — this PR, unmerged.** `.gllvmTMB_mspl_profile_feasibility()`,
`.gllvmTMB_mspl_profile_threshold_diagnostic()`, helper `.gllvmTMB_mspl_nlminb()` re-ported into
`R/mspl.R` from `claude/mspl-b0-prereqs` (PR #981). Purely additive. **No `src/` change** — they
read only `obj$env$data$estimator_id`, and main's C++ already computes `mspl_c_n` equivalently to
multiplier 1.0, so the branch's `mspl_c_n_multiplier` hook was correctly omitted.

Fence made mechanical, not conventional: `calibrated = FALSE`, `public_confint = "refused"`,
`coverage_claim = "none"`; endpoints named `*_endpoint` / `diagnostic_*` so no tidier can lift them
as `conf.low`/`conf.high`; an **enforced** binomial logit/probit/cloglog family allow-list with typed
abort `gllvmTMB_mspl_profile_family`, mirroring `.gllvmTMB_mspl_curvature_pin()`; the
softness/curvature/separation **admission gate deliberately absent and documented as such**.

## 3. Files Changed

- `R/mspl.R` (+~450: three functions, fence header, family fence, no-coverage markers)
- `tests/testthat/test-mspl-api.R` (+~280: ported cases + no-coverage + typed-refusal + family fence)
- `docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md` (in #1090)
- `docs/dev-log/check-log.md`, `docs/dev-log/plan-actual/…`, this file

No `src/`, NAMESPACE, `man/`, NEWS, `_pkgdown.yml`, or validation-register change.

## 3a. Decisions and Rejected Alternatives

- **Decision:** re-port, do not rebuild. **Rationale:** the instrument already existed off-main; the
  prior-work sweep found it. **Rejected:** writing a new profile walker (the plan's HEADLINE forbade
  it). **Confidence:** high.
- **Decision:** R-side only, omit the `src/` `c_n` hook. **Rationale:** measured unnecessary.
  **Rejected:** rebasing all 435 stale commits of #981. **Confidence:** high.
- **Decision:** enforce the family fence in code, not prose. **Rationale:** the cited authority is
  binomial-only, so on a gaussian fit `coverage_claim = "none"` would rest on an inapplicable
  citation. **Rejected:** documenting binomial-only and letting other families run.
- **Decision:** leave the PR **unmerged** pending G0. **Rationale:** §7. **Rejected:** merging on
  chat authority. **Confidence:** high.

## 4. Checks Run

```sh
Rscript -e 'devtools::load_all("."); testthat::test_local(filter = "mspl-api")'
# 19 tests / 292 expectations / 0 failures (pre-fix commit 6e8bb37e)
# re-run after the review edits: 0 failures
R CMD build . && R CMD check --as-cran --no-manual gllvmTMB_0.7.0.tar.gz
# Status: 1 NOTE ; checking tests ... [337s/392s] OK       (at 6e8bb37e)
```

The `--as-cran` was built **with** vignettes, which confirms the 2 WARNINGs carried in this session's
earlier runs were `--no-build-vignettes` artifacts, not defects. **Honest limitation:** that check
ran at `6e8bb37e`, *before* the review edits; the post-edit state is covered by the test re-run only,
not by a second full check.

## 5. Tests of the Tests

- The strongest inherited case makes the penalty-off tape's `$fn` `stop()`, so the test fails if the
  probe ever profiles the unpenalised objective.
- `expect_identical(.gllvmTMB_profile_tmb_checkpoint(fit$tmb_obj), checkpoint)` fails if tape state
  leaks.
- The no-coverage test fails if any marker flips or if `conf.low`/`conf.high` ever appear.
- `expect_identical(still_truncated$trace, narrow$trace)` fails if `max_widen_rounds = 0L` stops
  being inert — i.e. if widening becomes silent.
- The family test fails if a non-binomial fit stops being refused.

## 6. Adversarial review (Opus) — findings acted on

Verdict **DO NOT SHIP** on ownership; code discipline judged sound (no coverage leak in the markers,
genuinely unexported, no fitted map or tuned quantity). Fixed in response:

1. **An orphaned comment fragment** — the port had truncated *"a finite trace establishes neither
   calibrated standard errors nor confidence-interval coverage"* to its last line, leaving the
   negation amputated above a 380-line profile computer where it read as a heading. Full sentence
   restored.
2. **The fence header documented the wrong function** — it had been inserted between the `nlminb`
   docstring and `nlminb` itself, so the entire fence annotated a three-line wrapper while the probe
   had none. Moved.
3. **A false claim** that the probe is *"an instrument the fork can be measured with"* — it
   hard-refuses the penalty-off tape, so it implements Design 125's **fork A** and structurally
   cannot run B or C. Corrected in the header and in the cross-lane note.
4. **Missing enforced family fence** (5 of 6 admitted families would have run with zero evidence).
5. **Admission-gate absence undocumented** — now stated as a scope decision.
6. **Two falsified documents** — the plan-actual and the directed cross-lane note said this lane had
   stood down and offered the instrument to another lane. Both corrected in this PR rather than left
   standing; the cross-lane note now tells that lane what actually exists so they do not build it
   twice.

Optional suggestions not taken this pass (recorded, not lost): rename `level` → `chisq_level`;
rename `nuisance_reoptimized` → `nuisance_converged` (it records convergence, not movement);
tighten a retry assertion from `>= 1L` to `>= 2L`.

## 7. 🔴 Why this is UNMERGED — the gate that is not the lane's to open

Chat authority exists (*"a pin — build it now"*, *"go ahead"*), but three **written** fences do not
have a recorded G0, and the repo is the message bus:

- **D-149:** *"Codex Lane B remains the binomial SE owner. Do not rebuild, reassign, or absorb it."*
  This is a copy of `codex/lane-b-mspl-interval-feasibility`'s work landing from a Claude lane, on
  binomial.
- **`docs/dev-log/handover/2026-07-25-active-lane-split.md`** marks that branch **PROTECTED**, *"No
  absorb/rebase/merge"*.
- **Design 125 G4c** (SIGNED): *"no live profile impl / smoke until fork G0."*
- And the pattern file this mirrors, `R/mspl-curvature-pin.R:15`, says *"Do not copy Codex lane-b
  helpers. Do not export."* — the second half was obeyed, the first was not.

Also honestly noted: D-157 is **not** violated on its literal text (no campaign, no Totoro,
`MSPL-04` still `blocked`, no public door), but the object computed is a nominal-`level` penalised
profile bracket — Design 125's fork A. What separates it from the parked construction is labelling
and access, not content. That is a defensible place to stand *only* if the maintainer says so.

**Paste-ready G0 if the answer is yes:** *"G0: land the binomial profile-computability probe on
`main` from the Claude lane. D-149's Lane-B clause, the PROTECTED marker on
codex/lane-b-mspl-interval-feasibility, and Design 125 G4c are waived for this internal, unexported,
uncalibrated probe only — not for any interval construction or public door."*
**If the answer is no:** close the PR; the measurement in the check-log stands and Design 125 can
take the instrument.

## 8. Standing fences unchanged

`MSPL-04` `blocked`. `Q_0` the paper-aligned SE target (D-149, #1061). No public `se=TRUE`,
`vcov()`, `confint()`. Design 118 not reopened. #981 still open for its `src/` work; #1077 not
undrafted.
