# Missing / Mixed correctness — post-merge verification (milestone launch)

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion` (post fold-arc merge, `e9ca9b95`)
Agent: Claude (audit + claim-boundary review; runtime probes)

## Goal

Re-verify the missing/mixed claim boundaries **against the post-merge code**. The
Day-2 audit (`2026-07-05-missing-mixed-claim-boundary-audit.md`) was confirmatory
but predates the fold-arc merge, which churned `extract-sigma.R` (+492 lines) and
`extract-correlations.R` (+156) — exactly the mixed-family surface. Note: `rg`
output in this environment mangles matched text, so findings below are from
**running the code** and from `Read`, not grep.

## Findings

### 1. D-28 per-trait link residuals — CORRECT post-merge ✅

A gaussian+binomial+poisson mixed fit gives `link_residual_per_trait()` =
`0, 3.2899, 0.4658`: Gaussian uses estimated Ψ (0); binomial = exactly π²/3 =
3.2899 (logit); Poisson = log1p(1/μ) ≈ 0.47. The fold arc preserved the D-28
contract. `link_residual_per_trait()` (in `extract-sigma.R`) is wired into
`extract-correlations.R`, `proportions-ci.R`, `profile-derived.R`,
`extract-repeatability.R`.

### 2. Mixed-family correlation intervals carry NO interval-status marker 🔍

`extract_correlations()` on a mixed-family fit returns finite **`fisher-z`**
intervals (`lower`/`upper`) with **no `interval_status` field** — byte-identical
in shape to a pure-Gaussian fit, whose intervals ARE calibrated. The julia-bridge
branch, by contrast, marks its point-only rows `interval_status = "none"`.

- Not a hard-guard *violation*: no "coverage"/"nominal"/"95%" prose exists (the
  Day-2 audit's conclusion stands); the uncalibrated status is documented only in
  the register (CI-08 / CI-10 open) and Design 75 ("mixed-family CIs blocked").
- But it is the Day-2 audit's "reader-fragile" flag made **concrete**: the
  marking machinery exists (julia uses it), is simply not applied to the
  mixed-family route, so uncalibrated mixed-family intervals are
  output-indistinguishable from calibrated Gaussian ones.
- **RESOLVED — implemented** (Shinichi approved 2026-07-05). `extract_correlations()`
  now stamps every path with `interval_status` via `.correlation_interval_status()`:
  `"nominal"` for all-Gaussian fits, `"route-only"` for non-Gaussian / mixed-family
  fits (coverage unestablished, CI-08 / CI-10), `"none"` for julia point-only. The
  boundary is now visible in-output; the julia-vs-TMB inconsistency is removed.
  Single injection point at the assembly; roxygen + Rd updated; tests assert
  `nominal` (Gaussian) and `route-only` (mixed). Full suite PASS 4168 / FAIL 0.

### 3. MIX-10 delta/hurdle block — enforced, but the register's gate class is wrong 🔍

Design 57 (§ lines 22, 40, 114) confirms `check_auto_residual()` **rejects**
mixed-family delta/hurdle fits (two latent scales; single-σ²_d correlation
contract undefined). The block is real. BUT the Day-2 audit named the abort class
`gllvmTMB_auto_residual_delta_undefined` — that class **does not exist** in the
code (pre- or post-merge). The actual aborts in `check-auto-residual.R` are
`gllvmTMB_auto_residual_incoherent` (within-trait family mixing, line 107) and
`gllvmTMB_auto_residual_ordinal_probit_overcount` (warn, line 127).

- **Open verification:** confirm at runtime that a mixed-family fit containing a
  `delta_*` trait is actually blocked (build the fit, expect an abort), and
  correct the register/Day-2 note's class name. The delta block may rely on the
  incoherent path or a fit-time guard in `families.R` — the exact route needs a
  runtime trace, not asserted.

## Checks Run

- Runtime probes (`pkgload::load_all`, `NOT_CRAN=true`): mixed gaussian/binomial/
  poisson fit converges; D-28 residuals as above; `extract_correlations` columns
  compared mixed vs pure-Gaussian (identical: `fisher-z`, no `interval_status`).
- `Read` of `R/check-auto-residual.R` (170 lines); `grep` of Design 57.
- No code / register / grammar changed by this verification pass.

## Known Residuals / Next Actions (milestone, not yet done)

- ~~Interval-status marker (finding 2)~~ — DONE (approved + implemented).
- Runtime-verify the delta/hurdle block (finding 3) + fix the register/audit
  class-name inaccuracy.
- Re-confirm `na_mask` retention (`normalise_weights(drop_masked = FALSE)`) under
  the folded covariance.
- Register CI-08 / CI-10 promotion once the marker decision lands.

## Team Notes

Fisher: mixed-family intervals remain route-existence only; the boundary is now
inconsistent in-output (marked for julia, unmarked for mixed-family). Rose: the
Day-2 audit's MIX-10 gate class name is inaccurate — fix on the next register
pass. No push / PR / merge beyond the already-authorized branch push.
