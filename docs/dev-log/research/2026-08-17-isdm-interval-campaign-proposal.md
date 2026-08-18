# iSDM interval-calibration campaign — proposal

**Status: PROPOSAL — nothing launched; D-139 gate not yet passed; needs Shinichi
approval.** No compute spent; no code touched; no `src/` change.

**Lane:** Fisher, worktree `/private/tmp/gllvmtmb-isdm-predict`, branch
`claude/isdm-predict-20260817`.

**Why now.** Register rows `ISDM-01`/`ISDM-02` (`docs/design/35-validation-debt-register.md`)
are both `partial`: both explicitly say interval calibration is "outside this row."
The 2026-08-17 handover names this the second OWED item — "the big arc" — after the
prediction-surface probe (item 1, done this session; findings below).

---

## 1. Estimands, ranked by user value

| Rank | Estimand | Reachable today | New per D-157? |
|---|---|---|---|
| 1 | Fixed-effect contrasts — per-species env slopes (`trait:env`) | Point est. yes; Wald SE exists internally but **coverage never measured** on `isdm_sources()` fits | Treated as new — never gated on this model class |
| 2 | Shared-field variance/amplitude (latent-factor SD or SPDE marginal variance) | Point est. only; wrong to Wald-default a variance component | **Yes** — no prior construction targets a field amplitude in ISDM |
| 3 | Relative-intensity ratios between (training) cells | Point est. reachable via `predict(type="response")` differences; no interval exists | **Yes** — nonlinear multi-cell derived quantity, uncovered by any prior protocol |
| 4 | `predict()` `se.fit` coverage, training rows only | Runs, returns finite in-range SE (probe A6) | New **measurement**, not new construction — formula exists, coverage doesn't |

**Out of scope, probed and broken this session** (`dev/isdm-predict-probe/probe.R`,
findings B2/B2b/B3): `newdata` prediction on the spatial arm silently drops the
fitted SPDE field (max|diff| 0.966 vs eta sd 0.949, correlates 0.82 with the true
field); new-coordinate kriging returns fixed-effects-only, no `A_proj` re-projection.
No newdata/spatial SE can be calibrated before that machinery exists — an API gap,
not an interval-design question, and not this campaign's job. Scope here is
**training-row estimands only** (1, 2, 4, and 3 restricted to training-row pairs).

**On D-157.** This is not a Design 118/125 rerun and does not touch the MSPL triad,
fence, calibrator, or `src/gllvmTMB.cpp`'s penalty machinery. It is a distinct
estimand family (ISDM fixed effects and variance components, not penalised binary
loadings) and would need its own pre-registration before any calibration launch.
Design 118 stays closed.

---

## 2. Design sketch

**Families fixed:** the one admitted contract — Poisson-log count + Bernoulli-cloglog
detection (`isdm_sources()`, Design 120 §2).

**Factors**, drawn from the two completed campaigns' own axes for comparability:

| Factor | Levels | Source |
|---|---|---|
| `n_cells` | {150, 810} | domain-growth campaign's frontier axis |
| effort ratio | {1x, 10x} | gamma-recovery's dominant error driver |
| `n_sources` | {2, 3} | gamma-recovery's axis, restricted |
| field amplitude | {weak, strong} | new — needed because estimand 2 targets amplitude itself |

$2\times2\times2\times2=16$ cells — deliberately below the prior campaigns' 1,200–1,600
scale: this is a **feasibility grid**, not a full pre-registered protocol.

**Metrics: per-cell, per-group, never pooled** — the gamma-recovery v1→v2 retraction
(pooled RMSE manufactured a false finding) is the drift-ledger lesson inherited
directly. Report coverage separately by estimand, arm type, and grid cell.

**Target bands:** Design 118's own three-way rule (§2.5) — PASS if Wilson 90% CI for
coverage $\subset[0.92,0.98]$ at nominal 95%, FAIL outside, INDETERMINATE escalates
once. No calibrator ($\alpha^*$ map) is proposed here — only whether the **existing,
uncalibrated** SE is already inside that band.

