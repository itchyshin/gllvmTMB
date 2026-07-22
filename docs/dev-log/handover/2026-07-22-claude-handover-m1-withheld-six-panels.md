# Session Handoff — M1 withheld after SIX D-43 panels; engineering green; four maintainer decisions open

**Meta:** 2026-07-22 · Claude → Claude · context-pressure handoff, maintainer present
**Workspace:** `/private/tmp/gllvmtmb-060-m1-builder` (reattach + pull; do **NOT** recreate)
**Branch:** `codex/gllvmtmb-060-m1-baseline-20260720` · draft PR #778

## Read first, in this order

```text
LOOP/GOAL.md                                   (BOTH maintainer amendments)
LOOP/checkpoint.md                             (the live resume pointer)
docs/dev-log/known-residuals-register.md       (R-1..R-11, all closed)
docs/dev-log/check-log.md                      (every check, with retractions)
docs/dev-log/2026-07-22-nongaussian-variance-component-thread.md   (0.7 science)
this file
```

## One-paragraph state

**M1 is WITHHELD after six consecutive 3/3 NOT-DONE D-43 panels.** No register row blocks it,
no check is failing, no defect is outstanding — it is withheld on a **base rate**, not a known
problem. **Not one of the six panels found a numerical, algorithmic or statistical defect.**
Five complete evidence chains were earned and forfeited (each subsequent fix re-minted the
SHA); the sixth stands. What every panel found was the gap between what the package *does* and
what it *says about itself*. Closing M1 now needs **four maintainer judgements**, listed below.

## Where the work stands

**Head `eea9761c`** (clean, pushed). **Certified evidence SHA `21e04eb5`.**

**Before repeating any SHA claim, re-derive it — do not trust this file:**

```sh
git diff --name-only 21e04eb5 HEAD -- \
  R/ src/ tests/ man/ vignettes/ tools/ DESCRIPTION NAMESPACE
```

**Empty ⇒ the certification transfers to HEAD. Any output ⇒ it does not; re-earn the evidence.**

### Certified evidence at `21e04eb5`

```
devtools::test()                 FAILED 0 | ERROR 0 | SKIP 779 | PASS 7290
durable R CMD check --as-cran    0 errors | 0 warnings | 0 notes
CRAN-configuration check         0 errors | 0 warnings | 1 note (New submission)
Ubuntu CI            29903055881 success
three-OS matrix      29904363055 ubuntu + macos + windows — all success (asserted by name)
heavy full-check     29903134856 FAIL 0 | WARN 10 | SKIP 103 | PASS 13656
tools/check-reader-surface.sh    PASS (extended guard)
```

Receipts + `SHA256SUMS.txt`:
`~/gllvmTMB-0.6-evidence/m1/final-receipt/21e04eb59679d1a92120bc367914a4de948f9afd/`

**`WARN 10` is NOT a regression.** Six Ubuntu heavy runs returned **WARN 8, 9 and 10** from
functionally identical code — the contingent sites are optimiser-convergence-dependent.
**Only `FAIL` is a regression signal.** All six returned `FAIL 0`.

## 🔴 THE FOUR OPEN ITEMS — all maintainer judgements, none is agent work

1. **Wording review of the R-11 replacement strings.** *The one property no check can
   establish.* An Opus reviewer already caught **seven overstatements** in the first attempt —
   most seriously `"validated"` on CI rows, which `docs/design/75:99` forbids and which `CI-08`
   records as a **FAILED** gate (13/15 cells below the 94% threshold). Current strings include
   `"direct profile route (not coverage-calibrated)"`, `"diagonal grouping tier: no calibrated
   interval"`, `"no CI (point estimate only)"`, `"experimental route: partial validation
   only"`. **The question is not style — it is whether any still claims more than is true.**
2. **`NEWS.md` boundary statement** — drafted, deliberately NOT written in (release-level
   claim): *variance-component **point estimates** are the supported claim for non-Gaussian
   families; **interval calibration** is established only for the Gaussian cells that cleared
   the coverage gate.*
3. **Does R-7's SIGN-OFF still stand?** Its "exact set match" causation evidence has been
   **retired** — six heavy runs gave three different warning counts, so the set is not a
   function of the code and an exact match between two runs proves nothing.
