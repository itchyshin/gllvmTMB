# Phase C prospective amendment 3: portable configuration identity

Date: 2026-08-09  
Lane: `claude/experiment-integrated-sdm`  
Issue: #943

## Why this amendment exists

The exact-geometry preflight and corrected pilot at source `ce6c0671` both
completed their structural contracts. The sealed pilot-decision program then
stopped before reading any permitted pilot statistic because the preflight
configuration hash did not reproduce on Totoro. The receipt had identified the
configuration by hashing `saveRDS()` bytes produced on macOS R 4.6, whereas the
decision ran under Totoro R 4.5.3. Those bytes can differ for the same R object.

The `ce6c0671` pilot therefore remains sealed and scientifically
uninterpreted. It is retained as provenance, but it is superseded for the seed,
prevalence, and campaign decisions. No result from it may enter Phase C tables
or claims.

This amendment is frozen before opening that pilot and before launching its
replacement. It changes receipt identity only. It does not change the DGP,
grid, seeds, arms, estimands, thresholds, pairing, pilot decision rule, or
campaign analysis.

## Corrected identity contract

`config_sha256` and `input_config_sha256` now hash a canonical representation
of the configuration object. The representation is versioned with the prefix
`phase-c-canonical-object-v1:` and recursively records object type, class,
names and order, row names, dimensions, missingness, and values. Text is UTF-8
and length-prefixed; finite doubles use hexadecimal `%a` notation; `NA`,
`NaN`, `+Inf`, and `-Inf` are distinct. Unsupported classes or attributes fail
closed. The payload is written as binary bytes before SHA-256 is calculated.

`config_rds_sha256` and `input_config_rds_sha256` separately retain the raw
`saveRDS(version = 3)` hash produced by the compute host. They are provenance,
not a cross-host identity gate. A downstream verifier requires them to be
valid SHA-256 values and requires every resume part to agree with its compute
receipt, but it must not reconstruct and compare them on a different R build.

Every resumable part stores both hashes. Canonical identity gates source-built
configuration equality; raw-RDS identity detects incompatible parts within one
compute run.

## New start gate

Before rerunning the corrected chain, the source-built preflight and pilot
configurations must produce identical canonical SHA-256 values on macOS and
Totoro. Mutation tests must show that value, type, name, and order changes alter
the canonical hash. The verifier must reject malformed raw hashes and parts
whose canonical or raw hash differs from their receipt.

After that gate passes, preflight, pilot, decision, and G1--G6 use a new clean
source commit and new immutable artifact paths. The `ce6c0671` artifacts are
never overwritten or reinterpreted.
