# Capability-First Two-Hour Packet

**Date:** 2026-06-24
**Branch:** `codex/capability-first-audit-20260624`
**Start path:** `/private/tmp/gllvmtmb-capability-baseline-20260624`
**Base commit:** `7c675dd33d58f4dfd633cacfbf05e62c0e168d61`

## Scope

This packet implements the agreed two-hour planning block after PR #552:
audit the current power-pilot/DRAC state, identify the next safest slices,
prepare DRAC CPU commands without submitting them, and triage speed notes into
benchmark-first spikes.

No R source code, TMB code, validation-debt rows, public examples, roxygen, Rd,
vignettes, pkgdown navigation, or NEWS entries move in this slice.

## Live Gate Snapshot

| Gate | Current status |
|---|---|
| gllvmTMB PRs | none open |
| gllvmTMB main | `7c675dd33d58f4dfd633cacfbf05e62c0e168d61` |
| PR #552 | merged, manifest-only fir smoke infrastructure |
| post-merge R-CMD-check | success, run `28111548411` |
| post-merge pkgdown | success, run `28111605400` |
| scheduled Power pilot sweep | run `28106026686` still in progress at audit time |
| full-check run `28088698708` | cancelled; do not claim 3-OS full-check from it |
| GLLVM.jl #113 | draft, clean, now titled/scoped as fixed-nu native Student-t only |

## ADEMP Skeleton For The Core CPU Study

This follows Morris, White & Crowther (2019) ADEMP and the Williams et al.
(2024) simulation-reporting checklist. It is an audit skeleton, not a frozen
new design.

### A -- Aims

Primary aim: estimate coverage, bias/RMSE, power-like zero-exclusion
diagnostics, and failure rates for the Design 66 core GLLVM capability grid on
CPU nodes, with Monte Carlo standard errors reported for every aggregate.

Secondary aims:

- separate diagnostic pilot evidence from validation-row promotion evidence;
- decide whether ordinal-probit cells can enter the confirmatory coverage grid;
- replace the current binomial logit harness with true binomial-probit evidence
  before any probit claim is promoted;
- measure runtime/failure cost before scaling beyond tiny SLURM smokes.

### D -- Data-Generating Mechanism

Current bounded pilot grid:

| Factor | Current levels | Current caveat |
|---|---|---|
| family label | gaussian, nbinom2, binomial_probit, ordinal_probit | `binomial_probit` cell IDs currently use the logit harness, labelled by `evidence_family = "binomial_logit_harness"` |
| latent rank | d = 1, 2 | ok for pilot |
| n_units | 50, 150 | ok for pilot |
| signal | 0.0, 0.2, 0.5 | signal zero is a positive `Sigma_unit_diag` coverage diagnostic, not Type-I error |
| bootstrap | pilot default `N_BOOT = 25`; smoke `N_BOOT = 0` or `2` | smoke results are plumbing evidence only |

The current pilot implementation already records the key reproducibility
fields: `campaign_id`, `source_sha`, workflow IDs, shard, `chunk_id`,
`cell_id`, replicate windows, seed ranges, output paths, `n_boot`, and
evidence-family/link metadata.

### E -- Estimands / Targets

Primary validation target remains `Sigma_unit_diag` with bootstrap intervals.
The zero-exclusion rate is retained only as a diagnostic until a structure-
present decision rule is specified. Raw loadings and raw `psi` remain diagnostic
only.

Current unresolved targets:

- true binomial-probit target: not implemented in the M3 pilot harness;
- ordinal-probit primary coverage rows: still absent/unclear for promotion;
- Type-I/null calibration: needs a pre-specified structure-present null, not
  the current positive-variance `Sigma_unit_diag` signal-zero row.

### M -- Methods

Current method path:

- R/TMB `gllvmTMB` fits through `dev/m3-grid.R`;
- immutable chunk path through `dev/m3-pilot-launch.R` and
  `dev/power-pilot-run.R`;
- SLURM wrapper through `dev/power-pilot-slurm-smoke.sh`;
- CPU-only DRAC path, no GPU lane.

Next method gate is not the `n_sim = 2000` campaign. It is the tiny scheduled
fit smoke ladder:

1. manifest-only already passed on fir;
2. `SLURM_STAGE=all N_SIM_STEP=1 N_BOOT=0`;
3. inspect manifest, chunk files, aggregate files, report issue line, and no
   shared-index mutation;
4. only then repeat with `N_BOOT=2`.

### P -- Performance Measures

Every aggregate should carry both numerator/denominator and MCSE:

