# Design 43 — Speed techniques worth borrowing from ASReml (post-CRAN reference)

**Maintained by**: Jason (literature / sister-package scout, lead)
+ Gauss (TMB-side numerical feasibility, lead).
**Active reviewers**: Boole (R API surface impact), Ada
(scope-ratifies as v0.3.0+).
**Status**: Reference design — post-CRAN. No v0.2.0 implementation
work; this note captures what's borrowable and why, so M3 / Phase
5 / Phase 5.5 work can reach for the right idea when needed.

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
in our codebase is reserved for `meta_known_V()` (meta-analytic
sampling variance). ASReml uses **V** for the marginal
phenotypic covariance ($V = ZGZ^{\!\top} + R$). When citing
ASReml literature in M3+, be careful not to import their **V**
notation into gllvmTMB prose without translation.

## 4. Published techniques worth borrowing

Numbered for cross-reference; status reflects gllvmTMB v0.2.0.

| # | Technique | Open reference | Where gllvmTMB stands |
|---|---|---|---|
| 1 | **AI-REML** (Average Information matrix instead of Fisher) | Gilmour, Thompson & Cullis (1995) *Biometrics* 51:1440 | **Not applicable in v0.2.0** — we use ML via TMB autodiff. When REML lands post-0.2.0 (Gaussian-only per README), AI-REML's step rule is the canonical fast outer-loop. TMB's exact autodiff gradient is already a strong starting point; an AI-style Hessian approximation may not be net-faster. |
| 2 | **Sparse A⁻¹ direct engine path** (Henderson-Quaas) | Henderson (1976) *Biometrics* 32:69; Quaas (1976) *Biometrics* | **Already planned: ANI-08 in validation-debt register, v0.3.0**. We densify A⁻¹ internally in v0.2.0; ASReml takes sparse A⁻¹ directly. Biggest single win for n_species > 500. Implementation pattern: pass sparse A⁻¹ as `Eigen::SparseMatrix<double>` into the TMB template; reuse `MCMCglmm`'s convention. |
| 3 | **Factor-analytic G matrix (FA-RR)** | Smith, Cullis & Gilmour (2001) *Crop Sci.* 41:1138; Runcie & Mukherjee (2013) *Genetics* 194:753 | **Already implemented**: `animal_latent(d = K) + animal_unique()` is exactly FA-G. Confirmed in `vignettes/articles/animal-model.Rmd` Tutorial 3. |
| 4 | **Single-trait warmup → multi-trait fit** | ASReml-R user guide (Butler 2017, §5.4) — standard workflow | **Easy add, not implemented**. Pattern: fit one univariate animal model per trait first, use the per-trait variances as warm starts for the multivariate fit. Add as `control = list(init_strategy = "single_trait_warmup")` in `gllvmTMB.control()`. Slice size ~150 LOC + a recovery test. Likely M3.4 boundary-regimes or post-M3 polish. |
| 5 | **Variance-ratio (γ) parameterisation** | Searle, Casella & McCulloch (1992) §6 | **Alternative parameterisation, not implemented**. ASReml's outer loop optimises over γ = σ²_random / σ²_residual rather than absolute variances. More stable near σ²_random → 0. Could be a `gllvmTMB.control(parameterisation = "gamma")` mode. Lower priority than #4 — TMB's log-variance parameterisation already handles boundaries reasonably. |
| 6 | **Sparse Cholesky reordering (AMD / MMD)** | Davis (2006) "Direct Methods for Sparse Linear Systems" §7 (CHOLMOD reference) | **Likely already optimal**. TMB uses CHOLMOD under the hood, which applies AMD by default. ASReml uses MMD. Both are O(n^{3/2}) on regular sparsity patterns. Would need to profile gllvmTMB on the n > 500 phylo/pedigree regime to confirm CHOLMOD's default is fine; deferred until ANI-08 implementation surfaces a real bottleneck. |
| 7 | **Block-diagonal MME exploitation** | Lynch & Walsh (1998) §27 | **Not exploited**. When the trait covariance is block-diagonal (no cross-trait covariance), the MME decouples into per-trait blocks. TMB's autodiff doesn't automatically exploit this. Worth checking on T > 10 cases. Low priority. |
| 8 | **OpenMP parallel inner-loop** | Standard practice in ASReml + WOMBAT | **Not implemented**. TMB supports `#pragma omp parallel for` in C++ inner loops. Worth a profile-then-parallelise pass on the inner Laplace eval for large n. Post-CRAN; possibly Phase 5.5 if a pilot user hits a slow case. |

## 5. Cost-benefit ranking for gllvmTMB

Highest-impact first, given our M3+ trajectory:

**Tier A — definitely worth doing post-CRAN.**

- **#2 — Sparse A⁻¹ direct.** ANI-08 already on the roadmap; the
  speedup grows to ~24× at n_species > 500 (per the existing
  Hadfield & Nakagawa 2010 inheritance prose in `R/brms-sugar.R`).
- **#4 — Single-trait warmup.** Low-effort, high-frequency win;
  multivariate fits are slower per Curie's bench, and warm starts
  routinely cut wall time 2-5× when the per-trait variances are
  close to truth.

**Tier B — worth a profile pass before committing effort.**

- **#6 — Sparse Cholesky reordering.** CHOLMOD's default is
  probably already fine; confirm before optimising.
- **#1 — AI-REML.** Wait for REML to land first; the gain depends
  on the outer-loop Newton step's dominance of runtime, which TMB
  may already obviate via autodiff.

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
- Future entry: ANI-12 (single-trait warmup — Tier A item #4).
  To be added when M3.4 dispatches if the boundary-regime work
  finds slow cells that would benefit.

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
- **Ada** (review): scope-ratifies as v0.3.0+ — no v0.2.0 work
  is triggered by this note.
