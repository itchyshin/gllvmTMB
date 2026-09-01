# Spatial rho recovery: retained Totoro study

## Scope

This is point-recovery evidence for the frozen, complete, replicated Gaussian
trait-intercept regimes only. It does not support rho intervals, unseen-location
recovery, non-Gaussian recovery, multiple simultaneous sources, or coefficient
rho. Fixed-at-generating-rho fits are diagnostic benchmarks, not estimators.

## Exact evidence

- Frozen fixture manifest SHA-256:
  `692380327512a8ede39849eab813319469948d96c477f86b190e4f85d90181c3`
- Pilot bundle: `78e17ceb0c4589fff1c7983949a9f7cdfaa80e4e4699d0ab75870764d15d3383`
- Post-checkpoint continuation bundle:
  `688e8533931bc21032d6c7b5ab797017a4076eaf14d7915a5a34a0d72d976ac3`
- Compact completed-campaign archive SHA-256:
  `f249e4c8e8de5bc089584eea03fb73b343df60187afe4f855daf50e4a82518f7`
- Totoro archive:
  `/home/snakagaw/spatial-rho-full-a32726b19-compact.tar.gz`

The continuation bundle changes only recovery-runner plumbing after the measured
checkpoint. `full-evidence/pilot-transfer.json` binds the exact pilot bundle,
continuation bundle, shared frozen fixture, original pilot receipts, and the
explicit old-to-new path mapping created when immutable pilot rows were copied
to the isolated continuation root. The package was reinstalled in the
continuation root and every non-pilot job was run once.

## Accounting and execution health

| Quantity | Result |
| --- | ---: |
| Retained attempt budget | 1,600 |
| Terminal returned fits | 1,600 |
| Strict numerical successes | 1,494 (93.4%) |
| Numerical failures | 106 (6.6%) |
| Timeouts/process failures/missing results/extra optimizer entries | 0 / 0 / 0 / 0 |
| Remainder wall time | 678.7 s |
| Total fit work time | 8,033.5 s |
| Peak worker memory | 429,316 KiB (0.409 GiB) |

The 1,600-attempt count is the campaign denominator. Per-cell failure
frequencies use their own all-attempt denominators. Point-recovery metrics and
boundary frequencies are conditional on the strict numerical-success rule. The
all-attempt table, paired diagnostics, and per-cell metrics are in
`full-evidence/`.

## Predeclared mechanical classification

No estimated-rho cell passes every bounded recovery requirement. The frozen
rules and independent Fisher/Rose reconciliation classify 14 cells as `partial`
and two cells as `blocked`:

| Regime | Mode | rho | Mechanical result | Reason for blocked result where applicable |
| --- | --- | ---: | --- | --- |
| regular-short | indep, dep, latent, latent-plus-Psi | 0.3, 0.7 | partial | At least one recovery or covariance threshold misses; no blocking predicate. |
| irregular-long | indep | 0.3, 0.7 | partial | At least one recovery or covariance threshold misses; no blocking predicate. |
| irregular-long | dep | 0.3 | blocked | Boundary frequency 0.789 among successful estimated fits. |
| irregular-long | dep | 0.7 | partial | At least one recovery or covariance threshold misses; no blocking predicate. |
| irregular-long | latent | 0.3, 0.7 | partial | At least one recovery or covariance threshold misses; no blocking predicate. |
| irregular-long | latent-plus-Psi | 0.3 | blocked | Boundary frequency 0.816; rho/range diagnostic correlation 0.826 with large RMSEs. |
| irregular-long | latent-plus-Psi | 0.7 | partial | At least one recovery or covariance threshold misses; no blocking predicate. |

The blocked results are evidence of unstable range/strength separation in their
named regimes, not a universal non-identifiability theorem. The partial results
are not a positive recovery claim. No public documentation may state that
estimated spatial rho recovery has passed in any regime.

## Independent review verdict

The Noether mathematical review confirms that the two blocked cells and 14
partial cells follow the frozen predicates. The Fisher/Rose evidence review
independently reconciles all 1,600 frozen job IDs and metadata: 32 pilot plus
1,568 remainder attempts, each returned once with one optimizer entry. It
confirms the 1,494 strict successes and 106 numerical failures, with no
timeouts, process failures, missing results, or extra entries. The only closure
repairs were the pilot-path provenance mapping and the completed-study wording
in `full-evidence/README.txt`.
