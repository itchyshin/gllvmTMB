# Fairness audit — the VA/EVA/JJ vs `gllvm` Totoro-grid comparison

**Auditor:** Fisher (adversarial simulation-and-evidence-design review), read-only.
**Scope:** `dev/totoro-grid/run-grid.R`, `dev/totoro-grid/analyse-grid.R`,
`dev/totoro-grid/results/{grid.csv,grid.rds,RESULTS.md}`, `R/approximation-engine.R`,
`R/va-r3-proto.R`, and `gllvm` 2.0.13's own `vignette10.Rmd`
("Assessing Convergence in gllvm models").
**Claim under audit** (as recorded in
`docs/dev-log/handover/2026-07-27-va-eva-handover-note.md:31-34` and
`docs/dev-log/after-task/2026-07-26-va-eva-jj-engines-and-totoro-grid.md:70-78`):
our VA arm 1% degenerate / never clean-on-degenerate; `gtmb_laplace` 12% degenerate,
59/70 `convergence==0 & pdHess==TRUE`; `gllvm`'s EVA 68% degenerate, **all** reporting
converged.

**Bottom line up front:** the 68%/"all" figure is **partly an artefact of a coding
bug**, not (only) an artefact of an unfair diagnostic standard. The true self-report
capture rate for degenerate EVA fits is **160/203 (78.8%)**, not 203/203 (100%). The
"ALL" claim in the handover note is **false** as measured by the very data the grid
produced — 43 of the 203 degenerate EVA fits *did* self-report `not_converged`,
i.e. `gllvm`'s own `$convergence` flag correctly caught them. Separately, and
independently of the bug, the three arms were **not** scored on the same fields, and
the field used for `gllvm` is exactly the one its own vignette calls insufficient.
Both problems point the same direction (both understate `gllvm`'s self-diagnostic
performance), so the headline needs re-scoring and re-wording, not full withdrawal.

---

## What each arm was scored on (with code quotes)

### 1. `gllvm_va` / `gllvm_eva` (the `gllvm` package, method = "VA" / "EVA")

`dev/totoro-grid/run-grid.R:102-113`:

```r
for (mth in c("VA", "EVA")) {
  arm <- if (mth == "VA") "gllvm_va" else "gllvm_eva"
  r <- timed(gllvm::gllvm(y = Y, family = fam_r, num.lv = q,
                          method = mth, seed = 1))
  out[[arm]] <- if (inherits(r$v, "cell_error"))
    row(arm, secs = r$secs, status = "ERROR", note = r$v$msg)
  else {
    Lam <- tryCatch(as.matrix(r$v$params$theta) %*%
                      diag(r$v$params$sigma.lv, q, q), error = function(e) NULL)
    row(arm, r$v$logL, r$secs,
        if (isTRUE(r$v$convergence)) "converged" else "not_converged", Lam)
  }
}
```

The status field is derived from **exactly one** boolean: `r$v$convergence`. No
gradient is read (`fit$TMBfn$gr()` is never called), no Hessian is read
(`fit$Hess$Hess.full` / `fit$sd` is never touched). The full `gllvm` fit object
existed in memory at this point in the worker and — per the vignette (below) —
carries both fields by default; the grid code simply never extracted them.

### 2. `gtmb_laplace` (gllvmTMB's own Laplace route)

`dev/totoro-grid/run-grid.R:130-134`:

```r
Sb <- tryCatch(gllvmTMB::extract_Sigma_B(r$v)$Sigma_B, error = function(e) NULL)
pd <- tryCatch(isTRUE(r$v$sd_report$pdHess), error = function(e) NA)
rr <- row("gtmb_laplace", ll, r$secs,
          paste0("conv", r$v$opt$convergence, "_pdHess", pd),
          note = "Sigma_B may include link-implicit residual on diag")
```

