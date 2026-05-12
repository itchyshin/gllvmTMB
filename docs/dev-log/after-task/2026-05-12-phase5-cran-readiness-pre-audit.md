# After-Task: Phase 5 CRAN-readiness pre-audit

## Goal

Produce a read-only inventory of CRAN-relevant surfaces
(DESCRIPTION, inst/CITATION, NAMESPACE / @examples coverage,
URLs, NEWS.md, vignette infrastructure) so the maintainer has
a punch-list when Phase 5 becomes active. The package is many
phases away from submission, but a current snapshot prevents
the "submission week" panic-audit pattern.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/shannon-audits/2026-05-12-phase5-cran-readiness-pre-audit.md`**
  (NEW). Sections:
  - DESCRIPTION metadata verdict: GREEN
  - inst/CITATION verdict: GREEN (PR #26 added it)
  - inst/COPYRIGHTS verdict: GREEN (PR #26 strengthened it)
  - NAMESPACE + @examples coverage: NEEDS WORK -- 22 exports
    without `\examples` Rd blocks (post-S3-method exclusion;
    excluding S3 methods like `print.*`, `summary.*`, `tidy.*`)
  - Generated Rd cleanliness: GREEN (post-PR-#33 spot-check
    protocol)
  - URL inventory: GREEN-with-action (run urlchecker at submit)
  - NEWS.md: NEEDS REVIEW (rewrite top section for CRAN-reviewer
    audience at Phase 5 time)
  - Vignette infrastructure: GREEN
  - Tests at Phase 5: gated by Phase 4 (PR #43)
- **`docs/dev-log/after-task/2026-05-12-phase5-cran-readiness-pre-audit.md`**
  (NEW, this file).

The audit produces a specific list of 22 functions with missing
`\examples`. The list breaks down as:

- ~10 are functions that need a small `\dontrun` example
  (e.g., `latent`, `meta_known_V`, `traits`, `plot_anisotropy`,
  `gllvmTMBcontrol`, `VP`, etc.)
- ~6 are back-compat wrappers / deprecated aliases that should
  be `@keywords internal` (e.g., `extract_ICC_site`,
  `getResidualCov`, `unique_keyword`, `tmbprofile_wrapper`)
- ~4-6 are `profile_ci_*` profile-CI wrappers that share a
  pattern; one `\dontrun` example template would serve all of
  them

Estimate: one bounded Codex PR (~15-20 small `@examples`
additions) at Phase 5 time. Not urgent.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two new
markdown files under `docs/dev-log/`.

## Files Changed

- `docs/dev-log/shannon-audits/2026-05-12-phase5-cran-readiness-pre-audit.md`
  (new)
- `docs/dev-log/after-task/2026-05-12-phase5-cran-readiness-pre-audit.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 1 open PR (#43, Phase 4 audit; disjoint
  scope). Safe.
- `NAMESPACE` enumeration: `grep -c "^export" NAMESPACE` -> 93
  exports.
- `@examples` coverage:
  ```sh
  for f in R/*.R; do
    exp=$(grep -c "^#'\\s*@export" "$f")
    exa=$(grep -c "^#'\\s*@examples" "$f")
    if [ "$exp" -gt "$exa" ]; then
      echo "$f: @export=$exp, @examples=$exa"
    fi
  done
  ```
  -> 15 source files with `@export > @examples`. After
  filtering for S3 methods (`predict.`, `print.`, `summary.`,
  `tidy.`, `simulate.`, `confint.`) that don't need examples,
  the user-facing gap is 22 Rd files.
- `man/*.Rd` cross-check:
  ```sh
  for f in man/*.Rd; do
    if ! grep -q "^\\\\examples" "$f"; then echo "$f"; fi
  done
  ```
  Filtered to non-S3-method aliases.
- URL inventory:
  ```sh
  grep -hE "https?://" R/*.R DESCRIPTION | \
    grep -oE "https?://[^ )\",']+" | sort -u
  ```
  -> 12 distinct URLs. All look legitimate; the Stack Exchange
  and other-author GitHub URLs are most likely to rot at
  submission time and should be `urlchecker::url_check()`-ed.

