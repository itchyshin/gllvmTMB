# Phase C independent compute-audit specification — 2026-08-08

## Purpose

This audit is a post-campaign structural gate for the corrected Phase C G1--G6 run. It is independent of `dev/isdm-phase-c-analyse-official.R`: the verifier neither sources that file nor calculates scientific trends. Its first responsibility is the outcome firewall. It refuses to open any campaign RDS unless all six named result files and all six `PASS` compute receipts exist and the receipts clear provenance, predecessor, output-hash, byte-count, configuration-hash, and part-hash checks.

The audit does not change the statistical method, thresholds, grids, campaign files, receipts, or raw results. It writes a new content-addressed receipt, block CSV, and Markdown report into a caller-supplied directory outside the repository and refuses to overwrite those outputs.

## Why the additional receipt is needed

The current compute receipts are valid runner receipts, but they do not themselves enumerate every preregistered treatment axis or certify every cross-block contract. In particular, a per-block receipt does not contain the complete expected full-key set, exact six-arm membership per dataset, the combined one-null pairing count, exact A5/A6-null metric identity, G5/A2 rank-`d` isolation, or part-to-final content identity. This audit supplies those missing structural facts prospectively, after compute and before scientific analysis, without rewriting a receipt or rerunning a fit.

## Inputs and opening order

The caller supplies:

- exactly one result RDS and one compute receipt for each of G1 through G6;
- the corrected preflight receipt;
- the corrected pilot RDS and pilot-compute receipt;
- the frozen pilot-decision receipt; and
- an external output directory.

The verifier proceeds in this order:

1. Confirm every named input exists and no result or receipt path was assigned twice.
2. Parse receipts only. Require exact receipt type, `PASS`, Lane C branch, a clean recorded source, a real Git source commit, and one instrument ID matching both that commit and the current frozen instrument files.
3. Verify predecessor hashes from preflight through pilot decision and from that decision into every campaign block. Require G6 to name the exact G1 receipt hash.
4. Verify each result path, SHA-256, byte count, expected/actual rows, independently reconstructed configuration hash, seed manifest, `phi_x`, `phi_bias`, frozen `beta0_shift`, S100 decision, arm manifest, part directory, part count, and every part hash.
5. Only after steps 1--4 pass, open the raw campaign result and part RDS files.
6. Verify the exact preregistered full keys, six arms per dataset, no duplicates, expected block counts, retained fit-error rows, zero unlabelled non-finite completed results, exact one-null mapping on `stage + seed + arm + n + T_sp + d_fit + k`, A6-null collapse and A5/A6 completed-field identity, G6's isolated `phi_bias` axis with `phi_x=0.15`, and G5/A2 rank-`d` separation from total-`Sigma` results.
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

The self-test creates a complete synthetic 19,800-row campaign under `/private/tmp`, includes one retained model error, verifies the PASS path, verifies immutable-output refusal, and verifies the six-receipt opening gate. It neither connects to Totoro nor reads live Phase C artifacts.

## Outputs

- `phase-c-compute-audit.receipt`: immutable key-value receipt with source and instrument provenance, host, R/session information, timestamps, predecessor hashes, raw-result and receipt hashes, row/part/error totals, and hashes of the two companion audit files.
- `phase-c-compute-audit-blocks.csv`: one structural record per block, including row counts, result/receipt/config hashes, part counts and bytes, fit errors, completed rows, unique-key counts, and contract verdicts.
- `phase-c-compute-audit.md`: human-readable PASS summary, supplied metadata, and explicit limits.

Large raw RDS files and part files remain external. No campaign artifact is copied into Git or GitHub Actions.

## Limits

This verifier establishes structural completeness and content-addressed provenance for the supplied artifacts. It does not validate the biological interpretation, inspect treatment trends, estimate paired MCSE, apply C1--C3 or R1--R5, judge optimiser adequacy, or replace the independent Curie/Fisher/Noether completion panel. Exact scheduled rows and part manifests can show that the audited artifacts contain no unexplained missing or duplicated configuration; they cannot prove what an unrecorded alternative run would have produced or preserve external files after their hashes were recorded.
