# Check-log: source-pinned two-kernel recovery receipt (#1803)

**Goal:** Preserve the exact Totoro recovery design and denominators, fitted-object audit, software build identity, result summaries, and CI blocker for later citation. This receipt records exploratory pilot evidence; recovery qualification remains open.

## Source and build identity

- Task PR: [#1803](https://github.com/itchyshin/gllvmTMB/pull/1803), tested source commit `72856efae74971a155fed9cb0727f190bba754b5`, base `fc80be9ee232692a64dfef7f8570ce7a1528b861`.
- `git archive` SHA-256: `ab97964cec6fb44f8c849cc081b7317b496acdd977be5e3522a1382848e0ec1d`.
- Generator `dgp.R` SHA-256 recorded in each fit: `681e88623ef97168a66ff1ba2c7efc47890f29dd31cfaa4535471b6bf753a8ad`.
- Key package-source hashes recorded in each fit: `R/fit-multi.R` `5eae838611c38ed43e8f5ac6bb60a821df7ad1881874894a2e3ee365bc3dae93`; `src/gllvmTMB.cpp` `aba9758ba9815409402a6aafe9b124df9ea287af2a69b9dddf54e7542ca87165`.
- Totoro build from `/home/snakagaw/hsq_work/two-kernel-final-recovery-72856ef/`: R 4.6.1, TMB 1.9.25, gllvmTMB 0.8.0, GCC 13.3.0. Install command: `R CMD INSTALL --preclean --no-multiarch --with-keep.source .`; numerical-library threads were pinned to one. Installed `gllvmTMB.so` SHA-256: `0c6d935aa0601433f77ffb8e1f67de5bb215221fcd0eb7c95ceb7f4d265a9fab`.
- Each fit recorded the source commit, package-source SHA-256 vector, DLL SHA-256, design, mask, known observation SD, warnings, convergence code, extraction status, and named covariance estimates. Original and copied raw receipts remain under the ignored local `.unlazy/two-kernel/evidence/totoro/` directory and the Totoro run directory `/home/snakagaw/hsq_work/two-kernel-final-recovery-72856ef/`.

## Exact design and fit denominators

Each dataset has `n` H-lineage and `n` P-lineage species, four traits in order H1, H2, P1, P2, and `8n` possible species-trait cells. H species have H1/H2 observed; P species have P1/P2 observed. Thus each fit has `4n` observed and `4n` structurally missing cells: 256/256 at n=64, 512/512 at n=128, and 1024/1024 at n=256. Missing cells are NA and are omitted from fitting.

The two named kernel covariances are `Sigma_s = lambda_s lambda_s^T + diag(psi_s)`, with rank-one shared components and separate trait-specific uniqueness vectors. Trait order is H1, H2, P1, P2. The baseline and weak-separation lineage kernel uses `A_ij = a^abs(i-j)`, with `a=0.6` in baseline and `a=0.1` in weak controls. The phy kernel is `[[A, 0.55A], [0.55A, A]]`; the tip kernel is `[[I, 0.55I], [0.55I, I]]`. Baseline/weak truth:

| Tier | lambda | psi |
|---|---|---|
| phy | (0.90, 0.80, 0.85, 0.75) | (0.35, 0.45, 0.40, 0.30) |
| tip | (0.70, 0.90, 0.80, 0.65) | (0.40, 0.30, 0.35, 0.45) |

Boundary controls set every psi entry to 0.01 while retaining the corresponding baseline kernel and loading values. Fixed trait means are (0.1, -0.1, 0, 0). A per-kernel source ridge of `1e-8` is used. Observation error is the mean of three independent N(0, 0.2^2) errors, so the known SD supplied to the fit is `sqrt(0.04/3) = 0.1154701`; it is fixed and added once.

Fits used `kernel_latent(..., d=1, unique=TRUE)` for both names `phy` and `tip`, `known_sigma_eps` set to that SD, `n_init=3`, `init_jitter=0.3`, `optimizer="nlminb"`, `se=FALSE`, and optimizer limits `iter.max=3000`, `eval.max=5000`.

| Fitted objects | Sample sizes / seeds | Objects | Fit/extraction outcome |
|---|---|---:|---|
| Primary matched baseline | 12 matched data seeds, `2026111713`-`2026111724`, at n=64, 128, and 256 per lineage | 36 | 36 extracted; 36 optimizer code 0 |
| Additional baseline fits in the audited union | n=64 seeds `2026111702`-`2026111712` (11); n=128 seeds `2026111702`-`2026111712` (11) | 22 | 22 extracted; 22 optimizer code 0 |
| n=128 feasibility repeat | Data seed `2026111701`, initial and repeat fit | 2 | Both extracted, both optimizer code 0; same DGP key, not independent datasets |
| Weak-separation controls | n=64, seeds `2026111725`-`2026111736` | 12 | 12 extracted; 11 optimizer code 0, 1 code 1 |
| Near-boundary controls | n=64, seeds `2026111737`-`2026111748` | 12 | 12 extracted; 10 optimizer code 0, 2 code 1 |
| **Total source-pinned fit objects** | 83 distinct setting/n/data-seed keys; one repeated baseline n=128 seed `2026111701` | **84** | **84 extracted; 81 code 0, 3 code 1** |

The earlier two-size summary used seeds `2026111702`-`2026111713` at n=64 and n=128. The seed-1713 n=64 and n=128 fit objects are already in the 36-object primary matched set; they are not additional fit objects in the 84-object union. The two seed-1701 n=128 fits are the feasibility initial/repeat. The primary sample-size comparison uses 12 datasets at each n and 96 trait-by-tier uniqueness estimates per n (12 datasets x 2 tiers x 4 traits). The two-size summary is a separate paired description but shares its seed-1713 observations with the primary set.

The 23 stale-runner invocations and one missing-script startup failure are preserved as setup failures. They did not invoke a model fit and are excluded from the 84 fit-object denominator. No failed fit was replaced. The old mask-count discrepancy is resolved by the design and all 84 saved objects: `4n` observed plus `4n` omitted cells at each n, as listed above.

## Results

Primary matched baseline, pooled over the 96 tier-by-trait uniqueness estimates at each n:

| n per lineage | Fit datasets | Pooled RMSE | Mean absolute error | Estimates below 1e-6 |
|---:|---:|---:|---:|---:|
| 64 | 12 | 0.3141577 | 0.2729990 | 27/96 |
| 128 | 12 | 0.2543966 | 0.2185293 | 18/96 |
| 256 | 12 | 0.2148300 | 0.1814670 | 10/96 |

Paired absolute error was lower for 60/96 components at n=128 than n=64, 58/96 at n=256 than n=128, and 65/96 at n=256 than n=64. The trend supports improving uniqueness recovery with larger n in this well-separated setting. Ten estimates remained below `1e-6` at n=256. Twelve datasets per size do not establish consistency or an approximately normal sampling distribution.

For the n=64 controls, weak separation had pooled RMSE 0.399107, mean absolute error 0.360120, 57/96 estimates below `1e-6`, 60/96 below 0.01, and overlap warnings in 12/12 fits. Boundary truth `psi=0.01` had pooled RMSE 0.016678, mean absolute error 0.012792, 61/96 estimates below `1e-6`, and 65/96 below 0.01. All control fits extracted, including the three nonzero optimizer-code fits. These controls show substantial sensitivity to separation and boundary truth; they do not estimate a sample-size trend outside the baseline setting.

The independent fitted-object audit covered all 84 saved fit objects. It verified source commit and package-source hashes, common DLL identity, observed/missing counts, fixed known SD and map, kernel order (`phy`, `tip`), trait order, named shared/unique/total extraction, and `total = shared + diag(unique)` for each named tier. A local recheck of the 84 copied objects found a maximum absolute identity gap of `2.22e-16`, against a `1e-10` tolerance. Uncertainty availability and interval coverage were not evaluated.

## Commands and check outcome

Exact run schedule and supervisor records are in the copied `output-three-size-extension/schedule-and-supervisor.json` and `output-two-controls/schedule-and-supervisor.json`; the initial paired cohort and feasibility output are in the sibling `output-ladder*`, `output-pre-run`, and `output-attempt2` directories. Local summary tables are in `summary-three-size/`, `summary-controls/`, and `summary-final/`.

The following read-only audit was run against those copied RDS objects on the Mac. It asserted the 84-object and 83-key denominators, successful extraction, common DLL hash, mask counts, fixed known SD, and all named covariance identities; output was 60 baseline fits, 12 weak controls, 12 boundary controls, and maximum identity gap `2.2204460492503131e-16`.

```sh
Rscript --vanilla -e 'files <- list.files(".unlazy/two-kernel/evidence/totoro", pattern="[.]rds$", recursive=TRUE, full.names=TRUE); xs <- lapply(files, readRDS); keep <- vapply(xs, function(x) identical(x$source_commit, "72856efae74971a155fed9cb0727f190bba754b5"), logical(1)); xs <- xs[keep]; stopifnot(length(xs) == 84L, all(vapply(xs, `[[`, "", "status") == "extracted"), length(unique(vapply(xs, `[[`, "", "dll_sha256"))) == 1L); keys <- vapply(xs, function(x) paste(x$setting, x$n_per_lineage, unname(x$seeds[["data"]]), sep="/"), ""); stopifnot(length(unique(keys)) == 83L); for (x in xs) { stopifnot(sum(x$mask) == 4L*x$n_per_lineage, sum(!x$mask) == 4L*x$n_per_lineage, abs(x$estimates$fixed_sigma_eps[[1]]-x$design$sigma)<1e-12, all(is.na(x$estimates$fixed_sigma_map))); for (tier in c("phy","tip")) stopifnot(max(abs(x$estimates$total[[tier]] - x$estimates$shared[[tier]] - diag(as.numeric(x$estimates$unique[[tier]]),4))) < 1e-10) }; print(table(vapply(xs, `[[`, "", "setting"), vapply(xs, `[[`, 0L, "n_per_lineage"), vapply(xs, `[[`, 0L, "convergence")))'
```

Commands used for the source/build and remote status checks:

```sh
R CMD INSTALL --preclean --no-multiarch --with-keep.source .
shasum -a 256 .unlazy/two-kernel/evidence/source-72856ef.tar .unlazy/two-kernel/evidence/totoro/gllvmTMB.so
gh run view 43992588472 --json headSha,event,conclusion
gh run view 43992588587 --json headSha,event,conclusion
gh run view 43992940590 --json conclusion,headSha,jobs
```

PR #1803 was at head `72856efae74971a155fed9cb0727f190bba754b5`. PR R-CMD-check run `43992588472` failed Ubuntu shard 2 on attempts 1 and 2; PR coverage run `43992588587` failed Ubuntu shard 2. Both failures segfault in `TMB::MakeADFunObject()` while `tests/testthat/test-va-all-family-compiled.R` rebuilds the compiled VA objective. The failing test and `R/va-r3-proto.R` are byte-identical to the PR base. Full workflow-dispatch R-CMD-check run `43992940590` passed Ubuntu, macOS, and Windows on that head. The failures are outside the two-kernel source change, but the PR workflows remain red and PR #1803 must not be treated as merge-ready.

The VA lane owner identified by GitHub is Shinichi Nakagawa (`itchyshin`), maintainer and author of merged [PR #949](https://github.com/itchyshin/gllvmTMB/pull/949), from branch `cursor/va-arc1-merge-fence-20260807`. Cursor is listed as co-author on the PR commits. The coordination needed is with Shinichi as maintainer/PR author; this receipt does not claim that the segfault has been fixed.

**Claim boundary:** This receipt supports the specified likelihood/oracle, extraction, and exploratory recovery facts only. It does not establish broad parameter recovery, consistency, approximate normality, uncertainty availability, interval calibration, or a green PR check suite. No manuscript files were changed.

## Receipt review

**Style:** 2/10, medium confidence; this is a concrete technical receipt, and it names model settings, denominators, outcomes, and limits. **Genre/coverage:** Internal package check-log; the full receipt was read. **Evidence/repair:** The seed overlap and repeated feasibility fit are stated alongside their counts, so readers can distinguish fit objects from distinct data seeds; no further edit needed. **Gates:** Science = pass for the reported equations/design against the saved generator and fits; facts = pass for the denominator and identities against all 84 local RDS objects; references = pass for the linked PRs and run IDs. **Provenance:** Self-review of this receipt, 2026-11-16, after seeing its source records and fitted objects; no held-out writing controls were used.
