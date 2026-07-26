# Handover — binary GLLVM log-likelihood sign defect (fix ready for review)

**Meta:** 2026-07-26 · author = Claude · lane = `claude/fix-binary-loglik-20260726`
· worktree `/private/tmp/gllvmtmb-fix-binary-loglik` · base `main` `dc79753a`
· **committed? NO — awaiting maintainer approval** (likelihood change = high-risk
per `CLAUDE.md`).

## The defect

A binary GLLVM fit returns a **positive log-likelihood**, which is impossible —
a Bernoulli log-likelihood is a sum of logs of probabilities and cannot exceed 0.

Reproduced on a well-behaved 300 x 8 matrix (loadings max 0.87, `pdHess TRUE`,
`convergence 0`, no separation):

```r
gllvmTMB_wide(Y, family = binomial(), d = 2)
#> logLik = +29327.39      # impossible
```

**Not** a separation or Laplace-breakdown artefact — the fitted model is
unremarkable in every diagnostic.

## Root cause (confirmed to file:line, and to the decimal)

For single-trial binary/categorical traits, the per-trait identifiability gate
pins the between-unit Psi — `R/fit-multi.R:4639` sets
`theta_diag_B[t] <- log(1e-6)`, and `:4652-4657` map `theta_diag_B` and the
`s_B` rows off, fixing `s_B(t, .) = 0`.

But the C++ `DATA_INTEGER(use_diag_B)` flag stays `1`, and the density loop at
`src/gllvmTMB.cpp:882-893` iterated over **every** `(trait, site)` cell with no
per-trait mask:

```cpp
for (int s = 0; s < n_sites; s++)
  for (int t = 0; t < n_traits; t++)
    nll -= dnorm(s_B(t, s), Type(0), sd_B(t), true);
```

For a pinned trait `s_B(t,s) = 0` exactly and `sd_B(t) = exp(log(1e-6))`, so
each cell contributes `dnorm(0, 0, 1e-6, log = TRUE) = +12.8966` to the
log-likelihood.

**The arithmetic closes exactly:** 2400 cells x 12.8966 = **+30,951.8**;
observed `+29,327.39`; residual **-1,624.4** — a sane Bernoulli value, and
precisely what the fit returns after the fix.

## Impact

`logLik()`, AIC, BIC, and any likelihood-based model comparison on binary data
through the **default** path are silently wrong. The fit reports healthy.

**Scope limit — do not overclaim.** Both `theta_diag_B` and `s_B` are *mapped
off*, so the spurious term is a **constant**. It corrupts the likelihood value
but does **not** perturb gradients or the optimiser. It therefore does **not**
explain the gradient-gate failures in `Ayumi-495/BIRDBASE_pcm#3`, tempting as
that connection is.

## The fix

A per-trait skip mask, plumbed from the R gate that already computes it.

| File | Change |
|---|---|
| `src/gllvmTMB.cpp` | new `DATA_IVECTOR(diag_B_skip)`; length check; `if (diag_B_skip(t) == 1) continue;` in the density loop |
| `R/fit-multi.R:3512` | `diag_B_skip = integer(n_traits)` added to `tmb_data` (all-zero default = every trait keeps its Psi) |
| `R/fit-multi.R:4636` | `tmb_data$diag_B_skip <- as.integer(skip_psi_b_t)` where the gate already computes the mask |
| `tests/testthat/test-binary-loglik-sign.R` | **new** — 3 tests, 7 assertions |

`skip_psi_b_t` already existed; it simply never reached C++.

### Data-contract risk, checked

`diag_B_skip` is a **required** `DATA_IVECTOR`, so any other builder of the
`gllvmTMB_multi` data list would now fail. Verified there is exactly **one**
(`R/fit-multi.R:3494`); `R/va-r3-proto.R:412` targets a different DLL
(`gllvmTMB_va_r3`) and is unaffected.

## Evidence

- **Before:** `logLik = +29327.39` · **After:** `logLik = -1624.3866`
- New test file: **7/7 assertions pass**
- Regression sweep `filter = "binomial|binary|diag|wide|multi-fit|family"`:
  no new failures; remaining entries are pre-existing heavy-test skips
  (`GLLVMTMB_HEAVY_TESTS=1`) and the known R-4 glmmTMB non-PD residual.
- Reproduction script: `/private/tmp/claude-503/.../scratchpad/repro-bug.R`
- Original diagnosis: `dev/laplace-comparator-repair.md` in the VA lane.

## What the maintainer is being asked to approve

This is a **likelihood change**, which `CLAUDE.md` classes as high-risk and
therefore not agent-mergeable. Specifically:

1. **The fix itself** — is a per-trait skip mask the right shape, versus
   flipping `use_diag_B` to 0 when *all* traits are pinned? The mask is more
   general: it handles the mixed case where some traits keep Psi and others do
   not, which the all-pinned shortcut would not.
2. **Whether to file a public GitHub issue.** Not filed — that is outward-facing
   and yours. The reproduction above is issue-ready.
3. **Whether a NEWS entry is wanted** before this is user-visible.

## Not done

- Not committed, not pushed, no PR, no GitHub issue.
- Full `devtools::test()` not run end to end — only the targeted sweep above.
- No check of whether earlier released versions carry the same defect.

## Resume

```sh
cd /private/tmp/gllvmtmb-fix-binary-loglik && \
  Rscript -e 'devtools::load_all("."); testthat::test_local(filter="binary-loglik-sign")'
```
