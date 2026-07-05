# Design 48 — M3.4 boundary regimes: warm-start + residual starts + phi-clamp

**Maintained by**: Fisher (validation design) + Boole (R API)
+ Gauss (TMB-side numerical). **Active reviewers**: Curie (test
fidelity), Noether (identifiability — see audit
`2026-05-18-noether-nbinom2-identifiability.md`), Pat (user-
facing control surface), Rose (scope honesty), Ada (coordinator).
**Status**: Active — M3.4 mitigation implementation has landed;
target-explicit empirical rerun evidence and default-policy
decisions remain.
**Backed by**:
- Noether identifiability audit
  (`docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`)
- Cross-package scout audit
  (`docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`)
- Design 43 §4 #4 (single-trait warmup as Tier A borrowable from
  gllvm)
- McGillycuddy, Popovic, Bolker & Warton (2025), JSS 112(1):
  residual starts for reduced-rank `glmmTMB::rr()` fits
- Maintainer correspondence with McGillycuddy (2026-04-15):
  for complex Gaussian two-level rr models, residual starts were
  intended more for non-Gaussian responses; recommended workflow is
  multiple starts, simpler-model starts, and `optim`/BFGS when needed
- M3.4 implementation after-task report
  (`docs/dev-log/after-task/2026-05-18-m3-4-implementation.md`)
- validation-debt rows MIS-16 / MIS-17 / MIS-18 / MIS-19

## 1. The problem M3.4 solves

M3.3a smoke (PR #176, 15 cells × 10 reps × 5 traits with profile
CIs) surfaced **systematic under-coverage on count + ordinal +
mixed cells** at the smoke scale:

| Family | Avg coverage |
|---|---|
| Gaussian / binomial | ≈ 0.95 (near nominal) |
| ordinal-probit | 0.75 |
| Mixed | 0.64 |
| **nbinom2** | **0.38 (worst)** |

Per the Noether audit: nbinom2 under-coverage is caused by the
**$(\psi_t, \phi_t)$ trade-off** at small $n$ — the marginal
observed-y variance can be explained equivalently by latent
variance or NB dispersion, and the optimizer drifts along the
trade-off axis.

Per the scout audit: **no package warm-starts counts**
(glmmTMB, drmTMB, gllvm, galamm all start from default values);
gllvm has the only documented user-facing warm-start API
(`start.fit=` + vignette pattern "fit Poisson, pass to NB").
gllvm also has a phi starting-value clamp `[0.01, 100]`.

## 2. Implemented fix design (three initialization mitigations)

### Mitigation A — Single-trait warm-start

Per gllvm pattern (`gllvm.TMB:381-412` + vignette1): fit each
trait **univariately** first, then use the per-trait estimates
as **starting values** for the multivariate fit.

**Why it helps**: univariate fits have fewer parameters
competing for the variance signal. The univariate $(\hat\alpha_t,
\hat\psi_t, \hat\phi_t)$ are near-unbiased on a per-trait basis
because there's no rotation-ambiguous Lambda to absorb signal.
Using these as starting values lands the multivariate optimizer
near a good local mode rather than walking the
$(\psi, \phi)$ trade-off axis.

**User-facing API** (Boole lead):

```r
gllvmTMB(value ~ ... + latent(...),
         data = df,
         family = nbinom2(),
         control = gllvmTMBcontrol(
           init_strategy = "single_trait_warmup"
         ))
```

Default `init_strategy = "default"` keeps current behaviour.

**Implemented path** (Boole + Gauss):

1. Parse the multivariate data already assembled by
   `gllvmTMB_multi_fit()`.
2. For each trait level, fit an intercept-only univariate GLM with
   that trait's family.
3. Extract finite, clamped starts for matching `log_phi_*` entries.
4. Merge those starts into the default `tmb_params` before
   `TMB::MakeADFun()`.

**Implemented scope in v0.2.0**: phi-bearing families only, with
intercept-only univariate fits. Per-trait `b_fix`, `theta_diag_B`,
ordinal cutpoints, and delta-family secondary-parameter warmups are
deferred until the target-explicit M3.3 pilot shows they are needed.

