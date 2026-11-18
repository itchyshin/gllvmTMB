# Session Handoff: Paper 1 range--amplitude orthogonal-chart lane

Meta: 2026-08-15 · from Codex · target Claude · context boundary reached

```text
🎯 GOAL
Solo platform: Codex for the completed setup; Claude receives the next design/pure-contract arc
Deliverable: a separately specified iJSDM successor estimator that can later earn one provenance-valid
  numerical attempt per frozen paper model, then recovery evidence only if admitted
HEADLINE: replace exhausted G3/BFGS/gauge routes with a fixed range--amplitude orthogonal chart while
  preserving the MSPDE V3 marginal objective and raw-coordinate estimand
IN PARALLEL: symbolic map/Jacobian audit, pure adversarial tests, source-boundary review
DEFER: TMB construction, numerical smoke, recovery, empirical data, maps, pkgdown articles, and public claims
DISCIPLINE: verify=independent Gauss/Noether + Fisher/Rose before any executable packet · compute=n/a in
  this handoff arc · closure=one reviewed design and pure contract, not an admission claim
```

## Critical Context

The prior routes are not available for another retry.  The sealed G3
adjudication records Paper 1 as `G3_RAW_INELIGIBLE` and Paper 2 as
`G3_CURVATURE_INVALID`.  Exact-gradient BFGS, marginal-scale BFGS, and the
gauge trust-region roots are consumed.  The gauge trust-region V1 root is
post-claim and unsealed: marker and V3-live evidence exist, but no worker or
numerical evidence.  Do not repair, resume, reseal, backfill, or read partial
traces to tune this successor.

This lane is deliberately new.  It uses a fixed 45-degree rotation of
`log_kappa_spde` and the GBIF loading log-amplitude, on the positive sign
representative already present in immutable MSPDE V3.  It does not alter the
TMB likelihood, data, map, mesh, random effects, seed, raw ordering, or
scientific estimand.

## What Was Accomplished

- Created the isolated branch/worktree
  `codex/isdm-range-amplitude-orthogonal` at
  `/private/tmp/gllvmtmb-isdm-range-amplitude-chart`, based on
  `6f8cbe12ab9e8782b9cc02161d43054a5c7ac3fb`.
- Wrote the design-only successor contract:
  `dev/isdm-package-recovery/2026-08-15-paper1-range-amplitude-orthogonal-design.md`.
- Implemented a pure base-R 22-coordinate map/inverse/Jacobian/chain-gradient
  contract and an independent composed-quadratic finite-difference test.  It
  neither constructs TMB nor writes a scientific root.
- Ran successfully:

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-paper1-range-amplitude-orthogonal-contract.R", reporter = "summary", stop_on_failure = TRUE)'
# PASS: 13 expectations

