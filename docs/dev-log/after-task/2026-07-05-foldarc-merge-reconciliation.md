# After-task — fold-arc merge reconciliation onto the live branch

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion` (live), via
`integration/merge-main-foldarc` (isolated worktree)
Agent: Claude (implementation authorized by Shinichi; Codex out ~3 days)

## 1. Goal

Reconcile the long-lived work branch `codex/r-bridge-grouped-dispersion`
(grouped-dispersion → Julia bridge → gamma → #608 / #679 → Slice 2a/2b) with
main's landed `unique=` fold arc, drive the merge to a green suite, and adopt it
onto the live branch — without losing any guard, claim boundary, or grammar
contract. No push / no PR (maintainer gate).

## 2. Implemented

- **Merge**: main → live in an isolated worktree; **99 conflicts** resolved
  across 179 files. Took main's canonical `brms-sugar.R` (rename via
  `.gllvmTMB_warn_latent_residual_alias` + the phylo/spatial/animal/kernel
  folds); re-layered this branch's #608 augmented opt-out, #679, gamma, and the
  8 coevolution tests on top; union-merged the two-kernel coev test.
- **50 → 0 failure tail** cleared. Re-layered guards the merge dropped, fixed
  the one real merge bug (spatial SPDE-fold engine wiring), and reconciled stale
  tests to main's canonical behavior.
- **Grammar taxonomy** (maintainer clarification): split the muddled "latent
  structural helpers" test into (a) latent-mode SOURCE helpers
  (spatial/animal/kernel) and (b) `indep` as a distinct **diagonal kind**
  (asserts no `rr`/`spde` block). Restored **positional control args**
  (`d`/`unique`/`common`) as first-class for all source helpers (byte-identical
  to named).
- **Adopted** onto live as a `--no-ff` merge commit (`6e142f1d`).

## 3a. Decisions and Rejected Alternatives

- **Merge, not replay** — the branch was 267 commits diverged; a symmetric merge
  is the only faithful path. Rejected cherry-picking (would silently drop main's
  fold internals).
- **Julia `extract_correlations` → point-only, not abort** — adopted main's newer
  design (intervals NA, `interval_status="none"`, `JUL-01A`). Verified it refuses
  to *fabricate* intervals, so the claim boundary holds. Rejected restoring my
  branch's hard abort (would revert main's deliberate evolution).
- **`indep` is a kind, not a latent helper** (maintainer) — encoded as its own
  test. Rejected leaving it grouped with the source helpers.
- **Control args first-class positional AND named** (maintainer) — restored
  `.named_or_positional_arg` extraction; rejected named-only (my initial lean).
- **Adopt via merge-commit** (maintainer) over reset — non-destructive, explicit
  adoption marker.

## 4. Files Touched

- Merge (integration branch): 179 conflicted files reconciled; branch diff vs
  main ≈ 594 files.
- Hand-edited in reconciliation: `R/brms-sugar.R` (guards: source-`lv=` abort,
  duplicate-slope, phylo mode-dispatch exemption, spatial trait-anchor; #626
  strip-parens; #628 `.meta_type`; positional restore for animal/kernel/phylo/
  indep), `R/kernel-helpers.R` (#643 `profile_cross_rho` scalar,
  `diagnose_kernel_separability` align), `R/fit-multi.R` + `R/brms-sugar.R`
  (spatial SPDE-fold `unique=` wiring).
- Tests: `test-coevolution-two-kernel.R` (helpers restored + union),
  `test-canonical-keywords.R` (taxonomy split + positional), `test-julia-bridge.R`
  (point-only), `test-scan-deprecated-namespace.R`, `test-spatial-orientation-parser.R`,
  `test-ordinary-latent-random-regression.R`, `test-example-behavioural-reaction-norm.R`.
- Commits: `da332276`, `f481ac73`, `9d8e15fc` (integration); `6e142f1d` (live merge).

## 5. Checks Run

- Full suite (`testthat::test_dir`, `NOT_CRAN=true`): **PASS 4165 / FAIL 0 /
  ERR 0 / SKIP 770**.
- Targeted probes: all guards fire (source-`lv=` abort, spatial trait-anchor,
  phylo mode-dispatch 0 msgs / legacy 1 msg); positional desugar **byte-identical**
  to named for spatial/animal/kernel/phylo/phylo+slope/indep; julia point-only
  returns NA intervals + `interval_status="none"`.
- `R CMD check` (`--no-manual --no-build-vignettes`, `_R_CHECK_FORCE_SUGGESTS_=false`):
  first pass **0 ERROR / 1 WARNING / 0 NOTE** — the one warning was a codoc
  mismatch (`man/spatial_latent.Rd` stale after the `unique=` param restore).
  Fixed via `devtools::document()` (regenerated only `spatial_latent.Rd`);
  confirming re-check **0 ERROR / 0 WARNING / 0 NOTE** (a full `--as-cran` with
  all Suggests installed remains a pre-CRAN follow-up).
- Not run (deliberate): vignette / pkgdown build (slow, model-fitting; separate
  follow-up), full `--as-cran` with all Suggests installed.

## 6. Tests of the Tests

- Each re-layered guard was verified to **fire on the bad input and stay quiet on
  the good input** (e.g. `spatial_unique(sp | coords)` aborts; `spatial_unique(coords
  | trait)` warns+flips; `phylo(0+trait|species, mode=…)` emits 0 deprecation msgs
  while `phylo(species)` emits 1). Positional support proven by
  `expect_identical(positional, named)`, not just "parses".
- The julia claim-boundary test asserts the *columns* (`lower`/`upper` NA,
  `interval_status`), not merely non-error.

## 7a. Issue Ledger

- Fixed / re-layered: #608 (augmented opt-out), #679, #643 (`profile_cross_rho`
  scalar tie), #626 (`(0+trait)` strip-parens), #628 (`.meta_type` clean abort).
- Merge-dropped guards restored: source-`lv=~env` fail-loud, duplicate-slope,
  phylo mode-dispatch exemption, spatial `trait`-anchor, GJL correlation-interval
  boundary (now point-only), `diagnose_kernel_separability` alignment.

## 8. Consistency Audit

- **All** source-latent helpers swept for positional support (not just the one
  that failed): spatial ✓ (pre-restored), animal/kernel/phylo/indep restored +
  verified equivalent; sibling `*_unique`/`*_indep`/`*_dep`/`scalar` branches
  spot-checked for no regression.
- **All** merge-dropped guards grepped by ground truth (conflict markers, guard
  tokens) rather than trusting subagent self-reports.
- Full suite is the neighbourhood sweep for the 5-branch engine change (0 regress).

## 9. What Did Not Go Smoothly

- A broad-scope subagent hallucinated an orchestrator role and spawned children
  (fixed; lesson filed). One coev test was nearly lost to a `--theirs` misread
  (caught by re-inspection). The premise "Codex didn't merge its arc" was
  inverted by the git record (lesson filed).

## 10. Known Residuals

- **Push / PR to main not done** — awaiting maintainer approval (hard guard).
- Vignette / pkgdown render-check of changed articles pending (a documented
  follow-up since Slice 2b).
- Positional-first-class is in the grammar + tests but **not yet cascaded into
  the prose docs/articles** (named examples remain valid; positional undocumented).
- Julia point-only correlation behavior is main's design, adopted here; worth a
  maintainer confirmation that the claim-boundary framing is the intended one.
- `R CMD check` ran with missing Suggests forced off; a full `--as-cran` with all
  Suggests installed is a pre-CRAN follow-up.

## 11. Team Learning

Two durable lessons filed to `~/shinichi-brain/memory/LESSONS.md`:
(1) **never hand one subagent a broad multi-file task** (it hallucinates
delegation); scope small, forbid spawning, verify by file ground truth;
(2) **check main before building on a long-lived branch** (`git log HEAD..origin/main
-- <path>`) — the 99 conflicts were self-inflicted drift, not unmerged upstream
work; we even re-did main's `residual→unique` rename. Prevention > merge-time cure.
