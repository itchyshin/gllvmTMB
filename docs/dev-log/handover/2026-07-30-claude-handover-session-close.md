# Session handover — three PRs open awaiting merge; next arc is the ridge τ warning

**2026-07-30 · from Claude (Fable 5) · TARGET = Claude or Codex · all lanes clean and pushed**

## Mission control

| | |
|---|---|
| **state** | 3 PRs open, all green, all mergeable, **no conflicts between them** (verified by trial merge in both orders) |
| **blocked on** | maintainer merge only — the agent is blocked from `gh pr merge` by the permission classifier |
| **compute** | none running. Nothing on Totoro/DRAC. |
| **START HERE** | this doc → the PR bodies → `docs/dev-log/audits/2026-07-30-aghq-ridge-verification-audit.md` |

## What landed

| PR | contents |
|---|---|
| **#832** | Exports `profile_ci_total_variance()` behind a per-row `interval_status` fence: `"certified-0.94"` only inside the D-43 regime, `"route-only"` elsewhere, `"none"` for point-only rows. **The internal route is byte-unchanged** (137 insertions, 0 deletions), so "exporting does not change what was measured" holds structurally — `dev/m3-grid.R` still calls the identical instrument. |
| **#839** | #813 steps 1–2: `.details = TRUE` instrumentation on `.fix_and_refit_nll()`, 12 light-tier tests, and a corrected audit metric. The refit-budget commit was **dropped by maintainer decision** (reverted in `fb63a29b`, recoverable via `git cherry-pick 0b0c515d`). |
| **#842** | The AGHQ/ridge verification audit — documentation only. |

Issues filed: **#837** (zeta-scale asymmetry regression on `main` from `bb4862bb`), **#843** (AGHQ
multi-start disabled under `aghq_ridge = Inf` on invalidated evidence), **#844** (`aghq = "auto"`
k-ladder is dead code).

## Results worth not re-deriving

**#813 — the withdrawal reason is half right.** Measured on the #824 fixture (60 constrained
refits): the constraint is **tight** (median error 1.1e-5 against the 0.05 tolerance the route
accepts; zero points rejected), so **step 4's exact-constraint solver targets a problem that is not
there**. Unconverged refits genuinely are accepted (3 of 60). The dominant pathology is named by
neither half: adjacent *converged, constraint-satisfied* points land on different local optima. And
`.invert_profile_derived()` already knew — it smooths those curves with a spline rather than fixing
them, so a bound there is an average over optimiser failures.

**No fix shipped, deliberately.** Two candidates: sequential continuation met the pre-registered
criterion (8 → 0 non-monotone steps) and was **withdrawn** after adversarial review showed the
criterion was Goodharted — it counted drops at 1e-6 deviance, four orders below the χ²₁ cutoff, and
the relaxation's fixed point is nearly the condition that removes them. The refit-budget change
matched it on every CI-relevant number at ¼ the cost but regressed one knife-edge test. Full
reasoning in `docs/dev-log/after-task/2026-07-30-813-instrument-and-continuation.md` §2–§4.

**AGHQ — the integrator is correct, the estimator is not established.** Six independent checks
(Gaussian exactness at q=1 and q=2, a binomial k-ladder converging to 3e-06, an independent
re-implementation, an `integrate` oracle cross-checked by Simpson, AD-vs-FD at loading scale ×200).
No test anywhere compares an AGHQ point estimate to a known truth. Matches the repo's own line
(`decisions.md:2075`, *"The engineering is sound. The claims are not."*). Full detail and four
defects in the audit doc.

## The next arc — and why it is newly urgent

**Make the ridge warn when τ is mis-scaled.** `#838` merged during this session and its WARN action
now tells users to `gllvmTMBcontrol(aghq_ridge = 2)`. But the wide factorial shows the ridge makes σ
**worse** when true loadings exceed τ — 0.959 → 0.920 (Laplace) and 1.000 → 0.976 (AGHQ) at
`lam_sd = 3`. So the package now advises a fixed-τ setting we have evidence can harm exactly the
users most likely to hit the runaway that triggers the advice.

**Recommended scope: warn only, ~1–1.5 h.** When the fitted ‖Λ̂‖ sits far from τ, say so. A
genuinely scale-aware τ is its own arc (~4 h plus a validation campaign) — and adapting τ is itself
a modelling decision, which is how the unvalidated fixed τ = 2 got here in the first place.

Then, in order: the **shipped-engine truth-start at n=100** (#843 — decisive and small; it separates
"real statistics" from "single-start artifact"); the **false `penalised` disclosure** (set from the
request, not the effect, so W/phylo fits falsely warn "this is not AIC"); the **Gamma link fix** in
`19-family-axis.R` (trivial, unlocks a family that currently has zero usable fits); and last the
**Ψ-grammar gap**, which decides whether AGHQ ever applies to a default model.

`aghq = FALSE` should remain the default throughout.

## Do NOT redo

- **Campaign 12** (the T×n crossover). Its pre-registered O(1/T) mechanism is **not supported** —
  the wide factorial's σ-by-p is flat (1.003 / 0.987 / 0.989 / 1.002 at p = 2/4/6/12). The driver we
  could measure is **‖Λ‖**, and a six-point sweep answered it directly. Reasoning in the audit §7.
- **The #813 measurement** — done, recorded, reproducible via
  `dev/profile-communality-constraint-audit.R`.
- **CI-06** — checked, reads `blocked`, which is accurate. No defect.

## Lane state

| branch | committed | pushed | merged |
|---|---|---|---|
| `claude/export-profile-ci-20260730` | y | y | **n — maintainer** |
| `claude/813-instrument-20260730` | y | y | **n — maintainer** |
| `claude/aghq-audit-findings-20260730` | y | y | **n — maintainer** |

All three worktrees clean, zero unpushed commits. The main checkout's 15 dirty files are **not from
this session** — they were audited and deliberately left untouched (9 untracked docs exist only
there and would be lost if deleted; the two `.new.svg` snapshot artifacts are float-noise only).
