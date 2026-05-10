# gllvmTMB

Stacked-Trait Generalised Linear Latent Variable Models with TMB.

`gllvmTMB` fits multivariate latent-variable models on long-format
trait data using Template Model Builder (TMB). The covariance
dispatch is the 3 x 5 keyword grid:

|                | scalar             | unique             | indep             | dep             | latent             |
|---             |---                 |---                 |---                |---              |---                 |
| **none**       | (omit)             | `unique()`         | `indep()`         | `dep()`         | `latent()`         |
| **phylo**      | `phylo_scalar()`   | `phylo_unique()`   | `phylo_indep()`   | `phylo_dep()`   | `phylo_latent()`   |
| **spatial**    | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

The decomposition mode `latent + unique` paired produces the
canonical reduced-rank covariance:
Sigma = Lambda Lambda^T + diag(s).

## Installation

```r
# install.packages("remotes")
remotes::install_github("itchyshin/gllvmTMB")
```

The package is in active development. The legacy repo at
`itchyshin/gllvmTMB-legacy` preserves the 0.1.x history.

## Where to start

- `vignette("gllvmTMB")` -- the Get Started worked example.
- The seven Tier-1 worked-example articles cover morphometrics,
  joint species distribution modelling, behavioural syndromes,
  covariance-correlation interpretation, choose-your-model,
  functional biogeography, and common pitfalls.

## Citation

If you use gllvmTMB, please cite the package and its key upstream
dependencies (TMB, sdmTMB, MCMCglmm). See `citation("gllvmTMB")`.

## Sister packages

- `drmTMB` -- univariate / bivariate distributional regression.
- `sdmTMB` -- spatial single-response models. gllvmTMB inherits
  sdmTMB's SPDE/mesh code for its `spatial_*()` keywords.
