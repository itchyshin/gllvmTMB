# VA speed arc — the plan that makes our VA fast

**Date:** 2026-07-27
**Author:** Ada (orchestrator), consolidating three adversarially-verified lenses
**Status:** PLAN. Nothing implemented. Nothing committed. All evidence LOCAL (D-50).
**Scope guard:** this document is `docs/dev-log/` only. `R/`, `src/`, `inst/`, `tests/`
are owned by another live agent in this worktree and were **read but not edited**.

---

## 0. Evidence base and what is new here

Three lenses fed this plan. Two were supplied to me with their adversarial
verifications (`gllvm-prior-art` / Polya, verified in
`dev/va-speed-verify-gllvm-prior-art.md`; `our-profile`, verified by Noether in
`dev/va-speed-verify-our-profile.md`). A **third** lens — Fisher's "the wall"
(`dev/va-speed-the-wall.R`, `dev/va-speed-the-wall-run.log`,
`dev/va-speed-the-wall-{memory,qsweep,primary}.csv`) — was **not** in my brief and I
found it in the worktree. It carries the single most decisive measurement in the whole
campaign (§1, H1(c)) and one result that **falsifies the campaign brief's own premise**
(§5.1). Reading it changed this plan.

Everything below distinguishes:

- **MEASURED** — a number from a log or CSV in `dev/`, cited by file.
- **READ** — a fact verified in source, cited by file and line.
- **AGENT-INFERRED** — my extrapolation or reasoning. Never load-bearing for a claim.

The two independent verification passes already stripped out several false claims
(a fabricated ">15-minute observation window", every gllvm line number in the first
lens, an unpaired-median stability argument). Those corrections are carried through
here; I do not re-quote the retracted material.

---

## 1. Verdict table on H1–H4

| # | Hypothesis | Verdict | Strength |
|---|---|---|---|
| **H1** | `nlminb` (PORT) per-iteration cost is O(p²) in the FULL parameter count, so 25,000 parameters kills it | **SUPPORTED** | Three independent measurements, including a decisive axis-crossover test |
| **H2a** | The joint optimisation explains our gap **relative to gllvm** | **REFUTED** | gllvm does the identical joint optimisation |
| **H2b** | Restructuring to a per-unit inner solve is the **right fix** | **UNTESTED** | Never built, never timed. Now the leading structural candidate |
| **H3** | We hardcoded gllvm's most expensive variational covariance | **REFUTED** | Premise factually wrong *and* the change would not pay |
| **H4** | `diag.iter` two-stage warm-up is a speed win | **Mechanism CONFIRMED, benefit REFUTED** | Paired ratios straddle 1.0 |
| **H5** *(new)* | Our 4-start agreement gate is the largest single measured constant | **SUPPORTED as a cost; scientific value UNRESOLVED** | 3.3–4.5×, and it admitted nothing on any tested DGP |

### H1 — SUPPORTED

Three independent lines, none of which is architecture inference.

**(a) Isolation, mechanism.** `nlminb` on a trivial separable quadratic (fn/gr cost
≤1e-5 s/call, so anything that grows is the optimiser), at a *realistic* iteration
budget (`iter.max = 60`, matching the ~170 iterations the real fit uses — the original
isolation test ran degenerate at ~1800 iterations and Noether re-ran it):
per-iteration slope **2.27** in p; **71.3 ms/iter at p=4023**, **335 ms at p=8023**,
**815 ms at p=12523**. Confirmed **per-iteration, not one-time workspace setup**:
p=2023 at budgets 60/240/960 gives 15.35 / 15.06 / 15.25 ms per iteration.
Source: `dev/noether-verify-va-speed.log`.
Cross-check: `optim`/BFGS is *equally* quadratic (252.1 MB at p=8000);
**`L-BFGS-B` is flat (8.3 MB)**.

**(b) Memory on the real objective.** Peak RSS delta over baseline quadruples per
doubling of p: **207.6 / 270.5 / 485.4 MB at npar 2017 / 4017 / 8017**
(`dev/va-speed-the-wall-memory.csv`). This matches PORT's analytic workspace
`71 + p(p+15)/2` doubles to the megabyte. At our n=5000 cell (npar 25,017) that
workspace alone is **≈2.5 GB**.

**(c) The decisive axis-crossover test** — this is the strongest result in the campaign
and neither of the two briefed lenses reported it. Hold N fixed at 800 and vary q so
that parameter count moves along a *different axis*
(`dev/va-speed-the-wall-qsweep.csv`, 3 interleaved reps):

| cell | npar | median wall |
|---|---|---|
| N=800, q=1 | 1,610 | 0.97 s |
| N=800, q=2 | 4,017 | 10.04 s |
| **N=800, q=3** | **7,223** | **50.42 s** |
| **N=1600, q=2** | **8,017** | **46.82 s** |

