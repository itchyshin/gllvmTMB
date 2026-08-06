# Recovery checkpoint — VA(GH) H = 7 Gate E boundary

**Recorded:** 2026-08-06 07:36 MDT
**Worktree:** `/private/tmp/gllvmtmb-va-gh-all-families`
**Branch:** `codex/va-gh-all-families`
**Preservation base:** `1660b8f8 va: checkpoint H7 scalar-family Arc 1`
**Gate:** E remains **NOT PASS**. Do not promote H = 7, widen the public family fence,
or launch Arc 2.

## Git state at the boundary

`git status --short --branch` before this record:

```text
## codex/va-gh-all-families
 M R/approximation-engine.R
 M R/integration-fence.R
 M R/va-intervals.R
 M R/va-r3-proto.R
 M R/va-routing.R
 M inst/tmb/gllvmTMB_va_r3.cpp
 M tests/testthat/test-va-intervals.R
```

`git diff --stat` before this record:

```text
R/approximation-engine.R           |  4 ++++
R/integration-fence.R              |  2 +-
R/va-intervals.R                   | 11 ++++++---
R/va-r3-proto.R                    | 39 +++++++++++++++++++++++++++++--
R/va-routing.R                     | 47 +++++++++++++++++++++++++++++++++++++-
inst/tmb/gllvmTMB_va_r3.cpp        | 29 +++++++++++++----------
tests/testthat/test-va-intervals.R | 47 ++++++++++++++++++++++++++++++++++++++
7 files changed, 160 insertions(+), 19 deletions(-)
```

This checkpoint and the paired after-task report are the only additional files intended for the
boundary commit, plus the required `docs/dev-log/check-log.md` append.

## Independent Gate E result collected

Three completed reviewers were collected; no new agents were launched. The likelihood review
returned 11 PASS and seven NOT PASS scalar family/link cells at `1660b8f8`:

| Cell | Verdict at `1660b8f8` | Reason when not PASS |
|---|---|---|
| Gaussian / identity | PASS | — |
| binomial / logit | PASS | — |
| binomial / probit | PASS | — |
| binomial / cloglog | PASS | — |
| Poisson / log | PASS | — |
| lognormal / log | PASS | — |
| Gamma / log | PASS | — |
| NB2 / log | PASS | — |
| delta-lognormal / log | PASS | — |
| delta-Gamma / log | PASS | — |
| ordinal / probit | PASS | — |
| Tweedie / log | NOT PASS | fixed power metadata was dropped; eta clamp changed the density |
| Beta / logit | NOT PASS | probability clamp changed the density |
| beta-binomial / logit | NOT PASS | probability clamp changed the density |
| Student / identity | NOT PASS | fixed degrees-of-freedom metadata was dropped |
| truncated Poisson / log | NOT PASS | eta clamp changed the density |
| truncated NB2 / log | NOT PASS | eta clamp changed the density |
| NB1 / log | NOT PASS | eta clamp changed the density |

The independent extreme-tail probe at variational variance `1e-16` found material compiled-minus-
conditional discrepancies in those clamped cells, including about 2.37 log units for Beta and
beta-binomial at eta 30, about `2.34e17` for truncated Poisson and NB1 at eta 40, 12 log units for
truncated NB2 at eta 40, and a Tweedie finite-versus-`-Inf` mismatch caused partly by R-oracle
underflow. Existing tail tests used mild means and did not exercise these clamps.

The test review independently reran:

- `va-(ordination|routing-oracle|probit-adsafety)`: 180 pass, 0 fail/warn/skip;
- `va-all-family-(oracles|compiled)`: 160 pass, 0 fail/warn/skip;
- `va-all-family-light-fits`: 174 pass, 0 fail/warn/skip, all 18 light cells healthy.

The likelihood reviewer also obtained 804/804 on its combined regression target. Multinomial
`family_id = 16` was confirmed excluded in routing, validation, C++, and compiled tests.

## Uncommitted repair attempt

The current diff attempts, but does not yet prove, repairs for all seven NOT PASS cells:

- removes the Tweedie, truncated-Poisson, truncated-NB2, and NB1 eta clamps;
- replaces Beta and beta-binomial probability clamps with stable log-probability shapes;
- carries and pins constructor-supplied Tweedie power and Student degrees of freedom through the
  public VA route and private R3 objective;
- profiles all fitted global family/nuisance parameters in public VA-Wald covariance rather than
  conditioning on them;
- fixes the stale probit family-code comment.

The VA-Wald defect has a discriminating synthetic-Hessian regression test. The seven-cell tail and
fixed-metadata repairs do **not** yet have dedicated regression tests, and therefore do not change
any Gate E verdict in this checkpoint.

## Commands run after the repair attempt

```sh
Rscript --vanilla -e 'files <- c("R/approximation-engine.R", "R/integration-fence.R", "R/va-intervals.R", "R/va-r3-proto.R", "R/va-routing.R", "tests/testthat/test-va-intervals.R"); invisible(lapply(files, parse))'
# Parsed all 6 changed R files.

Rscript --vanilla -e 'devtools::test(filter = "va-(intervals|r3-prototype)", reporter = "summary")'
# The amended TMB template compiled; the command completed without an emitted failure/error.
# The captured session did not emit final counters, so none are invented here.

Rscript --vanilla -e 'devtools::test(filter = "va-r3-prototype", reporter = "summary")'
# The amended TMB template compiled again; the command completed without an emitted failure/error.
# The captured session did not emit final counters.
```

Immediately before the tail/metadata patch, the new VA-Wald test had 109 pass and 0
fail/warn/skip in `va-intervals`. No full package, documentation, pkgdown, check, cross-OS,
Totoro, DRAC, gllvm, or GLLVM.jl run was performed.

## Collision and process state

`git log --all --oneline --since="6 hours ago"` showed only `1660b8f8` and the inherited handover
commit. `gh pr list --state open` could not refresh because `api.github.com` was unreachable; the
earlier lane preflight found no foreign Claude lane but was only weak evidence. Process inspection
via `ps` was denied by the sandbox. All unified local test sessions launched here completed, and no
Totoro/DRAC job was submitted or launched.

## Single next action

Start a fresh Sol/high statistical-parent task at this commit. First add discriminating regression
tests for the seven Gate E repairs (including fixed Tweedie/Student metadata and adversarial tails),
rerun the independent per-cell likelihood/oracle review, and write one durable 18-cell Gate E
verdict. Do not change public defaults/fences or touch Arc 2 unless that review returns PASS.
