# The relative-collapse fix does NOT explain the campaign's 59/70

**Status: after-task §6a's final paragraph is REFUTED and is corrected here.**
The fix itself is unaffected — it remains a real fix for the Gaussian Heywood
case. What is withdrawn is the claim that it explains a *different* finding.

## The claim under test

`docs/dev-log/after-task/2026-07-27-start-method-res-worse-optimum.md` §6a
closes with:

> This is the same failure mode as the campaign's separate observation that
> Laplace reported `convergence == 0` and `pdHess == TRUE` on 59 of 70 genuinely
> degenerate fits.

The handover made this falsifiable and asked for it to be tested:

> if the relative-collapse fix explains why the Laplace campaign saw
> `convergence == 0` AND `pdHess == TRUE` on 59 of 70 genuinely degenerate fits,
> re-running that grid should flip a large share to flagged. If it does NOT, the
> explanation in after-task §6a is wrong and should be corrected, not quietly
> dropped.

## What was run

The 70 degenerate cells were identified from the original grid
(`dev/totoro-grid/results/grid.csv`, arm `gtmb_laplace`, `rel_frob > 10`) by
`family`/`n`/`p`/`q`/`seed`, and 24 of them — the cheapest by `n*p` — were
re-fitted on this branch with the same DGP (`dev/totoro-grid/run-grid.R:49-58`)
and the same model, then passed to the new detector.

Script: `dev/relative-collapse-vs-59of70.R` · results:
`dev/relative-collapse-vs-59of70.csv`

The original 59/70 figure was first re-confirmed directly from the grid:

| status | count |
|---|---:|
| `conv0_pdHessTRUE` | **59** |
| `conv0_pdHessFALSE` | 8 |
| `conv1_pdHessFALSE` | 3 |
| total degenerate | 70 |

## Result

```
cells re-fitted ok           : 22   (2 of 24 errored on refit)
flagged by the NEW detector  :  0   (0%)
still conv == 0 AND pdHess   : 20
```

**Zero of 22.** Not a small flip rate — none at all.

## Why, structurally

The refutation does not depend on the numbers; they confirm a fact about the
model the grid fits.

1. **The grid's Laplace arm has no `psi`.** `run-grid.R:18` labels the arm
   *"gllvmTMB Laplace, Psi SUPPRESSED via `latent(..., unique=FALSE)`"*, and
   line 118 fits exactly that. There is no unique-variance vector.
2. **Every degenerate cell is bernoulli** — so there is no residual sd either.
3. **The relative check reaches only the sd/variance components.** In
   `.gllvmTMB_boundary_flags()`, `.gllvmTMB_relative_collapse()` is applied to
   the `sd_*` block; the loading check (`near_zero_B_loading`) kept its
   **absolute** `loading_thresh = 1e-3` and was not changed by this arc.

So there is no variance component in these fits for a *relative* collapse test
to act on. The fix could not have flagged them under any threshold.

## What this changes, and what it does not

**Unaffected — the fix stands.** `check_gllvmTMB()` reporting
`near_zero_psi_unit … PASS … 0.0006826` for a component whose variance is
`4.7e-7` against siblings near 1.0 is a genuine blind spot, the sd-vs-variance
square is real, and detecting it relative to siblings is the right remedy. None
of that rested on the 59/70.

**Withdrawn — the generalisation.** The campaign's 59/70 is *not* the same
failure mode, and this fix does not close it.

**Consequence — the campaign's finding is still open.** That matters more than
the correction itself: §6a as written reads as though the silent-degenerate-fit
problem has been diagnosed. It has not. Whatever makes a rank-deficient
low-rank `Lambda_B` fit report `convergence == 0` with a positive-definite
Hessian is a *separate* mechanism, still undiagnosed, and it is the one that
affects the production route on the models users actually fit.

A plausible next hypothesis, explicitly **untested**: with `unique = FALSE` the
only structure is `Lambda_B`, and a degenerate fit there means a
rank-deficient or near-collinear loading matrix rather than a collapsed
variance. The absolute `loading_thresh = 1e-3` on `diag(Lambda_B)` is the same
shape of blind spot the psi threshold had — absolute where it should be
relative, and applied to the Cholesky diagonal rather than to the implied
`Lambda Lambda'` spectrum. Testing that means checking whether the degenerate
cells have a small trailing eigenvalue of `Lambda_B Lambda_B'` relative to the
leading one. That is a bounded experiment on the 22 fits already re-run.

## Scope

24 cells attempted, 22 fitted, all bernoulli, `n` in {40, 100}, `p` in {8, 20},
`q` in {2, 4}, one OS, one BLAS, single fit per cell. The zero flip rate is
strong evidence for these cells; the structural argument above is what makes it
general.
