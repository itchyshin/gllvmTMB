# Interval-calibration combined measured pre-run receipt

Date: 2026-08-25

Status: **MEASURED, NOT CERTIFIED — REMOTE CAMPAIGNS NOT RUN**

This receipt closes the bounded local timing stage for PVT-02 / CI-08, CI-09,
CI-10, CI-13, CI-14, and CI-15. It authorises no Totoro or DRAC work. Every
fit or simulation below had a written estimate of 30 minutes or less before
launch. No science compute used GitHub Actions.

## Frozen packet sources

| Packet | Source SHA used by the final usable smoke |
|---|---|
| PVT-02 / CI-08 | `1d4e03d926f78a244257d03c3a0669549c0eceac` |
| CI-09 | `822024b1bd31a90a9dbe211ad09e1b26b2030ac8` |
| CI-10 | `328d8abc9125ce1e7edbcdcdcb1a41f043488431` |
| CI-13 | `39ab3b2983560fd3dea7bdfee124144d203cba2e` |
| CI-14/15 | `328d8abc9125ce1e7edbcdcdcb1a41f043488431` |

Later commits contain only packet-local repairs or tracked receipts; a remote
manifest must name the relevant frozen source above and reject a mismatch.

## Measured usable smokes

| Packet / cell | Identity | Pre-run estimate | Measured model time | Retained outcome |
|---|---:|---:|---:|---|
| PVT-02 `n=400,d=2`, both traits | reps 50001–50002 | 1–3 min | 19.865 s; 6.134 s | one eligible row with both traits covered and `route-only`; one base-fit failure |
| CI-09 `n=150,rho=-0.5` | cell 1, rep 3 | 20–90 s for two cells | 0.827 s | base-fit failure, `n_eff=NA` |
| CI-09 `n=400,rho=-0.5` | cell 4, rep 3 | same | 5.557 s | eligible miss, realised `n_eff=400` |
| CI-13 `n=150,d=1` | cell 1, rep 2 | 1–4 min for two cells | 1.379 s | eligible; both mapped-free targets covered |
| CI-13 `n=400,d=2` | cell 4, rep 2 | same | 6.300 s | eligible; all three mapped-free targets covered |
| CI-14 `n_ind=50` | cell 1, rep 3 | 2–15 s | 2.776 s | base-health failure; no target payload |
| CI-15 phylo `n_sp=70` | cell 1, rep 3 | 2–15 s | 5.913 s | eligible; both targets covered |
| CI-15 loadings `n_ind=100` | cell 3, rep 3 | 3–20 s | 2.770 s | base-health failure; no target payload |
| CI-10 Gaussian `N=50`, 39 bootstraps | cell 10, rep 2 | 40–90 s | 20.480 s | multiple-r covered; both contrast profiles failed |
| CI-10 binomial `N=500`, 39 bootstraps | cell 9, rep 1 | 2–10 min | 78.604 s | multiple-r covered; both contrast profiles failed |

These are plumbing and timing observations, not coverage estimates. CI
failures in eligible rows are misses in a campaign. Availability is reported
but has no promotion floor.

## Preserved failed and superseded invocations

Nothing was rerun away.

- CI-09 rep 1, cells 1 and 4, failed before fitting because the smoke formula
  used the unsupported namespaced AST `gllvmTMB::dep(...)`. Both raw rows are
  retained. The parser repair is commit `eac77a28`.
- The next CI-09 command attempted rep 2 but stopped during cell 1 because a
  nonconverged fit exposed `n_sites` while the canonical constructor correctly
  required `n_eff=NA`. It wrote no RDS and used the mistaken non-HEAD source
  string `eac77a28c34518f04d7de94a4fc89724b338dc68`; this invocation is therefore
  unusable provenance, not a scientific row. The retention repair is commit
  `822024b1`.
- CI-13 rep 1, cells 1 and 4, are retained scientific base failures: the
  runner generated a `unit` column but left the front-end default
  `unit="site"`. The repair is commit `39ab3b29`.
- CI-14/15 rep 1 results are retained. The two ordinary routes warned that
  `unit_obs` was unused; the phylogenetic route warned about the deprecated
  global `phylo_tree` argument. Commit `88c14c31` removed those warnings.
- CI-14/15 rep 2 warning-clean results are retained, but their result objects
  dropped the request's `fit_formula`. Commit `328d8abc` repaired that
  provenance. Rep 3 verifies the final result schema and preserves mixed
  health outcomes.
- CI-10 Gaussian cell 10 rep 1 with `n_boot=8` is retained. It took 9.548 s
  but cannot make a 95% percentile interval: the maximum arithmetic coverage
  is 0.778. It is a timing probe only. Rep 2 uses the minimum valid 39 draws;
  even that produces materially noisy endpoints and is not evidence for the
  frozen 499-draw method.

