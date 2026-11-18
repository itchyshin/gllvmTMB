# After-task: the integrated two-source model fits through public `gllvmTMB()`

**Date:** 2026-08-16 · **Lane:** `claude/isdm-public-door-20260816` (Claude Code) ·
**Base:** `codex/isdm-range-amplitude-orthogonal` @ `bd2b261a` ·
**Commits:** `b131c155`, `751c1217`, `fc2f4465`, `56477e6a`, `36475a3b`

## 1. Scope

Make the two-source integrated SDM fittable through the ordinary public
`gllvmTMB()` call, and rewire the example article to it.

## 2. What changed, and why the plan changed first

The inherited baton (`docs/dev-log/handover/2026-08-15-claude-handover-isdm-public-api.md`)
specified an **exported wrapper** — `fit_isdm()` or `gllvmTMB_isdm()` — over
`.gll_isdm_fit()`, and called extending `gllvmTMB()` the "highest-risk class
avoided". The maintainer overrode that at this lane's first checkpoint:
*"do we need a new function?? — cannot you use gllvmTMB??"*

The record supports the override. Issue **#945** already specifies the design in
the maintainer's own words — *"design the smallest interface change that exposes
it — a `family` column honoured per row rather than collapsed per trait"*, with
encoding **(A)** chosen and **(B)** recorded as considered-and-rejected — and
`CLAUDE.md` states the invariant *"Both shapes go through one entry point:
`gllvmTMB()`"*, which is also why `gllvmTMB_wide()` is soft-deprecated.

**Nothing needed building.** Both blockers were already implemented and fenced
to the unexported route:

| Blocker | Issue | Where | Was |
|---|---|---|---|
| Per-row family within a trait | #945 | `R/fit-multi.R` `allow_isdm_mixed` | internal-attribute-keyed |
| Offset on binomial(cloglog) | #946 | `R/offset.R` `allow_isdm_cloglog` | internal-attribute-keyed |
| Spatial augmented slope | — | `R/fit-multi.R` token identity | namespace-token-keyed |

Admission is now **structural**: `.gllvmTMB_integrated_two_source_contract()` is
the single definition of the admitted model, and both the developer route and a
public caller pass through it. **No new export; NAMESPACE unchanged.** No
likelihood, TMB template, or 5×3 formula-grammar change.

## 3. Checks run, with outcomes

| Check | Command | Outcome |
|---|---|---|
| Public spatial fit | hand-built long table, no `:::` | **converged (0)** in 11.3 s; one-time notice fired |
| Focused tests | `devtools::test(filter = "isdm\|offset\|family-within-trait\|augmented-slope")` | **0 failures, 0 errors**, 1 deliberate skip (heavy) |
| Public ≡ developer | new assertion in `test-isdm-developer-fit.R` | same objective (1e-6) and parameters (1e-4) |
| Article render | `rmarkdown::render()` | **OK, 12.4 s**; `grep ":::"` → none |
| Docs | `devtools::document()` | clean; **NAMESPACE unchanged** |
| pkgdown | `pkgdown::check_pkgdown()` | **No problems found** |

**Deliberately not run:** full `devtools::test()` and `R CMD check --as-cran`.
The maintainer asked for the Mac to be kept light and other lanes were loaded;
3-OS CI runs on the PR, and a full check on Totoro before merge is the
maintainer's call. This is a Definition-of-Done item 1 deviation, stated rather
than skipped silently.

## 4. The adversarial review, and what it caught

A fresh-context Noether+Rose pass (Opus) reviewed the first three commits and
found a **real fence bypass**, fixed in `56477e6a`:

> Every clause of the predicate was **global over the data frame**. An ordinary
> *between*-trait mixed-family fit — trait A all Poisson/gbif, trait B all
> cloglog/survey — satisfied it while containing no integrated species at all,
> and was handed the cloglog offset and the augmented spatial slope. One dummy
> gbif row bought a survey-only dataset the same access.

The predicate now requires **every trait to carry both arms** and fails closed
on absent/misaligned labels. The review also produced: the slope-column pin on
the structural spatial route, order-insensitive `names(family)`, the corrected
`R/offset.R` comment, and — reader-facing — the article's **mis-paired
truth/estimate table** (`factor()` sorts species alphabetically, so simulated
truth printed against the wrong columns). That last one predates the lane but
the chunk was rewritten here and it was printing misleading numbers.

Review items **not** actioned, deliberately: the `.frequency = "once"` notice
can be consumed by a call that later aborts (cosmetic); the `\dontrun{}` example
references undefined objects (matches the neighbouring example's style).

## 5. Definition of Done

1. **Implementation** — on the lane, not yet on `main`; 3-OS CI runs on the PR.
2. **Simulation recovery** — *not claimed.* Register row `ISDM-01` is `partial`
   and says so: reachability and refusal-narrowness are established; estimator
   accuracy is not. Design 111's protocol is nonspatial-only and its gates are
   **not cleared for the spatial arm**, which rests on frontier-campaign
   experience (~7,200 fits).
3. **Documentation** — roxygen on the family surface + regenerated `man/`.
4. **Runnable example** — the article fits and renders through the public route.
5. **check-log** — appended.
6. **Review** — Noether + Rose engaged (§4). **Gauss did not review the offset
   change independently**; the coherence argument (cloglog offset = change of
   support) is carried from #945/#946 and the existing source comment, not
   re-derived here. Worth a look before merge.

## 6. Register and issues

`ISDM-01` added (new prefix — **MIS-37 is already claimed** by
`claude/predict-missing-se-20260815`; the preflight flagged 15 duplicate design
slots, so the ID was chosen to avoid a race). **#945 and #946 are closable** on
this evidence; the PR says so rather than auto-closing them, since the merge
decision is the maintainer's.

## 7. Follow-ups

- Merge needs the maintainer (API class).
- Gauss on the offset-coherence argument.
- Model 2 (multi-source, `n_sources > 2`) is the next capability arc per
  `bd2b261a` — explicitly **not** in this lane.
- `.prepare_isdm_contract()` could later be exported as a data-assembly
  convenience; the article shows the assembly by hand instead, which reads better.
