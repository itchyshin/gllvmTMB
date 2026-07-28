# Ultra-Plan — VA speed-up, then VA as the comparator engine

```
🎯 GOAL (paste verbatim to set a fresh session's goal)
PLATFORM: Claude (solo — read it from the runtime; codex/… branch names in this
repo are leftover naming, not ownership).
LANE: claude/va-wiring-20260726 · worktree /private/tmp/gllvmtmb-va-wiring-20260726
· main already merged in (c3d11667). Continuation of the same subject, not a new lane.
DELIVERABLE: (a) make VA fast enough to be usable — two measured changes first,
then two borrowed from gllvm; (b) ship VA/EVA as a CROSS-ENGINE COMPARATOR, not
as a competing estimator.
HEADLINE: Arc 0 — implement family-dependent resolution for `eval_method="auto"` (binomial→JJ, others→GH) and swap BFGS for L-BFGS-B.
The JJ default is already measured (5–8x, identical objectives). L-BFGS-B is
retained on different grounds (see verification rules). Potentially compounding before
anything structural is touched.
IN PARALLEL: nothing until Arc 0 lands — everything downstream depends on the
engine being fast enough to be worth comparing against.
DEFER (fenced, do NOT do): method="VA" as a user-selectable estimator; any claim
that VA is faster or more accurate than Laplace; new families; missing data; the
second latent tier; multinomial (needs a T-dimensional integral, architecturally
out of reach).
DISCIPLINE: verify = identical objective before/after every speed change +
interleaved timing (never a single sequential pass); compute = local for Arc 0-R1,
Totoro for the scale re-run; results LOCAL (D-50); closure = after-task +
plan-actual.
```

## Why this plan and not the obvious one

The obvious plan — "implement VA as an estimator" — is **refuted by our own
evidence**. Measured overnight on Totoro (48 cells, 640-cell grid before it):

- VA is **slower than Laplace at every tested n and p**; VA arms scale ~n^1.9–2.7,
  Laplace ~n^0.98 (linear). No crossover exists.
- Our VA **times out 12/12 at n=2500 and n=5000**. Ayumi's model is n=5397.
- The **tighter** GH bound recovers `Sigma_B` **worse** than the looser JJ bound,
  20/20 paired seeds, engine held fixed.

What the evidence *does* support: our engine was the **only arm to return a
number in all 640 cells**, was 1% degenerate, and **never reported a clean status
on a degenerate fit** — while gllvmTMB's own Laplace was 12% degenerate with 59
of those reporting `convergence = 0` and `pdHess = TRUE`, and gllvm's EVA was 68%
degenerate with **all** reporting converged.

So VA's product is a **second opinion**, and the arc is: make it fast enough to
be worth running, then wire it in as a comparator.

## Arc program (fixed capacity, 12 h)

| Order | Budget | Outcome | Done when |
|---|---:|---|---|
| **Arc 0** | 60 m | Implement family-dependent `eval_method="auto"` (binomial→JJ, others→GH); swap `optim(BFGS)`→`L-BFGS-B` | Objectives identical to pre-change; gradient tightness and function-evaluation count verified |
| R1 | 120 m | Block-diagonal / low-rank variational covariance behind an option | Fits converge; parameter count drops as predicted |
| R2 | 90 m | Re-run the scale sweep on Totoro | **Does the n>=2500 wall fall?** |
| R3 | 120 m | VA reachable *from a fitted object* (comparator plumbing) | Same data, both engines, both Λ |
| R4 | 120 m | `compare_engines()` reusing the existing `compare_loadings()` | Agreement table on a real fit |
| R5 | 120 m | Real-data validation, CSVs written **incrementally** | eSpider + beetle complete |
| R6 | 90 m | Persist `trace(Sigma_B)` + eigenvalues; the documented sentence | Round-trip test |
| Close | 60 m | After-task, plan-actual, handover | |
| **Total** | **720 m** | | |

## The four speed-ups, with provenance

| # | Change | Where it came from | Evidence |
|---|---|---|---|
| 1 | `eval_method="auto"` resolves family-dependently: **JJ** for binomial, **GH** for others | ours | JJ 5–8x faster **and** better `Sigma_B` on 20/20 seeds; binomial default is JJ via "auto" resolution |
| 2 | **L-BFGS-B** not BFGS | measured; gllvm uses both | **Retracted:** earlier timing from single sequential pass inflated by ~3x first-fit penalty. Remeasured with interleaved replicates: **0.9x — marginally slower**. Retained for gradient tightness (reaches tighter gradient norm in fewer function evaluations: 4 vs 10/19/6), and objectives agree to ~1e-13. |
| 3 | **Block-diagonal / low-rank** variational covariance | gllvm `Ab.struct` (default `"blockdiagonal"`), `Ab.struct.rank = 1` | inferred |
| 4 | **Two-stage warm-up** (diagonal S first, then relax) | gllvm `diag.iter = 1` | inferred |

