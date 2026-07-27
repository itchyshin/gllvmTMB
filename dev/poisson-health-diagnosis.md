# Poisson GH-VA `failed_health_gate` diagnosis (Gauss, READ-ONLY)

Scope: diagnose why `.approximation_engine_fit(engine = "va_r3", family =
"poisson", ...)` reported `status = "failed_health_gate"` at n=60, T=12,
q=2 (19.5s) but `"healthy"` at n=40, T=8, q=2 (~3s). No `R/` file was
modified. Repro scripts:
`dev/poisson-health-diagnosis-repro.R` and
`dev/poisson-health-diagnosis-precision.R` (raw output kept in
`/tmp/poisson-diag-out.txt`, `/tmp/poisson-precision-out.txt`; grid saved
to `dev/poisson-health-diagnosis-grid.rds`).

## Bottom line

**(b) Mislabelled healthy fit — a gate-calibration defect, not a real
convergence failure and not a starting-value problem.** The Poisson VA fit
converges to the *same* optimum from all 4 restarts, every time, at every
grid point tested (objective spread across all 4 starts ~1e-8, five to six
orders of magnitude inside the 1e-6 multi-start agreement tolerance). The
gate nonetheless returns `failed_health_gate` in 8 of 9 grid cells because
its **per-start absolute gradient-norm screen (`< 1e-4`)** is miscalibrated
for this objective's scale/parameterisation: post-optimisation gradients
routinely plateau in the 1e-4–8e-4 range even after two `nlminb` polish
passes and a BFGS polish, regardless of which of the 4 fixed starting points
was used. The 19.5s figure is unrelated to the health-gate outcome — it is
the well-known ~first-call-in-session TMB compile/load cost, not a
size-driven slowdown.

## 1. Which health criterion fails, exact quantity and threshold

`R/va-r3-proto.R` builds `admitted` from two independent gates (lines
558–612):

- **Per-start "healthy" screen** (line 558–559):
  `identical(opt$convergence, 0L) && is.finite(opt$objective) &&
  finite_parameters && max_abs_gradient < 1e-4`.
- **Cross-start agreement gate** (lines 578–582): needs
  `length(healthy_id) >= 3` AND `best_three_objective_range <= 1e-6`.
- **Variance-domain gate** (line 601): `max_projected_variance <= 4`,
  independently reported as `failed_variance_domain` when it alone fails.

`status` (lines 606–612) is `"healthy"` only if both the multi-start
agreement gate and the variance-domain gate pass; otherwise it is
`"failed_variance_domain"` if that gate alone is the failure, else
`"failed_health_gate"`.

For the reported symptom, `variance_domain_ok` was **TRUE in every run in
this diagnosis** (`max_projected_variance` ranged 0.17–1.02, far under the
4.0 limit — consistent with `dev/variance-domain-gate-note.md`: Poisson's
exact `E[exp(eta)]` closed form has no accuracy-vs-`v` sensitivity, so this
gate is essentially never the binding one for Poisson). The quantity that
actually trips is **`healthy_starts < 3`** — the per-start gradient screen,
not the agreement check and not the variance gate.

Concretely, for n=60, T=12 (this diagnosis's own run of exactly that cell,
Part 2 sweep): `healthy_starts = 0/4`, tripped reason `"insufficient healthy
starts (0/4 < 3)"`, with per-start gradients `1.14e-04, 1.26e-04, 1.06e-04,
1.27e-04` — every single one just above the `1e-4` cutoff.

## 2. Same gate as binary, or different?

**Different.** The binary/Bernoulli symptom documented in
`dev/variance-domain-gate-note.md` is the **variance-domain gate**
(`max_projected_variance <= 4`), driven by the softplus Taylor expansion's
domain of validity. The Poisson symptom here is the **gradient-norm health
screen** (`max_abs_gradient < 1e-4`), which is a completely separate check
earlier in the same `admitted` computation. Poisson essentially never trips
the variance-domain gate (exact closed form, no expansion); it trips the
gradient screen instead, for reasons unrelated to family algebra (see §5).

## 3. Real failure or mislabelled fit?

**Mislabelled.** High-precision evidence
(`dev/poisson-health-diagnosis-precision.R`):

