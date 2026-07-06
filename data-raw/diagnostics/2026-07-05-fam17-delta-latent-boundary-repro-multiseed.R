## FAM-17 delta-lognormal LATENT cell — multi-seed convergence/identifiability sweep.
## Does the register's "convergence=1, pdHess=TRUE" boundary ever appear, and if so is
## it benign (pdHess TRUE + estimates recover) or real (pdHess FALSE / large grad)?
options(crayon.enabled = FALSE)
suppressMessages(pkgload::load_all(".", quiet = TRUE))

one <- function(seed) {
  set.seed(seed)
  n_ind <- 800L; Td <- 3L; mu_d <- c(1.0, 1.5, 2.0); sig_d <- 0.7
  y <- matrix(NA_real_, n_ind, Td)
  for (t in seq_len(Td)) { eta <- mu_d[t]; p <- 1/(1+exp(-eta))
    y[, t] <- stats::rbinom(n_ind, 1, p) * stats::rlnorm(n_ind, eta, sig_d) }
  dfd <- data.frame(individual = factor(rep(seq_len(n_ind), each = Td)),
                    trait = factor(rep(letters[1:Td], n_ind), levels = letters[1:Td]),
                    value = as.vector(t(y)))
  f <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = dfd, trait = "trait", unit = "individual",
    family = gllvmTMB::delta_lognormal()))), error = function(e) NULL)
  if (is.null(f)) return(data.frame(seed = seed, conv = NA, pdHess = NA, maxgrad = NA, b_recovers = NA))
  conv <- f$opt$convergence
  pd   <- isTRUE(f$sd_report$pdHess)
  g    <- tryCatch(max(abs(f$tmb_obj$gr(f$opt$par))), error = function(e) NA_real_)
  bfix <- tryCatch(summary(f$sd_report, "fixed"), error = function(e) NULL)
  bok  <- if (!is.null(bfix)) {
    bf <- bfix[grepl("^b_fix$", rownames(bfix)), "Estimate"]; max(abs(bf - mu_d)) < 0.20
  } else NA
  data.frame(seed = seed, conv = conv, pdHess = pd, maxgrad = signif(g, 3), b_recovers = bok)
}

res <- do.call(rbind, lapply(c(1L, 7L, 13L, 42L, 101L, 2025L), one))
print(res, row.names = FALSE)
cat(sprintf("\nSWEEP SUMMARY (n=%d seeds): conv==0 %d/%d | pdHess=TRUE %d/%d | b_fix recovers %d/%d\n",
            nrow(res), sum(res$conv == 0, na.rm = TRUE), nrow(res),
            sum(res$pdHess, na.rm = TRUE), nrow(res),
            sum(res$b_recovers, na.rm = TRUE), nrow(res)))
