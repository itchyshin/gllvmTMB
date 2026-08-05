# Handover — gllvmTMB VA: the loading-bias lead, and a session of instrumentation errors

**Author:** Claude Code (solo) → **Target:** fresh session, no chat inherited
**Branch:** `claude/va-lane2` · **HEAD `bf483ce4`** · **Worktree:** `/private/tmp/gllvmtmb-va-lane2`
**`origin/main`:** `5bf18ab3` — PROTECTED, untouched.

> The repository is authoritative. Classify everything below OWED / DONE / RETRACTED
> against actual git state before acting.

## FIRST: rehydrate

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && ./tools/check-push-traps.sh && git status --short
```

## LANDED (uncommitted — ~18 files in the worktree, nothing pushed)

**Arc A — VA ordination surface: COMPLETE and verified.** `extract_ordination()`
(`R/extractors.R:463`) gained a `gllvmTMB_va` branch — 4 lines before the two failing
lines (`:478 fit$tmb_obj`, `:480 fit$data[[fit$trait_col]]`) — which unlocked
`getLV`/`getLoadings`/`extract_loadings` together. Plus `getLV(se=TRUE)` returning a
labelled variational posterior SD behind a **degeneracy gate** (per-column CV `< 1e-8`,
mechanism-based not tier-based), and a refusing `predict.gllvmTMB_va`.
**Checks:** 34 assertions (`test-va-ordination.R`); **full suite 0 failures**; fence test
`test-va-intervals.R` 83 assertions pass, `calibrated = FALSE` **unmoved**;
`git diff R/integration-fence.R` **empty**. Docs: `man/gllvmTMBcontrol.Rd`, register row
VA-13, corrections to `va-capability-worklist.md` + Design 85. Closure: after-task
`2026-08-05-va-ordination-usability.md`, check-log entry, ledger rows 50–58,
`docs/dev-log/plan-actual/2026-08-05-va-usability.md`.

## 🔴 THE LEAD — start here

**Our VA `jj`/`ac` tiers carry a real ~2× loading attenuation. gllvm does NOT. Our `gh` does NOT.**

Convention-free evidence (`dev/va-usability/130-crux.log`, probit n=150 p=20, 10 seeds).
`eta_var` = `var(Λ̂ẑ)/var(Λz)`, invariant to how scale splits between Λ and z — the arbiter,
because latent-r is a CORRELATION and therefore scale-blind:

| arm | sd(ẑ) | trace | **eta_var** |
|---|---|---|---|
| our `ac` | 0.895 | 0.528 | **0.441** |
| our `gh` | 0.883 | 1.157 | **0.922** |
| gllvm (raw `theta`) | 0.895 | 1.071 | **0.892** |

**NAMED SUSPECT: the collapsed variational covariance.** `GLLVM-REFERENCE-READ.md:403-420`
records gllvm computing `A_i = (I_d + Σ_j θ_j θ_j')⁻¹` in a **per-row fixed-point loop**
(lines 1125–1200) with `Lambda.struc` selectable **`"unstructured"`** (full `n × d × d`).
Our AC collapses to one shared matrix — claims-ledger claim 35 measured the per-unit SD as
**constant to machine zero (8.36e-17)**. A more restricted variational family = looser bound
= bias in the parameters living in the objective's curvature, i.e. the loadings.

🔴 **THE COLLAPSE SUSPECT IS DEAD — corrected 2026-08-05 before any test was run.**
`collapse_variational_cov = FALSE` is **already the DEFAULT** (`R/va-r3-proto.R:1929`).
Our AC never collapsed. The flag experiment measures nothing; do NOT run it.

The per-unit constancy claim 35 recorded (SD identical to 8.36e-17) is **structural to
Albert–Chib, not a configuration**: `∂E/∂v ≡ −n/2` carries no data dependence, so the
optimal variational variance is identical for every unit *by construction*. It cannot be
switched off. That also explains why **GH is unbiased** — its expectation is evaluated by
quadrature, so its variational variance genuinely varies per unit.

**SO THE REAL QUESTION IS ALGORITHMIC, NOT A FLAG:** what does gllvm's **per-row
fixed-point** update (`GLLVM-REFERENCE-READ.md:403-420`, gllvm lines 1125-1200, with the
family-specific solve at 1134-1156) compute that AC's closed form does not? That is a
genuine difference worth borrowing — and the method is PUBLISHED (Hui, Warton, Ormerod
et al. 2017, JCGS), so it is citable and reimplementable. Porting actual code would need
provenance notes in `inst/COPYRIGHTS` per CLAUDE.md; reimplementing from the paper would not.

**START HERE:** read `gllvm:::gllvm.TMB`'s variational-covariance update against
`inst/tmb/gllvmTMB_va_r3.cpp`'s AC branch and identify the structural difference. Measure
second. **Two mechanisms have now been proposed and refuted from plausible readings without
checking the code — do not propose a third without a grep first.**

**USE TOTORO.** The probit GH cells are the bottleneck (1147 s at n=1000 on 8 local cores);
384 cores collapse that to minutes. Deploy, verify the remote run wrote non-empty output,
THEN scale. Results stay LOCAL (D-50).

## RETRACTED THIS SESSION — do not cite

1. **"gllvm has the same loading attenuation as us."** WRONG — I mis-scored gllvm by folding
   in `sigma.lv` (following `29-head-to-head-gllvm.R:70-73`), which multiplies loadings by
   0.71 and shrinks trace by 0.71² ≈ 0.5, manufacturing the exact 0.508 that looked like
   damning agreement. gllvm's **raw `theta` IS Λ** (its `lvs` already have sd ≈ 0.9).
   ⚠ This also invalidates the gllvm **loading** column in `71-paired-summary.csv` (logit).
2. **"We are marginally ahead of gllvm."** Unpaired seed streams; SE of the difference
   (~0.026) swamps every gap. Superseded by the paired `71-...R`: **we MATCH gllvm**
   (only 1 of 4 cells separates from 0, and there we win just 13/20 replicates; gaussian
   identical to 7 dp).
3. **"VA bounded, Laplace unstable"** (ledger 52) — read a length-8 per-trait vector as a
   scalar. True maxima 1.136/0.804.

## WHAT STANDS

- **Thin-cell ceiling is REAL and externally reproduced.** Binomial latent-r 0.568 → 0.774 →
  0.859 → 0.919 at p = 8/20/40/80 (sd 0.078 → 0.008); gllvm climbs identically. The r ≈ 0.59
  "ceiling" was p = 8, not binary data. **Never benchmark at p = 8.**
- **`jj` is asymptotically biased**: trace 0.777/0.600/0.538/**0.535** at n = 150/400/1000/2000
  — a plateau, so a genuine plim ≈ 0.53. `gh` converges (1.583 → 1.132 → **1.014**).
  **The tier makes NO difference to latent scores**, so `gh`'s ~33× cost buys nothing for the
  ordination and only corrects loading magnitude.
- **Gaussian/Poisson VA are indistinguishable from Laplace** (paired diff 1.8e-07 gaussian).
- **Laplace on binary is UNSTABLE, not biased**: probit n=150 p=20 median 1.229 but **9/20
  seeds > 2×**, max 105. A stable bias is more usable than unstable near-unbiasedness.
- **Literature (`120-...md`): the specific finding is NOT documented.** VB *uncertainty*
  underestimation is well known; VB *point-estimate* consistency is the standard claim.
  Closest: Mauri & Dunson 2025 Biometrika ("valid UQ for B but not ΛΛᵀ" — a coverage claim).
  ⚠ Now that gllvm is exonerated, this is **our implementation gap, not a paper.**

## STILL RUNNING AT HANDOVER

`dev/va-usability/100-probit-stage8.R` — probit n-ladder (n=150 ✅ 400 ✅ 1000 in flight),
4 paired arms. Log `100-probit-stage8.log`. **Read it before acting on probit.**
`110-correlation-recovery.R` finished but wrote **no report** — recover from
`dev/va-usability/raw/` if the correlation-vs-variance question matters.

## PROCESS — read before trusting any number here

**EIGHT instrumentation errors in one session, all the same shape: a number or state
published without checking the artifact that would prove it.** Five caught by the adversarial
reviewer, two by the maintainer, one by a control refuting me. Full list in the after-task §8
and `plan-actual`. New brain notes filed (retrieval recall 82.4% → 90.4%):
`The verification rule you enforce on sub-agents is the one you exempt yourself from`,
`The ladder axis must match the estimand`,
`Degrading with n is OUR bug unless a correctly-specified control converges`,
`An internal control is not a comparator`.

⚠ **And the sharpest, learned at the very end:** a known-answer control only validates a
convention **if that cell exercises it.** The gaussian cell has `sigma.lv` ≈ 1.005, so both
scoring conventions pass there — the control I installed to catch the `sigma.lv` bug
**would not have caught it**. Validate where the suspect parameter is FAR from its
degenerate value (here: probit, `sigma.lv` = 0.710).

## OPEN — needs the maintainer

- **Expose `eval_method`** via `gllvmTMBcontrol()` (additive, reversible, no default change).
  Recommended. **Do NOT change the binomial default** — `gh` costs ~33× and buys nothing for
  the ordination; precedent is ledger claim 49 ("not licence to change the default").
- **probit fence admission** — probit beats logit for binary ordination (latent-r 0.864 vs
  0.774 at p=20). Would need the Stage-8 evidence; this campaign is Stage-8-*shaped*, not
  Stage-8-*grade* (20 seeds, one DGP).
- Nothing committed. Nothing pushed. `origin/main` untouched.
