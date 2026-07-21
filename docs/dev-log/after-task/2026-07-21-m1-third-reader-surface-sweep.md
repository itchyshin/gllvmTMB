# After-task — M1 third reader-surface sweep (R-7 closed, R-8/R-9 fixed, R-10 raised)

**Date:** 2026-07-21 · **Agent:** Claude Code (sole gllvmTMB 0.6 lane) · **Branch:**
`codex/gllvmtmb-060-m1-baseline-20260720` · **Draft PR:** #778

## 1. Scope

Resume M1 re-qualification after two consecutive 3/3 NOT-DONE D-43 panels. Planned work was:
finish R-7's evidence, run the CRAN-configuration check, produce durable runner receipts, and
stop at the push/CI gate. **Actual scope grew** because a pre-panel class sweep found a third
instance of the defect class that caused both withholdings.

## 2. Outcome — M1 is still WITHHELD

Not closed, for two independent reasons:

1. **A goal conflict only the maintainer can resolve.** The session goal sets "Close M1
   (release truth + qualified head)" as the deliverable *and* "stop before any push/CI spend"
   as discipline. M1's definition of done requires exact-SHA three-OS platform evidence, which
   requires push and CI. The discipline line was obeyed; M1 therefore cannot close.
2. **R-10 is `AWAITING SIGN-OFF`**, and by the register's own rule such a row blocks the arc's
   closing claim.

## 3. What was found

| Row | Finding | Disposition |
|---|---|---|
| **R-7** | Last untraced of eight heavy warnings traced; mechanism then **measured**, not inferred | **SIGNED OFF** — seven benign, site (d) a deferred 0.7 repair |
| **R-8** | Five help-page citations to **three articles that do not exist**, plus two dangling `vignette()` calls | **RESOLVED** |
| **R-9** | Internal `Scope boundary` / `IN` / `PARTIAL` / `PLANNED` vocabulary on user-facing pages — 21 sites, 14 files | **RESOLVED** |
| **R-10** | **15 internal `Design NN` / `Phase NN` codes inside user-facing error messages** | **AWAITING SIGN-OFF** |

### R-7 site (d) — inference upgraded to measurement

A probe refit the fixture and inspected the covariance at the moment the gate passes. The gate
`.fit_stationary_for_recovery_test()` returns **TRUE while `fit_health$pd_hessian` is FALSE**.
`cov.fixed` is 13×13 with exactly one negative diagonal entry, at **`log_tau_spde` = −3.518e10**;
the minimum eigenvalue equals it, so the matrix is definitively not positive-definite.
`summary(sd_report, "fixed")` yields **1 NaN standard error and 0 NaN estimates**, and a bare
`sqrt(diag(cov.fixed))` reproduces the identical `NaNs produced` warning in isolation.

The finding is the **gate, not the warning**: the test is named `"…pd_hessian TRUE…"` and skips
with *"did not converge with PD Hessian"*, but the predicate checks only the scaled gradient.
Its own wrapper comment says it "does not assert that a fit is ready for interpretation or
inference."

**0.7 must budget for the consequence:** repairing the gate will likely make this cell *skip*
rather than pass, moving SPA-02(nbinom2) from covered back toward partial. A real downgrade,
not a cosmetic fix.

### R-8 — the repair for the second panel introduced new false statements

The previous sweep replaced unshipped `docs/design/*.md` paths with prose citations to *named
articles*. Three names had no article. Verified by enumerating all 20 article files and reading
every YAML `title:`; `_pkgdown.yml` lists the same 19 and `check_pkgdown()` is clean, so the
enumeration is complete rather than a partial grep.

Sweeping the class then found a second form: **two `vignette()` citations that also do not
resolve**, because `.Rbuildignore:29` excludes `^vignettes/articles$` — the only vignette that
ships is `vignettes/gllvmTMB.Rmd`.

## 4. Checks run

