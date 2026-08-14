# Ultra Plan — LA-MSPL coverage calibration and conditional public promotion

🎯 GOAL

```text
Solo platform: Codex
Deliverable: calibrated fixed-effect profile and unconditional parametric-
bootstrap intervals for the selected 36 ordinary q=1 MSPL targets, plus an
honest conditional paper-style Wald map and only the public methods earned by
the frozen repeated-sampling gates.
HEADLINE: execute the exact DRAC readiness ladder before any production array.
IN PARALLEL: Gate 0 runner, cluster launchers, mechanical fence audit, and
statistical review.
DEFER: q=2, structured effects, missing data, derived targets, likelihood
comparison, public generic TMB profiling, and any route that fails calibration.
DISCIPLINE: verify=exact receipts plus independent review · compute=DRAC only ·
closure=conditional public promotion or a typed non-promotion map.
```

## Frozen statistical contract

The campaign crosses four regimes (baseline, low prevalence, high prevalence,
and strong signal) with logit, probit, and standard cloglog. Each of the 12
cases has three resolved `b_fix` targets, 1,000 attempted outer datasets, and
500 attempted unconditional bootstrap refits per outer dataset.

Profile intervals reoptimise every nuisance coordinate against the active
penalised `fit$tmb_obj` (`estimator_id = 1`). Bootstrap estimates come from
complete penalised MSPL refits. Wald curvature is the penalty-off approximate
Laplace Hessian (`estimator_id = 2`) evaluated only at the penalised MSPL
estimate; that tape is never optimised and non-positive-definite Hessians are
retained as typed failures.

For profile and bootstrap, unavailable intervals count as non-coverage.
Availability must be at least 0.95 and the 90% Wilson interval for coverage
must lie wholly inside [0.92, 0.98] in every target cell. A bootstrap interval
requires at least 475 of 500 usable refits. Wald promotion is separate: each
target cell needs at least 500 available intervals and conditional coverage
must pass the same equivalence gate. Failed confirmation evidence may not be
used to tune a method.

## Phase 0 receipt

- Worktree: `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB`.
- Branch/source at orientation:
  `codex/lane-b-mspl-interval-feasibility@ee206bfd`, clean, ten commits ahead
  of its remote tracking branch.
- Lane preflight: no foreign platform owns this subject; several independent
  same-platform lanes are live. This lane owns only MSPL uncertainty files.
- Coordination: the committed coordination board is visible. The GitHub PR
  query could not reach `api.github.com`; local all-ref history and the board
  are the recorded fallback.
- Prior result: Arc 3 established private endpoint construction for profile
  36/36, bootstrap 36/36, and Wald 21/36 with 15 typed non-PD blockers. It did
  not measure coverage.
- Sister sweep: no reusable public LA-MSPL calibration route was found in the
  local GLLVM.jl or drmTMB source searches.
- Brain receipt: earlier DRAC campaigns require manifest/test-only checks,
  scheduled zero/tiny-bootstrap smokes, exact production-command execution,
  pinned modules and source identities, per-task/node-local libraries, failure
  retention, and milestone status tools.
- Compute boundary: serious simulation runs on DRAC, never GitHub Actions.

## Readiness ladder

1. **Gate 0 — local contract.** Freeze the manifest and seeds; implement an
   exact-key, failure-retaining runner and aggregator; test duplicates,
   omissions, wrong SHA, and malformed shards; validate Slurm scripts with
   `bash -n`; and round-trip one local miniature compressed shard.
2. **Gate 1 — scheduler dry run.** Nibi, Narval, and Rorqual must accept setup,
   smoke, and array scripts with `sbatch --test-only`; storage must retain at
   least twice the projected file and byte margin.
3. **Gate 2 — cluster-native build.** Each admitted cluster builds its own
   compiled dependency library under `$SLURM_TMPDIR`, archives it, and writes
   a provenance receipt plus one finite MSPL objective evaluation. Narval may
   not consume binaries from another processor generation.
