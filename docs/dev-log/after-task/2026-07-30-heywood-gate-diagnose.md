# After-task — the Heywood gate in `check_gllvmTMB()`

Date: 2026-07-30. Agent: Claude. Lane: `claude/heywood-gate-20260730`.
Predecessor: `docs/dev-log/handover/2026-07-29-claude-handover-vgh-heywood-gate.md`.
Evidence: `docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md`.

## 1. Goal

Fix the conjunction at `R/diagnose.R:464` so a runaway `relative_loading` can flag
without `extreme_prevalence`, and calibrate the threshold against a measured
false-positive rate on healthy fits before shipping it.

## 2. Implemented

`.gllvmTMB_binomial_prevalence_loading_row()` gains a `runaway_loading` term:

```r
tab$flag <- (tab$extreme_prevalence &
  (tab$dominant_loading | tab$saturated_fit)) |
  tab$runaway_loading
```

with a new `loading_runaway_thresh = 25` argument threaded through the exported
`check_gllvmTMB()`. Three further changes, each forced by review after the first
draft:

- **The typical loading size is now taken over the traits being screened**
  (`reference_traits` on `.gllvmTMB_max_loading_by_trait()`). It previously
  pooled every trait regardless of family, so a large-scale trait from another
  family could set a binomial trait's yardstick.
- **The wording follows the trait actually reported.** `runaway_hit` is keyed on
  `best`, not `any()`, so a near-constant trait keeps the near-constant advice
  (it is usually the *cause*); the runaway wording appears only where prevalence
  cannot explain the loading. The row carries a `runaway_loading` attribute so
  the `weak_axis_*` row matches rather than describing a prevalence-0.6 trait as
  near-constant.
- **The action names the remedy that exists** — `gllvmTMBcontrol(aghq_ridge = 2)`,
  with its MAP/`logLik` caveat — and the `suggest_lambda_constraint()` referral
  is **deleted**: that function pins entries to zero for rotational
  identification and cannot resolve separation. It also contradicted the
  `weak_axis_*` advice on re-ranking.

## 3a. Decisions and Rejected Alternatives

- **Threshold 25, not 15.** Both give 0/551 false positives, and 15 detects 0.6
  points more. 25 was chosen because the healthy tail demonstrably grows with
  trait count (worst healthy `rl_max` 4.11 → 5.32 → 12.07 for p = 5 → 12 → 25),
  the row flags if *any* trait exceeds, and real datasets run past p = 25. 25
  keeps a 2.07x margin over the largest healthy value observed; 15 would keep
  1.24x against a statistic with a measured p-trend.
- **Threshold 25, not the 60 first drafted.** 60 was a pilot-informed placeholder.
  The full sweep showed it costs 192 missed degenerate fits against 54 at 25, for
  no false-positive benefit — the rate is already 0 at 25.
- **Rejected: adding a saturation conjunct.** `runaway & saturated` returns
  *identical* FPR and TPR at every tau at or above 15 — every degenerate fit with
  a runaway ratio is already saturated, so the conjunct is inert where it would
  operate. It differs only at tau = 8, and there its second term is evaluated on a
  trait the sweep did not measure across the board. Rejected because adopting it
  would ship a clause with a partially unmeasured false-positive rate, which is
  the specific failure `docs/design/vgh-phase4-eda-surface-design.md` warns against.
- **Rejected: loosening `loading_relative_thresh = 8` itself.** Healthy fits with
  a sparse loading structure reach 8 routinely (`sparse75` median 5.22, 90th
  percentile 7.68; 1 of 551 healthy fits exceeds 12). At 8 the ratio is a hint
  needing corroboration, so it keeps its prevalence conjunct. Nothing that flagged
  before stops flagging.
- **Rejected: a new statistic (e.g. max ÷ second-largest loading).** More robust to
  denominator collapse in principle, but a re-architecture where the handover
  specified a one-line gate, and unnecessary once the measured FPR came back 0.
- **Ran locally, not on Totoro**, against the standing scale-out default. The
  largest cell is 16.6 s and the grid finished in ~45 min wall on 16 cores;
  installing gllvmTMB's TMB toolchain remotely would plausibly have cost more than
  the run. Totoro's socket was checked and live before deciding. A judgement about
  this grid, not a revision of the rule.

## 4. Files Touched

