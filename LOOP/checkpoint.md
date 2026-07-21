# gllvmTMB 0.6 arc-loop checkpoint

**GOAL:** `LOOP/GOAL.md` — read its **2026-07-21 MAINTAINER AMENDMENT** first: EVA is
CUT from 0.6 to 0.7; 0.6 is Laplace-only.

**STATE: M1 IS WITHHELD.** Two consecutive D-43 panels returned 3/3 NOT-DONE. A third
sweep this session found **three further instances of the same defect class** (R-8, R-9,
R-10). Two are fixed; one awaits sign-off. **M1 has not closed and must not be claimed
closed.**

## ⚠️ A STANDING CONFLICT IN THE GOAL — the maintainer must resolve it

The session goal sets **"Close M1 (release truth + qualified head)"** as the deliverable
**and** **"stop before any push/CI spend"** as discipline. M1's definition of done requires
exact-SHA three-OS platform evidence, which requires push and CI. **These cannot both be
satisfied.** This session obeyed the discipline line and stopped at the local boundary.
A future session must not silently resolve this by pushing — get the decision.

## THE METHOD FINDING — more important than any single row

**Token-based greps under-scoped FOUR times in succession this session.** Found `PLANNED`,
missed `PARTIAL`/`Scope boundary`. Found those, missed title-case `Planned:`/`Partially
covered:`. Found those, missed `covered (partially)`. Each time a scope was reported, then
proved larger. **This is the exact "repair what you noticed, then assert completeness"
failure that withheld M1 twice — reproducing itself inside the repair.**

The lesson is not "write better patterns". It is that **a semantic class cannot be bounded
by token search**, and that **a whole surface can sit outside every check** — R-10 exists
because printed output is named as a reader surface by `CLAUDE.md` and is examined by no
guard, and both prior panels missed it. Before claiming a class is swept, enumerate the
SURFACES first, then the vocabulary.

## Register state

| Row | State |
|---|---|
| R-1, R-3, R-4, R-5 | `RESOLVED` |
| R-2, R-6 | `SIGNED OFF` |
| **R-7** | **`SIGNED OFF`** — seven benign; site (d) accepted as a **deferred 0.7 repair**. No longer blocks. |
| **R-8** | **`RESOLVED`** — 5 dangling article citations deleted + 2 dangling `vignette()` calls converted to published URLs (**conversion flagged for maintainer review**) |
| **R-9** | **`RESOLVED`** — 21 sites/14 files rewritten, 14/14 verified faithful, plus 4 later variant sites |
| **R-10** | **`AWAITING SIGN-OFF`** — 15 `Design NN`/`Phase NN` codes in user-facing error messages, 7 files. **Blocks M1's closing claim** per the register's own rule. |

## R-7 site (d) — mechanism MEASURED, not inferred

Probe (`~/gllvmTMB-0.6-evidence/m1/diagnostics/r7-site-d-mechanism-probe.{R,log}`) confirmed:
the gate `.fit_stationary_for_recovery_test()` returns **TRUE while `pd_hessian` is FALSE**;
`cov.fixed` is 13×13 with exactly one negative diagonal entry at **`log_tau_spde` = −3.518e10**;
min eigenvalue equals it, so definitively not positive-definite; `summary()` yields 1 NaN
standard error and **0 NaN estimates**. The asserted quantity survives (gap 0.0795 vs bound 0.6).
**0.7 must budget for this: repairing the gate will likely make the cell SKIP, moving
SPA-02(nbinom2) from covered back toward partial.**

## 🌙 OVERNIGHT RUN IN PROGRESS (2026-07-21 → 05:00 2026-07-22)

Maintainer away until 05:00 and has authorised the lane to keep running. **CI authorisation
is RESTORED** (`LOOP/GOAL.md` Amendment 2) — push, Ubuntu, heavy, and the three-OS matrix are
approved. Nothing irreversible: **no merge, no tag, no submission, no readiness claim.**

**Current head `037e64f1`.** Source is identical to the pushed `59da7505`; the only diff is a
`docs/dev-log/` file that `.Rbuildignore` excludes from the tarball, so CI's verdict at
`59da7505` describes this source too (same reasoning already recorded for `310cbaab`).

### ⚠️ A REGRESSION WAS SHIPPED AND CAUGHT THIS EVENING — read this before trusting any claim

R-10 removed the internal token `C1-partial` from `.augmented_slope_family_scope_text()`.
**`test-augmented-slope-family-policy.R:80` asserted on exactly that token.** Result: `R CMD
check` `Status: 1 ERROR`, and Ubuntu CI run `29875507222` **failed** on `1e14e3e0`.

**Worse, the failure was reported as a pass.** The suite log was grepped for `── Failure` /
`^Failure (` — not how the `summary` reporter formats failures — and no `[ FAIL … ]` summary
line existed either. Zero matches was read as clean, and a commit was made on it. That is
*never the exit code, never a negative grep* broken **inside the step meant to enforce it**.

