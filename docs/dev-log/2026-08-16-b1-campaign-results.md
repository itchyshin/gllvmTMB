# B1 campaign — execution record and integrity findings

**Status:** campaign COMPLETE and verified. Calibrator fitting (B2) is a separate
document; nothing here is a coverage claim.

## What ran

| | |
|---|---|
| Grid | Design 118 §5.1 — 132 cells (88 train, 44 hold-out), 600 outer datasets/cell |
| Shards | **7,920 / 7,920** (`--outer-per-shard 10`) |
| Cells | **132 / 132** |
| Rows | 250,380 |
| Sidecars | 15,840 = exactly 2 per shard; **0 shards missing either** |
| Repair failures | 0 |
| Train rows exported | 102,536 |
| Venue | **Totoro**, 140 cores (D-143 cap respected), ~19 h wall |
| Code | main run `a3b31e62`; 102 repaired shards `02b32324` |

**Venue deviation.** Design 118 §6.4 and D3 specified DRAC job arrays. The campaign was
launched on Totoro by a sibling lane under a parallel maintainer authorisation while this
lane was staging narval. It was allowed to stand rather than be re-run: shard size is an
execution partition only — the 600 outer datasets per cell and the deterministic 1-in-3
bootstrap subset (seed arithmetic, not RNG state) are identical either way — and the
narval array would have duplicated ~2,900 core-hours for no scientific difference. The
D-87 collision was resolved to this lane, and the sibling stood down.

## Two defects found by the campaign, both fixed, both consequential

### 1. Endpoint interpolation assumed a monotone profile trace (`02b32324`)

`b1_profile_trace_endpoint()` took `max(which(below))` — the last below-threshold point —
which identifies the bracketing pair **only if `objective_delta` is monotone along the
walk**. On a flat or near-separated surface the profile wiggles, so the last
below-threshold point can be the final row and `i + 1L` indexes past the end.

**80 shards died this way, and the loss was BIASED**: 75 of 80 were cloglog at extreme
prevalence (π ∈ {0.03, 0.08, 0.20, 0.97}) — i.e. concentrated in exactly the
near-separated regime the campaign exists to measure. A consolidation that silently
dropped them would have flattered every result. Fixed to take the first adjacent
(below, not-below) transition, NA-safe; monotone traces interpolate identically.

### 2. The stored endpoint columns are legacy and MIXED — 6.06% are wrong

Because fix (1) changed the endpoint *semantics*, the shards' stored
`profile_lower/upper` columns are a mixture: the main run wrote them with the pre-fix
rule, the 102 repaired shards with the corrected rule. Measured over all 102,536 train
rows during B2 precompute:

> **6,218 rows (6.06%) differ from the recomputed endpoint; max |diff| = 33.17.**

**Every endpoint is therefore recomputed from the raw trace sidecars, which are ground
truth. The stored columns are not used.** This is precisely the failure the §3.4 storage
contract was made a launch blocker for: with endpoints-only storage the discovery would
have cost a re-run of the whole campaign; with traces it cost a re-analysis. The
fast-path recomputation agrees with the registered function to **max |diff| = 0** over
all 102,536 rows, and the bootstrap re-expression to 1.07e-14 over 600 verification
checks.

## Fit errors — expected and unexpected

684 + 912 + 24 rows carried `outer_fit_error`, all traced to the pre-existing package
defect [#1020](https://github.com/itchyshin/gllvmTMB/issues/1020):

- **Expected (DEV-10):** the 5 cloglog `n_site = 192` hold-out cells.
- **Unexpected:** **B048** (cloglog, π = 0.03, `n_site = 96`, **q = 2**) lost 228 of 600
  outer datasets (38%) — a *training* cell, not forecast by DEV-10.

That surprise sharpened the bug materially. At identical inner dimension `n_site × q =
192`, π = 0.03 fails while π = 0.50 and π = 0.97 are clean; and q = 2 at `n_site = 96`
fails where q = 1 at `n_site = 96` passes. So the trigger is **inner Laplace dimension
(`n_site × q`) combined with cloglog's low-p tail**, not `n_site` alone and not extreme
prevalence symmetrically. Posted to #1020; any guard must be written in `n_site * q`.

**Carried as a caveat on the fitted calibrator:** B048's surviving 62% is not guaranteed
to be a random subset of its datasets, so that cell's contribution to the fit is
potentially selected. Recorded, not silently absorbed.

## Provenance

Campaign root (local, never a GitHub artifact — D-50):
`/home/snakagaw/gllvmtmb-local-artifacts/b1-full-20260816` on Totoro.
Consolidated outputs and the calibrator input: `/home/snakagaw/b1-consolidated`.
