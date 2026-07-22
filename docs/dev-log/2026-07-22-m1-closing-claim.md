# M1 closing claim

**Written in D-43's required form: cite the tier, and name the cells that are NOT covered.**

**Status: DRAFTED, NOT YET SIGNED.** The three maintainer decisions were answered on 2026-07-22
(§1). Answering them required **source edits**, which forfeited the certified evidence chain at
`21e04eb5`. This claim is signed only when the chain is re-earned at the new head (§4). Written
2026-07-22 on `claude/0.6-m1-close-20260722`.

---

## 1. The three decisions — answered 2026-07-22

| # | Question | Answer | Applied as |
|---|---|---|---|
| 1 | Keep or tighten `R/julia-bridge.R:1671` | **Tighten** | `"experimental route: partial validation only"` → `"experimental route: point estimate only; no coverage evidence"`, plus its asserting test at `test-julia-bridge.R:1273` |
| 2 | Write the `NEWS.md` boundary statement in | **Yes** | New first bullet under `## Known limitations` |
| 3 | Does R-7's sign-off stand | **Yes** | Stands. What was retired is one strand of *causation* evidence; D-43 governs *claims*, not signed-off register rows |

**⚠ Read-back on decision 1.** The reply was *"yes experment"*. Both options began "experimental
route:", so it did not disambiguate on its own. It was taken as assent to the proposed tightening,
because the asymmetry is one-sided: the tighter string claims **strictly less** and therefore cannot
become a false claim, whereas keeping a vague one risks exactly the failure this milestone was
withheld for. **If "keep as-is" was meant, it is a one-line revert in two files.**

## 2. THE CLAIM

> **M1 — release truth and a green heavy baseline — is complete**, at the tier **"reconciled release
> truth with a green package-check baseline on a pre-bump source identity."**
>
> This claims that the package's *statements about itself* have been reconciled against its source,
> and that the package passes its checks on three platforms. **It is not a release-readiness claim,
> not a coverage claim, and not a capability claim.**

**Per D-49 the rung must be named, not implied.** M1 does not itself establish a release rung; the
rung is M5's to claim. Per **D-66** the current honest rung remains **NOT READY** — *"the gap to
submission is evidence, not capability."*

## 3. WHAT IS NOT COVERED — named explicitly, as D-43 requires

D-43's remedy clause is *"WITHHELD until the uncovered cells are named explicitly."* This is that
naming. Every item is a cell the maintainer has already signed off or the register already records
as failing — none is newly discovered here.

**Estimator limitations (signed off, not fixed):**

- **R-2 — binomial-logit phylogenetic slope variance.** `sigma^2_slope` is systematically
  **over-estimated by roughly 50–60%** under the logit link. **21 seeds across three sample sizes
  all fail**, and the bias **does not diminish with sample size** (n_id = 60, 120, 240). Root cause
  is information starvation per cluster, not a convergence or parser fault. The identical fixture
  **recovers cleanly under Gaussian**. Its test is **skipped**. **Recovery for this cell is
  unverified and 0.6 must not claim otherwise.**
- **R-6 — no structural guard on random-slope identifiability.** A random slope of `x` within
  cluster `g` requires within-cluster variation in `x`; nothing refuses a specification that lacks
  it. Deferred to 0.7. The cost is a poor error message, not a wrong number — an unidentifiable
  specification typically fails to converge rather than returning a confident wrong answer.

**Test-integrity defect (signed off, deferred):**

- **R-7 site (d) — `test-matrix-nbinom2-spatial.R:258`.** The test is named *"…pd_hessian TRUE"* and
  its skip message claims that check, but the gate `.fit_stationary_for_recovery_test()` tests
  **only the scaled gradient**; `pd_hessian` never appears in the condition. Measured directly: the
  gate returns TRUE while `pd_hessian` is FALSE, with `cov.fixed` carrying one negative diagonal
  entry at `log_tau_spde` (−3.518e10). **The test name and skip message both claim a check that does
  not happen.** Not user-reachable. Repair deferred to 0.7 with the **SPA-02 downgrade budgeted** —
  fixing the gate will most likely make this cell *skip rather than pass*.

**Capability gap (documented, not fixed):**

- **R-5 — `simulate()` unconditional redraw.** Covers `rr_B, diag_B, rr_W, diag_W, propto, lv_B,
  phylo_rr, diag_species`. **Does NOT cover the SPDE spatial tier or `phylo_diag`**, which fall back
  to conditional simulation, reusing fitted random-effect modes and understating between-unit
  variability. **Simulate-based intervals for such fits — including `bootstrap_Sigma()` — are too
  narrow.** Issue #750 is retargeted to 0.7; its implemented work remains on unmerged parked
  branches.

