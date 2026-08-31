#!/usr/bin/env python3
"""Run one named check with an immutable log, process-group cap and receipt."""
import json, os, pathlib, signal, subprocess, sys, time
name, cap, *command = sys.argv[1:]
root = pathlib.Path(__file__).resolve().parent
out = root / "receipts"
out.mkdir(exist_ok=True)
receipt = out / (name + ".json")
log = out / (name + ".log")
if receipt.exists() or log.exists():
    raise SystemExit("Refusing to overwrite an existing attempt")
record = {"name": name, "command": command, "cwd": os.getcwd(), "cap_seconds": int(cap), "started": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "status": "running"}
receipt.write_text(json.dumps(record, indent=2) + "\n")
start = time.monotonic()
with log.open("w") as stream:
    proc = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        code = proc.wait(timeout=int(cap))
        record.update(status="passed" if code == 0 else "failed", exit_code=code)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGTERM)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
        record.update(status="timed_out", exit_code=124)
record["elapsed_seconds"] = round(time.monotonic() - start, 3)
receipt.write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record))
sys.exit(record["exit_code"])