### Mitigation A2 — Residual reduced-rank starts

Per McGillycuddy et al. (2025, JSS 112(1)), factor-analytic
likelihoods are often multimodal, so `glmmTMB` added
`start_method = list(method = "res")`: fit the fixed-effects part
first, compute residuals, fit a reduced-rank model to those residuals,
then use the resulting latent scores and loadings as starts. The
paper also recommends repeated fits with jittered latent starts
(`jitter.sd = 0.2` or similar) and keeping the highest-likelihood fit.

**User-facing API** (Boole lead):

```r
gllvmTMB(value ~ ... + latent(0 + trait | unit, d = K),
         data = df,
         family = gaussian(),
         control = gllvmTMBcontrol(
           start_method = list(method = "res", jitter.sd = 0.2),
           n_init = 5
         ))
```

**Why it helps**: the initial `Lambda` and latent scores come from
the observed residual cross-trait structure instead of the previous
flat start (`Lambda` diagonal 0.5, latent scores 0). This does not
make the likelihood convex, but it should reduce wasted optimizer
time in poor local basins and makes the repeated-start workflow more
purposeful.

**Implemented path** (Boole + Gauss):

1. Reuse the fixed-effect pseudo-response fit already computed in
   `gllvmTMB_multi_fit()`.
2. Aggregate residuals into a group x trait matrix for each active
   `latent()` tier.
3. Apply an SVD reduced-rank decomposition and rotate the loadings
   back into the engine's lower-triangular `Lambda` convention.
4. Seed `theta_rr_B` / `z_B` and, for paired `unique()` terms,
   `theta_diag_B` / `s_B`; do the same for W-tier terms when the
   W grouping has enough multi-trait residual information.
5. Add Normal jitter to latent scores when `jitter.sd > 0`.

**Implemented scope in v0.2.0**: opt-in only; contract-tested by
`test-start-method-residual.R`. This path is retained because it is
the published `glmmTMB` residual-start route and is most relevant for
non-Gaussian reduced-rank fits. It does not yet implement
glmmTMB's randomized Dunn-Smyth residuals for every discrete family;
the current start is deterministic apart from explicit `jitter.sd`.

### Mitigation A3 — Simpler independent GLMM starts

The maintainer's correspondence with McGillycuddy clarified an
important scope point: for complex Gaussian two-level reduced-rank
models, `method = "res"` was intended more for non-Gaussian
responses. The recommended Gaussian two-level workflow is to fit
multiple starts, try a simpler model (for example one rr term or an
independent covariance structure), use that model's estimated
parameters as starts for the complex fit, and switch to `optim`/BFGS
when `nlminb` struggles.

**User-facing API** (Boole lead):

```r
gllvmTMB(value ~ ... + latent(0 + trait | unit, d = K),
         data = df,
         family = gaussian(),
         control = gllvmTMBcontrol(
           start_method = list(method = "indep"),
           n_init = 5,
           optimizer = "optim",
           optArgs = list(method = "BFGS")
         ))
```

or manually:

```r
fit_indep <- gllvmTMB(value ~ ... + indep(0 + trait | unit),
                      data = df, family = gaussian())

fit_full <- gllvmTMB(value ~ ... + latent(0 + trait | unit, d = K),
                     data = df, family = gaussian(),
                     control = gllvmTMBcontrol(start_from = fit_indep))
```

**Why it helps**: an independent diagonal model is a genuine
GLMM/GLLVM warm start, not a fixed-effect-only GLM start. It estimates
the fixed effects, per-trait variance starts, and conditional random
effects on the same grouping tier before the full model has to split
that signal between `Lambda Lambda^T` and `Psi`.

**Implemented path** (Boole + Gauss):

1. `start_method = list(method = "indep")` drops B/W `latent()` rr
   terms from the parsed formula while retaining independent diagonal
   variance terms.
