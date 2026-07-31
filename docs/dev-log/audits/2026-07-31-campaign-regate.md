# Campaign re-gate — PASS, and an early signal that the populations disagree

**2026-07-31 · Claude (Fable 5) · 200 fits, local, ~35 min · Results LOCAL (D-50)**
**Answers the gate set by `2026-07-31-aghq-fixes-landed-campaign-unblocked.md`:
does the converged-only analysis population exist now that #874 is fixed?**

---

## Verdict: PASS. The campaign may run at the designed `NSIM = 400`.

Before the fixes the converged-only population — the one that answers "is AGHQ a better
**estimator**" rather than "does the AGHQ code emit better numbers" — was **empty at every
n**. It is not any more.

| arm | converged | expected converged fits at `NSIM = 400` |
|---|---|---|
| `aghq_single` (pre-#843) | 22.5% | ~90 |
| `aghq` (shipped, multi-start) | 25.0% | ~100 |
| `aghq_ridge` | **60.0%** | ~240 |

*(`aghq` was **2.5%** and `aghq_ridge` **15%** before #874/#843 — so roughly 10× and 4×.)*

**Converged pairs: 10 of 40, against 0 before.** SD of the paired ρ-MAE difference on those
pairs is **0.0225**, so `3 × MCSE < δ = 0.02` needs only **12 converged pairs** — i.e.
`NSIM ≈ 48` at 25% convergence. **The design already specifies 400.** The gate clears with
substantial margin.

---

## 🔴 The early signal, and it is not a footnote: the three populations disagree in SIGN

The design (§P.4) requires the primary contrast on three populations and forbids resolving
disagreement silently. On 40 seeds they do not agree:

| population | `laplace − aghq` (ρ-MAE) | reading |
|---|---|---|
| **all fits** (primary) | **+0.0436** [0.0102, 0.0770] | AGHQ more accurate |
| non-runaway only | **−0.0253** [MCSE 0.0071] | **Laplace** more accurate |
| **converged only** | **−0.0268** [MCSE 0.0071] | **Laplace** more accurate |

The sign flips. The most plausible mechanism, stated as inference rather than result: with
runaways included, Laplace's 48% runaway rate hurts it and AGHQ's multi-start (38%) hurts it
less, so AGHQ looks better in aggregate — but **among fits that are actually good, Laplace
recovers the trait correlations more accurately.** "AGHQ wins" and "AGHQ loses" are both
available from the same 40 seeds depending on which fits you keep.

**This is exactly the trap the campaign was designed to avoid**, and it is a strong argument
for running the full grid rather than reading anything into this smoke. It also means any
future AGHQ claim must name its population, not just its regime.

**40 seeds. This is a smoke, not a result.** Do not cite these numbers.

---

## One clean verdict the machinery already returned

`laplace_ridge − aghq_ridge` = **−0.0077**, 95% CI **[−0.0155, 0.0001]** → **NO PRACTICAL
DIFFERENCE**, and *not* tagged `OPTIMISER-LIMITED` (that arm converges 60%). The pre-registered
equivalence branch fired on its own — the first time this campaign's acceptance rule has
returned a conclusion rather than "inconclusive".

## What #843 bought, measured

`aghq_single − aghq` = **+0.0427** [0.0167, 0.0687] in ρ-MAE, and runaway **55% → 38%**.
Multi-start improves the accuracy of the arm, not just its tail behaviour.

## Stop reasons now that the loop reports gradients

| reason | n (of 120 AGHQ fits) |
|---|---|
| `stalled (no honest descent at cap 1)` | **75** |
| `converged (gradient below tolerance)` | **43** |
| `adaptation failed, kept last honest iterate` | 2 |

Stalls remain the dominant mode and are still unexplained — they sit far above tolerance, so
they are genuine non-convergence rather than near misses. That is the next engine question,
and it is **not** blocking the campaign.

---

## Arm definitions were corrected first, and this matters for reading any older run

The runner's arms were written against a **single-start** engine and #843 invalidated them:
`aghq` is multi-start now (so it was no longer "the shipped single start"), the injected-start
arm was neither one thing nor the other once the engine built its own second start, and the
derived `aghq_ms` became redundant because the engine does exactly that internally.

Corrected to `laplace`, `laplace_ridge`, **`aghq_single`** (explicitly `aghq_multistart =
FALSE`), `aghq`, `aghq_ridge`. Keeping `aghq_single` is a deliberate improvement on the
original design: it prices what multi-start bought, in the same replicate, on the same data.

## 🔴 The campaign is READY but NOT LAUNCHED — Totoro is fully committed to another lane

Checked before launching rather than after. **The VA lane's Gate-3 campaign is live on
Totoro right now**: `2160 tasks (6480 fits), 96 workers`, load average ~97, 238 R processes.

The courtesy limit on Totoro is **≤100 cores**, and another lane already holds 96. Launching
a 16,000-fit campaign on top would blow through the budget and slow a running campaign that
is not mine. **Not launched.** That is a compute-scheduling decision, not a technical
blocker — everything else is ready.

### Ready state (so the next session launches, not prepares)

- Source shipped to Totoro at `~/gllvmtmb-aghq-20260731/pkg` (from `main`, all fixes).
- gllvmTMB **rebuilt and verified**: `0.6.0`, `Built: 2026-07-31 16:20:19 UTC` — current,
  against the 2026-07-29 build that predated every fix.
- Runner arms corrected; re-gate passed; `NSIM = 400` justified.

### ⚠️ One thing I did that wants recording

That install went to `~/R/lib`, which **is on Totoro's default library path** — so it
overwrote the shared `gllvmTMB` while two lanes were running. **No harm done, but by luck
rather than by care:** both live lanes load with `devtools::load_all()` from their own
source trees (the gate3 script's own header says *"library(gllvmTMB) is unsafe here"*), so
neither reads the shared library. The shared library now holds current `main` rather than a
2-day-old build, which is an improvement for anyone who does use `library()` — but I should
have checked what else lived there **before** writing to it, not after.

### Then

1. Wait for Totoro to free (or take a maintainer ruling on priority against the VA lane).
2. `STAGE=1 NSIM=400 CORES=100` (~6.4 h), then `STAGE=2 NSIM=200` (~1.3 h measured).
3. Report all three populations side by side. The sign disagreement above says the headline
   is *which population*, not just *which engine*.

🔴 No public claim from any of it without Shinichi.
