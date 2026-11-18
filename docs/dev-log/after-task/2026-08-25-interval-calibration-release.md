# After Task: Release-complete interval calibration

**Branch**: `codex/interval-calibration-release`
**Date**: 2026-08-25
**Roles (engaged)**: Ada, Curie, Fisher, Noether, Grace, Rose, Shannon, Melissa

## 1. Goal

Replace “an interval route exists” with an evidence-backed terminal disposition
for every current public CI-08--CI-15 route. The lane had to preserve exact
estimands, every failed attempt, all-attempt denominators, and narrow claim
boundaries while completing all safe local and approved remote work.

## 1a. Mathematical Contract

No likelihood, family, formula grammar, C++ parameterisation, NAMESPACE entry,
or public function signature changed. Public status behaviour now fails closed:
every computed `profile_ci_total_variance()` interval is `route-only`, including
the formerly labelled `n_units = 150`, `d in {1,2}` cells, because retained
endpoint evidence cannot establish an exact constrained-refit LR contract.

The PVT-02 target was

\[
V_t = \Sigma_{\mathrm{unit},tt}
    = (\Lambda\Lambda^\top)_{tt} + \psi_t^2,
\]

with a requested two-sided 95% likelihood-ratio profile on `log(V_t)` and all
nuisance parameters reoptimised. CI-09 targeted ordinary unit-tier
`rho_12`. CI-13 targeted the native pinned unrotated standardized loading
`rho[t,k] = Lambda[t,k] / sqrt(Sigma[t,t])` with the full joint delta-method
gradient. CI-14/15 kept unique-Psi slope SD, total marginal slope SD,
phylogenetic-Cholesky slope SD, and loadings-only slope SD as distinct
estimands. None of these targets transfers to a neighbouring family, tier,
rank, sample size, rotation, or interval method.

## 2. Implemented

- Withdrew the historical CI-08 exact-cell labels after Rose showed that the
  same unauditable penalty-refit mechanism affects both historical and new
  campaigns; every computed total-variance profile now returns `route-only`.
- Added executable packet kernels, smokes, verifiers, seed contracts, retained
  attempt builders, remote dispatch, replay, and negative controls for PVT-02,
  CI-09, CI-10, CI-13, and CI-14/15.
- Ran the explicitly approved Totoro and Fir/DRAC envelope, preserving the
  invalid first deployment and all corrected campaign outcomes.
- Retained a 150,019-row all-attempt ledger and independently recomputed 18
  target rows from the archived frozen sources.
- Published a 19-row public-route census and exact target ledger with one of
  `certified`, `limited`, `blocked`, or `refused` on every CI-08--CI-15 route.
- Certified only the structurally free strict-lower symmetric joint-delta Wald
  targets in native pinned unrotated CI-13 cells `(n=150,d=2)`,
  `(n=400,d=1)`, and `(n=400,d=2)` after the independent D-43 panel, for one
  frozen DGP, conditional on eligible fits. The DGP and observed availability
  are now explicit on every claim surface; no other truth-parameter regime
  inherits the result.

## 4. Files Touched

Status and reader boundary:

