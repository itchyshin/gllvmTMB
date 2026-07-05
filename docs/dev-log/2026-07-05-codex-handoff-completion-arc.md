# Codex handoff — completion-arc live-fit items (2026-07-05)

From: Claude (audit + design lead, Shinichi's completion arc)
To: Codex (live R/TMB implementation lane)
Branch: `codex/r-bridge-grouped-dispersion` @ `c89aeff9` (pushed to origin)

This session ran the claim-boundary-enforcement audit across M2–M4 and wrote the
delta resolution into the design. The **audit + design work is done and pushed**;
what remains needs live fits (compilation, convergence, recovery) — your lane.
Each item below has precise pointers + the acceptance check.

## 1. Delta mixed-family: build latent-on-main (Shinichi 2026-07-05, this arc)

Design of record: **Design 02 §Hurdle/delta** (Resolution block). Constraint:
random effects on the **positive** submodel only; **occurrence submodel
fixed-effects-only** → single latent scale → correlation on the positive-part
residual, reported `interval_status = "route-only"`.

- **Convergence — ROOT CAUSE DIAGNOSED 2026-07-05 (Claude, local reproduction):**
  a mixed `gaussian + delta_lognormal` fit with `latent(0 + trait | unit, d = 1)`
  reproduces the boundary — `convergence = 0` but **`pdHess = FALSE`**; parameters
  do NOT run off (the latent/`theta_diag_B` params are weakly identified, not
  infinite). Ruled out the Ψ diagonal as the sole cause (`unique = FALSE` is
  *also* `pdHess = FALSE`). **Root cause:** `src/gllvmTMB.cpp:2037` — the comment
  is explicit: *"delta_lognormal (hurdle): one shared eta drives both
  components"* (line 238: `invlogit(eta)` for presence **and** `exp(eta)` for the
  positive part). The single latent-bearing `eta` drives BOTH the occurrence
  (logit) and positive (log) scales → two-scale confounding → non-PD Hessian.
  **This is exactly the obstruction Design 02's constraint removes.** (`pdHess`
  is never CI evidence, per the hard guard — it's used here only as the
  identifiability signal.)
- **THE PRIMARY FIX (maintainer, 2026-07-05 — general, not delta-specific):**
  the real cause is broader than delta. A mixed `gaussian + <non-Gaussian>`
  fit with `latent(0 + trait | unit)` estimates the non-Gaussian trait's
  between-unit **Ψ (`theta_diag_B`) FREE**, and it is driven to a near-zero
  boundary (probe: binomial → −8.75; poisson → −9.4/−11.1) — **a free parameter
  pinned against a zero boundary is what makes the Hessian non-PD.** D-28 says
  that Ψ is a *known zero* for every non-Gaussian family **except OD-Poisson**
  (whose OLRE variance is legitimately estimated). So: **generalize the
  single-trial-binary auto-Psi gate** (`fit-multi.R:4089`, currently
  `family_id_vec == 1L && n_trials == 1`) to **fix `theta_diag_B` to zero + map it
  (and its `s_B` rows) off for all non-Gaussian traits whose lowest-level Ψ is a
  known zero — everything except gaussian and OD-Poisson/OLRE.** Small R change,
  mirrors the existing gate. This unblocks the *general* non-Gaussian latent
  identifiability (binomial/poisson/delta all currently leak the free Ψ), not
  just delta. **Codex must recovery-test** it (does mixed non-Gaussian latent now
  give `pdHess = TRUE` with correct recovery?) — the tier detail (B-tier Ψ vs
  W-tier OLRE) and the exact OD-Poisson exception point need his live validation.
