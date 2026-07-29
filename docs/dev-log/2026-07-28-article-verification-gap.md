# The article verification gap — 20 of 21 reader documents are checked by nothing on a PR

Lane 2 (`claude/docs-honesty-20260728`), 2026-07-28. Verified on `origin/main` @ `869e92b5`.

This is a **structural** finding about the documentation pipeline, independent of whether any
particular article currently contains a defect. It explains how article rot can occur
undetected, and it is the reason the executable-honesty pass in this lane exists.

## The finding

Three mechanisms compose so that most reader-facing code is never executed:

1. **`R CMD check` never sees the articles.** `.Rbuildignore:29` contains `^vignettes/articles$`.
   Of 21 reader documents, **20 live in `vignettes/articles/`**; only `vignettes/gllvmTMB.Rmd`
   is a real vignette that `R CMD check` builds. So a local or CI `R CMD check` — including
   `--as-cran` — proves nothing about 20 of them.

2. **pkgdown, the only thing that would execute them, does not run on a PR.**
   `.github/workflows/pkgdown.yaml` triggers on:

   ```yaml
   on:
     workflow_run:
       workflows: ["R-CMD-check"]
       types: [completed]
       branches: [main, master]
     workflow_dispatch:
   ```

   `branches: [main, master]` means the build happens **after** a merge, never on the PR that
   introduces the change. A broken article is therefore discoverable only post-merge, or by
   manual `workflow_dispatch`.

3. **27 chunks are `eval=FALSE`** — not executed even when pkgdown does build the site.

The intersection of (1) and (2) is the exposure: for a whole class of change, nothing runs the
article before it lands. The `eval=FALSE` chunks in (3) are never run by anything at all.

## Where the unexecuted code is concentrated

The distribution is the part that matters. `eval=FALSE` is heaviest in exactly the
syntax-reference articles a user copies from:

| Article | chunks | `eval=FALSE` |
|---|---:|---:|
| `api-keyword-grid.Rmd` | 8 | **7** |
| `response-families.Rmd` | 7 | **4** |
| `covariance-correlation.Rmd` | 22 | 4 |
| `joint-sdm.Rmd` | 12 | 3 |
| `random-regression-reaction-norms.Rmd` | 19 | 2 |
| `convergence-start-values.Rmd`, `fixed-effect-zero-constraints.Rmd`, `function-map-cheatsheet.Rmd`, `gllvm-vocabulary.Rmd`, `model-selection-latent-rank.Rmd`, `morphometrics.Rmd` | — | 1 each |

`api-keyword-grid.Rmd` is the canonical statement of the 4×5 keyword grid — the package's core
grammar — and **7 of its 8 chunks are unexecuted**.

## Why this is worth acting on

`eval=FALSE` is often legitimate: a chunk may show syntax for a model too slow to fit during a
site build, or one requiring data the article does not ship. The defect is not `eval=FALSE`
itself — it is that **`eval=FALSE` currently carries no compensating check**. Nothing verifies
that an unexecuted call names a function that exists, passes arguments that are in its formals,
or uses a keyword that still parses.

The sister package's audit found this exact class as its only **BLOCKER**:
`docs/dev-log/dashboard/2026-07-11-docs-accuracy-audit.md` records drmTMB's `cross-family.Rmd`
prescribing `rho12()` and `confint(parm = "rho12")` calls that abort, and inverting the real
accessor contract. Adjective-level honesty was not the problem there; executable honesty was.

## Deliberately NOT claimed here

* **No claim that any article is currently broken.** That is being measured separately; this
  note records only the absence of verification.
* **No claim that `eval=FALSE` should be removed.** Many are certainly justified.
* **No CI change is proposed by this note.** Per the standing local-checks-over-Actions rule,
  the cheap fix is a *static* check (does every prescribed call resolve against `NAMESPACE` and
  formals?), runnable locally in seconds, not a new matrix job that rebuilds the site.

## Cross-lane

Nothing here touches lane 1's fenced set (PR #802) or lane 3's missing-data scope.
`missing-data.Rmd` appears in no table above because it is fenced out of this lane and assigned
to lane 3 (see `handover/2026-07-28-lane-starter-missing-data.md` §1).