- `DESCRIPTION`
- `README.md`
- `_pkgdown.yml`
- `cran-comments.md`
- `R/coverage-study.R`
- `R/loading-ci.R`
- `.gitignore`
- `R/profile-derived.R`
- `R/zzz.R`
- `man/gllvmTMB-package.Rd`
- `man/loading_ci.Rd`
- `man/profile_ci_total_variance.Rd`
- `tests/testthat/test-profile-ci-total-variance-export.R`
- `tests/testthat/test-profile-ci.R`
- `vignettes/articles/current-limits.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `docs/design/66-capstone-power-study.md`
- `docs/design/75-inference-route-truth-matrix.md`
- `docs/dev-log/known-limitations.md`
- `docs/dev-log/release/2026-08-08-0.7-release-claim-matrix.md`

PVT-02:

- `dev/pvt02/pvt02-contract.R`
- `dev/pvt02/pvt02-smoke.R`
- `dev/pvt02/pvt02-verify-packet.R`
- `tests/testthat/test-pvt02-contract.R`
- `tests/testthat/test-pvt02-packet.R`
- `docs/dev-log/artifacts/pvt02/2026-08-25-pvt02-pre-run-receipt.md`
- `docs/dev-log/artifacts/pvt02/2026-08-25-pvt02-ultra-plan.md`

CI-09, CI-10, CI-13, and CI-14/15 packets:

- `dev/interval-calibration/ci09/ci09-kernels.R`
- `dev/interval-calibration/ci09/smoke.R`
- `dev/interval-calibration/ci09/verify-packet.R`
- `dev/interval-calibration/ci10/ci10-kernels.R`
- `dev/interval-calibration/ci10/one-replicate-smoke.R`
- `dev/interval-calibration/ci10/verify-packet.R`
- `dev/interval-calibration/ci13/ci13-kernels.R`
- `dev/interval-calibration/ci13/smoke.R`
- `dev/interval-calibration/ci13/verify-packet.R`
- `dev/interval-calibration/ci14-ci15/TRUTH-ALIGNMENT.md`
- `dev/interval-calibration/ci14-ci15/campaign-shard.R`
- `dev/interval-calibration/ci14-ci15/ci1415-kernels.R`
- `dev/interval-calibration/ci14-ci15/run-shard.R`
- `dev/interval-calibration/ci14-ci15/smoke-runners.R`
- `dev/interval-calibration/ci14-ci15/smoke.R`
- `dev/interval-calibration/ci14-ci15/verify-packet.R`
- `tests/testthat/test-interval-calibration-ci09.R`
- `tests/testthat/test-interval-calibration-ci10.R`
- `tests/testthat/test-interval-calibration-ci13.R`
- `tests/testthat/test-interval-calibration-ci14-ci15.R`
- `tests/testthat/test-interval-calibration-claims.R`
- `tests/testthat/test-interval-calibration-seeds.R`

Campaign and replay infrastructure:

- `dev/interval-calibration/claim-contract.R`
- `dev/interval-calibration/seed-registry-contract.R`
- `dev/interval-calibration/verify-claims.R`
- `dev/interval-calibration/verify-seed-registry.R`
- `dev/interval-calibration/remote/aggregate-campaign.R`
- `dev/interval-calibration/remote/build-task-manifests.R`
- `dev/interval-calibration/remote/build-terminal-attempt-ledger.R`
- `dev/interval-calibration/remote/build-terminal-target-evidence.R`
- `dev/interval-calibration/remote/ci10-cost-array.sbatch`
- `dev/interval-calibration/remote/deploy-approved-envelope.sh`
- `dev/interval-calibration/remote/finalize-campaign.sh`
- `dev/interval-calibration/remote/import-post-guard-receipt.R`
- `dev/interval-calibration/remote/install-packet-library.sh`
- `dev/interval-calibration/remote/parse-sbatch-job-id.R`
- `dev/interval-calibration/remote/prepare-ci10-cost-array.sh`
- `dev/interval-calibration/remote/prepare-remote-host.sh`
- `dev/interval-calibration/remote/reconcile-ci10-submission.R`
- `dev/interval-calibration/remote/record-operational-timeout.R`
- `dev/interval-calibration/remote/record-wave-timeouts.R`
- `dev/interval-calibration/remote/run-approved-totoro-sequence.sh`
- `dev/interval-calibration/remote/run-shard.R`
- `dev/interval-calibration/remote/run-totoro-wave.sh`
- `dev/interval-calibration/remote/shard-io.R`
- `dev/interval-calibration/remote/validate-post-guard-receipt.R`
- `dev/interval-calibration/remote/validate-task-manifest.R`
- `dev/interval-calibration/remote/write-session-receipt.R`

Tracked evidence:

- `docs/dev-log/artifacts/interval-calibration/2026-08-25-all-attempt-ledger.csv.gz`
- `docs/dev-log/artifacts/interval-calibration/2026-08-25-combined-pre-run-receipt.md`
- `docs/dev-log/artifacts/interval-calibration/2026-08-25-local-smoke-checksums.sha256`
- `docs/dev-log/artifacts/interval-calibration/2026-08-25-prior-work-receipt.md`
- `docs/dev-log/artifacts/interval-calibration/2026-08-25-pvt02-r50001-cross-root-ledger.csv`
- `docs/dev-log/artifacts/interval-calibration/2026-08-25-seed-collision-receipt.md`
- `docs/dev-log/artifacts/interval-calibration/2026-08-25-target-recomputation.csv`
- `docs/dev-log/artifacts/interval-calibration/2026-08-25-terminal-campaign-evidence.md`
- `docs/dev-log/artifacts/interval-calibration/2026-08-25-totoro-invalid-deployment-incident.md`
- `docs/dev-log/artifacts/interval-calibration/interval-target-ledger.md`
- `docs/dev-log/artifacts/interval-calibration/public-route-census.csv`
- `docs/dev-log/artifacts/interval-calibration/seed-registry.csv`

Closure:

- `docs/dev-log/plan-actual/2026-08-25-interval-calibration-release.md`
- `docs/dev-log/after-task/2026-08-25-interval-calibration-release.md`
- `docs/dev-log/handover/2026-08-25-interval-calibration-release.md`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/design/35-validation-debt-register.md`

