# Codex Handover: Cross-Family LV R200 Recovery

Meta: 2026-08-27 · Codex to a fresh Codex task · successor evidence lane

You are Codex, picking up the retained recovery-evidence follow-up to the
landed cross-family predictor-informed latent-variable bridge. This is a fresh
task because the implementation milestone is complete and its lease was
released. Do not reopen or rewrite that milestone.

## Critical Context

PR #1218 is merged normally on `main` at
`0d442ce7b0ab0b5901ccbde08426f9d9c4923287`. Exact-main R-CMD-check run
`33105383315` passed, and pkgdown build/deploy run `33109313104` passed. The
reader-facing article is live at
<https://itchyshin.github.io/gllvmTMB/articles/cross-family-correlations.html>.

What is now implemented is compositional admission: registered native
family/link rows can occur together in one complete-response, ordinary
unit-tier `latent(..., lv = ~ x)` block. Scientific recovery targets are the
rotation-invariant

\[
B_{lv}=\Lambda\alpha^\top
\]

and the implied shared covariance/correlation, never raw `alpha`, raw
`Lambda`, signed axes, or individual scores across fits.

The direct follow-up is evidence, not another API expansion. General rank-2
and rank-3 arbitrary-composition recovery remains `partial`: the retained
production denominator is 400 planned, 0 started, 0 attempted, and 400
planned-not-started. The two pre-run fits are feasibility checks only.

## Goals and Mission

Run and adjudicate the smallest non-duplicative retained recovery campaign for
the landed cross-family predictor-informed LV route. Preserve every attempt and
all-attempt denominators. If the frozen gates pass, reconcile only the exact
earned recovery cells; do not infer calibrated intervals or universal recovery
for every possible family mixture.

This successor must not broaden into missing responses, missing or factor LV
predictors, fixed `X + X_lv`, REML, noncanonical links, extra tiers,
structured-source LV, Julia calibration, profile/bootstrap, or correlation
intervals.

## What Was Accomplished

- Landed the native cross-family predictor-informed LV bridge in PR #1218.
- Added exact family/link routing, joint dimension screening, scale handling,
  focused tests, honest validation status, and the public worked article.
- Verified the reviewed head on Ubuntu, macOS, and Windows.
- Verified the exact merged-main SHA and deployed pkgdown.
- Froze the R200 design, source pin, seeds, denominators, estimands, gates, and
  one-attempt timing/correctness receipt.
- Released the full implementation lease.

## Current Working State

- **DONE:** implementation, tests, article, internal status reconciliation,
  reviews, protected merge, exact-main check, and deployment.
- **OWED:** decide whether to authorize and run the exact retained 400-attempt
  Totoro recovery campaign; collect, validate, summarize, review, and land only
  the evidence warranted by its results.
- **PROTECTED:** the fixed-rho `phylo_coef()` lane is live and owns overlapping
  package paths. This recovery lane begins read-only and must claim only exact,
  disjoint campaign/artifact paths after a fresh lane preflight.
- **RETRACTED:** none.

## Frozen Campaign

Read the complete pre-run receipt before doing anything:

`docs/dev-log/artifacts/cross-family-lv-predictor/2026-08-27-r200-recovery-pre-run-receipt.md`

The immutable cells are:

| Cell | Rank | Attempts | Purpose |
|---|---:|---:|---|
| `continuous-unequal-scale-d2` | 2 | 200 | Recover `B_lv`, shared covariance/correlation, and separate Gaussian raw-scale versus lognormal log-scale parameters. |
| `five-family-d3` | 3 | 200 | Recover `B_lv` and shared covariance/correlation jointly for Gaussian, binomial, Poisson, ordinal-probit, and multinomial responses. |

Frozen source candidate:

- commit: `1cb4d33a4080e251073bc864086651b535b2d028`
- tree: `4cf7d95c1f0a2fe6d54b1488f9f0a8964a9f1553`
- seed base: `202608270`
- campaign script SHA-256:
  `ac21ebe93c6b9ad5b1aea528345b002d2669ba2deaf9c8beab4a5a1ae7f73200`
