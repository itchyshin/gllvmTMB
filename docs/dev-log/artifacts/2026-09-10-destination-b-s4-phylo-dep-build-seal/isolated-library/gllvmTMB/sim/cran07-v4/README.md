# CRAN 0.7 v4 confirmation harness

This directory is the zero-fit campaign harness for the v4 confirmation design.
It reuses the immutable v2 registry bytes and scientific fixture machinery, but
uses v4 campaign IDs and disjoint smoke, pilot, and production seed offsets.

The six-field attempt/manifest identity is campaign ID, registry SHA-256,
source-archive SHA-256, cell ID, replicate, and seed. Canonical cell number is
also recorded in each manifest and checked independently against the registry.
Smoke and pilot cover all 34 cells with 2 and 20 attempts per cell. Production
uses 1,600 attempts per explicitly pilot-admitted cell and always excludes the
three predeclared challenge cells.

The immutable production table contains 31 campaign-qualified keys.
Constructor, validator, runner, summarizer, and closeout all enforce it. Pilot
admission is recomputed from retained attempts; disagreement with a stored gate
is treated as corruption.

V4 retains v3 health, beta, covariance, Psi, correlation, catastrophic-error,
detector, and RMSE thresholds. Structural off-diagonal Psi truth must be exact
zero. An active estimate must also be exact zero; an already-inactive Psi block
may retain `NA`, but never a hidden nonzero value. The rows are then made
non-applicable. The rank-one correlation numerical-zero rule remains
`64 * .Machine$double.eps`. NB2 adds three named `phi_nbinom2`
components (truth 5), with relative bias at most 0.20, inclusion in the NB2 RMSE
pair, and catastrophic truth-ratio bounds `[0.1, 10]`.

Every estimand row carries the six-field attempt identity. Finite attempts must
contribute each canonical applicable component exactly once. Named NB2 reports
are reordered only after exact name matching; unnamed reports require the
engine `trait_id` sequence to prove trait order.

Before production cell or detector gates run, the harness recomputes
`catastrophic_truth_error`, `relative_covariance_error`, and
`max_eigen_ratio` separately for every six-field attempt from its retained
estimands. It also re-derives `detector_flagged` from terminal status. Any exact
disagreement with the stored attempt ledger is corruption and fails closed.

Every successful post-repair fit must expose warm-restart provenance through the
single defensive adapter in `schema-v4.R`. The ledger does not assume that a
restart occurs, but missing provenance fails the attempt closed. Run
`self-test.R` before any smoke. The self-test fits no model.

Frozen execution starts only through the detached `launch-bound-source.R`.
The launcher reads the canonical `source-archive-binding.csv`; callers cannot
supply an archive, receipt, hash, or source tree. The binding must carry the
exact receipt identity, `READY` status, `launch_authorized = TRUE`, archive
basename/absolute path/SHA-256, exact payload-manifest identity and member
count, exact detached SHA-ledger identity, and launcher identity. Direct runner
calls reject caller source identity.
Launch remains disabled unless that internal binding and a separately
maintainer-authorized external authority record both match the same exact
post-repair archive. Neither mechanism authorizes a package release.
The authority record must live at one of the two fixed local/Totoro paths as a
regular `0444` file inside a non-symlink `0555` authority directory, and must state
`simulation_authorized = TRUE` while release, version-change, publication, and
CRAN-submission authorization are all `FALSE`. Both the launcher and the
in-artifact runner independently verify this contract and the archive,
manifest, SHA-ledger, and launcher digests. The runner also verifies that its
live parent process is the authenticated detached launcher; invoking
`run-batch.R` directly is not an admitted execution path.

The archive is a metadata-controlled regular-file payload rooted at
`gllvmTMB/`. Its canonical binding receipt, exact path/type/mode/size/SHA-256
payload manifest, detached launcher, and `SHA256SUMS` are the launch envelope:
they are copied beside the extracted source, never embedded in the artifact
whose digest they declare. This prevents a self-referential hash. The local and
Totoro receipts bind the same bytes at their respective fixed absolute paths.
`build-source-archive.R` requires bsdtar 3.5.3, fixes locale, ownership, modes,
timestamps, member order, and format, and refuses overwrites, symbolic links,
unsafe paths, or an embedded envelope.

The launcher accepts only campaign/stage/output/manifest/launch-root (plus the
production pilot gate). It verifies the archive and manifest, rejects every
non-regular member, extracts to a new directory, checks every extracted byte
against the manifest, overlays the detached envelope, builds a package tarball,
installs it into a new isolated R library, and invokes the runner from the
extracted tree. The runner independently revalidates the live tree and requires
the loaded `gllvmTMB` namespace to come from that isolated library.

Cell evidence and public promotion are separate. Gaussian latent `n = 60` and
NB2 latent `n = 100` always report `CHARACTERIZATION_ONLY`. All 31 keys are
required for an execution-evidence PASS, while public release remains HOLD
pending claim-level adjudication.
