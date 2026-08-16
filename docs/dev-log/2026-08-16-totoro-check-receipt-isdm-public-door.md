# Totoro `R CMD check` receipt — the iSDM public-door lane

**Why this exists.** PR [#1016](https://github.com/itchyshin/gllvmTMB/pull/1016) is stacked on
`codex/isdm-range-amplitude-orthogonal`, and `.github/workflows/R-CMD-check.yaml` triggers on
`pull_request: branches: [main, master]` only. **The PR therefore gets no CI at all.** An earlier
report in this lane said "3-OS CI runs on the PR" — that was wrong, and this receipt replaces it.

**Host.** Totoro (`snakagaw@totoro.biology.ualberta.ca`), Ubuntu 24.04.4, R 4.5.3, x86_64.
Reached over the existing `ControlMaster` socket (D-64: no Duo prompt). Load average was ~140 of
384 cores at launch, comfortably inside D-143's 150-core ceiling; the check is effectively
single-core with `OPENBLAS_NUM_THREADS=1`.

**Command.**
```
R CMD check --no-manual --no-build-vignettes --no-vignettes gllvmTMB_0.6.0.tar.gz
# with OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MC_CORES=1 _R_CHECK_FORCE_SUGGESTS_=false
```

**Wall clock.** 12 min 33 s (11:18:35Z → 11:31:08Z). The D-139 pre-run estimate was 20–30 min, so
it came in under; no run approached the 45-minute stop-and-report line.

## Result: 1 ERROR, 2 WARNINGs — and none of it is this lane's

```
* checking package dependencies ... INFO
* checking installed package size ... INFO
* checking files in 'vignettes' ... WARNING
* checking tests ... ERROR
* checking package vignettes ... WARNING
Status: 1 ERROR, 2 WARNINGs
[ FAIL 46 | WARN 33 | SKIP 1406 | PASS 6731 ]
```

### The ERROR: 46 failures, all from tests that invoke `dev/` scripts the tarball does not contain

Failing files: `test-g2d-six-species-harness.R`, `test-g2e-information-diagnostic.R`,
`test-g2f-pa-replication.R`, `test-g2n-local-prerun.R`, `test-bfgs-smoke-contract.R`.
**None is a file this lane touched.**

Mechanism, confirmed rather than inferred:

- `.Rbuildignore:21` contains `^dev$`.
- `tar tzf gllvmTMB_0.6.0.tar.gz | grep -c '^gllvmTMB/dev/'` → **0**.
- Those tests shell out to runners such as `dev/isdm-package-recovery/run-bfgs-paper2-smoke.R`
  and assert `attr(output, "status")` is `NULL`. With the script absent, `Rscript` exits non-zero
  and the assertion fails. The observed message is exactly that: *"Expected `attr(output,
  "status")` to be NULL. `actual` is an integer vector (2)."*
- They guard for Windows, `devtools`, and `Rscript` availability
  (`test-bfgs-smoke-contract.R:174,554,556`) but **never for the existence of the scripts they
  invoke**.

So these tests pass in a source tree (`devtools::test()`, `load_all()`) and **cannot pass any
tarball-based check**, on any platform, with or without this lane's changes.

**Attribution, measured.** The same five files were run locally on macOS against both the base
commit `bd2b261a` and this lane's head: **164 passing, 0 failures, identical on both.** The
failures are a property of the tarball environment, not of the change.

> **This is a real blocker for the isdm branch itself.** `codex/isdm-range-amplitude-orthogonal`
> (~190 commits) cannot pass `R CMD check` while these tests are unguarded, and it has never been
> checked because a branch that never targets `main` never gets CI. The 2026-08-15 EOD handover
> already listed `test-bfgs-smoke-contract.R` and `test-g2o-postmortem.R` as **CARRIED-OVER
> (unowned)**; this receipt measures that item and names its cause. The fix is a
> `skip_if_not(file.exists(<runner>))` guard per test. **Not done here** — it is another lane's
> carried-over work and outside this lane's scope.

### The two WARNINGs

`checking files in 'vignettes'` and `checking package vignettes` — both relate to the
`vignettes/articles/` tree, which pkgdown builds as articles rather than as installed vignettes.
Pre-existing and orthogonal to this lane; `pkgdown::check_pkgdown()` is clean locally.

## What this receipt does NOT establish

- **It is one Linux box, not 3-OS.** macOS and Windows are unchecked.
- **`_R_CHECK_FORCE_SUGGESTS_=false` was set**, because Totoro lacks `DHARMa`, `ggforce`,
  `galamm`, `mirt`, `nadiv`, `vegan`, and `vdiffr`. **Every check that needs one of those did not
  run**, including all `vdiffr` visual-snapshot tests (the log shows their snapshots being
  deleted as unused). This is materially weaker than the 3-OS CI it substitutes for and must not
  be presented as equivalent.
- Vignettes were not rebuilt (`--no-vignettes --no-build-vignettes`); both articles were rendered
  separately and cleanly on the Mac (13.8 s and 8.3 s).

## Local evidence that does cover this lane

- `devtools::test(filter = "isdm|offset|family-within-trait|augmented-slope")` — **0 failures,
  0 errors**, 1 deliberate heavy-test skip.
- Both articles render end to end through the public route; `grep ":::"` returns nothing in either.
- `pkgdown::check_pkgdown()` — No problems found.
- `devtools::document()` clean; NAMESPACE unchanged.
