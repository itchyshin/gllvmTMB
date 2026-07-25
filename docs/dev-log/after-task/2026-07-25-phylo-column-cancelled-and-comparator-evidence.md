# After Task: Site × Species phylo lane — capability CANCELLED, comparator + validation evidence landed

Date: 2026-07-25 · Author: Claude · Lane origin: `claude/phylo-column-20260725`

## 1. Goal

Open the Site × Species phylogeny capability lane per the 2026-07-25 handover Part II §II.4,
ultra-plan it, and execute. The framing goal was credibility with Bolker, van der Veen/Warton, and
Hadfield — which the board already scores as an **evidence** gap, not a capability gap. The
capability half was **cancelled by the maintainer mid-arc** once evidence showed the existing
transposition workaround is sound and the column-axis keyword that *does* work actively misleads.
The evidence half was completed and extended.

## 2. Implemented

**Capability: CANCELLED, not built.** No new API, no new export, no likelihood change. The M3
freeze (`NAMESPACE c97ae039`) is untouched.

**What is now true that was not before:**

- The package **refuses or warns** when a supplied phylogenetic tree cannot enter the likelihood.
  Previously a user could fit a "phylogenetic JSDM" containing no phylogeny, with large fitted
  phylogenetic variances, and no diagnostic at all.
- `phylo_scalar()` / `phylo_indep(common = TRUE)` **accept an in-keyword `tree =`**. They
  previously aborted with a false "phylo_vcv is NULL" even when a valid tree was supplied.
- The test suite contains **the first `gllvm` model fit in its history** — Poisson ordination and
  binary GLLVM. The direct competitor was entirely unmeasured before today.
- The `NEWS.md` claim about `*_unique()` slope semantics is **verified by experiment** rather than
  asserted.
- nbinom1 on the phylo and spatial tiers has **canonical-spelling coverage**; it was previously
  reachable only through the soft-deprecated `*_unique()` path.
- `phylo_dep()` in the Site × Species layout is documented as **systematically preferring wrong
  trees** (0/20 replicates), with both controls clean.

## 3. Files Changed

Six branches, none merged to `main` at time of writing.

| Branch | Commit | Files |
|---|---|---|
| `claude/phylo-column-20260725` | `c7fd356d` (pushed) | `docs/dev-log/2026-07-25-phylo-column-ultra-plan.md`; `dev/s0-rederive-two-tree.R{,-RESULTS.md}`; `dev/s2-gllvm-colmat-reference.R{,-RESULTS.md}` |
| ” | this report | `docs/dev-log/after-task/2026-07-25-phylo-column-cancelled-and-comparator-evidence.md` |
| `claude/gllvm-comparator-20260725` | `67cc5a13` | `tests/testthat/test-comparator-gllvm.R` (new); `dev/s7-gllvm-comparator-RESULTS.md` |
| `claude/phylo-validation-fixes-20260725` | `a1b9b23e` | **`R/fit-multi.R`** (+103/−19); `tests/testthat/test-phylo-tree-unused-guard.R` (new); `dev/s1-phylo-validation-fixes-RESULTS.md` |
| `claude/slope-semantics-evidence-20260725` | `83e6b1c4` | `tests/testthat/test-unique-indep-slope-semantics.R` (new); `tests/testthat/test-tiers-nbinom1-canonical-twins.R` (new); `dev/s8-slope-semantics-RESULTS.md` |
| `claude/comparator-binary-20260725` | `9c111a5a` | `tests/testthat/test-comparator-gllvm.R` (extended); `dev/s9-binary-comparator-RESULTS.md` |
| `claude/phylodep-seed-replication-20260725` | `2d78712e` | `dev/s10-phylodep-seed-replication.R{,-RESULTS.md}` |

**Status-inventory cascade — deliberately NOT touched:** `README`, `NEWS.md`, `ROADMAP.md`,
`DESCRIPTION`, `NAMESPACE`, `man/*.Rd`, all vignettes, `docs/design/05-testing-strategy.md`, and
`docs/design/35-validation-debt-register.md`. Rationale in §3a. `R/fit-multi.R` is the only
non-test source file in the whole arc.

## 3a. Decisions and Rejected Alternatives

