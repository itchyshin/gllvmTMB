# After-task — L1 local coverage smoke harness for MSPL profile fork B (scaffold)

**Date:** 2026-08-18
**Lane:** `cursor/mspl-forkB-l1-smoke-20260818` @
`~/local-scratch/lanes/gllvmTMB-mspl-forkB-L1`
**Platform:** cursor. **Base:** `origin/main` @ `25cfa0b7`.
**Design:** `docs/design/125-mspl-profile-led-intervals.md`
**Pre-registration:** `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`
(ADEMP P1–P3 and the P5 **L1** gate row)

## Headline

**The L1 gate was NOT run, because L0 has not landed.** What landed instead is
the harness that will run it, with its statistics tested and its fixture cells
measured on real fits. The harness reports `L1_STATUS: NOT-RUN` today and says
why; it claims no PASS and no FAIL.

## Scope

| Item | State |
|---|---|
| L1 coverage verdict | **NOT-RUN** — no coverage number of any kind was produced |
| Fork-B profile door (L0) | **Not on any ref.** Sibling lane `cursor/mspl-forkB-l0-20260818` exists as a branch name at `origin/main` with zero commits |
| Fork choice (G4c FORK-DEFER) | **Untouched.** This lane does not pick A/B/C and did not implement a door |
| `#1077` | **Still draft.** Not touched, not undrafted |
| Register **MSPL-04** | **Still `blocked`.** Not touched |
| Public `se` / `vcov` / `confint` | **Still refused.** No `R/` or `src/` file was modified |
| T\* (Totoro) thresholds | **Still open.** Nothing here freezes them, and the harness has no cluster path |
| Compute | **Local only** (D-50). Total wall time under 3 minutes |

## What landed

| File | Role |
|---|---|
| `dev/mspl-forkB-l1-lib.R` | Pure functions: frozen cells and seeds, DGP, R-SAT screen, E2 sign anchor, refusal-priced coverage arithmetic, Wilson bands, the frozen L1 gate, and a mock rehearsal door |
| `dev/mspl-forkB-l1-coverage-smoke.R` | The runner: door resolution, fixture calibration, budget projection, the replicate loop, and the verdict block |
| `tests/testthat/test-zz-mspl-forkB-l1-gate.R` | 55 assertions on the gate arithmetic, on synthetic outcome tables — no fitting, no door |

Nothing in `R/`, `src/`, `NAMESPACE`, `NEWS.md`, or the register changed.

## The gate, as implemented

L1 is frozen by G4d (THRESHOLDS-SIGN-NOW): on ≥1 anchor cell with
`n_rep ∈ [50, 100]`, the effective-coverage Wilson band must not be entirely
below 0.80, availability must be ≥0.90, and refusal must be ≤0.15 — with
refusals priced **into** the coverage denominator, which is the SIGNED
fail-closed default from ADEMP P1.

Three decisions in the implementation are worth naming because a later reader
could otherwise mistake them for arbitrary:

**Refusal pricing is the anti-gaming rule, and it is tested as such.** The test
suite pins the case that motivates it: 40 returned intervals that all cover,
plus 10 refusals, reads as conditional coverage 1.00 and effective coverage
0.80. Design 118's DEV-11/DEV-12 lesson is that a construction which refuses
the hard cells can look calibrated on the survivors, so the gate is evaluated
on the priced number.

**Availability excludes R-SAT but coverage still prices it.** Saturation is a
property of the data, not a failure of the profile path, so a saturated trait
column is not scored against availability — but it is still non-coverage for
the claim.

**"Refuse everything" is not an escape hatch.** A unit is reported
`NOT-EVALUABLE` only when the door refused every replicate with the single
structural code `R-ENV` (target not admitted at all). Any mixture of codes, or
any `R-NAVL`-only sweep, is a **FAIL**. `NOT-EVALUABLE` is never a pass.

## Measured today (real fits, no coverage claim)

Fixture calibration at the frozen cells, Bernoulli logit,
`latent(d = 1, unique = FALSE)`, `estimator = "mspl"`, `se = FALSE`, seed
818001:

| Cell | n_site | T | realised prevalence | per-trait range | saturated columns | point fit |
|---|---|---|---|---|---|---|
| `anchor` | 80 | 8 | 0.502 | 0.44–0.59 | 0 | converged, 1.96 s |
| `small` | 40 | 4 | 0.500 | 0.33–0.65 | 0 | converged, 5.36 s |
| `neartail` | 80 | 8 | 0.134 | 0.06–0.24 | 0 | converged, 2.94 s |

The anchor cell sits where the pre-registration asks it to (π ≈ 0.5, largest
local n) and the near-tail cell reaches 0.134 without saturating any column at
this seed. Point-fit wall time is small but **not** monotone in cell size —
the 40×4 cell took longer than the 80×8 cell here, which is optimiser-path
variance across seeds, so the runner projects its budget from measured
calibration rather than from cell size.

