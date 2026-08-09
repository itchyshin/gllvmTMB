# CRAN 0.7 v4 confirmation preregistration receipt

**Frozen:** 2026-08-08, before any v4 fit.
**Launch status:** defined only by the detached canonical
`source-archive-binding.csv`; at design freeze it was
**HOLD_PENDING_SOURCE_ARCHIVE**. Zero v4 model fits had run.
**Design:** `docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md`.

## Frozen campaign surface

V4 reuses the exact 18-cell core, eight-cell silent-failure, and eight-cell
robustness registries and their compiled SHA-256 values. It does not pool or
reuse v3 attempts. Smoke and pilot run all 34 cells with 2 and 20 attempts per
cell. Production uses 1,600 attempts for each explicitly pilot-admitted member
of the predeclared 31-cell target. The correlation-0.98, `Psi = 0.01`, and
`Psi = 100` challenge cells remain pilot-only even if their pilot rows pass.

`campaigns.csv` freezes stage-specific IDs, offsets, and sizes. The seed is
`stage_offset + 100000 * cell_number + replicate`. The six-field exact
attempt/manifest identity is campaign ID, registry SHA-256, source-archive
SHA-256, cell ID, replicate, and seed. Manifest cell number is checked
separately against the canonical registry. A copied registry, altered registry,
wrong source hash, wrong stage offset, incomplete replicate sequence, duplicate,
missing, or extra identity fails closed.

`production-eligible.csv` freezes the 31 campaign-qualified keys and
`manifest-template.csv` freezes all stage sizes and offsets. Production paths
reject challenge keys directly and require the matching pilot-admission receipt.

## Scientific and diagnostic gates

`gates.csv` records the unchanged v3 thresholds with the v4 denominators. Every
applicable component requires exactly 1,600 finite contributions with
replicates `1:1600`. Off-diagonal Psi rows are accepted as structural and made
non-applicable only after exact zero truth is proved. Active estimates must also
be exact zero; an already-inactive Psi block may retain `NA`, but never a hidden
nonzero value. The rank-one shared-correlation numerical-zero exception is restricted to absolute errors no
larger than `64 * .Machine$double.eps`.

NB2 attempts append three named `phi_nbinom2` rows aligned to `t1`, `t2`, and
`t3`, each with truth 5. Each trait must have relative absolute bias at most
0.20. These rows enter the NB2 small/large RMSE comparison. A missing,
nonfinite, or nonpositive estimate fails extraction; a truth ratio outside
`[0.1, 10]` is catastrophic.

Every attempt carries the typed restart fields listed in `attempt-schema.csv`.
The ledger permits an unattempted, unaccepted restart with NA after-fields. An
accepted restart must have been attempted, must strictly improve the raw maximum
gradient, and must not worsen the objective beyond
`64 * .Machine$double.eps * max(1, abs(objective_before_restart))`. Fit-level
provenance is isolated behind one defensive adapter; a successful post-repair
fit without a recognized provenance record is classified as a fit error rather
than silently treated as no restart. Before/after optimizer code, Hessian,
boundary, objective, and nonnegative raw-gradient fields re-derive both trigger
and acceptance; the stored trigger reason must match.

Every estimand row carries the full six-field identity and joins exactly to one
attempt and manifest row. Each finite attempt supplies every canonical
applicable component once; stale seeds, missing rows, duplicates, and unexpected
components fail. Structural Psi zeros are checked before applicability. NB2
names match and reorder exactly, or engine `trait_id` proves unnamed order.
Before any production cell or detector gate, the three stored truth-error
fields are recomputed per six-field attempt from these estimands and compared
exactly. The detector flag is independently re-derived from terminal status.
A forged benign label on catastrophic Sigma therefore fails before aggregation.

Closeout separates `cell_verdict`, `evidence_pair_verdict`, and
`publicly_promotable`. Gaussian latent `n = 60` and NB2 latent `n = 100` remain
`CHARACTERIZATION_ONLY`. All 31 eligible cells are required for an execution
evidence PASS; public release remains HOLD.

## Verification at freeze

Run from the repository root:

```sh
Rscript --vanilla inst/sim/cran07-v4/self-test.R
Rscript --vanilla -e 'fs <- Sys.glob("inst/sim/cran07-v4/*.R"); for (f in fs) parse(file = f)'
sha256sum -c docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/SHA256SUMS
```

The adversarial suite pairs acceptance and rejection for stage manifests,
six-field identities, restart branches, structural Psi zeros, 3/20 versus 4/20
pilot admission, unclassified results, global detector denominators, exact
1,600-component ledgers, NB2 dispersion bias/catastrophic rules, and the
rank-one numerical-zero rule. It also loads the standalone summarizer/adjudicator
dependency set without the fitting runner, preventing gate-time helpers from
being hidden in model-execution code. It includes a complete 1,600-attempt forged-benign
catastrophic-Sigma ledger, which must be rejected before production gates. It
also proves the three challenge cells remain outside the 31-cell target and
scans the runner for forbidden size/cell overrides. The suite runs zero fits.

`SHA256SUMS` is the regenerated fixed inventory for the harness and the
registry/manifest contracts here. `source-archive-binding.csv` truthfully
records the current launch state. The binding receipt,
`source-payload-manifest.csv`, detached launcher, and `SHA256SUMS` form the
launch envelope and are excluded from the metadata-controlled source payload,
avoiding a self-referential digest. The exact payload manifest binds every
ordered path, regular-file type, normalized mode, byte count, and content
SHA-256. The source binding also records the exact detached SHA-ledger digest;
the binding itself is omitted from that ledger to avoid a second circular
digest. The envelope is copied beside a fresh extraction on each host.

Only the detached launcher can start a stage. It reads the canonical receipt,
rejects caller-selected source identity, verifies the archive plus exact
manifest and member types, extracts to a new directory, builds a package
tarball, installs it into a new isolated R library, and invokes the runner from
that extracted tree. The runner revalidates the live tree and the loaded
namespace location. Pending status, non-TRUE authorization, wrong identity,
basename/path/digest mismatch, missing/extra/link/device members, changed live
bytes, an embedded envelope, an old source tree, or a non-isolated package
library all fail closed. Root binds and refreezes the concrete archive only
after repair verification.

Simulation execution additionally requires one fixed external authority record
outside the copyable source/control tree. It is valid only as a nonempty `0444`
regular file inside a non-symlink `0555` authority directory. The runner
requires the live parent PID and command to identify the authenticated detached
launcher, so direct invocation cannot substitute caller-provided provenance.
The record carries the exact artifact digests and the explicit scope
`simulation_execution_only`. It must set simulation authorization to `TRUE`
and release, version-change, publication, and CRAN-submission authorization to
`FALSE`. The detached launcher and the installed runner validate the same
record independently. This is a local integrity and scope control, not a
cryptographic signature or a release authorization.

This receipt does not authorize smoke, pilot, production, a public capability
claim, a version bump, a candidate freeze, or CRAN submission. The
source-archive SHA-256 must be independently derived from the eventual
authorized archive rather than asserted from this worktree.
