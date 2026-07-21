# Known-residuals register

A standing, durable record of every accepted deviation between what this package
does and what a clean run would look like — failing or skipped tests, doc-code
gaps, and capability shortfalls that were **acknowledged rather than fixed**.

## The rule this register exists to enforce

**No exception is self-granted** (maintainer decision, 2026-07-21). An agent may
repair a defect its own arc caused. It may **not** decide, on its own judgment,
that a pre-existing failure is acceptable. Every row below is either:

- `AWAITING SIGN-OFF` — surfaced with evidence, no decision yet. **A row in this
  state blocks the arc's closing claim.**
- `SIGNED OFF` — the maintainer accepted it, with a date and a reason.
- `RESOLVED` — repaired or otherwise closed; retained for the audit trail.

An arc that closes with `AWAITING SIGN-OFF` rows must say so explicitly in its
closing claim. Silence is not acceptance.

**This register is public.** The repository is public and this file ships in git
(though not in the CRAN tarball). It is written on the assumption that a user or
CRAN reviewer may read it, so entries state facts and consequences plainly rather
than minimising them.

---

## Open — awaiting maintainer sign-off

### R-1 · testthat WARNING in the visual-snapshot suite

| | |
|---|---|
| **Class** | Test-fixture artifact; not a defect in package logic |
| **Surfaces as** | `FAIL 0 \| WARN 1` in the complete non-heavy suite |
| **Location** | `tests/testthat/test-plot-visual-snapshots.R:253:3`, warning emitted at `R/extract-sigma.R:382` |
| **Message** | `Link-scale residual variance is unavailable for trait(s): T1, T2, T3, T4. Returning NA rather than substituting a finite value.` |
| **Causation** | **PRE-EXISTING — verified.** Fires identically at `origin/main` (`de211f76`) and at branch HEAD (`2d9fd54c`), via a byte-identical code path. Only the backtrace line number differs, from unrelated edits above it. |
| **Mechanism** | `make_snapshot_ordination_fit()` builds a synthetic `gllvmTMB_multi` with no `tmb_data`, so `link_residual_per_trait()` finds no trait rows and **deliberately returns `NA` rather than fabricating a finite residual variance**, then warns. The two enclosing `suppressMessages()` calls do not catch `warning()` conditions, so testthat records it. |
| **Assessment** | The package behaves **correctly** — refusing to invent a value is the honest branch. The fixture is incomplete, not the code. |
| **Decision** | 2026-07-21, maintainer: **option (b)** — assert it with `expect_warning()`, documenting it as intended behaviour. |
| **Resolution** | Implemented at `test-plot-visual-snapshots.R:253`. Note a testthat 3e gotcha hit during the fix: `expect_warning()` returns the **caught condition**, not the expression's value, so the plot object must be assigned *inside* the call — otherwise vdiffr snapshots the warning object instead of the plot. Verified: `FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 33`, no snapshot churn. |
| **Status** | `RESOLVED` (2026-07-21) — suite is now WARN 0 for this file, with the behaviour asserted rather than escaping. |

### R-2 · Upward bias in phylogenetic slope-variance recovery under binomial-logit

