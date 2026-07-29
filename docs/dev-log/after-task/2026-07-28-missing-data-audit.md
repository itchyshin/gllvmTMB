# After-task — missing-data documentation-accuracy audit (lane 3)

Date: 2026-07-28 · Platform: Claude Code · Branch: `claude/missing-data-20260728`
Worktree: `/private/tmp/gllvmtmb-missing-data` (from `origin/main` @ `869e92b5`)

## 1. Goal

Establish whether the shipped missing-data machinery does what
`vignettes/articles/missing-data.Rmd` tells users it does — with the specific question of whether
the default silently drops data in a way that changes the estimand.

## 2. Implemented

An audit, not a rebuild. The subsystem already existed (`R/missing-predictor.R` is 2,859 lines,
four exports, a 314-line article, 13 test files).

- Settled the central behavioural question **by running fits**, not by reading code.
- Found and fixed two reader-facing documentation defects (one under-claim, one overclaim).
- Added a fast, always-run test file pinning the default's contract, which previously had no
  un-gated guard.
- Produced a severity-tiered ledger at `docs/dev-log/2026-07-28-missing-data-accuracy-audit.md`.

**The starting hypothesis was wrong, in the interesting direction.** The lane brief expected "silent
row-dropping that changes the estimand." What actually ships is cell-wise omission that is reported
at call time and reaches the same optimum as the opt-in masked route. The defects are almost all
**under-claiming** — the same direction the sister package's audit found.

## 3a. Decisions and rejected alternatives

- **Rejected: repeating a claims-reconciliation pass.** One was already run on 2026-07-12 and
  returned no open items; repeating it would have re-passed it. Chose live-fit verification instead,
  which is what made the findings possible.
- **Rejected: filing "complete-case is a misnomer" as a systemic finding.** Sweeping the rest of the
  surface showed `R/traits-keyword.R:74-81` already documents the distinction correctly. The finding
  narrowed to a single-surface imprecision in the tutorial.
- **Rejected: shipping a runtime change.** Making `gllvmTMB_wide()` report its drop, and flipping the
  default, are both behaviour changes to shipped exports. Written up as proposals per the agreed
  change authority.
- **Decided: name FIML once, with a plain gloss** (maintainer's call), rather than adopting the
  acronym throughout or omitting it.

## 4. Files touched

Created:
- `docs/dev-log/2026-07-28-missing-data-accuracy-audit.md` — the ledger
- `tests/testthat/test-missing-response-cellwise.R` — 4 always-run pins
- `docs/dev-log/after-task/2026-07-28-missing-data-audit.md` — this report

Modified:
- `vignettes/articles/missing-data.Rmd` — two edits: the default-behaviour sentence (L46-47) and the
  article description (L3)

Not touched (fenced to another lane, read-only here): `R/gllvmTMB.R`, `R/fit-multi.R`, and the rest
of PR #802's set. No `git add -A` was used at any point.

## 5. Checks run

| Check | Result |
|---|---|
| Smoke fit before any grid | logLik −36.65, nobs 80 — passed the gate |
| Cell-vs-unit probe (`nobs` 80 → 79 on one `NA`) | cell-wise confirmed |
| Independent control (hand-remove cell vs hand-remove unit) | Δ=1.4e-14 vs Δ=0.66 |
| `drop` vs `include`, gaussian+poisson × long+wide | \|ΔlogLik\| 1e-9…1e-8, `nobs` equal |
| wide vs long parity (article's own example) | \|ΔlogLik\| = 1.07e-14, `nobs` 44 both |
| Two `mi()` terms | correctly rejected |
| 13 test files, default run | 133 pass / 80 skip / **0 fail** |
| 13 test files + new file, heavy run | **665 pass / 0 skip / 0 fail** / 1 warn |
| New test file, default run | 8 pass / 0 skip / 0 fail |

All fits local; no remote compute (Totoro was at its core cap for another lane).

## 6. Tests of the tests

The new pins were mutation-checked to prove they can fail:

| Assertion | Outcome |
|---|---|
| `nobs == 59` (cell-wise, the truth) | PASS |
| `nobs == 58` (listwise regression) | **FAIL — the pin catches listwise deletion** |
| `nobs == 60` (drop silently skipped) | **FAIL — the pin catches a missed drop** |

The message test additionally asserts the word "cell" and the count, so a regression to row/unit
language would fail it.

## 7a. Issue ledger

One BLOCKER, two HIGH, three MEDIUM and four LOW; full detail in the audit ledger. **Five items are
carried over** — the three most severe were found by the adversarial pass and sit outside this lane's
files or remit:

- **B1 (BLOCKER)** `README.md:174-177` claims missing grouping variables and offsets "still error".
  They do not — both fit silently with different results. `README.md` is another lane's file.
- **B2 (HIGH)** `offset()` is silently ignored in both paths (logLik difference exactly 0, no
  warning, no formal, no guard). Outside the missing-data remit; needs its own investigation.
- **B3 (HIGH/MEDIUM)** `NA` in a grouping/unit identifier is neither dropped, reported nor rejected,
  and changes the fit.

The adversarial verifier returned **SURVIVES-WITH-SCOPE** on the headline claim after 12 attacks,
and forced four scope restrictions — including catching an overclaim in this audit's *own* fix (see
§9).

## 8. Consistency audit

Swept the whole reader surface for the same defect class rather than fixing only the instance found:
`grep` for drop/row/complete-case/listwise language across `vignettes/`, `man/`, `README.md`,
`NEWS.md`, and `R/` roxygen. Four further instances surfaced. Of these:

- Two (`R/gllvmTMB.R:239`, `:1312` → `man/gllvmTMB.Rd`, `man/miss_control.Rd`) are the same defect
  class and are **carried over** — the file belongs to another lane.
- Two (`R/traits-keyword.R:74-81` → `man/traits.Rd`) turned out to be **correct** and were not
  filed; that text explicitly distinguishes the default from listwise deletion.

This sweep is what turned a claimed systemic problem into an accurate single-surface one.

## 9. What did not go smoothly

- **An automated check produced a false positive.** A `grepl("NA", ..., ignore.case = TRUE)` test for
  whether a message mentioned dropped cells returned TRUE by matching the letters "na" inside
  **"diagonal"**. The correct answer was the opposite. Caught by reading the actual matched text.
  Same class as the known BSD-`grep`/`\b` trap.
- **A skip-count measurement was invalid on first attempt** — the environment variable never reached
  the test runner, so default and heavy runs returned identical counts. The sub-agent flagged its own
  result as suspect rather than reporting it clean, which is the behaviour we want. Re-measured by
  setting the variable inside the R session.
- **A scout's file:line citations were off** (it cited `R/gllvmTMB.R:15-16` for a default defined at
  `:1355`). The substance held, the coordinates did not — reinforcing that agent citations must be
  reopened, not trusted.
