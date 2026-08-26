# Native mixed-family predictor-informed LV source contract

Date: 2026-08-25

## Receipt status

This receipt freezes the implementation and evidence contract for the
family-wide native-TMB programme. All three preregistered campaigns are now
retained and independently checksum-verified. The 19 named mixed/sentinel
cells pass their point-recovery gates. Seventeen of the 19 pure family/link
cells pass point recovery; pure Beta is held at its frozen convergence gate,
and pure ordinal-probit is held at its frozen shared-covariance gate. All eight
selected mixed Gaussian-anchor archetypes pass their target-wise `B_lv` Wald
calibration gates. These are cell-specific conclusions: no interval conclusion
is borrowed from point recovery, no simultaneous all-target coverage claim is
made, and no arbitrary family mixture is admitted.

Implementation branch:
`codex/lv-mixed-family-all-native@7dd5eec733c42c722fe94be4c0e5a2efe1f4a3c3`.
Exact integrated base:
`origin/main@854d75a4b65b0f9eeb2b5fc5b121af90932bc86d`.
Predecessor Design 73 C1 landed through PR #1210 at the same base.

The pure r200 and mixed r500 calibration campaigns used a source-identical
Linux extraction of the v4 bundle after excluding macOS AppleDouble `._*`
metadata files. The earlier mixed/sentinel r200 campaign used its separately
retained dirty-worktree source snapshot; it did not run from the v4 bundle or
from the eventual landing commit. The original v4 bundle is preserved at
`.unlazy/lv-mixed-family-all-native/source-snapshot-v4-shallow-20260825-01.tar.gz`
with SHA-256
`d295bf14cae6e26036107f181bd2b3ff407303f783122c5127c7eb2da61dcd02`.
The downloaded Totoro result bundle is preserved at
`.unlazy/lv-mixed-family-all-native/totoro-v4-results.tar.gz` with SHA-256
`ba80545e58954500b641a7daed33aae1b38af18d6d392f0bcbbb4f911877393b`.

Source hashes at activation (a pre-edit provenance baseline, not the campaign
source identity):

| Source | SHA-256 |
|---|---|
| `R/enum.R` | `58ab4e7c777749207aaf63d1ef938660f3eb5f9491675ef34720d898861f6a7b` |
| `R/lv-predictor.R` | `612a0183dc376be5aa8d51e500e145c0b76af8953d795a2144fea5a3313a408f` |
| `R/fit-multi.R` | `438f3826b841711935fe85069226e31f20411f11979195ea9e9c5966d30927d5` |
| `src/gllvmTMB.cpp` | `e65134852298afcdb449fd81ed7e00be1ac5fac83a9289437f6ba330bd67412c` |
| `R/extractors.R` | `ab40d8251dae70b29f1a5af8e23ca26cc831fc0c795c5954b2dfa4e22ca5ddca` |
| `docs/design/02-family-registry.md` | `3ac9a1488e843e885f789882ad0821c2ae3e9ce10d4c9883c442359d70566f96` |
| `docs/design/73-predictor-informed-latent-scores.md` | `1971263d61b94ff8fdb20f2504ad2c8214c8d7db45c3ad10eb77ab973fdf4067` |

## Common symbolic contract

The programme is restricted to the native ML, ordinary unit-tier,
loadings-only, rank-one model

\[
x_i\sim N(0,1),\qquad
u_i=\alpha x_i+e_i,\qquad e_i\sim N(0,1),
\]

\[
\eta_{it}=\beta_{0t}+\lambda_tu_i,\qquad
B_{lv,t}=\lambda_t\alpha,\qquad
\Sigma_{shared}=\Lambda\Lambda^\top.
\]

The exact grammar is
`latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~ x)`, where `x` is one
untransformed numeric unit-level column and this latent block is the only
covariance term. Each named cell uses one registered family/link route per
trait; a single fit cannot mix multiple binomial links.
The ordinary family validator rejects within-trait family or link switching on
the public fit path. The LV-specific fence additionally applies the single-link
rule to the pre-existing pure-binomial C1 route and rejects matrix-valued
columns that would otherwise expand one syntactic predictor into several model
matrix columns.
There is no fixed-effect `x`, response mask, diagonal `Psi`, structured
source/tier, REML, VA, AGHQ, MSPL, Julia route, profile, or bootstrap claim.