4. **Gate 3 — exact scheduled smoke.** Each cluster runs the production lookup
   and runner path for one outer dataset per link, all three profiles, one Wald
   calculation, and two unconditional bootstrap refits; the retrieved shard
   must aggregate exactly.
5. **Gate 4 — production pre-run.** Run 10 outer datasets per case with 500
   inner attempts: 12 shards, 120 outer keys, 60,000 inner-attempt rows, and
   1,080 method-target endpoint rows. Record elapsed time, memory, storage, and
   the projected full campaign. Stop for maintainer approval.
6. **Production and promotion.** Only after Gate 4 approval, run the remaining
   immutable keys. Adjudicate every method/target cell before editing public
   inference dispatch.

## Routing and timing

Default case routing is Nibi 6, Narval 4, and Rorqual 2. Fir remains reserve
until its project file quota is relieved. Tasks contain 10 outer datasets, use
one CPU and one BLAS thread, request 4 GB and 30 minutes, write one compressed
atomic shard from node-local storage, and publish only that shard plus one
compact scheduler log. The full programme is estimated at 24--36 elapsed
hours over two to four calendar days. Gate 4 is expected after four to six
hours of readiness work; full production is estimated at four to eight hours
after queue start.

The monitor reports expected, completed, running, pending, failed, and newest
valid receipt time. It checks at 30--60 minute milestones. No setup/smoke start
within 45 minutes triggers rerouting; no shard within 60 minutes of the first
task start, a task above twice the Gate 4 median, a 30-minute task, or two hours
pending triggers stop-and-diagnose/reassignment of the identical missing keys.

## Public claim fence

No public inference surface changes before calibration adjudication.
After a route passes every predeclared target-cell gate, public work may expose
only resolved fixed-effect `b_fix` targets. `standard_errors()`, generic
`tmbprofile_wrapper()`, `bootstrap_Sigma()`, loading/covariance/latent and
derived targets, likelihood-comparison methods, q=2, structured, weighted, and
missing-data MSPL fits remain fail-closed. Validation row `MSPL-04` can move
only from blocked to partial.

## Planned verification and deliberate non-runs

Gate 0 uses focused MSPL and runner tests, local miniature aggregation,
`bash -n`, static fence scans, and `git diff --check`. Public promotion, if
earned, additionally requires all package tests, documentation regeneration,
pkgdown checks, `R CMD check`, three-OS CI, Fisher inference review, Rose
consistency review, an after-task report, and a plan-versus-actual receipt.
GitHub Actions will not run or store simulation outputs.

## ADEMP design and transparent-reporting audit

The primary **Aim** is to estimate availability and repeated-sampling coverage
for the three private fixed-effect interval candidates before any public
promotion. The **Data-generating mechanism** is

\[
z_i \sim N(0,1),\qquad
\eta_{it}=\beta_t+\lambda_t z_i,\qquad
Y_{it}\sim\operatorname{Bernoulli}\{g^{-1}(\eta_{it})\},
\]

with 24 sites, three traits, `q = 1`,
\(\beta=(-0.5,0.1,0.55)\), and
\(\lambda=(0.8,-0.55,0.35)\). Low/high prevalence shift every beta by
-1.5/+1.5; strong signal multiplies lambda by 1.75. The **Estimands** are the
three planted beta coordinates. The **Methods** are penalised profile,
unconditional parametric percentile bootstrap, and paper-style penalty-off
likelihood curvature evaluated at the penalised MSPL estimate. The
**Performance measures** are availability, unconditional and conditional
coverage, bias, RMSE, interval width, retained failure status, and wall time.
Coverage and availability use binomial MCSEs and 90% Wilson bounds; bias,
RMSE, mean width, and mean runtime carry their own MCSE fields. One thousand
outer attempts give coverage MCSE about 0.7 percentage points near 0.95.

