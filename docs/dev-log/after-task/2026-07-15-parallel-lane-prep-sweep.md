# After-task — parallel-lane prep sweep (2026-07-15)

**Lane:** fresh Claude lane, running in parallel with Lane A (the coverage/
certificate lane holding a large uncommitted diff on `claude/release-0.5.0`).
**Source of work:** `docs/dev-log/handover/2026-07-15-parallel-lane-handover.md`.

## Scope

Executed the three **conflict-free** items from the handover's work menu while
Lane A's Totoro coverage grid runs. Deliberately excluded the blocked items
(1b–e shared-dispersion C++, Item 4 `ci_missing_rate` fix) because they touch
Lane-A-modified files and must wait for Lane A to commit (handover §1, mode B).

## Lane-boundary compliance (verified)

- No Lane-A-modified file was edited (`R/fit-multi.R`, `src/gllvmTMB.cpp`,
  `R/bootstrap-sigma.R`, `R/diagnose.R`, `R/extract-correlations.R`,
  `R/extract-sigma.R`, `R/predictive-diagnostics.R`, `dev/m3-grid.R`,
  `dev/m3-pilot-report.R`) — all read-only.
- No Totoro/HPC job launched; the coverage grid keeps its cores.
- Nothing merged. The grammar change is committed on an **isolated** branch only.
- New files landed in the main working tree as untracked additions; one existing
  tracked-but-not-Lane-A file (`docs/dev-log/check-log.md`) was appended to as the
  async coordination bus.

## Outcome

### Item 2 — doc-honesty review prep
New file: `docs/dev-log/2026-07-15-doc-honesty-review-checklist.md`.
Reviewed 32 reader-facing surfaces (18 articles + 14 honesty-sensitive exports).
Existing prose is already extensively and consistently fenced; **only 3 nbinom2
surfaces need new fencing**, all downstream of the same-day dispersion-confound
diagnosis that postdates the current text:
- **G1** `vignettes/articles/response-families.Rmd`
- **G2** `man/families.Rd`
- **G3** `man/extract_Sigma.Rd`