## Full-campaign projections

The projections deliberately use successful or conservative measured times.
They exclude queueing, filesystem contention, serialization, retries for
infrastructure only, and aggregation overhead.

| Packet | Frozen outer rows | Measured serial projection | Recommended target |
|---|---:|---:|---|
| PVT-02 | 5,000 | 27.6 h using the successful two-target row | Totoro, bounded worker pool |
| CI-09 | 30,000 | up to 46.3 h if all six cells cost the measured `n=400` row | Totoro, bounded worker pool |
| CI-13 | 20,000 | 7.7–35.0 h using the two measured cell times as a bracket | Totoro, bounded worker pool |
| CI-14 | 10,000 | about 11.57 h if the unmeasured `n=100` cell scales linearly from 2.776 s | Totoro, bounded worker pool |
| CI-15 | 20,000 | about 36.18 h under linear size scaling from 5.913 s and 2.770 s | Totoro, bounded worker pool |
| CI-10 | 90,000 | 273–1,048 CPU-days by linear 39-to-499 bootstrap scaling | DRAC only; see recommendation below |

CI-10 alone freezes `18 × 5,000 × 499 = 44,910,000` inner bootstrap refits,
in addition to outer fits and contrast profiles. The measured 499-draw outer
projection is about 4.37 min for Gaussian `N=50` and 16.76 min for binomial
`N=500`. A monolithic launch is scientifically specified but operationally
expensive enough that the recommended next step is a small DRAC cost-array,
not the full 90,000-row campaign.

## Required remote controls

For any approved campaign:

1. pin single-thread BLAS and keep Totoro at or below 150 workers;
2. use disjoint packet/cell batch roots and immutable source-SHA-bound
   manifests;
3. retain one canonical scientific row for every frozen identity plus every
   operational attempt; scientific failures are terminal;
4. reject duplicates, missing batches, checksum mismatches, and source-SHA
   drift before aggregation;
5. mirror raw keepers to the durable campaign store and track outer ledgers,
   aggregates, session manifests, checksums, and failure counts in the repo;
6. run DRAC only through `sbatch`, never on a login node;
7. stop and re-estimate any job that exceeds its approved wall-time estimate.

The local raw outputs are gitignored. Their SHA-256 manifest is
`2026-08-25-local-smoke-checksums.sha256`. The missing CI-09 rep-2 RDS is
explicitly disclosed above rather than fabricated.

## Approval checkpoint

No remote job has been submitted. The recommended approval envelope is:

- **Totoro:** five sequential waves in the fixed order PVT-02, CI-09, CI-13,
  CI-14, CI-15. Each wave may use at most 96 workers; aggregate concurrency is
  therefore also 96, below the 150-core ceiling. Set `OPENBLAS_NUM_THREADS=1`,
  `OMP_NUM_THREADS=1`, and `MKL_NUM_THREADS=1`. Each wave has a 2 h hard stop;
  an overrun is stopped and re-estimated before any restart. Immutable roots
  are `/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/pvt02`,
  `/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci09`,
  `/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci13`,
  `/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci14`, and
  `/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci15`. No two waves
  run concurrently.
- **CI-10 DRAC cost-array only:** `--array=1-18%18`, one task and one canonical
  outer row per frozen cell, all at rep 3 and `n_boot=499`; 18 expected rows,
  18 shards, source SHA
  `328d8abc9125ce1e7edbcdcdcb1a41f043488431`. Seeds are
  `1060724, 2060727, 3060730, 4060733, 5060736, 6060739, 7060742, 8060745,
  9060748, 10060751, 11060754, 12060757, 13060760, 14060763, 15060766,
  16060769, 17060772, 18060775` in cell order 1–18. Submit only through
  `sbatch --account=def-snakagaw --time=00:30:00 --cpus-per-task=1
  --mem=8G`; fail closed if that account is unavailable rather than
  substituting another account. After the first preparation attempt measured
  the project file-count quota at its hard limit, the immutable output root is
  `/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/ci10-cost-array`.
  Any task reaching 30 minutes stops. If the full campaign is later approved,
  these exact rep-3 rows are its canonical rows and are not rerun; every
  operational attempt remains in the receipt.

The CI-10 cost-array is an approval to measure 18 rows only. It is not approval
for the 90,000-row campaign, any different DRAC account, a longer wall time, or
additional replicas.

The full CI-10 campaign is **not** recommended for immediate launch from the
39-draw extrapolation alone. Until explicit approval, the campaign routes
remain at their existing limited/blocked states, CI-11/12 remain refused, and
no new certificate is claimed.

## Approval and dispatch-readiness checkpoint

