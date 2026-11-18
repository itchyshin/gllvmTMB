# R0 inventory — #1077 scaffold + Confirm-in-ref + assert_inference map

**Date:** 2026-08-17
**Lane:** `claude/lane-mspl-profile-led-ci` @ `/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci`
**Status:** read-only recon for `/goal` SCAFFOLD. Docs only. No undraft. No Design 118 edit.

## Critical finding (INTERRUPT)

| Surface | Finding |
|---|---|
| Overnight WT `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` (`cursor/mspl-overnight-rehydrate`) | Had **uncommitted** triad Confirm SIGNED + ultra-plan + check-log / decisions / handover / brief |
| `origin/main` | Triad card still **UNSIGNED** doctrine note (Status line without SIGNED); Confirm paste text may exist as G0 proposal but card header is not SIGNED |
| Implication | A `/goal` lane based on `origin/main` alone would **lose Confirm**. Confirm must land in a **git ref** on this lane **before S1**. |

**Mitigation this sitting:** copy overnight Confirm-bearing paths into this worktree and **commit** them on `claude/lane-mspl-profile-led-ci` (not push unless asked). Overnight WT left as-is (still dirty) — this lane owns the durable Confirm ref for the Design sitting.

## #1077 scaffold

| Field | Value |
|---|---|
| PR | [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077) |
| Branch | `cursor/mspl-profile-ci-scaffold` |
| Tip | `fb44d7b5` |
| Draft? | **yes** (`isDraft: true`) |
| Key files | `R/mspl-profile-ci-stub.R`, `tests/testthat/test-zz-mspl-profile-ci-stub.R`, research + after-task notes |

**Fence (verified from tip, not wired on this lane's `origin/main` tip):**

- Unexported helpers only; must never wire into `R/z-confint-gllvmTMB.R`.
- Public `confint` / `vcov` / `se=TRUE` still refused via `.gllvmTMB_mspl_assert_inference`.
- Triad roles labelled: profile=`signature` / `not_constructed`; Wald Q₀=`quickest_baseline`; bootstrap=`asymmetry`.
- Toy family fence: Gaussian identity or Poisson log `se=FALSE` only.
- Design 118 = `parked` in stub metadata.
- No `TMB::sdreport()`, no `@export`, no NEWS covered.

**This lane does NOT undraft #1077.** Scaffold stays draft tip `fb44d7b5`.

## `.gllvmTMB_mspl_assert_inference` call sites (this checkout, main tip)

Observed callers include (non-exhaustive map for S1 awareness):

- `R/methods-gllvmTMB.R` — `predict(se.fit=TRUE)`, `tidy(conf.int=TRUE)`
- `R/extractors.R` — `extract_communality(ci=TRUE)`, `extract_lv_effects`
- `R/vcov-coef.R` — `vcov`
- `R/profile-targets.R` — `profile_targets`
- `R/loading-profile.R` — `loading_profile`

Public MSPL inference remains refused. Stub on #1077 tip is additional fenced plumbing, not a public door.

## Parallel G0s

| Card | Status |
|---|---|
| Triad Confirm (`2026-08-17-mspl-ci-wald-plus-profile.md`) | **SIGNED** on this lane after Confirm commit |
| Poisson W (`2026-08-17-mspl-poisson-W-G0.md`) | **UNSIGNED** (KEEP / REPLACE / PARK SE doors) |
| `MSPL-04` | **blocked** in register |
| Design 118 / B1 / Totoro | PARKED (D-157) — do not reopen |

## Next

S1 Design stub — only after Confirm is in this branch's git history (this commit series).
