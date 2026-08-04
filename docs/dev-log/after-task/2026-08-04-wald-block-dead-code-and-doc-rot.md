# After Task: `.wald_block()` confirmed dead, and `06-consumers.md`'s citation rot swept

**Branch**: `worktree-agent-a1ea2c74dc077c425` (rebased onto `claude/va-lane2` @ `0a280205`)
**Date**: `2026-08-04`
**Roles (engaged)**: Claude Code (solo)

## 1. Goal

The 2026-08-04 silent-all-NA fix (`docs/dev-log/after-task/2026-08-04-silent-na-standard-errors-closed.md`)
found `.wald_block()` (`R/profile-ci.R`) carrying the same silent-NA pattern it fixed elsewhere, but
flagged it as dead code and deliberately left it untouched, spawning this task. It also flagged
`dev/aghq-scope/06-consumers.md:44` as describing `.wald_block()` with stale line numbers and a false
call-graph claim ("called by all Wald confint routes"). This task: (1) independently re-verify the
dead-code claim rather than trust the brief, (2) surface rather than delete if confirmed dead, (3) fix
the flagged doc row, and (4) audit the rest of that document for the same class of rot, on the
assumption — the Rose principle — that one stale row implies more.

## 2. Implemented

**`.wald_block()` is CONFIRMED DEAD**, independently, by five separate lines of evidence (not just
trusting the brief):

1. Repo-wide case-insensitive grep for `wald_block` across every directory and file type (`R/`,
   `tests/`, `dev/`, `vignettes/`, `inst/`, `man/`, `docs/`) finds only its own definition and prose
   describing it as dead — zero call sites anywhere.
2. `git grep wald_block` at HEAD and at the introducing commit `7bb8a446` both show exactly one hit
   (the definition) — it was never called, from the moment it was written.
3. `git log -S'.wald_block('` (pickaxe, `--all`) across the full history returns only two commits, and
   both are markdown edits (the `06-consumers.md` creation and the 2026-08-04 doc-comment session) —
   never a code call site, at any point in the repo's history.
4. Every dynamic-dispatch mechanism in the repo was checked for a name that could resolve to
   `.wald_block` at runtime: `do.call`, `match.fun`, `get`/`mget`, `eval(parse(...))`, `getFunction`,
   `getExportedValue`, `as.function`, `sys.function`. None construct or reference this name. The only
   generic `_block`-suffix convention in the codebase is `.tmbprofile_block()` (a different, live
   function with real callers at `R/z-confint-gllvmTMB.R:1974,1998`) — there is no generic
   method-name-to-`_block`-suffix dispatcher that could reach `.wald_block` indirectly.
5. The real Wald CI routes for `confint.gllvmTMB_multi(method = "wald")` were traced and confirmed
   live: `.confint_wald_targets()` (`R/z-confint-gllvmTMB.R:1278`) and `.confint_sigma_wald()`
   (`R/z-confint-gllvmTMB.R:1845`), the latter confirmed exercised by a real test call
   (`gllvmTMB:::.confint_sigma_wald(...)` at `tests/testthat/test-profile-route-matrix.R:789`).

**Recommendation followed: mark, don't delete.** Per the repo's surface-don't-delete convention, the
function body is untouched. Its header comment (`R/profile-ci.R:480` before this change), which itself
falsely claimed "used by method = \"wald\"", is replaced with a dated dead-code notice naming the
evidence and the real live routes, per the repo's own instruction not to silently perform deletions.