> **Decision**: Cancel the Site × Species capability.
> **Rationale**: Maintainer call, on evidence produced in-lane. The transposition workaround is
> verified here (E3 positive control: true tree −8.730365 vs wrong −28.430023 under the stricter
> true-tree-wins criterion), and the keyword that *does* reach the column axis (`phylo_dep`) was
> then shown to prefer wrong trees 20/20. Building new API against a signed freeze to avoid a data
> transposition is a poor trade.
> **Rejected alternative**: a top-level tree argument (decided in-lane, then superseded by the
> cancellation).
> **Confidence**: high.

> **Decision**: Column-axis phylogeny would have entered as a **top-level argument**, not formula
> syntax, and `phylo_*()` would have stayed unit-axis only.
> **Rationale**: Maintainer's reasoning — a formula describes how **predictors** act; correlation
> among response columns is a standing fact about the response set. Recorded because it survives
> the cancellation and should not be re-litigated from scratch.
> **Rejected alternative**: an axis argument on `phylo_*()`, a new `phylo_col_*()` quartet, and a
> `traits()`-LHS spelling (rejected: cannot express the model in long format, the canonical shape).
> **Confidence**: high on the reasoning; the decision is now moot.

> **Decision**: Bug 1(b) warns rather than aborts.
> **Rationale**: A structurally-unreachable phylo term still produces a real, well-identified fit;
> aborting would break legitimate use. Guard deliberately narrow — tests assert it does NOT fire
> for `phylo_dep()` in the identical layout, nor for `unit = species`.
> **Rejected alternative**: abort for both sub-cases.
> **Confidence**: medium-high. Worth revisiting if users report the warning is too quiet for the
> severity (a silent no-phylogeny publication is a serious outcome).

> **Decision**: Do not promote any validation-debt or testing-strategy row.
> **Rationale**: Row promotion is a maintainer act. The binary comparator supplies the evidence
> `05-testing-strategy.md:71` asks for, but this arc records evidence rather than grading itself.
> **Rejected alternative**: marking :71 `covered` (an agent initially claimed the Poisson work did
> so; it does not — that row specifies binary).
> **Confidence**: high.

> **Decision**: Upgrade the lane's evidence criterion from "the log-likelihood moved" to "the TRUE
> tree wins".
> **Rationale**: `phylo_dep()` passes the weaker test while ranking truth last. The source
> handover's criterion would have certified a misleading keyword as working.
> **Rejected alternative**: keeping the inherited criterion.
> **Confidence**: high. This is the most reusable output of the arc.

> **Decision**: Do not add explicit `trait =` to the arc's new test call sites.
> **Rationale**: See §6 — the documented rule and the suite's actual practice disagree by a wide
> margin; changing 21 call sites while leaving ~925 is churn that hides the real discrepancy.
> **Rejected alternative**: "fixing" the new files to match the doc.
> **Confidence**: medium — flagged for Rose rather than settled here.

> **Decision**: Leave the two wedged CI runs (`30158126939`, `30158115396`).
> **Rationale**: Maintainer call after `gh run cancel` failed HTTP 500 ×4 across two sessions and
> the force-cancel endpoint failed ×2. Wedged GitHub-side; queued, consuming no runner.
> **Rejected alternative**: deleting the run records (a hard delete; left to the maintainer).
> **Confidence**: high.

## 4. Checks Run

| Command | Outcome |
|---|---|
| `testthat::test_file("test-phylo-tree-unused-guard.R")` | **20 passed, 0 failed, 0 error, 0 warning, 0 skipped** |
| `devtools::test(filter = "phylo")` | **245 passed, 0 failed, 0 error, 102 skipped** (pre-existing heavy gates) |
| `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "phylo")` | **2615 passed, 0 failed, 0 error, 14 skipped, 1 warning** |
| `devtools::test(filter = "unique\|indep\|canonical")` | 33 files, 460 expectations, **0 failures**, 390 passed, 70 skipped |
| `testthat::test_file("test-comparator-gllvm.R")` (binary) | **6 passed, 0 failed** under `NOT_CRAN=true` |
| `devtools::test(filter = "gllvm\|phylo")` (comparator lane) | clean, 0 failures |
| `gh run cancel` ×4, force-cancel ×2 | **HTTP 500 every time** — wedged GitHub-side |

The **heavy** run is the load-bearing one: it exercises the recovery paths where an over-broad
guard would have fired. The single warning is the pre-existing unconditional-`simulate()`
RE-redraw limitation for `phylo_unique`, unrelated to this arc. The 14 skips are documented
convergence-based honest skips.

