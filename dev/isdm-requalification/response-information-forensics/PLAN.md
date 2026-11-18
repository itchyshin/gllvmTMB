# iJSDM response-information: retained-fit forensic audit

```text
🎯 GOAL

Solo platform: Codex
Deliverable: a reproducible diagnosis of the two retained `rep3` fit-health
misses in the completed iJSDM response-information campaign, plus an honest,
checkable recommendation on whether a new campaign should be designed.

HEADLINE: explain the two gradient-gate misses before investing in another
recovery denominator.

IN PARALLEL: immutable-receipt verification and matched-control comparison.

DEFER: rerunning/replacing/reclassifying any retained identity; changing the
0.01 gradient threshold; new APIs, engine or optimizer changes; public claims;
release work; and a new scientific campaign.

DISCIPLINE: verify against the frozen 800-record manifest; compute is
read-only retrieval and local analysis only; closure is an internal forensic
receipt and a fresh-campaign decision, not a recovery verdict.
```

## Frozen contract

The predecessor campaign is immutable. Its 800 retained worker receipts,
frozen plan, source/harness identities, record hashes, and
`EVIDENCE_INCOMPLETE` verdict remain unchanged. This audit may copy a
read-only, named subset from Tamia's `/project` archive for analysis; it must
not write into that archive or infer a replacement result.

The two focal records are `rep3` task IDs 624 and 632: cell 7, datasets 312
and 316. They returned finite estimates, convergence code zero, and
positive-definite Hessians, but had maximum gradients 0.01036609 and
0.01108690, exceeding the frozen threshold of 0.01. The audit compares them
with all returned cell-7 records and their matched baseline arms.

## Gates

- **G0 predecessor integrity:** the frozen plan and focal receipt hashes match
the committed checksum manifest.
- **G1 reproducible extraction:** a script creates its working subset from
explicit task IDs and records every local file hash; raw evidence is never
changed.
- **G2 diagnostic oracle:** re-read raw records and independently recreate the
fit-health predicate, focal status, and matched-pair availability.
- **G3 mechanism analysis:** compare focal values with matched baseline and
same-cell controls for diagnostics, covariance/parameter estimates, surface
scores, runtime, and data/truth metadata available in raw records.
- **G4 conclusion:** label the mechanism as supported, unresolved, or
contradicted. A recommendation for a new campaign is allowed only if it does
not modify the predecessor result and specifies the pre-run evidence it needs.
- **G5 closure:** tests, report, validation-register wording, check log, and
after-task report agree. No public capability surface changes.

## Estimate and stop rules

This is a read-only archive analysis with no optimizer invocation. Estimated
active runtime is 20--45 minutes after archive access, well below a new
campaign decision. Stop and report rather than improvise if a focal receipt is
missing, hash verification fails, the record schema cannot expose the required
diagnostics, or archive access would require a new login/second factor.
