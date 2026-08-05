# After Task: VA ordination surface made usable (point estimates), with measured recovery

**Date:** 2026-08-05 · **Agent:** Claude Code (solo) · **Branch:** `claude/va-lane2`
**Worktree:** `/private/tmp/gllvmtmb-va-lane2` · **Compute:** local (8 cores), results LOCAL per D-50

## 1. Goal

Make the VA route usable for users — Laplace stays the default. A user who fit with
`gllvmTMBcontrol(integration = "va")` could `print()` and `summary()` and then nothing: every
extractor that produces the ordination a GLLVM exists for died by undefined-field access.

Maintainer direction, this session: *"we will make VA usable for users (LA stays as the default
yes)"*, and — cancelling the previous plan — *"VA is already good, we do not need to do sandwich"*.
Scope decisions taken with the maintainer: working extractors rather than politer errors; quantify
the documented attenuation in-arc; return `getLV(se = TRUE)` as a labelled posterior SD.

## 2. Implemented

**One choke point unlocked all four extractors.** `getLV()`, `getLoadings()`,
`extract_loadings()` and `extract_ordination()` all funnel through `extract_ordination()`
(`R/extractors.R:463`), which broke on exactly two lines — `:478 fit$tmb_obj` and
`:480 fit$data[[fit$trait_col]]`, neither of which a VA fit carries. A `gllvmTMB_va` branch
(4 lines, placed before those lines) dispatches to `.va_extract_ordination()`.

- `Lambda` unpacked from `theta_rr` via the engine's own `.va_r3_unpack_theta_rr()`; scores from
  the variational means. Trait/unit labels are **synthesised** (`trait1..p`, `unit1..n`) — a VA fit
  stores no data or column names; the convention mirrors the Julia bridge extractor's identical gap.
- `level = "unit_obs"` returns `NULL` (the route fits no within-unit tier).
- `getLV(se = TRUE)` returns the variational **posterior SD**, with `uncertainty_basis` and
  `calibrated = FALSE` as attributes on the returned matrix.
- `predict.gllvmTMB_va()` added: refuses via `.va_not_defined()` instead of R's bare dispatch error.

## 3. Files Changed

`R/extractors.R` (VA branch) · `R/va-methods.R` (`.va_extract_ordination`, `.va_getLV_se`,
`predict.gllvmTMB_va`) · `R/output-methods.R` (`getLV` VA se path + roxygen) · `R/gllvmTMB.R`
(`integration` roxygen) · `NAMESPACE` · `man/{extract_ordination,getLV,gllvmTMB_va-methods,gllvmTMBcontrol}.Rd`
· `docs/design/35-validation-debt-register.md` (row VA-13) ·
`docs/design/va-capability-worklist.md` · `docs/design/85-highdim-nongaussian-va-formal-contract.md`
· `tests/testthat/test-va-ordination.R` (new) · evidence under `dev/va-usability/` (untracked, D-50).

## 3a. Decisions and Rejected Alternatives

- **Rejected: "safe edges only"** (guards + clear errors). It would leave VA politely unusable —
  a user could still not plot an ordination. Maintainer chose working extractors.
- ~~**Rejected: exposing `eval_method` to users** to route around binomial attenuation. Measurement
  showed the alternative tier is not better (see §5), so the API change would have bought nothing.~~
  🔴 **SUPERSEDED SAME DAY by the n-ladder (§5a).** This bullet was written when only two `n` were
  known, where `gh` looked merely like an overshoot (1.507/1.172) against `jj`'s undershoot
  (0.670/0.582). The ladder to n=2000 reversed the reading: **`jj` PLATEAUS at 0.535 — a genuine
  plim, asymptotically biased — while `gh` CONVERGES (1.583 → 1.132 → 1.014).** So the alternative
  tier *is* better, for loadings, and the API change would buy exactly what this bullet said it
  would not.
  **Revised recommendation, for the maintainer (NOT actioned in this arc):** *expose* the tier via
  `gllvmTMBcontrol()` — additive, reversible, no default change, no reproducibility break — rather
  than change the binomial default. Changing the default is NOT recommended: `gh` costs ~33× and
  the ladder shows the tier makes **no difference to latent scores** (`jj` 0.583/0.578/0.604 vs
  `gh` 0.569/0.578/0.614), so it buys nothing for the ordination itself and only corrects loading
  magnitude. Precedent for the restraint: ledger claim 49 (`n_starts`), *"NOT SUPPORTED in this
  cell ⚠ explicitly not licence to change the default."*
