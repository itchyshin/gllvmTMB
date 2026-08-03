# Does VA get per-unit latent uncertainty "for free"? (and is the Laplace half of the premise right?)

Status: read-only synthesis of a same-day recon + measurement + adversarial-review cycle in
`/private/tmp/gllvmtmb-va-lane2` (branch `claude/va-lane2`). Nothing here is promoted:
`default_tier` stays `"gh"`, the integration fence stays shut, results stay LOCAL (D-50).

## 1. The answer

Yes, but only under the GH tier, and only as an uncalibrated, internal, unexported quantity —
under the AC tier the same per-unit-shaped output is a constant in disguise, carrying no
per-unit information at all. The Laplace half of the premise is wrong for this codebase:
`getLV(fit, se = TRUE)` already returns genuine, machine-verified, substantially varying
per-unit latent-score SEs from the shipped `gllvmTMB_multi` engine, computed by TMB's
`sdreport()` at effectively no extra cost — "hard to get from Laplace" does not describe what
gllvmTMB has actually built. So the maintainer's structural asymmetry (VA free, Laplace hard)
inverts on inspection: Laplace's per-unit SE is real, tested, and already shipped for one
random-effect block; VA's is real only under one of its two tiers, unshipped, and explicitly
flagged uncalibrated by the code that produces it.

## 2. The AC tier: the collapse and the "free uncertainty" are the same fact, seen from two sides

Under Albert-Chib, `.va_r3_latent_posterior()` still loops `i in 1:N` and reads a distinct
Cholesky factor `L_i` per unit — the code path that would, in principle, hand back per-unit
information is intact and unconditional. But the *values* landed in are the same number for
every unit, to floating-point precision:

- Committed evidence cited in the task (commit `07af7df3`): collapsing the N per-unit `A_i`
  blocks into a single shared parameter moves the objective by **6.9e-12 at N=100** and
  **5.9e-12 at N=1000** — three to four orders of magnitude inside the maintainer's own
  falsifier (`>1e-8 ⇒ wrong`). Per-unit `log_L_diag` values already agree to **1e-16** at the
  optimum, matching a derived closed form to **2.6e-14**.
- Reconfirmed in this arc's own binomial-probit measurement (`dev/va-speed/32-gh-vs-ac-per-unit-spread.R`,
  N=90, T=9, q=1, n_trials constant at 8): AC's per-unit SD has CV = **2.98e-17, 0, 5.63e-17**
  across three independent seeds (11, 23, 77) — machine zero every time.

These are not two separate facts that happen to agree. `.va_r3_collapse_gate()`'s own doc
comment (`R/va-r3-proto.R:1858-1886`) states the mechanism directly: the AC stationarity
condition `dE/dv = -n/2` makes the variational covariance data-independent, so every unit's
`A_i` is provably the same matrix. The speed win from collapsing N blocks into one *is* the
uncertainty result, read backwards: a quantity can only be safely deleted as redundant
parameterisation because it was never carrying unit-specific information in the first place.
Under AC, "VA gives you per-unit latent SEs for free" is true only in the sense that the array
has N rows — every row is the same free constant.

## 3. The GH tier: what the measurement showed

The collapse gate refuses under GH (`eval_method_code != 2L` is unconditionally rejected,
`R/va-r3-proto.R:1875`), and the gate's own comment frames this as a scope limitation of the
AC derivation, not a proof that GH varies. This arc tested it directly.

**Measurement** (`dev/va-speed/32-gh-vs-ac-per-unit-spread.R`, N=90 units, T=9 traits, q=1,
`binomial_probit`, `n_trials` held constant at 8 across all units so any spread found is driven
by realized `y`, not a shifting design quantity; H=15 GH nodes; 3 seeds 11/23/77):

| seed | AC CV | GH CV | GH cor(se, extreme-cell count) | GH cor(se, total count) |
|---|---|---|---|---|
| 11 | 2.98e-17 | 0.191 | 0.898 | 0.001 |
| 23 | 0 (exact) | 0.198 | 0.870 | −0.230 |
| 77 | 5.63e-17 | 0.224 | 0.931 | −0.086 |

