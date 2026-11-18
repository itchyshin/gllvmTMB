# G2i private replacement-smoke protocol

G2i repeats the frozen G2h six-species, 360-cell, nonspatial relative-intensity
iJSDM: GBIF Poisson-log records, three conditionally independent
PA-cloglog visits, one shared rank-one `Lambda`, free diagonal `Psi`, and the
GBIF-only bias gate.  It reuses `g2h-360cell-fixture.R` unchanged.

The only estimator change is the private G2i deterministic-polish contract in
`2026-08-11-g2i-polish-contract.md`.  One ordinary three-start fit is run.
When its raw state meets that contract, exactly one same-objective candidate is
run automatically from the raw outer vector.  There is no retry, alternate
fixture, changed profile, or tolerance relaxation.

The smoke root must be fresh under `dev/isdm-package-recovery/results/`, bind
the current SHA and all runner/fixture/contract hashes, and retain truth, fit,
raw/candidate polish ledger, six profile ledgers, decision ledger, stage log,
file manifest, and terminal receipt.  Fit errors and invalid profile ledgers
are `G2I_SMOKE_HOLD`.

`G2I_SMOKE_COMPLETE` requires: the frozen fixture/source-gate validation,
three retained starts, six finite/converged diagonal profiles, the frozen
geometry classification, an eligible/attempted/accepted G2i polish ledger, and
the selected final AD maximum gradient at or below `1e-3`.  G2h remains
`G2H_SMOKE_HOLD` regardless.  This smoke is admission evidence only; it does
not authorize a recovery pre-run or a Totoro campaign.
