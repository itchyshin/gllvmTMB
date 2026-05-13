# After-Task: inst/COPYRIGHTS stale engine path

## Goal

Fix a one-line stale reference in `inst/COPYRIGHTS`. The file's
opening paragraph (line 6) described "the multi-trait engine in
`inst/tmb/gllvmTMB_multi.cpp`" -- the path the engine had before
the 2026-05-10 move to `src/gllvmTMB.cpp`. The same file already
references the correct path `src/gllvmTMB.cpp` later (line 40-42);
only the opening summary was stale.

Found during the cross-package coherence sweep on the overnight
autonomous run (2026-05-12 18:00 MT). After-task report at branch
start per `CONTRIBUTING.md`.

## Implemented

- **`inst/COPYRIGHTS`** (M, one-line fix): "the multi-trait engine
  in `inst/tmb/gllvmTMB_multi.cpp`" -> "the multi-trait engine in
  `src/gllvmTMB.cpp`". The file's later mention of
  `src/gllvmTMB.cpp` (line 40) was already correct.
- **`docs/dev-log/after-task/2026-05-12-copyrights-stale-path.md`**
  (NEW, this file).

The PR does NOT:
- Touch any other line of `inst/COPYRIGHTS`. The body of the file
  (the sdmTMB inheritance description, the upstream copyright
  holder lists, the VAST transitive attribution) is correct.
- Touch `NEWS.md`. PR #52's CRAN-reviewer rewrite (in flight)
  drops the stale path reference there as part of its own
  refactor.
- Touch `docs/dev-log/decisions.md` or
  `docs/dev-log/after-task/2026-05-10-bootstrap-and-ci-hardening.md`.
  Those mention `inst/tmb/` correctly as a historical record of
  the move; they are NOT stale.
- Touch `tests/testthat/test-lme4-style-weights.R` comment that
  references `inst/tmb/gllvmTMB_multi.cpp` -- that comment is
  documenting historical engine behaviour and is not user-facing
  prose. Out of scope for this PR.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. One line
of `inst/COPYRIGHTS` updated to match the actual engine path.

## Files Changed

- `inst/COPYRIGHTS` (M, one line)
- `docs/dev-log/after-task/2026-05-12-copyrights-stale-path.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 2 open Claude PRs (#52 NEWS rewrite,
  #53 phylo article) + 1 Codex PR (#51 ordinal-probit). None
  touch `inst/COPYRIGHTS`. Safe.
- File-existence verification: `ls src/` shows `gllvmTMB.cpp` is
  the actual engine file at the path the corrected line now
  references; `ls inst/tmb/` returns "No such file or directory".
  The fix matches the on-disk reality.
- Cross-doc consistency: README.md, AGENTS.md, and
  `inst/COPYRIGHTS` line 40-42 all agree on `src/gllvmTMB.cpp`.
  PR #52's NEWS rewrite (in flight) also uses
  `src/gllvmTMB.cpp` as the canonical path.

## Tests Of The Tests

This is a one-line documentation fix. The "test" is whether
the path in `inst/COPYRIGHTS` line 6 matches the actual location
of the compiled engine. After this fix, both the opening
description (line 6) and the dedicated "TMB engine" section
(line 40-42) name the same path.

If a future engine move happens (e.g. to `src/gllvmTMB/` for a
multi-file C++ tree), both lines need updating in the same PR.

## Consistency Audit

```sh
rg -n 'src/gllvmTMB|inst/tmb' inst/COPYRIGHTS
```

verdict: both lines now name `src/gllvmTMB.cpp`. No stale path
remains in the active description.

```sh
rg -n 'inst/tmb' inst/ docs/ AGENTS.md CLAUDE.md README.md \
   CONTRIBUTING.md NEWS.md DESCRIPTION
```

verdict: remaining hits are in historical-record contexts
(`docs/dev-log/decisions.md` recording the move,
`docs/dev-log/after-task/2026-05-10-*.md` recording the
bootstrap, `tests/testthat/test-lme4-style-weights.R` comment
about historical engine behaviour). All correct as historical
references, not as current-path claims.

NEWS.md will lose its remaining `inst/tmb` reference when PR
#52 (CRAN-reviewer rewrite) merges; the current line ("renamed
from the legacy runtime-compiled `inst/tmb/gllvmTMB_multi.cpp`")
goes away in that rewrite's "Source-tree notes" section.

## What Did Not Go Smoothly

Nothing. The fix was a one-line search-and-replace caught by a
deliberate cross-package consistency sweep. The sweep itself
took longer than the fix (about 15 minutes vs 1 minute).

The sweep also surfaced one design observation worth recording
but not actionable here: `CLAUDE.md` and `AGENTS.md` mention the
TMB-family sister packages (`drmTMB`, `glmmTMB`, `sdmTMB`) but
not `gllvm` (the original GLLVM package) or the Bayesian
alternatives (`MCMCglmm`, `brms`). The broader scope record
lives in `docs/design/04-sister-package-scope.md`. Adding a
"see also" pointer from `CLAUDE.md` / `AGENTS.md` to design
doc 04 would help future agents discover it, but that is a
separate housekeeping item and is not bundled here.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Rose (cross-file consistency)** -- this is exactly Rose's
  lane: a one-line stale path in a durable attribution file
  that drifted from the engine-move PR (2026-05-10).
- **Pat (applied user)** -- a CRAN reviewer reading
  `inst/COPYRIGHTS` to check the attribution structure would
  not have found `inst/tmb/gllvmTMB_multi.cpp` and might have
  flagged it as a documentation bug.

## Known Limitations

- The `tests/testthat/test-lme4-style-weights.R` line-5 comment
  also mentions `inst/tmb/gllvmTMB_multi.cpp`. That comment is
  documenting historical engine behaviour
  ("(inst/tmb/gllvmTMB_multi.cpp) historically only honoured
  `weights = `"). A future test sweep can decide whether to
  update the comment to the current path, but it is not a
  user-facing prose claim and is out of scope here.
- The "see also design doc 04" pointer for `CLAUDE.md` /
  `AGENTS.md` is noted in the "What Did Not Go Smoothly"
  section as a separate housekeeping item.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: one-line
   prose fix to a licensing / attribution file, no source / API
   / NAMESPACE change.
2. After merge, the cross-package coherence sweep is complete
   for the `inst/tmb -> src/` rename.
3. Optional follow-up (not in this PR): a tiny `CLAUDE.md` /
   `AGENTS.md` polish adding "see also
   `docs/design/04-sister-package-scope.md`" to the existing
   sister-packages mentions, so future agents discover the
   broader scope record.
