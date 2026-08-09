# Phase C independent compute-audit specification — 2026-08-08

## Purpose

This audit is a post-campaign structural gate for the prospective exact-geometry Phase C G1--G6 rerun under amendment 2. It is independent of `dev/isdm-phase-c-analyse-official.R`: the verifier neither sources that file nor calculates scientific trends. Its first responsibility is the outcome firewall. It refuses to open any campaign RDS unless the preflight, `pilot_v2`, and all six campaign compute receipts use `schema_version=phase_c_compute_v2` and clear source, instrument, stage/block, predecessor path/hash, output, configuration, session, optimiser-control, logical-row, model-fit-attempt, and resume-part checks.

The audit does not change the statistical method, thresholds, grids, campaign files, receipts, or raw results. It writes a new content-addressed receipt, block CSV, and Markdown report into a caller-supplied directory outside the repository and refuses to overwrite those outputs.

## Why the additional receipt is needed

The v2 runner receipts record the full seed inventory, canonical `stage`/`block`, source-instrument file paths and SHA-256 values, configuration provenance, explicit default or supplied optimiser control, session/package versions, logical-row counts, model-front-end fit attempts, structural counts, and exact predecessor/output/resume-part paths and hashes. `actual_optimizer_calls` deliberately records `NOT_INSTRUMENTED_MODEL_FRONTEND_ATTEMPTS_RECORDED_SEPARATELY`; the exact numeric execution count is `actual_model_fit_attempts`. The independent audit additionally reconstructs the complete expected keys and checks cross-block contracts, exact bias geometry, and part-to-final content identity without rewriting a receipt or rerunning a fit.

## Inputs and opening order

The caller supplies:

- exactly one result RDS and one compute receipt for each of G1 through G6;
- the corrected preflight receipt;
- the corrected pilot RDS and pilot-compute receipt;
- the frozen pilot-decision receipt; and
- an external output directory.

The verifier proceeds in this order:

1. Confirm every named input exists and no result or receipt path was assigned twice.
2. Parse receipts only. Require exact receipt type, `PASS`, `phase_c_compute_v2` for compute receipts, Lane C branch, a clean recorded source, a real Git source commit, and one six-file instrument ID matching both that commit and the current frozen files, including `dev/isdm-phase-c-amendment-2-2026-08-09.md`.
3. Require canonical `preflight/preflight`, `pilot_v2/G1`, and `campaign/G1` through `campaign/G6` stage/block pairs. Verify exact predecessor paths and hashes from preflight through pilot decision and into every campaign block; G6 must name the supplied G1 receipt exactly.
4. Verify result paths, SHA-256, byte counts, full seed lists, `phi_x`, `phi_bias`, frozen `beta0_shift`, S100 decision, arm manifest, explicit optimiser/session fields, logical and model-fit accounting, and every exact resume-part path/hash. Reproduce the raw preflight-contract, pilot, and G1--G6 configuration hashes from the authenticated source builders. Independently reconstructed contracts must be `identical()` to those builders; campaign grids also receive separate canonical value hashes.
5. Only after steps 1--4 pass, open the raw campaign result and part RDS files.
6. Verify `fit_attempted=TRUE` on every raw row, retaining model-level fit-error rows but rejecting DGP/pre-fit failures. Require theoretical bias rho, sharing, and variance to equal the configuration exactly. For `kappa>0`, require finite realised rho/sharing/variance means and maximum absolute errors no larger than `1e-9`; at the null, correlations and their errors must be `NA` while realised variance and its error are exactly zero. Then verify the exact preregistered keys, six arms per dataset, no duplicates, expected block counts, zero unlabelled non-finite completed results, one-null mapping, A6 collapse/A5 identity, isolated G6 `phi_bias`, and G5/A2 rank-`d` separation.
7. Verify the union and contents of the immutable part files reproduce the final block RDS exactly.
8. Write the new audit artifacts without overwriting any existing audit output.

## Frozen campaign contract

The independent reconstruction enforces:

| Block | Seeds | Expected result rows | Structural axis |
|---|---:|---:|---|
| G1 | 100 | 15,000 | full `kappa × rho × omega` grid plus one null per seed |
| G2 | 50 | 1,200 | `n ∈ {100,1600}` with null and REF |
| G3 | 50 | 1,200 | `T_sp ∈ {6,12}` with null and REF |
| G4 | 50 | 1,200 | `d_fit ∈ {1,3}` with null and REF |
| G5 | 50 | 600 | `k=1` with null and REF |
| G6 | 50 | 600 | `phi_bias ∈ {0,0.4}`, no duplicate null; use G1 null |

