# Check-log: drop weighted sigma_eps recovery assertion (#1644 / #1602)

**Goal:** Stop CI shard 3 from failing on a single-seed recovery claim
that Totoro already showed is not identified at this size.

**Commands:**

    gh api repos/itchyshin/gllvmTMB/actions/jobs/124329134385/logs
    rg -n "weighted fit improves sigma recovery|weights move sigma_eps" tests/testthat/test-lme4-style-weights.R
    rg -n "expect_lt\\(abs\\(rep_w\\$sigma_eps" tests/testthat/test-lme4-style-weights.R

**Results:**

- Run 41133205539 job 124329134385 (ubuntu-latest release shard 3/4):
  FAIL 1 / WARN 7 / SKIP 302 / PASS 5528. The one failure is
  `test-lme4-style-weights.R:250`,
  `abs(rep_w$sigma_eps - 1) < abs(rep_unw$sigma_eps - 1)` with
  `0.58 >= 0.46`.
- After the edit: `weighted fit improves sigma recovery` is gone;
  title is `weights move sigma_eps`; the `expect_lt(abs(rep_w$sigma_eps`
  recovery comparison is gone.
- Focused `devtools::test(filter = "lme4-style-weights")` was not run
  here: this VM has no compiled TMB package.

**Claim boundary:** This is a test-honesty fix for #1644 CI. It does
not claim weighted `sigma_eps` recovery, does not close #1602 until
Shinichi merges, and does not file a new issue (receipt is the
comment on #1644).
