# After-task: two public articles for the integrated two-source model

**Date:** 2026-08-16 · **Lane:** `claude/isdm-public-door-20260816` (Claude Code) ·
**Base:** `codex/isdm-range-amplitude-orthogonal` @ `bd2b261a` ·
**PR:** [#1016](https://github.com/itchyshin/gllvmTMB/pull/1016) (stacked on the isdm branch)

## 1. Scope

Finish `integrated-two-source-example.Rmd` to Tier-1 parity, write a second article
answering the design question, and get a `R CMD check` receipt for a PR that has no CI.

## 2. What shipped

**Article 1 — `integrated-two-source-example.Rmd`.** Was correct but not Tier-1: no figures
at all despite building a mesh it never plotted, raw `fit$report$...` access where
`extract_Sigma(fit, level = "spde_slope")` exists, numbers printed without interpretation,
non-standard front matter. Now: three captioned figures, the public extractor, interpretation
after every result, house front matter, a paragraph pre-empting the exact-contract error, a
statement of why the example is long-format only, and "See also".

**Article 2 — `integrated-survey-design.Rmd` (new).** *"How big does an integrated survey
design need to be?"* — the question a reader has **before** fitting. One small live fit fixes
the workflow; the design curve is the domain-growth campaign's 1,600 recorded fits, presented
from a visible data frame rather than re-run (fit cost is ~linear in cells: 9.6 s at 360,
107 s at 2,250). Renders in ~8 s.

**Two code fixes** (below) and a Totoro check receipt
(`docs/dev-log/2026-08-16-totoro-check-receipt-isdm-public-door.md`).

## 3. A plan correction made mid-arc

The approved plan put article 2 on the **nonspatial** arm, reasoning that Design 111's
recovery gates are cleared there. Reading the evidence file first — Ada had flagged exactly
this as the plan's fragility, and it fired — showed the domain-growth law is a **spatial**
result: it is measured on patch count, amplitude `med_rel`, and `cos95`. A nonspatial article
citing it would have been citing evidence that does not apply to what the reader is shown.
Article 2 therefore runs the same spatial arm as article 1; what differs is the question.

## 4. Two blockers found by review, in code already shipped in #1016

**Gauss** — the one review lens that had never run on the public-door change — derived its two
coherence claims from source rather than accepting them from the issues they came from. Both
hold, but only under conditions the admission predicate did not enforce:

- **`weights` meant two incompatible things across the two arms.** The survey arm is binomial,
  so `has_binom` is always TRUE in an integrated fit; that turns `weights` into a per-row trial
  count for the whole data frame while `weights_i` is simultaneously set to 1 on those same
  rows. One vector, a trial count on one arm and a likelihood exponent on the other — and the
  weighted-objective warning skips binomial rows, so it would have passed in silence. A
  documented `weights = 0` CV hold-out would have aborted with a misleading "binomial size"
  message.
- **Multi-trial survey rows were admissible and are not derivable.** The coherence argument is
  a thinned-Poisson one and holds for a single trial of support `a`. `cbind(successes,
  failures)` reaches `n_trials > 1` with no `weights` at all.

Both are now hard refusals with named condition classes, checked where `n_trials` exists.
The one-time notice also now tells users the presence-only arm needs its own reporting-rate
term — without one the arms share an absolute intercept and the fit implicitly claims the
absolute intensity the notice above it says is unavailable.

**Rose + Darwin** returned no blockers on the articles and one finding worth the gate: the
design article foregrounded `conv` reaching 1.000 and said nothing in prose about `pd_rate`
topping out at **0.555** at the largest measured design. The number was in the printed table,
but a reader skimming the narrative could have concluded that adding cells solves
admissibility. Now stated where the axes are introduced and added as a seventh "cannot
conclude" item.

## 5. The Totoro check, and what it found about the branch

**1 ERROR, 2 WARNINGs — none of it this lane's.** 46 test failures across five `test-g2*` /
`test-bfgs-smoke-contract.R` files. Diagnosed rather than assumed: those tests shell out to
runner scripts under `dev/`, `.Rbuildignore:21` excludes `^dev$`, and the tarball contains
**zero** `dev/` files. They guard for Windows, devtools, and Rscript, never for the scripts
existing.

Attribution measured, not asserted: the same five files run locally on macOS against both
`bd2b261a` and this lane's head give **164 passing, 0 failures, identical**.

> **This is a blocker for the isdm branch itself.** ~190 commits that cannot pass
> `R CMD check`, unnoticed because a PR stacked on a non-main branch never triggers CI. The
> 2026-08-15 EOD handover already carried `test-bfgs-smoke-contract.R` as unowned; this
> measures it and names the cause. Filed as separate work, not fixed here.

**The receipt is weaker than CI and says so:** one Linux box, and
`_R_CHECK_FORCE_SUGGESTS_=false` because Totoro lacks `DHARMa`, `ggforce`, `galamm`, `mirt`,
`nadiv`, `vegan`, `vdiffr` — so every check needing one of those, including all `vdiffr`
visual snapshots, did not run.

## 6. Checks

| Check | Outcome |
|---|---|
| `devtools::test(filter = "isdm\|offset\|family-within-trait\|augmented-slope")` | **0 failures, 0 errors** (1 deliberate heavy skip) |
| Both articles render | **OK** — 13.6 s and 8.1 s |
| `grep ":::"` both articles | none |
| `pkgdown::check_pkgdown()` | No problems found |
| Both registered in `_pkgdown.yml` | yes |
| Totoro `R CMD check` | see §5 and the receipt |

## 7. Definition of Done

1. **Implementation** — on the lane; merge is the maintainer's (API class).
2. **Simulation recovery** — *not claimed.* `ISDM-01` stays `partial`.
3. **Documentation** — roxygen + `man/` regenerated; NAMESPACE unchanged (no new export).
4. **Runnable example** — two of them, both rendering through the public route.
5. **check-log** — appended.
6. **Review** — Gauss, Noether, Rose, Darwin all engaged. Every lens the DISCIPLINE line named
   has now run, including the one the previous after-task recorded as a deviation.

## 8. Follow-ups

- Merge needs the maintainer.
- The unguarded `dev/`-dependent tests (filed separately) block the isdm branch's own check.
- Gauss's unfixed observations, all pre-existing: the Poisson arm has no `eta` cap where the
  cloglog arm is guarded at 700; the public route does not inherit the developer route's
  support/response validation; an AGHQ multistart heuristic still reads family from row one.
- The two articles share a ~50-line simulation block by design (each must stand alone); a
  future edit to one should check the other.
- Model 2 (multi-source) remains the next capability arc, untouched here.
