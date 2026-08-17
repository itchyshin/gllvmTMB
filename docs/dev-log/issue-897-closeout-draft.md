# DRAFT comment for issue #897 — NOT POSTED

Ready to paste as a comment on
<https://github.com/itchyshin/gllvmTMB/issues/897>. Nothing below has been
posted, and the issue has not been closed. Recommended disposition is at the
end. Everything is quoted from the pre-registered criteria files and their
verdicts in `dev/ordinal-degeneracy/` and `dev/multinomial-structured/`;
branch `claude/categorical-paper-alignment-20260817`.

---

## Draft comment

**Both categorical families now have a degeneracy row in `check_gllvmTMB()`,
and this issue's three directives were each answered on their own terms —
though not all three land as a working screen.** The mechanism question is
**partially** settled — see the correction below. The multinomial screen
ships armed and measured. The ordinal threshold question is answered
**negatively, with evidence**: no threshold on the statistic tested is
defensible, so both ordinal arms ship disarmed, and the campaign identifies
what a working screen would need instead. Summary against the directives,
then the evidence.

### 1. The mechanism you flagged as unknown is PARTIALLY settled: NOT saturation (solid); separation is the residual hypothesis, NOT demonstrated

🔴 **This section was corrected on 2026-08-17, after this draft was first
written.** The original text below claimed the mechanism was settled as
"separation, not saturation" on three measurements. A follow-on campaign
(`dev/ordinal-degeneracy/pass-criteria-dichotomised.md`) has since shown that
the third of those three measurements does not discriminate at all, so the
positive half of that claim — "therefore separation" — no longer holds. What
follows is the corrected reading; see
`dev/ordinal-degeneracy/probe-criteria.md`'s appended correction for the full
record.

The issue named link saturation (cutpoint underflow in `gll_log_pnorm_diff`)
as the suspected mechanism and asked for it to be established before anything
was built. A pre-registered probe (decision rule frozen at `e932cf37`, verdict
at `b33d3b90`) ran a 60-fit grid, labelled 24 fits degenerate by per-fit truth
(`rel_frob > 10`), and measured three things:

1. **Flat-row share is EXACTLY 0 on all 24 degenerate fits.** The cutpoint
   underflow condition — both bracketing cutpoints more than 8.2924 from `eta`
   on the same side — is never reached on any observed row of any degenerate
   fit. **Link saturation is refuted by measurement**, not merely unsupported,
   and this finding is unaffected by the correction below.
2. ~~**24/24 dichotomised refits fire the EXISTING binomial detector.**~~
   **ELIMINATED as evidence, 2026-08-17.** Collapsing each degenerate fit's
   response to binary at the middle cutpoint and refitting as
   `binomial(link = "probit")` does reproduce a positive on all 24 degenerate
   fits — but a later campaign scored that same check's FALSE-POSITIVE rate
   for the first time, on 315 fits across four arms, and found it fires on
   **86.3% of healthy fits** (67.8% healthy arm, 93.3% transport, 100% mixed).
   A check that fires on 86% of healthy fits was always going to fire on
   24 of 24 degenerate ones; **the dichotomisation evidence originally cited
   for the separation mechanism does not discriminate between the two
   candidate mechanisms and carries essentially no information.** Mechanism:
   collapsing a `K = 4` ordinal response to binary destroys enough
   information to create quasi-separation IN THE REFIT that was never present
   in the data — healthy datasets give saturated binary refits
   (`saturated_fit` 0.83-0.91) with runaway loadings (`max_loading` 13.4) at a
   benign overall prevalence of 0.26.
3. **The pathology is a single-column runaway.** Worked example: one trait's
   loading 44.2 against a true `max|Lambda| = 4.79`, siblings near truth. This
   describes the runaway's shape and is not, on its own, evidence for either
   candidate mechanism.

The fourth (directional-derivative) arm landed in the pre-registered "mixed"
bucket, for a disclosed reason rather than a silent one: a uniform whole-matrix
rescale masks a single-column pathology, so that arm cannot see what
measurement 1 sees.

**Corrected standing: "NOT link saturation" is solidly evidenced.
"Therefore category-level separation" is the residual hypothesis, not a
demonstrated one** — it is what remains if saturation is refuted, not a
conclusion independently established by measurement 2 or 3.

**Consequence for the build, and it is a subtraction:** a flat-fit/saturation
arm has no empirical basis on the surviving evidence, so it was **deliberately
not built**. The ordinal row is modelled on the binomial loading arms instead
— a choice that rests on the "not saturation" finding alone and does not
depend on the separation question being resolved.

**Consequence for directive 2 (below): the binomial re-calibration is NOT a
prerequisite for the dichotomised-check route.** That route is eliminated
outright (see the eliminated-candidates note in section 2) because the
collapse manufactures damaged input, not because the binomial screen's own
thresholds are miscalibrated — recalibrating binomial would not fix it.

### 2. Ordinal thresholds were set on ordinal evidence, NOT inherited — and the measurement says no threshold is defensible

Directive 2 asked that ordinal not borrow binomial's numbers. Calibration ran
315 fits (`n = 100/400`, four pre-registered design arms;
`dev/ordinal-degeneracy/pass-criteria-ordinal.md`, frozen rule scored
2026-08-17). The frozen pre-registration measures sensitivity on the
`degenerate` arm's `rel_frob > 10` fits (41 of them) and false positives
ARM-LEVEL across `healthy` + `transport` + `mixed` combined (255 fits) — a
first scoring pass instead relabelled truth per-fit, which moved 57 fits out
of the false-positive denominator and inflated the numbers; two independent
reviewers caught the substitution before anything shipped, and the numbers
below are the frozen, corrected ones.

