# C1 gap-close report — 2026-09-02

Branch `claude/gapclose-20260902`, worktree
`/Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902`. No commits made
(per instructions). This worktree is shared with other concurrent agents; where
that is visible in `git diff --stat` / `git status`, it is called out below —
none of it was touched by this task.

## Item 1 — Version strings (`inst/CITATION`, `README.md`)

**Files touched:** `README.md`, `inst/CITATION`.

`README.md:221` and `inst/CITATION` (both `bibentry("Manual", ...)` `note` /
`textVersion` fields) hardcoded `"R package version 0.6.0"` against a
`DESCRIPTION` version of `0.7.1`. README got the literal string fix. CITATION
went further, per the "better" option in the task: it now reads
`meta$Version` (the variable `citation()`/`readCitationFile()` binds to the
package's `DESCRIPTION` metadata when sourcing this file) instead of a
hardcoded string, with a fallback `"unknown"` if `meta` is absent (e.g. a bare
`source()`).

**Proof:**
```
$ rg "0\.6\.0" README.md inst/CITATION
(no output, exit 1)
```
Also verified CITATION parses and renders the live version correctly:
```r
meta <- list(Version = "0.7.1")
env <- new.env(); env$meta <- meta
entries <- Filter(function(v) inherits(v, "bibentry"),
                   lapply(parse("inst/CITATION"), eval, envir = env))
format(entries[[1]])
# "Nakagawa S (2026). _gllvmTMB: Fit Multivariate Response Data_.
#  R package version 0.7.1; methods paper in preparation, <...>"
```

**Not done / caveats:** none. A stale branch
`origin/cursor/cran-path-a-0.6.1-20260807` also touches this file (hardcoding
`0.6.1`) but predates the current MSPL bibentry and the 0.7.x line; the
`meta$Version`-driven fix supersedes it going forward, so it was not built on.

## Item 2 — Accidental exports (`R/proportions-ci.R`)

**Files touched:** `R/proportions-ci.R`, `NAMESPACE` (regenerated),
`man/dot-proportions_wald_ci.Rd` / `man/dot-proportions_bootstrap_ci.Rd`
(deleted by `devtools::document()`).

Replaced `@export` with `@noRd` on `.proportions_wald_ci` (line ~246) and
`.proportions_bootstrap_ci` (line ~422), keeping `@keywords internal`,
matching the file's own convention for its other dot-prefixed helpers.

Checked callers before removing: `R/z-confint-gllvmTMB.R` calls both directly
(same-namespace, unaffected by export status).
`tests/testthat/test-proportions-ci.R` and `test-lme4-style-weights.R` call
them as bare names (`.proportions_wald_ci(fit)`); `test-mspl-api.R` and
`test-proportions-ci.R` also use the explicit `gllvmTMB:::` form. Bare-name
calls from testthat files work because tests run inside the package
namespace — confirmed by running the tests (below), not by inspection alone.

**Proof:**
```
$ grep -c "^export(\.proportions" NAMESPACE
0
$ ls man/dot-proportions_wald_ci.Rd man/dot-proportions_bootstrap_ci.Rd
ls: ... No such file or directory   (both gone)
```
`devtools::document()` output: `Deleting 'dot-proportions_bootstrap_ci.Rd' and
'dot-proportions_wald_ci.Rd'`.

`testthat::test_file("tests/testthat/test-proportions-ci.R")` → `FAIL 0 | WARN 0
| SKIP 4 | PASS 0` (the four assertions are heavy tests gated behind
`GLLVMTMB_HEAVY_TESTS=1`, so they skip rather than run here, but the file loads
and dispatches the bare `.proportions_*` calls with no "object not found"
error, which is what removing `@export` could have broken).

**Not done / caveats:** `test-mspl-api.R` currently fails at collection with
an unrelated pre-existing error (`unit = ... is required`, raised from
`R/gllvmTMB.R:913`) — this is caused by another agent's in-progress edit to
`R/gllvmTMB.R` in this shared worktree (a file I was told not to touch), not
by this change; none of its failures are in code paths that reach
`.proportions_wald_ci`/`.proportions_bootstrap_ci`.

## Item 3 — pkgdown index (`_pkgdown.yml`)

**Files touched:** `_pkgdown.yml`.

Added `getREsd` to "Report-ready extractors" (next to `extract_lv_effects`,
the section covering ordination/latent-score output — `getREsd()` is
`getLV()`'s standard-error generalisation per its own roxygen `@seealso`).
Added `reexports` to "Methods and plots on fitted models" (next to
`tidy.gllvmTMB_multi`) — `tidy` itself has no standalone Rd; it is an alias
inside the auto-generated `man/reexports.Rd` topic (`roxygen2`'s
`@export`-of-a-reexport convention), so `reexports` is the correct pkgdown
content entry, not `tidy`.

**Proof:**
```
$ Rscript -e 'pkgdown::check_pkgdown()'
✔ No problems found.
```

**Not done / caveats:** none.

## Item 4 — Register evidence hygiene (`docs/design/35-validation-debt-register.md`)

**Files touched:** `docs/design/35-validation-debt-register.md`,
`tests/testthat/test-register-evidence-paths.R` (new).

- **(a) COE-02** cited `vignettes/articles/cross-lineage-coevolution.Rmd`.
  Confirmed via `git log --all --diff-filter=A` / `-D` that this article was
  added 2026-06-02 (`50de43ee`) and cut at the 0.5.0 public-article-estate
  finalization (`eacbd0f65`, 2026-07-12) along with 14 other retired
  articles — genuinely gone, no renamed successor. Downgraded the row from
  `covered` to `partial`, dropped the dead citation, kept the two still-real
  test-file citations, and added a dated note explaining the downgrade.
- **(b) VA-02** cited `docs/dev-log/audits/2026-08-06-va-gh-h7-gate-e.md`.
  That file only ever existed on the dormant `origin/codex/va-gh-all-families`
  branch and was never merged to `main`. The 2026-08-17 VA-lane reconciliation
  (`b4ad164da`) salvaged 8 specific files from that branch for VA-06/09/13 but
  explicitly did **not** salvage this one, noting its findings were already
  ported into the register elsewhere (`ae340bdd`, citing `7bf56c4a`). Found
  the real, present evidence under a different name —
  `docs/dev-log/after-task/2026-08-06-va-gh-h7-arc1-public-closeout.md`,
  which documents the identical promoted Gate-E result (18-cell admission,
  `H = 7` default, `calibrated = FALSE`) — and repointed the citation to it.
  Status stays `covered` (real evidence now cited); added a note explaining
  the repoint.
- **(c) EXT-35** cited `dev/va-speed/60-se-false-consumer-probe.md` (in the
  Notes column, not the Evidence column — the row's actual Evidence column
  was already just `test-standard-errors.R`, which exists). Confirmed via
  `git log --all --diff-filter=A` that this probe file was never committed to
  any branch's history — a genuinely uncommitted ad hoc scratch file. Judgment
  call: did **not** downgrade EXT-35's `covered` status, because its own claim
  (deferred-`sdreport()` parity) is fully supported by
  `test-standard-errors.R`, which is real and unaffected; the dangling
  citation was only corroborating a side-note about a *different*,
  already-fixed defect that EXT-36 (also present, also `covered`, with real
  test evidence) already closes. Edited the sentence to say the probe file
  was never committed and to point the reader at EXT-36's real evidence
  instead of silently keeping a dead citation.
- **(d) EXT-02** note said "slated for `deprecate_soft()` 0.3.0". Confirmed
  in `R/extractors.R` that `extract_Sigma_B()` and `extract_Sigma_W()` call
  `lifecycle::deprecate_soft("0.7.0", ...)` — the soft-deprecation actually
  shipped in 0.7.0, not 0.3.0. Updated the note.
- **(e) New row MIS-38** for NEWS 0.7.1's "Explicitly unused optional grouping
  slots now warn (#1190)". Added to Section 12 ("Miscellaneous public
  surface"), status `covered`, evidence
  `tests/testthat/test-unused-grouping-slots.R` (confirmed exists), citing
  issue #1189 (the real external user who hit this) per NEWS.md's own text.

**New pure-R test:** `tests/testthat/test-register-evidence-paths.R`. Parses
every markdown table in the register (tracks the header row per table to find
the "Test evidence" / "Evidence" / "Evidence and remaining debt" column by
name, since header wording varies across sections), extracts path-like tokens
matching `tests/testthat/...`, `vignettes/...`, `docs/...`, `dev/...` from
**only** that column (deliberately not the free-text Notes column — several
rows now explain in prose that some *other* path does not exist, which would
otherwise trip the guard on its own honesty note), expands shell-style brace
groups (`docs/.../foo.{csv,dcf,md}`, used by three VA rows for three real
sibling files), and asserts every resulting path exists relative to the
package root.

**Proof:**
```r
devtools::load_all(quiet = TRUE)
testthat::test_file("tests/testthat/test-register-evidence-paths.R")
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 2 ]
```
(First run caught a real parser gap — the brace-expansion syntax — which
was fixed in the test itself, not by touching the register; after that fix
the only findings were the three citations already documented above.)

**Not done / caveats:** none of the five sub-items were skipped. The test
only checks the Evidence column, by design (see rationale in the test file's
header comment); it does not attempt to validate Notes-column prose
citations, which are far more numerous and often deliberately reference
non-existent paths as part of an honesty note (as EXT-35's edited sentence
now itself does).

## Item 5 — Silent deprecations (`meta_known_V()`, `kernel_unique()`)

**Files touched:** `R/brms-sugar.R` (lines 1525–1540, inside the allowed
1480–1560 window), `R/kernel-keywords.R` (lines 82–101),
`tests/testthat/test-direct-marker-call-deprecations.R` (new).

**Investigation finding, stated because it changes what "fixed" means here:**
both functions are formula **markers** — `invisible(NULL)` bodies that are
"never called at evaluation time" (per this package's own existing roxygen
wording on the sibling marker `spatial()`). The formula parser recognises
`meta_known_V(...)` / `kernel_unique(...)` by matching the unevaluated call's
head name as a string (`R/brms-sugar.R:4886` for `meta_known_V` via
`fn == "meta_V" || fn == "meta_known_V"`, and `:3717-3718` for
`kernel_unique`), so the marker function body genuinely never executes for
real formula-based usage. Also: `kernel_unique()` used *inside a formula*
**already warns** via a separate, unrelated, working mechanism
(`.gllvmTMB_warn_unique_family_deprecated()`, cli_warn-based, tested in
`test-unique-family-deprecation.R`) — that path was untouched. What was
genuinely silent, for both functions, is a **direct call** to the marker
function itself (outside a formula — a script, a test, or exploratory use),
which returned `invisible(NULL)` with zero warning. That is what this item
fixes, and it is consistent with the task's file-editing constraint (edits
confined to the marker bodies, since the parser dispatch code is outside the
allowed line range for `brms-sugar.R` and untouched for `kernel-keywords.R`).

Also confirmed empirically why the package's own established pattern
(`.gllvmTMB_warn_unique_family_deprecated`, ~line 124 comment) deliberately
avoids `lifecycle::deprecate_soft()` for *indirect* in-package callers:
`deprecate_soft()`'s source only signals a warning when
`is_direct(user_env)` is `TRUE` (global env or testthat), so it is silent
from deep nested package-internal calls — exactly the "silent for indirect
callers" problem that comment names. A direct call (console, script, or a
`test_that()` block) *is* "direct" per lifecycle's own definition, so
`lifecycle::deprecate_soft()` reaches the user correctly for the two
functions edited here.

Both edits follow the once-per-session shape of
`.gllvmTMB_warn_scalar_family_deprecated()` /
`.gllvmTMB_warn_latent_residual_alias()` exactly: gated by
`getOption("gllvmTMB.quiet_grammar_notes", FALSE)`, then a lookup/set on the
shared `.gllvmTMB_deprecation_seen` env (new keys `"meta_known_V"` and
`"kernel_unique_direct_call"`; `.gllvmTMB_deprecation_seen` is defined
top-level in `R/brms-sugar.R` and is reachable from `R/kernel-keywords.R` at
runtime — both are in the same package namespace). Attributed `when = "0.2.0"`
to both `deprecate_soft()` calls, matching the version already stated
elsewhere in the package for these two deprecations (the cli_warn message
text for the `*_unique` family says "soft-deprecated as of gllvmTMB 0.2.0",
and `docs/design/00-vision.md` says `meta_V()` was "renamed from
`meta_known_V()` in 0.2.0"). Neither function's return value changed — still
`invisible(NULL)` in both branches of both functions.

**New test file:** `tests/testthat/test-direct-marker-call-deprecations.R`,
one `test_that()` block per function plus a mute-option check. Mirrors the
`local_reset_lifecycle_cache()` pattern from
`test-unique-family-deprecation.R` / `test-scan-deprecated-namespace.R`
(resets both the package's own `.gllvmTMB_deprecation_seen` env and
lifecycle's internal `deprecation_env`, both restored via `withr::defer`).

**Proof:**
```r
devtools::load_all(quiet = TRUE)
testthat::test_file("tests/testthat/test-direct-marker-call-deprecations.R")
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 10 ]
```
Also re-ran the pre-existing `test-unique-family-deprecation.R` to confirm no
regression on `kernel_unique()`'s existing parser-time warning path: only
failure present is a pre-existing, unrelated one at line 171 (`unit = ...` is
required — same `R/gllvmTMB.R` collateral noted under item 2); all
deprecation-warning assertions (including the `kernel_unique` one) passed.

**Not done / caveats:** the `deprecate_soft()` calls added here do **not**
change the behaviour of formula-based usage — a user who writes
`meta_known_V(V = V)` or `kernel_unique(unit, K = K)` inside an actual
`gllvmTMB()` formula still gets no warning from these new calls specifically
(the marker body is never reached there); `kernel_unique()`'s existing,
separate parser-level warning is what a formula user actually sees, and it
was not touched. This is the literal, minimal fix the task's file-editing
constraints allow; making `meta_known_V()` also warn from formula usage
would require touching the parser dispatch code outside the permitted
`brms-sugar.R` line range (1480–1560), so it was deliberately not attempted.

## Item 6 — `ROADMAP.md`

**Files touched:** `ROADMAP.md`.

- **(a)** Marked `behavioural-syndromes`, `random-regression-reaction-norms`,
  `random-slopes-nongaussian`, `phylogenetic-gllvm` **RESTORED** in the
  Restoration Queue table, each citing their live `_pkgdown.yml` navbar +
  reference-index presence; kept their original return-condition text
  labelled as history rather than deleting it.
- **(b)** Marked the other seven queue entries (`mixed-family-extractors`,
  `animal-model`, `psychometrics-irt`, `lambda-constraint`,
  `simulation-recovery-validated`, `cross-package-validation`,
  `functional-biogeography`) "Removed at 0.5.0 (`eacbd0f65`); not queued.",
  confirmed by `git show eacbd0f65 --stat --diff-filter=D`, which lists all
  seven `.Rmd` files as deleted in that commit (also noted that a *different*,
  later article `lambda-constraint-suggest.Rmd` exists and is not this queue
  entry, to avoid a false "it's back" reading).
- **(c)** Added a dated note at the top: "Reconciled 2026-09-02 against
  `_pkgdown.yml`; this file no longer tracks a 0.6/0.7 checklist — the live
  boundary is `docs/design/35-validation-debt-register.md`."

**Proof:**
```
$ grep -n "behavioural-syndromes\|random-regression-reaction-norms\|random-slopes-nongaussian\|phylogenetic-gllvm" _pkgdown.yml
# 4 navbar hrefs + 4 reference-index entries, confirming RESTORED is accurate
$ git show eacbd0f65 --stat --diff-filter=D | grep -E "mixed-family-extractors|animal-model|psychometrics-irt|lambda-constraint|simulation-recovery-validated|cross-package-validation|functional-biogeography"
# all 7 .Rmd files listed as deleted
```

**Not done / caveats:** none; history text preserved, nothing deleted.

## Item 7 — `CLAUDE.md`

**Files touched:** `CLAUDE.md` (line ~587).

Confirmed via `grep -n "Discussion Checkpoint" ROADMAP.md` that no such list
exists in `ROADMAP.md`. Replaced the dangling reference with the high-risk
set already stated in the same paragraph, one sentence:

> The high-risk set is exactly the list above: deletions of public exports,
> API changes, formula-grammar changes, likelihood / TMB / family changes,
> and broad article rewrites.

**Not done / caveats:** none.

## Commands run, in order (abbreviated to the load-bearing ones)

```
until [ -f src/gllvmTMB.so ]; do sleep 15; done         # already present
rg "0\.6\.0" README.md inst/CITATION                     # -> no matches (item 1)
Rscript -e 'devtools::document(quiet = TRUE)'             # regenerates NAMESPACE/man (item 2)
grep -c "^export(\.proportions" NAMESPACE                 # -> 0 (item 2)
testthat::test_file("tests/testthat/test-proportions-ci.R")            # PASS/SKIP, no FAIL
Rscript -e 'pkgdown::check_pkgdown()'                      # -> No problems found (item 3)
testthat::test_file("tests/testthat/test-register-evidence-paths.R")   # PASS 2 (item 4)
testthat::test_file("tests/testthat/test-direct-marker-call-deprecations.R")  # PASS 10 (item 5)
testthat::test_file("tests/testthat/test-unique-family-deprecation.R") # regression check (item 5)
git show eacbd0f65 --stat --diff-filter=D                  # confirms item 6b
grep -n "Discussion Checkpoint" ROADMAP.md                 # -> no matches (item 7)
```

## Shared-worktree note

`git status` shows several files modified/created by other concurrent agents
in this same worktree (`R/data-mixed-family.R`, `R/diagnose.R`,
`R/gllvmTMB-wide.R`, `R/gllvmTMB.R`, `R/ridge-path.R`,
`R/suggest-lambda-constraint.R`, `tests/testthat/test-no-deprecated-recommendations.R`,
`dev/gapclose/B-parity-notes.md`, `dev/gapclose/B1-B2-report.md`,
`dev/gapclose/abort-inventory*`, `docs/design/capability-status.md`,
`tests/testthat/test-gapclose-parity-ledger.R`, `tools/parity_ledger.R`).
None of these were touched by this task. Running `devtools::document()`
(required once, per instructions, after my `R/proportions-ci.R` edit)
necessarily regenerates docs for the *whole* package, so
`man/gllvmTMB.Rd`, `man/ridge_path.Rd`, `man/suggest_lambda_constraint.Rd`,
and `man/suggest_lambda_constraints.Rd` picked up other agents' in-progress
roxygen edits as a side effect — this is inherent to sharing one worktree,
not a change I made deliberately. The pre-existing `unit = ...` required
error surfacing in `R/gllvmTMB.R` (noted under items 2 and 5) is likewise
someone else's in-progress work, not mine, and `R/gllvmTMB.R` was on the
explicit do-not-touch list for this task.

## Addendum 2026-09-02 — NEWS.md (per coordinator, post-Opus-review R4/R6)

Opus review flagged four gaps: no NEWS entry for the two removed exports, none
for the COE-02 register downgrade, none for the two new direct-call
deprecation warnings, and a stale VA precondition-free claim at NEWS.md:15-17.
Fixed all four in the "Development (unreleased)" section:

1. Fixed the existing `gllvmTMB_diagnose()` bullet: `integration = "va"` is
   now qualified as applying only to `latent(..., unique = FALSE)` fits with
   at least 100 units and latent rank <= 2 (matches the hard admission fence
   in `R/integration-fence.R`: `unique = TRUE` aborts, `n < 100` aborts,
   `q > 2` aborts).
2. New bullet: removed `.proportions_wald_ci()` / `.proportions_bootstrap_ci()`,
   names the public replacement route (`confint(fit, parm = "proportion...",
   method = "wald"/"bootstrap")`, `extract_proportions()` for point estimates).
3. New bullet: `meta_known_V()` / `kernel_unique()` direct-call deprecation
   warnings.
4. New bullet: corrected internal evidence citation for the cross-lineage
   coevolution extractor (`extract_Gamma()`) — plain language, no register
   code, per the coordinator's explicit instruction (NEWS.md is one of the
   surfaces `test-reader-facing-no-register-codes.R` checks).

Verified `test-reader-facing-no-register-codes.R` still passes with
`NOT_CRAN=true` (the file's own `skip_on_cran()` otherwise skips it):
`[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]`.

`git diff --stat NEWS.md`: `NEWS.md | 26 ++++++++++++++++++++++++--` (24
insertions, 2 deletions).
