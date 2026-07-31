# Handover — #851 scale-aware start, continuation

**2026-07-31 · from Claude (Fable 5) · TARGET = a fresh Claude session · branch pushed, PR open, NOT merged**

## Copy-paste opener

```
🎯 GOAL — gllvmTMB #851 · land the scale-aware start · solo platform: CLAUDE
DELIVERABLE: PR #873 merged, or a written decision not to. The fix is DONE and
  measured; what remains is resolving the regressions it causes against a main
  baseline, WITHOUT relaxing any convergence check.
STATE: 7 new failures vs main; 2 fixed on merit so far; ~5 remain.
DISCIPLINE: verification runs on TOTORO (~15 min, see below), never locally (~5 h).
  Always run a MAIN BASELINE too — the raw failure count is meaningless without it.
  🔴 Bolker's named failure mode is agents relaxing checks to force convergence.
  Fix tests on their merits or escalate; do not widen a tolerance to land this.
DEFER: #872 (two-tier flatness) — different mechanism, not fixable by starts.
```

## What is settled — do not re-derive

**The fix works, and it is not merely parity.** On the ordinary single-tier
`latent()` model every scale law holds at k = 100 and k = 5000 to ~1e-05 or better
(Λ, fixed effects, Σ, correlations, logLik).

**Both comparators fail where it passes**, 8 seeds × 2 scales, identical data
(`dev/851-scale-equivariance-comparators.R`):

| violations (rel.err ≥ 0.02) | gllvmTMB | gllvm 2.0.13 | glmmTMB 1.1.14 |
|---|---|---|---|
| k = 100 | **0/8** | 2/8 | 6/8 |
| k = 5000 | **0/8** | 1/8 | 8/8 |
| worst case | **0.0105** | 0.998 | 2.00 |

So the `sd(y) ≈ 1` assumption is inherited across the model class, not a local slip.

**The mechanism, and the trade-off.** Tested one component at a time:
- removing the **score seeding** → no effect on the regression
- removing the **Ψ scaling** → regression gone, but scale laws collapse at k = 5000
  (Λ 0.301, Σ 0.459, correlations 0.459)

Ψ scaling is **both necessary for the fix and the cause of the regression.**

## Do NOT retry

**Ψ started at the residual REMAINDER instead of the total scale.** Principled —
it mirrors `.gllvmTMB_residual_factor_start()` — and it looked right on every
targeted check (failing fixture went to `convergence = 0`, objective unchanged,
single-tier still exact at 6.7e-06). **The full suite said 36 fail / 16 error
against 25 / 3.** It broke 13 tests in `test-lv-gaussian-recovery.R` and 13
*errors* across the `test-m1-*` mixed-family extractors. Reverted at `43377d14`.
The commit is on the branch if you want the diff.

Also do not retry: scaling Λ alone (changes the balance, non-PD Hessian in
`test-getlv-se.R`), or `start_method = "res"` as a default (retired on 89 fits).

## The state of the 7 regressions

Against a **main baseline** — 18 failures and all 3 errors on this suite are
pre-existing on `main` and are NOT yours (`test-m3-pilot-manifest.R` 16+2,
`test-profile-derived-curves.R` 2, `test-tweedie-fixed-p.R` 1).

| test | status |
|---|---|
| `test-start-method-residual.R` | **FIXED** — it asserted `theta_rr_B == c(0.5, 0)`, i.e. the hardcoded 0.5 that IS the defect. Now checks the property the test is for. |
| `test-traits-keyword.R` (2) | **1 of 2 fixed** — paired `latent()` with `unique()` on the same grouping, which double-requests the diagonal. Switched to the identified `latent(..., unique = FALSE)` form. One failure remains, undiagnosed. |
| `test-coevolution-two-kernel.R` (2) | not diagnosed |
| `test-canonical-keywords.R` (1) | not diagnosed |
| `test-lv-factor-runtime.R` (1) | gradient 0.00337 vs a 0.003 absolute threshold — 12% over |

## The judgement call you will hit

Two of the original failures were `convergence = 1`, and the fit was **not worse**:
identical objective (328.6236), positive-definite Hessian, `max|grad|` 2.7e-05.
nlminb reports `singular convergence (7)` — a singular *quadratic model at the
step*, on a configuration RE-09 already documents as over-parameterised.

Shinichi's position: a non-PD Hessian is acceptable because `profile_ci_*`,
`loading_profile`, `tmbprofile_wrapper` and `bootstrap_Sigma` sidestep it, and
Bolker's view (vault, 2026-07-28) is that **CIs are the least reliable part of
this stack** — so Hessian-based inference is the weak link by design.

**That is right, and it is also the exact argument that shades into cheating.**
The line taken here: fix a test when the failing assertion is *incidental to what
the test is for* (both fixes above), and escalate when it is not. Do not accept
`convergence = 1` by relaxing a check. If the remaining failures cannot be fixed
on merit, that is a design question for Shinichi, not something to absorb.

## Verification — use Totoro, it is set up

Local suite ≈ 5 h. Totoro ≈ **15 min** on 32 cores, and it is what makes a main
baseline affordable — which is the thing that made these results interpretable.

```
SOCK=$(ls ~/.ssh/cm-*totoro* | head -1)
rsync -az --delete -e "ssh -o ControlPath=$SOCK -o ControlMaster=no -o BatchMode=yes" \
  --exclude '.git' --exclude 'src/*.o' --exclude 'src/*.so' --exclude 'docs/' \
  /private/tmp/gllvmtmb-851/ totoro:~/gllvm_work/gllvmTMB-851/
ssh -o ControlPath="$SOCK" -o ControlMaster=no totoro \
  'cd ~/gllvm_work && nohup env NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
   Rscript --vanilla fullsuite.R > fullsuite.log 2>&1 &'
```

`~/gllvm_work/` already holds both trees, the runner scripts, and a compiled
baseline at `gllvmTMB-main`. `glmmTMB` is **not** installed there, so a few
comparator tests skip — count those as skips, not passes.

## Also true, and separate from this work

**`main` is not green.** 18 failures and 3 errors sit on it today, 16 of them in
`test-m3-pilot-manifest.R`. That is independent of #851 and it sits under the 0.6
release rung. Worth someone's attention on its own.

## Artifacts

Branch `claude/851-scale-aware-start-20260731`, PR #873 (open, do not merge until
green). Everything measured is on issue #851 in five comments. `#872` holds the
two-tier flatness split. Reproducers: `dev/scale-equivariance-check.R` (two-tier
acceptance oracle), `dev/851-scale-equivariance-comparators.R` (cross-package).
