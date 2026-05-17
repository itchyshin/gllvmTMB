# After Task: PR-0C.LANDING-PAGE-FIX — execute Pat + Rose audit items 1–8

**Branch**: `agent/phase0c-landing-page-audit`
**PR type tag**: `scope` (README + audit doc; no R/, no NAMESPACE, no machinery change)
**Lead persona**: Pat (reader UX) + Rose (citation discipline)
**Maintained by**: Pat + Rose; reviewers: Ada (close gate)

## 1. Goal

Phase 0C closeout discovered that vision rule #2 (Pat + Rose
review BEFORE edits) was never applied to `README.md`. The
maintainer surfaced two parallel concerns 2026-05-17 morning:

- The `Hadfield A⁻¹` matrix label was confusing (no full
  citation).
- The rendered landing page felt "very crowded and messy".

The audit (filed earlier this PR) surfaced **9 actions** in 5
buckets; the maintainer ratified items 1–8 + flagged item 9
(Covariance keyword grid extraction) for a future small PR.
This commit executes items 1–8 and records the resolution in
the audit doc.

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change.
Pure README + audit-doc edits.

### Item 1 — Hadfield citation FIX (folded into item 5)

The previous label `**Hadfield A⁻¹ phylogenetic + paired
phylo_latent + phylo_unique**` became
`**Phylogenetic covariance: Hadfield & Nakagawa (2010, J. Evol.
Biol. 23: 494–508) sparse $A^{-1}$ + paired phylo_latent +
phylo_unique; phylo_scalar / indep / dep / slope variants**`.
The `A^{-1}` is now math notation; the citation is parenthetical
with full journal + volume + page numbers.

### Items 2 + 3 — Nakagawa 2022 citation FIX

Both occurrences of `(Nakagawa 2022)` (matrix L145 + Deferred
section L337) now read `(Nakagawa et al., *in prep*)`.

The maintainer 2026-05-17 confirmed the source is the
in-preparation methods paper *"A calibrated diagnostic for
misspecified sampling variances in multilevel meta-analysis"*
(Nakagawa et al., dated 2026-05-01; companion code at
`github.com/itchyshin/unifying_model`). The README had the year
wrong (2022 → 2026 in prep).

### Item 4 — REORDER

Status of supported features section demoted from L70 to after
Tiny example. New section flow:

- What can I model now? → Install → Data shapes → Tiny example
  → Status of supported features → Covariance keyword grid →
  Current boundaries.

