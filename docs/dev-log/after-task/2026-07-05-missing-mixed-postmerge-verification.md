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

### 3. MIX-10 "delta/hurdle blocked" is NOT enforced as an auto runtime gate 🔴

Design 02 (lines ~174-191) and Design 57 say mixed-family delta/hurdle
correlations are "undefined" (two latent scales) and that `check_auto_residual()`
"rejects" them. Code trace says otherwise — three inaccuracies:

1. The Day-2 audit named the abort class `gllvmTMB_auto_residual_delta_undefined`;
   **that class does not exist** (pre- or post-merge). The only aborts in
   `check-auto-residual.R` are `gllvmTMB_auto_residual_incoherent` (within-trait
   family mixing, line 107) and `..._ordinal_probit_overcount` (warn, line 127).
2. `check_auto_residual()` is **never called anywhere in `R/`** (grep-confirmed):
   it is an `@export`ed, MANUAL diagnostic the user runs on demand — NOT an
   automatic gate wired into `gllvmTMB()`, `extract_Sigma()`, or
   `extract_correlations()`.
3. Even when called, it blocks only *within-trait* family mixing, not delta/
   hurdle families (a single-family delta trait passes). And `extract-sigma.R`
   (lines 316-325) **handles** delta (delta_lognormal → σ²+π²/3; delta_gamma →
   trigamma) — it computes a σ²_d rather than refusing.

So a delta/hurdle mixed-family fit's `extract_correlations()` is **computed and
returned**, not hard-blocked — and (as of today's marker) tagged
`interval_status = "route-only"`. The claim boundary is therefore *flagged*
(route-only), but the register/Design "blocked" wording overclaims a hard guard
that isn't wired.

- **Runtime confirmation (definitive, deferred — needs a delta-family fixture,
  ~Codex lane):** fit `delta_* + gaussian`, call `extract_correlations()`, and
  confirm it returns `route-only` rows rather than aborting.
- **Decision (Shinichi / design):** is `route-only` marking sufficient for
  delta/hurdle mixed correlations (⇒ correct the register from "blocked" to
  "route-only / handled"), or should they be *hard-blocked* (⇒ wire a real guard
  + auto-call it, since check_auto_residual is currently opt-in only)?
- Register/audit fix regardless: the `..._delta_undefined` class name is wrong.

## Checks Run

- Runtime probes (`pkgload::load_all`, `NOT_CRAN=true`): mixed gaussian/binomial/
  poisson fit converges; D-28 residuals as above; `extract_correlations` columns
  compared mixed vs pure-Gaussian (identical: `fisher-z`, no `interval_status`).
- `Read` of `R/check-auto-residual.R` (170 lines); `grep` of Design 57.
- No code / register / grammar changed by this verification pass.

## Known Residuals / Next Actions (milestone, not yet done)

- ~~Interval-status marker (finding 2)~~ — DONE (approved + implemented).
- Finding 3: Shinichi/design call on route-only-vs-hard-block for delta/hurdle
  mixed correlations; fix the register/audit class-name + "blocked" wording;
  runtime confirmation with a delta fixture (Codex lane).
- `na_mask` retention — CONFIRMED still valid: the merge did not touch
  `R/weights-shape.R` (`git diff 08050034..HEAD` on the missing/mixed surface
  changed only `extract-correlations.R` + `extract-sigma.R`), so the Day-2
  audit's `normalise_weights(drop_masked = FALSE)` confirmation carries over
  unchanged.
- Register CI-08 / CI-10 promotion once the delta decision + marker land.

## Team Notes

Fisher: mixed-family intervals remain route-existence only; the boundary is now
inconsistent in-output (marked for julia, unmarked for mixed-family). Rose: the
Day-2 audit's MIX-10 gate class name is inaccurate — fix on the next register
pass. No push / PR / merge beyond the already-authorized branch push.
