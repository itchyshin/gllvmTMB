# CRAN 0.7 v4 confirmation design

Date: 2026-08-08  
Status: **FROZEN PRE-COMPUTE DESIGN — live launch authority is the detached
source-archive binding; zero fits at design freeze**  
Purpose: confirm the ordinary native-Laplace core after the proposed narrow
warm-`nlminb` repair, without reusing or pooling the immutable v3 evidence.

## Decision boundary

V3 remains the pre-repair baseline. The maintainer explicitly authorized the
default optimizer change on 2026-08-08. V4 may be frozen and launched only
after the implementation, focused tests, compiled regression tests, source
review, and independent harness review pass. If the repair changes from the
contract below, this document must receive a new design version before any fit
is launched.

The proposed repair applies only to the native-Laplace `nlminb` route. When the
first fit has code zero, a finite objective, a finite AD-exact gradient, and raw
`max(abs(gradient)) >= 0.01`, a positive-definite Hessian, and no boundary flag,
the engine attempts one additional `nlminb` pass from the reported optimum using
the same objective, gradient, bounds, scale, controls, and parameter order. The
warm candidate is accepted only if it has code zero, finite objective and
gradient, strictly smaller raw maximum gradient, a positive-definite Hessian,
no boundary flag, and objective no worse than

```text
64 * .Machine$double.eps * max(1, abs(objective_before)).
```

Otherwise the original result is retained. The fit records whether the restart
was attempted and accepted, with before/after objective and raw-gradient values.
The absolute `0.01` release-health gate is unchanged. `optim`, failed-code,
boundary, and non-positive-definite fits are not silently promoted.

## Symbolic alignment

| Layer | Frozen v4 statement |
|---|---|
| Target model | The same 18 core, eight silent-failure, and eight robustness cells and DGPs frozen for v2/v3 |
| Estimator | Native Laplace approximation with the package's default `nlminb` optimizer and, only under the trigger above, one fail-closed warm restart |
| Primary rotation-invariant targets | `beta`, `Sigma_shared = Lambda Lambda^T`, `Sigma_total = Sigma_shared + Psi`, correlations, diagonal `Psi`, and NB2 dispersion where applicable |
| Data-to-engine mapping | Long-format binomial cells retain integer Binomial(10, p) successes with `weights = 10`; all registry hashes and DGP assertions remain exact |
| Public interpretation | Cell-specific point-estimation evidence only; no broad interval, VA, AGHQ, EVA, ordinal, or structured-model promotion |

## Campaign identities and seeds

The canonical v2 registries and their scientific cells remain byte-identical.
V4 receives new campaign IDs and disjoint stage-specific seed offsets:

| Stage | Core | Silent-failure | Robustness | Attempts per cell |
|---|---:|---:|---:|---:|
| Smoke | `470800000` | `470810000` | `470820000` | 2 |
| Pilot | `570800000` | `570810000` | `570820000` | 20 |
| Production | `670800000` | `670810000` | `670820000` | 1,600 |

The campaign IDs are `cran07-core-recovery-v4`,
`cran07-silent-failure-v4`, and `cran07-robustness-v4`. Within a stage,

```text
seed = stage_offset + 100000 * cell_number + replicate.
```

Every attempt must retain campaign ID, registry hash, source-archive hash,
cell ID, replicate, seed, terminal status, optimizer/restart history, warnings,
and all primary estimands. Attempt-to-manifest identity is a six-field exact
bijection and failures remain in the denominator.

The source archive is a metadata-controlled regular-file payload rooted at
`gllvmTMB/`. Its canonical binding receipt, exact path/type/mode/size/content-
SHA payload manifest, detached launcher, and SHA ledger are copied beside the
fresh extraction on each host. Embedding this envelope would make the payload
digest self-referential. The builder is fixed to bsdtar 3.5.3 and normalizes
locale, ownership, modes, timestamps, member order, and ustar format.

Only the detached launcher may start a stage. It derives the canonical
envelope itself, verifies the bound archive and exact manifest, rejects every
non-regular or missing/extra member, extracts to a new directory, verifies all
bytes, builds a package tarball, installs into a new isolated R library, and
invokes the runner from that extracted tree. The runner independently rechecks
the live payload and requires the loaded namespace to reside in that isolated
library. A copied receipt under an arbitrary source root therefore cannot
authorize evidence unless that root is byte-identical to the bound payload.

## Why production uses 1,600 attempts

The standardized fixed-effect bias gate is `<= 0.10` for every coefficient.
With 400 unbiased Gaussian replicates, a single coefficient has approximately
a 4.55% chance of crossing that threshold by Monte Carlo error; across roughly
210 coefficient checks, a broad false HOLD is nearly certain. At 1,600
replicates, the corresponding two-sided normal-tail probability is about
`6.3e-5` per component and the 210-component union bound is about 1.3%.
This is a precision correction to the evidence design, not a relaxed gate.

