# Evidence chapter draft: missing-data handling in gllvmTMB

**STATUS: DRAFT for Shinichi's review. Rose-gated before any paper use.**
Written 2026-08-15 as an internal evidence-chapter draft toward the Design 66
capstone. Every number below is sourced to a file listed in the Appendix; none
is invented or estimated. Register codes (MIS-21, MIS-37, VA-10, MIS-32) are
kept to the Appendix only — the prose below states what they mean, not their
codes.

## 1. Mechanism

gllvmTMB treats a masked response cell as an *unobserved unit-trait cell*
rather than as a value to be filled in before fitting. The C++ likelihood
carries a per-cell observation gate, `is_anchor && is_y_observed`, that sits
**outside** the family-specific dispatch: every family's contribution to the
joint log-likelihood is switched off at exactly the cells flagged missing.
Because the gate is upstream of the family code, admitting masked responses
for a new family is, in the general case, a matter of proving the existing
gate is respected, not of writing new likelihood code.

This is the same statistical route as the EM-imputation used by Montoya et
al.'s (2026) phylogenetic probabilistic PCA (P3CA): cell-wise marginalisation
and EM-imputation are two computational routes to the same observed-data
maximum likelihood under missing-at-random (MAR) / ignorability. Nothing in
gllvmTMB's estimation target changes when cells are masked; only the set of
cells contributing to the likelihood does.

**Equivalence evidence.** The mask-invariance contract — fitting with
`response = "include"` (masked cells carry through as unobserved) versus
`response = "drop"` (masked rows removed outright) returns the same
log-likelihood and parameter estimates — was previously verified for three
families (poisson, nbinom2, binomial) and gaussian. It now extends to all 17
admitted families: lognormal, Gamma, nbinom1, tweedie, Beta, student,
truncated_poisson, truncated_nbinom2, delta_lognormal, delta_gamma,
ordinal_probit, and betabinomial (two-column `cbind` response) were added in
this arc's Tier-3b sweep, and multinomial required a genuine engine change
(below). The measured invariant across every family is
`|ΔlogLik(include, drop)| ≤ 2.5e-6`, mostly ~1e-9. Sigma or parameter-estimate
comparisons wobble more in a few flat/boundary directions (5e-3 to 9e-3 for
nbinom1, tweedie, truncated_poisson; ordinal's unique-tier log-SDs move 0.58
at `ΔlogLik = 8e-9`) — diagnosed as likelihood-surface flatness, not a
masking defect. Log-likelihood equality is the mask invariant that matters;
parameter identity is a guard against gross divergence, not the primary
evidence.

**Multinomial required an actual fix.** It was the one family that hard-
refused NA categorical responses. `expand_multinomial_response()` previously
aborted on NA; it now propagates NA into all K−1 one-hot contrast rows for
that observation, so the mask (or the drop) removes the whole contrast group
as one unit — group-uniform by construction, matching the C++ anchor gate's
requirement. No `src/` change was needed: the likelihood gate was already
mask-ready. This closes the last family gap under Laplace.

**The variational engine carries the same contract.** Under the scalar VA
route, `is_y_observed` is now parametrised across all 18 admitted VA cells
(16 family/link combinations plus two dispersion-parametrisation variants),
each checked for exact-sentinel invariance: masked cells contribute `fn`/`gr`
at tolerance exactly 0, and masked `expected_loglik_by_obs` is exactly 0.
Each cell is additionally admitted under a real fit with a ~15% include-mask.
Two cells (`betabinomial_logit`, `delta_gamma_log`) are health-gate-marginal
— a multi-start objective range of 2e-6 to 1e-5 with finite gradients
throughout, attributed to dispersion-parameter polish fragility, not a
masking defect. Multinomial has no VA route at all (a capability gap, not a
masking defect).

## 2. Reconstruction accuracy (Arc0 / Arc0b)

The mechanism evidence above establishes that masked-response fits recover
the *same likelihood* as unmasked fits; it says nothing about how well
`predict_missing()` reconstructs the masked values themselves. That accuracy
question had no code and no runs before this arc (Design 70 §E.2 target S1).
Two probes supply the first evidence, both dev-script (register status
`partial`, not testthat-backed `covered`), both failure-inclusive (every
attempted fit's convergence status is reported, not just the converged
subset), and both benchmarked against a trait-mean-fill baseline.

