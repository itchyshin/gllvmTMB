# Independent scoring: Detector-S2c curvature/multi-start calibration

**Scorer role:** independent reviewer, applying the rule frozen in
`dev/ordinal-degeneracy/pass-criteria-curvature.md` (STATUS: FROZEN
2026-08-17, mtime 18:07) to the scored run
`dev/ordinal-degeneracy/results/campaign-curvature-scored.csv` (mtime
18:32, 450 rows, `status == "OK"` throughout). I did not design this
campaign, did not run it, and applied the rule exactly as written. Where a
step below flags an ambiguity, both readings are computed and reported;
the bottom-line verdict does not depend on which reading is used (see
"Why the ambiguity doesn't matter" below).

The quarantined pilot files (`pilot-curvature-*.csv`,
`campaign-curvature-scored-smoke20.csv`) were **not** read for scoring.

## Implementation-vs-document cross-check

Before scoring, I verified the scoring script's Arm C/D functionals
(`dev/ordinal-degeneracy/campaign-curvature-pilot.R:86-157`, reused
verbatim by `campaign-curvature-scored.R`) against the frozen document's
"Exact functional (frozen)" sections. They match: `min_eig_scaled_per_obs`
in the CSV equals `(min(ev) * max(max_loading_unit,1)^2) / n_obs`, i.e.
exactly the document's step-7 `min_eig_scaled` formula (order of
multiplication/division differs cosmetically, not numerically).
`degenerate_label` in the CSV matches `rel_frob > 10` (`probe$DEGEN_RF ==
10`) with **zero mismatches** across all rows where `rel_frob` is
available. No implementation drift found.

## 1. Denominators (Scoring rule, items 1–2)

| pool | document definition | rows found |
|---|---|---|
| Sensitivity denominator | "`scale_degenerate` arm fits with `rel_frob(...) > 10`" (item 1) | **94** (53 at `n_init=1`, 41 at `n_init=5`) |
| Arm C FP denominator | "every fit in `scale_healthy` (restricted to `sigma_lambda ∈ {0.3,0.7}`), `transport`, and `mixed`, regardless of that individual fit's own `rel_frob`" (item 2) | **290** (140 `scale_healthy` + 80 `transport` + 70 `mixed`) — matches the document's own stated 290 exactly |
| Arm D FP denominator | "the Arm-D-evaluated subset of those cells, 92 base replicates at `n_init=5`" (Targets) | **92** (48 `scale_healthy` + 24 `transport` + 20 `mixed`, all `n_init==5`) — matches document's stated 92 exactly |
| Arm D sensitivity denominator | `scale_degenerate`, `n_init=5` subset, `rel_frob>10` | **41** |

`scale_boundary` (40 rows, `sigma_lambda ∈ {1.2,2.0}`) is **excluded from
both** the sensitivity and FP denominators, per the document's explicit
instruction (item 2) — confirmed not counted anywhere below; reported
separately in §6.

`scale_healthy` in the data is already restricted to `sigma_lambda ∈
{0.3, 0.7}` (grid-construction fact, verified: only those two values
appear), so no additional filtering was needed on my end.

## 2. Non-finite / availability audit (transparency, not in the document)

- `curvature_available == FALSE` on 4/450 rows (2 inside the Arm C FP
  pool: `transport` seed 13 n_init=1, `mixed` seed 13 n_init=1; 2 inside
  the sensitivity pool: `scale_degenerate` seed 5 n_init=5 [rel_frob=3.67,
  not actually in the sensitivity denominator] and seed 9 n_init=1
  [rel_frob=148.4, **is** in the sensitivity denominator]).
- `cond_LL` is `Inf` on 12 rows total across the dataset (3 inside the Arm
  C FP pool: `transport` seed 5 n_init=5, `mixed` seed 7 n_init=5,
  `transport` seed 40 n_init=1; the rest inside the sensitivity pool).
- `min_eig_scaled_per_obs` is negative on 8 rows (a mathematically forced
  consequence of a non-PD `cov.fixed` block, per the document's own §
  "Precondition checks item 3" — not a harness defect).
- The document does not state how to treat `curvature_available == FALSE`
  (unavailable statistic) or `Inf`/negative statistic values when scoring
  flag firing. I treated "cannot compute" as "cannot confirm flag" →
  **not flagged** (comparison of `NA` to a threshold is `NA`, coerced to
  `FALSE`). This is a **gap in the frozen document**, not a choice I was
  entitled to make silently — flagged explicitly here.