**Deliberately not run:** `devtools::check()` / `--as-cran`, `pkgdown::check_pkgdown()`,
`build_articles()`. No user-facing prose, roxygen, `NAMESPACE`, or `DESCRIPTION` changed, so
nothing in the pkgdown or Rd surface is affected. `GLLVMTMB_RUN_B2_LOGIT=1` was **not** set — that
gate is R-2's signed-off limitation and would fail for reasons unrelated to this arc.

## 5. Tests of the Tests

| Test | Rule satisfied | Bug it would have caught |
|---|---|---|
| `test-phylo-tree-unused-guard.R` — tree supplied, no consuming term | **failure-before-fix** | The silent no-op: a fit that looks phylogenetic and is not |
| ” — structurally unreachable `phylo_indep()` | **failure-before-fix** | The proven JSDM-layout no-op (identical logLik across 3 trees) |
| ” — `phylo_dep()` in the identical layout does NOT warn | **boundary** | An over-broad guard firing on a keyword that genuinely uses the tree |
| ” — legitimate `unit = species` does NOT warn | **boundary** | The guard breaking the working transposition route |
| ” — `propto` in-keyword `tree =` matches dense `vcv =` to 1e-8 | **failure-before-fix** | A fix that stops the abort without computing the right precision |
| `test-unique-indep-slope-semantics.R` | **feature-combination** | A future refactor silently aliasing the two slope paths, invalidating a NEWS claim |
| `test-tiers-nbinom1-canonical-twins.R` | **prophylactic** | Removal of `*_unique()` silently dropping nbinom1 phylo/spatial certification |
| `test-comparator-gllvm.R` (Poisson + binary) | **prophylactic** | Cross-package divergence from a refactor; no known bug today |

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `grep -c 'gllvmTMB('` vs `grep -c 'trait *= *"'` per new test file | **DISCREPANCY, not fixed** — see below |
| `gllvmTMB(` call sites across `tests/testthat/*.R` | 1122 calls in 266 files; **197 (18%)** pass an explicit `trait =`; 53 files (20%) |
| `traits(` LHS in new files | 0 — every new call site is long-format |
| new exports added | **0** — `NAMESPACE` untouched |
| `DESCRIPTION` changed | **no** — `gllvm` was already in `Suggests` |
| user-facing prose touched (`NEWS`, `README`, vignettes, roxygen) | **none** |

**The `trait =` discrepancy is a real finding and is deliberately left open.**
`10-after-task-protocol.md` requires every long-format `gllvmTMB()` call site to pass
`trait = "..."` explicitly (Option A uniform-naming, `01-formula-grammar.md`). Two of this arc's
new files omit it (14 and 7 call sites). But `trait = "trait"` is the **default**
(`R/gllvmTMB.R:436`), the files are correct, and **82% of the existing suite also omits it**.
Changing 21 call sites while leaving ~925 would hide the discrepancy rather than resolve it. The
documented rule and the codebase's actual practice disagree; that is Rose territory and a
maintainer decision, not something to paper over inside this arc.

Separately observed, pre-existing, not addressed: `vcv =` (soft-deprecated → `A =`/`Ainv =`) and
the deprecated global `phylo_tree =` appear across ~80 test files each.

## 7. Roadmap Tick

**N/A.** No `ROADMAP.md` row changed. The release rung stays **NOT READY**; nothing in this arc
was a release, freeze, tag, or submission action.

## 8. What Did Not Go Smoothly

- **A sub-agent returned a worthless completion report.** The validation-fix agent replied
  *"Good — clean, scoped changes. I'll wait for the background regression monitor"* — no files, no
  counts, no verdicts — and stopped without waiting. Its actual work was sound, but the state had
  to be re-derived from `git status`, the diff, and a fresh test run. **A structured output
  contract in the brief did not guarantee a structured return.** Verify from the repo, not the
  summary.
- **An agent over-claimed a register row.** The Poisson comparator was reported as closing
  `05-testing-strategy.md:71`; that row specifies **binary**. Caught by reading the row.
- **An agent used the wrong filename convention** (`test-gllvm-comparator.R` vs the documented
  `test-comparator-*.R`). Renamed.