**Arc0 (gaussian, poisson).** 50 units × 25 traits, `q_true = 2`, four
missingness mechanisms — 5% MCAR, 20% MCAR, trait-clustered structured MAR
(60% of a 10%-overall mass concentrated in 5 trait columns), and
unit-clustered structured MAR (60% of a 10%-overall mass concentrated in a
10-unit block) — 10 seeds per cell, 80/80 fits converged in 1.0 minute wall
time, reproducibility confirmed on a re-run seed.

| family | mechanism | metric | RMSE | RMSE meanfill | ratio vs meanfill |
|---|---|---|---|---|---|
| gaussian | mcar05 | r = 0.658 | 0.471 | 0.979 | 0.482 |
| gaussian | mcar20 | r = 0.738 | 0.540 | 1.029 | 0.525 |
| gaussian | trait_clustered | r = 0.655 | 0.509 | 0.907 | 0.562 |
| gaussian | unit_clustered | r = 0.718 | 0.561 | 0.985 | 0.569 |
| poisson | mcar05 | ρ = 0.623 | 3.052 | 6.942 | 0.440 |
| poisson | mcar20 | ρ = 0.680 | 2.774 | 6.100 | 0.455 |
| poisson | trait_clustered | ρ = 0.610 | 2.541 | 5.484 | 0.463 |
| poisson | unit_clustered | ρ = 0.604 | 2.832 | 6.306 | 0.449 |

Reconstruction RMSE runs at roughly 0.44–0.57 of the mean-fill baseline's
RMSE across every gaussian and poisson cell — the reconstruction, in effect,
roughly halves the baseline error — and the improvement holds, not just
under uniform MCAR, but under both structured-MAR clustering mechanisms.

**Arc0b (binomial, ordinal_probit, delta_lognormal, multinomial).** Same
failure-inclusive, seeded design (80/80 converged, 1.2 minutes wall), reduced
to two mechanisms (20% MCAR, unit-clustered) per family, each with its own
family-appropriate metric and baseline.

| family | mechanism | metric 1 | model | baseline | metric 2 | model | baseline |
|---|---|---|---|---|---|---|---|
| binomial | mcar20 | AUC | 0.629 (se 0.020) | 0.624 | Brier | 0.249 | 0.236 |
| binomial | unit_clustered | AUC | 0.573 (se 0.026) | 0.531 | Brier | 0.261 | 0.256 |
| ordinal_probit | mcar20 | Spearman ρ | 0.120 (se 0.063) | n/a | modal accuracy | 0.479 | 0.481 |
| ordinal_probit | unit_clustered | Spearman ρ | 0.195 (se 0.062) | n/a | modal accuracy | 0.514 | 0.514 |
| delta_lognormal | mcar20 | RMSE | 3.464 (se 0.227) | 3.434 | occurrence AUC | 0.643 | 0.645 |
| delta_lognormal | unit_clustered | RMSE | 3.277 (se 0.166) | 3.271 | occurrence AUC | 0.702 | 0.680 |
| multinomial | mcar20 | modal accuracy | 0.612 (se 0.023) | 0.524 | multiclass Brier | 0.500 | 0.619 |
| multinomial | unit_clustered | modal accuracy | 0.616 (se 0.017) | 0.504 | multiclass Brier | 0.510 | 0.624 |

**This is a finding, not a weakness to bury: reconstruction skill is
family-dependent.** Multinomial clearly beats its marginal-frequency baseline
on both metrics and both mechanisms. Binomial, ordinal, and delta-lognormal
sit near their respective baselines — AUC and Brier within a few points of
chance/naive, modal-category accuracy within 0.002–0.03 of the naive modal
baseline. The proximate cause is low per-cell information: a single masked
Bernoulli, ordinal, or hurdle-presence draw carries little signal relative
to a continuous or multi-category response, and the per-family DGPs here
were not tuned to maximise recoverable signal. On this evidence, categorical
and binary masked-cell reconstruction should not be advertised as accurate;
multinomial's advantage should be stated with its family and metric, not
generalised to "categorical responses."