| | |
|---|---|
| **Class** | **Estimator limitation** — NOT a test-fixture gap. Reclassified 2026-07-21 after scoping. |
| **Location** | `tests/testthat/test-phylo-unique-slope-binomial-logit.R:236:3` (skipped) |
| **Finding** | `sigma^2_slope` is systematically **over-estimated by roughly 50–60%** under the logit link. Evidence recorded in the test file: **21 seeds across three sample sizes all fail** — `n_id = 60` (10 seeds, best rel. err 0.38), `n_id = 120` (6 seeds, best 0.61 despite `sigma^2_int` rel. err 0.003 and `rho` err 0.06), `n_id = 240` (5 seeds, systematic 50–60% over-estimate). |
| **Why it is not noise** | The bias **does not diminish with sample size** — 60, 120 and 240 all fail. Fits are healthy throughout (`convergence == 0`, `pd_hessian == TRUE`, `sdreport_ok == TRUE`), so this is not a convergence or parser problem. |
| **Root cause** | **Information starvation per cluster.** With `n_rep = 4` and `n_traits = 3` there are 12 single-Bernoulli observations per species over 4 distinct `x` values, so the sampling variance of a per-species slope is roughly `(pi^2/3) / 12 ~= 0.27` — against a true between-species slope variance of `0.30`. Roughly half the spread in the estimated slopes is sampling noise; a partially-correcting estimator therefore returns an inflated variance. Uncorrected that predicts ~90% inflation; observed 50–78% sits between that and full correction. **Correction 2026-07-21:** an earlier draft of this entry framed it as a "1:11 signal-to-noise ratio" of `0.3` against `pi^2/3 = 3.29`. That was a category error — those are variances at *different levels* (between-cluster vs within-observation) and are not a ratio. The level-1 residual matters only via the *sampling variance of the per-cluster slope estimate*, as computed above. |
| **Re-measured on the current engine (2026-07-21)** | `sigma^2_int` rel. err **0.82**; `sigma^2_slope` **0.78**; `rho` **0.367**. Re-measured because the historical figures dated from 2026-07-06, **before** the 2026-07-20 slope-engine rework (`6e46a24a`, 357 lines of `R/fit-multi.R`) — a limitation must not be documented against code that no longer exists. |
| **Control: NOT an engine defect** | The identical fixture design **recovers cleanly under Gaussian** — `test-phylo-unique-slope-gaussian.R` passes `FAIL 0 \| SKIP 0 \| PASS 27` under heavy on this exact head. Same engine, same design, more information per observation. This rules out a regression from the slope rework. |
| **Structural identifiability is MET** | The fixture has 4 distinct `x` values per species, so it clears the "≥2 distinct `x` within cluster" bar (see R-6). The failure is *statistical information*, not *structural identifiability* — the two must not be conflated. |
| **⚠ Cross-repo anomaly (UNVERIFIED)** | The established, oracle-validated cross-repo finding is that small-cluster non-Gaussian variance components under ML-Laplace are biased **LOW** (drmTMB cumulative_logit: −7.3%, validated vs glmmTMB/glmer/lme4; see the vault note *Two-lever fix for small-cluster non-Gaussian variance-component bias*). **Our bias is UPWARD.** That is an opposite sign, not a larger magnitude. An initial conjecture that the bias *flips sign* at low per-cluster information was **REFUTED the same day** against drmTMB's retained artifacts (`2026-07-12-laplace-vs-aghq/laplace-vs-aghq.tsv`, M=40, single-trial Bernoulli, 80 seeds, `glmer` oracle): as information falls the bias goes **monotonically more negative** (+0.32%, −9.88%, −13.68%, −23.14% at `n_each` = 20/8/4/2), and drmTMB tracks the oracle to four decimals. On that same metric the gllvmTMB cell sits *inside* the measured downward region, yet measures upward. **The anomaly is real; low information is not the explanation.** Leading remaining candidate: drmTMB's sweep is a random **intercept**, whereas this cell is a **correlated `(1 + x \| species)` intercept+slope 2×2 block** (`rho = 0.5`) — a structure drmTMB has never measured. Full adjudication in the vault note *Information starvation and blocked variance-component cells — cross-repo adjudication*. |
| **Rejected "fix"** | The file proposes raising the true `sigma^2_slope` from `0.3` to `0.6` — its own comment flags this as *"a DGP truth change, separate from tolerance change"*. That would make the test pass by selecting, after seeing the failures, a parameter regime where a known bias is less visible. **Rejected as evidence-shopping**, consistent with the file's own standing discipline: *do NOT widen tolerances; do NOT fake-pass.* |
| **Decision** | 2026-07-21, maintainer: **document the bias and keep the test skipped.** Do not chase a passing fixture. |
| **Obligation this creates** | The limitation must be stated in user-facing documentation, not merely left as a silent skip. Recorded in `NEWS.md`. |
| **Status** | `SIGNED OFF` (2026-07-21) — as a **declared estimator limitation**, not as a passing test. Recovery for this cell remains unverified, and 0.6 must not claim otherwise. |

### R-3 · Sigma-rename test pending an internal migration

