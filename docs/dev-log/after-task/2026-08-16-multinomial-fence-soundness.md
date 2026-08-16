# After Task: multinomial admission-fence soundness repair (Slice 0)

**Branch**: `claude/multinomial-structured-20260816`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada / r-package-engineer (build) / Rose+Opus (adversarial verify ×2) / statistical-reviewer (plan review)

## 1. Goal

Make the multinomial (fid 16) structured-term admission fence actually
fail-closed. Slice 0 of the structured-dependency arc (ultra-planned this
session; design stub `docs/design/122-multinomial-structured-surface.md`).

## 2. What was wrong

The old fence was a mid-function `ls(pattern = "^use_")` allow-list. Two
independent holes, both empirically confirmed (fence stashed, tests fitted):

- **Keyword folding.** The grammar desugars distinct keywords onto allowed
  flags. Eight documented-as-blocked cells fitted silently: `dep()`@unit,
  `phylo_dep`, `phylo_indep`, `phylo_unique` (standalone), `phylo_scalar`,
  `animal_scalar`, `animal_latent`, single-name `kernel_latent`.
  `docs/design/02-family-registry.md` claimed all of these fail loud — false.
- **Timing.** `use_mi_*` flags were defined AFTER the scan site, so `mi()`
  terms were invisible to the fence.

Already genuinely blocked (not leaks, contrary to the initial stale-checkout
audit): explicit `unique()`/`indep()`@unit, `(1|g)`, unit_obs, cluster/
cluster2, multi-kernel.

## 3. Implemented

Two-stage fence:

1. **Early covstruct-kind classifier** (`R/multinomial-fence.R`): classifies
   every parsed covstruct into a (source, mode) cell (kind + markers `.dep`,
   `.phylo_unique`, `.latent_augmented`, `.latent_slope`, `.animal_source`
   [new marker on all `animal_*` desugars], kernel names, spatial markers,
   `.auto_unique`, grouping tier) and checks it against an explicit
   admission-table constant. Admitted set unchanged: `phylo_latent()`
   (loadings-only; it emits NO auto-Psi companion for multinomial —
   `unique = TRUE` is blocked, matching `extract-sigma`'s documented policy),
   shared ordinary `latent()`@unit, default auto-Psi. Typed abort:
   `gllvmTMB_multinomial_structured_not_admitted`, message carries the
   per-fit (not per-trait) limitation.
2. **Late `use_*` re-scan** relocated after all covstruct-derived flags
   (incl. `use_mi_*`); `use_propto` exemption removed; `use_equalto`/
   `meta_V` now fail-closed in pass 1; same typed class.

Tests: `tests/testthat/test-multinomial-fence.R` — typed `expect_error` per
blocked cell (each proven to FAIL pre-fix), positive controls, a
table-consistency test iterating every admission-table row, the `mi()`
timing-gap regression test, a VA-route pin, mixed-family message-honesty
pin.

## 4. Checks run

- `devtools::test(filter="multinomial")`: FAIL 0 | WARN 1 (expected AGHQ
  decline) | SKIP 4 (spatial cells, no INLA locally; classifier-verified) |
  PASS 201.
- Regression sweeps: keyword-grid/animal/kernel filters 475 pass; heavy
  animal 234; heavy two-kernel 570; cross-family-intervals 30;
  tiers-poisson control 19 (fence is a no-op without fid 16).
- Adversarial Opus review ×2: first pass found 8 findings (3 medium: pass-1
  holes for augmented-slope `latent()`/`phylo_latent()`; the
  `phylo_latent(unique=TRUE)` table/behaviour contradiction); repair loop
  applied; re-check verdict CLEAR ×8, no new holes.
- Rebased onto origin/main (post-mspl merges, disjoint hunks verified);
  fence file re-run green on the rebased base.

## 5. Decisions and rejected alternatives

- **Fence on parsed intent, not engine flags.** The admission table is the
  single source of truth; later slices flip one row + evidence.
- `equalto`/`meta_V` on fid-16: fail-closed by default (no admitted route
  argued); per-fit semantics stated in the message.
- Behaviour change deliberately breaking: users of the eight leaked paths
  now get a typed error (NEWS names this as a soundness fix).

## 6. Follow-up

- Slice 1 (next): admit `animal_latent`/`kernel_latent` with equivalence +
  recovery evidence; campaign scripts staged in `dev/multinomial-structured/`
  (uncommitted; land with S1). Pass criteria draft pending maintainer
  sign-off.
- Spatial blocked-cell tests need one fit-level run in an INLA environment
  (currently classifier-verified + skip).
- Cross-repo lesson filed: brain `memory/CROSS-REPO-GUARDS.md`
  ("allow-list keyed on engine flags is defeated by keyword folding").

🔴 **Needs maintainer:** merge sign-off (fence behaviour change is on the
high-risk list); campaign pass-criteria sign-off before the first Totoro
launch.
