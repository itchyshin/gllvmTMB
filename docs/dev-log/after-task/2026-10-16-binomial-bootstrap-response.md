# Preserve binomial response metadata in bootstrap refits

## Goal and outcome

Repair the bootstrap/refit defect in issue #1496 without changing the public API.
The first regression ran on aec24e16629f5030caa98232b6c2315ae618a5aa before any
implementation edit. Its three simulated refit calls changed trial totals; one
began 0, 9, 15 where the fitted model had 2, 7, 11. The same test passes after this
patch. This is observed local evidence, distinct from #1496's original code-reading
report and #1495's prior test reports.

## Investigation and isolation

Read the complete issue body/comment and linked PR #1495 body, files, commits and
reviews (none), the #1494 after-task record and verification scripts, AGENTS.md,
CLAUDE.md, CONTRIBUTING.md, the multi-lane ownership map and relevant handover,
check-log history, and the bootstrap/simulator implementation and git history.
The #1495 report refers to `.unlazy/traits-cbind-mixed/GATES.md`; that file is
absent from this checkout, so its claimed results are prior reports only.
No skill named software-engineering was found in the available catalog or local
skill directories; the R package engineering, systematic debugging, TDD and
verification skills supplied the applicable workflow.

GitHub main was verified as aec24e166 during this sitting. The primary checkout
was on main at 02b46cfc8, 189 commits behind its cached origin/main, with unrelated
untracked work. Its worktrees and edits were preserved. The isolated local clone
is `gllvmTMB-1496`, branch `codex/issue-1496-bootstrap`, pinned to aec24e166.
No commit, push, merge, issue change, GitHub comment, email or external-agent
contact was made. There is no new PR.

Open overlapping work inspected: PR #1501 changes default-level warnings in
R/bootstrap-sigma.R; PR #1505 wires the phylogenetic-signal extractor to its
existing bootstrap worker. Neither implements this trial-total fix. Their work
was not absorbed or altered. Coordination verdict: WARN for integration overlap;
review these PRs together before merging, especially the shared NEWS file.

## Mathematical contract and implementation

For each observed binomial-type model row i, retain N_i from
`fit$tmb_data$n_trials`, simulate S_i*, and refit with (S_i*, N_i - S_i*).
Family ids 1, 8 and 19 use this contract for paired responses. A private matrix
response column avoids trying to invert expressions such as `cbind(s, n - s)`;
the original data columns remain available unchanged to the RHS. Non-binomial
second-column metadata is retained. No likelihood, family, public formula
grammar, exported API, NAMESPACE or version change is introduced.

The simulator already draws successes using the engine's row-specific totals.
The defect was at response replacement: overwriting only the first response
variable left original failures in the refit. The model-row order of fit$data,
simulate() and tmb_data is the common index; dropped rows stay absent. Retained
masked rows are reset to NA and refitted with response="include" rather than
being filled with simulated observations. Their trial total remains the existing
engine sentinel 1; an unknown missing row's true trial count is not recovered.

Single-column binomial/beta-binomial refits now explicitly forward trial weights.
The issue's statement that this encoding was unaffected did not hold for these
helpers: they did not pass a weights argument to gllvmTMB(). Preserve likelihood
weights separately, including the engine's current different treatment of
zero-inflated binomial single-column weights. This patch does not expand that
encoding's admission contract.

The shared helper is used by covariance, LV-effect, proportions, phylogenetic
signal and loading bootstrap intervals, coverage_study(), and the identifiability
refit helper. Existing simulator choice, inference fences, auxiliary settings and
bootstrap-control handling remain in their respective callers. The documented
default is an unconditional simulate/refit bootstrap; existing conditional
fallback warnings are retained. Repairing inputs does not establish coverage.

## Files and documentation

Implementation: R/bootstrap-response.R, R/bootstrap-sigma.R,
R/bootstrap-lv-effects.R, R/proportions-ci.R, R/phylo-signal-ci.R,
R/loading-ci-bootstrap.R, R/coverage-study.R and R/check-identifiability.R.
Regression: tests/testthat/test-bootstrap-binomial-response.R and
tests/testthat/test-bootstrap-isdm-response.R.
Reproducible parallel check: dev/issue-1496/parallel.R.
NEWS.md and validation-debt rows MIX-08 / EXT-13 record the bounded correction,
without promoting interval calibration. docs/dev-log/check-log.md and this report record the
work. No README, ROADMAP, vignette, generated help, pkgdown navigation, example,
family registry or native-code change was needed. Roadmap tick: N/A.

## Tests of the tests and checks

The initial regression file failed three assertions on the old bootstrap code
(`dev/issue-1496/red.log`), then passed with this patch. The final regression
covers unequal totals, zero/all successes, cbind expressions, shuffled rows,
dropped and retained missing rows, binomial/beta-binomial/zero-inflated binomial,
single-column trial weights, Bernoulli, and mixed wide input. Real refits are
compared with an explicitly constructed manual response, including y, totals,
mask, likelihood weights and objective. A complete bootstrap draw list is also
compared against a manual simulate/refit loop. A wrong-length draw must abort.

