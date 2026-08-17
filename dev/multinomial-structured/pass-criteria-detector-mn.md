# Detector S3 calibration — multinomial K-1 contrast degeneracy row (pre-registered)

**STATUS: DRAFT, frozen at commit time.** This file is written and committed
BEFORE any refit runs or results exist, so the sensitivity/specificity
targets and the labeled-truth definitions cannot drift to match whatever the
measurement turns out to show. Do not weaken, widen, or add cells to the
frozen block below after seeing results; a change after that point needs a
fresh dated amendment note, not a silent edit.

This calibrates `.gllvmTMB_multinomial_degeneracy_row()`
(`R/diagnose.R`, component `multinomial_contrast_degeneracy`, landed
`8f233231`), which currently ships its M2/M3 thresholds "provisional pending
the S3 calibration campaign" in the roxygen. **This IS that campaign.**

## Why refit, not reuse the committed summary CSVs

The Arc-1 campaign CSVs in `results/` (`s2-summary-*.csv`,
`s2-indep-corrected-summary.csv`, `s3-summary-*.csv`, `s4-summary-*.csv`,
`s1b-replication-summary.csv`, `probe-scalar-null.csv`) record hand-computed
recovery statistics (`V_hat`, `rho_hat`, `range_hat`, ...) extracted via
`extract_Sigma()`/`fit$report` directly — they do NOT record what
`check_gllvmTMB()` itself says, because the detector row did not exist yet
when most of those campaigns ran. Calibrating a detector against its own
target's summary statistics, computed by different code than the detector
uses, is not evidence about the detector. This campaign refits every labeled
cell with the IDENTICAL seeds and DGP calls already used to establish the
labels, then calls `check_gllvmTMB()` on the actual fit object and parses the
`multinomial_contrast_degeneracy` row's `status`/`message` text for the
`arms:` list (`M1`/`M2`/`M3`, comma-separated when `status == "WARN"`).

## Frozen targets

- **M1 (`contrast_variance_collapse`) sensitivity: flags >= 6/7** labeled
  variance-collapse seeds.
- **M2 (`contrast_rail`) sensitivity: flags >= 7/8** labeled rail seeds.
- **M3 (`spatial_range_collapse`) sensitivity: flags 3/3** labeled PD
  range-collapse seeds.
- **Specificity: ZERO false positives** (`multinomial_contrast_degeneracy`
  status `WARN` with the relevant arm firing) across the three healthy cells
  below (N = 60 fits pooled).

### Amendments (from plan review, folded into the frozen block before any run)

1. A healthy **d = 1** `phylo_latent(species, d = 1, tree = tree)` cell MUST
   be included and MUST NOT fire M2. At `d = 1` every healthy fit reaches
   `rho = +-1` exactly by row proportionality (a single shared loading
   column) — this is the out-of-sample proof that the roxygen's stated
   `d >= 2` precondition (the "rank-1 tautology suppression") actually
   holds in a real fit, not just in the hand-built `d = 1`-shaped test
   fixture already in `tests/testthat/test-sanity-categorical.R`.
2. The **null-DGP** (`V_true = 0`) cell is counted SEPARATELY from the
   specificity tally. `phylo_indep()` on `V_true = 0` data SHOULD collapse to
   near-zero fitted variance — M1 firing there is the detector working as
   designed (a true positive against a designed-degenerate truth), not a
   false positive. It is reported as its own tally, not folded into the N =
   60 healthy-cell specificity bound.
3. **Rule-of-three precision caveat.** Zero observed false positives on N
   healthy fits does not mean the detector's true false-positive rate is
   zero — it bounds it at roughly `3/N` (95% one-sided upper confidence
   bound, the standard rule-of-three approximation for a Binomial(N, p) with
   0 successes). At N = 60 that is **~5%**. Report this bound alongside any
   "zero false positives" claim rather than stating zero unqualified.

## Cells (seeds and labeled truth, identical to the already-agreed labels)

All cells reuse the committed DGPs (`dgp-multinomial-structured.R`,
`dgp-multinomial-replicated.R`) and the exact seeds/design already used to
establish the Arc-1 labels in `pass-criteria-s2.md`/`pass-criteria-s3.md`.
"Labeled truth" below is the SAME criterion those files already froze, not a
new one invented for this campaign.

