## Cross-family demo: nominal (multinomial) sharing a latent factor with
## Gaussian, binary (binomial), count (Poisson), and ordinal traits. Recovers
## known cross-correlations. Compute local -> Totoro; results local (D-50).
suppressMessages(devtools::load_all(Sys.getenv("GLLVMTMB_DIR","/private/tmp/gtmb-item2"), quiet=TRUE))
d <- 3L
## rows: g, b, p, o, cat:2, cat:3   (6 latent trait-dims; multinomial K=3 -> 2 contrasts)
Lam <- matrix(c(
  1.2, 0.2, 0.0,   # g gaussian
  0.9, 0.6, 0.1,   # b binomial
  0.3, 1.0, 0.4,   # p poisson
  0.7, 0.4, 0.9,   # o ordinal
  1.0, 0.5, 0.2,   # cat:2
 -0.5, 0.8, 0.6),  # cat:3
 nrow=6, byrow=TRUE)
rn <- c("g","b","p","o","cat:2","cat:3")
R_true <- cov2cor(Lam %*% t(Lam)); dimnames(R_true) <- list(rn, rn)

build <- function(seed, N=500L, reps=6L, Ko=4L) {
  set.seed(seed); Z <- matrix(rnorm(N*d),N,d); u <- Z %*% t(Lam)   # N x 6
  taus <- c(-Inf, sort(rnorm(Ko-1L)), Inf)                          # ordinal cutpoints
  rows <- list()
  for (i in seq_len(N)) for (r in seq_len(reps)) {
    yg <- u[i,1] + rnorm(1,sd=.3)
    yb <- rbinom(1,1,plogis(u[i,2]))
    yp <- rpois(1, exp(u[i,3] + 0.3))
    yo <- as.integer(cut(u[i,4] + rnorm(1), breaks=taus))           # 1..Ko
    pc <- c(1, exp(u[i,5]), exp(u[i,6])); pc <- pc/sum(pc); yc <- sample.int(3L,1L,prob=pc)
    rows[[length(rows)+1L]] <- data.frame(unit=i, trait="g",   family="g", value=yg)
    rows[[length(rows)+1L]] <- data.frame(unit=i, trait="b",   family="b", value=yb)
    rows[[length(rows)+1L]] <- data.frame(unit=i, trait="p",   family="p", value=yp)
    rows[[length(rows)+1L]] <- data.frame(unit=i, trait="o",   family="o", value=yo)
    rows[[length(rows)+1L]] <- data.frame(unit=i, trait="cat", family="m", value=yc)
  }
  d2 <- do.call(rbind, rows)
  d2$unit<-factor(d2$unit,levels=seq_len(N)); d2$trait<-factor(d2$trait); d2$family<-factor(d2$family); d2
}
fam <- list(g=gaussian(), b=binomial(), p=poisson(), o=ordinal_probit(), m=multinomial())
attr(fam,"family_var") <- "family"

cat("R_true:\n"); print(round(R_true,3))
dat <- build(1L)
cat("\ndata:", nrow(dat), "rows, traits:", paste(levels(dat$trait),collapse=","), "\n")
fit <- tryCatch(suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 3, unique = FALSE),
  data=dat, family=fam, trait="trait", unit="unit"))), error=function(e){cat("FIT ERR:",conditionMessage(e),"\n");NULL})
if(!is.null(fit)){
  cat("FIT OK conv=",fit$opt$convergence,"\n")
  S <- suppressMessages(extract_Sigma(fit, level="unit", part="shared", link_residual="none"))
  Rh <- cov2cor(S$Sigma); cat("\nR_hat (latent):\n"); print(round(Rh,3))
  cat("\nextract_cross_correlations (nominal <-> each partner, obs scale):\n")
  print(suppressMessages(extract_cross_correlations(fit, level="unit", link_residual="auto")))
}