`ROADMAP.md`, NAMESPACE, C++, and formula grammar were inspected but not changed
by this lane. The concurrent LV lane released `NEWS.md`, the validation
register, and the check log before this lane claimed and integrated them; no
other lane's edit was reverted.

## 3a. Decisions and Rejected Alternatives

**Decision:** treat route availability and calibration as different facts.
**Rationale:** a callable interval can still have an unidentified estimand,
unverifiable constrained refit, failed source guard, or no retained campaign.
**Rejected alternative:** inherit calibration from nearby cells or from a
mechanical campaign Boolean.
**Confidence:** high; Ask-Brain, repository history, and independent reviewers
all support this boundary.

**Decision:** retain PVT-02 as blocked despite passing numerical gates.
**Rationale:** the retained endpoints cannot prove convergence and exact target
attainment for every constrained refit.
**Rejected alternative:** call the penalty-profile approximation an exact LR
profile because its empirical coverage cleared the threshold.
**Confidence:** high on the block; an exact-profile implementation and a new
campaign would be required to revisit it.

**Decision:** withdraw the historical `n=150,d=1/2` CI-08 labels too.
**Rationale:** those campaigns used the same penalty-refit mechanism and did
not retain distinguishing endpoint convergence or target-fidelity evidence.
**Rejected alternative:** preserve an inherited certificate while blocking
PVT-02 for a mechanism-wide defect.
**Confidence:** high; this is the only internally consistent fail-closed state.

**Decision:** certify three CI-13 tested regimes exactly, while keeping the
route global status limited.
**Rationale:** every free target in those cells passed both gates, the joint
delta-method gradient was checked against finite differences, and the fresh
D-43 panel verified the denominator. The claim is for the frozen DGP,
conditional on eligible fits: intercepts `(-0.20, 0.10, 0.25)`, unique SDs
`(0.70, 0.80, 0.90)`, and loading vector `(0.80, 0.45, -0.35)` for `d=1`, with
second column `(0, 0.70, 0.40)` for `d=2`.
**Rejected alternative:** average across `d`, sample sizes, targets, or
truth-parameter regimes.
**Confidence:** high inside the named native pinned unrotated tested regimes
only.

## 5. Checks Run

- `Rscript --vanilla dev/interval-calibration/verify-claims.R` ->
  `INTERVAL_CLAIMS_OK`.
- The public-route census read-back found 19 rows, every CI id from CI-08 to
  CI-15, no duplicate `route_id`, only the four terminal states, and exactly
  three certified CI-13 route ids -> `ROUTE_CENSUS_OK rows=19 certified=3`.
- In-memory duplicate-id, arbitrary route rename, invalid-state, PVT-02
  `blocked`-to-`limited` drift, and global-CI13 over-promotion mutations were
  all rejected by the exact 19-route/state oracle.
- Terra-high statistical and release reviews passed
  `eacbdc881cf9c74d2e692bb82f5c5c7a3e8cb48e`. A fresh Sol-high review then
  returned `WITHHOLD` because the public CI-13 certificate omitted the frozen
  DGP and eligible-fit condition and `test-profile-ci.R` retained a stale
  `psi_t`/certificate comment. The claim verifier now guards every source and
  generated surface plus each certified census row; final verdicts are rebound
  only after that repair. Those reviews passed at `7cff7e16`; Rose then found
  that the release claim matrix still omitted the word `unrotated`. A failing
  regression test preceded the final fence repair. The exact-SHA Terra release
  statistical, Terra release, and Sol-high rebinds returned PASS at
  `c86968ab9d69cd88f06e8892b4c00f451edd3691`, with no P0--P3 findings. Rose's
  final exact-SHA closure review and Grace's final reproducibility review also
  returned PASS.
