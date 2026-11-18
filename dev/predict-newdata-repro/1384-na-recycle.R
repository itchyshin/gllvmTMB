## Repro for #1384: predict(newdata) recycles a shorter eta onto NA rows.
## Recorded against main 9354ac2f9bf73d0823868671bb5ac2dd995cd434.
suppressMessages(library(gllvmTMB))
cat("commit: 9354ac2f9bf73d0823868671bb5ac2dd995cd434\n")
cat("package:", as.character(packageVersion("gllvmTMB")), "\n")
set.seed(4)
n <- 30
nt <- 3
d <- data.frame(
  unit = factor(rep(seq_len(n), each = nt)),
  trait = factor(rep(paste0("t", 1:nt), n)),
  x = rnorm(n * nt)
)
d$value <- c(1, 0, -1)[as.integer(d$trait)] + 0.8 * d$x + rnorm(n * nt, sd = 0.5)
fit <- gllvmTMB(
  value ~ 0 + trait + x,
  data = d, unit = "unit", trait = "trait", family = gaussian(),
  control = gllvmTMBcontrol(se = FALSE)
)
nd <- data.frame(
  unit = factor(c(1, 1, 1, 1), levels = levels(d$unit)),
  trait = factor(c("t1", "t1", "t2", "t2"), levels = levels(d$trait)),
  x = c(NA, 1, NA, 1)
)
cat("--- nd: x = c(NA, 1, NA, 1) ---\n")
print(tryCatch(
  predict(fit, newdata = nd, re_form = ~0),
  warning = function(w) {
    cat("WARNING:", conditionMessage(w), "\n")
    invokeRestart("muffleWarning")
  }
))
nd2 <- nd
nd2$x <- c(1, NA, 1, 1)
cat("--- nd2: x = c(1, NA, 1, 1) ---\n")
print(tryCatch(
  withCallingHandlers(
    predict(fit, newdata = nd2, re_form = ~0),
    warning = function(w) {
      cat("WARNING:", conditionMessage(w), "\n")
      invokeRestart("muffleWarning")
    }
  ),
  error = function(e) conditionMessage(e)
))
## Row-by-row reference for the complete rows
cat("--- row-by-row complete rows ---\n")
for (i in c(2L, 4L)) {
  one <- nd[i, , drop = FALSE]
  p <- tryCatch(
    predict(fit, newdata = one, re_form = ~0)$est,
    error = function(e) conditionMessage(e)
  )
  cat("row", i, ":", paste(p, collapse = " "), "\n")
}
