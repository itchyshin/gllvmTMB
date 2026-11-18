# AA-03 Gaussian latent n=240 production receipt

**Verdict:** `PASS` for one exact, ordinary native-Laplace Gaussian rank-1
`latent(unique = TRUE)` point-estimation cell. This is **partial,
cell-specific evidence**; it is neither a release nor a general Gaussian-latent
admission.

## Identity and retention

The approved Totoro batch used the archive
`gllvmTMB-aa03-smoke.tar` with SHA-256
`0c862fa607622c11645aa5cf42d40020abe2a563c20256814745f4b34ea13430`.
The immutable manifest has 1,600 rows for `g_latent_n240`, replicates 1--1,600,
and seeds 671400001--671401600. The archive-installed package reports version
0.6.0.

All 1,600 per-attempt RDS files and the summary RDS are retained on Totoro at
`/home/snakagaw/hsq_work/gllvmtmb-aa03-20260812/production-r3/`. The retained
summary SHA-256 is
`277385589f47cffd2e84d3ac506bcccd5ba55d5be079ad9e3e55d3b6b31bda64`.
`attempt-sha256.txt` is the SHA-256 inventory of all 1,600 per-attempt RDS
files; it has SHA-256
`6c8578fa55fdf80f03a9d06bb1204ad29b2ba3b4959dda1473ac86fb04cca224`.
The run used 150 workers on Linux 6.8.0-110-generic x86_64 with R 4.5.3.
No AA-03 worker process remained after completion.

The committed small receipts have these SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `manifest.csv` | `c0ac747918b111d241d5c50c1ecf2e85b148d767a3e153371baafb33d29e78d7` |
| `production-receipt.csv` | `d485f238a437e91be1d73a246351b5387d6acbc6732541f3fa4572d44ff6df31` |
| `cell-gate.csv` | `88d24c2409472bd3d30730b71c2d877d25bb5ed14025d3c263abcfacd3a92484` |

## Gate result

The cell was complete: 1,600 expected, attempted, and terminal attempts;
1,598 were usable and two were retained unusable false positives. All 1,600
had positive-definite Hessians, no attempt was unclassified, and no
catastrophic-but-healthy fit occurred (one-sided 95% upper bound 0.00187058).
The fixed-effect bias gate passed; the shared-Sigma and total-Sigma relative
biases were 0.00668346 and 0.00607144, respectively. All predeclared Psi,
correlation, component-schema, and total-Sigma gates passed. See
`cell-gate.csv`.

## Comparator

The current source was also checked against the exact rank-1
`glmmTMB::rr() + diag()` fixture with matching trait order, fixed effects,
Gaussian identity likelihood, and diagonal-Psi residual model. It passed with
objective difference `2.680e-08`, maximum fixed-effect difference `8.939e-06`,
maximum total-Sigma difference `5.085e-06`, maximum Psi difference
`1.036e-05`, and residual-SD difference `9.519e-07`. Both fits had
positive-definite Hessians. See `comparator-receipt.csv`.

The generic gate's `publicly_promotable = TRUE` / `public_status = PASS` fields
are properties of the reused v4 gate implementation only. They do **not** make
an AA-03 release, broad capability, or public-admission verdict; this packet's
scope is controlled by the frozen AA-03 contract.

## Boundary

This evidence does not change `CRAN07-AA-03` from `partial`. It does not cover
raw loading orientation, intervals, diagnostic sensitivity, n=60, the three
correlation-stress failures, the three boundary/Psi challenges, other ranks or
families, missing data, slopes, structured sources, VA, AGHQ, EVA, or a
release/platform-artifact ladder. The historical v4 archive is separate and is
not pooled with this fresh-source run.
