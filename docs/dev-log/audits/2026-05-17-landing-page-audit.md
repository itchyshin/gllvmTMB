# Landing-page audit (Pat + Rose) — 2026-05-17

**Date**: 2026-05-17
**Auditors**: Pat (reader UX) + Rose (citation + consistency discipline)
**Trigger**: maintainer 2026-05-17 surfaced two parallel concerns:
(a) the "Hadfield A⁻¹" matrix label is confusing without a full
citation; (b) the rendered landing page looks "crowded and
messy". Vision rule #2 (Pat + Rose review BEFORE edits) was not
applied to `README.md` during Phase 0A / 0C — this audit closes
that gap.

This doc surfaces **9 concrete actions** in 5 buckets (CUT /
FIX / REORDER / TIGHTEN / DEFER) for maintainer ratification.
Each item is a one-line decision; the executing PR is a single
~30–45 min `PR-0C.LANDING-PAGE-FIX`.

## Verdicts

- **Pat** (reader UX, applied PhD ecologist): "Pat bounces after
  30 seconds." The first two paragraphs work (biology-first,
  no jargon), but the page then explodes into crowding: the
  28-row "Status of supported features" matrix dominates the
  viewport before the reader sees a worked example. Pat never
  reaches the "Tiny example" or vignette links.
- **Rose** (citation + consistency): **WARN — 3 citation
  failures, 0 register-row resolution failures, 0
  status-mapping mismatches, 0 PR-# stale references, 0
  `@export` / `_pkgdown.yml` parity gaps**. The Hadfield label
  surfaces one missing citation; the same discipline gap shows
  up in 2 more "Nakagawa 2022" references.

## Triage table

