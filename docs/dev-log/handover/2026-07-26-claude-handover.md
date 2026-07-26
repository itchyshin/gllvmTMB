# Session Handoff: HVT-1 private high-variance truth instrument

**Meta:** 2026-07-26 · target = Claude · author = Claude · branch =
`codex/hvt1-high-variance-truth-oracle-20260726` · base = `origin/main`
`f2280081` · preservation commits = `3a22ac48`, `6e0c12a5`, `cfa4dbe6`.

## Critical Context

HVT-1 is **finished** as a private measurement-instrument arc.  Its only
durable arc-level decision is `ORACLE_NOT_CERTIFIED`: the frozen stable band-4
cell is individually certified, while frozen high band 20 is
`TRUTH_UNINTERPRETABLE_ADAPTIVE`.  This is an unavailable high-variance truth
instrument, **not** a VA failure verdict, a `<= 4` gate relaxation, or a VA/EVA
admission.

Do not merge this branch or turn it into a public claim without a separate
maintainer decision.  The existing `claude/va-implementation-20260725` branch
remains **DO-NOT-MERGE** because Design 85 §10 prohibits its Bernoulli widening.

## Goals / mission

`gllvmTMB` remains a multivariate stacked-trait R/TMB package.  This lane only
answered whether an independent q=2 fixed-coordinate numerical instrument can
measure the frozen complete multi-trial VA-R3 high-variance fixture.  It did
not add a family, formula/API route, estimator admission, or public evidence.

## What Was Accomplished

- Created a source-locked, independently coded adaptive nested-integration
  oracle for complete multi-trial binomial-logit q=2 fixed coordinates.
- Enforced frozen source/campaign hashes, campaign-fixture extraction, packed
  `theta_rr` retention, analytic zero-loading and independent q=1 anchors,
  forward/reverse order agreement, tolerance tightening, affine-coordinate
  checks, per-unit sums, and retained warnings/errors.
- Certified frozen band 4: adaptive versus admissible H801 product-GH
  difference `5.684342e-14`; retained private H61 ELBO-minus-truth
  `-0.7271131`.
- Classified frozen band 20 `TRUTH_UNINTERPRETABLE_ADAPTIVE`: tightened reverse
  nesting reported “integral is probably divergent” then a non-finite outer
  function.  Its `elbo_H61` and `elbo_minus_truth` are both `NA`.
- Curie, Noether, and Rose completion reviews passed after the recorded
  remediation loop.  The post-push runner packet also passed its lock and
  suppression assertions.

## Current Working State

- **Working:** clean, pushed private branch at `cfa4dbe6`.
- **In progress:** none. HVT-1 is closed.
- **Blocked / decision-gated:** any new high-variance numerical-method arc
  requires Shinichi's separate approval. Do not silently launch it.

## Key Decisions & Rationale

- Frozen inputs only: no fixture retuning, refit, Bernoulli widening, AGHQ,
  Laplace, or product-GH substitution.
- A per-cell `TRUTH_UNINTERPRETABLE_ADAPTIVE` status preserves attempted
  diagnostics but forbids an ELBO--truth gap.  The top-level HVT-1 decision is
  `ORACLE_NOT_CERTIFIED` unless every requested cell is certified.
- HVT-1 is evidence about a numerical measurement instrument at fixed
  coordinates only.  It cannot validate VA generally, establish a variance
  threshold, or reopen Design 86.

## Plans / roadmap

1. First ask Shinichi whether to approve a new, separate private arc.
2. If approved, use `ultra-plan` and scope it to a **genuinely different** q=2
   high-variance integration method at the same frozen coordinates.
3. Preserve all HVT-1 exclusions.  Only a separately certified high-cell
   instrument could support a later private comparison; it still would not
   approve public VA/EVA work.

Other active-lane context is retained in
`docs/dev-log/handover/2026-07-25-active-lane-split.md`: do not touch the dirty
Claude profile lane, Codex eta-simulation lane, or cancelled Site × Species
capability.

## Files Created / Modified

The HVT-1 implementation diff against `origin/main` consists of:

- `dev/va-variance-gate/high-variance-oracle.R`
- `dev/va-variance-gate/run-high-variance-oracle.R`
- `dev/va-variance-gate/hvt1-source-lock.md`
- `dev/va-variance-gate/hvt1-certification-spec.md`
- `docs/dev-log/after-task/2026-07-26-hvt1-high-variance-truth-oracle.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/handover/2026-07-26-codex-hvt1-high-variance-truth-oracle.md`
- `docs/dev-log/plan-actual/2026-07-26-hvt1-high-variance-truth-oracle.md`
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` (this handoff's lane-state refresh)
- this handoff document.

Raw packets are intentionally local-only under `/private/tmp` (D-50).  The
authoritative packet paths and SHA-256 values are in the after-task report.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `codex/hvt1-high-variance-truth-oracle-20260726` at `21f551da` | yes | yes | [#795](https://github.com/itchyshin/gllvmTMB/pull/795) open, do not merge | LANDED |

The branch is deliberately private and unmerged.  PR #795 exists only as a
preservation/review vehicle; it must not be auto-merged.  GitHub API access was
unavailable for the earlier PR census, so no broader open-PR census is asserted.

## Mission Control

| Repo | Branch / base | CI / state | What shipped | Plan by leverage |
| --- | --- | --- | --- | --- |
| `gllvmTMB` | `codex/hvt1-high-variance-truth-oracle-20260726` / `origin/main` `f2280081` | local parse, packet-schema, lock, diff checks PASS; remote PR census unavailable | private q=2 adaptive truth instrument; stable-cell certificate; high-cell unavailable diagnosis | wait for Shinichi's approval before a different numerical-method arc |

## Next Immediate Steps

1. Rehydrate and classify this handoff as `DONE`; do not rerun or rewrite
   HVT-1 absent an audit reason.
2. Confirm the preservation PR exists and is **not merged**.  If GitHub access
   remains unavailable, report that fact rather than guessing CI/PR status.
3. Ask Shinichi for approval before creating any next arc.  On approval, read
   the HVT-1 after-task report and certification specification first.

## Blockers / Open Questions

- Maintainer decision: whether to fund a separate high-variance numerical
  method comparison arc.
- GitHub API was unreachable locally, so the PR census/CI state could not be
  independently verified at handoff time.

## Gotchas / Failed Approaches

- Existing q=2 product-GH is stable through the lower observed-variance cells
  but not at 22.190718; do not use it as high-cell truth.
- The high band's baseline routes agree, but a failed tightened route is still
  an instrument failure. Never average, relax tolerances, or report a gap.
- Earlier oracle iterations merely recorded rather than enforced a campaign
  hash and lacked several route/schema checks. The committed runner fixes all
  of these; do not resurrect earlier `final3`--`final9` local packets.

## How to Resume

From the HVT-1 worktree, run the local lane check, read `AGENTS.md`,
`CLAUDE.md`, the active-lane split, this document, the after-task report, and
the certification specification.  Spawn Rose before any new claim.  Claude
may plan, refactor, and perform pure-R/logic checks; route a future live R/TMB
fit or heavy numerical campaign to Codex/approved compute.

```sh
cd /private/tmp/gllvmtmb-hvt1-high-variance-truth-oracle-20260726 && claude "Rehydrate from docs/dev-log/handover/2026-07-26-claude-handover.md + the AGENTS.md and CLAUDE.md snapshot, classify the HVT-1 handoff, then continue only with the Next Immediate Steps."
```
