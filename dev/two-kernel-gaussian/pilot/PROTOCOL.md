# Two-kernel Gaussian recovery pilot

## Aims

This exploratory pilot measures whether two named kernel components and their trait-specific uniqueness variances can be recovered in three specified Gaussian settings. It does not qualify confidence intervals or establish general identification. A future confirmatory study must set precision and coverage gates independently of these results.

## Data-generating mechanism

For species `i`, trait `t` and record `r`, generate independently for each kernel level `s` a shared field `g_s ~ N(0, K_s + 1e-8 I)`, trait-specific fields `u_st ~ N(0, K_s + 1e-8 I)`, and independent record errors `e_itr ~ N(0, 0.04)`. The observed record is `y_itr = beta_t + sum_s(lambda_ts g_si + sqrt(psi_ts) u_sti) + e_itr`. Average the three records within each observed species-trait cell, giving fixed observation SD `sqrt(0.04/3)`. Rows are 64 host and 64 partner species. H1 and H2 are observed only on hosts; P1 and P2 only on partners: 256 observed and 256 structurally absent species-trait cells. The same latent fields are shared across replicate records.

For `A[i,j] = a^abs(i-j)`, `I` identity and `rho = 0.55`, use `K_phy = [[A,rho A],[rho A,A]]` and `K_tip = [[I,rho I],[rho I,I]]`. Both kernels contain bridges. Species ordering is hosts followed by partners. The `1e-8` ridge belongs to each kernel source; observation error is added separately once.

| Setting | a | psi (both levels) | Purpose |
| --- | --- | --- | --- |
| baseline | 0.6 | vectors below | separation control |
| weak | 0.1 | vectors below | weak kernel separation |
| boundary | 0.6 | 0.01 for each trait | near-boundary uniqueness |

`lambda_phy = (0.9,0.8,0.85,0.75)`, `lambda_tip = (0.7,0.9,0.8,0.65)`, `psi_phy = (0.35,0.45,0.40,0.30)`, `psi_tip = (0.40,0.30,0.35,0.45)`, and `beta = (0.1,-0.1,0,0)` in trait order H1,H2,P1,P2. These values reuse the retained source-pinned 7762 study contract, with source ridge added to match the final package's likelihood.

## Alignment

| Symbol | Fit syntax | DGP | Recovery | Truth |
| --- | --- | --- | --- | --- |
| beta_t | `traits(...) ~ 1` | trait means | fixed-effect coefficients, matched by trait | beta above |
| Lambda_s Lambda_s' | `kernel_latent(..., d=1, unique=TRUE)` | shared field times loading | `extract_Sigma(..., part='shared')` | `tcrossprod(lambda_s)` |
| Psi_s | same keyword, `unique=TRUE` | independent trait-specific fields | `extract_Sigma(..., part='unique')` | diagonal values above |
| Sigma_s | same keyword | sum of shared and unique fields | `extract_Sigma(..., part='total')` | shared plus diagonal |
| K_s | named `K` matrix | kernel-correlated Gaussian fields | fixed by design | two block matrices above |
| sigma_epsilon | `known_sigma_eps` | three independent record errors averaged | fixed value / mapping | `sqrt(0.04/3)` |
| C_HP | derived | host/partner cross-covariance | kernel-weighted cross block | sum_s `kronecker(Sigma_s[H,P], K_s[H,P])` |

## Methods and estimands

Fit the exact final staged package build with both named kernels, known observation SD, `missing = miss_control(response='include')`, three starts, `nlminb`, `se = FALSE`, and the same parameter and data ordering in all settings. Compare trait means, each tier's shared, unique and total covariance, and `C_HP` with known truth. Loading signs themselves are not estimands. For the cross block, report absolute Frobenius error and relative error only when truth norm is nonzero.

## Performance and accounting

Schedule 12 fresh replicates per setting (36 total) solely for feasibility and exploratory summaries, not a coverage or precision qualification. Data seeds are 2026111501 through 2026111536, indexed by the immutable cases.csv. The fitter generates jitter offsets from its own fixed internal seed; no user-set optimizer seed is claimed. Never replace a failed or timed-out replicate. Save one result per scheduled case, including seeds, masks, input, warnings, elapsed wall time, optimizer status and objective, restart_history, extracted values, raw failures and source/build identity. Transformed gradients and boundary flags are retained if exposed; raw directional derivatives are explicitly unavailable unless separately computed. Shell logs and exit records cover startup errors and timeouts. Count scheduled, returned, converged and successfully extracted cases separately. Report bias `mean(estimate - truth)`, RMSE `sqrt(mean((estimate-truth)^2))`, bias MCSE `sd(estimate-truth)/sqrt(n)`, plus boundary frequencies and raw outcomes; denominators and missingness must accompany each summary. Twelve replicates do not target a confirmatory MCSE.

## Verification and execution

Before generation or fitting, independently check the analytic observed covariance against explicit Kronecker assembly and controls omitting each uniqueness tier or observation error; verify masks and rank-two observed same-trait kernel patterns. Draw fields independently of package simulation. Save each output atomically and do not overwrite an existing result. Pin all R and C++ source hashes, R version, package version, DLL hash, script hashes and session information. Supply a manually reviewed staged-build RDS manifest with named source_sha256 and dll_sha256 fields; the runner rejects identity mismatches. Matching hashes alone do not prove the binary was built from the stated source, so retain and independently review the clean-build command, log and source snapshot. Verify the staged package is exactly the supplied library. Pin OPENBLAS/OMP/MKL threads to one. Run on Totoro; time case 1 with a 300-second case and stage limit, then run check-first.R on its result and nonempty summary. Verify restart history, beta and Psi names before scaling. Estimate runtime from this source-specific first fit and a 50% margin before scheduling the other 35. Set an enforced stage wall limit no greater than 10800 seconds; case and stage timeout records remain visible. Stop and request approval if the projected stage exceeds three hours. Never run this campaign on GitHub Actions.

The pilot does not provide uncertainty calibration, mixed-family evidence, Julia parity or public-release evidence. Existing unsuccessful results remain unchanged.

Design follows the ADEMP framework of Morris, White and Crowther (2019, doi:10.1002/sim.8086) and the simulation-reporting guidance of Williams et al. (2024, doi:10.1111/2041-210X.14398); verify the latter DOI before using it in publication.
