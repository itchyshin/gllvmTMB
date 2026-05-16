# After Task: PR-0C.ROADMAP — insert M1 / M2 / M3 milestone sections + update phases-at-a-glance + recent merges

**Branch**: `agent/phase0c-roadmap`
**PR type tag**: `scope` (ROADMAP.md update; no R/, no NAMESPACE, no machinery change)
**Lead persona**: Ada (orchestrator) with Boole / Pat / Fisher per slice owner roles named inline
**Maintained by**: Ada + Rose; reviewers: Pat (reader-path framing), Boole (M1 slice contracts), Fisher (M3 slice contracts), Ada (close gate)

## 1. Goal

Fifth of six planned Phase 0C execution PRs
(PULL ✅ → TRIM ✅ → PREVIEW ✅ → REWRITE-PREP ✅ →
**ROADMAP** → COVERAGE).

Replace the article-port-centric Phase 1c plan in `ROADMAP.md`
with the function-first **M1 / M2 / M3 milestone sequence**
ratified in `decisions.md` item 9 (2026-05-16). Per maintainer
2026-05-16 directive *"Next 3 milestones only (M1, M2, M3).
Phase 5+ stays as is. Smaller PR, faster ratification"*, this
PR is a **surgical insertion** — adds M1/M2/M3 sections + 3
Phase-0 rows in the at-a-glance table + recent-merges sync;
does NOT rewrite Phase 1c-slope, 1c-viz, 1d, 1e, 1f, 2, 3, 4,
5, 5.5, 6 narratives (which already work).

The drmTMB-style **Goal → Main work → Done when** rhythm is
applied per slice. 25 slices total across M1 (10) + M2 (7) +
M3 (8).

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change. Pure
ROADMAP.md update.

### 4 surgical edits in `ROADMAP.md`

1. **Last-refreshed date** updated to 2026-05-16
   (function-first milestone insertion).
2. **"Phases at a glance" table** — added 6 new rows
   (Phase 0A `Done`, Phase 0B `Done`, Phase 0C `In progress`,
   M1 `Planned`, M2 `Planned`, M3 `Planned`); marked the
   pre-pivot Phase 1c article-port row as
   **Frozen at 7/14 — Superseded 2026-05-15** with a pointer
   to where the remaining work lands in M1.9 / M2.5 / M3.6 /
   Phase 1f.
3. **NEW section** between Phase 1f and Phase 2:
   `## ⚪ Phase 1 milestones -- M1 / M2 / M3 (function-first
   machinery completeness)`. Intro paragraph explaining the
   pivot + 3 sub-sections (M1 / M2 / M3) + per-slice tables in
   drmTMB rhythm + Cross-refs block.
