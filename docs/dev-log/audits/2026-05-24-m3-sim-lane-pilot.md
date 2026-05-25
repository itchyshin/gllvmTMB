# M3 sim lane pilot — accuracy + reliability check at n_reps=10

**Author**: Ada (lane lead) with Fisher (validation-design),
Curie (sim-fidelity), and Rose (scope honesty) lens consults.
**Coordinated with Codex** parallel lane (#257/#228 — speed,
convergence, diagnostic API).
**Date**: 2026-05-24 (pre-dispatch memo; results section will be
appended after the GHA run completes).
**Backed by**:
- Design 42 — M3 DGP grid for inference completeness
- Design 48 — M3.4 boundary-regimes (warm-start + phi-clamp)
- Design 50 — M3.3b surface-admission contract (controlling)
- Validation-debt register rows CI-08, CI-10 (NOT edited by this run)
- Issue #217 — Design 50 surface-admission tracker

## 1. Diagnostic-only disclaimer (READ FIRST)

**`n_reps=10` is below the Design 50 §5 `r50` admission floor.** All
coverage numbers in any artefact this dispatch produces are
**diagnostic-only**. **CI-08 and CI-10 stay `partial`** in the
validation-debt register. The deliberate non-update is part of the
lane assignment — no status change without evidence sufficient to
flip the row (Design 50 §9). The comprehensive accuracy + coverage
+ power simulation comes later, once all functionalities are in
place (maintainer 2026-05-24).

**The workflow file is named `m3-production-grid.yaml`** for
historical continuity with the 2026-05-19 production run. This
dispatch at `n_reps=10` is **a pilot, not a production run**. The
"production" string in the workflow name is a misnomer at this
sample size — preserved for run-URL traceability.

## 2. Lane scope (what this pilot IS)

**Headline target** (Fisher 2026-05-24 lens):

- **Accuracy**: per-cell median estimate/truth ratio on the
  rotation-invariant primary target
  `Sigma_unit[tt] = diag(Lambda Lambda^T + Psi)`, plus
  one-sided-bias flag (Design 50 §5).
- **Reliability triple**: convergence rate, `sdreport`/`pdHess`
  success rate, bootstrap-refit failure rate per cell.

**Diagnostic only** (computed, present in the artefact, but **NOT**
the headline):

- Bootstrap CI coverage on `Sigma_unit[tt]`.
- Profile CI coverage on `psi`.
- `pilot_status` from `m3_pilot_status()` — Design 50 §5 thresholds
  applied for screening only. **Relabelled in audit reporting as
  `pilot_status_diagnostic_at_r10`** to prevent §5 misread (per
  Rose 2026-05-24).

## 3. Pre-registered estimate/truth-ratio bands (Fisher)

Before the dispatch fires. Post-hoc band-narrowing is not allowed.

| Cell | Expected median ratio on `Sigma_unit[tt]` | What would count as "looks broken" |
|---|---|---|
| Gaussian × d∈{1,2,3} | 0.95–1.05 | ratio outside [0.85, 1.15] **or** one-sided-bias flag |
| binomial × d∈{1,2,3} | 0.90–1.05 (slight under-estimate of latent variance is common; link-residual standardisation) | ratio outside [0.80, 1.15] |
| nbinom2 × d∈{1,2,3} | 0.80–1.10 (ψ↔φ trade-off per Noether 2026-05-18 audit; Scenario B prediction) | ratio outside [0.65, 1.25] → flags **Scenario A** |
| ordinal-probit × d∈{1,2,3} | bootstrap unavailable per Design 50 §6 guard (`m3_bootstrap_supported()` refuses family-ID 14); profile-psi only as diagnostic | not evaluated — record fit reliability only |
| mixed × d=1 | 0.85–1.10 (`mixed` DGP = Gaussian+binomial+nbinom2 per Design 42 §2; **not** the 4-family Design 42 ideal) | ratio outside [0.70, 1.20] |
| mixed × d∈{2,3} | **EXPECTED-FRAGILE** (Design 48 §4: M3.4 does not claim to close mixed d≥2 convergence drop); fit-failure rate ≤30% per §5 family carve-out | fit-failure rate >50% → flag for stress-mapping (Codex lane) |

