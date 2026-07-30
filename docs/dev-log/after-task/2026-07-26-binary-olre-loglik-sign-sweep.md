# After-task — positive log-likelihood defect: verification + Rose sweep

**Meta:** 2026-07-26 · platform = **Claude Code** (read from runtime, not inferred
from the branch name) · lane = `claude/fix-binary-loglik-20260726` · worktree
`/private/tmp/gllvmtmb-fix-binary-loglik` · base `main` `dc79753a` ·
PR [#796](https://github.com/itchyshin/gllvmTMB/pull/796) — **pushed, NOT merged**.

## 1. Scope

Independently verify the handed-over binary log-likelihood fix; apply the Rose
principle to find every other instance of the same bug class; run the full test
suite end to end; determine whether released versions carry the defect.

## 2. What I verified independently (did not trust the handover)

Built the package **twice from source** — once at base `dc79753a` (pre-fix,
extracted with `git archive` so no worktree was disturbed) and once at the lane
HEAD — and ran the *same* generated 300x8 binary matrix through both.

| build | logLik |
|---|---|
| pre-fix `dc79753a` | **+29336.9698** (positive — impossible for Bernoulli) |
| fixed `59a83c5b` | **-1614.8031** |

Difference = **30951.7729** = 2400 cells x 12.8966, exact to four decimals.
Pre-fix logLik minus the predicted constant equals the fixed logLik *exactly*.

This confirms the **mechanism**, not merely the symptom. My absolute numbers
differ from the handover's (+29327.39 / -1624.3866) because I used my own seed;
the *difference* is identical, which is the quantity the diagnosis predicts.

The handover's stated root cause, file:line attribution, and arithmetic all hold.

## 3. Rose sweep — one more instance found, and it is older

**The bug class.** The R-side identifiability gate pins a per-trait random-effect
SD near zero and maps both the SD and the random effect off. The C++ density loop
has no per-trait mask, so each pinned cell adds `dnorm(0, 0, 1e-6, log = TRUE)` =
**+12.8966** to the log-likelihood.

**The discriminating pattern** (this is what makes the sweep decidable rather
than impressionistic): a **partial** pin of a random-effect SD to ~0, combined
with a **partial** NA map, *while the C++ block flag stays 1*. I enumerated every
`tmb_map$...` assignment and every subset assignment to `tmb_params` in `R/`.

### Instance 2 — `use_diag_W` (the OLRE tier). CONFIRMED, now fixed.

`R/fit-multi.R` pins `theta_diag_W[t] <- log(1e-6)` and maps the `s_W` rows off
for single-trial Bernoulli / ordinal_probit / multinomial traits; the `use_diag_W`
loop in `src/gllvmTMB.cpp` had no mask.

Demonstrated with the sharpest check available — when *every* trait is skipped the
OLRE is entirely mapped off, so the fit is the **same statistical model** as the
no-OLRE reference and the two log-likelihoods must agree:

| | logLik |
|---|---|
| no-OLRE reference | -404.5604 |
| OLRE, all skipped, **pre-fix** | **+22809.2693** |
| gap | **23213.8296** = 1800 x 12.8966 (exact) |
| OLRE, all skipped, **post-fix** | -404.5604 (gap **0.0000**) |

The code even carried a comment encoding the original reasoning error — that the
pinned term "contributes only a constant to the log-density". True with respect to
the optimiser; but it is a *large positive* constant, which is the whole defect.
Corrected in place.

### Candidates checked and cleared, with the reason

| candidate | verdict | evidence |
|---|---|---|
| `use_rr_B`, `use_rr_W`, `use_rr_B_slope` | **not an instance** | spherical `N(0,1)` prior — SD fixed at 1, never pinned near 0. `z_*` is mapped off only as a whole vector, and only when the block flag is 0. |
| `use_diag_B_slope` | **not an instance** | `theta_diag_B_slope`/`s_B_slope` mapped off only as whole vectors under `if (!use_diag_B_slope)`; no partial pin site exists. |
| `use_lv_B` | **not an instance** | contributes a *mean* to eta; adds no density term to `nll`. |
| `use_propto` | **not an instance** | `loglambda_phy`, `p_phy` whole-vector map-off; block flag 0 when mapped. |
| `use_diag_species`, `use_diag_cluster2` | **not an instance** | whole-vector map-off paired with flag 0. |
| `use_phylo_rr`, `use_phylo_diag`, phylo slope/dep tiers | **not an instance** | whole-vector map-offs paired with flag 0. |
| SPDE tiers (`use_spde*`) | **not an instance** | same — whole-vector map-offs paired with flag 0. |
| kernel tiers, `use_equalto`, `use_re_int` | **not an instance** | same. |
| `theta_dep_chol`, `theta_spde_dep_chol` | **not an instance** | these *are* partial pins, but they pin **Cholesky covariance entries to 0**, producing a legitimate block-diagonal covariance. A zero covariance never enters a `dnorm` SD denominator. |
| `atanh_cor_b`, `atanh_cor_spde_b` | **not an instance** | pin a *correlation* to 0, not an SD. |
| `lambda_packed_map` (loading constraints) | **not an instance** | pins **loadings**; loadings do not enter a `dnorm` SD. |
| `logit_p_tweedie`, `log_df_student` | **not an instance** | family dispersion parameters in the observation likelihood, not per-level RE density terms. |

**Conclusion: exactly two instances exist in the codebase. Both are now fixed.**

## 4. Full test suite — run end to end

`devtools::test()` complete (not a filtered sweep):

```
TOTALS  fail= 0   error= 1   warn= 2   skip= 782   pass= 7486
```

The single error was **my own new test** — the mixed-family fixture needs the
`family` column named by the `family_var` attribute. Fixed in `f2ffe229`; both new
files now pass (`binary-loglik-sign` 7 assertions, `olre-loglik-sign` 6). No
package-code failure anywhere in the suite.

## 5. Released versions

Checked each tag directly.

| tag | B-tier defect | W-tier defect |
|---|---|---|
| `v0.2.0` | no (gate absent) | **yes** |
| `v0.6.0` | **yes** | **yes** |
| `v0.6.0-rc.1` | **yes** | **yes** |
| `v0.6.0-rc.2` | **yes** | **yes** |

The **W-tier defect is the older one** — `skip_olre_t` dates to at least `v0.2.0`,
whereas `skip_psi_b_t` first appears at `v0.6.0`. gllvmTMB is not on CRAN, so no
CRAN-released artefact is affected.

## 6. Do-not-repeat — the tempting wrong connection

This does **not** explain the gradient-gate failures in
`Ayumi-495/BIRDBASE_pcm#3`. Both the SD and the random effect are mapped off, so
the spurious term is a **constant**: it corrupts the likelihood *value* and cannot
perturb gradients or the optimiser. I re-checked this for the W tier too — same
structure, same conclusion.

Second lesson, worth keeping: **"it's only a constant" is not a safety argument.**
It was written in the source as a justification and was wrong for the metric that
users actually read.

## 7. Commits on the lane (pushed, unmerged)

- `59a83c5b` B-tier fix (inherited from the handover)
- `409b68e6` W-tier fix + `test-olre-loglik-sign.R`
- `f2ffe229` mixed-family fixture correction

## 8. Landed

PR [#796](https://github.com/itchyshin/gllvmTMB/pull/796) **MERGED** by Shinichi.
`main` = `c3d11667`. Verified against GitHub, not a cached ref:

- all three commits are ancestors of `origin/main`
- `main`'s `src/gllvmTMB.cpp` contains 10 occurrences of `diag_B_skip`/`diag_W_skip`
- `test-binary-loglik-sign.R` and `test-olre-loglik-sign.R` both present in `main`
- CI on the PR was green (`ubuntu-latest (release)`)

## 8b. Still open / needs Shinichi

- 🔴 **No NEWS entry written.** This is user-visible and belongs in the 0.6.0 notes
  before release. Material for the bullet is in §2, §3 and §5.
- 🔴 **No GitHub issue filed** — outward-facing, remains your call. The evidence
  above is issue-ready.
- Fences honoured otherwise: the Codex lanes and `claude/va-wiring-20260726` were
  not touched.

## 9. Smallest safe next step

Merge PR #796, then add a NEWS bullet under 0.6.0 recording that `logLik`/AIC/BIC
were wrong for fits with pinned per-trait variances (single-trial Bernoulli,
ordinal_probit, multinomial) at both the Psi and OLRE tiers. Everything needed for
that bullet is in §2, §3 and §5 above.
