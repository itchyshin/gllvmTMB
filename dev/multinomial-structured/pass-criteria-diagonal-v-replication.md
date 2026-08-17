# Pre-registered criteria — diagonal-V replication rescue (closes FAM-20D's caveat)

**STATUS: SIGNED** — Shinichi's standing sign-off for this arc's campaigns
(2026-08-17, "sign off - please keep going!"). Committed BEFORE any fit of
this cell ran; results land in a separate later commit.

## What this closes

FAM-20D records: *"The replication rescue is UNTESTED for the diagonal-V mode
— s1b fit only the full-rank parameterisation; do not extrapolate."*
Unreplicated `phylo_indep` on diagonal truth FAILED its Arc-1 gate: the
smaller contrast variance collapsed (median ratio 0.24, 9/20 in band) and
**7/20 seeds collapsed to numerical zero (<= 1e-9) with convergence = 0 AND a
PD Hessian**. s1b then showed that per-species replication (n_rep = 5)
rescues the FULL-RANK cell. This cell asks the same question of the DIAGONAL
mode, which s1b did not touch.

## Design

- DGP: `dgp_multinomial_replicated()` with **diagonal truth** —
  `rho_true = 0`, `sd_true = c(0.8, 0.5)` (matching the corrected Arc-1
  diagonal cell so the comparison is like-for-like), `n_sp = 300`,
  `n_rep = 5`, K = 3, seeds 601:620 (20 seeds).
- Fit: `phylo_indep(0 + trait | species, tree = tree)`, `unit = "obs"`.
- Extraction: `extract_Sigma(level = "phy", part = "shared",
  link_residual = "none")`; per-contrast variance ratios vs truth
  (0.64 and 0.25).

## Frozen gates (not to be widened after results)

Aggregate over seeds with `convergence == 0` AND PD Hessian; non-PD counted
and reported, excluded from bands.

1. **Collapse rate** — seeds with any per-contrast variance <= 1e-9 must be
   **<= 2/20** (unreplicated baseline: 7/20). More than 2 = FAIL regardless
   of the rest.
2. **Median per-contrast variance ratio (est/true) in [0.33, 3.0] for BOTH
   contrasts** — the sd = 0.5 contrast is the one that failed unreplicated
   (0.24).
3. **Per-seed in-band** — >= 14/20 conv+PD seeds inside [0.33, 3.0] on each
   contrast.

Power note (stated up front): with a true collapse rate of 0.35 (the
unreplicated 7/20), P(<= 2/20) = 1.21%, so a pass is strong evidence of a
real change. The band does NOT strongly separate "rescued to ~0" from
"reduced to ~15-20%" (P(<= 2/20 | p = 0.20) = 20.6%), so a pass is worded as
*"collapse rate consistent with substantial rescue"*, never *"eliminated"*.

## Planted-zero sub-cell

`sd_true = c(0.8, 0)` (one contrast genuinely null), 10 seeds (621:630),
same replicated design, fit with the FULL-V `phylo_latent(d = 2)`:
median ratio of the null contrast's variance to the non-null contrast's
**< 0.35** (the model must not invent variance where there is none), and
rails (|rho| > 0.99) **<= 3/10**.

## Detector cross-check (free out-of-sample validation)

`.gllvmTMB_multinomial_degeneracy_row()` is evaluated on every fit of both
sub-cells and its verdict recorded per seed. Expectation stated in advance:
it fires on every collapse seed and on no in-band healthy seed. **A miss or
a spurious firing here is a calibration finding to be reported, not
suppressed** — this cell's fits were not part of the detector's calibration
set, so this is genuine out-of-sample evidence.

## Reporting

FAIL is recorded as *"replication does not rescue the diagonal-V mode at
this design"* and FAM-20D keeps its point-estimate-only honesty. Bands are
frozen as of this commit.

## AMENDMENT (2026-08-17, dated, below the frozen block — frozen block untouched)

The planted-zero sub-cell as pre-registered (`sd_true = c(0.8, 0)`) is
**mathematically unrunnable with this DGP**: V is then singular and the
generator's `chol(V)` fails ("the leading minor of order 2 is not positive").
Substituted `sd_true = c(0.8, 0.05)` — a genuinely tiny but positive-definite
variance, true ratio 0.0039 — and the gates are applied unchanged to it. The
substitution is recorded here rather than by editing the frozen block.

## VERDICT (2026-08-17; results committed alongside)

### Main cell — **FAIL**, and the failure is the finding

| Gate | Frozen | Measured | Result |
|---|---|---|---|
| 1 collapse rate | <= 2/20 | **7/20** | **FAIL** |
| 2 median ratios both contrasts in [0.33, 3.0] | — | 0.82, 0.54 | PASS |
| 3 per-seed in-band >= 14/20 each | — | 16/20, **12/20** | **FAIL** |

20/20 conv+PD. **Replication does NOT rescue the diagonal-V mode: the
collapse rate is 7/20, IDENTICAL to the unreplicated baseline of 7/20.**

This is a genuine mechanism split, and it sharpens what Arc-1 could claim.
Per-species replication (n_rep = 5) DID rescue the FULL-RANK cell (s1b:
rails 8/20 -> 4/20, median rho 0.680 in band). It does nothing for the
DIAGONAL mode, because the two cells fail differently: the full-rank cell's
pathology is *correlation railing*, which more information per species fixes;
the diagonal cell's pathology is *small-variance collapse*, which it does
not. FAM-20D's caveat is therefore CLOSED with a NEGATIVE result — the
rescue does not transfer — and the register must not extrapolate s1b to the
diagonal mode.

### Planted-near-zero sub-cell

- Variance ratio median **0.0175** against a true 0.0039 (frozen < 0.35) —
  **PASS**: the model does not invent variance where there is essentially
  none.
- Rails |rho| > 0.99: **10/10** (frozen <= 3/10) — **FAIL as scored**, but
  the honest reading is that the criterion was mis-specified for this
  design, not that the model misbehaved: when one contrast's variance is
  ~0 the correlation between contrasts is *undefined* (a ratio over ~zero),
  so railing is the expected numerical consequence. This reproduces Arc-1's
  null-DGP probe exactly (phylo_dep railed +-1 on zero-signal data with PD
  Hessians) and is the same evidence that grounds the `*_scalar` refusal.
  Reported as scored (FAIL) with the interpretation attached; the criterion
  is NOT retro-fitted.

### Detector cross-check (out-of-sample — these fits were never in the
### calibration set)

**7/7 collapse seeds flagged WARN; 0/13 non-collapsed fits flagged.** Perfect
sensitivity and perfect specificity on a cell the detector had never seen.
This is the strongest single piece of evidence that M1 generalises beyond
its calibration data.
