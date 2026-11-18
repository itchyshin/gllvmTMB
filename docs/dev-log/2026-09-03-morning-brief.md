# Morning brief — gllvmTMB gap-closure programme, 2026-09-03

`main` is at `cbf7b4d8e`. Written by the Claude lane at 06:30; every number below was
re-verified by the orchestrator, not copied from a builder's report.

## What you need to decide (three things)

**1. Two draft pull requests need your sign-off.** Both add public API, which CLAUDE.md
reserves for you.

- **[#1250](https://github.com/itchyshin/gllvmTMB/pull/1250) — `ordinal_logit()`**, the
  cumulative-logit ordinal response family. Decide: the reuse of `ordinal_probit`'s cutpoint
  machinery at runtime id 20; shipping on three-seed recovery evidence with a `partial` register
  row; and the `ordinal_logit()` / `cumulative_logit()` name split (the latter is the
  missing-predictor imputation family and is untouched).
- **[#1249](https://github.com/itchyshin/gllvmTMB/pull/1249) — `select_lv()` and `anova()`**.
  Decide: `select_lv()` refitting rather than reusing a fitted object; shipping the chi-bar
  boundary test at a measured size of about 0.095 against a nominal 0.05 rather than withholding
  p-values until it calibrates; and exporting the `AIC`/`BIC` methods that were previously de
  facto internal.

**2. A sequencing trap, before either of those merges.** Once
[#1251](https://github.com/itchyshin/gllvmTMB/pull/1251) lands, the package-wide ceiling on
refusals that lack a next-step line drops to 828. Both drafts add new refusals. If any of those
lack a next-step line, the branch will fail the ratchet test the moment it takes `main` — which is
exactly what turned the zero-inflated PR's CI red yesterday. Check it before merging, not after.

**3. Two ports remain unstarted**, both filed with the Julia reference implementation named:
[#1243](https://github.com/itchyshin/gllvmTMB/issues/1243) `ordination_uncertainty()` and
[#1244](https://github.com/itchyshin/gllvmTMB/issues/1244) the `censored_poisson()` engine (whose
constructor is exported today but has no likelihood behind it).

## What landed

| | |
|---|---|
| [#1239](https://github.com/itchyshin/gllvmTMB/pull/1239) | Gap closure: refusals that name a working route, plain-language front page, the R capability ledger and parity tool, 0.7 hygiene |
| [#1240](https://github.com/itchyshin/gllvmTMB/pull/1240) | Zero-inflated `zi_poisson()`, `zi_nbinom2()`, `zi_binomial()` |
| [#1248](https://github.com/itchyshin/gllvmTMB/pull/1248) | The recovery evidence those families were missing |
| [#1251](https://github.com/itchyshin/gllvmTMB/pull/1251) | 171 more refusals given a next step; count 999 → 828 (open, set to merge on green CI) |

Issues [#1241–#1247](https://github.com/itchyshin/gllvmTMB/issues/1247) carry the rest of the
reverse-parity backlog. The mission-control board now reads the new R ledger, so its twin-parity
page shows real Julia-only rows instead of zero by construction.

## The finding worth your attention

**The shipped recovery tests were tuned on a handful of seeds and do not generalise.** A 450-fit
campaign on Totoro measured how often the predeclared bars actually hold across fifty seeds:

| family | size the test uses | holds | size that works | holds |
|---|---|---|---|---|
| `zi_poisson` | 200 | 82% | 400 | 98% |
| `zi_nbinom2` | 400 | 82% | 800 | 98% |
| `zi_binomial` | 250 | 92% | 500 | 100% |

For `zi_nbinom2` the dispersion bar is worse: it holds in 74% of seeds at n = 400 and 98% at
n = 800. The register rows now quote these fractions and stay `partial`. I did not quietly raise
the test sizes: the tests are regression guards, the register is where a certified claim lives, and
that distinction is now written into the rows.

The same caution applies to the new `ordinal_logit()` in #1250, whose bars were set from a
pre-run on one of its own three test seeds. Its PR says so.

## Three corrections, recorded rather than smoothed over

1. **I gave a builder a wrong premise.** I wrote that the naive full-degrees-of-freedom
   chi-square is anticonservative for a boundary test. It is the opposite — the mixture sits
   below the full-df tail, so the naive test returns p-values that are too large and rejects too
   rarely. The builder caught it, proved it algebraically and numerically, and fixed the comments
   it had already written from my premise.
2. **An agent reported an absence that was not real.** It concluded the Julia twin had no
   comparable recovery campaign, having read dated August status reports as if current; the
   campaign exists but sits on an unmerged branch, invisible to a search of their `main`. The
   correction and its cause are written into the results file.
3. **The zero-inflated families' own dispersion caveat was understated** in yesterday's first
   draft: two of six traits exceed the 30% bar on every seed tried, not one. A detector for that
   runaway now exists.

The cross-package comparison that came out of correcting (2) is the strongest evidence here: the
Julia campaign varied the number of responses, ours varied the number of units, and both conclude
that recovery needs n large relative to p and that the negative-binomial dispersion failure is
small-sample identifiability shared with Gamma, Beta and Student-t rather than anything to do with
zero inflation. Neither campaign touched standard errors or coverage, so neither supports an
interval claim.

## Still owed

- Multi-seed recovery for `ordinal_logit()` before its register row could leave `partial`.
- The remaining 828 refusals without a next step (#1247), behind a ratchet that can only fall.
- `dispersion()` extractor and the `61-capability-status.md` refresh, deferred from the first arc.
- The overnight lane branch itself (`claude/lane-gapclose-overnight-20260902`) holds the LOOP kit;
  it never ran as an autonomous session, so this work was done by a conductor in the main session.