**Method fix now in force:** verify from **structured results only** —
`as.data.frame(<testthat result>)` counts, or the runner's `M1_FINAL_RECEIPT_CHECK_*` fields.
**A missing or unparseable field is a failure of verification, not a pass.**

Fixed at `59da7505` (assertion now tracks the plain-English wording). Full detail:
`docs/dev-log/after-task/2026-07-21-m1-third-reader-surface-sweep.md` §5b.

### 🧹 OPEN HOUSEKEEPING — `vignettes/` render detritus (needs a human hand)

`pkgdown::build_articles()` left **four untracked PNGs in `vignettes/`** —
`cor-matrix-1.png`, `cor-plot-1.png`, `ord-1.png`, `residual-qq-1.png`. They carry mtimes of
`17:47` because the render copied them with dates preserved; the tree was verifiably **clean
at `037e64f1`** when the durable runners ran, and the render happened after, so the render
put them there.

- **Never tracked, never committed** (`git ls-files` and `git log` both confirm).
- **Not covered by `.gitignore`**, so every article render will dirty the tree again.
- **Untracked files are not pushed**, so CI and the in-flight runs are unaffected, and the
  `037e64f1` receipts — cut before the render — remain valid.
- **They DO block future local runner runs**, which require a clean worktree.
- ⚠️ **No `R CMD check` has ever run with them present.** The CRAN-configuration check
  preceded the render, so their effect on `R CMD build` (stray files in `vignettes/`, a
  possible CRAN NOTE) is **untested, not proven harmless.**

**An agent attempt to `rm` them was DENIED by the permission layer, and was not retried.**
Left in place deliberately. **Recommended:** delete the four files, and add `vignettes/*.png`
to `.gitignore` so renders stop dirtying the tree. Both are the maintainer's to do.

### Overnight sequence (each step waits on the previous; waiters armed)

1. Ubuntu `29877269563` on the fixed head → verify green.
2. **After** Ubuntu completes, dispatch `R-CMD-check` with `-f full_matrix=true`. **Never
   during** — the concurrency group cancels the in-flight run and destroys its receipt.
   **Assert three OS-named jobs**; silent degradation to Ubuntu-only also goes green.
3. Re-dispatch `full-check` on the fixed head once the current one finishes. The in-flight
   one (`29875577778`) was launched on the PRE-FIX head and **is expected to fail** on that
   same single assertion — that is not a new defect. Its heavy **warning set** is still valid
   R-7 evidence, because a test-assertion string cannot change which warnings fire.
4. Article renders (running).
5. Third D-43 panel once platform evidence exists.
6. Consolidate + handover.

**M1 STILL CANNOT CLOSE OVERNIGHT — R-11 needs the maintainer's signature.**

## ⚠️ RECEIPT SHA vs HEAD — read before trusting either

**The durable receipts describe `5d7b6de6`.** This checkpoint update is the FIRST commit
after them, and it is **deliberately declared NON-CERTIFYING**: it touches only `LOOP/`, so
it changes no source, but it does move HEAD off the receipt SHA. That is the same drift that
superseded `25c76789`, so it is named here rather than left to be discovered.

The trade was made knowingly: a **stale resume pointer is a worse hazard than a one-commit
SHA gap**, because `5d7b6de6` is very unlikely to be the release SHA anyway — R-10 is still
open, and if the maintainer chooses "rewrite" it requires source edits and a fresh freeze.

**Receipts (SHA-256 verified) live at:**
`~/gllvmTMB-0.6-evidence/m1/final-receipt/5d7b6de6b3e24cd99506041791278bd2a25aed8b/`
containing both runner RDS files, both runner logs, the CRAN-check log, the suite log, and
the R-7 probe script + log, with `SHA256SUMS.txt`.

## Evidence state

| Item | State |
|---|---|
| Reader-surface guard | **PASS** |
| Construction family in `R/` + `man/` | **absent** (verified after final regeneration) |
| Rd regeneration | **done**, 0 errors / 0 warnings |
| Non-heavy suite | **`FAIL 0 \| WARN 0 \| SKIP 779`** — identical to the pre-sweep baseline |
| CRAN-configuration check (`remote`+`incoming`) | **0 errors / 0 warnings / 1 note** (`New submission`, expected) at `f56310ff` |
| New article URLs | **fetched and confirmed live**, not assumed |
| Durable package-check runner | **CLEAN at `5d7b6de6`** — 0 errors / 0 warnings / **0 notes**, no runner errors |
| Durable pkgdown runner | **CLEAN at `5d7b6de6`** |
| Receipts mirrored + SHA-256 | **DONE** — see the block above |
| CI cycle | **NOT RUN** (gated by the discipline line) |
| Third D-43 panel | **NOT RUN** (needs the gated platform evidence) |

