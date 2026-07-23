# M4 reader-surface overclaim audit — dossier for the page review

**2026-07-22, at `70e070be` (post-D-41).** A 10-agent workflow swept six reader-facing surfaces
for coverage/calibration overclaims, each candidate finding then handed to an adversarial verifier
told to **refute** it (default `is_real_overclaim = false`). This is an **audit, not a rewrite** —
every item below is a *proposal for the maintainer's page-by-page review*, per the standing rule that
0.6's reader wording is settled *with* Shinichi, not batch-edited.

## Headline

**The hard surfaces are clean.** README, NEWS, DESCRIPTION, the shipped vignette
(`vignettes/gllvmTMB.Rmd`), and the user-facing `cli`/`message`/`warning` strings across `R/` (beyond
the five files already reviewed for R-11) returned **zero** candidate overclaims. The R-11 sweep and
the honesty-fencing already in place did their job on the surfaces a user hits first.

The audit found **4 candidates, all in `man/`**, and its verifiers refuted all four. **I re-read the
journal rather than trust the count (the standing "read the log, not the summary" rule applies to my
own workflow too), and I disagree with the panel on one of them.** Corrected synthesis below.

## The one the panel got wrong — a real item

**`R/kernel-helpers.R:13` (roxygen) → `man/make_cross_kernel.Rd:40`.** The text reads:

> "The generic `kernel_*()` surface and the **validated** `extract_Gamma()` coevolution gate are
> documented separately."

The verifier refuted this as "descriptive output, not a calibration claim." That reasoning cuts the
**wrong way**: if `extract_Gamma()` only produces descriptive output, calling its gate *validated* is
*more* questionable, not less. And it is **internally inconsistent** — **line 281 of the same file**
explicitly warns *"…has **not** been calibrated, so do not report it as a **validated** confidence
[interval]."* One file uses "validated" as a bare virtue on line 13 and forbids that exact word on
line 281.

- **Severity:** medium. "Validated" modifies a *code gate* (a feature), not an interval, so it is not
  the flagrant "validated coverage" that R-11 hunted — but it is the exact word `docs/design/75:99`
  flags, on an **evolutionary-inference** construct, in a first-CRAN experimental package.
- **Proposed fence (your call):** drop the adjective — "the `extract_Gamma()` coevolution gate is
  documented separately" — or replace "validated" with a precise, defensible word ("dispatch-tested",
  or name what was actually tested). **Reader-facing wording → your decision, not mine to apply.**

## The three the panel refuted correctly — but they are M4 page-review candidates

These are **not** overclaims as written (the verifiers were right that a `\title{}` or `\value{}`
using "confidence intervals" is descriptive terminology, not a calibration assertion). But they are
the inference topics most exposed to the R-2 / CI-08 gap, and **none carries an explicit
"intervals are not coverage-calibrated" caveat** — which is exactly the honesty-fencing M4 is for.

| Topic | What it offers | Caveat present? | Page-review suggestion |
|---|---|---|---|
| `man/extract_phylo_signal.Rd` | profile/Wald/bootstrap CIs on per-trait phylogenetic signal H² (`ci=TRUE`) | none found | add a one-line "point estimates supported; interval coverage not calibrated" note |
| `man/loading_ci.Rd` | Wald / Fisher-z CIs on loadings; **worked example is a binomial-probit fit** (a non-Gaussian, non-cleared cell) | none found | same one-line caveat; consider whether the example should be Gaussian |
| `man/extract_repeatability.Rd` | Wald + parametric-bootstrap CIs on repeatability (estimand includes family-specific variance) | partial ("point estimates and percentile bounds rather than refitting") | strengthen the existing note toward the calibration caveat |

## What this audit did NOT cover

- **`vignettes/articles/`** — the pkgdown-only articles (not shipped, excluded from `.Rbuildignore`
  scope) were out of scope; they are a separate M4 sweep.
- **Figures and printed `print`/`summary` method output** — audited only as `cli`/`message` strings,
  not by rendering. A rendered-output pass belongs in the page review.
- **Whether the proposed fences are the right words** — that is the review itself, and it is yours.

## Provenance

Workflow `wf_66ad8b73-0b3`, 10 agents, 0 errors, ~657k subagent tokens, 247s. Per-agent returns:
`…/subagents/workflows/wf_66ad8b73-0b3/journal.jsonl`. Six find-agents (one per surface) → adversarial
verify per candidate → consolidation. The consolidation reported `confirmed_count: 0`; **this dossier
corrects that to one medium item plus three page-review candidates, after a human re-read of the
journal.**
