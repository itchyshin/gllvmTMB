---
name: after-task-audit
description: Audit a completed gllvmTMB task or phase before closing it, checking implementation, equations, examples, tests, docs, pkgdown, roadmap, NEWS, known limitations, stale wording, and after-task reporting. Includes the 2026-05-10 anti-patterns (success-complacency, coverage-of-acceptance, drmTMB-benchmark).
---

# After-Task Audit

Use this skill before treating a meaningful `gllvmTMB` task or phase as
complete. It is Rose's forest-and-trees checklist: make sure the
repository tells one coherent story after code changes.

## Required Audit

1. State the implemented claim in one sentence.
2. Check code paths that implement the claim.
3. Check symbolic equations and R syntax describe the same model. Use
   the symbolic-math <-> implementation alignment table from the
   `add-simulation-test` skill.
4. Check examples and vignettes use supported syntax.
5. Check tests exercise the intended behaviour and at least one
   failure path.
6. Run targeted tests for touched behaviour.
7. Run broader package checks when practical:
   - `devtools::test()`
   - `devtools::document()` if roxygen changed
   - `pkgdown::check_pkgdown()`
   - `pkgdown::build_articles(lazy = FALSE)` for any change that
     touches user-formula parsing (otherwise unit tests can pass while
     articles silently break)
   - `devtools::check()`
8. Search for stale wording across docs and generated site.
9. For prose-heavy tasks, apply the `prose-style-review` skill before
   closing. Check reader fit, concrete claims, stable terminology,
   citations or local evidence, error recoverability, and
   over-bulleted prose.
10. For family, formula-grammar, diagnostic, or implemented-scope
    changes, check the status inventory explicitly: `README.md`
    current status, `ROADMAP.md`, `NEWS.md`,
    `docs/dev-log/known-limitations.md`, the relevant design docs in
    `docs/design/`, and `_pkgdown.yml` when navigation should change.
    Record the exact `rg` patterns used; do not write only
    "stale-wording scans".
11. Update roadmap, NEWS, known limitations, and design docs when
    behaviour changed.
12. Add a compact after-task report under `docs/dev-log/after-task/`.

## Stale-Wording Searches

Use task-specific searches. Common `gllvmTMB` patterns:

```sh
rg "Sigma_B|Sigma_W|Lambda_B|Lambda_W|latent\\(|unique\\(|indep\\(|dep\\(" README.md ROADMAP.md docs vignettes R tests
rg "phylo_latent|phylo_unique|spatial_latent|spatial_unique" README.md ROADMAP.md docs vignettes R tests
rg "full.*rejected|only diagonal|planned.*implemented|deprecated.*0\\.1" README.md ROADMAP.md NEWS.md docs vignettes
```

Generated pkgdown pages can also contain stale text after a site build:

```sh
rg "full.*rejected|only diagonal|planned.*implemented" docs
```

Do not mechanically delete historical after-task notes. If an old note
was true when written, leave it; add the new after-task report to
supersede it.

## Tests Of The Tests

For new tests, verify at least one of the following:

- the new test failed before the fix;
- the test compares the likelihood to an independent calculation;
- the test checks a boundary, malformed input, or missing-data path;
- the test combines the new feature with an already-supported
  neighbouring feature.

## Anti-patterns from 2026-05-10 (do not re-derive)

These were learned the hard way during the gllvmTMB push-cancel-cascade
session of 2026-05-10. They live here as a checklist so the same
lesson doesn't have to be re-learned.

### Success-complacency

**A streak of successes is the most dangerous moment to skip the
pre-mortem.** After each successful agent dispatch lands clean,
momentum makes the *next* push feel routine. The verification
checklist starts feeling optional. Exactly when complacency is
highest is when the next failure ships.

The 2026-05-10 evidence: 11 successful agent dispatches -> "this team
is great" -> started running `git push` without
`pkgdown::check_pkgdown()` -> Wilkinson's `traits()` shipped with a new
`@export` not registered in `_pkgdown.yml`. pkgdown #162 went red. The
failure was 30 seconds away from being caught locally.

**The discipline correction:** the more successes I have stacked, the
more carefully I verify the next push, not less. The verification
checklist is cheaper than the trust-loss from one shipped red.

### Coverage-of-acceptance

**When you add a new guard / assert / parser-rejector, unit tests
covering the rejection cases do not substitute for tests covering the
acceptance cases.**

The 2026-05-10 evidence: PR #58's silent-collapse-guard added
`.assert_no_augmented_lhs()` to fail-loud against augmented-LHS
formulas the engine can't yet handle. The agent's tests covered the
rejection cases (intercept+slope, slope-only) thoroughly. They did NOT
cover the acceptance cases that should still pass. The guard
hardcoded the LHS symbol to literal `"trait"`, false-positive aborting
any user with `trait = "outcome"` or `trait = "item"` (two articles in
the wild). pkgdown #167 went RED.

**The discipline correction:** a guard's test plan is incomplete until
it has explicitly enumerated the variations in user input that SHOULD
still pass. "It rejects the bad cases" is half the test. "It still
accepts the cases that were working before" is the other half -- and
the half that catches regressions.

Cross-article render IS the integration test that unit tests cannot
replace. If a guard touches user-formula parsing, render at least one
article that uses a non-canonical pattern (custom `trait_col`, custom
unit name, etc.) before merging.

### drmTMB-benchmark

The maintainer flagged the gap by showing the drmTMB Actions page
side-by-side with gllvmTMB's: 198 runs visible on drmTMB, 100% green;
gllvmTMB had 2 REDs and 4 cancelled runs in a single 24-hour session.

drmTMB's all-green track record is not a code-quality difference. It
is three discipline habits:

1. **No patch-level fix-up commits to main.** Each drmTMB commit is a
   milestone ("Close phylogenetic structured-effect phase", "Improve
   curved-effects tutorial"). A commit titled `_pkgdown.yml: register
   foo() (fix the RED)` does not exist there -- because the RED never
   shipped. Either the verification caught the missing entry locally,
   or it landed inside the original feature commit.
2. **Pushes are spaced 10-30 minutes apart.** No drmTMB run was
   cancelled. Every CI cycle completed and was observed.
3. **Article rendering is verified locally for any parser-touching
   change.** `pkgdown::check_pkgdown()` validates the reference index;
   it does NOT render articles. Two REDs in 24 hours on gllvmTMB were
   both article-rendering failures. Both would have been caught by
   running `pkgdown::build_articles(lazy = FALSE)` locally on the
   affected articles.

**The discipline correction:** match the cadence of the peer who's
all-green. The reason isn't capability -- it's three concrete habits
to apply: each push is a milestone (not a fix-up), spaced wide enough
to let CI complete, and verified by article rendering when the change
touches user-formula parsing.

## After-Task Report Template

```md
# After Task: <Title>

## Goal

## Implemented

## Mathematical Contract

## Files Changed

## Checks Run

## Tests Of The Tests

## Consistency Audit

## What Did Not Go Smoothly

## Team Learning

## Known Limitations

## Next Actions
```

The task is not closed until the report records what passed, what
remains uncertain, which docs/examples were synchronised, what went
wrong or felt clumsy, and which team skill or process should improve
next.