The design follows ADEMP in Morris, White and Crowther
([2019](https://doi.org/10.1002/sim.8086)) and the transparent-reporting items
of Williams et al. ([2024](https://doi.org/10.1111/2041-210X.14415)). The Wald
construction is grounded in Sterzinger and Kosmidis
([2023](https://doi.org/10.1007/s11222-023-10217-3)); profile and bootstrap
are package candidates and are not attributed to that paper.

| # | Item                          | Status | Where addressed                        |
|---|-------------------------------|--------|----------------------------------------|
| 1 | Aims                          | ✅ | Goal and ADEMP paragraph |
| 2 | DGP + n_sim justified         | ✅ | DGP equation, fixed regime table, 0.7-point coverage MCSE |
| 3 | Estimand / target             | ✅ | Three planted `b_fix` beta coordinates |
| 4 | Methods literature cited      | ✅ | Morris, Williams, and Sterzinger/Kosmidis references |
| 5 | Performance measures (formulas) | ✅ | Frozen statistical contract and runner summary functions |
| 6 | Software / packages / versions | partial | Gate 2 receipts will freeze R/TMB/package/compiler versions |
| 7 | Code for DGP available        | ✅ | Private coverage runner |
| 8 | Code for performance measures | ✅ | Failure-retaining validator and aggregator |
| 9 | Worked-example case study     | partial | Three-link Gate 0 smoke exists; a reader-facing example waits for earned promotion |
| 10 | Full performance table       | gap | Requires the approved production campaign |
| 11 | MCSE reported alongside      | partial | Fields are implemented; production values require the campaign |

## Gate 0 actual — 2026-08-14

Gate 0 is complete at the working-tree candidate. The runner freezes 12 cases,
1,000 outer attempts per case, 500 unconditional bootstrap attempts per outer
dataset, 10 outer datasets per shard, and the Nibi 6 / Narval 4 / Rorqual 2
routing. Production aggregation and array execution reject smoke, test, mini,
mixed-version, relaxed-gate, or reduced-cardinality manifests. Bootstrap
endpoints are recomputed from retained type-7 attempts; successful profiles
must reproduce finite converged nuisance-reoptimised brackets at exactly
`qchisq(.95, 1) / 2`. Runtime libraries bind the source archive, dependency
source bundle, architecture, cluster, and source SHA.

Verification actuals:

- pure runner contract: 86 expectations, zero failures/warnings/skips;
- focused `mspl` suite: 1,301 expectations, zero failures/warnings, one
  pre-existing intentional skip, 152.4 seconds;
- real local smoke: logit/probit/cloglog, 3/3 outer fits, 6/6 unconditional
  bootstrap refits, 27/27 method-target endpoints, and 295 profile-trace rows;
- smoke receipt correctly says `calibration_gate_eligible: FALSE`;
- launcher negative self-test, all `bash -n` checks, `git diff --check`, and
  the unchanged-public-fence scan passed;
- Sol statistical review and Luna mechanical review both returned PASS with
  no P0/P1/P2 findings after two repair rounds.

The smoke establishes runner and readiness integrity only. It neither
establishes coverage nor authorises public MSPL inference. Gates 1--4 remain
pending, and the full 1,200-shard production campaign remains locked behind
maintainer approval of the 60,000-refit Gate 4 receipt.

## Gates 1--4 actual — 2026-08-14

Gates 1--4 completed against immutable source commit `112931db32088b5ff8c460ff9e89a7ef81d10c96` and stopped before the full campaign. Gate 1 scheduler dry-runs accepted setup, smoke, and array submissions on Nibi, Narval, and Rorqual; staged source, source-bundle, and manifest hashes matched on all three clusters. The source-only dependency repository contained 35 non-base source tarballs and no compiled binaries.

Gate 2 built separate native runtimes on every cluster. Nibi completed in 6:54 (4.26 GB maximum RSS), Narval in 7:57 (3.80 GB, x86-64-v3), and Rorqual in 5:45 (3.86 GB, x86-64-v4). Each receipt bound the source and dependency hashes and recorded a finite MSPL objective near 29.95617. No compiled runtime moved between clusters.

Gate 3 completed nine exact scheduled smokes: logit, probit, and cloglog on each cluster. The combined receipt contained 9 outer fits, 18 unconditional bootstrap attempts, 81 method-target endpoint rows, and 885 profile-trace rows. Each cluster's aggregate was explicitly `calibration_gate_eligible: FALSE`.

Gate 4 completed all 12 predeclared first shards. The exact receipt contains 120 outer fits, 60,000 unconditional bootstrap attempts, 1,080 endpoint rows, and 11,576 profile-trace rows, with zero missing or duplicate keys. All 120 outer fits succeeded and every outer dataset retained 500/500 usable bootstrap refits. Endpoint availability was bootstrap 360/360, profile 358/360, and Wald 279/360. The two retained profile failures were one `refinement_failed` lower side and one `truncated` lower side in case C010. Wald retained 81 unavailable target endpoints arising from 27 non-positive-definite fit-level likelihood Hessians; it did not use a pseudoinverse or repaired Hessian.

Task wall times were 4:48--9:45 (median 7:15.5), maximum RSS was 276,084--712,604 KB, and the 12 compressed shards totalled 2,254,447 bytes. The observed full-campaign projection remains four to eight hours after queue start and below the 12-hour redesign threshold. Rorqual's exact file quota was 497,536/500,000; the compact 200-task route needs 402 new files, leaving 1,660 files beyond the predeclared doubled-margin requirement.

The gates retained, rather than hid, several pre-compute launcher failures: Slurm-spooled relative helper lookup, concatenated dependency names, unexported runtime variables, and quoted-CSV case/campaign lookup. Each identical pending job was cancelled after the first deterministic failure. Recovery wrappers changed only the identified launcher operation, carried their own hashes, and passed targeted preflights before resubmission. The permanent launcher repairs now have spool-location, dependency-vector, child-process environment, quoted-manifest, cluster-routing, campaign-ID, and missing-final-newline regressions. A new `aggregate-prerun` route reproduces the real Gate 4 receipt without relaxing production aggregation; its receipt is typed `gate4-production-prerun-v1`, `gate4_contract: exact`, and `calibration_gate_eligible: FALSE`.

The production promotion gates are deliberately not adjudicated at ten outer datasets per case. Bootstrap had 360/360 operational endpoints, profile 358/360, and Wald 279/360, but all 108 Wilson coverage gates remain false at this pre-run size. These are operational data only, not calibrated interval evidence. Public MSPL `vcov()`, `confint()`, `profile_targets()`, `tmbprofile_wrapper()`, `bootstrap_Sigma()`, and standard-error routes remain fail-closed.

The completion receipt SHA-256 is `33ad3b6a8c9b2156299067be6fc705b1cd1c532d80dfac5ac7b985e8f8e844b3`; the final explicit, self-identifying `aggregate-prerun` receipt SHA-256 is `25da8a0b5fb76e93bd8cc13c33c920573637e48c4cf290425dbdd86e521a0d1e`. The preserved local retrieval is `/tmp/mspl-coverage-retrieval-112931db/gate4`, and the checksum-verified execution bundle is `/tmp/mspl-coverage-retrieval-112931db/gates1-4-execution-bundle.tar.gz` (SHA-256 `7869083e6c705cebb3eadba167fc3dd5a2a08eb749a0c09c8a4a9e37ecacfc05`). No full production job was submitted; the unlocking receipt remains absent on all clusters. The next irreversible step is maintainer approval of the full 1,200-shard campaign, followed by a new immutable source commit and repeat identity/dry-run gates for the permanent launcher repairs.
