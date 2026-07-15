## Self-contained logic check for pilot_scale_gate_eval() (A1a, 2026-07-13).
## Run: Rscript dev/test-pilot-scale-gate.R
## Pure-function test on synthetic pilot_collect()-shaped tables -- no fits.

source("dev/m3-pilot-report.R")

mkcell <- function(family, signal, coverage_primary, coverage_mcse,
                   fit_failure_rate = 0.05, boot_fail_rate = 0.05,
                   n_converged_fits = 190L, coverage_eligible_n = 188L,
                   evidence_family = family) {
  data.frame(
    family = family, evidence_family = evidence_family, signal = signal,
    coverage_primary = coverage_primary, coverage_mcse = coverage_mcse,
    coverage_eligible_n = as.integer(coverage_eligible_n),
    n_converged_fits = as.integer(n_converged_fits),
    fit_failure_rate = fit_failure_rate, boot_fail_rate = boot_fail_rate,
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

cat("\n", if (ok) "ALL PASS" else "SOME FAILED", "\n")
if (!ok) quit(status = 1L)