Shinichi explicitly approved the exact envelope above on 2026-08-25. That
approval covers the five sequential Totoro waves and the 18-task CI-10 DRAC
cost array only. It does not cover the full CI-10 campaign or any widened
resource, estimand, cell, or retry policy.

The first post-approval deployment audit found that the frozen scientific
commits had no production shard/launcher layer. The lane therefore added an
orchestration-only layer under `dev/interval-calibration/remote/` plus a
packet-local CI-14/15 shard validator before submission. The approved
scientific files (`R/`, the packet kernels/runners, and the existing DGP
helpers) remain byte-identical to their packet-specific frozen SHAs. Every
remote shard checks that fact with `git diff --quiet <frozen-sha> --
<scientific-paths>` before fitting.

The production layer now provides:

- exact 5,000-replicate task manifests (18 rep-3 rows only for CI-10);
- one identity per independent R process, with all thread counts pinned to one;
- immutable start/completion/failure operational receipts and an atomic
  canonical RDS shard;
- duplicate/conflicting-identity refusal;
- a 96-process, whole-wave two-hour Totoro hard stop and exact shard-count
  check;
- the frozen 18-task, 30-minute, `def-snakagaw` CI-10 SLURM array;
- environment/session receipts and fail-closed campaign aggregators.

Local negative controls verified that a source SHA outside the approved packet
is refused before an operational attempt, that an approved source paired with
an unmarked installed library retains start/failure receipts without starting
a fit, and that an incomplete campaign root refuses aggregation. The six
generated task manifests contain exactly
5,000, 30,000, 20,000, 10,000, 20,000, and 18 data rows for PVT-02, CI-09,
CI-13, CI-14, CI-15, and CI-10 respectively.

No remote job was submitted at this checkpoint. Existing reuse-only sockets
were present for Totoro and the DRAC clusters, but this Codex task's managed
sandbox denied the local Unix-socket connection with `Operation not
permitted`; escalation is disabled. The same managed profile grants only read
access to this worktree's external Git metadata, so the verified
production-dispatch diff cannot yet be staged or committed (`index.lock:
Operation not permitted`). The files remain on the leased branch and the
worktree is intentionally left uncommitted rather than misreported as landed.
The DRAC execution host is frozen to **Fir**, using the existing
`cm-snakagaw@fir.alliancecan.ca:22` socket and the already-approved
`def-snakagaw` account. A verified git bundle, rather than a shared-tree
`rsync`, is the required source transport.

Grace's final read-only deployment review returned **PASS** after two
fail-closed repairs: exact output-root creation is now atomic on both Totoro
and Fir, and tracked or untracked orchestration drift is rejected before every
shard, session receipt, and aggregation. Independent R parsing, shell syntax,
focused packet tests, and `git diff --check` passed after the repairs. The
preserved dispatch packet is under the gitignored
`dev/interval-calibration/results/2026-08-25-approved-dispatch/` root. Its
`dispatch-checksums.sha256` ledger binds the base git bundle, current overlay,
tracked patch, and all six complete task manifests. This packet is a recovery
artefact only: the overlay must first be committed into a clean orchestration
checkout, and no launcher may run from the intentionally dirty lane checkout.

Because the managed sandbox cannot update the lane's external Git index, the
same checksummed overlay was also applied to an independent clean clone at the
exact `dd4410155980cfc9a8a0e8f1c91d3cfc03bd95c5` base and committed there on
`codex/interval-calibration-release`. The complete-history portable branch
bundle is retained as `gllvmTMB-interval-dispatch.bundle` in the dispatch root
and covered by the checksum ledger. This preserves a clean, reverified landed
commit for recovery without falsely advancing the original worktree's branch
reference. A second reuse-only socket check still returned `Operation not
permitted` for both existing control sockets, so neither Totoro nor Fir
received a submission.

## Post-approval operational update

Escalated reuse of the existing `cm-` sockets subsequently became available.
Totoro preparation completed successfully: all four distinct packet libraries
installed and loaded with their exact scientific source-SHA markers. No
simulation had started at that point.

The first Fir preparation attempt failed before package installation or SLURM
submission. `diskusage_report` measured `/project/def-snakagaw` at
`500K/500K` files while using only `195GiB/954GiB`; the root cause was the
project file-count quota, not storage capacity or connectivity. The backed-up
Fir home filesystem measured `110K/500K` files and `11GiB/48GiB`. The Fir-only
dispatch was therefore revised to use the immutable backed-up home root shown
above. This changes no account, task identity, seed, source SHA, resource
request, timeout, estimator, or scientific denominator. A path-contract test
was observed failing against the old project root and then passed, together
with all other CI-10 focused assertions, after the four hard-coded paths were
changed. The failed preparation remains an operational attempt in this
receipt; it created no campaign row and submitted no job.
