# gllvmTMB 0.6 arc-loop checkpoint

**GOAL:** `LOOP/GOAL.md` — read its **2026-07-21 MAINTAINER AMENDMENT** first: EVA is
CUT from 0.6 to 0.7; 0.6 is Laplace-only.

**STATE:** M1 local qualification nearly complete. **M1 is NOT closed.** Working tree is
dirty with intended edits; the receipt commit (A10) has not landed.

## Maintainer decisions (2026-07-21)

1. **EVA cut 0.6 → 0.7.** M2 CUT, gates dissolved. 0.7 targets **sparse binary**.
2. **No exception is self-granted** — each needs individual sign-off + a register row.
3. Residuals register is **public**, in `docs/dev-log/`.
4. **#750** — fix the docs, retarget to 0.7; do NOT import the stranded implementation.
5. **R-1 / R-3 / R-4 fixed; R-2 documented** rather than chased.

Records: `docs/dev-log/2026-07-21-eva-cut-to-0.7.md`,
`docs/dev-log/known-residuals-register.md`.

## ARCS DONE (verified by reading logs and opening artifacts)

- **A1 full non-heavy (pre-edit):** `FAIL 0 | WARN 1 | SKIP 780 | PASS 7274`, tree clean.
- **A0 tarball hygiene:** `^LOOP$` in `.Rbuildignore`, asserted against a real
  `R CMD build` + `tar -tzf` manifest (LOOP = 0 entries). Without it, `LOOP/` shipped
  to CRAN and A11's note bar was unreachable.
- **A2 WARN causation: PRE-EXISTING** — identical at `origin/main` and HEAD. Synthetic
  fixture lacks `tmb_data`; the code correctly returns `NA` instead of fabricating.
- **A3 touched heavy:** `FAIL 0 | WARN 0 | SKIP 0 | PASS 173`, elapsed 1186.7s,
  `GLLVMTMB_HEAVY_TESTS='1'` verified inside the process, heavy-skip count **0**.
- **A4/A5 renders:** four articles built to **`pkgdown-site/articles/`** (destination is
  `pkgdown-site`, NOT `docs/`). String oracle passed — the ordinal refusal text is in the
  evaluated HTML. Gitignored, so no tree churn.
- **A7 precommit review:** NEEDS-REPAIR non-blocking, **no blocking correctness defect**.
  Sign-off scope is the **full 11-commit range** (includes `6e46a24a`, Design 79/80).
- **A8 repairs:** `simulate()` docs + fallback warning corrected (#750); R-1 asserted;
  R-3 migrated; R-4 skip messages made self-declaring at both sites; false fixture
  comment corrected; two `NEWS.md` entries added.
- **A9/A9b/A9c:** `GOAL.md` amended (append-only), `arcs.md`, `ultra-plan.md`,
  `decision-queue.md` reshaped, register created, Mission Control rewritten + JSON-valid.

- **A1r full non-heavy re-run (post-edit): GREEN.**
  `FAIL 0 | WARN 0 | SKIP 779 | PASS 7287`, namespace identity proved.
  Deltas vs the pre-edit baseline are exactly as the fixes predicted, with no
  unexplained movement across 311 test files:
  WARN 1 -> **0** (R-1 asserted), SKIP 780 -> **779** (R-3 migrated),
  PASS 7274 -> **7287** (+13 = R-3's 12 assertions + R-1's).

## ARC IN PROGRESS

- **A6b CRAN-configuration source check** — running.
  `devtools::check(remote = TRUE, incoming = TRUE, force_suggests = TRUE,
  manual = TRUE, NOT_CRAN = "false")`.
  **A6 and A6b were deliberately consolidated into this single run.** A6 existed only to
  predict A11's outcome; A6b's configuration is strictly harsher, so passing it de-risks
  A11 *and* yields the programme's only genuine CRAN evidence in one run instead of two.
  Note `manual = TRUE` exercises the LaTeX PDF manual over 139 Rd files, which has failed
  before — that exposure is deliberate, since A11's runner hard-codes `--no-manual`.

## NEXT

1. A6b result. Expect a `New submission` NOTE — that is allowlisted, not a failure.
   Anything outside the allowlist becomes a register row for sign-off, never a self-waiver.
2. A10 receipt commit (**last repo edit**) → A11 durable exact-head runners.
3. **🛑 STOP for maintainer go/no-go before any push or CI spend.**

## OPEN GATES (need human)

- **R-6 awaits sign-off** — no structural guard on random-slope identifiability
  (recommend deferring the guard to 0.7). R-1..R-4 are closed.
- Maintainer go/no-go before push/CI.
- M3 source/API freeze + version bump · M4 **page decisions** · M4 candidate freeze ·
  M5 RC tag · M5 final tag · CRAN submission.

## TRAPS THIS ARC ACTUALLY HIT — verify accordingly

- pkgdown reported **exit 0 while artifacts were absent** from the checked path.
- A focused run reported **`FAIL 0` while the assertion under test was skipped** behind
  `skip_if_not_heavy()`.
- `expect_warning()` in testthat 3e returns the **condition**, not the value — assigning
  from it silently snapshotted the warning object instead of the plot.
- A code comment read in isolation nearly became a false finding.
- An apparent false `#750 SHIPPED` claim in `CLAUDE.md` was **true on its own branch** —
  read while working in a different worktree.
- A limitation was nearly documented against code a 357-line rework had replaced.

**Read the log, open the artifact, and check which branch you are reading.**

## TRUTH LIVES IN

Branch `codex/gllvmtmb-060-m1-baseline-20260720`, draft PR #778, this `LOOP/` kit,
`docs/dev-log/known-residuals-register.md`, `docs/dev-log/2026-07-21-eva-cut-to-0.7.md`.

## RESUME

```text
Read LOOP/GOAL.md (incl. the 2026-07-21 amendment) -> LOOP/checkpoint.md ->
LOOP/decision-queue.md -> docs/dev-log/known-residuals-register.md.
Continue from A1r's result. Stop for maintainer go/no-go before any push or CI spend.
```
