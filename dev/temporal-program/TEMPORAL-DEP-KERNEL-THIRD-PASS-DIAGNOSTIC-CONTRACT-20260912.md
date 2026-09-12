# Dependent temporal--kernel third-pass diagnostic

## Purpose

This one-cell diagnostic tests whether a third *identical* BFGS pass clears
the sole strict-gradient failure in the retained 80-series, 32-occasion
qualification. It is an optimizer diagnostic, not a replacement recovery
campaign or an admission decision.

## Frozen target and comparator

The target is exactly `phi = 0`, `seed = 2609373`, from
`run-dep-kernel-occasion-qualification.R`: 80 labelled series, 32 occasions,
three traits, two measurements, the fixed non-proportional kernel, direct
Gaussian DGP, and the unchanged Gaussian ML/Laplace likelihood. The retained
two-pass endpoint had outer gradient `0.00167243199`, just above the fixed
`0.001` requirement; its recovery summaries otherwise passed.

The diagnostic independently recreates that fixture twice from the same
deterministic default start: once with two BFGS passes and once with three.
It retains both complete optimizer histories, final parameters, native
objectives and gradients, and an independently authored block-Gaussian
objective plus central-gradient audit at both endpoints. It never calls
production simulation.

## Decision rule

The candidate is accepted only if the two-pass comparator is terminally
successful, the third pass has convergence code zero and is retained, its
objective does not increase by more than `1e-8`, its maximum outer gradient
is at most `1e-3`, and the independent endpoint checks have NLL error at most
`1e-6` and maximum gradient error at most `1e-4`. A rejected diagnostic keeps
the original campaign, seed, thresholds, and failed verdict unchanged.

Even an accepted diagnostic is only a candidate for a later separately frozen
multi-cell qualification. It proves neither source-pair recovery, optimizer
superiority, interval coverage, publication readiness, nor release status.
