# Session Handoff — M1 withheld twice; repaired; awaiting re-qualification and a third panel

**Meta:** 2026-07-21 · Claude → Claude · context-pressure handoff at a batch boundary

You are the sole `gllvmTMB` 0.6 lane. Work in the existing isolated builder. Nothing is lost
by this handoff: all durable state is in git, `LOOP/`, PR #778, and Mission Control.

## Read first, in this order

```text
LOOP/GOAL.md                    (incl. its 2026-07-21 MAINTAINER AMENDMENT)
LOOP/checkpoint.md
LOOP/decision-queue.md
docs/dev-log/known-residuals-register.md
docs/dev-log/after-task/2026-07-21-m1-reader-surface-class-sweep.md
this file
```

## The one-paragraph state

**M1 is WITHHELD. Two consecutive D-43 panels returned 3/3 NOT-DONE.** The engineering is
sound — every failure has been documentary. The first panel found `NEWS.md` asserting
"reader-facing pages no longer expose internal validation identifiers" while carrying seven of
them. The repair for that was a **targeted string removal, not a class sweep**, and the second
panel withheld again: the class spanned 12 files, only 3 were patched, and the repair itself
**introduced** a new register code plus a dead `docs/` path. All nine of the second panel's
must-fixes are now applied, including a **mechanical guard** so the property is enforced rather
than asserted.

## What the maintainer has decided (do not re-ask)

1. **EVA is CUT from 0.6 to 0.7.** 0.6 is Laplace-only. M2 CUT, its gates dissolved. 0.7's EVA
   must target **sparse binary**, not the `q=1` multi-trial cell.
2. **No exception is self-granted.** Each pre-existing failure needs individual sign-off plus a
   register row.
3. The residuals register is **public**, in `docs/dev-log/`.
4. **#750** — docs corrected, retargeted to 0.7; the stranded implementation was deliberately
   NOT imported.
5. **R-1/R-3/R-4 fixed; R-2 and R-6 SIGNED OFF.**
6. **CI spend is authorised.** Push, Ubuntu, heavy and the three-OS matrix are approved — that
   gate is passed, do not re-ask. The full matrix is used deliberately rather than Ubuntu-only:
   closing M1 on Ubuntu-only at a new SHA would be a second declared deviation.
7. Standing instruction: **"finish M1 as soon as we can — but no compromise."**

## Where the work stands

**Committed head at handoff:** see `git log -1`. If the working tree is dirty, the repair
commit did not land — check `git status` before anything else.

**Applied this session (the second repair):**

- `tools/check-reader-surface.sh` — **the structural fix.** Fails on register codes,
  `M[0-9]`, `Design NN`, and `docs/(design|dev-log)/` paths across README, NEWS, DESCRIPTION,
  `man/`, `vignettes/`. Documented exclusions: `refs.bib` (R Journal DOIs match the code shape),
  resolving `https://github.com/...` URLs, and binaries. **Validated by its own failure** — it
  reported 11 violations before the sweep and passes after.
- Twelve roxygen blocks across eleven R files rewritten at source, Rd regenerated. Three
  (`check-identifiability.R`, `coverage-study.R`, `methods-gllvmTMB.R`) had violations the
  generated-`man/` scan never surfaced.
- `?simulate`'s `\description{}` corrected — it had documented the **non-default** branch —
  and `bootstrap_Sigma()`'s Caveats, which claimed the opposite of the corrected page.
  **R-5 reopened and re-closed**; it had been marked RESOLVED on a two-page surface with one
  page still wrong.
- `NEWS.md`'s "check the help page for coverage" instruction **removed** — zero of nine keyword
  help pages state coverage. It now says plainly that no per-route coverage table exists.
- Receipts mirrored with SHA-256 to `~/gllvmTMB-0.6-evidence/m1/final-receipt/<sha>/`. The
  earlier "durable receipt" claim was overstated; the files were in ephemeral `/private/tmp`.
- Retractions recorded in `check-log.md`, the register, and `checkpoint.md`.

## NEXT — resume here

1. **Verify the tree is clean and the guard passes:**
   ```sh
   cd /private/tmp/gllvmtmb-060-m1-builder
   git status --short && bash tools/check-reader-surface.sh
   ```
