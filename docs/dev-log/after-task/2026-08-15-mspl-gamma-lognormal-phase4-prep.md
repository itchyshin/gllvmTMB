# After-task: MSPL Gamma(log) + lognormal(log) Phase-4-style prep (planned only)

**Date:** 2026-08-15
**Lane:** `cursor/mspl-phase4-gamma-lognormal`
**Worktree:** `/tmp/gllvmtmb-mspl-gamma-lnorm`
**Roles (engaged):** Ada / Noether / Curie / Rose / Shannon

## 1. Goal

Land planned-only LA-MSPL Phase-4-*style* prep for Gamma(log) and
lognormal(log) on a fresh worktree from `origin/main`. Not
admission.

## 2. Implemented

- Derivation notes pin Gamma \(W=\phi_{\gamma}\) (mean-inert) and
  lognormal \(W=1/\sigma_{\varepsilon}^2\) on \(\log y\), with
  \(\mathrm{E}[Y]=\mathrm{e}^{\eta+\sigma^2/2}\).
- Pure-R oracles E1–E10 + prepare-fence source pins.
- Registry rows `gamma:log:ordinary:q1/q2` and
  `lognormal:log:ordinary:q1/q2` are `status = "planned"`,
  `evidence = "phase4_prep"`. **Not** `admitted`.
- `.gllvmTMB_mspl_family_link_name()` now returns `"log"` for
  `family_id` 3 and 4 (was falling through to Bernoulli `"logit"`).

No C++ tape. No prepare widen. No NEWS. No public `se=TRUE`.
`R/mspl.R`, `R/fit-multi.R`, and `R/mspl-curvature-pin.R` untouched.

## 3. Files Changed

- `R/mspl-registry.R`
- `tests/testthat/test-mspl-registry.R`
- `tests/testthat/test-mspl-gamma-phase4-oracles.R`
- `tests/testthat/test-mspl-lognormal-phase4-oracles.R`
- `docs/dev-log/research/2026-08-15-mspl-phase4-gamma-prep.md`
- `docs/dev-log/research/2026-08-15-mspl-phase4-lognormal-prep.md`
- `docs/dev-log/lanes/cursor-mspl-phase4-gamma-lognormal/LOOP/`
- `docs/dev-log/after-task/2026-08-15-mspl-gamma-lognormal-phase4-prep.md` (this file)
- `docs/dev-log/check-log.md`

Not touched: `src/`, `R/mspl.R`, `R/fit-multi.R`,
`R/mspl-curvature-pin.R`, NEWS, README, ROADMAP, repo-root `LOOP/`,
Poisson admit tests, Dropbox, shared worktree
`/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** add `planned` registry rows (user contract), unlike
  Tweedie/Beta siblings that stay paper-planned with no row.
  **Rejected:** flipping `admitted`, or omitting rows because
  Gamma/lognormal are not in the constitution’s Phase-4 Poisson/NB
  queue. **Confidence:** high — the rows say `planned` / not covered.
- **Decision:** two oracle files, not one combined file.
  **Rationale:** sibling style is one family per file; the atoms
  differ. **Confidence:** high.
- **Rejected:** widening `.gllvmTMB_mspl_prepare()` to `family_id`
  3 or 4, or adding GLM-outer weights in `src/`.

## 4. Checks Run

```sh
# Isolated worktree from origin/main
git worktree add -b cursor/mspl-phase4-gamma-lognormal \
  /tmp/gllvmtmb-mspl-gamma-lnorm origin/main
# HEAD fe867e40

export OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = FALSE)

# RED (before registry rows):
#   test-mspl-gamma-phase4-oracles.R
#     E9: nrow(g) >= 2L failed (0 < 2); lookups NULL
#   test-mspl-lognormal-phase4-oracles.R
#     E10: nrow(ln) >= 2L failed (0 < 2); lookups NULL
#   E1–E8 / no-live / prepare-fence already green

