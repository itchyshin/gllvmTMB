# Claude → Claude handover — Heywood gate MERGED; VGH lane open, Slice 1 half done

Date: 2026-07-30. Author: Claude. Target: **Claude** (same platform).
Predecessor: `docs/dev-log/handover/2026-07-29-claude-handover-vgh-heywood-gate.md`.
Lane map (multi-lane repo): `docs/dev-log/handover/2026-07-25-active-lane-split.md`.

**You are Claude, picking up a lane whose predecessor arc is finished and merged.**
Nothing is blocked on compute. One arc closed; one opened with its first slice half done.

## Mission control

| item | state |
|---|---|
| **`main`** | `a51ca881` — PR **#838 MERGED** |
| **this lane** | `claude/vgh-pluralism-20260730`, worktree `/private/tmp/gllvmtmb-vgh-pluralism`, **2 commits ahead, PUSH REQUIRED** |
| **checks** | `rcmdcheck --as-cran` **0 errors / 0 warnings / 1 note** (New submission); 58 tests green |
| **shipped this session** | the Heywood gate (both faces), `psi_rel_thresh` retune, `aghq_ridge` announced in NEWS |
| **next by leverage** | ① gaussian arm of Slice 1 ② VGH degeneracy at scale ③ compile VGH to C++ |
| **fenced** | Codex lanes `codex/va-*`, `codex/hvt1-*`, `codex/design86-*` — do not read, edit or claim |

## Critical context

**Do not re-open the Heywood arc.** It is merged and its calibration is complete —
thirteen cells, ~12,400 fits, all in `dev/heywood/`. Re-running reproduces what is
recorded.

**Two maintainer decisions were taken at the close and must not be re-litigated:**

1. **The gate ships with ONE new statistic, not the two the plan asked for.** Six
   candidates were measured and five rejected. Shinichi reviewed the evidence and
   chose "leave it at one" on 2026-07-30. If a future plan asks for a second,
   the answer is in `docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md`.
2. **`aghq_ridge` is announced** in `NEWS.md` with both costs stated (MAP not MLE;
   unit-tier only).

## What was accomplished

`check_gllvmTMB()`'s binomial loading row required `extreme_prevalence` as a
**conjunct**, so quasi-complete separation — a property of the fitted linear
predictor, not the marginal rate — could never trip it. **The gate keyed on a
quantity the pathology does not move**: across 3,944 binomial fits the worst
trait's prevalence never left [0.20, 0.807] while loadings ran to 24,057x typical,
essentially uncorrelated (**r = 0.036**).

| change | measured effect |
|---|---|
| `loading_runaway_thresh = 25` | 0/551 false positives, 96.3% detection |
| `loading_absolute_thresh = 6` on a new `max_loading_unit` column | +14 catches the ratio misses; the arm that survives p = 100 |
| `psi_rel_thresh` 0.001 → **0.01** | psi-collapse coverage 73.7% → 96.2%, FP 0 on 510 healthy fits |
| denominator taken over the traits being screened | a x100-scale gaussian trait no longer masks a binomial runaway (old behaviour: **0/37** detected) |
| absolute arm judged on the **unit tiers only** | the pre-fix rule flagged **60 of 61** healthy spatial fits; now **0/61** |
| advice rewritten | `suggest_lambda_constraint()` referral deleted; names `gllvmTMBcontrol(aghq_ridge = 2)` |

## Current working state

**WORKING:** everything above, merged.
**IN PROGRESS:** Slice 1 of the VGH lane — **binomial half DONE, gaussian half remaining**.
**BLOCKED:** nothing.
**UNPUSHED:** this lane's 2 commits. **Push before relying on them.**

## Key decisions & rationale

- **The Heywood gate is a Laplace-specific patch for a pathology VA does not have.**
  MEASURED: Laplace **50/148** degenerate (49 silent) against VGH **0/148**; Totoro
  grid agrees at 70/601 vs 0/320 (`gtmb_jj`) and 0/600 (`gllvm_va`).
- **The route is NOT "VA replaces LA".** The engines fail in disjoint ways — Laplace
  owns the median and small problems, VGH owns the tail and large m/n. **Both engines
  plus an honest gate saying which to trust** is what neither `gllvm` nor gllvmTMB ships.
- **A ratio and an absolute magnitude cover each other's blind spots.** At large p the
  ratio is fragile (23.95 against a threshold of 25); on a structured tier the absolute
  arm is fragile (70,792 from SPDE basis normalisation). Neither is safe alone.

## Files created / modified