**Why the runner reports 0 notes while the CRAN check reports 1** — not a contradiction. The
runner calls `devtools::check(args = c("--as-cran", "--no-manual"))` **without** `remote` /
`incoming`, and the `New submission` NOTE originates in the CRAN incoming-feasibility step,
which only runs with those enabled. Both results are correct for what they ran.

**Limit of the pkgdown receipt:** `pkgdown::check_pkgdown()` validates configuration only. It
**does not build the site**, so this is not evidence that the site renders. A previous arc was
burned by exactly that assumption (exit 0 with artifacts absent, destination `pkgdown-site`).

## NEXT — in order

**All local evidence that can be produced without a maintainer decision is DONE.** The lane
is stopped at the gate, exactly as the discipline line requires.

1. **🛑 R-10 decision** — the only thing blocking on evidence grounds. If "rewrite", it needs
   source edits and therefore a **fresh freeze and fresh runners**; `5d7b6de6` would be
   superseded. If "accept", the register row flips to SIGNED OFF and no re-freeze is needed.
2. **🛑 The goal conflict** — "close M1" vs "stop before any push/CI spend". Until resolved,
   M1 cannot close, because its definition of done requires exact-SHA platform evidence.
3. **🛑 The R-8 deviation** — two `vignette()` citations converted rather than deleted.
4. Then, once 1–3 are settled: freeze → push → full CI matrix (**assert three OS-named
   jobs**; do not dispatch `R-CMD-check.yaml` while an Ubuntu run is in flight, the
   concurrency group cancels it) → third D-43 panel.

## OPEN GATES (need the maintainer)

- **R-10 sign-off** — 15 internal codes in printed output.
- **R-8 review item** — two `vignette()` citations were **converted** to published URLs
  rather than deleted; the stated decision was "delete". Real, verified destinations, so
  conversion preserves reader value — but it is a deviation and is flagged as one.
- **The goal conflict** above: close M1 vs stop before push/CI.
- M3 freeze **+ the `0.5.0 → 0.6.0` bump, which invalidates every exact-SHA receipt.**
- M4 **page decisions** — the maintainer's own hours, and the real critical path for 0.6.
- M4 candidate freeze · M5 RC tag · M5 final tag · CRAN submission.

## TRAPS HIT THIS SESSION (all real, all recorded)

A **backgrounded launcher shell reported exit 0 while the suite it launched was still
running** — nearly read as a pass · `pkgdown::check_pkgdown()` validates config only and
does **not** prove the site builds · a grep for `"the register"` matched `"the
**regist**ered transformation"` and a grep for `slice` matched `extract_Gamma()`
"**slices** a matrix" — **a grep hit is not a finding, just as a negative grep is not
proof** · `.Rbuildignore` excludes `vignettes/articles`, so `vignette("x")` for any article
is dangling · the guard passes on `see the *Random effects* article` because there is no
code and no path in it — **it cannot know the article does not exist**.

## TRUTH LIVES IN

Branch `codex/gllvmtmb-060-m1-baseline-20260720`, **receipts at `5d7b6de6`**, tree clean,
**10 commits unpushed**, draft PR #778, this `LOOP/` kit,
`docs/dev-log/known-residuals-register.md`, `docs/dev-log/check-log.md`,
`docs/dev-log/after-task/2026-07-21-m1-third-reader-surface-sweep.md`, and
`~/gllvmTMB-0.6-evidence/m1/final-receipt/5d7b6de6b3e24cd99506041791278bd2a25aed8b/`.

## RESUME

```text
Read LOOP/GOAL.md (incl. the 2026-07-21 amendment) -> LOOP/checkpoint.md ->
LOOP/decision-queue.md -> docs/dev-log/known-residuals-register.md ->
docs/dev-log/after-task/2026-07-21-m1-third-reader-surface-sweep.md.

M1 is WITHHELD. R-1..R-9 are closed (R-7 signed off, site (d) deferred to 0.7).
R-10 AWAITS SIGN-OFF and blocks the closing claim by the register's own rule.

ALL LOCAL EVIDENCE IS DONE at 5d7b6de6 and mirrored with SHA-256: guard PASS, suite
FAIL 0 | WARN 0 | SKIP 779, CRAN check 0/0/1 (New submission), both durable runners clean,
both new article URLs fetched live. Do NOT re-run these unless source changes.

The lane is STOPPED AT THE GATE. Do not push, dispatch CI, merge, tag, or claim readiness.
Three maintainer decisions are outstanding: (1) R-10, (2) the goal's "close M1" vs "stop
before any push/CI spend" CONFLICT, (3) the R-8 vignette-URL conversion deviation.
Do not resolve any of them yourself.

If R-10 is answered "rewrite", it needs source edits -> re-freeze and re-run both runners;
5d7b6de6's receipts are then superseded.
```
