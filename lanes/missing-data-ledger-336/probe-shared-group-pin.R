# Narrow probe for S2 independence pin (mirrors the new test_that block).
devtools::load_all(".", quiet = TRUE)
stopifnot(identical(Sys.getenv("GLLVMTMB_HEAVY_TESTS"), "1"))

set.seed(3362L)
n_sites <- 180L
n_group <- 18L
b_x_true <- 1.25
group_sd_x <- 0.55
group_sd_y <- 0.45
sigma_x <- 0.4
miss_idx <- sort(sample.int(n_sites, 36L))

z <- stats::rnorm(n_sites)
w <- stats::rnorm(n_sites)
grp <- rep(seq_len(n_group), length.out = n_sites)
group_shift_x <- stats::rnorm(n_group, sd = group_sd_x)
group_shift_y <- stats::rnorm(n_group, sd = group_sd_y)
x <- 0.2 + 0.7 * z - 0.3 * w + group_shift_x[grp] +
  stats::rnorm(n_sites, sd = sigma_x)

rows <- vector("list", n_sites)
for (s in seq_len(n_sites)) {
  eta1 <- 0.6 + b_x_true * x[s] - 0.25 * z[s] + group_shift_y[grp[s]]
  eta2 <- -0.3 + b_x_true * x[s] + 0.45 * z[s] + group_shift_y[grp[s]]
  rows[[s]] <- data.frame(
    site = s,
    trait = c("t1", "t2"),
    value = c(eta1, eta2) + stats::rnorm(2, sd = 0.4),
    x = x[s],
    z = z[s],
    w = w[s],
    grp = grp[s],
    stringsAsFactors = FALSE
  )
}
dat <- do.call(rbind, rows)
dat$site <- factor(dat$site, levels = seq_len(n_sites))
dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
dat$grp <- factor(dat$grp, levels = seq_len(n_group))
dat$species <- factor(rep(1L, nrow(dat)))
dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
miss_rows <- which(as.integer(dat$site) %in% miss_idx)
dat$x[miss_rows] <- NA_real_

fit <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + (0 + trait):z + mi(x) + (1 | grp),
  data = dat,
  family = gaussian(),
  impute = list(x = x ~ z + w + (1 | grp)),
  missing = miss_control(predictor = "model"),
  control = gllvmTMBcontrol(se = FALSE)
)))

stopifnot(identical(fit$missing_data$predictors$x$version, "phase2b"))
stopifnot(isTRUE(fit$missing_data$predictors$x$random$enabled))
stopifnot(identical(fit$missing_data$predictors$x$random$group, "grp"))

par <- fit$tmb_obj$env$parList(fit$opt$par)
mu_col <- fit$missing_data$predictors$x$mu_col
b_x_hat <- par$b_fix[mu_col]
gr_max <- max(abs(fit$tmb_obj$gr(fit$opt$par)))
cat(sprintf("b_x_hat=%.4f truth=%.4f abs_err=%.4f gr_max=%.3e\n",
            b_x_hat, b_x_true, abs(b_x_hat - b_x_true), gr_max))
stopifnot(abs(b_x_hat - b_x_true) < 0.35)
stopifnot(gr_max < 1e-2)
cat("PROBE_PASS\n")
