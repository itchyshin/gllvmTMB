# E1 calibration campaign — pre-registration

**Status: PRE-REGISTRATION — awaiting maintainer launch approval.** No compute
is spent, no code is touched, and nothing on the validation-debt register moves
by this document alone. This asks Shinichi to approve a full-scale run of the
env-slope (E1) Wald-coverage measurement that the 2026-08-18 feasibility grid
scoped but could not resolve at n=100 reps/cell — i.e. to move from "the
uncalibrated SE looks defensible in the neighbourhood of nominal" to a
PASS/FAIL/INDETERMINATE verdict per cell that Design 118's own resolution
rule can actually deliver.

**Lane:** Curie (Lane C, design/evidence lane), worktree
`/private/tmp/gllvmtmb-ayumi25` (checkout of `origin/main`, no local commits by
this lane). No branch opened for this document; landing is another lane's or
the maintainer's call.

---

## 0. What "E1" is (established reading, cited)

**E1 = per-species Wald coverage of the environmental-slope fixed effect
(`trait:env`) in `isdm_sources()` fits** — the first-ranked estimand in the
proposal's own table and the only one the feasibility grid found *not*
already broken.

Established from two internally consistent sources:

1. The campaign proposal's estimand table ranks "Fixed-effect contrasts —
   per-species env slopes (`trait:env`)" **Rank 1**, noting "Wald SE exists
   internally but **coverage never measured**"
   (`docs/dev-log/research/2026-08-17-isdm-interval-campaign-proposal.md` §1).
2. The feasibility-results document labels its own headline section **"E1 —
   env-slope Wald coverage (the headline feasibility question)"** and reports
   per-cell-per-species coverage of `beta_j` via `est ± 1.96·se(b_fix)` on the
   `trait:env` coefficients
   (`dev/isdm-intervals/2026-08-18-feasibility-results.md`, confirmed against
   the harness `dev/isdm-intervals/campaign-intervals.R`, which computes
   `cov_env_sp1/2/3` from `bhat`/`bse` on the `:env` block of `fit$X_fix_names`).

Confidence: **high** — the two documents use the label identically and the
harness code confirms the computation. This pre-registration proceeds on that
reading without further caveat. (E2 = latent-loading amplitude coverage, E3 =
intensity-ratio intervals, E4 = `predict(se.fit)` eta coverage are the
sibling labels in the same grid; none of the three is in scope here — see §7.)

---

## 1. ADEMP design (Morris, White & Crowther 2019; reporting per Williams et
al. 2024)

### A — Aims

**Primary aim.** Determine, per grid cell and per species, whether the
existing uncalibrated Wald SE for the `trait:env` fixed-effect coefficient in
`isdm_sources()` fits achieves coverage inside Design 118's own
`[0.92, 0.98]` band at nominal 95%, at a replicate count (`n ≥ 580`) capable
of actually resolving PASS from FAIL rather than reporting INDETERMINATE by
construction.

**Secondary aim.** Characterise whether any single factor (`n_cells`,
effort ratio, `n_sources`, field amplitude) drives systematic under- or
over-coverage, so that a future calibrator (if one turns out to be needed)
can be scoped to the regime that actually requires it rather than the whole
grid.

**Explicitly not an aim:** building or fitting a calibrator. This campaign
measures the SE that already ships; it does not construct an `alpha*` map.

### D — Data-generating mechanism

Identical DGP and estimator to the approved feasibility grid — no new code,
same harness (`dev/isdm-intervals/campaign-intervals.R`), only the replicate
count changes. Restated for completeness:

- Contract: `isdm_sources()` — one Poisson-log count arm(s) + one
  Bernoulli-cloglog detection arm, `n_sources - 1` count arms and 1 PA arm.
- Per cell, 3 species (`sp1, sp2, sp3`) with fixed true intercepts
  `alpha = (-0.2, 0.2, 0.0)` and fixed true env slopes
  `beta = (0.5, -0.3, 0.4)` — **`beta` is E1's estimand truth**.