**Seeds:** multi-seed always. $\geq100$ replicates per feasibility cell (not
Design 118's $n=600$ scale — that is a later decision, gated by §5).

---

## 3. The D-139 pre-run test

**Exact smoke test:**

1. One grid cell: `n_cells=150`, effort ratio 1x, `n_sources=2`, weak amplitude —
   matches gamma-recovery's own baseline (known per-fit cost).
2. `n_rep = 12` (matching that campaign's own pre-run size).
3. Non-empty/valid output checked per replicate: fit converges (`opt$convergence==0`,
   `pd_hessian` recorded); fixed-effect Wald SEs finite/positive; field-amplitude
   estimate + SE finite/positive; `predict(se.fit=TRUE)` on training rows finite and
   in-range (re-checks probe A6 at this cell rather than assuming it generalises);
   truth-containment indicator computable per coefficient (not scored — just checked
   it computes).
4. Wall-clock and core-seconds per fit recorded directly.

**A-priori time estimate:** probe fits this session ran in seconds each
(`load_all()` overhead included). Gamma-recovery priced ~3.6 s/fit from its pre-run,
~1.2 s/fit installed; both prior campaigns (1,200 and 1,600 fits) finished **under 30
min on 100 Totoro cores** (1–2 min and ~26 min respectively). This grid (16 cells x
100 reps = 1,600 base fits + 12-fit smoke) is the same order of magnitude, so
**a-priori range: 5–30 minutes wall on 100 Totoro cores** — plausibly under the D-139
line but **unproven** until the smoke test reports its own number: this campaign adds
two SE/interval computations per fit (amplitude Wald, `se.fit`) whose cost
gamma-recovery never paid. If the smoke number pushes the full grid over 30 minutes,
return to Shinichi with the estimate before launching.

**Compute target:** Totoro, **≤150 cores** (D-143), `OPENBLAS_NUM_THREADS=1`, matching
both prior campaigns' harness convention. No DRAC request at this scale.

The smoke test's job is narrow — confirm the harness runs end-to-end and produce a
real per-fit cost. 12 reps cannot resolve a coverage band (Design 118 needs $n\geq580$
for $\pm0.015$ half-width); it only bounds gross failure (negative SE, non-convergence).

---

## 4. Kill rules, and what NOT to claim

- **K1 — harness failure.** Any of the four smoke checks non-finite/missing/erroring
  on >1/12 reps → stop; that's a bug-fix task, not a scoping task.
- **K2 — cost blowout.** If the smoke number implies the full grid exceeds ~2 h wall
  at 150 cores → stop, return to Shinichi with the revised estimate; do not shrink
  the grid silently to duck under 30 minutes.
- **K3 — grid fails badly.** If estimand-1 coverage is not even in a defensible
  neighbourhood of nominal (e.g. <0.80 at any cell) at $n=100$ → that is itself the
  finding: the existing SE does not transfer to this model class, and the next
  document is a from-scratch Design-118-shape protocol, not a light measurement.

**Not authorized by this document, at any stage short of a completed gated campaign:**
no public `confint()`/`se.fit` claim beyond what the probe found (runs, coverage
unknown); no promotion of ISDM-01/ISDM-02 past `partial`; no newdata or
spatial-prediction interval claim (that surface doesn't exist — §1); no treating this
feasibility grid as itself the calibration campaign — a positive or ambiguous read
still needs a separately pre-registered follow-on before any claim ships.

---

## 5. Approval block

**Asking Shinichi to approve:**

1. Run the D-139 smoke test (§3): 1 cell, 12 reps, local first, Totoro only if slow.
2. Report smoke results + resulting full-grid estimate back before anything larger —
   no feasibility-grid launch is authorized by this approval alone.
3. **If** the estimate keeps the 16-cell grid under 30 minutes: permission to run it
   on Totoro (≤150 cores) without a further round-trip, per D-139's own 30-minute
   line. **If** it exceeds 30 minutes: launch waits for explicit approval with the
   revised number attached (K2).

**Default recommendation:** approve 1–3 as scoped. This is a bounded, cheap-to-reverse
check of whether the package's *existing* SE machinery is already usable for the
highest-value iSDM estimands, before committing to a Design-118-scale calibrator.
Either it already looks defensible and only needs the full-scale gate Design 118
shows how to run, or it doesn't — worth knowing before a larger investment, and it
scopes the real pre-registration instead of guessing its design blind.
