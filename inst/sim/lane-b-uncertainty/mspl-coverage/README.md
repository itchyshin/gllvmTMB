# Private LA-MSPL coverage — DRAC readiness launcher contract

These are scheduler templates, not submitters.  They implement the Gate 1–4
readiness ladder for the private repeated-sampling coverage runner only:
`inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R run-shard`.
The RDS written by that runner is already gzip-compressed; these scripts copy
that exact byte stream atomically from node-local `shards/` to durable
`/project/.../shards/`.  They never emit or re-gzip a CSV shard.

## Inputs and source bundle

All scripts require `MSPL_COVERAGE_ROOT` (an explicit `/project/...` root),
`MSPL_COVERAGE_SOURCE_SHA`, source archive plus SHA (`MSPL_COVERAGE_SOURCE_ARCHIVE`
and `MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256`), and `MSPL_COVERAGE_CLUSTER`
(`nibi`, `narval`, `rorqual`, or reserve `fir`). The source SHA is the frozen
campaign identity, not an inferred checkout revision.

Setup additionally requires an **offline source repository bundle**:

```text
source-bundle.tar.gz
└── src/contrib/
    ├── PACKAGES
    ├── PACKAGES.gz                  # optional but recommended
    ├── BH_<version>.tar.gz
    ├── RcppEigen_<version>.tar.gz
    ├── TMB_<version>.tar.gz
    └── ... every transitive source dependency required below
```

Set its path/hash as `MSPL_COVERAGE_SOURCE_BUNDLE` and
`MSPL_COVERAGE_SOURCE_BUNDLE_SHA256`. A precompiled `r-library/` in this bundle
is rejected: setup requires `src/contrib/PACKAGES` plus source tarballs.
The default exact direct-install order is
`BH,RcppEigen,TMB,assertthat,cli,fmesher,generics,lifecycle,rlang,tidyselect`;
setup installs `BH,RcppEigen,TMB` first, then the remainder and their complete
Depends/Imports/LinkingTo closure from the local repository, then builds the
frozen `gllvmTMB` source archive. Override only the explicit comma-separated
`MSPL_COVERAGE_DEPENDENCY_PACKAGES` list when the frozen source bundle changes.

Setup writes exactly one cluster-labelled archive:

```text
$MSPL_COVERAGE_ROOT/runtime-libraries/<cluster>/
  mspl-coverage-runtime-<cluster>-<source_sha>.tar.gz
```

and an adjacent `.env` file containing the required later-task inputs
`MSPL_COVERAGE_RUNTIME_ARCHIVE`, `MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256`, and
the bound source archive/dependency-bundle hashes.
Its receipt records source/archive/bundle/package hashes and versions, R,
compiler, architecture, module list, `sessionInfo()`, and one finite MSPL
objective evaluation. Smoke and array tasks only verify and unpack this archive
below their own `SLURM_TMPDIR`; they never install or compile dependencies.
The embedded cluster/source/architecture contract prevents Narval from using a
library built on another cluster or processor generation.

## Manifest, maps, and immutable shards

The coverage runner produces the frozen `manifest.csv` and `array-map.tsv`.
The map has `array_index<TAB>case_id<TAB>shard_id`; lookup is by `awk` key, not
line number, so an omitted final newline cannot drop the final task. The shell
also compares each selected case's `assigned_cluster` in `manifest.csv` with
`MSPL_COVERAGE_CLUSTER` before invoking the runner.

Both Gate 4 pre-run and production validate the manifest independently before
looking up a map row. Admission requires the exact production version on all
12 ordered cases (`baseline`, `low_prevalence`, `high_prevalence`, and
`strong_signal` within logit, probit, and cloglog), their frozen DGP/seed
values, 1,000 outer datasets, `B=500`, 475 minimum usable bootstrap refits,
10 outer datasets per shard, 100 shards per case, availability 0.95, 90%
Wilson intervals, equivalence bounds [0.92, 0.98], Wald minimum 500, and the
6 Nibi / 4 Narval / 2 Rorqual assignment. A smoke, mini, test, mixed-version,
reordered, or numerically downgraded manifest fails before runner execution.

For Gate 3, each admitted cluster has exactly **three** production-path map
rows: one `logit`, one `probit`, and one `cloglog` outer dataset, each with
`B = 2` unconditional bootstrap refits. Thus each cluster retrieves exactly
three RDS shards, six bootstrap-attempt rows, and 27 method-target endpoint
rows, then runs one exact aggregation receipt. A multi-cluster Gate 3 keeps
these denominators separate by cluster. `drac-smoke.sbatch` remains a one-task
template and is submitted once for each of the three runner-produced rows.

`drac-array.sbatch` is for Gate 4 pre-run or final production. With
`MSPL_COVERAGE_STAGE=pre-run`, it requires a matching
`gates/gate3-smoke-ready.receipt` and defaults to the dedicated immutable
`pre-run-array-map.tsv`. That map is mechanically accepted only when it has
indices 1--12, each of the manifest's 12 cases exactly once, `shard_id=1` for
every case, and a manifest `outer_per_shard=10`: exactly 12 shards and 120
outer datasets. Pointing pre-run at the full production map or any other shard
fails before the runner starts. With `MSPL_COVERAGE_STAGE=production`
(default), the full `array-map.tsv` remains inaccessible until a matching
`gates/gate4-prerun-ready.receipt` exists. In either case the
receipt must exactly contain `gate_status=PASS`, `campaign_id`, `source_sha`,
and `manifest_sha256` matching the immutable root. Setup and Gate 3 smoke do
not require either receipt.

At task staging, the verified runtime archive's embedded contract must match
the current cluster, source SHA, source-archive SHA-256, dependency-source-
bundle SHA-256, and architecture. A byte-different source archive therefore
cannot run against an earlier compiled library even if the Git SHA label was
reused. Run `bash contract-self-test.sh` for the pure-shell positive/negative
map and source-archive/runtime binding checks.

## Gate 1 test-only and storage checks

Run these only on the relevant cluster login node after exporting the immutable
input variables; they validate scheduler shape and submit nothing:

```sh
sbatch --test-only inst/sim/lane-b-uncertainty/mspl-coverage/drac-setup.sbatch
sbatch --test-only inst/sim/lane-b-uncertainty/mspl-coverage/drac-smoke.sbatch
sbatch --test-only inst/sim/lane-b-uncertainty/mspl-coverage/drac-array.sbatch
```

Before admission, record current durable byte/file usage and verify at least a
2× margin over the declared Gate 3 or Gate 4 projection:

```sh
du -sb "$MSPL_COVERAGE_ROOT"
find "$MSPL_COVERAGE_ROOT" -xdev -type f | wc -l
df -PB1 "$MSPL_COVERAGE_ROOT"
lfs quota -h "$MSPL_COVERAGE_ROOT"  # where the project filesystem supports it
```

Defaults are `def-snakagaw_cpu`; setup requests 4 CPUs, 12 GB, and 30 minutes;
smoke/array tasks request 1 CPU, 4 GB, and 30 minutes. Modules are
`StdEnv/2023`, `gcc/12.3`, and `r/4.5.0`, plus an explicit
`MSPL_COVERAGE_EXTRA_MODULES` list when the frozen bundle needs geospatial
system libraries. `drac-monitor.sh` is read-only and always reports
`expected`, `completed`, `running`, `pending`, `failed`, and `newest_receipt`.