**Why #2 was hypothesized (and contradicted by measurement).** `stats::optim(method="BFGS")`
maintains a **dense** inverse-Hessian over the entire parameter vector, which for
VA includes `N*(2q + q(q-1)/2)` variational coordinates:

| n | params | dense BFGS matrix |
|---:|---:|---|
| 2500 | 12,581 | **1.3 GB** |
| 5000 | 25,081 | **5.0 GB** |

n=2500 is exactly where the sweep timed out 12/12, supporting the hypothesis. However,
empirical timing with interleaved replicates shows L-BFGS-B is **0.9x** (marginally slower),
not faster. The hypothesis about memory-induced scaling was refuted; the scaling wall remains
unexplained. The change is retained for its demonstrable benefit to gradient tightness and
function-evaluation efficiency, not speed.

**Why #3 is worth borrowing with a proof gllvm does not cite.** Their default
`Ab.struct = "blockdiagonal"` is presented as an engineering choice. **Proposition
2** (Design 106, derived independently here) proves a zero off-diagonal block of
`S` is *exactly* optimal — not an approximation — iff every observation's loading
is supported inside one group and the prior precision is block-diagonal on the
same partition (Fischer's inequality). So we know both that it is safe and
precisely where it stops being safe: across the q latent coordinates, across
tiers, and across SPDE mesh nodes.

## Slice table

| # | Slice | Member | Model · effort | Time | Dep |
|---|---|---|---|---|---|
| S0 | JJ default + L-BFGS-B, interleaved measurement | Gauss | Sonnet · high | 60 m | — |
| S1 | Structured/low-rank variational covariance | Polya → Gauss | Opus (derive) → Sonnet (build) | 120 m | S0 |
| S2 | Totoro scale re-run | Fisher | Sonnet · high | 90 m | S1 |
| S3 | Comparator plumbing from a fitted object | Curie | Sonnet · high | 120 m | S0 |
| S4 | `compare_engines()` | Curie | Sonnet · high | 120 m | S3 |
| S5 | Real-data validation (incremental writes) | Curie | Sonnet · medium | 120 m | S4 |
| S6 | Persist trace + eigenvalues, docs | Gauss | Sonnet · medium | 90 m | S4 |
| S7 | Adversarial review | Noether | **Opus · high** | 60 m | S5, S6 |

PARALLEL: {S1, S3} after S0. FAN-OUT BUDGET: <=6 children, 1 ceiling (S7).

## Verification rules, each paid for in blood

1. **Every speed change must leave the objective identical.** A faster wrong
   answer is not a speed-up.
2. **Interleave timing replicates.** There is a ~3x first-fit-in-session penalty
   (a full TMB compile can be 19 s). Three claims were retracted this session for
   ignoring this. Report objective evaluations alongside wall clock.
3. **Poisson must be untouched by #1.** JJ is binomial-only and errors otherwise
   by design; if the Poisson path moves at all, stop.
4. **No threshold may be quoted from in-sample selection.** The degeneracy
   detector's 100%/100% is a resubstitution estimate and must be validated
   out-of-sample in R5 before it is repeated anywhere.

## Do not repeat

- Do **not** re-test the warm start as an accuracy fix. Measured no-op:
  `max|ELBO_warm − ELBO_cold| = 1.63e-08`, 3 seeds positive / 3 negative. Keep it
  (it is ~21% faster) but the cold start is **cleared** as the explanation for the
  recovery gap.
- Do **not** attribute the GH-vs-JJ recovery gap to the optimiser. Cross-evaluating
  the GH objective at JJ's optimum gives `f_GH(theta_A) < f_GH(theta_B)` on 6/6
  seeds — GH finds a genuinely better GH optimum and still recovers worse.
- Do **not** claim "quadrature beats JJ" as novel. Published since 2011 (Knowles &
  Minka; Marlin/Khan/Murphy; Tiao). What is unfound is that comparison *inside a
  GLLVM*.
- Do **not** resurrect the `design94/95/96` JJ prototypes; they use the same bound
  at half the PG convention and we now have JJ implemented properly.
- Do **not** route multinomial through this architecture — `n*log(sum_t exp(eta_it))`
  couples traits and needs a T-dimensional integral.

## Open, and maintainer-only

NEWS entry and the public GitHub issue for the merged binary/OLRE logLik defect
(`c3d11667`, PR #796; `v0.6.0`/`rc.1`/`rc.2` affected, not on CRAN).
