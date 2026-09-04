# After Task: #1065 rebase + CI pins (stay planned)

**Branch**: `cursor/mspl-nbinom-admit-packet`
**Date**: `2026-08-17`
**Roles (engaged)**: Ada / Curie / Grace / Rose

## 1. Goal

Rebase #1065 onto latest `origin/main` and clear the two CI
failures (NB1 A7 penalty-off residual; D-phi `readLines` of
`src/gllvmTMB.cpp` under R CMD check) without flipping nbinom
registry rows to `admitted`.

## 2. Implemented

- Rebased onto `origin/main` @ `e22b8e96` (#1073). Conflict was
  `docs/dev-log/check-log.md` only.
- D-phi C++ comment pin no longer uses cwd-relative `../../src`
  or `system.file("..", "src", ...)`. Missing source now
  `skip_if(length(found) == 0L)` instead of `readLines` on `""`
  / a missing path. R-side D-phi pins stay in their own test.
- NB1 A7 fixture remains the 12-site designed-OD cell from the
  prior tip (max 4; trait-2 overdispersed).
- Registry stays `planned` / `phase4_prep`. No public `se`.
  No NEWS `covered`.

## 3. Files Changed

- `tests/testthat/test-mspl-nbinom2-admit-packet.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-17-mspl-nbinom-admit-packet-ci-fix.md`

Prior packet files (`R/mspl-nbinom*-atoms.R`, `src/gllvmTMB.cpp`,
NB1 packet test, research note) are unchanged in this sitting.

## 3a. Decisions and Rejected Alternatives

**Decision:** skip, do not error, when `gllvmTMB.cpp` is absent
under R CMD check. **Rationale:** the tarball test tree has no
`src/`; the science pin is the R-side Jacobian / quasi refuse.
**Rejected:** keep cwd-relative `../../src` (CI opened that path
and failed). **Confidence:** high.

**Decision:** keep the live A7 twins. **Rationale:** #1065 is the
C++ / live-twin packet; #1070 is the Pure-R-only pin.
**Rejected:** drop A7 to match #1070. **Confidence:** high.

## 4. Checks Run

```sh
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-mspl-nbinom1-admit-packet.R")'
# FAIL 0 | SKIP 0 | PASS 41
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-mspl-nbinom2-admit-packet.R")'
# FAIL 0 | SKIP 0 | PASS 51
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-mspl-nb1-fenced-tape.R"); testthat::test_file("tests/testthat/test-mspl-nb2-fenced-tape.R"); testthat::test_file("tests/testthat/test-mspl-registry.R")'
# fence 17+18; registry 81
rg 'status\s*=\s*"admitted"' R/mspl-registry.R
# nbinom blocks stay status = "planned"
rg 'NB2 Jeffreys-on-phi DROPPED' src/gllvmTMB.cpp
```

Deliberately not run: `--as-cran`, pkgdown, Totoro.

## 5. Tests of the Tests

- D-phi R-side still fails if `I_logφ ≠ φ² I_φφ` or if quasi
  `0.5 (μ/(μ+φ))²` is accepted.
- D-phi C++ test skips (does not error) when no regular
  `gllvmTMB.cpp` is on the `test_path` / `00_pkg_src` list.
- A7 still rejects `c=1`, `c_P`, Bernoulli V, and Poisson ybar V;
  registry A8 still fails if status is `admitted`.

## 6. Consistency Audit

```
rg 'status\s*=\s*"admitted"' R/mspl-registry.R
# nbinom1/2 ordinary cells remain planned
rg 'NEWS covered|public se=TRUE' docs/dev-log/after-task/2026-08-16-mspl-nbinom-admit-packet.md docs/dev-log/research/2026-08-16-mspl-nbinom-admit-packet.md
# no covered / public-se claim
```

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No relevant open issue; this is CI repair of
[#1065](https://github.com/itchyshin/gllvmTMB/pull/1065).
[#1070](https://github.com/itchyshin/gllvmTMB/pull/1070) remains
the Pure-R-only pin and is not merged here.

## 8. What Did Not Go Smoothly

The first CI run failed on the original 8-site / max-6 NB1 cell
(`residual -4.78e-6` vs `tol 3.71e-6`) and on an inline
`readLines('../../src/gllvmTMB.cpp')` under the tarball. The
cwd-relative candidate list looked like a skip and was not.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Grace:** R CMD check has no `src/` at `../../src` from
`tests/testthat`. `skip_if(is.na(path[1L]))` is not enough when
`file.exists` is true for a cwd-relative miss that `readLines`
cannot open. Use `length(found) == 0L` and only `test_path` /
`00_pkg_src`.

**Curie:** A7 live twins need `|obj|` slack for
`1e-7*(1+|obj|)` on ubuntu; a max-3 regular pattern collapses
Ibar onto ybar and voids the V-gap pins.

**Rose:** check-log rebase conflicts are expected; keep both
entries. Do not flip `planned` in the same sitting as a CI pin.

**Ada:** registry stays planned. #1070 is a later/parallel
Pure-R pin, not a licence to admit.

## 10. Known Limitations And Next Actions

nbinom1/2 remain `planned` / `phase4_prep`. No public SE. No
admit. Merge #1065 only when 3-OS CI is green. Do not force-push
`main`.