## Tests Of The Tests

This is an inventory audit. The "tests" of the audit are:

- The 22-Rd-missing-`\examples` list is verifiable by running
  the same `grep` loop at any time.
- The DESCRIPTION-field verdicts are verifiable by reading
  DESCRIPTION.
- The URL list is verifiable by re-running the URL grep.

If the audit miscategorised one (e.g., listed a function as
"add `\dontrun`" when it's actually a deprecated alias that
should be `@keywords internal`), the Phase 5 Codex PR catches
it during the example-adding pass.

## Consistency Audit

```sh
rg -n "S3method|@keywords internal" R/methods-gllvmTMB.R
```

verdict: S3 methods are registered via `@export` plus
`S3method()` in NAMESPACE; they don't typically need `@examples`
(CRAN tolerates this for methods that wrap a user-facing
generic that has its own example). The 9-export, 0-example
state of `methods-gllvmTMB.R` is therefore not a CRAN concern.

```sh
grep -c "^bibentry" inst/CITATION
```

verdict: 3 `bibentry()` calls (Nakagawa, Kristensen, Anderson).
Matches PR #26's design.

```sh
grep -E "^Copyright:" DESCRIPTION
```

verdict: `Copyright: inst/COPYRIGHTS` -- the CRAN-blessed
pointer pattern is in place (post-PR-#26 Path A).

## What Did Not Go Smoothly

The `@examples` gap is larger than I expected (22 exports
without examples vs the rough "~5-10" I'd guessed before
running the grep). The gap is manageable but real -- ~15-20
small `\dontrun` additions plus ~5-6 `@keywords internal`
demotions. CRAN would flag this in a `--as-cran` check as a
WARNING for each function without examples.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Grace (CI / pkgdown / CRAN)** is the lead role for Phase 5;
  this audit is Grace's input.
- **Ada (orchestrator)** sequences Phase 5 after Phase 4 lands
  so the CRAN-time check is fast enough.
- **Boole (R API)** owns the back-compat wrapper demotion
  decisions: which functions stay user-facing vs `@keywords
  internal`.
- **Pat (applied user / contributor)** -- the missing-`@examples`
  exports include `latent`, `meta_known_V`, `traits`, etc., which
  are user-facing formula keywords. Adding examples there is
  high-leverage for Pat's audience.

## Known Limitations

- The audit does NOT run `R CMD check --as-cran`. The 22 missing
  `@examples` would surface as WARNINGs in that check, but
  there may be additional CRAN-policy items (e.g., dontrun
  blocks needing reformatting, lazyloading, package size) that
  only the actual check reveals.
- The audit does NOT run `urlchecker::url_check()` or
  `spelling::spell_check_package()`. Those need actual R runs
  and are submit-time, not now.
- The audit's verdict on `methods-gllvmTMB.R` (S3 methods
  acceptable without `@examples`) is project-policy adjacent;
  some CRAN reviewers prefer examples on S3 methods too. If
  a future submission gets pushback on that, the policy can be
  amended.
- The audit assumes Phase 4 (RUN_SLOW_TESTS) lands before
  Phase 5. If submission becomes urgent before Phase 4 lands,
  the full test suite would run in the CRAN check at ~30 min
  Windows; CRAN tolerates this but it slows the back-and-forth.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: read-only
   audit + after-task in `docs/dev-log/`. No source change.
2. After merge, the audit lives alongside PR #41 (Tier-2
   queue) and PR #43 (Phase 4 audit) in
   `docs/dev-log/shannon-audits/`. All three are Phase 4/5 prep
   for when the maintainer is ready.
3. Sequence when Phase 5 becomes active:
   - Phase 4 land (PR #43's gating, via a future Codex PR)
   - Tier-2 ports per PR #41 (Codex one PR per article)
   - `@examples` round per this audit's list (Codex bounded PR)
   - NEWS.md rewrite for CRAN reviewer audience (Claude can
     draft; Codex implements)
   - `urlchecker` + `spelling` + `R CMD check --as-cran` runs
   - `cran-comments.md` draft (Claude)
   - Submission
