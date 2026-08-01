# Recovery checkpoint: #847 scale-aware tau before Totoro smoke

## Branch and working tree

- Worktree: `/private/tmp/gllvmtmb-tau-847`
- Branch: `codex/scale-aware-tau-847`
- Base: merged #877 on `origin/main` (`bca04b29` when this lane started)
- Tracked changes: `R/fit-multi.R`, `src/gllvmTMB.cpp`
- New artifacts: the Arc-0 equivalence test, stored-fit rescore, Totoro
  campaign/analyser, and the Ultra Plan. This checkpoint is also new.
- The maintainer's unrelated dirty checkout has not been touched.

## Completed checks

- `test-aghq-auto-psi-equivalence.R`: PASS, 90 assertions.
- Neighbor tests: AGHQ control wiring, AGHQ surface, AGHQ multistart
  convergence, and binary likelihood sign: PASS.
- Exact objective/gradient equivalence: logit/probit/cloglog, q=1/2,
  optimum plus three perturbations: PASS.
- `28-tau-rescore.R`: PASS on the retained 12,000-fit CSV; no cap selected.
- Campaign/analyser parse and `git diff --check`: PASS.
- Synthetic selection and confirmation paths: PASS.
- Adversarial missing-row and overlapping-seed inputs: both rejected.
- Three campaign reviews: NOT READY on fail-open/provenance findings, NOT READY
  on lock/content invariants, then READY after all findings were repaired.
- Totoro environment: live approved socket, R 4.5.3, TMB 1.9.21, 384 cores,
  ample disk, and no pre-existing `gllvmTMB` install.

## Still to run

1. Commit the bounded Arc-0 plumbing and campaign harness; record the full SHA.
2. Install that SHA into a SHA-named private Totoro library, add and verify the
   installed-package SHA marker, and run the one-cell smoke.
4. If smoke is complete and schema-clean, run the six-cell paired selection
   campaign at no more than 100 cores.
5. Analyse selection. Only if one cap passes every preregistered gate, lock it
   and run the disjoint-seed confirmation.

## Next safest action

Freeze the reviewed commit and run the one-cell Totoro smoke. Do not launch
selection if smoke or provenance validation fails, and do not change the
package default before a cap passes both selection and confirmation. Plain
Laplace remains forbidden as a tau pilot.

## Blocking question

None. A no-cap or failed-confirmation result is a valid negative result and
leaves fixed tau = 2 unchanged.
