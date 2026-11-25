# After-task: MSPL interval arc — Phase A (complete) + B0 (complete); B1 gated on the fence call

**Date:** 2026-08-15 · **Lane:** Claude (`claude/mspl-interval-calibration` docs ·
`claude/mspl-b0-prereqs` code/harness) · **Platform:** Claude Code, single session.

## Scope

Rehydrated the Codex lane-B handover (MSPL interval feasibility, closed with a new
theory arc OWED), ran the ultra-planned Phase A (zero new compute), obtained maintainer
signatures D1–D6 on the Design 118 pre-registration, built the two signed code
prerequisites, and ran B0 on Totoro. Binary LA-MSPL only (logit/probit/cloglog);
non-binary families remain the Cursor Phase-4 lanes' property.

## Outcome

- **Phase A (6 slices + A1b, all archived at `docs/dev-log/mspl-interval-phase-a/`):**
  failure partition 26 over / 6 under / 1 availability / 22 Wilson-resolution; C011 is
  an INTRINSIC penalty-determined count-attractor (arithmetically proven, no bug);
  Kosmidis & Firth 2021 verified against the primary (caveat survives profiling,
  existence-only ⇒ regime-scoped claims legitimate); base construction chosen =
  level-calibrated penalised profile; exactly one non-jackknife BCa acceleration route.
- **Design 118 pre-registration SIGNED** (D1 signed · D2 reduced ≈26M · D3 Totoro→DRAC ·
  D4 refuse · D5 keep · D6 this lane) — merged to main in
  [#980](https://github.com/itchyshin/gllvmTMB/pull/980) (`aa2daa13`) with Design 117.
  Vault decision **D-148** records the signature set and promotes the jackknife
  rejection into the ledger.
- **Prerequisites built** ([#981](https://github.com/itchyshin/gllvmTMB/pull/981),
  open, high-risk class — do not merge on CI alone): `mspl_c_n_multiplier` probe hook
  (bit-identity 9.05e-12 at 1.0) + profile bracket-search fixes (fail-first tests).
  MSPL filter 634/0/5.
- **B0 complete** (`docs/dev-log/2026-08-15-b0-fence-roc-results.md`): 7,200/7,200 ok,
  32 s wall on Totoro, cleaned after (D-142). **P5 exact to 6 dp** (probe attractors =
  analytic prediction). Screen catches 509/509 saturated coordinates. **Two
  pre-registered gates FAILED as written**: probe detection 0.0000 (≥0.90) and the
  Route-B switch rule 0.8744 (≥0.95). **782 near-attractor non-saturated coordinates
  (10.9%) escape both fence lines.**

## Checks

Independent orchestrator spot-checks of every load-bearing number
(`docs/dev-log/mspl-interval-phase-a/orchestrator-spot-checks.md`); A6 mechanical
verify 6/6 PASS; Melissa plan-vs-actual **5 adaptive / 0 drift / 0 unclear**
(`docs/dev-log/plan-actual/2026-08-15-mspl-interval-calibration.md`); B0 gates
evaluated exactly as pre-registered — failures reported, not tuned away.

## Artefacts

B0 raw shards: 240 CSVs, tar.gz SHA-256
`a71bbf6a7e2eadfcae7a746c60d562da8cf204fe6cc7f88a3deb2976f99aec3a`, retained at
`~/Dropbox/Github Local/gllvmTMB-local-artifacts-b0-shards-20260815.tar.gz` (local,
never a GitHub artifact — D-50).

## 🔴 Open — blocked on the maintainer (by design; do not proceed without him)

1. **The fence amendment (§8 deviation):** adopt the attractor-proximity statistic as
   fence line 2 (recommended; fit-time observable, derived by A1b before B0, catches
   782/782 with 0/5,909 false positives) vs keep the fence as pre-registered. This is
   a change to a signed pre-registration — maintainer sign-off only.
2. **B1/B2 launch:** ≈2,900 core-hours on DRAC (measured from B0 timing). D-139
   default: no launch until (1) is decided.
3. [#981](https://github.com/itchyshin/gllvmTMB/pull/981) review/merge (src-touching).

## What this arc does NOT cover

No public fence lifted; MSPL-04 stays `blocked`. No interval coverage measured yet for
the 782-coordinate band (that is B1's per-cell gate). Spatial (`spatial_indep`/
`spatial_latent`) and q=2 remain Phase C, unmeasured and fail-closed. logLik/AIC/BIC/
LRT untouched.

## Resume

Next session: read this file, then Design 118 §8 for the pending deviation; if the
fence call is made, spec the B1 DRAC array from the B0 harness pattern
(`inst/sim/b0-fence-roc/`, fresh-seed rule, per-shard CSV).
