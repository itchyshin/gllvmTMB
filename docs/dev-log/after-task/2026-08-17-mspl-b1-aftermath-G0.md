# After Task: B1 aftermath G0 brief (park default)

**Branch**: `docs/mspl-b1-aftermath-g0`
**Date**: `2026-08-17`
**Roles (engaged)**: Ada / Fisher / Rose
**Workspace**: `/private/tmp/gllvmtmb-mspl-b1-aftermath-g0`

## 1. Goal

Write the 05:00 decision brief Shinichi needs after the official B1
hold-out failed, and land it as a docs PR. No compute. No Totoro
relaunch.

## 2. Implemented

- Brief:
  `docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md`
- Official gate cited is #1040 (M0, G1 14/132 = 10.6%).
- #1056 / DEV-11 is named as a later M2 evaluator, not collapsed
  into the overnight number.
- Default recommended: **PARK**. Options B (redesign calibrator)
  and C (new construction) are written. \(n\to 2000\) is refused.
- D-148 paste-ready replies included.
- Design 118 §8 Phase B closure now points at the brief.
- `MSPL-04` not edited. No `R/` / `src/` / NEWS.

## 3. Files Changed

- `docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md` (new)
- `docs/dev-log/after-task/2026-08-17-mspl-b1-aftermath-G0.md` (this file)
- `docs/dev-log/check-log.md` (prepend)
- `docs/design/118-mspl-interval-calibration-protocol.md` (pointer)
- `docs/dev-log/dashboard/status.json` (B1 card)
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` (refresh)

## 3a. Decisions and Rejected Alternatives

Decision: recommend park as the 05:00 default.
Rationale: Design 118 §5.6 already requires no-promote on gate fail;
#1040 G1 is 10.6% vs 90%; M0 is the identity map, so this is not a
near-miss \(\gamma\) problem.
Rejected: redesign-calibrator as default (same construction, spent
hold-out, DEV-12 says the overcoverage premise is false).
Rejected: new-construction as default (needs a new Design number and
new compute; right later, wrong at 05:00).
Rejected: \(n\to 2000\) (even 14+25 PASS is 29.5%; G2 min 0.0218).
Confidence: high on the gate numbers (from #1040); high on park as
the operational default; medium on "C not B" if intervals reopen
(that is a later G0).

## 4. Checks Run

```sh
git rev-parse origin/main   # 3faa1a46 at branch cut
gh pr view 1040 --json title,state,mergedAt
rg -n '14/132|10\\.6%|M0' docs/dev-log/research/2026-08-16-mspl-b1-holdout-gate.md
rg -n 'DEV-11|Phase B closure' docs/design/118-mspl-interval-calibration-protocol.md
rg -n 'n→2000|n to 2000|PARK' docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md
```

Not run: `devtools::test()`, `--as-cran`, pkgdown. Docs-only.
No Totoro. No DRAC.

## 5. Tests of the Tests

N/A — no test file in this PR.

## 6. Consistency Audit

```
rg 'promote|second campaign|se=TRUE|NEWS covered' docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md
rg '14/132|10\\.6%' docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md docs/dev-log/dashboard/status.json
```

Verdict: brief says no promote, no second campaign, no public SE,
no NEWS covered. Overnight number is 14/132 = 10.6% throughout.
#1056 0.0% is labelled as the later M2 evaluator.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row. `MSPL-04` stays `blocked`.

## 7a. GitHub Issue Ledger

- [#1040](https://github.com/itchyshin/gllvmTMB/pull/1040) — cited;
  already MERGED. Official M0 hold-out.
- [#1056](https://github.com/itchyshin/gllvmTMB/pull/1056) — cited;
  already MERGED. Later M2 evaluator / Design 118 discharge.
- [#1020](https://github.com/itchyshin/gllvmTMB/issues/1020) — named
  as DEV-10; does not save G1.
- No new issue. This is a G0 brief, not a defect.

## 8. What Did Not Go Smoothly

Two official-looking hold-out numbers exist (14/132 on M0 vs 0.0%
on M2). Collapsing them would have been the easy mistake. The brief
keeps them in one table and treats #1040 as the overnight-track gate.

The #1056 verdict file is referenced from Design 118 but is not on
`origin/main`. Left there; not copied.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Ada:** 05:00 default is park; do not authorise a new programme
  from a failed gate.
- **Fisher:** G1 10.6% and G2 0.0218 are the load-bearing numbers;
  \(n\to 2000\) is arithmetically dead.
- **Rose:** do not let #1056's 0.0% overwrite #1040's 10.6% in the
  dashboard card.

## 10. Known Limitations And Next Actions

Brief is UNSIGNED. Next action is Shinichi's paste (park /
redesign / new construction / leave unsigned). No campaign until
that paste. If park: append SIGNED and update vault D-155.
