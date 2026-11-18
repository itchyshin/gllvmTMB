suppressMessages(devtools::load_all(".", quiet = TRUE))
set.seed(11)
n <- 300; sp <- c("sp1","sp2","sp3")
## Training env: a REGION of the landscape -> its own mean/sd differ from the grid's
env_raw_train <- rnorm(n, mean = 2.0, sd = 1.4)
mu_t <- mean(env_raw_train); sd_t <- sd(env_raw_train)
env_train <- (env_raw_train - mu_t) / sd_t
beta <- c(0.8, -0.5, 1.1); alpha <- c(0.2, 0.6, -0.3)
d <- do.call(rbind, lapply(seq_along(sp), function(j) data.frame(
  cell_id = factor(seq_len(n)), trait = sp[j],
  value = rpois(n, exp(alpha[j] + beta[j]*env_train)), env = env_train)))
d$trait <- factor(d$trait, levels = sp)
f <- gllvmTMB(value ~ 0 + trait + trait:env, data = d, trait = "trait",
              unit = "cell_id", family = poisson(), silent = TRUE)

## Prediction grid: a DIFFERENT slab of landscape (as a real map extent is)
ng <- 400
env_raw_grid <- rnorm(ng, mean = 3.1, sd = 0.9)
mk <- function(e) do.call(rbind, lapply(sp, function(j)
  data.frame(cell_id = factor(seq_len(ng)), trait = j, env = e, value = 0)))

## RIGHT: reuse the TRAINING centre and scale
gd_right <- mk((env_raw_grid - mu_t) / sd_t)
## WRONG: scale() the grid on its own moments -- the shipped chunk
gd_wrong <- mk(as.numeric(scale(env_raw_grid)))
for (g in list(gd_right, gd_wrong)) g$trait <- factor(g$trait, levels = sp)
gd_right$trait <- factor(gd_right$trait, levels = sp)
gd_wrong$trait <- factor(gd_wrong$trait, levels = sp)

pr <- function(nd) { p <- predict(f, newdata = nd, type = "response"); if (is.data.frame(p)) { nm <- names(p)[sapply(p, is.numeric)]; as.numeric(p[[tail(nm,1)]]) } else as.numeric(p) }
a <- pr(gd_right); b <- pr(gd_wrong)
cat(sprintf("training env raw: mean %.2f sd %.2f\n", mu_t, sd_t))
cat(sprintf("grid     env raw: mean %.2f sd %.2f\n", mean(env_raw_grid), sd(env_raw_grid)))
cat(sprintf("\nmedian ratio  wrong/right : %.3f\n", median(b/a)))
cat(sprintf("range  ratio  wrong/right : %.3f to %.3f\n", min(b/a), max(b/a)))
cat(sprintf("max |log2 fold error|     : %.2f  (=> factor %.1f)\n",
            max(abs(log2(b/a))), 2^max(abs(log2(b/a)))))
cat(sprintf("spearman cor(right, wrong): %.4f   <- MAP LOOKS FINE\n",
            cor(a, b, method = "spearman")))

sp_id <- gd_right$trait
cat("\n--- within species (what a per-species map shows) ---\n")
for (j in sp) {
  k <- sp_id == j
  cat(sprintf("%s : spearman %.4f | median ratio %.3f | worst fold %.1fx\n",
      j, cor(a[k], b[k], method="spearman"), median(b[k]/a[k]),
      2^max(abs(log2(b[k]/a[k])))))
}
