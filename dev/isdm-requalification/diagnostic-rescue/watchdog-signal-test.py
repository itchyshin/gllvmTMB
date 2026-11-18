#!/usr/bin/env python3
"""Adversarial check that TERM, INT, and HUP leave no supervised child."""

import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import time


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def check(watchdog: str, signum: int) -> None:
    with tempfile.TemporaryDirectory(prefix="isdm-watchdog-") as directory:
        pid_path = pathlib.Path(directory) / "child.pid"
        command = f"echo $$ > {pid_path}; exec sleep 20"
        process = subprocess.Popen(
            [sys.executable, watchdog, "20", "bash", "-c", command],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        for _ in range(100):
            if pid_path.exists():
                break
            time.sleep(0.02)
        if not pid_path.exists():
            process.kill()
            raise RuntimeError("supervised child did not publish its pid")
        child_pid = int(pid_path.read_text().strip())
        os.kill(process.pid, signum)
        output, _ = process.communicate(timeout=15)
        expected = 128 + signum
        if process.returncode != expected:
            raise RuntimeError(
                f"signal {signum}: status {process.returncode}, expected {expected}: {output}"
            )
        time.sleep(0.05)
        if alive(child_pid):
            raise RuntimeError(f"signal {signum}: child {child_pid} survived")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: watchdog-signal-test.py WATCHDOG_PY")
    watchdog = os.path.realpath(sys.argv[1])
    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        check(watchdog, signum)
    print("DIAGNOSTIC_WATCHDOG_SIGNALS_VERIFIED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
