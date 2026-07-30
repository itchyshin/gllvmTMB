# The gaussian arm of Slice 1, re-scoped — gaussian is not an estimator comparison

Date: 2026-07-30. Author: Claude. Lane: `claude/vgh-pluralism-20260730`.
Supersedes the gaussian half of `docs/dev-log/2026-07-30-vgh-pluralism-lane-brief.md`
§"The one thing blocking a claim".

## The finding

**On gaussian, the Laplace engine and VGH optimise the same objective.** This is not an
inference — it is stated in the benchmark script that produced the numbers under dispute,
`dev/vgh/vgh-bench.R:2-3`:

> *"For a gaussian-identity GLLVM Laplace is EXACT and the VGH ELBO is exact (validate.R check
> C-exact, 1.3e-12), so both optimise the SAME objective."*

**The quoted figure has since been corrected to 3.76e-13, and it does not matter here.** That
`1.3e-12` was measured while `vgh_fit()` returned a `$elbo` stale by one sweep; 70% of it was
the staleness, and the fixed engine reads **3.76e-13** at `tol = 1e-12`, falling to 1.26e-15
(~5 ulp) run to convergence. So the figure moved *favourably* — see
`2026-07-29-vgh-variational-speed-probe.md`'s addendum.

It does not matter here for two reasons worth stating, because "the number I cited was wrong"
would otherwise look like it threatens the argument. **First, the claim rests on a theorem, not
on the number** — the gaussian posterior of `u_i` is Gaussian, so the variational family
contains it and the bound is tight at the optimum; the figure was numerical corroboration of a
proved identity, and it now corroborates it 3.35× more sharply. **Second, nothing downstream in
this arc read the stale value at all**: `dev/vgh/gaussian-collapse.R` contains the string
`elbo` zero times, and `vgh-bench.R` itself recomputes `exact_ll()` from the returned
parameters at `:53` — so every number in `vgh-bench-gaussian.csv`, *including the `d_ll` column
that is the actual same-objective evidence*, is unaffected. The exposure was confined to the
citation in that header comment.

and corroborated by the package's own strongest oracle,
`tests/testthat/test-vgh-oracle.R:54-60`:

> *"For a gaussian-identity GLLVM the true posterior of u_i IS Gaussian, so the variational
> family CONTAINS it, the bound is tight, and at the optimum the ELBO must EQUAL the exact
> marginal log-likelihood."*

Two consequences follow, and together they re-scope the whole arm.

### 1. "Which estimator is more accurate" is not well-posed on gaussian

Same objective ⇒ same maximiser. Both engines target the identical marginal likelihood
`N(Xβ, ΛΛ' + diag(φ))`. If both reach their optimum they must return the same estimates, so
there is no accuracy difference to measure. What remains is a question about **optimisers**
(does each actually reach it?), not about estimators.

This means the task as originally briefed — *"score recovery against known truth"* to settle
which engine is more accurate on gaussian — was asking for something that cannot exist. The
finding is not that the answer is unknown; it is that the question dissolves.

### 2. VGH's anti-degeneracy mechanism is switched OFF on gaussian

This is the more consequential half. The brain note *"VGH in gllvmTMB — the settled
position"* credits VA's zero-degeneracy record to the variational objective's regulariser:

> *"A VA objective carries a KL-to-prior term — an implicit regulariser. Laplace has none. …
> The KL-to-prior term regularises the boundary away, exactly as theory predicts."*

But the ELBO equals `logLik − KL(q ‖ p(u|y))`. When the variational family **contains** the
true posterior — which on gaussian it does — the KL term goes to **zero at the optimum**. The
bound is tight, there is no slack, and therefore **no implicit regularisation**.

So the mechanism that makes VA immune to the loading runaway on Bernoulli cannot operate on
gaussian. **Prediction: gaussian VGH should show the loading runaway at approximately
Laplace's rate**, against binomial's measured 0/148 versus 50/148. This is falsifiable and
cheap, and it tests the premise the entire pluralist route rests on.

If the prediction holds, the pluralist "both engines plus an honest gate" design is
established as a **non-gaussian** proposition, and gaussian VGH buys speed only.

## The log-likelihood confound, quantified

The 60-vs-79 parameter confound was correctly identified on 2026-07-29 and correctly called
*"roughly what the extra parameters buy"*. It is now measured rather than judged.