Each ships exact proposed wording grounded in
`docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`. Register-code-leak
scan (§2) clean. Maintainer decision queue (§6): QG animal-model cut-vs-keep
(PR #746), G1–G3 wording/placement, and sequencing vs Item 1.

### Item 1a — shared-dispersion design doc
New file: `docs/design/82-shared-dispersion.md`.
Designs `disp_group=` (top-level arg on `gllvmTMB()`, default `NULL` = current
per-trait behaviour) to pool NB2 dispersion phi and break the
dispersion-vs-latent-variance ridge.
- **Route A (recommended):** TMB `map=` parameter-tying — the mechanism
  `m3_refit_known_nbinom2_phi()` already uses — needs **zero `src/gllvmTMB.cpp`
  diff**, only R-side index construction in `R/fit-multi.R`. Route B (`DATA_IVECTOR`
  re-indexing) documented as the heavier fallback.
- Grounded in the mitigation-ladder numbers (default median Σ̂/truth ≈ 0.46–0.52
  flat; oracle known-phi 0.78→0.84 rising with n but **plateauing below 1.0** at
  n=800). Caveat surfaced: pooling phi should help but may not fully restore Σ
  recovery on its own — the un-fencing claim must be earned on a re-run ladder
  (D-43 default NOT-DONE), not asserted.
- **Implementation gated on Lane A committing** (`R/fit-multi.R` is a Lane-A file)
  and is an API/engine change requiring maintainer sign-off.

### Item 3 — bare `||` uncorrelated-slope grammar (B3)
Built on isolated branch `worktree-agent-a283d56f6868709e7` @ `13d73844`, then
**merged to `claude/release-0.5.0` @ `900c1af3`** via cherry-pick after maintainer
sign-off (see the "Maintainer decisions applied" update below). `R/brms-sugar.R`
+49 lines; new test
`tests/testthat/test-bare-or-uncorrelated-slope.R`.
- Enables `indep(1 + x || g)` → routed byte-identically to the existing unit-tier
  `diag_B_slope` engine (== `unique(1 + x | g)`). Design 79's `indep ||` cell.
- Keeps `latent(1 + x || g)` **failing loud**: its block-diagonal-Λ engine is
  unbuilt, and routing it to the correlated joint-Λ engine would mislabel the fit.
  The pre-existing generic abort guard was preserved, not defeated.
- Source-tier (`phylo_*`/`spatial_*`) and none-source `dep ||` handling untouched.

## Checks

- **Item 3 parse tests:** 14/14 pass.
- **Item 3 recovery (heavy, `GLLVMTMB_HEAVY_TESTS=1`):** fit converged
  (convergence 0, pdHess TRUE); recovered `sd_B_slope` (0.538, 0.441, 0.484,
  0.745) vs truth (0.60, 0.45, 0.50, 0.70); `cor_b` NULL. Full file 24/24 pass.
- **Item 3 regression:** `test-ordinary-latent-random-regression.R` 85 pass,
  `test-augmented-lhs-guard.R` 33 pass; `phylo_indep(1 + x || species)` and
  `dep(1 + x || g)` behaviour unchanged. No regressions.
- Items 2 and 1a are documents; no code executed beyond read-only inspection
  (incl. reading the ladder `.rds`).

## Follow-up / handoff

- **🔴 Needs Shinichi:** (a) sign-off to merge the Item 3 grammar change
  (`13d73844`); (b) approve G1–G3 fencing wording/placement; (c) QG animal-model
  cut-vs-keep call (PR #746).
- **Gated on Lane A committing:** implement Item 1a (`disp_group=`, Route A) and
  Item 4 (`ci_missing_rate` metric fix) — both touch Lane-A files.
- **Convergence:** if `disp_group=` lands and re-certifies nbinom2, fold the
  G1–G3 fencing into default-vs-opt-in wording rather than a blanket caveat.
- Coordination line posted to `docs/dev-log/check-log.md` for Lane A.

## Update — maintainer decisions applied (2026-07-15, same day)

Shinichi ruled on the three surfaced decisions; applied as follows.

1. **Merge Item 3 grammar → DONE.** Cherry-picked `13d73844` onto
   `claude/release-0.5.0` as `900c1af3` (not a fast-forward — the grammar branch
   forked from `main`, and the release branch was 2 doc-commits ahead; the
   intervening commits do not touch `R/brms-sugar.R`, so the pick is clean). Lane
   A's uncommitted diff was left fully intact.
2. **Approve G1–G3 nbinom2 fencing → G1 landed, G2/G3 deferred.**
   - **G1** applied to `vignettes/articles/response-families.Rmd` as a
     "Specialist boundary for `nbinom2()` with latent covariance" subsection
     (verbatim approved wording, heading harmonised to the sibling hurdle
     "Specialist boundary" pattern).
   - **G2 landed** (`bcb6d774`): its roxygen source `R/families.R` is **not** a
     Lane-A file, so it was hand-mirrored into `R/families.R` roxygen +
     `man/families.Rd` (Rd re-parsed OK; no global `document()`, so Lane A's
     uncommitted roxygen is untouched; next `document()` reproduces it verbatim).
   - **G3 deferred** (boundary necessity, not a reversal): its roxygen source is
     `R/extract-sigma.R`, a **Lane-A-modified file** — lands via a clean
     `document()` once Lane A commits.
3. **QG animal-model → cut, hidden, preserved (not deleted).** The article was
   already removed from the tree in `eacbd0f6` and absent from `_pkgdown.yml`
   articles. Per "do not delete", the verbatim last version
   (`3159c421:vignettes/articles/animal-model.Rmd`, byte-identical blob
   `925c9603`) was restored to `dev/retired-articles/animal-model.Rmd` (under
   `^dev$` in `.Rbuildignore` → not shipped, not rendered), with a
   `dev/retired-articles/README.md` recording status/provenance and confirming the
   `animal_*` exports stay discoverable via the reference index + keyword grid.

### Remaining deferred (still gated on Lane A committing)
- **G3 roxygen fence** — source `R/extract-sigma.R` is Lane-A-modified.
- **Item 1a `disp_group=` implementation** (Route A) and **Item 4 `ci_missing_rate`
  fix** — both touch Lane-A files.
- **Diagnostics breadth (S6)** and **slope-recovery evidence (S7)** — S6 touches
  `R/predictive-diagnostics.R` (Lane-A) and likely `src/`; S7 is live-TMB (Codex).
- A background monitor is armed to re-trigger the moment Lane A commits.
