# How to tell whether the Gate 3 campaign is alive — and how I got it wrong

**2026-07-31.** Recorded because the obvious check gives the wrong answer, and I acted on it.

## The trap

`ps` on the processes matching `run-gate3.R` shows them at **0.0% CPU in state `SN`**
(interruptible sleep). That looks exactly like a deadlock. **It is not.** It is the design working.

`mc.preschedule = TRUE` forks one worker per core, and each worker keeps a **persistent
`callr::r_session`** that does the actual fitting — deliberately, so the VA engine's TMB template is
compiled once per worker instead of once per fit (~20–60 s each otherwise; see the rationale at
`run-gate3.R:455-466`). The forked workers therefore **sleep while their sessions compute**. Sleeping
wrappers are the expected steady state.

The `callr` sessions do **not** match `run-gate3.R`, so any check filtered on that pattern sees only
the idle half of the system.

## The correct check

```sh
ps -eo %cpu,command | grep "[R]esources/bin/exec/R" | awk '{s+=$1; n++} END {print n, s}'
```

Healthy looks like **~30 R processes and 1300–1500% total CPU** (≈13–15 cores busy), with several
processes in `RNs` at 80–90%. Confirm with `top -l 1 | grep "CPU usage"` — 0% idle.

The only trustworthy progress signal is the **cell count**:
`ls dev/va-gate3/results/cells/ | wc -l`. Expect roughly **1 cell/min**, and expect it to *stay*
around there even as CPU rises, because cells complete cheapest-first and the later ones (p=80,
n=400, q=4) are far larger.

## What I did wrong

I measured only the `run-gate3.R` processes, saw 0% CPU across all seven, observed no cell progress
for three minutes, found no `callr` children with a grep I did not verify, and concluded deadlock.
**I killed a campaign that was most likely healthy.**

Cost: about 14 minutes of in-flight work. It was bounded only because `run_task()` skips any cell
whose file already exists (`run-gate3.R:622-623`) — the 42 completed cells survived untouched. That
is the resume path earning its keep on the first real incident.

Not a total loss: the restart runs **14 workers instead of 6** on a 20-core machine (16 performance
+ 4 efficiency), which is how it should have been provisioned to begin with.

**Lesson: a strong conclusion from a measurement whose scope I had not checked.** The same failure
shape as pooling a median over `p` and missing the gradient underneath it.