git diff --check
# PASS
```

The first test invocation exposed only a test-path error; it was repaired by
using `testthat::test_path()` and the subsequent focused run passed.

## Current Working State

- Working: pure coordinate algebra and its independent 22-dimensional
  chain-gradient harness.
- In progress: this is a design/pure-contract lane only.  It has no no-fit
  adapter, runner, packet, result root, preflight, or smoke.
- Protected: all G3/BFGS/marginal-scale/gauge-no-fit/gauge-trust-region roots.
  Treat them as immutable forensic inputs only.
- Not started: Paper 2 successor design.  It must not inherit a Paper 1 result
  or chart without a separate source/estimand argument.

## Prior-work sweep receipt

| Surface | Evidence | Finding | Call forced |
| --- | --- | --- | --- |
| Repo/history | `git log --oneline`, `git worktree list`, and `dev/isdm-package-recovery/2026-08-14-g3-marginal-curvature-terminal-adjudication.md` | G3 is terminally HOLD for both papers; the earlier BFGS and gauge lineages are consumed. | Build only the genuine new chart gap. |
| Engine | `src/gllvmTMB.cpp:1801-1865,2029-2044` | The engine has two independent LHS SPDE-slope columns and rank one; the second loading block gives `Sigma_spde_slope_slope`. | Preserve the raw block and test sign-orbit equivalence before any live chart use. |
| Brain/memory | `rg -n -i 'iJSDM|matched-SPDE|G3|BFGS|gauge|trust.region|range.amplitude' /Users/z3437171/.codex/memories/MEMORY.md` | Existing notes require new roots/approval after consumed G3 evidence and prohibit relabelling a terminal HOLD as admission. | Preserve successor-only boundary. |
| Sister/twin repo | Not yet checked. | No reuse claim is made. | Claude must check GLLVM.jl/drmTMB only if proposing a reusable parameterisation or a novelty claim. |

## Key Decisions and Rationale

1. The parameterisation is not the old gauge map.  Define
   \(u=(q+\eta)/\sqrt2\), \(v=(q-\eta)/\sqrt2\), where
   \(\lambda=e^\eta(1,a,b)^\top\) for the GBIF slope block.  Its inverse,
   exact chain gradient, and full 22-by-22 raw-row/chart-column Jacobian are
   all in the new pure contract.
2. The full sign-orbit gate remains an executable prerequisite.  Covariance
   equality alone is not enough to claim likelihood or estimand equivalence.
3. Any transformed Hessian must finite-difference the transformed exact
   gradient or retain the nonlinear map term.  A raw covariance inverse alone
   is not a chart Hessian.
4. No numerical execution is authorised by this document or branch.

## Ultra Plan

| Slice | Member / platform | Output | Dependency | Estimate |
| --- | --- | --- | --- | --- |
| Rehydrate and classify protected roots | Claude, low-cost read-only | updated status table in this handover or a new plan note | none | 20 min |
| Audit the map as a mathematical chart | Claude / Noether lens | review note against the design and pure contract | pure contract | 45 min |
| Extend pure adversarial coverage | Claude | tests for local determinant, nonfinite overflow, raw/phi permutation, chart-domain and sign-orbit data shapes | audit | 1–2 h |
| Specify the full no-fit provenance gate | Claude / Rose lens | new design-only packet, not a runner | map review | 1–2 h |
| Live no-fit implementation and TMB identity execution | return to Codex | runner/contract + bounded test report | source/design review | 4–8 h |
| Numerical runner and one-attempt packet | return to Codex | separately reviewed implementation | no-fit gate PASS | 6–12 h |
| Independent reviews and only then one smoke each | Codex plus Gauss/Noether and Fisher/Rose | sealed GO/HOLD roots | all preceding slices | <30 min per smoke; no recovery yet |

LUNA/Haiku suitability: no dispatch was run in this handover slice.  Claude
should use its lowest safe review tier for the bounded mathematical/read-only
audit, and reserve a stronger reviewer for the map/estimand proof.  No
sub-agent was spawned here because the Codex session is ending at a context
boundary.

## Landing State

`/Users/z3437171/shinichi-brain/tools/handoff_gate.sh` reported this branch as
uncommitted and unpushed before this handover commit.  Once this document and
its three lane files are committed together, the local handoff is durable;
the branch remains deliberately unpushed because the GitHub API was
unreachable during the lane check.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `codex/isdm-range-amplitude-orthogonal` | yes (this handover commit) | no | none | CARRIED-OVER: clean local commit, not yet pushed |

Do not stage unrelated worktree files.  The three new implementation files
plus this handover are the only paths owned by this lane.  The repository has
multiple Cursor and Codex lanes; do not alter the global snapshot pointer,
coordination board, check-log, or shared reports from this branch.

## Next Immediate Steps

1. Run `bash ~/shinichi-brain/tools/lane_preflight.sh --file <path>` for every
   file before editing and reconcile this handover with live `git status`.
2. Classify this handover's items as `OWED`, `DONE`, `RETRACTED`, or
   `PROTECTED`.  Do not assume an unpushed branch is available remotely.
3. Read the new design, pure contract, G3 adjudication, and gauge-trust
   checkpoint before proposing code.
4. Perform a mathematical audit of the four-coordinate local transform,
   including determinant orientation, inverse domain, full 22-axis placement,
   and the no-Jacobian frequentist argument.  Retain any correction in tests.
5. Build a design-only no-fit/provenance plan.  Do not implement or run TMB
   until that plan has independent review.

## Blockers / Open Questions

- Whether the complete full-random-effect sign operator passes on the immutable
  V3 state is untested in this new chart; it is a prerequisite, not an
  assumption.
- The successor's numerical procedure is intentionally unspecified.  Do not
  silently reuse the trust-region grid or BFGS controls from consumed lanes.
- Paper 2 requires a separate new-estimator argument after Paper 1; no shared
  numerical permission exists.

## Gotchas and Failed Approaches

- G3 did not provide an admission: Paper 1 was raw-ineligible and Paper 2
  failed independent curvature validation.
- BFGS and marginal-scale BFGS did not cross the old-coordinate gradient gate.
- The gauge trust-region V1 root is unsealed after claim; no worker evidence
  survives.  Do not create a terminal ledger retrospectively.
- The no-fit V1/V2 contracts explicitly prohibit further retries.  This chart
  must not be disguised as a V3 no-fit replay of that adapter.

## How to Resume

Use a fresh Claude session in this worktree.  Claude should plan/refactor and
run pure-R checks; return live R/TMB construction, smoke, and recovery work to
Codex unless the active Claude environment demonstrably has the required
toolchain and the required execution gate has been approved.

```sh
cd /private/tmp/gllvmtmb-isdm-range-amplitude-chart
claude "Read AGENTS.md and docs/dev-log/handover/2026-08-15-claude-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps."
```

Paste-ready prompt:

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-15-claude-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
