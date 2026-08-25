# Plan vs Actual: Design 73 C1 LV Closeout

Date: 2026-08-25
Plan:
`docs/dev-log/plans/2026-08-25-lv-design73-c1-closeout-ultra-plan.md`
Branch: `codex/lv-family-evidence-reconcile`
Reviewer lens: Melissa
Status: complete; local-only landing verified

## Summary

The lane stayed inside the approved bounded C1 destination. It did not mutate
GLLVM.jl, launch a duplicate family campaign, broaden the estimand, add source
tiers or families, or promote umbrella validation rows. The evidence,
scientific review, article, and non-colliding status cascade are complete.
The maintainer explicitly approved releasing the stale interval-calibration
lease. This lane refreshed the complete exact-path lease, finished the shared
status/navigation cascade, and passed pkgdown and pre-panel Unlazy checks.

## Scope reconciliation

| Planned scope | Actual | Classification |
| --- | --- | --- |
| Native ordinary Gaussian rank-1/rank-2 C1 closure | Source-pinned recovery and conditional-on-eligible Wald evidence recorded; article teaches rank 1 and states the rank boundary | aligned |
| Native rank-1 multi-trial binomial logit/probit/cloglog closure | All 1,500 attempts and MCSE boundary recorded; no binomial article fit added | aligned |
| Keep factor intervals, masks, broader families/ranks, tiers, REML, and fixed `X + X_lv` out | All remain explicit negative space | aligned |
| Preserve Julia point route with optional uncalibrated Wald plumbing | Receipt and Design 73 use the exact boundary | aligned |
| Preserve common-family sister-evidence HOLD | Exact verdict retained; no campaign launched | aligned |
| Add Tier-1 article and navigation | Article written, evaluated, visually inspected, added to both pkgdown navigation surfaces, and checked by pkgdown | aligned |

## Evidence reconciliation

| Planned evidence | Actual evidence | Classification |
| --- | --- | --- |
| Pin source, commits, DGP, estimand, families, denominators, MCSE, failures | Closure receipt includes all requested fields and full commit hashes | aligned |
| Test Poisson generator bug | Source-pinned positive/negative control passed | aligned |
| Test finite-difference Hessian fix | Source-pinned positive/negative control passed | aligned |
| Do not target raw (\alpha) or (\Lambda) across fits | Receipt, design, article, and review use (B_{lv}) | aligned |
| Historical profile non-transfer | Designs 73/76 and historical README now state the current public withdrawal and REML refusal | aligned |
| Bridge endpoint exposed but not calibrated | Current R source/tests and receipt distinguish payload plumbing from calibration | aligned |

## Routing and team reconciliation

| Planned slice | Actual | Classification |
| --- | --- | --- |
| G0 Ada + Shannon | Preflight, PR census, branch/base, narrow lease, Unlazy ledger completed | aligned |
| S1 Jason / Luna low | Read-only provenance report completed under `.unlazy` | aligned |
| S2 Gauss + Noether + Fisher / Terra high | Scientific cell matrix completed under `.unlazy` | aligned |
| S3 Ada integration | Source-pinned closure receipt completed | aligned |
| S4 Boole + Pat / Terra medium | Documentation writer produced only the owned article; parent ran fits/render | aligned |
| S5 status reconciliation | Disjoint paths completed first; after explicit stale-lease release, shared register/NEWS/pkgdown/check-log/ignore paths were reconciled | adaptive, required by ownership protocol |
| S6 mechanical verification | Focused tests, artifact controls, render, screenshot, static scans, pkgdown, and pre-panel `--reverify` passed | aligned |
| S7 2-Terra/1-Sol panel | Gauss/Emmy, Rose/Grace, and Noether/Fisher passed the first frozen tree; one non-blocking P2 wording nuance was repaired and all three reverified the new tree PASS | adaptive and complete |
| S9–S11 closeout and landing | Reports and handover validated; one narrow local commit created; clean tree, final `--reverify`, full after-task validator, and lease release passed | aligned and complete |

## Safety and compute reconciliation

- Planned projection: 10–25 minutes locally.
- One-fit smoke estimate: 1–3 minutes; measured 0.912 seconds.
- Evaluated two-fit article render: 2.659 seconds.
- Focused tests: 55.837 seconds.
- No individual run or total local batch approached 30 minutes.
- No Totoro, DRAC, live GLLVM.jl fit, GitHub Actions science compute, or
  500-replicate rerun occurred.
- Failed attempts were retained in the after-task report rather than erased.

Safety classification: **aligned**.

## Public-claim reconciliation

The article claims only the native ordinary Gaussian teaching route and names
the existing binomial interval subcells in its boundary. It uses
associational language, native (\Lambda\Lambda^\top+\Psi), trait-scale
(B_{lv}), Wald output, and total/mean/innovation. It contains no internal
row IDs, raw-axis cross-fit comparison, REML, profile/bootstrap demonstration,
or broad Julia/family/tier claim.

Public-claim classification: **aligned**; the frozen Rose/Grace panel passed.

## Deviations

### Adaptive

- The first broad lease was refused, so the lane narrowed its owned paths and
  ran S1/S2/S3/S4 plus the disjoint part of S5.
- The full plan file replaced an initial condensed version before
  implementation continued.
- The article uses no ordinary fixed-effect predictor because current C1
  rejects every fixed `X + X_lv` combination. This resolves the older
  Design 73 article wording in favour of the current implementation contract.
- The maintainer explicitly released a stale shared-file lease after the
  protocol correctly blocked the first broad claim.
- The Sol panel identified one P2 wording nuance: explicit `unique = FALSE`
  is canonical, while default ordinary `latent()` warning-demotes to the same
  Julia loadings-only fitted model. Two internal evidence/status files were
  corrected and all three reviewers reverified the repaired frozen hash.

### Drift

- None accepted.

### Unclear

- None. The only ownership ambiguity was resolved explicitly by the
  maintainer.

## Acceptance-ledger reconciliation

Current evidence supports G1–G12. The pre-panel `--reverify` reran every
runnable oracle successfully, the exact frozen-candidate panel passed before
and after its P2 wording repair, and the post-commit `--reverify` passed all 13
gates. The full after-task validator found nine ledgers and every gate
satisfied.

The final command will be Unlazy `--reverify`, never `--status`.

## Landing reconciliation

Complete:

- one narrow local commit on `codex/lv-family-evidence-reconcile`;
- clean working tree;
- final Unlazy `--reverify` and full after-task validator passed;
- post-commit handoff audit run, with the expected local-only unpushed state
  already declared in the handover;
- `codex-lv-design73-c1` lease released.

No push, PR, merge, release, or public message occurred.