Modified:
- `R/diagnose.R` — the gate, the new argument, message/action/scoring, roxygen.
- `man/check_gllvmTMB.Rd` — regenerated (`NAMESPACE` unchanged).
- `NEWS.md` — Fixed entry.
- `tests/testthat/test-sanity-multi.R` — new regression test.

Created:
- `dev/heywood/fp-sweep.R`, `dev/heywood/fp-analyse.R`, `dev/heywood/fp-sweep-full.csv`
- `docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md`
- `docs/dev-log/after-task/2026-07-30-heywood-gate-diagnose.md` (this file)

Deliberately not touched: `CLAUDE.md`'s Live Phase Snapshot (a multi-lane map, not
this lane's to repoint — same call as the two preceding lanes); the pre-existing
`air` formatting drift in `R/diagnose.R` at lines 171/173/217/917, which is on
`main` and outside every edited range; the dangling `ROADMAP.md`
"Discussion Checkpoints" reference carried over from the predecessor handover.

## 5. Checks Run

- **Reproduction, before any change**: `dev/vgh/p3-existing-check-evidence.R` →
  `PASS`, `relative_loading = 6980`, `saturated_fit = 1`, `rel_frob = 156645.4`,
  `convergence = 0`, `pdHess = TRUE`. Matches the handover exactly.
- **Reproduction, after**: same fit → `WARN`, Heywood message and action.
- `test-sanity-multi.R` — 45 pass, 0 fail.
- `test-rotation-advisory.R`, `test-predictive-diagnostics.R` (run with
  `env = new.env(parent = asNamespace("gllvmTMB"))`), `test-example-morphometrics.R`,
  `test-example-behavioural-reaction-norm.R`, `test-example-covariance-edge-cases.R`
  — all pass.
- **False-positive sweep**: 7,200 fits, 12.0 CPU-hours. 0/551 false positives on
  healthy binomial fits; 96.3% detection (1,411/1,465) against the shipped rule's
  **0 of 1,465**.
- `rcmdcheck --as-cran`: *(see §5a)*
- `air format --check`: additions conform; pre-existing drift left alone.

## 6. Tests of the Tests

The new test was written **before** the fix and run against the unfixed build,
where it failed with exactly the defect under repair:

```
Expected `row$status` to equal "WARN".
`actual`:   "PASS"
`expected`: "WARN"
```

Every other test in the file passed at that point, so the failure was specific.
The test fixes prevalence at 0.6 — deliberately outside the extreme band — so it
cannot pass by the old path. Its two `weak_axis` assertions were added after the
knock-on in §8 was found, and fail if the advice reverts to "near-constant".
The pre-existing extreme-prevalence test is unchanged and still passes, which is
the evidence that nothing previously flagged stopped flagging.

## 7a. Issue Ledger

No issue opened or closed. The predecessor handover's `diagnose.R:464` item, listed
`CARRIED OVER — not started`, is now complete pending review.

## 8. Consistency Audit

- **Found and fixed a knock-on the change introduced.** `binomial_warn` is consumed
  at `R/diagnose.R:853` to steer the `weak_axis_*` action. Once a moderate-prevalence
  runaway sets it, a reader was advised about a "high-loading near-constant binary
  trait" for a trait at prevalence 0.617 — the wrong diagnosis. The row now reports
  which path fired and the advice follows it.
- Swept every test file referencing `check_gllvmTMB` (6 files); all pass.
- Confirmed `.gllvmTMB_max_loading_by_trait()` cannot produce `Inf`/`NaN` ratios:
  the denominator is built from strictly positive finite values, falls back to the
  single value when only one qualifies, and yields `NA` otherwise — which
  `is.finite()` screens. So the new term cannot fire on a degenerate denominator.
- Confirmed mixed-family stacked fits are not reachable through the public API
  (`family` takes one family object), so the cross-family denominator
  contamination this row could otherwise suffer does not arise in practice.
- Confirmed `NAMESPACE` unchanged and only `check_gllvmTMB.Rd` regenerated.
- Confirmed `^dev$` is in `.Rbuildignore`, so the sweep artifacts do not reach the
  tarball.

## 9. What Did Not Go Smoothly

**Five errors by the author, four found by review and one by verification. One
root cause: a summary was trusted over the primary artifact.**

