# After Task: Binomial screen false-positive attribution and `loading_absolute_thresh` retune (#1098)

**Branch**: `claude/1098-binomial-fp-20260817`
**Date**: `2026-08-17`
**Roles (engaged)**: `Fisher / Rose (self-applied consistency lens)`

## 1. Goal

Issue #1098 (spun out of #897 directive 2) asked: which arm of
`check_gllvmTMB()`'s `binomial_prevalence_loading` disjunction drives the
232/928 = 25% false-positive rate #897 measured, and can it be fixed
without losing sensitivity on genuinely degenerate fits? The task was
read-only analysis of two existing calibration pools followed by, once the
maintainer decided on a retune, the code/doc/test change implementing it.

## 2. Implemented

- Attributed all 232 of the 928-fit pool's false positives to a single
  arm, `extreme_magnitude` (`max_loading_unit >= loading_absolute_thresh`).
  `runaway_loading` and the prevalence-gated branch contribute **zero**.
  This **inverts #1098's own stated prior**, which named the
  `extreme_prevalence & saturated_fit` conjunct as the likely culprit and
  judged the runaway/absolute arms "unlikely." The attribution is exact up
  to co-firing (prevalence itself is unrecorded in pool 2, so the
  prevalence branch's contribution is inferred by subtraction, not
  observed directly) — safe here because the DGP's own probability model
  keeps prevalence away from the 0.9/0.1 gate essentially always (a Monte
  Carlo over the DGP's `(B, Lambda)` distribution at `sigma_lambda = 3`
  gives mean prevalence 0.5000, SD 0.044, and 0/200,000 draws outside
  `[0.1, 0.9]`).
- `check_gllvmTMB()`'s `loading_absolute_thresh` default raised `6 -> 8`.
  On the 928-fit pool: FPR `0.2500 -> 0.1552`; sensitivity on the pool's
  272 degenerate fits `1.0000 -> 0.9963` (one additional missed fit).
