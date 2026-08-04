# ARCS — the SPEED programme (redirected 2026-08-03 by Shinichi)

> **Scope change.** This lane opened as "ordinal-probit Albert–Chib (Item 1B)". Shinichi
> redirected it to **speed**, with the reasoning: *LA is the accurate engine, so speeding LA up
> is the prize* — and *"look at how gllvm and galamm are actually speeding things up."*
> Ordinal Item 1(B) is **DEFERRED, not cancelled** (see below).

Status: `TODO` · `WIP` · `DONE (verified: <how>)` · `BLOCKED` · `GATE`

| id | arc | status | gate | dep |
|---|---|---|---|---|
| **A0** | **Retract the false "VA is refuted" claim** — 4 surfaces, visible banners | **DONE** (verified: `56dfd5f0`; banners present in verdict doc, handover, ledger row 46 + lesson 3, check-log) | — | — |
| **A1** | **Adaptive `profile_variational`** — resolve the validated **39× fix that exists and is not the default**. Reconcile the two contradictory measurements, find the crossover, make the default adaptive | TODO | — | — |
| **A2** | **galamm + gllvm speed source-map** → `dev/va-speed/50-GALAMM-REFERENCE-READ.md`. What makes their sparse Cholesky cheap (reused symbolic factorisation, fixed sparsity pattern, fill-reducing ordering) | **WIP** (scout dispatched) | — | — |
| **A3** | **Apply the borrowed technique to OUR Laplace inner solve** — our own profile calls this *"potentially the largest available"* and *"the single most promising unexplored lever"* | TODO | **G2** | A2 |
| **A4** | **Package `se = FALSE` for LA** — 22–39% at zero statistical cost; already gated by `gllvmTMBcontrol(se = TRUE)`. Work is packaging: documented "fit now, SEs later" + a lazy `sdreport()`-on-demand accessor | TODO | — | — |
| **A5** | **Harden `43-va-vs-la-ladder.R`** — assert the RESOLVED `eval_method`/`collapse`/`H`, abort on mismatch, fix `va_iters = NA`. The A0 lesson, made mechanical | TODO | — | — |
| **A6** | **Consolidate** — after-task, check-log, register rows, handover | TODO | — | A1,A3,A4 |
| **A7** | **Reconcile plan vs actual** (Melissa) | TODO | — | A6 |

**Order (Shinichi's):** A1 → A2/A3 → A4. A2 runs in parallel (read-only research, no file conflict).

## A1 — the contradiction to resolve FIRST

The va-speed-arc handover's own "next step 0", never done. **A validated 39× fix is in the
codebase and is not the default**, but two measurements disagree about whether it helps:

| source | tier structure | outer par | result |
|---|---|---|---|
| `PROFILE.md` §Q2 (structured phylo, `gaussian_anchor`) | 2N−2 levels | **34×N** → 34,000 at N=1000 | `profile=TRUE` **wins 39×**; ~N^0.9 vs ~N^2.1. At N=1000, **99.83%** of wall-clock is `nlminb`'s own bookkeeping and **0.17%** is genuine `fn()`/`gr()` |
| lane-2 handover, Gotchas | plain latent tier | already small | `profile=TRUE` **loses**: 27.7 s vs 2.75 s at N=250; 128.5 s vs 29.1 s at N=1000 |
| va-speed-arc handover, §red | structured, `profile=TRUE` set | — | a fit **exceeding 3600 s** — "does not sit easily beside the profile's N^0.9 result" |

**Hypothesis (to test, not assume):** profiling pays exactly when the variational block is
large relative to the global block, and costs when it is not — so the fix is an **adaptive
default keyed on that ratio**, not a flag flip. The handover says plainly: *"Reproduce both
before building on either."*

**A1 is therefore a MEASUREMENT arc first**, an implementation arc second. Do not flip a default
on a hypothesis.

## Gates

- **G2 — before any Laplace inner-solve change lands.** A solver/parameterisation change to the
  shipped engine is likelihood-adjacent and touches `src/gllvmTMB.cpp`; it needs the maintainer's
  word and Gauss/Noether review (AGENTS.md Design Rule 4 + merge authority).
- **G3 — standing:** do NOT push `claude/va-lane2`. Maintainer's call.
- **G4 — statistically-free only.** Loosening a convergence tolerance to cut iteration count
  changes point estimates and is **NOT** a free speedup. Any lever that moves fitted values is
  out of scope for this arc without an explicit decision.

## Deferred (not cancelled)

- **Ordinal Item 1(B)** — Albert–Chib Theorem 3, VA family code 5. The derivation is DONE
  (`ALBERT-CHIB-DERIVATION.md` §5, cutpoints pinned in §5.8); only the build remains, and the
  numerical crux (`va_r3_log_pnorm_diff`, the `-1.2e-16` clamp, `he()`-finite gate) is fully
  specified in this lane's `ultra-plan.md`. Resume there.
- EVA, AGHQ, the interval-coverage campaign (D-112).

## Carried over

- A second Claude session committed to this branch earlier today (`695450d2`, `305b6b86`,
  `2a174fb9`). Surfaced for the maintainer, not resolved here (D-87).
