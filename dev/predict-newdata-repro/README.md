# predict(newdata) issue repros

Recorded against `main` `9354ac2f9bf73d0823868671bb5ac2dd995cd434`
(installed gllvmTMB 0.8.0.9000) before the alignment fix.

| Script | Issue | Before-fix result |
|---|---|---|
| `1384-na-recycle.R` | #1384 | `x = c(NA, 1, NA, 1)` recycles 1.748 / 0.789 onto the NA rows and swaps the complete rows (row 2 gets the t2 value). `x = c(1, NA, 1, 1)` warns `longer object length is not a multiple of shorter object length`. |
| `1423-scale-predvars.R` | #1423 | precomputed `xs` max\|newdata − in-sample\| = 0; `scale(x)` = 0.3751; one-row newdata errors `arguments imply differing number of rows: 1, 0`. |
| `1425-character-levels.R` | #1425 | `b` rows with only levels `b,c` are 0.71 below in-sample; adding an `a` row recovers the in-sample values. |
| `1424-contrasts.R` | #1424 | `contr.sum` on a training factor: in-sample predict has 180 rows; `newdata = training` errors `Unknown column(s): "gb" and "gc"`. |

Run with the installed package:

```r
Rscript --vanilla dev/predict-newdata-repro/1384-na-recycle.R
```
