# Mature VA for gllvmTMB — the approved arc

**Approved by the maintainer, 2026-08-03.** This supersedes the earlier framing in `ARC.md`,
which aimed at two gllvm borrowings the profile has since deprioritised.

> **Read the evidence lines, not just the conclusions.** Four well-argued claims were overturned
> by measurement in a single day (see §6). Every claim below carries what would falsify it.

## 0. The goal, in the maintainer's words

> *"we want to have mature VA for gllvmTMB (not the current one) — one in gllvm or better"*
> *"getting correct and speedy VA will help a lot if we are already fitting the best algorithm
> to suitable distributions (families)"*

**Target: gllvm's speed + our accuracy + a capability gllvm does not have.** Not parity.

| | speed | accuracy (`rel_frob`, planted truth) |
|---|---|---|
| gllvm VA | **0.70 s** | 0.359 |
| ours | 45.6 s | **0.298** (better, 4/4 seeds) |
| our Laplace | 114.5 s | **0.170** |

Reference cell: single-tier, binomial-probit, N=250, T=20, q=1. **Accuracy is the CONSTRAINT,
not the trade** — a faster VA recovering worse than 0.298 fails the arc.

## 1. NOT a rewrite — the core is sound

The current engine is **correct**: its KL agrees with a direct-algebra oracle to **2.26e-16**,
the iid reduction is **exactly 0.000e+00**, and it **out-recovers the mature reference**. What is
missing is one component — a closed-form evaluator instead of Gauss-Hermite quadrature, which
the profile puts at **~75% of runtime**.

A rewrite would discard a verified KL, a working structured tier, and R3's profile route, to
re-derive them. **Evolve, don't restart.** *(Falsifier: if the closed-form substitution proves
impossible to graft onto the existing template, revisit.)*

## 2. The four approved items

### Item 1 — closed-form probit/ordinal evaluator (Albert-Chib) — PRIMARY

Removes the ~75% GH cost. Truncated-Gaussian auxiliary variables (`z_ij ~ N(eta_ij, 1)`,
truncated by `sign(y_ij)`), proved **at GLLVM level** by Hui, Warton, Ormerod, Haapaniemi &
Taskinen — the paper gllvm's own VA engine implements. **Theorem 1** binary probit,
**Theorem 3** cumulative-probit ordinal (Ayumi's other hard column, which Design 108 calls
*"the hard case"*). Uses only `Phi`/`phi` — **TMB-native smooth atomics**, so it is an
objective substitution, not an architecture change.

Corroborating: the literature corpus is unanimous that **no one makes GHQ cheaper — every
speed-up replaces it**, and GHQ cost is exponential in latent dimension.

**This is a DIFFERENT objective from the GH one.** It must carry its own accuracy evidence
against planted truth; it does not inherit GH's. *(Falsifier: if it recovers worse than 0.298,
it fails the arc's constraint regardless of speed.)*

### Item 2 — `profile_variational` default — STATUS: HALF-ESTABLISHED

**Established:** the two routes compute the **same objective**. Confirmed at five sizes,
relative agreement **1.7e-11 to 1.4e-9**. The source comment explains why: `profile=TRUE`
disables the Laplace approximation, so the outer objective is the **EXACT profile**
`min_{m,L} ELBO`, not an approximation of it. And the stated reason for the `FALSE` default —
*"sdreport across the profiled block is untested"* — **does not apply**: grep confirms **zero
sdreport machinery anywhere in the VA-R3 path**.

**NOT established: the speed rule.** Measured, interleaved, 2 reps:

| N | joint s | profile s | ratio |
|---:|---:|---:|---:|
| 120 | 0.04 | 0.19 | 0.19 |
| 250 | 0.15 | 0.35 | 0.42 |
| 500 | 5.06 | 3.80 | 1.33 |
| 1000 | 2.36 | 2.63 | **0.90** |
| 2000 | 13.42 | 4.13 | **3.25** |

**Non-monotonic** — joint is 5.06 s at N=500 but 2.36 s at N=1000. That is iteration-count
noise dominating a 2-replicate measurement, not a cost curve. Profile clearly wins at N=2000,
clearly loses below N=250, and **N=500-1000 is unresolved**.

**An unconditional flip would slow every small fit.** Four independent arguments supported
flipping (identical objective, 39x at N=1000, better L3 convergence, inapplicable sdreport
rationale) and the naive action would still have been wrong. **Do not set a threshold from this
data — re-measure with more replicates first.**

### Item 3 — per-family best evaluator throughout

