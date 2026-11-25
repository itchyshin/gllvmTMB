#!/bin/sh
# The Python supervisor enforces both case and stage deadlines and cleans up
# the dedicated process group for each case. Never nest GNU timeout here.
set -eu
exec python3 dev/two-kernel-gaussian/pilot/supervisor.py "$@"