GH's per-unit SD is not just non-constant — it correlates strongly and consistently with
`unit_extreme_cells` (rows where `y = 0` or `y = n_trials`, where the probit link is flattest
and least curved), exactly as probit-curvature theory predicts, and correlates weakly and
inconsistently in sign with a cruder "how much data" summary. That pattern (strong on the
curvature-relevant feature, weak/noisy on the naive one) is itself evidence against "this is
just noise that happens to move with N."

**Was it optimiser slop?** This is the correct question to ask before trusting the spread, and
the adversarial review caught a real gap: the measured fits were flagged `UNHEALTHY` by the
package's own gate (`status = "failed_health_gate"`, max-gradient 1.3–2.0e-4, above the
package's 1e-4 bar) and the original write-up did not disclose this. Independent re-verification
closed the gap: reoptimising to a gradient ~30× tighter than the package's own bar
(max|g| = 7.0e-6) reproduced CV = 0.191 and cor = 0.898 to 6 significant figures — unchanged.
A companion Poisson probe (measurement 2 below) independently confirmed real per-unit signal by
comparing across the fit's own 4 independent starts: per-unit SEs agreed to ~1e-6 against an
across-unit spread of 0.047 (4–5 orders of magnitude tighter), and correlated with an exact
external reference at 0.9998. **Verdict: the GH spread is real per-unit signal, not
convergence-tolerance noise** — but this was established by the adversarial-review process, not
by the original report's own stated checks, and any future GH measurement should report the
health gate and a multi-start agreement check as standard, not as an afterthought.

One caveat the arc could not close at this compute budget: this is Poisson/probit-binomial
evidence only, cold-start GH only (not the AC→GH warm route), one regime each. It is a clean
positive result at N≈30–90, not a general property of GH established across families or N.

## 4. Does VA understate the spread?

**Measurement** (`dev/va-speed/32-va-vs-quadrature-spread.R`, N=30, T=6, q=1, Poisson-log, GH
tier, θ fixed at the VA point estimate, exact 1-D numerical quadrature as the reference — no
Laplace, no MCMC, no variational assumption, grid-converged to 5 decimals at h ∈
{0.01, 0.002, 0.0005}): VA's SD is narrower than the exact conditional posterior SD for **30/30
units**. Ratio `va_se / quad_sd`: mean 0.9945, median 0.9941, range [0.9886, 0.9991]. A
one-sample t-test on log-ratio gives 95% CI [−0.0069, −0.0041], p = 9.4e-09 — the direction is
unambiguous, but the *size* is small: VA is roughly **0.1%–1.1% narrower than exact, never
more**, in this regime.

This is directionally consistent with the maintainer's cited (UNVERIFIED, quarantined) dr21
lead — VA under KL(q‖p) is mode-seeking and should understate spread — but it does **not**
support "severe" understatement at this regime. A plausible mechanism: with T=6 independent
Poisson traits pooling evidence about each `z_i`, the conditional posterior is close to Gaussian
by an approximate CLT effect, leaving the Gaussian variational family little room to be wrong
about shape.

**Regime, stated plainly, because it matters:** N=30, T=6, q=1, one seed, one Poisson-log DGP,
moderate counts (range 0–14, mean 1.68), θ held fixed (estimation error in the fixed parameters
is *excluded* — this measures only the q-approximation, not the total uncertainty a user would
actually want). EVA — which dr21 specifically flags as *more* severely biased than plain VA —
was not tested. AC was not re-measured here (already known constant/uninformative). No coverage
or calibration study was run; a 0.5–1% SD understatement in one small regime says nothing about
how much a resulting interval's coverage would be degraded, here or elsewhere.

## 5. Does gllvm share this property? (if so, it is not a differentiator)

It does, exactly and cleanly, at the AC-equivalent corner. A same-day probe of the installed
`gllvm` 2.0.13 package (three tiny local fits, N=25–30, p=6, num.lv=1) found:

- **Gaussian family / probit-equivalent likelihoods** (gllvm's default binary link is `probit`,
  i.e. architecturally AC-equivalent): the raw per-unit VA SD (`sqrt(fit$A[i,1,1])`) is
  **constant across units to 8.4e-17** — the identical degeneracy this arc proved for our own
  AC tier, inside someone else's independent implementation.
- **Poisson (non-conjugate) family**, same DGP structure: the raw per-unit SD **varies
  substantially** — range 0.03–0.48 across two seeds, and correlates at **r ≈ −0.70** with each
  unit's fitted abundance (genuinely data-dependent, not noise).

So: the "AC-tier constancy" finding is **not specific to gllvmTMB's implementation** — it is a
property of the AC/conjugate-likelihood corner of variational inference generally, and gllvm's
own code reproduces it exactly. Where it is *not* AC-equivalent (Poisson), gllvm's raw VA
quantity is genuinely per-unit informative, mirroring what this arc found for our own GH tier
on binomial-probit. This means: **the "free per-unit uncertainty" property, where it is real, is
not a gllvmTMB differentiator against gllvm** — both packages get it under non-conjugate
likelihoods, both lose it under conjugate ones. It is a property of variational inference as a
method, tracking likelihood curvature, not a competitive edge of this codebase.

One further wrinkle, relevant to "for free": gllvm's own default extractor,
`getPredictErr(fit)` (`CMSEP = TRUE` by default), does **not** hand back the raw, free `A_i`
quantity — it adds a delta-method sandwich correction (`CMSEPf()`) that propagates fixed-
parameter uncertainty into the latent SE, inflating the reported SE by **~49% on average** in
the probed regime. That correction is architecturally the same class of computation
(curvature block + Hessian-sandwich term) that gllvm's own Laplace route (`sdrandom()`) and
gllvmTMB's `sdreport()`-based `getLV(se=TRUE)` use. So even gllvm's own maintainers do not treat
the raw variational covariance as the thing to report to a user by default — "free" describes
an internal quantity most users of that package never actually see uncorrected.

## 6. The honest bottom line

"Free BLUP uncertainty" is a real property, but it is tier-dependent, likelihood-dependent, not
gllvmTMB-specific, uncalibrated, and currently unreachable through the public API. Point by
point:

- **Real, not a mirage** — under GH, on non-conjugate likelihoods (binomial-probit with
  extreme cells, Poisson), the per-unit variational SD genuinely varies and correlates with
  theoretically meaningful features of each unit's own data. This survived an adversarial
  health-gate check.
- **Tier-dependent, and this has a direct strategic consequence.** The property is proven
  *absent* under AC (machine-precision constant) and only measured *present* under GH. If
  "free per-unit latent uncertainty" is to become a claim, it can only be made about the
  **slower** tier. That directly raises the value of getting the AC→GH warm-start route (Design
  103/Design 108 lane; see `dev/va-speed/20-CLAIMS-LEDGER.md` items 22–28) working correctly —
  its payoff is no longer only wall-clock speed, it is *inheriting GH's informative
  uncertainty while paying less than GH's full cost*. Note the ledger's own claim 22/28 history:
  the warm route was shown to silently collapse a real ψ back toward the AC boundary unless the
  tier SDs are explicitly reset before stage 2 — the same failure mode (AC's degeneracy leaking
  into what looks like a GH result) that this arc's tier question is fundamentally about. Any
  future claim that "the warm route gives GH's per-unit uncertainty" needs the same collapse
  check applied to the variational covariance specifically, not just to ψ.
- **Not a gllvmTMB differentiator.** gllvm reproduces the identical AC-tier degeneracy and the
  identical Poisson-tier informativeness in its own, independent implementation. Any framing of
  this as "our advantage over gllvm" is unsupported — it is a property of variational inference,
  not of this codebase.
- **Uncalibrated even where informative.** The code's own `calibrated = FALSE` flag
  (`R/va-r3-proto.R:1451-1452`) and `uncertainty_basis = "variational posterior, conditional on
  point estimates of beta and theta_rr"` are load-bearing, not boilerplate. Measurement 2 found
  a small (0.1–1.1%) but statistically unambiguous understatement in one small regime, directionally
  consistent with the quarantined dr21 lead. This has not been tested at a scale, family, or
  EVA-tier that would let anyone say how large the effect gets elsewhere.
