# After-task — two-paper C1/C2/Gate-A no-fit implementation

**Status:** private receipt implementation complete.  Paper 1 remains
`PRIVATE_NUMERICAL_ADMISSION_HOLD`; Paper 2 remains `PAPER2_PRIVATE_STOP_HOLD`;
the empirical candidate remains `HOLD_FOR_FIT_AND_DOWNLOAD`.

## 1. Goal

Implement only the user-approved Paper 1 C1 classifier-domain receipt, Paper 2
C2 all-attempt/Psi receipt, and empirical Gate-A metadata contract.  No fit,
profile, simulation, campaign, data download, public surface, or historical
HOLD mutation was in scope.

## 2. Implemented

No likelihood, DGP, map, transform, threshold, package API, or TMB source
changed. C1 reads the retained B2 gradient topology; C2 fixes the existing
S=6/20/60 design and retains `Psi_ss = exp(2 theta_diag_B_s)`; Gate A records
source/provenance eligibility without a row-level data asset.

## 3a. Decisions and Rejected Alternatives

Paper 1 is `NO_CANDIDATE`: the B2 maximum is the GBIF-only spatial slope
loading and outside frozen Case C. Paper 2 retains `NO_CANDIDATE` and the
private STOP/HOLD; its n=1 row cannot estimate co-occurrence. BBS + GBIF is
descriptive QA only and remains held for download/fit. Rejected alternatives:
reclassifying Case D, treating n=1 as a rate, or using BBS as repeated PA.

## 4. Files Touched

- `dev/isdm-package-recovery/paper1-spatial-c1-topology.R` and its runner/test.
- `dev/isdm-package-recovery/paper2-c2-all-attempt-contract.R` and its runner/test.
- `dev/isdm-package-recovery/empirical-gate-a-metadata-contract.R` and its runner/test.
- The three private design records, this report, and the check log.

No `R/`, `src/`, README, NEWS, ROADMAP, vignette, pkgdown, roxygen, or
generated Rd file changed.

## 5. Checks Run

- C1 immutable-ledger validation and private receipt: PASS.
- C2 frozen-contract validation and private receipt: PASS.
- Gate-A metadata validation and private receipt: PASS.
- `devtools::test()` targeted at the three new contracts: PASS (31 checks).
- `git diff --check`: PASS.

## 6. Tests of the Tests

The C1 test separates raw pass, Case C, spatial-only Case D, ties and invalid
inputs. C2 tests the independent denominator, unavailable attempts, A/P
separation, and immutable receipt shape. Gate A tests the BBS/GBIF candidate
is descriptive-only and statically excludes executable data/model paths.

## 7a. Issue Ledger

No GitHub issue, PR, CI, or remote compute action was created. This private
no-fit phase has no public tracker action.

## 8. Consistency Audit

The receipt runners contain no objective construction, optimiser, profile,
simulation, or download call.  Outputs are restricted to ignored private
results roots.  The historical Paper 1 and Paper 2 lanes were read but not
modified.

## 9. What Did Not Go Smoothly

Three receipt-only defects were caught and corrected before completion: an
overly strict floating-point equality check, a relative private-output path
guard, and a C2 validator that assumed one file hash rather than three source
hashes.  The metadata test also initially matched its own `download` wording;
it now scans only executable call forms.

## 10. Known Residuals

These are receipt contracts, not evidence that either model recovers a spatial
field or diagonal Psi. The protected historical Paper 1/Paper 2 HOLDs remain.
No raw empirical data are available, and no expected compute duration is known
because no timing probe or fit was approved.

## 11. Team Learning

Gauss/Noether independently confirmed the B2 maximum maps to the GBIF-only
spatial slope block and is not a frozen Case-C coordinate.  Rose identified
the need to protect loaded-source provenance before any future smoke; that
guard already exists in the B2 runner.  Fisher's interpretation holds: n=1
cannot estimate admission/Psi co-occurrence.

## 12. Cross-Product Coverage

The three contracts jointly cover: retained Paper 1 numerical classification,
Paper 2 all-attempt/Psi information design, and the empirical observation-law
admission boundary. This work **does NOT cover** recovery, spatial prediction,
empirical estimation, package API/engine changes, REML or penalty variants,
missing-data handling, aggregation, or any reader/public surface. Private design records name the
receipt outcomes; no public roadmap tick or advertised capability change is
warranted.

### Next action

The work supplies auditability, not recovery or empirical evidence.  A next
action must be explicitly approved: either retain both HOLDs, approve a new
Paper-1 numerical-admission estimator design, or separately approve a
time-estimated Paper-2 campaign proposal.  Empirical data remain metadata-only
until an observation-law-compatible case passes Gate A.
