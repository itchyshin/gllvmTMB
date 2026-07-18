## Self-contained logic check for pilot_scale_gate_eval() (A1a, 2026-07-13).
## Run: Rscript dev/test-pilot-scale-gate.R
## Pure-function test on synthetic pilot_collect()-shaped tables -- no fits.

source("dev/m3-pilot-report.R")

## coverage_certificate defaults to NA: these legacy-shaped cells exercise the
## coverage_primary (bootstrap) path, and the gate's cov_measure falls back to
## coverage_primary when the certificate is absent (FIX 2, 2026-07-18).
mkcell <- function(family, signal, coverage_primary, coverage_mcse,
                   fit_failure_rate = 0.05, boot_fail_rate = 0.05,
                   n_converged_fits = 190L, n_traits = 5L,
                   coverage_eligible_n = 940L,
                   miss_total = NA_integer_, one_sided_miss_share = NA_real_,
                   evidence_family = family,
                   coverage_certificate = NA_real_) {
  data.frame(
    family = family, evidence_family = evidence_family, signal = signal,
    coverage_primary = coverage_primary,
    coverage_certificate = coverage_certificate, coverage_mcse = coverage_mcse,
    coverage_eligible_n = as.integer(coverage_eligible_n),
    n_converged_fits = as.integer(n_converged_fits),
    n_traits = as.integer(n_traits),
    fit_failure_rate = fit_failure_rate, boot_fail_rate = boot_fail_rate,
    miss_total = as.integer(miss_total),
    one_sided_miss_share = one_sided_miss_share,
    stringsAsFactors = FALSE
  )
}

ok <- TRUE
chk <- function(cond, msg) {
  cat(if (isTRUE(cond)) "PASS" else "FAIL", "-", msg, "\n")
  if (!isTRUE(cond)) ok <<- FALSE
}

## 1. Clean CORE frame at pilot noise -> PASS_TO_SCALE (with smoke-MCSE note).
clean <- rbind(
  mkcell("gaussian", 0.2, 0.95, 0.015),
  mkcell("nbinom2", 0.5, 0.94, 0.016),
  mkcell("binomial_probit", 0.2, 0.95, 0.015)
)
r1 <- pilot_scale_gate_eval(clean)
chk(r1$verdict == "PASS_TO_SCALE", "clean core -> PASS_TO_SCALE")
chk(any(grepl("smoke-grade", r1$reasons)), "clean core notes smoke-grade MCSE")

## 2. A logit-harness binomial cell -> HOLD (Repair #1).
logit <- rbind(
  mkcell("gaussian", 0.2, 0.95, 0.015),
  mkcell("binomial_probit", 0.2, 0.95, 0.015,
         evidence_family = "binomial_logit_harness")
)
r2 <- pilot_scale_gate_eval(logit)
chk(r2$verdict == "HOLD", "logit-harness binomial -> HOLD")
chk(any(grepl("Repair #1", r2$reasons)), "logit-harness cites Repair #1")

## 3. A high fit-failure cell -> HOLD (health gate).
badfit <- rbind(
  mkcell("gaussian", 0.2, 0.95, 0.015),
  mkcell("nbinom2", 0.5, 0.94, 0.016, fit_failure_rate = 0.35)
)
r3 <- pilot_scale_gate_eval(badfit)
chk(r3$verdict == "HOLD", "fit_failure_rate 0.35 -> HOLD")
chk(any(grepl("health gate", r3$reasons)), "bad fit cites health gate")

## 4. Ordinal + signal==0 cells are excluded, don't affect a clean core.
mixed_in <- rbind(
  clean,
  mkcell("ordinal_probit", 0.2, 0.10, 0.02),   # excluded (not core)
  mkcell("gaussian", 0.0, 0.30, 0.02)          # excluded (signal == 0)
)
r4 <- pilot_scale_gate_eval(mixed_in)
chk(r4$verdict == "PASS_TO_SCALE", "ordinal + signal=0 excluded, core still PASS")
chk(nrow(r4$cells) == 3L, "only 3 core coverage cells enter the gate")

## 5. Catastrophically low coverage -> HOLD.
lowcov <- rbind(
  mkcell("gaussian", 0.2, 0.60, 0.015),
  mkcell("nbinom2", 0.5, 0.94, 0.016)
)
r5 <- pilot_scale_gate_eval(lowcov)
chk(r5$verdict == "HOLD", "coverage 0.60 -> HOLD (below provisional floor)")

