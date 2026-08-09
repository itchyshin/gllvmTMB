# Phase C prospective analysis supplement — 2026-08-08

**Status:** prospective instrumentation, written before inspecting any official campaign
scientific outcome. This supplement has not read, opened, summarized, or plotted a corrected
pilot, campaign, C-lite, smoke, preflight, or old-pilot result.

## Purpose and boundary

`dev/isdm-phase-c-analysis-supplement.R` materializes prediction evidence that was already
registered in `dev/isdm-phase-c-design.md`: P-primary, P-dose, P-structure, P-integration,
P-separation, and P-rank. It adds no scientific endpoint, threshold, equivalence margin, model,
or adaptive decision.

The supplement is downstream of the official analysis only. It accepts one directory containing
the fixed official outputs and opens only these basenames:

- `01-primary-endpoint.csv`
- `02-paired-headline-summary.csv`
- `03-c1-c2-verdicts.csv`
- `04-c3-a5-a6-summary.csv`
- `06-g2-g6-ladder-vs-ref.csv`
- `09-fit-status-by-cell.csv`
- `10-paired-fit-level.rds`
- `11-input-manifest.csv`
- `12-refutation-aggregate.csv`

It never follows the raw paths recorded inside the manifest. Paths or manifests marked C-lite,
old, smoke, or preflight are rejected. The manifest must contain exactly corrected `pilot_v2/G1`
and `campaign/G1` through `campaign/G6`. Fit-level paired rows must be campaign rows with unique
canonical keys, `phi_x = 0.15`, labeled estimands, and no G5/A2 leakage into the total-Sigma
headline set.

All supplement outputs go to a separately supplied external directory. Existing target files are
never overwritten. A content receipt records the size and SHA-256 of every consumed official-analysis
artifact, and the official input manifest is copied unchanged for provenance.
The official R1-R5 aggregate is also copied unchanged as
`09-refutation-aggregate-copy.csv`, keeping the five refutation verdicts and the overall
`H_sink` verdict explicit beside the prediction ledger rather than inferring them from figures.

## Frozen rules versus diagnostics

The claim ledger uses four distinct labels:

- `FROZEN_PASS_FAIL`: the preregistration supplied an explicit pass/fail rule, such as `>= 3 MCSE`
  or C1. The supplement evaluates it literally.
- `FROZEN_DIRECTION_AND_REPORTABILITY`: the scientific magnitude criterion is directional because
  no separate effect-size margin was frozen, but support is reportable only when the estimated
  difference also clears the frozen 3-MCSE rule (or a requested regression slope clears 3 SE).
- `FROZEN_DIAGNOSTIC_NOT_EQUIVALENCE` or `DESCRIPTIVE_UNRESOLVED`: being within 3 MCSE of zero is not
  an equivalence test, and “diagonal metrics rise sharply” has no frozen numerical boundary. These
  conditions remain visibly unresolved rather than receiving an invented pass.

Every reportability comparison is strict about its inputs: the estimate and its SE or MCSE must
both be finite and strictly positive before `estimate >= 3 * uncertainty` can be true. In
particular, zero divided by zero is never reportable support.

The evidence calculations are:

1. **P-primary:** copy the official primary-endpoint receipt; do not recompute it.
2. **P-dose:** for A1 and A3, retain seeds complete over the full kappa ladder; report per-seed OLS
   slopes, per-seed Spearman correlations, and the kappa coefficient and SE from
   `dD_bias ~ kappa + factor(seed)`.
3. **P-structure:** form same-seed, same-configuration contrasts for omega `1 - 0.5` and
   `0.5 - 0`; report omega-zero `ddiag_rmse` and `dpsi_rmse` descriptively.
4. **P-integration:** form the same-seed A1 minus A5 `dD_bias` contrast and copy the official A5 C1
   state at kappa 2.
5. **P-separation:** tabulate `dbeta_bias` over rho and kappa; at rho 0, label the within-3-MCSE
   result as a zero diagnostic, not equivalence; at rho 0.6, report a seed-fixed kappa slope.
6. **P-rank:** form the same-seed G6 `phi_bias = 0.4` minus `phi_bias = 0` contrast. Direction remains
   the scientific magnitude criterion, while support is labeled reportable only at `>= 3 MCSE`.

For each dose or separation trend, the kappa point estimate is the ordinary least-squares
coefficient from `y ~ kappa + factor(seed)`, but its uncertainty is a one-way seed-cluster-robust
CR1 sandwich SE. With model matrix `X`, OLS residual vector `u`, `G` seed clusters, `N` rows, and
`K` fitted coefficients, define the cluster score `s_g = X_g' u_g`. The covariance is

`V_CR1 = [G/(G-1)] [(N-1)/(N-K)] (X'X)^(-1) [sum_g s_g s_g'] (X'X)^(-1)`.

The reported SE is the square root of the kappa diagonal of `V_CR1`. The calculation fails closed
unless `G > 1`, `N > K`, the model matrix is full rank, and the variance is finite and nonnegative.
Before a per-seed Spearman correlation is calculated, both kappa and the outcome must vary within
that seed. Invariant inputs receive status `UNDEFINED_ZERO_VARIANCE`, contribute to the explicit
undefined count, and are never treated as positive correlations.

Every numerical table retains all-completed and both-`pdHess` summaries where the underlying
official paired rows permit them. The dose and separation trend tables likewise report the
seed-fixed slope, regression SE, complete-seed count, and per-seed Spearman summaries for both
populations. Each table flags an all-completed versus both-`pdHess` difference larger than one
all-completed MCSE (or one all-completed regression SE for a slope). Neither convergence flags,
Hessian flags, nor Heywood outcomes are used to discard a completed fit.

## Figures and audience

The PDF and PNG figures are internal evidence figures, not publication claims:

- paired `dD_bias` curves over kappa;
- beta-separation curves over kappa and rho;
- G2–G6 ladder contrasts, including the G6 rank channel.

They carry MCSE where available and remain inside the supplied external output directory. Nothing
is written to README, NEWS, pkgdown, the validation-debt register, or any public surface.

## Validation contract

`--self-test` constructs a wholly synthetic official-output bundle under `/private/tmp`, runs the
complete supplement, and requires every CSV, PDF, PNG, receipt, and copied manifest to exist and be
non-empty. It independently reconstructs the CR1 matrix as a manual oracle, checks that zero/zero
cannot be reportable, forces an invariant-outcome Spearman case, and checks that rank and dose
evidence agree with their ledger verdicts. It uses no package fit and no scientific result.
Synthetic artifacts are retained under
the printed `/private/tmp` directory so the test does not silently delete evidence.
