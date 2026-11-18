# After Task: Poisson / Tweedie / nbinom W one-sidedness audit

**Branch**: `cursor/mspl-W-onesided-audit`
**Date**: `2026-08-16`
**Roles (engaged)**: Ranga / Fisher / Curie / Rose / Gauss
**Workspace**: `/private/tmp/gllvmtmb-mspl-w-onesided-audit`

## 1. Goal

Document Ranga's red flag: live Poisson MSPL still uses GLM-outer
\(W=\operatorname{diag}(\mu)\), which is one-sided and an existence
risk for soft Jeffreys. Measure \(W\to 0\) vs \(\|\beta\|\) on a toy
cell. Audit Tweedie true-W one-sidedness (already known) and nbinom
saturation in the same note. Do **not** replace the tape (Shinichi
G0). No door, no admit, no `se=TRUE`.

## 2. Implemented

- Research note
  `docs/dev-log/research/2026-08-16-mspl-W-onesided-audit.md`
  cites Ranga: \(Q_0\) is the reporting target; \(W_*\) must be
  settled before more SE-series doors.
- Pure-R oracles W1–W8 in
  `tests/testthat/test-mspl-W-onesided-oracles.R` pin the \(+\infty\)
  path that Phase-4 E2 tests never measured.
- Toy-cell numbers: Poisson \(P_J\) rises \(+4\) per \(+4\) in the
  intercept (\(-6.84\) at \(\beta_0=-8\), \(+9.16\) at \(+8\));
  working \(W_*\) is symmetric (\(-6.84\) at both ends); nbinom2
  saturates (\(W/\varphi\to 1\), \(P_J\) stuck near \(1.84\)).
- C++ source pins: Poisson still `return eta`; Tweedie live tape
  already `gll_mspl_log_weight(eta, 0)`; NB2 still
  \(W=\mu\varphi/(\varphi+\mu)\).

No `src/` edit. No registry flip. No public door.

## 3. Files Changed

- `docs/dev-log/research/2026-08-16-mspl-W-onesided-audit.md` (new)
- `tests/testthat/test-mspl-W-onesided-oracles.R` (new)
- `docs/dev-log/after-task/2026-08-16-mspl-W-onesided-audit.md` (this file)
- `docs/dev-log/check-log.md` (prepend)

No `R/`, `src/`, NEWS, register `covered`, or prepare-fence change.

## 3a. Decisions and Rejected Alternatives

- **Decision:** document, do not replace Poisson \(W=\mu\).
  **Rationale:** tape replace needs Shinichi G0; Tweedie already
  moved to \(W_*\) under a separate hang slice. **Rejected:**
  overnight `return gll_mspl_log_weight(eta, 0)` on family 2.
  **Confidence:** high.
- **Decision:** add the \(+\infty\) toy measurement. **Rationale:**
  existing E2 oracles only pin \(\beta\to-\infty\). **Rejected:**
  note-only PR with no new test. **Confidence:** high.
- **Decision:** park further SE-series doors until G0 chooses keep
  or replace. **Rationale:** Ranga — \(Q_0\) is the reporting
  target; a pin on a one-sided atom reports curvature of an
  estimator whose existence is open. **Rejected:** open another
  nbinom / Tweedie / rest-family SE door from this sitting.
  **Confidence:** high.

## 4. Checks Run

```sh
git rev-parse origin/main   # 3faa1a46
Rscript -e 'devtools::test(filter = "mspl-W-onesided")'
# [ FAIL 0 | WARN 0 | SKIP 0 | PASS 55 ]
rg -n "se=TRUE|estimator = .mspl" tests/testthat/test-mspl-W-onesided-oracles.R
rg -n "return eta|gll_mspl_log_weight\\(eta, 0\\)" src/gllvmTMB.cpp
```

Not run: `devtools::test()` full, `--as-cran`, pkgdown.

## 5. Tests of the Tests

- W2 fails if Poisson \(P_J\) no longer increases with \(+\beta_0\).
- W3 fails if working \(W_*\) loses either infinity.
- W5 fails if NB2 \(P_J\) starts climbing like Poisson at large
  mean.
- W7 fails if a later G0 replaces Poisson `return eta` without
  updating the pin.
- W-onesided source scan fails if this file grows a live
  `estimator="mspl"` or `se=TRUE` call.

## 6. Consistency Audit

```
rg 'W=diag\\(mu\\)|return eta' R/mspl-registry.R R/mspl-poisson-atoms.R src/gllvmTMB.cpp
rg 'working logistic W_\\*|one-sided' R/mspl-registry.R src/gllvmTMB.cpp
rg 'se=TRUE|NEWS covered|admitted' docs/dev-log/research/2026-08-16-mspl-W-onesided-audit.md
```

Verdict: live Poisson still `W=diag(mu)`; Tweedie notes name
working \(W_*\); the audit forbids door / admit / `se=TRUE` /
NEWS covered from this PR.

## 7. Roadmap Tick

N/A — research + oracle pin, no ROADMAP chip.

## 7a. GitHub Issue Ledger

No new issue. #999 Tweedie hang is already diagnosed; this note
does not reopen it. No Poisson un-admit issue: G0 chooses keep or
replace. Concurrent sibling
[#1061](https://github.com/itchyshin/gllvmTMB/pull/1061)
(`cursor/mspl-se-ranga-synthesis`) owns pin metadata + paper
synthesis; this PR is the measurement/oracle companion and does
not touch `R/mspl-curvature-pin.R`.

## 8. What Did Not Go Smoothly

Phase-4 E2 oracles look like a coercivity proof if you only read
the \(-\infty\) side. The \(+\infty\) path is the existence risk
and was unpinned on the admitted Poisson row.

## 9. Team Learning

**Ranga:** \(Q_0\) is the reporting target; \(W_*\) must be
settled before more SE-series doors. True-family Jeffreys is
one-sided for Poisson and Tweedie and saturating for nbinom2.

**Fisher:** finiteness of a Poisson MSPL fit is not E3. A penalty
that grows with \(\mu\) can look "stable" while rewarding
runaway means.

**Curie:** the toy cell is enough to pin the sign of
\(dP_J/d\beta_0\). Do not start a live MSPL fit to measure a
weight path.

**Rose:** keep the five-atom "one-sidedly only" sentence after
admission. `admitted` did not make \(W=\mu\) two-sided.

**Gauss:** Poisson \(P_J\) is exactly linear in the intercept on
this design (\(+4\) per \(+4\) in \(\beta_0\)). That is the
\(\log\det\) of a rank-2 Gram that scales with \(e^{\beta_0}\).

## 10. Known Limitations And Next Actions

- Tape replace is G0. This PR does not do it.
- Exact NB1 \(I_\eta\) at \(\eta\to+\infty\) is still OPEN.
- Do not open another SE-series door from this note.
- Next safe action: Shinichi picks keep / replace / park on the
  G0 menu in the research note §6.
