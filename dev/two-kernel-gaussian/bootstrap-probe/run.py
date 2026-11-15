#!/usr/bin/env python3
"""Run the reviewed synthetic bootstrap probe with a process-group deadline."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

root = Path.cwd()
out = root / 'dev/two-kernel-gaussian/bootstrap-probe/output'
out.mkdir(exist_ok=False, parents=True)
sources = sorted(p for base in ('R', 'src') for p in (root / base).rglob('*')
                 if p.is_file() and p.suffix not in ('.o', '.so', '.dll', '.dylib'))
sources += [root / 'DESCRIPTION', root / 'NAMESPACE', Path(__file__),
            root / 'dev/two-kernel-gaussian/bootstrap-probe/probe.R']
def snapshot():
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}

before = snapshot()
env = dict(os.environ, OPENBLAS_NUM_THREADS='1', OMP_NUM_THREADS='1', MKL_NUM_THREADS='1')
command = ['Rscript', '--vanilla', 'dev/two-kernel-gaussian/bootstrap-probe/probe.R', str(out)]
started = time.monotonic()
reason = 'normal_exit'
with (out / 'run.log').open('w') as stream:
    child = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                             env=env, start_new_session=True)
    try:
        status = child.wait(timeout=300)
    except subprocess.TimeoutExpired:
        reason = 'timeout_300s'
        os.killpg(child.pid, signal.SIGTERM)
        try:
            status = child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            status = child.wait()
after = snapshot()
receipt = dict(command=command, child_pid=child.pid, exit_code=status, reason=reason,
               elapsed_seconds=time.monotonic()-started, source_sha256_before=before,
               source_sha256_after=after, source_unchanged=before == after)
(out / 'supervisor.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({k: v for k, v in receipt.items() if not k.startswith('source_sha256')}, indent=2))
sys.exit(0 if reason == 'normal_exit' and status == 0 and before == after else 1)