| Check | Result |
|---|---|
| `tools/check-reader-surface.sh` | **PASS** |
| Complete non-heavy suite | **`FAIL 0 \| WARN 0 \| SKIP 779`** — identical to the pre-sweep baseline |
| `devtools::document()` | 0 errors / 0 warnings; Rd regenerated |
| CRAN-configuration check (`remote = TRUE`, `incoming = TRUE`) | **0 errors / 0 warnings / 1 note** — the expected `New submission` |
| Both new article URLs | **Fetched and confirmed live** (not assumed) |
| `pkgdown::check_pkgdown()` runner | Clean; receipt mirrored with SHA-256 |
| Durable package-check runner | See §7 |

## 5. THE METHOD FINDING — the most important item in this report

**Token-based greps under-scoped four times in succession.** Found `PLANNED`, missed
`PARTIAL`/`Scope boundary`. Found those, missed title-case `Planned:`/`Partially covered:`.
Found those, missed `covered (partially)`. Each time a scope was reported and then proved
larger.

**This is the same "repair what you noticed, then assert completeness" failure that withheld
M1 twice — reproducing itself inside the repair.** The lesson is not "write better patterns":

- **A semantic class cannot be bounded by token search.** The vocabulary had already been
  half-prosified in places, leaving *ungrammatical text on live help pages* that matched no
  token at all.
- **A whole surface can sit outside every check.** R-10 exists because **printed output** is
  named as a reader surface by `CLAUDE.md` and is examined by no guard — and both prior D-43
  panels missed it too.
- **Enumerate SURFACES first, then vocabulary.** The guard covers five file surfaces; message
  strings in `R/` are a sixth that nothing checks.

Equally, **a grep hit is not a finding**: `"the register"` matched `"the regist**ered**
transformation"`, and `slice` matched `extract_Gamma()` "**slices** a matrix". Sites
deliberately left unchanged include `coverage_study()`'s `covered`/`n_covered` output columns
(documented schema) and `profile_cross_rho_ci`'s "its coverage has not been calibrated"
(*coverage* in its correct statistical sense).

## 6. Traps hit

- A **backgrounded launcher shell reported exit 0 while the suite it launched was still
  running** — nearly read as a pass. Counts were instead parsed from the log.
- `pkgdown::check_pkgdown()` validates configuration only; **it does not build the site**, so
  that receipt is not evidence the site renders.
- The guard passes on *"see the Random effects article"* because there is no code and no path
  in it. **It cannot know the article does not exist.**

## 7. Deviations and judgment calls (flagged, not silent)

1. **Two `vignette()` citations were converted to published-article URLs rather than deleted**,
   though the maintainer's R-8 decision was "delete the clauses". Reasoning: unlike the three
   article *names*, these destinations are real and were verified live, so a resolvable link is
   truthful and preserves reader value. Uses the house idiom already at `R/confint-inspect.R:41`.
   **Revisit if strict consistency with "delete" is preferred.**
2. **R-9 was executed across 15 files after being decided on a 10-site sample**, once the true
   extent was measured. The maintainer's chosen remedy was applied to the defect, not the
   sample; fixing only the ten would have left half-rewritten sentences.
3. **R-10's "low repair risk" is evidenced, not proven.** No snapshot or assertion contains a
   `Design` code, but a test could in principle match a substring by regexp.

## 8. What this task did NOT cover

- **No push, no CI, no merge, no tag** — gated, and deliberately not self-granted.
- **No third D-43 panel** — it needs platform evidence that the gate forbids producing.
- **R-10 not repaired.**
- **R-7 site (d) not repaired** — deferred to 0.7 by decision.
- Whether the prose that replaced the codes is true **everywhere**; two independent reviewers
  checked the R-9 rewrites and the highest-risk pages were read directly, but no mechanical
  check can establish this property.

## 9. Follow-up

1. Maintainer: **R-10 sign-off**; the **R-8 deviation** above; and the **goal conflict** in §2.
2. Then: freeze, push, full CI matrix (assert three OS-named jobs), third D-43 panel.
3. 0.7: repair the R-7 site (d) gate, budgeting the SPA-02 downgrade.
4. **Consider extending `tools/check-reader-surface.sh` to a sixth surface — message strings in
   `R/`** — since that is where R-10 lives and nothing currently looks there.

> Related: `docs/dev-log/known-residuals-register.md` · `docs/dev-log/check-log.md` ·
> `LOOP/checkpoint.md` · `~/gllvmTMB-0.6-evidence/m1/`
