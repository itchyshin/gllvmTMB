# Handover — the AGHQ campaign is DESIGNED and TURNKEY, and BLOCKED on #874

**2026-07-31 · from Claude (Fable 5) → a FRESH Claude session · nothing running · PR #870 open**
**Supersedes `2026-07-31-aghq-truthstart-done-campaign-next.md`, which said "the campaign is
next". It is not next. Read the blocker first.**

## Copy-paste opener

```
🎯 GOAL — gllvmTMB: establish (or refute) the AGHQ ESTIMATOR · solo platform: CLAUDE
STATE: the ADEMP campaign is DESIGNED, pre-registered, coded and smoke-tested. It is
  BLOCKED, not unfinished. Do not run the grid.
🔴 THE BLOCKER (#874): AGHQ reports convergence in 0% of fits at n=400 and n=1600 --
  aghq_grad_tol is a FIXED 1e-4 while the gradient at the stop grows ~sqrt(n). The
  campaign's converged-only population -- the one that answers "is AGHQ a better
  ESTIMATOR" rather than "does the AGHQ code emit better numbers" -- is EMPTY at every n.
NEXT: (1) #874 tolerance fix + have the stalled branch report its gradient [ENGINE change,
  Shinichi's call]; (2) THEN run STAGE=1 NSIM=400 CORES=100 on Totoro; (3) summarise.
DO NOT: re-derive the design, re-run #843's truth start, or run the grid to "see what
  happens" -- you would get a full table tagged OPTIMISER-LIMITED, which is the exact
  class of number this lane exists to stop producing.
🔴 NO PUBLIC CLAIM without Shinichi.
```

## What is done

| artefact | where |
|---|---|
| **#843 answered** — the n=100 runaway is an optimiser failure (16/16), fix already in the code | `docs/dev-log/audits/2026-07-31-aghq-truthstart-shipped-engine.md` |
| **The ADEMP design** — pre-registered estimand, δ, acceptance rule, MCSE-justified n_sim | `docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md` |
| **The runner + summariser** — turnkey, smoke-tested | `dev/aghq-evidence/24-estimator-campaign.R`, `24-summarise.R` |
| **The blocker** — 270 fits, mechanism identified | `docs/dev-log/audits/2026-07-31-aghq-convergence-nladder.md` |

Issues: **#843** answered · **#871** `aghq_multistart` dead control · **#874** the
convergence tolerance · finding routed to **#847**.

## The design, in one paragraph, so you do not re-derive it

Five arms fitted to the **same** data per replicate (paired — 2.2× tighter than unpaired,
which is how n_sim = 400 was justified from a real 40-seed pilot rather than habit):
`laplace`, `laplace_ridge`, `aghq` (shipped single-start), `aghq_alt` (truth-free
alternative start), `aghq_ridge`. Arm `aghq_ms` is **derived**, not fitted —
`min(aghq, aghq_alt)` on the final objective — which is why the campaign costs 5 fits per
replicate, not 6. Primary estimand is the **rotation-invariant** trait correlation
(Λ is identified only up to rotation, so an elementwise loading estimand would be
meaningless). Contrasts are **like-for-like on the penalty**, always; `aghq_ridge` vs plain
`laplace` is **banned** by pre-registration because it is the confound #842 named.
**Λ̂ is stored for every fit**, so the primary estimand stays a post-hoc choice and a change
of mind by the maintainer costs nothing.

## 🔴 Two things that will bite you

1. **`opt$convergence` is the WRONG FIELD on the AGHQ path.** It is nlminb's code for the
   per-pass iteration cap from the continuation schedule and returns 1 on a healthy fit.
   The engine's verdict is `aghq$stop_reason`; only a value beginning `"converged"` counts.
   The first draft of the runner got this wrong and reported 30–60% "non-convergence" that
   was entirely the cap; the truth is worse (≈0%).
2. **Totoro's installed gllvmTMB is built 2026-07-29** and predates both #844 and the
   `aghq_start_par` hook that campaign **arm 4 requires**. It must be reinstalled from the
   campaign branch before Stage 1. **Check the installed build date, never the branch** —
   the local install was 13 days stale at the start of this lane and would have made a
   "shipped-engine" campaign worthless.

## Compute, already scoped

Totoro is reachable through the existing ControlMaster socket (no Duo needed), 384 cores,
was idle at load 0.08. Use the lane's own directory **`~/gllvmtmb-aghq-20260731`** —
**`design90`/`design91` are Codex's and must not be touched.**
Stage 1 = 12,000 fits ≈ 640 core-hours ≈ **6.4 h at 100 cores**; Stage 2 = 4,000 fits ≈
2.5 h. Budget from measured per-fit times, not guesses. Results stay **LOCAL** (D-50).

```
STAGE=1 NSIM=400 CORES=100 Rscript dev/aghq-evidence/24-estimator-campaign.R
```

Smoke first (`STAGE=smoke NSIM=10`), read it, abort on garbage. That is how #874 was found.

## Do not redo

- #843's truth start (120 fits, committed) · the integrator verification (#842, six checks)
- `dev/aghq-r-reference.R` for any comparative number (`decisions.md:1706-1709`)
- campaign 12 (its O(1/T) premise is retracted)
- the 73%/47% n=100 headline **without** the single-start caveat

## Carried over

**PR #870 is OPEN and not self-merged** — it carries one source change (the
`control$aghq_start_par` diagnostic hook, inert, not a `gllvmTMBcontrol()` argument), which
is outside the low-risk self-merge rule. CI passed (22m). If Shinichi drops the hook,
campaign arm 4 and the two #843 scripts go with it.

## The method note that keeps earning its place

The previous handover said: *"if your own findings start contradicting the framing of the
task, that is a signal to stop and re-ask, not a footnote to file."* It happened again, in
the other direction: the task was "design and run the campaign", and the smoke test said
the campaign cannot answer its own question yet. **The smoke test is not a formality — it
is the cheapest place to discover that the expensive thing is premature.** 270 fits found
what 16,000 would have obscured.