| | |
|---|---|
| **Class** | Deferred work, explicitly parked |
| **Location** | `tests/testthat/test-sigma-rename.R:110:3` |
| **Skip reason** | `Skipped pending migration to gllvmTMB:::.normalise_level().` |
| **Assessment** | "Pending migration" is unfinished work. Real parked debt — and purely mechanical: the block called the unexported `.normalise_level()` by bare name, which testthat 3 does not put on the test environment's search path, so it fails under `R CMD check`. |
| **Decision** | 2026-07-21, maintainer: **fix it.** |
| **Resolution** | Migrated: the block now binds `normalise_level <- gllvmTMB:::.normalise_level` once and uses it throughout (9 call sites), and the `skip()` is removed. Verified: `FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 33` across this file and the snapshot file. |
| **Status** | `RESOLVED` (2026-07-21) — the assertions now run instead of being skipped. |

### R-4 · Cross-validation coverage can silently lapse on unlucky draws

| | |
|---|---|
| **Class** | Fragile test guard — coverage gap, not a failure |
| **Locations** | `tests/testthat/test-stage2-rr-diag.R:109:3`, `tests/testthat/test-stage3-propto-equalto.R:177:3` |
| **Skip reasons** | `glmmTMB hit non-PD Hessian on this dataset` / `... on combined model` |
| **Assessment** | These are deliberate `skip_if()` guards: gllvmTMB's own fit is always checked, and the skip fires only when the **reference `glmmTMB` cross-check** fails numerically. The design is defensive and reasonable, but the consequence is that cross-validation against the reference implementation **silently disappears** on an unlucky random draw, with no signal that verification was weaker than usual. |
| **Correction to the original framing** | The review described these as lapsing on "unlucky draws". They do not: the datasets are **seeded** (`seed = 7` at the stage-2 site), so the outcome is **deterministic per environment** — if the guard fires, it fires on every run on that platform. It is a standing coverage gap, not an occasional one. On this machine it **does** fire, so the cross-implementation comparison is currently not running here at all. |
| **Decision** | 2026-07-21, maintainer: **fix it** — make the lapse explicit rather than silent. |
| **Resolution** | Both skip messages now state exactly what is forfeited: the gllvmTMB-side assertions (convergence, active tiers, `Lambda_B` dimensions) have already run and hold; only the **cross-implementation logLik agreement** is lost. Each references this register. Applied at `test-stage2-rr-diag.R:109` and `test-stage3-propto-equalto.R:177`. The underlying `glmmTMB` non-convergence is upstream and is not fixed — deliberately not "fixed" by reseeding, since choosing a dataset where the reference happens to converge risks selecting on the outcome. |
| **Status** | `RESOLVED as far as this package can` (2026-07-21) — the gap is now self-declaring. The upstream convergence failure remains and is not gllvmTMB's to fix. |

### R-6 · No structural guard on random-slope identifiability

| | |
|---|---|
| **Class** | Missing typed refusal — capability-honesty gap. Raised by the maintainer 2026-07-21. |
| **The principle** | A random slope of `x` within cluster `g` requires **within-cluster variation in `x`**. A cluster contributes to the slope variance only if it has **≥2 distinct `x` values** (≥3 in practice, since 2 points determine a slope with zero residual df). If `x` is a cluster-level covariate — constant within `g` — the random slope is confounded with the intercept and is **not identifiable at any sample size**. This is an aggregate requirement, not strictly per-cluster: mixed models partially pool, so single-observation clusters simply contribute nothing to the slope variance. |
| **Why tier names do not settle it** | Identifiability is a property of the **data**, not of which tier is named. `R/fit-multi.R:803-815` refuses augmented slopes when `groupings == unit_obs` — a **name-based** check. If `unit` is itself the lowest level (one row per unit per trait), or if `x` is constant within `unit`, a `unit`-tier slope is equally unidentifiable and **nothing refuses it**. |
| **Evidence** | No guard found on within-group `x` variation or per-cluster replication for slope terms. The concept exists elsewhere in the codebase but is not wired to slopes: `R/fit-multi.R:570-580` counts *distinct observation units per species* for `kernel_unique`, explicitly noting that "counting raw rows would mistake trait-stacking for replication". |
| **Necessary vs sufficient** | The condition is **necessary, not sufficient**. The Phase-B2 logit fixture (R-2) *satisfies* it — 4 distinct `x` per species — and still fails, because single-trial binary observations carry too little information. The identical design recovers cleanly under Gaussian. Keep the two conditions separate: **structural identifiability** (distinct `x` within cluster) versus **statistical information** (enough signal per cluster to beat sampling noise). |
| **Impact** | Not a 0.6 blocker — an unidentifiable specification will typically fail to converge rather than return a confident wrong answer. But a mysterious non-convergence is a poor user experience compared with a typed refusal naming the actual problem. |
| **Recommended for 0.7** | Add a structural check at slope-term construction: for each augmented slope term, count distinct `x` values within each grouping level and refuse (typed) when no level has ≥2, warn when few do. Mirror the honest replication counting already used for `kernel_unique`. |
| **Decision** | 2026-07-21, maintainer: **defer the guard to 0.7.** Signed off as a recorded capability gap. |
| **Status** | `SIGNED OFF` (2026-07-21) — deferred to 0.7. Not a defect in current results; an unidentifiable specification fails to converge rather than returning a confident wrong answer, so the cost is a poor error message, not a wrong number. |

