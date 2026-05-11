# After-Task: Enrich `10-after-task-protocol.md` with drmTMB patterns

## Goal

Enrich `docs/design/10-after-task-protocol.md` so the bar for an
after-task report matches the standard set by the `drmTMB` team's
`2026-05-11-mu-sigma-mean-scale-covariance.md` report, which the
maintainer flagged as a model to learn from. Five patterns from
that report -- mathematical contract with equations, tests-of-the-
tests naming a specific catch, consistency audit with classified
`rg` output, team learning by standing-review role, and breadth-
aware files-changed -- are codified inline in the existing
protocol sections (integrate-before-adding) so Codex and Claude
both raise the bar together.

After-task report added at branch start per the new
`CONTRIBUTING.md` rule.

## Implemented

- `docs/design/10-after-task-protocol.md` (M): four edits.
  - Added a new `## Mathematical Contract` section after
    `## Required Sections`. drmTMB pattern: when a PR touches
    parameterisation, the contract section should write the model
    equations (`mu_i = X_mu beta_mu + b_g`), the parameter
    transform (`rho = 0.999999 * tanh(eta)`), and explicitly state
    what the change is NOT.
  - Enriched the existing `## Consistency Audit` section with the
    classified-output pattern: every `rg` invocation should be
    paired with a one-line verdict ("found only intentional
    boundaries for X, Y, Z").
  - Enriched the existing `## Tests of the Tests` section with the
    "name what the test would catch" pattern: link new tests to
    specific bug shapes or manual probes they would have caught.
  - Added a "team learning by role" paragraph: when invoking the
    `AGENTS.md` "Standing Review Roles" framework as a debrief,
    name each role (Ada / Boole / Gauss / Noether / Curie / Pat /
    Darwin / Rose / Grace / Emmy / Fisher / Jason / Shannon) and
    give it a one-line debrief on what it did or would have
    caught.
- `docs/dev-log/after-task/2026-05-11-after-task-protocol-enrich.md`
  (NEW, this file) -- after-task report at branch start.

The patterns are attributed inline to drmTMB's report:
`drmTMB/docs/dev-log/after-task/2026-05-11-mu-sigma-mean-scale-covariance.md`.

## Mathematical Contract

This is a documentation-only protocol enrichment. No public R
API, likelihood, formula grammar, family, NAMESPACE, generated
Rd, vignette, or pkgdown navigation change. The protocol doc
itself prescribes the form of future after-task reports; nothing
in this PR changes the engine.

## Files Changed

- `docs/design/10-after-task-protocol.md`
- `docs/dev-log/after-task/2026-05-11-after-task-protocol-enrich.md`

## Checks Run

- Pre-edit lane check (per `AGENTS.md` rule codified in PR #22):
  one open PR (#23, Phase 3 design doc, scope `docs/design/02-*` +
  `docs/dev-log/decisions.md`; no overlap with this PR's scope on
  `docs/design/10-*`). `git log --all --oneline --since="6 hours
  ago"` showed only the doc-sprint merges and my own PR #23
  commits.
- The five patterns are observable in
  `drmTMB/docs/dev-log/after-task/2026-05-11-mu-sigma-mean-scale-covariance.md`
  (the source report cited inline in the protocol doc).
- The four protocol-doc edits integrate inline (one new section
  for Mathematical Contract; three enrichments to existing
  sections) -- the protocol doc gains roughly 40 lines, not a
  parallel doc tree.

## Tests Of The Tests

The "name what the test would catch" pattern was the most concrete
lesson from drmTMB's report. A worked example, taken from that
report:

> "The corpairs() test ... would have caught the manual probe that
> briefly reported `to_response = 'z'` for the sigma endpoint
> before `random_effect_response_name()` was fixed to use the
> original response for univariate sigma."

This sentence couples a new test to a specific past mistake the
test prevents. Generic coverage prose ("the test exercises X, Y,
Z") does not give the reader the same signal. Codifying this
pattern means future tests-of-the-tests sections must point at
the bug shape, not only the surface area.

## Consistency Audit

Three checks ran before merge:

```sh
rg -n "Mathematical Contract|tests of the tests|team learning" docs/design/10-after-task-protocol.md
```

verdict: each section's anchor exists exactly once in the protocol
doc; no duplicate sections accidentally introduced.

```sh
rg -n "drmTMB" docs/design/10-after-task-protocol.md
```

verdict: attribution lines appear inline where each pattern is
introduced; no attribution is missing.

```sh
rg -n "## " docs/design/10-after-task-protocol.md | sort -u
```

verdict: the doc has one new `## Mathematical Contract` heading; no
heading-level inflation elsewhere.

## What Did Not Go Smoothly

- The protocol doc's "Required Sections" list and the actual
  reports in `docs/dev-log/after-task/` had a small drift: the
  list does not name "Mathematical Contract" or "Team Learning",
  yet several Claude-authored reports already use those section
  headings. The enrichment closes that drift in the prescriptive
  doc rather than retroactively rewriting the existing reports.

## Team Learning

By standing-review role, per the new pattern this PR codifies:

- **Ada (orchestrator)** kept the scope tight: enrich existing
  sections + one new section; do not rewrite the protocol doc
  end-to-end.
- **Rose (cross-file consistency)** verified the protocol doc and
  the actual reports in the after-task directory did not contradict
  each other after the enrichment; the four `rg` checks above are
  the audit footprint.
- **Pat (applied user / new reader)** is the implicit beneficiary:
  the next agent reading the protocol doc gets one place to learn
  the higher bar, not five scattered exemplars.
- **Emmy (R package architecture)** does not engage: no `R/`,
  S3, extractor, or API change.
- **Grace (CI / pkgdown / CRAN)** is not invoked: this PR does not
  trigger any platform or build concern.

drmTMB attribution: the five patterns are lifted from
`drmTMB/docs/dev-log/after-task/2026-05-11-mu-sigma-mean-scale-covariance.md`.

## Known Limitations

- The enrichment prescribes the bar going forward; it does not
  retroactively upgrade the 14 existing after-task reports in
  `docs/dev-log/after-task/`. That is intentional -- the cost of
  rewriting historical reports outweighs the benefit; future
  reports will compound the new standard.
- "Team learning by role" depends on the `AGENTS.md` "Standing
  Review Roles" table being current. If the role list changes,
  the protocol doc will need a one-line update.
- The "Mathematical Contract" section is only relevant for PRs
  that touch likelihood, parameterisation, or formula grammar. For
  doc-only or process-only PRs the section can be a single line
  ("No public R API ... change in this PR") -- the bar should
  scale with what was changed.

## Next Actions

1. Maintainer reviews this enrichment.
2. Self-merge after CI green (low-risk: doc-only, two files,
   protocol doc + after-task report).
3. Codex's next after-task report (probably the morphometrics PR)
   exercises the new pattern; the first practice case becomes the
   reference example for further iterations.
4. After three Codex/Claude reports use the enriched protocol,
   audit whether any further enrichment is needed (or whether some
   patterns should be relaxed for short PRs).