2. The simpler independent model is fitted once with recursive
   warm-starting disabled.
3. Matching same-shaped TMB parameters are copied into the full
   model's starting list (`b_fix`, `theta_diag_*`, `s_*`, and any
   same-shaped rr blocks if the supplied `start_from` has them).
4. Manual `start_from = simpler_fit` exposes the same copier so the
   maintainer can try "one rr term" or other bespoke simpler starts.

**Implemented scope in v0.2.0**: opt-in only; contract-tested by
`test-start-method-residual.R`. The automatic method currently targets
B/W tiers (`unit` and `unit_obs`); phylogenetic and spatial
independent-start analogues should wait for specific evidence that
they are needed.

### Mitigation B — Phi starting-value clamp `[0.01, 100]`

Per gllvm pattern (`gllvm.TMB:599-602`): when a count family is
used (nbinom1, nbinom2, truncated_nbinom1/2, beta_binomial),
clamp the **initial value** of `log_phi_*` to a reasonable
range.

**Why it helps**: avoids pathological random inits where phi
starts at numerical infinity (-> Poisson limit, sd_B picks up
all overdispersion) or numerical zero (-> NB likelihood
near-uniform, optimizer wanders).

**Implemented path** (Gauss):

For any `log_phi_*` starting parameter, clamp the initial value to
`[log(0.01), log(100)]` so initial phi ∈ `[0.01, 100]`. The
optimizer remains unconstrained; only the starting value is clamped.

No new user-facing argument needed — this is purely a sensible
default.

### Mitigation C — Fit-health and start provenance

The start ladder is only useful if users and simulation scripts can
see what actually happened. Design 49 adds the first robust-modeling
diagnostic layer:

- `fit$restart_history` records one row per attempted start, including
  start method, jitter scale, optimizer, objective, convergence code,
  message, elapsed time, and selected-restart flag.
- `fit$start_provenance` records whether the fit used default,
  residual, independent/simpler, single-trait warmup, or manual
  `start_from` starts.
- `fit$fit_health` stores optimizer, gradient, `sdreport()`,
  `pdHess`, fixed-effect SE, boundary, and selected-restart signals.
- `check_gllvmTMB()` exposes those signals as a stable data frame for
  tests, simulation summaries, and pkgdown examples.
- `TMB::sdreport()` failures are recorded as degraded inference
  status instead of aborting the fitted object.
- `gllvmTMBcontrol(se = FALSE)` intentionally skips Hessian-based
  standard-error calculation for hard models while preserving point
  estimates for bootstrap/profile uncertainty workflows.

This mitigation does not make any start strategy the default. It makes
the optimizer/start path auditable so the M3.3 target-explicit pilot
can compare strategies on objective, convergence, Hessian behavior,
coverage, and refit failure rate.

## 3. Implemented scope and remaining evidence

The implementation PR closed the API and internal-start mechanics.
The next M3 work is empirical validation, not basic implementation.

| Step | Lead | Status |
|---|---|---|
| **S1** — Add `init_strategy` arg to `gllvmTMBcontrol()` | Boole | Implemented; MIS-16 covered. |
| **S2** — Implement single-trait warmup loop in `R/fit-multi.R` | Boole + Gauss | Implemented for phi-bearing families. |
| **S2b** — Add residual reduced-rank starts | Boole + Gauss | Implemented as `start_method = list(method = "res")`; MIS-18 covered. |
| **S2c** — Add simpler independent GLMM starts | Boole + Gauss | Implemented as `start_method = list(method = "indep")` plus manual `start_from`; MIS-19 covered. |
| **S3** — Add phi starting-value clamp in `R/fit-multi.R` | Gauss | Implemented; MIS-17 covered. |
| **S3b** — Add fit-health and start provenance | Ada + Gauss + Fisher | Implemented in Design 49 slice: `restart_history`, `start_provenance`, protected/skipped `sdreport()`, `gllvmTMBcontrol(se = FALSE)`, `fit_health`, and `check_gllvmTMB()`; DIA-08 / DIA-09 / DIA-10 / MIS-20 track evidence status. |
| **S4** — Contract tests | Curie | Implemented in `test-m3-4-warmstart-phi-clamp.R`, `test-start-method-residual.R`, `test-stage39-multi-start.R`, and `test-sanity-multi.R`; these are contract tests, not R = 200 coverage claims. |
| **S5** — Rerun evidence | Curie + Pat | Pending. The next run must be target-explicit per Design 44. |
| **S6** — Validation-debt register | Rose | MIS-16 / MIS-17 / MIS-18 / MIS-19 / MIS-20 and DIA-08 / DIA-10 covered; DIA-09 / CI-08 / CI-10 remain partial. |
| **S7** — After-task report | Ada | Base report completed in `2026-05-18-m3-4-implementation.md`; residual-start addendum filed in `2026-05-19-residual-rr-starts.md`. |

