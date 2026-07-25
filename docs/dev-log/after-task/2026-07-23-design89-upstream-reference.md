# After Task: Design 89 upstream-reference EVA reproducer

## 1. Goal

Determine whether an unmodified, upstream-owned `gllvm` EVA regression fixture
is healthy in this local R/TMB environment.  The question is deliberately
narrow: it does not ask whether a gllvmTMB implementation is correct or ready.

## 2. Implemented

Created a private Design-89 source-lock packet for CRAN `gllvm` 2.0.13 and ran
exactly one upstream fixture, `corWithinLV works / fitlv2ar1cy`, from
`tests/testthat/test-fitgllvm.R`.  The one fit met both upstream assertions,
returned finite objective/parameters/gradient, and had
`max(abs(gradient)) = 0.00168`, below the predeclared 0.05 bound.  The final
Design-89 verdict is **UPSTREAM_REFERENCE_PASS**.

The initial generated JSON/RDS says `UPSTREAM_REFERENCE_STOP` because the
first runner compared an already-logical `fit$convergence` to zero.  Raw
artefacts are preserved unchanged.  The source-locked correction note proves
that `gllvm` stores `fit$convergence` as `optrFinal$convergence == 0` and that
the executed call did not emit the wrapper's non-convergence warning.  No fit
was rerun.

**Mathematical contract:** no gllvmTMB likelihood, parameterisation, formula
grammar, family, public R API, NAMESPACE, generated Rd, vignette, or pkgdown
navigation changed.  The only numerical criterion is the upstream model's
reported TMB gradient diagnostic, `max |g| <= 0.05`.

## 4. Files Touched

- `docs/design/89-upstream-reference-eva.md` — private scope, source fixture,
  frozen gates, and stop boundary.
- `dev/design89-upstream-reference/source-lock.json` — CRAN source, installed
  library, hashes, and execution-runner provenance.
- `dev/design89-upstream-reference/run-upstream-reference.R` — one-call
  reproducer; corrected after execution but not rerun.
- `dev/design89-upstream-reference/results/upstream-reference-result.{rds,json}`
  — immutable raw output of the one call.
- `dev/design89-upstream-reference/results/telemetry-correction.md` — source
  evidence correcting the post-run convergence interpretation.
- `docs/dev-log/check-log.md` and this report — private closeout.

`README.md`, `ROADMAP.md`, `NEWS.md`, `_pkgdown.yml`, `R/`, `src/`, `man/`,
`vignettes/`, and the validation-debt register were intentionally unchanged:
this is not an advertised package capability.  No examples were touched, so
the convention-change cascade is not applicable.

## 3a. Decisions and Rejected Alternatives

**Decision:** use the only explicit upstream `method = "EVA"` regression call
in CRAN `gllvm` 2.0.13 as the Design-89 fixture.  
**Rationale:** it supplies released source, fixture, invocation, and expected
assertions under one authority.  
**Rejected alternative:** create another custom q=2 fixture or alter controls;
that would not answer whether upstream EVA itself works locally.  
**Confidence:** high.

**Decision:** preserve the raw result and correct the convergence interpretation
from locked source without rerunning.  
**Rationale:** `R/gllvm.TMB.R:3310` defines the field as a logical success flag;
the wrong comparison is runner telemetry, not an altered fit.  
**Rejected alternative:** execute a second fit after fixing the runner; this
would violate the one-call gate.  
**Confidence:** high.

## 5. Checks Run

- `R CMD INSTALL --library=/private/tmp/design89-r-lib-y3mIZj --no-multiarch /private/tmp/design89-gllvm-source/gllvm` -> PASS; installed `gllvm` 2.0.13.
- SHA-256 checks for CRAN tarball, upstream test/C++ source, installed
  `DESCRIPTION`/shared object, runner, and raw result sidecars -> PASS.
- `Rscript --vanilla -e 'invisible(parse(file = "dev/design89-upstream-reference/run-upstream-reference.R")); cat("runner-parse: PASS\\n")'` -> PASS.
- `D89_GLLVM_LIB=/private/tmp/design89-r-lib-y3mIZj Rscript --vanilla dev/design89-upstream-reference/run-upstream-reference.R` -> one permitted call completed; its initial telemetry exit was 2 solely because of the later-corrected logical/numeric convergence comparison.
- `Rscript --vanilla -e '... raw-evidence ...'` -> PASS for both upstream
  assertions, finite objective/parameters/gradient, no warnings, and gradient
  bound.
- `git diff --exit-code HEAD -- R src` -> empty; `git diff --check` -> PASS.
- `jq -e '.package == "gllvm" and .version == "2.0.13" ...' dev/design89-upstream-reference/source-lock.json` -> PASS.
- `gh pr list --state open --limit 20` -> not run successfully: the GitHub API
  hostname could not resolve.  No remote PR state was inferred.

## 6. Tests of the Tests

The upstream fixture is a regression test with two retained assertions: rounded
`rho.lv` and latent-score dimensions.  It is a feature-combination check
(EVA + binomial + constrained latent variable + `corWithinLV` AR1), not a new
gllvmTMB test.  The source lock and runner parse checks would catch source or
runner drift before execution.  Full package tests, `devtools::check()`,
documentation, and pkgdown were not run because no package source or public
surface changed.

## 8. Consistency Audit

- `rg -n 'Design 89|UPSTREAM_REFERENCE_(PASS|STOP)|gllvmTMB parity|Design-86|Design 86' docs/design/89-upstream-reference-eva.md dev/design89-upstream-reference` -> only Design-89 scope boundaries and the intentionally retained raw-versus-corrected telemetry distinction.
- `rg -n 'Design 89|EVA' README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md _pkgdown.yml` -> no public Design-89 claim; Design 89 remains private.
- `git diff --exit-code HEAD -- R src` -> no package-engine change.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row changed; Design 89 is a private reproduction packet.

## 7a. Issue Ledger

No relevant open issue; no new issue created.  Remote issue state was not
queried after the GitHub API DNS failure, and this isolated private baseline
does not change a tracked package capability.

## 9. What Did Not Go Smoothly

The first runner assumed a numeric convergence code.  Upstream `gllvm` exposes
a logical success field instead, turning a healthy fit into a false stop in the
postprocessor.  The error was found through source audit after the one call;
the raw result and a transparent correction note are both retained.  GitHub
remote inspection was unavailable because DNS could not resolve the API host.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Jason:** source inventory identified a real upstream EVA regression fixture,
which is stronger baseline evidence than another constructed comparator input.

**Gauss/Noether:** the source-level representation of `fit$convergence` is
load-bearing telemetry semantics; a numerical threshold is only meaningful
after that representation is confirmed.

**Rose:** preserve a raw artefact when a postprocessor defect is found, then
record the correction and refuse a convenient rerun.

## 10. Known Residuals

This pass establishes only that the locked upstream `gllvm` fixture is healthy
in the local environment.  It does not validate the Design-87 private
objective, establish gllvmTMB parity, explain Design-86/87/88, or authorise
new fixtures, recovery, calibration, package integration, public claims, or
compute campaigns.  Any comparator or implementation work requires a new,
separately approved research design; it is not an Arc 9.

## 12. Cross-Product Coverage

Design 89 covers one released `gllvm` EVA fixture under one local R/TMB
environment, with source identity, upstream assertions, convergence semantics,
and gradient telemetry checked.  It does NOT cover another `gllvm` fixture,
package version, optimizer/control choice, a q=2 matrix-equivalent target,
gllvmTMB's private objective, long-format mapping, structured priors,
recovery/calibration, package integration, or any public API surface.
