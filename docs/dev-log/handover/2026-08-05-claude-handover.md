# Handover to Claude — gllvmTMB VA: ordination SHIPPED, and a loading-bias lead

**Author:** Claude Code (solo) → **Target:** Claude, fresh session, no chat inherited
**Branch:** `claude/va-lane2` @ **`461ac9c5`** · **Worktree:** `/private/tmp/gllvmtmb-va-lane2`
**`origin/main`:** `5bf18ab3` — PROTECTED, untouched all session.

> The committed repository is authoritative. This file supersedes the chat and supersedes
> `2026-08-05-claude-handover-va-loading-bias.md` (an earlier draft of the same day; its
> technical content is folded in here, and one of its central claims was retracted after it
> was written).
> **Classify every item below OWED / DONE / RETRACTED / PROTECTED against actual git state
> before acting.**

## FIRST: rehydrate

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && ./tools/check-push-traps.sh && git log --oneline -8 && git status --short
```

## Landing state

| item | state |
|---|---|
| `3a71117f` feat(va): ordination surface | ✅ **COMMITTED**, ⚠ **NOT PUSHED** |
| `59456ef7` docs(design): VA-13 + 3 stale-claim fixes | ✅ COMMITTED, NOT PUSHED |
| `e7c51e3b` docs(dev-log): arc closure + retractions | ✅ COMMITTED, NOT PUSHED |
| `0ce3389d` evidence(va): campaign aggregates | ✅ COMMITTED, NOT PUSHED |
| `461ac9c5` docs(handover): retract collapse suspect | ✅ COMMITTED, NOT PUSHED |
| **5 commits `bf483ce4..461ac9c5`** | 🔶 **CARRIED-OVER — unpushed.** WHY: the maintainer did not ask for a push; nothing here belongs on `main`. RESUME: `git push origin claude/va-lane2` after `git rev-parse --abbrev-ref claude/va-lane2@{upstream}` |
| `dev/va-usability/raw/` (4.6 MB per-seed `.rds`) | 🔶 **CARRIED-OVER, deliberately untracked (D-50).** Simulation output stays LOCAL, never GitHub artifacts. Aggregates (scripts/logs/CSVs) ARE committed |
| `dev/va-speed/80-arcB0-*`, `81-arcB2-analyse.R` | 🔶 **CARRIED-OVER, untracked.** Cancelled sandwich arc. `80-arcB0-README.md` IS committed and explains them. **Do not cite their numbers** |
| `dev/va-speed/inventory-analysis.txt` | 🔶 CARRIED-OVER, untracked scratch inherited from an earlier session. **Never stage** |
| `dev/va-usability/100-probit-stage8.R` | 🔶 **STILL RUNNING at handover** — see below |
| `origin/main` | **PROTECTED** `5bf18ab3`. Do not merge; a PR is the maintainer's act |

## DONE — Arc A: the VA ordination surface (verified)

A user can now fit with `gllvmTMBcontrol(integration = "va")` and get an **ordination** out.
Laplace stays the default.

**One choke point unlocked all four extractors.** `getLV()`, `getLoadings()`,
`extract_loadings()`, `extract_ordination()` all funnel through `extract_ordination()`
(`R/extractors.R:463`), which read `fit$tmb_obj` (`:478`) and `fit$data[[fit$trait_col]]`
(`:480`) — neither of which a VA fit carries. A `gllvmTMB_va` branch placed **before** those
lines dispatches to `.va_extract_ordination()`.

- Λ from `theta_rr` via the engine's own `.va_r3_unpack_theta_rr()`; scores from the
  variational means. Trait/unit labels **synthesised** (a VA fit stores no data or column
  names) — same convention as the Julia bridge extractor.
- `level = "unit_obs"` → `NULL` (the route fits no within-unit tier).
- `getLV(se = TRUE)` returns a variational **posterior SD**, never a standard error, stamped
  `uncertainty_basis` + `calibrated = FALSE`. Gated **twice**: by tier (`"jj"` refused) and by
  **mechanism** — any per-unit SD constant across units is refused (per-column CV `< 1e-8`).
  The mechanism gate exists because the tier gate had a live hole: `"ac"` is unreachable from
  the public route while a public **gaussian** fit resolves to `"gh"` and returned an array
  constant to CV 1.6e-15.
- `predict.gllvmTMB_va()` refuses via `.va_not_defined()` instead of R's bare dispatch error.

**Checks:** `test-va-ordination.R` 34 assertions · **full `devtools::test()` 0 failures** ·
fence test `test-va-intervals.R` 83 assertions pass · `git diff R/integration-fence.R` **empty**
· `confint`/`vcov` still abort on `calibrated = FALSE`.

## 🔴 THE LEAD — start here

**Our VA `jj`/`ac` tiers carry a real ~2× loading attenuation. gllvm does NOT. Our `gh` does NOT.**

Convention-free evidence (`dev/va-usability/130-crux.log`; probit n=150, p=20, 10 seeds, all
arms on identical data). `eta_var = var(Λ̂ẑ)/var(Λz)` is **invariant to how scale splits between
Λ and z** — the arbiter, because latent-r is a CORRELATION and therefore scale-blind:

| arm | sd(ẑ) | trace | **eta_var** |
|---|---|---|---|
| our `ac` | 0.895 | 0.528 | **0.441** |
| our `gh` | 0.883 | 1.157 | **0.922** |
| gllvm (raw `theta`) | 0.895 | 1.071 | **0.892** |

`sd(ẑ)` ≈ 0.89 for **every** arm — no compensating score inflation, so this is not a
reparameterisation.

### ⚠ TWO MECHANISMS PROPOSED AND REFUTED — do not propose a third without a grep

1. ~~"gllvm shares the bias"~~ — **RETRACTED.** I mis-scored gllvm by folding `sigma.lv`
   (0.710 on probit) into the loadings, shrinking trace by 0.710² ≈ 0.5 and manufacturing the
   0.508 that looked like agreement. **gllvm's raw `theta` IS Λ** (its `lvs` already have
   sd ≈ 0.9).
2. ~~"our AC collapses the variational covariance"~~ — **RETRACTED before any test.**
   `collapse_variational_cov = FALSE` is **already the DEFAULT** (`R/va-r3-proto.R:1929`).
   The per-unit constancy claim 35 recorded (SD constant to 8.36e-17) is **structural to
   Albert–Chib**: `∂E/∂v ≡ −n/2` carries no data dependence, so the optimal variational
   variance is identical for every unit *by construction*. No flag turns it off. This also
   explains why **GH is unbiased** — quadrature makes its variational variance genuinely
   per-unit.

### The real question

**What does gllvm's per-row fixed-point update compute that AC's closed form does not?**
`GLLVM-REFERENCE-READ.md:403-420` documents gllvm's `A_i = (I_d + Σ_j θ_j θ_j')⁻¹` computed in
a per-row loop (gllvm lines 1125-1200; family-specific solve 1134-1156), with `Lambda.struc`
selectable `"unstructured"`.

**START HERE: read `gllvm:::gllvm.TMB`'s variational-covariance update against
`inst/tmb/gllvmTMB_va_r3.cpp`'s AC branch. Identify the structural difference. Measure second.**
The method is **published** (Hui, Warton, Ormerod et al. 2017, JCGS) so it is citable and
reimplementable; porting actual code needs provenance notes in `inst/COPYRIGHTS` per `CLAUDE.md`.

**USE TOTORO — but budget 50 cores, 150 MAXIMUM (maintainer, 2026-08-05).** Totoro is SHARED;
do not size a job off its 384-core total. Probit GH cells are the bottleneck (1147 s at n=1000
on 8 local cores); even 50 cores is a ~6x speed-up over local. Deploy, **verify the remote run wrote non-empty output**, then scale.
Results LOCAL (D-50), never GitHub Actions.

## WHAT STANDS (do not re-measure)

- **Thin-cell ceiling is REAL and externally reproduced.** Binomial latent-r **0.568 → 0.774 →
  0.859 → 0.919** at p = 8/20/40/80, sd collapsing 0.078 → 0.008; gllvm climbs identically
  (0.565 → 0.743). The r ≈ 0.59 "ceiling" was **p = 8, not binary data**. **Never benchmark at
  p = 8** — every estimator collapses there and the comparison discriminates nothing.
- **We MATCH gllvm on the ordination.** Paired, 4 cells (`71-paired-summary.csv`): only 1 CI
  separates from 0 and there we win just 13/20 replicates; gaussian identical to 7 dp.
- **`jj` is asymptotically biased**: trace 0.777/0.600/0.538/**0.535** at n = 150/400/1000/2000
  — a *plateau*, hence a genuine plim ≈ 0.53. `gh` converges (1.583 → 1.132 → **1.014**).
  **The tier makes NO difference to latent scores**, so `gh`'s ~33× cost buys nothing for the
  ordination and only corrects loading magnitude.
- **Correlations largely survive the bias.** `110-correlation-recovery-summary.csv`: probit-ac
  MAE 0.179 / off-diag r 0.929; probit-gh 0.166 / 0.935; logit 0.282 / 0.818. Uniformity
  R² ≈ 0.85 — the attenuation is near a uniform scale factor, which **cancels in the
  correlation matrix**. What is wrong is the absolute variance scale. ⚠ gllvm was never scored
  on this metric — a real hole.
- **Gaussian/Poisson VA ≈ Laplace** (paired latent-r diff 1.8e-07 gaussian, ~4e-04 poisson).
- **Laplace on binary is UNSTABLE, not biased**: probit n=150 p=20 median 1.229 but **9/20 seeds
  > 2×**, max 105. A stable bias is more usable than unstable near-unbiasedness.
- **Literature (`120-LITERATURE-VA-ATTENUATION.md`): the finding is NOT documented.** VB
  *uncertainty* underestimation is well known; VB *point-estimate* consistency is the standard
  claim. Closest: Mauri & Dunson 2025 *Biometrika* ("valid UQ for B but not ΛΛᵀ" — a coverage
  claim). ⚠ **Now that gllvm is exonerated this is OUR implementation gap, not a paper.**

## STILL RUNNING AT HANDOVER

`dev/va-usability/100-probit-stage8.R` — probit n-ladder, 4 paired arms (VA-gh, VA-ac,
Laplace-probit, gllvm-probit) at p=20. **n=150 ✅ n=400 ✅ n=1000 in flight.**
Log: `dev/va-usability/100-probit-stage8.log`; per-cell `.rds` in `raw/`.
**Read the log before acting on probit.** It answers whether AC's 0.53 loading scale
*converges* or *plateaus* like `jj`'s.

## PROCESS — read before trusting any number here

**NINE instrumentation errors in one session, all one shape: a number or state published
without checking the artifact that would prove it.** Five caught by adversarial review, two by
the maintainer, one by a control that refuted the claim I had just made for it, one by a grep.
Full list: after-task §8 and `docs/dev-log/plan-actual/2026-08-05-va-usability.md`.

New brain notes filed (retrieval recall **82.4% → 90.4%**, golden set 62 → 73 cases):
`The verification rule you enforce on sub-agents is the one you exempt yourself from` ·
`The ladder axis must match the estimand` ·
`Degrading with n is OUR bug unless a correctly-specified control converges` ·
`An internal control is not a comparator`.

⚠ **The sharpest, learned last:** a known-answer control only validates a convention **if that
cell exercises it**. Gaussian has `sigma.lv` ≈ 1.005, so both scoring conventions pass there —
the control installed to catch the `sigma.lv` bug **would not have caught it**. Validate where
the suspect parameter is FAR from its degenerate value (here: probit, `sigma.lv` = 0.710).

## OPEN — needs the maintainer

- **Expose `eval_method`** via `gllvmTMBcontrol()` — additive, reversible, no default change.
  **Recommended.** Currently `R/va-routing.R:350-355` hard-wires the tier, so the accurate
  `gh` route is unreachable.
- **Do NOT change the binomial default** — `gh` costs ~33× and buys nothing for the ordination.
  Precedent: ledger claim 49 (`n_starts`), *"not licence to change the default."*
- **probit fence admission** — probit beats logit for binary ordination (latent-r 0.864 vs
  0.774 at p=20). Needs Stage-8 evidence; the running campaign is Stage-8-*shaped*, not
  Stage-8-*grade* (20 seeds, one DGP).
- **Whether to push the 5 carried-over commits.**

## Live environment

```sh
cd /private/tmp/gllvmtmb-va-lane2
export NOT_CRAN=true
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="va")'   # safe verify
# Totoro (384 cores, no Duo, standing authority):
SOCK=$(ls ~/.ssh/cm-*totoro* | head -1)
ssh -o ControlPath="$SOCK" -o ControlMaster=no -o BatchMode=yes totoro '<cmd>'
```

⚠ `Rscript --vanilla` implies `--no-environ` — pass `R_LIBS_USER=$HOME/R/lib` or
`library(gllvm)` fails. ⚠ A `pgrep -f "X"` wait-loop **matches its own command line** and
deadlocks forever while looking like patience — cost an hour this session. ⚠ **Never stage:**
`dev/va-usability/raw/`, the `80-arcB0-*` cancelled-arc files, `inventory-analysis.txt`.

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-05-claude-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