Implementation kept the original Install → Data shapes → Tiny
example sub-order (the audit's narrower interpretation of
Pat's recommendation: "demote Status, preserve the Install
sub-flow" rather than the broader "Install → Tiny example →
Data shapes → Status" permutation). Lower risk; preserves the
narrative arc Install → "here's how the data looks" → "here's
a fit".

### Items 5 + 6 + 7 — Matrix row FOLDS

Three fold operations on the Status matrix:

- **Item 5**: 2 phylo rows → 1 row. The new row leads with the
  Hadfield & Nakagawa citation, lists all 5 phylo variants
  (`latent + unique` paired + `scalar / indep / dep / slope`),
  and uses split status `stable (paired) / experimental
  (variants)` with register refs `PHY-01..PHY-10`.
- **Item 6**: 2 spatial rows → 1 row. New row covers SPDE mesh
  + 5 `spatial_*` keywords; split status; refs `SPA-01..SPA-07`.
- **Item 7**: 2 extractor rows → 1 row. New row covers all 7
  `extract_*` helpers (Sigma, Omega, correlations, communality,
  repeatability, phylo_signal, residual_split) with split
  status `stable (Gaussian) / experimental (non-Gaussian +
  mixed-family)`; refs `EXT-01..EXT-08`; cites the **M1
  milestone** as the walk path.

Net matrix size: 28 rows → 25 rows. ~3 rows / ~10 visual lines
saved.

### Item 8 — TIGHTEN

`## What can I model now?` trimmed from 35 lines to 11. 5 short
bullets pointing at vignettes + 1 closing paragraph about
preview-version status. The trimmed bullets preserve the 5
primary use-case branches (continuous, binary/count/ordinal,
phylo, spatial, meta-analytic) without inline family detail
(which the Status matrix carries one section below).

### Item 9 — DEFERRED

Covariance keyword grid extraction to its own page flagged in
the audit doc. Not in this PR.

### Audit-doc update

The audit doc records the resolution: each item now has a
`✅ ratified` marker; items 2 + 3 record the maintainer's
2026-05-17 confirmation of the Nakagawa paper reference. The
audit also flags a **future MET-03 follow-up**: the in-prep
paper uses *multiplicative* terminology while
`meta_V(scale = "proportional")` uses "proportional"; the
argument name may need reconciliation when MET-03 lands.

## 3. Files Changed

```
Modified:
  README.md                                       (-50 / +50 net; 3 citations, 3 row folds, 1 reorder, 1 tighten)
  docs/dev-log/audits/2026-05-17-landing-page-audit.md   (resolution markers + future-follow-up section)

Added:
  docs/dev-log/after-task/2026-05-17-phase0c-landing-page-fix.md   (this file)
```

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found.
- Section-heading audit: 12 `^## ` sections (was 12); reorder
  preserves count.
- Citation grep `rg "Nakagawa 20|Hadfield"` on README — all
  three target citations updated; no stale `Hadfield A⁻¹` or
  `Nakagawa 2022` strings remain.
- Status matrix row count: was 28 → now 25 rows.
- 3-OS CI not yet run; this PR touches no R/ source.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- N/A on all three rules. README + audit doc only. No test
  files added.
- The **upgraded `rose-pre-publish-audit` skill** (PR #149,
  checks 12–16) was specifically built to catch the kind of
  regressions this PR fixes. Check 14 (Preview-banner citation)
  is unaffected here (no banners on README). Check 13
  (removed-article cross-reference sweep) clean.

## 6. Consistency Audit

Stale-wording rg sweep on the PR diff:

- `rg "Hadfield A⁻¹" README.md` → 0 hits.
- `rg "Nakagawa 2022" README.md` → 0 hits.
- `rg "Hadfield & Nakagawa" README.md` → 1 hit (the new
  citation; correct).
- `rg "Nakagawa et al" README.md` → 2 hits (the two in-prep
  citations).
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide as primary|meta_known_V as primary"` → 0 hits.

Convention-Change Cascade (AGENTS.md Rule #10): no function ↔
help-file pair change; no `@export` change; no `_pkgdown.yml`
change.

## 7. Roadmap Tick

- No ROADMAP row change. Phase 0C closed last night (PR #148);
  this PR is a Phase 0C closeout follow-up (the landing-page
  audit was not part of the original 6-PR sequence but
  surfaced via maintainer review post-close).
- Validation-debt register: no row status change.

## 8. What Did Not Go Smoothly

- **Vision rule #2 not applied to the README** during Phase 0A
  or Phase 0C. The Pat + Rose audit only ran on vignettes /
  articles + skill files, never on the package's *primary*
  user-facing surface (the landing page). The maintainer's
  2026-05-17 morning surfacing of the Hadfield citation issue
  was the first explicit Pat + Rose review of the README. The
  upgraded `rose-pre-publish-audit` skill (#149) checks 12-16
  do NOT include a "Pat + Rose read the README cold every
  major closeout" check. Should it?
- **Two citation surfaces missed in Rose's initial pass**: the
  Hadfield label was visible only on the rendered pkgdown
  site, not on the raw README markdown grep (until I cross-
  read the matrix row carefully). The audit's manual
  inspection caught it; the skill check did not. Future
  hardening: add a rg pattern for "AuthorSurname [A-Z][a-z]+
  WITHOUT (4-digit year) in same line" to flag author-only
  references.
- **Audit + execute in the same PR**: Phase 0C cleanly
  separated PR-0C.AUDIT-TRIAGE (PR #140) from the execution
  PRs (#143-#147). This PR folds both into one, which is
  faster but breaks the maintainer-stop-checkpoint discipline
  between artefact (audit table) and action (edits). The
  shape works for this PR because the audit table was filed
  on the same branch as a separate commit, and the maintainer
  ratified inline before edits. But the precedent should not
  apply to larger audits.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Pat** (lead, reader UX): the audit's "Pat bounces after 30
sec" framing was concrete: 28-row matrix dominates the
viewport before the worked example. The 4 edits this PR
delivers (tighten + reorder + 3 row folds) cut the page's
crowding by ~40 % while preserving every essential claim.
Future landing-page work should treat the matrix as a
*reference appendix*, not the lede.

**Rose** (lead, citation discipline): the Hadfield A⁻¹ label
was the canonical "author surname masquerading as a math
symbol" regression. The new format (math symbol + parenthetical
full citation) is the discipline for any future foundational-
work citation in user-facing surfaces. The MET-03 follow-up
flagged in the audit doc (multiplicative vs proportional naming
question) is exactly the kind of forward-looking discipline
this audit's job is to surface.

**Ada** (orchestration): post-Phase-0C-close audit. The pattern
"close phase → run audit → fix" is healthy *if* the audit is
narrow (this one was: 9 items, 5 buckets, 35-min fix). For
larger audits (Phase 0C article triage at 24 rows), the audit
+ fix should still be separate PRs.

## 10. Known Limitations and Next Actions

- **M1.1 dispatch** is next (per Day-1 plan
  `docs/dev-log/audits/2026-05-17-day1-plan.md`): per-extractor
  mixed-family audit (Boole + Emmy lead).
- **Future PR — Covariance keyword grid extraction (item 9)**:
  small PR moving the 3 × 5 grid to its own short page
  `articles/formula-syntax.html` OR to the bottom of the README
  under a Reference sub-section. Not blocking M1.
- **Future PR — MET-03 design**: the multiplicative vs
  proportional terminology reconciliation. Flag added to the
  audit doc; lands when MET-03 (`meta_V(scale = ...)` walk to
  validated machinery) becomes scheduled work.
- **rose-pre-publish-audit skill hardening**: consider adding
  a "author-surname-without-year regex" check (§8). Deferred
  to next skill upgrade cycle.
