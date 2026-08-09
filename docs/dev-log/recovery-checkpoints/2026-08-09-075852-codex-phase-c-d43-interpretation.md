# Phase C recovery checkpoint — D-43 interpretation boundary

**Timestamp:** 2026-08-09 07:58:52 MDT  
**Repository:** `/Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm`  
**Branch:** `claude/experiment-integrated-sdm`  
**HEAD:** `5050e512`  
**Runtime model / effort:** not exposed by this task's metadata; do not infer it.
The next task should be GPT-5.6 Terra at medium effort.

## Lane state

Before adding this checkpoint the worktree was clean. This Lane C task owns
only this recovery checkpoint. Main, package source, public documentation,
issues #943--#946, Phase A/B, and the pending permission-boundary diff remain
untouched.

## Completed milestone

The frozen exact-geometry campaign is complete and remains immutable:

- Source commit: `7e26e1bdb9d0f99fd67ec3a4850bcf2e28d7229b`.
- Artifact root: `/Users/z3437171/local-scratch/gllvmtmb-isdm-artifacts/7e26e1bd/run4-aligned`.
- `CAMPAIGN_PASS`, 19,800 scheduled fits, and no remote Phase C jobs remain.
- Independent compute audit PASS; receipt SHA-256
  `4a1df5570a4231366c6ec9a7925a7d97fc1f81363c2d0a0c5ce865d60e268f91`.
- Original official analysis and supplement are immutable evidence under
  `phase-c-official-analysis-v1` and `phase-c-analysis-supplement-v1`.

The D-43 completion panel has now returned:

- **Curie: DONE.** Provenance, pairing, pilot lineage, and retained-health
  handling pass. The primary A1 cell has 100/100 completed and both-pdHess
  pairs; `dD_bias = 0.4521764`, MCSE `0.0021970`.
- **Fisher: NOT-DONE (P1/P2).** The primary shared-bias cell and A5--A6
  attribution pass, but the frozen global `H_sink` label is overbroad because
  all 32 R5 negative triggers occur at the `omega=0` control. G5/A6 has
  7/50 excluded fits and remains qualified sensitivity evidence.
- **Noether: NOT-DONE (P1/P2).** The same scope conflict is load-bearing.
  R3/R4 are genuinely unresolved because no equivalence/diagonal thresholds
  were frozen; G6 rank prediction is unsupported. The narrow shared-bias
  attribution claim remains supported.

The D-43 rule therefore **withholds a Phase C completion claim** until the
named interpretation defect is repaired. This does not require new fits or
any change to thresholds/grids.

## Important provenance finding

An attempted edit to `dev/isdm-phase-c-analyse-official.R` was reverted before
any output was written. The official analyser fail-closed because its receipt
authentication binds the original eight-file instrument identity; after the
edit it correctly rejected the immutable compute receipts. The clean current
worktree and `SELF_TEST_REFUTATION_RULES_PASS` confirm no frozen-instrument
file remains modified.

Do **not** overwrite or re-run the v1 official analysis. The required repair
is a separately labelled post-analysis D-43 interpretation addendum, which
must retain the original 32 R5 cell-level findings while superseding only the
overbroad global interpretation.

## Exact next action

In a fresh Terra-medium task, build and self-test a small dev-only D-43
interpretation/addendum writer that:

1. reads only the immutable v1 `08-refutation-evidence.csv` and
   `12-refutation-aggregate.csv` after checking their SHA-256 values;
2. records every existing R1--R5 cell verdict unchanged;
3. emits `H_SINK_UNRESOLVED_PREREGISTRATION_SCOPE_CONFLICT` when all R5
   triggers lie at `omega=0`, and `H_SINK_REFUTED` when any R5 trigger has
   `omega>0`;
4. writes a new non-overwriting addendum directory and receipt, explicitly
   marked post-analysis/D-43 rather than preregistered evidence;
5. reruns the supplement only if its input contract can consume the addendum
   without altering the original official output; otherwise leave the v1
   supplement immutable and cite the addendum separately.

Then ask the same three D-43 reviewers to review the repaired *interpretation*
only. If fewer than two return NOT-DONE, proceed with the approved closure
audits and write the findings/after-task/handover. No new compute is allowed
or needed.

## Fresh-task prompt

```text
Resume gllvmTMB integrated-SDM Lane C in GPT-5.6 Terra at medium effort.

Worktree: /Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm
Branch: claude/experiment-integrated-sdm
Read first:
docs/dev-log/recovery-checkpoints/2026-08-09-075852-codex-phase-c-d43-interpretation.md

The frozen Phase C compute and its v1 official analysis are complete,
audited, and immutable. D-43 returned two NOT-DONE verdicts, both locating
one interpretation defect: all R5 negative triggers are omega=0 controls,
so the global H_sink refutation is overbroad. Do not rerun fits or overwrite
v1 evidence. Implement and self-test the separate post-analysis D-43
interpretation addendum described in the checkpoint; retain all cell-level
R1--R5 results and qualify G5/A6. Re-review that addendum under D-43, then
run closure audits and write only Lane C internal records. Main, #943--#946,
Phase A/B, C-lite, public docs, and the pending permission-boundary diff stay
untouched.
```
