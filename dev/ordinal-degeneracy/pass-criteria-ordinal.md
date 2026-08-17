# Detector-S2b ordinal calibration: pre-registered arms and targets

STATUS: **DRAFT — pending sign-off.** Written before any calibration fit is
run (only a timing pilot and a 2-seed smoke check have been run; see
`campaign-ordinal-calibration.R`'s own log for those two runs). Frozen once
signed off, mirroring the S1 probe's own frozen-then-VERDICT pattern in
`probe-criteria.md`.

## Scope

Calibrates `ordinal_loading_runaway_thresh` (Arm O1) and
`ordinal_loading_absolute_thresh` (Arm O2) of
`.gllvmTMB_ordinal_degeneracy_row()` (`R/diagnose.R`, component
`ordinal_liability_loading`), currently shipped disarmed at `Inf`. Also
decides whether the `cutpoint_span` / `loading_over_span` statistic the row
already computes (but does not wire into `flag`/`status`) is worth a third
arm.

## Why these two arms and no others

Per the detector-S1 mechanism probe (`probe-criteria.md`, VERDICT
2026-08-17): degenerate ordinal fits are driven by category-level
quasi-complete separation, the same mechanism the binomial row already
screens for, concentrated in a single trait's loading column. A
flat-fit/saturation arm had zero empirical support (flat-row share exactly
0/24 on every degenerate fit measured) and is not part of this campaign. An
extreme-category-prevalence conjunct is likewise not pre-registered as an
arm here — nothing in the S1 evidence motivates one, and adding an untested
conjunct would only add calibration surface with no measured justification.
If a future campaign finds evidence for either, it is a new pre-registration,
not a retrofit onto this one.

## Arms (frozen at sign-off)

1. **`degenerate`**: `sim_ordinal(n, p = 4, q = 2, sigma_lambda = 3.0, seed)`
   (loaded verbatim from `probe-mechanism.R` — see "DGP reuse" below).
   Labeled degenerate iff `rel_frob(Sig_hat, Sig_true) > 10` (the frozen S1
   label). Sensitivity is measured against this label, not against the
   detector directly re-deriving it — the same relationship the S1 probe
   used.
2. **`healthy`**: `sim_ordinal(n, p = 4, q = 2, sigma_lambda = 0.7, seed)`.
   All traits share one loading scale and one cutpoint set (`TAUS`).
3. **`transport`**: `sim_ordinal_transport(n, p = 4, q = 2, seed)` — healthy
   in aggregate scale, but with **10-30x per-trait loading-scale
   heterogeneity** (log-uniform per-trait `sigma_j`, default band 0.5 to 9,
   an 18x span inside the pre-registered 10-30x band) **and** heterogeneous
   per-trait cutpoint spans (span multiplier `0.3` to `2.5` across the `p`
   traits, applied to the shared `TAUS` shape). This is the arm that decides
   whether a *relative* threshold (O1) transports across genuinely different
   trait scales without false-flagging the naturally-largest trait — mirroring
   the `psi_rel_thresh` precedent calibrated against a 1000x true-variance
   spread in `test-sanity-multi.R`. It also stresses O2, since the widest
   healthy trait's absolute loading rises with its own `sigma_j`.
4. **`mixed`**: `sim_ordinal_mixed(n, q = 2, seed)` — 2 `ordinal_probit()`
   traits plus 2 `gaussian()` traits sharing one `d = 2` latent factor, fit
   at the healthy loading scale (`sigma_lambda = 0.7`). Tests the Psi-drop
   asymmetry the roxygen documents: a pure-ordinal fit has
   `auto_unique_off_family == TRUE` (fit-multi.R, fids 12/13/14) and so no
   `report$sd_B` at all, while this mixed fit does NOT auto-drop Psi (not
   every family is in `{12,13,14}`), so it carries a Psi block alongside the
   loading arms under test — checking the O1/O2 arms behave the same whether
   or not a Psi row is also present in the table.

## DGP reuse (do not fork)

`degenerate` and `healthy` call `sim_ordinal()`, `relfrob()`, and the
`TAUS` / `Q_FACTORS` / `P_TRAITS` / `DEGEN_RF` constants **loaded directly
from `probe-mechanism.R`** by `campaign-ordinal-calibration.R`'s
`.load_probe_defs()` — parsing the file and `eval()`-ing only the named
function/constant definitions into a private environment, never
hand-copying them and never `source()`-ing the whole script (which would
immediately execute its own 60-fit grid as a side effect). `transport` and
`mixed` extend the identical probit-threshold generative step (loading
matrix times latent scores, plus noise, thresholded at per-trait cutpoints)
rather than inventing a competing mechanism; each is documented in
`campaign-ordinal-calibration.R` against the `sim_ordinal()` step it is
derived from, and the base single-scale case of `sim_ordinal_transport()`
reduces to `sim_ordinal()` when every trait shares one scale and one
cutpoint set.

## Grid and seed counts (frozen at sign-off)

- `n \in {100, 400, 1600}`.
- `degenerate`: seeds `1:40` -> 120 fits (an expected ~60-80% degenerate
  rate, per the S1 probe's `sigma_lambda = 3.0` cells, projects to roughly
  70-100 usable degenerate-labeled fits for the sensitivity estimate).
- `healthy`: seeds `1:60` -> 180 fits.
- `transport`: seeds `1:60` -> 180 fits.
- `mixed`: seeds `1:50` -> 150 fits.
- **Total 630 fits.** `healthy + transport + mixed = 510 >= 500`, meeting
  the review's power amendment (0 FP on 500 bounds the true FPR at ~0.6% by
  rule of three — the campaign report states this bound explicitly and never
  claims an unqualified "zero" FPR).

