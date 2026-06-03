# After Task: Kernel engine C3 -- two-kernel model + two-Psi identifiability guardrail

**Branch**: `claude/kernel-c3-two-kernel`
**Date**: `2026-06-03`
**Roles (engaged)**: Ada (engine), Curie/Fisher (identifiability + recovery), Pat (CI)

## 1. Goal

Implement Design 65 §C3 of the cross-lineage coevolution kernel engine:
(C3.1) fit / extract two named kernel tiers, and (C3.2) the two-Psi
identifiability guardrail. Serialized engine lane, TDD, narrow slice, DRAFT
PR (engine-lane change needs maintainer review; do NOT merge). C0-C2 are
already DONE on main.

## 2. Implemented

- **C3.1 scope finding (STOP / reserved).** The C0-C2 kernel core reuses the
  SINGLE dense-relatedness phylo slot: one `Ainv_phy_rr` / `d_phy` /
  `Lambda_phy` / `g_phy_diag` in `src/gllvmTMB.cpp`, and one `phylo_rr_idx`
  + one `phylo_diag_idx` in `R/fit-multi.R` (with explicit "only one
  phylo_latent term" / "must use one name" aborts). Two GENUINELY
  independent named kernel tiers -- a phylo cross-kernel `K_phy` AND a
  tip-level non-phylo `K_non = scale(W)`, each with its own `K`, `Lambda`,
  and augmented random field -- would need a SECOND TMB data/parameter slot
  and a second NLL block. That is a LARGE C++/engine change, so per the C3
  brief ("if C3.1 would require a LARGE new C++/engine change, STOP and
  report") it is STOPPED and left `reserved`. The test pins the honest
  boundary (the engine rejects two distinct named tiers fail-loud) and
  re-asserts that the SUPPORTED single named tier's two-component
  (latent + unique) `Sigma` and `Gamma` extract by `name`.
- **C3.2 guardrail (done).** `R/fit-multi.R` now detects two `kernel_unique`
  (uniqueness) tiers without within-species replication and, instead of
  aborting, drops the extra uniqueness covstruct (defaulting to a single
  identifiable uniqueness tier) and emits a `cli::cli_warn` citing the
  two-Psi confound (Boettiger et al. 2012; Design 65 C3.2). Detection is
  conservative: TWO+ `kernel_unique`/`kernel_indep` tiers present AND every
  species level appears in at most one observation row. The pruning runs
  early (right after `kinds`/`groupings` are built) so all downstream slots
  -- vcv harvest, `phylo_diag`, `extract_Sigma` -- see a single tier, and it
  precedes the single-`name` validation so two differently-named tiers
  ("phy" + "non") collapse rather than abort.
- **C3.2 replication-count fix (gate red -> green).** The first cut of the
  guardrail counted replication with `table(data[[species]])` (raw long-format
  rows). By the time the fit runs, a wide `traits(y1, y2)` call has already
  been pivoted to stacked-trait long format, so every species appears in
  `n_traits` rows even with ONE community realisation. The raw-row count
  therefore reported `max == n_traits > 1` (false "replication"), the prune
  did NOT fire, and the two differently-named tiers reached the single-`name`
  validation and **aborted** at `R/fit-multi.R:627` -- the C3 gate's `1
  errored` cell ("two `kernel_unique` tiers without replication warn and
  collapse to one"). Fix: count DISTINCT observation units per species via the
  `unit_obs` factor (`tapply(data[[unit_obs]], data[[species]], n_distinct)`),
  which collapses the trait-stacking and reports the honest 1-unit-per-species
  count, so the prune fires, warns, and the model fits with one tier. The
  heavy single-tier recovery cell never reaches the prune (`sum < 2`) and was
  not the culprit; the brief's C3.1 skip-reserve (#1) did not apply because
  that cell was already reworked to a single feasible tier.

## 3. Files Changed

- Engine: `R/fit-multi.R` (C3.2 early-prune guardrail block).
- Tests: `tests/testthat/test-coevolution-two-kernel.R` (new).
- CI: `.github/workflows/coevolution-two-kernel-recovery.yaml` (new heavy
  `pull_request` gate; runs the C3 suite + C1/C2 suites as regression with
  `GLLVMTMB_HEAVY_TESTS=1`, fails on failure/error, skips do not fail,
  paths-filtered).
- Docs: `docs/design/65-cross-lineage-coevolution-kernel.md` (C3.1 marked
  STOPPED/reserved, C3.2 marked done); `docs/design/35-validation-debt-register.md`
  (new COE-03 row); this after-task report.

## 3a. Decisions and Rejected Alternatives

- **Decision:** STOP on C3.1 two independent tiers; pin the fail-loud
  boundary in a test rather than build a second engine slot.
  **Rationale:** the design lists only a test file for C3, implying the
  multi-tier machinery already exists; it does not, and a second TMB slot is
  out of the narrow-slice C3 scope. **Rejected:** adding `Ainv_phy_rr_2` /
  `g_phy_2` / second NLL block (large C++; deliberate future extension).
  **Confidence:** high (verified the single slot in both the C++ template
  and the R guards).
- **Decision:** C3.2 is a `cli::cli_warn` + collapse-to-one, not a hard
  abort. **Rationale:** the brief says "use `cli_warn` (warn, not hard-fail)
  unless the file's existing convention is fail-loud" -- and the existing
  kernel-tier code already aborts on two same-name uniqueness tiers, so warn
  + collapse is the more user-friendly identifiable default. **Confidence:**
  high.
- **Decision:** prune the redundant covstruct early (after `kinds`/`groupings`)
  rather than late. **Rationale:** the vcv harvest at line ~1799 iterates all
  `parsed$covstructs`; pruning early means the dropped tier's (possibly
  different) `K` never reaches the harvest, keeping the surviving single-`K`
  path clean. **Confidence:** high.

## 4. Checks Run

- No local R in this environment (`R`/`Rscript` not on PATH) -- validation is
  CI-only via the new heavy gate, per the task's "iterate via the gate's job
  log" instruction.
- `rg` audits: confirmed the single phylo slot (`phylo_rr_idx`/`phylo_diag_idx`
  "only one ... supported" aborts; one `Ainv_phy_rr`/`d_phy`/`Lambda_phy`/
  `g_phy_diag` in `src/gllvmTMB.cpp`); confirmed parser markers
  (`.phylo_unique` / `.indep` / `.kernel_mode`) set for `kernel_unique` /
  `kernel_indep` in `R/brms-sugar.R`; confirmed `expect_no_warning` already
  used elsewhere (testthat edition 3).

## 5. Tests of the Tests

- C3.1 rejection test: failure-before-fix is N/A (the abort pre-exists);
  prophylactic boundary pin so a future two-slot engine change is deliberate.
- C3.2 warning test: feature-combination (two distinct names + no
  replication) drives the new code path; the negative-control test (single
  uniqueness tier -> no warning) is the boundary on the conservative
  detector.
- Heavy replicated-Psi test: the replication-present branch (max obs/species
  > 1) must NOT warn and must recover a positive phylo uniqueness diagonal.

## 6. Consistency Audit

- `rg "kernel_.*tiers.*one .arg name"` -> single-`name` validation present;
  C3.2 prune runs before it (verified by line order in `R/fit-multi.R`).
- `rg "data\[\[species\]\]"` -> `species` is the cluster column-name string.
  CORRECTION (gate fix): a raw `table(data[[species]])` count at the prune site
  is NOT a valid replication metric, because `data` is the stacked-trait long
  frame (each species spans `n_traits` rows). Replication is now measured in
  distinct `unit_obs` values per species, which is invariant to trait-stacking.

## 7. Roadmap Tick

Design 65 C3.1 (reserved) + C3.2 (covered); register row COE-03 added.

## 7a. GitHub Issue Ledger

Refs #361 / Design 65 §C3. No new issue created; the C3.1 STOP is recorded
in the design doc + COE-03 register row and surfaced for maintainer decision
in the PR body.

## 8. What Did Not Go Smoothly

No local R toolchain, so the heavy fits are validated CI-only. The C3 brief
framing ("only a test file") did not match the engine reality (single slot),
which is the headline scope finding.

## 9. Team Learning

- **Ada (engine):** the kernel core is intentionally a thin reuse of the one
  phylo slot; "two tiers" in the design means two COMPONENTS (latent+unique)
  on one tier, not two independent `K`s. A second `K` is a real engine slot.
- **Curie/Fisher:** the two-Psi confound under no replication is the
  load-bearing identifiability claim; the guardrail makes the identifiable
  single-Psi default explicit and documents the replication requirement.

## 10. Known Limitations And Next Actions

- **Reserved:** two independent named kernel tiers (`K_phy` + `K_non`) need a
  second TMB data/parameter slot + NLL block -- a deliberate future engine
  extension, maintainer-gated.
- C3.2 collapses to the FIRST uniqueness tier; it does not attempt to merge
  the two `K`s. That is the conservative identifiable default.
- DRAFT PR -- maintainer review required before merge (engine lane).
