# Audit: what CI-08 actually says, and the release claim it supports

**Author**: Fisher (inference policy) with Rose (claim honesty), Claude Code session 2026-08-02.
**Trigger**: maintainer, 2026-08-02 — *"below 94% is OK as long as we have good reasons — low N, or
other packages like gllvm give the same."* That is a different and better gate than "hit 0.94", and
it prompted a re-reading of what CI-08's headline number is actually measuring.
**Scope**: read-only over existing evidence. No new coverage campaign was run for this audit. No
register row is moved here; two are flagged as **stale** for the maintainer to move.

---

## 1. The headline number is measuring a retired estimand

Mission Control and register row CI-08 both lead with **"13 of 15 cells below the 94% gate"**. That
number is real, but it is a **failed gate on a quantity the package has since declared not to be an
estimand.**

`docs/design/66-capstone-power-study.md:167-176`, in the package's own words:

> "The estimand choice is the single most consequential decision in this study, and it is the one
> the package **got wrong once already**. The 2026-05-19 M3.3 production run gated on **profile CIs
> of per-trait `psi`** (`theta_diag_B`), a *rotation-variant* proxy. 13/15 cells 'failed' the 94%
> gate (CI-08) and the mixed-family cells looked badly miscalibrated (CI-10: d=1 0.820, d=2 0.685,
> d=3 0.550). **PR #364 (merged 2026-05-31) corrected this**: the promotion gate now keys on
> `coverage_primary` / `primary_gate_status`, evaluated on the **bootstrap CI of total
> `Sigma_unit_diag`** — the rotation-invariant estimand the coverage claim is actually about.
> `psi` is retained only as a diagnostic."

**Why this is a legitimate explanation and not an excuse.** In a latent-variable model the loadings
`Lambda` and the per-trait uniquenesses `psi` are identified only up to rotation. A confidence
interval for a rotation-variant quantity does not have a well-defined coverage target, because the
"true" value depends on a rotation the model does not pin down. Gating on it was a category error,
the package identified it independently, and it was corrected fourteen months' worth of design
iterations ago. The same document lists raw `psi` and raw `Lambda` under **"Diagnostic-only
quantities (reported, never gated)"**.

**Consequence:** the 13/15 figure should not drive a release decision, and citing it as the 0.6
blocker overstates the problem. It is negative historical evidence about a superseded gate.

## 2. On the corrected estimand, the profile route clears

The 2026-07-29 campaign (`docs/dev-log/2026-07-29-certificate-disposition.md`) measured the
rotation-invariant target, `Sigma_unit_diag`:

| cell | coverage | reps used | attempted | failed | 2·MCSE band | 0.94 gate |
|---|---|---|---|---|---|---|
| gaussian d1-n150 | 0.9467169 | 19,372 | 20,000 | 628 | 0.9434896 | clears |
| gaussian d2-n150 | 0.9467216 | 19,888 | 20,000 | 112 | 0.9435366 | clears |

Recomputed from raw independently by three lenses; 180 contiguous shards, no gaps, no overlaps, no
duplicate `(d, rep)`. Pre-registration commit `8121f377` (10:44:35) strictly precedes the run
directory (10:47:10). A three-lens D-43 panel returned **CERTIFY 3-0**. The MCSE band used is
**conservative** — the rep-level MCSE is ~2.1× the rep-clustered SE, so the gate was cleared with
the wider instrument.

**The scope fences on that certificate are real and must travel with it**: two-sided only (upper-tail
misses ≈1.53× lower, so one-sided use is invalid); a marginal average that does **not** hold in the
smallest-V_t ventile (d1 0.9259, d2 0.9369); conditional on convergence (96.9% / 99.4%); a **0.94
floor, never nominal 95%**; and the two cells share 19,000 of 20,000 seeds, so they are not
independent replicates of each other.

## 3. STALE — the "certified but unreachable" caveat has been closed

The disposition doc's most prominent caveat reads:

> "**The certified route is not reachable by users.** `.profile_ci_total_variance()` has no exported
> entry point… Any wording that omits this is 'a lie by implication.'"

**That was true on 2026-07-29 and is no longer true.** Commit **`f04c066c`** — *"feat(profile):
export `profile_ci_total_variance()` behind a per-row fence"* — has since landed on `main`:

- `NAMESPACE:174` carries `export(profile_ci_total_variance)`;
- the exported wrapper (`R/profile-derived.R:1010`) delegates to the certified internal
  `.profile_ci_total_variance()` (`:856`);
- it returns an `interval_status` field marking `"certified-0.94"` for rows inside the certified
  regime, `"route-only"` for a computed but uncertified interval, and `"none"` for point-only rows —
  with the roxygen stating explicitly that this marks **regime membership, not an individual
  interval**.

So the certificate now closes a gap in the **capability** surface as well as the evidence surface.
**Two documents understate the package's position and need a dated correction** (flagged, not
edited here): register row CI-08 (`docs/design/35-validation-debt-register.md:411`) and
`docs/dev-log/2026-07-29-certificate-disposition.md`.

## 4. The one genuinely open defect

In the same campaign, on the same estimand, the resampling route covered:

> `bootstrap_Sigma()` — **0.7774 (d1) / 0.7810 (d2)**

A **17-point shortfall against nominal 95%**, on the correct rotation-invariant target, in a
20,000-replicate campaign. **This one does not survive the maintainer's standard.** "Low N" does not
explain it — n = 150 is the certified regime, and the profile route reaches 0.9467 on the same data.
A comparator agreeing would not rescue it either: a route that misses by 17 points is not delivering
a 95% interval by any reading.

### DIAGNOSED 2026-08-02 — it is a measurement artifact, not a `bootstrap_Sigma()` defect

**The campaign ran the bootstrap route at `n_boot = 10`, against a documented default of 200.**
`dev/totoro-profile-rescore.sh:38` sets `NBOOT="${NBOOT:-100}"` and forwards it at `:102`; the run
record's own invocation block (`docs/dev-log/2026-07-29-certificate-run-record-v2.md:9-13`) reads
**`NBOOT=10`**, reaching `bootstrap_Sigma(n_boot = 10)` at `dev/m3-grid.R:1388-1398`.

At B = 10, percentile bounds at 0.025 / 0.975 (`stats::quantile` type 7, `R/bootstrap-sigma.R:526-540`)
land at h = 1.225 and h = 9.775 — *interpolations inside order statistics 1–2 and 9–10*. The interval
is therefore **narrower than `[min, max]` of ten draws**, whose coverage ceiling is
(B−1)/(B+1) = **0.818**. Observed 0.777 / 0.781 is exactly where that lands once bootstrap skew is
added. **The profile route was measured at full precision and the bootstrap route with a 20×-thinned
instrument. They were never the same measurement.**

Empirical confirmation (`dev/boot-vs-profile-diagnosis.R`; 55 converged reps × 5 traits = 275 cells,
gaussian d = 1, n = 150; DGP and fit copied verbatim from `dev/m3-grid.R`). One bootstrap at B = 200
per replicate with `keep_draws = TRUE`, then percentile bounds recomputed **from prefixes of the same
draws**, so only B varies:

| route | coverage | MCSE | mean width |
|---|---|---|---|
| profile (now exported) | **0.9491** | 0.0133 | 0.796 |
| `bootstrap_Sigma` B = 10 | **0.8073** | 0.0238 | 0.569 |
| B = 20 | 0.8582 | 0.0210 | 0.655 |
| B = 50 | 0.9018 | 0.0179 | 0.725 |
| B = 100 | 0.9309 | 0.0153 | 0.749 |
| **B = 200 (the documented default)** | **0.9418** | 0.0141 | 0.765 |

B = 10 reproduces the campaign's 0.78. **At the documented default the 17-point gap collapses to
~0.7 points — within 1 MCSE of the profile route.** Width rises monotonically with B, exactly as
endpoint-thinning predicts.

