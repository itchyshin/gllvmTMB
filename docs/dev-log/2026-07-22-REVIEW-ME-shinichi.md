# 📋 REVIEW ME — Shinichi, ~05:00 (2026-07-22 overnight session)

**Start here.** This is the single reminder of everything that changed while you were away and
everything I'm *suggesting* but did **not** apply. Nothing crossed a gate — no freeze, no tag, no
submission. The next action is yours: your page review, then the **candidate freeze**.

Open the rendered site alongside this: `pkgdown-site/index.html`.

---

## A. What CHANGED this session — review each (all committed, each revertible)

Every reader-facing edit is additive-safe (a claim only ever got *smaller*). Grouped by "look at this."

| # | File(s) | What changed | Commit |
|---|---|---|---|
| 1 | `R/zzz.R`, `README.md`, `_pkgdown.yml`, `DESCRIPTION` | **D-41 experimental warning** on all four channels (startup message, README `[!WARNING]` callout, pkgdown home-sidebar Status, DESCRIPTION line) | `70e070be` |
| 2 | `R/kernel-helpers.R` | dropped the word **"validated"** from the `extract_Gamma()` gate line | `aa939ce8` |
| 3 | `R/extract-omega.R`, `R/loading-ci.R`, `R/extract-repeatability.R` | added an **`@section Interval calibration:`** caveat (point estimates supported; interval coverage not calibrated) | `aa939ce8` |
| 4 | `_pkgdown.yml` | fixed the **deprecation date** — the reference section said "0.5.0" over two families deprecated at *different* versions (0.2.0 unique-family, 0.5.0 scalar) | `eb9324c2` |
| 5 | `NEWS.md`, `DESCRIPTION` | **version bump 0.5.0 → 0.6.0** + a Laplace sentence in NEWS | `458dc01b`-era |
| 6 | `cran-comments.md` | **corrected** a stale-and-false 0.5.0 `0/0/0` (from a `--no-tests` run) to the honest 0.6.0 `0/0/1` — DRAFT for your final read | `195ecafb` |
| 7 | `R/brms-sugar.R` | internal typo: comment "unique-family" → "scalar-family" (not reader-facing) | `aa939ce8` |

**The four fences (#2, #3) are the ones most worth your eye** — if you'd word any differently, each
reverts in one line.

## B. What I SUGGEST but did NOT apply — your call

**The article overclaim audit (19 articles, 24 agents) found the articles CLEAN.** Five low-severity
borderline phrasings surfaced; I judged all five defensibly fine (each sits in a self-fencing context),
so I did **not** edit your prose. Listed so you can decide:

| Article | Line | Phrase | My read |
|---|---|---|---|
| `multinomial.Rmd` | 234 | "the fixed-effect route … is **validated**" | Self-fenced by lines 249/255/256–257 ("coefficient recovery is validated *only* …; none establishes interval coverage"). Optional: tighten line 234 to match 255. |
| `joint-sdm.Rmd` | 219 | "a **full** sampling-distribution CI" | Line 311 already says "empirical percentile interval." Optional: drop "full" for consistency. |
| `morphometrics.Rmd` | 36 | "do not establish calibrated coverage **across other sample sizes**" | Mildly implies *this* cell is calibrated. Optional: "…do not establish calibrated interval coverage" (no contrast). |
| `morphometrics.Rmd` | 308 | "strongest **evidence** of positive/negative association" | Teaching framing; a judgment call on emphasis. Held for you. |
| `cross-family-correlations.Rmd` | 42 | "the five-family latent covariance is **valid**" | "Valid" = the covariance is a coherent object, not an interval claim. Defensibly fine. |

## C. HELD for the freeze (source edits — I bundle these when you freeze)

- **`inst/WORDLIST`** — `spell_check()` flags 142 domain terms (`Ainv`, `coevolution`, `eigen`, author
  surnames); none in DESCRIPTION, and the CRAN lane flagged no spelling. A WORDLIST silences the advisory.
- **`\value` on `ordiplot` and `gllvmTMB_multi-methods`** — the CRAN lane is satisfied, but these two
  exported topics lack an explicit return-value section. Adding one is factual content — your wording.

## D. The "outdated content" axis (you raised this)

A staleness grep of the articles found **no stale syntax**: the `link_residual =` uses are current API,
`meta_known_V()` is correctly labelled deprecated, and there are **no** TODO/FIXME/WIP/draft markers.
Two minor flags only — a historical "0.2.0 grammar" aside (`covariance-correlation.Rmd:198`) and a
"placeholders:" line (`:315`). **Content currency** — whether an article's *approach* is superseded — a
grep can't judge; that's your read.

## E. Where the release stands

- **Rung: `tarball-clean` proven.** The built `gllvmTMB_0.6.0.tar.gz` (SHA-256 `73893f97…`, 3.25 MB)
  passes `R CMD check --as-cran` at **0/0/1** (New submission), forbidden-path scan clean, vignettes
  rebuild OK. DESCRIPTION spell clean. Evidence: `~/gllvmTMB-0.6-evidence/m5-prep/`.
- **NOT READY for submission** — the gap is your review + the gate sign-offs, not capability (D-49/D-66).
- **Next gate: the candidate freeze (yours).** On your word I apply your review changes + the WORDLIST +
  `\value` docs, build the **final** tarball, cut `v0.6.0-rc.1`, run the exact-tag 3-OS cycle, and stop
  again for your final-tag and submission sign-offs. Sequence on disk:
  `docs/dev-log/2026-07-22-m4-to-m5-runbook.md`.

**Nothing is running. State is clean and pushed at `195ecafb`+.** I did no simulation (none exists in
the 0.6 path) and touched neither the EVA/Design 86 lane nor any parked worktree.