- **Rejected: fencing binomial out of the extractors.** The Laplace control showed binary
  recovery is data-limited, not VA-limited — fencing would have implied a VA defect that does not exist.
- **Adopted after adversarial review: gate `getLV(se=TRUE)` on the MECHANISM, not the tier label**
  (see §8).

## 4. Checks Run

```sh
export NOT_CRAN=true
Rscript -e 'devtools::document()'
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="va-ordination")'   # 34 assertions, 0 failures
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="va-intervals")'    # 83 assertions, 0 failures (the fence)
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="va")'              # 9 files, 0 failures
Rscript -e 'devtools::load_all("."); testthat::test_local()'                         # full suite
```

Evidence campaign: 6 cells × 50 seeds VA + 6 × 50 Laplace control + 2 × 50 GH probe + probit smoke,
~4.2 min local on 8 cores. Smoke-first discipline observed (1 cell / 1 seed / inspected before each grid).

## 5. Tests of the Tests

The recovery evidence carries its own control, which is the point. Measuring VA against *truth*
alone would have been uninterpretable: binary data at `p=8, q=2` is information-poor, so a low
correlation might mean nothing about VA. Running Laplace on the **same simulated data, same seeds**
is what makes the number readable.

| family | n | VA trace | LA trace | VA latent-r | LA latent-r |
|---|---|---|---|---|---|
| gaussian | 150 | 1.009 | 1.010 | 0.937 | 0.934 |
| gaussian | 400 | 0.979 | 0.979 | 0.944 | 0.944 |
| binomial | 150 | 0.670 | 198.99 | 0.587 | 0.563 |
| binomial | 400 | 0.582 | 16.97 | 0.593 | 0.590 |
| poisson | 150 | 1.022 | 1.035 | 0.887 | 0.886 |
| poisson | 400 | 0.985 | 0.997 | 0.890 | 0.889 |

The gaussian arms agree to `1.8e-07` / `6.7e-08` on latent-r **through different
parameterisations** (VA carries residual variance in `log_sigma`, LA in the `unique` tier) — a
copy-paste bug would give exactly 0, so the small nonzero difference is evidence the harness is
sound. The `unique` trap that once drove a coverage number from 0.517 to 0.096 was handled
explicitly: LA uses `unique = TRUE` for gaussian only, where the DGP plants real `psi`.

### 5a. Follow-up evidence (folded in during closing pass, same day)

**Paired gllvm (CRAN 2.0.13) head-to-head.** Both engines fit to IDENTICAL simulated data and seeds
against the published reference implementation (Niku, Hui, Taskinen, Warton), scored on the same
planted truth (`dev/va-usability/71-gllvm-paired-head-to-head.R`, `71-paired-summary.csv`):

| cell | ours r | gllvm r | paired Δr | 95% CI | ours wins |
|---|---|---|---|---|---|
| binomial n=150 p=8 | 0.598 | 0.565 | +0.0334 | [+0.0015, +0.0652] separated | 13/20 |
| binomial n=150 p=20 | 0.749 | 0.743 | +0.0064 | [-0.0015, +0.0142] | 10/20 |
| binomial n=400 p=8 | 0.615 | 0.590 | +0.0240 | [-0.0029, +0.0510] | 8/20 |
| gaussian n=150 p=8 | 0.9420 | 0.9420 | +8.2e-07 | — | 8/19 |

Verdict: **we match gllvm.** Only one cell's CI separates from zero, and even there our
per-replicate win rate is 13/20 — the mean is carried by a few seeds, not a uniform edge. Gaussian
agrees to 7 dp (both packages compute an exact closed form for this family), which validates the
paired harness more than it validates either engine specifically. `ours_wins` alongside the CI is
the per-seed agreement statistic [[WHAT-WORKS]] asks for.

**Retraction: an earlier UNPAIRED comparison.** Before the paired script above existed,
`dev/va-usability/70-gllvm-external-benchmark.R` scored gllvm on its own fresh seed stream and set
the result beside "our" numbers pulled from two OTHER scripts' seed streams (`A2-summary.csv`,
`60-pladder-summary.csv`). That produced the claim "we are marginally ahead on every cell" (gaps
+0.004 to +0.029 across the four cells). **It does not survive:** the unpaired standard error of
the difference is ≈0.026 at the p=8/n=150 cell alone (combining each arm's own across-seed SD over
20 seeds), which swamps every one of those gaps. Superseded by the paired script above. See §8
(defect 4) for the process failure this represents.

