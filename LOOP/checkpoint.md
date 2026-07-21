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

## Evidence state

| Item | State |
|---|---|
| Reader-surface guard | **PASS** at `e506dc94` |
| Construction family in `R/` + `man/` | **absent** (verified after final regeneration) |
| Rd regeneration | **done**, 0 errors / 0 warnings |
| CRAN-configuration check | 0 errors / 0 warnings / 1 note — **but recorded at `ce2fb177`, now SUPERSEDED by 3 commits** |
| Non-heavy suite | **WAS STILL RUNNING** at `e506dc94`; result NOT recorded |
| Durable runners | **NOT RUN** on the final head |
| CI cycle | **NOT RUN** (gated by the discipline line) |
| Third D-43 panel | **NOT RUN** |

## NEXT — in order

1. **Record the non-heavy suite result.** Log:
   `~/gllvmTMB-0.6-evidence/m1/diagnostics/da267eaf-post-r9-suite.log`. Expect the prior
   `FAIL 0 | WARN 0 | SKIP 779 | PASS 7287`; the only behaviour-adjacent change was three
   `cli` message strings. **Investigate any deviation rather than accepting it.**
2. **Re-run the CRAN-configuration check** — `NEWS.md`/`man/` changed again, and the
   recorded result is three commits stale. Two NEW published-article URLs were added, so
   the `remote = TRUE` URL check matters this time.
3. **R-10 decision** from the maintainer.
4. **Freeze the SHA**, then durable runners, mirrored with `SHA256SUMS.txt` into
   `~/gllvmTMB-0.6-evidence/m1/final-receipt/<sha>/`.
5. **STOP** — push/CI is gated. Do not self-grant it.
6. Third D-43 panel once platform evidence exists.

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

Branch `codex/gllvmtmb-060-m1-baseline-20260720` @ **`e506dc94`** (tree clean, **4 commits
unpushed**), draft PR #778, this `LOOP/` kit, `docs/dev-log/known-residuals-register.md`,
`docs/dev-log/check-log.md`, and `~/gllvmTMB-0.6-evidence/`.

## RESUME

```text
Read LOOP/GOAL.md (incl. the 2026-07-21 amendment) -> LOOP/checkpoint.md ->
LOOP/decision-queue.md -> docs/dev-log/known-residuals-register.md.
M1 is WITHHELD. R-7/R-8/R-9 are closed; R-10 AWAITS SIGN-OFF and blocks the closing claim.
Head e506dc94, tree clean, 4 commits unpushed, guard PASSES.
Start by recording the non-heavy suite result from
~/gllvmTMB-0.6-evidence/m1/diagnostics/da267eaf-post-r9-suite.log, then re-run the
CRAN-configuration check (it is 3 commits stale and two new URLs were added), then get
R-10 signed off, then freeze the SHA and run the durable runners.
STOP before push/CI — it is gated by the goal's discipline line, and the goal's "close M1"
deliverable CONFLICTS with that gate. Do not resolve the conflict yourself.
```