- **Root cause: regime/effect-size dependence, corrected after D-43
  review.** A first draft of `dev/heywood/fp-scale-dependence.md` filed
  this under the #851/#855 "latent standardisation pushes the response
  scale into Lambda" class. **That framing is wrong for this arm and this
  family** — probit fixes the residual (liability) variance at exactly 1
  by construction, so a binomial loading is identified in absolute units
  already; there is no free response scale for standardisation to absorb.
  What actually varies is the DGP's true effect size (`sigma_lambda`): FPR
  runs `3.85%` at `sigma_lambda = 0.7` versus `49.08%` at `3.0` (the same
  scale `aghq_ridge = 2` is already known to struggle at, #847).
  `aghq_ridge = 2` reduces but does not remove it (`46.0% -> 13.5%` at the
  larger scale). This distinction changes the handoff to #851/#855: that
  class's remedy (`tau -> tau * sd(y_t)`) has no Bernoulli analogue
  (`sd(y)` for a 0/1 response carries no information about the latent
  loading scale), and the other obvious device — a quantile of the fit's
  own loading distribution — collapses into the already-existing
  `loading_relative_thresh` ratio arm. `dev/heywood/fp-scale-dependence.md`
  is revised to file this as a **negative scoping result** (the class's
  device may not transfer here), not as one more instance the device will
  fix.
- **The mechanism is quantitative, not just correlational.** An oracle
  exceedance calculation — `Lambda_true ~ N(0, sigma_lambda^2)` entrywise
  over `p*q` independent entries, so `P(max|Lambda_true| >= c) = 1 - [2 *
  Phi(c/sigma_lambda) - 1]^(p*q)` — predicted, independently of the
  measured data, `P(max >= 6)` of `0.6729` (`p=12`) to `0.9191` (`p=27`) at
  `sigma_lambda = 3`, falling to `0.1685`-`0.3398` at threshold 8. This
  closely matches the measured FPR at threshold 8 (`0.2420` vs oracle
  `0.1685` at `p=12`; `0.3321` vs oracle `0.3398` at `p=27`) and
  over-predicts at threshold 6 in the expected direction (the oracle is
  unconditional on recovery quality; the measured FPR conditions on
  `rel_frob<=10`). Derived and verified independently this session, not
  copied from the coordinator's stated range.
- **Robustness recheck against the obvious alternative, promoted out of
  the footnotes.** `rel_frob<=10` is a *relative* bound, and
  `||Sigma_true||_F` itself grows ~9x from `sigma_lambda = 0.7` to `3.0`,
  so the same relative bound admits absolutely larger error at large
  scale — the competing hypothesis is that the "healthy" LABEL is the
  scale-dependent thing, not the detector. Re-running the identical
  attribution under `rel_frob <= 0.5` (ten times tighter) gives FPR
  `0.2156` (n=422, WARN=91) — materially unchanged from `0.2500`. This
  defuses the alternative rather than merely noting it in passing.
- **Unmeasured caveat, now stated in the roxygen: probit-only evidence.**
  The gate applies to `family_id == 1L` for every link, but both pools are
  probit-only. Logit loadings run larger than probit loadings for the same
  underlying model (the standard logistic/probit variance-matching ratio,
  `~1.6-1.8`), so the same threshold is reached by a smaller true effect
  on logit — the FPR measured here should be read as a **lower bound** for
  logit fits, not a transportable number. No logit evidence exists in
  either pool.
- **Why the original calibration missed this — the transferable lesson,
  stated as a design gap, not bad luck.** The pool that originally
  justified `loading_absolute_thresh = 6` (3,944 simulated binomial fits,
  NEWS.md's 0.6.0 entry) fixed its true loading SD at 0.7-1.0 and never
  crossed `sigma_lambda = 3`. Re-scored against the SAME `rel_frob <= 10`
  healthy cutoff used above, only **1 of 2,499** of its healthy fits
  exceeds the threshold at all. **Loading SD is the one parameter this arm
  thresholds directly** — omitting it from that campaign's calibration
  grid was a design gap in that campaign's own scope, not misfortune; the
  grid could have crossed it and did not. **A threshold is only as
  trustworthy as the widest regime its calibration pool spans** — a pool
  that never crosses the failing regime will report a clean bill of health
  regardless of how many fits it contains.
- This is an interim retune, not a structural fix. No fixed constant is
  correct across every loading scale a fit may have, and — per the
  corrected root cause above — the usual #851/#855 rescaling device may
  not even be available for this arm. `dev/heywood/fp-scale-dependence.md`
  is filed as a negative scoping result for that programme, not a to-do
  item.
- **Checked, not steered: does DIA-08's own "inference/identifiability
  warning" framing change the false-positive story?** At `sigma_lambda=3`,
  `q=2`, a trait's true per-entry latent contribution has SD `sqrt(2)*3 ~
  4.24` on the probit scale — quasi-separation territory, where a WARN
  could be *correct* even with `Sigma` well recovered. Pool 2 records
  `convergence` and `pdHess` but **not** standard errors (no SE column
  exists in this CSV, contrary to what was assumed when this check was
  requested). For the 232 flagged vs 696 passed healthy fits: flagged
  `convergence==0` 98.71% / `pdHess` 97.84%; passed `convergence==0`
  99.43% / `pdHess` 87.50% — the flagged group's Hessians are, if
  anything, cleaner than the passed group's, the opposite of "flagged
  fits are more broken." This does not resolve the question: quasi-
  separation converges cleanly by nature, so `convergence`/`pdHess` cannot
  see the pathology an SE-based check would. **Reported as found, not
  steered toward either conclusion** — see §10.

## 3. Files Changed

Implementation:
- `R/diagnose.R` — `loading_absolute_thresh` default `6 -> 8` at both call
  sites (`.gllvmTMB_binomial_prevalence_loading_row()` helper and the
  exported `check_gllvmTMB()` signature); roxygen justification rewritten
  with the new evidence, the FPR/TPR trade-off, and the scale-dependence
  caveat.
- `man/check_gllvmTMB.Rd` — regenerated via `devtools::document()`.
- `tests/testthat/test-runaway-warning.R` — new failure-before-fix test
  (see §5).

Status-inventory cascade:
- `NEWS.md` — new `## Changed` entry under `0.7.0 (development)`. The
  historical `0.6.0` entry describing the original `default 6` was left
  untouched (a past release's record, not live documentation).
- `docs/design/35-validation-debt-register.md` — DIA-08 row: appended a
  dated note recording this arm specifically as `partial` (not `covered`),
  with the attribution numbers and the scale-dependence caveat. DIA-08's
  overall status stays `covered` (the fit-health table machinery itself is
  unaffected; only this one sub-arm is `partial`).
- `README.md`, `vignettes/*` — inspected, no hits, no change needed (see
  Consistency Audit).

Evidence artifacts (dev/, uncommitted-analysis convention, D-50 — no
campaign CSV committed):
- `dev/heywood/fp-attribution.R` — self-contained, re-runnable attribution
  script over both pools.
- `dev/heywood/fp-attribution-findings.md` — full findings note.
- `dev/heywood/fp-scale-dependence.md` — the structural-finding note for
  #851/#855.

This after-task report and the paired `check-log.md` entry (this same
closeout) are the remaining Definition-of-Done artifacts; both are
committed in the same push as this report.

## 3a. Decisions and Rejected Alternatives

- **Decision**: retune `loading_absolute_thresh` (6 -> 8) rather than
  disarm the arm or remove it. **Rationale**: it is the sole source of the
  measured false positives, but it is also a strong true-positive
  contributor (99.63% sensitivity retained at 8; disarming would lose
  detection entirely on a real pathology). **Rejected alternative**:
  disarm at `Inf` — rejected because it discards genuine signal for a
  problem that is scale-dependence, not uselessness. **Confidence**: high
  (both numbers directly measured on the same pool).
- **Decision**: attribute pool 2's WARNs by subtraction (`runaway_loading`
  and `extreme_magnitude` are exactly computable from `rl_max`/
  `max_loading`; anything left over must be the prevalence branch) rather
  than refitting to recover prevalence data pool 2 does not record.
  **Rationale**: the shipped rule's arithmetic makes this exact, not
  inferred, and D-139 (estimate before you run) rules out an unnecessary
  refit for a <30-minute analysis task. Validated: the reconstructed rule
  matches the real, recorded `check_status` with 0 mismatches across all
  1,200 binomial_probit fits. **Rejected alternative**: refit all 928
  fits to extract prevalence directly. **Confidence**: high.
- **Decision**: use pool 2's native `rel_frob <= 10` cutoff (matching its
  own `silent_divergent` convention) as the primary "healthy" population,
  not pool 1's stricter `fp-analyse.R` 0.5/5 cutoff. **Rationale**: it is
  the cutoff that exactly reproduces #897's reported 232/928; pool 1's
  cutoff is reported as a secondary consistency check only (FPR 0.2156
  there, consistent within noise). **Confidence**: high.
- **Decision**: leave the FAM-14 register row's stale "binomial's own
  threshold of 6" cross-reference untouched. **Rationale**: that text
  describes what that ordinal campaign was frozen and scored against at
  the time it ran; silently rewriting it to "8" would misrepresent a
  pre-registered campaign's own record. **Rejected alternative**: update
  it live — rejected as a correctness risk. **Confidence**: medium;
  flagged as a follow-up needing a maintainer call rather than resolved
  here.

## 4. Checks Run

```sh
cd /private/tmp/gllvmtmb-1098-fp
OPENBLAS_NUM_THREADS=1 Rscript --vanilla dev/heywood/fp-attribution.R
```
Outcome: reproduces `n=928, WARN=232, FPR=0.2500` exactly (integer match
against #897); `runaway_loading` fires 0 times, `extreme_magnitude` fires
232/232 on the healthy pool; sensitivity sweep table printed (tau=6..150).

```sh
OPENBLAS_NUM_THREADS=1 Rscript --vanilla -e 'devtools::document()'
```
Outcome: `Writing 'check_gllvmTMB.Rd'`. Three pre-existing, unrelated
`aghq-report.R` S3-method warnings (`anova`/`BIC`/`AIC.gllvmTMB_multi`
missing `@export`/`@exportS3Method`) were emitted; not introduced by this
change, not touched by this PR, left as-is.

```sh
OPENBLAS_NUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter="runaway|diagnose|sanity")'
```
Outcome (this session): `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 174 ]`, run
twice (once immediately after the code+test change, once again after all
doc/register edits were in place) with identical results.
Outcome (coordinator's independent re-run, reported after PR #1110
opened): `0 failures / 0 errors / 174 passing / 13 environment-gated
skips` — the skip-count difference is `skip_on_cran()` guards on the four
real-fit tests in `test-runaway-warning.R`, which run under
`devtools::test()`'s default `NOT_CRAN` but can skip under a different
invocation; the pass count (174) and failure count (0) agree exactly.

Filter-matched files confirmed by direct enumeration (not left to the
regex alone):
```sh
ls tests/testthat/test-*.R | sed 's#.*/test-##;s#\.R$##' | grep -E "runaway|diagnose|sanity"
```
-> `gllvmTMB-diagnose`, `runaway-warning`, `sanity-categorical`,
`sanity-multi`, `scale-free-runaway-detector` (5 files). Confirmed
`test-scale-free-runaway-detector.R` (matched via "runaway") independently
green: `13 pass, 0 fail`.

**Deliberately NOT run**: full `devtools::check()` / `rcmdcheck(args =
"--as-cran")` (this is a threshold retune in one diagnostic row, not a
build/packaging change, and 3-OS CI is already running on the open PR);
the `GLLVMTMB_HEAVY_TESTS=1` heavy suite (no family/likelihood/grammar
code touched, only a `check_gllvmTMB()` default and its roxygen);
`pkgdown::build_articles()` (no vignette references this threshold — see
Consistency Audit, zero hits). Pool 2's 3,600-fit CSV was generated on
Totoro and deliberately never committed to this repo (D-50); the
attribution script reads it from its Totoro-retrieved path outside the
repo, overridable via the `POOL2_CSV` env var.

## 5. Tests of the Tests

`test-runaway-warning.R`: `"loading_absolute_thresh default is 8, up from
the old 6 (issue #1098)"` — **failure-before-fix verification**. A
synthetic `gllvmTMB_multi` fixture (exercising the real
`check_gllvmTMB()` code path, no fitting) has one trait loading at exactly
7 — inside `[6, 8)` — with prevalence (0.5), saturation (none), and
`relative_loading` (7, below both `loading_relative_thresh = 8` and
`loading_runaway_thresh = 25`) all held ordinary, so only
`extreme_magnitude` can possibly fire. The test asserts `WARN` when
called with the OLD default explicitly (`loading_absolute_thresh = 6`) —
demonstrating it would have failed against pre-#1098 code — and `PASS`
under the package's new bare default. It also pins
`formals(check_gllvmTMB)$loading_absolute_thresh` to `8` directly, so a
future accidental revert of just one of the two call sites (the internal
helper vs. the exported signature) would be caught even if the fixture's
own loading value happened not to expose the mismatch.

## 6. Consistency Audit

```sh
grep -rn "loading_absolute_thresh" --include="*.R" --include="*.Rd" --include="*.Rmd" --include="*.md" .
```
Verdict: every live site (`R/diagnose.R`, `man/check_gllvmTMB.Rd`) reads
the new default (8); ~30 historical mentions across
`docs/dev-log/handover/*`, `docs/dev-log/audits/*`, and `check-log.md`
itself still name the old value of 6 or discuss it as it stood at the
time — these are append-only session logs, not live documentation, and
were deliberately left untouched. `docs/design/35-validation-debt-register.md`'s
FAM-14 row also still names "binomial's own threshold of 6" inside its own
frozen ordinal-campaign record — flagged as a known follow-up (§10), not
silently fixed (see §3a).

```sh
grep -rn "3,944\|3944" --include="*.R" --include="*.Rd" --include="*.Rmd" --include="*.md" .
grep -rn "3\.99" --include="*.R" --include="*.Rd" --include="*.Rmd" --include="*.md" .
```
Verdict: the `3,944`/`3.99` figures (the original, now-superseded
calibration pool) appear only in `NEWS.md`'s historical `0.6.0` entry and
in `docs/dev-log/*` session logs — none in a currently-live `R/` roxygen
or `man/*.Rd` (both were rewritten to cite the new pool's numbers
instead).

```sh
grep -n "loading_absolute_thresh\|3,944\|3\.99\b" README.md
grep -rln "loading_absolute_thresh|3,944" vignettes/
grep -rln "loading_absolute_thresh" docs/design/
```
Verdict: zero hits in `README.md`, zero hits in `vignettes/`; the sole
`docs/design/` hit is the FAM-14/DIA-08 rows in the validation-debt
register, both handled above.

```sh
OPENBLAS_NUM_THREADS=1 Rscript --vanilla -e 'devtools::document()'
```
(rerun as the rendered-Rd spot-check) — verdict: `man/check_gllvmTMB.Rd`
line 21 reads `loading_absolute_thresh = 8,`; the corresponding `@param`
prose (line 104 onward) matches the rewritten roxygen.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row names this diagnostic screen or issue #897/#1098;
confirmed via `grep -n -i "897\|1098\|degenera\|heywood\|binomial_prevalence" ROADMAP.md` (zero hits).

## 7a. GitHub Issue Ledger

- **Inspected**: #1098 (OPEN — this PR's target; `gh pr view 1110` body
  already carries `Closes #1098`, so it will close on merge), #897 (OPEN —
  the parent issue; this PR contributes evidence to its directive 2 but
  does not close it, since #897's other directives are untouched), #847
  (CLOSED — cited for the `sigma_lambda = 3` regime and the `aghq_ridge`
  numbers), #851 (CLOSED — the scale-dependent-constants class this
  finding was initially, and incorrectly, filed as an instance of; see
  §2's D-43 correction — it is filed as a NEGATIVE scoping result instead),
  #855 (OPEN — the structural-fix design issue;
  `dev/heywood/fp-scale-dependence.md` is filed as a negative-result note
  toward it, not a positive proposal).
