# Local paired LA-MSPL vs LA-ML smoke — admitted Bernoulli logit

**Status:** one-Mac point-estimate smoke. Not a campaign. Not a
programme result. Interval / SE work is owned by
`codex/lane-b-mspl-interval-feasibility` and was not run
(no sandwich, profile, jackknife, `vcov`, `confint`, or `se = TRUE`).

**Reader:** method developer who needs a cheap paired check that
LA-MSPL and LA-ML both return finite Laplace point estimates on the
admitted ordinary binomial-logit surface.

**Tree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` @
`fb6f9dae` (`origin/main`, #963). Loaded with
`pkgload::load_all(..., compile = TRUE)` then refit with
`compile = FALSE`. `OMP_NUM_THREADS=1`, `NOT_CRAN=true`.

**Recipe:** `tests/testthat/test-mspl-api.R` `.mspl_fixture` /
`.mspl_fit`. Ordinary `latent(..., unique = FALSE)`, so no Psi.
Rotation-invariant comparison is relative Frobenius on
`extract_Sigma(..., part = "shared")` = \(\Lambda\Lambda^\top\),
not raw Lambda packs. True \(G = \Lambda_{\mathrm{DGP}}\Lambda_{\mathrm{DGP}}^\top\).

Both arms used the same data, `n_init = 1`, `init_jitter = 0`,
`nlminb` / Laplace, `se = FALSE`. q = 1 only (the helper also does
q = 2 cheaply; this smoke did not).

## Cells

1. **HEALTHY** — exact `.mspl_fixture("logit", q = 1)`:
   `n_site = 24`, 3 traits, \(\Lambda = (0.8, -0.55, 0.35)\),
   \(\beta = (-0.5, 0.1, 0.55)\), seed `8808 + 1 + 1`. Prevalence
   0.542 / 0.500 / 0.625. Complete responses, no near-separation.

2. **NEAR-BOUNDARY smoke, not a certified separation DGP.** Same
   grammar. `n_site = 12`, \(\Lambda = (2.4, -2.0, 1.8)\),
   \(\beta = (-2.5, 0.05, 2.6)\), seed `88081`. Prevalence
   0.167 / 0.833 / 0.917 (rare + ubiquitous). No Design-88 /
   `detectseparation` certificate. The existing MSPL separation
   fixture in `test-mspl-api.R` is cloglog fixed-effect, not this
   logit latent cell.

## Table (two cells × two arms)

| cell | arm | conv | finite | registry_cell | status | evidence | rel Frob vs true \(G\) | rel Frob MSPL vs ML | max\|Λ\| | min ψ | wall s | obj |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| healthy | ML | 0 | yes | — | — | — | 2.576 | 0.543 | 1.169 | NA | 0.55 | 48.294 |
| healthy | MSPL | 0 | yes | `binomial:logit:ordinary:q1` | admitted | `partial_b2_incomplete` | 1.459 | 0.543 | 0.748 | NA | 3.76 | 47.214 |
| near-boundary | ML | 0 | yes | — | — | — | 179.9 | 1.000 | 47.21 | NA | 0.07 | 10.992 |
| near-boundary | MSPL | 0 | yes | `binomial:logit:ordinary:q1` | admitted | `partial_b2_incomplete` | 1.000 | 1.000 | 7.1e-6 | NA | 0.10 | 13.779 |

MSPL registry on both MSPL fits: **admitted**, evidence
**partial_b2_incomplete**, as required. ML has no `fit$mspl` slot.

Healthy shared \(\Sigma\) (rounded):

```
ML    t1 0.313  0.529  0.654
      t2 0.529  0.894  1.105
      t3 0.654  1.105  1.365

MSPL  t1 0.191  0.288  0.327
      t2 0.288  0.435  0.493
      t3 0.327  0.493  0.560
```

Near-boundary shared \(\Sigma\): ML exploded
(\(\max|\Lambda|=47.2\), \(G_{33}\approx 2229\)); MSPL collapsed to
a numerical zero matrix.

## Looked better / worse / similar (one seed, not a programme result)

- **Healthy:** both arms finite and converged. MSPL was closer to
  true \(G\) on this seed (1.46 vs 2.58) and smaller
  \(\max|\Lambda|\). The pair still disagreed (rel Frob 0.54). Call
  this **similar-to-modestly-closer for MSPL on one healthy seed**.
- **Near-boundary:** ML ran away; MSPL zeroed the latent
  (\(\max|\Lambda|\approx 0\), rel Frob vs true \(G\) = 1 because
  \(\|0-G\|_F/\|G\|_F=1\)). MSPL looked better only as
  anti-runaway; it did not recover the DGP. Call this **different
  pathologies, not a win**.

Do **not** promote, flip a registry row, or cite this as B2
evidence. No C++. No NEWS. No admit change.

## Commands

```sh
cd /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
git fetch origin
git checkout main && git pull --ff-only   # landed at fb6f9dae
# worktree later sat on cursor/mspl-catchup-loop-closeout (clean, has #963);
# smoke used pkgload::load_all of that tree, then this note branched from origin/main
OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla /tmp/mspl-local-binary-pair-smoke.R
```

Machine TSV: `/tmp/mspl-local-binary-pair-smoke.tsv`.
RDS: `/tmp/mspl-local-binary-pair-smoke.rds`.
Script: `/tmp/mspl-local-binary-pair-smoke.R` (not in repo).
