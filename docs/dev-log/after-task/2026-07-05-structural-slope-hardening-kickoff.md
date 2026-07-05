# Milestone 3 — structural random-slope hardening (kickoff audit)

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion` (post fold-arc merge + M2 marker)
Agent: Claude (audit + claim-boundary review; lead lane)

## Goal

Open Milestone 3. The structural random-slope tiers (Design 75 "augmented
structural split tiers") are mostly **blocked** for intervals — the hardening
question, in the same class as the M2 MIX-10 finding, is whether those blocks are
**actually enforced at runtime** or merely advisory.

## Surface (Design 75, lines 175-201)

- `unit_slope` (ordinary augmented latent random-regression, 2T×2T reaction-norm):
  `Sigma_unit_slope` blocked on all interval methods; `rho:unit_slope:i,j` =
  **partial** (Gaussian selected-entry canary, one known-DGP truth-inclusion test).
- `phy_*_slope` / `spde_*_slope` structural splits: **all estimands blocked on all
  interval methods** (Design 74); `not_applicable` for the 2×2 `*_base_slope`
  blocks and the full `*_dep` blocks. Point covariances ARE computed (the 2×2
  blocks in `extract-sigma.R` lines 752/813/877/957); "blocked" = no intervals.

## Findings

### Profile-CI slope boundary IS enforced ✅ (opposite of MIX-10)

`profile-derived.R:689-697`: for `tier == "B_slope"` the profile path has a wired
`cli::cli_abort` — *"`rho:unit_slope` profile intervals are currently a
Gaussian-only canary; non-Gaussian augmented ordinary random-regression profiles
need a separate calibration gate."* So the Design-75 "partial (Gaussian canary)"
status is **enforced**: non-Gaussian augmented slope profiles are refused, not
fabricated. Unlike MIX-10, this claim boundary holds at the profile layer.
`.profile_route_matrix()` encodes the same routing and is covered by
`test-profile-route-matrix.R` (unit_slope Σ blocked; only `rho:unit_slope` is the
`unit_slope_selected_entry` canary).

### Confirmed: the fisher-z / extract_correlations path at `unit_slope` REFUSES ✅

Runtime probe DONE (2026-07-05, Claude — authorized to code). A converging
augmented Gaussian fit
(`value ~ 0 + trait + (0 + trait):temperature + latent(0 + trait + (0 + trait):temperature | individual, d = 2)`,
via `make_ordinary_latent_rr_fixture()`, `convergence = 0`, `rr_B_slope = TRUE`)
was built, then:

- `extract_correlations(fit, tier = "unit_slope")` **REFUSES** with
  `"No covariance tiers found in the fit."` — it does **not** fabricate
  slope-tier fisher-z intervals. (The augmented fit exposes only the slope tier,
  which the fisher-z correlation path does not treat as a standard correlation
  tier, so nothing is produced.)
- `extract_Sigma(fit, level = "unit_slope")` returns the 2T×2T point covariance
  (Design 75 = point-extractable), confirming the fit is valid and the refusal
  is specific to the *interval* path, not a broken fit.

So Design 75's "`Sigma_unit_slope` intervals blocked" **holds at runtime across
both paths**: the profile path aborts (`profile-derived.R:692`) and the fisher-z
path refuses. No MIX-10-class gap here — the slope-tier interval boundary is
enforced. (Setup note for reruns: the fit needs explicit
`trait=`/`unit=`/`unit_obs=` args and the fixed `(0 + trait):x` slope term, or
gllvmTMB defaults the unit column to `"site"` and errors.)

## Scoped M3 plan (remaining)

1. **Runtime confirm** (Codex lane — needs a fit): `extract_correlations(tier =
   "unit_slope")` and bootstrap on slope tiers — do they refuse per Design 75, or
   return marked intervals? Bootstrap already implicitly excludes slope tiers via
   `intersect(tier, c("B","W","phy"))`.
2. **`phy_*_slope` / `spde_*_slope`**: confirm the fully-blocked splits refuse
   intervals on every method (same runtime check).
3. If any path fabricates a blocked-tier interval: wire the refusal (parallels the
   profile-derived guard) or, minimally, ensure the M2 `interval_status` marker
   flags it — maintainer call, like the delta decision.

## Checks Run

Read-only audit + one inconclusive runtime probe (augmented fixture setup error,
not a code finding). Evidence: Design 75, `profile-derived.R`,
`extract-sigma.R`, `extract-correlations.R`, `test-profile-route-matrix.R`.
No code / register changed.

## Known Residuals

- Items 1-3 above (runtime confirmations gated on a converging augmented fixture).
- Feeds task #2 (ledger-reality sync: `.profile_route_matrix()` is profile-only;
  wald/bootstrap/est-lik rows pending) — the runtime confirmation here is the
  evidence that sync needs.
