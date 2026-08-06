# After-task report — VA(GH) H = 7 Arc 1 preservation checkpoint

**Date:** 2026-08-06
**Branch:** `codex/va-gh-all-families`
**Verdict:** PARTIAL / PRESERVED. This is not Arc 1 completion and Gate E is not PASS.

## 1. Goal

Implement exact/Gauss-Hermite/hybrid variational expectations for every scalar response
family/link cell, with H = 7 as a candidate quadrature order, and expose bounded VA uncertainty for
fixed effects and latent scores. Arc 1 was to earn a light Gate E verdict before any Totoro/DRAC Arc
2 campaign or public-default promotion.

## 2. Implemented

The private R3 VA engine now carries the Laplace-aligned scalar registry (`family_id` 0:15 plus
binomial links), parameter maps, support validation, ordinal metadata, exact expectations, GH
expectations, and hybrid hurdle/delta expectations. Multinomial `family_id = 16` remains fenced as
a coupled-softmax problem. H = 7 is available as a candidate. Per-cell optimizer routing preserves
measured Gaussian/JJ behaviour and uses L-BFGS-B for NB2 GH after the multi-start light gate exposed
objective dispersion under `nlminb`.

Fixed-effect VA-Wald inference uses a profiled-Schur covariance when the fit is healthy and
single-tier, labels its approximation/calibration basis, and otherwise fails closed. Existing
latent posterior SD extraction through `getLV(se = TRUE)` is retained. Production VA preserves
per-trait Gaussian/lognormal scales; a private pure-family option can match the single Laplace
residual nuisance scale for honest comparator work.

The mathematical contract is

\[
q(z)=N(\mu,v),\qquad
Q(\mu,v)=E_q\{\log p(y\mid z)\},
\]

with GH cells evaluated as

\[
Q_H(\mu,v)=\pi^{-1/2}\sum_{h=1}^{H} w_h
\log p\!\left(y\mid \mu+\sqrt{2v}\,x_h\right).
\]

Analytic cells use their exact normal moments; hurdle/delta cells combine a GH occurrence term
with an exact or GH positive-part term. The R registry, test oracle, and TMB switch use the same
family/link identifiers.

The public contract was deliberately not changed: H = 61, JJ auto-routing for pure logit, and the
three-family integration fence remain until Gate E is recorded.

## 3. Files Changed

Implementation: `R/approximation-engine.R`, `R/va-intervals.R`, `R/va-methods.R`,
`R/va-r3-proto.R`, `R/va-routing.R`, and `inst/tmb/gllvmTMB_va_r3.cpp`.

Tests: `tests/testthat/helper-va-all-family-oracles.R`,
`tests/testthat/test-va-all-family-compiled.R`,
`tests/testthat/test-va-all-family-light-fits.R`,
`tests/testthat/test-va-all-family-oracles.R`, `tests/testthat/test-va-intervals.R`,
`tests/testthat/test-va-mixed-family.R`, `tests/testthat/test-va-ordination.R`,
`tests/testthat/test-va-probit-adsafety.R`, `tests/testthat/test-va-r3-prototype.R`, and
`tests/testthat/test-va-routing-oracle.R`.

Design/process: `docs/design/110-va-gh-h7-all-scalar-families.md`, this report, the paired recovery
checkpoint, and `docs/dev-log/check-log.md`.

Arc 2 scaffold (incomplete/frozen): all five files under `dev/va-gh-h7-campaign/`. Its README
explicitly forbids submission/execution pending repair and Gate E.

No reader-facing example, NEWS entry, roxygen/Rd file, pkgdown article, README, or vision example
was changed because public promotion has not been earned. Therefore the convention-change cascade
is not yet applicable; it becomes mandatory if Gate E authorizes promotion.

## 3a. Decisions and Rejected Alternatives

- Keep H = 7 as a candidate, not a universal accuracy claim or default.
- Keep multinomial outside the scalar programme.
- Keep per-trait VA nuisance scales in production; use the private tied-scale mode only for pure
  Gaussian/lognormal Laplace comparisons.
- Route NB2 GH specifically to L-BFGS-B; reject a blanket optimizer change.
- Preserve unchanged health/recovery gates and repair DGPs/optimizers instead of lowering bars.
- Freeze the flawed Arc 2 scaffold rather than launch it or pretend its syntax checks imply runtime
  readiness.

## 4. Files Touched

Section 3 enumerates every touched path, including each implementation file, test, design/process
record, and frozen campaign-scaffold file. No generated Rd, pkgdown output, campaign result, or
compute receipt was touched.

## 5. Checks Run

| Check | Outcome |
|---|---|
| independent oracle + compiled bridge | 160 pass; 0 fail/warn/skip |
| all-family light fits | 174 pass; 0 fail/warn/skip; all 18 pure cells + mixed + two-tier |
| VA R3 prototype | final 624 pass; 0 fail/warn/skip |
| VA intervals | final 101 pass; 0 fail/warn/skip |
| mixed-family target | 24 pass; 0 fail |
| VA control exposure | 33 pass before final core edits; public defaults unchanged |
| R and shell parsing | PASS |
| `git diff --check` | PASS before preservation records |
| `check-after-task.R` on this report | initial exact-heading failure repaired; final PASS |

The combined ordination/routing/probit target exposed one stale expected label, which was patched
but not rerun after the final patch. Full package tests, documentation generation, pkgdown,
`R CMD check`, cross-OS CI, Totoro, DRAC, gllvm, and GLLVM.jl campaigns were not run.

