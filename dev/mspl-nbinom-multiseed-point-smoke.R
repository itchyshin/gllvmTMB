## Local multi-seed nbinom1/nbinom2 LA-ML vs LA-MSPL POINT smoke.
## se = FALSE. No SE / sandwich / intervals. Registry must stay planned.
## Operational PASS = every arm finite and converged.
## Admit-evidence PASS is NOT claimed from finiteness.
## Do not start Totoro / DRAC from this script (D-50 / D-139).
##
## Usage:
##   OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla \
##     dev/mspl-nbinom-multiseed-point-smoke.R
##
## Default grid: {nbinom2, nbinom1} × q=1 × 8 seeds × 2 arms = 32.
## Drop a family or seeds via env; never below 4 seeds if you run it.

Sys.setenv(OMP_NUM_THREADS = "1", NOT_CRAN = "true")
options(warn = 1)

ROOT <- Sys.getenv(
  "GLLVMTMB_ROOT",
  unset = getwd()
)
OUT_TSV <- file.path(
  ROOT, "docs/dev-log/research/2026-08-16-mspl-nbinom-point-smoke.tsv"
)
OUT_RDS <- "/tmp/mspl-nbinom-multiseed-point-smoke.rds"
HARD_STOP_S <- 20 * 60
SEEDS <- as.integer(strsplit(
  Sys.getenv("GLLVMTMB_NBINOM_SMOKE_SEEDS", "160801,160802,160803,160804,160805,160806,160807,160808"),
  ","
)[[1L]])
FAMILIES <- strsplit(
  Sys.getenv("GLLVMTMB_NBINOM_SMOKE_FAMILIES", "nbinom2,nbinom1"),
  ","
)[[1L]]

if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
  pkgload::load_all(ROOT, compile = FALSE)
}

.mspl_nb_fixture <- function(family, n_site = 16L, seed = 160801L) {
  set.seed(as.integer(seed))
  n_trait <- 3L
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(sprintf("t%d", seq_len(n_trait)), n_site))
  z <- stats::rnorm(n_site)
  Lambda <- c(0.70, -0.45, 0.35)
  beta <- c(0.40, 0.10, 0.55)
  eta <- beta[as.integer(trait)] +
    z[as.integer(site)] * Lambda[as.integer(trait)]
  mu <- exp(eta)
  y <- if (identical(family, "nbinom2")) {
    stats::rnbinom(length(mu), mu = mu, size = 2.5)
  } else {
    phi <- 1.5
    stats::rnbinom(length(mu), size = mu / phi, prob = 1 / (1 + phi))
  }
  data.frame(site = site, trait = trait, y = y)
}

.mspl_nb_fit <- function(dat, family, estimator = "mspl") {
  fam <- if (identical(family, "nbinom2")) {
    gllvmTMB::nbinom2(link = "log")
  } else {
    gllvmTMB::nbinom1(link = "log")
  }
  gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat,
    family = fam,
    estimator = estimator,
    control = gllvmTMB::gllvmTMBcontrol(
      n_init = 1L,
      init_jitter = 0,
      se = FALSE,
      warn_runaway = FALSE
    )
  )
}

.finite_fit <- function(fit) {
  is.list(fit) &&
    isTRUE(fit$opt$convergence %in% c(0, 1)) &&
    is.finite(as.numeric(fit$opt$objective))
}

rows <- list()
t0 <- proc.time()[["elapsed"]]
for (fam in FAMILIES) {
  for (seed in SEEDS) {
    if (proc.time()[["elapsed"]] - t0 > HARD_STOP_S) {
      warning("Hard stop after ", HARD_STOP_S, "s; partial smoke only.")
      break
    }
    dat <- .mspl_nb_fixture(fam, seed = seed)
    for (est in c("ml", "mspl")) {
      cell <- data.frame(
        family = fam,
        seed = seed,
        estimator = est,
        ok = NA,
        objective = NA_real_,
        c_n = NA_real_,
        registry = NA_character_,
        err = NA_character_,
        stringsAsFactors = FALSE
      )
      fit <- try(.mspl_nb_fit(dat, fam, estimator = est), silent = TRUE)
      if (inherits(fit, "try-error")) {
        cell$ok <- FALSE
        cell$err <- as.character(fit)
      } else {
        cell$ok <- .finite_fit(fit)
        cell$objective <- as.numeric(fit$opt$objective)
        if (identical(est, "mspl")) {
          cell$c_n <- as.numeric(fit$report$mspl_c_n)
          cell$registry <- fit$mspl$registry_status
        }
      }
      rows[[length(rows) + 1L]] <- cell
      cat(
        sprintf(
          "%s seed=%d %s ok=%s c_n=%s\n",
          fam, seed, est, cell$ok,
          if (is.na(cell$c_n)) NA else signif(cell$c_n, 4)
        )
      )
    }
  }
}

tab <- do.call(rbind, rows)
dir.create(dirname(OUT_TSV), recursive = TRUE, showWarnings = FALSE)
utils::write.table(tab, OUT_TSV, sep = "\t", row.names = FALSE, quote = FALSE)
saveRDS(tab, OUT_RDS)

n_ok <- sum(isTRUE(tab$ok) | tab$ok %in% TRUE)
n <- nrow(tab)
mspl <- tab[tab$estimator == "mspl", , drop = FALSE]
cat(sprintf(
  "operational %s: %d/%d finite. MSPL c=1 count=%d. admitted count=%d.\n",
  if (n_ok == n) "PASS" else "FAIL",
  n_ok, n,
  sum(abs(mspl$c_n - 1) < 1e-8, na.rm = TRUE),
  sum(mspl$registry == "admitted", na.rm = TRUE)
))
cat("admit-evidence: NOT CLAIMED (finiteness is not Phase-4 exit).\n")