| # | Bucket | README line(s) | Issue | Proposed fix | Decision |
|---|---|---|---|---|---|
| **1** | **FIX** (citation) | L140 | `**Hadfield A⁻¹ phylogenetic + paired …**` — author-surname-only label, no full citation. | Replace `Hadfield A⁻¹` with `Hadfield & Nakagawa (2010) sparse $A^{-1}$`; keep the math symbol $A^{-1}$ as math, the citation as a parenthetical. | maintainer ratify |
| **2** | **FIX** (citation) | L145 | `**meta_V(scale = "proportional") (Nakagawa 2022)**` — year-only, no journal / DOI. | Replace `(Nakagawa 2022)` with `(Nakagawa 2022, *Res. Synth. Methods*)` or whichever the actual journal is — maintainer to confirm publication venue. | maintainer ratify (need journal) |
| **3** | **FIX** (citation) | L337 | `**meta_V(scale = "proportional")** — Nakagawa 2022 unifying weighted-regression / meta-analysis mode` — same year-only citation in the Deferred section. | Same fix as #2; consistent shape across both sites. | maintainer ratify (need journal) |
| **4** | **REORDER** | L94 (Status table) vs L169 (Install) + L~200 (Tiny example) | The matrix dominates before any worked example. Pat: "Pat bounces; never reaches the runnable 5-line fit." | Move `## Install` + `## Tiny example` *before* `## Status of supported features`. The matrix is developer-facing triage; the runnable fit closes Pat's "should I install?" loop. | maintainer ratify |
| **5** | **CUT / FOLD** | L140–141 (phylo variants) | 2 phylo rows (`Hadfield A⁻¹ paired` + `phylo_scalar / indep / dep / slope`) read as one fold-able set; together they take ~6 visual lines on a laptop. | Fold to **one** row: `Phylogenetic covariance (Hadfield & Nakagawa 2010 sparse $A^{-1}$ + paired latent/unique covered; scalar/indep/dep/slope smoke)` — status: `stable (paired) / experimental (variants)`. Register refs: PHY-01..PHY-10. Saves ~1 row + ~3 visual lines. | maintainer ratify |
| **6** | **CUT / FOLD** | L142–143 (spatial variants) | Same pattern: 2 spatial rows (SPDE mesh + 5 spatial keywords) fold-able. | Fold to one row: `Spatial covariance (SPDE mesh + spatial_latent/unique/scalar/indep/dep)` — status: `stable (mesh + dispatch) / experimental (variants)`. Register refs: SPA-01..SPA-07. Saves 1 row. | maintainer ratify |
| **7** | **CUT / FOLD** | L133–134 (extract_*) | 2 rows for `extract_Sigma / Omega / correlations` and `extract_communality / repeatability / phylo_signal / residual_split`. | Fold to one row: `Extractors (Sigma, Omega, correlations, communality, repeatability, phylo signal, residual split)` — status: `stable (Gaussian) / experimental (non-Gaussian + mixed-family)`. Register refs: EXT-01..EXT-08. Saves 1 row + cleans matrix shape. | maintainer ratify |
| **8** | **TIGHTEN** | L58–92 (`## What can I model now?`) | 35-line bullet list with code spans + links + per-bullet model-type detail. Reads like a reference index, not a decision tree. | Trim to 4 short bullets pointing at vignettes (Pat's Win 3): continuous traits → Morphometrics; binary/count → Joint SDM; phylogeny → Phylogenetic GLLVM; spatial → SPDE-vs-glmmTMB. Drop in-line family lists (the matrix carries those). Saves ~23 lines. | maintainer ratify |
| **9** | **DEFER** | L287–307 (Covariance keyword grid) | The 3 × 5 keyword grid is machinery-first; appears between the worked example and Current boundaries. Pat: "Pat doesn't need this until *after* the install decision." | **DEFER to a follow-up PR**: extract the grid to its own short page `articles/formula-syntax.html` OR move it to the bottom of the README under a "Reference" sub-section. Out of scope for PR-0C.LANDING-PAGE-FIX (would change navbar). | flag for future PR |

## What PR-0C.LANDING-PAGE-FIX will do (if all ratified)

If maintainer ratifies items 1–8 (and defers 9):

- 3 citation fixes (1, 2, 3) — ~5 min.
- 1 section reorder (4) — ~5 min.
- 3 matrix row folds (5, 6, 7) — ~10 min.
- 1 section tighten (8) — ~15 min.

**Total**: ~35 min of straight edits + `pkgdown::check_pkgdown()`
verification + after-task report. One PR, one commit window,
one FINAL CHECKPOINT before merge.

## Pat findings — verbatim summary

- **Verdict**: "Pat bounces after 30 seconds. The first three
  paragraphs work well, but the page then explodes into
  crowding."
- **Top 3 problems**:
  1. Status table appears before any worked example (Item 4).
  2. "What can I model now?" is a 35-line bullet list (Item 8).
  3. "Covariance keyword grid" is machinery-first (Item 9).
- **Matrix problem rows**: 6 fold-able row sets, folding cuts
  ~25 % vertical space (Items 5, 6, 7).
- **Quick wins**: reorder sections; fold phylo + spatial rows;
  tighten "What can I model now?" (~30 min total).

## Rose findings — verbatim summary

- **Verdict**: WARN, 4 items (3 citation, 1 wording context).
- **Citation failures**: L140 Hadfield, L145 Nakagawa 2022,
  L337 Nakagawa 2022.
- **Register row-ID resolution**: all 53 cited IDs resolve;
  zero mismatches.
- **Status-vs-register consistency**: clean (stable→covered,
  experimental→partial, planned→blocked).
- **@export ↔ pkgdown.yml parity** (NEW skill check 12): all
  114 exports indexed; no gaps.
- **Stale terminology**: clean (no `gllvmTMB_wide`,
  `meta_known_V` as primary, `S_B`/`S_W`, `trio`, `phylo_rr`).

## Cross-references

- `README.md` (current).
- `docs/design/35-validation-debt-register.md` (53 row-IDs cited; all resolve).
- `.agents/skills/rose-pre-publish-audit/SKILL.md` (16 checks; checks 1, 7, 9, 12, 14 fired; check 13 inapplicable here).
- `docs/dev-log/audits/2026-05-16-phase0c-article-triage.md` (the parallel triage for vignettes/articles).

## Decisions needed (maintainer 2026-05-17)

1. **Citation FIXES (items 1, 2, 3)** — approve as-is, OR provide the correct journal name for the Nakagawa 2022 paper (item 2 + 3).
2. **REORDER (item 4)** — approve moving Install + Tiny example before Status matrix.
3. **CUT / FOLD (items 5, 6, 7)** — approve folding phylo, spatial, and extractor matrix rows.
4. **TIGHTEN (item 8)** — approve trimming "What can I model now?" to 4 short bullets.
5. **DEFER (item 9)** — approve flagging the Covariance keyword grid extraction for a future PR.

Once ratified, one PR (`PR-0C.LANDING-PAGE-FIX`) executes 1–8;
item 9 is flagged for a future small PR.