4. **Recent merges** prepended with 12 new entries for
   PRs #132 (Phase 0A) → #146 (PR-0C.REWRITE-PREP), in
   newest-first order. The 12 entries are the entire post-
   2026-05-15 closed sequence (function-first pivot through
   today's PR-0C work).

### Milestone-slice content

Each of M1.1–M1.10, M2.1–M2.7, M3.1–M3.8 has:

- A **Goal** (the slice's specific deliverable, one sentence).
- A **Lead** persona (Boole / Fisher / Pat / Curie / Emmy /
  Darwin / Ada — matching the validation-debt-register
  row-ownership pattern).
- A **Done when** condition citing the validation-debt
  register row that the slice walks to `covered` (where
  applicable).

Per-milestone **scope-boundary statements** named explicitly:

- M1 boundary: profile CIs on derived quantities for
  mixed-family are M3 work, not M1.
- M2 boundary: Gaussian + binary are end-to-end-validated
  after M2; other families remain `partial` until post-CRAN.
- M3 boundary: empirical coverage on simulated data ≠
  cross-package agreement on real fixtures (= M5.5).

Banner-removal pointers per slice tell the future maintainer
which Preview banners (added in PR-0C.PREVIEW + PR-0C.REWRITE-
PREP) come off at each milestone close: `lambda-constraint` +
`ordinal-probit` at M2.7; `psychometrics-irt` at M2.5;
`covariance-correlation` at M1.9; `profile-likelihood-ci` +
`functional-biogeography` at M3.8; `choose-your-model` at
Phase 1f.

## 3. Files Changed

```
Modified:
  ROADMAP.md   (4 edits: date + 3 table rows + new section + recent merges)
               (~ 132 lines added; 981 → 1113 line count)

Added:
  docs/dev-log/after-task/2026-05-16-phase0c-roadmap.md   (this file)
```

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found.
- Section-heading audit: 22 `^## ` + 47 `^### ` sections; the
  new M1 / M2 / M3 sub-sections render cleanly in the section
  index.
- Roadmap article wrapper (`vignettes/articles/roadmap.Rmd`,
  knitr `child` include of `ROADMAP.md`) re-renders unchanged
  in structure; pkgdown picks up the new content automatically.
- Recent-merges PR numbers cross-checked against
  `git log --oneline` and `gh pr list --state merged`.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- N/A on all three rules. ROADMAP.md update; no machinery
  change; no new tests. The M1 / M2 / M3 close PRs at their
  respective milestones will each exercise the 3-rule contract
  in full.

## 6. Consistency Audit

Stale-wording rg sweep on the PR diff:

- `rg "claimed" ROADMAP.md` — only references are to
  "ZERO `claimed` rows" (the Phase 0B close gate description).
  No surviving overpromise framing.
- `rg "Phase 1c article" ROADMAP.md` — the pre-pivot article
  port row is now marked "Frozen at 7/14 — Superseded"; no
  bare "Phase 1c article ports continues" claim.
- Per-milestone scope-boundary statements present (3/3 —
  M1, M2, M3).

Convention-Change Cascade (AGENTS.md Rule #10): ROADMAP update
only; no function ↔ help-file pair affected; no `@export`
change; no `_pkgdown.yml` change. The roadmap article wrapper
(`vignettes/articles/roadmap.Rmd`) auto-renders the new content
via its `child` include; no edit needed there.

## 7. Roadmap Tick

- This PR **is** the roadmap tick. ROADMAP.md Phase 0C row
  updated from `███░░░ 3/6` to `████░░ 4/6` (after this PR
  merges) and to `█████░ 5/6` after PR-0C.COVERAGE.
- Validation-debt register: no status change; the M1 / M2 / M3
  slice rows in the new ROADMAP section name which
  register-row IDs each slice walks to `covered`. The register
  itself remains the source of truth.

## 8. What Did Not Go Smoothly

- **Initial scope question** on whether the rewrite should
  include Phase 0A / 0B / 0C narrative sections (not just
  table rows) or just M1 / M2 / M3. Maintainer's
  `"smaller PR, faster ratification"` directive resolved
  it: include Phase 0A / 0B / 0C as table rows only;
  detailed narrative lives in after-task reports + decisions
  log, not the roadmap. The pre-pivot Phase 1c article-port
  section stays for historical record but is explicitly
  marked Superseded.
- **Line count grew net + 132** rather than shrinking. This
  is consistent with "smaller PR" (small in surgical scope:
  4 edits, no rewrites of existing sections) but the
  resulting document is longer. The growth is concentrated
  in M1 / M2 / M3 slice content, which is forward-looking
  material that did not previously exist on the roadmap.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** (lead, orchestrator): the M1 / M2 / M3 slice contracts
are the orchestration spine for the next ~ 7 weeks of work.
Each slice has a named lead, a specific deliverable, and a
register-row hook. This means the M1 / M2 / M3 close PRs cannot
silently drift from the milestone definition — the slices are
public, named, and tied to validation-debt-register rows that
will tick to `covered`.

**Boole** (formula / API; lead on M1 + M2 slice contracts):
the slice-level granularity matches what the next
implementation PRs need to consume. M1.3, M1.4, M1.5, M1.6
each name the specific extractor + fixture combo to test.
M2.3 explicitly names the `n_items × d` regime grid for
LAM-03 walk. This prevents the M1 / M2 implementer from
under-scoping a slice into "I'll just add a smoke test"
without the rigour the milestone needs.

**Fisher** (inference framing; lead on M3 slice contracts):
the M3 slice contracts pin the ≥ 94 % per-family empirical
coverage gate to a specific `coverage_study()` deliverable
(M3.3), with `dev/precompute-vignettes.R` as the reproducible
pipeline (M3.2). The M3 scope-boundary statement makes the
M3 / M5.5 distinction unambiguous: M3 is simulated-data
coverage; M5.5 is real-fixture cross-package agreement.

**Pat** (reader UX): the at-a-glance table is the main thing
users read. The 6 new rows (Phase 0A / 0B / 0C + M1 / M2 / M3)
make the function-first pivot visible to a casual reader.
The "Superseded 2026-05-15" annotation on the pre-pivot
Phase 1c row tells a returning reader why the article-port
plan changed shape.

**Rose** (audit / pre-publish): every slice's "Done when"
condition cites a specific deliverable that can be checked
against the validation-debt register. The roadmap is no
longer self-citing; every forward claim has a register-row
hook.

**Curie** (testing): slice naming convention (M1.1, M1.2, ...,
M3.8) gives the test files at M1 / M2 / M3 close PRs a clear
naming convention (e.g. `tests/testthat/test-m1-3-extract-sigma-mixed-family.R`).
The slice → test-file mapping prevents test-file proliferation
without a milestone hook.

## 10. Known Limitations and Next Actions

- **PR-0C.COVERAGE** is next — the sixth and final Phase 0C
  PR. Phase 1b empirical coverage artefact (R = 200 grid +
  cached RDS at `dev/precomputed/coverage-grid.rds`).
  After PR-0C.COVERAGE merges, Phase 0C closes and M1 begins.
- **The 25 milestone slices** (M1.1 – M3.8) are now publicly
  named on the roadmap. The M1 → M2 → M3 close PRs each
  exercise their 7–10 slices as the implementation PRs land;
  each slice's after-task report ticks the corresponding row.
- **rose-pre-publish-audit skill upgrade**: now should add a
  "every roadmap slice 'Done when' condition cites a specific
  deliverable (test file, audit doc, register-row walk)"
  check. Deferred to Phase 0C closeout.