- **Currently unreachable through the public API.** `.va_r3_latent_posterior()`'s output sits
  three structure levels deep (`fit$engine_result$latent$se`), undocumented, and class
  `gllvmTMB_va` registers no `ranef`/`getLV`/`predict` method — `R/va-routing.R:413-416` states
  the field vocabulary is deliberately disjoint from the Laplace engine's. "For free as part of
  the fit" currently means "computed internally and discarded," not "available to a user."
- **The Laplace half of the premise is the weakest part of the maintainer's framing.**
  `getLV(fit, se = TRUE)` on the shipped `gllvmTMB_multi` engine already returns per-unit latent
  score SEs — verified against an independent joint-precision-inversion route to ~1e-15, guarded
  by a dedicated ordering test, and empirically confirmed in a tiny local fit (N=40 sites, T=4
  traits) to vary substantially across units (SE range 0.47–32.8, sd 9.1) — the structural
  opposite of the VA-AC constant result. This machinery is wrapped into a public accessor for
  only *one* random-effect family (ordinary `latent()` z_B/z_W scores); other blocks (phylo,
  spatial, random intercepts) have the identical `sdreport`-computed SEs sitting unexposed in
  `fit$sd_report` — a real but narrow build gap, not a structural Laplace limitation. If the
  maintainer's actual concern is *calibration/accuracy trade-off* rather than *availability*,
  that is a different, still-open question this recon does not settle.

**So: is it worth building a claim on?** Only a narrow, tier-scoped, regime-scoped one — "under
GH, on likelihoods with real curvature variation across units, VA's own posterior SD is
informative, though of unmeasured and possibly non-trivial understatement, and this property is
shared with at least one other VA implementation (gllvm)." Anything broader — "VA gives free
uncertainty Laplace can't," "this is our advantage," "the warm route inherits this for free" —
is not supported by what has been measured and should not be asserted.

## 7. What is still unmeasured, and what would settle it

All of the below are Totoro/DRAC-scale campaigns, not extensions of this local recon (hard
compute constraint honored throughout — every measurement here was N≤100, seconds per fit,
2–4 seeds).

1. **Does GH informativeness hold beyond binomial-probit/Poisson, and beyond N≈30–90?** A
   seeded sweep across N (100–1000), family (gaussian, binomial, poisson, ordinal), and link,
   measuring CV(se) and the extreme-cell/curvature correlation per cell. This is what would
   let "GH gives informative per-unit uncertainty" become a package-level claim rather than a
   two-regime finding.
2. **Does the warm-started GH route inherit cold-GH's informativeness, or does it inherit
   AC's degeneracy** the way it was shown to for ψ (ledger claim 22/28)? Needs the identical
   CV(se)/correlation measurement run on `.va_r3_fit_warm()` output at the same regimes as (1),
   both before and after the tier-SD reset fix.
3. **How large is the understatement, and does it grow?** A multi-seed (≥10), multi-N sweep of
   measurement 2's exact-quadrature comparison, extended to EVA (dr21's specifically-flagged
   worse case), sparser/smaller-count and larger-T regimes, and with θ estimation error
   propagated rather than held fixed — the current 0.1–1.1% figure excludes exactly the
   uncertainty component a real user's interval would need to include.
4. **Is GH's per-unit SE calibrated (coverage), not just informative?** A full ADEMP-style
   recovery/coverage study with known ground-truth latent variances — ties into the existing
   capstone coverage-repair arc referenced in the project's live phase snapshot, not a
   standalone task.
5. **Does gllvm's Poisson-tier informativeness (r≈−0.70 with abundance) hold up to the same
   health-gate/multi-start scrutiny this arc applied to our own GH result?** Not checked here;
   the gllvm probe was single/double-seed and did not re-verify against tightened optimizer
   tolerance the way our own GH claim was adversarially re-verified.

None of items 1–5 can be answered from a local desktop at load ~12 without turning this into
exactly the kind of multi-seed campaign the task instructions forbid. They are named, not run.
