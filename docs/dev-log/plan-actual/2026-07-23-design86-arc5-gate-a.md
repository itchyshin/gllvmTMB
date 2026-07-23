# Plan versus actual — Design 86 Arc 5 Gate A

## Planned

Run a two-gate diagnosis: close artifact provenance and parameter mapping,
perform deterministic no-DGP controlled diagnostics, and promote to a V2
amendment and one smoke only after a Gate-A `GO` and a separately signed Gate
B.

## Actual

Completed the static provenance, coordinate, and numerical-source reviews;
froze the Gate-A diagnostic specification; implemented and executed a
non-Gate-2 controlled TMB/optimizer probe; and obtained independent Gauss and
Rose reviews.  The work stopped at Gate A.

## Material evidence

- `output_manifest_sha256` is a result-file digest under the current runner,
  not a missing manifest object.
- Historical extreme coordinates are raw `theta_rr` loadings.
- Controlled AD/finite-difference and code/gradient telemetry checks behaved
  as designed, but the predeclared scale test was nondiscriminating.
- Gauss: `INCONCLUSIVE`; Rose: `PARK` because the receipt lacks the full
  audit trail required for a Gate-A pass.  The conservative operative verdict
  is `PARK`.

## Deviations and reconciliation

The plan expected full raw A0–A3 telemetry.  The initial receipt preserved
only a summary, so Rose correctly withheld a pass.  This is a material
evidence-recording deviation, not a reason to rerun or retrofit the historical
record.  The receipt wording was corrected to state `PARK`; no V2 or live lane
was started.

## Deferred work

V2 amendment drafting, Gate-B preflight, all runner calls, smoke roots,
campaigns, historical rescores, public/API/C++ work, Gate-3/4, Totoro, DRAC,
push, and PR remain deferred.
