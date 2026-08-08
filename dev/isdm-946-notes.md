# Issue #946 — `offset()` admitted for `binomial(cloglog)` — implementation notes

Worktree: `/Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm`
Branch: `claude/experiment-integrated-sdm`
Not committed, not pushed, no PR — per lane rule.

## Pre-edit lane check (AGENTS.md rule for `docs/design/`)

Run against the shared `/Users/z3437171/Dropbox/Github Local/gllvmTMB` checkout:

```
$ gh pr list --state open
(no output -- zero open PRs)

$ git log --all --oneline --since="6 hours ago"
725b6e94 docs(isdm): Phase A after-task report + check-log entry
68b45223 measure(isdm): THE GATE PASSES above prevalence 0.3 -- mixed curvature is nearly free
50f578b9 docs(handover): Claude experimental lane -- integrated SDM in one latent space
```

All three recent commits are this lane's own prior work (isdm). Also checked
`git log -3 --oneline -- docs/design/01-formula-grammar.md` on the shared
checkout: last touch was `a91a5e87 docs: reconcile scalar compatibility
guidance`, not recent/in-flight. **Clear to edit** `docs/design/01-formula-grammar.md`.

## Family/link ids verified against source (not trusted from the brief)

`R/enum.R`:
```r
.valid_family <- c(gaussian = 0L, binomial = 1L, poisson = 2L, ...)
.valid_link   <- c(logit = 0L, probit = 1L, cloglog = 2L)
```
`R/fit-multi.R:359-374` (`family_to_id()` doc comment) confirms the same
encoding at the call site. **`family_id == 1L` (binomial), `link_id == 2L`
(cloglog)** — matches the brief exactly, no correction needed.

`link_id_vec` is in scope at the `gll_prepare_offset()` call site
(`R/fit-multi.R:2159`, at that point in the file `link_id_vec` was already
built at line 526/537) — confirmed by grep before editing.

## The four touch points, as actually edited (final line numbers, post-edit)

1. **`R/offset.R:135-141`** (roxygen) — added `@param link_id_vec` documenting
   that it is only consulted for `family_id_vec == 1` rows.
   **`R/offset.R:124-126`** (function signature) — added `link_id_vec` param
   to `gll_prepare_offset()`.
2. **`R/fit-multi.R:2159-2167`** — the sole call site now passes
   `link_id_vec = link_id_vec`.
3. **`R/offset.R:164-166`** — the gate:
   ```r
   offending <- off != 0 &
     !(family_id_vec %in% .gll_offset_count_family_ids) &
     !.gll_offset_binom_cloglog(family_id_vec, link_id_vec)
   ```
   with a new helper `.gll_offset_binom_cloglog(family_id_vec, link_id_vec)`
   (`R/offset.R:30-34`) `family_id_vec == 1L & link_id_vec == 2L`. Existing
   zero-offset pass-through (`off != 0 & ...`) is untouched.
4. **`R/offset.R:168-179`** (`fam_name()`) — now reports `binomial(<link>)`
   for binomial rows (reading `f$link` off the family object) instead of bare
   `"binomial"`, so a still-refused `binomial(logit)` row is distinguishable
   from an admitted `binomial(cloglog)` row in a partially-admitted-family
   error. `cli_safe()` brace-escaping is applied to the resulting label
   exactly as before (untouched call site, just fed a different string).
   **`R/offset.R:205-208`** — updated `cli_abort()` message and `>` hint text
   to state the family x link rule and name `binomial(link = "logit")` /
   `binomial(link = "probit")` explicitly.

## Cascade: "count families only" phrasing

- `docs/design/01-formula-grammar.md:680-731` — the "Offsets (count families
  only)" section heading and its family-not-link paragraph **rewritten**
  (not appended) to state the family x link rule, keep the original gaussian/
  binomial(logit)/binomial(probit) reasoning, add the cloglog change-of-support
  construction with citations, and note Gamma/lognormal/Tweedie remain
  unaddressed and refused.