### R-7 · Eight pre-existing warnings in the heavy suite

| | |
|---|---|
| **Class** | Pre-existing test warnings, surfaced only under `GLLVMTMB_HEAVY_TESTS=1` |
| **Surfaces as** | `FAIL 0 \| WARN 8 \| SKIP 102 \| PASS 13647` in the Ubuntu-heavy CI run |
| **Why it went unseen locally** | The complete local suite is **non-heavy**, and the local heavy run was filtered to the four touched groups. These sites are heavy-gated, so no local run reached them. `R CMD check` also fails its tests step only on **error**, so eight testthat warnings sit invisibly behind `Status: OK`. |
| **Sites — all eight now identified** | 1–4. `test-loading-ci-bootstrap.R` :60, :84, :105, :171 — all four emitted from `R/loading-ci-bootstrap.R:287`, so likely **one defect presenting four times**, not four defects · 5. `test-matrix-nbinom2-spatial.R:258` · 6. `test-missing-response-gaussian.R:192` (from `R/predictive-diagnostics.R:377`) · 7. `test-phylo-signal-ci.R:197` (from `R/phylo-signal-ci.R:471`) · 8. `test-tweedie-recovery.R:51` (from `R/methods-gllvmTMB.R:1098`) |
| **Causation — EXACT SET MATCH, not a count delta** | Site-by-site comparison against the previous heavy run on this branch at predecessor `c6e1dd8a`: sites present in the predecessor but **not** now = `test-plot-visual-snapshots.R:253:3` **and nothing else** — exactly the warning R-1 fixed. Sites present now but **not** in the predecessor = **none**. So this arc removed precisely one warning site and **introduced none**. (An earlier version of this row offered only the aggregate delta `WARN 9 -> 8`; the set comparison supersedes it and is strictly stronger.) |
| **Note on site 8** | `test-tweedie-recovery.R:51` emits from `R/methods-gllvmTMB.R:1098` — the `simulate()` conditional-fallback warning whose **text this arc rewrote** (see R-5). The site and the count are unchanged; only the message content differs, now stating that simulate-based intervals for that fit are too narrow. That is the intended user-protective behaviour firing in a real test, not a new warning. |
| **Remaining limit of the evidence** | The set match establishes that no site was added and one was removed. It does **not** independently diagnose the eight underlying causes. |
| **DIAGNOSIS (2026-07-21) — none of these is a defect** | Seven of eight traced to source. **All are the package correctly warning about a degraded condition, not misbehaving.** This reclassifies what a sign-off means: the question is not "waive eight bugs" but "accept that these conditions occur in the test suite." <br><br>**(a) Four × `loading-ci-bootstrap.R:287`** — a deliberate honesty warning that *N* of *M* bootstrap refits failed or were rejected and are excluded, with intervals computed from the survivors. Its own comment states it exists "so intervals built from a small surviving fraction are not mistaken for fully reliable ones", and it mirrors `.phylo_signal_bootstrap_ci`. Working as designed. The open question is the *refit failure rate* in those fixtures, not the warning. <br><br>**(b) One × `predictive-diagnostics.R:377`** — a **typed** condition (`gllvmTMB_conditional_residual_saturated`) stating that exact conditional Gaussian residuals are uninformative when a diagonal random effect is indexed at trait-cell resolution, and naming the alternative (`type = "simulation_rank"`, `condition_on_RE = FALSE`). Working as designed, with actionable advice. <br><br>**(c) Two × `test-phylo-signal-ci.R:197` and `test-tweedie-recovery.R:51`** — both route through `stats::simulate()` and emit the unconditional-redraw **fallback** warning from `R/methods-gllvmTMB.R:1098`. These are **R-5's documented capability gap surfacing in the heavy suite**, which is corroboration that the too-narrow-interval limitation is real and reachable rather than theoretical. <br><br>**(d) One × `test-matrix-nbinom2-spatial.R:258`** — **not yet traced.** Remaining work. |
| **Status** | `AWAITING SIGN-OFF` — surfaced with evidence, not waived. All eight sites are named (see the Sites row); each still needs an individual decision, and the four `loading-ci-bootstrap` sites should be triaged together given their shared source line. |

