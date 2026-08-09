# Phase C recovery checkpoint — analysis materialized

**Timestamp:** 2026-08-09 07:46:02 MDT  
**Repository:** `/Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm`  
**Branch:** `claude/experiment-integrated-sdm`  
**HEAD before this checkpoint:** `bf3db6b5`  
**Runtime model / effort:** not exposed by the current Codex task metadata; do not infer it. The next task must use GPT-5.6 Terra at medium effort.

## Lane state

Before adding this checkpoint, `git status --short --branch` was clean:

```text
## claude/experiment-integrated-sdm...origin/claude/experiment-integrated-sdm
```

This Lane C task owns only this new recovery-checkpoint file. Main, package source, public documentation, issues #943--#946, and the pending permission-boundary diff remain untouched.

## Completed atomic milestone

The frozen exact-geometry Phase C campaign completed on Totoro from clean source commit
`7e26e1bdb9d0f99fd67ec3a4850bcf2e28d7229b`.

- Remote artifact root: `/home/snakagaw/hsq_work/isdm-phase-c-artifacts/7e26e1bd/run4-aligned`
- Campaign status: `CAMPAIGN_PASS`
- Durable part counts: G1 = 105, G2 = 9, G3 = 9, G4 = 9, G5 = 5, G6 = 5 (142 total)
- Every G1--G6 final result and compute receipt exists.
- Anchored log scan (`^Error|Execution halted|^FAIL`) found zero true errors.
- An earlier broad `FAIL` grep matched the ordinary word `failures)` in repeated package guidance; it was diagnosed as a false positive and not treated as campaign evidence.
- Independent structural/provenance audit: PASS.
- Audit receipt SHA-256: `4a1df5570a4231366c6ec9a7925a7d97fc1f81363c2d0a0c5ce865d60e268f91`.
- Official analysis completed with exit status 0 and wrote 13 files under `phase-c-official-analysis-v1`.
- Analysis supplement completed with exit status 0 and wrote 16 files under `phase-c-analysis-supplement-v1`.
- The current task did not inspect the substantive scientific tables after they were written.

The complete evidence tree was mirrored to:

`/Users/z3437171/local-scratch/gllvmtmb-isdm-artifacts/7e26e1bd/run4-aligned`

An `rsync -acn --delete --itemize-changes` comparison returned an empty change list after both analysis directories were mirrored. The local and Totoro trees are therefore byte-identical with no missing or extra files at this checkpoint.

## Remote-job state

No Phase C compute job remains running. The fail-stop launcher ended at `CAMPAIGN_PASS`; the independent audit, official analysis, and supplement commands each returned exit status 0. Preserve the remote root, logs, parts, results, and receipts unchanged.

The installed narrow wrapper `/Users/z3437171/.codex/tools/totoro-campaign-status` could not run because `/Users/z3437171/.codex/tools/totoro-campaign-status.conf` is missing. Do not replace it with repeated raw SSH status probes; current completion is already established by the launcher status and final artifacts.

## Verification completed

- G1--G6 independent compute verifier: PASS.
- Exact campaign receipt hash recorded above.
- Official analysis: completed, 13 outputs.
- Supplement: completed, 16 outputs including PDF/PNG figure pairs.
- Local mirror checksum/directory identity: PASS (empty rsync dry-run).
- Repository was clean at `bf3db6b5` before this checkpoint.

## Exact next action

Start a fresh GPT-5.6 Terra / medium task. Rehydrate from this checkpoint and inspect the already-generated official tables without rerunning any fit, audit, analysis, or supplement. The first scientific read should be:

```sh
Rscript --vanilla -e 'root <- "/Users/z3437171/local-scratch/gllvmtmb-isdm-artifacts/7e26e1bd/run4-aligned"; files <- c("phase-c-official-analysis-v1/01-primary-endpoint.csv", "phase-c-official-analysis-v1/03-c1-c2-verdicts.csv", "phase-c-official-analysis-v1/04-c3-a5-a6-summary.csv", "phase-c-official-analysis-v1/08-refutation-evidence.csv", "phase-c-official-analysis-v1/12-refutation-aggregate.csv", "phase-c-analysis-supplement-v1/06-claim-verdict-ledger.csv"); for (f in files) { cat("\n###", f, "\n"); print(read.csv(file.path(root, f), check.names = FALSE)) }'
```

Then complete the approved sequence: interpret all official/supplement outputs and figures; run the fresh Curie/Fisher/Noether D-43 panel; repair only a named defect if required; run Grace/Luna/Rose/Shannon/Melissa completion audits; write findings, check-log, after-task, reconciliation, and handover records; commit and push Lane C. Leave main and issues #943--#946 untouched.

## Fresh-task prompt

```text
Resume gllvmTMB integrated-SDM Lane C in GPT-5.6 Terra at medium effort.

Worktree:
  /Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm
Branch:
  claude/experiment-integrated-sdm

Read first:
  docs/dev-log/recovery-checkpoints/2026-08-09-074602-codex-phase-c-analysis-materialized.md

The frozen exact-geometry G1--G6 campaign is complete (`CAMPAIGN_PASS`), the
independent compute audit passed (receipt SHA-256
4a1df5570a4231366c6ec9a7925a7d97fc1f81363c2d0a0c5ce865d60e268f91),
and the official analysis plus supplement have already been materialized and
checksum-mirrored locally. Do not rerun compute, the audit, the official
analysis, or the supplement.

Begin with the exact first scientific-read command in the checkpoint. Then:
1. interpret every preregistered official/supplement table and figure;
2. run the fresh Curie/Fisher/Noether D-43 completion panel;
3. withhold completion if at least two reviewers return NOT-DONE;
4. run Grace/Luna/Rose/Shannon/Melissa closure audits;
5. write findings, check-log, after-task, reconciliation, and handover;
6. commit and push only Lane C.

Fences remain: no Phase A/B rebuild, no C-lite/old-pilot evidence, no package
or src/public-doc/main/PR/merge/issue changes, #943--#946 stay open, and the
pending permission-boundary diff remains read-only without Shinichi approval.
```