## 4. Honest scope — what M3.4 will NOT achieve

Per the Noether audit §6:

- **Will not guarantee >= 94% coverage at smoke scale (R=10).**
  Monte Carlo error is ±15 pp; even if true coverage is exactly
  nominal, the smoke estimate at R=10 could read anywhere in
  $[0.80, 1.00]$. M3.3 production at R=200 is needed for ±3 pp
  precision.
- **Will not eliminate the $(\psi, \phi)$ trade-off** —
  warm-start and residual starts help the optimizer find a good
  local mode; the flat-likelihood direction still exists.
- **Will not make any warm start the default yet.** Residual starts
  and independent-GLMM starts are both opt-in until target-explicit
  M3 evidence compares default, residual, independent, and combined
  workflows.
- **Will not address mixed-family $d = \{2, 3\}$ convergence
  drop** beyond what nbinom2 warm-start gives (mixed-family
  fits include nbinom2 rows; helping nbinom2 helps mixed in
  proportion).
- **Will not implement `disp_group=` shared phi** (the follow-on
  dispersion-sharing mitigation in the Noether audit). That's a
  deliberate API choice
  needing maintainer ratification; if M3.4 warm-start + clamp
  don't get us to nominal at R=200 production, the follow-on
  PR considers disp_group.

## 5. Evidence needed after M3.4

Fisher's original prediction was that warm-start + phi clamp would
improve count and mixed-family coverage without changing Gaussian or
binomial cells. Residual reduced-rank starts are now an additional
opt-in convergence mitigation, while independent-GLMM starts are the
more relevant Gaussian two-level start. The implementation exists,
but the 2026-05-19
production grid still measured profile-`psi` coverage rather than
the primary total `Sigma_unit[tt]` target. Treat the table below as
the pre-implementation expectation, not as validated post-M3.4
evidence.

At smoke (R=10) — expected visible improvement:

| Cell | M3.3a coverage | M3.4 prediction |
|---|---|---|
| Gaussian | 0.95 | ~0.95 (no change; no count family) |
| Binomial | 0.95 | ~0.95 |
| ordinal-probit | 0.75 | ~0.80-0.85 (phi clamp irrelevant; warm-start helps cutpoints find good init) |
| Mixed | 0.64 | ~0.75-0.85 (warm-start helps the nbinom2 traits) |
| nbinom2 | 0.38 | **~0.70-0.85** (largest improvement) |

At production (R=200) — prediction before the target-scale audit:

- Gaussian / binomial: ≥ 0.94 (nominal at gate)
- ordinal-probit: ≥ 0.90, likely ≥ 0.94 with warm-start
- Mixed: ≥ 0.85, possibly ≥ 0.94
- nbinom2: ≥ 0.85, possibly ≥ 0.94 — but the
  $(\psi, \phi)$ trade-off at n=60 may keep this below gate;
  dispersion-sharing mitigation (`disp_group`) would close the rest

If the target-explicit post-M3.4 pilot still under-covers total
`Sigma_unit[tt]` in any cell < 0.90, Design 49 (dispersion sharing)
activates.

## 6. Cross-references

- Noether audit:
  `docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`
