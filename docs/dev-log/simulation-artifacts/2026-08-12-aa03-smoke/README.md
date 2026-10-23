# AA-03 archive-bound smoke receipt

**Status:** PASS for one pre-run smoke only; this is not production evidence or
a claim promotion.

## Exact run

| Field | Value |
| --- | --- |
| Source branch / commits | `codex/aa03-gaussian-latent-admission` through `dcb6f89f` |
| Archive | `gllvmTMB-aa03-smoke.tar` |
| Archive SHA-256 | `b6f509fd68275eec8f9e5a1c9f21247f2c20d75b14726bc3f8544b28793d563b` |
| Payload manifest SHA-256 | `e019696fec50f9de8b10b09b37fe0c98ebdf63d63bae31d349ed8d116ebc70b3` |
| Installed package | isolated archive-installed `gllvmTMB` 0.6.0 |
| Cell / seed | `g_latent_n240` / `471400001` |
| Attempt status | `usable` |
| Fit time | 0.854 seconds |
| Estimand rows | 30, all finite |
| Health | converged, stationary, PD Hessian; no boundary or geometry flag; maximum gradient 0.002772007 |
| Raw receipt | `/private/tmp/gllvmtmb-aa03-smoke-20260812-r4/` |

The runner built a metadata-controlled source archive, extracted it, installed
it into an isolated R library, and rejected completion unless the loaded
namespace came from that library. The smoke used exactly the frozen
`g_latent_n240` registry row; it did not execute any held, failed, rho-stress,
or Psi-boundary row.

Three earlier isolated directories (`...-smoke-20260812`, `...-r2`, and
`...-r3`) are retained failure evidence for launcher construction. They did
not produce a usable attempt and are not pooled with this receipt.

## Comparator pre-run

The local fail-closed comparator runner passed with 353 assertions and no
failures or warnings:

```sh
GLLVMTMB_CRAN07_RECERTIFY=true Rscript --vanilla -e \
  'devtools::test(filter = "cran07-core-comparators", stop_on_failure = TRUE)'
```

Its Gaussian latent row uses the same rank-1, diagonal-Psi ordinary model and
the matched `glmmTMB::rr() + diag()` reference. The six ordinary individual
tests are intentionally skipped in this mode because the release runner owns
their all-row accounting.

## Full-batch estimate and approval gate

The frozen full cohort is 1,600 all-attempt `g_latent_n240` fits. At the smoke
fit time, its lower-bound serial fit time is 1,366 seconds (22.8 minutes),
before source preparation, retained output writes, aggregation, comparator
receipt, and repair reserve. The operational estimate is therefore 30–45
minutes on one core; a bounded Totoro parallel batch can reduce wall time but
must preserve every attempt and the predeclared seed schedule.

No full batch has been launched. It requires Shinichi's separate approval,
after which a fresh source archive (the current smoke archive predates this
receipt document) and a new normal-vignette/package-platform ladder are
required for any later release decision.