The last two rows are nearly matched in parameter count and cost **the same time
despite a 2× difference in N**. Cost tracks **parameter count**, not n. That is exactly
H1's claim, tested on the real objective, and it is the reason the fix is a *parameter-count*
fix and not an *n* fix.

**(d) Iteration count is NOT the driver.** Objective-call counts are near-flat in n
(slope 0.17 fn / 0.23 gr over n=150→800); implied nlminb iterations are
179 / 165 / 168 at n=150 / 400 / 800 — flat across a 5.3× range of n. Wall clock is
fully reconstructed by **(flat ~170 iterations) × (p^2.27 per-iteration cost)**.

**Still untested inside H1:** whether the O(p²) is specifically PORT's dense secant
Hessian update or merely its workspace allocation. Irrelevant to the plan — the fix is
identical either way — but it is not settled, and no one should write that it is.

### H2 — split verdict; the half that matters is UNTESTED

**H2a (REFUTED).** gllvm — the reference that beats its own Laplace at small n — performs
the *same* single joint optimisation we do. All three VA/EVA `TMB::MakeADFun` call sites
in `gllvm.TMB.R` (**L1365, L1403, L1617**, corrected line numbers from the verification
pass) omit `random=`; `randomp <- NULL` is at **L1977**, inside the `method=="LA"` branch,
and is never in scope in the VA branch. There is no inner loop, no coordinate ascent, no
profiling anywhere in gllvm's VA path. Their parameter layout is identical to ours
(`u` / `Au`-log-diag / `Au`-off-diag = our `m` / `log_L_diag` / `L_off`), confirmed by a
live fit: **npar = 273** at n=50, p=8, q=2, dropping to **223** under
`Lambda.struc="diagonal"` — exactly the 50-parameter off-diagonal block. So H2 cannot
explain our gap *relative to gllvm*; they have the same architecture.

**H2b (UNTESTED — and I am naming it as untested).** Whether exploiting per-unit
independence *fixes* the problem has never been built, never been timed, and is not
evidenced by anything in this campaign. What is **not** in doubt (verifiable by
inspecting the ELBO, not by measurement): each unit's variational block enters only its
own T rows of the likelihood, so the Hessian of the ELBO with respect to the variational
parameters is **exactly block-diagonal with N blocks of size 2q + q(q−1)/2** (5 at q=2).
That structure is real. That it delivers is a hypothesis. §3 argues it *should*, and §4
specifies what would prove it did not.

Note the direction the verification pass got right and I am preserving: the premise
refutation in §5.1 **removes gllvm as a ceiling**, which makes H2b *more* interesting,
not less. We are not trying to match gllvm. We are trying to beat the architecture both
packages share.

### H3 — REFUTED, on two independent counts

**The premise is factually wrong.** `Ab.struct` governs the variational covariance of
**random slopes**, not latent variables. It is passed as `sp.Ar.struc` and consumed only
inside `if (col.eff == "random")`, so for a plain `gllvm(y, family, num.lv=2)` it and
`Ab.struct.rank` are **completely inert**. The latent-block control is `Lambda.struc`,
whose gllvm **default is `"unstructured"`** — the full per-unit Cholesky, identical to
ours. We match their default; we did not hardcode their most expensive option.

**And the change would not pay.** Forcing `Lambda.struc="diagonal"` inside gllvm is
1.5–1.7× faster but costs a **median 6.84 / 18.24 / 50.49 nats** of logLik at
n=200 / 500 / 1000 — a gap that **grows with n**. It is a different variational family,
hence a different ELBO: a faster wrong answer, which the campaign's hard rules prohibit
being sold as a speed-up. Separately, at q=2 it removes only N of 5N+23 parameters
(773 → 623, a 19% cut), which under the measured p^2.3 law is ≈0.66× — an order of
magnitude below H1's fix.

**Disposition:** keep a diagonal tier as an optional user-visible *approximation* choice
at large q, clearly labelled as a different objective. Never as the speed route.

### H4 — mechanism CONFIRMED, benefit REFUTED

The `diag.iter` machinery is exactly as hypothesised and verified in source: `Au` is
initialised diagonal-only, a gate fires, the off-diagonal block is appended as zeros, a
**new** `MakeADFun` is built and the optimiser runs a second time. Parameter count
confirms the first-stage block is genuinely absent (223 vs 273), not mapped off.

The benefit does not survive paired analysis. Ratios vs `diag.iter=0` are
**0.928 / 0.964 / 1.026** at n=200 / 500 / 1000 — straddling 1.0 — with logLik identical
to 5–6 significant figures. gllvm's own help claims only that it "can sometimes" help,
and they default the analogous `Ab.diag.iter` to **0** for the block where it would
actually matter.

**Disposition: DO NOT PORT.** This is a closed question.

### H5 (new) — the 4-start agreement gate

