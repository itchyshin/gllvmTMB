# 🔴 Codex adversarial review — findings for Shinichi's pre-submit check

**2026-07-23.** An independent Codex adversarial pre-CRAN review (different tool + model, live
toolchain) ran on `v0.6.0-rc.1`. Verdict: **do not submit yet.** Below, each finding is checked
against the artifacts — Codex made two tooling errors, but caught **one real, important thing about
the central honesty claim.** Nothing has been changed; this is for your decision.

## 1. 🔴 THE DECISION — the "calibration is established" wording may overclaim (a CLASS)

**Codex's finding, and I judge it CORRECT on the merits.** The D-41 honesty line says:

> "…interval calibration **is established** only for the Gaussian cases that cleared the coverage gate."

But `docs/design/75:96-99` states:

> "**No cell in this matrix is empirical-coverage-calibrated** … a cell may not be described as
> calibrated on the strength of this matrix. The empirical coverage gates are CI-08 and CI-10 … which
> remain open/failing."

And the project's own record agrees with design/75, not with the wording: the Sigma_unit certificate
was **provisional / withheld at 0.95**, and **CI-08 failed** (13/15 cells <94%). So "**is
established**" asserts more than the evidence supports.

**It is a class, not one line** — the "cases that cleared the coverage gate" carve-out repeats on:

| Surface | Location |
|---|---|
| DESCRIPTION | `:28-29` |
| README | `:13-14` |
| `.onAttach` startup message | `R/zzz.R` |
| NEWS.md boundary bullet | (M1 decision 2) |
| `loading_ci` / `extract_phylo_signal` / `extract_repeatability` caveats | the `@section Interval calibration:` blocks |

My earlier `morphometrics.Rmd:36` article finding flagged the *same* implicature — so this is a
consistent pattern I under-weighted and my same-model reviewers rationalised. Cross-tool review caught it.

**Your decision.** If you agree it overclaims, the fix is a strictly-honest reword across the class,
which requires an **rc.2** (frozen RC). Proposed replacement (your voice, your call):

- Current: *"…interval calibration is established only for the Gaussian cases that cleared the coverage gate."*
- Option A (strict, matches design/75): *"…no cell's interval coverage is certified; routes exist and
  have focused-test evidence only."*
- Option B (keeps the nuance): *"…interval coverage has been empirically studied for some Gaussian
  cases but is not certified for any cell."*

I recommend a reword (A or B). **Held for you — I did not touch it.**

## 2. Codex's other findings — checked, mostly not blocking

- **"`\dontrun` is 0; the claimed 72 is false."** ❌ **Codex is wrong.** It genuinely is **72**
  `\dontrun{}` blocks (`grep -l '\dontrun{' man/*.Rd` = 72; Codex's `rg -F '\\dontrun{'` used a
  double backslash and under-matched). My original flag stands: 72 is high; CRAN prefers `\donttest`
  for merely-slow examples. Advisory, **held** for an optional pre-submit pass.
- **"0 Rd missing `\value`."** Imprecise — 135/139 topics have `\value`; ~2 exported function-topics
  (`ordiplot`, `gllvmTMB_multi-methods`) lack it. The `--as-cran` lane is satisfied. Advisory, held.
- **"BLOCKER — could not independently rebuild the tarball."** This is a **Codex sandbox limitation**
  (`mkdir` denied), **not a package defect.** The `0/0/1` result is verified by *this* lane multiple
  times (the m5-rc1 ledger). The genuinely-independent cross-check is **win-builder R-devel** — which
  is exactly why it matters, and it is in your inbox pending.
- **"NOTE — HEAD (`19a65843`) ≠ tag (`e9bc655a`)."** Fair precision point. The intervening commits are
  all `.Rbuildignore`d (checkpoint, cran-comments, docs), so there is **no package-source delta** — the
  tarball is from the frozen source — but "the worktree is exactly frozen" is loose; the *shipped
  content* is byte-identical, the working tree has moved by docs only.

## 3. Spelling audit (mine, en-GB) — advisory, held

DESCRIPTION declares `Language: en-GB`. A few **user-facing** US spellings in shipped files:
`"modeling"` (`add_utm_columns` Rd), `"summarized"` (`extract_cross_correlations` Rd), `"standardize"`
in some `cli` errors. Most other hits are **false positives** (a book-title citation "behavior";
`fig.align="center"`, `normalize=TRUE`, `initialize` are code keywords). Advisory; `--as-cran` did not
flag. Held — would fold into an rc.2 if you do one.

## Net recommendation

**One decision gates everything: the calibration wording (§1).** If you reword it → rc.2 (I rebuild,
re-tag `v0.6.0-rc.2`, re-run the exact-tag checks, and could fold in the `\dontrun`/spelling polish at
the same time). If you judge the current wording defensible → the RC stands and only win-builder
R-devel + your submit remain. **Either way, I have submitted nothing and will not.**