- `R/gllvmTMB.R:50-65` (roxygen on `gllvmTMB()`'s `formula` param) — rewritten
  to the same effect; this is user-facing `?gllvmTMB` documentation.
  `devtools::document()` regenerated `man/gllvmTMB.Rd` from it (only that
  file changed under `man/`).
- `R/offset.R` header comment block (lines 1-22) and the `gll_prepare_offset()`
  roxygen description — also rewritten, since the file's own top-of-file
  reasoning directly argued *against* what is now implemented ("Gating on
  family rather than link..."); leaving it would have been actively
  misleading in the same file as the new gate. This was not one of the
  brief's four numbered touch points but falls under "a convention change
  must cascade."

### Found but deliberately NOT touched (out of scope)

`R/missing-predictor.R:647-653` — the error raised when `offset()` appears
inside an `impute` / `mi()` covariate formula says *"An offset in the main
response formula is supported for count families"* in its `i =` hint. This
is now slightly incomplete (omits `binomial(cloglog)`), but it is a
different, unconditional refusal (offsets inside impute formulas are refused
for every family/link, so the undersell doesn't change behaviour) and was
not named in the brief's scope (docs file + `R/gllvmTMB.R` roxygen only).
Flagging rather than fixing, per the surgical-changes rule.

## Tests — `tests/testthat/test-offset-support.R`, new section "(5b)"

Read the whole file first (486 lines pre-edit). Confirmed: every existing
"offset refused on non-count family" test used `gaussian()`; none touched
`binomial` at all. Inserted 4 new `test_that()` blocks plus one helper
(`.ofs_cloglog_long()`) between the existing "(5) The family gate" section
and "(6) Wide per-trait offset(e1, e2)" section.

1. **"a binomial(cloglog) offset is accepted and recovers the planted
   intensity slope"** — FAILURE-BEFORE-FIX. Two `binomial(cloglog)` traits
   (`t1`, `t2`), `log_area` correlated with `z` (mirrors the existing
   `.ofs_pois_long` design rationale: uncorrelated exposure would only shift
   the intercept and couldn't distinguish "applied" from "ignored"). Checks
   `traitt1:z` recovers within 0.15 of the true 0.5 with the offset, and that
   omitting the offset shifts the estimate by >0.2 in the expected direction
   (empirically ~0.94 vs 0.60, truth 0.5 — see exploratory run below).
2. **"binomial(logit) and binomial(probit) offsets still abort, naming the
   link"** — BOUNDARY. Two-trait binomial fit, both links tried in a loop;
   asserts the message matches `"count"`, `"binomial"`, and the specific link
   string (`"logit"` / `"probit"`). Nothing guarded this before #946 — the
   old gate refused all of `binomial` unconditionally, so no test could
   previously distinguish "the whole family is refused" from "this specific
   link is refused for a reason."
3. Existing `gaussian()` refusal test (unmodified) — reran; still passes.
4. **"poisson exposure offsets and binomial(cloglog) area offsets combine in
   one mixed-family fit"** — FEATURE-COMBINATION. `t1` = poisson with
   `log(effort)`, `t2` = `binomial(cloglog)` with `log(area)`, both nonzero;
   asserts `convergence == 0L` and the offset engages (logLik differs from
   the all-zero-offset control by >1). This is the literal integrated-SDM
   use case from the issue.

## Before-fix verification (stash/revert, run, restore)

```
$ git stash push -- R/fit-multi.R R/gllvmTMB.R R/offset.R
$ Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-offset-support.R", reporter="summary")'
```

Result: 4 failures, exactly the 4 new tests, 0 failures elsewhere:

```
── 1. Error ('test-offset-support.R:296:3'): a binomial(cloglog) offset is accep
Error in `gll_prepare_offset(...)`: offsets are supported for count families
(poisson, nbinom) only; trait `t1` uses `binomial` and trait `t2` uses
`binomial`.
i An offset is a multiplicative rate adjustment on the log link. Under
`gaussian()` it would be an unexplained mean shift, and under `binomial()` a
fixed shift in log-odds.
> Set the offset to `0` on the rows of a non-count trait; an offset of zero
is a multiplier of one, so those traits are left unchanged.

── 2. Failure ('test-offset-support.R:347:5'): binomial(logit) and binomial(prob
Expected `msg` to match string "logit".
Actual text:
x | offsets are supported for count families (poisson, nbinom) only; trait
`t1` uses `binomial` and trait `t2` uses `binomial`. ...

── 3. Failure ('test-offset-support.R:347:5'): binomial(logit) and binomial(prob
Expected `msg` to match string "probit".
Actual text: [same as above]

── 4. Error ('test-offset-support.R:383:3'): poisson exposure offsets and binomi
Error in `gll_prepare_offset(...)`: offsets are supported for count families
(poisson, nbinom) only; trait `t2` uses `binomial`.
```

Then `git stash pop` to restore the fix (confirmed via `git diff --stat` that
the three `R/` files matched the pre-stash diff exactly).

## Post-fix verification

```
$ Rscript -e 'devtools::document(quiet = TRUE)'
```
Only `man/gllvmTMB.Rd` changed under `man/` (pre-existing unrelated `@details`
link-resolution warnings for `.cv_join_truth` / `.cv_score` /
`.gllvmTMB_sigma_eps` and two missing `@exportS3Method` tags on
`AIC.gllvmTMB_multi` / `BIC.gllvmTMB_multi` are pre-existing, not introduced
by this change).

```
$ Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-offset-support.R", reporter="summary")'
```
18 test_that blocks, 67 assertions passed, 0 failed, 1 skipped (`skip_on_cran()`
cross-package comparator).

Also ran every other test file with "offset" in it that exercises the gate:
`test-offset-guard.R` (5/5 pass — the pre-existing lv-offset / impute-offset /
wide-traits-offset-rejection guards, all untouched by this change) and
`test-missing-predictor-categorical.R` (unaffected; its skips are pre-existing
`GLLVMTMB_HEAVY_TESTS` gates, unrelated to this change — ran to confirm the
`offset()`-inside-`mi()` refusal still fires, test 6 "unordered mi() rejects
out-of-scope predictor models" passes 6/6).

## Things the brief got wrong / needed correction

- Everything in the brief's stated touch points, family id, link id, and call
  site was accurate on inspection — no corrections needed there.
- The brief's four touch points did not include the `R/offset.R` top-of-file
  header comment (lines 1-22), but that comment's own reasoning
  ("Gating on family rather than link...") directly contradicted the new
  behaviour, so it was rewritten too (documented above under "Cascade").
- One issue found outside scope: `R/missing-predictor.R:647-653`'s "count
  families" phrasing in the impute-offset rejection message is now slightly
  incomplete. Not fixed (out of the brief's named scope, behaviour
  unaffected). See "Found but deliberately NOT touched" above.

## Unrelated concurrent activity in this worktree (flag, not mine)

While this task was in progress, `R/extract-sigma.R` and
`tests/testthat/test-extract-sigma.R` became modified in this same worktree
without any action by this session — content is a `link_residual` NA-
propagation fix for `extract_Sigma()` on within-trait mixed-family fits,
dated "isdm lane, 2026-08-08" in its own comments. The worktree was
confirmed clean (`git status --short` empty) at the start of this session,
before any of that content appeared. This session **never touched** either
file. It appears another process/agent is writing into this same worktree
concurrently — worth flagging to the maintainer as a potential lane
collision, since the task brief describes this worktree as exclusively
this task's.
