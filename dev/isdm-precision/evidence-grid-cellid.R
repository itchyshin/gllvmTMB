suppressMessages(devtools::load_all(".", quiet = TRUE))
sp <- c("A","B"); set.seed(3); n <- 150
ev <- rnorm(n)
u  <- rnorm(n, 0, 0.8)                      # a REAL unit-level effect
d <- do.call(rbind, lapply(seq_along(sp), function(j)
  data.frame(site=factor(seq_len(n)), env=ev,
             trait=sp[j], value=rpois(n, exp(0.5 + c(0.9,-0.4)[j]*ev + u)))))
d$trait <- factor(d$trait, levels=sp)

## Model WITH a unit-level random intercept
f <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + trait:env + (1 | site),
  data = d, trait = "trait", unit = "site", family = poisson(), silent = TRUE)))
cat("fit conv:", f$opt$convergence, "| par blocks:",
    paste(unique(names(f$opt$par)), collapse=", "), "\n")

grid <- expand.grid(env = seq(-2, 2, length.out = 25), trait = sp)
grid$value <- 0
pr <- function(cell) {
  g <- grid; g$site <- factor(cell, levels = levels(d$site))
  p <- predict(f, newdata = g, type = "link")
  if (is.data.frame(p)) { nm <- names(p)[sapply(p,is.numeric)]; as.numeric(p[[tail(nm,1)]]) } else as.numeric(p)
}
a <- pr(levels(d$site)[1]); b <- pr(levels(d$site)[2]); z <- pr(levels(d$site)[50])
cat(sprintf("\nmax |pred(cell 1) - pred(cell 2)|  = %.6g\n", max(abs(a-b))))
cat(sprintf("max |pred(cell 1) - pred(cell 50)| = %.6g\n", max(abs(a-z))))
cat(sprintf("range of predictions themselves    = %.3f\n", diff(range(a))))
cat(if (max(abs(a-b)) < 1e-8) "\n=> cell_id choice is IGNORED: the map does NOT inherit a unit effect.\n"
    else "\n=> cell_id choice CHANGES the map: it DOES inherit that cell's effect.\n")
