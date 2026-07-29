# AGHQ family harness audit + Gamma zero-row diagnosis (Slice B1)

Author: Curie (Claude), worktree `/private/tmp/gllvmtmb-evidence-gap`,
branch `claude/evidence-gap-20260729`. Read-mostly slice; the only edit made
is a documentation comment inside `dev/aghq-families/family_spec.R` (see
Task 3). Not committed — orchestrator reviews and commits.

## 1. Harness audit (`dev/aghq-families/`)

Four files, read in full:

- `dev/aghq-families/family_spec.R` (349 lines) — the 16-family cell table
  and per-family DGP simulators.
- `dev/aghq-families/driver.R` (120 lines) — sequential (family, seed) loop,
  one CSV row per cell, no self-parallelisation.
- `dev/aghq-families/run_family.R` (153 lines) — fits one cell under Laplace
  and AGHQ, returns one comparison row.
- `dev/aghq-families/kill_rule.R` (119 lines) — the pre-registered
  pass/dead/ambiguous verdict rule, applied downstream of the CSV.

### What cells it builds

`family_spec()` (`family_spec.R:279-341`) returns 16 `list`s, one per
`fid` 0..15 (multinomial `fid`=16 is explicitly excluded by design —
documented in the file's own header, `family_spec.R:1-47`, citing
`R/enum.R`, `R/fit-multi.R`'s `family_to_id()`, and the `obs_loglik`
dispatch in `src/gllvmTMB.cpp:2102-2312`). Every family shares one DGP shape
— the single-block loadings-only `latent(0 + trait | unit, d = q, unique =
FALSE)` term (`family_spec.R:105-110`), because that is the only shape the
current AGHQ eligibility gate admits (Stage 1a, "z_B the sole random
block"). Per-family simulators (`family_spec.R:121-269`) draw a response
respecting that family's support (Bernoulli/Poisson/Gamma/Beta/NB/Tweedie/
delta-hurdle/ordinal/etc.), built on a shared `eta` grid
(`.aghq_fam_eta_grid`, `family_spec.R:83-100`). Three families (`tweedie`,
`delta_lognormal`, `delta_gamma`, `ordinal_probit`) carry explicit
"HIGH RISK (pre-flagged)" notes in their spec entries for cost or
non-smoothness reasons unrelated to Gamma.

### What it records per fit

`run_family()` (`run_family.R:88-152`) returns one row with `family`, `fid`,
`seed`, `k`, `n`, `p`, `q`, `n_rep`, then for each of the Laplace and AGHQ
engines: `objective`, `frob`, `rel_frob`, `attenuation`, `convergence`,
plus `aghq_used`/`aghq_reason` (AGHQ engine only), `elapsed`, and a combined
`error` string. `.aghq_fam_fit_one()` (`run_family.R:42-79`) is the engine
runner: it wraps the actual `gllvmTMB::gllvmTMB()` call in `tryCatch`
(`run_family.R:49-55`), records `conditionMessage(e)` into `out$error` on
any R-catchable failure, and separately treats a missing/NA
`fit$report$Lambda_B` as its own error case (`run_family.R:65-69`) even when
the fit call itself didn't throw.

### How it decides a cell failed

Three independent `tryCatch` layers, all producing a full row rather than
propagating:

1. `run_family()` catches `spec$simulate(seed)` errors
   (`run_family.R:93-106`) and `spec$family()` constructor errors
   (`run_family.R:109-122`) — each returns the full column set with `NA`
   metrics and a descriptive `error` string.
2. `.aghq_fam_fit_one()` catches the `gllvmTMB()` call itself
   (`run_family.R:49-55`) and the `Lambda_B` extraction
   (`run_family.R:61-69`).
3. `driver.R`'s loop wraps the entire `run_family(spec, seed, k)` call in one
   more `tryCatch` (`driver.R:79-98`) as a "last-resort net", explicitly
   commented as guarding against "a bug in the harness itself."

The driver then writes the row **unconditionally** — `.aghq_fam_driver_write_row(row, out_path)` (`driver.R:99`) runs immediately after `row` is
computed, regardless of whether `row$error` is `NA` or populated, and it
appends to CSV per-cell (not buffered), so a mid-run kill leaves usable
partial output (`driver.R:8-12`).

