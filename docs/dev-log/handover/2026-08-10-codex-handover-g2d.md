# Codex-to-Codex handover — G2d six-species design lane

**Date:** 2026-08-10  
**From / to:** Codex → Codex  
**Status:** G2c closed `G2C_SMOKE_ADMISSION_HOLD`; G2d is **plan-only** and has not begun implementation.

## Mission

Create an approval-ready Ultra Plan for **G2d**, a private synthetic recovery
design that increases the community dimension from three to six species while
preserving the two-source relative-intensity model: GBIF Poisson quadrature,
three linked PA-cloglog visits, rank-one ecological covariance, and free
diagonal \(\Psi_C\).  The purpose is to test whether the community covariance
becomes estimable away from the three-species near-saturation regime.

This is not permission to fit G2d, start Totoro, change package/public APIs,
use empirical data, or claim Paper 2 is fit-ready.  Get a fresh explicit
approval after the G2d plan is presented.

## Read first

1. `AGENTS.md` and this repository's active-lane map:
   `docs/dev-log/handover/2026-07-25-active-lane-split.md`.
2. This handover.
3. G2c's terminal decision:
   `dev/isdm-package-recovery/2026-08-10-g2c-smoke-decision.md`.
4. The G2c protocol and closeout:
   `dev/isdm-package-recovery/2026-08-10-g2c-replicated-pa-protocol.md` and
   `docs/dev-log/after-task/2026-08-10-g2c-replicated-pa-smoke.md`.
5. The durable two-root provenance ledger:
   `docs/dev-log/recovery-checkpoints/2026-08-10-164500-codex-g2c-smoke-provenance.md`.

## Established state

| Item | State | Meaning |
| --- | --- | --- |
| G1 | passed | Fixed-vector routing only; not recovery. |
| Earlier G2 / G2a | HOLD | Protected private evidence; do not reinterpret. |
| G2b | separate information diagnostic | Never call it a recovery gate. |
| G2c | `G2C_SMOKE_ADMISSION_HOLD` | One three-visit local admission fixture did not meet the frozen two-sided \(\psi\)-profile rule. No Totoro campaign. |
| Full Paper 2 model | not fit-ready | Recovery, source separation, and later two-field spatial validation are still owed. |

The G2c runner proved private package-native row routing and exact repeated-PA
event construction.  Its three-visit smoke retained small gradients but had
flat or one-sided diagonal-profile endpoints and a diagonal-variance error
above its frozen threshold.  This is a narrow design finding, not a likelihood
defect or a general non-identifiability theorem.

## Decisions to preserve

- Keep the estimand as **relative ecological intensity**, slopes, and relative
  maps.  Do not add absolute abundance, detection multipliers, event random
  effects, source-specific ecological slopes, or spatial terms to G2d.
- G2d changes only the number of species.  It must keep three conditionally
  independent PA visits at the same cell/species state, unchanged GBIF process,
  rank-one \(\Lambda\), and free diagonal \(\Psi_C\).
- Do not relax G2c thresholds or rerun/reuse either G2c smoke root.
- Before any G2d fit, freeze a new protocol, truth, seeds, profile-coordinate
  mapping, attack rules, all-attempt denominators, and an immutable output root.
- Carry Fisher's harness repairs forward: named per-coordinate profile verdicts,
  finite-objective checks, and exact validation of the five fixed profile
  offsets.  These are design requirements, not grounds to revise G2c.
- `spatial_indep(common = TRUE)` and `spatial_latent(d = 1)` remain one-field
  controls.  Neither substitutes for the later ecological-plus-GBIF-bias
  two-field architecture.

## Landing ledger

| Field | Value |
| --- | --- |
| Source worktree | `/private/tmp/gllvmtmb-isdm-g2c-replicated-pa` |
| Source branch | `codex/isdm-g2c-replicated-pa` |
| Source head before this handover | `ac712755` |
| Landing state | **CARRIED-OVER, local commits unpushed** |
| Push / PR | Neither was authorised. Do not presume a remote checkout contains this work. |
| Protected ignored roots | `dev/isdm-package-recovery/results/g2c-smoke-20260810/` and `.../g2c-smoke-20260810-retry1/` |

The handoff gate reported unpushed commits.  The next Codex task must open the
local G2d worktree created from this exact local tip, or the maintainer must
explicitly authorise pushing first.

## Exact resume action

```sh
cd /private/tmp/gllvmtmb-isdm-g2d-six-species
git status --short --branch
```

Then run the lane preflight, read the files above, ask the brain for Paper 2 /
G2 recovery decisions, and use the Ultra Plan method.  The first deliverable
is an approval-ready G2d plan, not code or a smoke fit.

## G2d planning checklist

1. Specify a six-species DGP and explain why it increases covariance
   information without changing the estimand.
2. Specify immutable new seed blocks, ordinary and attack fixture counts,
   pairing, profiles, eligibility, recovery thresholds, and a named PASS/HOLD
   decision table.  Do not silently inherit a rule sized for another gate.
3. Require byte-identical GBIF and first-visit PA rows when comparing any
   one-visit reference with the three-visit arm; only the two extra PA uniforms
   and event IDs may differ.
4. Include independent reconstruction, adversarial source-gate tests, retained
   starts/profiles/failures, and root immutability before any Totoro approval.
5. Keep comparator, count, spatial, source-admission, empirical, public, and
   Issue #953 work explicitly deferred.

## Likely next decision

After an approved G2d plan and a successful local smoke admission, ask for a
separate authorisation for the Totoro recovery campaign.  A G2d PASS would be
only fixture-specific synthetic recovery evidence; it would still not make
Paper 2 article-ready or authorise empirical fitting.
