# Design 100-C: one-shot direct-2D non-evidence execution contract

**Status:** approved execution contract; not a VA/JJ/EVA, package, calibration,
or public-capability task.

This fresh run supersedes neither Design 99 nor the terminal Design-100-B root.
It uses a new output root and does not delete, repair, or read the B root.

The only computation is four serial evaluations of the frozen
`direct-2d-original-u-v1` worker: a six-trait Bernoulli-logit pattern
probability under the fixed normalized-standard-normal 5x5 original-`u` rule.
The order is `000000`, `010101`, `101010`, `111111`.  There is one worker, no
retry, no optimizer, no adaptive rule, and no information ladder.

Hard limits: 300 seconds per component and pattern, 60 seconds stale-progress,
30 seconds liveness, and 1,260 seconds for the whole gate.  The sole root is
`/private/tmp/gllvmtmb-design100c-direct2d-output`; it must be absent before
launch and is exclusive-write thereafter.

The approved input is a fresh private `beta[6]`/`lambda[6,2]` manifest.  The
run writes approval, launch, liveness, progress, result, component-terminal,
and pattern-terminal records only.  `PROGRESS_COMPLETE` means only that these
four finite calculations and records completed; it is not an exact-reference,
recovery, or approximation-quality claim.
