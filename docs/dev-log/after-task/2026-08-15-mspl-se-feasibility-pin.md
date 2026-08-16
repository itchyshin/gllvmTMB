# After Task: LA-MSPL SE feasibility pin (not admitted)

**Branch**: `cursor/mspl-se-feasibility-pin`
**Date**: `2026-08-15`
**Roles (engaged)**: Ada / Gauss / Noether / Curie / Fisher / Rose / Shannon / Melissa
**Lane LOOP**: `docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/`

```text
🎯 GOAL
Solo: Cursor
Deliverable: binary SE teacher + local se=TRUE feasibility pin for Bernoulli-logit and Poisson
HEADLINE: learn SE from the Codex binary lane; pin whether a named curvature construction can be formed; do not absorb; do not call it covered
DEFER: admit · NEWS covered · public vcov/confint · NB1/NB2/beta/Tweedie · gaussian SE · profile/bootstrap/sandwich
```

## 1. Goal

Name one internal, non-exported SE construction for LA-MSPL on
Poisson and Bernoulli-logit, and measure whether it can be *formed*.
Public `se = TRUE` stays withheld. Nobody is admitted.

## 2. Implemented

- Teacher extract from `git -C` on
  `codex/lane-b-mspl-interval-feasibility` @ `e91c7b7c`. No helper
  copy.
- Estimand pick Q3 = (c): both numerical Hessians.
- New unexported `R/mspl-curvature-pin.R`:
  `.gllvmTMB_mspl_curvature_pin()`. \(Q_P\) = `fit$tmb_obj`;
  \(Q_0\) = `fit$mspl$unpenalized_tmb_obj`, evaluated not optimised.
  `stats::optimHess` + existing TMB checkpoint restore. Non-PD
  retained unrepaired.
- Public door unchanged. `R/fit-multi.R` withholding untouched.
  Poisson registry still `planned`. No `src/` edit.

### Availability pin (one tiny cell each; not a campaign)

| Family | Tape | Status | min eigenvalue |
|---|---|---|---|
| Bernoulli logit | \(Q_P\) | `available` | 0.226 |
| Bernoulli logit | \(Q_0\) | **`non_pd`** (retained) | −0.774 |
| Poisson log | \(Q_P\) | `available` | 3.300 |
| Poisson log | \(Q_0\) | `available` | 2.473 |

This is **not** coverage and **not** “MSPL has standard errors.”
The Bernoulli \(Q_0\) non-PD row is the binary-lane lesson landing
on this fixture: penalty-off curvature can fail while the penalised
tape looks usable.

## 3. Files Changed

- `docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/` (new kit)
- `docs/dev-log/research/2026-08-15-mspl-binary-se-teacher.md`
- `docs/dev-log/research/2026-08-15-mspl-se-estimand-pick.md`
- `docs/dev-log/research/2026-08-15-mspl-next-se-ultra-plan.md`
- `docs/dev-log/research/_sweep-{brain,codex-interval,git,shannon}-mspl-next.md`
- `tests/testthat/test-mspl-bernoulli-se-feasibility.R` (new)
- `tests/testthat/test-mspl-poisson-se-feasibility.R` (new)
- `R/mspl-curvature-pin.R` (new)
- this after-task; Melissa plan-actual; check-log; lane-split;
  morning brief `docs/dev-log/handover/2026-08-16-cursor-handover-se-pin.md`

No NEWS. No `man/*.Rd`. No ROADMAP tick. No `src/gllvmTMB.cpp`.
No `R/fit-multi.R`. No `R/mspl.R`. No `R/mspl-registry.R`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** both Hessians, internal only (G0 Q1=a, Q2=a, Q3=c).
- **Rationale:** smallest pair the binary lane actually formed;
  sandwich blocked; profile too expensive for the 30-minute budget.
- **Rejected:** public `se=TRUE`→`sdreport()`; `vcov()`/`confint()`;
  Codex helper paste; sandwich; profile; bootstrap; jackknife;
  Gaussian SE; probit/cloglog (D-135); admit; NEWS covered.
- **Confidence:** high that the construction can be *named and
  formed* on these two cells. Zero confidence that the numbers are
  calibrated.

## Mathematical Contract

