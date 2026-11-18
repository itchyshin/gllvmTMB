# Issue 1467 reproduction and completed output fixes

Supplied-data results and all fit evidence remain local.

The patch repairs omitted LV coefficient summaries, one-axis ordiplot(),
and redundant full-group coding of factor LV predictors. It also includes
the loading prior in uncertainty calculations, including lazy standard_errors(),
missing-response joint predictions, and ordinary ordination covariance.

Loading-ridge SDs are local posterior approximations conditional on the chosen prior and axis parameterisation. They are not calibrated sampling errors.

refit.R runs the three configurations and saves full objects, summaries,
diagnostics, predictor effects, and ordination PDFs outside Git. It explicitly
sets Introduced as the factor reference. Add ridge-multistart for a bounded
five-start BFGS sensitivity check. Smaller positive ridge scales shrink more;
Inf disables the penalty. The ordinary Laplace default remains unpenalised.

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 \
  Rscript --vanilla dev/issue-1467/refit.R /absolute/path/dat.csv /absolute/output/directory
```

The comparison separates the unpenalised likelihood at the fitted point from
the penalised objective. Ordinary AIC/BIC/LRT rank comparisons are inappropriate
for the ridge MAP fit. Allow 1-3 minutes for the supplied-data reproduction on the Mac Studio.

Evidence includes synthetic reproductions, the original redundant factor fits,
corrected contrasts, corrected posterior curvature, and integrated regressions.
Historical after-task reports describe earlier phases; the completion report
supersedes their pending-data and withheld-ridge-SD status. No data CSV or
fitted object is committed. Reply drafting and posting are stopped.