The status string encodes **two** fields jointly: the optimizer's convergence code
(`r$v$opt$convergence`) **and** whether TMB's `sdreport()` found the Hessian positive
definite (`r$v$sd_report$pdHess`, i.e. `-H` positive definite / `H` negative
definite — literally the vignette's second criterion). No independent gradient
threshold is computed or reported for this arm (nlminb's own internal convergence
code is the only stand-in for "gradient near zero").

### 3. `gtmb_gh` / `gtmb_jj` (our VA-R3 engine, the "our VA arm" of the claim)

`dev/totoro-grid/run-grid.R:92-99` calls `.approximation_engine_fit(engine = "va_r3", ...)`,
whose status is set inside `.va_r3_fit()` at `R/va-r3-proto.R:739-828`:

```r
finite_parameters <- all(is.finite(opt$par))
max_abs_gradient <- if (length(gradient) && all(is.finite(gradient))) {
  max(abs(gradient))
} else Inf
healthy <- identical(opt$convergence, 0L) && is.finite(opt$objective) &&
  finite_parameters && max_abs_gradient < 1e-4
...
healthy_id <- which(vapply(fits, `[[`, logical(1), "healthy"))
...
agreement <- length(healthy_id) >= 3L && agreement_range <= 1e-6
admitted <- length(healthy_id) >= 3L && agreement
...
max_projected_variance <- ... # from best_report$v_by_obs
variance_domain_ok <- max_projected_variance <= 4
admitted <- admitted && variance_domain_ok
...
status = if (admitted) {
  "healthy"
} else if (!variance_domain_ok) {
  "failed_variance_domain"
} else {
  "failed_health_gate"
}
```

This is a **4-start ensemble** gate: each of 4 optimizer starts must independently
reach `convergence == 0`, a finite objective, finite parameters, **and** an explicit
gradient threshold `max(abs(gradient)) < 1e-4`; then at least 3 of the 4 "healthy"
starts must **agree** on the objective to within `1e-6`; then the best fit's
projected latent variance must stay `<= 4` (a degeneracy proxy). Only if all of that
holds does the arm report `"healthy"`. There is **no explicit Hessian
negative-definiteness check anywhere in this gate** (confirmed: no `hessian`,
`sdreport`, `pdHess`, or eigenvalue check anywhere in `R/va-r3-proto.R` outside the
unrelated GH-quadrature eigendecomposition at line 117).

### 4. The downstream "clean" test applied uniformly to all five arms

`dev/totoro-grid/analyse-grid.R:93-104`:

```r
say("A fit is DEGENERATE when rel_frob > 10 (loadings off by an order of magnitude+).\n\n")
...
for (a in names(ARMS)) {
  s <- d[d$arm == a & is.finite(d$rel_frob), ]
  if (!nrow(s)) next
  deg <- s$rel_frob > 10
  clean <- grepl("pdHessTRUE|healthy|converged", s$status)
  say("| `%s` | %d | %d | %s | %d |\n", a, nrow(s), sum(deg), pct(deg), sum(deg & clean))
}
```

The ground-truth "degenerate" test (`rel_frob > 10`) **is** applied uniformly — it
is a recovery criterion computed identically from `Sig_true` for all five arms and
is not the fairness problem. The problem is `clean <- grepl("pdHessTRUE|healthy|converged", ...)`:
`grepl()` is an unanchored substring search, and the literal string `"not_converged"`
**contains** the substring `"converged"`:

```r
> grepl("converged", "not_converged")
[1] TRUE
```

So this line does not implement "did the arm report a clean/positive status" — it
implements "does the status string contain the substring `converged` anywhere,"
which is also true of the *negative* status.

---

## Is the comparison symmetric?

**No, on two independent axes**, and both push in the same direction (both make
`gllvm` look worse than the data support):

**Axis A — which fields were read into the status string (the real asymmetry).**
`gllvm_va`/`gllvm_eva` were scored on `$convergence` alone — the single field
`vignette10.Rmd` names explicitly as *not sufficient by itself* (see next section
for the exact quote). `gtmb_laplace` was scored on convergence code **and**
`pdHess` (Hessian). `gtmb_gh`/`gtmb_jj` were scored on convergence, an explicit
gradient threshold, cross-start numerical agreement, and a variance-domain check —
a stricter and *differently shaped* test than the vignette's own two-part
recommendation (it substitutes multi-start agreement for a direct Hessian check —
see "Verdict on our own arm" below). Nothing in the code suggests this was a
deliberate attempt to flatter our own arms — `gllvm`'s own richer diagnostics
(`fit$TMBfn$gr()`, `fit$Hess$Hess.full`, `fit$sd`) exist in the live fit object
(`gllvm::gllvm()` computes SEs by default, so `$Hess$Hess.full` is populated unless
`sd = FALSE` is passed, which `run-grid.R` never does) but were simply never pulled
out of the object before it was discarded — while our own two engines happened to
already expose a richer top-level `status`/`health`/`sd_report$pdHess` field that
the grid code could grab cheaply. The effect, regardless of intent, is that `gllvm`
was held to the shallowest of the three standards, and to the one standard its own
authors document as insufficient.

**Axis B — the regex bug (an independent, unintended asymmetry).** Verified
directly from `dev/totoro-grid/results/grid.csv`:

```
gllvm_eva usable rows (finite rel_frob): 300
             deg=FALSE  deg=TRUE
converged        97        160
not_converged      0        43

sum(deg & clean) via the analyse-grid.R regex = 203   (= ALL degenerate rows)
```

Every one of the 43 `not_converged` gllvm_eva fits is degenerate (`rel_frob > 10`),
and every one of them is counted as "reported OK anyway" by the `clean` regex,
because `grepl("converged", "not_converged")` is `TRUE`. This bug happens to be
inert for the other four arms: `gtmb_gh`/`gtmb_jj` use the vocabulary
`healthy`/`failed_health_gate`/`failed_variance_domain`/`not_applicable_rank_zero`
(no status string contains `healthy` as a false-positive substring of a failure
label), `gllvm_va` had zero degenerate fits so the bug never fires, and
`gtmb_laplace` uses the vocabulary `conv{0,1}_pdHess{TRUE,FALSE}` (verified: no
`conv1_pdHessTRUE` combination occurs in the data at all, so the unanchored
`pdHessTRUE` substring match happens, in this dataset, to coincide with the
intended `conv0 AND pdHessTRUE` conjunction — see "strongest surviving claim"
below for the caveat that this is a coincidence of the data, not a property of the
regex). The bug is therefore not generic noise; it specifically and
**unidirectionally inflates the count against `gllvm_eva`**, the arm at the centre
of the "gllvm is worse" claim.

## Verdict on the 68% figure

- **The 68% degenerate rate itself survives.** `203/300 = 67.7%` is computed from
  `rel_frob > 10`, a criterion applied identically to all arms from the same known
  `Sig_true`. No bug found in that computation.
- **The "ALL reporting converged" claim does NOT survive as stated.** It is
  **false** against the grid's own saved data: only **160 of 203 (78.8%)**
  degenerate EVA fits self-reported `converged`; the other **43 (21.2%)**
  self-reported `not_converged` — i.e., `gllvm`'s own bare `$convergence` flag,
  even used alone, *did* catch roughly a fifth of the degenerate fits. The
  `analyse-grid.R` "reported OK anyway" column (203) is wrong for this arm; the
  correct value under the code's own stated intent ("a clean flag on a broken
  fit") is **160**, not 203.
- **Needs re-scoring, and re-wording — not full withdrawal.** Even the corrected
  160/203 (78.8%) figure is a materially worse silent-failure rate than any other
  arm in the grid (`gtmb_gh` 0/4, `gtmb_laplace` 59/70 = 84.3% — see below,
  `gllvm_va` 0/0). So the *qualitative* conclusion "EVA degenerates far more often
  than either of our engines, and mostly without a self-reported hard failure"
  plausibly survives. But the specific "**all**" wording in
  `docs/dev-log/handover/2026-07-27-va-eva-handover-note.md:33-34` and the "**203**"
  entry in `docs/dev-log/after-task/2026-07-26-va-eva-jj-engines-and-totoro-grid.md:77`
  and `dev/totoro-grid/results/RESULTS.md` are incorrect and should be corrected to
  160/203 before this claim is used in any external or public-facing context.
- Separately, and even after fixing the regex, the **fairness objection stands**:
  `gllvm_eva`'s 160 (or 203) count was earned using only the one field its own
  vignette calls insufficient, while gradient and Hessian information that would
  let a `gllvm`-style user actually run the vignette's own diagnostic was available
  in the fitted object and never extracted. A hostile reviewer who knows the
  vignette will reasonably say: "you didn't check the fields our own paper tells
  you to check before calling our method's self-report unreliable."

## Verdict on our own arm

The claim "ours never reported a clean status on a degenerate fit" is verified
directly from the data: `gtmb_gh`'s 4 degenerate rows (of 640) all carry
`status == "failed_variance_domain"`; `gtmb_jj` has zero degenerate rows (of 320).
`sum(deg & clean)` for both is 0, matching `RESULTS.md`'s "reported OK anyway" = 0
for each. This part of the claim is not touched by the regex bug (verified above:
the bug is inert for this arm's vocabulary) and is **robust**.

Is the bar "at least as strict" as what was demanded of `gllvm`? **Yes, and by a
wide margin** on the criteria that were actually checked (convergence, finiteness,
an explicit `1e-4` gradient threshold, cross-start `1e-6` numerical agreement, and
a projected-variance domain check) — this is a materially stricter test than
`gllvm_va`/`gllvm_eva`'s bare `$convergence` boolean. It is **not**, however, a
strictly stronger test than *the vignette's own two-part recommendation*: the
vignette wants gradient **and** Hessian negative-definiteness; our gate checks
gradient explicitly but never computes or checks a Hessian at all for VA-R3 (no
`hessian`/`sdreport`/eigenvalue call appears in `R/va-r3-proto.R`'s health gate).
Our gate substitutes independent multi-start numerical agreement (>=3 of 4 starts
agreeing to `1e-6`) for a Hessian check — a defensible, arguably stronger empirical
signal of having found a genuine, reproducible optimum, but it is not literally
"the same two fields" the vignette names, so an adversarial reviewer could note
that none of the three arms actually implements the vignette's exact prescription
in full; ours simply implements a different, and on the criteria it does check,
stricter one.

## The strongest surviving claim

**`gtmb_laplace`'s 59/70 figure is genuine and jointly scored on both vignette
criteria — this is the headline that should replace "68%/all."** Verified from
`grid.csv`: of 601 usable-`Sigma_B` `gtmb_laplace` rows, 70 are degenerate
(`rel_frob > 10`), and the status crosstab is:

```
                    deg=FALSE  deg=TRUE
conv0_pdHessFALSE       0          8
conv0_pdHessTRUE      531         59
conv1_pdHessFALSE       0          3
```

Unlike the `gllvm_eva` figure, this is **not** an artefact of the `analyse-grid.R`
regex: the status string itself is constructed by jointly concatenating
`opt$convergence` and `sd_report$pdHess` at `run-grid.R:132-133`, so "59 of 70
degenerate fits have `convergence == 0` AND `pdHess == TRUE`" is directly readable
off the raw status string, field by field, with no dependence on the downstream
`clean` regex at all (the fact that the regex's unanchored `pdHessTRUE` substring
match happens to reproduce the same 59 here is a coincidence of there being no
`conv1_pdHessTRUE` combination in this dataset — not evidence the regex is
correctly written; it would silently over-count if such a combination existed).
`convergence == 0` and `pdHess == TRUE` are literally the two conditions
`vignette10.Rmd` names (gradient stand-in via the optimizer's own internal
tolerance, plus explicit Hessian positive-definiteness via TMB `sdreport()`).
So `gtmb_laplace` is the one arm in the grid whose "silently degenerate" count was
earned on a test that satisfies the vignette's standard, and it *still* shows an
84.3% (59/70) silent-failure rate on that honest test — worse than the corrected
EVA figure (160/203 = 78.8%) in relative terms, though on a much smaller absolute
denominator (70 vs. 300 usable fits) and a lower overall degenerate rate (12% vs
68%). This reframes the honest headline as: **our own Laplace route, tested with
the vignette's own two-part criterion, still silently passes the large majority of
its degenerate fits** — arguably a more damaging and more defensible finding about
convergence diagnostics in general (ours included) than a `gllvm`-specific claim.

One further caveat, offered adversarially and marked **AGENT-INFERRED** (not
verified against extracted gradients/Hessians, since none were saved): gradient
and Hessian diagnostics test whether the *optimizer* found a stationary,
locally-concave point of the objective it was actually given. They do **not** test
whether that objective (VA / EVA / Laplace, all approximations to an intractable
marginal likelihood) is a *good approximation* to the truth. `rel_frob > 10`
measures estimator/approximation quality, not optimizer convergence. It is
plausible — this is inference, not something checked here — that even a full
gradient+Hessian check on `gllvm`'s EVA fits would still show many "healthy,
converged, PD-Hessian" fits that are nonetheless recovery-degenerate, because
EVA's second-order Taylor surrogate is known in the literature to become unstable
at higher dimension independent of whether the optimizer converged cleanly on it.
If that is right, the vignette's fairness objection is procedurally valid (we
should have checked the fields `gllvm` tells its users to check) but may be
substantively orthogonal to the actual finding (bad estimates from a converged
approximate objective) — this would need the actual re-scoring below to confirm
either way, and should not be asserted without it.

## Cost of re-scoring

**The saved outputs cannot be re-scored in place; a re-run is required**, but only
of a bounded subset of the grid, and it is exactly reproducible.

- `dev/totoro-grid/results/grid.rds` / `grid.csv` are confirmed (loaded and
  inspected directly) to be plain scalar-column data frames — columns `family, n,
  p, q, seed, arm, objective, seconds, status, rel_frob, attenuation, note`. No
  gradient vector, Hessian matrix, or fitted model object was persisted for any
  arm. `TMB`/`gllvm`'s ADFun objects (`fit$TMBfn`) are not meaningfully
  serializable across sessions in any case, so this is not a matter of the wrong
  columns having been dropped — the gradient/Hessian could only ever have been
  captured at fit time, inside the worker, before the object was discarded.
- **Re-scoring therefore requires re-running `gllvm::gllvm(..., method = "VA"/"EVA")`**
  for the cells of interest and additionally extracting `fit$TMBfn$gr()` and
  `-fit$Hess$Hess.full` (or `-fit$TMBfn$he(fit$TMBfn$par)` if `sd = FALSE` were
  ever used) at the fitted optimum, then applying the vignette's own tests
  (`max(abs(gradient))` threshold, `all(eigen(0.5*(H+t(H)))$values < 0)` or a
  Cholesky attempt on `-H`).
- **This is reproducible, not a fresh experiment**: `run_cell()` calls
  `set.seed(seed)` before generating `Y`, and passes a fixed `seed = 1` into
  `gllvm::gllvm()` itself (`run-grid.R:105`), so re-running the same
  `(family, n, p, q, seed)` cells regenerates byte-identical data and, modulo
  ordinary floating-point/platform variation, the same fitted optimum.
- **Scope of the re-run needed:** only `gllvm_va` and `gllvm_eva` need re-fitting
  with diagnostics extracted (0% and 68% degenerate respectively; `gllvm_va` is
  cheap insurance since it had zero degenerate fits and is unlikely to change the
  conclusion, but should be included for a complete, symmetric re-audit).
  `gtmb_gh`/`gtmb_jj`/`gtmb_laplace` already have adequate per-fit diagnostic
  fields in their status strings and do not need re-fitting for this particular
  fairness question — only the `analyse-grid.R` regex bug (which affects the
  reporting layer, not the fitting layer) needs fixing for all arms, which is a
  one-line change (`clean <- s$status %in% c("converged", "healthy") | grepl("pdHessTRUE", s$status)`,
  or equivalent, plus an audit for whether any `conv1_pdHessTRUE` combination
  could occur and needs excluding explicitly).
- **Rough compute-cost bound (AGENT-INFERRED estimate from the runtime table in
  `RESULTS.md`, not measured directly for this task):** re-running `gllvm_eva`
  alone across its 640 attempted cells is bounded well below the cost of the
  original 5-arm, 2880-row grid — the expensive arms in that grid were `gtmb_gh`
  (up to 2941 s/fit at n=400,p=80,q=4 Poisson) and `gtmb_jj`/`gllvm_va` at the
  same sizes; `gllvm_eva`'s own recorded runtimes top out at 792 s/fit (bernoulli,
  n=400, p=8, q=4) with most cells far cheaper, and its Poisson cells appear to
  fail near-instantly (median 0.00 s across the board in `RESULTS.md` §5, so most
  of its 340 recorded `ERROR`s are plausibly Poisson-family failures, not slow
  timeouts — not independently confirmed here). On Totoro's existing 64-worker
  `mirai` setup this re-run is a small fraction of the original grid's wall time —
  order of an hour, not the multi-hour-to-day cost of the full 640-cell x 5-arm
  campaign — but this is an estimate, not a benchmarked figure, and should not be
  quoted as measured.

---

### Summary table (corrected)

| arm | usable fits | degenerate | rate | self-reported "converged/healthy" among degenerate (as coded) | corrected count |
|---|---:|---:|---:|---:|---:|
| `gtmb_gh` | 640 | 4 | 1% | 0 | 0 (unaffected by bug) |
| `gtmb_jj` | 320 | 0 | 0% | 0 | 0 (unaffected by bug) |
| `gllvm_va` | 600 | 0 | 0% | 0 | 0 (bug moot, no degenerate rows) |
| `gllvm_eva` | 300 | 203 (68%) | — | **203** (RESULTS.md, buggy) | **160** (78.8% of degenerate; verified from raw status) |
| `gtmb_laplace` | 601 | 70 (12%) | — | 59 | 59 (unaffected by bug; jointly scored on conv+pdHess by construction) |