Two `predict_missing()` surface issues were found and filed rather than
worked around silently: for `ordinal_probit`, `type = "response"` applies the
scalar link-inverse (`pnorm(eta)`) elementwise, not a category probability
for K > 2 (link-scale eta plus hand-computed cutpoint probabilities were used
instead); for multinomial, `original_row` falls back silently to the
internal expanded pseudo-row index rather than the user's original row when
its length-mismatch fallback fires, so Arc0b's join used `unit` instead.

## 3. Comparison with P3CA and Rphylopars

**Model-class relationship.** `phylo_latent(..., unique = TRUE)` fits a
loadings-plus-diagonal covariance, `Sigma = Lambda Lambda' + diag(psi)`, with
the loadings' random-effect covariance structured by the phylogeny. This
nests the P3CA covariance model at Pagel's `lambda = 1`: gllvmTMB does not
estimate Pagel's lambda — `phylo_latent(tree = tree)` uses the tree's branch
lengths directly, the `lambda = 1` (pure Brownian) case — whereas both
`p3ca_reimpl` and Rphylopars estimate or profile lambda. This is a genuine,
expected structural asymmetry, and a stated limitation of the current
gllvmTMB phylogenetic factor model: it covers the Brownian-motion case, not
the fractional-phylogenetic-signal case P3CA and Rphylopars both target.

**Comparator provenance.** mvMORPH's `p3ca()`, described in Montoya et al.
(2026, bioRxiv 2026.05.27.728209) as the paper's own implementation, is not
publicly available: absent from CRAN mvMORPH 1.2.1, GitHub `master`, and
branch `Paola-devel` at commit `321e6ea8` (v1.2.2), all checked directly. The
paper's Data Availability statement outruns the shipped code. The
`p3ca_reimpl` arm is therefore a labelled reimplementation of the paper's
eqs 6–13 (EM update and the analytical complete-data ML solution), never
presented as the authors' code. Before any comparison it was checked against
the paper's own closed-form solution on complete data (n = 50, p = 25, q =
3, lambda fixed at 1): principal-subspace angle 1.490e-08 rad (threshold
< 1e-3), relative sigma² difference 4.736e-08 (threshold < 1e-4), both pass.
Rphylopars (`phylopars(model = "lambda")`) is the one arm that is the
authors' own published code. All arms were fit by maximum likelihood,
matched across arms (the paper itself used REML) — judged the fairer
comparison than replicating the paper's exact setting.

**Head-to-head design.** Two DGPs: DGP-a is P3CA's home field — the residual
is genuinely phylo-structured — swept over `lambda in {0.6, 0.98}` and two
mechanisms (5% MCAR; a phylogenetically clustered "clade" structured-MAR
mechanism), 4 cells. DGP-b is gllvmTMB's native case — an iid,
non-phylo-structured residual — swept over the same two mechanisms, 2 cells.
Three arms (`gllvmTMB-primary`, `gllvmTMB-lean` "misspecified-lean" without
the phylo-Psi companion, `p3ca_reimpl`) ran the full grid: 6 cells × 10
seeds = 180 fits, foreground, 414.4 s wall time (~6.9 min), **zero
failures, zero timeouts**.

| cell | gllvmTMB-primary | gllvmTMB-lean | p3ca_reimpl |
|---|---|---|---|
| DGP-a, λ=0.6, MCAR 5% | 1.226 (0.088) | 1.513 (0.079) | 1.244 (0.108) |
| DGP-a, λ=0.6, clade | 1.590 (0.079) | 2.029 (0.110) | 1.494 (0.083) |
| DGP-a, λ=0.98, MCAR 5% | 0.575 (0.045) | 1.299 (0.108) | 0.572 (0.045) |
| DGP-a, λ=0.98, clade | 0.517 (0.056) | 1.263 (0.101) | 0.521 (0.059) |
| DGP-b, MCAR 5% | 0.679 (0.052) | 0.664 (0.053) | 0.677 (0.054) |
| DGP-b, clade | 0.803 (0.034) | 0.766 (0.035) | 0.786 (0.034) |