# GREEN (after planned rows):
testthat::test_file("tests/testthat/test-mspl-gamma-phase4-oracles.R")
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 70 ]
testthat::test_file("tests/testthat/test-mspl-lognormal-phase4-oracles.R")
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 66 ]
testthat::test_file("tests/testthat/test-mspl-registry.R")
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 34 ]
git diff --stat -- src/ R/mspl.R R/fit-multi.R NEWS.md
# empty
```

Structured oracle PASS counts (expectations per test):

| ID / test | passed | failed |
|---|---:|---:|
| Gamma E1 \(W=\phi\) vs Poisson / Bernoulli / Tweedie-\(p=2\) | 7 | 0 |
| Gamma E2 mean path inert | 6 | 0 |
| Gamma E3 \(\phi\to 0\) / \(\phi\to\infty\) + log-det | 7 | 0 |
| Gamma E4 \(I_{\phi\phi}=\psi'(\phi)-1/\phi\) | 10 | 0 |
| Gamma E5 size \(n\phi\), not \(\sum\mu\) | 6 | 0 |
| Gamma E6 no mass at zero | 5 | 0 |
| Gamma E7 Hirose refused | 5 | 0 |
| Gamma E8 \(V_{\mathrm{loading}}\) inert | 5 | 0 |
| Gamma E9 planned, not admitted | 12 | 0 |
| Gamma E10 no live MSPL | 3 | 0 |
| Gamma prepare fence not 4 | 4 | 0 |
| Lognormal E1 \(W=1/\sigma^2\) | 6 | 0 |
| Lognormal E2 \(\mathrm{E}[Y]=\mathrm{e}^{\eta+\sigma^2/2}\) | 6 | 0 |
| Lognormal E3 \(\sigma\to\infty\) / \(\sigma\to 0\) | 7 | 0 |
| Lognormal E4 Jacobian + \(I_{\sigma}\) | 6 | 0 |
| Lognormal E5 size \(n/\sigma^2\) | 5 | 0 |
| Lognormal E6 no mass at zero; not delta | 5 | 0 |
| Lognormal E7 shared \(\sigma_{\varepsilon}\) ≠ Gaussian-on-\(y\) | 4 | 0 |
| Lognormal E8 Hirose refused | 5 | 0 |
| Lognormal E9 \(V_{\mathrm{loading}}\) inert | 4 | 0 |
| Lognormal E10 planned, not admitted | 11 | 0 |
| Lognormal no live MSPL | 3 | 0 |
| Lognormal prepare fence not 3 | 4 | 0 |
| Registry (existing + new planned pins) | 34 | 0 |
| **oracle files total** | **136** | **0** |

`load_all(..., compile = FALSE)` printed a DLL-load warning; oracles
are pure R and did not need the compiled tape.

Not run: `devtools::test()`, `R CMD check`, pkgdown, Totoro.

## 5. Tests of the Tests

- **Failure-before-fix:** E9/E10 lookups were `NULL` on
  `origin/main` before the planned rows landed. That is the
  registry contract.
- **Wrong-atom failures:** Gamma E2 would fail if \(W\) used
  \(\mu\); E3’s log-det identity would fail if the atom used
  \(\operatorname{tr}(W)\) alone. Lognormal E2 would fail if
  \(\mathrm{E}[Y]\) were coded as \(\mathrm{e}^{\eta}\).
- **Prepare source pin:** would fail if
  `fam_ids %in% c(0L, 1L, 2L, 3L)` or `4L` landed.
- **No-live scan:** would fail if this file called
  `estimator = "mspl"`.

## 6. Consistency Audit

```sh
rg -n 'status = "admitted"' R/mspl-registry.R
# Verdict: only pre-existing binomial / gaussian rows; gamma and
# lognormal rows are status = "planned".

rg -n 'fam_ids %in%' R/mspl.R
# Verdict: still c(0L, 1L, 2L). Not widened.

rg -n 'estimator = .mspl.|se = TRUE' \
  tests/testthat/test-mspl-gamma-phase4-oracles.R \
  tests/testthat/test-mspl-lognormal-phase4-oracles.R
# Verdict: no live MSPL; no se=TRUE.

git diff --stat -- src/ R/mspl.R R/fit-multi.R NEWS.md
# Verdict: empty.
```

User-facing stale-wording patterns were not re-run on
README/NEWS/vignettes: this PR does not touch those surfaces.

## 7. Roadmap Tick

N/A — planned prep; no `ROADMAP.md` row.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created.

## 8. What Did Not Go Smoothly

`move_agent_to_root` is blocked for subagents, so edits used
absolute paths under `/tmp/gllvmtmb-mspl-gamma-lnorm`. A lane-check
warning named `origin/cursor/mspl-phase4-tapes-planned` on
`R/mspl-registry.R`; `git diff HEAD..that-ref -- R/mspl-registry.R`
was empty (already on `origin/main`), so this lane added Gamma /
lognormal rows additively.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Isolated worktree from `origin/main` @ `fe867e40`, not
Dropbox and not the shared MSPL worktree. Finish line is a DRAFT
PR, not merge.

**Noether.** Load-bearing identities: Gamma
\(I(\beta)=\phi X^\top X\) (mean-inert) and lognormal
\(\mathrm{E}[Y]=\mathrm{e}^{\eta+\sigma^2/2}\) with
\(I(\beta)=X^\top X/\sigma_{\varepsilon}^2\) on \(\log y\).

**Curie.** Oracles stay pure R. RED was the missing registry
lookups; GREEN is 70 + 66 + 34.

**Rose.** `planned` ≠ `admitted`. Prepare fence unchanged. LOOP
lives under the lane folder, not repo-root.

**Shannon.** Owned paths only. Did not edit Poisson-admit or SE
sibling files.

## 10. Known Limitations And Next Actions

- Loading-atom coercivity under Laplace: **OPEN** for both families.
- Soft rate \(c\): **OPEN**.
- Shared `sigma_eps` composition with Gaussian: **OPEN**.
- No tape, no healthy/boundary DGP, no admit.
- **HARD STOP / OPEN GATE:** Shinichi before any `admitted` flip,
  C++ tape, prepare widen, NEWS covered, or public `se=TRUE`.
  Do not merge this PR as admission.

## Mathematical contract

No public API / likelihood / grammar / family change. Science is
the two notes: Gamma \(I(\beta_*)=\phi_{\gamma} X_*^\top X_*\);
lognormal \(I(\beta_*)=\sigma_{\varepsilon}^{-2} X_*^\top X_*\)
on \(\log y\), Jacobian \(-\log y\) parameter-free.
