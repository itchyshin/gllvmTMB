## Repro for #1425: character predictor silently mispredicts without baseline.
## Recorded against main 9354ac2f9bf73d0823868671bb5ac2dd995cd434.
suppressMessages(library(gllvmTMB))
cat("commit: 9354ac2f9bf73d0823868671bb5ac2dd995cd434\n")
cat("package:", as.character(packageVersion("gllvmTMB")), "\n")
set.seed(5)
n <- 40
d <- do.call(rbind, lapply(1:3, function(j) {
  data.frame(unit = factor(1:n), trait = paste0("t", j), stringsAsFactors = FALSE)
}))
d$trait <- factor(d$trait)
d$g <- rep(sample(c("a", "b", "c"), n, TRUE), 3)
d$value <- 1 + 0.8 * (d$g == "b") + rnorm(nrow(d))
fit <- suppressWarnings(suppressMessages(
  gllvmTMB(
    value ~ 0 + trait + g + latent(0 + trait | unit, d = 1),
    data = d, unit = "unit", trait = "trait", silent = TRUE
  )
))
all <- suppressMessages(predict(fit))
rows_b <- which(d$g == "b")[1:3]
rows_c <- which(d$g == "c")[1:3]
rows_a <- which(d$g == "a")[1:3]
pick <- function(r) suppressMessages(predict(fit, newdata = d[r, ]))$est
cat("in-sample est for 3 'b' rows                  :", round(all$est[rows_b], 3), "\n")
cat(
  "newdata = same 'b' rows + 'c' rows (levels b,c):",
  round(pick(c(rows_b, rows_c))[1:3], 3), "\n"
)
cat(
  "newdata = same 'b' rows + 'a' rows (levels a,b):",
  round(pick(c(rows_b, rows_a))[1:3], 3), "\n"
)
cat(
  "diff b+c vs in-sample:",
  round(pick(c(rows_b, rows_c))[1:3] - all$est[rows_b], 3), "\n"
)
