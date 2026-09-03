# After-task — gap-closure overnight arcs O1, O3–O7 (2026-09-02 → 09-03)

## Scope

Continuation of the reverse-parity gap-closure programme after PRs #1239 and #1240 merged.
Arcs run: O1 (refusals without a next step), O3 (zero-inflated multi-seed recovery), O4
(`ordinal_logit()`), O5 (`select_lv()` + `anova()`), O6 (`ordination_uncertainty()`), O7
(`censored_poisson()` engine). The lane branch `claude/lane-gapclose-overnight-20260902` holds the
LOOP kit; the autonomous session was never launched, so a conductor in the main session ran the arcs
with fresh sub-agent builders.

## Outcome

Merged to `main`: [#1248](https://github.com/itchyshin/gllvmTMB/pull/1248) (zero-inflated recovery
evidence), [#1251](https://github.com/itchyshin/gllvmTMB/pull/1251) (171 refusals given a next step;
bare-abort count 999 → 828), [#1250](https://github.com/itchyshin/gllvmTMB/pull/1250)
(`ordinal_logit()` at runtime family id 20).

Open: [#1249](https://github.com/itchyshin/gllvmTMB/pull/1249) (`select_lv()`/`anova()`, signed off,
queued on CI), and two drafts awaiting maintainer sign-off —
[#1253](https://github.com/itchyshin/gllvmTMB/pull/1253) `ordination_uncertainty()` and
[#1254](https://github.com/itchyshin/gllvmTMB/pull/1254) `censored_poisson()`.

Maintainer sign-off for #1249/#1250 is recorded as D-216 in the vault.

## Checks

- O1 branch: full suite FAIL 0 | WARN 55 | SKIP 880 | PASS 27020; `R CMD check` 0 errors / 0 warnings
  / 0 notes (25m 55s).
- O3: 450 fits on Totoro. The orchestrator recounted from the 450-row per-seed CSV rather than
  accepting the agent's summary table; two cells came out stricter because convergence was also
  required.
- O4: density identity 5.684e-14 on a fixed-effects-only fit; FD gradient 2.786e-08.
- O5: 48 assertions; empirical size of the boundary test 0.095 (MCSE 0.021) against a nominal 0.05.
- O6: 231 assertions, re-run by the orchestrator with `NOT_CRAN` set; checked against a hand-written
  dense inverse of a fresh joint precision on `d = 1` and `d = 2` fixtures, agreeing to 1e-6.
- O7: density identity 0.000e+00 (bit-identical); FD gradient 1.905e-10; all-uncensored fit matches
  `poisson()`; recovery holds at 4 seeds.

## Findings worth keeping

**Shipped recovery bars tuned on a few seeds do not generalise.** Across 50 seeds the zero-inflated
bars hold in 82% / 82% / 92% of seeds at the sizes the tests use, and the `zi_nbinom2` dispersion bar
in only 74%. The register rows now quote the measured fractions and stay `partial`. The test sizes
were deliberately **not** raised: the tests are regression guards, the register is where a certified
claim lives, and that distinction is now written into the rows.

**Ordination scores are rotation-pinned up to a sign, not up to a rotation.** `R/rotate-loadings.R`'s
header says the raw loadings carry "sign / rotation indeterminacy", which would make a per-axis
standard deviation meaningless. Measured on a fitted `d = 2` model, the strict upper triangle of
Lambda is exactly zero — `rr()` packs it structurally lower-triangular, so the only residual freedom
is a per-axis sign flip. Variance is sign-invariant, so a per-axis SD is well defined; only an
off-diagonal sign is convention.

**Cross-package corroboration on the zero-inflated families.** GLLVM.jl's 6,000-fit campaign varied
the number of responses where ours varied the number of units; both conclude recovery needs n large
relative to p, and that the negative-binomial dispersion failure is small-sample identifiability
shared with Gamma, Beta and Student-t rather than anything to do with zero inflation. Neither
campaign touched standard errors or coverage.

## Corrections made in the open

1. **A brief from the orchestrator was statistically wrong.** It stated that the naive full-degrees-of-
   freedom chi-square is anticonservative for a boundary test. It is conservative — the mixture sits
   below the full-df tail, so naive p-values are too large. The builder caught it, proved it
   algebraically and numerically, and corrected the comments it had already written from the premise.
2. **An agent reported an absence that was an artifact of where it searched.** It concluded GLLVM.jl
   had no comparable campaign, having read dated status reports as current; the campaign exists on an
   unmerged branch, invisible to a search of their `main`. Corrected in place with the cause recorded.
3. **A family-id collision was disclosed rather than hidden.** `censored_poisson()` and
   `ordinal_logit()` independently claimed runtime id 20. Its builder flagged the clash in three
   places; `censored_poisson` moved to 21 and every verification number was re-measured afterwards,
   because a wrong id dispatches the wrong likelihood while everything still appears to run.

## Two green signals that meant nothing

Both were caught by inspecting the artifact rather than the report, and both are worth remembering.

- **testthat printed "DONE" over a file in which every assertion had skipped** behind
  `skip_on_cran()`. The claimed 231 passes were real only once `NOT_CRAN` was set.
- **A merge watcher logged "#1249 MERGED" when no merge had occurred.** The script checked that CI was
  green but never checked the merge command's own result. The PR was still open and conflicting.

A third recurred three times: **merging a branch whose conflict markers leave a file unparseable makes
the bare-abort counter skip that file silently**, so the count comes out *below* the ceiling and reads
as a pass. Every count quoted from that point is preceded by a check that all 116 R files parse.

## Follow-up

- #1249 merges on green; #1253 and #1254 need maintainer sign-off (new public API; one a new family
  likelihood).
- 828 refusals still lack a next step ([#1247](https://github.com/itchyshin/gllvmTMB/issues/1247)),
  behind a ratchet that can only fall.
- `ordinal_logit()` and `censored_poisson()` ship on few-seed regression guards; neither has a
  multi-seed campaign, and their register rows say so.
- No coverage or interval evidence was produced for `ordination_uncertainty()`; both returned
  quantities are Wald.
