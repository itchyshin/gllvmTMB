## Repro for #1423: predict(newdata) re-evaluates scale() on the new rows.
## Recorded against main 9354ac2f9bf73d0823868671bb5ac2dd995cd434.
suppressMessages(library(gllvmTMB))
cat("commit: 9354ac2f9bf73d0823868671bb5ac2dd995cd434\n")
cat("package:", as.character(packageVersion("gllvmTMB")), "\n")
set.seed(2)
n <- 60
d <- do.call(rbind, lapply(1:3, function(j) {
  data.frame(unit = factor(1:n), trait = paste0("t", j))
}))
d$trait <- factor(d$trait)
d$x <- rep(rnorm(n, 10, 3), 3)
d$xs <- as.numeric(scale(d$x))
d$value <- 1 + 0.3 * d$x * (d$trait == "t2") + rnorm(nrow(d))
fit_fun <- function(f) {
  suppressWarnings(suppressMessages(
    gllvmTMB(f, data = d, unit = "unit", trait = "trait", silent = TRUE)
  ))
}
sub <- d[d$unit %in% levels(d$unit)[1:5], ]
cmp <- function(fit, label) {
  all <- suppressMessages(predict(fit))
  m <- match(paste(sub$unit, sub$trait), paste(all$unit, all$trait))
  nd <- suppressMessages(predict(fit, newdata = sub))
  cat(sprintf("%-26s max|newdata-in-sample| = %.4f\n",
              label, max(abs(nd$est - all$est[m]))))
}
cmp(
  fit_fun(value ~ 0 + trait + trait:xs + latent(0 + trait | unit, d = 1)),
  "precomputed xs column"
)
f_scale <- fit_fun(value ~ 0 + trait + trait:scale(x) + latent(0 + trait | unit, d = 1))
cmp(f_scale, "scale(x) in formula")
cat(
  "single row newdata, scale(x): ",
  tryCatch(
    {
      predict(f_scale, newdata = d[1, ])
      "returned"
    },
    error = function(e) conditionMessage(e)
  ),
  "\n"
)