The scientific cross-fit targets are trait/contrast-scale `B_lv`, shared
`Sigma`, trait intercepts, and the identity
`score_total = score_mean + score_innovation`. Raw `alpha`, raw `Lambda`, and
raw score signs are not cross-fit targets because the latent axis is sign
indeterminate.

## Source-to-model alignment

| Layer | Authoritative route | Contract |
|---|---|---|
| Symbolic score mean | equations above | one numeric unit predictor shifts the shared rank-one score mean |
| R grammar and admission | `R/lv-predictor.R` | exactly one ordinary unit-tier LV predictor term; existing C1 routes remain, while new pure and named mixed programme cells require rank one, `unique = FALSE`, canonical links, one numeric vector, and a complete response; pure-binomial C1 also keeps one exact link per fit |
| Per-row family data | `R/fit-multi.R:963-986`, passed to preflight near `R/fit-multi.R:1054-1067` | family and link IDs are already available before TMB construction |
| TMB score block | `src/gllvmTMB.cpp:1528-1558` | computes `X_lv_B * alpha_lv_B`, combines mean and innovation, and reports `B_lv_unit = Lambda_B * alpha_lv_B^T` before family dispatch |
| Observation likelihood | family contract near `src/gllvmTMB.cpp:683-727`; row dispatch near `src/gllvmTMB.cpp:2755-2998`; multinomial grouped branch near `src/gllvmTMB.cpp:3205` | likelihood is selected per row; the score-mean algebra is family-neutral, and the retained mixed/sentinel r200 campaign establishes point recovery for the frozen named cells without establishing interval calibration |
| Extraction | `R/extractors.R:689-783` | trait-scale `B_lv_unit` and axis-scale `alpha_lv_B` already exist; the former is primary |

Therefore the first implementation hypothesis is an exact R admission change,
not a TMB likelihood rewrite. Any need to alter `src/gllvmTMB.cpp`, the family
registry, the estimand, rank, or `Psi` contract is a stop gate requiring a
revised plan and TMB likelihood review.

## Seventeen-family adjudication matrix

`R/enum.R:5-22` and the TMB dispatch enumerate the 17 fit-admitted native
family IDs. `Activation state` describes the guard before this lane's R-side
admission change. The last column is the earlier mixed/sentinel-r200 checkpoint
and is retained as preregistration history; the final pure and calibration
verdicts in the next section supersede its campaign-pending wording.

