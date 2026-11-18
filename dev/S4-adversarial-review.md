# S4 — Adversarial review (Rose): random-slope surface lane

**Reviewer:** Rose (claims audit, fresh context)
**Date:** 2026-08-18
**Target:** `claude/rand-slope-surface-20260818` @ `eba7f6a4`, three commits off `origin/main`
**Method:** full read of `git diff origin/main...HEAD`; every register row, test file, C++ block
and cited document re-read at source, not through the producers' summaries.

**FINAL VERDICT: CHANGES REQUIRED** (2 required changes; see §5).

---

## Task 1 — Mechanical recheck of the five changed board cells — **PASS (5/5 licensed)**

Each new value was checked against the actual register row, read in
`docs/design/35-validation-debt-register.md`, not against the note's paraphrase.

| id | family | new board value | cited row | row read at source | verdict |
|---|---|---|---|---|---|
| 7 | Beta | `partial` | PHY-15 | line 238: `covered`; "at least 5/6 seeds must be healthy … pooled intercept/slope relative error at most 0.45" | **licensed** (note's paraphrase exact) |
| 4 | Gamma | `partial` | PHY-14 | line 237: `covered`; "at least 5/6 seeds … factor-4 band" | **licensed** (paraphrase exact) |
| 9 | student | `partial` + "C1 phylo_indep single-seed" | RE-14 | line 207: `partial` (C1 runtime admission only); "one adequate-N `phylo_indep(1 + x \| species)` seed per family"; explicitly NOT fixed-effect recovery / PD Hessian / per-trait / replicated seeds / interval calibration | **licensed**; annotation is the weakest honest reading |
| 3 | lognormal | `partial` + same annotation | RE-14 (+ FAM-11 line 162) | same; FAM-11: "one `phylo_indep(1 + x \| species)` seed and pooled slope-SD plausibility only" | **licensed** |
| 14 | ordinal_probit | `—` + "PHY-16: 3/6 converged PD-Hessian fits (min_good=4) — recovery not admissible" | PHY-16 | line 239: `partial`; "only 3/6 converged positive-definite-Hessian fits against `min_good = 4` and therefore deliberately skips recovery" | annotation is **verbatim-accurate to PHY-16**, but PHY-16 does not license the *cell* — see Task 2 |

Note that the four `partial` upgrades are, if anything, **under**-claims relative to the
register (Beta and Gamma sit on full `covered` rows and are shown as `partial`), which is
correct per the board's own capping policy.

**Untouched cells (ids 0/2/5/15):** confirmed. `git diff` for
`docs/dev-log/capability-surface.html` contains exactly five hunks, none touching the
gaussian (line 370), poisson/nbinom1/nbinom2 (line 384), binomial (391), betabinomial (398),
tweedie (419), truncated_* (440), multinomial (454) or delta/hurdle (461) rows.

**No `✓` created:** confirmed mechanically. `sed -n '360,470p' … | grep 'class="yes"'` shows
every `✓` in the per-family table sits in the columns *after* Rand. slope. All five changed
cells carry `tag t-avail` (`partial`) or the pre-existing `no` class. The maintainer's cap
holds.

**Collateral (Task 4 result, reported here for adjacency):** `git diff --name-only
origin/main...HEAD -- R/ src/ NEWS.md DESCRIPTION tests/` is **empty**. Eight files changed,
all under `dev/` and `docs/`. **PASS.**

---

## Task 2 — RULING: **(a) — ordinal_probit deserves `partial` too.**

### The principle that decides it

> **The board's Rand. slope cell is a FAMILY-scoped question, not a ROUTE-scoped one.**
> Because the column is capped at `partial` by maintainer decision, it is effectively binary:
> `—` means "this family has no admitted augmented-slope capability", `partial` means
> "admitted and unfinished". The correct decision rule — the only one that makes the five
> existing `partial` cells mutually coherent — is:
>
> **a family shows `partial` iff it is present in `.augmented_slope_family_contract()` AND at
> least one validation-register row records augmented-slope evidence above "none".**
>
> A single failing row on one route cannot pull the cell to `—` when other rows on other
> routes carry stronger evidence, any more than a single passing row could pull it to `✓`.

### Why ordinal clears that bar by a wide margin

The lane's own note justifies keeping ordinal at `—` on the grounds that "PHY-16's evidence
is weaker than the other four cells fixed here" (`dev/board-correction-notes.md`, ID 14
section). That comparison is **route-scoped against a family-scoped cell** — it compares
ordinal's *phylo_indep* row against Beta's and Gamma's *phylo_indep* rows, and then applies
the answer to the whole family. Read at source, ordinal_probit's augmented-slope evidence is:

- `.augmented_slope_family_contract()` (`R/fit-multi.R:453-481`): `family_id = 14L`,
  `admission_basis = "route_specific"`, `evidence = "route-specific validation-register rows"`
  — i.e. the *strongest* of the two admission tiers, the same tier as Beta/Gamma/poisson,
  and strictly above lognormal's and student's `c1_partial`.
- **RE-02** (line 195) `covered`, citing `test-matrix-slope-ordinal.R`, which contains a real
  recovery cell: `"phylo_unique(1 + x | sp) x ordinal_probit recovers Sigma_b within 2.5x
  band; pd_hessian TRUE"` (line 204) plus a CI smoke cell (line 265).
- **PHY-18** (line 241) — `phylo_dep` full-unstructured — names ordinal-probit among the
  direct recovery cells; `test-matrix-slope-phylo-dep.R:767` is an explicit
  `"VALIDATION (PHY-18): real-API fit converges PD and recovers slope variances from
  Sigma_b_dep"` cell for `ordinal_probit()` at `var_band = 2.5`.
- **PHY-17** (line 240) — `phylo_latent` — ordinal-probit is a listed covered route-specific
  cell (`test-matrix-slope-phylo-latent.R:323`).
- **SPA-09 / SPA-10** (lines 257–258) — ordinal-probit listed among the covered spatial
  latent and dep slope cells (`test-matrix-slope-spatial-latent.R:298`,
  `test-matrix-slope-spatial-dep.R:319`).

Against that, lognormal and student have **one** C1 seed on **one** route, on the weaker
`c1_partial` basis, with the register itself enumerating five things it does not establish.
**Ordinal_probit therefore has strictly more augmented-slope evidence than either family the
lane just promoted, on a strictly stronger admission basis, and it is the one left at `—`.**
That is the inconsistency.

### Why not (b)

Option (b) — demoting lognormal/student back to `—` — would require reverting a **landed
maintainer-approved precedent**: `betabinomial` already carries
`partial` + `C1 phylo_indep large-N` on this same board (line 398), on the *identical* RE-14
basis, landed 2026-08-01 (`docs/dev-log/after-task/2026-08-01-slope-per-family-betabinomial-admission.md`,
"capability-surface Rand. slope = partial (C1)"). A single C1 seed has already been ruled
sufficient for `partial` in this column. The lane applied that precedent correctly. (b) is
closed.

### Why not (c)

There is no principled route-scoped reading available, because the column has no route axis.
The cell cannot say "partial on phylo_dep, — on phylo_indep"; it has one slot per family.
Given one slot, the honest summary of ordinal's evidence is `partial`, not `—`.

### The consequence: the new ordinal annotation is itself a false cell-level statement

The new text — *"PHY-16: 3/6 converged PD-Hessian fits (min_good=4) — **recovery not
admissible**"* — is verbatim-accurate **as a statement about PHY-16** and **false as a
statement about the cell**. Ordinal-probit augmented-slope *recovery* IS admissible: PHY-18's
dedicated VALIDATION cell recovers slope variances from `Sigma_b_dep`, and RE-02 recovers
`Sigma_b` within a 2.5x band with a PD Hessian. The lane correctly identified that the old
text (*"ordinal RE not implemented"*) was false; it replaced it with a narrower falsehood
rather than with the truth. This is the second-worst outcome and must be fixed.

---

## Task 3 — Attack on the claim set

### 3a. `dev/slope-interval-feasibility-RESULTS.md` — **FAIL (one substantive error, one false headline)**

**On scope discipline, it is clean.** The file never asserts coverage or calibration; §"What
this does NOT establish" is explicit and correct ("No coverage or calibration evidence …
Design 80's calibration arc and D-112 own that question"), and the failed small-N attempts
are reported in the body ("**First-attempt failure, corrected**"), in the VERDICT's caveat,
and in a dedicated "What changed between attempts" section — surfaced three times, not
buried. D-112 and Design 80 are respected. Every arithmetic check I ran reproduces:
`exp(-0.410418) = 0.663373`; `0.663373 × 0.151135 = 0.100259`; delta CI
`[0.466869, 0.859877]`; exponentiated Wald `[0.493300, 0.892081]`; Route B entry 1
`exp(-1.993085) = 0.136274`, `se = 0.064755`, CI `[0.009357, 0.263192]`. The log
(`dev/slope-interval-feasibility-OUTPUT.log`) corroborates `convergence = 0` / `pdHess = TRUE`
on both final fits.

