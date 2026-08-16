# After Task: package-native two-source iSDM PA recovery gate

## 1. Goal

Run the approved developer-only, synthetic PA recovery gate for the private
two-source `gllvmTMB` route: freeze the DGP and criteria, prove a local smoke,
then run the fixed 30-fixture Totoro campaign.  This task did not authorise a
count branch, comparator, spatial two-field implementation, empirical data,
public API, or article claim.

## 2. Implemented

`dev/isdm-package-recovery/` now contains a frozen PA protocol, a
package-native runner, and a Totoro launcher.  The runner uses the existing
private `.gll_isdm_fit()` route rather than the protected standalone G2
prototype.  It generates GBIF Poisson/log plus survey Bernoulli/cloglog data,
retains all three native restart rows, fit objects, truth, metrics, warnings,
and fixture provenance.  The post-campaign review repaired future-run controls:
the disconnected attack is truly source-disjoint, root summaries reject
overwrites, all three panels are required for completeness, and the launcher
rejects an existing result root.
The final D-43 hardening made those controls load-bearing: a finalised root
rejects additional fixtures; the retained panel must exactly match the frozen
scenario/replicate/seed grid with one package/runner/protocol provenance; the
package SHA is resolved from `--pkg`; non-finite metrics deterministically
fail; and a complete attack must show retained joint-target degradation.

### Mathematical Contract

The frozen DGP is

\[
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},\quad
e_{cs}\sim N(0,\psi_s^2),
\]

with GBIF \(Y^G_{cs}\sim\mathrm{Poisson}\{a^G_c
\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\}\) and PA
\(D_{cs}\sim\mathrm{Bernoulli}\{1-\exp[-a^S_c\exp(\eta_{cs})]\}\).
The fitted package formula uses the shared ordinary rank-one `latent()` field
and its default diagonal `Psi` companion.  The estimand is relative ecological
intensity, not absolute abundance or detection.  No public R API, likelihood,
formula grammar, family, NAMESPACE, generated Rd, vignette, or pkgdown
navigation changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** preserve the completed ordinary panel as a named HOLD and repair
the harness prospectively.  **Rationale:** all 20 ordinary fixtures are valid
and 0/20 pass, while the attack/provenance defects cannot turn that result into
a PASS.  **Rejected alternative:** rerun or reinterpret the old attack results
as if they were valid.  **Confidence:** high for the ordinary HOLD; no claim is
made about the invalid disconnected panel.

## 4. Files Touched

- `.gitignore` — ignores local/Totoro private recovery artifacts.
- `dev/isdm-package-recovery/2026-08-10-pa-recovery-protocol.md` — frozen DGP,
  seeds, thresholds, and claim fence.
- `dev/isdm-package-recovery/run-pa-recovery.R` — fixture generator, native fit,
  retained metric extraction, and immutable future-root summary logic.
- `dev/isdm-package-recovery/run-pa-totoro.sh` — one-build, at-most-30-worker
  Totoro launcher with isolated R library and result-root guard.
- `docs/dev-log/check-log.md` and this report — durable evidence boundary.

No README, NEWS, ROADMAP, vignette, roxygen, generated Rd, or public status
inventory file changed because this remains a private developer gate.

## 5. Checks Run

- `Rscript --vanilla ...run-pa-recovery.R --mode=validate --scenario=ordinary`
  — PASS (no-fit contract validation).
- `Rscript --vanilla ...run-pa-recovery.R --mode=fixture --scenario=ordinary
  --replicate=1` — PASS mechanically: retained non-empty smoke fixture, three
  native restart rows, selected converged fit, and positive-definite Hessian.
  Its incomplete one-fixture summary is correctly a HOLD, not evidence.
- Totoro preflight — PASS: 384 cores, load about 1.1, R 4.5.3, `devtools` and
  TMB available.  The first deployment at `19b3dfcf` failed before fitting
  because its isolated R library hid the user package library (`assertthat`);
  the failed root is retained.
- Totoro retry at `43bc9c63` — 30/30 fixture RDS plus summary retained;
  `OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1`, at most 30 workers.
- `Rscript --vanilla ...run-pa-recovery.R --mode=validate
  --scenario=disconnected` — PASS after the attack correction; no fit run.
- `Rscript --vanilla ...run-pa-recovery.R --mode=validate
  --scenario=ordinary|disconnected` — PASS after final root-provenance,
  seed-tamper, non-finite-metric, and all-20/eligible-summary hardening; no
  fit run.
- `bash -n dev/isdm-package-recovery/run-pa-totoro.sh` — PASS.
- `git diff --check` — PASS after each repair.

