# After-task — HMSC cross-package scout (2026-07-29)

## 1. Goal

Answer the maintainer's question — *what can we learn from `Hmsc`
(<https://github.com/hmsc-r/HMSC>) and its publications, given it is Bayesian?*
— as an evidence-based assessment, without re-deriving the landscape review
already held in the brain.

## 2. Implemented

Nothing in `R/`, tests, NAMESPACE, or ROADMAP. Read-only scout producing two
documents:

- `docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md` (437 lines)
  — verified facts about `Hmsc`, a three-way capability table
  (`Hmsc` / `gllvm` 2.0.13 / `gllvmTMB` 0.5.0), a 13-item ranked
  adopt/adapt/decline recommendation, three claim-constraining literature
  findings, and an explicit negative-space section.
- A brain note (vault `memory/`) recording the cross-project findings so the
  next session recalls rather than re-scouts.

## 3a. Decisions and Rejected Alternatives

- **Recalled before scouting.** `DR3-gllvm-jsdm-2026-07-01` and the Bolker
  2026-07-28 follow-up already hold the competitive landscape and the
  "Ovaskainen is the closest subject match" correction. The audit explicitly
  does not repeat them; it covers only what they lack (package internals, test
  architecture, the frequentist-analogue split).
- **Filed as an `audits/` scout, not a `docs/design/` doc.** It reports and
  recommends; it settles nothing. Design 54's precedent
  (`2026-05-25-jason-cross-package-binomial-sigma-scout.md`) is the format.
- **Did not install `Hmsc`.** Installing is the maintainer's call and no claim
  here needs a live fit. Recorded as a residual.
- **Did not comment on issue #800**, though the findings bear on it directly
  (licence + fixtures). Posting to a public issue is outward-facing and was not
  requested. Surfaced for the maintainer instead.
- **Did not commit the two repo documents.** The working tree already carries
  untracked docs from prior sessions, the active branch
  (`claude/profile-coverage-remeasure-20260718`) is topically unrelated, and the
  2026-07-25 lane split warns against absorbing other lanes. Left on disk and
  reported rather than committed onto a mismatched branch.

## 4. Files Touched

Created:
- `docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md`
- `docs/dev-log/after-task/2026-07-29-hmsc-cross-package-scout.md` (this file)
- vault: `memory/HMSC scout (2026-07-29) — what transfers to frequentist GLLVM,
  and two open problems nobody has taken.md`

Modified / deleted: none. No file under `R/`, `tests/`, `man/`, `NAMESPACE`,
`DESCRIPTION`, or `ROADMAP.md` was touched.

Scratchpad only (outside the repo): three throwaway `Rscript` files used to read
`gllvm`'s `Rd_db`.

## 5. Checks Run

No package check was run, and none was warranted — no package file changed.
What was run:

| Command | Result |
|---|---|
| `Rscript` package-presence probe (9 JSDM packages) | `Hmsc` NOT INSTALLED; `gllvm` 2.0.13, `glmmTMB` 1.1.14, `TMB` 1.9.21 present |
| `getNamespaceExports("gllvm")` + `tools::Rd_db("gllvm")` | 56 exports, 8 help pages read |
| `gh api repos/hmsc-r/HMSC/contents{,/tests,/inst,/data,/data-raw}` | directory inventory + sizes |
| `curl` raw fetches: `DESCRIPTION`, `NAMESPACE`, `.Rbuildignore`, 7 test files, `simulateTestData.R`, 7 `man/*.Rd` | all 200 |
| repo greps: test counts, `data/`, `LazyData`, man-page example sourcing | 307 test files / 1908 `test_that`; `data/` **absent**; `LazyData: true`; 98/138 man pages have examples |
| structural check of the audit file | 437 lines, 13 headers, no broken sections |

## 6. Tests of the Tests

Not applicable in the usual sense — no tests were written. The analogue here is
whether the *claims* would survive being wrong, so the load-bearing ones were
sourced twice or first-hand:

- "`Hmsc` ships fixtures / is GPL-3" — read from the repository itself, not
  from a search snippet. These specifically **contradict** the prior record
  (logged UNCHECKED in the Bolker note), so they were verified directly.
- "`gllvm` already has X" — read from the **installed** 2.0.13 namespace and
  help database, not from web recall, because the whole
  already-transferred/not-transferred split turns on it.
- "`Hmsc`'s updater tests are weaker than their names" — quoted verbatim from
  `test-sampling.R` rather than characterised.
- Everything sourced only from a sub-agent carries `[A]`; inference carries
  `[I]`; prior notes carry `[R]`. A reader can tell what would fall over.

## 7a. Issue Ledger

- **[#800](https://github.com/itchyshin/gllvmTMB/issues/800)** — materially
  advanced, not edited. Two of its blockers are resolved by this scout:
  `Hmsc` is **GPL-3** (the AGPL-3 objection that ruled out vendoring `glmmTMB`
  material does not apply) and it **does** ship fixtures, including a fully
  specified known-truth DGP. Caveat recorded: their updater tests are
  change-detectors, so scope any oracle to the fitted-model and DGP level.
  Maintainer's call whether to post this to the issue.
- **`docs/design/05-testing-strategy.md:75`** — the "planned (Phase 5.5)"
  `Hmsc` capstone now has a ready-made fixture (`TD` is phylo + spatial + trait
  + hierarchical). Not edited; the design doc is not this lane's to change.
- No issue opened or closed.

## 8. Consistency Audit

Walked the neighbours the claims touch:

- Every prior `Hmsc` mention in the repo (6 files) was read before writing, so
  the audit extends rather than contradicts them. `00-vision.md:47`'s "do not
  copy their grammars wholesale" is honoured — the recommendation explicitly
  declines the grammar and takes the evaluation layer instead.
- The recommendation is checked against the mission-control NOW line: items 1–3
  are evidence-shaped (in scope for 0.6's stated blocker), 5–9 are
  capability-shaped (arguably not). Said so rather than implying everything is
  urgent.
- The claim-constraining findings (§5a) were checked *against existing fences*
  rather than proposed as new policy: Poggiato 2021 supports the standing
  "latent-scale correlation is not an interaction" rule; Norberg 2019 / Zurell
  2020 support the existing recovery-only framing. Both are external support
  for positions already held, and are labelled as such.

## 9. What Did Not Go Smoothly

- The `Hmsc` pkgdown site (`hmsc-r.github.io/HMSC/`) **404s** on every path.
  Worked around by reading `R/`, `man/` and `NAMESPACE` from source, which is
  more precise anyway.
- The vault note for `DR3` did not resolve by short identifier and initially
  routed to the wrong project (`symbolizer-docs`), returning a "not found" list.
  Recovered by reading via the full permalink. Worth knowing the short-title
  lookup is unreliable across projects.
- Two `Rscript -e` invocations failed on backslash escaping through the shell;
  switched to heredoc script files in the scratchpad.
- One draft claim had to be **retracted mid-write**: the first version of §4
  concluded "almost every transferable idea has already been transferred by
  `gllvm` 2.0". The frequentist-landscape scout falsified it — turnkey CV and
  CIs on variance-partition shares have been transferred by *nobody*. The
  section was rewritten into a two-half split. Recording this because the wrong
  version was the more quotable one.

## 10. Known Residuals

- `Hmsc` is **not installed**; nothing was fitted. No accuracy, runtime, or
  agreement claim is made, and none should be read in.
- `TD`'s fitted object was not checked for reproducibility from
  `simulateTestData.R` at current versions — the script is dated 2020-02-29.
- The Ovaskainen & Abrego (2020) book was not read; vignette *structure* was
  read, not vignette *content*.
- All literature carries `[A]`: DOIs recorded by sub-agents, not re-verified
  paper by paper. Treat as leads until grounded if any becomes load-bearing for
  a public claim.
- **Open risk flag, not resolved here**: the `gllvm` literature reports plain
  Laplace as measurably biased for binary responses, and gllvmTMB's binary paths
  are Laplace-only for 0.6 with EVA cut to 0.7. This needs a position before
  release even if the position is "documented limitation".

## 11. Team Learning

- **Memory receipt.** Recalled first, per the routing rule: brain
  `search_notes` (`search_all_projects=true`) surfaced `DR3-gllvm-jsdm` and the
  Bolker follow-up, both of which changed the shape of the task — the landscape
  was already done, so the scout aimed at package internals instead. The
  after-task cross-project rule was honoured by filing a findable vault note.
  No Golden-Set regression check: no known-mistake class was in scope.
- **The reusable technique**: for "what can we learn from package X", the
  landscape review is the *cheap* part and is usually already on file. The
  expensive, non-duplicable part is **reading their tests and their shipped
  fixtures** — that is where the transferable engineering ideas live, and no
  literature review surfaces them. Both genuinely new findings here (their
  block-conditional recovery pattern; their "is correct" tests not being
  correctness tests) came from the test directory, not from any paper.
- **A naming caution, from watching someone else pay for it**: `Hmsc` labels
  seed-pinned sum assertions `"updateX is correct"`. It reads as certification
  and is not. Our own opt-in gating (`GLLVMTMB_HEAVY_TESTS`) matches theirs; the
  naming should not.

## 12. Cross-Product Coverage

- **gllvmTMB** — primary target; findings above.
- **GLLVM.jl** — the capability gaps (held-out CV, fit metrics, conditional
  prediction) are engine-agnostic and apply to the twin. Not surveyed.
- **drmTMB / hsquared** — no direct read-across from this scout. The one
  shared thread is Bolker item 1 (sparse phylogenetic precision), which
  `Hmsc` implements as a user-facing `phyloFast` switch; that observation is
  recorded but the audit for it belongs to those repos.
- **Vault** — cross-team note filed and linked to four resolved hubs, so the
  next session on any of these repos recalls rather than re-scouts.
