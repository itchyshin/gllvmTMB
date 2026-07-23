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

## C2. One extracheck flag worth knowing before submission

**72 man topics use `\dontrun`.** The tarball passes `--as-cran` regardless (dontrun examples aren't
executed), so it is **not a blocker** — but CRAN policy prefers `\donttest` for examples that are
merely *slow* and reserves `\dontrun` for examples that genuinely *cannot* run. 72 is high enough that
a CRAN reviewer may ask about it. Worth a pass before submission to reclassify the slow-but-runnable
ones; a large source edit, so **held for your decision**, not applied.

**Site QA (rendered HTML) passed:** the D-41 callout renders on the home page; the three
`Interval calibration` sections render in the reference pages; `make_cross_kernel` shows zero
"validated"; no broken links or build problems.

## D. The "outdated content" axis (you raised this)

A staleness grep of the articles found **no stale syntax**: the `link_residual =` uses are current API,
`meta_known_V()` is correctly labelled deprecated, and there are **no** TODO/FIXME/WIP/draft markers.
Two minor flags only — a historical "0.2.0 grammar" aside (`covariance-correlation.Rmd:198`) and a
"placeholders:" line (`:315`). **Content currency** — whether an article's *approach* is superseded — a
grep can't judge; that's your read.

## E. Where the release stands — RC CUT, submission WITHHELD (honest)

You authorised the freeze + RC ceremony; I ran it and stopped at the R-devel gate.

- **`v0.6.0-rc.1` is cut** (frozen source `e9bc655a`, zero source edits) and is **`platform-clean`**:
  the RC tarball passes `--as-cran` at **0/0/1**, the exact-tag 3-OS is green on all three OS, and the
  exact-tag heavy is `FAIL 0` on all three. Record: `docs/dev-log/2026-07-22-rc1-review-and-rung.md`.
- **The D-49 adversarial review returned 3/3 NOT-READY → submission WITHHELD**, on **one** real gap:
  **win-builder R-devel + macbuilder have not run.** CRAN checks first submissions on R-devel; my
  matrix pins R *release*. This is an **external upload I held for you** — the ceremony correctly
  stopped rather than crossing it.
- The review independently **confirmed the candidate is honest and clean**: no forbidden coverage claim
  on any shipped surface, D-41 on all four channels, residuals disclosed, tarball matches the tag exactly.

### 🔴 Your remaining steps to submit (in order)

1. **Run win-builder R-devel + macbuilder** on
   `~/gllvmTMB-0.6-evidence/m5-rc1/gllvmTMB_0.6.0.tar.gz`. Reconcile any R-devel findings into
   `cran-comments.md` (already updated to cite the frozen-tag runs).
2. **Do the page review** (Parts A–D) — required before a *stable* release; optional for rc.1.
3. **Cut the final `v0.6.0` tag** and **submit** — both your acts. I will not do either.

**Nothing is running now. State clean and pushed.** I did no simulation (none exists in the 0.6 path)
and touched neither the EVA/Design 86 lane nor any parked worktree. The RC tag `v0.6.0-rc.1` is the
evidence anchor — do not delete it.
