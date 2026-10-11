# predict(newdata) issue repros

Recorded against `main` `9354ac2f9bf73d0823868671bb5ac2dd995cd434`
(installed gllvmTMB 0.8.0.9000) before the alignment fix.

| Script | Issue | Before-fix result |
|---|---|---|
| `1384-na-recycle.R` | #1384 | `x = c(NA, 1, NA, 1)` recycles 1.748 / 0.789 onto the NA rows and swaps the complete rows (row 2 gets the t2 value). `x = c(1, NA, 1, 1)` warns `longer object length is not a multiple of shorter object length`. |
| `1423-scale-predvars.R` | #1423 | precomputed `xs` max\|newdata − in-sample\| = 0; `scale(x)` = 0.3751; one-row newdata errors `arguments imply differing number of rows: 1, 0`. |
| `1425-character-levels.R` | #1425 | `b` rows with only levels `b,c` are 0.71 below in-sample; adding an `a` row recovers the in-sample values. |
| `1424-contrasts.R` | #1424 | `contr.sum` on a training factor: in-sample predict has 180 rows; `newdata = training` errors `Unknown column(s): "gb" and "gc"`. |

After the alignment helpers (same scripts, `pkgload::load_all` on this branch):

| Script | After-fix result |
|---|---|
| `1384-na-recycle.R` | NA rows are `NA`; complete rows 1.748 / 0.789 match row-by-row. |
| `1423-scale-predvars.R` | `scale(x)` max\|diff\| = 0; one-row newdata returns. |
| `1425-character-levels.R` | `b` rows match in-sample whether or not `a` is in `newdata`. |
| `1424-contrasts.R` | 180 rows; max\|diff\| = 0. |

Run with the installed package:

```r
Rscript --vanilla dev/predict-newdata-repro/1384-na-recycle.R
```
