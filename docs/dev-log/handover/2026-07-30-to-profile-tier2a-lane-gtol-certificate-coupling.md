# Cross-lane note → the Profile / Tier-2a lane: the coverage certificate conditions on an *unscaled* convergence test

Date: 2026-07-30. From: Claude, the VA/VGH lane (closed; #840, #850, #853, #857 all merged).
**To: whoever owns Profile / Tier-2a and the `certified-0.94` label.**

**This is a question, not a defect report.** I found a coupling while inventorying something else,
verified the code path, and deliberately did **not** draw a conclusion about your certificate —
because the honest version of this finding is narrower than it first looks, and I have already had
to withdraw one over-broad claim today. Nothing in `R/` was changed by my lane
(`git diff --stat -- R/ src/` against `main` is empty).

---

## The coupling

**1. The convergence flag rests on an explicitly *unscaled* quantity.**
`R/diagnose.R:13` — `.gllvmTMB_converged_gtol <- 1e-2`, and the comment immediately above it
(`:10-12`) states the design in its own words:

> *"`converged` therefore requires the optimiser's success code, a finite objective, and a small
> **unscaled** maximum gradient."*

A gradient's magnitude scales with the objective it differentiates. So `1e-2` does not mean the same
thing for data on different scales — the same fit, with `y` multiplied by 10, presents a different
maximum gradient against a fixed bar.

**2. The certificate is conditional on that flag.**
`R/profile-derived.R:941-942`, with its own comment:

> *"Conditional on convergence — the certificate is among converged fits only."*
> ```r
> health <- fit$fit_health %||% .gllvmTMB_build_fit_health(fit)
> isTRUE(health$converged)
> ```

So the population the certificate is computed over is filtered by a scale-dependent test.

## What this does and does not imply — the important part

**It does NOT mean the 0.94 number is wrong.** The coverage you measured is what it is for the
population that passed the gate. I am not claiming a bias, a direction, or a magnitude, and I have
run **no** measurement on your surface.

**What it does mean** is that the certificate's **conditioning set** — which fits count as
converged — moves with the data's scale. The open question is whether that shifts the measured
coverage in a way the certificate's wording does not disclose. It could go either way: a looser
effective gate at small scale admits worse fits (pushing coverage down), a tighter one at large scale
excludes fits that were fine (which could push it either way depending on what correlates with
scale).

**That is your question to answer, not mine to assert.** You have the coverage harness, the seeds,
and the calibration history; I have a code reading.

## Why it came up

Two lanes independently found the same defect class on 2026-07-30 — a hardcoded magnitude constant
standing in for a scale the data determines. That prompted a repo-wide read-only inventory
(`docs/dev-log/2026-07-30-scale-dependent-constants-inventory.md`, merged as #857):

- **99** numeric constants examined, **48** genuinely scale-dependent (16 high) across 22 files,
  ~50 cleared as dimensionless with reasons recorded, and `src/gllvmTMB.cpp` **clean**.
- `.gllvmTMB_converged_gtol` was rated the **worst instance in the shipped (non-prototype)
  surface** — specifically *because* of the coupling above. Every other high-severity hit affects a
  fit or a warning; this one is the only one that reaches a **public label**.

## The cheapest thing that would settle it

If you want a bounded check rather than a re-run: take a handful of your existing certificate cells
and refit with `y` rescaled by a constant factor (say ×10 and ÷10, which leaves the model
statistically equivalent), then compare **which fits pass `health$converged`**. If the set is stable,
the concern is theoretical and you can say so in one line. If it moves, the certificate's wording
should probably name the scale regime it was measured in — which is the same discipline the profile
lane already applies elsewhere (the `claim-boundary marker` comment at `R/profile-derived.R:946-949`
is exactly this instinct).

I have deliberately not run that — it is your harness and your claim.

## What this note does NOT cover

No measurement on the profile/coverage surface. No claim about the direction or size of any effect.
The severity rating is **AGENT-INFERRED** from reading the two code paths above. I did not examine
whether other `fit_health` components (`pdHess`, the objective-finiteness test) carry the same
property, nor whether `n_init` restarts interact with it.

Raised as information because it touches a public label; ownership and the decision are yours.
