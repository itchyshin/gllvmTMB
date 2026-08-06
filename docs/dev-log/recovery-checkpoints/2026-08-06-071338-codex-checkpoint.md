# Recovery checkpoint — VA(GH) H = 7 scalar-family Arc 1

**Timestamp:** 2026-08-06 07:13 MDT
**Status:** PRESERVED, NOT COMPLETE; Gate E is not PASS
**Branch:** `codex/va-gh-all-families`
**Worktree:** `/private/tmp/gllvmtmb-va-gh-all-families`
**Base:** `62f5809e` (`origin/claude/va-ac-curvature`)

## Why this checkpoint exists

The parent session reached the D-76 context boundary after three compactions. Work stopped at the
next safe file boundary. No new agent, literature/media job, compute campaign, or Arc 2 job was
started. This checkpoint preserves Arc 1 without weakening Gate E or claiming public readiness.

## Current implementation state

The private VA R3 template and R plumbing now cover all 18 scalar family/link cells (`family_id`
0:15; three binomial links), using exact expectations where analytic, GH where required, and hybrid
expectations for hurdle/delta families. `family_id = 16` multinomial remains deliberately outside
this scalar programme. H = 7 is implemented and tested as a candidate, not promoted as the public
default.

Fixed-effect VA-Wald inference uses the profiled-Schur covariance on healthy single-tier fits and
fails closed otherwise. Existing `getLV(se = TRUE)` latent posterior SD output is retained. A
private `match_laplace_residual_sd = TRUE` comparator mode ties pure Gaussian or pure lognormal VA
residual scales to the single Laplace nuisance scale. It deliberately rejects a mixed
Gaussian/lognormal comparator because the two VA parameter vectors cannot yet be cross-tied.

The public fence has not moved: `va_H = 61`, pure binomial-logit `auto` routes to JJ, and the
integration fence still names only Gaussian/binomial-logit/Poisson. NEWS, roxygen/Rd, reference
pages, and broader public documentation have not been promoted.

## Modified and new files

Implementation:

- `R/approximation-engine.R`
- `R/va-intervals.R`
- `R/va-methods.R`
- `R/va-r3-proto.R`
- `R/va-routing.R`
- `inst/tmb/gllvmTMB_va_r3.cpp`

Tests:

- `tests/testthat/helper-va-all-family-oracles.R`
- `tests/testthat/test-va-all-family-compiled.R`
- `tests/testthat/test-va-all-family-light-fits.R`
- `tests/testthat/test-va-all-family-oracles.R`
- `tests/testthat/test-va-intervals.R`
- `tests/testthat/test-va-mixed-family.R`
- `tests/testthat/test-va-ordination.R`
- `tests/testthat/test-va-probit-adsafety.R`
- `tests/testthat/test-va-r3-prototype.R`
- `tests/testthat/test-va-routing-oracle.R`

Design and preservation records:

- `docs/design/110-va-gh-h7-all-scalar-families.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-06-va-gh-h7-arc1-checkpoint.md`
- this checkpoint

Incomplete Arc 2 scaffold, frozen and not executable:

- `dev/va-gh-h7-campaign/README.md`
- `dev/va-gh-h7-campaign/drac-array.sbatch`
- `dev/va-gh-h7-campaign/launch-totoro.sh`
- `dev/va-gh-h7-campaign/prepare-runtime.sh`
- `dev/va-gh-h7-campaign/run-cell.R`

Before preservation records, the tracked diff was 12 files, 1,046 insertions and 530 deletions;
the statistic excluded the untracked files listed above.

## Checks actually run

- `devtools::test(filter = "va-all-family-(oracles|compiled)")`: 160 pass, 0 fail,
  0 warning, 0 skip (~21.9 s).
- `devtools::test(filter = "va-all-family-light-fits", stop_on_failure = FALSE)`: 174 pass,
  0 fail, 0 warning, 0 skip (27.8 s, including compilation). All 18 pure cells, a mixed-family
  fixture, and a two-tier fixture passed the unchanged health/recovery gates at H = 7.
- `devtools::test(filter = "va-r3-prototype", stop_on_failure = TRUE)`: final run 624 pass,
  0 fail, 0 warning, 0 skip (47.4 s).
- `devtools::test(filter = "va-intervals")`: final run 101 pass, 0 fail, 0 warning,
  0 skip (29.4 s).
