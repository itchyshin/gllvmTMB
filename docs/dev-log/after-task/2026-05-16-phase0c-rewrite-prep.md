# After Task: PR-0C.REWRITE-PREP — banner + handoff for psychometrics-irt (M2.5) + choose-your-model (Phase 1f)

**Branch**: `agent/phase0c-rewrite-prep`
**PR type tag**: `scope` (article banners + handoff doc; no R/, no NAMESPACE, no machinery change)
**Lead persona**: Pat (rewrite contract author + decision-tree framing)
**Maintained by**: Pat + Rose; reviewers: Boole (`lambda_constraint` requirements), Fisher (CFA / IRT inference framing), Darwin (audience framing), Ada (close gate)

## 1. Goal

Fourth of six planned Phase 0C execution PRs
(PULL ✅ → TRIM ✅ → PREVIEW ✅ → **REWRITE-PREP** → ROADMAP →
COVERAGE).

Two articles are flagged REWRITE-LATE in the Phase 0C triage
(`docs/dev-log/audits/2026-05-16-phase0c-article-triage.md`,
rows #7 and #23):

- `psychometrics-irt.Rmd` — re-authoring in **M2.5** once
  binary IRT machinery (LAM-03) is validated.
- `choose-your-model.Rmd` — re-authoring in **Phase 1f** after
  M1 + M2 + M3 close so each decision-tree branch points at a
  validated worked example.

The discipline is different from PR-0C.PREVIEW. The five
PREVIEW articles have bodies that stand as-is after a banner;
these two articles have bodies that will substantially change
(rewrite) at a future milestone. The deliverable is therefore
two-part: (a) a Preview banner with explicit "slated for
re-authoring in <Mn>" wording, and (b) a rewrite-prep handoff
doc capturing what the future re-author needs to know about
the contract.

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change.

### Banner additions

Same banner shape as PR-0C.PREVIEW (blockquote, single-sentence
headline + 2–3 sentences of context), but with intentionally
different headline wording so a reader can tell at a glance
that the article will be re-authored, not just scope-expanded:

- **5 PR-0C.PREVIEW articles**: *"Preview — `<X>` validation is
  `<Mn>` milestone work."* (Body OK now; scope-expanded later.)
- **2 PR-0C.REWRITE-PREP articles**: *"Preview — slated for
  re-authoring in `<Mn>` once `<X>` is validated."* (Body
  fundamentally changes later.)

`psychometrics-irt.Rmd` banner cites LAM-03 + M2.3 (the binary
IRT validation slice) + M2.5 (the rewrite slice). The
distinction matters: M2.3 validates the machinery,
**M2.5 re-writes the article against that validated machinery**.

`choose-your-model.Rmd` banner cites M1 + M2 + M3 (the three
milestones whose closes change the decision-tree branch
destinations) + Phase 1f (the rewrite slice). Phase 1f is
named explicitly because the existing ROADMAP material lists
choose-your-model-rewrite as the *last* PR of Phase 1.

### Handoff doc

New file `docs/dev-log/audits/2026-05-16-phase0c-rewrite-prep.md`
captures the two rewrite contracts in 5 sections:

1. `psychometrics-irt.Rmd` M2.5 rewrite — what the article
   currently does, why a rewrite (not a trim), 5-point M2.5
   rewrite contract, sequencing dependencies (M1 → M2.3 → M2.5).
2. `choose-your-model.Rmd` Phase 1f rewrite — same shape;
   4-point Phase 1f rewrite contract; sequencing dependencies
   (M1 + M2 + M3 → 1f).
3. Why these two are different from PR-0C.PREVIEW (the banner-
   shape distinction explained above).
4. Cross-references (vision, register, triage, paper notes,
   decisions log).
5. Open questions (none — contracts are concrete).

The handoff doc lives under `docs/dev-log/audits/` alongside
the article triage and Nakagawa paper-findings notes (the
2026-05-16 Phase 0C audit family).

## 3. Files Changed

```
Modified:
  vignettes/articles/psychometrics-irt.Rmd       (+11 lines, banner)
  vignettes/articles/choose-your-model.Rmd       (+12 lines, banner)

Added:
  docs/dev-log/audits/2026-05-16-phase0c-rewrite-prep.md     (handoff)
  docs/dev-log/after-task/2026-05-16-phase0c-rewrite-prep.md (this file)
```

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found.
- Banner-presence audit on both articles: each contains exactly
  one `Preview — slated for re-authoring` blockquote.
- Handoff-doc cross-reference audit: links to register, triage,
  paper notes, decisions all valid (verified by file existence).
- 3-OS CI not yet run; this PR touches no R/ source.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- N/A on all three rules. No new tests; no machinery change.
  The handoff doc is a forward-pointing contract that the M2.5
  and Phase 1f closes will fulfil; the close PRs at those
  milestones will exercise the 3-rule contract.

## 6. Consistency Audit

Stale-wording rg sweep on the PR diff:

- `rg "Preview —" vignettes/articles/` — now 7 hits (5 from
  PR-0C.PREVIEW + 2 from this PR). Spot-check confirms 2 distinct
  banner shapes: 5 "`<X>` validation is `<Mn>`" + 2 "slated for
  re-authoring in `<Mn>`".