---

## Resolved

### R-5 · `simulate()` documented an unconditional redraw it does not perform

| | |
|---|---|
| **Class** | Doc-code mismatch on an exported method |
| **Location** | `R/methods-gllvmTMB.R` — `@param condition_on_RE` vs `.check_simulate_unconditional()` |
| **The gap** | The doc listed `phylo` and `spde` among tiers redrawn unconditionally. The implemented set is `rr_B, diag_B, rr_W, diag_W, propto, lv_B, phylo_rr, diag_species` — **`spde` and `phylo_diag` are absent** and fall back to conditional simulation with a one-shot warning. |
| **User consequence** | Conditional simulation reuses fitted RE modes, understating between-unit variability, so simulate-based intervals for such fits (e.g. `bootstrap_Sigma()`) are **too narrow** — the false-precision failure issue #750 was opened to fix. |
| **Related** | The #750 spatial redraw commits `dd80244a`..`051eb4e5` **exist but are not in `origin/main` nor in this release branch** — they live on `claude/profile-coverage-remeasure-20260718` and other parked branches. The phylo half (`phylo_rr`) did land here; the spatial half did not. **No documentation is wrong about this.** An earlier draft of this register asserted that `CLAUDE.md` carried a false "SHIPPED" claim; that was itself mistaken. The claim appears in the *primary checkout's* `CLAUDE.md`, which is checked out on `claude/profile-coverage-remeasure-20260718` — the same branch that holds the commits — so it is **true there**. The release branch carries neither the claim nor the code, which is likewise consistent. The apparent contradiction came from reading `CLAUDE.md` from one branch while working in another. |
| **Resolution** | 2026-07-21, maintainer: **fix the doc to match the code; retarget #750 to 0.7.** The stranded work was deliberately NOT merged, to avoid touching the quarantined branch estate and re-minting M1's source identity. The `@param` text now names the handled tiers and states the too-narrow-intervals consequence; the fallback warning now says why it matters instead of only how to silence it; a stale internal comment listing the handled set was corrected. |
| **Status** | `RESOLVED` (2026-07-21, **second pass**). The first resolution was **incomplete and closed prematurely**: it corrected `?simulate`'s `@param` but left two other surfaces stating the opposite — `bootstrap_Sigma()`'s Caveats claimed the simulator "conditions on the fitted random effects", and `simulate.gllvmTMB_multi`'s `\description{}` still described the non-default `condition_on_RE = TRUE` branch and a Gaussian-only residual. A second D-43 panel caught both. Now fixed at source and regenerated: `bootstrap_Sigma()` states that redraw is the default, that it is not implemented for the SPDE spatial and diagonal phylogenetic tiers, and that intervals for such fits are **not calibrated**; `?simulate`'s description documents the actual default. **Lesson recorded: fixing the parameter you are looking at is not fixing the page.** The capability gap itself remains, honestly documented. |

---

> Related: `LOOP/GOAL.md` (maintainer amendment, 2026-07-21) · `docs/dev-log/2026-07-21-eva-cut-to-0.7.md` · `LOOP/decision-queue.md`