- **Commented**: none by this closeout. PR #1110's own body carries the
  same pre-correction framing this report's §2 fixes; the PR body should
  be updated to match before merge (see §8) rather than a duplicate
  standalone comment being added.
- **Closed**: none directly (closure happens on PR merge, not yet
  merged — item 1 below).
- **Created**: none. The FAM-14 stale cross-reference (§3a, §10) was
  judged not to need a standalone issue — it is a two-word staleness
  inside one existing register row, cheaper to fix inline whenever that
  row is next touched than to track separately; recorded here and in the
  register instead.
- **Judged not relevant**: none beyond the above.

## 8. What Did Not Go Smoothly

- The lane-check hook fired on every touched file (`R/diagnose.R`,
  `NEWS.md`, the validation-debt register) with high ref counts (9, 43,
  40). Checked the three most-plausibly-overlapping branches' diffs by
  hand; none actually retunes `loading_absolute_thresh` — the hits were
  unrelated structural reordering / doc-drift noise in worktree branches
  and Codex snapshot refs. Worth naming because the hook's own guidance
  ("do what it says") does not distinguish a real collision from this
  kind of false-positive noise, and a future session should not assume a
  high ref count always means contention.
- Rose's cross-file consistency-audit role was self-applied by Fisher
  (me) rather than run as a genuinely separate pass — this repo's
  Standing Review Roles framework assumes a distinct reviewer identity
  for that role, and I did not spin one up for a single-arm diagnostic
  retune. The coordinator's independent reproduction (attribution numbers
  + test suite) functioned as an external check in its place, but that is
  not the same discipline as a dedicated Rose pass, and a maintainer
  reviewing this PR should treat the consistency audit as self-checked,
  not independently verified.
