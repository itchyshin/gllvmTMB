# After Task: the three-axis frontier programme (pilot + three campaigns)

**Branch**: `codex/isdm-range-amplitude-orthogonal`
**Date**: `2026-08-15`
**Roles (engaged)**: `Ada (orchestration) / Gauss (workers, campaigns) / Noether (audits, verification) / Rose (closure) / Florence+Tufte (figures) / Melissa (reconcile) / Shannon (preflight)`

## 1. Goal

After the morning's audit closed the chart lane, the maintainer reassigned
execution to Claude and drove three successive measured arcs: the effort
frontier, the replication axis, and the domain-growth axis -- with the
declared destination *"it is our final prize and data integration is where we
are heading"* (the integrated-JSDM papers).

## 2. Implemented

- **Effort-ladder pilot** (4 fits, byte-exact DGP reconstruction) and the
  **effort campaign** (1,600 fits): E*_pd = 1.85 [1.43, 3.17]; amplitude
  frontier unreached; bimodal failure surface (92 runaways).
- **Replication campaign** (2,400 fits, Amendment A1, discrete-anchored
  normalisation after the gate caught a 17-21% continuum drift): the
  finer-patches hypothesis **REFUTED** -- monotone degradation.
- **Domain-growth campaign** (1,600 fits, Amendment A2, anchor rebuild gate
  5.5e-12 through the sealed lineage's `.gll_isdm_fit`): monotone improvement
  on every metric; the two-arm law *replication helps iff per-patch
  information is preserved*.
- **Ride-alongs**: runaway classification (whole-SPDE-block scale ray;
  `loading_runaway_thresh = 25` mis-fires on 60% of healthy fits -- #851
  class); P1-F1 v2 with the four Florence fixes; figure reviews; P1-F2/F3/F4.
- ~7,200 fits total on Totoro; every campaign 0 errors, all within budget.

## 3. Files Changed

Commits `73ead7d9..7935c741` (this arc-set): campaign designs + amendments,
workers `frontier-campaign/{0,1,1b,1c,2,2b,2c,3}_*.R`, results notes,
runaway-classification note, figure review, P1-F1 v2 renderer, distilled
artifacts under `frontier-campaign/artifacts/`. `R/` and `src/` untouched.
Sealed roots reread only; no packet/root/ledger/status token written.

## 3a. Decisions and Rejected Alternatives

- Replication arm chose range-shrink (surgical, frozen geometry) over domain
  growth first -- the refutation it produced then justified building the new
  geometry for A2. Sequencing vindicated.
- A1 normalisation switched continuum -> discrete-anchored when the gate
  caught the drift; rejected widening the tolerance.
- A2 went through the package's own developer entry rather than hand-built
  TMB data; rejected the hand-assembly after the public front-end fence
  revealed the sealed lineage's actual path.
- E capped at 2 in A2 (cost concentrates in big domains; A1 showed E=4 adds
  little discrimination near the frontier).

## 4. Checks Run

Anchor gates: byte-exact y reconstruction (pilot); objective replay 1.5e-11
(falsifier); anchor rebuild 5.5e-12 (A2 builder). Anchor-consistency kill
rules passed for A1 vs effort (|z| <= 2.53) and A2 vs A1 (|z| <= 1.97).
Pre-run smoke gates before every campaign. MCSE on every aggregate; failures
retained as rows. All raw rows on Totoro `~/frontier-prerun/` + local copies;
distilled artifacts committed.

## 5. Tests of the Tests

The A1 gate demonstrated its worth by FAILING first (unit-field SD 0.795) and
forcing the discrete anchoring; the A2 anchor gate was preceded by three
in-process failures (column mapping, deprecated alias, the isdm fence) each
of which stopped the build loudly. The adversarial reviewer earlier refuted
the diagnosis's mechanism and the DGP-truth claim -- both corrected visibly.

## 6. Consistency Audit

Cross-campaign anchors reproduce within predeclared MCSE rules; truth values
recomputed from constants at every level, never transcribed (the fixture
literal lesson). The three results notes cross-reference; superseded sections
retained under SUPERSEDED headings.

## 7. Roadmap Tick

Three axes measured; DEFER on paper drafting lifted. Next: evidence-chapter
draft (started this session), then the ~10-20k-cell confirmation campaign if
the draft needs the crossing measured rather than extrapolated.

## 7a. GitHub Issue Ledger

None. Branch push authorized by maintainer; blocked by the session's
permission classifier -- command handed to the maintainer to run.

## 8. What Did Not Go Smoothly

The replication arm's first normalisation was wrong (caught by its own gate);
my audit's F1 framing ("pathological loadings") was corrected by measurement;
the pilot's optimism did not survive marginalisation over field realisations
-- recorded as the standing lesson *conditional recovery is not marginal
recovery*. The public front-end fence cost three build iterations before the
developer entry was found.

## 9. Team Learning

The day's generalisable results: (1) the two-arm replication law; (2)
conditional != marginal recovery; (3) gates that fail loudly at build time
are worth more than reviews after -- every campaign gate that could fail did
so at least once during development and each failure was caught before
compute was spent.

## 10. Known Limitations And Next Actions

Frontier crossing beyond 2,250 cells is extrapolation; gamma under-coverage
still unexamined; scale-free runaway detector designed-by-evidence but not
built; two test files remain unguarded for a different call shape; the
detector/coverage items and Paper 2 are unstarted. Raw rows on Totoro should
move to a durable archive if the programme pauses.
