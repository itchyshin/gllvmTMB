# G2i smoke decision record

The fixture, seed, GBIF-only bias gate, rank-one `Lambda`, diagonal `Psi`,
three PA-cloglog visits, profile offsets `(-2,-1,0,1,2)`, and geometry labels
are frozen from G2h.  `GEOMETRY_RESPONSIVE` requires finite valid profiles,
GBIF-bias maximum error below `0.30`, and at least two lower-profile
delta-NLL values at least `2`; `PROFILE_LIMITED` has finite valid profiles and
GBIF-bias error below `0.30` but not that lower-profile result; all other
finite cases are `NONRESPONSIVE`.

Operational completion is separate: three restart rows, all six valid
profiles, and a final selected-estimator AD maximum gradient at most `1e-3`.
For G2i it additionally requires a retained, eligible, attempted, accepted
deterministic-polish ledger.  Any missing/invalid field is a HOLD, never a
scientific nonresponse.  A pass supports only this synthetic nonspatial core;
it is not recovery-campaign, spatial, empirical, abundance, or public-package
evidence.