## 4. nbinom2 Scenario A vs B disambiguation

The 2026-05-19 production grid (workflow run 26100827665) measured
profile-`psi` coverage 0.38 on nbinom2 at R=200 (Design 48 §5, M3.3a
smoke confirmed 0.38 at R=10). This pilot disambiguates:

- **Scenario A**: `Sigma_unit[tt]` median estimate/truth ratio
  **outside [0.65, 1.25]** on any nbinom2 cell → the rotation-
  invariant total is genuinely biased. Diagnostic root-cause work
  hands off to #257/#228 (Codex's lane); this lane only records
  + reports.
- **Scenario B**: `Sigma_unit[tt]` ratio **inside [0.65, 1.25]**
  (and ideally inside [0.80, 1.10]) → `psi` is the unstable
  component (Noether: optimizer walks ψ↔φ trade-off ridge), but the
  TOTAL stays accurate. Profile-psi coverage is the wrong
  instrument; not a package bug.

**Local smoke hint (n=2 nbinom2 d=1, seed_base=20260524, this
worktree, 2026-05-24)**:

- `median_est_truth_ratio` on `Sigma_unit[tt]` = **0.865** — inside
  Scenario B band [0.80, 1.10]. **Hint, not evidence** at n=2.
- `median_est_phi_truth_ratio` = **0.617** — phi 38%
  under-estimated, confirming the ψ↔φ trade-off pathology Noether's
  audit predicted.
- `median_est_link_residual` = **2.76** (vs DGP truth ~1.0 → ratio
  1.39) — the optimizer is sharing variance between phi and the
  link-residual scale.
- `pd_hessian_rate` = **0 / 2** fits — **reliability flag** worth
  watching at the n_reps=10 scale.
- `boot_fail_rate` = 0.15 (within tolerance).

These are smoke signals only. The n_reps=10 dispatch produces the
first reportable evidence.

## 5. Dispatch parameters

After PR #258 (workflow + script patch) merges to main:

```
gh workflow run m3-production-grid \
  -F n_reps=10 \
  -F init_strategy=single_trait_warmup \
  -F targets=psi,Sigma_unit_diag \
  -F n_boot=25 \
  -F seed_base=20260524 \
  -F retention_days=14
```

Per Design 50 §3 estimand contract, every artefact row will carry:
`target`, `ci_method`, `ci_level` (=0.95), `fit_phi_mode`
(=`estimated`), `link_residual` (=`none`), `n_boot` (=25),
`n_cores_boot` (=1), `seed_base` (=20260524), `scenario`.

## 6. Cross-lane disclaimers (Rose)

These belong in every reporting artefact (this memo, the Issue #217
comment, the coordination-board entry):

- **`fit-failure rate`** is a reliability indicator on the m3-grid
  DGP at `n_units=60, n_traits=5`. It is **not** a convergence
  benchmark for `gllvmTMB::fit_*` — see Codex's #257/#228 lane.
- **`bootstrap-failure rate`** is the inner-loop ledger of
  `bootstrap_Sigma()` retries. It is **not** a restart / `n_init`
  benchmark — see Codex's lane.
- **`init_strategy`** is fixed at `single_trait_warmup` for this
  dispatch. This pilot does **not** compare init strategies.

## 7. Codex hand-off trigger (Fisher)

**Trigger condition**: any count-family cell (nbinom2 × d∈{1,2,3},
or the nbinom2 traits within `mixed` × d∈{1,2,3}) whose median
estimate/truth ratio on `Sigma_unit[tt]` falls **outside the
pre-registered band in §3 of this memo** → **Scenario A**.

**Action on trigger**:

1. **This lane records the observation** in the post-dispatch
   §8 results section of this memo.
2. **Comment on Issue #217** with the specific cell + ratio + the
   Scenario A label.
3. **Update `docs/dev-log/coordination-board.md`** to flag the
   handoff.
4. **Do not debug the engine here.** The diagnostic root-cause work
   lives in Codex's #257/#228 lane.

If all count-family cells land inside their pre-registered bands →
**Scenario B**. The lane records that, posts the same triple
(memo + Issue + coordination-board), and **CI-08 / CI-10 still stay
`partial`** because the n_reps=10 sample is below admission floor.

## 8. Post-dispatch results

**Run**: [26404672871](https://github.com/itchyshin/gllvmTMB/actions/runs/26404672871)
(workflow_dispatch, 2026-05-25 14:08 UTC).
**Inputs**: `n_reps=10`, `init_strategy=single_trait_warmup`,
`targets=psi,Sigma_unit_diag`, `n_boot=25`, `seed_base=20260524`,
`retention_days=14`.
**Matrix outcomes**: 15 / 15 jobs returned `success` (no compute
crashes). Five cells were flagged `COMPUTE_FAIL` by
`m3_pilot_status()` (Design 50 §5 thresholds) — see table; these
are diagnostic flags inside the artefact, not GHA failures.

### 8.1 Accuracy headline — median estimate/truth ratio on `Sigma_unit[tt]`

| Family | d=1 ratio | d=2 ratio | d=3 ratio | Pre-registered band | d=1 in-band | d=2 in-band | d=3 in-band |
|---|---|---|---|---|---|---|---|
| Gaussian | **1.172** | 1.087 | 1.045 | [0.85, 1.15] | ❌ (just over) | ✅ | ✅ |
| binomial | **0.244** | **0.325** | **0.425** | [0.80, 1.15] | ❌ (severe) | ❌ (severe) | ❌ (severe) |
| nbinom2 | **0.558** | 0.743 | **0.640** | [0.65, 1.25] | ❌ | ✅ | ❌ (just under) |
| ordinal-probit | n/a | n/a | n/a | bootstrap unavailable (§6 family-ID 14 guard) — psi-only diagnostic | n/a | n/a | n/a |
| mixed | 0.917 | 0.999 | 0.703 | d=1 [0.70, 1.20]; d∈{2,3} expected-fragile | ✅ | (band n/a — expected-fragile) | (band n/a — expected-fragile, borderline) |

### 8.2 Reliability headline

| Family | d | Convergence | `pd_hessian_rate` | `sdreport_ok_rate` | `boot_fail_rate` | `pilot_status_diagnostic_at_r10` |
|---|---|---|---|---|---|---|
| Gaussian | 1 | 10/10 | 1.0 | 1.0 | 0.000 | `TARGET_FAIL` |
| Gaussian | 2 | 10/10 | 1.0 | 1.0 | 0.004 | `TARGET_FAIL` |
| Gaussian | 3 | 9/10 | 0.2 | 1.0 | 0.022 | `TARGET_FAIL` |
| binomial | 1 | 10/10 | 0.9 | 1.0 | 0.000 | `TARGET_FAIL` |
| binomial | 2 | 10/10 | 0.7 | 1.0 | 0.008 | `TARGET_FAIL` |
| binomial | 3 | 10/10 | 0.6 | 1.0 | 0.016 | `TARGET_FAIL` |
| nbinom2 | 1 | 10/10 | 0.4 | 1.0 | 0.124 | `TARGET_FAIL` |
| nbinom2 | 2 | 9/10 | 0.3 | 1.0 | **0.218** (> 0.20 floor) | `COMPUTE_FAIL` |
| nbinom2 | 3 | 10/10 | 0.4 | 1.0 | 0.168 | `TARGET_FAIL` |
| ordinal-probit | 1 | 10/10 | 0.6 | 1.0 | 0.000 (no boot) | `COMPUTE_FAIL` (expected: bootstrap unsupported) |
| ordinal-probit | 2 | 10/10 | 0.7 | 1.0 | 0.000 (no boot) | `COMPUTE_FAIL` (expected) |
| ordinal-probit | 3 | 10/10 | 0.9 | 1.0 | 0.000 (no boot) | `COMPUTE_FAIL` (expected) |
| mixed | 1 | 9/10 | **0.0** | 1.0 | 0.036 | `TARGET_FAIL` |
| mixed | 2 | 10/10 | **0.0** | 1.0 | 0.096 | `TARGET_FAIL` |
| mixed | 3 | 6/10 (40% fail; > 30% mixed allowance) | **0.0** | 1.0 | **0.227** | `COMPUTE_FAIL` |

### 8.3 Diagnostic coverage values (NOT headline, NOT promotion evidence)

| Family | d | Coverage on `Sigma_unit[tt]` (bootstrap) | Coverage on `psi` (profile) |
|---|---|---|---|
| Gaussian | 1/2/3 | 0.80 / 0.88 / 0.87 | 0.80 / 0.64 / 0.89 |
| binomial | 1/2/3 | 0.76 / 0.84 / 0.84 | 0.94 / 0.80 / 0.90 |
| nbinom2 | 1/2/3 | 0.76 / 0.80 / 0.68 | 0.44 / 0.38 / 0.28 |
| ordinal-probit | 1/2/3 | n/a (§6 guard) | 0.70 / 0.74 / 0.60 |
| mixed | 1/2/3 | 0.82 / 0.82 / 0.70 | 0.78 / 0.60 / 0.53 |

**All coverage values are DIAGNOSTIC ONLY**. At n_reps=10 with MCSE ≈ ±15 pp, none of these values can support a coverage claim. The audit memo §1 disclaimer holds.

### 8.4 Verdict — Scenario A confirmed, broader than nbinom2

Pre-registered trigger (§7) was: "any count-family cell outside its band → Scenario A → hand off to Codex's #257/#228."

**Observed**: nbinom2 fired Scenario A (d=1 and d=3 outside the [0.65, 1.25] band). **But the bigger signal is binomial** — all three d-levels show severe under-estimate of `Sigma_unit[tt]` (median ratios 0.24, 0.32, 0.42 — well below the [0.80, 1.15] band). Gaussian d=1 just exceeds its upper bound (1.17 vs 1.15).

This is consistent with **a systematic under-estimate of the rotation-invariant total** on link-residual-bearing families, not just the ψ↔φ trade-off Noether's audit predicted for nbinom2. The diagnostic root-cause work belongs in #257/#228 (Codex's lane).

