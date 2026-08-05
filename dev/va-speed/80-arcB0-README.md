# Arc B0 pilot artifacts — DESCRIPTIVE ONLY, from a CANCELLED arc

**Do not cite any number in these files as evidence.** They are untracked on purpose.

## What they are

`80-arcB0-timed-pilot.R`, `81-arcB2-analyse.R`, and the `80-arcB0-*.rds` / `80-*.log`
files were produced on **2026-08-05** for Arc B (VA interval **route selection** — scoring
the sandwich interval route against Wald).

**Arc B was cancelled by the maintainer before the scoring campaign ran** ("VA is already
good — we do not need to do sandwich"). What remains is a *timed pilot*, not a measurement.

## Why they are a trap

They contain the first sandwich-route coverage numbers ever produced in this repo, which
makes them look like evidence. They are not:

- **15–16 seeds per cell.** The campaign design's own bar is *"several hundred seeds"*
  (`docs/design/va-interval-route-selection.md:117-118`); 30 seeds gives MCSE 0.055.
  These numbers cannot rank two routes and were never intended to.
- Everything committed still correctly records the sandwich route as **UNSCORED**
  (`va-interval-route-selection.md:70`, `va-intervals-status.md:23`). That is accurate for
  anything a reader can cite. Do not "correct" it from these files.

## What IS reusable

Two things here are sound and were reused by later work:

1. **Per-fit timing at the primary cells** — median **1.35 s** at n=150 and **4.91 s** at
   n=400, on health-gate-PASSING fits. This retired the earlier **~13 core-hour** estimate,
   which had been derived from `failed_health_gate` rows at 1–2 iterations (the cost of a fit
   that gives up). The VA-usability arc's compute sizing rests on these numbers.
2. **The harness pattern** in `80-arcB0-timed-pilot.R` — the production DGP, the
   `.va_r3_load_dll()` warm-up *before* `mclapply` forks (this matters; without it every
   forked child races to recompile the same `.cpp`), and the per-seed record shape.

A third observation, recorded but **not** established: converged fits sit at
max|gradient| ~2.6e-4 median, i.e. **above** the 1e-4 polish target and **below** the 5e-3
health bar. That bears on the polish-escalation question and is why a 1e-4 stationarity gate
would reject 80–94% of genuinely converged fits.

## Disposition

Kept, untracked, pending the maintainer's call. Nothing depends on them.
