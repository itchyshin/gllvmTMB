# Post-validation issue sweep before 0.7

Date recorded: 2026-08-08  
Trigger: immediately after the warm-restart/v4 scientific arc and before the
0.7 identity/source freeze  
Live baseline: 49 open GitHub issues (`gh issue list`, 2026-08-08)

## Maintainer instruction

Shinichi asked for an issue sweep after the current validation arc because the
repository has more than 40 open issues and some should be resolved before 0.7.
This is a required pre-freeze arc, not an invitation to interrupt the current
scientific campaign or to implement every roadmap item.

## Deliverable

Produce one complete 49-row disposition ledger. Every issue receives exactly
one status:

1. **close — already completed**, with commit/test/document evidence;
2. **close — duplicate/superseded**, naming the surviving issue or decision;
3. **fix before 0.7**, limited to bounded correctness, silent-failure,
   documentation, CRAN, or release-engineering work;
4. **fence before 0.7**, where implementation remains but public scope/error
   handling must prevent overclaiming;
5. **defer after 0.7**, with a concrete reason and dependency;
6. **park/research**, for non-release feature or methods exploration.

No issue is closed merely because it is old, difficult, or outside the
dependable-core headline. Closure requires direct evidence; deferral remains an
open, labelled disposition unless the issue itself is explicitly a completed
decision record.

## Triage order

### A. Possible pre-0.7 correctness or silent-failure blockers

Start with issues whose titles indicate false convergence, silent degeneracy,
dead controls, misleading disclosure, asymmetric interval behavior, opaque
failures, brittle tests, or hidden assertions: #897, #872, #871, #848, #843,
#837, #836, #835, and #834. Alternative-integration, ordinal, structured-tier,
and nonlinear-profile certification remain deferred, but their shipped surface
must still be honestly fenced.

### B. Likely bounded documentation or stale-evidence closures

Inspect #932, #931, and #913 against the live source and existing receipts.
These may be small pre-0.7 corrections or already-completed issues, but the
sweep must reproduce their current state before deciding.

### C. Recently completed or partially completed implementation issues

Check recent issues such as #946 against `main`, all branches, tests, and
public docs. A merged implementation is not automatically a closed issue if
documentation, recovery evidence, or issue acceptance criteria remain open.

### D. Explicitly deferred release-scope items

The approved CRAN programme already defers broad Stan expansion (#930 and
related oracle extensions), #750 unconditional structured-tier redraw, ordinal
certification, VA/AGHQ/EVA promotion, broad coverage, new families/covariance
modes, and large roadmap umbrellas. The issue sweep records these boundaries;
it does not silently pull them into 0.7.

### E. Roadmap and umbrella hygiene

Reconcile the long-lived roadmap/status issues (#345--#349, #340--#343, and
related umbrella items) with the current validation register and limitations
page. Close only umbrellas whose stated work is genuinely complete; otherwise
update their scope/status rather than treating them as ordinary bugs.

## Gates

- Inspect issue bodies/comments and live code before disposition; title-only
  triage is provisional.
- Search `git log --all`, not only the current checkout.
- A pre-0.7 fix receives implementation, focused tests, reader-facing boundary
  where relevant, check-log entry, and independent review.
- Avoid feature creep: a large deferred method becomes a documented fence, not
  a surprise release sprint.
- After the ledger is reviewed, apply GitHub labels/comments/closures in a
  deliberate batch and retain before/after counts.
- The 0.7 version/source freeze cannot begin until every issue has a disposition
  and every **fix before 0.7** item is either closed with evidence or explicitly
  escalated into the 19 August no-go decision.

## Boundary

The current warm-restart/v4 arc remains first. This sweep begins after its
scientific adjudication, while the package still carries the 0.6 identity. It
precedes any 0.7 tag, GitHub release, exact CRAN candidate, or CRAN submission.
