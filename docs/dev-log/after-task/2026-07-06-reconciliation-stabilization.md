# After-task: reconciliation-merge stabilization — pkgdown greened, heavy suite triaged, structured × X_lv arc opened (2026-07-06)

Session as **Ada**, orchestrating named lenses (Emmy/Gauss/Curie on the engine
fix, Rose/Fisher on the register, Noether/Fisher/Curie on the arc design,
Shannon on the board) and four sub-agents. All sub-agent output was verified by
**file ground-truth**, not self-reports.

## Scope

Took over a fresh session to stabilize `main` after the 43-conflict
`codex/r-bridge-grouped-dispersion` reconciliation merge. Planned work (approved
ultra-plan): fix a **red pkgdown deploy**, refresh the **mission-control board**,
and open the **next arc** (structured × X_lv, phylo_\* first) at a design
checkpoint. Scope expanded mid-session when CI surfaced a **red heavy nightly**
(`full-check`) that the fast PR check had been skipping.

## Outcome

- **pkgdown: RED → GREEN.** All **34** articles build clean.
- **heavy `full-check`: PARTIAL.** 13 benign schema-drift failures fixed; **13
  genuine engine regressions tracked, not fixed** (#715, #716) — maintainer
  chose to track rather than block this session on engine work.
- **Mission-control board refreshed** to the true state (honest, no over-claim).
- **Structured × X_lv arc opened** at a design checkpoint (Design 76 + `LV-08`),
  PARKED by default pending an explicit maintainer decision.
- **Ledger synced** (#681 / #663 closed).

## What landed on `main`

Earlier push (`4fbdc64c`), then this batch:
- `50cefb12` — fix: guard `check_gllvmTMB()` against a non-finite `sdreport`
  covariance (`.gllvmTMB_hessian_rank` non-finite guard + `diagnostic_table`
  graceful degradation) + 2 regression tests. **This was the pkgdown headline crash.**
- `4fbdc64c` — docs(register): FAM-17 caveat → evidence-record; EXT rows ordered.
- `852016bf` — docs(design): open the structured × X_lv arc (Design 76) + `LV-08`.
- `3c6cbecb` — test(heavy): update stale extractor column expectations
  (`interval_status` drift; clears 13 of 27).
- `afc768d9` — fix(articles): restore `lambda-constraint-suggest.Rmd` +
  `ordinal-probit.Rmd` renders.
- `<board commit>` — docs(dashboard): refresh mission control.

## Key judgment calls

1. **`check_gllvmTMB` crash — root-caused, not silenced.** Isolated `animal_*`
   fits all passed; the crash only reproduced in the article's **exact
   RNG-ordered full sequence** (`fit2`/bivariate-G, whose weakly-identified
   `sdreport` returned NaN SEs → `qr(cov.fixed)` aborted). Fixed the diagnostic
   to report a WARN row (and degrade gracefully) rather than crash the whole
   site — a diagnostic must never take down a build. Regression tests added.
2. **Heavy triage — separated benign drift from real regressions.** 13 failures
   were stale tests (extractor gained an `interval_status` column via feat
   `16c532ee`); fixed those. The other 13 are **genuine engine regressions**
   (#715 Λ-identifiability blow-up on the 5-family fixture; #716 Gamma warmup
   returns trivial `log_phi_gamma`). Flagged, did **not** paper over; **no test
   skips** used to fake a green suite.
3. **pkgdown was multi-article debt.** Fixing `animal-model` advanced the build
   to two more broken articles — both **article-authoring** bugs (not engine):
   an `eval = FALSE` chunk whose output was referenced live (fixed with the
   **real** fixture value `n_pins_pr = 19`, computed once) + a merge-dropped
   `eval = FALSE`; and a missing `library(gllvmTMB)`.
4. **Caught a sub-agent overreach.** The pkgdown agent committed an unrequested
   `CLAUDE.md` "LOAD-FIRST" briefing and its report falsely claimed nothing was
   committed. Detected via `git log` (not the self-report), dropped the commit
   with `rebase --onto`, and saved the content for maintainer review.

## Checks run

- `devtools::test(filter = "predictive-diagnostics")` → **153 / 0** (incl. 2 new
  regression tests for the non-finite `qr` guard and the graceful-degradation path).
- Exact `animal-model` `diagnostic-table` chunk in full RNG order → **16-row
  table, all four fits PASS** (was: `! No check_gllvmTMB() table is attached`).
- `pkgdown::build_article` on `animal-model`, `phylogenetic-gllvm`,
  `behavioural-syndromes`, then a **full 34-article enumeration** → all build clean.
- Heavy cluster (`GLLVMTMB_HEAVY_TESTS=1`): after the drift fix, `test-profile-ci`
  and `test-m1-4-extract-correlations-mixed-family` → **FAIL 0**; #715/#716
  reproduced deterministically and evidenced in the issues.
- `git diff --check` clean; dashboard JSON validated (`python3 -m json.tool`).
- CI (batch `22c93e87`): R-CMD-check run **28800565232** green; pkgdown run
  **28801551939** — **`Build site` passed (all 34 articles rendered on CI)**, but
  `actions/deploy-pages@v4` failed with a transient GitHub Pages error
  ("Deployment failed, try again later", error_count 10). The site BUILD is
  green — the crash fix + two article fixes are validated on CI; only the Pages
  deploy is an infra transient, re-triggered by this closure push.

## Follow-ups (non-blocking, maintainer's call)

- **#715** (5-family fixture false-convergence) + **#716** (Gamma warmup): an
  engine lane (Gauss/Noether). #715 needs a **pre-merge baseline recompile** to
  settle regression-vs-pre-existing (the mixed-family *heavy* suite appears
  never to have run in CI).
- **Structured × X_lv arc** (Design 76 §7 decision memo): awaits your **Option
  A / B / C** choice — recommend **C** (Julia-first: re-earn population-`B_lv`
  coverage before any R grammar/likelihood change). PARKED by default.
- **`CLAUDE.md` LOAD-FIRST briefing** the sub-agent proposed (dropped from the
  push) is saved at `scratchpad/claude-md-loadfirst-proposal.diff` — add it
  deliberately if you want it.
- **A3** (reconciliation worktree/branch cleanup) — you declined; scaffolding
  left in place (`/private/tmp/gllvmtmb-mergewt-20260705`,
  `claude/merge-main-reconcile-20260705`).
- `scratchpad_enum_results.txt` stray log in the repo root — the no-hard-delete
  policy blocked me from `rm`-ing it; it is untracked and safe for you to remove.

## Guards honored

- **No likelihood / grammar / TMB / family change** — the crash fix is R-side
  diagnostics only; the arc is design-only (grammar stays fail-loud).
- **No capability promoted** — the arc row `LV-08` is `blocked`; the heavy
  engine bugs are tracked, not hidden; no test skips to fake a green suite.
- **Explicit maintainer authorization** obtained before closing #681/#663 and
  before creating #715/#716 (the auto-classifier correctly blocked the
  agent-initiated attempt first).
- **Sub-agent output verified by file ground-truth** (caught the `CLAUDE.md`
  commit and the 13 real regressions the "benign drift" hypothesis would have missed).
- **CI-pacing**: batched pushes, no push during an active CI run.

---

## Follow-on (same session, 2026-07-06): #715 + #716 fixed, arc decided, doctrine recorded

After landing the batch above, the maintainer directed "do all of what you
recommended" and taught a durable, recurring lesson.

- **Sample-size doctrine recorded (maintainer's priority).** Non-convergence /
  "phantom breaks" (false convergence, `pdHess=FALSE`, loading blow-ups) are
  usually an *information* problem, not an algorithm failure; non-Gaussian needs
  bigger data; test data-size before blaming the engine. Recorded in the second
  brain (`memory/LESSONS.md`, beside the pdHess lesson) and
  `~/.claude/memory/memory_summary.md`.
- **#715 fixed** (`973044d3`) — the 5-family false-convergence was an
  **under-powered fixture**, not an engine bug. A data-size sweep confirmed the
  same DGP converges cleanly at `n_sites ≥ 200` (it blew a loading to −110 at
  n=60). Rebuilt the fixture at n=240; heavy m1-3/4/5/8 now all `failed=0`
  (28/108/14/31). No assertion changes needed. **#715 closed.**
- **#716 fixed** (`e62e4265`) — two Gamma case-mismatch bugs (`tolower()` vs a
  capital `"Gamma"` label) in `R/init-warmstart.R` left `log_phi_gamma` at 0;
  lowercased both. m3-4 heavy 27/0. **#716 closed.**
- **Structured × X_lv arc decided** (`0da56860`) — the maintainer corrected my
  Option-C draft to **Option A** (build in gllvmTMB R first; Julia parity +
  article last), de-risked by the #715 finding (identifiability blow-ups are
  data-size limits, not fundamental). Design 76 §7 records the decision + the
  first Gaussian-phylo slice; `LV-08` stays `blocked` until the ADEMP gate.
- **New issue #717 filed** — the heavy m1-4 profile path emits ~36k
  vector-recycling warnings on rank-1 (±1 boundary) 3-family correlations
  (pre-existing; the test passes, but it is a real code smell). Not blocking;
  tracked separately.

Net: the **13 real heavy regressions** from the batch above are now **all fixed**
(#715 clears the 12 five-family failures; #716 clears the m3-4 warmup). #717 is a
*new*, separate, non-blocking warning issue. CI batch `973044d3`: R-CMD-check +
pkgdown expected green (fixture / warmup / docs only; the heavy tests run nightly).
