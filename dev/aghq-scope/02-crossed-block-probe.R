## Does an ordinary crossed (1|group) random intercept merge the per-site
## conditional-independence blocks? (i.e. destroy blockwise AGHQ.)
suppressPackageStartupMessages(library(gllvmTMB))
ctl <- gllvmTMBcontrol(se = FALSE)
comps <- function(H) { Hs <- as(H, "TsparseMatrix"); cp <- seq_len(nrow(H))
  repeat { old <- cp
    for (e in seq_along(Hs@i)) { a<-Hs@i[e]+1L; b<-Hs@j[e]+1L; m<-min(cp[a],cp[b]); cp[a]<-m; cp[b]<-m }
    for (e in rev(seq_along(Hs@i))) { a<-Hs@i[e]+1L; b<-Hs@j[e]+1L; m<-min(cp[a],cp[b]); cp[a]<-m; cp[b]<-m }
    if (identical(old, cp)) break }
  table(cp) }
set.seed(9); ns <- 20L; nt <- 3L
Y <- matrix(rnorm(ns*nt), ns, nt); colnames(Y) <- paste0("t",1:nt)
w <- data.frame(site = factor(seq_len(ns)), region = factor(rep(1:4, length.out = ns)),
                Y, check.names = FALSE)
for (frm in list(
  list(t="latent(d=1|site) ONLY",     f = ~ 1 + latent(1 | site, d = 1)),
  list(t="latent(d=1|site) + (1|region) CROSSED", f = ~ 1 + latent(1 | site, d = 1) + (1 | region)))) {
  ff <- as.formula(paste("traits(t1,t2,t3) ~", deparse(frm$f[[2]])))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(ff, data = w, unit = "site",
            family = gaussian(), control = ctl)))
  o <- fit$tmb_obj; H <- o$env$spHess(o$env$last.par.best, random = TRUE)
  tb <- comps(H)
  cat(sprintf("\n== %s ==\n  random blocks: %s\n  dim(H)=%d  n conditional blocks=%d  largest block=%d\n",
      frm$t, paste(fit$random, collapse=","), nrow(H), length(tb), max(as.integer(tb))))
}
