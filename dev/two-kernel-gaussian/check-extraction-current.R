## Exact-source fitted-extraction check for the admitted two-kernel Gaussian
## route. This is a small extraction check, not a parameter-recovery trial.
devtools::load_all(".", quiet = TRUE)

n <- 8L
species <- c(paste0("H", seq_len(n)), paste0("P", seq_len(n)))
A <- 0.6 ^ abs(outer(seq_len(n), seq_len(n), "-"))
I <- diag(n)
K_phy <- rbind(cbind(A, 0.55 * A), cbind(0.55 * A, A))
K_tip <- rbind(cbind(I, 0.55 * I), cbind(0.55 * I, I))
dimnames(K_phy) <- dimnames(K_tip) <- list(species, species)

y <- data.frame(
  species = factor(species, levels = species),
  row_id = factor(species, levels = species),
  H1 = c(sin(seq_len(n)), rep(NA_real_, n)),
  H2 = c(cos(seq_len(n)), rep(NA_real_, n)),
  P1 = c(rep(NA_real_, n), sin(seq_len(n) + 0.3)),
  P2 = c(rep(NA_real_, n), cos(seq_len(n) + 0.3))
)
formula <- traits(H1, H2, P1, P2) ~ 1 +
  kernel_latent(species, K = K_phy, d = 1, name = "phy", unique = TRUE) +
  kernel_latent(species, K = K_tip, d = 1, name = "tip", unique = TRUE)

fit <- gllvmTMB(
  formula, y, family = gaussian(), unit = "row_id", cluster = "species",
  missing = miss_control(response = "include"),
  control = gllvmTMBcontrol(se = FALSE), silent = TRUE,
  known_sigma_eps = 0.12
)
stopifnot(identical(fit$opt$convergence, 0L),
          identical(fit$known_sigma_eps, 0.12))
cat("CONVERGENCE", fit$opt$convergence, "KNOWN_SD", fit$known_sigma_eps, "\n")

for (level in c("phy", "tip")) {
  shared <- extract_Sigma(fit, level = level, part = "shared")$Sigma
  unique <- extract_Sigma(fit, level = level, part = "unique")$s
  total <- extract_Sigma(fit, level = level, part = "total")$Sigma
  stopifnot(length(unique) == 4L,
            identical(rownames(shared), names(unique)),
            identical(dimnames(shared), dimnames(total)))
  gap <- max(abs(total - shared - diag(unique)))
  stopifnot(gap < 1e-10)
  cat("TIER", level, "TOTAL_IDENTITY_GAP", format(gap, digits = 16), "\n")
}
cat("CURRENT_SOURCE_EXTRACTION_PASS\n")