## 6. Regression (Repair #5): coverage_eligible_n counts (draw x trait) checks,
## so the CI-missing denominator is n_converged_fits * n_traits. Under the old
## denominator (n_converged_fits alone) eligible_n > n_converged made the rate
## negative; confirm it is now a sane fraction in [0, 1] on the correct denom.
reg <- rbind(
  mkcell("gaussian", 0.2, 0.95, 0.015,
         n_converged_fits = 190L, n_traits = 5L, coverage_eligible_n = 900L),
  mkcell("nbinom2", 0.5, 0.94, 0.016,
         n_converged_fits = 190L, n_traits = 5L, coverage_eligible_n = 950L)
)
r6 <- pilot_scale_gate_eval(reg)
cm <- r6$cells$ci_missing_rate
chk(all(cm >= 0 & cm <= 1), "ci_missing_rate in [0, 1] (no longer negative)")
chk(isTRUE(all.equal(cm[r6$cells$family == "gaussian"], 1 - 900 / (190 * 5))),
    "ci_missing_rate uses n_converged_fits * n_traits denominator")

## 7. A one-sided miss pattern in a CORE cell -> HOLD (Design 66 sec.6 gate 5).
onesided <- rbind(
  mkcell("gaussian", 0.2, 0.95, 0.015),
  mkcell("nbinom2", 0.5, 0.94, 0.016,
         miss_total = 12L, one_sided_miss_share = 0.92),
  mkcell("binomial_probit", 0.2, 0.95, 0.015)
)
r7 <- pilot_scale_gate_eval(onesided)
chk(r7$verdict == "HOLD", "one-sided miss pattern -> HOLD")
chk(any(grepl("one-sided miss", r7$reasons)), "one-sided miss cites gate 5")

## 8. A lopsided but tiny miss count is noise, not a pattern -> still PASS.
fewmiss <- rbind(
  mkcell("gaussian", 0.2, 0.95, 0.015,
         miss_total = 3L, one_sided_miss_share = 1.0),
  mkcell("nbinom2", 0.5, 0.94, 0.016),
  mkcell("binomial_probit", 0.2, 0.95, 0.015)
)
r8 <- pilot_scale_gate_eval(fewmiss)
chk(r8$verdict == "PASS_TO_SCALE",
    "lopsided but <5 misses -> PASS (below the pattern floor)")

## 9. FIX 2 -- the gate must enforce coverage on the DEFAULT (profile) route,
## where coverage lands in coverage_certificate and coverage_primary is NA.
## A CORE cell with catastrophic profile coverage 0.70 must HOLD with a
## coverage reason (previously PASSED because the gate was coverage-blind).
cert_low <- rbind(
  mkcell("gaussian", 0.2, NA_real_, NA_real_, coverage_certificate = 0.70),
  mkcell("nbinom2", 0.5, NA_real_, NA_real_, coverage_certificate = 0.95),
  mkcell("binomial_probit", 0.2, NA_real_, NA_real_, coverage_certificate = 0.95)
)
r9 <- pilot_scale_gate_eval(cert_low)
chk(r9$verdict == "HOLD",
    "FIX 2: catastrophic profile coverage (cert 0.70) -> HOLD")
chk(any(grepl("provisional coverage floor", r9$reasons)),
    "FIX 2: cert 0.70 emits a coverage-floor reason")

## 10. FIX 2 -- a healthy profile route (all certs 0.96, primary NA) passes the
## coverage arm (verdict PASS_TO_SCALE, no coverage-floor reason).
cert_ok <- rbind(
  mkcell("gaussian", 0.2, NA_real_, NA_real_, coverage_certificate = 0.96),
  mkcell("nbinom2", 0.5, NA_real_, NA_real_, coverage_certificate = 0.96),
  mkcell("binomial_probit", 0.2, NA_real_, NA_real_, coverage_certificate = 0.96)
)
r10 <- pilot_scale_gate_eval(cert_ok)
chk(r10$verdict == "PASS_TO_SCALE",
    "FIX 2: healthy profile coverage (cert 0.96) passes the coverage arm")
chk(!any(grepl("provisional coverage floor", r10$reasons)),
    "FIX 2: cert 0.96 emits no coverage-floor reason")

## 11. FIX 2 regression -- coverage_primary is still enforced when it is the
## only measurement present (cert NA): a bootstrap-route cell at 0.60 HOLDs.
prim_only_low <- rbind(
  mkcell("gaussian", 0.2, 0.60, 0.015),
  mkcell("nbinom2", 0.5, 0.94, 0.016),
  mkcell("binomial_probit", 0.2, 0.95, 0.015)
)
r11 <- pilot_scale_gate_eval(prim_only_low)
chk(r11$verdict == "HOLD",
    "FIX 2: coverage_primary path still enforced when cert is NA (0.60 -> HOLD)")

cat("\n", if (ok) "ALL PASS" else "SOME FAILED", "\n")
if (!ok) quit(status = 1L)
