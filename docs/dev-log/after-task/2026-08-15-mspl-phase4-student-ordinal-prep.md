# After-task: MSPL Student-t + ordinal_probit Phase-4 prep (planned only)

**Date:** 2026-08-15
**Lane:** `cursor/mspl-phase4-student-ordinal`
**Worktree:** `/tmp/gllvmtmb-mspl-student-ordinal`
**Branch:** `cursor/mspl-phase4-student-ordinal` from `origin/main` @ `fe867e40`
**PR:** https://github.com/itchyshin/gllvmTMB/pull/1005 (DRAFT; not admitted)
**Arc:** A0–A3

## 1. Goal

Move Student-t (identity) and `ordinal_probit` from **na** on the
Phase-4 board to **planned prep only**: family-specific derivation
notes and failing-then-green pure-R oracles. Not admission. No
registry row. No public door. No NEWS covered. `se=FALSE`.

## 2. Implemented

- Research notes
  `docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md`
  (location weight \(\mu\)-inert; \(\sigma\to 0\) anti-coercive;
  TMB \(\nu=1+\exp(\texttt{log\_df})\)) and
  `docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md`
  (exact \(K\)-category \(I_\eta\); location vs cut-collision vs
  cut-infinity; residual pinned at 1).
- Oracles
  `tests/testthat/test-mspl-student-phase4-oracles.R` (S1–S12 +
  live-fit fence) and
  `tests/testthat/test-mspl-ordinal-phase4-oracles.R` (O1–O11 +
  live-fit fence).
- LOOP under `docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/`.
- `R/mspl.R`, `src/`, `.gllvmTMB_mspl_prepare()`, and
  `R/mspl-registry.R` untouched.

## 3. Files Changed

- `docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md` (new)
- `docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md` (new)
- `tests/testthat/test-mspl-student-phase4-oracles.R` (new)
- `tests/testthat/test-mspl-ordinal-phase4-oracles.R` (new)
- `docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/` (new)
- this after-task; Melissa plan-actual; check-log; lane-split row;
  handover `docs/dev-log/handover/2026-08-15-cursor-handover-phase4-student-ordinal.md`

No NEWS. No `man/*.Rd`. No ROADMAP tick. No `docs/design/117`.
No `R/` or `src/` edits.

## 3a. Decisions and Rejected Alternatives

- **Decision:** no registry `planned` row (same as nbinom1 / beta /
  Tweedie prep; unlike Poisson, which already has a fenced tape).
- **Rationale:** `test-mspl-registry.R` freezes `planned` as Poisson
  only; a row without a tape would look like admission-shaped
  progress.
- **Rejected:** public `estimator="mspl"` door; Hirose-on-\(\sigma\);
  Bernoulli \(V_{\mathrm{loading}}\) transplant; treating ordinal
  as stacked Bernoulli.
- **Confidence:** high on the fence; the location Student-t atom is
  explicitly *not* a later-admission candidate.

## 4. Checks Run

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = FALSE)
# RED (helpers missing): could not find function .st_fixture / .ord_fixture
testthat::test_file("tests/testthat/test-mspl-student-phase4-oracles.R")
# GREEN PASS 51 / 13 blocks
testthat::test_file("tests/testthat/test-mspl-ordinal-phase4-oracles.R")
# GREEN PASS 45 / 12 blocks
testthat::test_file("tests/testthat/test-mspl-registry.R")
# PASS 26 (untouched)
git diff --stat -- src/ R/mspl.R R/mspl-registry.R
# empty
```

| Family | n |
|---|---|
| Student S1–S12 + fence | 51 |
| ordinal O1–O11 + fence | 45 |
| registry (untouched) | 26 |

## 5. Tests of the Tests

- **Failure-before-fix:** both files were run with helpers absent;
  every science block errored `could not find function`.
- **Boundary:** Student S4/S5/S6/S7; ordinal O3/O4/O5/O7.
- **Feature-combination:** S12/O11 pin lookup `NULL` against the
  live registry; live-fit fences scan their own source.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `rg -n "status = \"admitted\"" R/mspl-registry.R` | unchanged; no student/ordinal row |
| `rg -n "estimator\\s*=\\s*[\"']mspl[\"']" tests/testthat/test-mspl-student-phase4-oracles.R tests/testthat/test-mspl-ordinal-phase4-oracles.R` | fence-only (negated expects) |
| `rg -n "NEWS covered\\|admitted" docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md` | FAIL/kill-list language only |
| `git diff -- src/ R/mspl.R R/mspl-registry.R NEWS.md` | empty |

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is planned-only
prep from `origin/main`, sibling in spirit to #973–#976.

## 8. What Did Not Go Smoothly

Ordinal O3’s first positive-intercept step was flat because
\(\tau\in\{0,1,2\}\) makes \(\mathcal I_\eta(\eta)=\mathcal I_\eta(\eta+2)\)
near the fixture. O5’s tail hit exact zero so `diff < 0` failed.
Both assertions were tightened to the actual tail claim. Student
needed no repair.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Isolated worktree from `origin/main`; explicit-path commit;
DRAFT PR; merge is human.

**Noether.** Student location weight is \(\mu\)-inert and
anti-coercive as \(\sigma\to 0\); TMB \(\nu=1+\exp\) is not Design
03’s \(2+\exp\). Ordinal \(I_\eta\) is a finite \(K\)-sum, not
Bernoulli \(W_g\).

**Gauss.** Helpers stay in the test files; no `src/` tape; loglik
matches `dt((y-μ)/σ,ν,log)-log(σ)`.

**Curie.** RED then GREEN; structured counts from the log, not the
exit code.

**Rose.** No NEWS covered, no registry row, no public door, no
repo-root `LOOP/`, no `git add -A`.

**Shannon.** Pre-edit `gh pr list` showed #972–#976 still open and
#978 already on `main`; this lane does not stack on those PRs’
unmerged science.

## 10. Known Limitations And Next Actions

- No C++ tape; no `estimator="mspl"` on either family.
- **OPEN GATE:** Shinichi before any later `planned` row or admit.
  Merge is human, not this lane.
- Student later-admission candidate is **not** the location
  Jeffreys atom. Ordinal location atom is a candidate only; cut
  and loading atoms remain OPEN.

## Mathematical Contract

No public API / likelihood / grammar / family change. Oracles pin
already-wired Student-t `dt` / `1+exp(log_df)` and ordinal
\(\tau_1=0\) log-increment cuts with residual sd 1.

## Non-claims / OPEN GATE

- No C++ tape; no live MSPL on either family; no NEWS covered.
- **No student or ordinal_probit registry row** (S12 / O11 pin
  lookup `NULL`).
- **OPEN GATE:** Shinichi before any later `planned` row or admit.
