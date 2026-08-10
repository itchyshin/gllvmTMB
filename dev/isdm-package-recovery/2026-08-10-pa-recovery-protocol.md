# Package-native two-source iSDM PA recovery protocol

## Status and scope

This is the frozen, developer-only PA recovery protocol released by the
maintainer on 2026-08-10.  It tests the private package route on branch
`codex/isdm-package-core`; it is not a retry, reinterpretation, or replacement
of the protected standalone `dev/isdm-g2` / G2a evidence.  The latter remains
HOLD evidence on its own branch.

The only authorised outcome is `G2_PACKAGE_PA_PASS` or a named
`G2_PACKAGE_PA_HOLD`.  Either outcome is nonspatial, synthetic-only, relative
intensity evidence.  It does not admit count surveys, a comparator, spatial
fields, source data, empirical fits, public syntax, absolute intensity, or an
article claim.

## Estimand and DGP

For cells \(c=1,\ldots,120\) and species \(s=1,2,3\), draw one ecological
rank-one score and a trait-specific residual score,

\[
 z_c \sim N(0,1),\qquad e_{cs}\sim N(0,\psi_s^2),\qquad
 \eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs}.
\]

The fixed truth is

\[
 \alpha=(-1.40,-1.20,-1.55),\quad
 \beta=(-0.55,0.35,0.70),\quad
 \lambda=(0.70,-0.55,0.45),\quad
 \psi=(0.35,0.30,0.40),\quad
 \gamma=(0.45,-0.35,0.25).
\]

`x` and the GBIF bias covariate `b` are deterministic centred grids, with
support varying by cell.  They are generated once per replicate together with
the scores and then used identically by both source arms.  GBIF rows follow

\[
 Y^G_{cs}\sim\operatorname{Poisson}\{a^G_c
 \exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},\qquad
 \delta=(0.30,-0.20,0.15),
\]

and one PA event per cell follows

\[
 D_{cs}\sim\operatorname{Bernoulli}\{1-\exp[-a^S_c\exp(\eta_{cs})]\}.
\]

`a^G` and `a^S` are known positive offsets.  The survey scale is the
reference scale: \(\alpha\) and \(\delta\) are reported only as identifiable
survey-reference and GBIF-contrast coefficients, never as absolute intensity.
The fitted formula is the existing private `.gll_isdm_fit(..., d = 1L)` route.
It is therefore exactly GBIF Poisson/log plus survey Bernoulli/cloglog with a
shared cell-level `latent()` field and diagonal \(\Psi\).

## Cells and seeds

The ordinary campaign contains 20 independent fixtures with seeds
`71001:71020`.  Two attack panels contain five fixtures each, using seeds
`72001:72005` (disconnected support) and `73001:73005` (weak overlap).

The disconnected attack puts GBIF and survey `x` values in disjoint halves of
the centred covariate grid.  Its expected verdict is an explicit diagnostic
failure or materially degraded recovery; it is never counted as an ordinary
success.  The weak-overlap attack retains only 25% shared support and uses
aligned ecological and bias covariates (correlation approximately 0.9).  Its
expected verdict is retained degradation or warning, not ordinary success.

## Fitting and retention

Every fixture uses the same native Laplace control:

```
gllvmTMBcontrol(n_init = 3L, init_jitter = 0.25, se = TRUE,
                aghq = FALSE, warn_runaway = TRUE)
```

The `n_init = 3` restart history recorded by `gllvmTMB()` is retained with the
fixture.  A fixture is eligible only when exactly three restart rows are
present, one selected restart is recorded, the selected fit has finite
objective, `opt$convergence == 0`, and `sd_report$pdHess` is `TRUE`.
All fixtures, errors, warnings, restart rows, truth, fits, metrics, and hashes
are saved before root summarisation.  No best-fit-only deletion or denominator
substitution is permitted.

## Predeclared recovery metrics and pass rule

All calculations are on the generating link scale.  Relative maps compare
`eta` after subtracting its cell mean separately for each species; factor
orientation is never scored.  Let an eligible ordinary fixture pass only when
all of the following hold:

| Target | Fixture criterion |
|---|---:|
| Ecological slopes `beta` | maximum absolute error \(\le 0.30\) |
| GBIF-bias slopes `gamma` | maximum absolute error \(\le 0.30\) |
| Relative maps | minimum species correlation \(\ge 0.70\) |
| Shared covariance `Lambda Lambda'` | relative Frobenius error \(\le 0.50\) |
| Diagonal residual variance `Psi` | maximum absolute variance error \(\le 0.20\) |

The campaign passes only if at least 18 of all 20 ordinary fixtures are
eligible **and** pass every target.  Its summary also reports every metric over
the fixed all-20 denominator and separately over eligible fixtures; the latter
is descriptive, never a replacement denominator.  Each attack receives a
separate retained verdict.  A missing artifact, failed fixture, incomplete
restart ledger, failed smoke, or incomplete attack panel produces a named
HOLD.

## Execution and provenance

The local smoke is one ordinary fixture (`seed = 71001`) and must write a
non-empty truth manifest, fit RDS, restart ledger, metric row, and receipt.
Only after inspection can the 30-fixture campaign run on Totoro with one core
per fixture and no more than 30 simultaneous workers.  Compilation/loading is
done before dispatch; workers use `OPENBLAS_NUM_THREADS=1` and
`OMP_NUM_THREADS=1`.

The result root is immutable below
`dev/isdm-package-recovery/results/`.  A root records this protocol hash, the
runner hash, package commit, R/TMB/platform versions, seed grid, all file
hashes, and its complete/incomplete status.  Re-summarisation is read-only;
rerunning a completed fixture is rejected.

## Claim fence

A PASS means only that this exact package-native, nonspatial PA DGP met its
predeclared point-recovery gate.  It does not establish count recovery,
two-field spatial separation, detection calibration, absolute intensity,
empirical validity, or article readiness.  A separately approved count gate
is required before comparator work; a separately approved two-field design is
required before spatial or empirical work.
