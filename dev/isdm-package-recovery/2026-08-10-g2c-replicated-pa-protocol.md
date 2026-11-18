# G2c package-native replicated-PA recovery protocol

## Status, identity, and boundary

**Status: approved design; not executed.**  G2c is a new, developer-only,
synthetic recovery campaign on `codex/isdm-g2c-replicated-pa`.  It does not
repair, pool with, replace, or reinterpret the completed one-visit package PA
campaign (`G2_PACKAGE_PA_HOLD`) or the protected standalone G2/G2a evidence.

The sole question is whether **three conditionally independent PA visits at the
same linked survey cells**, under the exact law below, meet the frozen recovery
and identifiability gate through the package-native private route.  An outcome
is either `G2C_REPLICATED_PA_PASS` or a named `G2C_REPLICATED_PA_HOLD`; a PASS
has no force beyond this exact design.

G2c excludes count surveys, a comparator, spatial fields, source admission,
empirical data, public functions or syntax, absolute intensity, detection
models, and article claims.  It retains the nonspatial relative-intensity
estimand with one shared ecological rank-one field and a free diagonal `Psi`.

## Exact generating law and support

For cells \(c=1,\ldots,120\), species \(s=1,2,3\), and visits
\(v=1,2,3\), draw once per cell/species

\[
 z_c \sim N(0,1),\qquad e_{cs}\sim N(0,\psi_s^2),\qquad
 \eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs}.
\]

The frozen truth is

\[
\alpha=(-1.40,-1.20,-1.55),\quad
\beta=(-0.55,0.35,0.70),\quad
\lambda=(0.70,-0.55,0.45),\quad
\psi=(0.35,0.30,0.40),\quad
\gamma=(0.45,-0.35,0.25),
\]

with GBIF contrast \(\delta=(0.30,-0.20,0.15)\).  `x` and the GBIF bias
covariate `b` are deterministic centred grids generated with each fixture's
shared primitives.  Known positive offsets \(a^G_c\) and \(a^S_c\) are held
fixed and supplied on their declared log scale.  GBIF observations are

\[
Y^G_{cs}\sim\operatorname{Poisson}\{a^G_c
\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},
\]

and the three PA observations are conditionally independent given the same
\(\eta_{cs}\):

\[
D_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-a^S_c\exp(\eta_{cs})]\}.
\]

There is no visit-specific ecological, detection, bias, or offset parameter.
The PA support is the same predeclared linked survey-cell set in all three
visits; each supported `(cell, species)` has exactly three PA rows and each
unsupported cell has none.  GBIF support and the first PA visit are shared
between paired arms.  The fit must use the existing private
`.gll_isdm_fit(..., d = 1L)` route: GBIF Poisson/log plus PA
Bernoulli/cloglog with the shared `latent()` ecological field and diagonal
`Psi` companion.  \(\alpha\) and \(\delta\) remain survey-reference and
GBIF-contrast coefficients, not absolute intensity.

## Frozen paired fixture and attack map

Every ordinary replicate has one primitive stream and is evaluated in two
paired data views: `one_visit` retains PA visit 1 only, and `three_visit`
retains all three visits.  The GBIF rows, truth, covariates, offsets, survey
support, first-visit rows, and first-visit uniforms must be byte-identical
within a pair; visits 2 and 3 add only their independently generated PA
uniforms.  The runner must write and verify this paired identity before fitting.

| Panel | Replicates | Seeds | PA support / adversarial change | Required role |
|---|---:|---|---|---|
| Ordinary paired | 20 | `81101:81120` | Fixed linked support; one versus three visits | Main recovery comparison |
| Disconnected paired attack | 5 | paired to ordinary primitives `r = 1:5` | GBIF and PA supports occupy disjoint halves of the `x` grid | Falsification |
| Weak-overlap paired attack | 5 | paired to ordinary primitives `r = 1:5` | 25% shared support; ecological and bias covariates aligned at approximately 0.9 | Falsification |

The attacks retain the same three-visit law.  They are not discarded, replaced,
or counted as ordinary successes.  Each complete attack panel must show a
named degradation relative to the ordinary joint target in every fixture; an
attack fixture that meets the ordinary joint target, missing attack output, or
an attack panel whose generated support differs from its frozen map yields
`G2C_ATTACK_NOT_DEGRADING_HOLD`.

## Eligibility, profiles, and recovery gate

Use the native Laplace control unchanged across all cells:

```
gllvmTMBcontrol(n_init = 3L, init_jitter = 0.25, se = TRUE,
                aghq = FALSE, warn_runaway = TRUE)
```

A fixture is eligible only if it retains exactly three restart rows, records
one selected restart, has a finite objective, `opt$convergence == 0`,
`sd_report$pdHess` is `TRUE`, and has maximum absolute gradient
\(\le 1\mathrm{e}{-3}\).  It must also retain the predeclared fixed
`log_psi` profile ledger at offsets `-2, -1, 0, 1, 2`: the profile request,
finite evaluated grid/deviance values, endpoint status, and a named verdict.
Each endpoint must have delta NLL \(\ge 2\).  A flat, one-sided, non-finite,
unavailable-endpoint, failed, or inadequate-endpoint profile is an
identifiability failure, not an eligible fit.  In the package object the three
ledger coordinates are `theta_diag_B`, which are the unit-tier diagonal
**log-SD** coordinates; `log_psi` is retained here only as the protocol's
generic shorthand.  Profiles diagnose the fitted
coordinates; no interval endpoint is reported as public inference.

All truth, generated support map, paired-identity receipt, fit object, errors,
warnings, restart ledger, profile ledger, metric row, and hashes are retained
before summarisation.  Best-fit-only deletion and denominator substitution are
forbidden.

Calculations are on the generating link scale.  Relative maps compare `eta`
after its cell mean is removed separately for each species.  Raw loadings or
latent-score orientation are never scored.  An eligible ordinary `three_visit`
fixture passes only if all conditions below hold; the paired `one_visit` result
is reported as a retained comparator within G2c, not a substitute denominator.

| Target | Three-visit fixture criterion |
|---|---:|
| Ecological slopes `beta` | maximum absolute error \(\le 0.30\) |
| GBIF-bias slopes `gamma` | maximum absolute error \(\le 0.30\) |
| Relative maps | minimum species correlation \(\ge 0.70\) |
| Shared covariance `Lambda Lambda'` | relative Frobenius error \(\le 0.50\) |
| Diagonal residual variance `Psi` | maximum absolute variance error \(\le 0.20\) |
| Fixed `log_psi` profiles | offsets `-2, -1, 0, 1, 2` finite; both endpoints have delta NLL \(\ge 2\) |

`G2C_REPLICATED_PA_PASS` requires at least 18 of the fixed 20 ordinary
`three_visit` fixtures to be eligible and pass every target, the same all-20
denominator reported without substitution, all paired `one_visit` results
retained, and both attack panels complete and degrading.  Eligible-only
summaries are descriptive only.  Any missing artifact, failed smoke, incomplete
restart/profile ledger, support/seed mismatch, non-finite metric, or incomplete
panel is a named HOLD.

## Smoke, root, and campaign rules

The local smoke is ordinary replicate 1 (`seed = 81101`) in both paired arms.
Before any remote launch it must create non-empty truth/support and paired-map
receipts, fit RDS files, restart and profile ledgers, metric rows, and a root
receipt; a smoke that cannot satisfy all structural checks is retained as a
HOLD and blocks launch.

S0--S4, including the local smoke, are authorised under this decision.  Totoro
S5 is not authorised: only a healthy inspected smoke may support a fresh
approval request for the 30-fixture Totoro campaign.  If later approved, it
uses one core per fixture and at most 30 workers, with
`OPENBLAS_NUM_THREADS=1` and `OMP_NUM_THREADS=1`; compilation/loading happens
once before dispatch.  The campaign has exactly 30 scenario/replicate/seed
rows, as listed above; paired ordinary arms belong to one fixture identity, not
two additional seed rows.

Each result root beneath `dev/isdm-package-recovery/results/` is new and
immutable.  Its manifest records the G2c protocol and runner hashes, package
commit, R/TMB/platform versions, exact seed/attack map, all fixture hashes,
and complete/incomplete status.  Every fixture manifest must agree exactly.
After a root summary is written, no fixture may be added, replaced, or
re-summarised.  A root must never be reused for a retry; retries receive a new
root and retain the failed root.

## Claim fence

A PASS says only that this exact package-native, nonspatial, synthetic,
three-visit PA DGP met its predeclared point-recovery and profile gate.  It
does not establish detection estimation or calibration, count recovery,
two-field spatial separation, absolute intensity, empirical validity, a
comparator result, public package capability, or article readiness.  Any such
work requires a separately approved protocol and a fresh campaign identity.