**gllvm's VA shows the same binomial loading attenuation as ours.** Paired trace ratios
(`71-paired-summary.csv`): ours 0.645 / gllvm 0.619 at n=150,p=8; ours 0.560 / gllvm 0.539 at
n=400,p=8 — both packages undershoot 1 by a similar margin on identical data. This package's own
reverse-engineering of gllvm's VA objective (`dev/va-speed/GLLVM-REFERENCE-READ.md:92`) already
recorded why: gllvm's binomial term "reads as a fixed-curvature (Bohning-style) quadratic bound
applied uniformly," the same bound class as our default `jj` tier. gllvm ships no exact-quadrature
alternative for binomial either, so a gllvm user hitting this ceiling has only `method = "LA"` to
fall back on — the attenuation looks like a property of the bound family, not a gap specific to
this package.

**n-ladder: the loading-scale bias is asymptotic, not finite-sample.**
(`dev/va-usability/80-nladder-summary.csv`, q=2, p=8, 20 seeds/cell.) Trace ratio (target 1) at
n=150/400/1000/2000: `jj` 0.777 / 0.600 / 0.538 / 0.535 — moving away from 1, then plateauing near
0.535, i.e. a genuine `plim` short of 1, not shrinking finite-n noise. `gh` (exact quadrature) at
n=150/400/1000: 1.583 / 1.132 / 1.014 — converging toward 1 from above (not run at n=2000: capped
at n≤1000 by design on cost grounds, see below). Latent-score recovery is essentially unaffected by
the tier: `jj` 0.583/0.578/0.604 vs `gh` 0.569/0.578/0.614 at n=150/400/1000. So `gh`'s much higher
cost (median fit-time ratio 33.14×/33.58× at n=150/400, `dev/va-usability/30-gh-followup.log`) buys
back loading SCALE but nothing for the ordination itself.

**p-ladder: the r ≈ 0.59 "ceiling" is a thin-`p` artefact, not a method ceiling.**
(`dev/va-usability/60-pladder-summary.csv`, n=150, q=2, 20 seeds/cell.) Binomial latent-r climbs
0.568 / 0.774 / 0.859 / 0.919 at p=8/20/40/80, with across-seed SD collapsing from 0.078 to 0.008
over the same range. At p=80, binary data reaches 0.919 — closely approaching, though not quite
matching, gaussian's own 0.937 ceiling at p=8. The paired gllvm benchmark reproduces the same climb
over the two p values it covers: gllvm r 0.565 → 0.743 at p=8 → p=20 (`71-paired-summary.csv`) —
the same trajectory confirmed in an independent implementation, not an artefact of this package's
estimator.

**AC (Albert-Chib) is partially rehabilitated for probit ordination.**
(`dev/va-usability/90-probit-ac-summary.csv`, `binomial_probit`, n=150, q=2, 20 seeds/cell.) The
existing §10 "AC is not the route" verdict was a one-seed read at p=8 alone. Across this p-ladder,
AC's latent-r climbs 0.508 / 0.864 / 0.925 at p=8/20/40 — the same trajectory as the logit p-ladder
above — at a verified median 21.8× lower fit time than probit-`gh` at p=8 (range 16–25× across 20
paired seeds; recomputed here from `dev/va-usability/raw/A2-probit-{ac,gh}_p8.rds`'s `fit_s` field,
since the ~17× figure floated informally this session does not reproduce from the logged data and
should not be quoted). AC's loading SCALE stays materially attenuated throughout (trace 0.151 /
0.566 / 0.787 at p=8/20/40) even as its latent-r recovers. Probit-`gh` itself looks materially
better than binomial-logit for ordination: trace ratio near 1 throughout (1.126 / 1.173 / 1.219 at
p=8/20/40) and latent-r 0.732 at p=8, well above logit's 0.568 at the same n/p/q. One p-ladder of 20
seeds/cell is documentation-grade evidence (§10), not a calibration-grade result.

## 6. Consistency Audit

```sh
grep -rniE "va (fit|route).{0,40}(cannot|no) (extract|ordination|getLV)" R/ docs/design/   # none
grep -rn "fence shut" R/ docs/                    # only the corrective note + 2 dated handovers
grep -n "outside the shipped" docs/design/85-*.md # retained as SUPERSEDED record, not deleted
grep -n "gllvmTMB_va" NAMESPACE                   # 14 S3 methods incl. predict
```

The two surviving "fence shut" hits are in dated 2026-08-04 handover documents — historical
records, deliberately not rewritten.

## 7. Roadmap Tick

VA remains a fenced research route; `integration = "laplace"` remains the default. Nothing promoted.