All blocks use the six arms A1--A6, `stage=campaign`, `phi_x=0.15`, the pilot-frozen zero `beta0_shift`, and the immutable instrument ID. The audit counts fit errors but never removes them or conditions structural acceptance on optimiser or Hessian flags.

## Invocation

```sh
Rscript --vanilla dev/isdm-phase-c-verify-campaign.R \
  --result G1=/absolute/path/g1-results.rds \
  --result G2=/absolute/path/g2-results.rds \
  --result G3=/absolute/path/g3-results.rds \
  --result G4=/absolute/path/g4-results.rds \
  --result G5=/absolute/path/g5-results.rds \
  --result G6=/absolute/path/g6-results.rds \
  --receipt G1=/absolute/path/g1-compute.receipt \
  --receipt G2=/absolute/path/g2-compute.receipt \
  --receipt G3=/absolute/path/g3-compute.receipt \
  --receipt G4=/absolute/path/g4-compute.receipt \
  --receipt G5=/absolute/path/g5-compute.receipt \
  --receipt G6=/absolute/path/g6-compute.receipt \
  --preflight-receipt=/absolute/path/preflight.receipt \
  --pilot=/absolute/path/pilot-v2-results.rds \
  --pilot-compute-receipt=/absolute/path/pilot-v2-compute.receipt \
  --pilot-decision-receipt=/absolute/path/pilot-decision.receipt \
  --out-dir=/absolute/external/path/phase-c-compute-audit
```

Run the pure structural self-test without campaign artifacts:

```sh
Rscript --vanilla dev/isdm-phase-c-verify-campaign.R --self-test
```

The self-test creates a complete synthetic 19,800-row campaign under `/private/tmp`, includes one retained model error, and verifies the PASS path, immutable-output refusal, and six-receipt opening gate. Negative fixtures tamper schema, stage, block, raw/canonical configuration identity, source authentication, positive-`kappa` geometry, theoretical geometry, null zero/`NA` contracts, and `fit_attempted`. It neither connects to Totoro nor reads live Phase C artifacts or runs a fit.

## Outputs

- `phase-c-compute-audit.receipt`: immutable key-value receipt with source and instrument provenance, host, R/session information, timestamps, predecessor hashes, raw-result and receipt hashes, row/part/error totals, and hashes of the two companion audit files.
- `phase-c-compute-audit-blocks.csv`: one structural record per block, including row counts, result/receipt/config hashes, part counts and bytes, fit errors, completed rows, unique-key counts, and contract verdicts.
- `phase-c-compute-audit.md`: human-readable PASS summary, supplied metadata, and explicit limits.

Large raw RDS files and part files remain external. No campaign artifact is copied into Git or GitHub Actions.

## Configuration-hash amendment found before outcomes opened

The first live audit attempt stopped before any campaign RDS was opened because a logically
identical independently reconstructed G1 table did not reproduce the receipt's raw RDS hash.
On Totoro, the two tables were `identical()` value-for-value, attribute-for-attribute, and
class-for-class, but their serialized bytes differed because their construction histories used
different internal R representations. A `saveRDS()` byte hash is therefore a provenance hash for
the exact source-built object, not a canonical hash of a logical table.

The corrected audit authenticates all predecessor and G1--G6 receipt source commits plus the
current six-file instrument identity before it evaluates any campaign source. It then keeps both
configuration checks without weakening either:

- the receipt's raw configuration hash must reproduce from the immutable campaign source builder,
  loaded with nested `source()` calls redirected into a closed evaluation environment;
- the independently reconstructed table must be exactly `identical()` to that source table; and
- a length-prefixed UTF-8/LF binary encoding of names, classes, missingness, and 17-digit values is SHA-256 hashed and recorded
  separately as `independent_config_sha256`.

The synthetic gate asserts that source loading creates no global bindings, tampers a raw receipt
hash, perturbs an independently reconstructed grid, mutates both a value and a column class, and
checks that the canonical hashes emitted to the audit CSV and receipt equal the independently
calculated hashes. An injected-loader test also supplies an unauthenticated campaign receipt and
proves the source builder is never invoked.

This amendment was made after all compute completed but before any scientific campaign outcome
was opened. It changes no configuration, fit, threshold, row, or result artifact.

## Limits

This verifier establishes structural completeness and content-addressed provenance for the supplied artifacts. It does not validate the biological interpretation, inspect treatment trends, estimate paired MCSE, apply C1--C3 or R1--R5, judge optimiser adequacy, or replace the independent Curie/Fisher/Noether completion panel. Exact scheduled rows and part manifests can show that the audited artifacts contain no unexplained missing or duplicated configuration; they cannot prove what an unrecorded alternative run would have produced or preserve external files after their hashes were recorded.