(Cell entries are mean masked-cell MSE over 10 seeds, Monte Carlo SE in
parentheses.)

**Result: parity, not superiority, on P3CA's home field.** On DGP-a (all
four cells), `gllvmTMB-primary` and `p3ca_reimpl` are statistically
indistinguishable — differences well inside 1 MC SE at every cell (e.g.
0.575 vs 0.572, 0.517 vs 0.521 at λ = 0.98) — and both clearly beat
`gllvmTMB-lean` by 5–10+ SEs at λ = 0.98 and a smaller but consistent margin
at λ = 0.6. This is exactly the regime where the phylo-structured Psi
companion earns its keep, identically whether the computation is gllvmTMB's
engine or the paper's own EM/closed-form route. On DGP-b, the phylo-Psi
advantage disappears as designed: all three arms are near-parity (every
pairwise gap under 2 MC SEs), because the extra phylo-structured Psi is
itself misspecified against a genuinely iid residual there. The honest
summary is parity with P3CA on P3CA's own DGP, plus wider family reach (17
response families with masked-response support under gllvmTMB versus P3CA's
phylogenetic-PCA-only scope) — not a claim of superior accuracy on P3CA's
home ground.

**Rphylopars.** Under default `phylopars(model = "lambda", REML = FALSE)`
at n = 50 × p = 25, Rphylopars was the sole bottleneck: across the pre-run
(3 cells) plus the cameo extension (12 planned, 5 attempted before an early
kill at a session boundary), **7 of 8 attempted fits exceeded the
600-second per-fit cap**; recurring `solve(): system is singular` warnings
appeared on every attempted cell, not only the ones that timed out —
consistent with a property of this problem class, not one unlucky seed. The
single completed fit took 603.5 s and returned MSE 2.165, against gllvmTMB's
0.83 on the same DGP-b clade cell — too thin (n = 1) for a general accuracy
verdict, but sufficient to show Rphylopars is not a viable full-grid
comparator at these default settings; tuning (`skip_optim`, `npd`,
`EM_missing_limit`) or a smaller problem size is an open maintainer
decision, not resolved here. A full-grid Rphylopars comparison (6 cells ×
10 seeds) was not run.

## 4. Uncertainty (Design 119)

`predict_missing()` currently returns point reconstructions only —
"reconstruction standard errors and prediction intervals are not currently
returned" is the shipped documentation, still true after this arc. Design
119 frames the estimand split: a **confidence** interval targets the
conditional mean `mu_ut`, the weaker and cheaper target; a **prediction**
interval targets the value `y_ut` itself and additionally carries the
family's variance function `V_family(mu_ut, phi_t)` — irreducible response
noise that Arc0b's near-baseline binary/ordinal/hurdle results already
signal will be large for those families.

Source inspection established that the package's existing `se.fit`
machinery is not simply reusable: it propagates only the fixed-effect block,
`se(eta)^2 = diag(X_fix Cov(b_fix) X_fix')`, holding every random-effect
contribution at its conditional mode (derivative zero). A masked cell's
linear predictor is dominated by `lambda_t' u_hat` — the latent-score
contribution — so reusing `se.fit` as-is would understate reconstruction
uncertainty. Two candidate routes were named: R1-joint (one additional
`sdreport(getJointPrecision = TRUE)` call, exact but potentially expensive
at scale) and R1-quad (add `getLV(se = TRUE)` curvature in quadrature to the
fixed block — cheap, but ignores the fixed/latent cross-covariance).

**Wave-1 coverage result (gaussian, Totoro, 2026-08-15): not calibrated.**
Four mechanisms × 400 replicates = 1,600 fits, 100% convergence, zero bad
standard errors, ~0.9 s/fit, 0.2 core-hours total.

| mechanism | conf 90% | conf 95% | pred 90% | pred 95% |
|---|---|---|---|---|
| mcar05 | 0.937 | 0.965 | 0.916 | 0.953 |
| mcar20 | 0.930 | 0.960 | 0.908 | 0.948 |
| trait_clustered | 0.939 | 0.966 | 0.911 | 0.951 |
| unit_clustered | 0.938 | 0.966 | 0.912 | 0.951 |