- Scout audit:
  `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`
- Design 42 — M3 DGP grid
- Design 43 §4 #4 — single-trait warmup as Tier A borrowable
- Design 43 §4 #9 — residual reduced-rank starts from glmmTMB
- Design 43 §4 #10 — simpler independent GLMM starts
- Design 44 — M3.3 inference replacement
- M3.3a after-task:
  `docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md`
- `R/init-warmstart.R` — single-trait warmup, residual-start, and
  `start_from` parameter-copy
  helpers.
- `R/fit-multi.R` — warmup / residual-start merge before
  `TMB::MakeADFun()`.
- `R/gllvmTMB.R` — `gllvmTMBcontrol()` `init_strategy` and
  `start_method` arguments.

## 7. Open questions

- **Q-Boole-1**: should single-trait warmup default to ON for
  count families, or always opt-in?
  - Lean: **opt-in for v0.2.0** (`control = list(init_strategy
    = "single_trait_warmup")`); revisit defaulting only after
    target-explicit R=200 evidence.
- **Q-Gauss-1**: phi clamp at $\log(0.01)$ ($\phi = 0.01$, near
  Poisson limit) — is this the right lower bound, or should it
  be tighter (e.g. $\phi = 0.1$)?
  - Lean: $[0.01, 100]$ matches gllvm's pattern; defensive +
    permissive. Adjust if production shows pathology.
- **Q-Curie-1**: warm-start parallelization — `future` /
  `future.apply` are already in Suggests; should the warmup
  loop default to parallel?
  - Lean: serial by default (5 univariate fits is ~5s); parallel
    optional via `control = list(warmup_parallel = TRUE)`.
- **Q-Boole-2**: should `start_method = list(method = "res")` become
  the default whenever a `latent()` term is present?
  - Lean: no for v0.2.0. Keep opt-in until M3 target-explicit
    evidence compares default, `single_trait_warmup`, residual starts,
    and their combination.
- **Q-Boole-3**: should `start_method = list(method = "indep")`
  become the recommended default for Gaussian two-level
  ordinary latent covariance fits?
  - Lean: not automatically. It is now the preferred rescue workflow
    for this regime, but defaulting needs M3 timing and recovery
    evidence because it adds an extra model fit.
- **Q-Fisher-1**: should we report a Wald CI in addition to the
  target-explicit bootstrap/profile CI for nbinom2 variance targets,
  to give users diagnostic insight into the $(\psi, \phi)$ trade-off
  symmetry?
  - Lean: extend `confint_inspect()` to plot profile-vs-Wald
    discrepancy on nbinom2 fits. Post-M3.4 polish.

## 8. Persona contributions to this draft

- **Fisher** (lead): expected-outcomes table (§5); mitigation
  ranking via Noether's audit.
- **Boole** (lead): user-facing `init_strategy` and
  `start_method` arg design (§2).
- **Gauss** (lead): phi-clamp and residual-start implementation
  sketch (§2); TMB-side cost-benefit.
- **Curie** (review, tests): warm-start vs default
  before/after smoke design (§3 S5).
- **Pat** (review): opt-in vs default for `init_strategy` —
  applied users would benefit from default-on, but it changes
  per-fit semantics; opt-in for v0.2.0 is conservative.
- **Rose** (review, scope honesty): §4 explicit no-claim that
  M3.4 hits the gate; §5 honest prediction band.
- **Ada** (coordinator): two-PR split held historically; current
  coordination point is the target-explicit M3.3 pilot before any
  default-policy change.

## 9. Next actions

1. **N1** — Keep `init_strategy = "single_trait_warmup"` opt-in for
   v0.2.0.
2. **N2** — Run the Design 44 target-explicit pilot with warmstart
   enabled before any new full 15-cell production dispatch.
3. **N3** — Update CI-08 / CI-10 only after total `Sigma_unit[tt]`
   evidence is available.
4. **N4** — If target-explicit R=200 production still under-covers
   any cell < 0.90, activate Design 49 (Mitigation C).
