# After Task: gllvmTMB gap closure — ARC A (signposting), ARC B (twin ledger + parity tool), ARC C (0.7 hygiene)

**Date:** 2026-09-02
**Branch:** `claude/gapclose-20260902` (worktree outside Dropbox, from `origin/main` `a15f9e46a`) · **Draft PR:** [#1239](https://github.com/itchyshin/gllvmTMB/pull/1239)
**Roles engaged:** Ada (orchestration), Boole (messages/API), Pat (first-reader prose), Wickham (twin
ledger naming), Rose (hygiene + plan review), Fisher (tau pre-run), Shannon (lane preflight), a fresh
Opus adversarial reviewer, Melissa (reconcile). Builders ran as fresh-context Sonnet/Haiku children.

## 1. Goal

Close the gaps a first-time ecology graduate student falls through on gllvmTMB's advertised 0.7
surface, give the R twin a machine-checked capability ledger that the mission-control board can
match against GLLVM.jl row-for-row, and clear the forgotten 0.7 hygiene items — without any new
family or likelihood in this checkpoint. Owner decisions (Shinichi, 2026-09-02): parity both ways
for user-facing capabilities, bridge stays R->Julia; zip/zinb/zib come to R in the next checkpoint;
`unit` defaults to `NULL`; both twins carry `unit / unit_obs / cluster / cluster2`.

## 2. Mathematical contract

No likelihood, family, estimator, or formula-grammar change. No `src/` change. The only behaviour
changes are (a) refusal and warning text, (b) two new guards that turn silently wrong fits into
refusals or warnings (grouping column value-identical to `trait`; ignored `spatial_*()` grouping
token), (c) the staged `unit` default (`NULL`; an implicit `site` column is still used with a
once-per-session deprecation; no `site` column aborts naming `unit=`), and (d) two runtime
deprecations on direct calls to `meta_known_V()` and `kernel_unique()`. Fits that ran before still
run and return the same numbers (A1's internal callers now pass `unit` explicitly; byte-identical).

## 3. Findings and files

Scouting (three read-only scouts + two peer lanes + the brain) established: every mechanical bug
Ayumi and iwogross reported was already fixed on `main`; what remained was the signposting layer,
a missing R-side capability ledger (the cockpit could only ever show 0 Julia-only rows, by
construction), and release-hygiene debt. Full evidence: the approved plan and `dev/gapclose/*.md`.

ARC A (docs + code): `README.md`, `vignettes/gllvmTMB.Rmd`, `vignettes/articles/{api-keyword-grid,
current-limits,profile-likelihood-ci}.Rmd`; `R/{brms-sugar,gllvmTMB,isdm-sources,fit-multi,
family-cdf-args,parse-multi-formula,diagnose,methods-gllvmTMB,ridge-path,suggest-lambda-constraint,
data-mixed-family,gllvmTMB-wide}.R`; `NEWS.md`; tests `test-gapclose-signposting.R` (10),
`test-gapclose-next-steps.R` (7, incl. the package-wide ratchet at 658 bare aborts),
`test-no-deprecated-recommendations.R` (+2). Evidence `dev/gapclose/tau-prerun*` (two datasets;
dataset 2 reproduces the runaway: ML 10.9 -> `loading_ridge` 0.25 gives 1.0, 2 gives 3.0; VA 3.5).

ARC B: `docs/design/capability-status.md` (76 rows, generated), `dev/gapclose/build-capability-status.R`,
`tools/parity_ledger.R` (44 matched / 32 R-only / 29 Julia-only, every Julia-only row dispositioned,
CLOSURE: PASS), `tests/testthat/test-gapclose-parity-ledger.R` (21), `dev/gapclose/B-parity-notes.md`,
`docs/dev-log/2026-09-02-true-parity-decision-map-gllvmtmb.md`.

ARC C: `inst/CITATION`, `README.md:221`, `NAMESPACE` (two dot-internals un-exported, their Rd removed),
`_pkgdown.yml` (`getREsd`, `tidy`), `docs/design/35-validation-debt-register.md` (COE-02/VA-02/EXT-35
evidence repointed, EXT-02 note, new #1190 row), `R/brms-sugar.R` 1480-1560 and `R/kernel-keywords.R`
(runtime deprecations), `ROADMAP.md` (reconciled against `_pkgdown.yml`), `CLAUDE.md` merge rule;
tests `test-register-evidence-paths.R`, `test-direct-marker-call-deprecations.R`.

Coordination: `docs/dev-log/coordination-board.md` entry; lease `claude:gllvmTMB:91412`.

## 4. Checks run

Per-slice targeted `testthat::test_file()` runs by the builders and re-run by the orchestrator for
every gate (`.unlazy/gapclose/GATES.md`, all G-A1..G-C1 marked with evidence). `pkgdown::check_pkgdown()`
clean. `Rscript dev/gapclose/build-capability-status.R --check` idempotent after the register edits.
`Rscript tools/parity_ledger.R --check-names` 0 near-miss. G-ALL (full `devtools::test()` +
`devtools::check(args = "--no-manual")`): PENDING — filled in below when the run completes.

Verify-then-fix loop (recorded so the numbers below are read in context): a fresh Opus adversarial
review of the first A–C state returned PASS-WITH-CORRECTIONS (2 blocking: the parity tool normalised
`scope-limited`/`point-fit-recovery` to `implemented`, inflating 24/44 matched rows; the group-axis
redirect named `phylo_slope(x | site)`, which refuses, while `latent(1 + x | site)` fits; 8 required).
Gates G-A1/G-A2/G-B2 were un-ticked, the four producers fixed their own files, the reviewer's probe
scripts were re-run on the fixed tree (all consistent), and the gates re-ticked with G-A2's claim
re-scoped honestly (ratchet 999 bare aborts package-wide, may only fall). The first full suite then
showed 9 failures: 2 from the `unit` staging firing before the data check / an older expected message,
4 from tests pinning the removed jargon, 4 from one 2-second child-process deadline test under a load
of 76 caused by another lane's runaway hook (passed solo afterwards). R CMD check (tests run from the
tarball) added a real regression the suite had not reached: `suggest_lambda_constraint()` and
`ridge_path()` lost their grouping under `unit = NULL` (the latter silently, into an all-NA table);
both now share `.gllvmTMB_resolve_unit_staged()` with `gllvmTMB()`. New tests that read repo files skip
on an installed copy.

G-ALL RESULT (final commit `b1004636a`): full `devtools::test()` with the failure cap lifted →
**FAIL 0 | WARN 55 | SKIP 879 | PASS 26948**. `devtools::check(args = "--no-manual")` on the same
commit: **0 errors | 0 warnings | 0 notes** (26 m 56 s).

## 5. Tests of the tests

- Signposting: each rewritten refusal has a snapshot AND a fit test proving the named route fits on
  the same data (a redirect to a route that also refuses would fail the fit test).
- Ratchet: `count-bare-aborts.R` re-derives the bare-abort count with the inventory's rule; the
  hard-coded 658 may only fall, so a new bare abort fails the test.
- Register evidence: `test-register-evidence-paths.R` fails on any cited path that does not exist —
  it would have caught the three dangling `covered` rows this arc fixed.
- Parity: `test-gapclose-parity-ledger.R` asserts the collision rows never join to the wrong Julia
  row (`cumulative_logit` imputation family vs Julia's ordinal response) and that the four grouping
  levels are rows.
- Deprecations: each direct call warns exactly once per session.

## 6. Consistency and documentation audit

`grep -rnE "dependable-core claim|characterization-only|tested-regime evidence|production pair|route-only" README.md vignettes/ --exclude=current-limits.Rmd`
-> no matches (current-limits.Rmd is the page that defines the terms). `grep "0\.6\.0" README.md
inst/CITATION` -> none. No register codes added to reader-facing surfaces (Opus reviewer scan,
pending). NEWS entries in plain language. Roxygen for `unit` regenerated (`man/gllvmTMB.Rd`,
`ridge_path.Rd`, `suggest_lambda_constraint*.Rd`).

## 7. Design and pkgdown

New generated design artifact `docs/design/capability-status.md` (row names match GLLVM.jl
byte-for-byte; R spellings canonical, aliases carry Julia spellings). `_pkgdown.yml` index complete.
`docs/design/61-capability-status.md` left as-is (dated 2026-07-20; C2 deferred). Mission-control
`projects.json` repoint deferred to post-merge (the ledger exists only on this branch until then).

**Roadmap tick:** `ROADMAP.md` reconciled (four articles marked restored, seven marked removed at
0.5.0, dated note pointing at the register as the live boundary).

## 8. GitHub issue ledger

Issues to file with the draft PR (B3): the Julia-only rows dispositioned `port` (zero-inflated trio,
cumulative-logit ordinal response with a distinct name, `select_lv`, boundary-corrected LRT/anova,
ordination uncertainty, censored_poisson engine, fourth-corner estimand, constrained/RRR/quadratic
ordination) and the bare-abort remainder (inventory attached). #1195/#1196/#1163 message items are
addressed here; #1189 gets the measured tau/VA guidance; #1190 gains a register row.

## 9. What did not go smoothly

- The adversarial review found two blocking defects the builders' own tests had passed: a status
  normalisation that made the parity tool lie in the reassuring direction, and a redirect verified
  only on the one grouping where it happened to work. Both were fixed by the original builders.
- `unit = NULL` reached two helpers that derive a grouping from it; one failed loudly, one silently.
  R CMD check, not the suite, exposed them (different skip set).
- A looping after-task hook in the DRM.jl lane spawned ~650 R processes (load 76 on 20 cores),
  timing out a 2 s child-deadline test here; the owner authorised killing the orphans; the other lane
  fixed its hook and is adding a recursion guard to the shared checker.
- The GitHub GraphQL API hit a secondary limit; the draft PR was created through the REST endpoint.

- The first `git worktree add` hit the 2-minute tool timeout (object store on Dropbox); recreated in
  the background.
- RECON-0 found 495 abort calls (318 bare) in 14 files, not the ~30 the scout sampled; A2 was
  re-scoped to the user-reachable set plus a package-wide ratchet (658).
- A hard `unit` abort would have touched 628 test call sites in 178 files, many in other lanes;
  staged to a deprecation instead (owner flag below).
- The A4 first dataset did not reproduce the runaway; a harder second dataset did.
- Gate CHECK lines used `rg`, which `sh` cannot find; switched to `grep -E`.
- The CLAUDE.md handover pointer the scout flagged is not on `main` (only on an old branch).

## 10. Team learning

**Ada:** one worktree with per-arc commit grouping was enough for three arcs on disjoint files; the
Rose plan review caught the two file collisions before dispatch. **Boole:** a redirect must be
conditioned on the erroring call (trait RHS vs grouping RHS) — the two `phylo_slope` grammars
answer different questions. **Pat:** the terms were defined, but on a page a first-time reader never
reaches; rewriting the sentence beats adding a glossary link. **Wickham:** exact-string row keys
plus an alias column keep the cockpit join honest without forcing Julia spellings into R.
**Rose:** three `covered` rows cited files that did not exist — the register now has a test that
would have caught it. **Fisher:** the first simulated dataset was too easy; a pre-run has to
reproduce the pathology before its numbers can ground advice.

## 11. Limitations and next action

- Pre-existing, not this lane: roxygen note that `AIC.gllvmTMB_multi`/`BIC.gllvmTMB_multi` in
  `R/aghq-report.R` lack `@export`/`@exportS3Method` tags.
- README hard-codes the version string (static markdown); CITATION now reads `meta$Version`.
- Bare aborts: 999 remain package-wide behind the ratchet; the user-reachable set and all
  "Internal:" aborts were fixed; the rest is a filed issue.

- 🔴 Owner flag: Decision 3 shipped staged (implicit `site` still works with a deprecation); the
  forced explicitness is deferred to 0.8 because of the 628-site blast radius.
- Owed after merge: mission-control `projects.json` repoint; B3 issues; message to the GLLVM.jl lane
  (their `mi()` ledger row under-claims; bridge `dep()` early error is #1236-lane work).
- Deferred slices: C2 (`dispersion()` extractor; refresh or retire `61-capability-status.md`),
  formula-time warnings for the deprecated marker keywords, the remaining ~650 bare aborts.
- Next checkpoint (ARC D): zip/zinb/zib to R — symbolic alignment table, TMB likelihoods, 14-slot
  registry rows, recovery on a known DGP (Totoro pre-run, then a DRAC job array), register rows,
  NEWS scope statement; own sub-branch; Gauss/Noether review; maintainer sign-off before merge.
