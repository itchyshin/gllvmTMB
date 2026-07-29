# gllvmTMB — missing-data documentation-accuracy audit

_2026-07-28. Scope: the shipped missing-data surface — `vignettes/articles/missing-data.Rmd` (314
lines), `man/{predict_missing,impute_model,imputed,miss_control}.Rd` and their roxygen, and the 13
`test-missing-*` files — reconciled against what the code actually does when run._

**Method.** Adapted from the sister package's shipped-docs accuracy audit (drmTMB, 2026-07-11):
inventory every behavioural claim on the reader-facing surface, reconcile it against the
code-verified behaviour, tier by severity, and adversarially verify before reporting. One
difference, deliberate: a claims-reconciliation pass over this article was already run on 2026-07-12
and returned no open items. Repeating it would have re-passed it. **So every behavioural row below
is settled by a live fit, not by reading.** Fits were run locally against the worktree via
`devtools::load_all()`; no remote compute was used.

**Headline.** The subsystem does what the article says it does. The defects are all in the
**under-claiming** direction — the same direction the sister-package audit found, and the safe one:
no reader is led to over-trust a result. The most-read sentence describes the default less precisely
than the software's own runtime message does.

---

## What the audit confirmed by running it

| Question | Answer | Evidence |
|---|---|---|
| Is the default cell-wise or listwise? | **Cell-wise.** A unit with one missing trait keeps contributing every trait it has. | 30 units × 2 traits: `nobs` 80 complete → **79** with one `NA` (listwise would give 78). Independently: the one-`NA` fit is logLik-identical (Δ=1.4e-14) to hand-removing just that cell, and clearly different (Δ=0.66) from hand-removing the whole unit. |
| Is the user told? | **Yes, on both taught entry points**, and precisely. | Verbatim: `ℹ` `traits()`: dropped 1 (trait, row) **cell** with `NA` response.` Long-format route emits the equivalent notice. |
| Do `drop` and `include` differ? | **No** — same optimum. | gaussian/long, gaussian/wide, poisson/long, poisson/wide: \|ΔlogLik\| 1e-9…1e-8, `nobs` equal (146 = 146) in all four. |
| Does wide == long? | **Yes.** | The article's own worked example: \|ΔlogLik\| = 1.07e-14, `nobs` 44 both ways — matching the 44 the article states. |
| Are missing predictors silently dropped? | **No — they abort.** | `predictor = "fail"` is the default; `R/fit-multi.R:2386-2391` aborts on any `NA` in the fixed-effect design matrix. |
| Is the one-predictor scope boundary enforced? | **Yes.** | Two `mi()` terms → *"The missing-predictor model requires exactly one `mi()` term in the location formula. ✖ Found 2 `mi()` terms."* |

---

## Findings

> The three findings below were surfaced by the adversarial verification pass, not by the initial
> audit, and **each was then re-verified independently**. They are more severe than anything the
> first pass found. Two sit **outside this lane's files** and outside the missing-response remit —
> they are reported, not fixed.

### BLOCKER

**B1 — `README.md:174-177` · false fail-loud claim.**
The README tells readers:

> "Ordinary missing **grouping variables, offsets**, weights, or design-matrix values still **error**
> because the model cannot build that row."

Two of those four categories do not error. All four were tested on the same 30-unit fixture:

| README category | Actual | |
|---|---|---|
| grouping variable (`(1 \| grp)`) | **fits silently** — logLik −35.95859 vs −34.49161 clean, `nobs` unchanged, **0 messages** | ✗ |
| unit identifier (`site`) | **fits silently** — logLik −35.83823, `nobs` unchanged, **0 messages** | ✗ |
| offsets | **fits silently** — logLik −36.26135, identical to the no-offset fit (see B2) | ✗ |
| weights | `ERROR: `weights` must be finite at observed cells.` | ✓ |
| design-matrix values | `ERROR: NA in the fixed-effect design matrix.` | ✓ |

The claim is not merely imprecise: it promises **fail-loud safety that does not exist**, and the
actual behaviour is a *silently different fit*. A user who trusts this sentence will assume an
un-errored run means their grouping variable was clean. This is the highest-visibility surface in
the package and the one a reviewer reads first.

**Not fixable from this lane — `README.md` belongs to another lane.** Escalated to the maintainer.

### HIGH

**B2 — `offset()` is silently ignored.**
Not a missing-data defect; found while testing B1, and outside this lane's remit — but it is a
correctness risk and must not sit unreported.

With a *varying* offset (a constant one would be absorbed by the intercept, so it would prove
nothing): logLik **−36.261352 with and without** `offset(offv)` — difference **exactly 0**, `npar`
identical, **no error and no warning**. Confirmed in both the wide and long paths, independently by
two agents and by the orchestrator.

Supporting static evidence: `gllvmTMB()` has no `offset` formal; `grep` for `offset` in
`R/parse-multi-formula.R` and `R/traits-keyword.R` returns **0** hits; **0** guards anywhere in `R/`
reject it.

Ecological count models routinely carry a sampling-effort offset. Silently dropping it yields a
different model from the one the user wrote, with no signal. Two shipped articles
(`fit-diagnostics.Rmd:296,317`, `response-families.Rmd:334`) advise readers to "revisit … offsets"
as a modelling lever — advice about a term the package does not use.

**This needs its own investigation before any claim is made about it.** Reported here with numbers,
not audited.

**B3 — `NA` in a grouping/unit identifier silently changes the fit.**
Neither dropped, nor reported, nor rejected: `nobs` stays 60 (nothing removed) while logLik moves
−34.49161 → −35.83823. So the article's pairing — responses omitted, predictors rejected — is not an
exhaustive account of missingness: there is a **silent third category**.

*Deliberately not documented in the article.* Writing this trap into the guide would enshrine what is
most likely a defect; the right fix is probably to make it error, which is a runtime change and the
maintainer's call.

### MEDIUM

**M1 — `missing-data.Rmd:46-47` · under-claim / ambiguity.**
The article's single most-read sentence about the default reads:

> "By default, `miss_control()` drops **rows** with missing responses and rejects missing predictors."

In long format one row *is* one `(unit, trait)` cell, so this is literally true. But the article
leads with the **wide** `traits(...)` shape, where "row" is the reader's word for a **unit**. A
reader with wide data reads this as *"a unit with one missing trait is discarded."* That is the
opposite of what happens.

The software is more precise than its own documentation here: the runtime message says **"cell"**.

*Fix:* say cell, and say what is retained. Proposed wording in §Fixes below.

**Important qualifier, found by sweeping the rest of the surface for the same defect.** The package
already gets this right elsewhere — `R/traits-keyword.R:74-81` (rendered into `man/traits.Rd`) is the
best-written text on the whole surface:

> "Cells with `NA` responses are, by default, dropped … Users who want strict **listwise** drop
> should pre-filter the wide data before calling."

That says *cells*, and it explicitly distinguishes the default from listwise deletion. So this is not
a systemic misunderstanding running through the docs; it is **the tutorial being less precise than
the reference documentation**, which is the wrong way round — the article is the more-read surface
and the one a new user meets first. M1 stands, but it is a single-surface imprecision, not a pattern.

The phrase "the canonical complete-case behaviour" in that same roxygen block is loose, but it is
immediately disambiguated by the sentence that follows. **Not filed as a defect.**

**M2 — `R/gllvmTMB-wide.R:218-221` · silent data drop.**
The soft-deprecated matrix wrapper `gllvmTMB_wide()` strips `NA` cells itself before handing clean
data to `gllvmTMB()`, so the drop notice never fires. Measured: 40 × 3 = 120 cells, 4 `NA`s → `nobs`
116, **with no message about the drop** (the only message emitted was an unrelated `sigma_eps`
notice). Verified by reading the emitted text, and by `grep -c` for `cli_inform|cli_warn|message(`
over that file returning **0**.

Every other path reports. This one is exported (`NAMESPACE:107`) and no test covers `NA` in `Y`
there. It is soft-deprecated, which caps the severity — but "deprecated" is not "unreachable", and
silently discarding data is the one behaviour a user must never have to guess at.

*Note:* the drop is still **cell-wise** here (120→116), so this is a transparency defect, not an
estimand defect.

**M3 — `missing-data.Rmd:3` (the article description) · overclaim + cross-page inconsistency.**
The description — rendered on the article index, so it is read before the article itself — promised:

> "Choose among omitted, retained, or explicitly modelled missing values and verify how **each**
> choice changes the estimand and fitted rows."

Two of the three choices do **not** change the estimand. `drop` and `include` reach the same
estimates in every cell measured (gaussian and poisson × long and wide; \|ΔlogLik\| 1e-9…1e-8, equal
`nobs`). They differ in which rows `predict_missing()` can return — the "fitted rows" half is true —
but not in the estimates. Only the modelled-missing-predictor route changes the estimand.

This is the one finding pointing in the **overclaiming** direction, and it **contradicts the
article's own body**: line 146-150 already states *"Retaining a cell's identity is not the same as
adding information."* The description promises a difference the article then correctly denies.

*Fixed* — the description now states that omitting and retaining reach the same estimates and differ
in which rows can be predicted, while modelling a predictor changes the estimand.

### LOW

**L1 — the term for the property appears nowhere a reader can find it.**
`FIML` occurs in **11 internal design/dev-log documents and 0 reader-facing surfaces** (`R/`,
`vignettes/`, `man/`, `tests/`, `NEWS.md`, `README.md` all count 0 — verified twice by independent
commands). Readers arriving from an SEM or psychometrics background search for this term. The
package has the property and never names it.

**L2 — the proofs of the headline property do not run by default.**
`skip_if_not_heavy()` (`tests/testthat/setup.R:16-21`) skips unless `GLLVMTMB_HEAVY_TESTS` is set,
and it is unset in an ordinary run. Both runs were measured directly, with the variable set inside
the R session so there is no subprocess-propagation doubt:

| run | expectations passed | blocks skipped | failures |
|---|---|---|---|
| default (`GLLVMTMB_HEAVY_TESTS` unset) | 133 | 80 | 0 |
| heavy (`=1`) | **665** | 0 | **0** |

So **only about one assertion in five (133 of 665) executes in an ordinary run**, and **100% of
`test-missing-response-gaussian.R` (0 pass / 9 skip) and 100% of `test-missing-response-traits.R`
(0 pass / 7 skip)** are skipped — the two files that pin the default's retain-every-observed-cell
contract.

**The gated tests all pass when run** (665 pass, 0 fail, 1 warning in
`test-missing-response-gaussian.R`). This is the reassuring half of the finding: the package's
claims are backed by tests that genuinely hold. The gating is a deliberate, reasonable CI-cost
decision, not a bug. The problem is only that *nothing cheap* guarded the contract. Addressed below.

*(A first automated attempt at this measurement reported ~62% execution and identical default/heavy
counts — the environment variable had not reached the test runner, so the comparison was invalid.
It was discarded and re-measured. The figures above are the re-measured ones.)*

**L3 — the wide-vs-long parity claim was untested.**
`missing-data.Rmd:119` — *"The two forms maximize the same observed-data likelihood in this
example."* Hedged with "in this example", so not a blanket claim. No test compared a wide masked fit
against a hand-built long fit. **Now verified true** (Δ=1.07e-14) and pinned.

**L4 — the one-`mi()` scope guard was unpinned.**
The guard is real and fires correctly, but no test in the 13 files exercised it, so a refactor could
have silently turned a documented boundary into an overclaim. Now pinned.

### No defect found (recorded so it is not re-audited)

- **Zero broken examples.** All 10 chunks are `eval = TRUE`; every function and named argument used
  exists with the documented signature. (`mi()` is not a callable function — it is stripped from the
  formula AST before evaluation — but that is deliberate and works.) This is where the sister
  package's audit found its blocker; this surface is clean.
- **`missing-data.Rmd:146-150` is accurate and well-judged** — *"Retaining a cell's identity is not
  the same as adding information: the missing response itself contributes nothing to the
  likelihood."* Exactly right, and consistent with `drop` ≡ `include` measured above.
- **`missing-data.Rmd:40-44`** states the ignorability/MNAR assumption plainly and up front.
- **The four exports** (`miss_control`, `impute_model`, `imputed`, `predict_missing`) match their
  documented contracts.

---

## Fixes

**Applied in this lane** (reader surfaces this lane owns):

1. M1 — reword `missing-data.Rmd:46-47` to name the cell and the retention, and introduce the term
   once with a plain gloss:

   > By default, `miss_control()` omits each missing response **cell** — a unit keeps every trait it
   > does have — and rejects missing predictors. Because every observed cell still contributes, this
   > is full-information maximum likelihood (FIML) over the observed data, not case-wise deletion.

   Plain English thereafter; the acronym is introduced once, where it is literally true.
2. M3 — the article description now says what actually differs between the three strategies, and
   stops promising an estimand change that two of them do not produce.
3. L1 — the same sentence carries the term, making it findable.
3. L2/L3/L4 — new `tests/testthat/test-missing-response-cellwise.R`: four fast, **un-gated** blocks
   pinning (a) cell-wise not unit-wise, (b) the call-time message names a *cell* and a count,
   (c) `drop` ≡ `include`, (d) the one-`mi()` guard. Measured: 8 expectations, 0 skips, 0 failures in
   a default run.

**Carried over — needs sequencing, not in this lane:**

4. Two roxygen blocks in **`R/gllvmTMB.R` — fenced to another active lane** — carry the same
   imprecision as M1 and should be corrected when that lane allows:
   - `:1312` (→ `man/miss_control.Rd:15`) — *"the historical complete-case behaviour: rows with a
     missing response are removed"*
   - `:239` (→ `man/gllvmTMB.Rd:245`) — *"the historical complete-case behaviour"*, and
     *"keeps **rows** with a missing response"*

   "Complete-case" is the standard name for listwise deletion — the behaviour this default avoids —
   and "rows" repeats the article's ambiguity. Lower severity than M1 because reference docs are
   read after the tutorial, and because `man/traits.Rd` already states the distinction correctly.
   **Patch prepared, not applied**: the file belongs to another lane. Suggested substitution:
   *"…is cell-wise omission: each missing response cell is dropped, and a unit keeps every trait it
   does have."*
5. M2 — making `gllvmTMB_wide()` report its drop is a runtime behaviour change to a shipped
   (deprecated) export. Written up as a proposal; not shipped in this lane.

---

## Adversarial verification

A fresh-context verifier was tasked with **refuting** the headline claim, defaulting to "refuted" if
uncertain. Verdict: **SURVIVES-WITH-SCOPE** after 12 attack fronts.

The core held everywhere it could be tested. Cell-wise behaviour and `drop` ≡ `include` were
confirmed for **gaussian, poisson, binomial (0/1 and `cbind`), ordinal_probit, delta_gamma,
delta_lognormal, tweedie, nbinom2**; with **`latent()`, `dep()`, `indep()`, ordinary `(1|g)`**; in
both entry points; and under `REML = TRUE` — 14 paired fits, max \|ΔlogLik\| 1.3e-9, identical
`nobs`/npar/AIC/BIC. The strongest structural attack (a factor level whose only unit is entirely
`NA`, so its design column empties after dropping) still agreed to 2.8e-14.

It also showed the distinction is **substantive, not a technicality**: with 20 of 40 units each
missing one trait, cell-wise retains 100 cells across all 40 units where complete-case deletion
would keep 60 across 20 — **40 observed cells rescued**.

**Scope restrictions it forced:**

1. "Reported at call time" is **false for `gllvmTMB_wide()`** (finding M2) — scope the claim to the
   two `gllvmTMB()` entry points.
2. `drop` ≡ `include` is an **ML-only** statement: `REML = TRUE` rejects `include` outright, so no
   equivalence exists to assert there.
3. The report is a **cell count only**. When an entire trait is missing it still says just "dropped
   40 cells": the fit keeps that trait's parameters free and counted in `logLik` df, and
   `fit$sd_report` becomes `NULL` with `sdreport_error = FALSE` and **no warning**.
4. "Responses" is load-bearing — see B3.

**It also caught an overclaim in this audit's own fix.** The first rewrite of `missing-data.Rmd:46`
asserted the default "is full-information maximum likelihood (FIML) over the observed data". That is
stronger than anything demonstrated: what was verified is that two *optimisation routes* agree, never
that the marginalisation is exact — and for non-Gaussian families the marginal is a **Laplace
approximation**, not a closed-form observed-data likelihood. The wording was corrected to describe
the full-information *principle* and to state the Laplace approximation explicitly. Recorded here
because an audit that fixes an overclaim by committing one would be worse than no audit.

## Scope — what this audit does NOT cover

- It makes **no claim about interval coverage**, and none should be read into it. No bias claim
  either: what was compared is optimisation routes, `nobs`, npar and information criteria.
- **`phylo_*` and `spatial_*` structures are entirely untested here** — they need a vcv or an SPDE
  mesh, and whether dropping a cell interacts with kernel dimensioning is unknown. This is the
  largest gap.
- **`categorical()` could not be exercised** — it aborted on a mixed-family setup requirement before
  any missing-data behaviour could be reached.
- Not run: `betabinomial`, `nbinom1`, truncated / `_mix` / `poisson_link` deltas, `Beta`.
- **The interaction of `mi()` predictors with missing responses is untested** — each route was
  exercised alone.
- Everything is `n ≤ 40`, `d ≤ 1`, **single-seed**. The 1e-9…1e-14 equalities are
  single-configuration results, not a sweep.
- It is not an MNAR robustness study; the article says so itself and that framing is correct.
- The heavy-gated tests were measured for *whether they run*, and observed to pass — not
  independently re-derived.
- B2 (`offset()`) and B3 (identifier `NA`) are **reported with numbers, not audited**. Each needs its
  own investigation.