Not in the original hypothesis list, and it is the **largest single measured constant**
in our fit. `R/va-r3-proto.R:851` builds 4 starts; `:871` loops them; each start runs
`nlminb`, then **up to two further `nlminb` re-runs** when the gradient exceeds 1e-4
(`:890-902`), then optionally L-BFGS-B (`:905-928`) — **up to 16 optimiser invocations
per reported fit**. gllvm's default is `n.init = 1`.

Measured cost: **3.33× at N=200, 3.93× at N=400** (Poisson, T=8, q=2, medians of 3,
interleaved) and **4.45×** at N=400 on the binomial DGP (2.36 s one-start-one-call vs
10.51 s full). Objectives across starts agreed to **<6e-9** in all six replicate pairs
(three exactly 0.0); full 1023-parameter vectors agreed to **max |Δpar| 1.98e-05**, with
**max |Δ| on beta/theta_rr 8.17e-06** and no sign flips.

And it **admitted nothing**: all six four-start Poisson fits returned
`status = failed_health_gate`, `healthy_starts = 0 of 4`.

**A synthesis neither lens made explicitly (AGENT-INFERRED, and falsifiable — see §4.5):**
the gate is not failing because its 1e-4 gradient tolerance is too tight. It is failing
because **`nlminb` cannot reach that tolerance**. Measured single-call `maxgrad` for
nlminb is **4.9e-4 / 9.8e-4 / 1.2e-3** at n=150 / 400 / 800 — above 1e-4 at *every* n —
while **L-BFGS-B alone lands at 2.6e-5 / 4.4e-5 / 5.7e-5**, inside tolerance unaided.
That is why the polish always fires, and it predicts that fixing the optimiser should
flip `healthy_starts` from 0/4 to 4/4. If it does not, my model of the gate is wrong.

**Disposition:** the gate's cost is an engineering fact; whether to keep it in production
fits is Shinichi's scientific call, not mine.

---

## 2. The ranked plan

Two tiers, kept strictly separate as the brief demands.

**Tier S — provably the SAME optimum** (a different path to the same stationary point;
must pass the §4 verification but carries no statistical risk).
**Tier D — a DIFFERENT algorithm** (reaches a stationary point of the same objective,
but by a route whose equivalence must be *proved*, not assumed).
**Tier X — changes the objective.** Explicitly rejected as a speed route.

| Rank | Change | Tier | Expected gain | Changes estimates? | Effort | Depends on |
|---|---|---|---|---|---|---|
| **R1** | `n_starts` as a parameter of `.va_r3_fit()` (default 4 kept; `n_starts = 1` for benchmarking and for the large-n path) | **S** | **3.33× (N=200), 3.93–4.45× (N=400)** — MEASURED | **No.** Verified at estimate level: obj Δ ≤6e-9, max\|Δpar\| 1.98e-05, max\|Δbeta,θ\| 8.17e-06 | hours | — |
| **R2** | **L-BFGS-B as the PRIMARY optimiser**, not the conditional polish | **S** | **2.21× / 3.75× / 11.13×** at n=150/400/800; wall-clock exponent **2.21 → 1.27**; peak memory 490 → 188 MB — MEASURED | **No**, on the cell tested: obj gap ≤1.1e-6 absolute (≤2.4e-10 relative), beta agrees to 2.3e-05–6.4e-04 | hours (the call already exists verbatim at `R/va-r3-proto.R:914`) | R1 (so the timing is not swamped by 4 starts) + the §4.2 fragility resolution |
| **R3** | **Move the variational block to `TMB::MakeADFun(..., profile=)`** — the structural change | **D** | Makes the *outer* problem 23 parameters and the iteration count **n-independent by construction**; projected O(N) — **UNMEASURED, AGENT-INFERRED** | Must be **No** — that is the §4 gate | multi-day | R1, R2 (as the fallback and as the comparator) |
| **R4** | Residual-factor-analysis warm start for the variational **means** and log-SDs (we already warm-start loadings; `m`, `log_L_diag`, `L_off` all start at exactly 0, `R/va-r3-proto.R:466-468`) | **S** | **~2.5× median (range 1.7–4.2×)** measured *inside gllvm*; transfer to our code is inference | **No** (a start, not an objective) — but a *better* optimum is possible, which must be reported honestly, not as a speed-up | day | independent; multiplies with R2 and R3 |
| **R5** | Diagnose the health gate: does R2/R3 flip `healthy_starts` 0/4 → 4/4? | — | No speed gain. **Gates the trustworthiness of every VA benchmark we publish** | n/a | hours, once R2 lands | R2 |
| **R6** | Fix the polish-overwritten counter bug: `opt <- candidate` at `R/va-r3-proto.R:900` discards the earlier calls' `iterations`/`evaluations`, so the reported counters are the *last accepted call's* only (observed: `iterations=2, fn_evals=5` for a fully converged cold start) | — | No speed gain; removes a wrong diagnostic that already produced one published-in-`dev/` false figure | No | hours | — |
| **R7** | Retract `optimizer_overhead_frac = 0.993–0.999` in `dev/va-speed-our-profile-run.log` panel 3 — computed from the broken counters R6 fixes. Correct figures: **66.5% / 83.4% / 92.1%** at n=150/400/800 | — | none | No | minutes | R6 |
| **R8** | Re-run everything on a quiet machine or Totoro before any absolute number leaves `dev/` | — | Converts within-cell ratios into quotable absolutes | No | hours | all of the above |
| ~~RX~~ | ~~Diagonal / rank-1 variational covariance~~ | **X** | 1.5–1.7×, at 6.8–50.5 nats — and the deficit grows with n | **Yes — different variational family, different ELBO** | — | **REJECTED as a speed route** |
| ~~RY~~ | ~~Reduce to 2 starts~~ | — | ~~2×~~ | **Yes, silently** | — | **REFUTED.** `R/va-r3-proto.R:954,957-958` require `length(healthy_id) >= 3L`; with 2 starts `admitted` is FALSE *unconditionally*. This is gate removal dressed as a speed knob |
| ~~RZ~~ | ~~Port gllvm's `diag.iter`~~ | — | 0.93–1.03× | No | — | **REFUTED** (H4) |

