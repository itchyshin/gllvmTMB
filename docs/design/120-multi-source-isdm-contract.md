# Design 120 — the multi-source integrated-SDM contract (Model 2)

**Status: STUB — claimed 2026-08-16, content lands in this lane
(`claude/isdm-model2-multisource-20260816`).** Committed first to claim the number:
the design ledger has live duplicate slots, and slots 112–119 are already taken on
branches this checkout cannot see. A number is claimed by committing it, not by
reading the directory.

Scope, per the approved plan: generalise the two-source admission
(`.gllvmTMB_integrated_two_source_contract()`, `R/fit-multi.R`) to a **declared
source→observation-law map** (`isdm_sources()`), so `n_sources > 2` fits through
public `gllvmTMB()` with honestly named sources. The two-source contract becomes
the `n = 2` case of the same predicate.

To be written here: the n-arm coherence derivation (does the thinned-Poisson
argument survive more than two arms?), the admitted law set, reference-source
coding `gamma[1,j] = 0` at `n > 2` and its identifiability, what stays refused,
and what is explicitly out of scope (per-source bias covariates; #944 weights).