**`dev/aghq-scope/06-consumers.md` audited in full**, not just the flagged row. Of 36 consumer rows (33
carrying a specific line citation), **28 needed a correction**: severe line drift (several `R/fit-multi.R`
citations now land on unrelated prose — one dead-code call-graph claim (the flagged `.wald_block()` row),
one fabricated caller name (`gll_cross_kernel_rho()` does not exist anywhere in the repo — the real
caller is `profile_cross_rho()`), one non-existent function name (`diagnose.gllvmTMB()` — the entry
point is `check_gllvmTMB()`), and one casing error present since the document's own authoring commit
(`extract_sigma()` has never existed; the exported function has always been `extract_Sigma()`, capital
S, confirmed back to the same `7bb8a446` commit that introduced `.wald_block()`). 4 rows were fully
accurate as written; 3 cite no specific line and were confirmed still true. All 28 corrections were
applied in place (struck-through original, corrected value, dated), plus a banner at the top of the
document recording the audit. The category-level analysis and AGHQ-impact predictions were left
untouched — only locations and the specific false claims were fixed.

## 3. Files Changed

- `R/profile-ci.R` — replaced the misleading header comment above `.wald_block()` (lines ~480-497)
  with a dated dead-code notice citing the search evidence and the real Wald CI routes. No code logic
  changed; the function body is untouched.
- `dev/aghq-scope/06-consumers.md` — added a 2026-08-04 audit banner near the top; corrected the
  flagged row 44 (`.wald_block()`); corrected 27 further rows' `File:Line` citations and/or
  call-graph/function-name claims across all six categories.

## 3a. Decisions and Rejected Alternatives

- **Mark, don't delete `.wald_block()`.** The brief and the repo's standing convention both say
  surface deletions rather than perform them. Rejected: silently deleting the function (out of scope,
  and the brief explicitly forbids it) or leaving the misleading header comment as-is (would perpetuate
  the false claim the task exists to correct).
- **No `lifecycle`-package marker.** Checked whether the repo uses `lifecycle` badges for this kind of
  internal-dead-code annotation; it does not — `lifecycle` badges in this codebase are reserved for
  exported, user-facing functions going through a deprecation cycle, and `.wald_block()` is
  `@noRd`/`@keywords internal` and was never exported. A plain dated comment matches the existing house
  style seen in `docs/design/35-validation-debt-register.md` (EXT-36) and elsewhere in `R/` (e.g.
  `R/aghq-control.R:172`'s "the ladder was dead code" note).
- **Correct all 28 stale rows in `06-consumers.md`, not just row 44.** The task explicitly required
  fixing row 44 and asked for an audit report of the rest; it did not explicitly require fixing every
  other row. Chose to fix them anyway: (a) this is the Rose principle from the user's own standing
  doctrine — "when a mistake is found, assume there are ten more of the same kind and fix them all"; (b)
  the corrections are docs-only, mechanical, and low-risk under this repo's own merge-authority rule; (c)
  a document whose purpose is navigation is actively harmful with 28/33 wrong citations, and a
  warning-only banner would not restore that purpose. Rejected: leaving the rest of the document
  unedited and only reporting the audit table, which would have been the more conservative, narrower
  reading of the brief and would have kept the diff to two rows.
- **Did not "fix" the substantive AGHQ-impact predictions.** Those are 2026-07-28 forward-looking design
  judgments (e.g. "AGHQ Hessian will differ; SEs will change"), not factual claims checkable against
  current code the way a `File:Line` citation is. Re-verifying 36 predictions against the now-landed
  AGHQ engine is a materially different, much larger task than a doc-rot audit and was out of scope.
- **Caught and fixed a self-referential instance of the same defect.** An early draft of the audit
  banner cited "the `.wald_block()` row, row 44 below" — but after editing the document, that row had
  itself moved to line 63. Corrected to a content reference instead of a line number, with a one-line
  note on why (the document's own citations move every time it is edited).

## 4. Checks Run

- `NOT_CRAN=true Rscript -e 'devtools::load_all("."); testthat::test_local(filter="profile")'` (as
  specified in the brief): **`[ FAIL 0 | WARN 0 | SKIP 70 | PASS 523 ]`**. The 70 skips are the
  pre-existing `GLLVMTMB_HEAVY_TESTS=1`-gated heavy recovery/matrix tests, unrelated to this change.
  `devtools::load_all()` (including the `gllvmTMB_va_r3` TMB template compile) completed cleanly,
  confirming the comment-only edit to `R/profile-ci.R` did not break parsing or loading.
- Repo-wide searches (see §2, item 1-4 above) — commands and full results recorded in this session's
  transcript; not re-pasted here per instructions to keep this report free of large diffs.
- `git status --short` / `git diff --stat` after edits: exactly the two intended files touched
  (`R/profile-ci.R`, `dev/aghq-scope/06-consumers.md`); no accidental edits elsewhere.
- Verified I did not touch `/Users/z3437171/Dropbox/Github Local/gllvmTMB` or
  `/private/tmp/gllvmtmb-va-lane2` (confirmed via `ps aux`: two other, unrelated R test processes were
  running against the latter path from a different session throughout this task — correctly left alone).

## 5. Tests of the Tests

No new tests were added — this task is a dead-code annotation and a documentation-accuracy fix, not a
behavior change, so there is no new behavior to gate with a test. The existing `filter="profile"` suite
(523 passing) is the correct regression check for `R/profile-ci.R`, since `.wald_block()`'s neighbors
(`tmbprofile_wrapper()`, `.tmbprofile_block()`) are exercised there and would have caught any accidental
syntax or logic disturbance from the comment edit.

## 6. Consistency Audit

- `grep -rni "wald_block" . --exclude-dir=.git` — one hit in `R/` (the definition), rest in docs
  describing it as dead. Consistent with "dead code" verdict.
- `git log -S'.wald_block(' --oneline --all` — 2 commits, both markdown, confirmed against `git show`
  for each. Consistent.
- `grep -c "corrected 2026-08-04" dev/aghq-scope/06-consumers.md` cross-checked against a manual
  row-by-row tally of every edit made — reconciled to 28 rows carrying some form of a 2026-08-04
  correction/verification marker (26 with the literal "corrected" phrasing, plus the `.wald_block` row's
  "SUPERSEDED" phrasing and the `.cross_rho_logLik()` row's "verified ... unchanged" phrasing). Recorded
  here because the two counting passes initially disagreed by 10 (18 vs. 28) before the tally was
  redone against the actual edits rather than an earlier rough estimate — see §8.
- Re-read the full corrected `06-consumers.md` end to end after all edits: markdown table structure
  (pipe delimiters, row counts per category) intact; no row left half-edited.

## 7. Roadmap Tick

None. This is a dead-code annotation and a dev-scope documentation-accuracy fix, not one of the
project's tracked capability arcs.

## 7a. GitHub Issue Ledger

No relevant open issue; none opened. This is a same-day continuation of an already-recorded register
row (EXT-36, `docs/design/35-validation-debt-register.md`), not new project-facing scope.

## 8. What Did Not Go Smoothly

**My own first pass at the audit banner's headline number was wrong (18 vs. the actual 28).** I drafted
the banner text early, from a rough mental tally taken partway through the row-by-row check, before
finishing every row and before actually applying the corrections. When I later counted the real edits
(via `grep -c "corrected 2026-08-04"` plus a manual reconciliation), the true number was 28, not 18. This
is exactly the failure mode this task exists to catch — an unverified count asserted with confidence —
and it was only caught by cross-checking the banner's claim against the actual diff rather than trusting
the earlier draft. Fixed before finalizing.

**A second self-referential miss**, caught in the same review pass: the banner initially pointed to "row
44 below" for `.wald_block()`, which was true of the original file but became false the moment the
document was edited (that row is now at line 63). Corrected to a content reference with an explanatory
note, rather than repeating the exact defect under audit.

**`R/fit-multi.R` resisted precise line-range correction** for three Category 5 rows (`fit$opt$objective`
storage, `fit$opt$convergence`, `fit$tmb_obj$fn()`). The entire fitting engine is one ~6,000-line
top-level function (`gllvmTMB_multi_fit()`, lines 333-6354), and objective/convergence assignment is
genuinely diffuse across at least three code paths (initial fit, restart, AGHQ) rather than a single
site the 2026-07-28 document implied. Rather than fabricate a single false-precision line number, these
three rows now cite multiple verified anchor points and say explicitly that storage is diffuse.

## 9. Team Learning

- **Rose (after-task discipline):** a documentation-rot audit needs the same "verify, don't trust the
  brief" discipline as a code claim — the brief's own line numbers and claims were independently
  re-derived from `git grep`/`git log -S`, not assumed correct, and one of my own intermediate claims (the
  banner's headline count) got the same scrutiny before landing.
- **Fisher (evidence over confidence):** the corrected count (28, not 18) only surfaced because the
  final artifact was checked against itself (`grep -c` on the actual edits) rather than against an
  earlier draft's stated intent. A summary written before the work is finished is a hypothesis, not a
  result.

## 10. Known Limitations And Next Actions

- **`06-consumers.md`'s citations will drift again.** The document says so now (its own audit banner).
  No standing mechanism prevents this; the next drift will need the same kind of sweep. Not a
  regression from this task — the original document had no such mechanism either.
- **The AGHQ-impact predictions in `06-consumers.md` were not re-verified against the now-landed AGHQ
  engine.** Those are substantive design claims from 2026-07-28 (before AGHQ was the main engine), not
  location citations, and re-checking them is a materially larger, separate task.
- **`vcov.gllvmTMB`'s non-existence** (roxygen at `R/gllvmTMB.R:295` claims dispatch) was surfaced by the
  predecessor task and is adjacent to this one but was not re-investigated here — out of this task's
  scope.
- Branch is committed locally on `worktree-agent-a1ea2c74dc077c425` (rebased onto `claude/va-lane2` @
  `0a280205`); per the brief, **not pushed, no PR opened**. Whoever picks this up next should decide
  whether to merge it into the `claude/va-lane2` lane or open a PR.
