# Nested timeout process cleanup probe

15 November 2026, Totoro. These are dummy `sh` and `sleep` processes, not fits or simulations. Commands used the existing ControlMaster socket. Each probe installed an EXIT cleanup trap that terminated the recorded PIDs and removed its temporary directory. A subsequent `ps` check found all six recorded PIDs gone.

The original nested pattern was evaluated with an outer two-second timeout and inner 30-second timeout:

```sh
timeout --signal=TERM --kill-after=2s 2s sh -c 'timeout --signal=TERM --kill-after=2s 30s sh -c '\''echo $$ >> "$scratch_dir/pids"; sleep 30 & echo $! >> "$scratch_dir/pids"; wait'\'''
```

The outer status was 124. Inner shell PID 754499 and sleep PID 754500 both remained live with state `S` until cleanup. **FAIL: the original stage timeout can leave a fit running.**

With the inner timer changed to `timeout --foreground`, the same outer two-second timeout returned 124 and both recorded PIDs, 755091 and 755092, were gone. However, reversing the deadlines (outer 30 seconds, inner foreground two seconds) returned 124 with shell PID 755268 gone but sleep PID 755269 still live in state `S` until cleanup. **FAIL: foreground mode does not reliably clean descendants on case timeout.**

The probe cleanup was checked by:

```sh
ps -o pid=,stat=,command= -p 754499,754500,755091,755092,755268,755269 || true
```

It returned no rows. Neither nested configuration is acceptable for a campaign. Use a supervisor that creates a dedicated process group for each case and explicitly terminates that group at the earlier of the case and stage deadlines. Verify stage timeout, case timeout, interrupt and normal exit with live descendant checks before any fit.

## Dedicated process-group supervisor

The nested timers were replaced by `supervisor.py`, which launches each case in a dedicated session, enforces the earlier case or stage deadline, sends TERM then bounded KILL to that process group, and checks Linux `/proc` for surviving non-zombie members. On Totoro, `python3 test-supervisor.py` passed case timeout, stage timeout, SIGTERM interruption, normal exit and normal leader exit with a live child. Each result reported an empty `remaining_after_cleanup`. The final tested supervisor SHA-256 is `ca6749a6013c741d744c88d8fb0ee485b4591ac77b68e5909bbf6fc59e74e96a`; the test script SHA-256 is `61c016fc5ef25300407e299fe7a9d697fb5a2d8feb66be5247c47c310773b200`. The test copy remains at `/tmp/twokernel-supervisor-test.eCUwjy` on Totoro. This is a dummy-process test, not evidence from an actual model fit.

An automatic command guard rejected the initial attempt to transfer and recursively delete the temporary test directory. The test was rerun without deleting that directory. No prior data or directories were removed.