- summarizer SHA-256:
  `1c266a8b2a503b4543fe3dc36255232f3985faf8f37610be3600dc55e6986c90`

Measured pre-run:

- continuous rank-2 fit: 3.99 seconds, eligible;
- five-family rank-3 fit: 79.20 seconds, eligible;
- projection: 10--20 minutes wall time on Totoro with 40 one-thread workers;
- stop and re-report if the campaign exceeds 30 minutes;
- never exceed 150 Totoro cores;
- never use GitHub Actions for science compute.

The frozen acceptance thresholds are in the pre-run receipt. Do not tune them
after seeing production results, replace failed seeds, or discard unavailable
fits from denominators.

## Key Decisions and Rationale

1. The implementation milestone may be called complete because its public and
   internal claims are limited to route admission and named route health.
2. Recovery and interval calibration are separate programmes. Point recovery
   cannot earn interval coverage.
3. `B_lv` is the cross-fit predictor-effect estimand because it is invariant to
   latent rotations. Raw `alpha` and `Lambda` are not cross-fit targets.
4. The 400-attempt campaign is intentionally smaller than the already retained
   3,800/4,000-attempt named-family campaigns and must not duplicate them.
5. A future source change requires a new source pin and a new measured pre-run
   receipt; do not quietly run the frozen scripts against a different tree.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `main` `0d442ce7b0ab0b5901ccbde08426f9d9c4923287` | yes | yes | #1218 merged | LANDED |
| `codex/cross-family-lv-r200-recovery` | handover commit only at lane start | no at handover creation | none | CARRIED-OVER: fresh evidence lane; continue from this document |

Resume command for the carried-over lane: start a fresh Codex task in the
`gllvmTMB` project from branch `codex/cross-family-lv-r200-recovery`, then use
the one-command prompt under **How to Resume**.

`FINDINGS-OF-RECORD: none` — all substantive implementation findings and claim
boundaries are already landed on `main` in the after-task report and evidence
audit linked below. The successor branch initially carries only this handover.

## Files Created or Modified in This Handover

- `docs/dev-log/handover/2026-08-27-codex-cross-family-lv-r200-recovery.md`

No package source, tests, campaign scripts, status surfaces, or public
documentation were changed while producing this handover. The implementation
lane's complete path ledger is in
`docs/dev-log/after-task/2026-08-27-cross-family-lv-predictor-bridge.md`.

`AGENTS.md` was deliberately not edited: this is a multi-lane repository, and
its current snapshot correctly keeps `docs/dev-log/handover/2026-07-25-active-lane-split.md`
as the canonical start point rather than replacing other lanes with this one.

## Next Immediate Steps

1. Read `AGENTS.md`, every row of the active-lane split, this handover, the
   landed after-task report, the engine/evidence audit, and the R200 pre-run
   receipt.
2. Run `tools/lane_preflight.sh` correctly with the repository path and run
   `/ask-brain` with `search_all_projects=true`.
3. Inspect live leases. Claim only exact campaign, raw-result, summary,
   evidence, check-log, after-task, plan-actual, and handover paths that are
   free. Do not touch the fixed-rho coefficient lane.
4. Create a fresh Ultra Plan and Unlazy acceptance ledger for the evidence
   task. Treat the existing pre-run design as frozen input, not as permission
   to broaden it.
5. Revalidate the source pin, hashes, Totoro socket, worker cap, retained output
   destination, and all-attempt denominator mechanics.
6. Present the exact launch authority for the 400-attempt, 40-worker,
   10--20-minute Totoro run. Do not reinterpret the older 3,800-attempt approval
   as approval for this different campaign.
7. If explicitly approved, run once, monitor without duplicate launches,
   preserve all attempts, collect raw results, and execute the frozen
   summarizer and gates.
8. Obtain Curie/Fisher recovery review, Gauss/Noether parameterization and
   estimand review, Rose scope review, and Grace reproducibility review.
