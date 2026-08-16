# After-task: Gamma / lognormal MSPL door gap list (draft only)

**Date:** 2026-08-16
**Lane:** `cursor/mspl-gamma-lognormal-door-gap`
**Worktree:** `/private/tmp/gllvmtmb-mspl-gamma-lnorm-door-gap`
**Roles (engaged):** Ada / Noether / Rose / Shannon

## 1. Goal

SE-arc speed-up track 4 asked for a fenced planned door + C++
GLM-outer tape so `#1000` can drop its Gamma / lognormal
`skip_if`, mirroring nbinom `#1007`, **if** Phase-4 oracles were
scientifically ready. Otherwise open a draft with the
oracles→door gap list only. Prefer draft if the tape is
speculative.

## 2. Implemented

The tape is speculative. This sitting writes the gap list and
stops.

`#1003` already landed `planned` / `phase4_prep` rows. Prepare
still rejects `family_id` 3 and 4. `gll_mspl_log_weight_glm()`
still errors on both fids. Soft rate \(c\) and the loading atom
are OPEN on both prep notes. A `#1007` mirror would inherit
unpinned \(c=1\) and Bernoulli \(V_{\mathrm{loading}}\), which
those notes kill.

No prepare widen. No `src/`. No admit. No NEWS. No public
`se=TRUE`. `#1000` still skips.

## 3. Files Changed

- `docs/dev-log/research/2026-08-16-mspl-gamma-lognormal-door-gap.md`
- `docs/dev-log/after-task/2026-08-16-mspl-gamma-lognormal-door-gap.md` (this file)
- `docs/dev-log/check-log.md`

Not touched: `src/`, `R/mspl.R`, `R/mspl-registry.R`,
`R/mspl-curvature-pin.R`, `R/fit-multi.R`, NEWS, README,
ROADMAP, repo-root `LOOP/`, `#1000` test file, Dropbox, the
shared dirty worktree
`/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** draft gap list, not a `#1007` door+tape.
  **Rationale:** `#1007` added no `src/` because nbinom weights
  already existed; Gamma / lognormal weights do not, and rate /
  loading remain OPEN. **Rejected:** implement \(W=\phi\) /
  \(W=1/\sigma^2\) plus inherited \(c=1\) and Bernoulli radial
  so `#1000` can run. **Confidence:** high — both prep notes
  name that path as a kill-list transplant.
- **Decision:** do not retarget oracle E10 or the `#1026`
  prepare-fence test. **Rationale:** those pins are correct
  while the door stays closed. **Confidence:** high.

## 4. Checks Run

```sh
git rev-parse --short HEAD
# 55666f1e  (origin/main after #1041)

rg -n 'fam_ids %in%' R/mspl.R
# R/mspl.R:229: fam_ids %in% c(0L, 1L, 2L, 5L, 15L)

rg -n 'No prepare widen|No C\+\+ tape' R/mspl-registry.R
# R/mspl-registry.R:194: prep only. NOT admitted. No prepare widen. No C++ tape.

rg -n 'family_id == 3|family_id == 4|unknown family_id' src/gllvmTMB.cpp
# weight helper: unknown family_id at the GLM-outer error; no fid 3/4 branch

rg -n 'estimator = .mspl.|se = TRUE' \
  tests/testthat/test-mspl-gamma-phase4-oracles.R \
  tests/testthat/test-mspl-lognormal-phase4-oracles.R
# no live MSPL; no se=TRUE

git diff --stat -- src/ R/mspl.R R/mspl-registry.R R/fit-multi.R NEWS.md
# empty
```

Not run: `devtools::test()`, `R CMD check`, pkgdown, Totoro.
Docs-only; no compile.

## 5. Tests of the Tests

No new tests. Prophylactic: the existing Gamma E10 / lognormal
E10 prepare pins would FAIL if this draft had widened
`fam_ids` to 3 or 4. They stay green because it did not.

## 6. Consistency Audit

```sh
rg -n 'status = "admitted"' R/mspl-registry.R
# Verdict: gamma / lognormal rows remain status = "planned".

rg -n 'fam_ids %in%' R/mspl.R
# Verdict: still c(0L, 1L, 2L, 5L, 15L). Not 3 or 4.

rg -n 'NEWS covered|admitted' \
  docs/dev-log/research/2026-08-16-mspl-gamma-lognormal-door-gap.md
# Verdict: only fence / non-claim language.

git diff --stat -- src/ R/ NEWS.md
# Verdict: empty.
```

## 7. Roadmap Tick

N/A — draft gap list; no `ROADMAP.md` row.

## 7a. GitHub Issue Ledger

Inspected `#1000` (rest-family SE pins, merged; Gamma / lognormal
still `skip_if`), `#1003` (planned rows, merged), `#1007`
(nbinom planned door, merged; no `src/`). No issue closed. No
new issue. This draft is the track-4 deliverable.

## 8. What Did Not Go Smoothly

`move_agent_to_root` is blocked for subagents, so the isolated
worktree was edited by absolute path. The parent shared
worktree stayed on `cursor/mspl-poisson-admit-packet` and was
not mutated.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Isolated worktree from `origin/main` @ `55666f1e`.
Finish line is a DRAFT PR, not a door.

**Noether.** Load-bearing gap: weights \(W=\phi_\gamma\) and
\(W=1/\sigma_\varepsilon^2\) are oracle-READY; \(c\) and
\(V_{\mathrm{loading}}\) are OPEN. Inheriting nbinom defaults
is a transplant, not a `#1007` replay.

**Rose.** `planned` ≠ door ≠ `admitted`. `#1000` skip stays.

**Shannon.** Owned paths only. Did not edit `#1045` / `#1047`
siblings or the dirty Poisson-admit tree.

## 10. Known Limitations And Next Actions

- `#1000` Gamma / lognormal live pins remain SKIP.
- Soft rate, loading atom, shape/residual atom, shared
  \(\sigma_\varepsilon\), and Laplace-marginal \(I(\beta)\)
  stay OPEN.
- **HARD STOP / OPEN GATE:** Shinichi before any prepare
  widen, `src/` tape, `#1000` un-skip, `admitted` flip, NEWS
  covered, or public `se=TRUE`. Do not merge this PR as a
  door.

## Mathematical contract

No public API / likelihood / grammar / family change. Science
stays in the `#1003` notes: Gamma
\(I(\beta_*)=\phi_\gamma X_*^\top X_*\); lognormal
\(I(\beta_*)=\sigma_\varepsilon^{-2} X_*^\top X_*\) on
\(\log y\). This sitting adds the door-gap, not a tape.
