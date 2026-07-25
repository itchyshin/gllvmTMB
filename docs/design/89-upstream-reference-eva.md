# Design 89 — upstream-reference EVA reproducer

## Purpose and boundary

Design 89 is a private source-reproduction design.  Its only question is
whether one **unmodified, upstream-owned** `gllvm` EVA regression fixture runs
healthily in the local R/TMB environment.  It is a new design, not Design-86
Arc 9, Design-87 V2, a Gate B, or an evidential repair of any prior design.

The locked authority is CRAN `gllvm` 2.0.13.  The fixture is the single
`method = "EVA"` call in `tests/testthat/test-fitgllvm.R`, lines 260--281,
inside the upstream `corWithinLV works` test.  It uses `kelpforest`, binomial
responses, one constrained latent variable, an AR1 within-latent correlation,
and the upstream `seed = 1` / `starting.val = "zero"` settings.  This is not a
matrix-equivalent q=2 target and establishes no gllvmTMB parity.

## Frozen gates

**Gate 0 — authority and isolation.**  Lock the CRAN source tarball, selected
test file, dispatch source, private installed library, exact runner, and
separate Design-89 result root.  Design-86/87/88 artefacts are neither read as
inputs nor rescored.

**Gate 1 — one upstream call.**  The runner reproduces the upstream data
preparation and `gllvm()` invocation verbatim.  Its only permitted action is
that call.  No alternative fixture, package version, start, seed, threshold,
or optimizer setting may be substituted after a result.

**Gate 2 — predeclared verdict.**  `UPSTREAM_REFERENCE_PASS` requires: the
locked package/source identity; no call error; both upstream assertions
(`rho.lv` and latent-score dimensions) passing; finite fitted objective and
parameters; `convergence == TRUE`; and a finite maximum absolute gradient no
greater than 0.05.  The 0.05 diagnostic cut-off is the threshold documented by
the locked upstream R source for its large-gradient warning.  Any other result
is `UPSTREAM_REFERENCE_STOP`.  A pass proves only that this upstream baseline
is healthy locally; it does not authorise parity, a gllvmTMB objective, custom
fixtures, recovery, calibration, or integration.

## Deferred work

There is no gllvmTMB code, API, C++, formula grammar, public documentation,
compile/probe of the old designs, smoke/campaign, Totoro/DRAC job, merge, push,
or pull request in Design 89.  A subsequent comparator design would require a
separate approval even if this reference passes.
