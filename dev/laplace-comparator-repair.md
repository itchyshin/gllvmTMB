# Laplace comparator repair — Psi suppression + the impossible Bernoulli logLik

Scope: internal diagnosis only. No package code touched (per constraints). All
evidence reproduced against this worktree via `devtools::load_all()`; scripts
are `dev/inspect-fit3.R`, `dev/inspect-bernoulli.R`, `dev/inspect-bernoulli2.R`,
`dev/inspect-bernoulli3.R`.

## (1) Psi suppression — RESOLVED, no bug

`gllvmTMB_wide()` (`R/gllvmTMB-wide.R:224-244`) hardcodes
`latent(0 + trait | site, d = <d>)` with **no way to pass `unique = FALSE`
through** — its `...` only forwards to `gllvmTMB()`'s other arguments, not
into the spliced formula text. So the wide-matrix wrapper can never fit the
loadings-only (`Lambda Lambda^T`, no Psi) model; it always carries the default
`unique = TRUE` Psi companion.

The **formula path does support it**, exactly as the task hypothesized:

```r
gllvmTMB(
  traits(sp1, ..., sp8) ~ 1 + latent(1 | unit, d = q, unique = FALSE),
  data = df_wide, unit = "unit", family = poisson()
)
```

Verified on Poisson data (n_unit=40, n_trait=8, q=2):

| call | active params (opt$par) | psi/theta_diag_B active? | logLik |
|---|---|---|---|
| `latent(1 \| unit, d=2)` (default, `unique=TRUE`) | `b_fix`(8) + `theta_rr_B`(15) + `theta_diag_B`(8) = 31 | **yes** | −478.5927 |
| `latent(1 \| unit, d=2, unique=FALSE)` | `b_fix`(8) + `theta_rr_B`(15) = 23 | **no** | −480.4126 |

Confirmed via `fit$tmb_map$theta_diag_B` / `fit$tmb_map$s_B` (all levels `NA`
in the `unique=FALSE` fit, i.e. mapped to fixed constants and excluded from
`opt$par`) and via `fit$covstructs` (the `unique=TRUE` fit carries a second
`kind="diag"` covstruct with `.auto_unique=TRUE`; the `unique=FALSE` fit has
only the `kind="rr"` covstruct).

**Verdict:** `latent(1 | unit, d = q, unique = FALSE)` through the `traits()`
formula path is the correct, verified like-for-like Laplace comparator for a
VA fit that only estimates `Lambda Lambda^T`. `gllvmTMB_wide()` cannot do this
and should not be used for the comparator.

## (2) The impossible Bernoulli logLik — CONFIRMED PACKAGE BUG

Reproduced on a 300×8 (and separately a 40×8) 0/1 matrix with **sane,
well-identified loadings** (no separation: `eta` range ≈ [−1, 1],
`sd_report$pdHess == TRUE`, `opt$convergence == 0`, "relative convergence"):

```r
gllvmTMB_wide(Y, family = binomial(), d = 2)
# opt$objective = -29300.58   =>  logLik = +29300.58   (IMPOSSIBLE for Bernoulli)
```

This is **not** a separation/Laplace-breakdown artifact — a first attempt at
n=40 with mild separation (`theta_rr_B` entries up to 151) also gave an
impossible +3934, but the n=300, well-scaled loadings (max |loading| ≈ 0.87)
case above rules that out: the fitted model is completely unremarkable, yet
still returns a positive logLik.

### Root cause (confirmed, file:line)

`gllvmTMB()`'s ordinary `latent()` (default `unique = TRUE`) adds a
between-unit Psi diagonal (`theta_diag_B` / `s_B`). For single-trial
binary/categorical traits this Psi is unidentified, so a **per-trait
identifiability gate** pins it off — `R/fit-multi.R:4615-4673`:

