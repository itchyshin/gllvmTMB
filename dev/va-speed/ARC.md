# VA speed arc — make our VA as fast as gllvm's without losing our accuracy

```
🎯 GOAL — paste verbatim to set a fresh session's goal

PLATFORM: Claude Code, solo. gllvmTMB. Lane: VA speed arc.
Worktree /private/tmp/gllvmtmb-va-speed, branch claude/va-speed-arc, cut from
origin/main @ 19e9cedd. Never build from the Dropbox checkout (PROTECTED, D-112).

DELIVERABLE: our VA fits the reference cell in time comparable to gllvm's, with
recovery NO WORSE than it is today. Speed is the objective; accuracy is the
constraint, not the trade.

THE MEASURED TARGET (identical single-tier model, identical data, planted truth,
binomial-probit, N=250 T=20 q=1, 4 seeds):
    gllvm VA     0.70 s   rel_frob 0.359
    OUR VA      45.6  s   rel_frob 0.298   <- ours is 65x SLOWER and 17% BETTER
    our Laplace 114.5 s   rel_frob 0.170
  Plus: adding our 198-level structured phylo tier costs a FURTHER ~56x
  (>3600 s, never finished). That tier is our unique capability and has NEVER
  been cost-profiled.

ACCEPTANCE: (a) median wall-clock within a small factor of gllvm's 0.70 s on the
reference cell; (b) median rel_frob NOT worse than 0.298 -- our accuracy edge over
gllvm is the thing being protected; (c) the structured tier finishes at all.

DISCIPLINE — each rule paid for in blood on this exact problem:
  * Every speed change must leave the OBJECTIVE identical (agreement ~1e-13),
    verified before/after. A speed-up that changes the answer is a model change.
  * Time with INTERLEAVED replicates, never a single sequential pass. The July
    arc's L-BFGS-B looked 3x faster that way; interleaved remeasurement gave
    0.9x — marginally SLOWER. The hypothesis was refuted by its own methodology.
  * PROFILE BEFORE OPTIMISING. Do not build a speed-up whose target the profile
    has not confirmed.
  * n_starts must be 1, 3 or 4 (2 is rejected). H must be 15, 25 or 61.
  * Results LOCAL (D-50). Nothing promoted; the VA fence stays shut.
```

## Why this arc, and why now

Our VA is **correct** — it beats gllvm's mature implementation on recovery, 4/4 paired
seeds, and its KL agrees with a direct-algebra oracle to 2.26e-16. What it is not, is
usable: 65x slower than the reference on the base engine, and a further ~56x once our
structured phylogenetic tier is added, which is the tier the whole Design 108 programme
exists to serve.

Everything downstream is gated on this. The structured VA-vs-Laplace question cannot be
measured at the sizes where it matters, because VA does not finish there. So this is not
an optimisation nice-to-have; it is the blocker.

## What is already known — do NOT re-derive

From the 2026-07-27 speed plan, of four identified speed-ups:

| # | Change | Provenance | Status |
|---|---|---|---|
| 1 | `eval_method="auto"` → JJ for binomial-logit | ours | **LANDED** |
| 2 | L-BFGS-B over BFGS | measured | landed, but its **speed claim was REFUTED** (0.9x). Retained only for gradient tightness |
| 3 | **Block-diagonal / low-rank variational covariance** | gllvm `Ab.struct="blockdiagonal"`, `Ab.struct.rank=1` | **NOT BUILT** |
| 4 | **Two-stage warm-up** (diagonal `S` first, then relax) | gllvm `diag.iter=1` | **NOT BUILT** |

