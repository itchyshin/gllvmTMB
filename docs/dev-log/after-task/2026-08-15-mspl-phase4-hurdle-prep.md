# After Task: MSPL delta/hurdle Phase-4 prep (planned only)

**Branch**: `cursor/mspl-phase4-hurdle`
**Date**: `2026-08-15`
**Worktree**: `/tmp/gllvmtmb-mspl-hurdle`
**Roles (engaged)**: Ada / Curie / Rose / Noether

## 1. Goal

Land planned-only LA-MSPL Phase-4-*style* prep for
`delta_lognormal` and `delta_gamma`: shared-η research note,
pure-R oracles, and `planned` registry rows. Not admission. No
public estimator door.

## 2. Implemented

- Research note
  `docs/dev-log/research/2026-08-15-mspl-phase4-hurdle-prep.md`
  pins \(W=\pi(1-\pi)+\pi/\sigma^2\) (lognormal) and
  \(W=\pi(1-\pi)+\pi/\varphi^2\) (Gamma) on one shared η.
  All-zero is coercive; all-positive is finite (unlike Bernoulli);
  dispersion collapse rewards \(P^*_{\mathrm{J}}\).
- Oracles
  `tests/testthat/test-mspl-hurdle-phase4-oracles.R` (E1–E10 +
  no-live; **66/66 PASS**).
- Registry: four ordinary q1/q2 rows
  `delta_lognormal:log:ordinary:q{1,2}` and
  `delta_gamma:log:ordinary:q{1,2}` → `status="planned"`,
  `evidence="phase4_prep"`. Notes say no public door / not
  admitted / not covered.
- Companion test updates so planned-family counts include hurdle
  without flipping Gaussian or Poisson status.
- Lane LOOP kit under
  `docs/dev-log/lanes/cursor-mspl-phase4-hurdle/LOOP/`.

## 3. Files Changed

- `docs/dev-log/research/2026-08-15-mspl-phase4-hurdle-prep.md` (new)
- `tests/testthat/test-mspl-hurdle-phase4-oracles.R` (new)
- `R/mspl-registry.R` (planned hurdle rows only)
- `tests/testthat/test-mspl-registry.R` (planned count 2 → 6)
- `tests/testthat/test-mspl-gaussian-heywood-oracles.R` (planned-family allow-list)
- `docs/dev-log/lanes/cursor-mspl-phase4-hurdle/LOOP/{GOAL,arcs,checkpoint,ultra-plan}.md`
- this after-task

Not touched: `src/`, `R/mspl.R`, NEWS, repo-root `LOOP/`,
validation-register, Dropbox, the shared
`/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` tree.

## 3a. Decisions and Rejected Alternatives

Decision: add `planned` rows and leave the public door closed
(`family_id %in% {0,1,2}`). Rationale: board was na; parent
asked for planned registry rows plus “no public estimator door.”
Rejected: Tweedie-style paper-only (no row) — that would leave
the board na. Rejected: widening prepare to fid 12/13 — that
would open a door the C++ GLM-outer hook cannot serve
(`unknown family_id`).

## 4. Checks Run

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = FALSE, quiet = TRUE)
testthat::test_file("tests/testthat/test-mspl-hurdle-phase4-oracles.R")
# FAIL 0 | WARN 0 | SKIP 0 | PASS 66
testthat::test_file("tests/testthat/test-mspl-registry.R")
# FAIL 0 | WARN 0 | SKIP 0 | PASS 35
testthat::test_file("tests/testthat/test-mspl-gaussian-heywood-oracles.R")
# FAIL 0 | WARN 0 | SKIP 0 | PASS 75
testthat::test_file("tests/testthat/test-mspl-poisson-phase4-oracles.R")
# FAIL 0 | WARN 0 | SKIP 0 | PASS 42
testthat::test_file("tests/testthat/test-mspl-fenced-family-tapes.R")
# FAIL 0 | WARN 0 | SKIP 0 | PASS 23
git diff --stat -- src/ R/mspl.R NEWS.md
# empty
```

### Structured counts (hurdle oracles)

| Block | Expectations |
|---|---|
| E1 combined \(W\) vs Bernoulli / Poisson | 8 |
| E2 all-zero \(P^*_{\mathrm{J}}\to-\infty\) | 7 |
| E3 all-positive hurdle finite; Bernoulli diverges | 6 |
| E4 lognormal ≠ Gamma | 4 |
| E5 matched \(\Pr(Y=0)\) ≠ shared η / \(W\) | 5 |
| E6 \(\kappa\to\infty\) collapses to Bernoulli-only | 2 |
| E7 \(\kappa\to 0\) rewards \(P^*_{\mathrm{J}}\) | 6 |
| E8 Hirose refused | 3 |
| E9 \(V_{\mathrm{loading}}\) inert | 5 |
| E10 planned / not admitted / prepare `{0,1,2}` | 17 |
| no live MSPL | 3 |
| **Total** | **66/66 PASS** (11 `test_that`) |

Not run: `devtools::test()`, `R CMD check`, hurdle
`estimator="mspl"` fit.

## 5. Tests of the Tests

Prophylactic oracles (no production defect). E3 would fail if
Bernoulli \(W_g\) were reused as a “coercive at \(\pi\to 1\)”
hurdle atom. E5 would fail if matched zeros were treated as a
shared η. E10 would fail if a row flipped to `admitted` or if
prepare gained `12L`/`13L`. The no-live block would fail if this
file called `estimator = "mspl"`.

## 6. Consistency Audit

```
rg -n "estimator\\s*=\\s*[\"']mspl[\"']" tests/testthat/test-mspl-hurdle-phase4-oracles.R
# no match
rg -n "fam_ids %in%" R/mspl.R
# family_id %in% c(0L, 1L, 2L) only
rg -n "status = \"admitted\"" R/mspl-registry.R
# binomial + gaussian only; hurdle rows are status = "planned"
ls -d LOOP  # pre-existing 0.6 kit on main; this lane did not write it
```

Verdict: planned-only; no prepare widen; no NEWS covered.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is planned-only
prep from `origin/main`.

## 8. What Did Not Go Smoothly

`pkgload::load_all(..., compile = FALSE)` warned about a DLL
registration miss; tests still ran against the checkout R sources
and passed. No compile was requested (no `src/` edit).

## 9. Team Learning

**Ada.** Isolated `/tmp` worktree from `origin/main`; explicit
paths; draft PR only.
**Noether.** Shared-η is the load-bearing fact: occurrence logit
and positive mean are one coordinate. Design 02’s FE-only
occurrence note is a correlation contract, not a second η.
**Curie.** Structured counts are 11 blocks / 66 expectations, not
an exit code.
**Rose.** `planned` ≠ `admitted`; prepare stays `{0,1,2}`; no
NEWS covered; no repo-root `LOOP/` write; no shared-tree edit.

## 10. Known Limitations And Next Actions

All-positive path is **not** a Jeffreys repair (E3). Dispersion
collapse has the **wrong sign** (E7). Loading / rate /
Laplace-marginal \(I(\beta)\) remain OPEN. Human merge only.
HARD STOP: admit, prepare widen to 12/13, C++, SE, NEWS covered.