| ID | Constructor and admitted link | Response and nuisance contract | `B_lv` interpretation / contract risk | Activation state | Mixed-r200 checkpoint verdict |
|---:|---|---|---|---|---|
| 0 | `gaussian()` / identity | real response; shared scalar `sigma_eps` | additive conditional-mean effect | pure-family C1 admitted; every mixed route rejects | Pure C1 recovery/Wald retained; named mixed anchors `ADMIT_RECOVERY + ADMIT_UNCALIBRATED` |
| 1 | `binomial()` / logit, probit, cloglog | binary or grouped counts with retained trials; no fitted family dispersion | log-odds, liability, or cloglog scale | pure-family C1 admitted; mixed routes reject | Each pure standard-link C1 cell has recovery/Wald evidence; each named Gaussian-anchored link cell `ADMIT_RECOVERY + ADMIT_UNCALIBRATED` |
| 2 | `poisson()` / log | nonnegative integers; no observation dispersion | log-rate; `exp(B_lv)` is a conditional rate ratio | rejects | Named Gaussian anchor, lognormal pairing, and non-Gaussian sentinel `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 3 | `lognormal()` / log | strictly positive; log-response Jacobian; same scalar `sigma_eps` used by Gaussian | log-median/geometric-mean effect; a Gaussian pairing constrains raw- and log-scale SDs equal | rejects | Named Poisson pairing `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; Gaussian pairing remains excluded; pure programme route awaits pure r200 |
| 4 | `Gamma()` / log | positive; per-trait shape `phi`, CV `1/sqrt(phi)` | log-mean | rejects | Named Gaussian anchor and non-Gaussian sentinel `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 5 | `nbinom2()` / log | counts; per-trait `phi`; variance `mu + mu^2/phi` | log-mean; dispersion is not latent `Psi` | rejects | Named Gaussian anchor `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 6 | `tweedie()` / log | nonnegative with zero mass; per-trait `phi` and `1<p<2` | log-mean; evidence needs a non-boundary power regime | rejects | Named Gaussian anchor `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 7 | `Beta()` / logit | strictly inside `(0,1)`; per-trait precision | logit-mean; endpoints violate support | rejects | Named Gaussian anchor and non-Gaussian sentinel `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 8 | `betabinomial()` / logit | integer successes with retained trials; per-trait precision | logit-mean; beta-binomial heterogeneity is not LV variance | rejects | Named Gaussian anchor `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 9 | `student()` / identity | real; per-trait scale and `df>1` | conditional location; variance language needs `df>2` | rejects | Named Gaussian anchor `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 10 | `truncated_poisson()` / log | integers at least one; parent rate `exp(eta)` | parent log-rate, not log conditional mean after truncation | rejects | Named Gaussian anchor, targeting the parent log-rate, `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 11 | `truncated_nbinom2()` / log | integers at least one; parent mean and per-trait `phi` | parent log-mean, not truncated conditional mean | rejects | Named Gaussian anchor, targeting the parent log-mean, `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 12 | `delta_lognormal()` / current shared hurdle predictor | zero or positive; positive-part log-SD | one constrained `B_lv` acts simultaneously on occurrence log-odds and positive-part log mean; never call it a positive-only or unconditional-mean effect | rejects | Named Gaussian anchor under the frozen shared-eta DGP `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 13 | `delta_gamma()` / current shared hurdle predictor | zero or positive; positive-part CV/shape | the same constrained `B_lv` acts simultaneously on occurrence log-odds and positive-part log mean | rejects | Named Gaussian anchor under the frozen shared-eta DGP `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 14 | `ordinal_probit()` / probit | ordered categories; unit liability residual; ordered free cutpoint spacings | latent-liability shift; no free response residual or diagonal OLRE | rejects | Named Gaussian anchor `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 15 | `nbinom1()` / log | counts; per-trait `phi`; variance `mu(1+phi)` | log-mean; distinct from NB2 | rejects | Named Gaussian anchor `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |
| 16 | `multinomial()` / baseline-category logit | unordered categories; one response expands to `K-1` grouped contrast pseudo-traits | labelled `K-1` baseline-contrast effect vector, never one scalar per original trait | rejects | Named Gaussian anchor with retained contrast labels `ADMIT_RECOVERY + ADMIT_UNCALIBRATED`; pure programme route awaits pure r200 |

## Evidence boundary

Existing mixed-family tests exercise family alignment, likelihoods,
family-aware simulation, Sigma/correlation extraction, and bootstrap plumbing.
They do not contain a known-DGP mixed-family predictor-informed LV recovery
test.

Existing Gaussian and pure-binomial Design 73 recovery/Wald evidence remains
cell-specific. It proves neither mixed-family curvature nor other-family
recovery. Historical COE-04 concerns a different two-kernel recovery problem
and supplies no mixed predictor-informed LV interval claim. GLLVM.jl remains
read-only and its family narratives cannot validate this native route.

Every family must finish with exactly one of:

- `ADMIT_RECOVERY`: the named mixed route has healthy extraction and retained
  recovery evidence;
- `ADMIT_UNCALIBRATED`: point/recovery support is admitted but interval
  calibration is absent or fails;
- `HOLD_NUMERICAL`: the model is coherent but the frozen health/recovery gate
  fails;
- `BLOCK_MODEL_CONTRACT`: the response construction or reported estimand is
  incoherent without a separately approved design change.

A failure in one family does not block coherent families and cannot disappear
inside an aggregate rate.