- **PRECISE LOCATION — the fix is TWO gaps, both traced 2026-07-05 (Claude):**
  (1) **Gate-firing gap.** In a mixed `gaussian + binomial` latent fit the binomial
  trait has `family_id == 1` and `n_trials == 1` (verified) — the gate's *inner*
  condition is met — yet `theta_diag_B` stays free (est. −8.75, not pinned at the
  gate's `log(1e-6)`). The gate never runs because its *outer* flag
  `auto_psi_B <- any(diag_is_auto_residual & groupings == site)`
  (`fit-multi.R:922`) is not TRUE here (grouping/`site` match or
  `diag_is_auto_residual` fails for the mixed latent config). **Fix step 1: make
  the auto-Psi gate actually fire for auto-Psi latent fits regardless of family
  mix** (debug the `922` condition). (2) **Family-scope gap.** Even once firing,
  the skip at `fit-multi.R:4093` is `family_id == 1L && n_trials == 1`
  (single-trial binary only). **Fix step 2: widen it to all non-Gaussian except
  gaussian + OD-Poisson.** Both are `fit-multi.R`, both need Codex's recovery
  loop (a mis-fix silently zeroes a legitimate variance; the test suite lacks a
  case for every legitimate non-Gaussian between-unit Ψ).
- **Delta two-part note (secondary):** the `src/gllvmTMB.cpp:2037` shared-eta
  (one `eta` drives both hurdle parts) is a *further* delta-specific factor for
  the correlation *scale* (positive-part residual), but the Ψ-gate above is the
  primary convergence fix. Verify whether the Ψ-gate alone restores delta
  `pdHess = TRUE`; only if not, also split the delta eta (latent → positive part
  only).
- **Guard:** random *slopes* on delta are already blocked (`fit-multi.R:1495`).
  The occurrence-RE guard largely falls out of the fix (the occurrence predictor
  is constructed fixed-effects-only); still fail loud if a formula would target a
  random effect at the occurrence part.
- **Correlation residual:** use the **positive-part residual** for delta in
  `extract_correlations()` — `sigma^2` (log scale, delta_lognormal) /
  `trigamma(shape)` (delta_gamma) — NOT the two-component `+ pi^2/3`
  (`extract-sigma.R` fid 12/13 currently adds pi^2/3; that stays for
  total-variance/repeatability but is wrong for the latent correlation).
- **Label:** the correlation is conditional-on-occurrence — surface that.
- **Acceptance:** a `delta_lognormal + gaussian` latent fit converges
  (`convergence = 0`, no boundary), `extract_correlations()` returns
  `interval_status = "route-only"` rows using the positive-part residual, and an
  occurrence-RE formula fails loud.

## 2. M3 structural random-slope: runtime block confirmations

Design 75 says the slope tiers are interval-blocked (except the `rho:unit_slope`
Gaussian canary). Profile layer is ENFORCED (`profile-derived.R:692` aborts
non-Gaussian augmented profiles) — good.

- **`unit_slope` fisher-z path — CONFIRMED 2026-07-05 (Claude, done):** a
  converging augmented Gaussian fit's `extract_correlations(tier = "unit_slope")`
  **refuses** ("No covariance tiers found"), does NOT fabricate intervals;
  `extract_Sigma(unit_slope)` still returns the point covariance. Design 75's
  `Sigma_unit_slope`-blocked holds across profile (abort) AND fisher-z (refuse).
  No gap. (See the M3 kickoff note for the fixture/setup.)
- **Still open (Codex):** confirm `phy_*_slope` / `spde_*_slope` splits refuse
  intervals on every method (Design 75 "all blocked") — needs phylo/spatial
  augmented fixtures.
- Feeds **task #2** (ledger-reality sync: `.profile_route_matrix()` is
  profile-only; the wald/bootstrap/est-lik rows need this runtime evidence).

## 3. M4 non-Gaussian safety — AUDIT PASSED (no code item)

D-28 per-family link residuals implemented + referenced (`extract-sigma.R` fid
switch); zero-diagonal contract enforced by the auto-Psi family gate
(`fit-multi.R:4089`, single-trial binary skip) + all-or-nothing off-family gate
(ordinal/delta); OD-Poisson exception via the per-family OLRE selection
(`fit-multi.R:3953`). No live-fit item — recorded for completeness.

## Audit trail (my lane, done + pushed)

- M2: `docs/dev-log/after-task/2026-07-05-missing-mixed-postmerge-verification.md`
  + the `interval_status` marker (shipped, 4168/0).
- M3: `docs/dev-log/after-task/2026-07-05-structural-slope-hardening-kickoff.md`.
- Delta design: Design 02 §Hurdle/delta, register MIX-10/FAM-17, Design 57
  banner, gate-class sweep across Design 03/05/06.
