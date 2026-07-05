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
- **THE FIX = the design, with a specific target:** split the delta linear
  predictor so the **latent (random-effect) contribution drives only the
  positive component**, while the **occurrence component stays
  fixed-effects-only**. Concretely at `src/gllvmTMB.cpp:2037` (+ the delta_gamma
  twin ~2052): stop sharing the full `eta` across both parts — route the
  random-effect contribution into the positive-part `eta` only; keep the presence
  `eta` fixed-effects-only. Then the latent scale is single + identified (expect
  `pdHess = TRUE`). A Totoro multi-seed recovery run CONFIRMS it across seeds once
  implemented.
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