Final package-structure check: 0 errors, 1 warning and 3 notes (exit 1).
The warning is duplicated argument x in unchanged gllvmTMB_julia-methods.Rd;
notes concern offline time verification, the existing TMB:::EvalADFunObject call,
and xcrun_db temp detritus. Static R code checks passed. Tests, examples, manual
and vignettes were explicitly disabled in this check. New regression: 69 passes;
existing eight-file bootstrap subset: 249 passes and one sandbox socket error,
resolved by the 50-pass existing bootstrap-Sigma file rerun with sockets allowed.
The dedicated cbind parallel comparison also passed. The two subset counts overlap
and must not be added as a unique assertion total.

Commands and current results are recorded in dev/issue-1496/RESULTS.md with raw
logs in the same directory. These are package regression checks, not a coverage
or recovery campaign. Small bootstrap replicate counts are intentional software
checks and are not recommended for inference.

## Consistency audit and review

Exact scans: `rg -n 'all.vars\(fit\$formula|\[\[resp.*\]\] <-|\[\[response.*\]\] <-' R`
located the seven repaired callers and separate temporal/CV/other data utilities.
Temporal bootstrap is Gaussian-only. The two CV paths listed in #1496 remain
separate follow-up work; this patch does not fix them. `rg -n 'bootstrap|simulate'
docs/dev-log/decisions.md` and the bootstrap help/source confirm existing
simulate/refit intent and calibration boundaries. `rg -n 'bootstrap|cbind'
docs/design/35-validation-debt-register.md` confirms the scope remains partial
for non-Gaussian calibration. `git diff --check` is the whitespace gate.

Inline review used Fisher's input/estimand perspective (fixed N_i and explicit
manual refit oracle), Curie's regression perspective (edge cases, masks and red
proof), and Shannon's coordination perspective (isolated checkout and overlapping
PR inventory). An independent reviewer subsequently checked the first patch and identified the
all-unit-weight regression documented below; this correction still needs their
follow-up review. These names describe perspectives, not contacted agents.

## What did not go smoothly

The first test inspection tried to model.frame() a reconstructed covariance
formula; that evaluates internal covariance markers as ordinary R functions.
It was corrected to evaluate the LHS alone before recording the real red proof.
The broad suite's one error was a sandbox prohibition on local worker sockets,
not an assertion failure. Parallel verification was retried with permitted local
sockets and a matching temporary installation, leaving the global 0.7.1 install
untouched. Roxygen 8 rewrote unrelated sigma S3 registration syntax; that
unrelated generated diff was restored. An unqualified utils::tail call was
corrected during review; the final source uses the qualified call.

## Known limitations and next actions

Review/apply the patch and run normal three-OS CI before integration. The full
package test suite, examples and PDF manual were not run; the broader bootstrap
subset and a package check with explicitly disabled tests/examples are identified
separately. CV scoring still defaults trial totals to one, and its null-model
construction still takes the first response column; those related #1496 items
need their own repair and tests. Do not close #1496 solely on this patch. No new
claim about non-Gaussian interval coverage or unsupported simulator tiers is made.

Prose assessment: NOTASSESSED. Technical statements above are grounded in the
source, GitHub reads and recorded local tests; prior-reported results are labelled.


## Independent-review correction: integrated-source weights

The reviewer supplied `/tmp/review1496.R` and
`/tmp/review1496-counterexample.log`. I read both and inspected the integrated-source
contract in R/fit-multi.R. Its guard rejects every explicit weights argument:
the detection arm is Bernoulli, and a weight vector would conflate trial totals
with likelihood exponents on the count arms. The first patch constructed an
unnecessary all-unit weight vector for this fit and consequently lost 3/3
bootstrap refits; original HEAD and manual unweighted refits lost 0/3.

A new regression based on the existing three-source fixture reproduced this with
three failed assertions before the correction (`isdm-red.log`). Response setup
now returns NULL when the reconstructed weight vector is exactly all ones.
Without a weights argument, both trial totals and likelihood multipliers default
to one, so no model information is discarded. Genuine non-unit trial totals and
likelihood weights are retained, including the mixed semantics test. There is no
special bypass of the integrated-source guard and no change to its contract.

The Bernoulli test now expects omission of all-unit weights. The new integrated
regression compares all three bootstrap draws to explicit unweighted manual
refits, rather than just counting successes. It requests link_residual="none"
because mixed laws within each trait have no single residual variance; this
keeps that unrelated limitation out of a covariance-input regression.

Replaying the reviewer's script after the correction reports original fit
convergence 0, successful direct refits, patched bootstrap 0/3 failures and original
HEAD bootstrap 0/3 failures (`review-reproducer-fixed.log`). Final affected-test
and package-check receipts are in RESULTS.md. The first patch/archive is superseded
by the refreshed files at the same deliverable paths. All publication restrictions
and unrelated edits remain preserved.

Correction verification completed: the eight-file focused sweep passed all 225
assertions with zero failures, errors, warnings or skips. The repeated bounded
package check again found 0 errors, 1 unchanged Julia-help warning and the same
3 notes; static R code analysis passed. Tests/examples/manual/vignettes were
explicitly disabled in that package check. Full-suite and three-OS CI remain
outstanding, and the related CV defects remain outside this patch.