The maximum production commitment is 31 admitted cells x 1,600 = 49,600 fits.
Smoke and pilot add 68 and 680 fits respectively. At the observed v3 Totoro
throughput, use 31 workers with BLAS/OpenMP pinned to one thread and budget
approximately 2.5--3 wall-clock hours. DRAC is the overflow platform if Totoro
is unavailable; neither campaign runs on GitHub Actions.

The three v3-held challenge cells (`rho = 0.98`, `Psi = 0.01`, and
`Psi = 100`) remain pilot-only characterization cells and cannot be promoted
from a favorable pilot. The production target is the same predeclared 31-cell
surface used in v3, subject only to the fail-closed v4 pilot admission rule.

## Admission and production gates

Smoke runs two production-shaped attempts for all 34 cells and must prove
non-empty finite output, exact keys, restart-history invariants, binomial trial
evidence, and one attempt inspected beyond every guard. Pilot runs exactly 20
attempts for all 34 cells. A cell is admitted with at most 3/20 unusable and no
unclassified result. The global detector challenge must retain sensitivity
`>= 0.95` and specificity `>= 0.90`; undefined denominators fail closed.

Production preserves every substantive v3 threshold:

- exactly 1,600 terminal attempts and no unclassified results per admitted cell;
- stationary-usable rate `>= 0.95` and positive-Hessian rate `>= 0.90`;
- standardized fixed-effect bias `<= 0.10` for every frozen coefficient;
- relative Frobenius bias `<= 0.15` for shared and total covariance;
- diagonal-Psi relative bias `<= 0.20`, with the existing absolute near-zero rule;
- absolute correlation bias `<= 0.10`, or `<= 0.15` in the `rho = 0.98` cell;
- catastrophic-but-healthy exact one-sided 95% upper bound `< 0.02`;
- detector sensitivity `>= 0.95` and specificity `>= 0.90` globally;
- each large-sample RMSE no worse than its small-sample RMSE plus one
  preregistered bootstrap standard error.

Every applicable component requires exactly 1,600 finite contributions with
replicates `1:1600`; missing or unexpected components fail closed. Structural
off-diagonal Psi zeros are asserted exact and classified non-applicable. The
existing rank-one correlation numerical-zero rule remains limited to errors
`<= 64 * .Machine$double.eps`.

## NB2 dispersion repair to the evidence ledger

The NB2 DGP uses trait-specific `phi_t = 5`. V4 records
`fit$report$phi_nbinom2`, aligned exactly to the three frozen trait names. Every
NB2 attempt requires three named, finite, positive dispersion estimates. The
per-trait relative absolute bias gate is `<= 0.20`, and dispersion participates
in the NB2 `n = 100` to `n = 300` RMSE comparison. A nonfinite estimate or a
truth ratio outside `[0.1, 10]` is catastrophic. This closes the missing primary
estimand that forced NB2 to HOLD in v3; it does not change the fitted model.

## Fences and adjudication

Gaussian latent `n = 60` and NB2 latent `n = 100` remain characterization cells
and remain publicly fenced even if a replicate-level gate happens to pass. Their
v3 failures were genuine boundary or weak-identification behavior, not the
binomial stopping artifact. Failed cells are never averaged into a family
verdict. A broad family-pair PASS requires both frozen sample-size cells, all
required robustness cells, all component gates, and the RMSE gate.

V4 may promote only the cells that pass independently. It may not promote
interval calibration, raw loading orientation, VA/AGHQ/EVA, ordinal models,
mixed-family models, or structured latent models. Any failed v4 cell is repaired
under a new campaign ID or removed from the dependable public surface.

## Required pre-compute verification

1. Pure acceptance/rejection tests for every warm-restart branch.
2. Deterministic binomial seed `372000004` with objective, gradient, parameter,
   report, and `sdreport` consistency checks.
3. Gaussian seed `371300010` remains an honest Psi-boundary case.
4. NB2 seed `371700001` is not silently promoted.
5. Existing ordinary, family, loading-unpack, sentinel, and compiled-engine
   regression suites pass.
6. The v4 runner, manifests, schema, gates, and adversarial tests are hash-frozen.
7. A local two-attempt smoke passes before Totoro/DRAC access.

Only then may the 680-attempt pilot launch. Production launches only after the
pilot receipt authorizes an explicit nonempty cell subset and records projected
runtime. Production results remain local; only compact manifests, summaries,
hashes, and adjudication receipts enter the repository.
