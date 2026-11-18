# Response-information campaign recovery checkpoint

- **Branch:** `codex/isdm-response-information-20260901` at `9c96f0353` (ahead of `origin/main` by 13 commits)
- **Working tree:** clean
- **Active remote gate:** fresh-worker DRAC qualification, job `57741095`, task IDs 900003 and 900004
- **Scheduler state observed:** `PENDING` on Fir `cpubackfill`, no scheduler start estimate; no worker receipt exists and no retained scientific identity has run.
- **Totoro counterpart:** task IDs 900001 and 900002 passed at `/home/snakagaw/gllvm_work/isdm-response-information/output/qualification-6219a478`.
- **Fir inputs:** source `/home/snakagaw/isdm-response-information/508a6596` at `6219a478`; verified runtime `/home/snakagaw/isdm-response-information/runtime-lib/515ca31`; intended DRAC output `/scratch/snakagaw/isdm-response-information/qualification-6219a478`.
- **Do not change:** first failed scientific pilot job `57740580` is an immutable predecessor; it used the superseded v2 record namespace. The fresh retained campaign uses v3 records and seed base `209110001L` after explicit maintainer approval.

## Completed local work

- Added and committed `dev/isdm-requalification/response-information/pilot-checkpoint.R` (`9c96f0353`), which checks the valid 16-fit pilot and makes the predeclared conservative 16-worker / 784-fit six-hour projection.
- Ran `freeze.R`, `verify-contract.R`, focused response-information tests (40 passing), and `sha256sum -c` on the harness manifest successfully before that commit.

## Next safe action

Poll job `57741095`. After it is terminal, retrieve Totoro and Fir qualification receipts, run `verify-qualification.R` and `freeze-runtime.R` locally, copy the fresh runtime identity to a new Fir pilot output root, and submit exactly the new 16-identity pilot. Do not submit the remaining 784 identities until the pilot receipt is shown to and accepted by Shinichi.
