# Lane B — parallel agent results + integration plan (2026-07-15)

Three live-TMB slices were dispatched to isolated-worktree agents after Lane A's
diff was committed (`84aea3e8`). This records their outcomes and how they will be
integrated. **Coordination note:** `isolation: worktree` branches from the
merge-base (`8ec261bb` = main), NOT the working-branch tip. So all three worktrees
lack Lane A's committed engine + my session commits; their work must be applied as
**diffs onto the current tip** (`c01a888c`+), not merged wholesale.

## S6 — diagnostics family breadth (DONE, needs sign-off)

Extended `residuals(type="randomized_quantile")` / `predictive_check()` /
`diagnostic_table()` to **binomial + Gamma + Beta**, validated by real fits
(n=60×2). All residuals finite; PIT-uniformity KS p = 0.28 (binomial), 0.36
(Gamma), 0.87 (Beta).

**Load-bearing find — a real bug in committed code.** Lane A's Gamma branch wrote
`scale <- mu / shape` at `R/predictive-diagnostics.R:458`, **clobbering the
function's `scale` argument** (`"normal"`/`"uniform"`) used at lines 531/618. Every
Gamma normal-scale residual silently returned the raw PIT `u` instead of
`qnorm(u)`, and the output `scale` column was corrupted to a number. Caught by
*running* the diagnostic, not trusting it (#388 "use it, don't assert it"). Fix:
rename the local to `scale_gamma`. **This bug is on the release branch now and must
be fixed there.** S6 also fixed `test-predictive-diagnostics.R` (it asserted Beta
= unsupported; repointed to tweedie), a break that also exists on the branch.

## S7 — nbinom1 + tweedie slope-recovery evidence (DONE, honest result)

| family | mode | n_sp | ratio (fitted slope-SD ÷ truth) |
|---|---|---|---|
| nbinom1 | free | 200 | **1.005** (recovers) |
| tweedie | free-p | 200 | 0.883 |
| tweedie | p-fixed | 200 | 0.884 |

- **nbinom1 RECOVERS** (unbiased at n=200); recovery test shipped.
- **tweedie: B1's premise is stale.** The reputed ~44% slope-SD over-estimate does
  NOT reproduce on the current engine (free-p recovers at ratio 0.88–1.04), and the
  `p`-fix escape hatch does NOT resolve B1 because there is no ridge-driven bias to
  remove (free-p already recovers `p` to within ~0.05 of truth). tweedie stays
  **deliberately gated** off the augmented-slope allowlist pending a full
  multi-seed campaign (#388/D-43). No tweedie capability claim made.
- Prior arm1 results were invalid (ran against a stale installed 0.5.0 predating
  the p-fix); S7 rebuilt from source to measure.
- **Flagged:** `test-tweedie-fixed-p.R` still cites the stale "~44% persists with p
  fixed" rationale. Conclusion (stay gated) holds; the magnitude is stale — refresh
  is a maintainer call.

## disp_group= — shared NB2 dispersion (STILL RUNNING)

Pending. Result shapes the nbinom2 story (whether pooled dispersion recovers Σ and
can begin to un-fence nbinom2). Integrated in the same pass.

## Integration plan (one verified pass, after disp_group= lands)

1. Apply each agent's surgical diff onto the current tip (not a branch merge —
   base mismatch): S6 Gamma `scale_gamma` fix + roxygen + the two test files; S7
   `test-family-slope-recovery.R` nbinom1 cell; disp_group= `R/fit-multi.R` + test.
2. Compile ONCE; run the heavy suite (`NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1`),
   summing the `error` column.
3. **Land** the unambiguous correctness fixes (Gamma bug, broken test).
4. **Present for maintainer sign-off** (do NOT auto-merge): the family-breadth
   capability + its advertising (S6), keeping tweedie gated + refreshing its stale
   rationale (S7), and the `disp_group=` API + its recovery evidence.

## Sign-off queue forming (🔴 needs Shinichi)
- S6 family-breadth capability claim (binomial/Gamma/Beta residuals) + roxygen.
- Confirm tweedie stays gated; whether to refresh `test-tweedie-fixed-p.R`'s stale
  ~44% rationale.
- `disp_group=` API + merge (pending its result).