- `devtools::test(filter = "va-mixed-family")`: 24 pass, 0 fail.
- `devtools::test(filter = "va-control-exposure")`: 33 pass before the final core changes;
  the public defaults were not changed.
- The combined ordination/routing/probit run found one stale expected family label, which was
  patched. The combined suite was not rerun after that last patch and is therefore not claimed
  green here.
- R parse checks passed for changed R files and `dev/va-gh-h7-campaign/run-cell.R`.
- `bash -n` passed for the three campaign shell scripts.
- `git diff --check`: PASS immediately before writing this checkpoint.
- The hub `check-after-task.R` validator initially rejected noncanonical headings; the report was
  repaired to the live 12-section contract and the final validation passed.

Deliberately not run: full `devtools::test()`, `devtools::document()`, pkgdown checks/article
renders, `R CMD check`, cross-OS CI, Totoro, DRAC, or any gllvm/GLLVM.jl campaign.

## Failures and corrections observed

- The legacy prototype suite initially had 136 failures and 23 warnings from schema drift. The
  implementation and tests were reconciled; two later stale optimizer expectations were corrected
  before the final 624-pass run.
- The first interval fixture fell outside the variance-domain health gate. The deterministic DGP
  was repaired without relaxing the gate; two attribute assertions were then corrected.
- Initial light fits exposed NB2, Student-t, truncated-NB2, delta-Gamma, ordinal, and mixed-family
  weaknesses. Fixtures/sample sizes were strengthened without relaxing recovery gates. NB2 alone
  required explicit L-BFGS-B routing; a blanket optimizer switch was rejected.
- Independent review found that production VA has per-trait Gaussian/lognormal scales while the
  Laplace engine uses one shared `log_sigma_eps`. The private pure-family matching mode records and
  controls this comparator boundary.
- The Arc 2 scaffold failed adversarial audit: public-fence incompatibility, repeated dirty-tree
  compilation, unbound PASS receipts, redundant task geometry, weak Laplace health checks, omitted
  family-parameter truth, non-transactional outputs, lost trait detail, incorrect latent alignment,
  and hard-coded DRAC resources. Repair began but was interrupted. Its README now says it is
  incomplete and must not be submitted or executed.
- The stale historical comment `R/integration-fence.R:38` still calls probit "family code 4". The
  current all-family registry uses family 1 plus `link_id = 1`; correct this during Gate E
  reconciliation, not in this preservation-only boundary.

## Review and process state

Curie's independent oracle/light-fit work is complete and green. Gauss's review found the residual
scale comparator mismatch and confirmed the core arithmetic/AD checks, but the final independent
18-cell likelihood verdict was interrupted. The campaign audit returned NOT READY and its attempted
repair was interrupted. No reviewer sign-off establishes Gate E.

No Codex child or unified-exec session is active at this checkpoint; the two unfinished children
were interrupted after their state was collected. An operating-system process inventory could not
be obtained because `ps` is denied by the sandbox. No Totoro/DRAC job was launched.

The required pre-edit check found only base commit `62f5809e` in
`git log --all --oneline --since="6 hours ago"`. `gh pr list --state open` failed because
`api.github.com` was unreachable, so remote PR collision status remains unverified.

## Single next action

In a fresh Sol/high statistical parent task, complete and record the independent Gate E likelihood
and routing review across all 18 scalar cells. This includes rerunning the combined
ordination/routing/probit targets after the last patch and reconciling the stale probit family-code
comment. Do not repair or launch Arc 2 and do not flip H = 7/public-family defaults until a durable
per-cell Gate E verdict exists.

Copy-paste continuation prompt:

> Continue gllvmTMB VA(GH) H=7 from
> `docs/dev-log/recovery-checkpoints/2026-08-06-071338-codex-checkpoint.md` on branch
> `codex/va-gh-all-families`, worktree `/private/tmp/gllvmtmb-va-gh-all-families`. Read the paired
> after-task report first. Your single next action is to complete and record the independent Gate E
> likelihood/routing review for all 18 scalar cells, including rerunning the combined
> ordination/routing/probit targets and resolving the stale probit family-code comment. Do not
> weaken Gate E, launch Arc 2, or promote public H=7/default-family routing before a durable Gate E
> PASS. Keep the statistical parent/core verifier on Sol/high; route only bounded support work to
> Terra/medium or Luna/low with fresh self-contained briefs, and batch approval-boundary actions.