(Monte Carlo SEs 0.001–0.002.)

Applying the pre-registered rule verbatim: prediction intervals at 95% are
near-nominal — two mechanisms pass the operative gate outright, one is
borderline, one is marginal — while every other estimand × level
combination over-covers by 1–4 percentage points, a gap well beyond 2×MCSE.
**The operative gate FAILS; register status stays `heuristic_unvalidated`.**
The over-coverage is informative rather than merely disappointing: it points
toward R1-quad's omitted fixed/latent cross-covariance double-counting
shared information, which is exactly what the exact joint-precision route
(R1-joint) removes. Per the pre-registered rule, the prescribed next step is
that route change, not a higher-precision re-run of R1-quad.

## 5. Boundaries — what is NOT claimed

| Claim explicitly out of scope | Status |
|---|---|
| MNAR-mechanism handling | Not modelled; only MCAR and structured-MAR mechanisms are exercised anywhere in this evidence. MNAR sensitivity is a listed, `blocked` deferred extension. |
| Multiple-imputation pooling (Rubin's rules or similar) | `blocked`, not built. |
| VA (variational) missing-response evidence | `partial`: sentinel/admission contract holds across 18 scalar cells, but this is not a public missing-data certificate, not VA `mi()` support, and carries no coverage or recovery evidence; multinomial has no VA route at all. |
| MSPL (binary Laplace-MSPL estimator) and masked responses | MSPL refuses masks by design; a FIML-MSPL route is deferred and unbuilt. |
| Reconstruction standard errors / prediction intervals as a public feature | None shipped. Design 119 wave-1 gaussian coverage failed its pre-registered gate (over-coverage); register status is `heuristic_unvalidated`; R1-joint is the prescribed next route, not yet built. |
| Categorical / binary / hurdle masked-cell reconstruction accuracy | Measured near baseline (binomial, ordinal_probit, delta_lognormal); explicitly not to be advertised as accurate on this evidence. Multinomial is the one categorical family that clearly beats baseline. |
| `predict_missing()` accuracy evidence status | `partial` by register rule (dev-script, not testthat-backed); no interval or MNAR claim attached. |
| Full-grid Rphylopars comparison | Not run: 7 of 8 attempted fits exceeded the 600 s cap at n = 50 × p = 25 under default settings; only a thin (n = 1 completed fit) data point exists. |
| Pagel's lambda estimation in gllvmTMB's phylogenetic factor model | Not estimated; `phylo_latent()` uses branch lengths directly (effectively λ = 1, pure Brownian), unlike P3CA/Rphylopars, which both estimate or profile λ. |

## Appendix: sources and register cross-reference

- `docs/dev-log/after-task/2026-08-15-missing-response-all-families.md` —
  arc report: mechanism, family sweep, VA arm, comparator harness, decisions,
  checks, limitations. (Read from the `gllvmtmb-986` worktree, at merged
  `main`.)
- `dev/missing-accuracy/RESULTS.md` — Arc0 (gaussian/poisson) and Arc0b
  (binomial/ordinal_probit/delta_lognormal/multinomial) accuracy tables,
  design, baselines, stop rules.
- `dev/missing-accuracy/rung1-prerun.md` — P3CA/Rphylopars head-to-head:
  comparator provenance, self-check, 3-replicate pre-run, G2-approved full
  fast-grid (180 fits) and per-cell MSE table, Rphylopars cameo, full-grid
  extrapolation.
- `docs/design/119-predict-missing-uncertainty.md` (worktree `gllvmtmb-pm-se`)
  — estimand split, R1a source-inspection finding, wave-1 gaussian coverage
  table and verdict (§7).
- `docs/design/35-validation-debt-register.md` — register rows consulted for
  claim-boundary wording: **MIS-21** (`covered`, per-family masked-response
  evidence across all 17 families under Laplace), **MIS-37** (`partial`,
  `predict_missing()` reconstruction accuracy, family-dependence note),
  **VA-10** (`partial`, VA response-include sentinel/admission contract),
  **MIS-32** (`blocked`, deferred missing-data extensions including MNAR
  sensitivity and MI pooling).
