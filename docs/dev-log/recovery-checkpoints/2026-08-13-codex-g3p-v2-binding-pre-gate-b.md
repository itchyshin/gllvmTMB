# Recovery checkpoint — G3P V2 binding, pre-Gate B

- **Branch:** `codex/isdm-g3-provenance-amendment` at `fdcb05cd`.
- **Changed commit:** execution-context receipt binding plus V2-only packet,
  root, attempt, and time argument guards; the preflight time estimate and
  hard stop are receipt-bound before smoke entry.
- **Passed:** focused G3P contract/packet tests and parse checks (no-fit).
- **Not run:** every runner mode; all fitting, profiling, simulation, remote
  compute, and public builds.
- **Next safest action:** obtain independent Gauss/Noether, Fisher, and Rose
  review of `fdcb05cd`. Only a unanimous pass permits an explicit request to
  create the V2 packet and ignored root; that approval does not permit a
  preflight or smoke.