**But the Route A parameter identification is WRONG, and it invalidates the file's headline.**

The probe states its indexing assumption at `dev/slope-interval-feasibility-OUTPUT.log:20-23`
and repeats it in `RESULTS.md`:

> "theta_dep_chol packs, per trait, 2 diagonal Cholesky entries (log-scale int SD, log-scale
> slope SD) + 1 within-block off-diagonal … The SLOPE variance for trait t is entry 2 of that
> trait's 3-entry block (index 3*(t-1)+2)"
> — giving "Route A slope-SD sub-entries (index **2, 5, 8** within theta_dep_chol)".

That packing does not exist. The engine packs **all C diagonals first, then the strictly-lower
entries column-major**:

- `src/gllvmTMB.cpp:1909-1935`: `// Diagonal first (exp-transformed …)` `for (j…) Lb(j,j) =
  exp(theta_dep_chol(idx));` then `// Strictly-lower entries, column-major`.
- `R/lambda-constraint.R:57-79` (`dep_chol_crossblock_pins`) states the same and pins only the
  **cross-block** strictly-lower entries; `R/fit-multi.R:5162-5181` applies those pins for the
  `phylo_indep` route, leaving "the within-block diagonal + intercept-slope entries free ->
  3T params".

With `C = 6` interleaved as `(int_1, slope_1, int_2, slope_2, int_3, slope_3)`
(`R/lambda-constraint.R:85-88` states this ordering explicitly), the 9 free entries in
`par.fixed` order are **6 diagonals then 3 within-block off-diagonals**. So:

| free entry | probe's label | what it actually is | value |
|---|---|---|---|
| 2 | trait 1 slope | trait 1 slope Cholesky diagonal | −0.410418 — *coincidentally right slot* |
| 5 | **trait 2 slope** | **trait 3 INTERCEPT diagonal** | −0.452731 |
| 8 | **trait 3 slope** | **trait 2 within-block OFF-DIAGONAL `L(4,3)`, raw scale** | −0.001243 |

Two of the three rows of the Route A table are the wrong parameters, and row 3 exponentiates
a **raw-scale** Cholesky off-diagonal, which is a category error. This fully explains the
"trait 3" outlier the file waves off as noise:

> `RESULTS.md`, "Sanity signal" paragraph: *"trait 3 is off by >2x (ratio 2.23) on this single
> seed — expected single-seed noise, not evidence of a systematic bias"*

`exp(−0.001243) = 0.9988` is not a slope SD at all; the 2.23 is an artefact of the indexing
bug. Recomputed at the correct indices (diagonals 2, 4, 6 = −0.410418, −0.640056, −0.589356;
off-diagonals 7, 8, 9 = 0.086342, −0.001243, −0.009469), the marginal slope SDs
`sqrt(L21² + L22²)` are 0.669 / 0.527 / 0.555 against truths 0.548 / 0.707 / 0.447 — ratios
**1.22 / 0.75 / 1.24**, with no outlier.

**The knock-on over-claim.** Because the within-block intercept–slope off-diagonal is **free**
under `phylo_indep(1 + x | species)` with a single `|` (register PHY-11 line 233: "Each
trait's intercept-slope correlation remains free"), the slope coordinate's marginal variance
is `Sigma_22 = L21² + L22²`, **not** `exp(2θ)`. The engine itself makes the distinction —
`src/gllvmTMB.cpp:1941`: `sd_b(j) = sqrt(Sigma_b_dep(j,j)); REPORT(sd_b);`. Therefore these two
statements are false:

> `RESULTS.md`, "Delta-method back-transform requirement": *"Both `theta_dep_chol` (Route A
> slope sub-entries) and `theta_diag_B_slope` (Route B) are **univariate log-SDs**"*

> `RESULTS.md`, VERDICT: *"A univariate exp()-delta-method CI is then a two-line computation
> with no engine change required."*