Hypotheses worth investigating in the Codex lane (NOT this lane's job):

1. **Latent-scale vs response-scale unit mismatch.** The `est_diag_sigma` vs `truth_diag_sigma` ratio comparing a fit on one scale to a DGP truth on the other would produce systematic biases like these. The binomial ratio of 0.24-0.42 ≈ 3/π² (logit link-residual π²/3 ≈ 3.29) raises a units-flag worth checking.
2. **Warm-start asymmetry.** `init_strategy=single_trait_warmup` activates only for count families with phi. Gaussian, binomial, ordinal-probit don't receive warm-up; their `Sigma_unit[tt]` estimates rely on default init. Worth comparing `init_strategy=default` vs `single_trait_warmup` on the same seed to isolate the contribution.
3. **`mixed × d=3` convergence collapse** (40% fit-failure) — Design 48 §4 expected this; the artefact records it; Codex's lane could improve via per-family init separation.

Reliability headlines worth flagging:

- **`pd_hessian_rate = 0` on all mixed cells**. Zero of the converged mixed-family fits had a positive-definite Hessian. `sdreport` still returned OK (1.0) — TMB falls back to a generalised inverse — but this is a fit-health red flag worth Codex's eyes.
- **`pd_hessian_rate` averages ~0.5 on count cells**. Half the count-family fits have non-pd Hessians. Connects to the ψ↔φ ridge pathology Noether documented.
- **bootstrap-fail rates 12–22% on count cells** (nbinom2 d=2 + d=3 + mixed d=3). At n_reps=10 each cell ran 250 bootstrap refits (10 × 25); 15-22% failures = ~40-55 refits failing per cell.

### 8.5 What this run did NOT change

Per Design 50 §9 and the audit memo §1 + §10 disclaimer:

- **CI-08 stays `partial`.** No row promotion.
- **CI-10 stays `partial`.** No row promotion.
- **No edit to** `ROADMAP.md`, `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/`, `R/diagnose.R`,
  `tests/testthat/test-sanity-multi.R`.
- **No engine / R/ source change.**
- **No comprehensive-coverage claim.** That sim runs once functionality is in place (maintainer 2026-05-24).

### 8.6 What this run hands to Codex (#257/#228 lane)

1. **15-cell artefact** retained 14 days on the GHA run page (run id 26404672871). Per-cell long-format RDS at `dev/precompute*/` artefact downloads.
2. **3 hypothesis prompts** in §8.4 above — unit-mismatch, warm-start asymmetry, mixed-d=3 collapse.
3. **No engine debugging from this lane.** Codex owns the root-cause path. This lane's job is now done after the comments + lane-close steps below.

### 8.7 Cross-lane reminders (Rose)

- **`fit-failure rate`** is a reliability indicator on the m3-grid DGP at `n_units=60, n_traits=5`. **Not** a convergence benchmark for `gllvmTMB::fit_*`.
- **`bootstrap-failure rate`** is the inner-loop ledger of `bootstrap_Sigma()` retries. **Not** a restart / `n_init` benchmark.
- **`init_strategy`** was fixed at `single_trait_warmup`. This pilot did **not** compare init strategies.
- **`pilot_status_diagnostic_at_r10`** values above are NOT Design 50 §5 admission decisions. The `_diagnostic_at_r10` suffix on the column name is the deliberate flag against §5 misread.

### 8.8 Lane close

This M3 sim lane closes at 2026-05-25. PR with the post-dispatch
memo + coord-board move-to-resolved + Issue #259 verdict comment is
the final artefact.

The comprehensive accuracy + coverage + power simulation referenced
by the maintainer 2026-05-24 ("once all the functionalities are in
place") remains future work. This pilot's contribution to that
future work: a target-explicit dispatch contract on the workflow,
a pre-registered ratio-band methodology, and a 15-cell snapshot of
where the rotation-invariant `Sigma_unit[tt]` estimator currently
sits.

## 9. Cross-references

- Plan: `~/.claude/plans/please-have-a-robust-elephant.md`
  (M3 simulation lane section at the top).
- Workflow PR: #258 (`agent/m3-workflow-targets-nboot-seed`).
- Design 42 §3 — primary target ratification (2026-05-19 update).
- Design 48 §5 — M3.4 pre-implementation expectations (the 0.38
  nbinom2 figure that prompted the maintainer's flag).
- Design 50 §3 §5 §6 §9 — controlling contract for this dispatch.
- Noether 2026-05-18 audit — ψ↔φ trade-off documentation:
  `docs/dev-log/audits/2026-05-18-noether-nbinom2-identifiability.md`.
- 2026-05-19 target-scale audit:
  `docs/dev-log/audits/2026-05-19-m3-3-target-scale-audit.md`.
- Cross-package count-inference scout (Jason 2026-05-18):
  `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`.
- Codex parallel lane: #257 (PR), #228 (issue), #248 (issue).

## 10. Files NOT edited by this dispatch (Shannon's lane assignment)

- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/`
- `R/diagnose.R`
- `tests/testthat/test-sanity-multi.R`

Plus per Design 50 §9: **register rows CI-08 and CI-10 are NOT
updated**. Their `partial` status stays. The audit memo records the
deliberate non-update.