## Final retained adjudication

The pure r200 campaign retained 3,800/3,800 started and final attempts. It had
3,770 optimizer-converged fits and 3,762 strict point-eligible fits. Seventeen
of 19 pure cells passed every frozen point gate. The two HOLD cells remain in
the denominator and were not retried or tuned:

- `p07-Beta`: `HOLD_NUMERICAL`; 182/200 fits converged (0.91), below the
  preregistered 0.95 convergence threshold. Its eligible point estimates pass
  the frozen `B_lv`, shared-Sigma, intercept, and score-identity thresholds,
  but the route does not earn a pure recovery claim.
- `p14-ordinal-probit`: `HOLD_NUMERICAL`; 200/200 fits converged and its
  `B_lv` targets were healthy, but the shared-Sigma gate failed (the recorded
  `Sigma_shared[1]` bias is 6.5778). It therefore does not earn a pure recovery
  claim.

The separately retained mixed/sentinel r200 campaign contains 3,800/3,800
attempts, 3,800 optimizer convergences, and 3,789 strict point-eligible fits.
All 19 named cells passed the frozen point gates; 11 gradient exclusions remain
visible in the all-attempt denominator. Because this campaign used
`se = FALSE`, it earns no interval conclusion.

The eight-archetype mixed r500 campaign retained 4,000/4,000 started and final
attempts. All 4,000 fits converged and were point-eligible; 3,999 were
interval-eligible. The single non-positive-definite/CI-unavailable attempt was
in the Gaussian + Gamma cell and remains in the denominator. All eight named
cells passed both point and calibration verdicts. The target summary has 71
total rows: 17 distinct trait-scale `B_lv` target rows, 17 intercept rows, and
37 shared-Sigma rows. The `B_lv` rows contain 8,498 eligible intervals; their
coverage was 0.920--0.966 with MCSE
0.0081--0.0121, inside the preregistered inclusive 0.92--0.98 band. The lower
cell-summary `coverage` values are simultaneous all-`B_lv` coverage and are not
the frozen interval oracle; this receipt makes no simultaneous-coverage claim.

The promoted summary and raw-manifest receipts are:

- `lv-mixed-family-all-native-pure-recovery-{cell-summary,target-summary,gate-verdicts,raw-sha256}.csv`/`.txt`;
- `lv-mixed-family-all-native-calibration-{cell-summary,target-summary,gate-verdicts,raw-sha256}.csv`/`.txt`; and
- the earlier mixed/sentinel
  `lv-mixed-family-all-native-recovery-{cell-summary,target-summary,gate-verdicts,raw-sha256}.csv`/`.txt`.

Independent local `shasum -a 256 -c` runs verified all 7,607 pure-manifest
entries and all 8,007 calibration-manifest entries. Raw payloads remain under
the ignored `.unlazy/` evidence tree; the tracked manifests bind every retained
attempt without adding the large RDS payloads to package source.

### Pre-data delta adjudication

The delta contract is resolved for this lane without a TMB change. The current
native likelihood and public `gllvmTMB()` documentation implement a coherent,
constrained shared-predictor hurdle model:

\[
\Pr(Y_{it}>0\mid u_i)=\operatorname{logit}^{-1}(\eta_{it}),
\qquad \eta_{it}=\beta_t+\lambda_tu_i,
\]

and, conditional on occurrence, `delta_lognormal()` uses
`log(Y_it) ~ Normal(eta_it, sigma_t)` while `delta_gamma()` uses a Gamma
positive part with mean `exp(eta_it)`. Consequently
`B_lv,t = lambda_t alpha` is one constrained coefficient with two simultaneous
link-scale meanings: an occurrence log-odds effect and a positive-part log-mean
effect. It is not a positive-only effect and is not an unconditional
response-mean effect.

This is coherent in the present `unique = FALSE` programme because the only
covariance target is `Sigma_shared = Lambda Lambda^T` with
`link_residual = "none"`. No attempt is made to collapse the occurrence and
positive observation-residual scales into `Psi` or a latent-residual
correlation. Design 02's contrary positive-part-only wording was reconciled on
2026-08-25 to match this compiled likelihood. The broader positive-only delta design,
default `+Psi`, total/link-residual correlation, and unconditional marginal
effects remain outside this lane.

