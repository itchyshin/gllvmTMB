# PVT-02 — targeted Gaussian total-variance interval calibration packet

🎯 GOAL

Solo platform: Codex

Deliverable: a reproducible, fail-closed PVT-02 packet for exactly one new
cell: ordinary Gaussian unit-tier `latent(..., unique = TRUE)`, `d = 2`,
`n_units = 400`, targeting `V_t = (Lambda Lambda^T)[t,t] + psi_t^2` with a
two-sided 95% likelihood-ratio profile on `log(V_t)` and every nuisance
parameter re-optimised.

HEADLINE: replace the broad `n_units >= 150` *regime* label with evidence that
distinguishes the two measured `n = 150` cells from this unmeasured `n = 400`
cell. This packet does not alter the public predicate or status.

IN PARALLEL: pure-contract tests and static claim reconciliation are
independent of the bounded local smoke.

DEFER: the frozen `n_sim = 5000` campaign, any validation-register promotion,
public API/R/C++ changes, bootstrap comparison, CI-14/CI-15 slope work,
random slopes, LV effects, GitHub Actions science compute, and all Totoro/DRAC
work.

DISCIPLINE: verify=Unlazy `--reverify` plus focused tests and review ·
compute=local smoke only, then explicit approval for Totoro · closure=Rose and
Grace review, after-task, Melissa plan-vs-actual, handover, narrow local
commit.

## Lane receipt

- **Lane and exact base:** `codex/pvt02-interval-calibration`, created from
  `origin/main` at `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`; both ancestry
  directions were zero, so `HEAD == origin/main` at creation.
- **Leases:** `dev/pvt02/**`, `tests/testthat/test-pvt02-*`, and
  `docs/dev-log/artifacts/pvt02/**`, plus this lane's closure files only.
  This lane does not edit `R/`, `src/`, public documentation, the validation
  register, or the existing `n = 150` certificate artifacts.
- **Preflight:** the required `lane_preflight.sh` was not present in the
  installed brain or repository tool locations. The superseding plan-only
  receipt was read; it records the prior interval work as **resume**. Current
  Git history shows the random-slope handover commit `6acfc053`, but no
  PVT-02 path overlap. `gh pr list` could not reach GitHub in this session, so
  this is a local-only collision check, not a claim that no remote PR exists.
- **Prior work:** the 2026-08-25 receipt and interval target ledger establish
  that CI-08 is `partial`; the only calibrated cells are Gaussian `d = 1,2`,
  `n = 150`. The v2 certificate used rep window `20001:40000`; PVT-02 freezes
  `50001:55000`, avoiding those indices and the earlier `1:20000` windows.

## Reconciliation before implementation

`R/profile-derived.R` currently gives `"certified-0.94"` whenever the fit is
Gaussian, unpenalised native Laplace, ordinary unit tier, `d in {1,2}`,
`n_sites >= 150`, level 0.95, and converged. Its focused export test also
asserts that a stub with `n_sites = 4000` is certified. That is a **route label
whose predicate is broader than the retained calibration evidence**, not proof
that the added values of `n` were measured. `docs/design/75-inference-route-
truth-matrix.md` has stale blanket wording that no cell is empirically
calibrated; the PVT-02 packet records the two actual `n = 150` cells as
calibrated evidence and this `n = 400` cell as unmeasured. Neither discrepancy
authorises a broader status.

The failure mode guarded here is important: a successful `n = 400` smoke
proves plumbing only. It cannot change the current public label, CI-08, or the
truth matrix. Only a frozen 5,000-attempt campaign that passes the exact
PVT-02 promotion predicate could become evidence for a later maintainer
decision.

## Frozen mathematical and campaign contract

