#!/usr/bin/env python3
"""Run one command in a new process group and stop the whole group on overrun."""

import os
import signal
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 3:
        raise SystemExit("usage: watchdog.py SECONDS COMMAND [ARG ...]")
    try:
        seconds = int(sys.argv[1])
    except ValueError as exc:
        raise SystemExit("SECONDS must be an integer") from exc
    if seconds < 1:
        raise SystemExit("SECONDS must be positive")
    process = subprocess.Popen(sys.argv[2:], start_new_session=True)
    try:
        return process.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        print("DIAGNOSTIC_WATCHDOG_FIRED status=124", flush=True)
        return 124


if __name__ == "__main__":
    raise SystemExit(main())