The r200 DGP exactly matches this constrained shared-eta likelihood and must
retain the zero and positive counts for every attempt. Near-all-zero or
near-all-positive draws are weak-information/failure observations, not redraw
reasons. A passing point-recovery gate can earn `ADMIT_RECOVERY` and
`ADMIT_UNCALIBRATED`; it cannot earn a Wald or response-scale claim.

The concrete pre-existing evidence pointers are:

- `docs/dev-log/artifacts/methods-superarc/lv-design73-c1-closure-receipt.md`
  for the independently reviewed C1 source/claim boundary;
- `docs/dev-log/artifacts/lv-wald-coverage/2026-06-28-local-r500-summary.csv`
  for retained pure-Gaussian attempted/eligible/MCSE summaries;
- `docs/dev-log/artifacts/lv-wald-coverage/2026-06-30-local-binomial-r500-summary.csv`
  for retained pure-binomial standard-link summaries;
- `tests/testthat/test-lv-gaussian-recovery.R`,
  `tests/testthat/test-lv-bernoulli-depth.R`, and
  `tests/testthat/test-lv-wald-coverage-harness.R` for the focused native C1
  oracles;
- `tests/testthat/test-lv-family-boundary-guard.R` and
  `tests/testthat/test-lv-native-nongaussian-guard.R` for the current
  fail-closed family boundary;
- `docs/dev-log/after-task/2026-06-19-coe04-mixed-family-recovery.md` for the
  explicitly non-transferable two-kernel recovery precedent; and
- `docs/design/73-predictor-informed-latent-scores.md` for the current Julia
  and native separation. GLLVM.jl itself is not an implementation or evidence
  dependency in this programme.

## Frozen programme allow-list

The R guard admits no arbitrary family mixture. Beyond the existing pure
Gaussian and pure standard-link binomial C1 routes, the family-wide programme
is exactly:

- each pure family ID 2--16;
- Gaussian plus one candidate ID in 1, 2, or 4--16;
- Poisson plus lognormal, avoiding the scientifically incoherent equality of
  raw-Gaussian and log-response residual scales;
- the Poisson + Gamma + Beta non-Gaussian sentinel; and
- Gaussian + binomial under logit, probit, or cloglog.

All new cells are native ML, rank one, loadings-only, and complete-response.
Gaussian + lognormal, arbitrary non-Gaussian pairs, and every other
three-family set still reject. This is implementation scope, not a claim that
every row has passed recovery.

## First proof cell

The first and only initially admitted implementation candidate is:

- Gaussian identity plus multi-trial binomial logit;
- complete balanced response;
- one numeric unit predictor;
- rank one and `unique = FALSE`;
- native ML/TMB only;
- no fixed RHS predictor or any deferred surface.

The first slice admitted only that named family/link pattern. The subsequent
family-wide parser slice now implements the frozen allow-list above while
continuing to reject `K>1`, default `+Psi`, masks, factor/missing LV
predictors, fixed `X + X_lv`, REML, structured sources/tiers, and arbitrary
family combinations.

The first route-health fit requires a stated local estimate and an inspected
pre-run command. It is not recovery evidence. Every attempted fit, warning,
error, convergence state, gradient, Hessian/`sdreport` state, and elapsed time
must be retained.

The first three-attempt corrected canary passed 3/3 optimizer convergence,
finite `B_lv` and shared `Sigma`, exact family/link routing, zero score-identity
residual, and `fit$use$diag_B == FALSE`. Its complete five-run development
denominator, including the installed-package preflight failure and two
harness-extraction failures, is retained at
`.unlazy/lv-mixed-family-all-native/canary-receipt.md`. This remains
route-health evidence only.

## All-family route-health receipt

The inspected local driver enumerated 38 frozen one-attempt routes: 19 pure
family/link routes, 18 named mixed pairs, and the Poisson + Gamma + Beta
sentinel. Its generator-only pre-run passed support and constructor checks for
38/38 seeds in 4.4 seconds. The full local wave was estimated at 8--20 minutes
and completed in about 30 seconds.

