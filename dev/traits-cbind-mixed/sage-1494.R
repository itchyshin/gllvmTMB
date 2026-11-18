## Issue #1494 end-to-end: the reporter's data, fitted in wide and long format,
## for (A) the all-binomial model they asked about and (B) a mixed-family
## variant. Prints SAGE_1494_PASS only if wide == long for both.
## Usage: NOT_CRAN=true Rscript --vanilla dev/traits-cbind-mixed/sage-1494.R
suppressMessages(pkgload::load_all(".", quiet = TRUE))
quiet <- function(e) suppressMessages(suppressWarnings(e))

dat <- data.frame(
  n_infected_500 = c(0,0,0,0,0,0,1,1,1,1,NA,NA,11,11,0,0,12,12,NA,NA,0,0,0,0,4,4,2,NA,NA,NA,0,0,1,1,NA,2,2,7,0,2,2,6,6,17,17,0,0,13,6,6,30,6),
  n_scats_500 = c(1,1,2,2,2,2,8,8,2,2,0,0,16,16,16,16,20,20,0,0,1,1,14,14,11,11,11,0,0,0,1,1,1,1,0,3,3,25,9,3,3,25,25,41,41,1,1,40,18,18,59,12),
  n_disease = c(9,1,3,4,0,0,1,30,14,29,2,2,0,0,2,2,5,10,1,9,16,4,0,1,14,10,19,0,2,4,0,7,0,9,2,4,4,13,3,1,0,2,3,6,76,5,2,0,0,11,0,4),
  no_behav_events = c(10L,2L,9L,24L,1L,12L,4L,34L,25L,39L,2L,13L,4L,11L,3L,3L,18L,16L,10L,49L,25L,7L,8L,17L,23L,37L,30L,3L,9L,10L,6L,18L,11L,33L,5L,6L,32L,40L,6L,13L,7L,7L,14L,20L,153L,31L,59L,1L,26L,34L,7L,9L),
  n_solve = c(0,1,0,1,0,0,0,0,3,11,0,0,0,0,0,0,1,1,0,2,2,0,0,1,0,0,0,0,0,0,2,5,0,1,0,3,1,4,0,0,0,0,0,0,2,1,5,0,1,0,0,0),
  n_light = c(3,1,0,5,0,3,0,20,8,23,1,0,3,5,1,1,7,6,1,4,18,2,5,0,19,23,5,1,2,0,5,1,1,7,2,3,10,23,0,1,0,3,3,3,43,9,15,0,17,14,6,4),
  SiteIDYear = c("NE1_2024","NE1_2025","NE2_2024","NE2_2025","NE3_2024","NE3_2025","NE4_2024","NE4_2025","NE5_2024","NE5_2025","NE6_2024","NE6_2025","NE7_2024","NE7_2025","NW1_2024","NW1_2025","NW2_2024","NW2_2025","NW3_2024","NW3_2025","NW4_2024","NW4_2025","NW5_2024","NW5_2025","NW6_2024","NW6_2025","NW7_2025","SE1_2024","SE2_2024","SE2_2025","SE4_2024","SE4_2025","SE5_2024","SE5_2025","SE6_2024","SE7_2024","SE7_2025","SE8_2025","SE9_2025","SW1_2024","SW1_2025","SW2_2024","SW2_2025","SW3_2024","SW3_2025","SW4_2024","SW4_2025","SW5_2024","SW6_2024","SW6_2025","SW7_2024","SW8_2025")
)
dat$SiteIDYear <- factor(dat$SiteIDYear)
stopifnot(all(dat$n_infected_500 <= dat$n_scats_500, na.rm = TRUE),
          all(dat$n_disease <= dat$no_behav_events),
          all(dat$n_solve <= dat$no_behav_events),
          all(dat$n_light <= dat$no_behav_events))

ctl <- gllvmTMBcontrol(loading_ridge = Inf)
cmp <- function(label, fw, fl) {
  d_obj <- abs(fw$opt$objective - fl$opt$objective)
  Lw <- as.matrix(extract_loadings(fw, level = "unit"))
  Ll <- as.matrix(extract_loadings(fl, level = "unit"))
  Sw <- extract_Sigma(fw, level = "unit")$Sigma
  Sl <- extract_Sigma(fl, level = "unit")$Sigma
  bw <- fw$opt$par[names(fw$opt$par) == "b_fix"]
  bl <- fl$opt$par[names(fl$opt$par) == "b_fix"]
  cat(sprintf("\n== %s ==\n  logLik wide %.6f | long %.6f | |d objective| %.2e\n",
              label, as.numeric(logLik(fw)), as.numeric(logLik(fl)), d_obj))
  cat(sprintf("  convergence wide %d long %d | max|d b_fix| %.2e | max|d Sigma| %.2e | max|d |Lambda|| %.2e\n",
              fw$opt$convergence, fl$opt$convergence, max(abs(bw - bl)),
              max(abs(Sw - Sl)), max(abs(abs(Lw) - abs(Ll)))))
  cat("  n obs wide", nrow(fw$data), "long", nrow(fl$data), "\n")
  print(round(Sw, 3))
  d_obj < 1e-6 && max(abs(Sw - Sl)) < 1e-4 && max(abs(bw - bl)) < 1e-4 &&
    nrow(fw$data) == nrow(fl$data)
}