## 3. Threshold selection (Scoring rule, item 3) — an internal tension in the frozen text

Item 3 says: "`thresh` is set to the most extreme value observed anywhere
in that statistic's FP-scored pool ... the empirical zero-FP boundary."
Step 8's own flag formula uses **inclusive** operators (`cond_LL >=
thresh`, `min_eig_scaled <= thresh`). These two instructions are in
tension: if `thresh` is literally the pool's own most extreme value and
the comparison is inclusive, the pool row that *achieves* that extreme
value satisfies its own criterion and is flagged — a nonzero FP by
construction, contradicting "zero-FP boundary." I could not resolve this
silently, so I scored **four readings** and confirmed the sensitivity
verdict is identical under all of them (§5 below):

- **cond_LL (C-ratio):** finite max in the FP pool = 11,588,525,456
  (`transport` seed 26); the pool additionally contains **3 rows at
  literal `Inf`** (`transport` seed 5, `mixed` seed 7, `transport` seed
  40) — `Inf` is a value the document explicitly endorses as a valid
  `cond_LL` reading (Precondition-checks item 3), so it is a legitimate
  member of "the most extreme value observed," making the literal
  extreme `Inf` itself.
- **min_eig_scaled_per_obs (C-abs):** min (most extreme, low=worse) in
  the FP pool = **−609.76** (`transport` seed 40, n=400).
- **obj_spread_per_obs (Arm D):** max in the 92-row pool = **149.08**
  (`transport`, no `Inf` present — this statistic has no analogous
  ambiguity).

| reading | thresh_ratio | operator | Arm C FP (n=290) |
|---|---|---|---|
| A — finite-max threshold, literal `>=`/`<=` | 11,588,525,456 | inclusive | **4** (mixed:1, transport:3, healthy:0) |
| B — literal extreme incl. `Inf`, literal `>=`/`<=` | `Inf` | inclusive | **3** (mixed:1, transport:2, healthy:0) |
| C — finite-max threshold, strict `>`/`<` | 11,588,525,456 | strict | **3** (`Inf` rows still exceed a *finite* threshold under `>`) |
| D — literal extreme incl. `Inf`, strict `>`/`<` (the only reading that is tautologically zero-FP, matching the document's own "zero-FP boundary" language) | `Inf` | strict | **0** |

Arm D has no such ambiguity (no `Inf`/non-finite values in its pool):
threshold = 149.08, **FP = 1 under `>=`** (the pool's own defining row,
`transport`), **FP = 0 under strict `>`**.

**Every FP-pool row that flags under any reading is in `transport` (3 of
4) or `mixed` (1 of 4); `scale_healthy` contributes zero FPs under every
reading.** This matches the document's own anticipated attribution (item
4): `transport`'s known partial contamination (three of its own rows have
`rel_frob` 12.3, 187.9, 360.7 — i.e. these "false positives" are fits that
are themselves genuinely degenerate by the frozen label, counted as FP
only because arm membership, not per-fit truth, is the scoring criterion)
and `mixed`'s one flagged row has no `rel_frob` available to check (a
harness limitation the document itself names).

## 4. Sensitivity at the mechanically-derived threshold

| arm | reading | numerator / denominator | sensitivity | n_init=1 stratum | n_init=5 stratum |
|---|---|---|---|---|---|
| Arm C (`flag_C = ratio | abs`) | A/B/C (thresholds finite or `Inf`, inclusive/strict-but-not-D) | 5 / 94 | **5.3%** | 3/53 (5.7%) | 2/41 (4.9%) |
| Arm C (`flag_C = ratio | abs`) | **D (tautological zero-FP)** | 1 / 94 | **1.1%** | 1/53 (1.9%) | 0/41 (0.0%) |
| Arm D (`flag_D`) | `>=` or strict `>` (agree) | 3 / 41 | **7.3%** | n/a (Arm D only has `n_init=5` data) | 3/41 |
| Exploratory `flag_C | flag_D` (Reading D thresholds, `n_init=5` subset only, both statistics available) | — | 3 / 41 | **7.3%** | — | 3/41 |

Target is **sensitivity ≥ 90%**. Every reading, every arm, and the
exploratory combination land between **1.1% and 7.3%** — one to two
orders of magnitude below target.

## 5. Why the ambiguity in §3 does not change the verdict

The FP-count reading (0, 1, 3, or 4, depending on operator/`Inf`
treatment) never comes close to threatening the "zero FP" target on its
own — the reported non-zero counts trace to `transport`/`mixed`, exactly
as the document anticipated and pre-authorized as an interpretable,
non-detector-quality result (item 4). What is dispositive is
**sensitivity**, which fails by 83–89 percentage points under every
reading. The ambiguity is real and is reported in full per the task's
instructions, but it is not the reason either arm fails.

## 6. `scale_boundary` (reported only, per document — not scored)

40 rows, `sigma_lambda ∈ {1.2, 2.0}`. Realised `rel_frob > 10` rate:
**47.5%** (19/40). `flag_C` (Reading D thresholds) firing rate: **0/40**.
Confirms this stratum is correctly excluded from both denominators (its
inclusion would have made the FP target trivially easier to fail
differently, or the sensitivity target easier to pass spuriously — the
document's B1 fix that carved it out is doing real work here).

## 7. Independence precondition (B8)

Computed across **all 450 fits with a finite pair** (not restricted to
the healthy pool), per the document's explicit instruction:

| statistic | n finite pairs | `cor(., max_loading_unit)` | `|r| >= 0.8`? |
|---|---|---|---|
| `cond_LL` | 438 / 450 | **0.538** | No |
| `min_eig_scaled_per_obs` | 446 / 450 | **−0.452** | No |

**Precondition PASSES for both statistics** — neither is refused as a
duplicate of the already-eliminated `max_loading_unit` candidate. This
does not rescue either arm: both clear the independence bar and both
still fail the sensitivity target by a wide margin.

## 8. Verdict

- **Arm C: FAIL.** Sensitivity 1.1–5.3% (reading-dependent) vs. target
  ≥90%. FP 0–4 depending on reading, always fully attributable to
  `transport`/`mixed`, never to `scale_healthy`.
- **Arm D: FAIL.** Sensitivity 7.3% vs. target ≥90%. FP = 0 under the
  strict (tautological) reading, 1 (`transport`) under the inclusive
  reading.
- **Exploratory `flag_C | flag_D`: also reported, also FAIL** (7.3%,
  identical to Arm D alone on the `n_init=5` subset — Arm C contributes
  nothing incremental there under any reading).
- **Ship-disarmed fallback (pre-registered) APPLIES:** neither arm, nor
  the exploratory OR-combination, meets the sensitivity/FP conjunction at
  any threshold. Per the document: "both stay unimplemented / unshipped,
  and that is the deliverable. This is not a failure to be rescued by
  loosening the 90%/zero-FP targets after the fact."
- This campaign's own targets (Targets section) additionally state that
  even a clean pass here would not itself justify shipping a default —
  moot, since neither arm passed.

## 9. Ambiguities / gaps found in the frozen document (reported per task instructions, not resolved unilaterally)

1. **Item 3 vs. step 8 operator tension** (detailed in §3): "thresh =
   pool's own extreme" combined with inclusive `>=`/`<=` cannot produce a
   literal zero-FP boundary when the pool itself is being scored against
   that same threshold; only the strict-operator reading (D) is
   tautologically zero-FP. The document does not disambiguate which
   operator applies at the scoring step (step 8 is written for the
   *candidate flag definition*, not explicitly re-stated for the
   *mechanical threshold-selection* step).
2. **`Inf` in "the most extreme value observed"** — the document
   endorses `Inf` as a legitimate `cond_LL` reading elsewhere (Precondition
   checks item 3) but does not say whether an `Inf` inside the FP pool
   itself should be allowed to *define* the mechanical threshold (making
   the ratio criterion permanently unable to fire) or should be excluded
   from threshold-setting while still being scored as a data point.
3. **`curvature_available == FALSE` / `disagreement_available == FALSE`
   rows** are not addressed by the scoring rule. I treated them as
   "cannot confirm flag → not flagged," which is conservative for FP but
   also conservative against sensitivity (one genuinely degenerate row,
   `scale_degenerate` seed 9 n_init=1, rel_frob=148.4, is excluded from
   the numerator by this treatment though it remains in the denominator).
4. No non-finite values were silently dropped from either denominator;
   all are enumerated above.

## 10. What I did not do

I did not re-cut either denominator, did not drop or relabel any row, and
did not choose a threshold after inspecting which one "worked" — the
mechanical thresholds above are the pool's own observed extremes (all
four readings), computed once, not tuned. The null result (both arms
fail by a wide margin) is reported as found.