| Measure | Current status | MCSE rule |
|---|---|---|
| coverage_primary | implemented for eligible primary rows | `sqrt(p * (1 - p) / n_sim)` with `coverage_eligible_n` reported separately |
| zero_exclusion_rate | implemented as diagnostic | `sqrt(p * (1 - p) / zero_exclusion_n)` |
| fit_failure_rate | implemented | binomial MCSE over attempted fits |
| nonpd_rate | implemented | binomial MCSE over attempted fits |
| conv_failure_rate | implemented | binomial MCSE over attempted fits |
| boot_fail_rate | implemented | binomial MCSE over bootstrap attempts |
| bias/RMSE/power decision | not yet confirmatory | needs core-grid analysis script and pre-specified target |

## Pilot Semantics Audit

| Topic | Verdict | Next action |
|---|---|---|
| validation-row promotion | guarded | keep `CI-08` and `CI-10` partial until n_sim evidence |
| binomial-probit label | honest but incomplete | implement true probit DGP/fit or keep all pilot outputs labelled logit harness |
| ordinal-probit coverage | incomplete | either add primary coverage rows or exclude ordinal from confirmatory coverage claims |
| signal-zero naming | repaired | keep "signal-zero coverage diagnostic", not Type-I error |
| MCSE/denominators | largely repaired | keep both `n_sim` MCSE and row denominators visible |
| durable manifests | strong | current manifest/chunk fields are adequate for the next smoke |
| shared `pilot-index.rds` | guarded | DRAC chunk path must not use concurrent shared-index writes |
| scheduled sweep output | diagnostic only | do not promote validation rows from sweep output |

## Next-PR File Map

The next focused package PR should be one of these. Do only one at a time.

| Priority | Slice | Files likely touched | Acceptance gate |
|---:|---|---|---|
| 1 | Tiny scheduled fir fit-smoke readout | `docs/design/66-capstone-power-study.md`, `docs/dev-log/check-log.md`, one after-task report | fir `SLURM_STAGE=all N_SIM_STEP=1 N_BOOT=0` completes, writes expected chunk/aggregate artifacts, no fit on login node, no validation promotion |
| 2 | Tiny fir bootstrap smoke readout | same docs/log files only, unless wrapper gaps appear | after slice 1, `N_BOOT=2` completes and aggregate/report path is readable |
| 3 | True binomial-probit harness repair | `dev/m3-grid.R`, `dev/m3-pilot-launch.R`, tests, Design 66, check-log, after-task | DGP and fit both use probit; old result-store labels remain compatible; no old logit evidence promoted |
| 4 | Ordinal coverage decision | `dev/m3-grid.R`, report tests, Design 66, register wording only if evidence changes | ordinal either produces valid primary coverage rows or is explicitly excluded from confirmatory coverage |
| 5 | Core-grid analysis scaffold | new dev analysis/report script plus tests | bias/RMSE/coverage/power tables include MCSE and failure ledgers |

For the immediate next two-hour block, choose priority 1 unless the running
Power pilot sweep or main CI fails first.

## Prepared DRAC CPU Commands

These are prepared only. They were not run in this audit.

```sh
# Login-node validation only: no job submission.
ssh fir 'set -euo pipefail
cd "$SCRATCH/gllvmTMB-fir-slurm-library-smoke"
RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RESULTS_DIR="$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot0-$RUN_STAMP"
DRAC_EXTRA_MODULES="StdEnv/2023 gcc/12.3 udunits/2.2.28 gdal/3.9.1 geos/3.12.0 proj/9.2.0" \
R_LIBS_USER_DIR="$SCRATCH/gllvmtmb-r-libs/4.5.0" \
SLURM_ACTION=test SLURM_STAGE=all \
SLURM_TIME=01:00:00 N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=0 \
RESULTS_DIR="$RESULTS_DIR" SEED_BASE=185 \
bash dev/power-pilot-slurm-smoke.sh'
```

```sh
# Requires explicit maintainer widening: scheduled tiny fit smoke, CPU only.
ssh fir 'set -euo pipefail
cd "$SCRATCH/gllvmTMB-fir-slurm-library-smoke"
RESULTS_DIR="$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot0-20260624"
DRAC_EXTRA_MODULES="StdEnv/2023 gcc/12.3 udunits/2.2.28 gdal/3.9.1 geos/3.12.0 proj/9.2.0" \
R_LIBS_USER_DIR="$SCRATCH/gllvmtmb-r-libs/4.5.0" \
SLURM_ACTION=submit SLURM_STAGE=all \
SLURM_TIME=01:00:00 N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=0 \
RESULTS_DIR="$RESULTS_DIR" SEED_BASE=185 \
bash dev/power-pilot-slurm-smoke.sh'
```