## ---- (A) the reporter's model: four binomial traits, probit, d = 2 ------
## Their second columns are TRIALS, so failures = trials - successes.
fwA <- quiet(gllvmTMB(
  traits(infected = cbind(n_infected_500, n_scats_500 - n_infected_500),
         disease  = cbind(n_disease, no_behav_events - n_disease),
         solve    = cbind(n_solve,   no_behav_events - n_solve),
         light    = cbind(n_light,   no_behav_events - n_light)) ~ 1 +
    latent(1 | SiteIDYear, d = 2),
  data = dat, family = binomial(link = "probit"), unit = "SiteIDYear",
  control = ctl))
## Long twin built by hand (one row per site x trait, unit-major).
tr <- c("infected", "disease", "solve", "light")
long <- do.call(rbind, lapply(seq_len(nrow(dat)), function(i) data.frame(
  SiteIDYear = dat$SiteIDYear[i], trait = tr,
  succ = c(dat$n_infected_500[i], dat$n_disease[i], dat$n_solve[i], dat$n_light[i]),
  trials = c(dat$n_scats_500[i], rep(dat$no_behav_events[i], 3)))))
long$trait <- factor(long$trait, levels = tr)
long$fail <- long$trials - long$succ
longA <- long[!is.na(long$succ) & long$trials > 0, ]
flA <- quiet(gllvmTMB(
  cbind(succ, fail) ~ 0 + trait + latent(0 + trait | SiteIDYear, d = 2),
  data = longA, trait = "trait", family = binomial(link = "probit"),
  unit = "SiteIDYear", control = ctl))
okA <- cmp("A: four binomial traits (wide vs long)", fwA, flA)

## ---- (B) mixed families: infected/disease binomial, behaviour events as a
## Poisson count, solve as binomial ----------------------------------------
famsB <- list(infected = binomial(link = "probit"), disease = binomial(link = "probit"),
              no_behav_events = poisson(), solve = binomial(link = "probit"))
fwB <- quiet(gllvmTMB(
  traits(infected = cbind(n_infected_500, n_scats_500 - n_infected_500),
         disease  = cbind(n_disease, no_behav_events - n_disease),
         no_behav_events,
         solve    = cbind(n_solve, no_behav_events - n_solve)) ~ 1 +
    latent(1 | SiteIDYear, d = 2),
  data = dat, family = famsB, unit = "SiteIDYear", control = ctl))
trB <- names(famsB)
longB <- do.call(rbind, lapply(seq_len(nrow(dat)), function(i) data.frame(
  SiteIDYear = dat$SiteIDYear[i], trait = trB,
  value = c(dat$n_infected_500[i], dat$n_disease[i], dat$no_behav_events[i], dat$n_solve[i]),
  fail  = c(dat$n_scats_500[i] - dat$n_infected_500[i],
            dat$no_behav_events[i] - dat$n_disease[i], 0,
            dat$no_behav_events[i] - dat$n_solve[i]))))
longB$trait <- factor(longB$trait, levels = trB)
longB <- longB[!is.na(longB$value) & !(longB$trait != "no_behav_events" &
                                       longB$value + longB$fail == 0), ]
famsL <- famsB; attr(famsL, "family_var") <- "trait"
flB <- quiet(gllvmTMB(
  cbind(value, fail) ~ 0 + trait + latent(0 + trait | SiteIDYear, d = 2),
  data = longB, trait = "trait", family = famsL, unit = "SiteIDYear",
  control = ctl))
## Third route: single column + weights = trials.
longB$n <- ifelse(longB$trait == "no_behav_events", 1, longB$value + longB$fail)
fwtB <- quiet(gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | SiteIDYear, d = 2),
  data = longB, trait = "trait", family = famsL, unit = "SiteIDYear",
  control = ctl, weights = longB$n))
okB <- cmp("B: mixed binomial + Poisson (wide vs long cbind)", fwB, flB)
okBw <- cmp("B: long cbind vs long weights route", flB, fwtB)

if (okA && okB && okBw) cat("\nSAGE_1494_PASS\n") else stop("SAGE_1494 FAILED")
