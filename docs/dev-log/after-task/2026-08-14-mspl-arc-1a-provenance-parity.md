# After Task: MSPL Arc 1A internal provenance parity

**Branch**: `cursor/mspl-arc-1a-provenance`
**Date**: `2026-08-14`
**Roles (engaged)**: Ada / Boole / Emmy / Curie / Gauss / Noether / Rose / Grace / Melissa

```text
🎯 GOAL
Solo platform: Cursor
Deliverable: internal estimator provenance on every current admitted route, with exact numerical and accepted-call parity
HEADLINE: separate integration, outer criterion, numerical kernel, and penalty-eval internally without changing any result or accepted call
IN PARALLEL: recon of estimator_id 0/1/2 sites; compatibility-table draft; parity-fixture inventory
DEFER: Arc 1B; Arcs 2–8; inference; Design 117; Codex iSDM / G3P / #872 / #855 / AA-03
DISCIPLINE: verify=objective/gradient/report/warning/error/routing parity · compute=local targeted tests only · closure=parity receipt + after-task + stacked Cursor PR
```

## 1. Goal

Record resolved integration, outer criterion, numerical kernel, and
penalty-eval on every current admitted estimator route, while keeping
TMB `estimator_id` as the existing 0/1/2 tape integer and changing no
accepted call, default, NEWS claim, or numeric result.

## 2. Implemented

- New unexported resolver and compatibility table in
  `R/estimator-provenance.R`.
- `gllvmTMB_multi_fit()` now *derives* `estimator_id` 0/1/2 from that
  resolver. The penalty-off tape is adapter output
  `penalty_eval = provenance_off` (still integer 2).
- Every Laplace/AGHQ fit from `gllvmTMB_multi_fit()` and every
  user-facing `gllvmTMB()` fit, including accepted
  `estimator = "ml"` + `integration = "va"`, carries
  `fit$estimator_provenance`.
- VA+ml remains accepted. Provenance records `criterion_id = va_elbo`
  and that the public `ML` label is coarse.
- No C++ edit. No NEWS. No register promotion. No print/summary change.

## 3. Files Changed

- `R/estimator-provenance.R` (new)
- `R/fit-multi.R` (adapter + attach)
- `R/gllvmTMB.R` (VA-path attach; record, do not reject)
- `tests/testthat/test-estimator-provenance.R` (new)
- `tests/testthat/test-mspl-api.R` (two provenance expects on the
  existing ML-identity test)
- `docs/dev-log/lanes/cursor-mspl-arc-1a/LOOP/` (Arc 1A `/goal` kit).
  Repo-root `LOOP/` was restored from `origin/main` on 2026-08-15 so
  merging #962 cannot clobber the 0.6 release kit.
- `docs/dev-log/plans/2026-08-14-cursor-mspl-one-arc-ultra-plan.md`
- `docs/dev-log/after-task/2026-08-14-mspl-arc-1a-provenance-parity.md`
  (this file)
- `docs/dev-log/check-log.md` (append)
- `docs/dev-log/plan-actual/2026-08-14-mspl-arc-1a.md`

Not changed: `src/gllvmTMB.cpp`, `NEWS.md`,
`docs/design/35-validation-debt-register.md`, Design 88, print/summary,
`R/mspl.R` atoms, Design 117, interval-feasibility, iSDM / G3P / #872 /
#855 / AA-03.

## 3a. Decisions and Rejected Alternatives

- **Decision:** keep TMB integers 0/1/2; derive them in R.
  **Rejected:** new TMB DATA slots. **Confidence:** high (G0 lock).
- **Decision:** VA+ml stays accepted and is labelled coarse.
  **Rejected:** typed error (that is Arc 1B). **Confidence:** high.
- **Decision:** VA `estimator_id` is `NA_integer_` because VA does not
  use the TMB DATA slot. **Rejected:** writing 0 and pretending it is
  LA-ML. **Confidence:** high.
- **Decision:** stacked PR against `main`; leave #961 as the docs
  vehicle. **Rejected:** committing 1A onto #961. **Confidence:** high
  (G0).

