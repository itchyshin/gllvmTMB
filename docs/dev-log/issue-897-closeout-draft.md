# DRAFT comment for issue #897 — NOT POSTED

Ready to paste as a comment on
<https://github.com/itchyshin/gllvmTMB/issues/897>. Nothing below has been
posted, and the issue has not been closed. Recommended disposition is at the
end. Everything is quoted from the pre-registered criteria files and their
verdicts in `dev/ordinal-degeneracy/` and `dev/multinomial-structured/`;
branch `claude/categorical-paper-alignment-20260817`.

---

## Draft comment

**Both categorical families now have a degeneracy screen, and this issue's
three directives were each answered on their own terms.** Summary against the
directives, then the evidence.

### 1. The mechanism you flagged as unknown is SETTLED: separation, not saturation

The issue named link saturation (cutpoint underflow in `gll_log_pnorm_diff`)
as the suspected mechanism and asked for it to be established before anything
was built. A pre-registered probe (decision rule frozen at `e932cf37`, verdict
at `b33d3b90`) ran a 60-fit grid, labelled 24 fits degenerate by per-fit truth
(`rel_frob > 10`), and measured three things:

1. **Flat-row share is EXACTLY 0 on all 24 degenerate fits.** The cutpoint
   underflow condition — both bracketing cutpoints more than 8.2924 from `eta`
   on the same side — is never reached on any observed row of any degenerate
   fit. Saturation is **refuted by measurement**, not merely unsupported.
2. **24/24 dichotomised refits fire the EXISTING binomial detector.**
   Collapsing each degenerate fit's response to binary at the middle cutpoint
   and refitting as `binomial(link = "probit")` reproduces the pathology under
   a screen that already works — which is what identifies the mechanism as the
   same category-level quasi-complete separation geometry.
3. **The pathology is a single-column runaway.** Worked example: one trait's
   loading 44.2 against a true `max|Lambda| = 4.79`, siblings near truth.

The fourth (directional-derivative) arm landed in the pre-registered "mixed"
bucket, for a disclosed reason rather than a silent one: a uniform whole-matrix
rescale masks a single-column pathology, so that arm cannot see what arms 1-3
see.

**Consequence for the build, and it is a subtraction:** a flat-fit/saturation
arm has no empirical basis, so it was **deliberately not built**. The ordinal
row is modelled on the binomial loading arms instead, which is where the
measurement pointed.

### 2. Ordinal thresholds were set on ordinal evidence, NOT inherited — and the measurement shows exactly why that mattered

Directive 2 asked that ordinal not borrow binomial's numbers. Calibration ran
315 fits (`n = 100/400`, four pre-registered design arms, per-fit truth
`rel_frob > 10`; `dev/ordinal-degeneracy/pass-criteria-ordinal.md`, VERDICT
2026-08-17).

**At binomial's own threshold of 6, the ordinal screen measures 100%
sensitivity and 24% false positives** — reproducing on ordinal precisely the
defect this issue reports in binomial (25%). Inheriting the number would have
shipped the very failure the issue asks us to fix. The full curve:

| O2 threshold | sensitivity | FP (all healthy fits) |
|---|---|---|
| 6 (binomial's) | 100.0% | **24.0%** |
| 20 | 90.8% | 10.6% |
| 40 (**shipped**) | 60.2% | 0.9% |

**Where the false positives come from.** Every false alarm at every threshold
comes from designs with heterogeneous per-trait loading scales — the
adversarial *transport* arm, pre-registered to test exactly that hypothesis
(78.6% FP at 6, 35.7% at 20, 0.0% at 40). **The plain healthy arm has ZERO
false positives at every threshold from 6 to 40.** An absolute liability-scale
threshold cannot transport across heterogeneous trait scales: a legitimately
large loading on a wide-cutpoint trait is indistinguishable from a runaway.

**Shipped, armed at 40** (`check_gllvmTMB()` row `ordinal_liability_loading`):

- **O2 `ordinal_loading_absolute_thresh = 40`** — sensitivity 60.2% overall,
  **70.0% on homogeneous designs**, FP 0.9% overall (0.0% healthy arm, 0.0%
  transport arm, 2.7% mixed).
- **O1 `ordinal_loading_runaway_thresh = 40`** — sensitivity 37.8%, FP
  **0.0% on every arm**.

**Reported honestly, because it did not pass:** the frozen conjunction
(sensitivity ≥ 90% **and** zero false positives) was **NOT achieved at any
threshold** — the class distributions overlap in the tails (degenerate minimum
10.2, healthy maximum 52.3). Arming at 40 rather than taking the pre-registered
ship-disarmed fallback follows this issue's own stated priority — *a check that
cries wolf a quarter of the time gets switched off* — so specificity was
treated as the binding constraint. Against the status quo this issue reports
(**0/239** detected), a screen that never cries wolf on a healthy fit and
catches ~60-70% of degenerate ones is a strict improvement; the alternative
leaves the gap fully open.

**Limits, stated rather than buried:** no `n = 1600` evidence (that arm was
dropped and `n = 400`'s seeds halved to stay inside the 30-minute pre-run
budget); the healthy pool of 217 fits gives a rule-of-three FPR bound of
**~1.4%, not a verified zero**; the `cutpoint_span` variant was NOT promoted
(its circularity precondition was untested, so it stays calibration-only); and
sensitivity below 90% is a real miss, recorded as one.

### 3. `aghq_ridge` was not touched

Directive 3 asked that the ridge be left alone. It was: no change to
`aghq_ridge`, its default, or any AGHQ path. This work is confined to
`check_gllvmTMB()` rows.

### Also closed: multinomial had the same gap, and it is now screened

`multinomial()` (fid 16) had no degeneracy coverage either — the Design 123
campaigns had produced fits that converged with a PD Hessian while reporting a
collapsed contrast variance or a railed correlation, unflagged.
`check_gllvmTMB()` now emits a `multinomial_contrast_degeneracy` row with three
arms (criteria frozen at `f6552ee9` **before** results, verdict at `6f34568e`;
128 fits, 122 conv+PD):

- **M1** `contrast_variance_collapse` (`multinomial_collapse_floor = 1e-10`) —
  6/7 labeled collapses, **plus 7/7 fully out-of-sample** on a later
  diagonal-`V` replication cell (0/13 false positives there).
- **M2** `contrast_rail` (`multinomial_rail_thresh = 0.99`, evaluated only
  where the tier's rank is ≥ 2) — 8/8 labeled rails, **plus 4/4 individually
  railed fits hidden inside a cell whose AGGREGATE gate had passed** (refitting
  those seeds gives `rho = ±1.00000`; two non-firing controls give 0.48997 and
  -0.14534). Rank-1 suppression is proven out-of-sample: 0/20 on healthy `d = 1`
  fits despite `rho = ±1` holding there by row proportionality.
- **M3** `spatial_range_collapse` (`multinomial_range_collapse_thresh = 0.02`)
  — 3/3 **after** a scope fix. Its first measurement was 0/3, and that was a
  keyword-scope bug rather than a calibration miss: the arm gated on
  `Lambda_spde`, which the engine reports only on the low-rank
  `spatial_latent()`/`spatial_dep()` route, so on the `spatial_indep()` fits it
  was built for it emitted **no row at all** (0/20). After branching on the
  engine route: rows 20/20, sensitivity 3/3, 0/11 false positives on the same
  cell's healthy fits.

Zero false positives on 40 informative healthy fits, with the denominator
stated honestly: a bare `(1 | group)` multinomial fit has no loading tier, so
no row is emitted and those 20 fits carry zero specificity information —
excluding them gives a rule-of-three bound of **~7.5%**, which is a real
improvement on binomial's measured 25% but is **not** a verified zero.

### Also fixed: a structural false positive in `near_zero_psi_unit`

Found while building the above and live-confirmed: a **healthy** mixed
`multinomial()` + `gaussian()` fit WARNed `near_zero_psi_unit` purely because
the auto-Psi skip block pins each contrast pseudo-trait's `theta_diag_B` at
`log(1e-6)` while the C++ still REPORTs `sd_B` for the pinned entry — so the
pinned value always cleared both the absolute and the relative collapse
thresholds. The free gaussian trait's sd was 0.312. This predates the current
arc and affected every fit with a single-trial-Bernoulli or multinomial trait
sharing a `latent()` term with a free partner trait. The screen now drops
pinned entries before evaluating the row; a genuine collapse among the
remaining free traits is still caught.

### What this issue's point 2 leaves open — spun out, not rushed

**The binomial screen's own ~25% false-positive rate is measured and diagnosed
but NOT re-calibrated here.** The ordinal campaign identifies the cause — an
absolute liability-scale threshold cannot transport across heterogeneous
per-trait loading scales, which is the same mechanism that produced 24% on
ordinal at the same threshold — but re-tuning a shipped, load-bearing screen on
evidence gathered for a *different* family would repeat exactly the inheritance
error directive 1 warns against. It needs its own binomial healthy/degenerate
arms and its own pre-registration, and is proposed as a follow-up issue rather
than folded into this one.

### One behaviour change deliberately NOT made

**Fit-time warnings are not wired for either categorical family.** Both rows
surface through `check_gllvmTMB()` only; `gllvmTMB()` warns exactly as it did
before. Making either row an automatic warning is a change every existing user
would feel and is left to the maintainer.

### Suggested disposition

Close this issue on directives 1-3 (mechanism settled, ordinal screen shipped
on ordinal evidence, `aghq_ridge` untouched), and open a follow-up for the
binomial re-calibration described above. Full record:
`docs/design/123-multinomial-structured-surface.md` §8, register rows FAM-14 /
FAM-20 / DIA-08, and
`docs/dev-log/after-task/2026-08-17-categorical-paper-alignment-and-detector.md`.