| Item | PVT-02 value |
| --- | --- |
| Cell | Gaussian; ordinary unit tier; `latent(..., unique = TRUE)`; `d = 2`; `n_units = 400` |
| Target | `V_t = sum_k Lambda[t,k]^2 + psi_t^2`, diagonal of `Sigma_unit` |
| Profile | genuine one-df LR inversion on `q_t = log(V_t)`; two-sided `level = 0.95`; nuisance coordinates reoptimised at every fixed `q_t` |
| Target gradient | analytic `d q_t / d theta`, checked against central finite differences; no numeric-gradient substitution in the campaign |
| Profile acceptance | both endpoints finite, ordered, and contain the profile estimate; a failed/missing endpoint is `ci_failed`, not a dropped row |
| Seed window | replicate indices `50001:55000`, exactly 5,000; no pooled historical rows; check index and realised-seed disjointness before launch |
| Primary denominator | converged outer fits; profile failures among them are counted as coverage misses (`covered = FALSE`) |
| All-attempt ledger | one retained row per attempted replicate and target, including fit failures, endpoint failures, and reason codes |
| Uncertainty | replicate-clustered MCSE over eligible replicate means; report all-attempt failure fraction separately |
| Promotion | only exact cell, 5,000 retained attempts, zero seed overlap, coverage `>= 0.94`, and `coverage - 2 * MCSE >= 0.94` |

## Slice table

| Slice | Member | Model / dispatch | Estimate | Output / dependency |
| --- | --- | --- | --- | --- |
| S0 provenance and reconciliation | Ada / Rose | Luna-low provenance, local read-only | 15 min | this plan and reconciliation note; complete |
| S1 pure estimand and scoring contract | Fisher / Noether | Terra-high, native explicit | 35 min | `dev/pvt02/pvt02-contract.R`, PVT-02 tests |
| S2 executable smoke wrapper and receipt validator | Grace | Terra-high, native explicit | 30 min | `dev/pvt02/pvt02-smoke.R`, verifier, retained local receipt; depends S1 |
| S3 bounded local smoke | Grace / Fisher | Codex local R toolchain | estimated 10 min, hard stop at 25 min | smoke receipt; depends S2 and estimate |
| S4 adversarial closeout | Rose / Grace | Terra-high review | 30 min | review, after-task, Melissa, handover; depends S1--S3 |

No remote child or campaign is dispatched. The requested Luna-low provenance
slice was completed by the prior-work and branch-history sweep; the remaining
work couples statistical arithmetic to a real TMB profile and is Terra-high.

## Estimate and compute gate

The local smoke runs two frozen-window replicates (not 5,000), each retaining
all profile rows. Based on the retained v2 campaign's roughly 2 h 50 min for
20,000 parallel replicates on 90 Totoro cores, the conservative local estimate
is **10 minutes**, with a **25-minute hard stop**. It is below the 30-minute
threshold, so it may run after pure-contract checks and receipt validation.

The full `n_sim = 5000` cell is intentionally estimated as **more than
30 minutes** and needs a measured local pre-run receipt plus explicit user
approval before any Totoro/DRAC execution. It will not run in this lane.

## Team view and locked decisions

- **Fisher:** the target must stay the rotation-invariant total diagonal, not
  the `psi` proxy; profile endpoint failures must count as misses within the
  converged denominator.
- **Noether:** lower-triangular loading reconstruction, the `exp(2*theta)`
  diagonal transform, analytic log-target gradient, and one-df root inversion
  each receive independent pure tests.
- **Grace:** preserve all attempts, use a fresh seed window, record a measured
  smoke, and keep science compute off GitHub Actions.
- **Rose:** no smoke, test, or packet promotion broadens CI-08 or repairs the
  truth matrix by assertion.

Locked: exact target and cell; 5,000-attempt future size; indices `50001:55000`;
CI failure equals miss; coverage and lower-band threshold 0.94. No unresolved
design choice blocks the packet.

## Pre-authorised after G0

Scoped edits in the leased paths; routine local commands; focused tests;
documentation/closure artifacts; a two-replicate local smoke bounded by the
estimate; and a narrow local commit. Must stop for an `n_sim = 5000` run,
Totoro/DRAC, any estimate above 30 minutes, a public claim/status change,
release/merge/push, or scope expansion.