## 4. Checks Run

Worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
`OMP_NUM_THREADS=1`, `NOT_CRAN=true`. Loaded namespace was this
checkout (`pkgload::load_all` debug compile).

```text
testthat::test_file("tests/testthat/test-estimator-provenance.R")
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 75 ]  Duration: 26.1 s

testthat::test_file("tests/testthat/test-mspl-api.R")
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 223 ]  Duration: 16.9 s
```

`git diff -- src/` empty (no C++). No `estimator_id <- 0L/1L/2L`
assignments remain in R. `R CMD check` not run (plan: not required
unless NAMESPACE changes; none did).

## 5. Tests of the Tests

- Resolver unit tests fail if the locked ID sets drift or if VA+ml
  becomes a resolver abort.
- ML implicit/explicit test fails on `opt$par` / `opt$objective`
  drift beyond 1e-10 or if `estimator_id` leaves 0.
- MSPL test fails if the live tape is not 1 or the penalty-off tape
  is not 2.
- VA+ml test fails if the combination is rejected or if provenance
  claims LA-ML.
- Abort-class tests fail if poisson-MSPL, MSPL+VA, or explicit
  estimator+REML change class.
- Print capture fails if `estimator_provenance` leaks onto `print()`.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `estimator_id <- [012]L` in `R/` / `src/` | expected-absent (adapter only) |
| `NEWS.md` / register / Design 117 in this diff | expected-absent |
| `src/gllvmTMB.cpp` in this diff | expected-absent |
| public `print()` mentions `criterion_id` | expected-absent (print capture) |

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

No relevant open issue for Arc 1A implementation; no new issue
created. Programme vehicle remains
[#961](https://github.com/itchyshin/gllvmTMB/pull/961) (docs-only;
not merged).

## 8. What Did Not Go Smoothly

- `move_agent_to_root` is blocked for subagents; work stayed on the
  mandatory worktree path by absolute path.
- Historical `LOOP/` on `main` is the 0.6 release kit. This branch
  replaces those four files for `/goal` only; history on `main` is
  unchanged.
- S5 is a written Gauss/Noether/Rose review in this closeout, not a
  spawned Claude Opus panel.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Gauss.** The tape still sees only `DATA_INTEGER(estimator_id)` in
`{0,1,2}`. Id 2 remains the penalty-off stable kernel at the MSPL
point. A silent DATA-slot rewrite did not happen. PASS.

**Noether.** R resolver fields match the locked adapter contract
(`la_ml` / `la_mspl` / `reml` / `va_elbo`; kernels
`legacy_ml` / `audited_stable_mspl` / `va`; penalty
`off` / `on` / `provenance_off`). Equations in the programme document
are unchanged. PASS.

**Rose.** Combining 1A with a new typed error for VA+ml would have
violated accepted-call parity. That combination is recorded, not
rejected. No NEWS, no register promotion, no default change, no
“and also do 1B.” PASS.

**Curie.** Targeted tests can fail: numeric drift, missing
provenance, wrong tape integer, or a newly rejected accepted call.
Existing `test-mspl-api.R` stayed green including spatial cells.

**Boole / Emmy.** Resolver is unexported. Public `estimator =`
values and accepted combinations are unchanged.

**Grace.** Local only; OMP=1; no campaign; no NAMESPACE change.

**Melissa.** See `docs/dev-log/plan-actual/2026-08-14-mspl-arc-1a.md`.

## 10. Known Limitations And Next Actions

- Julia-engine fits are not in the Arc 1A definition of done and do
  not yet carry `estimator_provenance`.
- Direct `gllvmTMB_multi_fit()` VA returns still get provenance only
  after the `gllvmTMB()` wrapper attach. The public entry point is
  covered.
- Arc 1B (public policy for explicit `estimator = "ml"` outside
  Laplace) remains queued and separately approved.
- Do not merge this PR without Shinichi. Do not start Arc 2 from
  this closeout.