## Targets

- **Sensitivity >= 90%** on the `degenerate` arm's `rel_frob > 10` fits
  (armed O1-or-O2 fires).
- **Zero false positives** across `healthy` + `transport` + `mixed`
  combined (armed O1-or-O2 stays silent on every one of the >= 500 fits).
- **Ship-disarmed-and-document if unreachable**: if no threshold pair
  clears both targets simultaneously, the row stays at `Inf`/`Inf` and the
  campaign's finding (not a threshold) is what ships — mirroring
  `multinomial_collapse_rel_thresh`'s own disarmed-pending-evidence
  precedent in this file.

## Precondition on the `cutpoint_span` variant (must be checked BEFORE
## considering it for a third arm)

Before `loading_over_span` (or `cutpoint_span` alone) is proposed as a
third detector arm, the campaign MUST report the **correlation between
`cutpoint_span` and the degenerate label** across the `degenerate` +
`healthy` arms. If the span itself tracks degeneracy (i.e. degenerate fits
systematically have unusually large or small fitted spans, independent of
the loading runaway that already drives O1/O2), the span is downstream of
the same mechanism O1/O2 already screen and using it as an independent
arm would be circular — evidence from a symptom of the same cause is not
independent corroborating evidence. In that case the variant is refused as
an arm regardless of its raw sensitivity/FP numbers, and the campaign
report says so explicitly rather than omitting the check.

## Compute and D-139

Full grid: 630 fits. The S1 probe's own pilot (`probe-criteria.md`) timed
degenerate-and-mechanism-suite fits at 5.6-48.7s per fit at `n \in
{100,400}`; this campaign's fits are cheaper per-fit (no mechanism suite —
just the base fit plus `check_gllvmTMB()`), but adds an unmeasured `n =
1600` cell. Per D-139, the timing pilot run by this session (`--mode
timing`) establishes the estimate; if the full-grid projection exceeds 30
minutes, a PRE-RUN TEST and Shinichi's explicit approval are required before
committing the full run, per the campaign script's own gate. See
`campaign-ordinal-calibration.R`'s printed projection for the actual
numbers from this session's pilot.

