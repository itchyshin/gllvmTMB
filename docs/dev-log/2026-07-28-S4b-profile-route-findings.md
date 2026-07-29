# S4b — profile-route judgment read (2026-07-28)

> Recovered from the agent's returned message: it was dispatched with a read-only agent type and
> had no Write tool, so it correctly refused to fake a file write and returned inline instead.
> Dispatch error, not an agent error.

## Q1 — What the certified diagonal profile does

Profiles the **log-SD parameter `theta_diag_B` directly** through `TMB::tmbprofile()`, then
root-finds the χ² crossing and transforms to the variance scale.

Chain: `confint.gllvmTMB_multi()` (`R/z-confint-gllvmTMB.R:1526`) → `.is_sigma_parm()` (:1635) →
`.confint_sigma()` (:1708) → `.confint_sigma_profile()` (:1889). Branch requires
**`!rr_used && diag_used`** (:1947), flags read from `object$use$rr_B` / `$diag_B`, set at
`R/fit-multi.R:5710`. Refit via `.tmbprofile_block()` (`R/profile-ci.R:305-346`) →
`tmbprofile_wrapper()` (:225-299) → `TMB::tmbprofile(..., ystep = 0.5, ytol = 2,
parm.range = c(-Inf, Inf))` (:268-275). Root-find `.profile_bounds()` (:108-164) with
`crit <- .qchisq_threshold(level)` (:239). Transform `exp(2*x)` at `:1953`.

**Parameterisation is log-SD, inherited from the TMB model** (`src/gllvmTMB.cpp:995`:
`sd_B = exp(theta_diag_B)`), *not* chosen by the profile code. Reporting on the variance scale is a
separate decision made at the confint layer.

## Q2 — Why low-rank falls back to bootstrap

Trigger is a **boolean flag check**, not a failed attempt: `!rr_used && diag_used`
(`R/z-confint-gllvmTMB.R:1947`). If `rr_B` is TRUE it goes straight to
`.confint_sigma_bootstrap()` (:1988-1995) behind an `cli_inform()`.

Substantive reason is **(c) + (d)**:
- (c) `Sigma_tt = (ΛΛ')_tt + ψ_t` is **nonlinear in `theta_rr_B`**, so not expressible as
  `TMB::tmbprofile()`'s scalar-index-or-fixed-`lincomb` form.
- (d) **the load-bearing half** — a generic nonlinear fix-and-refit engine *already exists*
  (`.fix_and_refit_nll()`, `R/profile-derived.R:259-324`; `.profile_ci_via_refit()` :332+) and is
  wired for communality, `rho`, variance proportions, and `B_lv`. It is **deliberately not pointed
  at Σ**, because Λ's rotation indeterminacy makes it unstable ("the rotation-equivalent class of
  Lambda is dense", :1982/:1985) *and* the engine uses only an **inexact quadratic penalty**
  (`lambda = 1e6`, accept if `|q_hat - q_0| <= 0.05`, :279/:316), which the route matrix's own Stop
  Rules (`R/profile-route-matrix.R:124-127`) and Next Gates (:136-137) forbid extending without an
  **exact constraint solver** and an **optimizer-status ledger**.

**(a) is false** — a target *is* computed every call (`Sigma_pt`, :1908-1913).

## Q3 — 🔴 IS BOUNDARY DETECTION IMPLEMENTABLE? **NO.** (blocking)

Four independent reasons, each verified:

1. **`TMB::tmbprofile()`'s inner refit is UNCONSTRAINED.** Reading installed TMB 1.9.21 source:
   `nlminb(start, newfn, newgr, control = control)` — no `lower=`/`upper=`.
2. **Convergence status is DISCARDED.** `ans$convergence` / `ans$message` are computed by `nlminb`
   but never read; `tmbprofile()` returns **exactly two columns** (`parameter`, `value`). No
   convergence code, gradient norm, or active-set flag survives to the caller.
   `.profile_bounds()` consumes exactly those two columns (`R/profile-ci.R:111-112`).
