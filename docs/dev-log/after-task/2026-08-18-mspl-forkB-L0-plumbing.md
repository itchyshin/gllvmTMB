# After Task: Design 125 fork B — internal Q_0 profile plumbing (L0)

**Branch**: `cursor/mspl-forkB-l0-20260818`
**Date**: `2026-08-18`
**Roles (engaged)**: Ada / Emmy / Curie / Fisher / Rose / Shannon
**Workspace**: `~/local-scratch/lanes/gllvmTMB-mspl-forkB-L0`
**State**: plumbing shipped under signed G0; public doors closed.

## 1. Goal

Unlock Design 125 **fork B** as an internal computability instrument:
unpenalised Laplace profile (`fit$mspl$unpenalized_tmb_obj`,
`estimator_id = 2`) evaluated at the MSPL point with the nuisance held
fixed. The probe stays unexported, `calibrated = FALSE`, and
`public_confint = "refused"`.

## 2. Implemented

`.gllvmTMB_mspl_profile_feasibility()` now takes `tape = c("Q_P", "Q_0")`.
Default `Q_P` is the existing penalised walk (fork A, nuisance
re-optimised). `tape = "Q_0"` evaluates the penalty-off tape at fixed
MSPL nuisance and never calls `nlminb`.

Returned fields that keep the two tapes honest:

- `tape`, `design_125_fork` (`"A"` / `"B"`)
- `nuisance_treatment` (`"reoptimized"` / `"fixed_at_mspl"`)
- `reference_is_maximum` (`TRUE` on `Q_P`; `FALSE` on `Q_0`, because
  the MSPL point maximises \(Q_P\), not \(Q_0\))
- `calibrated = FALSE`, `public_confint = "refused"`,
  `coverage_claim = "none"` on both tapes

`.gllvmTMB_mspl_profile_threshold_diagnostic()` accepts both of the
probe's own `objective_source` strings and passes the tape fields
through. Fork C (`Q_C`) is a typed refusal.

## 3. Files Changed

- `R/mspl.R` — `tape` argument; fork-B evaluate path; honesty fields
- `tests/testthat/test-mspl-api.R` — Q_P field pins + Q_0 walk / refusal
- `docs/dev-log/decisions.md` — 2026-08-18 G0
- `docs/dev-log/check-log.md` — this sitting
- this file

