# After Task: Design 125 fork B G0 + `objective=` selector (reconciles #1126)

**Branch**: `cursor/g0-unlock-design125-forkB`
**Date**: `2026-08-18`
**Roles (engaged)**: Ada / Emmy / Curie / Fisher / Rose / Shannon
**Workspace**: `~/local-scratch/lanes/gllvmTMB-g0-unlock-20260818`
**State**: signed G0 + authorising code shipped together; #1126 superseded; public doors closed.

## 1. Goal

Commit the uncommitted 2026-08-18 fork-B G0 (decision text +
`objective = c("penalised", "unpenalized")` selector) that sat dirty on
this worktree, and reconcile it with open #1126 rather than dual-merge
two L0 APIs.

## 2. Implemented

`.gllvmTMB_mspl_profile_feasibility()` now takes the signed selector
`objective = c("penalised", "unpenalized")`. Default `"penalised"` is
the existing fork-A walk (byte-identical). `"unpenalized"` walks
`fit$mspl$unpenalized_tmb_obj` at the MSPL point with the nuisance held
fixed.

`tape = "Q_P"` / `"Q_0"` is accepted as the existing curvature-pin
synonym so #1128 L1 callers keep working. Disagreeing
`objective`/`tape` pairs are a typed refusal.

Returned honesty fields on both arms:

- `objective`, `tape`, `design_125_fork` (`"A"` / `"B"`)
- `nuisance_treatment` (`"reoptimized"` / `"fixed_at_mspl"`)
- `reference_is_maximum` (`TRUE` on fork A; `FALSE` on fork B)
- `calibrated = FALSE`, `public_confint = "refused"`,
  `coverage_claim = "none"`

**Mathematical contract:** no public API / likelihood / grammar / family
change. Internal probe only. Fork B is a fixed-nuisance one-dimensional
slice of \(Q_0\), not a nuisance-maximised profile.

## 3. Files Changed

- `R/mspl.R` — selector + fork-B evaluate path + honesty fields
- `tests/testthat/test-mspl-api.R` — fork-B walk, synonym, distinct-measurement, refusals
- `docs/dev-log/decisions.md` — 2026-08-18 G0
- `docs/dev-log/check-log.md` — this sitting
- `dev/mspl-fork-b-l0-smoke.R` — local smoke only
- this file

No `src/`, NAMESPACE, `man/`, NEWS, `_pkgdown.yml`, ROADMAP, register,
or `isdm-package-recovery` change. #1077 left draft.

## 3a. Decisions and Rejected Alternatives

- **Decision:** ship the signed G0 and the authorising code in one PR.
  **Rationale:** sibling recommendation; a docs-only G0 plus a
  `tape=`-only L0 would have left the named selector uncommitted.
  **Rejected:** merging #1126 as-is and following up. **Confidence:** high.
- **Decision:** keep `tape=` as a synonym, not a rename. **Rationale:**
  #1128 already calls `tape = "Q_0"`. **Rejected:** `objective=` only,
  which would have broken L1. **Confidence:** high.
- **Decision:** close #1126 as superseded rather than dual-merge.
  **Rationale:** same estimand, same files, conflicting G0 wording.
  **Rejected:** two L0 PRs. **Confidence:** high.
- **Decision:** leave #1129's Design 125 / ADEMP / D-159 cascade as a
  separate docs PR. **Rationale:** those files are not this unlock.
  **Rejected:** folding #1129 into this PR. **Confidence:** medium.

## 4. Checks Run

Recorded in `docs/dev-log/check-log.md` (this sitting). Focused
`test-mspl-api.R` plus `gh pr view 1077 --json isDraft` and the
MSPL-04 blocked pin. Full `--as-cran` deferred to CI.

## 5. Tests of the Tests

- Fork B replaces penalised `$fn` and mocks `nlminb` to `stop()`, so a
  silent re-optimisation or a penalised walk fails.
- A finite Q_0 row is re-evaluated with the stored
  `unpenalized_tmb_obj$fn` at the MSPL nuisance.
- Fork A and fork B must return different endpoints from the same
  target, estimate, and threshold; both reference values are
  cross-checked against `opt$objective` and
  `mspl$unpenalized_nll_at_estimate`.
- Default trace is `identical` to explicit `objective = "penalised"`
  and to `tape = "Q_P"`.
- `objective = "unpenalized"` and `tape = "Q_0"` traces are identical.
- Mislabelled `estimator_id = 1` in the penalty-off slot is refused.
- Diagnostic widening accepts two sources, not an arbitrary list.
- Disagreeing `objective`/`tape` is a typed refusal.

## 6. Consistency Audit

| pattern | verdict |
|---|---|
| `MSPL-04` still `blocked` | hold |
| `calibrated = FALSE` / `public_confint = "refused"` / `coverage_claim = "none"` on both arms | hold |
| no `conf.low` / `conf.high` | hold |
| #1077 remains draft | hold |
| no NEWS `covered` | hold |
| no Totoro / no public se | hold |

## 7. Roadmap Tick

N/A — no ROADMAP row changed. Internal probe only.

## 7a. GitHub Issue Ledger

No relevant open issue for this unlock; no new issue created.
#1077 inspected and left draft. #1126 closed as superseded once this
PR is up. MSPL-04 left `blocked`.

## 8. What Did Not Go Smoothly

Three parallel 2026-08-18 agents wrote overlapping G0s: this dirty
`objective=` unlock, #1126 `tape=` L0, and #1129 docs-only G4c. The
named selector was the one that sat uncommitted. Reconcile chose one
code PR and left the design-doc cascade on #1129.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Ship the signed selector and the code together; do not leave a
G0 sitting dirty while a synonym-only L0 races to merge.

**Emmy.** One function, two argument names that resolve to one pair of
tapes. A second entry point would have invited a public-looking name.

**Curie.** The load-bearing tests are negative (penalised `$fn` /
`nlminb` both `stop()`) and comparative (fork B endpoints differ from
fork A). A happy-path "it returned a list" test would have accepted a
relabelling.

**Fisher.** `objective_delta` on fork B is a level-set, not an LR
statistic. `reference_is_maximum = FALSE` is the field that says so.

**Rose.** The 2026-08-17 header claimed the probe "structurally cannot
run fork B". That sentence is now false and was rewritten in place.

**Shannon.** Named this lane `cursor/g0-unlock-design125-forkB`. Did not
touch #1077, Totoro, or `isdm-package-recovery`. Staged by explicit
path. Commented #1126 / #1129 rather than silently overlapping
`decisions.md`.

## 10. Known Limitations And Next Actions

- L0 does not require a finite Q_0 crossing. L1 smoke (#1128) measures
  whether the level-set actually brackets; it already calls `tape = "Q_0"`.
- Fork C is still unimplemented.
- Non-binomial families remain refused on both arms.
- Public `se` / `vcov` / `confint` remain refused. MSPL-04 remains
  `blocked`.
- #1129 still owns the Design 125 / ADEMP / D-159 docs cascade and
  will need a `decisions.md` rebase after this G0 lands.