### DEGENERATE (positive-label) cells

| cell | keyword | DGP | seeds | n | labeled-degenerate criterion | labeled-degenerate seeds (n=..) |
|---|---|---|---|---|---|---|
| `deg_m1_phylo_indep` | `phylo_indep(0 + trait \| species)` | `dgp_multinomial_structured(n_sp=800, rho_true=0, sd_true=c(0.8,0.5))` | 201:220 | 20 | either fitted contrast variance `< 1e-6` (`pass-criteria-s2.md`'s own collapse definition) | {202,203,205,206,207,208,209} (n=7) |
| `deg_m2_phylo_dep` | `phylo_dep(0 + trait \| species)` | `dgp_multinomial_structured(n_sp=800)` (default `rho_true=0.6, sd_true=c(0.8,0.8)`) | 201:220 | 20 | `\|rho_hat\| >= 0.99` (`pass-criteria-s2.md`'s rail definition) | {202,203,205,206,207,217,218,219} (n=8) |
| `deg_m3_spatial_indep` | `spatial_indep(0 + trait \| coords)` | `dgp_multinomial_spatial(n_site=300)` (copied from `campaign-s3-spatial.R`, same seed/design) | 301:320 | 20 | PD Hessian AND `range_hat < 0.02` (`pass-criteria-s3.md`'s rail definition, restricted to the PD subset per this task's brief) | {303,304,312} (n=3, all PD) |

Ground truth for each of the three tables above is recomputed independently
from the committed summary CSVs
(`s2-indep-corrected-summary.csv`/`s2-summary-*.csv`/`s3-summary-*.csv`)
using the exact pre-registered definitions, confirming the counts above
BEFORE refitting — the refit's job is to see whether the DETECTOR agrees with
these already-frozen labels, not to relabel.

### HEALTHY (negative-label) cells — N = 60 pooled for the specificity bound

| cell | keyword | DGP | seeds | n |
|---|---|---|---|---|
| `healthy_s4_re_int` | `(1 \| group)` | `dgp_multinomial_grouped(G=60, n_per_g=15, sigma_re=0.6)` | 201:220 | 20 |
| `healthy_s1b_phylo_latent_rep` | `phylo_latent(species, d=2, tree=tree)` | `dgp_multinomial_replicated(n_sp=300, n_rep=5)` (default `rho_true=0.6, sd_true=c(0.8,0.8)`) | 301:320 | 20 |
| `healthy_d1_phylo_latent` | `phylo_latent(species, d=1, tree=tree)` (NEW) | `dgp_multinomial_structured(n_sp=800)` (default `rho_true=0.6, sd_true=c(0.8,0.8)`) | 401:420 | 20 |

### NULL-DGP (counted separately, not part of the N=60 bound)

| cell | keyword | DGP | seeds | n |
|---|---|---|---|---|
| `null_phylo_indep` | `phylo_indep(0 + trait \| species)` | `dgp_multinomial_structured(n_sp=200, rho_true=0, sd_true=c(0,0))` | 601:608 | 8 |

## D-139

State a time guesstimate before running. Prior measured rates on this same
worktree's DGPs: `phylo_dep`/`phylo_indep` at `n_sp=800` ~10 sec/fit
(`s2-summary`'s `elapsed_sec` column); `spatial_indep` at `n_site=300` ~1.5-2
sec/fit (`s3-summary`); `re_int` (S4) ~0.6 sec/fit; replicated `n_sp=300`
phylo_latent ~2 sec/fit (README). Naive linear projection for 128 total fits
at a blended ~8 sec/fit average is ~17 min sequential, well under 30 min even
before parallelising — run a 2-4 fit timing pilot first per D-139, record
elapsed time and the projection, and only proceed to the full 128-fit run if
that projection stays under 30 min (it is expected to, by a wide margin).

## Verdict rule

Apply the frozen targets above exactly. A missed sensitivity target is
reported as a miss, not silently patched by loosening the threshold. A
specificity violation (any false positive on the N=60 healthy pool) is a
blocking finding, reported prominently, regardless of how the sensitivity
numbers land. Any threshold change is proposed with a measured
sensitivity/specificity trade-off table and left flagged for the maintainer
to decide — never applied unilaterally to make a target pass.