**Rival hypotheses tested and rejected.** *Conditional-RE redraw (the #750 class)* — rejected;
`simulate.gllvmTMB_multi()` defaults to `condition_on_RE = FALSE` and the redraw covers `rr_B` and
`diag_B` (`R/methods-gllvmTMB.R:1043-1050`), the only tiers this fit activates; the fallback warning
never fired across 56 fits. *Centring bias from ML's downward-biased variance components* — this was
the audit author's leading hypothesis and it is **rejected**: `mean(V̂ − truth) = −0.005` on a mean V
of ~2, `mean(boot median − V̂) = −0.019`, and misses at B = 200 run 1 low / 15 high — the same mild
1.5× upper-tail skew the *profile* route also shows, not a location error. *Failure accounting* —
not the cause; `m3_summarise` (`dev/m3-grid.R:2326-2341`) uses comparable denominators for both routes.

**Proportions.** An independent analytic check (scaled-χ² variance estimator, no model fits) gives
percentile coverage 0.792 at B = 10 and 0.9458 at B = 2000 for df = 150; at B → ∞, percentile 0.9412
versus log-scale pivotal 0.9479. So **~16 of the 17 points are the measurement artifact**, and
**~0.5–1 point is a genuine limitation** — the percentile method on a right-skewed variance component
is not second-order accurate.

### The real defect this episode exposed

Not the coverage. **`bootstrap_Sigma()` accepts `n_boot = 10` silently.** `R/bootstrap-sigma.R:194-196`
guards only `n_boot >= 1`, and the ≥80 %-effective-B floor at `:577` applies **only** to
`multiple_r_*` entries — the matrix branch that produces the headline `Sigma_B` computes neither
`n_effective` nor any floor, and `na.rm = TRUE` silently drops failed refits (4.24 of 200 per
replicate here). A user can therefore request a 95 % interval from ten draws and receive one, with no
warning, when the arithmetic ceiling on its coverage is 0.818.

## 5. The release claim this evidence supports

Applying the maintainer's gate — *sub-0.94 is acceptable when explained* — to each item:

| item | number | explained? |
|---|---|---|
| the 13/15 `coverage_study()` cells | <0.94 | **Yes** — rotation-variant estimand, category error, corrected by PR #364. Retired, not outstanding. |
| profile route, `Sigma_unit_diag` | 0.9467 | **Clears**, within named scope fences, and now user-callable |
| mixed-family CI-10 cells | 0.820 / 0.685 / 0.550 | **Yes, same cause** — same retired `psi` route (Design 66:170-171) |
| `bootstrap_Sigma()` "0.78" | 0.78 | **Yes** — measured at `n_boot = 10` against a default of 200; the arithmetic ceiling at B = 10 is 0.818. At the default it is **0.9418**. |
| `bootstrap_Sigma()` at its default | 0.9418 | Within ~1 MCSE of the profile route; ~0.5–1 point of residual is the percentile method's known second-order inaccuracy |

**Every headline coverage number on this row is now explained**, and none of the explanations is
"small N". Two are category errors about the estimand, one is a harness misconfiguration, and the
residual is a documented property of the percentile method.

**The defensible release sentence is "coverage is explained", not "coverage is 0.94".** The honest
shape of the remaining work is **not a coverage gap at all** — it is a **missing guard**: the package
will hand a user a 95 % interval built from ten draws without complaint.

### Required corrections to existing documents

Two documents state, as a property of the exported function, a number that is a property of one
misconfigured invocation:

- `docs/design/35-validation-debt-register.md:411` (CI-08) — "the exported `bootstrap_Sigma()` route
  for the same estimand covered **0.78**"
- `docs/dev-log/2026-07-29-certificate-disposition.md:47` — "covered **0.7774 (d1) / 0.7810 (d2)**"

That sentence is **currently the single strongest stated reason the exported surface looks broken**,
and it is not a property of `bootstrap_Sigma()`. It should be re-measured at `n_boot = 200` before it
is repeated anywhere. Both rows are flagged here and left for the maintainer to move — this session
built the evidence and should not also promote its own status rows.

## 6. What this audit does NOT establish

- **No new coverage numbers were produced here.** Everything above is a re-reading of existing
  evidence, plus one verified fact about `NAMESPACE` and `f04c066c`.
- **The profile certificate's scope fences are not relaxed** by anything here. Two cells, Gaussian,
  n ≥ 150, d ≤ 2, two-sided, marginal-average, 0.94 floor. Everything outside that is uncertified.
- **No comparator run was performed.** Whether `gllvm` shows the same behaviour on the same design
  is still unmeasured — and per `docs/design/87-latent-variable-oracle-map.md` it is only partly
  answerable, since `gllvm` cannot reach several of the relevant cells at all.
- **The bootstrap mechanism is not yet established** (§4). Until it is, "bug" versus "known
  limitation of a percentile bootstrap on a boundary-adjacent variance component" is open, and those
  imply very different fixes.
