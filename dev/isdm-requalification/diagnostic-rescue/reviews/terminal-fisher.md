# Fisher terminal review — integrated-JSDM diagnostic rescue

Date: 2026-08-29  
Role: estimand, screening-rule, and statistical-interpretation review  
Verdict: **PASS**

The retained evidence supports the frozen `next_action = "MIXED"` disposition.
It supports one narrow follow-up experiment; it does not identify a general
failure cause, justify an engine change, or alter any production gate.

## Evidence and denominator verification

The experiment manifest verifies cleanly with `sha256sum -c`. The retained
plan contains exactly 52 unique task identities: 16 nonspatial tasks and 36
spatial tasks. There are exactly 52 started receipts and 52 worker terminal
records, with no coordinator-created terminal record. All 52 statuses are
`fit_returned`; errors, interruptions, and unavailable records are all zero.
Target availability is complete: 16/16 for every nonspatial target and
curvature target, and 36/36 for spatial held-out prediction, curvature, and
joint precision. All eight planned nonspatial pairs are available. All eight
originally ineligible spatial sentinels are comparable under both optimizer
contrasts.

I independently reran the pure-reader summarizer in memory from `plan.rds` and
the 52 retained attempt records. Its result is byte-identical at the R-object
level to `independent-summary.rds`; it reproduces five `FALSE` signals and
`next_action = "MIXED"`. The focused receipt tests also pass.

## Findings

### P2 — PASS: zero fired signals maps to `MIXED` by the approved rule

The approved plan states that exactly one fired signal selects its named
follow-up, whereas two or more signals **or no signal** yield `MIXED` and only a
narrower discriminating experiment (`LOOP/ultra-plan.md:242-244`). The
independent summarizer implements exactly that mapping after evaluating all
five frozen predicates (`summarise-independent.R:221-255`). Because the saved
and independently recomputed vector is

`REPLICATION = FALSE, ESTIMAND = FALSE, BASIN = FALSE, TERMINATION = FALSE, CURVATURE = FALSE`,

`MIXED` is the preregistered result. It must not be replaced post hoc by the
name of whichever partial pattern looks most interesting.

### P2 — The nonspatial result supports a surface-specific information lead

Adding two independent responses per observed source-cell-trait improved the
full conditional surface in all 8/8 selected pairs. Full-surface nRMSE fell by
a median 0.1283 (IQR 0.1246 to 0.1384), and full-surface correlation increased
in 8/8 pairs by a median 0.0795 (IQR 0.0695 to 0.0860). A supplementary paired
read of the retained table shows that the shared latent surface also improved
in all 8/8 pairs: median nRMSE reduction 0.0857 and median correlation increase
0.0591. Fixed-surface nRMSE improved in only 6/8 pairs with a much smaller
median reduction, 0.0067.

This supports the narrow statement that, for these eight frozen fixtures,
additional within-cell response information improved recovery of the shared
and full ecological surfaces. Because `rep3` preserves the baseline rows and
adds two independently generated responses under the same truth, the paired
contrast is interpretable as the effect of added response information within
each selected fixture.

It does not satisfy `REPLICATION_SIGNAL`, because species-1 `Psi` error improved
in only 4/8 pairs rather than at least 6/8, and its median reduction was
-0.0355 (IQR -0.1560 to 0.1590) rather than at least 0.10. The data therefore do
not support a single claim that replication jointly repairs surfaces and the
unique-variance component.

### P2 — The result does not support changing the scored estimand

No baseline pair met the compound `ESTIMAND_SIGNAL` requirement that the shared
surface have nRMSE at least 0.10 below the full surface while also having no
lower correlation. The observed baseline full-minus-shared nRMSE gaps ranged
from -0.1330 to 0.0837. Thus the evidence does not show that the historical
failure is chiefly an artefact of scoring the full conditional surface rather
than the shared surface. The fixed, shared, and full estimands remain distinct;
raw latent axes are not interpreted.

### P2 — The spatial result rejects the two prespecified optimizer screens

All eight originally ineligible sentinels were comparable for both `nlminb5`
and BFGS continuation, but 0/8 passed either compound rescue predicate. BFGS
continuation changed each of the four default nonconverged/non-PD cases to
converged/non-PD, but did not make any of them PD. This is evidence that a
longer/different termination route can alter the convergence flag for these
sentinels without resolving the curvature eligibility failure. It is not
evidence that BFGS or more starts repairs the spatial model.

### P3 — Curvature shows a class-stratified lead, not a dominant cause

Native and relative-coordinate block rankings agreed for all 12 default
sentinels. `theta_rr_spde_lv` was the largest normalized block in 8/12, with
median normalized mass 0.991 among those eight, but the frozen curvature rule
requires at least 9/12. The remaining four defaults were all dominated by
`log_kappa_spde`; descriptively, those four were the converged/non-PD class,
whereas the four converged/PD and four nonconverged/non-PD defaults were
`theta_rr_spde_lv`-dominated.

That exact 4/4/4 pattern is worth retaining as a lead, but there is only one
outcome-stratified sentinel per class in each design cell. Curvature attribution
is parameterization-dependent and was preregistered as descriptive. It does
not establish that either parameter block causes non-identifiability, and it
does not justify a TMB parameterization or optimizer change.

## What the experiment supports

- The denominator is complete and the all-false signal vector is reproducible.
- `MIXED` is the correct frozen screening label.
- Added within-cell responses improved shared and full surface recovery in all
  eight selected nonspatial fixtures.
- The same intervention did not consistently improve species-1 `Psi` recovery.
- Neither prespecified spatial optimizer intervention converted the ineligible
  sentinels to qualifying converged/PD fits.
- Weak fixed-Hessian directions show a descriptive, outcome-class-specific
  block pattern that needs independent replication.

## What the experiment does not support

It does not estimate mechanism prevalence: each nonspatial cell contributes one
paired seed, and spatial seeds were selected by historical outcome class. It
does not prove causation beyond the within-fixture replication contrast, prove
that `Psi` is generally unrecoverable, endorse shared-surface rescoring, diagnose
an engine defect, validate intervals, justify replacement production attempts,
retune a threshold, or support public capability promotion.

## Exactly one next technical action

Run **one preregistered, nonspatial-only paired multi-seed replication-
discrimination experiment**. In the same eight design cells, select additional
immutable production seeds and compare only baseline one-response fits with
paired `rep3` fits under the unchanged public route and DGP. Freeze separate
co-primary contrasts for shared/full surface nRMSE and correlation and for all
three diagonal `Psi` errors before compute. The question is whether the
unanimous surface improvement persists across seeds while variance-component
recovery remains inconsistent. Do not include spatial optimizer arms, modify
the engine, rescore historical production, or change any gate in this action.

This is a narrower discriminating experiment, not the larger confirmatory
within-cell-information campaign that the unfired `REPLICATION_SIGNAL` would
have selected.

## Final disposition

P0: none. P1: none. The evidence, frozen logic, and claim boundary pass this
review. `MIXED` should be retained, together with the single bounded next action
above.