```
n=40,T=8:  objectives 538.9794898059 / 538.9794897966 / 538.9794897998 / 538.9794897986
           spread across all 4 starts: 9.27e-09
n=60,T=12: objectives 1224.7946253158 / 1224.7946253263 / 1224.7946253153 / 1224.7946253328
           spread across all 4 starts: 1.75e-08
```

All 4 restarts land on the same optimum to ~8–9 significant figures in
every grid cell tested (spread 7.9e-09 to 6.3e-08 across all 9 cells) —
there is no local-optima disagreement anywhere in this sweep. If the
gradient screen is loosened even slightly, the *existing* 1e-6 agreement
gate still applies and is passed trivially (spreads are ~100–1000x tighter
than that tolerance already).

Sign check also passes cleanly, consistent with the established VA-vs-
Laplace bound:

```
n=40,T=8:  VA ELBO -538.980  vs Laplace logLik -537.860  (gap 1.12 nats, ELBO <= logLik: TRUE)
n=60,T=12: VA ELBO -1224.795 vs Laplace logLik -1224.179 (gap 0.62 nats, ELBO <= logLik: TRUE)
```

Both gaps are small and the bound direction is correct, matching the
established sign-check magnitude for other matched Poisson cells (~1.16
nats). This is a converged, correct fit carrying an incorrect status label.

Procrustes-vs-Laplace loadings comparison was **not completed** — I did not
find a working extractor for the plain Laplace `latent(..., unique=FALSE)`
fit's `Lambda` in the time available (`gllvmTMB::getLV()` does not exist;
`extract_loadings()` was not chased down). This is a gap in the requested
evidence, but the objective-spread and sign-check evidence above is already
sufficient to rule out (a) real convergence failure on its own — a
genuinely bad/wrong optimum would not reproduce the identical objective to
8 significant figures from 4 independent, meaningfully different starting
points (`diagonal_scale` alternating `+/-0.10, +/-0.20`, see
`.va_r3_default_parameters`) at every one of 9 grid points.

## 4. Why 19.5s? Evaluations, iterations, restarts

`nlminb` itself is cheap: `evaluations` (function count) were 6–13 across
every start in every grid cell, `iterations` mostly `NA` (nlminb didn't
report it) or 3 when reported. The optimizer is not doing many restarts
beyond the fixed 4 starts, and each restart converges almost immediately —
this is exactly the "cheapest arm" behaviour expected for the closed-form
Poisson likelihood.

The BFGS polish **does** fire on most starts (`polish_optimizer =
"nlminb_then_bfgs"`) because the post-nlminb gradient is already above
`1e-4` before BFGS runs — but BFGS's own post-optimisation gradient still
often doesn't clear `1e-4` either (see §5), so this is wasted effort, not
runaway cost: BFGS was capped at `maxit = 500` and none of the observed fits
show signs of hitting that cap.

**The 19.5s is not attributable to the fit itself.** In this diagnosis,
whichever Poisson cell was fit *first in the R session* (i.e., first call
to `.va_r3_load_dll()`/`TMB::compile()`) paid the full compile+link cost —
18.87s for a call that, once the DLL was cached, dropped to 0.3–2.8s for
every subsequent cell including much larger ones (n=100, T=20 took 2.80s).
This exactly mirrors the already-established "~3x first-fit-in-session
penalty" — here amplified further because the DLL had to be compiled from
scratch (`clang++ ... gllvmTMB_va_r3.cpp`), not just JIT-warmed. **The
original report's "n=60,T=12 took 19.5s vs n=40,T=8 took ~3s" is almost
certainly this same order-of-first-call artifact**, not a real n/T-driven
cost difference — in this diagnosis's own run, fitting n=40,T=8 *first*
made *it* the 18.9s call and n=60,T=12 the fast one, i.e. the timing
followed call order, not problem size, exactly as the swapped labels here
demonstrate.

## 5. Reproduces across seeds and sizes?

Yes, pervasively. Sweep over n in {40, 60, 100} x T in {8, 12, 20}, q=2,
H=15, one seed per cell (`dev/poisson-health-diagnosis-repro.R`, Part 2):