- `R/fit-multi.R:4635`: `tmb_params$theta_diag_B[skip_psi_b_t] <- log(1e-6)`
  — the skipped traits' variance parameter is fixed at `sd = exp(log(1e-6))
  ≈ 1e-6`, essentially a point mass at 0.
- `R/fit-multi.R:4645` / `:4648-4655`: `tmb_map$theta_diag_B` and
  `tmb_map$s_B` are set to `NA` for the skipped trait rows (removing them
  from `opt$par`) and `s_B[skip_psi_b_t, ] <- 0`.

The R-side comment (`R/fit-multi.R:4646-4648`) states the intent correctly
for the **predictor** side ("so a mapped-off (fixed) `s_B` does not inject a
nonzero between-unit effect") — and that part is fine, `s_B = 0` contributes
0 to `eta`.

But `use_diag_B` (the DATA flag gating the whole diag-B block in C++) stays
`1` whenever *any* trait keeps its Psi (or, as in a pure-binary matrix, when
every trait individually gets pinned but the model-level flag was never
flipped to 0). The forward computation in `src/gllvmTMB.cpp:882-893`:

```cpp
if (use_diag_B == 1) {
  ...
  vector<Type> sd_B = exp(theta_diag_B);
  for (int s = 0; s < n_sites; s++) {
    for (int t = 0; t < n_traits; t++) {
      nll -= dnorm(s_B(t, s), Type(0), sd_B(t), true);
    }
  }
}
```

iterates over **every** `(trait, site)` cell unconditionally — it has no
per-trait skip mask. For a pinned trait, `s_B(t,s) = 0` exactly and
`sd_B(t) = exp(log(1e-6)) ≈ 1e-6`, so
`dnorm(0, 0, 1e-6, log=TRUE) ≈ +12.90` **per cell**. This is subtracted from
`nll` (`nll -= ...`), i.e. it is a huge **positive** addition to the reported
log-likelihood, for every one of the `n_traits × n_sites` pinned cells.

### Numerical confirmation

For the n=300 example, all 8 traits are binary so all 8 are pinned
(`skip_psi_b_t` all `TRUE`), giving `n_sites × n_traits = 300 × 8 = 2400`
spurious cells:

```
predicted spurious contribution = 2400 × dnorm(0, 0, exp(log(1e-6)), log=TRUE)
                                 = 2400 × 12.89657
                                 = 30951.77
observed logLik                 = +29300.58
implied genuine nll             = 30951.77 − 29300.58 = 1651.19   (SANE, positive)
```

Refitting the *same* data with `latent(..., unique = FALSE)` — which sets
`use_diag_B = 0` at the whole-model level and never enters the buggy branch —
gives exactly the sane number predicted:

```r
gllvmTMB(
  traits(sp1..sp8) ~ 1 + latent(1 | unit, d = 2, unique = FALSE),
  data = df_wide, unit = "unit", family = binomial()
)
# use_diag_B = 0
# opt$objective = 1651.191  =>  logLik = -1651.191   (matches the null-model
#                                                       sanity check -n*log(2)
#                                                       = -1663.55 closely)
```

This is an exact match to the analytically predicted "genuine" nll (1651.19),
which closes the loop: the +29300 figure is 100% explained by the spurious
`dnorm` spike from mapped-off-but-still-evaluated diagonal rows, nothing
else.

### This is a genuine package bug, not a misuse of a deprecated entry point

The bug is in the **per-trait auto-Psi skip identifiability gate**
(`R/fit-multi.R:4615-4673`, forward-evaluated in
`src/gllvmTMB.cpp:882-893`), not in `gllvmTMB_wide()` itself — the same
defect would fire through the recommended `traits()` + default `latent()`
path too, for any single-trial binary/multinomial trait, whenever at least
one trait triggers the per-trait skip. It is **not gated on the
soft-deprecated wide-matrix wrapper**. A quick corroborating check: the
identical whole-model skip path (`!use_diag_B`, `R/fit-multi.R:4022-4024`,
used when the *entire* model has no diag term) correctly sets `use_diag_B` to
`0`, and that path is bug-free — confirming the bug is specific to the
**per-trait partial pin** where the DATA flag isn't also refined to a
per-trait mask.

**Not verified / out of scope for this task:** whether the mirrored W-tier
OLRE per-trait skip (referenced in the `R/fit-multi.R:4608` comment) has the
same defect for the analogous W-tier `theta_diag_W`/`s_W` pinning. Flagging
this as a place to check, not confirmed here.

## Exact working calls (what to actually use)

**Poisson, loadings-only (Sigma = Lambda Lambda^T), for the VA comparator:**

```r
gllvmTMB(
  traits(sp1, sp2, sp3, sp4, sp5, sp6, sp7, sp8) ~
    1 + latent(1 | unit, d = q, unique = FALSE),
  data = df_wide, unit = "unit", family = poisson()
)
```
logLik seen: −480.4126 (n=40×8, q=2, seed 1).

**Binomial/Bernoulli, loadings-only — REQUIRED, not optional, to avoid the
bug above (do NOT use the default `unique = TRUE` / `gllvmTMB_wide()` for
Bernoulli data):**

```r
gllvmTMB(
  traits(sp1, sp2, sp3, sp4, sp5, sp6, sp7, sp8) ~
    1 + latent(1 | unit, d = q, unique = FALSE),
  data = df_wide, unit = "unit", family = binomial()
)
```
logLik seen: −1651.191 (n=300×8, q=2, seed 42), sane and negative, close to
the null-model sanity bound `-n*log(2) = -1663.55`.

**Do not use** `gllvmTMB_wide(Y, family = binomial(), d = q)` for a Bernoulli
comparator: it cannot request `unique = FALSE` and so always hits the buggy
per-trait auto-Psi-skip branch, producing an impossible positive logLik
(+29300.58 / +3934.07 seen in two independent reproductions).