3. **No `parm.range` is ever imposed** in the certified path — defaults to `c(-Inf, Inf)`
   (`R/profile-ci.R:234`); `.tmbprofile_block()` (:305-313) has no such argument, so callers cannot
   set it; `.confint_sigma_profile()` (:1949-1954) passes none.
4. **The log-SD parameterisation puts SD = 0 at −∞.** There is no finite boundary to detect. Even a
   finite `parm.range` would be a truncation heuristic, never a boundary test.

**What stands in for detection today:** `.profile_bounds()`'s `find_cross()` heuristic
(`R/profile-ci.R:122-159`). If the trace never crosses within `TMB::tmbprofile()`'s finite adaptive
budget (`maxit = ceiling(5*ytol/ystep)` ≈ 20 steps at defaults), `length(pos) == 0L` is treated as
"hit the boundary" and ±Inf is returned (:139-141).

> **A profile that is merely SLOW (needs >~20 steps) is indistinguishable, by this code, from a
> genuine boundary case.** This defect is in the **already-certified diagonal path**, not only in
> the routes the design doc marks blocked.

Design 76 §5 (`docs/design/76-structured-xlv-phylo.md:348-356`) requires the Self–Liang χ̄²
reference at variance→0 / correlation→±1 / loading→0 — but **applying it presupposes detecting the
boundary regime, which no mechanism currently provides.**

## Q4 — What a target-explicit full-Σ profile needs

**Reusable:** `build_Lambda()` reconstruction exists in near-identical form three times
(`R/profile-derived.R:576-590`, :844-858, :1015-1022). Rotation-invariance as the design gate is
established precedent — `B_lv` is documented as the right target class for exactly this reason
(:1328). The fix-and-refit driver is reusable **in shape**.

**Genuinely missing:** (1) an **exact** equality-constrained solve replacing the quadratic penalty
(augmented Lagrangian, or a reparameterisation making the constraint linear); (2) an
**optimizer-status ledger** — absent everywhere in this subsystem, including the certified path;
(3) the **boundary-corrected LR reference** — `.qchisq_threshold()` is the only reference
implemented, no χ̄² anywhere; (4) **known-DGP coverage calibration** for full-Σ-with-reduced-rank —
no such campaign found in `dev/` or `docs/dev-log/`.

## Q5 — ✅ FOUND: the certificate's producing script

**`dev/profile-rescore-run.R` + `dev/totoro-profile-rescore.sh`**, added in commit **`829c34cd`**
(2026-07-16, *"feat(coverage): genuine profile + log-SD delta-Wald on Sigma_unit total variance V_t"*),
together with +301 lines in `R/profile-derived.R` (`.total_variance_spec()`,
`.profile_ci_total_variance()`, `.wald_ci_total_variance_logsd()`) and +139 lines in `dev/m3-grid.R`
wiring `profile_total` / `wald_t_logsd` / `coverage_certificate`.

**Lives on** `claude/release-0.5.0` and `claude/profile-coverage-remeasure-20260718` (plus some
`codex/*`). **NOT an ancestor of `claude/sigma-intervals-boundary-20260728`** —
`git merge-base --is-ancestor 829c34cd HEAD` is false, and `ls dev/ | grep profile-rescore` is empty
on this branch.

`dd80244a` is the **public-flip commit only** — no script, just `R/z-confint-gllvmTMB.R` wiring,
`NEWS.md`, roxygen, and three evidence docs. Its after-task doc names the actual compute: a Totoro
run at `~/gllvm_work/profile_rescore_freshseed_A/` (reps 5001–15000) pooled with
`~/gllvm_work/profile_rescore/` (reps 1–5000).

⚠ The committed MCSE pointer `m3-pilot-report.R:768` is **stale** — the file exists at HEAD (1658
lines) but that line no longer holds the formula. Treat the line number as stale, the file as real.

## Consequence for the arc

S7's re-certification arm **can** be like-for-like after all — but only by bringing
`829c34cd`'s scripts and the `dev/m3-grid.R` wiring onto this lane first. That is now a
prerequisite, and it supersedes the weaker "state it is a fresh measurement" fallback recorded in
commit `f6a317c7`.
