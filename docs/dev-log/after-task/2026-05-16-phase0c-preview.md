# After Task: PR-0C.PREVIEW — add Preview banners to 5 articles

**Branch**: `agent/phase0c-preview`
**PR type tag**: `scope` (article banner additions; no R/, no NAMESPACE, no machinery change)
**Lead persona**: Pat (reader UX)
**Maintained by**: Pat + Rose; reviewers: Boole (milestone wording), Fisher (CI / validation framing), Ada (close gate)

## 1. Goal

Third of six planned Phase 0C execution PRs
(PULL ✅ → TRIM ✅ → **PREVIEW** → REWRITE-PREP → ROADMAP →
COVERAGE).

Add a consistent "Preview — <one-line headline>" banner at the
top of each of 5 articles whose body describes machinery whose
validation status in the
[validation-debt register](../../design/35-validation-debt-register.md)
is `partial` (or whose composite-fit identifiability is M3 work,
in the case of `functional-biogeography.Rmd`).

The triage (PR #140, rows #6, #10, #11) flagged 3 banner targets;
the maintainer 2026-05-16 expanded to 5 by adding
`profile-likelihood-ci.Rmd` and `covariance-correlation.Rmd`
("preview banner is quite a good idea") on the grounds that their
Gaussian-validated machinery should ship with an explicit
mixed-family-extension-pending notice rather than reading as
fully production-grade.

## 2. Implemented

**Mathematical Contract**: zero R/ source, NAMESPACE, generated
Rd, family-registry, formula-grammar, or extractor change. Pure
article banner additions; article bodies untouched.

Single banner pattern applied to all 5 articles, inserted right
after the knitr setup chunk and before the first body paragraph:

```markdown
> **Preview — <one-line milestone-frame>.**
>
> <2–3 sentences citing the relevant validation-debt row + the
> milestone at which the row walks to `covered`.>
```

The 5 banners use one consistent register-row link
(GitHub-absolute URL to the register file; no fragment anchors,
which would break if section headings churn) so cross-link
maintenance is minimal.

### Per-article banner

| Article | Headline | Cited row(s) | Milestone |
|---------|----------|--------------|-----------|
| `functional-biogeography.Rmd` | capstone composite fit is M3 milestone work | individual components `covered`; composite identifiability | **M3** |
| `ordinal-probit.Rmd` | `ordinal_probit` family validation is M2 (Binary completeness) milestone work | FAM-14 `partial` (smoke only) | **M2** |
| `lambda-constraint.Rmd` | Gaussian path validated; binary IRT is M2.3 milestone work | LAM-01 + LAM-02 `covered`; LAM-03 `partial` | **M2.3** |
| `profile-likelihood-ci.Rmd` | Gaussian validated; mixed-family extension is M3 milestone work | CI-02..CI-07 `covered` (Gaussian) | **M3** |
| `covariance-correlation.Rmd` | Gaussian validated; mixed-family `extract_correlations()` is M1 milestone work | EXT-01 + EXT-04 Fisher-z/Wald `covered` | **M1** |

## 3. Files Changed

```
Modified:
  vignettes/articles/functional-biogeography.Rmd   (+10 lines)
  vignettes/articles/ordinal-probit.Rmd            (+9 lines)
  vignettes/articles/lambda-constraint.Rmd         (+10 lines)
  vignettes/articles/profile-likelihood-ci.Rmd     (+9 lines)
  vignettes/articles/covariance-correlation.Rmd    (+9 lines)

Added:
  docs/dev-log/after-task/2026-05-16-phase0c-preview.md   (this file)
```

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found.
- Banner-presence audit on all 5 articles: each contains exactly
  one `Preview —` blockquote in the expected position (after the
  knitr setup chunk).
- 3-OS CI not yet run; this PR touches no R/ source.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- N/A on all three rules. No new tests; no machinery change. The
  banners do not assert any new claim — they downgrade the
  surface description of existing partial / composite machinery
  so reader expectation tracks the validation-debt register.

## 6. Consistency Audit

Stale-wording rg sweep on the PR diff:

- `rg "Preview —" vignettes/articles/` — 5 hits (one per
  banner). All blockquotes consistent in shape and milestone
  framing.
- `rg "validation-debt register" vignettes/articles/` — only
  the 5 new banner references (plus the M1-pointer added in
  PR-0C.TRIM to `joint-sdm.Rmd`). No stale or duplicate
  cross-links.
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|phylo\\(|gr\\(|meta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/`
  — clean (no legacy notation re-introduced by the banner
  additions).

Convention-Change Cascade (AGENTS.md Rule #10): banners add
content only; no function ↔ help-file pair affected; no
`@export` change; no NAMESPACE diff; no `_pkgdown.yml` change.

## 7. Roadmap Tick

- `ROADMAP.md` Phase 0C "transition cleanup" slice — PREVIEW PR
  (third of six).
- Validation-debt register: no status change; the cited rows
  remain `partial` / `covered (Gaussian) / partial (mixed-family)`
  / `covered (components) / M3 (composite)`. The banners simply
  surface these statuses to readers.

## 8. What Did Not Go Smoothly

- **One Edit blocked by "File has not been read yet"** on
  `ordinal-probit.Rmd`. The session-summary context contained
  the file's opening from earlier reads, but the harness tracks
  reads per tool-instance and required a fresh Read. Added the
  Read; edit proceeded. Lesson: when working from compacted
  context, expect to re-Read files before Edit even if the file
  contents are visible in the conversation.
- No content / scope issues surfaced. The banner pattern was
  designed once and applied 5 times with no per-article rework.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Pat** (lead, applied PhD user): the banner pattern reads as a
single sentence at a glance ("Preview — <X> is <Mn> milestone
work") with 2–3 sentences of register-citation context for
readers who want detail. The consistent shape across all 5
articles trains readers: as soon as they see "Preview —" they
know the article describes machinery in a known partial state,
with a specific milestone at which it walks to `covered`.

**Rose** (audit / pre-publish): the banner pattern enforces the
function-first discipline at the reader-facing surface. Every
banner cites a specific register row + milestone, so the
banner cannot drift away from the register's status without a
mismatch being detectable by grep. The
`rose-pre-publish-audit` skill upgrade (deferred to Phase 0C
closeout) should add a check: *"every `Preview —` banner cites
at least one register row ID + a milestone (M1 / M2 / M3 / M5.5
/ post-CRAN)."*

**Boole** (formula / API): no formula or API surface affected.
The banners do not change any user-facing call surface; only
the reading-frame around the surface.

**Fisher** (inference framing): the
`profile-likelihood-ci.Rmd` banner is a careful framing — the
Gaussian validation is real (CI-02..CI-07 `covered`) and the
profile / Wald / bootstrap surface is the package's inference
differentiator. The banner narrows the claim to "Gaussian
validated" so the inference-completeness story does not over-
extrapolate to mixed-family before M3 closes.

**Ada** (orchestration): third of six Phase 0C PRs. After this
lands, next is **PR-0C.REWRITE-PREP** — handoff notes for the
two articles flagged as REWRITE-LATE in the triage
(`psychometrics-irt.Rmd` to be re-written in M2.5;
`choose-your-model.Rmd` to be re-written in Phase 1f). The
handoff notes are smaller than full article ports — they just
document what gets re-written and why, so the future M2.5 / 1f
work has a clear contract to fulfil.

## 10. Known Limitations and Next Actions

- **PR-0C.REWRITE-PREP** is next.
- **rose-pre-publish-audit skill upgrade**: now needs to add
  the banner-citation check (§9 Rose paragraph).
- **Banner restoration roadmap** (when each banner can be
  removed and the article fully promoted):
  - `functional-biogeography.Rmd` → after **M3** close
    (capstone fit identifiability gate).
  - `ordinal-probit.Rmd` → after **M2** close (FAM-14 walks
    to `covered`).
  - `lambda-constraint.Rmd` → after **M2.3** close (LAM-03
    walks to `covered`).
  - `profile-likelihood-ci.Rmd` → after **M3** close (CI
    extension to mixed-family).
  - `covariance-correlation.Rmd` → after **M1** close (EXT-04
    mixed-family path walks to `covered`).
