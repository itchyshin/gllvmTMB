# Design 43 — Speed techniques worth borrowing from ASReml (post-CRAN reference)

**Maintained by**: Jason (literature / sister-package scout, lead)
+ Gauss (TMB-side numerical feasibility, lead).
**Active reviewers**: Boole (R API surface impact), Ada
(scope-ratifies as v0.3.0+).
**Status**: Reference design. Most items remain post-CRAN
reference material; single-trait warmup has since moved from this
borrowable-technique list into the implemented M3.4 mitigation
recorded in Design 48 and MIS-16 / MIS-17.

## 1. Why this document exists

Maintainer ask 2026-05-17: *"is there any coding techniques you
could learn from asreml to make our algorithm more efficient and
fast?"* The honest answer requires distinguishing **proprietary
implementation** (we cannot legally inspect or copy ASReml's
FORTRAN binary) from **published algorithms** (which we can
re-implement from the published literature). This note enumerates
the second set.

## 2. ASReml inspection — what's actually in the tarball

`/Users/z3437171/Desktop/asreml-4.1.0.130-macOS-10.13.2-R4.0.tar.gz`,
inspected 2026-05-17:

```
asreml/
├── inst/libs/asreml.so       (7.7 MB Mach-O 64-bit binary)
├── inst/libs/libvsninet.so   (3.4 MB VSN licence-server binary)
├── R/all.R                   (17 323 lines — pure R wrapper:
                                parser, output formatting, plots)
├── inst/doc/                 (3 public PDF manuals)
└── man/                      (88 help pages)
```

The R wrapper roxygen header itself says: *"the model is fitted
by calls to the underlying Fortran REML routines (Gilmour et al.,
1995)."*

**The speed lives inside `asreml.so`** — proprietary, not legally
inspectable. The R wrapper is interface code only.

What we **can** legitimately learn from is the **published**
algorithmic literature that ASReml implements. The references in
Section 4 below are all open-access papers we can study and
re-implement from scratch, without any reference to ASReml's
source code.

## 3. The A-vs-V naming boundary, restated

The animal-model side of this discussion uses **A** = pedigree-
derived additive relatedness matrix. ASReml shares the same
convention (its `nrm` / "numerator relationship matrix" is our
**A**). In what follows, **A** always means relatedness; **V**
in our codebase is reserved for `meta_V()` (meta-analytic
sampling variance; `meta_known_V()` is the deprecated alias).
ASReml uses **V** for the marginal
phenotypic covariance ($V = ZGZ^{\!\top} + R$). When citing
ASReml literature in M3+, be careful not to import their **V**
notation into gllvmTMB prose without translation.

## 4. Published techniques worth borrowing

Numbered for cross-reference; status updated 2026-06-15 after the
Gaussian-only `REML = TRUE` pilot landed.

| # | Technique | Open reference | Where gllvmTMB stands |
|---|---|---|---|
| 1 | **AI-REML** (Average Information matrix instead of Fisher) | Gilmour, Thompson & Cullis (1995) *Biometrics* 51:1440 | **Later Gaussian-only acceleration candidate.** A narrow Gaussian-only `REML = TRUE` pilot exists, but AI-REML is not a public algorithm claim and is not a label for non-Gaussian Laplace models. If the exact Gaussian variance-component cells become outer-loop limited, AI-REML's step rule is the canonical fast candidate to test against the current TMB autodiff baseline. |
| 2 | **Sparse A⁻¹ direct engine path** (Henderson-Quaas) | Henderson (1976) *Biometrics* 32:69; Quaas (1976) *Biometrics* | **Already planned: ANI-08 in validation-debt register, v0.3.0**. We densify A⁻¹ internally in v0.2.0; ASReml takes sparse A⁻¹ directly. Biggest single win for n_species > 500. Implementation pattern: pass sparse A⁻¹ as `Eigen::SparseMatrix<double>` into the TMB template; reuse `MCMCglmm`'s convention. |
| 3 | **Factor-analytic G matrix (FA-RR)** | Smith, Cullis & Gilmour (2001) *Crop Sci.* 41:1138; Runcie & Mukherjee (2013) *Genetics* 194:753 | **Already implemented**: `animal_latent(d = K) + animal_unique()` is exactly FA-G. Confirmed in `vignettes/articles/animal-model.Rmd` Tutorial 3. |
| 4 | **Single-trait warmup → multi-trait fit** | ASReml-R user guide (Butler 2017, §5.4) — standard workflow | **Implemented for M3.4 phi starts**. `gllvmTMBcontrol(init_strategy = "single_trait_warmup")` now fits intercept-only univariate GLMs per trait and seeds matching `log_phi_*` entries before `MakeADFun()`. Covered by MIS-16 / `test-m3-4-warmstart-phi-clamp.R`. Per-trait `b_fix`, ordinal cutpoints, and delta-family secondary-parameter warmups remain deferred. |
| 5 | **Variance-ratio (γ) parameterisation** | Searle, Casella & McCulloch (1992) §6 | **Alternative parameterisation, not implemented**. ASReml's outer loop optimises over γ = σ²_random / σ²_residual rather than absolute variances. More stable near σ²_random → 0. Could be a `gllvmTMB.control(parameterisation = "gamma")` mode. Lower priority than #4 — TMB's log-variance parameterisation already handles boundaries reasonably. |
| 6 | **Sparse Cholesky reordering (AMD / MMD)** | Davis (2006) "Direct Methods for Sparse Linear Systems" §7 (CHOLMOD reference) | **Likely already optimal**. TMB uses CHOLMOD under the hood, which applies AMD by default. ASReml uses MMD. Both are O(n^{3/2}) on regular sparsity patterns. Would need to profile gllvmTMB on the n > 500 phylo/pedigree regime to confirm CHOLMOD's default is fine; deferred until ANI-08 implementation surfaces a real bottleneck. |
| 7 | **Block-diagonal MME exploitation** | Lynch & Walsh (1998) §27 | **Not exploited**. When the trait covariance is block-diagonal (no cross-trait covariance), the MME decouples into per-trait blocks. TMB's autodiff doesn't automatically exploit this. Worth checking on T > 10 cases. Low priority. |
| 8 | **OpenMP parallel inner-loop** | Standard practice in ASReml + WOMBAT | **Not implemented**. TMB supports `#pragma omp parallel for` in C++ inner loops. Worth a profile-then-parallelise pass on the inner Laplace eval for large n. Post-CRAN; possibly Phase 5.5 if a pilot user hits a slow case. |
| 9 | **Residual reduced-rank starts** | McGillycuddy, Popovic, Bolker & Warton (2025), JSS 112(1), `glmmTMBControl(start_method = list(method = "res"))` | **Implemented as opt-in**. `gllvmTMBcontrol(start_method = list(method = "res", jitter.sd = 0.2))` now seeds `latent()` loadings and latent scores from a reduced-rank decomposition of fixed-effect residuals, with paired `unique()` residual starts when present. Covered by MIS-18 / `test-start-method-residual.R`. |
| 10 | **Simpler GLMM/GLLVM starts** | McGillycuddy correspondence with maintainer (2026-04-15): fit simpler models and use their estimated parameters as starts for complex rr fits | **Implemented as opt-in**. `gllvmTMBcontrol(start_method = list(method = "indep"))` fits the matching independent `unique()`-only model first and copies same-shaped TMB parameters into the full latent+unique fit. Manual `start_from = simpler_fit` also supports one-rr-term starts. Covered by MIS-19 / `test-start-method-residual.R`. |

