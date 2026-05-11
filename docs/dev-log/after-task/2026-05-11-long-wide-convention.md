# After-Task: Long + Wide Example Pairing Convention (PR #11)

## Goal

Lock in a writing-style rule: when demonstrating how to fit a
`gllvmTMB` model in user-facing prose (README, vignettes, Tier-1
articles), show both the long-format and the wide-format call side
by side. Submitted as PR #11 (`agent/long-wide-convention`).

## Implemented

- `AGENTS.md` "Writing Style" gains one bullet that states the rule
  and gives the canonical pair of calls:
  - long (canonical): `gllvmTMB(value ~ ..., data = df_long)`
  - wide (convenience): `gllvmTMB_wide(Y, ...)` or
    `gllvmTMB(traits(...) ~ ..., data = df_wide)`.
  Roxygen `@examples` for individual keyword or extractor functions
  may stay single-form when the keyword is intrinsically one shape
  (for instance, `traits()` is wide-only by construction).
- `docs/dev-log/decisions.md`: new entry "User-facing examples pair
  long + wide" recording the rule and rationale (readers vary in
  mental model -- matrix vs long tibble -- so one example that
  shows both reaches both reader types without forcing a
  translation step).
- `docs/dev-log/check-log.md`: new entry recording the
  documentation-only scope.

## Mathematical Contract

No public R API, likelihood, formula grammar, estimator, family,
NAMESPACE, or generated Rd changed. Documentation rule only.

## Files Changed

- `AGENTS.md` (M -- one new bullet under "Writing Style")
- `docs/dev-log/decisions.md` (M -- one new entry)
- `docs/dev-log/check-log.md` (M -- one new entry)

## Checks Run

None beyond a manual reread of the AGENTS.md bullet. The change is
documentation-only and produces no R code, generated Rd, or pkgdown
navigation that needs verifying.

## Tests Of The Tests

The rule is explicit enough that Codex or any future agent reading
`AGENTS.md` before starting the Priority 2 article-rewrite PR will
recognise the requirement to show both call forms. The rule names
the canonical pair literally, so an agent cannot interpret "show
both" loosely.

## Consistency Audit

- The rule aligns with the active plan's "wide-as-convenience,
  long-as-canonical" framing.
- It aligns with `ROADMAP.md` Phase 1, which now also lists paired
  long + wide examples as the reader-path requirement.
- It does not contradict any existing rule in `AGENTS.md` or
  `CONTRIBUTING.md`.

## What Did Not Go Smoothly

The PR itself shipped cleanly. The gap was process: I did not
write this after-task report at the time of the original PR #11
commit. The maintainer flagged the gap; AGENTS.md and ROADMAP.md
are explicit that every completed task ends with an after-task
report. This file is the corrective entry, written as part of
PR #13 alongside the matching PR #9 retrospective.

## Team Learning

- Writing-style rules belong in `AGENTS.md`, not in the active
  Claude plan or in a transient design note. AGENTS.md is what
  Codex re-reads before each task; rules buried elsewhere drift.
- A rule is only useful if it includes the canonical example
  syntax. "Show both forms" without a literal `gllvmTMB(value ~ ...,
  data = df_long)` versus `gllvmTMB_wide(Y, ...)` pair leaves
  interpretation to the next agent.
- The carve-out for intrinsically-one-shape functions (`traits()`)
  is necessary so the rule does not over-fire on contexts where
  one form is meaningless.

## Known Limitations

- The rule is documentary. Enforcement happens at PR-merge time
  through the Rose pre-publish gate, not at code time. If Rose
  sees a Tier-1 article example that shows only one form, the
  gate should warn or fail. Worth confirming Rose's checklist
  catches this.

## Next Actions

- Merge PR #11 once CI clears.
- The Priority 2 article-rewrite PR is the first application of
  the rule. Whoever picks that up (Claude or Codex) must show both
  long and wide for each fit example in the rewritten articles.
- Re-check `.agents/skills/rose-pre-publish-audit/SKILL.md` against
  this rule to confirm the gate would catch a single-form
  violation in a canonical article context.
