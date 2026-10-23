# After-task: AA-03 Gaussian latent admission

## 1. Goal

Establish or refuse one exact ordinary native-Laplace Gaussian rank-1
`latent(unique = TRUE)` point-estimation statement at `n = 240`, without
changing any broader validation or release boundary.

## 2. Implemented

Added archive-bound smoke and Totoro production runners, retained the completed
1,600-attempt evidence packet, and recorded the matched current
`glmmTMB::rr() + diag()` comparator. The supported statement is:

> For the exact ordinary native-Laplace, three-trait complete-data Gaussian
> rank-1 `latent(unique = TRUE)` design at 240 units, retained production
> evidence supports point estimation of fixed effects and rotation-invariant
> shared and total covariance, including diagonal Psi targets.

**Mathematical contract:** no public R API, likelihood, formula grammar, family,
NAMESPACE, generated Rd, vignette, or pkgdown navigation change. The assessed
targets are fixed effects and `Sigma = Lambda Lambda^T + Psi` (shared/total
covariance plus diagonal `Psi`); raw loading orientation is excluded.

## 3. Files Changed

- `inst/sim/cran07-aa03/launch-smoke.R`, `run-smoke.R`,
  `launch-totoro-production.sh`, and `run-production.R` provide the
  archive-bound, fail-closed simulation plumbing.
- `docs/dev-log/release/2026-08-12-aa03-gaussian-latent-admission-contract.md`
  records the frozen scope and completed-evidence status.
- `docs/dev-log/simulation-artifacts/2026-08-12-aa03-smoke/README.md` records
  the archive smoke receipt.
- `docs/dev-log/simulation-artifacts/2026-08-12-aa03-production/` retains the
  manifest, production gate/receipt, comparator receipt, 1,600-file checksum
  inventory, and reader-facing internal audit note.
- `docs/dev-log/check-log.md` carries the concise AA-03 receipt after the
  remote #956 head; AA-03 was rebased onto that branch to avoid a competing
  append.
- This after-task report and the paired plan-versus-actual note complete the
  dev-log closure.

No README, NEWS, ROADMAP, known-limitations, design-register status, vignette,
roxygen, Rd, or pkgdown file changed. No convention changed; the AGENTS.md
Rule #10 cascade is not applicable.

## 3a. Decisions and rejected alternatives

The generic v4 `publicly_promotable` field is not an AA-03 release signal.
The historical v4 archive was not pooled with the fresh-source batch. MSPL,
iSDM, VA, AGHQ, EVA, n=60, correlation-stress, boundary/Psi, interval, and
release/platform work were deliberately deferred.

## 4. Checks run

- Archive-bound smoke: one `g_latent_n240` fit from source archive
  `0c862fa...3430`, usable with 30 estimand rows.
- Approved Totoro batch: 1,600 expected/attempted/terminal; 1,598 usable; two
  retained unusable false positives; 1,600 PD Hessians; cell `PASS`.
- `TMPDIR=/tmp Rscript --vanilla -e 'Sys.setenv(GLLVMTMB_CRAN07_RECERTIFY = "true"); testthat::test_file("tests/testthat/test-cran07-core-comparators.R", reporter = "summary")'`:
  completed; six individual exact tests intentionally skipped because the
  fail-closed recertification ledger owns them.
- Direct exact current comparator: `cmp07-gaussian-latent-n240` passed with
  objective difference `2.680e-08`, maximum fixed-effect difference
  `8.939e-06`, maximum total-Sigma difference `5.085e-06`, maximum Psi
  difference `1.036e-05`, and residual-SD difference `9.519e-07`.
- `git diff --check`: passed. The normal-vignette artifact/platform ladder,
  `devtools::check()`, pkgdown checks, and package-wide tests were not run:
  no package/runtime or reader-facing surface changed, and this is explicitly
  not a release decision.

## 5. Tests of the tests

The production runner checks the requested worker count against verified host
capacity, writes one RDS per attempt, and the summarizer requires an exact
manifest-to-attempt bijection before `complete = TRUE`. Two pre-attempt launcher
failures exposed the host-core discovery path and were retained; the successful
run passes capacity from the verified shell context. The comparator is an
independent `glmmTMB::rr() + diag()` model with the same rank and diagonal Psi.

## 6. Consistency audit

- `rg -n 'CRAN07-AA-03|g_latent_n240|Gaussian.*latent' docs/design/35-validation-debt-register.md docs/dev-log/known-limitations.md docs/dev-log/release/2026-08-12-aa03-gaussian-latent-admission-contract.md` confirmed the register stays `partial` and the contract keeps the excluded rows explicit.
- `rg -n 'publicly_promotable|characterization-only|partial|release' docs/dev-log/simulation-artifacts/2026-08-12-aa03-production/README.md docs/dev-log/release/2026-08-12-aa03-gaussian-latent-admission-contract.md` confirmed the generic flag is disclaimed and no release claim remains.

## 7. Roadmap tick

N/A — this is an internal conditional-evidence packet; no public roadmap row changed.

## 8. What did not go smoothly

The first two Totoro launches failed before simulation due to R seeing an
incorrect host-core count. The repair made that capacity an explicit launcher
input, then rebuilt, rehashed, and re-smoked the archive before the production
batch. A draft initially mislabelled the two Sigma bias values as fixed-effect
bias; independent review caught and corrected it before commit.

## 9. Team learning

**Rose:** separated a numerically passing cell from an admissible claim and
required the current comparator plus exact boundary wording.

**Noether:** checked that only rotation-invariant covariance/Psi targets are
claimed and caught the swapped bias labels in the prose receipt.

**Shannon:** reconciled branch, source identity, receipt hashes, and the fact
that new `inst/sim` bytes invalidate any older artifact receipt.

## 10. Known limitations and next actions

`CRAN07-AA-03` remains `partial`. This evidence does not cover raw loading
orientation, intervals, diagnostic sensitivity, n=60, correlation-stress or
boundary/Psi regimes, other ranks/families, missing data, slopes, structured
sources, alternative estimators, or release readiness. Any release proposal
after source-byte changes needs a new normal-vignette artifact and platform
ladder; any new numerical regime needs its own approved compute plan.

**GitHub issue ledger:** inspected open PRs #952, #955, and #956 for collision
only; AA-03 was rebased onto #956's remote head before its separate receipt was
appended. No issue was created, commented on, or closed.