**Interval calibration — the largest uncovered class:**

- **CI-08 — the empirical coverage gate FAILED.** **13 of 15 cells below the 94% threshold**; only
  **Gaussian d=1 and d=3** cleared. No production cell was promoted.
- **CI-10 — mixed-family coverage** measured to 0.55.
- Per `docs/design/75:96-99`, **no cell in the inference-route matrix is empirical-coverage-
  calibrated**, and **a cell may not be described as calibrated**. `"covered"` means the route
  dispatches and is dispatch-tested — *"never that Wald coverage is calibrated."*
- **FAM-17 / MIX-10 — delta/hurdle latent-scale correlation is flagged "do not advertise."**

**Process-level, not defects:**

- **Six D-43 panels ran where D-74 specifies one.** Recorded as drift in
  `docs/dev-log/plan-actual/2026-07-22-m1-plan-vs-actual.md`. **Not one of the six found a
  numerical, algorithmic or statistical defect.**
- The claim-string class **outside** the five R-11 files — `man/`, the shipped vignette, `NEWS.md`,
  `README.md`, the `DESCRIPTION` `Description` — was **never swept**. An M4 item.
- **D-41's mandatory experimental warning is unverified.** gllvmTMB is **not** exempt. A release
  blocker for M4/M5 if absent.

## 4. Evidence — MUST BE RE-EARNED BEFORE THIS CLAIM IS SIGNED

The decisions in §1 changed three shipped paths — `R/julia-bridge.R`, `NEWS.md`, and
`tests/testthat/test-julia-bridge.R` — so **the certified chain at `21e04eb5` no longer describes
this tree.** This is the sixth time in the arc that a repair re-minted the source identity; it is
expected, not a fault.

Required order (Amendment 2's sequencing, and CI is authorised — do not re-ask):

1. `devtools::test()` — structured counts, not reporter prose
2. durable `R CMD check --as-cran`
3. CRAN-configuration check (the only real CRAN evidence; the durable runner sets `NOT_CRAN=true`)
4. freeze + commit → push
5. Ubuntu CI → **then** the three-OS matrix (never dispatch while Ubuntu is in flight)
6. Ubuntu heavy — `FAIL` is the only regression signal; `WARN n` is not

### Evidence re-earned so far, at the edited tree

| Step | Result |
|---|---|
| **1. `devtools::test()`** | **`FAILED 0 \| ERROR 0 \| SKIP 779 \| PASS 7290`** — an **exact match** to the certified baseline, confirming the wording change is behaviourally neutral. `SKIP 779` (not `test_dir()`'s 1001) confirms the full suite ran. |
| Targeted `test-julia-bridge.R` | `FAILED 0 \| ERROR 0 \| SKIP 19 \| PASS 562` |
| Parse check | `R/julia-bridge.R` and its test both parse |
| Old-string sweep | zero residue across `R/`, `tests/`, `man/`, `NEWS.md`, `vignettes/` |
| 2–3. CRAN-configuration check | *in flight* |
| 4–6. push → Ubuntu → matrix → heavy | *pending local checks* |

### ⚠ The transfer check itself was incomplete until today

The canonical command omitted **`NEWS.md`, `README.md` and `inst/`** — all three ship. Decision 2
edited `NEWS.md`, so had that been the only source change, the check would have reported "empty" and
declared a certification that no longer held. Corrected in `LOOP/checkpoint.md` §0; demonstrated by
construction (old list → 2 files, corrected list → 3). This does not change any earlier verdict in
the arc, because every prior commit was documentation-only under `docs/` and `LOOP/`.

## 5. What signing this claim does NOT authorise

No merge, no tag, no CRAN submission, no readiness or release claim. The API freeze, candidate
freeze, RC tag, final tag and submission each remain separate maintainer gates. **No exception is
self-granted.** M3's version bump will invalidate every M1 platform receipt by design, and M5 must
price a second exact-tag three-OS cycle.

> Related: `docs/dev-log/known-residuals-register.md` · `docs/design/75-inference-route-truth-matrix.md`
> · `docs/dev-log/plan-actual/2026-07-22-m1-plan-vs-actual.md`
> · `docs/dev-log/2026-07-22-r11-wording-review-dossier.md` · `LOOP/checkpoint.md`