**Dependency order:** R6+R7 (make the instruments honest) → R1 (stop charging the gate to
every timing) → R2 (the cheap, measured, large win) → R5 (does the gate now mean
anything?) → R3 (the structural change, with R2 as both fallback and comparator) → R4
(multiplies with whatever architecture wins) → R8 (before any claim leaves `dev/`).

**Why R2 outranks R3 despite R3 being the "real" fix.** R2 has 11.13× measured on the
real objective with same-optimum verified; R3 has zero measurements. The campaign's own
hard rule is *never infer relative cost from architecture*. R3 earns its place because of
what R2 cannot promise (§3), not because it is more elegant.

---

## 3. THE STRUCTURAL QUESTION — answered

> Should the variational parameters stay as ordinary TMB parameters in one joint
> optimisation, or move to a per-unit inner solve (or TMB's `random=` mechanism)?

### The answer

**They should move — but to TMB's `profile=` mechanism, not to `random=`, and not to a
hand-rolled block-coordinate loop.** Concretely:

```r
TMB::MakeADFun(
  data, parameters,
  random  = c("m", "log_L_diag", "L_off"),
  profile = c("m", "log_L_diag", "L_off"),   # <- Laplace DISABLED
  ...
)
```

### Why `profile=` and not `random=` — the crux

`random=` **alone** applies TMB's Laplace approximation: it adds a
`−½ log det H` term and *integrates out* the named parameters. That would be
**mathematically wrong here**. The variational parameters are not latent random
variables to be integrated over; they are optimisation variables of a deterministic
bound. Adding a log-determinant would turn the ELBO into a Laplace approximation *of*
the ELBO — a quantity with no interpretation.

`profile=` is the mechanism that does what we want. TMB's own documentation
(`?MakeADFun`, verified verbatim on the installed TMB in this environment):

> **profile:** Parameters to profile out of the likelihood (this subset will be
> appended to `random` **with Laplace approximation disabled**).

Laplace disabled means: TMB runs its **inner Newton solver** on those parameters to
their conditional optimum, and returns the **exact profiled objective**, with **no**
log-determinant correction. That is, by construction,

  `min over (variational block) of ELBO(fixed, variational)`

which is precisely the function the current joint optimisation is minimising over its
last 5N coordinates. **The optimum is the same by construction, not by hope** — which is
why R3 sits in Tier D only because of *numerical* equivalence risk (§4), not
*mathematical* equivalence risk.

This is not exotic. `glmmTMB` uses the same mechanism (`glmmTMBControl(profile=)`) to
profile fixed effects into the inner problem for speed. It is battle-tested TMB.

### Why this is the fork, and why it dominates

Three things change at once, and each is a direct answer to a *measured* problem:

1. **The outer parameter count collapses from 5N+23 to 23.** At n=5397, T=8, q=2 that is
   **27,002 → 17** (the exact layout: `npar = 5N + (T·q − q(q−1)/2) + p_beta`, verified
   against the-wall's reported npar = 25,017 at N=5000). H1's measured p^2.27
   per-iteration law then applies to a 17–23 dimensional problem. It becomes free.
2. **The inner solve exploits the structure we already have.** TMB detects the sparsity
   of the inner Hessian from the tape. As established in §1/H2b, that Hessian is
   **exactly block-diagonal, N blocks of 5×5**. A sparse Cholesky of a block-diagonal
   matrix is **O(N·q³) — linear in N**. This is the only route in this document under
   which the *iteration count itself* stops depending on n.
3. **The ~2.5 GB PORT workspace disappears**, along with the memory wall that arrives
   at n≈5000 on any machine with less than ~8 GB free.

### Defending it against the alternative: a hand-rolled per-unit block-coordinate loop

The brief's H2 describes exactly this — alternate closed-form/few-Newton per-unit updates
with fixed-parameter updates. It is correct mathematics and I am **rejecting it as the
first implementation**, for four reasons:

- **It is the same algorithm, implemented worse.** TMB's inner Newton *is* a per-unit
  Newton solve — it just discovers the block structure automatically from the tape and
  uses exact AD derivatives and a sparse Cholesky, rather than derivatives we would have
  to re-derive per family.
- **Per-family closed forms do not exist uniformly.** The variational optimum is closed
  form for the Gaussian anchor and for the JJ bound, but not for Poisson-exact, and
  certainly not for nbinom2 under Gauss-Hermite. We would ship four different inner
  solvers with four different correctness proofs.
- **Convergence guarantees must be re-derived.** Alternating minimisation converges to a
  stationary point under block-convexity, which we have not established for
  `log_L_diag`/`L_off`. `profile=` needs no such theorem: the outer objective is the
  exact profile, and the outer optimiser's own convergence theory applies unchanged.
- **Effort.** R3 is a `MakeADFun` argument plus verification. H2's version is a multi-day
  numerical-methods project.

**Keep it as the documented fallback (R3-fallback):** if TMB's inner Newton proves
unstable on the `log_L_diag`/`L_off` parameterisation (§4.3), the hand-rolled loop is the
next thing to build, and by then we will know exactly which family and which parameter
block is misbehaving.

### And what does gllvm do?

**gllvm does neither.** gllvm performs the *same single joint optimisation we currently
do* — all three of its VA/EVA `MakeADFun` sites omit `random=`, `randomp` is scoped to
the `LA` branch only, and their parameter layout matches ours parameter-for-parameter
(npar 273 at n=50, p=8, q=2). Their VA-beats-their-own-Laplace advantage comes from
**avoiding TMB's Laplace inner Newton and its sparse Cholesky**, which we already avoid.

The consequence is worth stating plainly, because it inverts the campaign's framing:
**there is no prior art to copy here.** gllvm's own VA scales n^2.25 (§5.1). If R3 lands,
we would not be catching up to the reference implementation — we would be doing something
neither package currently does.

---

## 4. What would make this NOT work — failure modes, and the verification gate

### 4.1 The gate on the whole arc: proving the new algorithm reaches the same optimum

This is the requirement that decides whether R3 ships. **Objective-value agreement is not
sufficient** — the first lens's `same-optimum` classification was asserted from the scalar
objective alone and only survived because a verifier went and checked the parameter
vectors. The protocol below is ordered so that each level catches what the previous one
cannot.

Reference implementation for all levels: the **current** `.va_r3_fit()` path
(`random = NULL`, 4 starts, nlminb + polish), frozen at its current commit, run on the
identical simulated dataset with the identical start.

| Level | Test | Pass criterion | Catches |
|---|---|---|---|
| **L0** | ELBO at convergence | `\|Δobj\|` ≤ 1e-6 absolute **and** ≤ 1e-9 relative | Gross algorithm error |
| **L1** | Fixed parameters `beta`, `theta_rr` | max `\|Δ\|` ≤ 1e-5, after canonicalising loading-column signs (positive diagonal) | A different stationary point with a coincidentally similar objective |
| **L2** | Variational block `m`, `log_L_diag`, `L_off` | max `\|Δ\|` ≤ 1e-4. **Read from `obj$env$last.par.best`** — under `profile=` this block is no longer in the outer `par` vector | An inner solve that stops short and hides it in a flat objective |
| **L3** | **The decisive test.** Assemble the new solution's *full* parameter vector, feed it to the **ORIGINAL** joint `MakeADFun` object (`random = NULL`), and evaluate its gradient | max `\|grad\|` < 1e-4 — the package's own health tolerance | Everything L0–L2 can miss. This proves the new answer is a **stationary point of the old objective**, which no amount of value agreement does |
| **L4** | Gate invariance | `healthy_starts`, `best_three_objective_range`, `max_projected_variance`, and `status` unchanged across all 4 starts | An architecture that is fast because it quietly converges less |
| **L5** | Regime coverage | L0–L4 pass on **every** cell of: family {`gaussian_anchor`, `binomial`(jj), `binomial`(gh), `poisson`, `nbinom2`} × q {1, 2, 3} × N {50, 150, 400, 800}. **Smoke one tiny cell first** and confirm non-empty valid output before launching the grid | A fix that works on the one DGP we happened to profile. `nbinom2` is mandatory: it is the *only* family that spends quadrature nodes (`R/va-r3-proto.R:508-558` — Poisson is `expectation="exact"`, binomial defaults to the closed-form `jj` bound) |
| **L6** | Existing test suite | Every `tests/testthat` file touching `va_r3` passes unchanged | Contract breakage |
| **L7** | **Negative control** | Deliberately loosen the inner Newton tolerance to 1e-2 and confirm **L3 FAILS** | A verification that cannot fail is not a verification |

**L7 is not optional.** If the perturbed implementation also passes L3, the protocol is
measuring nothing and the arc stops until it is fixed.

**Timing evidence, separately and to the campaign's hard rules:** interleave replicates
across conditions within each rep, ≥3 reps, report medians, state that you interleaved,
record `logLik`/objective on every fit so a "speed-up" that moved the optimum cannot pass,
and — per the verification pass that caught it — compute **paired within-rep ratios with
ranges**, not ratios of unpaired medians. Unpaired medians silently compare rep 1's arm A
to rep 3's arm B, which is how a "reproduces to 0.5%" claim got fabricated once already.

### 4.2 R2 (L-BFGS-B primary) — the known fragility, unresolved

`dev/va-speed-the-wall-primary.csv`, N=1600, gaussian_anchor, 3 reps, nlminb vs
L-BFGS-B as primary from an identical start:

| rep | nlminb | L-BFGS-B |
|---|---|---|
| 1 | 54.66 s, obj **19688.24** | **0.023 s**, obj 20826.12 |
| 2 | 48.66 s, obj 20212.82 | 1.048 s, obj 20212.88 |
| 3 | 50.14 s, obj **19485.21** | **0.023 s**, obj 20226.75 |

**Two of three reps aborted in 23 milliseconds at a worse objective.** Rep 2 matched
nlminb's optimum in 1.05 s (a 46× speed-up). This directly contradicts the clean
2.21×/3.75×/11.13× result and **must be resolved before R2 ships**.

**AGENT-INFERRED most likely cause:** the-wall's harness calls
`optim(..., method="L-BFGS-B", control = list(maxit = maxit))` with **no `factr`**, i.e.
optim's *default* tolerance — whereas both the production polish call
(`R/va-r3-proto.R:914-917`) and Noether's V2 pass
`factr = 1e-12 / .Machine$double.eps`. A default-`factr` L-BFGS-B terminating at iteration
0–1 is the textbook symptom. This is a plausible harness artefact, **not** evidence
against L-BFGS-B — but it is *unresolved*, it involves a different family
(gaussian_anchor vs binomial-jj) and a much larger N than any cell where R2's win was
measured, and **"probably a harness bug" is not a finding**. Resolving it is the first
task of R2: re-run the-wall's cell with the production `factr`, record `convergence`
codes (a code of 52 is `ABNORMAL_TERMINATION_IN_LNSRCH`), and report either way.

**Second risk on R2 (AGENT-INFERRED):** the measured exponent 1.27 comes from n=150→800,
a 5.3× range. Limited-memory BFGS with the default memory `m=5` carries poor curvature
information on an ill-conditioned 27,000-dimensional problem, and its **iteration count
typically grows with dimension**. The exponent may not extrapolate. This is precisely the
gap R3 closes and R2 cannot.

### 4.3 R3 (`profile=`) — the failure modes

- **Inner Newton non-convergence.** The ELBO is concave in `m` for log-concave
  likelihoods, but `log_L_diag` enters through `exp()` and `L_off` is unconstrained, so
  the inner problem is **not guaranteed convex**. TMB's inner Newton can fail or oscillate.
  *Symptom:* inner-solver warnings, non-monotone outer objective, L3 failure.
  *Mitigations, in order:* tune `inner.control` (gllvm's own LA path sets
  `mgcmax = 1e200, tol10 = 0.01` for exactly this reason); reparameterise the inner block
  to improve conditioning (this changes the *path*, never the optimum); fall back to the
  hand-rolled block-coordinate loop.
- **Sparsity not detected, or detected expensively.** If TMB's tape does not resolve the
  block-diagonal structure, the inner Cholesky becomes dense in 5N and the change is a
  *pessimisation*. *Detection:* inspect the reported inner Hessian sparsity pattern before
  timing anything; the nnz must be N·15 (lower triangle of N 5×5 blocks), not O((5N)²).
- **Standard errors break.** `profile=` changes what `sdreport()` computes and how the
  delta method is applied across the profiled block. **Our VA SE story is not covered by
  the §4.1 protocol** and must be re-derived separately. This is a real, named open item
  (§6), not a detail.
- **Warm-start interaction.** TMB reuses `last.par.best` as the inner start. That is a
  *benefit* (each outer iteration's inner solve starts near its answer) but it makes the
  fit **path-dependent on evaluation order**, so a single-fit reproducibility check
  (same seed, same start, twice) belongs in the protocol.
- **It might simply not be faster.** The outer problem may need many more iterations than
  the joint problem needed in total. R3 has zero measurements; treat a null result as a
  live possibility and report it as a negative result if it happens.

### 4.4 R1 — the honest caveats

R1 is a constant factor, **not a scaling fix**. Removing a 4.45× constant from an n^2.2
curve moves the wall by 4.45^(1/2.2) ≈ 1.98×, i.e. from n≈2500 to n≈4900 — and no
further. Any write-up that frames R1's "roughly parity at n=400" as fixing the scaling
problem is wrong. Also: part of the 4× is **four TMB tape builds**, not four optimiser
runs; the comparison must be like-for-like. And "start 1 suffices" is **unproven** — in
one verified run the four-start winner was **start 3**.

### 4.5 The falsification test I owe you

§1/H5 claims the health gate fails because nlminb cannot reach 1e-4, not because the
tolerance is wrong. That is AGENT-INFERRED. It makes a sharp prediction: **after R2 (or
R3), `healthy_starts` should go from 0/4 to 4/4 on the same Poisson and binomial DGPs.**
Run it as R5. If it does not, my model of the gate is wrong and §1/H5's disposition must
be rewritten.

---

## 5. Honest speed estimate — does n = 5397 become reachable?

### 5.1 First, a correction to the campaign brief

The brief states our VA "does not complete beyond n ~ 2500 (times out 12/12)". The
the-wall sweep **completed n = 5000**:
`dev/va-speed-the-wall-run.log`, gaussian_anchor, T=8, q=2, npar 25,017, one start, one
`nlminb` call at `iter.max=300`: **536.5 s and 497.8 s, convergence = 0 in both**.
Median ≈ 517 s ≈ 8.6 minutes.

So the n≈2500 wall is a **wall-clock budget wall, not an impossibility wall**. What times
out is the *full 4-start fit* (up to 16 optimiser invocations), not the underlying
optimisation. Caveat, stated plainly: this is the **gaussian anchor**, the cheapest
per-call family; I did not re-run it at binomial or nbinom2, and I did not verify the
brief's timeout harness.

The same log gives our scaling exponent as **n^2.20** (0.09 s at N=100 → 517 s at N=5000),
which sits inside the brief's stated n^1.9–2.7 band, and **matches gllvm's own default VA
at n^2.25** (2.33 / 18.03 / 87.74 s at n=200 / 500 / 1000). Neither package has solved
the scaling problem.

### 5.2 Projections at n = 5397, T=8, q=2 (npar = 27,002)

| Scenario | Projected wall clock | Basis |
|---|---|---|
| **Today, 1 start, 1 nlminb call** | **≈600 s (10 min)**, ≈2.9 GB PORT workspace | MEASURED 517 s at N=5000, scaled by the measured n^2.20 |
| **Today, full 4-start fit** | **≈40–45 min** | above × the measured 4.45× gate cost |
| **R1 only** | **≈10 min** | R1 removes the 4.45× |
| **R1 + R2, if exponent 1.27 holds** | **≈12 s single start, ≈50 s at 4 starts** | MEASURED 1.075 s at n=800 (binomial-jj, L-BFGS-B primary), scaled by the measured exponent 1.27 |
| **R1 + R2, if exponent 1.27 does NOT extrapolate** | **≈2–10 min** | the honest downside: L-BFGS-B's per-iteration cost is flat, but its iteration count may grow with dimension |
| **R1 + R2 + R3 (`profile=`)** | **tens of seconds, with an n-INDEPENDENT iteration count** | AGENT-INFERRED. Anchored on a measured quantity: 2.6 ms per fn/gr call at n=800 → ~17 ms at n=5397 under the measured near-linear per-call law (slope 0.88–0.99). ~150 outer iterations × ~4 evaluations × ~2–3 inner steps ≈ 1200–2000 evaluations ≈ **20–35 s**. The iteration counts are **assumed**, and that is the whole risk |
| **R1 + R2 + R3 + R4 (warm start)** | plausibly 1.7–4.2× better again | measured range inside gllvm; transfer is inference |

The 12 s figure carries a warning I want on the record: it extrapolates a measured
exponent 6.75× beyond the largest n it was measured at (n=800), for a total 36×
extrapolation. It is the *optimistic* end of a range, not a prediction.

### 5.3 The verdict, plainly

**YES — n = 5397 becomes reachable. And the sharper, more honest finding is that it is
already reachable today**: ≈10 minutes for a single-start gaussian fit, ≈40 minutes with
the 4-start gate, at a ~2.9 GB memory cost. The campaign brief's "cannot fit at all" is
overstated for the gaussian anchor; what we cannot do today is fit it *routinely*, or on
a machine with modest RAM, or in a simulation campaign where the fit runs hundreds of
times.

The plan converts **"possible in 40 minutes and 3 GB"** into **"routine in well under a
minute and a few hundred MB"** — and R1+R2 alone, which are hours of work and both
Tier S, are very likely sufficient to get there. R3 is what buys headroom to n = 20,000+
and what makes an O(N) claim defensible rather than extrapolated.

**Three caveats that could invalidate this, stated up front rather than discovered later:**

1. **The n=5000 evidence is gaussian_anchor.** Ayumi's model's family, trait count T, and
   q are not in my brief. If it is `nbinom2` — the only family that spends Gauss-Hermite
   nodes — or has T ≫ 8, or q = 3 (which the q-sweep shows costs ~5× at fixed N), every
   number above shifts and must be re-measured on the actual model. **Get the actual
   (family, T, q, N) before quoting any of this to anyone.**
2. **R2's fragility (§4.2) is unresolved**, and it appeared precisely in the large-N
   regime that matters here.
3. **Every timing in this campaign was taken on a contended machine** (the gllvm lens
   documents load averages of 28–36 on 20 cores; the-wall and Noether logs do not
   document their machine load at all). Ratios are protected by interleaving; **absolutes
   are not**. R8 exists for this reason: re-run on Totoro before anything leaves `dev/`.

---

## 6. What this does NOT address

1. **Whether the VA answer is statistically right.** Nothing in this arc touches the bias,
   variance, or interval coverage of VA estimates. A fast VA that is biased is worse than
   a slow one, because it will get used.
2. **Standard errors.** `profile=` changes `sdreport()` semantics for the profiled block.
   The VA SE path is untouched by the §4 protocol and needs its own slice. This is the
   largest named gap in R3.
3. **The trait axis (T / p).** Every one of our measurements is at T=8. gllvm's advantage
   was measured at p up to 120, and the loading block scales as T·q. The T axis is
   **completely unmeasured on our side** and it is the axis a real multivariate dataset
   grows along.
4. **`nbinom2` and the quadrature families.** All the-wall measurements are
   gaussian_anchor; all our-profile measurements are binomial-jj. The one family that
   actually spends Gauss-Hermite nodes has **never been timed** in this campaign.
5. **A head-to-head against gllvm at a matched (n, p, q, family) cell.** Both lenses
   measured *within-package* ratios only. **We still do not know the size of our own gap
   to gllvm.** The campaign's founding question is unanswered, and
   `dev/va-speed-gllvm-scaling.R` was written but never run.
6. **VA versus Laplace as the production engine.** Our Laplace scales n^0.98 and takes
   3.66 s at n=400, p=8. If R2/R3 land, the two become computationally comparable and the
   choice becomes a *statistical* one — accuracy, SEs, which regimes each is honest in.
   Nothing here decides it.
7. **Parallelism.** No part of this plan uses more than one core. The per-unit inner
   problems are embarrassingly parallel in principle; TMB's inner solve is single-threaded
   as configured. Totoro/DRAC help a *campaign* of fits, not a single fit — but a
   campaign is exactly what a coverage study is, and that is where they belong.
8. **The scientific question of whether the 4-start gate should exist.** R1 makes it
   optional and honestly priced. Whether a production fit should pay for it is Shinichi's
   call.
9. **The `failed_health_gate` status semantics under `n_starts = 1`.** The gate requires
   ≥3 healthy starts; at `n_starts = 1` the status must report something honest like
   `gate_not_run`, not `failed_health_gate`. Small, but it is a user-facing correctness
   detail and R1 must not ship without it.

---

## Appendix — source anchors read for this plan

`R/va-r3-proto.R`:
`:789-793` `MakeADFun(..., random = NULL)` ·
`:466-468` variational block starts at exactly zero ·
`:508-558` family evaluation registry (Poisson exact, binomial jj, only nbinom2 uses quadrature) ·
`:851` four starts built · `:871` start loop ·
`:890-902` up-to-two nlminb polish re-runs (`opt <- candidate` at `:900` is the counter bug) ·
`:905-928` conditional L-BFGS-B with `factr = 1e-12/.Machine$double.eps` and a correct
in-file comment about dense-vs-limited-memory that was never applied to the primary ·
`:934` health criterion (`max_abs_gradient < 1e-4`) ·
`:954,957-958` gate requires `length(healthy_id) >= 3L` ·
`:1012` `optimizer = "nlminb"` reported.

`dev/`: `va-speed-the-wall.R` + `-run.log` + `-{memory,qsweep,primary}.csv` ·
`noether-verify-va-speed.{R,log}` · `va-speed-verify-our-profile.md` ·
`va-speed-verify-gllvm-prior-art.md` · `va-speed-multistart-cost-results.csv` ·
`va-speed-gllvm-prior-art-results.csv` · `va-speed-our-profile-run.log` (panel 3 needs
the R7 retraction line).

TMB: `?MakeADFun`, `profile` argument, verified verbatim on the installed TMB in this
environment.
