# OU plus one static source: mathematical review

Reviewer: Noether. Reader: gllvmTMB method developers and package contributors.
Inspected worktree: `/private/tmp/gllvmTMB-temporal-program`, HEAD
`0b88694345e73396ba9d13886ef6a64684a5976d`. This is a source review;
no fits, tests, compilation, or recovery campaigns were run. Existing test
definitions are evidence of intended checks, not fresh passing results.

OU can compose additively with each of the four existing static source
families. No additional random-effect tier or cross-source parameter is
mathematically required. The inspected dedicated temporal state and parameter
maps support that conclusion. However, this does not establish qualification
of any OU source pair: current admission explicitly refuses every such pair,
and AR1 recovery cannot establish irregular-time OU recovery.

## Model and likelihood map

For observation i with series g_i, numeric time t_i, source label h_i and
trait j_i, define independent temporal and static Gaussian fields. Then

\[
V_{ii'}=1(g_i=g_{i'})e^{-\kappa_T|t_i-t_{i'}|}
 [\Sigma_T]_{j_i j_{i'}}+
 K_S(h_i,h_{i'})[\Sigma_S]_{j_i j_{i'}}+
 1(i=i')\sigma_\epsilon^2.
\]

Ordinary covariance terms can be added only under a separately admitted
contract. The initial recommendation below excludes them. The product
`K_S * K_T * Sigma_ST` describes a different process and is excluded.

Temporal `indep` uses `Sigma_T = diag(exp(2 theta_temporal_diag))`;
`dep` uses the full packed lower-triangular factor `L_T L_T'`;
rank-one `latent(unique = FALSE)` uses `lambda lambda'`.
If a later cell admits `unique = TRUE`, its covariance is
`lambda lambda' + diag(exp(2 theta_temporal_diag))`, with the entire sum
multiplied by the OU correlation. Psi is temporally correlated, not extra
measurement noise. Current source-pair admission excludes that latent-Psi
cell (`R/temporal.R:197-205`).

The current source companions are specifically `kernel_indep`,
`phylo_indep`, `animal_indep`, and `spatial_indep`; there is no blanket
admission of all static trait-covariance modes. Kernel/phylo/animal use their
fixed labelled source covariance with the existing trait-diagonal scales.
Spatial uses `tau_j^-2 P Q(kappa_S)^-1 P'`, with
`Q = kappa_S^4 M0 + 2 kappa_S^2 M1 + M2`; a fixed mesh does not fix its
estimated range or projected marginal scale
(`dev/temporal-program/TEMPORAL-DEP-SPATIAL-CONTRACT.md:13-28`).

For each series and successive distinct times, the existing template takes
`kappa_T = exp(theta_temporal_time)`, `a = exp(-kappa_T Delta)` and
`z_next = a z_previous + sqrt(1-a^2) epsilon`, with stationary unit-variance
initial states and independent standard-normal innovations. Induction gives
`Cov(z_t,z_s) = exp(-kappa_T |t-s|)`. The stable innovation calculation is
already present (`src/gllvmTMB.cpp:1770-1843`). Its Gaussian innovation
density is the generative prior: no extra state-space Jacobian should be
added while innovations remain the integration variables.

`R/fit-multi.R:5551-5576` supplies numeric elapsed gaps and a separate state
map; `:5841-5852` supplies temporal-only parameters; `:6443-6467` maps
unused blocks off. Temporal effects enter the predictor additively
(`src/gllvmTMB.cpp:3102-3111`). Changing AR1 to OU therefore introduces no
observed parameter-slot collision with the existing AR1 static-source
route. The extractor correctly reports `ou_rate = exp(theta)`
(`R/temporal.R:604-611`). This is a structural inspection, not a numerical
proof of the composed OU likelihood.

## Identification and admission

On a regular grid with spacing Delta, OU equals the positive AR1 submodel
at `phi = exp(-kappa_T Delta)`, wherever that phi lies within the native
AR1 cap. Thus the same observation design has the same covariance
identification problem under this parameter substitution. OU removes AR1's
negative-persistence/even-lag sign ambiguity: its admission must not require
integer time or an odd lag. Irregular time changes the actual covariance
design and needs its own evidence.

At `kappa_T -> 0`, time becomes constant within series and can compete
with a static unit/source effect. At `kappa_T -> infinity`, distinct states
become independent, but repeated measurements still share a temporal state;
replication separates its diagonal variance from measurement noise.
These covariance limits have AR1 analogues, but log-rate identification
differs: OU reaches exact independence only at infinity. A nearly flat
rate likelihood must not be reported as accurate rate recovery. Zero
temporal amplitude also makes the rate unidentified. Time-unit rescaling
`t* = c t`, `kappa_T* = kappa_T/c` must leave the model unchanged.

Admit only Gaussian identity-link ML/native Laplace, complete panels with
at least three traits and three distinct finite numeric occasions per
series, at least two measurements per state, one temporal intercept source,
one existing static diagonal source, fixed source `rho = 1`, and fixed,
externally supplied source information. Preserve source labels and state
coordinates. For kernel/phylo/animal, cross-series relatedness and repeated
times provide useful independent contrasts; for spatial, retain spatial
contrasts beyond those determined by lag and assess range jointly with rate.
These are design conditions, not a guarantee from minimum counts alone.

Reject duplicate/proportional *observed covariance* bases and otherwise
exactly unidentified component decompositions. Assess the local covariance
derivatives (including rate, scales and spatial range) jointly; positive
definiteness of total V only establishes a valid likelihood, not component
identification. Retain existing restrictions on extra ordinary terms,
multiple sources, source slopes, estimated attenuation, latent rank/Psi,
non-Gaussian responses and interaction processes until separately tested.

## Minimal first cell and required evidence

Start with replicated `temporal_indep(0 + trait | series, time = elapsed,
replicate = measurement, structure = "ou") +
kernel_indep(series, K = K, name = "fixed_kernel")`, with three traits,
one fixed labelled positive-definite nonidentity kernel, several independent
series, irregular well-spaced times, and no ordinary covariance term.
Choose a moderate rate with both appreciable and decayed correlations over
the observed lag range. This avoids adding estimated spatial range or a
loading factor to the first qualification.

1. Independently build the full observation covariance above and check
   normalized Gaussian NLL plus every active outer derivative at common
   parameters. Exercise irregular gaps and both rate limits. Compare
   positive regular-time AR1 using `phi = exp(-kappa_T Delta)` and account
   for the transform in gradient comparisons.
2. Reject a deliberately substituted product kernel; verify independent
   series, same-state replication, cross-series source covariance, row and
   kernel-label permutations, time-unit rescaling, long/wide rewriting,
   `update()` and extraction. Source matrices and incidence maps in the
   oracle must come from independently checked public inputs.
3. Independently generate the OU and static fields plus measurement noise.
   Compare unconditional simulation mean/covariance with Monte Carlo error
   bounds; verify conditional draws retain the full fitted predictor.
4. Freeze DGP, seeds, optimizer, thresholds and failure policy before
   recovery. Retain every attempt. Assess fixed effects, both variance
   components, residual variance, rate and fitted correlation at observed
   lags. Include moderate rates, near-constant/near-independent controls,
   weak or zero temporal signal and varied time spacing; report boundary
   rate identification separately. Repeat source-specific oracles and
   recovery before extending to phylo, animal, spatial, dep or latent.

Existing reusable anchors are the temporal-only OU dense oracle at
`tests/testthat/test-temporal-sixth-source-oracles.R:214-248`, its finite
extreme-rate check at `:359-373`, and the AR1 kernel additive oracle at
`tests/testthat/test-temporal-program-kernel-replicated.R:36-59,112-130`.
They do not cover their OU-plus-source composition.

## Severity-tagged findings and hard blockers

- **P1 — No composed OU qualification yet.** The explicit rejection at
  `R/temporal.R:524-530` is consistent with the evidence boundary. Removing
  its AR1 condition would expose all currently allowed source/mode pairs,
  not just the first proposed cell. Admission must be scoped to the cell
  whose oracle, simulation and recovery gates pass. No mathematical
  impossibility was found; the blocker is missing composed evidence.
- **P2 — Rate-boundary checks need more than finite gradients.** The
  temporal-only extreme check at
  `tests/testthat/test-temporal-sixth-source-oracles.R:359-373` verifies
  numerical finiteness, not identifiability. Extend qualification with
  correlation/rate profiles or equivalent diagnostics at the two limits.
- **P2 — The spatial refusal text overstates what its heuristic proves.**
  `R/temporal.R:367-384` tests within-series correlation of distance and lag;
  this is not a proof that the *full observed covariance* bases are
  proportional. It ignores cross-series spatial covariance and the SPDE
  covariance shape. Preserve the conservative fence for a first OU cell,
  but describe it as a design exclusion, not a mathematical impossibility.

Forecasting and interval/selection helpers remain separate gates. In
particular, `R/temporal-selection.R:3-5,34` and
`R/temporal-bootstrap.R:25-28,54` retain AR1-only composed contracts;
fitting admission must not imply those helpers support OU source pairs.
