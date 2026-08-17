# Slice-4 pass criteria — multinomial group random intercepts ((1 | group))

**STATUS: SIGNED (Shinichi, 2026-08-16, in-session).** This is a pre-registered criteria
block copied verbatim into this file so the aggregation logic cannot drift from
what was agreed before results exist. Do not weaken or add cells to this
block after seeing the `--mode full` output; any change after that point needs
a fresh dated note explaining why, not a silent edit.

---

## `(1 | group)` cell

20 seeds; `G = 60` groups, `n_per_g = 15` categorical draws per group
(`N = 900` observations), `K = 3`, `sigma_re_true = 0.6`
(`dgp_multinomial_grouped()`). Fits enter the aggregate only if
`convergence == 0` and PD Hessian (non-PD → counted+reported, excluded).

- **Recovery:** median `sigma_re_hat / sigma_re_true` ratio across the
  20-seed aggregate ∈ **[0.5, 2.0]** (loose band, mirroring S1/S2's own
  first-pass discipline — `sigma_re` is a single scalar per fit here, not a
  per-contrast vector, so there is no ratio-per-dimension pooling question).
- **Convergence/PD accounting:** report convergence code and PD-Hessian
  status for every one of the 20 seeds, same convention as S1/S2 (non-PD
  fits are excluded from the ratio aggregate but not from the denominator).
  >6/20 non-converged or non-PD = FAIL.

## Non-degenerate diagonal cell (`indep(0 + trait | g)` at the cluster tier)

Construction-level only for this slice — `test-matrix-multinomial-unit.R`
already carries the structural `extract_Sigma(level = "cluster")` shape
check (per-contrast diagonal, off-diagonal < 1e-8) against the SAME
`(1 | group)` grouped DGP reused as a convenience covariate (it has no
cluster-tier structure of its own to recover against). A dedicated
per-contrast recovery DGP and criteria block is deferred to a future slice
if the cluster-tier diagonal route needs its own calibrated recovery claim
— FAM-20F stays `partial` on this axis until then.

---

## Notes (not part of the pre-registered block above)

- `sigma_re` is REFERENCE-CATEGORY-SPECIFIC (R/multinomial-fence.R,
  docs/design/122-multinomial-structured-surface.md's Slice 4 section): the
  `(1 | group)` shared additive shift moves `P(y = baseline)` vs
  `P(y != baseline)`, so its recovered value is only comparable across fits
  that share the same `baseline` — re-labelling `baseline` is NOT a
  reparameterisation of the same model here (unlike the fixed-effects-only
  case), it fits a genuinely different constraint. This campaign fixes
  `baseline = NULL` (the first factor level) for every seed; it does not
  attempt a baseline-varying recovery claim. The separate, TRUE invariant
  this slice tests (`test-matrix-multinomial-unit.R`'s Cell (c)) is a
  WITHIN-fit, across-groups one: the log-odds between the two non-baseline
  categories is constant across every group level, exact to 1e-6 tolerance
  — not a claim about refitting under a different `baseline`.
- The MEASURED timing/smoke evidence for this campaign (D-139, this task,
  2026-08-16): `--mode timing` (`G = 60`, `n_per_g = 15`, seed = 1, 900 obs):
  **elapsed 0.76 sec**, convergence = 0, pdHess = TRUE, `sigma_hat = 0.389`
  (true 0.6) — projected 20-fit full run ≈ 0.3 min, well under the 30-min
  line. `--mode smoke` (`G = 20`, `n_per_g = 5`, 2 seeds, 100 obs): both
  convergence = 0, pdHess = TRUE; `sigma_hat` = 0.521 (seed 1, 0.64 sec) and
  0.137 (seed 2, 4.69 sec) against true 0.6 — noisy at this small a fixture,
  consistent with S1/S2's own smoke-mode observation that small-n cells are
  data-hungry; the pre-registered `--mode full` fixture (`G = 60`,
  `n_per_g = 15`) is deliberately larger. A separate single-seed check at the
  `--mode full` scale (`G = 60`, `n_per_g = 15`, seed = 111,
  `sigma_re_true = 0.6`) recovered `sigma_hat = 0.718`, ratio 1.197 — inside
  the pre-registered [0.5, 2.0] band (`test-matrix-multinomial-unit.R`'s
  heavy-gated Cell (b)).
- `--mode full` was **NOT run** as part of the ORIGINAL task that drafted
  this file — staged only, at that time. **Update: the full campaign HAS
  since run to completion under these signed criteria, for the `(1 |
  group)` cell only** (results:
  `dev/multinomial-structured/results/s4-summary-20260816-183635.csv` --
  20/20 rows, all `keyword = "re_int"`); the verdict is PASSED, recorded
  in `docs/design/35-validation-debt-register.md`'s FAM-20F row and
  `docs/design/122-multinomial-structured-surface.md` §1/§4. The
  "Non-degenerate diagonal cell" section above remains accurate as
  written: the cluster/cluster2 route was NOT part of this campaign and
  stays construction-level-only, `partial` on its recovery axis -- this
  file's own framing of that cell was correct throughout; the conflation
  that needed fixing was in the register/design-doc/NEWS surfaces, not
  here.

**Amendment (D-43 completion panel R6, 2026-08-16, dated below the frozen
block above -- the frozen block itself is unedited):** STATUS updated from
DRAFT to SIGNED to match the register's FAM-20F row, which already
reported this campaign's verdict as signed. The criteria numbers above
were not touched.