**At binomial's own threshold of 6, the ordinal screen measures 100%
sensitivity and 39.2% false positives** — *worse* than the 25% defect this
issue reports in binomial. Inheriting the number would not just have repeated
the failure the issue asks us to fix, it would have made it worse. The full
curve:

| threshold | O2 sensitivity | O2 FP | O1 sensitivity | O1 FP |
|---|---|---|---|---|
| 6 (binomial's) | 100.0% | 39.2% | 61.0% | 28.6% |
| 20 | 95.1% | 27.8% | 43.9% | 20.4% |
| 40 | 80.5% | 11.0% | 36.6% | 8.6% |
| 250 (first zero-FP) | 0.0% | 0.0% | 0.0% | 0.0% |

**No threshold meets the frozen conjunction (sensitivity ≥ 90% AND zero false
positives), and none can:** the healthy pool reaches `max_loading_unit` 216.9
while the degenerate arm starts at 13.5, so the classes are not separable on
this statistic at all. The first zero-false-positive point is threshold 250,
where sensitivity is 0.0%.

**Disposition: both arms ship DISARMED at `Inf`/`Inf`** — the pre-registered
fallback, applied as measured. `check_gllvmTMB()`'s `ordinal_liability_loading`
row still computes and reports both statistics for every fid-14 fit, so a
user can arm either threshold explicitly; arming a *default* is a maintainer
decision this evidence does not support.

**Five candidate statistics were tried in total, and all five are
eliminated** (full record: `docs/dev-log/after-task/2026-08-17-categorical-paper-alignment-and-detector.md`
§11): the absolute liability-scale loading (39.2% FP at binomial's own
threshold), the family-scoped relative loading (28.6% FP at best
sensitivity), loading-over-cutpoint-span (refused on its own pre-registered
circularity precondition, and fails empirically anyway), the max/second-max
spike ratio (2.4% sensitivity at the first zero-FP point), and — the fifth,
tried from a genuinely different information source — **the dichotomisation
counterfactual described in §1 above, which is also eliminated: 97.6%
sensitivity but 86.3% false positives**, worse than every one of the other
four. Closing #897's detection gap needs an information source none of these
five drew on; the observed-information / curvature structure is the
remaining untested candidate.

**What the campaign nonetheless establishes — the finding is the
deliverable:**

1. **Borrowing binomial's threshold would have been a bug, not a shortcut.**
   At 6 the ordinal screen fires on 39.2% of healthy-arm fits — worse than the
   25% binomial rate this issue exists to complain about. Directive 1's
   premise (thresholds on ordinal's own evidence, not inherited) is vindicated
   by measurement, not merely honoured procedurally.
2. **The failure mode is heterogeneous per-trait loading scales.** False
   alarms concentrate in the *transport* arm (pre-registered specifically to
   test 10-30x per-trait loading-scale heterogeneity). An absolute
   liability-scale threshold cannot transport across per-trait scale
   heterogeneity: a legitimately large loading on a wide-cutpoint trait is
   indistinguishable from a runaway. **A future ordinal screen needs a
   scale-invariant statistic, not a better constant** — that is the stated
   path forward, not a re-tuned threshold on the same statistic.

**Limits, stated rather than buried:** no `n = 1600` evidence (that arm was
dropped and `n = 400`'s seeds halved to stay inside the 30-minute pre-run
budget); the `cutpoint_span` variant was NOT promoted (its circularity
precondition was untested, so it stays calibration-only).

**Do not read this as the detection gap closed for ordinal.** The mechanism
question this issue raised is settled (§1). The threshold question is
answered — negatively, with evidence and a stated path forward — not solved.
`ordinal_probit()` fits still get no armed degeneracy screen by default.

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
per-trait loading scales, the same mechanism that produced an even higher
39.2% false-positive rate on ordinal at that same threshold — but re-tuning a
shipped, load-bearing screen on evidence gathered for a *different* family
would repeat exactly the inheritance error directive 1 warns against. It needs
its own binomial healthy/degenerate arms and its own pre-registration, and is
proposed as a follow-up issue rather than folded into this one. **This
follow-up is NOT a prerequisite for the ordinal-detection route** — the
dichotomised-check candidate that would have made it one is eliminated
outright (§1/§2 above): its failure is damaged input from the collapse, not
a mis-set binomial threshold, so recalibrating binomial would not rescue it.

### One behaviour change deliberately NOT made

**Fit-time warnings are not wired for either categorical family.** Both rows
surface through `check_gllvmTMB()` only; `gllvmTMB()` warns exactly as it did
before. Making either row an automatic warning is a change every existing user
would feel and is left to the maintainer.

### Suggested disposition

Close this issue on directives 1-3: the mechanism is **partially** settled —
NOT link saturation, solidly evidenced; category-level separation is the
residual hypothesis, NOT demonstrated (the dichotomisation evidence
originally cited for it does not discriminate — see the correction in §1);
the ordinal threshold question is answered on ordinal's own evidence,
negatively — no threshold is defensible on `max_loading_unit`, and the
dichotomised-check alternative is also eliminated (86.3% FP), so both arms
ship disarmed, with a stated path forward (a scale-invariant statistic, or an
information source neither tried candidate family drew on); `aghq_ridge` is
untouched. Multinomial's parallel gap is also closed with an armed, measured
screen. Open a follow-up for the binomial re-calibration described above
(NOT a prerequisite for the ordinal route), and a second follow-up for an
ordinal scale-invariant or refit-based statistic if a working default screen
is wanted. Full record:
`docs/design/123-multinomial-structured-surface.md` §8, register rows FAM-14 /
FAM-20 / DIA-08, and
`docs/dev-log/after-task/2026-08-17-categorical-paper-alignment-and-detector.md`.
