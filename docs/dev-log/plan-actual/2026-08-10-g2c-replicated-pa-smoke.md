# Plan versus actual: G2c replicated-PA admission

## Planned

S0--S4 were approved: freeze G2c, construct the package-native three-event
fixture, test its event contract, and run one local smoke.  S5 (a 30-fixture
Totoro campaign) required a fresh approval after `SMOKE_PASS`; comparator
execution, count, spatial, sources, empirical data, public interfaces, and
Issue #953 were deferred.

## Actual

- **S0--S3:** completed.  Protocol, decision, runner, dormant launcher, no-fit
  validation, and a private comparator-readiness reconciliation were retained.
- **S4:** completed with `SMOKE_HOLD`, not `SMOKE_PASS`.  The fit/profile
  evidence is retained in two reconciled roots.
- **S5--S8:** not started.  This is an adaptive stop required by the explicit
  smoke gate, not a dropped campaign.
- **Scope:** matched.  No Totoro, empirical, source, count, comparator run,
  spatial, public/package API, manuscript, or issue mutation occurred.  A
  read-only Issue #953 / PR #952 state check was part of closure only.
- **Review:** two fresh read-only admission reviews were obtained.  Fisher
  approved the scientific HOLD; Rose required and then received the durable
  provenance/closeout work.  The full D-43 campaign panel was not fired because
  no campaign was admitted.

## Material deviations and reconciliation

| axis | status | reconciliation |
|---|---|---|
| evidence | adaptive | smoke failed eligibility, so a 30-fixture recovery verdict could not be pursued |
| verification | adaptive | full D-43 was conditional on S5; admission reviews instead constrained the HOLD wording |
| provenance | repaired | two ignored smoke roots are inventory-hashed in a committed ledger |
| routing | matched | local-only; dormant launcher refuses Totoro |
| safety/public claims | matched | no public or empirical scope widened |
| handoff | complete | next design and no-rerun fence are explicit in the private decision memo |

## Next boundary

`LANE: START A FRESH TASK`.  First read the G2c smoke decision, provenance
ledger, and after-task report.  The next task must decide whether to approve a
larger-community G2d design; it must not rerun, reinterpret, or overwrite G2c.