Merged to `main` in #838 — `R/diagnose.R`, `man/check_gllvmTMB.Rd`, `NEWS.md`,
`tests/testthat/test-sanity-multi.R`,
`docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md`,
`docs/dev-log/2026-07-30-psi-face-heywood-and-rel-threshold.md`,
`docs/dev-log/2026-07-29-vgh-phase3-screen-result.md` (scope correction),
`docs/dev-log/after-task/2026-07-30-heywood-gate-diagnose.md`,
`docs/dev-log/after-task/2026-07-30-psi-face-and-mixed-family-validation.md`,
`docs/dev-log/handover/2026-07-30-claude-handover-heywood-gate-landed.md`,
and `dev/heywood/*.{R,csv}` (13 scripts + result CSVs).

On THIS branch (unpushed): `docs/dev-log/2026-07-30-vgh-pluralism-lane-brief.md`,
and this file.

**Never staged, deliberately:** `dev/heywood/fp-sweep-pilot*.csv` — superseded
exploratory output on an earlier column schema.

## Next immediate steps

1. **Push this branch**, then the gaussian arm of Slice 1 — see the lane brief.
2. **VGH degeneracy at scale** on the Totoro-grid design it postdates.
3. **Compile VGH to C++/TMB.** It is 8–15x faster than Laplace *as interpreted R* at
   large n/m, but ~20–25% SLOWER at small binomial problems.

## Gotchas / failed approaches

- **A test that passes proves nothing until it FAILS against the defect.** A patch here
  named its argument `keep`, colliding with a local `keep` in the loop above
  (`R/diagnose.R`). The parameter was silently overwritten and the denominator collapsed
  to the *first trait's* loading for every fit. **The new test passed anyway.** Renamed
  `reference_traits`.
- **Design the DGP so the gated quantity can reach its threshold.** A headline
  ("the old rule fired on 0 of 1,465") was forced by a DGP in which `extreme_prevalence`
  was unreachable — deducible from the code without simulating.
- **Reject a candidate only on a measurement as WIDE as the candidate.** Two rejections
  had to be re-run: a scale statistic scored against the wrong face, a saturation arm
  scored on the argmax trait only.
- **VGH takes FLAT args** and `X` must be constant within a unit — pass
  `matrix(1, n*p, 1)`; it fits per-trait coefficients internally. A per-trait design
  matrix is rejected.
- **Spatial fits need multi-trial binomial to converge.** Single-trial Bernoulli at
  n = 80 with two latent structures degenerates (`rel_frob` 677). Use n 200–300,
  10–20 trials. Build the mesh on the **long-format** data, not the unique sites.
- **`gllvm`'s VA is NOT faster than its LA** in our measurements (LA 3.3x faster at
  n = 200, m = 50). The received wisdom does not survive.

## How to resume

Read the lane brief first — it carries the do-not-re-derive list:
`docs/dev-log/2026-07-30-vgh-pluralism-lane-brief.md`.

> **🔴 SUPERSEDED 2026-07-30 — do not run the command below as written.** It contains two
> defects that were acted on before being caught, and it is left visible rather than deleted
> because the second one is the instructive part.
>
> 1. **"note VGH FIXES rather than estimates the residual SD" is inverted** for the engine
>    this arm actually uses. `dev/vgh/vgh-engine.R::vgh_fit()` (family `"gaussian"`)
>    **estimates** per-trait φ_j; it is `R/va-vgh.R::.vgh_fit()` (family
>    `"gaussian_anchor"`) that fixes it. This handover's own predecessor said it correctly —
>    `2026-07-29-claude-handover-vgh-heywood-gate.md:110` writes *"`gaussian_anchor` FIXES…"*.
>    Compressing `gaussian_anchor` to "VGH" dropped the only word carrying the distinction,
>    and the inverted version then travelled into a live instruction.
> 2. **"score recovery against known truth" is not a well-posed request on gaussian.** Laplace
>    is exact for a gaussian-identity GLLVM and the VGH ELBO is exact, so both optimise the
>    same objective (`dev/vgh/vgh-bench.R:3`) and share an MLE. There is no accuracy
>    difference to score. The arm was re-scoped accordingly — see
>    `docs/dev-log/2026-07-30-gaussian-arm-rescope.md`.
>
> **The lesson worth carrying:** a resume command is executable instruction, not prose. A
> one-word compression in it is a defect that the next session will act on before it reads
> the evidence. Keep engine names exact in resume commands, even at the cost of brevity.

```bash
# SUPERSEDED — see the note above. Kept for provenance.
cd /private/tmp/gllvmtmb-vgh-pluralism && claude "Rehydrate from docs/dev-log/2026-07-30-vgh-pluralism-lane-brief.md and docs/dev-log/handover/2026-07-30-claude-handover.md. Push this branch first. Then run the GAUSSIAN arm of Slice 1: match dispersion across Laplace and VGH — note VGH FIXES rather than estimates the residual SD — and score recovery against known truth. Make no accuracy claim in either direction until the parameterisations match."
```

Durable background in the brain (four notes):
*Two runaway modes in GLLVM loadings* · *VGH in gllvmTMB — the settled position* ·
*Query the PHENOMENON, not the PLAN* · *Designing a degeneracy gate*.
