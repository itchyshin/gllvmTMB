# After Task: LV Arc Gate 3 Running Mission Control

## Goal

Refresh local Mission Control after the Phylo Model A Gate 3 DRAC
claim-evidence array moved from queued to running.

## Files Changed

- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-01-lv-arc-gate3-running-mission-control.md`

## Live Evidence

```text
SLURM job: 17049809_[1-500%100]
host: Nibi
state: running / pending array
active tasks: 20
pending tasks: 480
result files: 0/500
detail files: 0/500
non-empty error logs: 0
results: /scratch/snakagaw/phylo_model_a_gate3_20260701-1122/results
```

Design remains unchanged:

```text
target: B_eta_realized
method: profile_eta_realized
cell: p=80, n_sites=200, K=2, q_lv=1, K_phy=1, lambda=0.5, scenario=main
replicates: 500
seed0: 20260701
entries: 14,41,71,8,44
fit/profile optimizer budgets: 1000 / 1000
host denominator: DRAC/Nibi only
```

## Validation

```sh
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
sh tools/start-mission-control.sh --background
curl -s http://127.0.0.1:8770/status.json | python3 -m json.tool | rg -n "17049809|Gate 3|running|1 active|0 queued|0/500"
ssh nibi 'squeue -j 17049809 -o "%.30i %.12P %.20j %.8u %.2t %.12M %.6D %R"'
```

## Claim Boundary

Gate 3 is running, not passed. Mission Control must not imply completed DRAC
claim evidence, public source-specific support, PR #127 reopening, or R grammar
exposure.

## Rose Audit

PASS WITH NOTES. The board may show one active DRAC claim-evidence row, but the
evidence denominator is still zero. Keep Totoro Gate 2 separate from the DRAC
Gate 3 denominator.

## Next Command

Poll job `17049809`; when result files appear, reduce only the DRAC/Nibi result
directory and report fit convergence, usable selected entries, coverage, MCSE,
Wilson interval, LR misses, and timing.
