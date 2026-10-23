## Probe: what does predict() actually do on an isdm_sources() fit?
## Lane claude/isdm-predict-20260817 — OWED-1 from
## docs/dev-log/handover/2026-08-17-claude-handover-isdm-next.md.
## Nothing here is a claim; every line prints evidence.

suppressMessages(devtools::load_all(".", quiet = TRUE))

say <- function(id, ...) cat(sprintf("PROBE[%s] %s\n", id, sprintf(...)))
try_say <- function(id, expr) {
  r <- tryCatch(expr, error = function(e) e, warning = function(w) w)
  if (inherits(r, "condition")) say(id, "CONDITION: %s :: %s",
                                    class(r)[1], conditionMessage(r))
  r
}

## ---------------------------------------------------------------- Part A
## Non-spatial isdm fit: 2 sources (count + pa), shared latent, offset.
set.seed(7)
n_cell <- 30L
cells <- paste0("c", seq_len(n_cell))
species <- c("sp1", "sp2")
x <- as.numeric(scale(runif(n_cell)))
alpha <- c(-0.1, 0.2); beta <- c(0.4, -0.3)
## a REAL shared latent field, so random-effect re-add paths are testable
## (round 1 had none: the fitted z collapsed to ~0 and re_form variants
## were indistinguishable)
u_cell <- rnorm(n_cell, sd = 0.8)
lam_tr <- c(0.9, 0.6)
mk <- function(src, kind, support) {
  d <- expand.grid(cell_id = cells, trait = species, stringsAsFactors = FALSE)
  ci <- match(d$cell_id, cells); si <- match(d$trait, species)
  eta <- alpha[si] + x[ci] * beta[si] + u_cell[ci] * lam_tr[si]
  d$isdm_source <- src
  d$support <- support
  d$value <- if (kind == "count") rpois(nrow(d), support * exp(eta))
             else rbinom(nrow(d), 1, -expm1(-support * exp(eta)))
  d
}
dat <- rbind(mk("gbif", "count", 1.5), mk("survey", "pa", 0.9))
dat$trait <- factor(dat$trait)
dat$cell_id <- factor(dat$cell_id)
dat$isdm_source <- factor(dat$isdm_source, levels = c("gbif", "survey"))
dat$log_support <- log(dat$support)
dat$env <- x[match(as.character(dat$cell_id), cells)]
dat$src_gbif <- as.integer(dat$isdm_source == "gbif")

fam <- isdm_sources(gbif = poisson(), survey = binomial(link = "cloglog"))
fitA <- suppressMessages(gllvmTMB(
  value ~ 0 + trait + trait:env + trait:src_gbif + offset(log_support) +
    latent(0 + trait | cell_id, d = 1),
  data = dat, trait = "trait", unit = "cell_id", family = fam, silent = TRUE))
say("A0", "fitA class=%s conv=%d", paste(class(fitA), collapse = ","),
    fitA$opt$convergence)

## A1: in-sample default — shape, columns, link scale vs report$eta
pA1 <- predict(fitA)
say("A1", "in-sample cols: [%s]; nrow=%d (data %d); est==report$eta: %s",
    paste(names(pA1), collapse = ","), nrow(pA1), nrow(dat),
    isTRUE(all.equal(pA1$est, as.numeric(fitA$report$eta))))
say("A1b", "arm attribution in output: has isdm_source col? %s",
    "isdm_source" %in% names(pA1))

## A2: response scale — per-row inverse link, per arm
pA2 <- predict(fitA, type = "response")
i_ct <- dat$isdm_source == "gbif"; i_pa <- !i_ct
man_ct <- exp(pA1$est[i_ct])
man_pa <- -expm1(-exp(pA1$est[i_pa]))
say("A2", "count arm: response==exp(link)? %s; pa arm: response==1-exp(-exp(link))? %s",
    isTRUE(all.equal(pA2$est[i_ct], man_ct)),
    isTRUE(all.equal(pA2$est[i_pa], man_pa)))
say("A2b", "pa-arm response in [0,1]: %s; count-arm response >0: %s",
    all(pA2$est[i_pa] >= 0 & pA2$est[i_pa] <= 1), all(pA2$est[i_ct] > 0))

