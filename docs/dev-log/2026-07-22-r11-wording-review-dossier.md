# R-11 wording review — dossier for the maintainer decision

**Purpose.** M1's remaining blocker is a judgement no check can make: do the R-11 replacement
strings claim more than the evidence supports? This file turns that from a hunt into a review.
Every user-facing claim string in the five R-11 files is inventoried below with its verdict and
the reasoning, so the decision is *confirm or overrule*, not *go and find them*.

**Prepared** 2026-07-22, on `claude/0.6-m1-close-20260722` @ `509d5792`. Agent work; **the decision
is the maintainer's.**

---

## The bar — quoted, not paraphrased

`docs/design/75-inference-route-truth-matrix.md:96-99`:

> **"No cell in this matrix is empirical-coverage-calibrated.** Every status is route existence
> plus focused-test evidence. The empirical coverage gates are `CI-08` and `CI-10` in the
> validation register, which remain open/failing; **a cell may not be described as calibrated on
> the strength of this matrix.**"

`:88-90` — `"covered"` means the route **dispatches and is dispatch-tested**, *"never that Wald
coverage is calibrated for a boundary-sensitive variance target."*

`:92-94` — parametric bootstrap is the *intended* calibration engine, but *"no coverage study
promotes any cell here; treat as route existence only."*

Corroborating: `CI-08`'s empirical gate **FAILED** — 13/15 cells below the 94% threshold, only
Gaussian d=1 and d=3 cleared (independently recorded in brain **D-42**).

**So the test for each string is narrow and answerable:** does it assert calibration, coverage, or
validation that the record does not support? Hedged, negative, and route-existence statements pass.

---

## Verdict

**No HIGH-risk string found. One item for the maintainer's eye. Two apparent defects investigated
and ruled out by reading the code.**

The automated pass that produced **seven overstatements** — most seriously `"validated"` stamped on
CI rows, including a structural-zero correlation — was corrected before this review. The surviving
strings are, on inspection, in materially better shape than the handover implied.

### The one item to look at

| Site | String | Why it is here |
|---|---|---|
| `R/julia-bridge.R:1671` | `"experimental route: partial validation only"` | The only surviving string using **"validation"** in a *positive* frame. It is hedged twice ("experimental", "only"), so it limits rather than asserts — but "partial validation" is undefined, and a reader could take it as *partially calibrated*, which nothing supports. **Reachable**: `validation_row` is stripped from *display* by `.reportable_table()` (both branches, R-11's fix), but it remains readable programmatically and through the **documented** `attr(p, "gllvmTMB_data")` on `plot_Sigma_table()`, `plot_Sigma_heatmap()` and `plot_Sigma_comparison()`. **Suggested, if you want it tightened:** `"experimental route: point estimate only; no coverage evidence"`. |

### Two apparent defects — investigated, NOT defects

Recorded because both would have been flagged by a mechanical sweep, and acting on either would
have been an over-reach of exactly the kind R-9 documents.

1. **`R/fit-multi.R:151,153,155`** — `"route-specific validation-register rows"` ×8, sitting in an
   `evidence` column, pointing at a register that **does not ship** (`.Rbuildignore:18` is `^docs$`,
   excluding the whole `docs/` tree). This looks exactly like the R-10/R-11 defect class that five
   panels missed once already. **It is not user-reachable.** Its only consumer,
   `.augmented_slope_family_allowed()` (`:161-172`), reads **only** `family_id` and the `link_0/1/2`
   columns; the `evidence` and `admission_basis` columns are never read, returned, or printed. Dead
   internal data. The user-facing text for this contract is
   `.augmented_slope_family_scope_text()` (`:174-182`), which is honest — *"permitted"*, *"more
   limited evidence only"*, *"validation depth remains family- and covariance-mode-specific"* — and
   asserts no calibration.

2. **`R/julia-bridge.R:245`** — roxygen stating the `validation_row` column *"links each row to an
   internal validation-register entry."* Directs a reader to a non-shipping document, so it looks
   like R-8's dangling-reference class. **It generates no help page**: the block carries both
   `@keywords internal` and `@noRd`, so nothing reaches `man/`.

### The rest — honest or explicitly negative

Every remaining string either states a limitation or describes route existence. Counts are
occurrences across the five files.

| n | String | Note |
|---:|---|---|
| 21 | `Julia-bridge point-estimate route (partial evidence)` | point-estimate + partial; no calibration claim |
| 12 | `no CI (point estimate only)` | explicitly negative |
| 6 | `diagonal grouping tier: no calibrated interval` | explicitly negative, uses the right word |
| 4 | `Random-regression slope: partial recovery; no CI` | honest |
| 4 | `Multi-trait slope covariance: mixed evidence; no CI` | honest |
| 2 | `direct profile route (not coverage-calibrated)` | explicitly negative |
| 2 | `diagonal grouping SD: direct profile route (not coverage-calibrated)` | explicitly negative |
| 2 | `Empirical coverage calibration is not established for this route.` | **matches `design/75` almost verbatim** |
| 2 | `profile CI blocked (point estimate only)` | explicitly negative |
| 2 | `profile CI partial (diagonal only; else bootstrap)` | route availability, not calibration |
| 2 | `Lognormal/Student-t: permitted at runtime; single-seed evidence on one route only` | precise and self-limiting |
| 1 | `phylogenetic direct-scale profile route (not coverage-calibrated)` | explicitly negative |
| 1 | `phylogenetic covariance CI: partial (diagonal only)` | route availability |
| 1 | `phylo-signal profile-CI: 2-component only, partial beyond` | route availability |
| 1 | `spatial Sigma: direct-scale CI only, partial elsewhere` | route availability |
| 1 | `augmented random-slope: recovery evidence varies by family/route; no CI` | honest |
| 1 | `Validation depth remains family- and covariance-mode-specific.` | vague but claims nothing |
| 3 | `…do not treat an unadmitted combination as validated for recovery or inference.` | uses "validated" **prohibitively** — warns against over-claiming |

The `…as validated…` family is worth noticing: it is the one place "validated" survives, and it
survives correctly, because it appears inside a negation telling the user *not* to infer validation.

---

## Method, and what this dossier does NOT establish

Inventory was a literal-string sweep of the five R-11 files
(`profile-route-matrix.R`, `extract-sigma-table.R`, `julia-bridge.R`, `fit-multi.R`,
`extract-sigma.R`) filtered for claim vocabulary, then each survivor was traced to its consumer
before judging. Tracing is what reclassified both apparent defects — **a string's text does not
tell you whether it reaches a user.**

**Not established here:**

- That the inventory is exhaustive **outside** those five files. The wider class — any user-facing
  string asserting validation/calibration/coverage on any surface (`man/`, the shipped vignette,
  `NEWS.md`, `README.md`, the `DESCRIPTION` `Description`) — was **not** swept. That is an M4 item
  and should not be assumed done.
- Whether the *hedged* strings are the wording the maintainer wants. This dossier tests them for
  **truth**, not for tone or house style.
- Anything about `NEWS.md`'s boundary statement or R-7's sign-off — the other two open decisions.

> Related: `docs/dev-log/known-residuals-register.md` R-11 · `docs/design/75-inference-route-truth-matrix.md`
> · `LOOP/checkpoint.md` §5
