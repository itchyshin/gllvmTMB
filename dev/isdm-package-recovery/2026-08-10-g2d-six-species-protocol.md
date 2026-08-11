# G2d package-native six-species replicated-PA recovery protocol

## Status and boundary

**Status: one local smoke attempted and held; campaign not executed.** G2d is
a fresh, developer-only, synthetic recovery campaign. It does not rerun, pool with,
replace, or reinterpret G2c, including either protected G2c smoke root.  Its
only question is whether increasing the community dimension to six species
improves recovery for the same package-native two-source, relative-intensity
estimand.  Its only terminal verdicts are `G2D_SIX_SPECIES_PASS` and a named
`G2D_SIX_SPECIES_HOLD`.

G2d excludes the survey-count branch/outcomes, a comparator, spatial fields, source admission,
empirical data, public functions or syntax, Issue #953 work, absolute
intensity, and detection modelling.  Repeated PA visits are conditionally
independent observations of the same cell/species ecological state; they do
not introduce a detection parameter.

## Symbolic-to-implementation alignment

| Symbol | Package route | Generating draw | Scored quantity | Frozen truth |
| --- | --- | --- | --- | --- |
| `x_c beta_s` | `.gll_isdm_fit(..., X, ...)` | centred `x` times `beta` | `beta_hat` | six-vector below |
| `b_c gamma_s` | GBIF-only `B` | centred `b` times `gamma` | `gamma_hat` | six-vector below |
| `z_c lambda_s` | `latent(..., d = 1L)` | one `z_c` shared by species | `Lambda Lambda'` | `lambda lambda'` |
| `e_cs` | free diagonal `Psi` companion | independent Normal residual | diagonal variance | `psi^2` |
| `eta_cs` | shared ecological predictor | sum of the four preceding terms | centred relative map | realised `eta` |

For cells `c = 1,...,120`, species `s = 1,...,6`, and visits
`v = 1,2,3`, the fixed law is

\[
z_c \sim N(0,1),\quad e_{cs}\sim N(0,\psi_s^2),\quad
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},
\]

\[
Y^G_{cs}\sim\operatorname{Poisson}\{a^G_c
\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},\qquad
D_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-a^S_c\exp(\eta_{cs})]\}.
\]

The first three species retain G2c's truth.  The appended species have

```
alpha  = (-1.35, -1.60, -1.10)
beta   = (-0.40,  0.55,  0.20)
lambda = ( 0.60, -0.40,  0.50)
psi    = ( 0.32,  0.38,  0.34)
gamma  = (-0.40,  0.30,  0.20)
delta  = (-0.25,  0.20, -0.10)
```

`B` is present only on GBIF rows.  It is structurally `NA` on every PA row.
The fit uses the unchanged private `.gll_isdm_fit(..., d = 1L)` route with a
rank-one ecological field and a free diagonal `Psi` companion.

## Frozen panel and adversarial checks

Ordinary fixtures are `86101:86120`.  The five disconnected and five
weak-overlap attacks use the primitives of ordinary replicates `1:5`; they do
not obtain a new seed block and are not ordinary successes.  Each fixture has
three PA visits, with GBIF rows and PA visit 1 byte-identical between its
one-visit reference and three-visit arm.

The weak-overlap attack has exactly 25 percent support overlap (30 of the 120
GBIF support cells) and `abs(cor(x, b)) >= 0.85`.  These facts are checked
directly from the generated fixture before any fit.  An invalid map is a
retained `G2D_*_HOLD`, never a substituted fixture.

## Eligibility, profile ledgers, and gate

All fixtures use

```
gllvmTMBcontrol(n_init = 3L, init_jitter = 0.25, se = TRUE,
                aghq = FALSE, warn_runaway = TRUE)
```

Eligibility requires exactly three retained restarts, one selected restart, a
finite selected objective, convergence zero, `pdHess`, finite gradient with
maximum absolute value at most `1e-3`, and all six named profile ledgers to
pass.  The profile coordinates are precisely
`theta_diag_B_sp1` through `theta_diag_B_sp6`; these are unit-tier diagonal
log-SD coordinates.  Each ledger evaluates exactly offsets `-2,-1,0,1,2`,
retains every profile optimisation result, requires finite objective values,
and records a named `G2D_PROFILE_THETA_DIAG_B_SP*_PASS` or `..._HOLD` verdict.
Both endpoints must have delta NLL at least 2.  Profiles diagnose fitted
coordinates only; they do not produce public intervals.

An eligible ordinary three-visit fixture passes only when maximum absolute
errors for `beta` and `gamma` are at most `0.30`, minimum relative-map
correlation is at least `0.70`, shared-covariance relative Frobenius error is
at most `0.50`, and diagonal-variance maximum absolute error is at most
`0.20`.  `G2D_SIX_SPECIES_PASS` requires at least 18 of all 20 ordinary
three-visit fixtures to pass, both complete attack panels to degrade, and no
missing or non-finite retained artifact.  All-attempt and all-20 denominators
are mandatory; eligible-only summaries are descriptive only.

## Root, smoke, and launch rules

Every G2d result root is fresh, beneath
`dev/isdm-package-recovery/results/`, has an immutable `G2D` root receipt,
and must not contain `g2c` in its path.  The root receipt freezes the protocol,
decision, runner, package commit, seed map, and platform provenance.  A root
cannot be used after a summary or smoke receipt is written; a retry needs a
new root.  Every fixture retains truth, support, paired-map receipt, both arm
fit objects or errors, all warnings, all restart attempts, all profile grids,
metrics, and hashes before any summary.

Before a replacement smoke, run the no-fit `preflight` mode in a distinct,
fresh root.  It must write and re-read the root receipt and a sentinel RDS,
then retain their hashes in a preflight manifest.  A failed preflight is a
`G2D_PREFLIGHT_HOLD` and consumes no smoke allowance.  Before a future panel,
the no-fit `init` mode creates the campaign root receipt; fixture mode rejects
any root whose receipt is absent or drifts from its command-line commit and
artifact hashes.

The local smoke is ordinary replicate 1 (`86101`).  It may be called a
`G2D_SMOKE_PASS` only after non-empty truth, support, paired-map, root, fit,
restart, profile, metric, and file-manifest receipts all exist and pass their
structural checks.  One fresh local smoke is authorised only after the no-fit
gate passes.  The Totoro launcher remains dormant and exits 64 until a
separate explicit authorisation follows an inspected `G2D_SMOKE_PASS`.

## Claim fence

Even a PASS is evidence only for this fixed, private, six-species, nonspatial,
synthetic package-native DGP.  It does not establish detection estimation,
calibration, survey-count outcomes, spatial source separation, absolute intensity, empirical
validity, public capability, or article readiness.
