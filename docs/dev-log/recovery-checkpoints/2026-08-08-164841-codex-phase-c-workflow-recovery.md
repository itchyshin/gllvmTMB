# Phase C workflow recovery checkpoint

Date: 2026-08-08 16:48:41 MDT  
Platform: Codex  
Lane: integrated-SDM experiment  
Branch: `claude/experiment-integrated-sdm`  
HEAD before this checkpoint: `aa28376f`

## Working state

`git status --short --branch` was clean:

```text
## claude/experiment-integrated-sdm...origin/claude/experiment-integrated-sdm
```

The Lane C worktree is `/Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm`.
The Dropbox `main` checkout, the CRAN 0.7 worktrees, and the VA/GH worktree are
foreign lanes and remain untouched.

## Workflow journal reconciliation

The authoritative journal is:

```text
/Users/z3437171/.claude/projects/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/c51f74ae-0378-45d1-9a20-23e846735810/subagents/workflows/wf_b705e82c-2c8/journal.jsonl
```

It contains seven events: four `started` events and three `result` events.

1. Scout returned `dev/isdm-phase-c-reuse-map.md`; it is already committed in
   `76eb5e7c`.
2. Scout returned `dev/isdm-wide-format-probe.md` and its script; both are
   already committed in `76eb5e7c`.
3. Design returned `dev/isdm-phase-c-design.md`; it is already committed in
   `aa28376f`.
4. Build started as agent `ae0b0a4ab785e2f53` but has no journal result. During
   recovery its transcript and worktree continued changing asynchronously: it
   wrote `dev/isdm-bias-harness.R` at 16:47:58 MDT and
   `dev/isdm-bias-campaign.R` at 16:49:59 MDT. It then measured the bias-control
   ladder, ran all six arms on one `n = 100`, `T = 6` dataset, checked the `k = 1`
   versus `k = 3` diagonal-Psi gate, and verified the exact 21,300-fit grid count.
   Its final preflight launcher failed before execution because macOS has no
   `timeout` command. The agent emitted no final return and the workflow journal
   did not append a Build `result` event.
5. Smoke, Run, Analyse, and Verify never started.

Therefore the journal alone understates the recovered state: two uncommitted Build
artifacts survived and must be verified and committed before Phase C continues.
The design commit `aa28376f` remains the last completed workflow event. Phase A
and Phase B are landed predecessors and must not be rebuilt.

## Commands run

```text
git status --short --branch
git log --oneline -12
jq -c . <workflow>/journal.jsonl
jq ... agent-ae0b0a4ab785e2f53.jsonl  # compact tool-use and return inventory
ls -la dev/isdm-phase-c-design.md dev/isdm-bias-*.{R,md,rds}
bash ~/shinichi-brain/tools/lane_preflight.sh .
```

Results: Lane C began clean, then the inherited Build agent deposited the two
untracked scripts above while recovery was in progress. GitHub PR census was
unavailable because `api.github.com` could not be reached. The lane handover
already identifies Cursor CRAN 0.7 as the foreign lane, so the network failure
does not widen ownership.

## Commands still required

1. Independently parse and inspect `dev/isdm-bias-harness.R` and
   `dev/isdm-bias-campaign.R` against the frozen design.
2. Re-run the DGP bias-correlation control and exact grid-count check.
3. Run the preregistered toy smoke and inspect its first returned fit.
4. Continue only if the low-to-high bias distortion metric moves; otherwise record
   the preregistered NO-GO.
5. Commit each verified Lane C slice with explicit paths only.

## Next safest action

Verify and commit the two recovered Phase C dev scripts without editing package
code, `src/`, the VA/GH estimator, CRAN files, or any other worktree. Use
`devtools::load_all()` and `NOT_CRAN=true`; do not use the installed package.

## Blocking question

None. Shinichi explicitly authorised resuming Phase C from the journal and fenced
Phases A and B against reconstruction.