### Would it silently drop a family the way `19-family-axis.R` did? Where could a failure produce no row at all?

Within pure R-level error handling: **no** — every one of the three
`tryCatch` layers above always yields a `data.frame` row, and the CSV write
is unconditional on that row, not gated on success. This is a structurally
different (and more defensive) design than `19-family-axis.R`, whose
CSV-write call sits *inside* the "if not NULL" branch, so any caught error
skips the write entirely (see Task 2 below — this is in fact the exact
mechanism that produced Gamma's zero rows there).

The one place a failure **can** still produce zero rows in the current
harness: a **native crash** during `spec$simulate(seed)` or inside the
compiled TMB call in `gllvmTMB()` — a segfault, an unrecoverable C++
exception that doesn't surface as an R condition, or an `abort()` — kills
the R process before any `tryCatch` handler ever runs, R-level `tryCatch`
cannot intercept it. `driver.R` explicitly does **not** parallelise itself
(header, lines 1-6): it runs sequentially in one process, so a native crash
mid-family kills that entire process, losing not just the crashing seed but
every seed after it in that run (rows already written for earlier seeds in
that family survive on disk because of the per-row append). The header's
own suggested sharding pattern (`driver.R:38-44`) forks one `mclapply`
worker per family; a crash there is contained to that family's worker, but
`mclapply` does not synthesize a replacement error row for a dead worker —
it silently returns `NULL` for that job index, and nothing downstream in
this harness detects or reports "a worker died and produced nothing."
That is the one documented, unmitigated gap.

I found no other documentation-vs-implementation gap that reaches the level
of a "silent drop." One minor discrepancy: `driver.R`'s own header comment
(line 11) claims a "non-finite objective" is among the failure modes
"caught inside `run_family()` and recorded in that row's `error` column" —
but `run_family()`/`.aghq_fam_fit_one()` never explicitly checks
`is.finite(fit$opt$objective)`; a non-finite objective that still yields a
non-NA `Lambda_B` would be recorded as-is with `error = NA`. This does not
drop the row (all columns are still populated) and `kill_rule()` already
guards against it downstream by filtering `is.finite(attenuation)`
(`kill_rule.R:63`), so it is not a correctness bug for the pass/dead
verdict, just an overclaim in the header comment. Not fixed here — it is
outside the Gamma diagnosis and outside what the slice asked for.

## 2. The Gamma crash diagnosis

### Reproduction

Ran the exact DGP/model call from `dev/aghq-evidence/19-family-axis.R`
(family constructor `SPEC$Gamma$fam <- function() Gamma()`,
`19-family-axis.R:28`) as a single, non-forked fit against the current
worktree source (`devtools::load_all(".")`, HEAD `b4495cfb`), so that a
native crash would kill the script directly rather than vanish inside an
`mclapply` worker. Command:

```
OPENBLAS_NUM_THREADS=1 Rscript dev/aghq-families/_diag_gamma_19axis.R
```

Full output preserved at `dev/aghq-families/_diag_gamma_19axis.log`; script
at `dev/aghq-families/_diag_gamma_19axis.R`. Exit code: `0` (script ran to
completion, no crash).

### Result

The response DGP itself is fine — `range(Y)` = `[0.00757, 212.22]`, no
zeros, no negatives, no non-finite values (log lines 2-6 of the diagnostic
output). So the "invalid support" hypothesis (zeros/negatives from a shared
DGP) is **ruled out** for this specific script.

The actual failure is a plain, immediately R-caught error, thrown before
any TMB/C++ code runs:

```
CAUGHT R ERROR: Gamma: only the log link is currently supported. Use `Gamma(link =
"log")`.
```

thrown identically for both the Laplace and the AGHQ arm (log lines 10-11,
15-16). Mechanism, traced to source:

- `19-family-axis.R:28` calls `SPEC$Gamma$fam <- function() Gamma()` — bare
  `Gamma()`, no `link` argument.
- `stats::Gamma()`'s own default link is **`"inverse"`**, confirmed
  directly: `Rscript -e 'stats::Gamma()$link'` → `"inverse"`.
- `R/fit-multi.R:466-467` enforces `if (fid == 4L && !identical(f$link,
  "log")) cli::cli_abort("Gamma: only the log link is currently
  supported. Use {.code Gamma(link = \"log\")}.")` — a `cli::cli_abort()`
  call, i.e. an ordinary R condition, fully catchable by `tryCatch`, thrown
  at formula/family-validation time inside `gllvmTMB()` before any
  quadrature or optimisation begins.

So `f <- tryCatch(gllvmTMB(...), error = function(e) NULL)` at
`19-family-axis.R:56-58` catches this cleanly and returns `NULL` for every
one of the 20 Gamma jobs (10 seeds x {laplace, aghq_ridge}). This is
**not** a worker crash, not a link-eligible-but-numerically-unstable case,
and not an AGHQ-specific issue — it fails identically and immediately for
the plain Laplace arm too, confirming it is a pure specification bug in the
calling script, not a family/quadrature defect.

### Why the artifacts looked like a crash

`19-family-axis.R:56-61`:
```r
f <- tryCatch(suppressWarnings(gllvmTMB(...)), error = function(e) NULL)
if (is.null(f)) return(data.frame(fam = jb$fam, ..., reason = "fit error", ...))
```
This early `return()` happens **before** the `utils::write.table(row, OUT,
...)` call at line 68 — the CSV write is only reached on the success path.
So every caught Gamma error (all 20 of them) produced an in-memory
placeholder row with `reason = "fit error"` inside that `mclapply` worker's
return value, but **zero of those rows were ever written to
`19-family-inc.csv`**. Confirmed directly:
```
$ awk -F, 'NR>1{print $1}' dev/aghq-evidence/19-family-inc.csv | sort | uniq -c
  20 "binomial"
  20 "gaussian"
  20 "nbinom2"
  20 "poisson"
```
— 80 rows total, exactly 4 families x 20 jobs, zero Gamma rows, matching
what "no usable fits" (`19-family.log`) implies. Separately, the script's
own final summary loop (`19-family-axis.R:77-79`) filters `is.finite(res$sigma_rat)`
before printing per-family stats, and `sigma_rat` is `NA` for every one of
these caught-error rows in `res` too — so the printed summary shows "no
usable fits" regardless of whether the underlying cause was a caught R
error (this case) or an actual crashed worker (which would have produced
the identical-looking silence, since a dead forked worker returns `NULL`
to the parent `mclapply` and gets filtered by `Filter(Negate(is.null),
res)` at line 73). **The task brief's "zero rows with no error row
suggests a worker crash" was a reasonable prior but is not what happened
here** — the mechanism is a link-argument omission in the calling script,
not a native crash. I cannot rule out that some *other* historical run hit
an actual crash, but for this reproduction, on this worktree, the failure
is 100% attributable to the missing `link = "log"` argument and reproduces
deterministically and instantly (no timing/seed dependence — the error
fires before any random draw of the fit path, only after `mk()`'s DGP,
which itself never touches the link).

## 3. Fix

**No functional fix was needed inside `dev/aghq-families/`.** The current
harness's own `family_spec.R:304-305` already calls
`stats::Gamma(link = "log")` explicitly — it does **not** have the bug that
`19-family-axis.R` had. Verified this is the correct, working call by
running it end-to-end (Task 4 below): the Gamma cell fits with `error =
NA` and `aghq_used = TRUE`.

Checked whether any *other* family in `family_spec.R` relies on a base-R
family constructor whose default link disagrees with `R/fit-multi.R`'s
per-`fid` requirement (the general class of bug Gamma exhibited). Of the 16
specs, four use bare `stats::` constructors: `gaussian` (`stats::gaussian()`,
default link `identity`, matches the `fid==0` identity requirement),
`binomial` (`stats::binomial()`, default `logit`, accepted by the `fid==1`
check), `poisson` (`stats::poisson()`, default `log`, matches `fid==2`), and
`Gamma` (already fixed). The remaining twelve use gllvmTMB's own
constructors (`lognormal()`, `nbinom2()`, `nbinom1()`, `truncated_poisson()`,
`truncated_nbinom2()`, `tweedie()`, `student()`, `Beta()`,
`betabinomial()`, `ordinal_probit()`, `delta_lognormal()`, `delta_gamma()`),
whose own default `link` arguments were read directly from `R/families.R`
(`Beta`: `logit`, `lognormal`/`nbinom2`/`nbinom1`/`truncated_poisson`/
`truncated_nbinom2`/`tweedie`: `log`, `student`: `identity`,
`betabinomial`: `logit`, `ordinal_probit`: `probit`) and each matches the
link its own package family requires by construction. So `stats::Gamma()`
was the only base-R-default/gllvmTMB-required mismatch among the 16, and
`family_spec.R` was already written correctly for it.

**What I did change** (the only edit in this slice, entirely inside
`dev/aghq-families/family_spec.R`): added an 8-line comment directly above
the `Gamma` spec entry explaining that `link = "log"` is load-bearing, not
stylistic, citing the exact mechanism above, so a future edit does not
"simplify" it back to bare `stats::Gamma()` and silently reintroduce the
`19-family-axis.R` failure mode. No behavioural change; `family_spec()`
still returns 16 specs and the Gamma entry still constructs
`Gamma(link = "log")` (re-verified by re-sourcing the file after the edit).

## 4. AGHQ engagement verification

Ran three single cells (`gaussian`, `poisson`, `Gamma`; `seed = 1`, `k =
9`) through the **unmodified** harness (`family_spec.R` + `run_family.R`,
using `family_spec_by_name()` + `run_family()` directly) against the
current worktree source:

```
OPENBLAS_NUM_THREADS=1 Rscript dev/aghq-families/_diag_harness_cells.R
```

Full output at `dev/aghq-families/_diag_harness_cells.log`; script at
`dev/aghq-families/_diag_harness_cells.R`. All three cells completed with
`error = NA` (no failure) and exit code `0`.

Observed `aghq_used` (the fit object's `fit$aghq$used` component, exactly
as `run_family.R:76` extracts it):

| family   | fid | aghq_used | aghq_reason (truncated)                                                                 | convergence_laplace | convergence_aghq |
|----------|-----|-----------|-------------------------------------------------------------------------------------------|----------------------|-------------------|
| gaussian | 0   | `TRUE`    | "quadrature on z_B (d=2, k=9, 81 nodes); 8 adaptation passes, stalled ... mode shift 9.5e-05" | 0                    | 0                 |
| poisson  | 2   | `TRUE`    | "quadrature on z_B (d=2, k=9, 81 nodes); 54 adaptation passes, stalled ... mode shift 5.6e-08" | 0                    | 0                 |
| Gamma    | 4   | `TRUE`    | "quadrature on z_B (d=2, k=9, 81 nodes); 2 adaptation passes, STALLED at the warm start ... max\|grad\|=0.301, NOT converged" | 1 | 1 |

All three report `aghq_used = TRUE` with 81 quadrature nodes (`k=9`,
`d=2`), i.e. AGHQ genuinely engaged rather than silently falling back to
Laplace, for all three cells including Gamma.

**Observation outside the assigned scope, flagged not fixed:** the Gamma
cell's `convergence_laplace`/`convergence_aghq` are both `1` (non-zero =
optimiser did not report clean convergence at `seed = 1`), and its
`aghq_reason` states the AGHQ adaptation itself stalled at the warm start
("the optimiser moved nothing... NOT converged"). This is a normal,
harness-caught outcome (recorded, not silently dropped, `error` still `NA`
because `Lambda_B` was still extractable) and is a different concern from
the Gamma "zero rows" defect this slice was diagnosing — a single-seed
convergence flake is exactly what the pre-registered `kill_rule()`'s
>= 8-seed averaging and DEAD/PASS thresholds exist to characterise, not
something a k=1-seed smoke run should be used to judge. Not investigated
further here; worth a note for whoever runs the full seed campaign.

## Other family expected to fail for the same class of reason

None identified in `dev/aghq-families/family_spec.R` — see Task 3's
per-family link audit above (source-grounded, not inferred): every one of
the 16 specs' family constructors already supplies (explicitly or via its
own correct default) the link that `R/fit-multi.R`'s per-`fid` check
requires. The Gamma case was the only base-R-default mismatch in the set,
and it was already handled correctly in this harness before this slice
started.
