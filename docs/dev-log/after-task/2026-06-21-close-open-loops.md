# After-task — close two open loops (#343 flaky gate + in-engine `rho` decision)

**Date:** 2026-06-21 · **Author:** Claude (Ada) · **Branch:**
`claude/close-open-loops-20260621` (PR # to follow) · **Scope:** two
maintainer-chosen loop closures from the 2026-06-21 handover — (1) stabilise the
#343 multi-trial binomial CI gate by raising reps; (2) record the keep-fixed-`rho`
decision for the Design 65 coevolution kernel and close the parked in-engine-`rho`
loop. Test-only + docs; no engine/grammar/family change.

## Why this work exists

The 2026-06-21 handover left two open loops the maintainer asked to close, with the
approach for each chosen explicitly:

- **#343** — `test-multi-trial-binomial.R`'s slope-recovery gate flaked on
  `ubuntu-latest` while passing locally (28/30). Maintainer choice (from a 4-option
  menu): **raise the rep count** for a more stable proportion — *not* pin BLAS, *not*
  widen the threshold, *not* count-converged-only.
- **In-engine `rho`** (#507 design note, parked): maintainer choice — **keep
  fixed-`rho`; record + close**.

## #343 — what raising reps actually surfaced (the real root cause)

Bumping `R` 30 → 100 (seeds 101–200 instead of 101–130) immediately **failed on
mac** — but not on the threshold. `sum(ok)` came back **`NA`**, not a number below
67:

```
Expected `sum(ok)` >= 67L.   Actual comparison: NA < 67
```

Mechanism: a rep can report optimiser convergence (`opt$convergence == 0`) yet have
a **non-PD Hessian**, so `summary(sd_report)` returns **NaN** standard errors. The
loop then did `hits[r] <- as.integer(NA)`, and a single `NA` poisons the whole
`sum(ok)` (and `mean(est[ok])`). The original R=30 seed window happened to dodge the
offending seeds; the wider window hit them. **This NA-leak — not the 20/30 margin —
is the likely true cause of the ubuntu flake:** threaded-BLAS numerics occasionally
push one rep to a non-PD Hessian, `sum(ok)` becomes `NA`, and the gate hard-fails
regardless of how many reps recovered. Raising R *without* a guard makes it strictly
worse (more chances to hit a NaN rep).

**Fix** (`tests/testthat/test-multi-trial-binomial.R`):

1. `R <- 100L` (was `30L`); threshold `expect_gte(sum(ok), 67L)` (was `20L`) — the
   **same ~2/3 proportion**, only more reps (the maintainer's chosen lever).
2. A guard treating a non-finite `est`/`se` rep as a **miss** (`next`, exactly like
   the existing non-converged guard), so it counts against the R-denominator
   threshold instead of poisoning `sum(ok)`. This is *not* the rejected
   count-converged-only option — failed-fit reps still count against the gate.

## #343 — verification (mac-local, compiled `origin/main` worktree)

Full file `test-multi-trial-binomial.R`, `NOT_CRAN=true`, package built from the
worktree (`devtools::load_all(compile = TRUE)`):

| state | recovery gate |
|---|---|
| R=100, no guard | **FAIL** — `sum(ok) = NA` (both assertions) |
| R=100, with guard | **PASS** — 0/5 failures in the file |

Instrumented margin (seeds 101–200): `null=0  nonconv=4  nan_se=2  finite=94`,
**`sum(ok) = 93/100`** (threshold 67), hit-rate-among-finite = **0.989**. The gate
now clears the bar by **26**; every miss is a fit-quality failure (non-converged or
NaN SE), and finite fits recover the slope within 2 SE 98.9 % of the time — i.e. the
estimator coverage was never the problem. For ubuntu to drop below 67 it would need
~32/100 reps to fail vs the 6/100 seen on mac, so the flake is robustly closed.
**Real validation remains the 3-OS PR CI** — the flake is ubuntu-specific and mac
cannot reproduce it.

## In-engine `rho` — decision recorded

Ratified the #507 design-note recommendation: **keep fixed-`rho` profiling; do NOT
add a TMB-estimated `rho` in this arc.** Rationale — identifiability is fragile on a
single shared `W` (`rho` trades off with cross-loading magnitude along a ridge
broken only by the within-lineage blocks and tip/`W` replication; Boettiger et al.
2012); the profile (`profile_cross_rho()` + `profile_cross_rho_ci()`) already
delivers the honest object without the per-evaluation Cholesky, boundary, sign, and
cross-package-API hazards; and simpler Design 65 C3.3 gaps sequence first. Recorded
in `docs/dev-log/decisions.md` (2026-06-21 entry) and pointed to from Design 65
C3.3 (`docs/design/65-cross-lineage-coevolution-kernel.md`). The parked loop is
closed; **issue #361 stays open** (other C-items remain). If revisited, the
zero-engine first step is the pure-R outer-optimiser identifiability simulation in
the design note §4 step 1.

## Definition-of-Done notes

- **Implementation:** test-only + docs; no engine/grammar/family touch, so DoD items
  2/3/4/6 (new simulation recovery, roxygen, runnable example, likelihood review)
  are N/A — the change *is* a recovery-test stabilisation.
- **check-log:** entry appended (`docs/dev-log/check-log.md`) with commands +
  outcomes.
- **Register:** no validation-debt row promoted (maintainer-gated); nothing newly
  advertised.
- **Cascade:** not a convention change — no example cascade required.

## Open notes for the maintainer

1. The recovery test still emits ~6–9 `NaNs produced` warnings per run (the non-PD
   reps). Harmless — they're now counted as misses — but if the CI-log noise is
   unwanted I can wrap the `summary()` extraction in `suppressWarnings()`. Left
   visible deliberately as an honest signal that a few fits are non-PD.
2. **Rose-principle follow-up (not done here):** the same NA-leak idiom —
   `as.integer(<comparison>)` where the comparison can be `NA`/`NaN`, feeding an
   un-guarded `sum()`/`mean()` — may exist in other MC recovery gates. Worth a
   `rg` scan of `tests/testthat/test-*` for the pattern. Flagged rather than
   expanded into this PR.