**A separate probe of the landed fork-A door** (`.gllvmTMB_mspl_profile_feasibility`,
penalised tape) measured 6.4 s per coordinate at 40×4 and 16.7 s at 80×8, both
returning `centre = matched` with both sides crossed. If fork B costs the same
order, the anchor cell at `n_rep = 50` and E1 only projects to roughly 2 hours
locally; at `--cells=small` it is minutes. This is a **budget estimate from
fork A**, not a fork-B measurement and not a coverage result.

## Two findings the L0 lane should know

**Fork A structurally cannot serve E2.** `.gllvmTMB_mspl_profile_feasibility()`
requires `names(fit$opt$par)[which] == "b_fix"` and raises
`gllvmTMB_mspl_profile_target` on any loading coordinate. E2 is half the
pre-registered estimand set, so if the fork-B door inherits that restriction,
E2 will come back uniformly `R-ENV` and be reported `NOT-EVALUABLE` — visible,
but not evidence. Worth deciding deliberately rather than discovering at L1.

**Q_0 non-PD is already a recorded finding on this family.**
`tests/testthat/test-zz-mspl-bernoulli-se-feasibility.R` pins
`pin$penalty_off$status == "non_pd"` with a negative minimum eigenvalue on a
Bernoulli-logit MSPL fit. Fork B is defined by that same unpenalized tape. Non-PD
curvature at the point does not by itself prevent a profile from bracketing, so
this is a flagged risk for the availability arm, not a prediction — but if
fork B's availability comes in under 0.90, this is the first place to look.
That pin is at n_site = 8; the L1 cells are 40 and 80.

The loading estimates on the single probe fit were far from truth (1.47 against
a true 0.90 at 40×4, one seed). That is a point-estimation observation on one
draw, not a claim, and it is not this lane's to make.

## Checks run

```sh
# 55 assertions, no fitting
NOT_CRAN=true Rscript --vanilla -e \
  'pkgload::load_all(".", compile=FALSE, quiet=TRUE); testthat::test_file("tests/testthat/test-zz-mspl-forkB-l1-gate.R")'
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 55 ]

# harness against the real tree: door absent, honest NOT-RUN
OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla \
  dev/mspl-forkB-l1-coverage-smoke.R --cells=anchor,small,neartail --n-rep=50
# L1_STATUS: NOT-RUN  (fork-B door has not landed)

# full campaign loop end-to-end against the mock door, 50 reps x 2 estimands
GLLVMTMB_L1_FORKB_DOOR=mock OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla \
  dev/mspl-forkB-l1-coverage-smoke.R --cells=small --n-rep=50 --budget-min=25
# L1_STATUS: REHEARSAL (mock door) -- no verdict, no PASS, no FAIL
```

The mock rehearsal exercised fitting, door calls, refusal typing, the E2 sign
anchor, pricing, Wilson bands, TSV output, and the verdict block. Its per-cell
lines print `L1 verdict: NOT APPLICABLE -- mock door`, it writes to a
`-REHEARSAL-MOCK` filename rather than the evidence path, and its rehearsal
artefacts were deleted rather than committed. **No number from a mock run is
evidence about anything.**

Not run: `devtools::check()`, `pkgdown::check_pkgdown()`. Neither is
informative here — no package surface, no exported function, no documentation
page, and no vignette was touched. The new test skips on an install tree
because it sources from `dev/`, the same pattern the Bernoulli SE-feasibility
test already uses for its pin source.

## How this runs once L0 lands

`l1_resolve_forkB_door()` searches the `gllvmTMB` namespace for a dedicated
fork-B entry point under four plausible names, then for an `objective` / `fork`
/ `tape` selector on the existing probe. If L0 names its door something else,
`GLLVMTMB_L1_FORKB_DOOR=<name>` points the harness at it with no code change.

The runner then **verifies the tape before measuring anything**: a door
reporting a penalised `objective_source` is rejected with an error, because
that is fork A wearing fork B's name and its number would land under an L1
fork-B heading. A door that reports no source at all is accepted but stamps the
run `PROVISIONAL`.

## Follow-up

1. **Blocked on L0** (sibling lane `cursor/mspl-forkB-l0-20260818`): the fork-B
   profile door. L1 cannot run without it and this lane must not build it.
2. **Blocked on Shinichi (G4c FORK-DEFER):** fork A/B/C is still unpicked. This
   harness is written for B on the instruction of the lane that commissioned
   it; if the fork lands as A or C, the door adapter is the only part that
   changes.
3. **Open question for L0:** does the fork-B door admit `theta_rr_B` (loading)
   targets? If not, E2 is unevaluable at L1.
4. **Not owed here:** T\* numbers, any Totoro admission, any register or NEWS
   movement.

## Non-claims

This report does not claim MSPL intervals are calibrated, does not report a
coverage figure, does not pick a fork, does not undraft #1077, does not move
MSPL-04, does not open a public `se` / `vcov` / `confint` door, does not freeze
T\*, and does not authorise any cluster compute.
