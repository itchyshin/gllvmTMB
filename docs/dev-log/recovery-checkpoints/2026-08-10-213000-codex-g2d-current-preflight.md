# G2d current-commit no-fit preflight checkpoint

- **Branch/head**: `codex/isdm-g2d-six-species` at `a4ab334490de5a49d52e0a5b4034ff09d1b3e636`.
- **Why refreshed**: the exact-profile-map harness repair changed the runner after the earlier P1 receipt, so a future smoke requires provenance at the new frozen runner hash.
- **Evidence**: ignored root `dev/isdm-package-recovery/results/g2d-preflight-20260810-213000/` returned `G2D_PREFLIGHT_PASS`; receipt and sentinel read-back audit passed.
- **No fit**: this command did not run a local smoke, campaign fixture, Totoro, or empirical/public work.
- **Gate**: a future local smoke still requires fresh explicit authority and a new root; current state remains `G2D_SMOKE_HOLD`, so Totoro remains closed.