- **The inherited handover contained a wrong prescription.** It blamed two prior failures on
  omitting `randomX = ~ env`; in gllvm 2.0.11 that argument is inert (`col.eff` stays `FALSE`,
  design matrix degenerate). Following the handover would have failed a third time. Re-running
  rather than inheriting is what caught it — a maintainer instruction, and it paid for itself.
- **Six failed CI cancellations** across two documented endpoints, plus one blocked by the local
  permission classifier. Unresolvable from this side.
- The first S0 formulation was **confounded** (collinear `0 + trait` + `phylo_indep()` drove the
  phylo variance to the zero boundary), producing "identical logLik" for a trivial reason that
  could not distinguish structural unreachability from nothing-left-to-explain. The agent caught
  this itself and re-ran deconfounded. Worth recording: **the naive version of this experiment
  gives the right answer for the wrong reason.**

## 9. Team Learning

**Fisher (inference).** The arc's central methodological output: *"the likelihood moved"* is not
evidence of correct tree sensitivity. `phylo_dep()` moves with the tree and ranks truth last, 0/20.
Discrimination tests need a **direction**, and a positive control to prove the instrument can see
a real effect — the transposed-layout arm (18/20) is what makes the 0/20 interpretable.

**Gauss (numerics).** The `propto` fix was verified by agreement with an independent route to 1e-8,
not by absence of an error. It reused `.gllvm_phylo_tree_precision()` and
`.resolve_sparse_propto_precision()` rather than adding numerical machinery — the sweep's reuse
finding paying off.

**Boole (API).** The strongest design contribution was the maintainer's, and it was a *refusal* to
put the tree in the formula: a formula describes how predictors act; response-column correlation is
not a predictor relationship. Recorded in §3a even though the capability was cancelled.

**Rose (consistency).** Three agent-introduced discrepancies caught by audit rather than by review
(over-claimed row, wrong filename, worthless report), plus the standing `trait =` doc-vs-practice
gap. Also: the naming audit's own recommendation — comment headers on 60 files — was declined as
churn; an audit's recommendations are input, not orders.

**Curie (testing).** The `phylo_indep` control arm (all 20 exactly tied, < 1e-4) did double duty:
it reconfirmed the structural no-op *and* proved the harness reports ties when ties are the truth.
A control that validates the instrument is worth more than one that only validates the hypothesis.

## 10. Known Limitations and Next Actions

**Not claimed, deliberately:**

- `phylo_dep()` wrong-tree preference is **one DGP, one n, one m, Gaussian**, wrong trees drawn as
  random topologies. Enough to retire "it was one draw"; **not** enough for a user-facing claim.
  Per D-43 a fresh adversarial panel is required before this reaches the register or any public
  surface. Nothing promoted.
- `05-testing-strategy.md:71` **stays `claimed (M2 work)`**. The binary evidence now exists
  (ρ = 0.9989 / 0.9996 against a 0.95 bar, 5-seed sweep, worst factor 0.9947); promotion is a
  maintainer act.
- The binary comparison needed **5× the Poisson sample size** and gllvm's `n.init = 3`. At gllvm's
  single-start default, 3/5 seeds hit a reproducible local-optimum/rank-collapse. Recorded as
  configuration evidence about the reference implementation's defaults, **not** as a capability
  claim about either package.

**Next actions:**

1. **Merge decision on `a1b9b23e`** — the only commit touching `R/`. Adds a user-facing error and
   warning; maintainer review per the high-risk merge rule.
2. **Vary species count *m*** on the `phylo_dep` replication. The aliasing hypothesis predicts the
   effect scales with the free m(m+1)/2 Σ; this is the cleanest test of the mechanism.
3. **D-43 panel** before any `phylo_dep` finding becomes a register row or public statement.
4. **Resolve the `trait =` doc-vs-practice discrepancy** (§6) — either relax the protocol or plan a
   suite-wide migration. Currently the documented rule is violated by 82% of the codebase.
5. **Consider whether Bug 1(b) should abort rather than warn.** A silently non-phylogenetic
   publication is a severe outcome for a warning.
6. Still open from the source handover and untouched here: the held calibration overclaim
   `a9ecd29f` (maintainer only), R-2 / Experiment B, the capstone metric-repair (separate fenced
   lane), and the uncommitted `CLAUDE.md` in the primary checkout.