The two models are strictly **nested** — Laplace is VGH under `φ_1 = … = φ_m` — the bench DGP
is **homoscedastic** by construction (`dev/vgh/vgh-bench.R:13`, commented *"homoscedastic:
both models can fit it"*), and both log-likelihoods are **exact**. So `2·d_ll` is a
likelihood-ratio statistic against a *true* null, on 19 df:

| n | d_ll | 2·d_ll | p (χ²₁₉) | percentile of null |
|---|---|---|---|---|
| 200 | 6.23 | 12.47 | 0.865 | 13.5% |
| 500 | 6.67 | 13.33 | 0.821 | 17.9% |
| 1000 | 9.99 | 19.98 | 0.396 | 60.4% |
| 2000 | 11.96 | 23.92 | 0.199 | 80.1% |
| 4000 | 12.31 | 24.61 | 0.174 | 82.6% |

The null **expects** `d_ll = 9.5 ± 3.08`. **0 of 5 cells reach p < 0.05**, and two fall
*below* the null expectation — VGH gained *less* than 19 free parameters typically buy.

**The df count, since it is the crux.** Effective loading dof is 39 on both sides. Laplace
constrains the strict upper triangle of `Lambda_B` to zero (`src/gllvmTMB.cpp:875-899`),
giving `T·d − d(d−1)/2 = 39` free entries, the count the template asserts at `:885`. VGH
leaves Λ unconstrained (`dev/vgh/vgh-engine.R:358-360`, `:321-322`) at 40 raw entries, but
only 39 are identified — the extra one is a rotational gauge direction in which the likelihood
is exactly flat, confirmed numerically (rotating an unconstrained 20×2 into lower-triangular
form leaves `ΛΛ'` unchanged to 2.2e-15) and documented at `R/vgh-verify.R:9-11`. So the gap is
exactly the 19 dispersions. At a naive df = 20 the p-values are 0.854…0.187 — the same
conclusion.

### What this does NOT establish

An adversarial review returned **WOUNDED, not refuted**, and the wound is worth keeping:

- **Five cells, one seed, single-start, no convergence verification.** `sim()` redraws `Lam`
  and `b0` at *every* n, so these are five draws from five **different truths**, not
  replicates at growing n — the apparent rise of `d_ll` with n is therefore uninterpretable.
- **A VGH fit stuck on a worse local optimum would deflate `d_ll` and manufacture a false
  null.** `R/gllvmTMB.R:1213-1216` documents exactly this failure mode for reduced-rank
  GLLVMs: *"Every failure reported `convergence == 0` and a positive-definite Hessian on both
  sides, so the worse fit was silent, and restarts did not detect it."* The bench's `sweeps`
  column (59, 59, 53, 78, 81 against `maxit = 1000, tol = 1e-11`) shows VGH stopped on
  tolerance rather than the cap, which is reassuring but is not a multi-start check.
- **Direction of bias:** a Laplace shortfall *inflates* `d_ll` (conservative here); a VGH
  shortfall *deflates* it (anti-conservative). Only the second would matter, and it is the
  reason every slice below uses multi-start.
- **Not a boundary problem.** The null is equality among 20 *interior* positive variances, not
  a variance at zero, so ordinary χ² applies rather than a chi-bar-square mixture.

**Honest statement:** *the observed advantage is fully consistent with 19 degrees of freedom,
on five unreplicated draws with unverified optima.* That refutes "the advantage is real"; it
does not establish "the advantage is exactly 19 dof".

## Corrections made, and what did NOT need correcting

**The one real error.** The lane brief said *"VGH's gaussian route FIXES the residual
dispersion rather than estimating it (`gaussian_sd`)"*. That inverts the fact for the engine
this arm uses:

| engine | family | dispersion |
|---|---|---|
| `R/va-vgh.R::.vgh_fit()` | `"gaussian_anchor"` | **FIXED** at `gaussian_sd^2` (`:575-576`) |
| `dev/vgh/vgh-engine.R::vgh_fit()` | `"gaussian"` | **ESTIMATES per-trait φ_j** (`:67`, `:341`, `:402`) |

Verified by running it: on heteroscedastic truth φ moves off its initialisation and spreads
across traits (range 1.737). The 79-parameter count is itself the proof — fixed dispersions
would not be parameters.

**Provenance, because it is the transferable lesson.** The predecessor handover was
**correct** — `handover/2026-07-29-claude-handover-vgh-heywood-gate.md:110` writes
*"`gaussian_anchor` FIXES the residual dispersion"*, as does
`2026-07-29-vgh-vs-gllvm-headtohead.md:83`. Compressing `gaussian_anchor` to "VGH's gaussian
route" dropped the only word carrying the distinction. The inverted version then propagated
into the lane brief **and into the resume command** at
`handover/2026-07-30-claude-handover.md:126`, which is how it reached the next session as an
executable instruction and was acted on before being caught.

> **A resume command is executable instruction, not prose. A one-word compression in one is a
> defect the next session acts on before it reads the evidence.** Keep engine names exact
> there, even at the cost of brevity.

**What did NOT need correcting — recorded because the initial diagnosis overcharged.** Both
2026-07-29 documents got the substance right on every point: *"That is not evidence of a
better optimum"*, the 60-vs-79 count, *"roughly what the extra parameters buy"*, *"No
equal-accuracy claim is established"*, *"not explained by VGH stopping early"*, and — exactly
naming this slice — *"a clean equal-accuracy statement needs a matched dispersion
parameterisation, which has not been run"*
(`2026-07-29-vgh-variational-speed-probe.md:131-133`).

An initial reading of this arc charged those documents with a *category error* — treating a
convergence diagnostic as an accuracy claim — and with *silently dropping* the two largest-n
rows from the quoted range. **Both charges were wrong.** The documents drew the correct
conclusion, and the range "+6.2 to +10.0" was accurate when written: the same file records at
`:133-134` that *"n=2000 and n=4000 did not complete in this session."* Those cells landed
later, so the quoted range is **stale, not wrong**. The stronger accuracy reading appears only
in downstream compression, not in the source documents.

Corrected/annotated: `2026-07-30-vgh-pluralism-lane-brief.md` (engine attribution, range,
quantification) · `2026-07-29-vgh-report.md` (addendum) ·
`2026-07-29-vgh-variational-speed-probe.md` (addendum) ·
`handover/2026-07-30-claude-handover.md` (resume command marked superseded).

## The re-scoped deliverables

The broad 3×3 accuracy grid is **cut as vacuous**. What replaces it is cheaper and answers
questions that are not dissolved:

**A. Collapse test, doubling as a TMB template cross-check.** Pool `vgh_fit()`'s dispersion to
a single shared estimated value, matching Laplace at 60 parameters, multi-start both arms.
Same objective ⇒ `d_ll` must fall to ≈ 0 from 6.23–12.31, and `Σ̂` must agree. A persistent gap
is either an optimiser difference or a **template bug** — and this is the one unexploited use
the brain note grants VGH: *"a genuinely independent implementation of the same likelihood …
could cross-check the TMB template for implementation errors — a software test, not a
statistical instrument."*

**B. Degeneracy falsification.** Does gaussian VGH show the loading runaway at Laplace's rate?
Prediction: yes, because KL = 0 removes the protection. Both degeneracy definitions in
circulation get reported — `rel_frob > 10` (Totoro grid, brain note, the binomial half) and
`atten_F` outside [0.2, 2] (`dev/vgh/phase0-matched-recovery.R:88-100`) — rather than silently
picking one.

## Recommended ordering for the lane

1. **Close gaussian out with A and B** (hours). Either the theory holds and the pluralist route
   is scoped to non-gaussian families, or it does not, which is a surprise worth having before
   anyone invests.
2. **Then the real fork.** There is currently **no single thing called VGH** — two
   half-implementations with disjoint capabilities:

   | | in the package? | gaussian dispersion | validation | convergence flag |
   |---|---|---|---|---|
   | `R/va-vgh.R::.vgh_fit()` | yes (internal) | **cannot estimate it** | full | `$converged` |
   | `dev/vgh/vgh-engine.R::vgh_fit()` | **no** (dev prototype) | estimates per-trait φ | **none** | **none** |

   "Implement VGH properly" therefore means unifying these and filling the gaps — already
   scoped as unbuilt work at `docs/design/108-va-parity-programme.md:194` (2–3 days). Do that
   for **binomial/Poisson**, where the advantage is measured and real, or first measure that
   advantage at scale on the Totoro-grid design (lane brief slice 2). The scale measurement is
   days cheaper and tells you how much engine to build.
3. **The mixed route last**, once there is an engine to mix.

**What not to do:** build VGH properly *for gaussian*. On the evidence above, that work has no
target — same objective, no protective mechanism, speed only.

## Standing constraints honoured

Healthy is defined by recovery against known truth, never convergence — and `vgh_fit()` has no
`$converged` field and no input validation at all, so convergence is derived and inputs are
guarded explicitly. Every threshold ships with its definition named. Compute is local; results
stay local (D-50). This slice answers **Q4** of the brain note's taxonomy (VA as an
*estimator*), not **Q3** (VGH as a public *screening* surface), whose standing decision — keep
VGH internal, unexported, opt-in, no public surface — is untouched.
