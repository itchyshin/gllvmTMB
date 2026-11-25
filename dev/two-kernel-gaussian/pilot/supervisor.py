#!/usr/bin/env python3
"""Run bounded pilot cases in dedicated process groups; Linux /proc required."""
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

_CANCEL = None

def _on_signal(signum, _frame):
    global _CANCEL
    _CANCEL = signum


def group_live(pgid):
    """List non-zombie processes in the case process group."""
    live = []
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():
            continue
        try:
            stat = (proc / 'stat').read_text()
            fields = stat[stat.rfind(')') + 2:].split()
            if int(fields[2]) == pgid and fields[0] != 'Z':
                live.append(int(proc.name))
        except (OSError, ValueError, IndexError):
            continue
    return live


def stop_group(pgid, proc, grace=2.0):
    """TERM then KILL any surviving group members; do not touch other groups."""
    for sig, wait in ((signal.SIGTERM, grace), (signal.SIGKILL, 2.0)):
        try:
            os.killpg(pgid, sig)
        except ProcessLookupError:
            pass
        until = time.monotonic() + wait
        while time.monotonic() < until:
            proc.poll()
            if not group_live(pgid):
                break
            time.sleep(0.05)
        if not group_live(pgid):
            break
    try:
        proc.wait(timeout=1)
    except subprocess.TimeoutExpired:
        pass
    return group_live(pgid)


def execute(command, output, case_seconds, stage_deadline):
    """Return receipt; every case has a separate session/process group."""
    begin = time.monotonic()
    deadline = min(begin + case_seconds, stage_deadline)
    proc = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                            start_new_session=True)
    pgid = proc.pid
    reason = None
    while True:
        code = proc.poll()
        if _CANCEL is not None:
            reason = 'interrupted'
            break
        if time.monotonic() >= deadline:
            reason = 'stage_timeout' if stage_deadline <= begin + case_seconds else 'case_timeout'
            break
        if code is not None:
            reason = 'normal_exit'
            break
        time.sleep(0.05)
    residual_before = group_live(pgid)
    # Even a normally exited leader may have left children behind.
    remaining = stop_group(pgid, proc) if residual_before else []
    code = proc.poll()
    return dict(reason=reason, process_exit=code, pgid=pgid,
                residual_before_cleanup=residual_before,
                remaining_after_cleanup=remaining,
                elapsed_seconds=time.monotonic()-begin)


def main(argv):
    if len(argv) < 4:
        raise SystemExit('usage: supervisor.py OUTPUT_DIR LIBRARY CASE_ID [CASE_ID...]')
    if not Path('/proc').is_dir():
        raise SystemExit('Linux /proc is required for process-group verification')
    out = Path(argv[1]).resolve(strict=True)
    library = Path(argv[2]).resolve(strict=True)
    ids = [int(x) for x in argv[3:]]
    if len(set(ids)) != len(ids) or any(x < 1 or x > 36 for x in ids):
        raise SystemExit('case IDs must be unique integers in 1..36')
    case_limit = int(os.environ['TWO_KERNEL_CASE_TIMEOUT_SECONDS'])
    stage_limit = int(os.environ['TWO_KERNEL_STAGE_BUDGET_SECONDS'])
    if case_limit <= 0 or stage_limit <= 0 or stage_limit > 10800:
        raise SystemExit('invalid time limit; stage must be at most 10800 seconds')
    if not os.environ.get('TWO_KERNEL_BUILD_MANIFEST'):
        raise SystemExit('TWO_KERNEL_BUILD_MANIFEST is required')
    for v in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):
        os.environ[v] = '1'
    for case in ids:
        for ext in ('log','exit','status.json'):
            if (out / f'case-{case}.{ext}').exists():
                raise SystemExit(f'refusing to overwrite case {case}')
        if (out / f'case-{case:02d}.rds').exists():
            raise SystemExit(f'refusing to overwrite case {case}')
    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGINT, _on_signal)
    stage_deadline = time.monotonic() + stage_limit
    failed = False
    for case in ids:
        if _CANCEL is not None or time.monotonic() >= stage_deadline:
            failed = True
            break
        with (out / f'case-{case}.log').open('x') as log:
            try:
                receipt = execute(['Rscript','--vanilla','dev/two-kernel-gaussian/pilot/run-case.R',str(case),str(out),str(library)],log,case_limit,stage_deadline)
            except OSError as exc:
                receipt = dict(reason='startup_error', process_exit=127, error=str(exc),
                               pgid=None, residual_before_cleanup=[], remaining_after_cleanup=[])
        code = receipt['process_exit'] if receipt['reason'] in ('normal_exit', 'startup_error') else 124
        if code is None:
            code = 125
        if receipt['remaining_after_cleanup'] or receipt['residual_before_cleanup'] and receipt['reason'] == 'normal_exit':
            code = 125
        (out / f'case-{case}.exit').write_text(f'{code}\n')
        with (out / f'case-{case}.status.json').open('x') as f:
            json.dump(receipt,f,indent=2)
        if code != 0:
            failed = True
        if receipt['remaining_after_cleanup'] or receipt['reason'] in ('stage_timeout','interrupted'):
            break
    return 1 if failed else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv))