The initial all-attempt table retains 38/38 rows. Thirty-six routes were fully
healthy. Pure and Gaussian-anchored multinomial failed during construction
because the draft harness passed an all-ones weights vector sized before
multinomial category-to-contrast expansion. Repository multinomial fixtures
omit weights. The two failures remain retained; a separate two-row rerun with
`weights = NULL` for family 16 passed both routes. The honest development
denominator is therefore 40 route-health attempts: 38 initial attempts plus
two corrections, never 38/38 after silently replacing failures.

Across the final route for every family ID:

- optimizer convergence was zero and the objective finite;
- the maximum gradient was below `0.01`;
- family and link IDs matched the frozen route;
- trait/contrast-scale `B_lv`, shared `Sigma`, and intercepts were finite;
- the score identity residual was at most `2.85e-11`;
- `fit$use$diag_B` was false;
- `extract_lv_effects(type = "trait_effect")` and
  `extract_Sigma(part = "shared", link_residual = "none")` succeeded; and
- multinomial labels remained `category:2` and `category:3` (plus the Gaussian
  label in the mixed cell), with 2-by-1 or 3-by-1 `B_lv` payloads.

The retained tables live under ignored
`.unlazy/lv-mixed-family-all-native/route-health-all-families/` and
`route-health-multinomial-rerun-02/`. These results establish construction and
payload health only. They do not replace the frozen r200 recovery denominators
or justify interval claims.

## Independent audit conclusion

The current code contains the family-neutral `B_lv` algebra and family-aware
row likelihoods needed to attempt a bounded R-side admission. It does not yet
contain retained recovery evidence for any mixed predictor-informed LV claim.
The route may proceed without a TMB edit. Truncated targets remain parent-scale,
delta targets use the constrained shared-eta interpretation above, and
multinomial targets remain labelled baseline-category contrasts; none is a
blanket reason to stop coherent families.

## Retained r200 recovery verdict

The maintainer approved the exact remote campaign as
`APPROVE TOTORO MIXED-LV R200 RECOVERY: 40 WORKERS, 3,800 ATTEMPTS`.
The source-pinned Totoro snapshot started at `2026-08-26T00:50:06Z` and
finished at `2026-08-26T00:52:31Z` with launcher exit zero. It produced one
started record and one final record for every planned task: 19 cells times
200 replicates, or 3,800/3,800 attempts. All 3,800 optimizers converged and
none emitted a warning. The strict point-evidence rule retained 3,789
attempts and excluded 11 only because their maximum gradient was just above
`0.01` (range `0.01002209`--`0.01350697`): cloglog 1, probit 2,
Poisson--lognormal 1, Gaussian--delta-lognormal 3, and
Gaussian--multinomial 4. These exclusions remain in the all-attempt ledger.

All 19 cells passed every pre-frozen point gate without widening a threshold:
complete denominators, convergence at least 0.95, point availability at
least 0.90, absolute B bias at most 0.10, B RMSE at most 0.20, absolute
shared-Sigma entry bias at most 0.15, absolute intercept bias at most 0.10,
and score identity error at most `1e-8`. Across the 166 target summaries, the
largest absolute biases were 0.00946 for `B_lv`, 0.01177 for shared Sigma,
and 0.01084 for an intercept; the largest corresponding RMSEs were 0.06509,
0.10152, and 0.08868. Cell-level point availability ranged from 0.98 to 1.00.

The three byte-identical promoted summaries are:

- `lv-mixed-family-all-native-recovery-cell-summary.csv` (SHA-256
  `0f194c78230a0e0ab847431dcf0dc4f70cee65f1d800e3406bf940b1a3b0386e`);
- `lv-mixed-family-all-native-recovery-target-summary.csv` (SHA-256
  `b10196c439cacaaecd7f15e54cb9baff2846b1a9e01e27d84ecc81b14067d452`);