- Focused interval suite -> `INTERVAL_FOCUSED_TESTS_OK`.
- Post-fence focused claim/loading/profile replay ->
  `POST_SOL_SCOPE_FOCUSED_OK`; 98 passes, 35 intentional heavy skips, zero
  failures or warnings.
- Ordinary tests were rerun deterministically in four alphabetic shards plus
  the numeric-prefix shard: 112 + 79 + 223 + 108 + 1 = 523 configured files,
  all passed. Configured heavy/On-CRAN/optional skips and warnings remained
  visible.
- `pkgdown::check_pkgdown()` -> `No problems found` after both the primary
  boundary edit and the independent-review repairs.
- `pkgdown::build_article("articles/current-limits", lazy = FALSE)` and
  `pkgdown::build_article("articles/profile-likelihood-ci", lazy = FALSE)` ->
  `AFFECTED_ARTICLES_OK` in 18.6 seconds.
- `devtools::document(quiet = TRUE)` -> `DOCUMENT_OK`; only the pre-existing
  AIC/BIC/anova S3 export warnings appeared. Generated-Rd verification found
  `man/gllvmTMB-package.Rd` with one `\\keyword{}` entry and both
  `man/loading_ci.Rd` and `man/profile_ci_total_variance.Rd` with zero, matching
  their sources.
- Clean target replay -> byte-identical CSV and numerically identical RDS.
  The target CSV SHA-256 is
  `3d204c754d9cada7858c656341a7d8234c018af9a7c874772b666632018f9047`.
- All-attempt ledger read-back -> 150,019 rows; SHA-256
  `f8c1f33308b0ccb9bed684a99a746f415d79f090875756a6eba752e577dfbe4a`.
- Grace's independent final replay found 55,018 unique canonical identities,
  zero duplicate canonical keys, zero missing artefact paths, 175,000 pairwise
  disjoint planned seeds with one exact reviewed historical CI-10 collision,
  and 5.4 GB of retained raw local campaign data. `seed-registry.csv` is the
  frozen pre-run reservation registry; its `reserved; not executed` rows do
  not claim that every reserved packet was launched.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-08-25-interval-calibration-release.md`
  -> recorded after the final prose pass.
- Unlazy packet, claims, and closure ledgers -> rerun with `--reverify`; final
  result recorded in the handover.

The initial monolithic `devtools::test()` run was estimated at 12--25 minutes.
It exceeded that estimate while still in the `m1-*` files and was stopped under
the D-139 overrun rule. It showed no failure before the stop and is not counted
as a full-suite pass; the complete 523-file sharded replay is the full ordinary
test result.

## 6. Tests of the Tests

The pure packet tests challenge target identity, lower-triangular loading
reconstruction, the `psi^2` transform, analytic versus finite-difference
gradients, one-degree-of-freedom roots, disjoint seed windows, all-row
retention, failed-endpoint policy, and fail-closed promotion. CI-09 rejects
missing or too-small realised `n_eff`, incomplete rows, and duplicates. CI-10
keeps bootstrap `multiple_r` separate from profile contrast correlation and
retains inner failures. CI-13 rejects raw/standardized target interchange and
pin mismatches. CI-14/15 retains the old positive-Psi loadings-only fixture as
a negative control. Remote orchestration rejects truncated manifests,
unmarked libraries, source-SHA mismatch, and incomplete aggregation roots.

The release-wide deliberate challenge duplicated a census route identity in
memory; the uniqueness gate rejected it. This proves the passing census gate
is not a vacuous status scan.

## 8. Consistency Audit

- `rg -n 'n_sites|n_units|certified-0\\.94|route-only' R/profile-derived.R`
  -> no retained certification predicate; every computed row is `route-only`
  and unavailable rows are `none`.
- `rg -n 'certified-0\\.94|route-only|no other sample size|likelihood-ratio profile|nuisance' R/profile-derived.R man/profile_ci_total_variance.Rd tests/testthat/test-profile-ci-total-variance-export.R vignettes/articles/current-limits.Rmd vignettes/articles/profile-likelihood-ci.Rmd docs/design/75-inference-route-truth-matrix.md docs/dev-log/artifacts/interval-calibration/2026-08-25-terminal-campaign-evidence.md`
  -> code, help, tests, articles, matrix, and evidence agree on the exact-cell
  boundary and the PVT-02 profile-fidelity block.
- `rg -n 'certified|limited|blocked|refused' docs/dev-log/artifacts/interval-calibration/public-route-census.csv docs/dev-log/artifacts/interval-calibration/interval-target-ledger.md docs/design/75-inference-route-truth-matrix.md`
  -> every promotion is an exact frozen-DGP, eligible-fit-conditional tested
  regime; no global CI-13 or PVT-02 certificate.
- `rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S' R/profile-derived.R man/profile_ci_total_variance.Rd vignettes/articles/current-limits.Rmd vignettes/articles/profile-likelihood-ci.Rmd docs/design/75-inference-route-truth-matrix.md docs/dev-log/known-limitations.md docs/dev-log/artifacts/interval-calibration`
  -> no stale `S_B`/`S_W` notation in affected surfaces.