- A sub-agent correctly flagged an unexpected file appearing in the worktree mid-run. It was this
  session's own new test file, not a foreign lane.
- **The audit committed the very error it was auditing for.** The first fix to
  `missing-data.Rmd:46` asserted the default "is full-information maximum likelihood (FIML) over the
  observed data". The adversarial verifier caught it: what was demonstrated is that two
  *optimisation routes* agree, never that the marginalisation is exact — and for non-Gaussian
  families the marginal is a Laplace approximation. The wording now describes the full-information
  *principle* and states the approximation. This is the strongest argument for keeping the
  adversarial pass: it was pointed at the finding, and caught the fix instead.

## 10. Known residuals

- **Carried over (needs sequencing, not this lane):** the two `R/gllvmTMB.R` roxygen blocks; and the
  proposal to make `gllvmTMB_wide()` report its NA drop.
- The audit covers gaussian and poisson, long and wide. It does **not** sweep every family ×
  covariance-structure combination. Ordinal, categorical, delta/hurdle, and `cbind()` binomial were
  not exercised for the drop/include equivalence.
- No claim is made about interval coverage, and none should be read in.
- The vignette was not re-knitted end to end; the edits are prose-only and touch no code chunk.

## 11. Team learning

**Run the thing before writing about the thing.** A claims-reconciliation audit of this exact article
passed three weeks ago and found nothing. Every finding here came from executing fits — the
cell-vs-unit probe is four lines of R and settled the central question outright. When an audit of a
surface has already passed, the only way to add value is to change the *instrument*, not repeat it.

**Sweep the neighbourhood before believing the finding.** The first framing ("the docs call it
complete-case, so they systematically under-claim") did not survive the sweep: the reference docs
already say it correctly. The sweep both narrowed the claim and made it defensible.

**Distrust automated verdicts on string matching.** Two separate near-misses this session (`\b` on
BSD grep; `ignore.case` matching "na" in "diagonal"). Always read the matched text.

## 12. Cross-product coverage — the negative space

What this audit does **not** cover, stated so nobody infers it later:

- Not a coverage study; no interval-coverage claim anywhere.
- Not an MNAR robustness study.
- Not a re-derivation of the heavy-gated tests — they were measured for *whether they run* and
  observed to pass, not independently re-proved.
- Not an audit of the missing-**predictor** numerical results; the `mi()` route was exercised for its
  scope guard and one fitted case, not for estimator accuracy.
- Not a review of `R/missing-predictor.R`'s 2,859 lines as implementation; only the contracts its
  four exports advertise.
