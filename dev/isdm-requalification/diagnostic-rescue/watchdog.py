#!/usr/bin/env python3
"""Run one command in a new process group and stop the whole group on overrun."""

import os
import signal
import subprocess
import sys


class SupervisorSignal(Exception):
    """Raised inside wait() when the supervisor receives an external signal."""

    def __init__(self, signum: int):
        self.signum = signum


def stop_group(process: subprocess.Popen) -> None:
    """Terminate the supervised process group and wait for every child."""
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()


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
    previous = {}

    def handle(signum, _frame):
        raise SupervisorSignal(signum)

    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        previous[signum] = signal.signal(signum, handle)
    try:
        return process.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        stop_group(process)
        print("DIAGNOSTIC_WATCHDOG_FIRED status=124", flush=True)
        return 124
    except SupervisorSignal as exc:
        stop_group(process)
        status = 128 + exc.signum
        print(f"DIAGNOSTIC_WATCHDOG_SIGNAL signal={exc.signum} status={status}",
              flush=True)
        return status
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


if __name__ == "__main__":
    raise SystemExit(main())