2. **CRAN-configuration check** (validates `NEWS.md` and `man/`, both heavily edited):
   ```sh
   NOT_CRAN=false Rscript --vanilla -e 'devtools::check(document = FALSE, remote = TRUE,
     incoming = TRUE, force_suggests = TRUE, manual = TRUE, error_on = "never",
     env_vars = c(NOT_CRAN = "false", GLLVMTMB_HEAVY_TESTS = ""))'
   ```
   Expect **0 errors / 0 warnings / 1 note** (`New submission` — allowlisted, not a failure).
3. **Durable runners** from the clean commit. Verify hashes first
   (`fdee381f…`, `6bc5c7f2…`), then run both from
   `~/gllvmTMB-0.6-evidence/m1/final-receipt/runners/`. **Mirror the resulting RDS + log into
   `~/gllvmTMB-0.6-evidence/m1/final-receipt/<sha>/` with `SHA256SUMS.txt`** — do not leave
   them in `/private/tmp` and call them durable.
4. **Push, then CI.** Authorised. **Do NOT dispatch `R-CMD-check.yaml` while an Ubuntu run is
   in progress** — the concurrency group is `workflow-ref` with `cancel-in-progress` true off
   main, so a dispatch cancels the running Ubuntu job and destroys that receipt. Wait for
   Ubuntu, then dispatch with `-f full_matrix=true`. `full-check.yaml` is a separate workflow
   and can be dispatched immediately.
5. **Third D-43 panel.** 2 Sonnet + 1 Opus, fresh contexts, NOT-DONE default, whole estate.
   Give it the previous two verdicts and tell it to **verify the repairs hold** rather than
   accept a summary.

## Verify by log, never by conclusion — traps this arc actually hit

- pkgdown reported **exit 0 while artifacts were absent** — destination is `pkgdown-site`, not
  `docs/`.
- A focused run reported **`FAIL 0` while the assertion under test was skipped** behind
  `skip_if_not_heavy()`, which fails **open**.
- `expect_warning()` in testthat 3e returns the **caught condition**, not the value — assigning
  from it snapshotted the warning object instead of the plot.
- `R CMD check` fails its tests step only on **error**, so testthat warnings and skips are
  invisible behind `Status: OK`. Parse the test summary explicitly.
- A green CI conclusion is not 0/0/0: the workflow uses `error-on: "error"`.
- `full_matrix` silently degrading to Ubuntu-only would also go green — **assert three
  OS-named jobs**.
- An apparent false `#750 SHIPPED` claim in `CLAUDE.md` was **true on its own branch**. Check
  which branch you are reading.
- **A negative grep over one file is not a property of all files.** "origin/main carried zero
  register codes" came from grepping `NEWS.md` alone and was false of `vignettes/`.
- **Fixing the parameter you are looking at is not fixing the page.**
- **Readable-but-false is worse than opaque-but-true.**

## Open gates (need the maintainer)

- **R-7 AWAITING SIGN-OFF** — eight pre-existing heavy-suite warnings, all sites named,
  causation by exact set match. Four share one source line (`R/loading-ci-bootstrap.R:287`) and
  are likely **one defect presenting four times** — worth diagnosing before asking him to sign.
- M3 source/API freeze **+ the `0.5.0 → 0.6.0` version bump, which invalidates every exact-SHA
  receipt** — M5 must budget its own platform cycle.
- M4 **page decisions** (his own hours — the critical path for 0.6, not compute).
- M4 candidate freeze · M5 RC tag · M5 final tag · CRAN submission.

## What this handoff does NOT cover

- The eight R-7 warnings are **recorded, not diagnosed**.
- The guard covers register codes, phase codes, `Design NN` and `docs/` paths on five surfaces.
  It does **not** cover `inst/`, surfaces added later, agent names, dates, phase language in
  prose — **or whether the prose that replaced the codes is true**. That last gap is exactly
  how a true statement became a false one this session, and no grep can catch it.
- Whether a third panel will pass. Two have not.

## RESUME

```text
Read LOOP/GOAL.md (incl. the 2026-07-21 amendment) -> LOOP/checkpoint.md ->
LOOP/decision-queue.md -> docs/dev-log/known-residuals-register.md ->
docs/dev-log/handover/2026-07-21-claude-handover-m1-withheld-twice.md.
M1 is WITHHELD after two 3/3 NOT-DONE panels; all nine must-fixes are applied and a
mechanical guard now enforces the reader-surface property. Resume at the CRAN-configuration
check, then durable runners (mirror them with checksums), then push + full CI (already
authorised), then a THIRD D-43 panel. Do not re-ask for the CI gate. Do not commit after the
runners produce receipts — that invalidates them.
```
