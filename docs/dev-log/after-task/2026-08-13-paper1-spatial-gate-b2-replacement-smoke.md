# After-task — Paper 1 spatial Gate-B2 replacement smoke

**Status:** `PRIVATE_SPATIAL_SMOKE_PASS` for one named synthetic fixture only.
This supersedes neither the historical `PRIVATE_SPATIAL_SMOKE_HOLD` nor any
Paper 2 hold: it records a distinct, fresh, one-attempt Paper 1 receipt.

## 1. Task goal

Make the failed 2026-08-12 Paper 1 spatial smoke observable, then conduct one
fresh, seed-pinned local attempt only if the pre-run estimate was at most 30
minutes. No recovery campaign, profile, retry, Paper 2 work, remote compute,
or public surface work was in scope.

## 2. Mathematical contract

No public R API, likelihood, formula grammar, family, TMB parameterisation, or
DGP constant changed. The existing two-column SPDE route remains
`spatial_latent(1 + isdm_gbif | cell_id, d = 1)`: its intercept is the
ecological field and its GBIF-gated slope is the bias field. The fixture retains
independent ecological and bias draws (`correlation = 0`) and PA rows retain no
GBIF bias covariate. The only changed DGP item is a fresh replacement seed,
86202, not a parameter or threshold.

## 3. Files changed

- `dev/isdm-package-recovery/run-spatial-isdm-gate-b-smoke.R` — durable
  terminal ledger, immutable-clean-tree receipt check, and downstream telemetry.
- `dev/isdm-package-recovery/spatial-isdm-gate-b-smoke-fixture.R` — fresh seed
  and the terminal all-attempt schema helpers.
- `dev/isdm-package-recovery/2026-08-13-paper1-spatial-gate-b2-receipt-alignment.md`
  — symbolic receipt-to-estimand alignment.
- `tests/testthat/test-spatial-isdm-gate-b2-receipt-contract.R` — pure no-fit
  fixture, map, ledger, finalisation, and consumed-root checks.
- This report, the recovery checkpoint, and the check-log entry.

No README, NEWS, ROADMAP, vignette, pkgdown, roxygen, generated Rd, public
design note, or validation-debt register was changed; this is not an advertised
capability change.

## 4. Checks run

- Both targeted no-fit suites passed:
  `test-spatial-isdm-gate-b2-receipt-contract.R` and
  `test-isdm-spatial-private-contract.R`.
- `git diff --check` passed before both safeguard commits.
- Independent Gauss/Noether-style review found and corrected preservation of
  `extractor_truth_map`; independent Rose-style review found and corrected
  uncommitted-estimator drift. Both confirmed no likelihood/DGP/map change.
- Preflight passed at commit `d5c1481c8ffba7cec5a68ebb8de778426e88e0b5`.
- The pre-run estimate was 5–15 minutes. The one local fit returned in 12.324
  seconds: finite objective 2467.705970; optimizer code 0; maximum absolute
  gradient 0.003392914; PD Hessian TRUE; zero boundary flags and warnings.
  Both recorded 3 x 3 field outputs were finite and symmetric.
- A second `--mode=smoke` invocation rejected the consumed root before a model
  call: `this immutable root has already consumed its one Gate-B smoke attempt`.

## 5. Consistency audit

`rg -n 'SPATIAL_ISDM_GATE_B2|paper1-spatial-b2|PRIVATE_SPATIAL_SMOKE' README.md ROADMAP.md NEWS.md docs vignettes R tests`
found only the intended private receipts, runner/test identifiers, and the
historical HOLD. No public claim or Paper 2 promotion was introduced.

## 6. Tests of the tests

The receipt test is prophylactic plus boundary coverage: it validates the
terminal `FIT_ERROR` schema, rejects a missing ledger field, checks separate
field draw seeds and PA-source purity, and statically proves ledger finalisation
precedes telemetry. The consumed-root execution check supplies the corresponding
post-success rejection path. It does not claim an end-to-end injected crash
test; R's `on.exit()` finaliser is additionally inspected in the runner.

## 7. What did not go smoothly

The first historical smoke failed after fit because a Linux-only `/proc` probe
was treated as mandatory telemetry. B2 avoids that failure mode by making RSS
optional and saving the terminal ledger before telemetry. macOS therefore
records `peak_rss_kb = NA`, a machine limitation retained visibly rather than
inventing a value.

## 8. Team learning

**Gauss / Noether:** verified that the engine already represents independent
intercept and GBIF-slope SPDE fields and that the reported covariance blocks
match the truth map. They caught loss of the extractor map during ledger update.

**Rose:** verified the one-attempt receipt and scope fences, and caught that
`HEAD` alone did not protect against uncommitted loaded estimator source. The
runner now requires a clean tracked tree.

**Fisher:** the adjudication separates numerical admission from recovery: a
single successful fixture cannot identify a recovery rate or establish spatial
separation generally.

## 9. Design/docs and roadmap

The private symbolic alignment note was added. **Roadmap tick:** N/A; private
Gate-B2 evidence does not alter a public roadmap row or status chip.

## 10. GitHub issue ledger

Inspected open PRs #958, #957, #956, and #955 for shared-file collisions; none
owns this private Paper 1 spatial receipt. No issue was created, commented on,
or closed: this bounded evidence record has no public tracker action.

## 11. Limitations and next action

This is one successful numerical-admission smoke for `C = 360`, `S = 3`, three
PA visits, one seed, and one start. It provides no recovery, coverage,
identifiability, empirical, occupancy/detection, absolute-abundance,
generic-zero-inflation, arbitrary-source, Paper 2, C=1,000, or 10,000-species
claim. The next action requires explicit approval: independently adjudicate
whether this private smoke warrants a Paper 1 `C = 360` recovery campaign, with
the all-attempt metrics, machine, seed panel, budget, and compute estimate fixed
before any campaign starts.
