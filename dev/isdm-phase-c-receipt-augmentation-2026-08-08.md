# Phase C retrospective structural receipt augmentation — 2026-08-08

## Purpose and status

`dev/isdm-phase-c-augment-receipts.R` creates one new, append-only structural
augmentation receipt for one block, G1 through G6, of the original Phase C
campaign that amendment 2 now supersedes for exact-geometry and global-attribution claims.
It does not edit or replace the original compute receipt, raw RDS, independent
compute-audit receipt, or audit CSV. The output identifies itself as
`receipt_class=retrospective_structural_augmentation` and uses
`schema_version=phase_c_structural_augmentation_v1`.

That schema label is prospective for the augmentation format only. The
augmentation is created after campaign outcomes exist; it is not represented as
having existed before compute or before outcomes. It does not retroactively
strengthen or replace the original outcome firewall, and it cannot repair the
original run's non-exact realised bias geometry.

## Authenticated evidence and opening order

For a requested block, the script authenticates these inputs before opening the
raw RDS:

1. the original `PASS` G1--G6 compute receipt, including its raw output path,
   byte count, SHA-256, recorded source commit, Lane C branch, clean source
   status, and five-file instrument ID;
2. the independent `PASS` compute-audit receipt, including its source commit,
   instrument ID, six-block result/receipt manifests, and audit-CSV SHA-256; and
3. the independent audit CSV, including the named block's raw, receipt,
   configuration, canonical configuration, row, failure, uniqueness, six-arm,
   and null-contract fields.

The recorded instrument ID is reconstructed from the five Git blobs at the
recorded commit. It is deliberately not compared with the current working-tree
bytes: later analysis-only edits must not invalidate a historical
commit-addressed receipt. The original receipt and independent audit must still
name the same campaign source commit and instrument.

Only after those checks pass does the script call `readRDS()`. It then reads
configuration keys, arms, structural status labels, error labels, and whether
the contract-required fields are finite. It does not calculate treatment
contrasts, trends, effect summaries, thresholds, or scientific verdicts.

G6 contains no duplicated null rows by design. A G6 augmentation therefore
requires the authenticated G1 raw RDS and original G1 receipt. The script checks
their hashes against both audit manifests and reconstructs every G6-to-G1 null
pair from the frozen null key. It never relies only on the audit's Boolean null
verdict.

## Invocation

For G1--G5:

```sh
Rscript --vanilla dev/isdm-phase-c-augment-receipts.R \
  --block=G1 \
  --result=/absolute/path/g1.rds \
  --receipt=/absolute/path/g1-compute.receipt \
  --audit-receipt=/absolute/path/phase-c-compute-audit.receipt \
  --audit-csv=/absolute/path/phase-c-compute-audit-blocks.csv \
  --output=/absolute/new/path/g1-structural-augmentation.receipt
```

For G6, add both G1 inputs:

```sh
Rscript --vanilla dev/isdm-phase-c-augment-receipts.R \
  --block=G6 \
  --result=/absolute/path/g6.rds \
  --receipt=/absolute/path/g6-compute.receipt \
  --g1-result=/absolute/path/g1.rds \
  --g1-receipt=/absolute/path/g1-compute.receipt \
  --audit-receipt=/absolute/path/phase-c-compute-audit.receipt \
  --audit-csv=/absolute/path/phase-c-compute-audit-blocks.csv \
  --output=/absolute/new/path/g6-structural-augmentation.receipt
```

The output is a key-value receipt with exactly one field per line. The script
refuses an existing output path and refuses to use an input path as its output.
It embeds a SHA-256 of the canonical payload preceding the payload-hash field,
records the exact output path, and prints the final receipt-file SHA-256 after
writing. A final file hash cannot truthfully be embedded in the bytes it hashes;
the printed final hash is therefore the exact external content address, while
`augmentation_payload_sha256` is the embedded non-self-referential payload
address.

## Receipt contents

Each successful augmentation records:

- the retrospective receipt class, augmentation schema and temporality;
- the exact augmentation script path and SHA-256 plus its checkout HEAD;
- canonical `stage=campaign` and `block=Gx`;
- the full observed seed list, six arms, `phi_x`, `phi_bias`, and frozen zero
  `beta0_shift`;