9. Update only the exact earned internal evidence/status surfaces. Public prose
   changes only if the new evidence materially changes an already stated
   boundary.
10. Finish with Unlazy `--reverify`, after-task, Melissa plan-vs-actual,
    handover, a narrow commit/PR, exact-head 3-OS CI, normal merge, exact-main
    verification, and lease release.

## Blockers and Open Questions

- Explicit launch authority for this exact 400-attempt Totoro campaign must be
  recorded before remote execution.
- If the frozen source pin cannot be executed reproducibly from a clean remote
  checkout, stop with the measured failure receipt; do not repin silently.
- A lease collision pauses only the colliding path. Continue read-only or
  disjoint preparation.

## Gotchas and Failed Approaches

- Do not confuse “all registered families route” with “all arbitrary family
  compositions have recovery evidence.”
- Do not count the two feasibility fits among the 400 production attempts.
- Do not drop failed, nonconverged, non-PD, or unavailable attempts from the
  all-attempt denominator.
- Do not compare raw latent axes across fits.
- Do not launch a duplicate job because monitoring output is temporarily
  quiet.
- Do not use GitHub Actions for recovery compute.
- Do not mutate `/Users/z3437171/Dropbox/Github Local/GLLVM.jl`.
- Do not extend this evidence task into interval calibration or structured
  sources.

## Read First

1. `AGENTS.md`
2. `docs/dev-log/handover/2026-07-25-active-lane-split.md`
3. `docs/dev-log/handover/2026-08-27-codex-cross-family-lv-r200-recovery.md`
4. `docs/dev-log/after-task/2026-08-27-cross-family-lv-predictor-bridge.md`
5. `docs/dev-log/artifacts/cross-family-lv-predictor/engine-and-evidence-audit.md`
6. `docs/dev-log/artifacts/cross-family-lv-predictor/2026-08-27-r200-recovery-pre-run-receipt.md`
7. `docs/design/73-predictor-informed-latent-scores.md`
8. `dev/cross-family-lv-predictor/recovery-campaign.R`
9. `dev/cross-family-lv-predictor/summarise-recovery.R`

## Codex Live-Toolchain Recipe

From the repository root:

```sh
export NOT_CRAN=true
export OPENBLAS_NUM_THREADS=1
git status --short --branch
git rev-parse HEAD origin/main
python3 /Users/z3437171/Dropbox/Github\ Local/Shinichi/tools/route.py gllvmTMB
/Users/z3437171/Dropbox/Github\ Local/Shinichi/tools/lane_preflight.sh "$PWD"
```

Use the existing Totoro ControlMaster socket only. Never open a new login that
could prompt for credentials. Confirm the socket and remote source pin before
any run. The production launch, monitoring, collection, summarization, and
review receipts are Codex live-toolchain work.

## Mission Control

| Repository | Base / branch | Verified state | What shipped | Next by leverage |
|---|---|---|---|---|
| `gllvmTMB` | main `0d442ce7b`; successor `codex/cross-family-lv-r200-recovery` | PR #1218 merged; exact-main check and pkgdown green | Cross-family predictor-informed ordinary LV route and reader article | Run the frozen 400-attempt recovery evidence task; interval calibration remains a later fresh programme |
| `GLLVM.jl` | read-only | untouched | historical evidence only | no action |

## How to Resume

Start a fresh Codex task in the `gllvmTMB` project from branch
`codex/cross-family-lv-r200-recovery`, then paste:

> Read `AGENTS.md` and `docs/dev-log/handover/2026-08-27-codex-cross-family-lv-r200-recovery.md`. Run the handover rehydration steps, classify every item as OWED, DONE, RETRACTED, or PROTECTED against current git and live leases, then create the bounded Ultra Plan and Unlazy ledger for the exact 400-attempt cross-family LV R200 recovery. Ask for explicit approval of that exact Totoro launch before running it, preserve every attempt and all-attempt denominators, and carry the approved evidence task through review, closeout, protected landing, exact-main verification, and lease release without broadening into intervals or structured sources.