`exp(θ)` on a slope diagonal is the **conditional** SD of the slope given the intercept. A
marginal slope-SD interval on Route A needs the 2×2 `cov.fixed` sub-block for
`(L21, L22)` propagated through `L21² + L22²` — exactly the multivariate delta method the file
correctly reserves for `theta_rr_B_slope`. The file's own two-tier framing (Route A "two-line",
loadings "multivariate") is therefore inverted for half of Route A. **Route B
(`theta_diag_B_slope`) is genuinely a log-SD vector and that half stands unaffected**; the
intercept diagonals on Route A are also genuine marginal log-SDs (their rows carry no free
off-diagonal), so the error is confined to the slope coordinate — which is the whole point of
the probe.

**What survives.** The *structural* finding is untouched and correct: the slope-variance
parameters are ordinary TMB fixed effects present in `sd_report$par.fixed` with a `cov.fixed`
block, on both routes; `sd_report` is non-NULL by default; no exported function surfaces a
slope-variance interval today (`R/profile-targets.R` has no `B_slope` target — verified,
`grep -n 'B_slope'` returns nothing). The PD-Hessian fragility caveat is real and well made.

**Minor (not required):** "recovers the true `psi_sd = 0.2` **closely** … (ratios 0.68–1.21)"
overstates 0.68 slightly, though it is explicitly fenced as "not a recovery claim". And one
sentence is garbled: *"sitting exactly on the boundary the parameter estimates"*.

### 3b. `docs/design/128-slope-per-family-campaign.md` — **PASS (all citations resolve)**

Both citations the brief singled out were checked at source, and every other numeric claim
was spot-checked:

- **~2.5–3.5 h, betabinomial arc.** `docs/dev-log/after-task/2026-08-01-slope-per-family-betabinomial-admission.md:43`
  — *"Recommended ~2.5–3.5 h; large-N probe added ~2 min wall after first fail"*. **Resolves.**
  One nuance worth stating: that line appears under "Arc actuals" but reads *"Recommended"* —
  it is a planned budget, not a measured elapsed time. Design 128 §4 describes it as what the
  after-task "reports … not a per-fit time" and §5 as "mostly authoring/verification time, not
  fit time", both of which are fair; but a reader could take "cited ~2.5-3.5h" as measured. Not
  a required change — the doc is flagged COSTING ONLY and §5 already labels the figure
  qualitative and contingent on the §4 pre-run test.
