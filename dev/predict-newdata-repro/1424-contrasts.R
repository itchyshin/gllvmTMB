## Repro for #1424: restore_newdata_factor_levels drops contrasts.
## Recorded against main 9354ac2f9bf73d0823868671bb5ac2dd995cd434.
## This helper is on the predict(newdata) path used by #1384/#1423/#1425.
suppressMessages(library(gllvmTMB))
cat("commit: 9354ac2f9bf73d0823868671bb5ac2dd995cd434\n")
cat("package:", as.character(packageVersion("gllvmTMB")), "\n")
set.seed(5)
n <- 60
d <- do.call(rbind, lapply(1:3, function(j) {
  data.frame(unit = factor(1:n), trait = paste0("t", j))
}))
d$trait <- factor(d$trait)
d$g <- factor(rep(sample(c("a", "b", "c"), n, TRUE), 3))
d$value <- 1 + 0.8 * (d$g == "b") - 0.5 * (d$g == "c") + rnorm(nrow(d))
contrasts(d$g) <- contr.sum(3)
fit <- suppressWarnings(suppressMessages(
  gllvmTMB(
    value ~ 0 + trait + g + latent(0 + trait | unit, d = 1),
    data = d, unit = "unit", trait = "trait", silent = TRUE
  )
))
ins <- suppressMessages(predict(fit))
cat("in-sample predict rows:", nrow(ins), "\n")
r <- tryCatch(
  suppressMessages(predict(fit, newdata = d)),
  error = function(e) conditionMessage(e)
)
if (is.character(r)) {
  cat("newdata error:", gsub("\n", " ", r), "\n")
} else {
  cat("newdata rows:", nrow(r), " max|diff| =", max(abs(r$est - ins$est)), "\n")
}
