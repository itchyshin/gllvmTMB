# After-task — rebuilding the two iSDM articles for a real reader

**Date:** 2026-08-18
**Lane:** `claude/article-figures` (Claude Code)
**Scope:** article quality and the package defects the rebuild exposed. No
shipped package behaviour was changed.

## 1. Why this happened

Two articles (#1147, #1156) were **merged before the reviews that found their
defects**. That ordering error is the root cause of this entire arc, and it is
the one process change carried forward: reviewers run *before* merge.

A simulated PhD-student reader gave the verdict that framed the work:

> "Both articles are unusually honest about what they do not know... But the
> honesty is spent in the wrong places: the fences guard against claims I would
> not have made, and leave open the two things I would actually have got wrong."

## 2. What was done

A shared evidence base was built first — **thirteen measured blocks plus three
corrections** in `dev/isdm-precision/READER-BLOCKS.md`, each with a runnable
script in the same directory — and only then were the articles rewritten
against it. No prose preceded its measurement.

The simulation was rebuilt to pass a **six-condition recovery gate** before any
article was allowed to rest on it (`dev/isdm-precision/SIM-REBUILD-REPORT.md`).

## 3. Checks run

| check | result |
|---|---|
| Recovery gate, all six conditions | PASS, no threshold changed |
| `isdm-spatial-precision.Rmd` render | RENDER_OK, 0 warnings |
| `isdm-canada-warbler.Rmd` render | RENDER_OK, 35 chunks |
| Figures verified as PNGs, not as code | done for both articles |
| `test-isdm-predict.R` (for the merged PRs) | 65 pass, 0 fail, 0 skip |
| `R CMD check` | **not applicable** — `dev/` and `vignettes/articles/` are both in `.Rbuildignore`, verified |

The recovery gate:

```
G1a |cor(env, access)|         -0.0000   G1b |cor(env, field)|  -0.0000
G2a mean cor(beta_hat, true)    0.9941   G2b err / MC-SE ratio     1.07
G3  cor(|err|, log PO)  r=-0.073 p=0.972 G4  |cor(log_eff, src)| 0.0064
G5  one UTM zone, 0 straddle warnings    G6  0 shared cell_id
```

30/30 fits, `mean|err|` 0.1028 against a true-slope SD of 0.514 — it was 1.81
against 0.45. Byte-identical across runs; holds at three further landscape
seeds.

## 4. Package defects the rebuild exposed

Three filed, all the same class: **the code took a degenerate path and reported
success**. They join #1132, #1120, #1119 and #1083 to make seven this session.

| issue | defect |
|---|---|
| [#1163](https://github.com/itchyshin/gllvmTMB/issues/1163) | The grouping token on a `spatial_*()` term is inert. `coords`, `banana` and `xy` all give logLik −63.01954 to 8 s.f. |
| [#1165](https://github.com/itchyshin/gllvmTMB/issues/1165) | A raw `fmesher` mesh passed as `mesh =` errors correctly *with* a spatial term and is **silently ignored without one** — objective identical to 15 significant figures |
| [#1167](https://github.com/itchyshin/gllvmTMB/issues/1167) | SPDE fits return `convergence == 0` after **one** iteration at objective ~1e21, spatial parameters at starting values, slopes ≈ 20. `iterations` catches it; `convergence` does not |

**#1167 is the most consequential of the set**, because the returned estimates
are not defaulted but numerically enormous, and would be carried straight into
a map. The margin is narrow: max cell count 150 is fine, 371 is silently
wrong — about 3× in intensity, at counts realistic for an eBird-derived arm.

A capability gap was also documented, and it is *not* a defect: `weights =` is
deliberately refused for any `isdm_sources()` fit, because across arms it would
mean a binomial trial count on detection rows and a likelihood multiplier on
count rows. The refusal is loud and self-explaining — the opposite of the
class above.

## 5. Claims of my own that were wrong, and corrected in place

Recorded rather than deleted, because the correction is the useful artefact.

1. **Block 8's mechanism.** My disjoint-arms demonstration passed a raw
   `fmesher` mesh with **no spatial term**, so the `A_proj` mechanism I
   described was never exercised. Caught by a mesh sweep returning slopes
   identical to three decimals across 59–1,081 nodes — inertness, not
   robustness. That is what exposed #1165. Redone properly, the demonstration
   is far stronger (ΔlogLik 284.06, slope error 0.108 → 0.041).
2. **The offset confound severity.** I rated `offset(log_effort)` being
   perfectly confounded with `isdm_source` as high-severity. Measured, the
   slopes are unharmed: dropping the offset gives an objective identical to
   eight significant figures, because an offset carries no free coefficient.
   The defect is **pedagogical**, not statistical.
3. **The presence-only route's reach.** My rewrite brief assumed the
   Berman–Turner quadrature device would combine with the two-arm fit. It does
   not (§4). Found because the article lane tested the brief instead of
   trusting it.

A fourth was corrected earlier in the session: a seed-block sign-test
`p ≈ 0.004` that ignored a measured 0.151 correlation among the indicators.
Corrected `p = 0.30`.

## 6. A process failure of mine

Commit `d58cd8e7`, whose message says it commits nine evidence scripts, also
swept another lane's in-progress `precision-sim.R` into itself — 522 insertions
the message never mentions. I staged a scoped **directory**, which is still too
broad while another agent is writing into it. The content was verified
byte-identical to that lane's final script, so nothing was lost; this is a
provenance defect, recorded rather than rewritten because later commits sit on
top.

Two agents were dispatched into the same worktree, and **both independently
flagged it**. That was my dispatch error. The fix is one agent per worktree, or
explicit file-level staging — not directory-level.

## 7. Caveats that must travel with the work

- The rebuilt simulation retains a small but statistically real residual bias:
  pooled mean error **+0.0274, t = 4.17**, uniform across species, 5.3% of the
  true slope SD. Immaterial for an article, but **these slopes must not be
  described as unbiased**.
- Every article result is a single simulated seed for illustration, not a
  calibration campaign.
- No real GBIF or ABMI data was analysed. Doing so needs the ABMI data
  agreement. This is a scope decision, stated in both articles rather than
  silently omitted.

## 8. Follow-up

- #1163, #1165, #1167 are filed and unfixed; all three are reader-facing traps.
- The E1 `covered` register note remains proposed, not applied — ISDM-03 stays
  `partial`.
- #1161 (phylogeny on the trait axis), #1138's remaining tiers and #1133 item 4
  are deferred and fenced.

## 9. The review round (added after §1–8)

Both reviewers ran **before** merge. Full response:
`dev/isdm-precision/REVIEW-2-RESPONSE.md`.

**Pat moved from "No — the first thing I would try fails" to "Yes-but",**
with four blockers, all now addressed. The most important, and the single
most valuable finding of the arc:

**The headline inverts in the case a real reader has.** The biased-arm design
gave itself an accessibility surface **measured exactly** and modelled, which
makes the presence-only arm already unbiased — so integration could only
cost. Reproduced independently before acting, 12 replicates at `fuzz = 1.0`:

| what the analyst has | integration helped |
|---|---|
| independent + measured exactly *(the design)* | 3/12 |
| confounded ρ = 0.7, still measured exactly | **0/12** |
| confounded, surrogate error sd 0.5 | **11/12** |
| confounded, not modelled | **12/12** |

The switch is not confounding but whether the bias surrogate is exactly
right, and nobody's is. In the reversal regime *nothing* recovers truth
(1.72 vs 1.58 against 0.9) — the ranking flips, both answers are bad.

**Florence found a false claim in the prose**: "at `fuzz = 0` every design
and every arm sits within 0.02 of 0.9" — the fuzzed arm at 400/100 is
**0.9662**, verified. Plus six clipped replicates against captions saying
"all", a caption saying 45 where the file holds 135, and the map's fence on
the last pixel row of the canvas. She confirmed the greyscale hatching fix
holds under luminance, deuteranopia and protanopia.

**A fourth wrong claim of mine, caught by the render.** The `d = 1` section I
wrote read a parameter that does not exist, returned `numeric(0)`, and the
prose after it asserted the loadings differ — a claim with no evidence
shown, which is exactly the failure this arc is about. Real name
`theta_rr_spde_lv`; it prints 0.0515 / 0.0009, matching Florence's
independent measurement.

**Still open**, recorded rather than closed: Pat's friction list (dev-path
references without hyperlinks, `species: placeholder` unexplained, no route
to map uncertainty), her N4 (mild over-correction in section order), and
Florence's polish tier.