```sh
# Only after N_BOOT=0 succeeds and artifacts inspect cleanly.
ssh fir 'set -euo pipefail
cd "$SCRATCH/gllvmTMB-fir-slurm-library-smoke"
RESULTS_DIR="$SCRATCH/gllvmtmb-power-pilot-smoke-fit-nboot2-20260624"
DRAC_EXTRA_MODULES="StdEnv/2023 gcc/12.3 udunits/2.2.28 gdal/3.9.1 geos/3.12.0 proj/9.2.0" \
R_LIBS_USER_DIR="$SCRATCH/gllvmtmb-r-libs/4.5.0" \
SLURM_ACTION=submit SLURM_STAGE=all \
SLURM_TIME=01:30:00 N_SIM_STEP=1 N_SIM_CAP=1 N_BOOT=2 \
RESULTS_DIR="$RESULTS_DIR" SEED_BASE=186 \
bash dev/power-pilot-slurm-smoke.sh'
```

Post-run inspection should require:

```sh
find "$RESULTS_DIR" -maxdepth 6 -type f | sort
find "$RESULTS_DIR" -type f \( -path "*/_chunks/*" -o -path "*/_chunk-aggregate/*" -o -name "*.rds" \) -print | sort
Rscript --vanilla dev/power-pilot-run.R --mode=chunk-audit --results-dir="$RESULTS_DIR"
Rscript --vanilla dev/power-pilot-run.R --mode=chunk-aggregate --results-dir="$RESULTS_DIR"
Rscript --vanilla dev/m3-pilot-report.R --emit-issues --chunk-aggregate --results-dir="$RESULTS_DIR"
```

## Speed Spike Triage

Source: `/Users/z3437171/Desktop/speed.txt`. The NotebookLM URL redirected to a
Google login in this session, so citation numbers from that note are not
independently verified here.

| Rank | Spike | First gllvmTMB/GLLVM gate |
|---:|---|---|
| 1 | independence-GLM / simple-model warm starts | benchmark same objective/estimates, fewer non-PD/failures, faster convergence |
| 2 | Cholesky/log-Cholesky PD parameterization | TMB-likelihood review plus objective/gradient parity on existing fixtures |
| 3 | OpenMP independent sums | identical objective/gradient with 1 vs many threads; CPU speedup on representative cells |
| 4 | pre-filtered second-order Laplace | accuracy versus AGQ spot checks before any speed claim |
| 5 | fully exponential Laplace / attenuation correction | reduced binary/low-count bias without worsening coverage |
| 6 | Takahashi selected inverse / sparse AD graph coloring | exact sparse inverse subset parity and Hessian/Jacobian evaluation counts |

Speed work must not move a capability row until it clears accuracy,
objective/gradient, CI/status, and runtime gates.

## Williams 2024 Self-Audit

| # | Item | Status | Where addressed |
|---|---|---|---|
| 1 | Aims | partial | ADEMP skeleton |
| 2 | DGP + n_sim justified | partial | Design 66 plus this packet; final n_sim waits for core-grid launch decision |
| 3 | Estimand / target | partial | `Sigma_unit_diag`, zero-exclusion caveat, unresolved probit/ordinal gaps |
| 4 | Methods literature cited | partial | cites Morris et al. 2019 and Williams et al. 2024; speed-note citations unverified |
| 5 | Performance measures | partial | formulas and MCSE rules listed |
| 6 | Software / packages / versions | partial | fir library convention exists; final campaign must save session info |
| 7 | Code for DGP available | partial | `dev/m3-grid.R`, `dev/m3-pilot-launch.R` |
| 8 | Code for performance measures | partial | `dev/m3-pilot-report.R`, core-grid analysis still needed |
| 9 | Worked-example case study | gap | not part of this audit |
| 10 | Full performance table | gap | waits for core-grid analysis |
| 11 | MCSE reported alongside | partial | implemented for pilot summaries; must be preserved in core outputs |

## Hard Stops

Stop immediately if any next slice does one of these:

- stages or commits from the Dropbox checkout;
- opens a second active capability PR;
- promotes `CI-08` or `CI-10` from pilot or scheduled sweep output;
- starts GPU work;
- fits on a DRAC login node;
- launches broad DRAC/Totoro production simulation;
- writes concurrently to `pilot-index.rds`;
- uses restricted-likelihood language outside the Gaussian-only scope;
- implies broad Julia parity from admitted-row tests.