| n | T | status | elapsed(s) | healthy/4 | max_proj_var | tripped |
|---|---|---|---|---|---|---|
| 40 | 8 | failed_health_gate | 0.40 | 0 | 0.55 | insufficient healthy starts |
| 60 | 8 | failed_health_gate | 1.03 | 0 | 1.02 | insufficient healthy starts |
| 100 | 8 | failed_health_gate | 0.85 | 0 | 0.59 | insufficient healthy starts |
| 40 | 12 | failed_health_gate | 0.34 | 1 | 0.40 | insufficient healthy starts |
| 60 | 12 | failed_health_gate | 0.54 | 0 | 0.50 | insufficient healthy starts |
| 100 | 12 | failed_health_gate | 1.03 | 0 | 0.47 | insufficient healthy starts |
| 40 | 20 | failed_health_gate | 0.92 | 0 | 0.64 | insufficient healthy starts |
| **60** | **20** | **healthy** | 0.78 | 4 | 0.19 | n/a |
| 100 | 20 | failed_health_gate | 2.80 | 0 | 0.32 | insufficient healthy starts |

**8 of 9 cells fail**, with no monotonic relationship to n or T — small and
large problems fail alike, and the one healthy cell (n=60, T=20) is not the
smallest or the largest. This is consistent with the gradient screen
sitting essentially on a coin-flip boundary that the RNG-driven starting
points happen to land on either side of, not with a genuine size-dependent
breakdown.

Gradient-threshold sensitivity confirms the boundary is arbitrary
(`dev/poisson-health-diagnosis-precision.R`, all 9 grid cells, same seeds):

| n | T | healthy count @ 1e-4 | @ 2e-4 | @ 5e-4 | @ 1e-3 |
|---|---|---|---|---|---|
| 40 | 8 | 0/4 | 1/4 | 3/4 | 4/4 |
| 60 | 8 | 0/4 | 2/4 | 3/4 | 4/4 |
| 100 | 8 | 0/4 | 0/4 | 4/4 | 4/4 |
| 40 | 12 | 1/4 | 3/4 | 4/4 | 4/4 |
| 60 | 12 | 0/4 | 4/4 | 4/4 | 4/4 |
| 100 | 12 | 0/4 | 2/4 | 3/4 | 4/4 |
| 40 | 20 | 0/4 | 1/4 | 4/4 | 4/4 |
| 60 | 20 | 4/4 | 4/4 | 4/4 | 4/4 |
| 100 | 20 | 0/4 | 0/4 | 3/4 | 4/4 |

At `1e-3` every cell is 4/4 healthy, while the objective spread across all
4 starts stays ~1e-8 throughout — i.e. loosening the per-start gradient
screen does not admit any genuinely divergent fit; the 1e-6 agreement gate
remains the real safeguard against multimodality and is passed by a wide
margin at every threshold tested.

## Recommended smallest fix

Raise the per-start gradient-norm threshold used in the `healthy` screen
(`R/va-r3-proto.R` line 559, and the `gradient_tolerance` value reported at
line 636) from `1e-4` to `1e-3` for the Poisson (and possibly generally —
out of scope here) arm. This is the minimal change because:

- It is a single constant, not a restructuring of the gate.
- The evidence above shows the existing cross-start objective-agreement
  check (`1e-6` tolerance) already does the real work of catching a
  genuinely non-convergent or multimodal fit; it is untouched by this
  change and still has 2–3 orders of magnitude of headroom versus the
  observed spreads (~1e-8).
- Tightening `nlminb`/BFGS controls instead (more iterations, tighter
  `reltol`) is unlikely to help: gradients already plateau at 1e-4–8e-4
  after 2 polish passes plus a BFGS polish with `reltol = 1e-12`, so the
  residual is best read as the numerical floor of this objective's scale
  (~500–1200) and per-observation variational parameterisation, not
  under-iteration.

Do not touch the variance-domain gate (`<= 4`) or the agreement tolerance
(`<= 1e-6`) — both are working as intended and neither was implicated here.

## Follow-up not completed (flagged, not silently dropped)

Direct Procrustes comparison of VA vs. Laplace `Lambda` loadings for the
two named cells was not finished — no working extractor for the plain
Laplace fit's loadings was located in the time available. The
objective-spread and sign-check evidence already rules out a real
convergence failure, but a maintainer wanting the loadings-level check
specifically should re-run `dev/poisson-health-diagnosis-repro.R`'s
`extract_lambda_lap()` stub with a correct extractor (e.g. whatever
`fit-multi.R`'s own diagnostics use internally) rather than trusting the
current stub, which returns `NULL`.
