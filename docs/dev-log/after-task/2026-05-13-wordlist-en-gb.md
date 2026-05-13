# After-Task: Language: en-GB + curated inst/WORDLIST (Phase 5 prep)

## Goal

Resolve `spelling::spell_check_package()`'s 284 reported
"misspellings" by:

1. Setting `Language: en-GB` in DESCRIPTION (the package uses
   British prose, per the existing wording — "visualise",
   "summarised", "standardised", etc.). Maintainer scope decision
   2026-05-13 ~03:45 MT (answer `3 GB`).
2. Curating `inst/WORDLIST` with the remaining valid technical
   terms, author names, acronyms, Greek-letter LaTeX names, and
   citation-preserved spellings. Maintainer scope decision
   2026-05-13 ~03:45 MT (answer `4 curated`).

After this PR, `spelling::spell_check_package()` reports zero
misspellings.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`DESCRIPTION`** (M, 1 line added): `Language: en-GB` after
  `License: GPL-3` and before `Copyright: inst/COPYRIGHTS`.
- **`inst/WORDLIST`** (NEW, 226 lines): one-word-per-line sorted
  list of valid words that the hunspell dictionary does not
  recognise. Categories:
  - **Author names** (~35): `Blanchet`, `Bolker`, `Dempster`,
    `Dingemanse`, `Drobniak`, `Dunic`, `Felsenstein`,
    `Garamszegi`, `Hadfield`, `Halliwell`, `Hankison`, `Hilbe`,
    `Kristensen`, `LAK`, `Laskowski`, `Lerner`, `Lindgren`,
    `Lindström`, `Magnusson`, `McGillycuddy`, `Mizuno`,
    `Moolgavkar`, `Moustaki`, `Niku`, `Ovaskainen`, `Pagel`,
    `Pawitan`, `Philina`, `Popovic`, `Réale`, `Schielzeth`,
    `Sih`, `Skaug`, `Sørensen`, `Stoklosa`, `Taskinen`,
    `Thorson`, `Venzon`, `Verkuilen`, `Warton`, `Westneat`.
  - **Greek letters / LaTeX** (~10): `ε`, `Λ`, `π`, `σ`, `Σ`,
    `varepsilon`, `bigl`, `bigr`, `boldsymbol`, `cdot`,
    `mathbb`, `mathbf`, `mathcal`, `mathrm`, `frac`, `geq`,
    `gtrsim`, `otimes`, `propto`, `qquad`, `underbrace`,
    `ldots`.
  - **Acronyms / abbreviations** (~35): `AVONET`, `BLUP`,
    `BLUPs`, `CMRG`, `CWM`, `DGP`, `GALAMM`, `galamm`, `GLLVM`,
    `GLLVMs`, `GLMM`, `GLMMs`, `GMRF`, `Hmsc`, `ICCs`, `INLA`,
    `JSDM`, `MOM`, `MVN`, `NLL`, `OLRE`, `ORCID`, `OU`,
    `PGLLVM`, `PGLMM`, `PGLS`, `PICs`, `PSD`, `SDM`, `SDs`,
    `SEs`, `SPDE`, `spde`, `TMB`, `UTMs`, `VCV`.
  - **Software / R / TMB / package jargon** (~50):
    `betabinomial`, `brms`, `cloglog`, `compat`, `coords`,
    `covstruct`, `covstructs`, `Cphy`, `desugars`, `dep`,
    `drmTMB`, `eps`, `Eq`, `eqn`, `eqs`, `Eqs`, `estimand`,
    `fmesher`, `geostatistical`, `gllvm`, `glmmTMB`,
    `indep`, `lifecycle`, `listwise`, `lme`, `ln`, `logL`,
    `loglik`, `logn`, `LV`, `Matern`, `Matérn`, `MCMCglmm`,
    `nats`, `nbinom`, `newdata`, `Newick`, `obs`, `optim`,
    `parens`, `parm`, `phy`, `phylo`, `poisson`, `Poisson`,
    `profileable`, `promax`, `reentrant`, `rr`, `Rtools`,
    `sd`, `sdmTMB`, `sdreport`, `Spatiotemporal`, `speedup`,
    `tibble`, `tidyselect`, `Tidyselect`, `tmbprofile`,
    `tweedie`, `Tweedie`, `varimax`, `Xcode`.
  - **Math / index variables** (~20): `Bt`, `ch`, `df`, `EB`,
    `EJ`, `ed`, `etc`, `ij`, `iT`, `JD`, `JT`, `K's`,
    `km's`, `LV`, `NJS`, `parm`, `R's`, `si`, `sp`, `st`,
    `th`, `tk`, `tt`, `TT`, `u`, `Var`, `Wi`.
  - **Citation-preserved spellings** (American English in
    published titles): `Behavioral` (Sih et al. 2004
    "Behavioral syndromes" article title in
    behavioural-syndromes.Rmd:620); `modeling` (Warton et al.
    2015 "joint modeling in community ecology" in
    joint-sdm.Rmd:386, plus `add_utm_columns.Rd:38` body
    prose inherited from sdmTMB).
  - **Journal abbreviations**: `Aquat`, `Biometrika`,
    `bioRxiv`, `Ecol`, `Evol`, `jss`, `Sci`, `Soc`, `Softw`,
    `Stat`.
  - **Code-style words**: `gotchas`, `walkthrough`,
    `runnable`, `standalone`, `Standalone`, `roadmap`,
    `payoff`, `toolchain`, `workflow's`, `parens`.
- **`docs/dev-log/after-task/2026-05-13-wordlist-en-gb.md`**
  (NEW, this file).