## 6. Tests of the Tests

The copied immutable retry bundle is git-ignored at
`dev/isdm-package-recovery/results/pa-campaign-20260810-retry1/`.  It contains
30 fixtures with one common runner and protocol hash.  All 20 ordinary fits
were eligible (three restart records, selected restart, convergence 0,
`pdHess = TRUE`, finite NLL), but **0/20** met every predeclared target; the
gate requires 18/20.  Median ordinary minimum map correlation was 0.624
(required 0.70), median shared-Sigma relative Frobenius error was 0.477, and
median maximum Psi-variance error was 0.237.  Therefore the ordinary-panel
verdict is `G2_PACKAGE_PA_HOLD`.

The test of the harness was adversarial rather than happy-path-only: its first
smoke caught a residual-DGP/extractor error before campaign launch; the remote
preflight caught a missing-library-path defect before a fit; and the D-43 panel
caught the invalid disconnected attack and mutable/incomplete summary contract.

## 8. Consistency Audit

```sh
rg -n 'G2_PACKAGE_PA|two-source iSDM|isdm-package-recovery|absolute intensity|empirical|spatial' README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design dev/isdm-package-recovery
rg -n 'gllvmTMB_internal_isdm|report_obs_nll|observation_nll|\.gll_isdm_fit|spatial_indep\(|spatial_latent\(' R src tests/testthat docs/design/111-isdm-nonspatial-recovery-protocol.md dev/isdm-package-recovery
rg -n 'GBIF|Artportalen|absolute intensity|empirical|spatial bias' README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design/111-isdm-nonspatial-recovery-protocol.md dev/isdm-package-recovery
```

Verdict: private route, recovery protocol, and boundaries are explicit; public
surfaces make no iSDM/recovery claim.  The status inventory was read and needs
no change because no public capability advanced.

## 9. What Did Not Go Smoothly

The first local smoke revealed a DGP residual-addition/extraction bug and was
preserved rather than overwritten.  The first Totoro deployment compiled but
failed before any fit because `R_LIBS_USER` excluded the preinstalled user
library.  The retry completed.  D-43 then found that the completed campaign's
disconnected panel was not actually disjoint and its root receipt lacked the
future-protocol immutability/completeness controls.  Those defects invalidate
the attack evidence, not the all-eligible, 0/20 ordinary-panel HOLD.

## 11. Team Learning

**Gauss/Noether** confirmed the DGP and package covariance decomposition match;
they also found the source-support attack did not match its own definition.
**Fisher** independently recomputed the stored metrics (maximum discrepancy
`6.66e-16`) and confirmed the ordinary HOLD, while flagging missing named
attack/root receipts.  **Rose** required the failed smoke/deployment roots and
the invalid attack to remain visible rather than becoming a silent retry.
**Curie**'s retained-fixture discipline made the ordinary result auditable.
The final Gauss/Noether, Fisher, and Rose re-review approved the prospective
harness only; it did not convert the retained old campaign into a pass.

## 7. Roadmap Tick

The developer protocol is the design record.  No public documentation,
pkgdown, validation-debt row, or roadmap status changed; **Roadmap tick: N/A**.

## 7a. Issue Ledger

`gh pr list --state open` was attempted before shared-document edits but the
GitHub API was unavailable.  No relevant open issue; no new issue created,
because the current result is a private HOLD and not ready for an issue
showcase.

## 10. Known Residuals

This task is **not closed as a full PA recovery promotion**.  Its defensible
state is: *ordinary package PA recovery HOLD; original disconnected attack
invalid; original root provenance incomplete*.  The repaired harness is ready,
but a fresh, separately approved recovery campaign is required before any PA
promotion.  The next scientific design decision should be whether to change
the information design (for example repeated linked PA events or a larger
survey-support regime) while retaining the free-Psi estimand and explicitly
re-freezing the DGP/thresholds.  Count, comparator, spatial two-field,
empirical source, and public work remain blocked.

## 12. Cross-Product Coverage

This arc covers only the product of: private package route × synthetic data ×
nonspatial rank-one-plus-free-Psi ecological field × GBIF Poisson/log × one
survey PA/cloglog event × Laplace fitting × three native starts.  It does NOT cover
count surveys, repeated-visit detection, alternative support regimes,
two spatial fields, `spatial_indep()`/`spatial_latent()` recovery, source
admission, empirical data, traits/phylogeny, a comparator, user-facing syntax,
or article readiness.  It also does NOT validate the original disconnected
attack panel or elevate the old standalone G2/G2a evidence.
