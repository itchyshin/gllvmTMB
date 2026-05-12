# After-Task: Phase 4 test-classification audit (read-only prep)

## Goal

Produce the per-file classification of `tests/testthat/`
(76 files, 11585 lines) that Codex's eventual Phase 4 gating PR
will need. The audit categorises each test file into smoke /
diagnostic / recovery / identifiability / integration buckets and
recommends a `RUN_SLOW_TESTS` gate so PR-time CI stays fast.

This audit is Claude-lane prep, not implementation. The gates
themselves (per-`test_that()` `skip_if` calls + the
`R-CMD-check.yaml` env condition) are Codex's Phase 4 PR.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/shannon-audits/2026-05-12-phase4-test-classification.md`**
  (NEW). Sections:
  - Methodology (file-name patterns + spot-checks)
  - Per-file classification (5 buckets + out-of-scope)
  - Summary by bucket (39 always-run + 30 slow-gated + 7 no-fit)
  - Recommended `RUN_SLOW_TESTS` mechanism (per-file vs per-`test_that()`)
  - CI workflow integration (set env only on main pushes /
    workflow_dispatch)
  - Verification protocol for Codex's Phase 4 PR
- **`docs/dev-log/after-task/2026-05-12-phase4-test-classification.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two new
markdown files under `docs/dev-log/`.

## Files Changed

- `docs/dev-log/shannon-audits/2026-05-12-phase4-test-classification.md`
  (new)
- `docs/dev-log/after-task/2026-05-12-phase4-test-classification.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 0 open PRs at branch start (PR #39 merged
  15:50 MT). No Codex push pending. Safe.
- File enumeration:
  ```sh
  ls tests/testthat/*.R | wc -l
  ```
  -> 76 test files.
- Size profile:
  ```sh
  for f in tests/testthat/*.R; do wc -l "$f"; done | sort -n -r | head
  ```
  -> largest is `test-canonical-keywords.R` (602 lines, but pure
  formula-grammar smoke); largest *recovery* test is
  `test-spatial-latent-recovery.R` (175 lines, multiple fits).
- Per-file categorisation: file-name patterns + spot-check of
  first 30 lines for ambiguous cases.

## Tests Of The Tests

The audit's classification is a hypothesis: "these 39 files are
fast, these 30 files are slow." The hypothesis is verifiable
when Codex implements the gates and runs:

```sh
unset RUN_SLOW_TESTS
time Rscript -e 'devtools::test()'   # should be the fast suite
```

vs

```sh
export RUN_SLOW_TESTS=1
time Rscript -e 'devtools::test()'   # should be the full suite
```

If a file was miscategorised (e.g. a "smoke" file actually has a
recovery test inside), the gate either fires when it shouldn't or
doesn't fire when it should. Boole + Curie review the
misclassifications during Phase 4 PR.

The conservative miscategorisation is "smoke when it should be
recovery" -- the slow file then runs in the fast suite,
slowing PRs but not losing coverage. The dangerous
miscategorisation is "recovery when it should be smoke" -- the
fast file then skips on PRs, losing coverage of a fast guard.
The audit leaned conservative (more files into smoke) to make
the latter rare.

## Consistency Audit

```sh
rg -n "skip_if|RUN_SLOW_TESTS|skip_on_ci|skip_on_cran" tests/testthat/
```

verdict: current test suite has NO existing slow-test gates. The
field is empty; this audit's recommendation is to add the first
ones (via Codex's Phase 4 PR).

```sh
rg -n "gllvmTMB\\(" tests/testthat/ | wc -l
```

verdict: ~250+ `gllvmTMB(` fits across the test suite. The cost
profile per category is dominated by which files contain
multiple recovery fits at varied sample sizes.

```sh
ls .github/workflows/
```

verdict: post-PR-#42, two workflows exist (`R-CMD-check.yaml`,
`pkgdown.yaml`). Phase 4's gate edit is one env-conditional
addition to `R-CMD-check.yaml`.

## What Did Not Go Smoothly

Nothing. The audit took ~25 minutes of file-name pattern reading
and one substantive table. The size profile (`wc -l`) was helpful
for catching outliers; the largest file (`test-canonical-keywords.R`,
602 lines) turns out to be all smoke / formula-grammar coverage,
not recovery -- counter-intuitive but correctly classified.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Ada (orchestrator)** -- the audit produces a verifiable
  hypothesis for Codex's Phase 4 PR. Codex tests the hypothesis;
  Boole + Curie review misclassifications.
- **Curie (simulation / testing specialist)** is the lead on
  Phase 4 implementation. Curie's verification is the actual
  test of whether the audit got the buckets right.
- **Grace (CI / pkgdown / CRAN)** owns the `R-CMD-check.yaml`
  edit setting `RUN_SLOW_TESTS` only on main pushes /
  workflow_dispatch.
- **Pat (applied user / contributor)** is the beneficiary of
  the fast PR-time CI -- when an article author opens a PR,
  the fast suite runs in <10 min on Windows instead of the
  current ~35 min Windows pole.

## Known Limitations

- The audit categorises by file name + spot-check, not by
  running the tests. Some files may be misclassified; the
  verification protocol catches this when Codex runs the
  gated and ungated suites.
- The audit does not benchmark individual files. The cost
  estimates in the categories (smoke <30s, recovery 2-10min)
  are rough.
- The audit does not propose `Config/testthat/parallel: true`.
  Parallel testing is a separate Phase 4 sub-task; the gate is
  more important and simpler to implement.
- Phase 4 is not the immediate next dispatch -- per ROADMAP,
  Phase 4 comes after Phase 3 (done) and Phase 1a article
  rewrites continue. The audit is prep, ready when needed; it
  is NOT a dispatch.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: read-only
   audit + after-task in `docs/dev-log/`. No source change.
2. After merge, the audit waits for Phase 4 to be the active
   ROADMAP item. When Codex picks up Phase 4, this audit is
   the implementation guide.
3. Until then, the audit lives in `docs/dev-log/shannon-audits/`
   alongside the other ratified pre-work (PR #37 dispatch queue,
   PR #41 Tier-2 audit).