- `rg -n '\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(|meta_known_V|gllvmTMB_wide' vignettes/articles/current-limits.Rmd vignettes/articles/profile-likelihood-ci.Rmd docs/design/75-inference-route-truth-matrix.md docs/dev-log/known-limitations.md docs/dev-log/artifacts/interval-calibration`
  -> only intentional soft-deprecation descriptions in
  `docs/dev-log/known-limitations.md`; neither changed interval article teaches
  a deprecated alias.
- `rg -n 'gllvmTMB\\(' vignettes/articles/current-limits.Rmd vignettes/articles/profile-likelihood-ci.Rmd`
  -> the long call includes `trait = "trait"`; the paired wide call uses the
  `traits(...)` LHS and correctly has no `trait` argument.
- `rg -n 'CI-0[89]|CI-1[0-5]|certified-0\\.94|route-only|profile_ci_total_variance' README.md ROADMAP.md NEWS.md cran-comments.md docs/dev-log/known-limitations.md docs/design/66-capstone-power-study.md docs/design/75-inference-route-truth-matrix.md docs/dev-log/release/2026-08-08-0.7-release-claim-matrix.md _pkgdown.yml vignettes/articles/current-limits.Rmd vignettes/articles/profile-likelihood-ci.Rmd`
  -> the changed status inventory distinguishes callable CI-08 `route-only`,
  historical/callable census `limited`, PVT-02 campaign `blocked`, and the
  three exact CI-13 tested-regime certificates.

## 7. Roadmap Tick

**Roadmap tick:** N/A. No `ROADMAP.md` row or progress bar changed. The release
programme adjudicated calibration debt rather than changing the public roadmap.

## 7a. Issue Ledger