- **Tweedie ~44% slope-SD bias surviving `p`-fixing.** Two independent sources, both resolve
  verbatim: `docs/dev-log/after-task/2026-07-12-re-surface-arc-start.md:87-91`
  (*"over-estimates the slope SDs by ~44% (the sigma_u^2 <-> p <-> phi ridge …)"*) and
  `tests/testthat/test-tweedie-fixed-p.R` header (*"fixing p does NOT unlock tweedie random
  SLOPES … the ~44% slope-variance over-estimate persists with p fixed"*). **Both resolve.**
  §2.3's observation that 1.44 sits *inside* the generic `(0.5, 1.7)` C1 band is correct and is
  a genuinely good catch — it is the doc's strongest contribution.
- Also verified: `docs/design/80-nongaussian-re-evidence-bars.md:49-50` (the `p`-fix escape
  hatch and "σ_u²↔p↔φ ridge is flat with few clusters"); the C1 band and its "generous band,
  single seed" comment at `tests/testthat/test-family-slope-recovery.R:82-83`;
  `test-truncated-recovery.R` `n_ind` values 250 (line 36), 280 (76), 300 (189), 320 (239) and
  the "keep mu on the higher side" rationale (lines 190-194); `test-matrix-truncated.R:14-25`
  (the phi runaway to ~4e7 / nlminb code 8); the tweedie allowlist-boundary fail-loud test
  (`test-matrix-slope-phylo-indep.R:158-167`); `docs/design/57-mixed-family-link-residual.md:53`;
  `docs/design/61-capability-status.md:158`; register FAM-17 (line 168); the G0 question
  (`docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md:141`, option (d) "one slope gap
  (name tweedie vs truncated_*)"); and the gap ledger's existence.
- No invented sample sizes found. §2.3 explicitly refuses to invent one ("Sample size —
  genuinely not established for slopes … Do not invent one"), and §5 refuses a tweedie
  wall-clock outright. D-139 discipline is followed: a pre-run test is specified with an abort
  criterion, and nothing was run.
- Scope fences hold: §0 and §8 both exclude coverage/calibration by name (D-112, Design 80),
  and the claim that `R/`, `src/`, `NEWS.md`, `DESCRIPTION` are untouched is true (§9, verified).

### 3c. Universal / "works for all families" claims — **PASS (none found)**

`grep` across all three artifacts for "all families", "every family", "universal", "works for"
returns nothing. `dev/rand-slope-truth-ledger.md` is a three-column extraction with no
promotion language. `dev/board-correction-notes.md` explicitly documents the *decision not to
raise* ids 0/2/5/15 despite `covered` rows, and quotes the gap box as its reason — correct
deference to the maintainer cap. No capability claim anywhere exceeds its register row.

**One incidental verification** (the lane's `docs/design/61-capability-status.md` edit, not
covered by the brief): the note claims the old row ("the validation-led article was retired
from pkgdown") was false. Verified: `_pkgdown.yml:150` lists `articles/random-slopes-nongaussian`,
commit `60318d48` exists with the stated message, and `vignettes/articles/random-slopes-nongaussian.Rmd:3`
carries `tier: 3 # under-audit structured-slope draft; visible as a Developer Note`. The
correction is accurate and appropriately hedged ("not yet a full public claim").

---

## Task 4 — Collateral damage — **PASS**

`git diff --name-only origin/main...HEAD -- R/ src/ NEWS.md DESCRIPTION tests/` → empty.
Changed files: `dev/board-correction-notes.md`, `dev/rand-slope-truth-ledger.md`,
`dev/slope-interval-feasibility{.R,-RESULTS.md,-OUTPUT.log}`,
`docs/design/128-slope-per-family-campaign.md`, `docs/design/61-capability-status.md`,
`docs/dev-log/capability-surface.html`. No engine, test, or release-metadata change.

---

## 5. Required changes

**R1 — `docs/dev-log/capability-surface.html`, ordinal_probit Rand. slope cell (line ~447).**
Change from `no`/`—` to the same `partial` treatment as the other four:
```html
<td><span class="tag t-avail">partial</span> <span style="font-size:10px">route-specific (RE-02, PHY-17/18, SPA-09/10); phylo_indep route PHY-16 3/6 PD fits, recovery skipped there</span></td>
```
The current annotation's clause *"recovery not admissible"* must go — it is false at the cell
level (PHY-18's ordinal VALIDATION cell recovers slope variances). Keep the PHY-16 fact; scope
it to the phylo_indep route. `dev/board-correction-notes.md`'s ID 14 section and
`dev/rand-slope-truth-ledger.md`'s mismatch 8 need the matching update.

**R2 — `dev/slope-interval-feasibility-RESULTS.md` (and the OUTPUT log's derived section).**
The Route A indexing is wrong (`2, 5, 8` should be the diagonals `2, 4, 6`), so:
 1. Correct or withdraw the Route A slope table; rows for traits 2 and 3 report a different
    trait's intercept and a raw-scale off-diagonal.
 2. Delete the "trait 3 is off by >2x (ratio 2.23) … expected single-seed noise" sentence —
    the outlier is an indexing artefact, not noise.
 3. Retract *"Both `theta_dep_chol` … and `theta_diag_B_slope` … are univariate log-SDs"* and
    the VERDICT's *"a two-line computation"* **as applied to Route A's slope coordinate**.
    Under `phylo_indep(1 + x | g)` the within-block intercept–slope Cholesky entry is free, so
    the marginal slope variance is `L21² + L22²` and needs the same 2×2 multivariate delta
    method the file reserves for `theta_rr_B_slope`. State that Route A's *intercept*
    diagonals and Route B's `theta_diag_B_slope` remain genuine univariate log-SDs.
 4. The structural computability conclusion, the "no exported extractor" finding, the
    PD-Hessian fragility caveat, and the entire "What this does NOT establish" section stand
    unchanged — none of them depend on the indexing.

**Not required, offered:** the "recovers … closely (ratios 0.68–1.21)" wording; the garbled
"sitting exactly on the boundary the parameter estimates" sentence; and a one-word hedge in
Design 128 §5 that ~2.5–3.5 h is a *recommended*, not measured, arc budget.

---

## 6. Verdict

**CHANGES REQUIRED.** The board work is honest, the maintainer's `partial` cap is intact, the
register licenses every changed value, Design 128's citations all resolve, and nothing under
`R/`, `src/`, `NEWS.md` or `DESCRIPTION` moved. Two things block consolidation: the
ordinal_probit cell is inconsistent with the standard the same lane applied to lognormal and
student and now carries a false "recovery not admissible" claim (R1), and the interval-probe's
Route A numbers read the wrong parameters out of `theta_dep_chol`, which turns its central
"two-line univariate delta method" verdict into an over-claim (R2). Fix both and this
consolidates cleanly.
