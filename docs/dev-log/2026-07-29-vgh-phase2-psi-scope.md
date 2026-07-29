# VGH Phase 2 — the `Psi` gap, and why the warm start fails closed on it

Date: 2026-07-29. Lane: `claude/vgh-phase2-20260730`. Status: **decided (scope)**.

## The gap

VGH solves a model whose between-unit covariance is exactly

```
Sigma = Lambda Lambda'
```

with no diagonal term. `src/gllvmTMB.cpp:911` confirms the reduced-rank tier is
assembled the same way: `Sigma_B = Lambda_B * Lambda_B.transpose()`.

But gllvmTMB's latent structure can *also* carry an independent diagonal tier,
parameterised separately as `theta_diag_B` (length `n_traits`,
`R/fit-multi.R:3751`), entering as

```
sd_B = exp(theta_diag_B)          # src/gllvmTMB.cpp:995
```

The template default is `theta_diag_B = 0.0`, i.e. **sd = 1.0, variance = 1.0
per trait** (`R/fit-multi.R:3751`).

## Why the obvious hand-off is wrong

VGH's `Lambda` was fitted with no diagonal available, so it has absorbed **all**
of the between-unit covariance, including whatever a diagonal tier would
otherwise explain. Seed `theta_rr_B` from that `Lambda` into a model that also
has a free `theta_diag_B`, leave the diagonal at its default, and the implied
starting variance per trait is

```
diag(Lambda Lambda') + 1.0
```

— systematically inflated by exactly 1.0 on every trait. That is not a small
perturbation of the VGH optimum; it is a different point, and it pushes Laplace
away from the solution the warm start was supposed to hand it. A warm start that
starts further from the optimum than a cold one is worse than no warm start, and
the failure is invisible in a mean speedup number.

## Options considered

1. **Leave `theta_diag_B` at its default.** Simplest, and wrong for the reason
   above.
2. **Shrink `theta_diag_B` toward zero variance** so the start's total covariance
   matches VGH's. Preserves `Lambda` exactly, but pins a component to a boundary
   value purely to compensate for a structural mismatch — and `exp()` has no zero,
   so "small" is arbitrary.
3. **Split `Lambda Lambda'` into `Lambda* Lambda*' + Psi`.** The principled
   version, and the one a factor-analytic model actually wants. But it changes
   `Lambda`, and choosing the split *is* the factor-analytic estimation problem —
   it is not a detail of a hand-off. Doing it badly silently changes which
   estimand the start represents.

## Decision

**The Phase 2 warm start applies only where VGH's latent structure matches the
target model's — a reduced-rank tier with no independent diagonal tier. Where a
free `theta_diag_B` is present, fail closed and fall back to a cold start.**

Rationale: option 3 is a research question wearing a hand-off's clothes, and this
arc's whole premise is *speed at zero statistical cost*. A fenced, honest "no
warm start here" costs a fit that was going to run anyway; a guessed `Psi` costs
the guarantee that makes the arc worth doing. This matches the arc's existing
posture — `nbinom2`, structured and spatial tiers are already fail-closed.

## Consequences

- `.vgh_to_laplace_start()` seeds `theta_rr_*` and `z_*` only. It has no opinion
  about `theta_diag_*` and must never write one.
- The wiring slice must **detect** a free diagonal tier and decline, rather than
  proceed and hope.
- The benchmark campaign must report which configurations were eligible, so the
  headline speedup is not quietly computed over a filtered subset.
- Option 3 stays open as later work, and would need its own recovery evidence
  before it could be trusted.

## Not yet established

Whether option 2 would in practice be good enough is **untested**. This decision
is made on the structural argument, not on measurement. If the eligible-model
restriction turns out to exclude most real fits, that is the trigger to revisit —
and the answer would then need a recovery study, not a judgement call.