## 5. Cost-benefit ranking for gllvmTMB

Highest-impact first, given our M3+ trajectory:

**Tier A — landed or definitely worth doing post-CRAN.**

- **#2 — Sparse A⁻¹ direct.** ANI-08 already on the roadmap; the
  speedup grows to ~24× at n_species > 500 (per the existing
  Hadfield & Nakagawa 2010 inheritance prose in `R/brms-sugar.R`).
- **#4 — Single-trait warmup.** Implemented for phi-bearing
  families as an opt-in M3.4 mitigation. The remaining question is
  empirical: whether the next target-explicit M3.3 pilot supports
  keeping it opt-in or making it the count-family default later.
- **#9 — Residual reduced-rank starts.** Implemented as an opt-in
  glmmTMB/JSS-style start method for factor-analytic terms. Treat
  this primarily as a non-Gaussian reduced-rank rescue path.
- **#10 — Simpler GLMM/GLLVM starts.** Implemented as the more
  relevant Gaussian two-level rescue path. The remaining question is
  empirical: whether it should stay a manual rescue option or become
  the default for `latent()` fits after M3 target-explicit evidence.

**Tier B — worth a profile pass before committing effort.**

- **#6 — Sparse Cholesky reordering.** CHOLMOD's default is
  probably already fine; confirm before optimising.
- **#1 — AI-REML.** Revisit only for exact Gaussian REML cells after the
  narrow Gaussian REML pilot has enough target-explicit runtime evidence; the
  gain depends on the outer-loop Newton step's dominance of runtime, which TMB
  may already obviate via autodiff. Do not use AI-REML language for
  non-Gaussian Laplace models.

**Tier C — defer.**

- **#3** — already implemented.
- **#5, #7, #8** — speculative; revisit if a profile finds the
  relevant bottleneck.

## 6. What we should NOT borrow

For honesty and to set scope:

- **The FORTRAN inner loops.** Proprietary. Even if we could read
  them, re-implementing them outside the original engine wouldn't
  give the same speed (the speed comes from years of tuning).
  TMB's autodiff is our equivalent — different tradeoff, comparable
  ceiling.
- **ASReml's specific data structures.** Proprietary; not in the
  R wrapper.
- **The licence-server pattern (`libvsninet.so`).** Open-source
  package; users should not encounter a licence prompt.

## 7. Where to put this guidance

This document captures the **reference**. Concrete v0.3.0 work
items derived from it are tracked in:

- `docs/design/35-validation-debt-register.md` ANI-08 (sparse
  A⁻¹ — Tier A item #2 above).
- `docs/design/35-validation-debt-register.md` MIS-16 / MIS-17
  (single-trait warmup and phi clamp — M3.4 implemented scope).
- `docs/design/35-validation-debt-register.md` MIS-18
  (residual reduced-rank starts — glmmTMB/JSS-style opt-in scope).
- `docs/design/35-validation-debt-register.md` MIS-19
  (simpler independent GLMM starts and manual `start_from`).

## 8. Cross-references

- Sister-package scope: `docs/design/04-sister-package-scope.md`
  has a one-line summary row for ASReml-R.
- Animal model worked example:
  `vignettes/articles/animal-model.Rmd`.
- Speed-related planning: `docs/dev-log/audits/2026-05-14-phase-1-landscape-scan.md`
  (Jason's pre-M1 landscape scan; this note extends that surface).

## 9. Persona contributions to this draft

- **Jason** (lead): ASReml tarball inspection; literature
  enumeration in Section 4; cost-benefit ranking in Section 5;
  scope-honesty list in Section 6.
- **Gauss** (lead): TMB-side feasibility check for each technique
  (the "Where gllvmTMB stands" column in Section 4).
- **Boole** (review): R-API surface impact for the proposed
  `control` flags (#4 warmup, #5 parameterisation).
- **Ada** (review): keeps this as a reference map; the only v0.2.0
  item moved from proposal to implementation is the M3.4 warmup
  mitigation.
