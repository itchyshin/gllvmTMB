# AA-03 Gaussian latent admission: plan versus actual

## Planned

Establish or refuse one bounded ordinary native-Laplace Gaussian rank-1
`latent(unique = TRUE)` point-estimation statement at `n = 240`; preserve all
smaller-sample, stress, boundary/Psi, interval, alternative-estimator, and
release fences. The plan required an archive-bound smoke, an approved Totoro
all-attempt batch, a matched `glmmTMB::rr() + diag()` comparator, retained
evidence, and independent boundary review.

## Actual

The smoke and approved 150-worker Totoro production batch used a fresh archive
with SHA-256 `0c862fa607622c11645aa5cf42d40020abe2a563c20256814745f4b34ea13430`.
The 1,600-attempt `g_latent_n240` cell passed its frozen gates; all attempt
files, an attempt checksum inventory, the manifest, gate, and summary receipt
were retained. A current exact `glmmTMB::rr() + diag()` comparator also passed.

Two launcher-startup failures were retained (`production` and `production-r2`)
before any production attempt: the R child could not discover host core count.
The runner was repaired to receive the verified shell capacity explicitly, and
the successful `production-r3` run is separately identified. No numerical
attempt was discarded or rerun selectively.

## Reconciliation

The achieved outcome is narrower than a capability or release promotion and
matches the bounded plan: conditional point-estimation evidence for the one
exact `n = 240` regime. `CRAN07-AA-03` remains `partial`; no package runtime
code, public API, version, artifact/platform ladder, or release state was
changed.