- **The D-43 ceiling-tier reviewer caught a real mechanism error this
  session's own writing introduced** (see §2): `fp-scale-dependence.md`'s
  first draft filed the binomial arm's regime-dependence under the
  #851/#855 units-dependence class by pattern-matching to "this repo has a
  known scale-dependent-constants class" without checking whether the
  specific mechanism (a free response scale absorbed by standardisation)
  actually applied to a fixed-residual-variance link. It does not, for
  probit. Two reviewers confirming the numbers did not catch this — the
  numbers were right, the causal story attached to them was wrong. This is
  worth naming as a category of error the "verify the numbers"
  discipline does not by itself catch: a correct measurement can still be
  filed under an incorrect mechanism, and only a reviewer checking the
  *mechanism* against first principles (here: what does the probit link
  actually fix?) will find it.
- **PR #1110's own description still carries the pre-correction framing**
  ("a fixed link-scale constant cannot be correct when latent
  standardisation pushes the response scale into Lambda" and "the
  attribution is exact rather than inferred") at the time of this
  addendum. Both claims are corrected in the committed files (§2); the PR
  body was updated to match in this same session (not a repo file, so not
  part of `git diff`, but recorded here since it is user-facing and a
  reviewer reading the PR page should see the corrected framing, not the
  stale one).

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Fisher** (primary, this whole task): the core inference-machinery
finding — that a detector's measured false-positive rate is a property of
where the calibration pool's parameter range sits relative to a fixed
threshold, not an intrinsic property of the detector — is the kind of
result this role exists to surface. The subtraction-attribution method
(exploiting that two of three arms are exactly computable from recorded
columns) avoided an unnecessary 928-fit refit; that is a reusable pattern
for any future issue where a shipped rule's ground truth (`check_status`)
is recorded but its intermediate arm-level firings are not.

**Rose** (self-applied, see §8): the cascade grep across `R/`, `man/`,
`vignettes/`, `docs/design/`, `NEWS.md`, `README.md` caught that the FAM-14
register row carries a now-stale numeric cross-reference that a narrower
grep scoped only to `loading_absolute_thresh`'s own definition site would
have missed — it surfaced only because the audit searched the *value*
(the literal `6`) as well as the *name*, confirming the cascade rule's
requirement to enumerate every occurrence, not just the ones adjacent to
the changed code.

## 10. Known Limitations And Next Actions

- **Definition-of-Done item 1 (3-OS CI) is NOT yet met.** PR #1110 was
  just opened; CI has not finished running at the time of this report.
  Do not treat this PR as done until that run is green.
- **Definition-of-Done item 2 (simulation recovery test)**: N/A as
  stated — this PR adds no new likelihood, family, keyword, or estimator,
  only retunes an existing diagnostic threshold. The failure-before-fix
  test in §5 is the applicable substitute for a diagnostic-row change.
- **Definition-of-Done item 4 (runnable user-facing example)**: N/A — no
  vignette, article, or README example currently demonstrates
  `binomial_prevalence_loading` or `loading_absolute_thresh` (confirmed,
  §6), so there is no example to update.
- **FAM-14 register row's stale "binomial's own threshold of 6"
  cross-reference** (§3a, §8) awaits a maintainer call: annotate it
  in-place, or leave it as a frozen historical record with a forward
  pointer to this report.
- **The structural fix's ownership is now genuinely open, not settled as
  "belongs to #851/#855."** This PR is an interim point-move on one ROC
  curve, explicitly not a resolution — but `dev/heywood/fp-scale-dependence.md`
  is filed as a **negative** scoping result: the #851/#855 class's usual
  per-fit rescaling device has no Bernoulli analogue (no free response
  scale on a fixed-residual-variance link), and the alternative (a
  within-fit quantile) collapses into the existing `loading_relative_thresh`
  ratio arm. A real fix likely needs information external to the single
  fit being screened (a substantive prior on plausible effect sizes, or an
  empirical-Bayes estimate across many fits) — a materially harder
  proposition than #851/#855's per-fit rescaling, and not attempted here.
- **No calibration evidence exists above `sigma_lambda = 3.0`** (the
  largest scale either pool tested). If a fit's true loading scale
  exceeds that, this retune's FPR/TPR numbers do not bound anything
  there.
- **No logit evidence exists.** Both pools are probit-only; the measured
  FPR should be read as a lower bound for logit fits (logit loadings run
  ~1.6-1.8x larger than probit for the same model), stated in the roxygen
  but not measured — a logit-arm calibration pool is the natural next
  slice if this arm is revisited.
- **Item 6 (is "false positive" the right frame?) is not resolved.**
  Convergence/pdHess do not discriminate between "genuinely spurious WARN"
  and "correct identifiability warning on a quasi-separated fit" — both
  the flagged and passed groups report mostly clean optimizer signals.
  Resolving it needs standard errors, which pool 2 does not record.
  Refitting a sample of the 232 flagged fits with SE computation, and
  checking whether those SEs are well-calibrated or blown up, is the
  natural follow-up and was explicitly not attempted this session.