## 7a. GitHub Issue Ledger

No issue opened or closed. Three findings are carried forward in §10 for a future lane.

## 8. What Did Not Go Smoothly

**The adversarial review (Opus, refute-first) found three real defects. It earned its cost.**

1. **A live bug I had shipped.** Gating `getLV(se=TRUE)` on `eval_method` left a hole: the `"ac"`
   branch is *unreachable* from the public route (`R/va-routing.R:350-355` emits only `"jj"`/`"gh"`),
   while a public **gaussian** fit resolves to `"gh"` and returned a per-unit SD **constant across
   all units** (measured CV 1.6e-15) — precisely the degeneracy the `"ac"` refusal existed to
   prevent. Fixed by gating on the observable property (per-column CV `< 1e-8`), which is
   mechanism-based and covers corners not yet enumerated. Two regression tests added.
2. **Wrong numbers, and a framing that flattered VA.** I extracted `sigma_ratio` as a scalar when it
   is a length-8 per-trait vector, so my ad-hoc snippet silently used trait 1 only. "Max 1.8",
   "4/50 seeds > 100×" and "max 4134×" were statistics produced by that bug. Correct maxima are
   **1.136 / 0.804** (`A2-summary.csv`). The robust picture also **inverts** the framing I wrote:
   Laplace's median trace ratio brackets 1 (1.137/0.854) while VA's does not (0.664/0.592), and
   Laplace exceeds VA on **100/100 paired seeds** — so VA's low binomial loading scale is a real
   bias relative to Laplace, not merely Laplace instability. Corrected in VA-13, with the effort
   asymmetry disclosed (VA 4 starts + agreement gate vs LA 1 start on `pdHess`).
   *Note: Curie's `A2-ATTENUATION.md` table was always correct and reproduced exactly under
   independent recomputation. Only the numbers I hand-derived were wrong.*
3. **A false statement written into a governing design document.** I claimed Design 85's NO-GO
   governs `q = 4/6` while the fence's `q <= 2` sits where "Gates 0–2 DID support". **False.**
   Gate 3 (`:428`) is *"joint-fit known-DGP recovery at `q = 1/2`"* — the gate that FAILED is the
   recovery gate in exactly the regime the fence admits. `q = 4/6` is Gate 5 (`:456`), never
   reached. Corrected, and the containment sentence restored as **superseded rather than deleted**,
   recording that `8def9781` (2026-07-31) made the route publicly reachable eleven days after the
   NO-GO closed, without reopening the design.
4. **A fourth defect, this one NOT caught by the adversarial review — an unpaired comparison
   published as though it settled a paired question.** `dev/va-usability/70-gllvm-external-benchmark.R`
   scored the CRAN `gllvm` package on its own fresh seed stream and set the result beside "our"
   numbers pulled from two OTHER scripts' seed streams (`A2-summary.csv`, `60-pladder-summary.csv`),
   then the write-up asserted "we are marginally ahead on every cell" from gaps of +0.004 to +0.029
   across four cells. It does not survive: the unpaired standard error of that difference is ≈0.026
   at the p=8/n=150 cell alone, which swamps every one of those gaps. Superseded by the paired
   script `71-gllvm-paired-head-to-head.R` (§5a), which fits both engines to identical data and
   seeds and finds the two packages statistically indistinguishable on 3 of 4 cells. What makes
   this the fourth defect rather than a cousin of the first three: [[WHAT-WORKS]]'s "pair, don't
   sample independently" rule had been re-filed into the brain **the same session, roughly an hour
   before the violation** — the lesson was current, written down, and still did not fire. Caught
   only because a paired follow-up was run anyway, not because the first write-up was checked
   against it.

**Sub-agent stalls.** Both producer agents repeatedly ended their turn saying they would "wait for
the monitor's notification" after launching a background command — four times for one, twice for
the other. Work was recovered each time by the orchestrator relaunching the run and verifying
directly. **Lesson: verify sub-agent output from the artifacts, never from the agent's own report** —
which is also how defect (2) was caught, since the stall meant I recomputed numbers myself.

## 9. Team Learning

**A measurement without a control can be worse than no measurement.** The first two rounds of
evidence said binomial VA attenuates loadings to ~0.6× and no tier fixes it. Both true, and both
about to be documented as a VA deficiency. The Laplace control — commissioned late, only because
the GH result prompted "compared to *what*?" — showed every estimator including the shipped default
sits at r ≈ 0.59 on binary data. **The control should have been in the original brief.**

