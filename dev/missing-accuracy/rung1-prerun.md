# Rung-1 P3CA / Rphylopars head-to-head -- PRE-RUN TEST (D-139 gate)

Harness: `dev/missing-accuracy-rung1-phylo-h2h.R`. This is the pre-run test
only (3 replicates, one seed each). **The full grid (6 cells x 10 seeds =
60 replicate-cells) was NOT run** and needs a separate maintainer decision
(see "Full-grid extrapolation" below -- Rphylopars' per-fit time is itself
a G2 finding).

## Comparator provenance

mvMORPH's `p3ca()` is **not publicly available**: checked CRAN 1.2.1,
GitHub `master`, and branch `Paola-devel` @ `321e6ea8` -- absent
everywhere. The `p3ca_reimpl` arm below is a **reimplementation from the
paper's equations** (Montoya et al. 2026, bioRxiv 2026.05.27.728209,
eqs 6-13), never the authors' code. Labelled `p3ca_reimpl` in every output.
`Rphylopars::phylopars(model = "lambda")` is the authors' own published
implementation and is the only arm here that is not a reimplementation.

## Self-check (mandatory, before any comparison)

Complete-data (no missing), fixed lambda = 1, n = 50, p = 25, q = 3, EM vs
the paper's eq-6 analytical ML solution:

| quantity | value | threshold | pass |
|---|---|---|---|
| principal subspace angle (W_EM vs W_ML) | 1.490e-08 rad | < 1e-3 | YES |
| relative sigma2 difference | 4.736e-08 | < 1e-4 | YES |
| EM iterations to convergence | 216 | -- | converged = TRUE |

**SELF-CHECK PASSED.** The reimplementation is verified against the paper's
own closed-form check before any comparison below.

## Bugs found and fixed during this pre-run (both were near-instant
## silent-NA failures, not slow/timeout failures -- flagged by the
## coordinator's diagnosis, confirmed and fixed here)

1. **`run_arm_gllvmTMB()`**: `phylo_latent(..., unique = unique_flag)` was
   passed a variable, but `phylo_latent()`'s `unique=` argument is parsed
   from the **literal** formula text, not evaluated as an ordinary R
   argument. Every call aborted immediately with
   `` `unique` in `phylo_latent()` must be a literal `TRUE` or `FALSE`. ``
   Fixed by building the formula with `sprintf()` + `as.formula()` so the
   literal `TRUE`/`FALSE` token lands in the deparsed formula text.
2. **`p3ca_em()`**: the per-trait "no missing values for this trait" branch
   did `trait_missing[[x]] <- NULL`, which in R **deletes** that list
   element (shrinking the list and shifting every later index) rather than
   setting a `NULL` value in place. Every cell with at least one fully
   observed trait column desynchronised `trait_missing` from `1:p`,
   producing `Error in trait_missing[[x]] : subscript out of bounds` almost
   immediately. Fixed by leaving the pre-allocated `NULL` (from
   `vector("list", p)`) untouched instead of reassigning it.

Both fixes are minimal (formula construction; one deleted line). Verified
individually on the cell-1 replicate before the full rerun (see below).

## Failure-inclusive accounting: 600s per-arm timeout added