- [#346, Simulation / coverage framework](https://github.com/itchyshin/gllvmTMB/issues/346)
  was inspected and remains open. This lane advances its CI-08/CI-10 evidence
  debt but does not complete the umbrella or the power capstone.
- [#813, profile-likelihood intervals for communality](https://github.com/itchyshin/gllvmTMB/issues/813)
  was inspected and remains open. Its documented loose-constraint and
  unconverged-refit concern directly supports the PVT-02 profile-fidelity block;
  this lane did not implement the exact nonlinear profile requested there.
- No issue was commented, closed, or created because the approved authority did
  not include public messages and the terminal findings are already durable in
  tracked repository artifacts.

## 9. What Did Not Go Smoothly

The first Totoro deployment omitted `assertthat`. The corrected campaign did
not erase the invalid attempt: all 85,000 rows and the original archive remain
in the operational denominator. CI-14 then exposed a frozen-source provenance
guard and correctly stopped the dependent CI-15 waves. Every CI-10 cost-array
base fit failed before bootstrap, so the programme learned neither successful
nested-bootstrap cost nor coverage.

The lane-lease helper once printed `GRANTED` after its registry write had failed
with `Operation not permitted`. The lease was reissued outside the sandbox and
verified through `--list`; closure treats the first message as a tooling defect,
not ownership evidence.

The monolithic ordinary test suite exceeded its estimate and was stopped. The
deterministic five-shard replay covered all 523 configured files and passed.

For article rendering, the first command used bare article stems; pkgdown's
registry requires `articles/current-limits` and
`articles/profile-likelihood-ci`. Several optional Sass-cache redirection
experiments also failed before knitting. The final exact-name render used the
standard cache, completed both articles, and changed no tracked file.

## 11. Team Learning

**Ada.** Keeping the terminal state as the deliverable prevented “blocked” from
being mistaken for unfinished work. Ada also kept shared-file integration
serialized behind the live LV lane instead of bypassing its lease.

**Curie.** Pure kernels and deliberate malformed-input cases made retention,
seed, and promotion rules testable before remote scale-up. Future packets should
retain this separation between mathematical kernels and expensive fits.

**Fisher.** Fisher separated coverage arithmetic from estimand validity. That
distinction stopped the CI-09 extreme values from being published as a clean
method failure and kept availability descriptive rather than promotional.

**Noether.** Noether identified the load-bearing PVT-02 mismatch: empirical
coverage cannot certify an exact LR profile when constrained refit convergence
and target attainment are not auditable. The same review confirmed why traits
1 and 2 cannot be averaged.

**Grace.** Grace required immutable source-SHA-bound manifests, checksums,
duplicate rejection, and clean-path replay. The byte-identical target CSV and
all-attempt denominator are the evidence that the campaign is reproducible.

**Rose.** Rose caught two release-blocking repeated mistakes: a vacuous census
column assertion and preservation of historical CI-08 labels despite the same
mechanism-wide endpoint defect that blocked PVT-02. The final oracle asserts the
exact 19 route/state map, and every total-variance profile is now route-only.
Rose and the final Sol review then caught a third: a fixed-DGP campaign had
been described as if `n` and `d` alone defined the certified regime. The
repaired claim now names the DGP, eligibility condition, and availability, and
the oracle rejects a certified census row that drops either condition. Rose's
final release-matrix walk then caught the missing `unrotated` qualifier; the
claim verifier and a direct regression test now require it.

**Shannon.** Shannon's lease boundary prevented this lane from overwriting the
concurrent LV lane's validation register and check log. The remaining shared
integration is explicit rather than silently omitted.

**Melissa.** Melissa's plan-versus-actual reconciliation records the invalid
deployment, source guard, test overrun, and exact-cell promotions as deviations
with consequences, not as footnotes hidden by a headline pass.

## 10. Known Residuals

- Every CI-08 total-variance profile remains route-only until an exact
  constrained-refit profile records convergence and target fidelity at every
  endpoint and is recalibrated. This includes the former historical cells.
- CI-09 requires a DGP that identifies the scored unit-tier correlation
  separately from residual variance before any new campaign.
- CI-10 requires a successful small cost preflight before proposing the full
  `18 x 5000 x 499` campaign.
- CI-13 certification is limited to structurally free strict-lower symmetric
  joint-delta Wald targets in the three exact native pinned unrotated
  frozen-DGP regimes, conditional on eligible fits; pinned rows, Fisher-z Wald,
  arbitrary constraints, other truth-parameter values, `n=150,d=1`, rotated,
  unconstrained, and neighbouring cells remain limited.
- CI-14 requires a source-provenance repair and a fresh approved run; CI-15 must
  remain blocked until its predecessor completes.
- CI-11/12 remain typed refusals. MSPL, prediction, missing-data, nonlinear
  profile restoration, LV expansion, new APIs, C++, and random-slope
  point-recovery remain outside this lane.
- The validation-debt register, NEWS, and check-log cascade was serialized
  behind the LV lane, then claimed and integrated only after that owner released
  the exact paths.
- The branch remains local. No push, PR, merge, release, or GitHub issue message
  is authorised by this task.
- No fresh `R CMD check` or 3-OS CI ran after the final claim-only repair. The
  complete 523-file ordinary suite and local documentation checks are the
  bounded evidence; this lane is not a merged or cross-platform package
  release.

## 12. Cross-Product Coverage

This lane covers the exact public CI-08--CI-15 interval routes enumerated in the
19-row route census, their declared estimands, frozen campaign cells, fit/CI
failure denominators, seed identities, and terminal claim states. It covers the
native Laplace ordinary unit-tier CI-08 predicate, the approved PVT-02/CI-09/
CI-13 corrected campaign rows, the CI-10 cost preflight, and the CI-14/15
provenance/predecessor dispositions.

It **does NOT cover** a new estimator, exact nonlinear-profile restoration,
MSPL, prediction or missing-data intervals, latent-variable expansion, rotated
or unconstrained standardized loadings, another family/tier/rank/sample size,
random-slope point recovery, bootstrap comparison for PVT-02, new APIs, C++, or
formula grammar. It also does NOT turn a campaign block into a claim about the
underlying statistical method outside the frozen design.