- `lv-mixed-family-all-native-recovery-gate-verdicts.csv` (SHA-256
  `50cec670461692e20264c8b2db027ae286eb4a0d0257e31834883dc7113ab66a`).

The raw ignored evidence, including all attempt RDS files and the exact
ledger, remains under
`.unlazy/lv-mixed-family-all-native/retained-r200-20260825-02/`.
The runtime sum was 3,249.62 fit-seconds; the median was 0.694 seconds and
the maximum 3.923 seconds under R 4.5.3 on Ubuntu 24.04.4.

The source-pinned verdict for every named recovery cell is
`ADMIT_RECOVERY + ADMIT_UNCALIBRATED`. Gaussian anchors cover each admitted
non-Gaussian family; the three binomial links remain distinct; lognormal is
also anchored to Poisson; Poisson, Gamma, and Beta have the three-family
sentinel; truncated targets remain on their parent scale; delta targets retain
the constrained shared-eta interpretation; and multinomial targets remain
baseline-category contrasts. This is point-recovery evidence only. The run
used `se = FALSE`, so `pd_hessian = FALSE`, zero interval-eligible attempts,
and `NA` calibration verdicts are expected and are not interval failures.
No calibrated Wald, profile, or bootstrap claim is earned here.

The retained source snapshot records the exact dirty-worktree code used by
the campaign rather than pretending the pinned Git HEAD alone contains the
admission patch. In particular, campaign `R/lv-predictor.R` has SHA-256
`e698fbbe9287f52c0b69cab894c50ae9a19bd7588563b4dd324943f094da9ec8`
and embedded MD5 `c0b198d4b2929bfe24e53a2faef5bad3`; the r200 manifest,
runner, and collector have SHA-256 values beginning `e239d056`, `58c2a534`,
and `1f250d8d`, respectively. The final admission logic retains that same
long-format model contract. A post-campaign `traits()` pre-pass repair in
`R/gllvmTMB.R` now creates the per-row family selector when a fully named
family list matches the selected wide response columns. It is outside the
retained r200 source snapshot and is gated before the recursive long-format
fit: the r200 evidence therefore certifies the long-form core route only, not
the translation by assertion. `test-lv-mixed-family-first-cell.R` proves that
the wide and long Gaussian + Poisson calls produce the same ordered family
vector, trait labels, and `B_lv` estimates (tolerance `1e-8`); the evaluated
article demonstrates both reader calls. Explicit missing `family_var`
selectors still fail loud. The v1 campaign
harness remains preserved verbatim in the ignored evidence tree after the
tracked harness advances to v2.

The final admission path is not asserted to be byte-identical to that r200
snapshot. A direct seven-file comparison shows that `R/families.R`,
`R/fit-multi.R`, `R/extractors.R`, `R/extract-sigma.R`, and
`src/gllvmTMB.cpp` are byte-identical. The only final-code differences are:

- `R/gllvmTMB.R` adds the tested named-family `traits(...)` pre-pivot before
  dispatching the same long-format core route; and
- `R/lv-predictor.R` tightens the evidence fence: it rejects every ordinary
  unit-tier intercept-only diagonal companion (including explicit `indep()`
  and compatibility `unique()`), factor/transformed/multi-column LV designs,
  multiple binomial links within one fit, and any extra covariance term.

Neither difference changes the r200 estimand, likelihood, family/link
parameterisation, TMB data, extractor, or admitted long-format formula used by
the campaign. The first is covered by the live long/wide equality test; the
second only closes routes that the retained formula did not use. Therefore
the r200 rows are evidence for the unchanged named long-format core cells, not
evidence that the final Git SHA itself was executed on Totoro.

The tracked raw checksum manifest
`lv-mixed-family-all-native-recovery-raw-sha256.txt` contains 7,622 entries:
3,800 started records, 3,800 final records, ten exact source-snapshot files,
and twelve campaign receipts/summaries. Its own SHA-256 is
`846ff118107d1fa6ae167520c263146e377e6314b94d9af8a4627d228a203def`.
This cryptographically commits the full locally retained evidence tree; the
raw RDS payloads remain local because they are not suitable package-source
artifacts.