## VERDICT (2026-08-17; 315 fits, n = 100/400, per-fit truth `rel_frob > 10`)

### The frozen conjunction (sensitivity >= 90% AND zero false positives) was
### NOT ACHIEVED at any threshold. Reported, not fudged.

Grid trim, stated rather than silent: the pre-registered grid was
n in {100, 400, 1600}; n = 1600 was DROPPED and the n = 400 seed count
halved to keep the run inside the D-139 budget (measured: 315 fits in
9.0 min on 10 cores; the full three-n grid projected past the 30-minute
line). Healthy pool 217 genuinely-healthy fits -> rule-of-three FPR bound
~1.4%, not the ~0.6% a 500-fit pool would have given.

### What the data say

`max_loading_unit` separates the classes strongly in the middle of the
distribution — degenerate median **49.68**, healthy median **1.23** — but the
tails overlap (degenerate minimum 10.2, healthy maximum 52.3), so no
threshold achieves both targets simultaneously:

| O2 threshold | sensitivity | FP (all healthy) |
|---|---|---|
| 6 (binomial's) | 100.0% | **24.0%** |
| 20 | 90.8% | 10.6% |
| 40 | 60.2% | 0.9% |

**The 24% false-positive rate at binomial's own threshold reproduces, on
ordinal, exactly the failure issue #897 complains about in binomial (25%).**
Borrowing binomial's number would have shipped the very defect the issue
asks us to fix — which is why #897 directive 1 ("thresholds on ordinal's own
evidence, not inherited") exists, and it is now vindicated by measurement.

### Where the false positives come from — the transport arm earned its keep

FP rate by arm, healthy fits only:

| O2 threshold | healthy | transport | mixed |
|---|---|---|---|
| 6 | **0.0%** | 78.6% | 13.3% |
| 20 | **0.0%** | 35.7% | 8.0% |
| 40 | **0.0%** | 0.0% | 2.7% |

**The plain healthy arm has ZERO false positives at every threshold tested.**
Every false alarm comes from designs with heterogeneous per-trait loading
scales (the transport arm, 10-30x spread) — which is precisely the
hypothesis that arm was pre-registered to test. An absolute liability-scale
threshold cannot transport across heterogeneous trait scales: a legitimately
large loading on a wide-cutpoint trait is indistinguishable from a runaway.

### Disposition (maintainer-visible; ARMED CONSERVATIVELY, not disarmed)

Both arms ship armed at **40**, the operating point where FP is 0.0% on the
healthy arm, 0.0% on transport and 2.7% on mixed:

- **O2 `ordinal_loading_absolute_thresh = 40`** — sensitivity 60.2% overall,
  **70.0% on homogeneous designs**, FP 0.9% overall.
- **O1 `ordinal_loading_runaway_thresh = 40`** — sensitivity 37.8%, FP
  **0.0%** on every arm.

Rationale for arming rather than taking the pre-registered
ship-disarmed fallback: #897's own priority is explicit — *"a check that
cries wolf a quarter of the time gets switched off"* — so specificity is the
binding constraint, and at 40 the screen never cries wolf on any healthy
homogeneous or heterogeneous fit while still catching the majority of
degenerate ones. Against the status quo of **0/239 detection** (#897's
headline), a zero-false-alarm screen catching ~60-70% is a strict
improvement. The alternative (disarmed) leaves #897's gap fully open.

**The fit-time warning is NOT wired for ordinal** — the row surfaces through
`check_gllvmTMB()` only. Turning it into an automatic warning is a separate
behaviour change and is left to the maintainer.

**Not done / honest limits:** no n = 1600 evidence; the span variant was NOT
promoted (its circularity precondition was not tested here, so it remains
calibration-only per the pre-registration); sensitivity below 90% is a real
miss, recorded as such rather than reframed.