1. **"The old rule fired on 0 of 1,465 — it is inert."** The DGP made
   `extreme_prevalence` unreachable (prevalence spans only [0.20, 0.807] across
   all 3,944 binomial fits), so the zero was **forced by the design** and
   deducible from the code without simulating. The defensible claim — the gate
   keys on a quantity the pathology does not move, `r = 0.036` — is stronger,
   but it is not what was written. *Found by Rose.*
2. **"Mixed-family fits aren't reachable through the public API."** `family`
   accepts a list (`R/gllvmTMB.R:869`, `R/fit-multi.R:505-526`;
   `R/data-mixed-family.R` has `family_list`). Claimed from the `@param` prose
   without reading the code path. The pooled-denominator gap was real.
   *Found by the statistical reviewer.*
3. **Shipped advice pointing at a function that cannot help.**
   `suggest_lambda_constraint()` was named as a source of "a boundary
   constraint"; it pins entries to zero for *rotational identification*
   (`R/suggest-lambda-constraint.R:263`), and zeroing `λ_t1` on a separating row
   relocates the divergence to `λ_t2`. Written from a design-doc mention. It
   also **contradicted** the `weak_axis_*` string added in the same change.
4. **"Prevention is a separate arc."** The remedy already ships:
   `gllvmTMBcontrol(aghq_ridge = 2)` takes this exact reproduction fit from
   **‖Λ‖_F = 979.1 to 3.352**, on the Laplace path. The brain held a note two
   days old with the mechanism, the elimination chain and the remedy. The
   prior-work sweep *ran and passed* — it queried the plan's vocabulary
   ("diagnostic efficacy audit") rather than the phenomenon's ("Heywood",
   "runaway", "ridge").
5. **A name collision that a passing test hid.** The stratification argument was
   first called `keep`, colliding with a local `keep` in the merge loop above
   (`R/diagnose.R:340`). The parameter was silently overwritten and the
   denominator collapsed to the *first trait's* loading for every fit — a worse
   defect than the one being fixed. **The new test passed anyway** (12/0.25 = 48
   clears 25 by accident). Found only by checking the test *fails* against the
   unfixed behaviour. Renamed `reference_traits`.

Ordinary friction:

- The first sweep design used homogeneous loadings only and would have licensed a
  threshold as low as 8. It was the *sparse* data-generating processes — added
  after reasoning about where a ratio statistic must break — that exposed the
  healthy tail at 12.07 and made the calibration honest. A family-stratified sweep
  alone, which is what the handover literally asked for, would have missed it.
- 376 of 7,200 fits (5.2%) failed with `All 1 restarts failed.`, all binomial.
  Excluded from every rate. They are loud failures a user would see, not silent ones.
- Building the package into the same library the running sweep was reading from
  would have been a race; a second library was used instead.
- `R CMD INSTALL -l` into a directory that does not yet exist fails silently enough
  to look like a dependency error. Cost one cycle.

## 10. Known Residuals

- **54 of 1,465 degenerate fits remain unflagged**, and 1% of degenerate fits have
  `rl_max` below 1.30 — their loadings did not run away, so a runaway-loading gate
  structurally cannot see them. This targets Heywood cases, not poor recovery generally.
- **The threshold is binomial-only and must stay that way.** At tau = 25, healthy
  *sparse* fits in other families would be flagged at 14.7% (poisson) and 3.0%
  (gaussian). The row is binomial-only by construction so shipped behaviour is
  unaffected, but the number must not be reused elsewhere.
- **Non-binomial degenerate loadings still have no screen.** Pre-existing, and
  accepted knowingly in `docs/design/vgh-phase4-eda-surface-design.md` §7.
- This is an **API change** to an exported function. Additive, appended,
  behaviour-preserving for every existing flagged case — but high-risk under
  `CLAUDE.md`, so **not self-merged**.

## 10a. The limit found last, and it is the important one

**A within-fit ratio degrades from the halfway mark, not only at the limit.** In
an over-specified-rank run (binomial, truth `q = 2`, fitted `d = 3`) the shipped
threshold missed **3 of 8** degenerate fits, and they were the three worst
(`rel_frob` 7,491 / 5,272 / 2,775); one was missed even at `>= 8`. With 3 of 6
traits inflated, the robust centre in the denominator straddles both groups and
is itself inflated. Users routinely guess the rank, so this is not an exotic
regime. **The 96.3% figure is a true-rank, single-family number.**

