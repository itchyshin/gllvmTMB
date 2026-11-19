# Two-kernel Gaussian recovery pilot

15 November 2026. This exploratory study used 12 generated datasets in each of three settings. Both named kernels had a shared rank-one component and a separate trait-specific uniqueness component. The fit fixed the observation-error standard deviation at `sqrt(0.04/3)`. The design and full estimands are in `PROTOCOL.md` and `cases.csv` in this directory.

## Results

| Setting | Scheduled | Extracted | Optimizer code 0 | `near_zero_sd_kernel_diag` | Kernel-overlap warnings | Mean relative C_HP error |
|---|---:|---:|---:|---:|---:|---:|
| baseline | 12 | 12 | 12 | 11 | 0 | 0.489 |
| weak kernel separation | 12 | 12 | 11 | 12 | 12 | 0.339 |
| near-boundary uniqueness | 12 | 12 | 11 | 12 | 0 | 0.287 |
| **Total** | **36** | **36** | **34** | **35** | **12** | not pooled |

All 36 supervisor exit records were zero; this process status is separate from optimizer convergence. Cases 13 and 30 reported optimizer code 1, singular convergence. Every weak-separation case warned that kernel overlap weakens component-specific separation. All cases retained three-start histories. Case fit times ranged from 4.60 to 7.60 seconds.

Among the 12 baseline draws, the mean estimated `phy` uniqueness variance for trait P2 was 0.048 against truth 0.30; 9 of 12 estimates were below `1e-6`. For baseline uniqueness, the eight tier-by-trait bias estimates ranged from -0.252 to 0.0315. The table's cross-block metric is the mean of each draw's relative Frobenius error, including both code-1 fits in their respective settings. These results show frequent boundary estimates and do not establish reliable component recovery.

An independent read-only audit reconstructed all 468 rows of the saved metric table from the case RDS files, including all-extracted and converged-only subsets. The maximum discrepancy in bias or RMSE was `4.44e-15`. It checked each saved mask (256 observed and 256 structurally absent cells), fixed observation SD, two active uniqueness flags, and `total = shared + diag(unique)` for both tiers. The largest total-covariance discrepancy was `2.17e-16`. It reconstructed the true cross-lineage covariance from the saved kernel and trait matrices. These checks do not independently replay the compiled likelihood or establish interval calibration.

## Source and build identity

The clean Totoro build used an archive of base commit `abf3e905fb9e22f5eca9b8dd01c9ea476fde4ee2` plus the then-uncommitted tracked diff. It is not a final committed package release. Its source tar SHA-256 was `072fbd4deb0ccf1e5ed762166399a2d888ff856d4ec17f60ff92b1c6c74dbc26`, and the tracked diff SHA-256 was `27134213e3935d5f1abcbdef9daaa2667d0e7238fc5617b418bd9e66756f42b3`. The RDS build manifest SHA-256 was `b499407aeea117d1afc237b4f61b2af4f215efd83c5b81f9765e25f08948bf16`; its recorded DLL SHA-256 was `1e602d880af4eec8c27a348686f50a7b11f66bee019c69481c154634134e4e6d`. All 36 case files recorded the same manifest and DLL and matching pre- and post-run hashes.

The archived source had no Git metadata. Thus the case files' `head` field contains the literal `HEAD`, and `git rev-parse HEAD` returned status 128. It is not a commit identity. The base commit and tracked diff are recorded in the build receipt and source manifests instead. The build used R 4.6.1 with TMB 1.9.25 at runtime and in the compiler include path. The first install failed on macOS AppleDouble metadata; that log and the successful clean retry were retained.

Raw case RDS files, per-case logs, exit and supervisor records, `final-cases.csv`, `final-estimates.csv`, and `final-metrics.csv` are retained on Totoro under `/home/snakagaw/hsq_work/two-kernel-build-20261115.u4bM1P/timing/`. The parent directory contains `BUILD-RECEIPT.txt`, the source and build-input manifests, `source.tar.gz`, `install.log`, `install-retry.log`, and the staged library. The supervisor timeout probe is documented in `TIMEOUT-PROBE.md`. The first launch failed before generation because the output directory was absent; the directory was created before the retained timing case.

## Limits

Twelve datasets per setting support descriptive diagnostics, not a coverage or uncertainty claim. The design has four Gaussian traits, one fixed observation-error SD, and rank-one shared structure at each of two kernels. It does not establish performance for other data, ranks, kernels, mixed families, Julia, or empirical analyses. Raw directional derivatives at the boundary were not calculated. No failed or nonconverged case was replaced.
