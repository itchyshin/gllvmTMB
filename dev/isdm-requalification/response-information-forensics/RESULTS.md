# iJSDM response-information forensic result

## Verdict

**Supported observation:** the two unscoreable `rep3` fits form the narrow
upper gradient tail in cell 7 (`n_sources = 3`, `n_cells = 810`, full overlap).
They have ranks 49/50 and 50/50 among that cell's `rep3` fits, with maximum
gradients 0.01036609 and 0.01108690. Their hashes match the immutable retained
manifest.

**Not established:** a component-level numerical cause. Retained receipts hold
only the scalar maximum gradient, not its parameter/component identity or a
full optimizer trace. The result cannot distinguish a shallow stopping residue
from a particular covariance, fixed-effect, or response-stream direction.

**Decision: `NO_FRESH_CAMPAIGN_YET`.** The original 800-fit campaign remains
`EVIDENCE_INCOMPLETE` with 398/400 scoreable pairs. The audit does not alter
its denominator, thresholds, eligibility, classification, or public scope.

## Evidence

Both matched baseline fits were valid and had ordinary gradients (0.00506980
and 0.00346187). In the same cell, the largest baseline gradient was 0.00999407:
just below the same frozen 0.01 threshold. The two focal `rep3` fits are not
obvious recovery outliers: their shared and full surface errors are near the
cell's `rep3` medians, their covariance errors are below the cell's 95th
percentile, and their runtime and memory use are also near the cell median.
One focal fit has elevated `Psi[1]` error, but the other does not, so this is
not a stable `Psi` failure pattern.

The committed evidence tables were regenerated directly from all 800 immutable
Tamia `/project` records:

- `evidence/fit-diagnostics.csv`: one health and raw-score row per retained fit.
- `evidence/pair-diagnostics.csv`: 400 matched baseline/`rep3` rows.
- `evidence/focal-diagnostics.csv`: exact focal hashes, ranks, matched controls,
  raw scores, runtime, and memory.
- `evidence/receipt.csv`: schema and conservative decision.
- `evidence/HASHES.sha256`: SHA-256 receipt for every committed compact table.

## Required pre-run evidence before any successor campaign

A successor must be a **new** study with a new immutable denominator. First run
a non-retained engineering qualification using the exact cell-7 fixture and
record component-level gradient labels plus optimizer termination information.
It must establish whether an enhanced convergence setting resolves the tail
without changing the fitted estimand or systematically changing estimates. Only
then may a new campaign plan specify its DGP, fit-health rule, comparator, and
budget. It must never overwrite or retroactively amend this campaign.