The instrument for that case is a *scale* statistic, not a ratio — and
`communality > 1`, the literal Heywood criterion, is already computed at
`R/extractors.R:201` and wired into no check row at all. That is the next arc,
and it is free.

## 11. Team Learning

**A ratio statistic's transport risk lives in its denominator, not in its units.**
The handover predicted the threshold would fail to transport *across families*,
reasoning from bounded versus unbounded response variance. That framing pointed at
the wrong axis: `relative_loading` is already a within-fit ratio, so the response
scale cancels. What actually moved the null distribution by a factor of three was
the **sparsity of the true loading structure**, which collapses the median in the
denominator — and it moves it within a single family. When calibrating any
normalised statistic, sweep the thing the normaliser is estimated from, not just
the thing the units come from.

**Corollary, and the reason this lane did not ship the tempting rule:** the best
operating point on paper (`runaway & saturated`, tau = 8) was rejected because half
of it was evaluated on a quantity the sweep did not measure across all traits. A
better number on partially-measured evidence is worse than a slightly weaker number
on fully-measured evidence, for something that ships in an exported diagnostic.

**The second lesson, and it is the one worth carrying to every lane: query the
PHENOMENON, not the PLAN.** The ultra-plan prior-work sweep is a default-closed
gate, it was run, and it *passed* — while the brain held a note two days old
containing this pathology's mechanism, its elimination chain, its shipped remedy
and its citation. The sweep asked *"has anyone audited diagnostic efficacy?"*
(true answer: no) instead of *"what do we know about loading runaways, Heywood
cases, improper solutions, separation, ridges?"* (answer: nearly everything).
**A receipt can pass and still be vacuous.** Before scoping, search the thing
that is going wrong — in its own domain vocabulary, in the field's standard term,
**and under the remedy's name**, because an existing fix is filed under the fix
and never under the bug. Filed as
`~/shinichi-brain/memory/Query the PHENOMENON, not the PLAN …`.

**The third: a test that passes proves nothing until it has been shown to fail
against the defect it targets.** Item 5 in §9 is the whole argument — a silent
name collision that broke the denominator for *every* fit sat behind a green
test, and only the deliberate "does this fail without the fix?" check exposed it.

## 12. Cross-Product Coverage

What this lane's evidence does **not** cover, stated as negative space:

| Dimension | Swept | Not swept |
|---|---|---|
| Link | logit | **probit, cloglog** — in scope of the row (`family_id == 1`), never exercised |
| Binomial shape | Bernoulli (`n_trials = 1`) | **multi-trial / `cbind(succ, fail)` / `betabinomial`** — the row divides by `sum(trials)`, untested here |
| Traits `p` | 5, 12, 25 | **p > 25**, where the healthy tail is rising (§5.2) — the main reason for the 2.07x margin |
| Units `n` | 60, 150, 400 | n < 60, n > 400 |
| Rank `q` | 2, 3, 5 | q > 5 |
| Loading structure | homogeneous, 50% sparse, 75% sparse | genuinely blocked/clustered structures; all-weak (no latent signal) fits |
| Latent tier | `latent()` / `Lambda_B` | **`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`** — `.gllvmTMB_max_loading_by_trait()` pools across every latent spec present, so multi-tier fits change the denominator and were not swept |
| Missingness | complete data | incomplete responses |
| Families for the gate | binomial | others measured but **excluded by design**, with the FPR that would result recorded in §5.4 |

The multi-tier row is the most substantive gap. `.gllvmTMB_max_loading_by_trait()`
takes, per trait, the largest loading across *every* latent spec present, then
divides by the median of those. If both tiers load all traits comparably the
larger tier simply dominates uniformly and the ratio is unaffected. The exposure
is a fit where different traits get their maximum from different tiers at
different scales — a trait loading only on a small-scale `phylo_latent()` sits in
the denominator's weak group while a trait loading on `latent()` sits far above it.
**That is the same denominator-collapse mechanism the `sparse*` runs cover**, so
it is not a new failure mode; what is unmeasured is whether a real multi-tier fit
produces heterogeneity worse than `sparse75`, which is the case the 2.07x margin
was sized against. Testing it needs a phylogeny fixture and was out of scope here.
