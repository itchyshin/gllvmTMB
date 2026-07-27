# After-task — VA registry, calibrated standard errors, and four retractions

**Date:** 2026-07-27 · **Platform:** Claude Code · **Lane:** `claude/va-wiring-20260726`
· **Worktree:** `/private/tmp/gllvmtmb-va-wiring-20260726` · **PR:** #798

## 1. Scope

Tier 1 of the LA/VA parity goal: make the VA engine's evaluation tier declarative,
give VA standard errors and calibrate them before anything quotes them, and produce
something defensible for Ayumi. Plus the ENGINE column on the capability surface.

## 2. What shipped

| Commit | Content |
|---|---|
| `51d1fa81` | Family-adaptive `eval_method`, JJ binomial default, L-BFGS-B polish, ENGINE column |
| `4dc65e44` | `.va_r3_family_registry` — the per-family evaluation contract, declared |
| `74f4c810` | Latent posterior SDs + fixed-parameter observed information |
| `b20061e7` | Design 109, fairness audit, three-engine demo, calibration harness |
| `2becfd49` | S12 coverage evidence recorded on the SE contract |
| `35ac6c88` | Four per-family row corrections on the surface |

## 3. The headline results

**VA now has calibrated intervals.** 25 seeds, MCSE 0.015, nominal 0.95:

| n | method | `se_conditional` | `se_profile` | attenuation |
|---|---|---|---|---|
| 150 | JJ | 0.910 | **0.940** | 0.693 |
| 400 | JJ | 0.895 | **0.935** | 0.595 |
| 150 | GH | 0.885 | **0.950** | 1.622 |
| 400 | GH | 0.900 | **0.945** | 1.206 |

`se_profile` (Schur complement, variational block marginalised out) covers at nominal
in every cell. `se_conditional` (naive `optimHess` over the fixed block) under-covers
in every cell. **The Schur correction is the difference between valid and invalid
intervals, not a refinement.**

**`sdreport` is 27–32% of Laplace's time-to-inference and rising with n.** Point-only
timing understates every engine. Time-to-inference is now the only headline metric.

## 4. Four retractions

1. **"L-BFGS-B is 16× at n=800"** → measures **0.9×**, marginally slower. Kept on
   gradient-quality grounds (4 vs 10/19/6 evaluations). Kills the "dense
   inverse-Hessian is the n≥2500 wall" hypothesis.
2. **"gllvm EVA: all reported converged"** → a `grepl("...|converged", status)` bug
   matching `"not_converged"` (`dev/totoro-grid/analyse-grid.R:100`). True 160/203
   (78.8%). The three arms were also never scored on comparable fields.
3. **"JJ recovers Σ_B better than GH"** → true at n=150, **reverses at n=400**
   (distance from unit attenuation: JJ 0.307 vs GH 0.622, then JJ 0.405 vs GH 0.206).
4. **"VA has no speed advantage"** — mine, this session. **Inside gllvm, VA is
   2.1–4.7× faster than LA in every cell.** I had compared gllvm's VA against *our*
   Laplace. Their default is justified by speed exactly as Shinichi assumed.

## 5. Design 109 — the mechanism

"Tighter bound ⇒ better estimates" is false as stated and known-false in the
literature (Rainforth et al. 2018; Turner & Sahani 2011): bias depends on the
*gradient* of the gap, not its level. The JJ gap is a Jensen gap, zero at `v=0` and
increasing in `v`, so JJ **deflates** the variational variance — the opposite of the
mechanism this lane had assumed. Empirically confirmed: JJ 0.693/0.595, GH 1.622/1.206.
Global monotonicity of `g` in `v` is **not** proved; downstream claims are conditional.

## 6. The engine ordering, measured

**gllvmTMB Laplace ≫ gllvm VA > gllvm LA ≫ our VA.**

Our Laplace is the outlier and it is very good — it beats gllvm's VA even though VA
beats LA inside gllvm. **Our VA being slow is therefore an implementation gap, not a
property of VA**, and gllvm demonstrates the headroom is real. VA's advantage *shrinks*
with p (4.71× at p=30 → 2.09× at p=120), contradicting the "designed for many species"
story.

## 7. Checks

`devtools::test()`: **FAIL 0 | WARN 2 | SKIP 782 | PASS 7563**, post-merge with `main`.
NAMESPACE diff 0 lines; `src/gllvmTMB.cpp` and `R/gllvmTMB.R` untouched. Capability
surface: 6 deletions across the whole file, every one an edited line, no content lost.
Nothing exported; no `method=` argument; Laplace remains the only estimation route.

## 8. Follow-up

- **`score$negative_elbo_gh`** hardcodes `_gh` in a field that can hold a JJ value.
  Shinichi approved the rename; deferred only because an agent held `R/`.
- **The JJ binomial default** was justified by a claim that reverses at n=400.
  Shinichi elected to keep it (it is still 4–5× faster) — now a speed/accuracy trade,
  not dominance.
- **Re-score the gllvm comparison** with real gradient/Hessian extraction. Bounded
  re-run, not a full 640-cell repeat.
- **Latent-score SDs are entirely uncalibrated.** Only β was tested.
- **AGHQ (Shinichi's suggestion, and a good one).** It is the only route with a
  convergence knob — Laplace *is* AGHQ with one node. We already use it as an oracle
  (`.eva_aghq_marginal_q1`, and the fixed-coordinate admission test). Cost wall is
  `H^q` per unit, so practical at q ≤ 2. Recommended above pushing VA further.
- **"Improve LA" concretely means "speed up the SE step"** — that is where 27–32% sits.

## 9. Do-not-repeat

- **Never time from a single sequential pass.** Five retractions now, from one cause.
- **Never reason about relative speed from architecture.** Three of my framings were
  corrected by measurement today; every one came from inferring rather than measuring.
- **A default flip must sweep the call sites AND the tests.** `eval_method = "auto"`
  meaning GH was assumed in four research scripts and three tests.
- **`grepl` on a status string is a substring match.** `"converged"` matches
  `"not_converged"`. Use exact comparison or anchor the pattern.
- **Score every arm on the same fields**, or the comparison is an artifact.

## 10. Compute

Local throughout. Totoro was checked and reachable (384 cores, live socket) but the
25-seed calibration was ~45 min locally with MCSE 0.015 — adequate to decide, so the
deploy cost was not paid. Results LOCAL (D-50).

## 11. Lane receipt

**START A FRESH TASK.** Parent context is high. See the handover for the resume block.