- `rg "validation-debt register" vignettes/articles/` — 8 hits
  total (1 PR-0C.TRIM joint-sdm M1-pointer + 5 PREVIEW + 2
  REWRITE-PREP). All cite the register file via GitHub absolute
  URL (no fragment anchors).
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|phylo\\(|gr\\(|meta\\(|block_V\\(|phylo_rr\\("` — clean.

Convention-Change Cascade (AGENTS.md Rule #10): banners + handoff
doc only; no function ↔ help-file pair affected; no `@export`
change; no `_pkgdown.yml` change.

## 7. Roadmap Tick

- `ROADMAP.md` Phase 0C "transition cleanup" slice — REWRITE-PREP
  PR (fourth of six).
- Validation-debt register: no status change. The banners + handoff
  doc surface the M2.5 / Phase 1f rewrite contracts; the register
  rows (LAM-03 etc.) keep their existing `partial` / `covered`
  statuses.

## 8. What Did Not Go Smoothly

- **Read-before-Edit gating** on `psychometrics-irt.Rmd` again
  (same lesson as PR-0C.PREVIEW §8 on `ordinal-probit.Rmd`).
  Re-read; edit proceeded. Repeated occurrence reinforces the
  lesson: when working from compacted context, always Read each
  file before Edit, even if the file contents appear in the
  conversation transcript.
- The two banner shapes (PREVIEW vs REWRITE-PREP) needed
  deliberate wording differentiation. Initial draft had both
  shapes saying "Preview — `<X>` is `<Mn>` work" which collapsed
  the distinction. The current "slated for re-authoring in
  `<Mn>` once `<X>` is validated" wording for REWRITE-PREP makes
  the article-fundamentally-changes-later signal explicit.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Pat** (lead, reader UX + rewrite contract author): the two
banner shapes train readers on the meta-distinction. Reader A
("Preview — ordinal-probit validation is M2 work") knows the
article body is correct now and gets scope-expanded after M2.
Reader B ("Preview — slated for re-authoring in M2.5") knows
the article body will be re-thought. The shape difference is
the user-facing version of the engine's REWRITE-LATE vs
PREVIEW-BANNER triage distinction.

**Boole** (formula / API; lead on `lambda_constraint` binary
IRT contract section): the M2.5 rewrite contract is explicit
about which validation rows back which claim. M2.3 validates
LAM-03 (binary IRT recovery); M1 validates MIX-03..MIX-08
(mixed-family extractor rigour); M2.5 ties both into a re-
authored `psychometrics-irt.Rmd` that uses both. The contract
prevents the M2.5 re-author from drifting back into describing
unvalidated machinery.

**Fisher** (CFA / IRT inference framing): the rewrite contract
adds the audit-2 A1 "Stay Laplacian" pedagogy note to the
M2.5 deliverable. Readers coming from `mirt` (AGHQ) should
understand that gllvmTMB's Laplace approximation is the
production inference path; AGHQ for low-d binary IRT is post-
CRAN. The contract also names `mirt::mirt()` as the cross-
package live agreement run — patterned on
`cross-package-validation.Rmd`'s glmmTMB + gllvm comparisons.

**Darwin** (audience framing on `choose-your-model.Rmd`): the
Phase 1f rewrite contract explicitly applies audit-1 R8
"Capability boundary statement" template: every decision-tree
branch terminates with a one-line summary of what the
destination article validates AND what its boundaries are.
Combined with the "branch only to articles whose machinery is
`covered`" rule, this prevents the dead-end-branch problem
that emerged after PR-0C.PULL (Mixed-family branch, Simulation-
recovery branch).

**Rose** (overpromise-removal alignment): the rewrite contracts
double-check that no future M2.5 / Phase 1f author can re-
introduce overpromise without notice. Every claim in the
re-authored articles has to cite a `covered` row in the
validation-debt register at the time of the rewrite PR. The
pre-publish-audit skill (deferred upgrade) will check this
cross-link at re-author time.

**Ada** (orchestration): fourth of six Phase 0C PRs. After this
lands, two PRs remain — **PR-0C.ROADMAP** (rewrite
`ROADMAP.md` from article-port-centric to milestone-centric
M1/M2/M3/M5/M5.5 format) and **PR-0C.COVERAGE** (Phase 1b
empirical coverage artefact — R = 200 grid + cached RDS). The
ROADMAP rewrite is the larger of the two; the COVERAGE artefact
is the engine-validation deliverable that backs M3's R ≥ 200
gate.

## 10. Known Limitations and Next Actions

- **PR-0C.ROADMAP** is next (milestone-format rewrite of
  `ROADMAP.md`).
- **rose-pre-publish-audit skill upgrade**: now needs to add
  the *"every claim in a re-authored article cites a `covered`
  row at the time of the rewrite"* check.
- **Banner-restoration roadmap** for these two REWRITE-PREP
  articles:
  - `psychometrics-irt.Rmd` → banner removed when **M2.5**
    delivers the re-authored article. The original file in
    the diff after M2.5 will look fundamentally different
    (different fixtures, different inference framing, cross-
    package `mirt` comparison).
  - `choose-your-model.Rmd` → banner removed when **Phase 1f**
    delivers the re-authored article (the last PR of Phase 1
    per the existing ROADMAP material).