4. **The `glmer` experiment** (0.7 science, **not** an M1 blocker) — see the thread note.

**If the maintainer changes any wording, that is a source change:** re-freeze and re-earn the
whole chain (runners → CRAN check → push → Ubuntu → **then** matrix → heavy) before a seventh
panel. If nothing changes, a seventh panel is the only remaining step.

## What six panels actually found — read before trusting anything the agent wrote

**The recurring failure was one thing:** *repair the instance pointed at, not the class it
belongs to — then state in a commit message that the class is fixed.* **Twelve instances.
THREE of the six panel findings were defects introduced by the previous panel's own fix.
THREE commit messages were false or damaged.**

Worked examples worth knowing:
- A reported `FAIL 0` from a grep matching a marker the reporter never emits — the run had failed.
- A suppression wrapper applied to one of **two** return branches, leaving the **default** broken.
- `"validated"` corrected on line 1587 and left on line 1588 of the **same** `cli_abort`.
- An R-10 register contradiction fixed without checking R-9, which had the identical defect.
- An "established invariant" asserted from **n=4** and refuted at n=5.
- A checkpoint warning about stale references that named its own commit's SHA — stale on arrival.

**The real class is two-dimensional: SURFACES × CODE SHAPES.** Every panel found a cell the
guard did not cover. Sweeping the shapes it already knew on the surfaces it already scanned
was itself instance-thinking, one level up.

## Standing rules now in force (each paid for by a failure)

- **Verify from structured results only** — `as.data.frame(<testthat result>)` counts, or the
  runner's `M1_FINAL_RECEIPT_CHECK_*` fields. **A missing field is CANNOT VERIFY, never PASS.**
  Never grep reporter prose for failure markers.
- **`test_dir()` ≠ `devtools::test()`** — measured: `FAILED=2` at `SKIP=1001` versus
  `FAILED=3 + ERROR=1` at the correct `SKIP=779`. ~2,400 tests silently did not run.
- **A backgrounded launcher's exit 0 is not the job's result.**
- **Write commit messages to a FILE and use `git commit -F`.** Every `-m` message containing
  backticks was mangled by shell command substitution; every `-F` one is intact.
- **Never dispatch `R-CMD-check.yaml` while an Ubuntu run is in flight** — the concurrency
  group cancels it. Observed live twice.
- **`WARN n` from a heavy run is not a signal. Only `FAIL` is.**

## What this arc changed, durably

- `tools/check-reader-surface.sh` now covers the **class**: two new code shapes (`M1.8`,
  `D-28`), a new surface (**`R/` string literals** — runtime messages and returned values,
  comments exempt), and shipped-vignette link checking. **Each pattern validated by
  construction**, not asserted. Its PASS message states what it **cannot** check.
- R-1…R-11 all closed; R-7 carries three recorded corrections; R-9's four-panel-stale status
  fixed; R-11 repaired in both code and suppression.
- A genuinely **false capability claim** removed (`simulate()` told users multinomial was
  unsupported while drawing it) and **dead links in the shipped vignette** fixed.

## What this handoff does NOT cover

- Whether the replacement prose is **true**. No grep establishes it; that is item 1.
- Whether a seventh panel would pass. Six have not.
- The `glmer` experiment — designed, not run.
- Any CRAN submission, merge, or tag. None occurred; all remain maintainer acts.

## RESUME

```text
Read LOOP/GOAL.md (BOTH amendments — CI IS AUTHORISED, do not re-ask) ->
LOOP/checkpoint.md -> known-residuals-register.md -> check-log.md -> this file.

M1 WITHHELD after six 3/3 NOT-DONE panels. No row blocks it, no check fails, no defect
outstanding. Head eea9761c; certified 21e04eb5 — VERIFY TRANSFER with the git diff above
before relying on it.

Do NOT convene a seventh panel before the maintainer's wording review (item 1). The
remaining findings are prose-accuracy judgements the agent is demonstrably unreliable at,
and three of six findings were self-inflicted.

SWEEP THE CLASS, NEVER PATCH THE INSTANCE. Verify from structured results only.
Do not trust this agent's commit messages — three were false or damaged.
```