No `src/`, NAMESPACE, `man/`, NEWS, `_pkgdown.yml`, ROADMAP, or
validation-register change. `LOOP/` left untouched (stale Poisson
REPLACE kit; not this lane's to rewrite). Design 125 stub not edited
(owned by `claude/lane-mspl-profile-led-ci`); the G0 lives in
`decisions.md`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** extend the existing probe with `tape=`, do not write a
  second walker. **Rationale:** fork A is already the bounded bisection
  instrument; fork B differs only in objective and nuisance treatment.
  **Rejected:** a new exported helper or a #1077 undraft. **Confidence:**
  high.
- **Decision:** hold the nuisance fixed at the MSPL estimate; do not
  re-optimise \(Q_0\). **Rationale:** that is the G0 estimand; a
  re-optimised \(Q_0\) walk would be a different (unauthorised) fork.
  **Rejected:** profiling \(Q_0\) with free nuisance. **Confidence:** high.
- **Decision:** leave MSPL-04 `blocked` and NEWS untouched.
  **Rationale:** hard OUT. **Rejected:** a `partial` register flip for
  "computable on Q_0". **Confidence:** high.

## 4. Checks Run

```sh
Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-mspl-api.R")'
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 352 ]
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="mspl|estimator-provenance|curvature")'
# [ FAIL 0 | WARN 0 | SKIP 17 | PASS 2313 ]   (all 17 skips pre-existing family-door skips)
gh pr view 1077 --json isDraft   # true
rg -n 'MSPL-04' docs/design/35-validation-debt-register.md
# still `blocked`
```

Full `--as-cran` deferred to CI. No NEWS edit. No register flip.

The count moved 330 → 352 in a second pass on this branch, which added the
four cases in §5's last block. The broader `mspl|estimator-provenance|curvature`
sweep is new in that pass too: the `tape` argument is additive, but
`estimator_id` and the Q_P/Q_0 tape pair are read by the curvature-pin and
provenance suites, so "additive" was worth checking rather than asserting.

## 5. Tests of the Tests

- The Q_0 walk replaces `fit$tmb_obj$fn` with `stop()` and mocks
  `.gllvmTMB_mspl_nlminb` to `stop()`, so the test fails if fork B
  either walks the penalised tape or re-optimises.
- A finite Q_0 trace row is re-evaluated with the stored
  `unpenalized_tmb_obj$fn` at the MSPL nuisance; a drifted nuisance
  would miss.
- `centre_status = "matched"` plus `reference_is_maximum = FALSE` fails
  if someone later "repairs" the by-construction centre into an
  agreement check.
- Typed refusals for `tape = "Q_C"`, a non-character tape, a missing
  penalty-off objective, and a re-labelled gaussian fit fail if the
  fences drop.
- Existing Q_P cases still assert `objective_source` on the penalised
  tape with the penalty-off `$fn` mocked to `stop()`.

Four cases added in a second pass, each covering a way the unlock could be
wrong that nothing above would have caught:

- **Fork B differs from fork A.** Same target, same estimate, same threshold,
  different endpoints. Without this, `tape = "Q_0"` could be new field names
  over the old walk and the whole suite would still pass. Both reference
  values are also cross-checked against numbers the fit recorded
  independently at fitting time (`opt$objective`, `mspl$unpenalized_nll`).
- **The default is byte-for-byte fork A.** `implicit$trace` is
  `expect_identical` to `explicit$trace` at `tape = "Q_P"`, so no caller that
  predates the argument moves.
- **A mislabelled penalty-off slot is refused.** Present-but-wrong
  (`estimator_id = 1` sitting in `unpenalized_tmb_obj`) is the dangerous
  case: without the id check the probe would walk it and still report the
  penalty-off `objective_source`. The sibling case only covers a NULL slot.
- **The diagnostic accepts two sources, not anything.** Widening it from one
  accepted `objective_source` to two must not have widened it to "any list
  with the right names"; a foreign source and a tape-stripped probe both
  stay typed refusals.

## 6. Consistency Audit

| pattern | verdict |
|---|---|
| `MSPL-04` still `blocked` in the register | hold |
| `calibrated = FALSE` / `public_confint = "refused"` / `coverage_claim = "none"` still written on both tapes | hold |
| no `conf.low` / `conf.high` in the probe or its tests | hold |
| #1077 remains draft | hold |
| no NEWS `covered` in this sitting | hold |

## 7. Roadmap Tick

N/A — no ROADMAP row changed. Internal probe only.

## 7a. GitHub Issue Ledger

No relevant open issue for this plumbing unlock; no new issue created.
#1077 inspected and left draft. MSPL-04 left `blocked`.

## 8. What Did Not Go Smoothly

Sibling Opus already had the `R/mspl.R` unlock dirty in this worktree
and no PR. This sitting finished tests and fence docs on that work
rather than rewriting the walker. `LOOP/` in the worktree is still the
closed Poisson REPLACE kit; left alone.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** G0 is a computability unlock, not a fork pick. Shipping the
instrument without a campaign, a register flip, or an undraft is the
whole job.

**Emmy.** One function, one `tape` argument, two honest field sets.
A second entry point would have invited a public-looking name.

**Curie.** The strongest Q_0 test is negative: penalised `$fn` and
`nlminb` both `stop()`. A happy-path "it returned a list" test would
have accepted a silent re-optimisation.

**Fisher.** `objective_delta` on `Q_0` is a level-set, not an LR
statistic. `reference_is_maximum = FALSE` is the field that says so;
do not read a crossed status as coverage.

**Rose.** The 2026-08-17 fork-A header claimed the probe "structurally
cannot run fork B". That sentence is now false and was rewritten in
place. The no-coverage markers were left mechanical.

**Shannon.** Named this lane `cursor/mspl-forkB-l0-20260818`. Did not
touch Design 125 (claude-owned), #1077, or `isdm-package-recovery`.
Staged by explicit path.

## 10. Known Limitations And Next Actions

- L0 does **not** require a finite `Q_0` crossing. L1 smoke may measure
  whether the level-set actually brackets.
- Fork C is still unimplemented.
- Non-binomial families remain refused on both tapes.
- Public `se` / `vcov` / `confint` remain refused. MSPL-04 remains
  `blocked`.
