# Melissa reconciliation — PVT-02 interval calibration packet

## Planned versus actual

| Plan item | Actual | Assessment |
| --- | --- | --- |
| Reconcile the `n >= 150` predicate before building | Reconciled against the predicate, its `n = 4000` test, CI-08 certificate, target ledger, and stale truth matrix | completed; no public status changed |
| Build pure contract and focused tests | Added target/gradient/root/seed/retention/promotion helpers and 7 focused tests | completed |
| Estimated local smoke under 30 minutes | Estimated 10 min; two actual fits took 21.3 s total | completed, materially under estimate |
| Retain every smoke attempt | CSV retains both rows, both realised seeds, both endpoint classifications | completed |
| Unlazy ledger | First run exposed a ledger-CWD path defect; fixed relative commands and replayed all four gates | adaptive repair; verifier is stronger |
| Rose and Grace review | Rose PASS; Grace found missing realised-seed validation, then PASS after the repair | completed; review changed the artifact |
| Full campaign | Not run | correct stop: measured projection is >30 min and requires explicit Totoro approval |

## Deviations

The plan described a Luna-low provenance slice, but the provenance sweep ran
inline because native Codex dispatch in this session did not provide a Luna
child route. This is a process-routing deviation, not a substitution of
unreviewed evidence: the prior-work receipt, source-pinned ledger, branch
history, and local searches are recorded in the packet. Terra-high was used
for the two independent review lenses as planned.

The required lane-preflight executable was absent from the installed tool
locations and GitHub API access was unavailable. The lane therefore relied on
the prior plan receipt, exact leases, local branch history, and a new branch
from `origin/main`; it does not claim a live remote-PR absence.

## Melissa verdict

**ON PLAN after one adaptive verifier repair.** The repair closed a real
reproducibility gap before any campaign work. Scope stayed narrower than the
plan: no public predicate/test/truth-matrix edit, no status promotion, no
remote run, and no shared check-log edit.
