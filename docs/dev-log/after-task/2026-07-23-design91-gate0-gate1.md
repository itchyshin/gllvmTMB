# After Task: Design 91 Gate 0/1 private EVA/VA envelope

## 1. Goal

Create an independent, upstream-only Design-91 packet for a
row-and-trait-support-conditioned Bernoulli-logit q=2 GLLVM, with EVA and VA
as paired numerical-health arms.  Gate 0/1 was limited to the contract and
non-running infrastructure; it was not a source installation, fixture
materialisation, smoke fit, or campaign.

## 2. Implemented

The new packet pins CRAN `gllvm` 2.0.13, a 48-cell support-conditioned grid,
the quadrature-calibrated q=2 DGP, and paired `method = "EVA"` / `method =
"VA"` receipts.  A candidate matrix must have both outcomes in every row and
trait before it can be frozen.  EVA and VA each receive an independent health
receipt; VA cannot rescue a failed EVA receipt.  The smoke driver fails closed
unless `D91_AUTHORIZE_SMOKE=YES` is set.

### Mathematical Contract

The design uses \(U_i\sim N_2(0,R_\rho)\) and
\(Y_{it}\sim\mathrm{Bernoulli}\{\mathrm{logit}^{-1}(b_t+
\lambda_t^\top U_i)\}\), with rank-two `lambda` and quadrature-solved
marginal intercepts.  The new estimand is explicitly conditional on row and
trait support.  There is no public API, likelihood, formula grammar, family,
or `src/gllvmTMB.cpp` change.

## 3. Files Changed

- `docs/design/91-upstream-eva-va-row-support-envelope.md` — private contract
  and claim boundary.
- `dev/design91-eva-va-envelope/design91-config.json` — immutable grid,
  controls, seeds, and health rule.
- `dev/design91-eva-va-envelope/source-lock.json` — fresh CRAN source and
  implementation checksums.
- `dev/design91-eva-va-envelope/design91-producer.R` — non-running producer
  and paired receipt writer.
- `dev/design91-eva-va-envelope/telemetry-schema.json` and
  `check-gate01.R` — receipt contract and mechanical verifier.
- `dev/design91-eva-va-envelope/run-smoke.R` plus empty fixture/result roots
  — explicit closed Gate-2 entry point.
- `docs/dev-log/check-log.md` and this report — durable Gate-0/1 record.

`README.md`, `NEWS.md`, `ROADMAP.md`, vignettes, man pages, `_pkgdown.yml`,
R package code, and validation-debt rows were not changed because this packet
is private and makes no advertised capability claim.

## 3a. Decisions and Rejected Alternatives

- **Decision**: make VA a paired diagnostic arm, not an admission benchmark.
  **Rationale**: the two approximations have different objectives; paired
  health outcomes can localise a numerical observation without asserting
  objective equality.  **Rejected alternative**: EVA-only receipts would not
  distinguish shared fixture/optimizer difficulty from EVA-specific behaviour.
  **Confidence**: high.
- **Decision**: condition on both row and trait support and exclude the former
  `.10`, `T=12` region.  **Rationale**: the upstream all-zero-row warning in
  the terminal Design-90 receipt made the missing support predicate observable.
  **Rejected alternative**: regenerating Design-90 inputs would alter its
  frozen target and evidence.  **Confidence**: high.
- **Decision**: leave the smoke driver closed after static verification.
  **Rationale**: Gate 2 requires a live-compute checkpoint.  **Rejected
  alternative**: an incidental local fit would consume the one-shot smoke
  evidence before its environment lock is complete.  **Confidence**: high.

## 4. Checks Run

- `gh pr list --state open --limit 30` — completed with no open PRs.
- `Rscript --vanilla -e '...parse...; source(...); stopifnot(nrow(d91_grid()) ==
  48L, ...)'` — PASS; no fixture generated and no model fitted.
- `Rscript --vanilla dev/design91-eva-va-envelope/check-gate01.R` — PASS;
  verified source, producer, config, smoke-driver, and telemetry hashes.
- `Rscript --vanilla dev/design91-eva-va-envelope/run-smoke.R` without the
  authorization variable — expected failure: `Design 91 Gate 2 is closed`.
- `git diff --check` — PASS.

## 5. Tests of the Tests

`check-gate01.R` is a prophylactic static contract test: it catches a missing
packet file, grid drift, changed method pair, source/implementation checksum
mismatch, or an absent smoke authorization guard before any fixture or fit can
be created.  The smoke guard test is the paired rejection case.  The matching
acceptance case is deliberately deferred: setting the authorization variable
would generate fixtures and start live fits, which Gate 2 has not opened.

## 6. Consistency Audit

`rg -n -i 'Design 8[6-9]|Design 90|gllvmTMB|parity|recovery|calibration' docs/design/91-upstream-eva-va-row-support-envelope.md dev/design91-eva-va-envelope`
returned only intended historical fences and prohibited-claim statements.

`rg -n -i 'method.?=.?(EVA|VA)|row.?support|trait.?support|D91_AUTHORIZE_SMOKE' docs/design/91-upstream-eva-va-row-support-envelope.md dev/design91-eva-va-envelope`
returned the intended method, support, and closed-gate declarations.

## 7. Roadmap Tick

N/A — this is a private upstream research packet, not a package roadmap change.

## 8. What Did Not Go Smoothly

The first GitHub CLI request could not reach the API in the restricted
environment.  The required lane check succeeded after approved external access
and found no open pull requests.  No source installation receipt exists yet;
the source tarball is locked, while an isolated binary/library lock belongs to
the live Gate-2 preflight.

## 9. Team Learning

Gauss — kept the target conditional on support rather than treating a warning
as a post-hoc cleaning rule.  Fisher — required paired numerical-health
telemetry without converting VA into an oracle.  Rose — required fresh locks,
non-overwrite roots, and explicit Design-86--90 fences.  Jason's earlier source
map supports ordinary `num.lv = 2`, `num.lv.c = 0` as the narrow upstream
target.

## 10. Known Limitations and Next Actions

No `gllvm` package has been installed into the required fresh isolated library,
no fixture has been materialised, and no EVA or VA model has been fitted.
Design 91 cannot yet support any numerical-health conclusion.  The next action
is a Gate-2 preflight that records isolated-library hashes and, only after the
maintainer opens the smoke gate, executes the four paired smoke fixtures on
Totoro.  A failure stops the design; a pass does not authorize the atlas without
the remaining campaign gate.

## GitHub Issue Ledger

`gh pr list --state open --limit 30` returned no open pull requests.  No issue
was inspected, created, closed, or changed because this is a private
research-design packet without a public package change.