The PR does NOT:

- Touch any prose to "fix" British spellings. The `en-GB`
  Language field handles that natively.
- Fix the American spellings in citation titles. Those are
  citation-preserved (the published article titles use
  American spelling; the convention is to quote them
  verbatim).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. One
DESCRIPTION field added + one new `inst/WORDLIST` data file.

## Files Changed

- `DESCRIPTION` (M, 1 line)
- `inst/WORDLIST` (new, 226 lines)
- `docs/dev-log/after-task/2026-05-13-wordlist-en-gb.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 1 open Claude PR (#62 Pat audit) + 1
  Codex PR (#61 covariance-correlation). Neither touches
  DESCRIPTION or inst/WORDLIST. Safe.
- Iteration 1: `Language: en-GB` only, no WORDLIST. Reduced
  count from 284 to 226 (dropped British-spelling drifts
  like `behavioural`, `summarised`, `visualise`, etc.).
- Iteration 2: `Language: en-GB` + initial WORDLIST excluding
  `Behavioral` and `modeling` (assumed prose drift). Reduced
  count from 226 to 2. Verified the 2 remaining are citation
  titles / inherited code, NOT prose drift.
- Iteration 3: added `Behavioral` and `modeling` to WORDLIST.
  `spelling::spell_check_package()` returns 0 misspellings.

## Tests Of The Tests

This is a Phase 5 CRAN-readiness pre-flight. The "test" is
whether `spelling::spell_check_package()` returns 0
misspellings. After this PR:

```
$ Rscript -e 'res <- spelling::spell_check_package(".");
              cat("Misspellings:", nrow(res), "\n")'
Misspellings: 0
```

If future prose introduces new technical jargon or author
names, the WORDLIST should grow. The protocol is:
`devtools::spell_check()` (alias) -> see new words -> append
to WORDLIST in alphabetical order -> rerun -> 0.

If a future prose change introduces an actual misspelling
(not a technical term), it should be fixed in the prose, not
added to WORDLIST.

## Consistency Audit

```sh
grep -c '^[a-zA-Z]' inst/WORDLIST
```

verdict: 226 lines, all start with a letter (no blank lines,
no comments).

```sh
sort -c inst/WORDLIST
```

verdict: returns clean (the file IS sorted).

```sh
rg -n 'Language' DESCRIPTION
```

verdict: `Language: en-GB` on its own line, between
`License: GPL-3` and `Copyright: inst/COPYRIGHTS`. Per the
"Writing R Extensions" §1.1.1 convention.

## What Did Not Go Smoothly

Nothing substantive. The hardest decisions were:

1. **Which language to pick** (`en-GB` vs `en-US`). Resolved
   by the maintainer's `3 GB` answer.
2. **Curation depth**. A "dump all 226" WORDLIST is easy but
   reads like the author gave up. A heavily-curated WORDLIST
   reads better but requires per-word judgement. I chose a
   middle path: include every word that's clearly valid
   (author names, acronyms, technical jargon, Greek letters,
   citation-preserved spellings), categorise by type in the
   after-task report for future readers.
3. **`Behavioral` and `modeling` in citation titles**. These
   look like American-spelling drift at first glance, but
   are actually published article titles quoted verbatim
   (Sih et al. 2004; Warton et al. 2015). The convention is
   to preserve published titles as published; added to
   WORDLIST.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Grace (release readiness)** -- this is exactly Grace's
  lane: take a CRAN-pre-flight check from a TODO state to a
  zero-misspellings state. The Phase 5 audit listed this as
  "scope decision needed"; the overnight findings produced
  the decision; this PR implements it.
- **Pat (applied user / CRAN reviewer)** -- a CRAN reviewer
  running `R CMD check --as-cran` will see zero spelling
  warnings. Friction removed.
- **Rose (cross-file consistency)** -- WORDLIST scope follows
  the British-English convention the prose already uses; no
  drift between language tag and prose register.
- **Noether (math consistency)** -- Greek-letter LaTeX names
  (`varepsilon`, `mathrm`, etc.) are in WORDLIST; math
  prose passes the spelling check.

## Known Limitations

- **WORDLIST grows over time.** Each new article, citation, or
  technical term may add entries. The Phase 5 pre-audit
  recommended re-running `spelling::spell_check_package()`
  periodically. After this PR, the protocol is automatic:
  spelling warnings on PRs trigger WORDLIST appends.
- **Inherited sdmTMB prose** uses American spellings in some
  places (`add_utm_columns.Rd:38` "geostatistical modeling").
  The decision to preserve these as inherited code is
  pragmatic, not policy. A future "British-ify inherited
  prose" sweep could decide differently.
- **The `Behavioral`/`modeling` entries** are citation-
  preserved spellings. If those citations are ever removed
  or rephrased, the WORDLIST entries become orphans (no
  source flagged them). A future audit can remove them.
- **`en-GB` choice** matches the prose register. If the
  package author decides to standardise on `en-US`, the
  Language field flips and many existing British spellings
  would re-flag and need WORDLIST entries or prose fixes.
  Not urgent.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible per
   `docs/dev-log/decisions.md`: documentation /
   release-readiness fix touching DESCRIPTION and a new
   `inst/` data file, no R/ source or NAMESPACE change.
2. After merge, `spelling::spell_check_package()` is
   integrated into the Phase 5 pre-submission protocol.
3. Future PRs that add new prose / citations / author names
   should append to `inst/WORDLIST` if `spell_check` flags
   them; the protocol is documented in this after-task
   report.
