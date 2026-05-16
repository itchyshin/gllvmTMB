# After Task: Skill upgrade — rose-pre-publish-audit (+5 Phase 0C closeout checks)

**Branch**: `agent/skill-rose-prepublish-audit-upgrade`
**PR type tag**: `skill` (skill-file update; no R/, no NAMESPACE, no machinery change)
**Lead persona**: Rose (skill owner)
**Maintained by**: Rose + Ada; reviewers: Pat (banner-discipline framing), Boole (`@export` ↔ pkgdown parity), Ada (close gate)

## 1. Goal

Add five new checks to `rose-pre-publish-audit/SKILL.md` that
codify the discipline gaps surfaced during the Phase 0C six-PR
sequence (PULL, TRIM, PREVIEW, REWRITE-PREP, ROADMAP, COVERAGE).
Each new check is one PR's worth of lesson; together they
prevent the documented regressions from recurring.

The 5 checks were accumulated across the Phase 0C session:

- (i) PR-0C.PKGDOWN-HOTFIX #142 added `meta_V` to `_pkgdown.yml`
  after PR-0B.4 #139 added the `@export` but missed the index
  → `@export` ↔ pkgdown reference-index parity check.
- (ii) PR-0C.TRIM #144 surfaced an orphan
  `simulation-recovery.html` link in
  `cross-package-validation.Rmd` after PR-0C.PULL #143 moved
  the article → removed-article cross-reference sweep.
- (iii) PR-0C.PREVIEW #145 + PR-0C.REWRITE-PREP #146
  introduced 7 Preview banners with milestone citations →
  Preview-banner citation discipline.
- (iv) PR-0C.REWRITE-PREP #146 filed rewrite contracts for
  `psychometrics-irt.Rmd` (M2.5) and `choose-your-model.Rmd`
  (Phase 1f) → REWRITE-PREP contract verification.
- (v) PR-0C.ROADMAP #147 wrote 25 M1/M2/M3 slices in
  drmTMB-style `Done when` rhythm → ROADMAP slice
  deliverable rule.

Maintainer 2026-05-16 authorised the upgrade overnight (one
PR, no admin-merge; await 5 am review).

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change.
Skill-file edit only.

### 5 new checks (numbered 12–16; appended to existing 11)

- **12. `@export` ↔ `_pkgdown.yml` reference-index parity.**
  Every `@export` in `R/*.R` appears in the reference index
  OR is `@keywords internal`.
- **13. Removed-article cross-reference sweep.** When an
  article moves / renames / is pulled, grep all surviving
  articles for cross-refs to the affected slug.
- **14. Preview-banner citation discipline.** Every
  `> **Preview —` blockquote cites a register row ID + a
  named milestone (M1 / M2 / M2.3 / M2.5 / M3 / M3.3 /
  Phase 1f / M5.5 / post-CRAN). REWRITE-PREP banners
  additionally cite the rewrite-prep handoff doc.
- **15. REWRITE-PREP contract verification.** When a slated-
  for-rewrite article is re-authored, verify (a) every claim
  cites a `covered` row, (b) the rewrite contract from the
  handoff doc is satisfied in full, (c) the banner removal
  follows.
- **16. ROADMAP slice "Done when" deliverable rule.** Every
  M1 / M2 / M3 slice's "Done when" cell cites a specific
  test path / audit doc / register-row walk / fixture /
  vignette path. Vague conditions are `FAIL`.

Each check is one short paragraph in the body + one or two
suggested `rg` patterns in the Suggested Commands block. The
existing 11 checks are unchanged.

### YAML frontmatter `description` updated

The skill's discovery-time description now names the five new
checks so the skill matches user requests that explicitly
reference Phase 0C closeout discipline.

## 3. Files Changed

```
Modified:
  .agents/skills/rose-pre-publish-audit/SKILL.md   (+72 lines: 5 checks + 5 rg blocks + frontmatter)

Added:
  docs/dev-log/after-task/2026-05-16-skill-rose-prepublish-audit-upgrade.md   (this file)
```

## 4. Checks Run

- Skill file renders inline (markdown structure intact;
  numbered list 1–16; Suggested Commands block extended with 5
  new `# Check <N>: ...` headers).
- `pkgdown::check_pkgdown()` not applicable (skill file is not
  in the package source tree).
- 3-OS CI not applicable (no R/ change).

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **Rule 1** (would have failed before fix): each of the 5
  new checks corresponds to a specific Phase 0C regression
  that the pre-upgrade skill did not catch. PR #142 was
  needed precisely because check 12 didn't exist. PR-0C.TRIM
  flagged the orphan link precisely because check 13 didn't
  exist. The 7 PREVIEW + REWRITE-PREP banners shipped without
  a check 14. The two rewrite contracts shipped without a
  check 15. The 25 M1 / M2 / M3 slices shipped without a
  check 16.