## A3: newdata = training data — should equal in-sample IF the same terms
##     (offset + all REs) are included on both paths
pA3 <- suppressMessages(predict(fitA, newdata = dat))
dif3 <- pA3$est - pA1$est
say("A3", "newdata==in-sample (link): max|diff|=%.3g; cor(diff, log_support)=%.3f",
    max(abs(dif3)), suppressWarnings(cor(dif3, dat$log_support)))

## A2c: newdata + type = "response" — the newdata branch reduces the per-row
##      family/link vectors to a per-trait MODAL id (.modal_integer_id), which
##      cannot represent an isdm fit (family varies by source WITHIN trait).
##      Found by the adversarial verification (verify-report.md VER[C1]);
##      re-measured here so the number has a reproducible source line.
pA2c <- suppressMessages(predict(fitA, newdata = dat, type = "response"))
say("A2c", "newdata response == in-sample response? %s; max|diff|=%.3g",
    isTRUE(all.equal(pA2c$est, pA2$est)), max(abs(pA2c$est - pA2$est)))
say("A2c2", "pa-arm newdata 'probabilities': range [%.3g, %.3g]; equals exp(link) (WRONG arm)? %s",
    min(pA2c$est[i_pa]), max(pA2c$est[i_pa]),
    isTRUE(all.equal(pA2c$est[i_pa], exp(pA3$est[i_pa]))))

## A4: re_form = ~0 — fixed-effects-only on newdata
pA4 <- suppressMessages(predict(fitA, newdata = dat, re_form = ~0))
say("A4", "re_form=~0: sd(RE contribution)=%.4g (should be >0 if latent active)",
    sd(pA3$est - pA4$est))

## A5: re_form = NA — the roxygen says NA is accepted; is it?
pA5 <- try_say("A5", suppressMessages(predict(fitA, newdata = dat, re_form = NA)))
if (is.data.frame(pA5)) {
  say("A5", "re_form=NA ran; equals ~0 (documented)? %s; equals ~. ? %s",
      isTRUE(all.equal(pA5$est, pA4$est)), isTRUE(all.equal(pA5$est, pA3$est)))
}

## A6: se.fit on training rows; and the documented newdata refusal
pA6 <- try_say("A6", predict(fitA, se.fit = TRUE))
if (is.data.frame(pA6)) {
  say("A6", "se.fit in-sample: col present %s; range [%.3g, %.3g]; all finite %s",
      "se.fit" %in% names(pA6), min(pA6$se.fit), max(pA6$se.fit),
      all(is.finite(pA6$se.fit)))
}
try_say("A6b", predict(fitA, newdata = dat, se.fit = TRUE))

## A7: newdata with a genuinely NEW cell level (unseen unit)
nd_new <- dat[dat$cell_id == "c1", ]
nd_new$cell_id <- factor("cNEW")
nd_new$env <- 0.25
pA7 <- try_say("A7", suppressMessages(predict(fitA, newdata = nd_new)))
if (is.data.frame(pA7)) {
  pA7f <- suppressMessages(predict(fitA, newdata = nd_new, re_form = ~0))
  say("A7", "unseen unit ran; equals fixed-only (documented fallback)? %s",
      isTRUE(all.equal(pA7$est, pA7f$est)))
}

## ---------------------------------------------------------------- Part B
## Spatial isdm fit (the map-making case): spatial_latent + mesh.
## DGP carries a STRONG shared field so the fitted field cannot collapse
## (an earlier weaker version collapsed to sd ~ 1e-4 with conv = 1, which
## made the path-comparison vacuous).
set.seed(23)
n_lon <- 10; n_lat <- 8
grid <- expand.grid(lon = seq(0, 1.2, length.out = n_lon),
                    lat = seq(0, 0.9, length.out = n_lat))
grid <- grid[order(grid$lat, grid$lon), ]
n_cell <- nrow(grid)
cells <- paste0("cell_", seq_len(n_cell))
speciesB <- c("spA", "spB")
xB <- as.numeric(scale(grid$lon))
u <- 1.5 * sin(pi * grid$lat / 0.9) * cos(pi * grid$lon / 1.2)
alphaB <- c(0.3, 0.5); betaB <- c(0.6, -0.4); lambdaB <- c(1, 0.8)
etaB <- outer(u, lambdaB) + sweep(outer(xB, betaB), 2, alphaB, "+")
a_g <- 5 * exp(rnorm(n_cell, sd = 0.2)); a_s <- rep(1.2, n_cell)
base <- expand.grid(cell_id = cells, trait = speciesB,
                    stringsAsFactors = FALSE)