- A latent factor `d = 1` (`latent(0 + trait | cell_id, d = 1)`) with true
  loadings `lambda = amp * (0.8, 0.5, -0.4)`, `amp in {1 (weak), 2 (strong)}`.
- Per-source intercepts `gamma[d, ]` for `d > 1` are drawn fresh each
  replicate from `Uniform(-1, 1)` (nuisance, not a coverage target) — this
  matches the already-approved harness; it is not a new design choice.
- Fitted formula: `value ~ 0 + trait + trait:env + trait:src +
  offset(log_support) + latent(0 + trait | cell_id, d = 1)`, `family =
  isdm_sources(...)`.
- Effort/support `eff = (2.0, 2.0/eff_ratio, ...)`; the PA arm's success
  probability is `1 - exp(-eff * exp(eta))` (cloglog exact form), count arms
  `Poisson(eff * exp(eta))`.

**Factors** (identical to the feasibility grid, for direct comparability of
point coverages already measured):

| Factor | Levels |
|---|---|
| `n_cells` | 150, 810 |
| effort ratio | 1x, 10x |
| `n_sources` | 2, 3 |
| field amplitude | weak (1x), strong (2x) |

$2\times2\times2\times2 = 16$ cells, unchanged from the feasibility grid.

**Replicates per cell, justified by MCSE (Williams item 2, "number of
simulation runs justified"):** coverage MCSE $=\sqrt{p(1-p)/n}$ at $p=0.95$.

| $n$ | MCSE | Note |
|---|---|---|
| 100 (already run) | 2.18% | feasibility grid; correctly reported INDETERMINATE everywhere |
| 580 | 0.905% | Design 118's own Wilson-half-width-<0.015 floor |
| **600 (recommended)** | **0.889%** | Design 118 §2.5's registered value, $w=0.0147$ |
| 2000 (one-shot escalation) | 0.487% | Design 118's escalation target for cells that stay INDETERMINATE at 600 |

**Recommendation: register $n=600$ per cell**, identical to Design 118 §2.5
("Wilson 90% half-width < 0.015 at $\hat p=0.95$ requires $n\ge580$; Phase B
registers $n=600$ per cell"), for two reasons: it is the smallest replicate
count Design 118 found sufficient to resolve its own three-way rule, and
adopting the same $n$ keeps this campaign's numbers comparable to that
precedent's resolution power. This choice is flagged in §8 (NEEDS SHINICHI)
because E1 is a different estimand family from Design 118's binary-loading
target and the number is not automatically inherited — it is a fresh
decision that happens to match.

### E — Estimands

| Estimand | True value | Estimator output | Scope |
|---|---|---|---|
| $\beta_j$, per-species env slope, $j \in \{$sp1, sp2, sp3$\}$ | $(0.5, -0.3, 0.4)$ | `b_fix` on the `trait:env` block, Wald 95% CI $=\hat\beta_j \pm 1.96\cdot\mathrm{se}(\hat\beta_j)$ from `TMB::sdreport()` | **In scope — this is E1** |

$16$ cells $\times$ 3 species $= 48$ cell-by-species coverage verdicts, each
computed **on PD-Hessian fits only** (per-cell PD rate measured 0.81–0.90 in
the feasibility run; non-PD fits report `se_ok = FALSE` and are excluded from
the coverage denominator, exactly as the feasibility grid did — never
imputed, never pooled across cells or species).

### M — Methods

One estimator only: `gllvmTMB()` Laplace MLE through the `isdm_sources()`
admission contract (`R/` — no code touched by this document), Wald SE via
`TMB::sdreport()` delta method on the fixed-effect block. No calibrator, no
alternative interval construction (profile, bootstrap, BCa) is fitted here —
those are out of scope by design (§7). This mirrors the feasibility grid's
own method exactly; the only change is replicate count.

Software: R (package `gllvmTMB` `0.7.0` per `DESCRIPTION` at this checkout),
`TMB`, base `parallel::mclapply`. Same versions as the feasibility run since
no code changes between that run and this proposal.

### P — Performance measures

| Measure | Formula | MCSE |
|---|---|---|
| Coverage, per cell $\times$ species | $\widehat{\mathrm{cov}} = \frac{1}{n_{\mathrm{PD}}}\sum \mathbb{1}[\beta_j \in \mathrm{CI}]$ | $\sqrt{\widehat{\mathrm{cov}}(1-\widehat{\mathrm{cov}})/n_{\mathrm{PD}}}$, reported alongside every cell (Williams item 11) |
| Three-way verdict | Design 118 §2.5 rule, restated in §5 below | — |
| PD-Hessian rate, per cell | $\mathbb{1}[\texttt{pd\_hessian} = \mathrm{PASS}]$ mean | binomial MCSE |
| `se_ok` (finite, positive SE) rate, per cell | mean indicator | binomial MCSE |
| Wall-clock / core-seconds per fit | direct measurement | — |

Never pooled across cell or species (the gamma-recovery v1→v2 retraction is
the standing lesson this campaign inherits — pooling manufactured a false
finding there; see the proposal §2).

---

## 2. Pre-run test (D-139 smoke)

D-139 requires a pre-run test before any run estimated over 30 minutes, and
this campaign's own a-priori estimate (§3) is well under that line — but the
harness has never been exercised at $n>100$/cell, and the scoring code that
turns raw fits into the Wilson/three-way verdict **does not exist yet**. Two
smoke checks, both cheap, both run before the full launch:

**Smoke 1 — zero-compute scoring dry run.** Apply the (to-be-written)
Wilson-CI / three-way-verdict scorer to the **existing** 1,600-row
`dev/isdm-intervals/campaign-intervals-results.csv` ($n=100$/cell, seeds
1001–1100, already on disk from the approved feasibility run). Pass criteria:
(a) reproduces the feasibility document's own reported per-species point
coverages (0.883–0.988, 43/48 in $[0.90, 0.98]$) to rounding; (b) correctly
emits INDETERMINATE on all 48 cell-species verdicts at $n=100$ — this is
analytically guaranteed (Wilson half-width at $n=100$, $\hat p\approx0.95$,
is $\approx0.043$, well over the 0.015 PASS/INDETERMINATE threshold), so a
scorer that emits anything else at this $n$ has a bug. Cost: **zero new
compute** — this is a code-correctness check against data that already
exists.

**Smoke 2 — live top-up at a fresh seed block.** Extend the two extreme
cells by per-fit cost — cheapest (`n_cells=150, eff_ratio=1, n_sources=2,
amp=1`: measured 0.37–0.45 s/fit) and most expensive (`n_cells=810,
eff_ratio=1, n_sources=3`: measured 3.05–3.16 s/fit,
`dev/isdm-intervals/smoke-remote.csv`) — by 30 replicates each at a
non-overlapping seed block (e.g. 2001–2030), 60 new fits total. Purpose: (i)
confirm the harness runs cleanly beyond its previously-exercised seed range
1001–1100; (ii) get a fresh, unbiased per-fit cost sample to sanity-check
that cost does not creep at a fresh seed block (memory, TMB compile caching,
or contention effects untested at $n>100$).

**Expected wall-clock (Smoke 2):** using the measured extremes (0.37–3.16 s
core-time per fit, `smoke-remote.csv`), 60 fits sum to at most $30\times(0.37
+ 3.16) \approx 106$ core-seconds $\approx 1.8$ core-minutes. Run
single-threaded on $\geq 20$ cores, this is under a minute of wall-clock;
budgeting for R/TMB startup overhead, **under 5 minutes wall**, trivially
inside D-139 and requiring no separate round-trip before Smoke 2 itself
(mirroring the original proposal's own smoke-then-report pattern, §5 of that
document).

**Pass/fail for the smoke pair:** both checks pass -> proceed to §3's launch
recommendation. Either fails -> stop; a scorer bug or a harness-drift finding
is a bug-fix task, not a scoping question (same K1 framing as the feasibility
proposal).

---

## 3. Time estimate and compute target

**A-priori time estimate.** The feasibility document's own "What follows"
section already computed this: *"Full E1 calibration campaign: 16 cells x
>=580 reps ~ 9,280 fits ~ ~5-9 min wall at 100 cores on these timings"*
(`dev/isdm-intervals/2026-08-18-feasibility-results.md`, "What follows"
item 1). At the recommended $n=600$/cell this is $16\times600=9{,}600$ base
fits, materially the same order of magnitude as the 9,280 figure already
estimated (the difference is 3%, inside the stated range's own margin) — **no
new number is being invented here**; the ~5–9 minute figure is quoted, not
re-derived, from the source document's own timing.

**Escalation contingency.** Design 118's one-shot escalation re-runs a cell
to $n=2000$ if it lands INDETERMINATE at $n=600$. Because all 3 species'
coverage indicators for a cell come from the *same* set of fits (one fit
produces `cov_env_sp1/2/3` simultaneously), escalation is mechanically
**per cell**, not per cell-species — a cell escalates once if any of its 3
species verdicts is INDETERMINATE at $n=600$, and the additional 1,400 fits
that follow re-resolve all 3 species together. Worst case, all 16 cells
escalate: $16\times1{,}400=22{,}400$ additional fits. Using the measured
average per-fit cost from the completed feasibility run (45.1 core-min /
1,600 fits $\approx$ 1.69 s/fit), that is $\approx37{,}856$ core-seconds
$\approx 631$ core-minutes $\approx 10.5$ core-hours — at 100 cores,
$\approx 6.3$ minutes additional wall-clock. **Even full worst-case
escalation stays under 30 minutes** (base ~5–9 min + escalation ~6 min
$\approx$ 11–15 min total), so no separate D-139 round-trip is needed if
escalation fires, unlike the base grid's own conditional launch clause.

**Compute target: Totoro, 100 cores, `OPENBLAS_NUM_THREADS=1`.**
Justification:
- The completed feasibility run already used exactly this configuration
  (Totoro, 100 cores, `OPENBLAS_NUM_THREADS=1`) and finished 1,600 fits in
  56.5 s wall / 45.1 core-min — two orders of magnitude under the D-139 line.
- 100 cores is within the D-143 shared-use cap (<=150 cores) with headroom.
- No GPU, no multi-node, no queue benefit — DRAC is the wrong tool for a
  single-node, sub-15-minute embarrassingly-parallel job; DRAC's job-array
  strength (SLURM arrays, per-seed tasks) is not needed at this scale and
  would add queue latency the job doesn't need.
- GitHub Actions is **forbidden for campaigns** (D-50) — not considered.
- Local (this Mac) is not recommended: the campaign is embarrassingly
  parallel and Totoro's 100+ idle cores turn an already-short job into an
  even shorter one, and it keeps the timing directly comparable to the
  already-completed feasibility run's own numbers.

---

## 4. Software / code availability (Williams items 6–8)

- **DGP + fitting code:** `dev/isdm-intervals/campaign-intervals.R`
  (unchanged from the approved feasibility run — only `CAMPAIGN_NREP` and the
  seed range change for the full launch).
- **Performance-measure code:** the Wilson-CI / three-way-verdict scorer is
  **new** and does not exist yet (Smoke 1 above is its first correctness
  check). It must be written before Smoke 1 can run.
- **Package version:** `gllvmTMB` `0.7.0` (`DESCRIPTION` at this checkout),
  `TMB`, base R `parallel`.

---

## 5. Pre-declared gate

Restating Design 118 §2.5's three-way rule exactly, applied to E1's 48
cell-species verdicts:

| Verdict | Rule | Action |
|---|---|---|
| PASS | Wilson 90% CI $\subset [0.92, 0.98]$ | — |
| FAIL | point coverage outside $[0.92, 0.98]$ | — |
| INDETERMINATE | point inside, Wilson pokes out | escalate that **cell** to $n=2000$ once; still INDETERMINATE $\Rightarrow$ recorded FAIL (fail-closed) |

**SUCCESS (pre-declared, cannot move afterwards):** at least 90% of the 48
cell-species verdicts PASS after escalation (43/48 or better) — the same
PASS-fraction Design 118 itself registered as gate G1 for its own,
differently-shaped estimand family
(`docs/design/118-mspl-interval-calibration-protocol.md` line 532: "$\geq$90%
of hold-out cells PASS ... at $n=600$, escalated per §2.5"). Adopting the
identical threshold here is a **fresh decision for a different estimand
family**, flagged for explicit sign-off in §8 — it is proposed as the
natural precedent, not silently inherited.

If SUCCESS: the register may record E1 (per-species `trait:env` Wald
coverage on `isdm_sources()` fits, training rows, this factor grid) as
`covered` with a citation to this campaign's results — no other estimand,
no `newdata`, no map claim.

**FAILURE (pre-declared):**
- **Global failure:** fewer than 90% of the 48 verdicts PASS after
  escalation. This does not mean E1 is unusable everywhere — see the next
  bullet — but it means the current Wald SE cannot be advertised across the
  whole grid without a calibrator, and a Design-118-shape calibrator
  pre-registration becomes the next document, not a claim.
- **Regime-specific failure (a distinct, actionable finding even under
  global SUCCESS):** if any single factor level shows FAIL on **all** its
  cells (e.g. every `n_cells=810` cell fails regardless of the other three
  factors) — that identifies a specific regime where the existing SE is not
  usable, scoping a narrower calibrator instead of a grid-wide one. Report
  this whether or not the 90% global threshold is cleared.
- **Harness failure (K1-style, mirrors the feasibility proposal):** more
  than 1/12 replicates in either smoke check are non-finite, missing, or
  erroring $\Rightarrow$ stop; that is a bug-fix task, not a scoping task,
  and blocks the full launch until resolved.

No result from this campaign authorizes a calibrator build, a `confint()`
claim, or promotion of ISDM-01/ISDM-02 past `partial`
(`docs/design/35-validation-debt-register.md`) by itself — SUCCESS licenses
only the narrow `covered` note described above.

---

## 6. Williams et al. (2024) self-audit

| # | Item | Status | Where addressed |
|---|---|---|---|
| 1 | Aims | ✅ | §1 A |
| 2 | DGP + $n_{\mathrm{sim}}$ justified | ✅ | §1 D, MCSE table |
| 3 | Estimand / target | ✅ | §1 E, §0 |
| 4 | Methods literature cited | partial | Morris/White/Crowther 2019, Williams 2024 (framework); no external interval-calibration literature is cited beyond the package's own Design 118 precedent — this campaign measures an existing SE, it does not survey interval methodology |
| 5 | Performance measures (formulas) | ✅ | §1 P |
| 6 | Software / packages / versions | ✅ | §4 |
| 7 | Code for DGP available | ✅ | `dev/isdm-intervals/campaign-intervals.R` (§4) |
| 8 | Code for performance measures | gap | scorer not yet written (§4, §2 Smoke 1) — must exist before Smoke 1 runs |
| 9 | Worked-example case study | gap | not attempted in this pre-registration; the feasibility grid's own DGP stands in for a worked example but no independent real-data case study is proposed |
| 10 | Full performance table | planned | to be produced from campaign output, one row per cell $\times$ species, per §1 P |
| 11 | MCSE reported alongside | ✅ | §1 D MCSE table, §1 P |

---

## 7. What this campaign explicitly does NOT cover

- **E2 (latent-loading amplitude coverage):** no ADREPORT SE exists for
  `Lambda` on any fit measured so far (`lam_report_se` FALSE on 1,600/1,600,
  `dev/isdm-intervals/2026-08-18-feasibility-results.md` "E2"). A coverage
  claim needs new construction (delta on the loading transform, or ADREPORT +
  delta in C++) — an `R/`/`src/` change, out of scope for a docs-only
  pre-registration.
- **E3 (between-cell intensity-ratio intervals):** no row-pair covariance
  surface exists at all; not measurable with current machinery.
- **E4 (`predict(se.fit)` coverage of the true linear predictor):** already
  measured and **negative** — 0.23–0.82 coverage, falling with grid size
  (`dev/isdm-intervals/2026-08-18-feasibility-results.md` "E4"). This
  campaign does not re-attempt E4 and does not propose a fix; the fix path
  (joint-precision eta SEs) belongs with the Design 126 predict work per the
  feasibility document's own "What follows" item 2.
- **`newdata` / spatial-arm prediction intervals:** the underlying
  `predict(newdata=)` machinery silently drops random-effect tiers on spatial
  fits (ISDM-03 row, `docs/design/35-validation-debt-register.md`); no
  interval can be calibrated on a surface that does not correctly compute a
  point estimate yet.
- **Any calibrator (`alpha*` map) construction.** This campaign is a
  measurement of the existing, uncalibrated Wald SE — identical in kind to
  the feasibility grid, just at resolving replicate count. Building a
  calibrator, should FAILURE (§5) warrant one, is a separately pre-registered
  follow-on.
- **Any public-facing claim.** No NEWS, README, article, or exported
  documentation change is authorized by this document or by a completed run
  of it. No register row (`ISDM-01`/`02`/`03`) moves past `partial` except
  the narrow `covered` note described in §5 under SUCCESS, and that note
  itself requires the maintainer to review the completed results, not this
  pre-registration alone.

---

## 8. NEEDS SHINICHI

1. **Confirm $n=600$/cell** as the registered replicate count (§1 D). This is
   proposed by direct analogy to Design 118 §2.5's own choice for a different
   estimand family, not automatically inherited — please confirm or set a
   different value.
2. **Confirm the 90% PASS-fraction SUCCESS threshold** (§5). Same reasoning:
   proposed as the natural precedent from Design 118's G1 gate, but it is a
   fresh number for E1, not carried over by right.
3. **Confirm compute target: Totoro, 100 cores** (§3). No objection expected
   given the feasibility run already used this configuration successfully,
   but flagging per D-139's explicit-approval requirement.
4. **Confirm cell-level escalation semantics** (§3): a cell escalates to
   $n=2000$ if *any* of its 3 species verdicts is INDETERMINATE at $n=600$
   (mechanically forced by shared fits), and the resulting higher-$n$
   verdicts are reported for all 3 species even though only one triggered
   the escalation. If a stricter species-independent escalation is wanted
   instead, the harness would need per-species-conditional re-fitting, which
   is a larger and slower design — flagging before, not after, launch.
5. **On FAILURE (§5), does report-back happen before any calibrator
   pre-registration is drafted**, or is drafting the next pre-registration
   pre-authorized by this approval? Recommendation: report back first — the
   feasibility proposal's own §4 fence ("a positive or ambiguous read still
   needs a separately pre-registered follow-on before any claim ships") reads
   as applying equally to a negative read, so this document recommends the
   same discipline rather than assuming continuation.

---

## 9. Approval block

**Asking Shinichi to approve:**

1. Writing the Wilson-CI / three-way-verdict scorer (§4, currently absent)
   and running Smoke 1 (zero-compute, against existing data) and Smoke 2
   (60 live fits, <5 min wall) as scoped in §2.
2. **If** both smoke checks pass: permission to launch the full $n=600$/cell
   grid (9,600 base fits + any escalation, ~11–15 min worst-case wall on
   Totoro at 100 cores) without a further round-trip, per D-139's own
   30-minute line — mirroring the feasibility proposal's own conditional
   launch clause.
3. **If** either smoke check fails, or the smoke-derived cost estimate
   revises the full-grid estimate past 30 minutes: stop and return with the
   revised number before any further compute (§2, §5 K1).
4. The five points in §8 (NEEDS SHINICHI) — replicate count, gate threshold,
   compute target, escalation semantics, and the report-back convention on
   FAILURE.

**Default recommendation:** approve 1–3 as scoped, with the §8 numbers as
proposed unless corrected. This is the natural next step the feasibility
grid itself named ("needs its own pre-registration (grid, gates, MCSE) per
the proposal's §4 fence, then Shinichi's launch approval") and stays inside
D-139 at every stage, including its own worst-case escalation.