**#3 is the lever, and we hold a proof gllvm does not cite.** Design 106 **Proposition 2**
shows a zero off-diagonal block of `S` is **exactly optimal — not an approximation** — iff
every observation's loading is supported inside one group and the prior precision is
block-diagonal on the same partition (Fischer's inequality). gllvm presents `Ab.struct` as an
engineering default; we can adopt it knowing precisely where it stays exact and where it
stops being safe: across the `q` latent coordinates, across tiers, and across SPDE mesh nodes.

**Also still open:** the `n >= 2500` wall. Its memory hypothesis (dense BFGS inverse-Hessian
over `N*(2q + q(q-1)/2)` coordinates — 5.0 GB at n=5000) was measured and **refuted**. The
wall is unexplained. It is now diagnosable, because we have a reference implementation that
does not have it.

**Note R3 (`profile_variational`) landed AFTER that plan** and already collapsed the OUTER
problem to 206 parameters, constant in N. So the remaining cost lives in the **INNER** solve —
which is exactly what #3 and #4 attack. The two efforts compose; they do not overlap.

## Slices

| # | Slice | Member | Model · effort | Dep |
|---|---|---|---|---|
| P0 | **Profile**: where do the 45.6 s go? Where does the structured tier's 56x go? Is it per-iteration cost or iteration COUNT? | Gauss | Sonnet · high | — |
| P1 | Block-diagonal / low-rank `S` behind an option, guided by P0 and Proposition 2 | Gauss | Sonnet · high | P0 |
| P2 | Two-stage warm-up (`diag.iter` analogue) | Gauss | Sonnet · medium | P0 |
| P3 | Re-measure vs gllvm, interleaved, objective-identity checked | Fisher | Sonnet · high | P1, P2 |
| P4 | Does the `n >= 2500` wall fall? Scale sweep | Fisher | Sonnet · high | P3 |
| P5 | Adversarial review of the speed claims | Noether | **Opus · high** | P3, P4 |

**P0 decides P1 vs P2 ordering.** If the structured tier's cost is *per-iteration*, #3
(block-diagonal `S`) is the fix. If it is *iteration-count*, #4 (warm-up) and starting values
are the fix, and #3 will disappoint. Building both without knowing is how the July arc spent
its budget on L-BFGS-B.

## What would make this arc fail honestly

If the profile says the time is in a place neither borrowing touches — e.g. TMB tape
construction, or the GH quadrature loop at H=15 — then #3 and #4 are the wrong tools and the
arc must re-aim rather than build them anyway. That is a legitimate outcome and must be
reported as one.

---

## P0b — the FAMILY SWEEP (maintainer, 2026-08-03): is the cost GH, or is it the engine?

Everything measured so far is **binomial-probit**. That is one cell of five, and it happens to
be one of only two families that must integrate numerically. So the 65x may be a property of
the family, not the engine — and the registry lets us predict the answer before running it.

From `.va_r3_family_registry` (`R/va-r3-proto.R`):

| family | tiers | `expectation` | prediction |
|---|---|---|---|
| `gaussian_anchor` | gh | **exact** — `E[(y-eta)^2] = (y-mu)^2 + v`; *"the quadrature nodes are never touched"* | fastest |
| `poisson` | gh | **exact** — `E[exp(eta)] = exp(mu + v/2)`, the log-normal mean | fast |
| `binomial` (logit) | gh, **jj** | **bound**, closed form | fast |
| `binomial_probit` | gh only | **quadrature** | slow (measured: 45.6 s) |
| `nbinom2` | gh | **quadrature** — *"the only hard term"*, `E[log(phi + exp(eta))]` | slow |

**The discriminating prediction.** If cost tracks the `expectation` column — gaussian and
Poisson fast, probit and nbinom2 slow — then the 65x is **the Gauss-Hermite loop**, and the
fix is narrow: make GH cheaper, cut nodes adaptively, or find a probit augmentation. If
gaussian and Poisson are ALSO ~60x slower than gllvm despite touching no quadrature nodes,
then GH is exonerated and the cost is **structural in the engine** — which is where the two
gllvm borrowings (#3 block-diagonal `S`, #4 warm-up) become the right target.

**These two theories imply different work.** Running this sweep before building either is the
same discipline as profiling before optimising, and it is cheap: gaussian and Poisson fits
should be seconds, not minutes.

### Design

- Same latent structure and the SAME `eta` across families, with each family's response drawn
  from that shared `eta`. `Sigma_B` truth is then identical across families, so recovery is
  comparable across the sweep and not just within a family.
- Arms per family: **our VA** and **gllvm VA** (gllvm supports gaussian, poisson,
  negative.binomial, binomial). **gllvm EVA is excluded — it errors on binomial**
  (*"Binomial distribution not yet supported with the EVA method"*), measured 2026-08-03.
- N=250, T=20, q=1, `n_starts = 1`, `H = 15`, 3 seeds. Report **time and `rel_frob` per
  family per engine**, plus the GH-vs-exact classification beside each row so the prediction
  is falsifiable on sight.
- Interleaved timing (never a single sequential pass) — the July arc's L-BFGS-B claim was
  inflated ~3x by exactly that mistake and had to be retracted.

### What each outcome means

| result | reading | next move |
|---|---|---|
| gaussian/Poisson fast, probit/nbinom2 slow | cost is **the GH loop** | attack quadrature; a probit augmentation (if one exists — see LITERATURE.md §2) becomes the highest-value item |
| all families ~60x slow | cost is **structural** | build #3 block-diagonal `S` and #4 warm-up as planned |
| mixed / neither pattern | the model is wrong | re-profile before building anything |

---

## P0c — APPROVED (maintainer, 2026-08-03), CONDITIONAL: EVA as the probit evaluator

Raised by the maintainer 2026-08-03 ("when mixture family — can we use mix of VA and LA?").
Recorded because the analysis is durable; **the arm itself is NOT approved and must not be
built without a decision.**

### The architecture already mixes evaluators — that is the answer to the question

Design 108 §0: *"every family sees the latent variable only through a scalar
`eta_ij ~ N(mu_ij, v_ij)`, so one 1-D Gauss-Hermite rule covers the family surface;
Poisson-log and Gaussian-identity are EXACT, binomial-logit needs GH, **EVA is a 2nd-order
Taylor surrogate**."*

The shared latent `q(u_i) = N(m_i, S_i)` is common to all traits, but the likelihood part of
the ELBO is a **sum of per-observation 1-D expectations**, so the *evaluator* is a free choice
per family. We already run exact + quadrature + bound evaluators inside one fit. Mixing is not
a trick to invent; it is the existing design.

**And EVA IS the Laplace-flavoured evaluator** — a 2nd-order Taylor expansion of the
intractable expectation is what Laplace does locally. So "use a Laplace-style shortcut for the
hard families" already has a name and a Gate-1 prototype (Design 86/94).

### Why this matters to THIS arc

Probit is slow because it is one of only two families forced onto Gauss-Hermite. If P0b's
family sweep confirms the cost is the GH loop, **EVA is a ready-made fix for the probit path
rather than an open research problem** — replacing quadrature with a closed-form surrogate.

### Three limits, stated so the option is not oversold

1. **VA and Laplace cannot be mixed as OBJECTIVES.** The ELBO is a lower bound; the Laplace
   marginal is not. A hybrid objective is neither, and Design 72 §0.4 already records that
   AIC/LRT are not comparable across `method = "LA"` vs `"VA"`. Mixing *evaluators inside one
   ELBO* is sound; mixing *objectives* is not.
2. **EVA trades accuracy for speed, and accuracy is this arc's protected constraint.** Our
   17-21% recovery edge over gllvm is the thing we are defending. An EVA probit path must be
   measured against that floor, not assumed to clear it.
3. **It does not generalise to mixture families.** Design 105 §10 found the architecture
   BREAKS for multinomial and for zero-inflated / `*_mix` families, which carry separate
   component predictors — so the "latent enters through one scalar `eta`" property fails.
   Whatever EVA buys for probit does not extend there.

### VERIFICATION the maintainer required before approving ("only if EVA is what you say")

**Confirmed, six independent places.** `docs/design/104-va-family-coverage.md:56` gives the
formula outright:

> **EVA.** Second-order Taylor about `mu`:
> `E[log p] ~= log p(y|mu) + (v/2) * d2/deta2 log p(y|eta)|_mu`. Cheap, and the only route
> for families where even 1-D quadrature is awkward. It is a **surrogate, not a bound** --
> it can sit either side of the truth.

Corroborated at `106:24`, `108:22`, `104:44`, the literature citation (Korhonen et al. 2023,
`2026-07-21-eva-cut-to-0.7.md:72`), and — importantly — an EMPIRICAL probe rather than a
reading: `2026-07-31-eva-misuse-probe.md:145` confirms *"`gllvm_va` really is the JJ bound,
`gllvm_eva` really is the Taylor surrogate."*

### TWO CONDITIONS that change how this arm must be built

**1. EVA is NOT a speed change -- it is a DIFFERENT OBJECTIVE.** It is a surrogate, not a
bound, and "can sit either side of the truth". This arc's discipline requires every speed
change to leave the objective identical to ~1e-13. EVA cannot satisfy that and must not be
smuggled in under it. Scope it as a separate estimator with its own accuracy evidence.

**2. A STABILITY GATE is mandatory, not optional.** From
`2026-07-27-gllvm-comparison-fairness-audit.md:304`: EVA's surrogate is *"known in the
literature to become unstable at higher dimension independent of whether the optimizer
converged cleanly on it."* Our own doc marks that as inference needing confirmation -- but it
is a highly plausible explanation for gllvm's EVA scoring **68% degenerate with ALL reporting
converged**, and our envelope (T = 20-30, N = 5397) is exactly the high-dimension regime.

  So the EVA arm is scored on **recovery against planted truth, at OUR dimensions**, never on
  convergence flags -- and a degeneracy rate is reported with its denominator. If EVA is fast
  and silently degenerate at T=20+, it is worse than the slow GH path it replaces.

### Priority (maintainer, 2026-08-03)

> *"VA will be more necessary to do -- getting correct and speedy VA will help a lot if we are
> already fitting the best algorithm to suitable distributions (families)."*

**VA speed is PRIMARY; EVA-for-probit is SECONDARY** and conditional on P0b showing the cost
is the GH loop. If the family sweep exonerates GH, this arm does not run at all -- there would
be nothing for it to fix.