ci <- match(base$cell_id, cells); si <- match(base$trait, speciesB)
gbif <- transform(base, source = "gbif", support = a_g[ci],
  lon = grid$lon[ci], lat = grid$lat[ci],
  value = rpois(nrow(base), a_g[ci] * exp(etaB[cbind(ci, si)])))
pa <- do.call(rbind, lapply(1:3, function(v) transform(base,
  source = "survey", support = a_s[ci],
  lon = grid$lon[ci], lat = grid$lat[ci],
  value = rbinom(nrow(base), 1, -expm1(-a_s[ci] * exp(etaB[cbind(ci, si)]))))))
datB <- rbind(gbif, pa)
datB$trait <- factor(datB$trait)
datB$cell_id <- factor(datB$cell_id)
datB$isdm_gbif <- as.integer(datB$source == "gbif")
datB$log_support <- log(datB$support)
datB$env <- xB[match(as.character(datB$cell_id), cells)]
datB$isdm_source <- factor(ifelse(datB$source == "gbif", "gbif", "survey_pa"),
                           levels = c("gbif", "survey_pa"))
famB <- isdm_sources(gbif = poisson(), survey_pa = binomial(link = "cloglog"))

mesh <- make_mesh(datB[, c("lon", "lat")], c("lon", "lat"), cutoff = 0.12)
fitB <- try_say("B0", suppressMessages(gllvmTMB(
  value ~ 0 + trait + trait:env + trait:isdm_gbif + offset(log_support) +
    spatial_latent(1 + isdm_gbif | cell_id, d = 1),
  data = datB, trait = "trait", unit = "cell_id", family = famB,
  mesh = mesh, silent = TRUE)))
if (inherits(fitB, "gllvmTMB")) {
  parB <- fitB$tmb_obj$env$last.par.best
  say("B0", "fitB conv=%d; fitted spatial field sd(g_spde)=%.3g",
      fitB$opt$convergence, sd(parB[grepl("g_spde", names(parB))]))

  ## B1: in-sample predict on the spatial fit
  pB1 <- predict(fitB)
  say("B1", "in-sample ran; est==report$eta: %s",
      isTRUE(all.equal(pB1$est, as.numeric(fitB$report$eta))))

  ## B2: newdata = SAME training rows — does the spatial field survive the
  ##     newdata path? (code inspection: only rr_B/diag_B/propto are
  ##     re-added; there is no SPDE re-add and no A_proj projection)
  pB2 <- try_say("B2", suppressMessages(predict(fitB, newdata = datB)))
  if (is.data.frame(pB2)) {
    difB <- pB2$est - pB1$est
    ug <- u[match(as.character(datB$cell_id), cells)]
    say("B2", "newdata-vs-in-sample max|diff|=%.3g sd=%.3g (sd eta=%.3g) -> %s",
        max(abs(difB)), sd(difB), sd(pB1$est),
        if (max(abs(difB)) > 1e-6) "SPATIAL FIELD DROPPED on newdata path"
        else "paths agree")
    say("B2b", "dropped piece IS the field: cor(-diff, u_true)=%.2f",
        suppressWarnings(cor(-difB, ug)))
  }

  ## B4: on a pure-spatial fit, is ANYTHING re-added on the newdata path?
  pB4 <- suppressMessages(predict(fitB, newdata = datB, re_form = ~0))
  if (is.data.frame(pB2)) {
    say("B4", "newdata re_form=~. equals re_form=~0? %s (TRUE = nothing re-added, message misleads)",
        isTRUE(all.equal(pB2$est, pB4$est)))
  }

  ## B3: newdata at NEW coordinates (off-grid, unseen cells) — the actual
  ##     map-making call a user would try
  ndB <- datB[datB$trait == "spA" & datB$source == "gbif", ][1:5, ]
  ndB$cell_id <- factor(paste0("new_", 1:5))
  ndB$lon <- ndB$lon + 0.05; ndB$lat <- ndB$lat + 0.04
  ndB$env <- 0
  pB3 <- try_say("B3", suppressMessages(predict(fitB, newdata = ndB)))
  if (is.data.frame(pB3)) {
    pB3f <- suppressMessages(predict(fitB, newdata = ndB, re_form = ~0))
    say("B3", "new-locations ran; equals fixed-only? %s (i.e. no A_proj kriging)",
        isTRUE(all.equal(pB3$est, pB3f$est)))
  }
}

say("END", "probe complete")