- the source-builder configuration SHA-256, independent canonical
  configuration SHA-256, and raw RDS SHA-256;
- exact paths and SHA-256 values for the raw RDS, original compute receipt,
  independent audit receipt, and audit CSV;
- source SHA, branch, and instrument ID;
- expected and actual logical rows, expected optimizer calls, and actual
  logical fit attempts;
- full-key uniqueness, null-key uniqueness, exact null-pair candidate/matched
  counts, mismatches, and A6 null-collapse count;
- fit-error, exclusion, and unexplained nonfinite counts; and
- exact original-output and augmentation-output paths, the original output
  hash, the embedded augmentation payload hash, and the final augmentation hash
  printed to standard output.

For G6, the receipt additionally records the authenticated G1 raw and receipt
paths/hashes and the external G1 A6-null collapse count.

## Refusal conditions

The augmenter fails without writing an output if it encounters a noncanonical
block or raw stage, a source/branch/instrument mismatch, a raw/receipt/audit hash
mismatch, an audit receipt or CSV that is not structurally `PASS`, a duplicate
full or null key, a missing or excess scheduled row, incomplete six-arm
coverage, an exact-null mismatch, an invalid A6 collapse label, a receipt/count
mismatch, an unexplained nonfinite completed row, a malformed input, an input
alias, or an existing output path.

## Exact limits

This is structural and provenance evidence only. A logical result row shows one
retained logical fit attempt, but it cannot establish whether a low-level
optimizer was entered before every retained error. Therefore the receipt records
`actual_optimizer_calls=NOT_RECONSTRUCTABLE`; it does not infer that value from
the result-row count. It likewise records that optimizer control beyond the
source or command default is `NOT_RECONSTRUCTABLE`, and that an exact historical
package/session snapshot is `NOT_RECONSTRUCTABLE` if the original evidence did
not retain one.

The augmenter does not judge optimizer adequacy, Hessian adequacy, biological
interpretation, treatment effects, Monte Carlo uncertainty, C1--C3, R1--R5, or
any public capability claim. Hashes authenticate the supplied bytes at the time
of augmentation; they do not preserve external artifacts. The augmentation does
not replace the original compute receipt, predecessor chain, independent audit,
or outcome firewall.

## Synthetic verification

Run:

```sh
Rscript --vanilla dev/isdm-phase-c-augment-receipts.R --self-test
```

The self-test creates canonical synthetic G1--G6 result/receipt fixtures under
`/private/tmp`, including one retained G2 fit error, and emits all six
augmentation receipts. It exercises G6-to-G1 null reconstruction and negative
checks for raw tampering, output overwrite, original-receipt/audit mismatch,
audit tampering, duplicate keys, missing rows, unexplained nonfinite rows, and a
noncanonical stage. It removes its temporary fixture tree after completion and
does not read live campaign artifacts.

## Local verification receipt

On 2026-08-08 the following dev-only checks passed in the Lane C worktree:

```text
Rscript --vanilla -e 'invisible(parse(file="dev/isdm-phase-c-augment-receipts.R")); cat("PARSE PASS\n")'
  PARSE PASS

Rscript --vanilla dev/isdm-phase-c-augment-receipts.R --help
  PASS; usage rendered and G6's two additional inputs were listed

Rscript --vanilla dev/isdm-phase-c-augment-receipts.R --self-test
  PASS; G1, G2, G3, G4, G5, G6 positive receipts plus all named negative checks

git diff --no-index --check /dev/null dev/isdm-phase-c-augment-receipts.R
git diff --no-index --check /dev/null dev/isdm-phase-c-receipt-augmentation-2026-08-08.md
  PASS; no whitespace-error diagnostics (status 1 is expected because each new
  file differs from /dev/null)
```

No live campaign RDS, receipt, audit artifact, treatment value, or scientific
summary was opened. No package fit, simulation campaign, `R CMD check`, commit,
push, or staging operation was performed for this dev-only augmentation slice.