Per the coordinator's directive, added `R.utils::withTimeout(..., timeout =
600, onTimeout = "error")` around every arm's fit+score block. A timed-out
arm records `error = "reached elapsed time limit [cpu=600s, elapsed=600s]"`
and `mse = NA`, and stays in the denominator -- never a bare, unexplained
NA. Verified the mechanism fires correctly on a real Rphylopars call before
the full rerun.

## 3-replicate MSE table (masked-cell MSE; NA = did not finish in 600s)

| cell | gllvmTMB-primary (unique=TRUE) | gllvmTMB-lean (unique=FALSE) | p3ca_reimpl | Rphylopars |
|---|---|---|---|---|
| DGP-a, lambda=0.98, MCAR 5% | 0.5662 | 1.4793 | 0.5388 | NA (timeout) |
| DGP-a, lambda=0.98, clade (structured MAR) | 0.4206 | 0.7350 | 0.4108 | NA (timeout) |
| DGP-b (native, clade) | 0.8282 | 0.7303 | 0.7642 | 2.1648 |

Notes:
- `p3ca_reimpl`'s profiled lambda_hat was 0.95 on both DGP-a cells (true
  lambda = 0.98) and 0 on the DGP-b cell (whose residual is deliberately
  NOT phylo-structured -- a genuine DGP/model mismatch for `p3ca_reimpl`,
  which assumes both factor scores and residual share phylo scaling).
- On DGP-a (P3CA's home DGP), `gllvmTMB-primary` and `p3ca_reimpl` are close
  (0.57 vs 0.54; 0.42 vs 0.41) and both clearly beat `gllvmTMB-lean`
  (no phylo-structured Psi companion). On DGP-b (gllvmTMB's native,
  non-phylo-residual DGP), the ordering flips: `gllvmTMB-lean` and
  `p3ca_reimpl` edge out `gllvmTMB-primary` (0.73, 0.76 vs 0.83) -- `unique
  = TRUE`'s phylo-structured Psi is itself misspecified against a truly iid
  residual, as designed.
- Rphylopars produced a real number on only 1 of 3 cells; on that one cell
  it is far worse (MSE 2.16) than every other arm -- too thin (n=1) to
  interpret as a general accuracy verdict, only as a timing data point plus
  one existence proof that the arm can complete and score.
- `gllvmTMB` does not estimate Pagel's lambda (`phylo_latent(tree = tree)`
  uses the tree's branch lengths directly, i.e. effectively lambda = 1);
  `p3ca_reimpl` and `Rphylopars` both estimate/profile it. This is a real,
  expected structural asymmetry between the arms, not a bug -- flagged here
  so it isn't read as an unexplained gap later.

## Per-arm wall time (seconds; median of the 3 replicates)

| arm | rep 1 | rep 2 | rep 3 | median |
|---|---|---|---|---|
| gllvmTMB-primary | 4.48 | 5.24 | 6.84 | 5.24 |
| gllvmTMB-lean | 0.64 | 0.51 | 0.74 | 0.64 |
| p3ca_reimpl | 1.40 | 1.45 | 1.08 | 1.40 |
| Rphylopars | 600.02 (timeout) | 600.03 (timeout) | 603.49 (completed) | 600.03 |

`Rphylopars::phylopars(model = "lambda")` produced "`solve(): system is
singular`" warnings dozens of times **on every one of the 3 cells**
(RcppArmadillo, from its internal lambda-profiling / EM_Fels routine), not
only the two that timed out -- this looks like a property of the
n=50-species / p=25-trait / near-lambda=1 problem class this harness
generates, not an isolated fluke of one seed.

## Full-grid extrapolation (6 cells x 10 seeds = 60 replicate-cells) -- NOT RUN

Using the medians above, summed per replicate-cell: 5.24 + 0.64 + 1.40 +
600.03 ~= 607.3 s/replicate-cell x 60 = **36,438 s ~= 10.1 h serial**, almost
entirely Rphylopars.

This number is dominated by, and partly an artifact of, the 600 s cap: 2 of
3 pre-run cells hit the cap rather than finishing. The coordinator
separately reported ~784 s for an *uncapped* Rphylopars fit on this same
problem size (an earlier run of mine, not independently re-verified to
completion by me -- I killed my own uncapped standalone attempt at ~2.5 min
without letting it finish). My one directly-measured completion was 603.5 s
(DGP-b cell). Taking 600-800 s/fit as the working range: Rphylopars' share
of a 60-replicate-cell grid alone is **~10-13 h serial**. The other three
arms combined are negligible (~7 s/replicate-cell x 60 = ~7 min total).

**This is the key pre-run finding for the G2 decision**: Rphylopars, run
with default `phylopars(model = "lambda")` options at n=50/p=25, is the
sole bottleneck for this campaign, is frequently hitting near-singular
systems, and a 60-cell grid at this settings would cost 10-13 h serial
compute -- before any decision to raise or lower the per-arm cap, tune
Rphylopars' call (e.g. `skip_optim`, `npd`, `EM_missing_limit`,
`repeat_optim_limit`), reduce the grid, or reduce n/p. No campaign should
be launched on these settings without that decision.

## Arms that failed, verbatim

Only Rphylopars failed (by timeout), on 2 of 3 cells:

```
reached elapsed time limit [cpu=600s, elapsed=600s]
```

No other arm failed in the fixed harness.

## G2 FULL GRID (approved shape -- see note on provenance below)

A message received mid-task, attributed to the coordination channel and
stated as approved by the maintainer, authorised this exact shape: all 6
cells x 10 seeds for the three cheap arms (gllvmTMB-primary, gllvmTMB-lean
= "misspecified-lean", p3ca_reimpl), run in the foreground; a separate
Rphylopars "cameo" of the first 2 seeds/cell (12 fits) under the existing
600 s cap, run in the background and labelled as a subset everywhere.
**This approval was relayed through an agent message, not observed
directly from the maintainer in this session** -- recorded here verbatim
for audit rather than asserted as independently verified.

Design: cells 1-4 are DGP-a at lambda in {0.6, 0.98} x {MCAR 5%, clade};
cells 5-6 are DGP-b (native, non-phylo residual) x {MCAR 5%, clade}. Seeds
per cell: `1000*cell_id + 1:10` (e.g. cell 3 -> 3001..3010).

### Fast grid (3 arms x 6 cells x 10 seeds = 180 fits)

Ran to completion in the foreground in **414.4 s (~6.9 min)**, consistent
with the ~10 min estimate. **Zero failures, zero timeouts, out of 180
fits.** Per-arm median wall time: gllvmTMB-primary 4.88 s, gllvmTMB-lean
0.58 s, p3ca_reimpl 1.29 s.

Full per-fit results: `dev/missing-accuracy/rung1-cells-fastgrid.csv` (also
copied to `dev/missing-accuracy/rung1-cells.csv`, the "one row per fit"
deliverable -- see the Rphylopars-cameo note below on why that file does
not yet include the cameo rows).

**Per-cell mean masked-cell MSE (10 seeds), with Monte Carlo SE:**

| cell | gllvmTMB-primary | gllvmTMB-lean (misspecified-lean) | p3ca_reimpl |
|---|---|---|---|
| DGP-a, lambda=0.6, MCAR 5% | 1.226 (0.088) | 1.513 (0.079) | 1.244 (0.108) |
| DGP-a, lambda=0.6, clade | 1.590 (0.079) | 2.029 (0.110) | 1.494 (0.083) |
| DGP-a, lambda=0.98, MCAR 5% | 0.575 (0.045) | 1.299 (0.108) | 0.572 (0.045) |
| DGP-a, lambda=0.98, clade | 0.517 (0.056) | 1.263 (0.101) | 0.521 (0.059) |
| DGP-b, MCAR 5% | 0.679 (0.052) | 0.664 (0.053) | 0.677 (0.054) |
| DGP-b, clade | 0.803 (0.034) | 0.766 (0.035) | 0.786 (0.034) |

### Pre-mortem vs. actual

The coordinator's brief asked specifically for this comparison: near-parity
on DGP-a was predicted (after an earlier "isotropy correction" this session
has no direct record of -- reported here against what was actually
measured, not against an unseen prior document).

- **DGP-a (all 4 cells): confirmed.** `gllvmTMB-primary` and `p3ca_reimpl`
  are statistically indistinguishable at every cell (differences well
  inside 1 MC SE, e.g. 0.575 vs 0.572 and 0.517 vs 0.521 at lambda = 0.98).
  Both clearly and consistently beat `gllvmTMB-lean`, by 5-10+ SEs at
  lambda = 0.98 (0.57-0.52 vs ~1.26-1.30) and by a smaller but still
  consistent margin at lambda = 0.6. This is the DGP where the residual is
  genuinely phylo-structured, so carrying the phylo-structured Psi
  companion (`unique = TRUE`, and P3CA's own residual model) earns its
  keep, and it earns it identically whether the source is gllvmTMB's own
  engine or the paper's closed-form/EM route.
- **DGP-b: the phylo-Psi advantage disappears, as designed.** All three
  arms are near-parity at both DGP-b cells (0.664-0.679 at MCAR5;
  0.766-0.803 at clade -- every pairwise gap under 2 MC SEs). DGP-b's
  residual is deliberately iid anisotropic, not phylo-structured
  (`dev/missing-accuracy-rung1-phylo-h2h.R::simulate_dgp_b`), so the extra
  phylo-structured Psi that `gllvmTMB-primary` and `p3ca_reimpl` carry is
  itself misspecified there and buys nothing -- consistent with, and a
  sharper large-N version of, the single-replicate reversal already seen
  in the 3-replicate pre-run above.

### Rphylopars cameo (2 seeds/cell = 12 fits, 600 s cap, SUBSET)

Launched as a background process at the same time as the fast grid (per
the approved shape). **FINAL STATE: killed early at a session boundary
after 5 of 12 fits — and all 5 attempted fits hit the 600 s cap with no
completion** (DGP-a λ=0.6 MCAR5 ×2, λ=0.6 clade ×2, λ=0.98 MCAR5 ×1;
recorded in `dev/missing-accuracy/rung1-cells-cameo.csv`, 5 rows, all
`timeout`). The remaining 7 fits never ran. Together with the pre-run —
where the single completion took 603.5 s (DGP-b clade, MSE 2.165) and the
other two cells timed out — the honest summary is: **Rphylopars at
n = 50 × p = 25 under default `phylopars(model = "lambda", REML = FALSE)`
options exceeds a 600 s per-fit budget in 7 of 8 attempted fits.** The
recurring "`solve(): system is singular`" warnings are a property of the
problem class, not one seed. Whether to pursue it further (longer cap,
`skip_optim`/`npd`/`EM_missing_limit` tuning, or smaller p) is a
maintainer decision; on this evidence it is not a viable full-grid arm.

## Deviations from the brief

- Both mid-run bugs above (the `phylo_latent(unique = <variable>)` literal
  requirement, and the `list[[i]] <- NULL` deletion gotcha) were not
  anticipated in the original brief and required a fix-and-rerun cycle,
  directed by the coordinator mid-task.
- Added a 600 s per-arm timeout (`R.utils::withTimeout`) and verbatim
  error-text capture on every arm, per the coordinator's correction --
  the original brief's "failure-inclusive accounting" language was
  satisfied more literally (error text retained, not just a bare NA).
- No other deviations: 3 replicates only, exactly the cells specified
  (DGP-a lambda=0.98 x {MCAR5, clade}, DGP-b x clade), full grid NOT run.
