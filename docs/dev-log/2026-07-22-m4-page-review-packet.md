# M4 page-review packet — for Shinichi

**Purpose.** Turn the page-by-page reader review into a fast sitting. You chose "review first, then
freeze" (2026-07-22). Everything below is a *proposal or a surface to skim* — nothing is frozen. When
you're done, the single decision at the end is the **candidate freeze**, and then M5 is ceremony.

**The rendered site is at** `pkgdown-site/index.html` in the worktree
(`/private/tmp/gllvmtmb-060-m1-builder/pkgdown-site/`) — open it in a browser to read the pages as a
reader sees them.

---

## Part A — the four applied fences (approve, or one-line revert)

All four are roxygen-comment only (zero code), additive-safe (each makes a claim *smaller*). Commit
[`aa939ce8`]. If you want any worded differently, say so — each reverts in one line.

### A1 · `kernel-helpers.R:13` → `make_cross_kernel` Rd — dropped a loaded word

- **Before:** "the generic `kernel_*()` surface and the **validated** `extract_Gamma()` coevolution
  gate are documented separately"
- **After:** "…and the `extract_Gamma()` coevolution gate are documented separately"
- **Why:** line 281 of the same file forbids the word "validated" for intervals; using it on the
  coevolution gate was internally inconsistent. The audit panel refuted this; a human re-read of the
  journal reinstated it.

### A2–A4 · `@section Interval calibration:` on three inference topics

Added the **same** one-line caveat (a class fix) to `extract_phylo_signal`, `loading_ci`,
`extract_repeatability`:

> "The point estimates are the supported claim. The interval methods here are provided for
> exploration: their empirical coverage has **not** been calibrated for this estimand outside the
> Gaussian cases that cleared the coverage gate, so the intervals must not be reported as
> coverage-calibrated. See `NEWS.md` for the current coverage status."

- **Why these three:** each offers CIs on a non-Gaussian estimand (H² at species level; a
  binomial-probit loading example; a family-specific residual) with no prior calibration caveat.
- **Your call:** wording, and whether `loading_ci`'s worked example should be Gaussian rather than
  binomial-probit (I did not change the example — that would alter content, so it is held).

---

## Part B — surfaces the audit already cleared (skim to confirm)

The 10-agent overclaim audit found these **clean** (`docs/dev-log/2026-07-22-m4-overclaim-audit-dossier.md`).
Skim to confirm the reader experience, not to hunt:

- **Home / README** — the D-41 `[!WARNING]` experimental callout renders under the badges.
- **NEWS** — the boundary statement (point estimates supported; interval calibration only for the
  cleared Gaussian cells) is the first "Known limitations" bullet.
- **The `get started` vignette** (`vignettes/gllvmTMB.Rmd`) — the only shipped vignette.
- **Console messages** — the `.onAttach` experimental banner fires on `library(gllvmTMB)`.

## Part C — reference topics worth a direct look

The inference-facing topics carry the honesty burden. Beyond A2–A4, glance at:

- `extract_correlations` / `extract_cross_correlations` — already fenced ("None … is
  coverage-calibrated yet"); confirm the wording reads right.
- `bootstrap_Sigma` / `coverage_study` — the tool docs; confirm they read as *tools that measure*, not
  claims that the package *is* calibrated.
- `confint_inspect` — the "does not prove … calibrated coverage" language.

## Part D — the pkgdown articles (pkgdown-only, not shipped)

These were **out of scope** for the shipped-surface audit. If you want them reviewed, they are the
`articles/` menu — a separate skim. They do not gate the tarball (not shipped), but they are
reader-facing on the site.

---

## Part E — overnight M5-prep findings (2026-07-22, while you were away)

The rung advanced `source-clean → tarball-clean`, no gate crossed. Two small **held** items surfaced
for you to fold into the freeze — neither is a blocker:

1. **`inst/WORDLIST`** — `devtools::spell_check()` flags 142 domain terms (`Ainv`, `coevolution`,
   `eigen`, author surnames …); none in DESCRIPTION, and the CRAN lane itself flagged no spelling. A
   `WORDLIST` silences the advisory. It is a source edit, so it is **held for the freeze** — say the
   word and I add it (safe: a whitelist of correctly-spelled terms).
2. **`\value` on `ordiplot` and `gllvmTMB_multi-methods`** — the CRAN lane is satisfied, but these two
   exported topics have no explicit `\value`. Adding one is factual return-value documentation
   (content), so it is **held for your review** rather than written autonomously.

Also done and safe: **`cran-comments.md` corrected** from a stale-and-false 0.5.0 `0/0/0` to the honest
0.6.0 `0/0/1` (it is `.Rbuildignore`d, so the tarball is unaffected) — a DRAFT for your final read
before upload.

## The decision at the end

When you're satisfied: **declare the candidate freeze.** That is the gate. On your word I:

1. (apply any wording changes you marked, then) freeze **one** candidate,
2. build the frozen tarball + ledger (the provisional one is already staged — see
   `~/gllvmTMB-0.6-evidence/m5-prep/`),
3. cut `v0.6.0-rc.1`, run the exact-**tag** 3-OS cycle,
4. run the Grace/Rose/Pat NOT-READY adversarial review,
5. and stop again for your **final-tag** and **submission** sign-offs.

Rung today: **`source-clean` proven** (green 3-OS `--as-cran` + CRAN-config at the exact identity);
`tarball-clean` being proven overnight. **NOT READY** for submission — the gap is your review + the
gate sign-offs, not capability (D-49/D-66).

> Runbook for the M5 ceremony: `docs/dev-log/2026-07-22-m4-to-m5-runbook.md`.