**Adversarial review must attack the claim you most want to be true.** The brief told Fisher to go
hardest at the Laplace control, because it was the finding that rescued the arc and therefore the
one most likely to be flattering. It survived — but the review found three other things by working
in that spirit.

**A lesson just re-filed is not a lesson yet installed.** [[WHAT-WORKS]]'s "pair, don't sample
independently" was written into the brain roughly an hour before this arc's unpaired gllvm
comparison violated it anyway (§8, defect 4). Filing a rule and having it fire under time pressure
are different achievements — the paired re-run happened because someone asked "compared to what
stream?", not because the rule was consulted before publishing. The external validation itself was
still worth having: gllvm now confirms, on identical data, that we match it (§5a). But the first
attempt at it is the same near-miss pattern this report already catalogues twice over.

## 10. Known Limitations and Next Actions

- **`p = 8` only in the original A2 grid — since extended, but still narrow.** This closing pass
  folds in a p-ladder that ran p in {8, 20, 40, 80} at n=150, q=2, for both binomial-logit
  (`60-pladder-summary.csv`) and binomial-probit AC/GH (`90-probit-ac-summary.csv`; §5a). The fence
  still admits p up to 80, and these are the only p>8 cells anyone has measured. Still untested:
  p>8 at n=400+, p>80 anywhere, and any family other than binomial at p>8.
- **Not effort-matched.** VA ran 4 starts behind an agreement + gradient gate; Laplace 1 start on
  `pdHess`. The Laplace tail is confounded with this. The same asymmetry recurs inside VA itself:
  the n-ladder's `gh` tier was capped at n≤1000 purely on cost grounds (median fit-time ratio
  33.14×/33.58× vs `jj` at n=150/400, `dev/va-usability/30-gh-followup.log`), so the `jj`
  asymptotic-bias finding (§5a) rests on a longer ladder than the `gh` convergence finding does.
- **20–50 seeds/cell** (50 for the original A2 grid; 20 for this session's paired-gllvm, n-ladder,
  p-ladder, and AC-probit-ladder campaigns) supports a documented number, not a calibration-grade
  claim. No MCSE-backed pass/fail, no coverage statement, anywhere in this arc.
- **CARRIED FORWARD (1): Laplace's binary loading instability.** 9/50 seeds above 100× at n=150,
  max 2716×. A finding about the **shipped default engine**, surfaced incidentally by a control run.
  Out of scope here; should not be lost.
- **CARRIED FORWARD (2), UPDATED: probit breaks the r ≈ 0.59 ceiling, and AC is now a documented
  partial route, not just a one-seed probe.** The original single-seed probe stands confirmed and
  extended by this session's probit p-ladder (`90-probit-ac-summary.csv`, 20 seeds/cell, §5a):
  probit-`gh` reaches latent-r 0.732 at p=8 (vs the original probe's 0.725), corroborated in
  direction by the package's own AD-safety test (`max|log Sigma_B ratio|` 0.1696 vs Laplace-probit
  against 0.9653 vs Laplace-logit). AC — dismissed at one seed as "not the route" — climbs latent-r
  0.508/0.864/0.925 at p=8/20/40, the same trajectory the logit p-ladder shows, at a verified median
  21.8× lower fit time than probit-`gh` (range 16–25×, p=8). AC's loading SCALE stays materially
  attenuated throughout (trace 0.151/0.566/0.787 at p=8/20/40) even as its latent-r recovers, so
  "AC is not the route" should narrow to "AC is not the route for loading MAGNITUDE," not for
  ordination. Still 20 seeds/cell, one n (150), one q (2) — documentation-grade per the seed-count
  bullet above, not a reversal of the fence.
- **CARRIED FORWARD (3), NEW: `jj`'s binomial loading-scale bias is asymptotic, not a small-n
  artefact.** The n-ladder (`80-nladder-summary.csv`, n up to 2000, §5a) shows the trace ratio
  moving away from 1 and then plateauing near 0.535, not returning toward 1 — no amount of
  additional data fixes loading MAGNITUDE under the default `jj` tier. It costs nothing on the
  ordination itself: latent-score recovery is statistically flat across `jj` vs `gh` at every n
  measured. A user who needs calibrated loading magnitudes (not just ordination axes) under
  binomial-logit has no route to that within the fence today, at any `n`.
- **Definition of Done, item 4 (runnable user-facing example): NOT MET, deliberately.** The
  maintainer scoped the vignette out of this arc when choosing between "working extractors" and
  "working extractors AND a worked example". Recording the omission rather than skipping it silently.