Largely falls out of Item 1: the registry already dispatches per family
(`.va_r3_family_registry`); probit and ordinal simply gain a better tier alongside
`exact` / `quadrature` / `bound`. Current state:

| family | evaluation | consequence |
|---|---|---|
| gaussian | **exact** — quadrature nodes never touched | fast |
| poisson | **exact** — log-normal mean | fast |
| binomial-logit | **bound** (JJ) | fast |
| binomial-probit | **quadrature** | **slow — the target** |
| nbinom2 | **quadrature** | slow |

The **family sweep (P0b)** confirms this mechanism across families and is cheap. *(Falsifier:
if gaussian and Poisson are ALSO ~60x slower than gllvm despite touching no quadrature nodes,
GH is exonerated and the cost is structural — re-aim.)*

### Item 4 — re-measure against gllvm, speed AND accuracy

Baseline locked in §0. **Interleaved replicates, never a single sequential pass** — the July
arc's L-BFGS-B claim was inflated ~3x by exactly that error and had to be retracted.

## 3. Deprioritised on evidence (not abandoned)

- **Block-diagonal `S`** (gllvm `Ab.struct`): targets the **inner solve**, which the profile
  shows is healthy — `nnz/dim` flat (Stage 7) **and** inner iteration count flat (this profile).
  It aims at a cost that is not there.
- **Two-stage warm-up** (`diag.iter`): **no literature support at all** — the corpus does not
  address staged schedules anywhere in 14 sources.
- **EVA as the probit route**: likely superseded. EVA is a **surrogate, not a bound** — *"it can
  sit either side of the truth"* — and the 2026-07-31 misuse probe measured its own objective
  preferring a runaway solution (attenuation 8.8e+08) at **-327.4** over the **true parameters**
  at **-618.6**, by **291 nats**, with MORE restarts making it WORSE. Albert-Chib gives closed
  form **while remaining a genuine bound**. Run EVA only if the closed form fails.

## 4. Where the time actually goes (the profile)

**Single-tier, 18.3 s:** `nlminb` 89.0%, of which `gr()` 65.1% and `fn()` 33.9%. **GH is ~75% of
TOTAL** — measured by node scaling (`fn` 23.3 / 46.7 / 92.6 ms at H = 15 / 25 / 61). Taping
4.6%. No `sdreport` bucket exists.

**Structured tier:** the blowup is **not** GH, TMB, the tape, or the inner solve. At N=1000 it
is **99.83% `nlminb`'s own outer bookkeeping** (genuine `fn`/`gr` work: **0.17%**), because the
default hands `nlminb` a vector growing as **34xN**. The profiled route pins outer par at **32**.

**GH multiplier on the structured tier: 8.8x** (N=100/T=8: gaussian 22.8 s vs probit 199.7 s).

## 5. The campaign question this unblocks — and an early warning

Design 108's headline — *does structured VA recover the two-tier `Sigma_B` better than
Laplace?* — is **still open**. First N=1000 seed (gaussian, both tiers extracted):

| | tier-1 | **tier-2 (phylo — the headline)** |
|---|---|---|
| VA | 0.747 | **16.89 — DEGENERATE** (threshold 10) |
| Laplace | **0.186** | **0.704** |

**One seed. Not a finding.** But if it holds, VA's structured phylo tier *runs away* at N=1000
while Laplace's improves (1.18 at N=150 -> 0.704 here) — which would answer the campaign
against VA and make the Stages 3/5 verdict follow.

Also note the **informativeness precondition**: the corrected control curve had tier 2 still at
0.38-0.43 at N=1000 against 0.09 for tier 1. Cells where no arm recovers tier 2 cannot
discriminate the engines, and `d ~ 0` there is **not** evidence of equivalence.

## 6. Four claims overturned by measurement in one day — read §0's warning again

| claim | why it was believed | what overturned it |
|---|---|---|
| "probit is unavoidably slow (no JJ bound)" | the family registry says probit has no bound | **gllvm fits probit VA in 0.7 s** without one |
| "gllvm EVA cannot fit binomial" | one failed call | **my `Ntrials = 6`** — EVA fits Bernoulli fine, rejects only multi-trial |
| "VA is slower than Laplace at every n" | the 640-cell grid headline | **configuration-dependent** — ours is 2.4x FASTER at the reference cell |
| "flip the `profile_variational` default" | 4 independent sound arguments | **0.19x at N=120** — the 39x is large-N only |

The pattern is not carelessness: it is **scope qualifiers being dropped on recall**. Every
source was correct; the conclusions were not. Hence the evidence lines above.