- **Rule 2** (boundary): the skill's existing 11 checks were
  primarily about content (notation, scope-boundary). The 5
  new checks are about *structural integrity* (every export
  has a doc; every banner has a citation; every slice has a
  deliverable). The boundary between content and structure
  is the discipline upgrade Phase 0C taught.
- **Rule 3** (feature combination): each new check combines
  the existing register-cross-reference discipline (check 8)
  with a new surface — exports, articles, banners, rewrite
  contracts, ROADMAP slices.

## 6. Consistency Audit

- `rg "Preview —" .agents/skills/rose-pre-publish-audit/SKILL.md`
  — 0 hits (check 14 is described, not exemplified — correct).
- `rg "Phase 0C closeout 2026-05-16" .agents/skills/`
  — 5 hits (one per new check). Audit-trail explicit.
- `rg "FAIL" .agents/skills/rose-pre-publish-audit/SKILL.md`
  — 6 hits (one per check 12–16 + one in the Output legend).
  The new checks all specify what triggers `FAIL` status.

Convention-Change Cascade (AGENTS.md Rule #10): skill-file
update; no function ↔ help-file pair affected; no `@export`
change; no `_pkgdown.yml` change. The skill itself is now
required to verify the cascade.

## 7. Roadmap Tick

- No ROADMAP row changes. The skill upgrade is internal
  tooling, not a user-facing milestone.
- The new check 16 will be exercised against `ROADMAP.md` in
  every future Phase-1 milestone PR.

## 8. What Did Not Go Smoothly

- The skill upgrade was easy to *write* but the regression-
  motivation paragraph for each check required tracing the
  specific Phase 0C PR that surfaced the gap. The mental
  audit took ~20 min — quick because the after-task reports
  from PRs #142, #144, #145, #146, #147 documented each gap
  in §8 ("What Did Not Go Smoothly") at the time.
- One ambiguity surfaced: should the skill check `@export`
  *parity* (every export is in the index) or *consistency*
  (every entry in the index is exported)? The current check
  12 only checks parity (the direction PR #142 was bitten
  by); reverse-direction (orphaned index entries) is a
  separate gap not yet observed in this codebase. Deferred.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Rose** (lead, skill owner): the 5 new checks are the
distilled cost of the Phase 0C six-PR sequence. Each check
encodes a regression the pre-upgrade skill failed to prevent.
Net effect: future PRs that touch articles, banners, exports,
or ROADMAP slices automatically run these checks; the
maintainer's FINAL CHECKPOINT cycle gets shorter because Rose
catches more.

**Pat** (banner discipline framing on check 14): the banner
shape ("Preview — `<X>` is `<Mn>` milestone work" vs "Preview
— slated for re-authoring in `<Mn>`") was deliberately
distinct after PR-0C.PREVIEW + PR-0C.REWRITE-PREP. Check 14
preserves both shapes by requiring a register row + milestone
citation in both — and check 15 specifically catches the
rewrite-shape banners.

**Boole** (`@export` ↔ pkgdown parity on check 12): PR #142
caught the `meta_V` regression because docs-build went red
after PR-0B.4. Without docs-build CI, the regression could
have shipped into a vignette render that 404'd at runtime.
Check 12 closes the loop before the docs build catches it
later.

**Ada** (orchestration): the skill upgrade is the
**structural memory** of Phase 0C. Without it, the next
function-first-cycle sequence (M1 → M2 → M3 close PRs) could
repeat the same regressions. With it, every cross-reference
between articles / register / ROADMAP gets checked before
merge.

## 10. Known Limitations and Next Actions

- **No automated test** for the skill file itself (the skill
  is invoked by Rose; the maintainer or Claude reads the
  checklist and runs the `rg` patterns). M1+ work may
  exercise the skill many times; if a gap shows up, that's a
  new check to add.
- **Future skill upgrades** likely follow the same pattern:
  every multi-PR sequence (M1 close, M2 close, etc.) ends
  with a `skill-rose-prepublish-audit-upgrade` PR adding the
  cycle's distilled lessons.
- **Companion skill `after-task-audit`** may need the same
  treatment (separately) to add post-Phase-0C discipline.
  Deferred until a regression surfaces that the after-task
  audit should have caught.

## Maintainer review checkpoint

Per maintainer 2026-05-16 directive: this PR is **not auto-
merged**. Skill upgrades are reader-facing tooling and the
maintainer should review the 5 new checks for wording + scope
before merge. PR opens; awaits 5 am review.
