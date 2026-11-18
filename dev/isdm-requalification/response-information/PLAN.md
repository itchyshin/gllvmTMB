# Fresh iJSDM response-information campaign

## Purpose and predecessor fence

This is a fresh nonspatial study of whether two additional conditional response
streams at the same observed source-cell-trait support improve recovery of
shared/full ecological surfaces and trait-specific `Psi`. It is not a spatial
patch/range study and makes no public capability claim.

The earlier `PILOT_INFRASTRUCTURE_STOP` remains immutable: 800 planned fits,
16 terminal pre-optimizer errors, zero fitted pairs, and 784 unstarted
identities. This study has a distinct campaign identifier, seed namespace,
output root, record schema, and denominator. No old task, seed, record, or
result may be reused. A second frozen campaign follows the retained-pilot
launcher repair under seed namespace `209110001L`; it is a new denominator,
not a retry or amendment of the stopped campaign.

## Frozen scientific contract

The eight cells are `n_sources = {2,3}`, `overlap = {full,weak}`, and
`n_cells = {150,810}`. For every cell, 50 matched datasets yield 400 pairs and
800 retained fits. The baseline and `rep3` arm share all structural and
observation truth, including `Sigma = Lambda Lambda' + Psi`; `rep3` preserves
baseline rows byte-for-byte and appends two disjoint conditional response
streams. Pair members use the same optimizer seed.

The 16 identities with `seed_index = 1` form the retained DRAC pilot. The first
array launcher mistakenly treated array positions as task identities and produced
terminal records for `1:16`: two intended pilot identities plus fourteen valid
extra retained identities. The immutable repair runs only the missing intended
IDs `101,102,...,701,702`, leaving 30 terminal retained records and 770
unstarted identities. It does not repeat, replace, or discard any fit. Scale-up
remains blocked until the repaired checkpoint is explicitly accepted.
A worker writes exactly one started record and one terminal record. A
coordinator may add an unavailable/interrupted disposition only when no worker
terminal exists; it never overwrites a worker record.

## Engineering qualification and compute

Qualification is outside the 800 and uses four reserved identities: baseline
and `rep3` on Totoro, then baseline and `rep3` in fresh DRAC array workers. It
must bind source tree, installed package, DLL, manifest, load order, optimizer
entry, finite raw estimates, serialization, and independent scoring. A repair
invalidates qualification and repeats only this engineering tier.

The retained pilot runs on DRAC with 16 one-thread tasks, 8 GiB/task, and a
20-minute ceiling. Scale-up requires 16/16 valid terminal fits, convergence
zero, positive-definite Hessians, finite raw values/scores, maximum gradient at
most 0.01, all nesting/oracle/public-prediction checks, maximum worker memory
at most 8 GiB, and a pilot-derived projection at most six hours. Raw outputs
stay on DRAC `/project`; only checksums and compact summaries enter Git.

## Classification and scope

For each target, `D = log(error_rep3 + 1e-8) - log(error_baseline + 1e-8)`.
A target passes a cell when its paired median is at most `log(0.90)` and its
upper 95% percentile-bootstrap limit is below zero (2,000 resamples, seed
209019999). A surface or `Psi` target passes globally in at least six of eight
cells. `SURFACE_ONLY` means both surfaces pass and zero/one `Psi` trait passes;
`JOINT` means both surfaces and all three `Psi` traits pass; every other fully
observed result is `MIXED_OR_NULL`. A missing score makes
`EVIDENCE_INCOMPLETE`; a qualification/hash/receipt failure makes
`INFRASTRUCTURE_STOP`. Neither is a scientific null.

No spatial inference, intervals, API/engine/optimizer change, empirical claim,
merge, release, tag, or version bump belongs to this campaign.