## 6. Tests of the Tests

The independent oracle exercises exact-vs-GH agreement, the `v -> 0` point-mass limit, tail/support
boundaries, finite objectives, and finite AD gradients for all 18 cells. Compiled tests build the
same parameter maps used by the engine and compare each cell to an independently written R oracle.
Light fits use known DGPs, multi-start objective agreement, parameter recovery, mixed links/families,
and multi-tier structure. Tests also reject multinomial in this scalar route, verify comparator-map
constraints, and exercise fail-closed interval behaviour. The main remaining test-of-test risk is
the incomplete independent reviewer verdict, not absence of cell-level assertions.

## 7. Roadmap Tick

No roadmap item is ticked. Arc 1 is preserved but not complete because independent Gate E review,
the final targeted rerun, public cascade decision, and package-level checks remain. Arc 2 remains
unlaunched.

## 7a. Issue Ledger

An earlier focused open-issue search returned no relevant VA-GH-H7 issue. No issue was created at
this context boundary. Current remote PR/issue state could not be refreshed because GitHub was
unreachable.

## 8. Consistency Audit

Exact scans run:

```sh
rg -n 'va_H = 61|va_H.*61|auto.*jj|pure binomial-logit.*JJ|Uncertainty remains fenced|no standard errors|families = c\(' R tests docs/design/104-va-family-coverage.md docs/design/108-va-parity-programme.md docs/design/110-va-gh-h7-all-scalar-families.md
rg -n 'log_sigma_eps|log_sigma_lognormal|match_laplace_residual_sd' R src inst/tmb tests/testthat docs/design/110-va-gh-h7-all-scalar-families.md
rg -n 'family code 3|code 4|family_id.?=.?16|H = 7|H=7' R inst/tmb tests/testthat docs/design/110-va-gh-h7-all-scalar-families.md
```

The first scan confirms the intentional public hold: H = 61/JJ/three-family fence and old
uncertainty prose remain. The second confirms the Laplace/VA scale distinction and its private
matching option in code, tests, and Design 110. The third confirms H = 7 coverage and the
multinomial exclusion, while exposing one stale historical `family code 4` probit comment at
`R/integration-fence.R:38`. Gate E reconciliation must fix it.

Remote collision audit is incomplete: `git log --all --oneline --since="6 hours ago"` found no
foreign local lane, but `gh pr list --state open` could not reach `api.github.com`.

## 9. What Did Not Go Smoothly

Legacy schema drift caused a large initial prototype failure set. Several initial light DGPs were
too weak or outside the unchanged health domain. NB2 exposed optimizer-specific dispersion. An
independent comparison found a real Gaussian/lognormal nuisance-scale mismatch between VA and
Laplace. The first campaign scaffold then widened prematurely and failed adversarial review on
runtime immutability, receipt binding, task geometry, health scoring, truth retention, transactional
output, latent alignment, and scheduler configuration. Finally, context reached the D-76 boundary
before a complete independent likelihood verdict. These are recorded as open work, not hidden by
the green targeted suites.

## 10. Known Residuals

Gate E has no durable per-cell reviewer verdict. The last combined ordination/routing/probit target
needs rerunning. One stale probit family-code comment remains. Public defaults and documentation
are intentionally unchanged. Full package/pkgdown/cross-platform checks have not run. The Arc 2
scaffold is incomplete and must not be launched; no Totoro/DRAC job exists.

The single next action is to start a fresh Sol/high statistical parent task and complete the
independent 18-cell Gate E likelihood/routing review, including the final targeted rerun and stale
comment reconciliation. Only a durable Gate E PASS can authorize public promotion or Arc 2 repair
and launch. Bounded support work should use Terra/medium or Luna/low with context-fresh briefs.

## 11. Team Learning

Curie showed that all-family light recovery can remain stringent when fixtures and optimizer
routing are repaired rather than gates weakened. Gauss identified the nuisance-scale comparator
boundary and confirmed that green arithmetic/AD checks are necessary but not sufficient for Gate E.
Noether/Fisher's campaign lens prevented H = 7 evidence from being conflated with a runnable
large-scale campaign. Rose's consistency lens exposed the still-public H = 61/JJ fence and the
stale probit code comment. Grace's runtime lens rejected compilation from a dirty checkout and
unbound receipts. Jason's sibling-package map supports using gllvm only as a secondary comparator;
the package may itself be wrong, so the package's own Laplace path and independent oracles remain
primary. Ranga's literature synthesis supports H = 7 as a plausible candidate between published
GLLVM node choices, not as a theorem or universal optimum.

## 12. Cross-Product Coverage

This checkpoint covers the private scalar family/link cross-product for the ordinary VA R3
objective, its parameter maps, independent expectation oracles, compiled AD bridge, known-DGP light
fits, a mixed-family fixture, and a two-tier fixture. It covers fixed-effect VA-Wald inference only
for healthy single-tier fits and retains the existing latent posterior SD surface.

It **does NOT cover** multinomial softmax, a completed independent Gate E review, all covariance
keywords/providers, missing-data combinations, every structured random-effect tier, calibrated
coverage, public-default/fence promotion, the roxygen/Rd/pkgdown cascade, full-package or cross-OS
checks, or a runnable Totoro/DRAC campaign. Exact/GH/hybrid cell coverage must not be read as proof
over those untested product axes.
