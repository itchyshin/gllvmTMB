#!/usr/bin/env python3
"""Harmless bounded Linux process cleanup test; no fits or simulations."""
import io
import os
import signal
import sys
import tempfile
import threading
import time
import supervisor

signal.signal(signal.SIGTERM,supervisor._on_signal)
signal.signal(signal.SIGINT,supervisor._on_signal)
child_code = "import subprocess,time; p=subprocess.Popen(['sleep','30']); print(p.pid,flush=True); time.sleep(30)"
for label,case_limit,stage_limit,interrupt in [
    ('case_timeout',.5,10,False),('stage_timeout',10,.5,False),
    ('interrupted',10,10,True),('normal_exit',10,10,False),
    ('normal_exit_with_orphan',10,10,False)]:
    supervisor._CANCEL=None
    if label=='normal_exit':
        command=[sys.executable,'-c','print("normal")']
    elif label=='normal_exit_with_orphan':
        command=[sys.executable,'-c',"import subprocess; p=subprocess.Popen(['sleep','30']); print(p.pid,flush=True)"]
    else:
        command=[sys.executable,'-c',child_code]
    timer = threading.Timer(.5,lambda: os.kill(os.getpid(),signal.SIGTERM)) if interrupt else None
    if timer: timer.start()
    with tempfile.TemporaryFile(mode='w+') as out:
        receipt=supervisor.execute(command,out,case_limit,time.monotonic()+stage_limit)
        out.seek(0); output=out.read().strip()
    if timer: timer.join()
    assert receipt['reason']==label if label!='normal_exit_with_orphan' else receipt['reason']=='normal_exit', receipt
    assert not receipt['remaining_after_cleanup'], receipt
    assert not supervisor.group_live(receipt['pgid']), receipt
    if label=='normal_exit_with_orphan': assert receipt['residual_before_cleanup'],receipt
    if label in ('case_timeout','stage_timeout','interrupted','normal_exit_with_orphan'):
        assert output.isdigit(), (label,output)
        try: os.kill(int(output),0)
        except ProcessLookupError: pass
        else:
            # A killed, reparented process may transiently be a zombie; it is not running.
            try:
                stat=open('/proc/'+output+'/stat').read(); state=stat[stat.rfind(')')+2:].split()[0]
            except FileNotFoundError: state='gone'
            assert state in ('Z','gone'), (label,output,state)
    print(label,'PASS',receipt,flush=True)
print('SUPERVISOR_CLEANUP_PASS')
