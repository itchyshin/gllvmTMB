# Lane B B2 resumable ordinary-GLLVM harness

This directory implements the frozen complete-Bernoulli B2 surfaces: 96
ordinary cells, the mandatory 24-cell trait-order audit, and 72 spatial cells.
Together they contain 130,800 generated datasets, 561,600 primary arm fits,
and 8,472 shards (2,880 ordinary, 192 permutation, 5,400 spatial). Alternate
starts are retained child attempts in addition to those primary counts. Heavy
outputs must use an absolute campaign root outside the git checkout.

The scripts split pure logic from fitting. `prepare` freezes manifests, seed
registries, thresholds, and a queue without loading the compiled engine.
`run` performs a four-arm capability preflight before creating a shard lock.
Because the public MSPL estimator may not yet exist, the default is a loud,
pre-fit failure. The MSPL-plus-ridge arm is implemented locally by the harness:
it refreshes the TMB report at the private ridge optimum and does not add a
package API. `--allow-missing-mspl` is
restricted to diagnostic smoke work and retains missing-capability failures as
attempt rows. It cannot produce promotion evidence.

Local smoke preparation and capability check:

```sh
SMOKE_ROOT=/private/tmp/gllvmtmb-lane-b-b2-smoke
Rscript --vanilla inst/sim/lane-b/0_prepare_lane_b_b2.R \
  --root "$SMOKE_ROOT" --smoke
Rscript --vanilla inst/sim/lane-b/1_run_lane_b_b2_shard.R \
  --root "$SMOKE_ROOT" --shard-id ordinary-O007-0001
```

Smoke preparation freezes five datasets: ordinary O007, permutation P01, and
one mixed-extreme logit cell for each spatial structure. Run their five shard
IDs from `queue/lane-b-b2-queue.csv`. Until MSPL lands, add
`--allow-missing-mspl` only to exercise failure retention.
Aggregate incomplete smoke output with `--provisional`; it is labelled
`PROVISIONAL-NOT-EVIDENCE`.

Totoro pilot then full queue (after syncing the exact checkout and after the
four-arm preflight passes):

```sh
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
export GLLVMTMB_LANE_B_CAMPAIGN=/path/outside/repo/lane-b-b2
Rscript --vanilla inst/sim/lane-b/0_prepare_lane_b_b2.R \
  --root "$GLLVMTMB_LANE_B_CAMPAIGN"
Rscript --vanilla inst/sim/lane-b/1_run_lane_b_b2_shard.R \
  --root "$GLLVMTMB_LANE_B_CAMPAIGN" --shard-id ordinary-O001-0001
tail -n +2 "$GLLVMTMB_LANE_B_CAMPAIGN/queue/lane-b-b2-queue.csv" | \
  cut -d, -f1 | tr -d '"' | xargs -P120 -I{} \
  Rscript --vanilla inst/sim/lane-b/1_run_lane_b_b2_shard.R \
    --root "$GLLVMTMB_LANE_B_CAMPAIGN" --shard-id '{}'
Rscript --vanilla inst/sim/lane-b/2_summarise_lane_b_b2.R \
  --root "$GLLVMTMB_LANE_B_CAMPAIGN"
```

The spatial generator jointly simulates training and withheld-block fields on
the unit square with a nu=1 Matérn covariance; all traits for a unit stay
together. The permutation audit refits original, reverse, and cell-seeded
random orders and stores estimates after undoing each permutation.

Workers use atomic partial-file renames plus SHA-256 receipts. `resume` reports
pending shards and never deletes running locks automatically. Aggregation
refuses an incomplete queue unless `--provisional` is explicit and verifies
every raw shard against its frozen shard ID, completion status, row count, and
SHA-256 receipt before reading it as evidence.

## Exact B0 and quasi-complete amendments

The immutable fit campaign did not have `detectseparation` in its private R
library, so its stored B0 hash is not evidence. Fits are unaffected. The
separate `3_run_lane_b_b0_shard.R` supplement regenerates only the frozen
ordinary training responses and records exact trait-wise certificates under
`b0-exact-v3/`. `4_adjudicate_lane_b_b2.R` refuses incomplete B0 or fit queues,
joins by the frozen `(cell_id, replicate_id)` key, and applies promotion gates
within realized `OVERLAP`, `COMPLETE`, and `QUASI_COMPLETE` strata. Risk and
prediction comparisons use only replicate IDs usable in both arms; usability
differences retain every paired attempt. `CONSTANT` and `NOT_CHECKED` remain
diagnostic and cannot promote a claim.

The B0 completion receipt is authenticated against the immutable v3 launch
source hashes recorded by the adjudicator, not against the current shipping
harness files. This keeps the 2,880-shard evidence verifiable after later
adjudication-only repairs while still rejecting a changed launch receipt. The
current source receipt helper remains available for creating a future frozen
campaign; it is not used to rewrite v3 history.

The prevalence campaign produced too few quasi-complete datasets for the
predeclared Wilson gate. The frozen targeted supplement in
`lane-b-quasi-supplement.R` therefore constructs an exact full-rank
quasi-complete fixed design for trait 1 in 12 cells: three links, two latent
ranks, and two loading strengths, with 500 replicates per cell. This is a
conditional stationarity experiment, not a recovery experiment. Its trait-1
coefficient error and held-out log loss are excluded from promotion.

```sh
Rscript --vanilla inst/sim/lane-b/5_run_lane_b_quasi.R \
  prepare --root /path/outside/repo/lane-b-quasi
Rscript --vanilla inst/sim/lane-b/5_run_lane_b_quasi.R \
  run --root /path/outside/repo/lane-b-quasi --shard-id quasi-Q001-0001
Rscript --vanilla inst/sim/lane-b/5_run_lane_b_quasi.R \
  aggregate --root /path/outside/repo/lane-b-quasi
```

The strict combined adjudicator requires all balanced ordinary cells in the
realized overlap stratum, a complete-separation core with at least 300 realized
datasets at both loading strengths for every link by rank family, and both
targeted quasi-complete loading cells for every link by rank family. The
300-dataset availability threshold was frozen after exact B0 classification
and before estimator outcomes were inspected. It follows the approved
300-replicate core design and prevents tiny realized strata from earning a
family claim.

Spatial promotion is also stricter than the immutable v1 recovery table. The
post-launch adjudicator requires every usable primary MSPL point to have a
healthy alternate fit, agreement in penalised objective and marginal
covariance at the frozen tolerances, and no numerical or spatial boundary
contact. It then forms nine independent link-by-structure gates. Each gate
requires all eight cells spanning both sample sizes, balanced and mixed-tail
prevalence, and both range regimes. This extra layer can withhold a v1 pass; it
cannot reverse a v1 failure.

The mandatory trait-order audit is also promotion-gating. Its ledger must be
exactly 24 frozen cells by 200 replicates by three trait orders by four arms by
two starts. Every original-versus-reverse and original-versus-random comparison
must pass before either the ordinary, spatial, or overall headline can pass;
an incomplete or failed permutation family therefore withholds promotion.
The immutable spatial v1 recovery table is recomputed from the authenticated
raw attempts and must exactly match the stored table before the stricter
spatial gates are applied; a modified stored pass cannot revive a v1 failure.

Covariance agreement is the retained scientific-order relative Frobenius gap
`||Sigma_alt - Sigma_primary||_F / max(1, ||Sigma_primary||_F) <= 1e-4`.
The immutable ledger's elementwise gap remains diagnostic only.