| Symbol | R / TMB | Meaning |
|---|---|---|
| \(Q_P(\theta)\) | `fit$tmb_obj`, `estimator_id = 1` | active penalised Laplace NLL |
| \(Q_0(\theta)\) | `unpenalized_tmb_obj`, `estimator_id = 2` | penalty-off Laplace NLL at the MSPL point |
| pin SE | \(\sqrt{\mathrm{diag}((\nabla^2 Q)^{-1})}\) when PD | availability diagnostic, not Wald inference |
| GLM-outer atom | unchanged | **not** \(I_{LA}(\beta)\) |
| Poisson \(c\) | still `1` | unpinned; does not vanish with \(N\) |

## 4. Checks Run

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
# RED before R/mspl-curvature-pin.R:
#   test-mspl-bernoulli-se-feasibility.R  9 pass / 1 error
#     (object '.gllvmTMB_mspl_curvature_pin' not found)
#   test-mspl-poisson-se-feasibility.R    14 pass / 1 error
#     (same)

# GREEN after:
#   test-mspl-bernoulli-se-feasibility.R  PASS 24
#   test-mspl-poisson-se-feasibility.R    PASS 29
#   test-mspl-poisson-public-door.R       PASS 6
#   test-mspl-registry.R                  PASS 26
```

```sh
rg -n 'sd_rep <- if \\(identical\\(estimator, "mspl"\\)\\)' R/fit-multi.R
# R/fit-multi.R:6423  unchanged

rg -n 'status = "planned"' R/mspl-registry.R
# Poisson still planned

rg -n 'gllvmTMB_mspl_curvature_pin' NAMESPACE
# no export
```

Not run: `devtools::test()`, `R CMD check`, pkgdown, Totoro, NEWS,
`devtools::document()`.

## 5. Tests of the Tests

- Public-fence tests were already green before the pin existed
  (`se=TRUE` withholds; `vcov`/`confint`/`standard_errors` refuse;
  Poisson `planned`). That is the contract, not a weakened pin.
- Pin tests were RED on a missing object, then GREEN after
  `R/mspl-curvature-pin.R`.
- Opposite-tape poison: `estimator_id` 1 vs 2 and unequal NLLs.
- Unexported: name absent from `getNamespaceExports("gllvmTMB")`.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `fit-multi.R` MSPL `sd_rep <- NULL` | PASS — untouched |
| Poisson `status = "admitted"` | PASS — still `planned` |
| NEWS MSPL SE / “covered” | PASS — NEWS untouched |
| Codex `R/mspl.R` helpers copied | PASS — new file, original names |
| `src/gllvmTMB.cpp` this lane | PASS — not edited |
| public `vcov` on MSPL | PASS — still refused |
| D-135 probit/cloglog pin | PASS — logit only |
| repo-root `LOOP/` | PASS — not written |

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is an internal
availability pin, not a user-facing bug.

## 8. What Did Not Go Smoothly

#978 CI was red on two tests (Poisson door vs provenance abort;
NB1 source pin under `R CMD check`). Those fixes were already on
the tapes tip (`0df6ab30`) before this lane cut. The SE branch is
stacked on that tip until #978 squash-merges.

## 9. Team Learning

**Ada.** “Allow SE” is not a switch. The withholding branch is the
product; the pin is a private diagnostic.

**Gauss.** Bernoulli \(Q_0\) went non-PD on the first tiny logit
cell. That is a finding, not a defect to repair.

**Noether.** The pin SE is not \(I_{LA}(\beta)\) and not an ML Wald
SE. Poisson \(c=1\) still scales the penalty.

**Curie.** RED-then-GREEN on the two new files. Related public-door
and registry files stayed green.

**Fisher.** Availability only. One cell is not a campaign. The
Bernoulli non-PD row stays in the denominator.

**Rose.** No admit, no NEWS covered, no public inference, no Codex
absorb. PASS.

**Shannon.** WIP still includes #972–#976 (do not merge) plus #978
and this PR. Soft cap remains exceeded; next act is merge #978
then this PR, not more MSPL PRs.

**Melissa.** Plan-actual records Q1/Q2/Q3 lock and the stacked-on-
tapes base.

## 10. Known Limitations And Next Actions

- One cell per family. No all-zero / large-μ Poisson grid.
- No coverage, width, or SE/SD gate.
- Poisson still `planned`. Bernoulli still `admitted` for the
  *point*, not for this SE.
- Next human act: squash-merge #978 when CI green, then this PR
  when CI green. Do not admit. Do not merge #972–#976.
