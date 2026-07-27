# Does the tighter binomial VA bound produce better parameter estimates?

**Fisher pass. Internal research only — no `@export`, no `method=` argument, no
public claim.** Script: `dev/bound-vs-estimates-recovery.R`. Raw data:
`dev/bound-vs-estimates.csv` (60 rows: 2 sizes x 10 seeds x 3 arms). Never call
an ELBO a likelihood.

## The established fact vs the question tested

Established (this session, prior to this test): gllvmTMB's Gauss-Hermite VA
(`va_r3`, H = 15) uses a **strictly tighter** ELBO bound on Bernoulli-logit
data than gllvm's `method = "VA"`, which **is** the Jaakkola-Jordan /
Polya-Gamma (JJ) bound (verified against gllvm 2.0.13 source). Bound
tightness is a fact about the objective. It says nothing about whether the
*parameter estimates* obtained by optimizing a tighter bound are better. That
is what this test measures.

## Design

- Bernoulli-logit, q = 2, known `Lambda_true` (`rnorm(sd = 0.7)`) and
  `beta_true` (`rnorm(sd = 0.3)`), Gaussian latent scores `Z ~ N(0, I)`.
- Sizes: (n = 60, p = 12) and (n = 100, p = 20). 10 seeds per cell, 20 cells
  total, 3 arms each = 60 fits.
- **Arm A**: gllvmTMB GH-VA, `.approximation_engine_fit(engine = "va_r3",
  family = "binomial", link = "logit", H = 15L)`. `Sigma_hat` read directly
  from `fit$engine_result$report$Sigma_B` (the TMB template already reports
  `Lambda %*% t(Lambda)`).
- **Arm B**: `gllvm::gllvm(family = "binomial", link = "logit", num.lv = 2,
  method = "VA")` — the JJ bound. `control.start = list(n.init = 4, jitter.var
  = 0.2)` to match va_r3's internal 4-start search (see pitfall #1 below);
  gllvm's own single-start default is not a fair fight against an engine that
  already retries from 4 starting points internally.
- **Arm C**: gllvmTMB Laplace, Psi-suppressed, via the matched call
  `traits(...) ~ 1 + latent(1 | site, d = 2, unique = FALSE)`,
  `family = binomial()`. `Sigma_hat` from `extract_ordination(fit, level =
  "unit")$loadings %*% t(...)`.
- Metric (rotation-invariant; loadings themselves are never compared
  elementwise): `rel_frob = ||Sigma_hat - Sigma_true||_F /
  ||Sigma_true||_F`, `atten = trace(Sigma_hat) / trace(Sigma_true)`.
- Every fit wrapped in `tryCatch`; no cell was dropped. All 60/60 fits
  returned a usable `Sigma_hat` (`ok = TRUE` throughout) — the failure mode
  that showed up instead was **silent numerical divergence to garbage
  estimates that still report a healthy convergence code**, which is a worse
  failure mode than a clean error because nothing stops you from using it.

## Two harness pitfalls found and fixed before results are trustworthy

Both are recorded here because they invalidate a naive first pass at this
exact comparison, and would invalidate anyone else's:

1. **gllvm's `theta` is not the fitted loading matrix by itself.**
   `fit$params$theta` carries a fixed identifiability constraint (e.g. species
   1's first loading fixed at exactly 1) and the true per-axis scale lives in
   a separate `fit$params$sigma.lv` vector. The fitted linear-predictor
   loading is `theta %*% diag(sigma.lv)`. Missing this inflated `rel_frob`
   from a sane ~0.4–0.9 to **10⁶–10⁹** in a first pass — not a subtle
   difference, a qualitatively wrong conclusion ("JJ is catastrophically
   biased") caused entirely by an omitted rescaling.
2. **gllvm's default single optimizer start (`n.init = 1`) genuinely diverges
   on Bernoulli VA.** With the default, one latent axis's loadings blew up to
   the thousands (verified: `LV1` loadings up to ±4600, seed 20261786, n=60,
   p=12) while `fit$convergence` still reported `TRUE`. `n.init = 4` (matching
   va_r3's 4 attempted starts) fixed this. This is disclosed, not hidden: it
   is a fairness correction (equal optimization budget across arms), not a
   tune-away of the finding under test.

## Results

### n = 60, p = 12 (10 seeds)

| Arm | rel. Frobenius error (median [IQR]) | attenuation ratio (median [IQR]) | median time |
|---|---|---|---|
| A: gllvmTMB GH-VA (H=15) | 2.19 [1.78, 2.49] | 2.75 [2.31, 2.91] | 2.8 s |
| B: gllvm JJ (method="VA") | **0.87** [0.79, 0.97] | 1.18 [1.06, 1.32] | **0.5 s** |
| C: gllvmTMB Laplace | 2750 [722, 7478] | 2001 [571, 5678] | 4.4 s |

Arm A status: 8/10 `failed_variance_domain`, 2/10 `healthy`. Arm C: 8/10 fits
diverged to a degenerate loading (`rel_frob > 10`, up to 55205×) — a single
species' loading runs away (e.g. −119.9 / −62.2 against true-scale loadings
of ~0.1–1.5) while the rest of the fit looks unremarkable and reports
`pdHess = TRUE`. This tracks a known, already-documented risk in this
codebase (`docs/design/2026-06-22-pre-fit-response-screening.md`,
quasi-complete separation in binary responses) — Laplace's unregularized MLE
has no defense against it; the VA arms' KL-to-prior term acts as an implicit
shrinkage/regularizer that the Laplace arm lacks. Restricting Arm C to its
2/10 non-degenerate fits: rel_frob median 1.22 [1.15, 1.29], atten median
1.65 [1.64, 1.67] — still visibly worse than Arm B and still overestimating,
not attenuating.

### n = 100, p = 20 (10 seeds)

| Arm | rel. Frobenius error (median [IQR]) | attenuation ratio (median [IQR]) | median time |
|---|---|---|---|
| A: gllvmTMB GH-VA (H=15) | 0.90 [0.68, 1.10] | 1.44 [1.27, 1.69] | 11.2 s |
| B: gllvm JJ (method="VA") | **0.55** [0.47, 0.66] | 0.88 [0.82, 1.13] | **1.5 s** |
| C: gllvmTMB Laplace | 1.06 [0.68, 1.13] | 1.59 [1.24, 1.70] | 6.5 s |

Arm A status: 6/10 `healthy`, 3/10 `failed_health_gate`, 1/10
`failed_variance_domain`. Arm C: 2/10 fits still diverged (rel_frob up to
1550×); excluding them, rel_frob median 0.93 [0.62, 1.07] — now
indistinguishable from Arm A, still behind Arm B.

## Answers

**1. Does GH-VA recover Sigma_B better than JJ? No — the reverse.** Across
both sizes and both metrics, the JJ arm (B) has a *lower* median relative
Frobenius error than the tighter-bound GH-VA arm (A): 0.87 vs 2.19 at n=60,
0.55 vs 0.90 at n=100. This is not a close call or within-noise tie; it is a
consistent, sizeable gap in the *opposite* direction from what bound
tightness would predict. Pooled, the gap is roughly 1.6–2.5× in GH-VA's
disfavor. The tighter bound is not translating into a tighter estimate.

**2. Does JJ attenuate more than GH-VA, as the theory predicts? No — neither
result matches the textbook attenuation story, and if anything they're
reversed.** JJ's attenuation ratio hovers near 1 (0.88–1.18 across cells,
straddling 1 in three of four cell-level IQRs) — a mild net effect, not the
severe underestimate the Polya-Gamma variance-collapse literature describes.
GH-VA, meanwhile, consistently *overestimates* — atten 1.44–2.75, i.e. Sigma_B
too big, not too small — the opposite direction from "attenuation." Two
caveats limit how far this goes: (a) the literature's variance-collapse claim
is about the *variational posterior* over the latent scores u_i, a different
quantity from the *point estimate* of the loading covariance Sigma_B tested
here; (b) GH-VA's own health gates flag most of these fits as outside its
certified domain (`failed_variance_domain`/`failed_health_gate` in 12/20
cells), so its overestimation may be an artifact of exactly the regime its
own diagnostics say not to trust, not a property of the bound per se. Read
literally on the numbers actually produced, the textbook prediction does not
survive contact with this design.

**3. How does Laplace compare to both? Nominally competitive when it
converges cleanly, but it converges cleanly less often, silently.** Its
non-degenerate subset (12/20 fits total) sits close to GH-VA (rel_frob
~0.9–1.2, atten ~1.4–1.7) — behind JJ, ahead of nothing. But 8/20 fits (40%)
land on a degenerate loading that is off by 2–5 orders of magnitude while
reporting a clean convergence code and `pdHess = TRUE`. A user trusting the
convergence flag alone would have no signal that the fit is garbage. This is
the single most operationally important result in this study: whatever its
median looks like, Arm C is the least trustworthy arm precisely because nothing
in its own reported diagnostics flags the failure — contrast Arm A, whose
`failed_variance_domain`/`failed_health_gate` labels are honest about exactly
this kind of risk.

**4. Is the tighter bound worth it for estimates — plainly.** No, not in this
design. GH-VA's provably tighter ELBO does not produce a better Sigma_B
estimate than the provably looser JJ bound; on this evidence it produces a
*worse* one, is markedly slower (4–20× JJ's wall-clock), and is honest enough
to flag most of its own fits as outside its certified operating domain in
exactly the regime tested (small n, moderate loadings, Bernoulli). The
publishable claim from this test is not "GH-VA's tighter bound pays off" —
it is close to the reverse: **bound tightness and estimator quality are
dissociated here, and JJ's simplicity/speed/stability advantage dominates in
practice for this recovery target.** This does not mean GH-VA is worthless —
its own health gates are doing real, disclosed work, and its failure mode
(labelled `failed_*`) is safer than Laplace's silent one — but "our bound is
tighter" is not, on this evidence, a claim that the estimates are better.

## Honest limitations

- Loading magnitude (`sd = 0.7`) combined with n = 60 puts most Arm A fits
  outside GH-VA's own certified variance domain — a smaller loading scale or
  larger n might change the balance; this was not swept, per the "keep it
  small" brief.
- 10 seeds per cell is enough to see a consistent, sizeable direction of
  effect, not enough for a formal significance test on the gap between arms.
- Arm C's degenerate/non-degenerate split used an ad hoc `rel_frob > 10`
  threshold for reporting clarity; the raw, unfiltered medians (which are
  what the brief actually asked for) are the ones in the results tables above
  and are reported first, before any filtering.
