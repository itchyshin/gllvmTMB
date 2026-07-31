suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
set.seed(109); n_unit <- 150L; uu <- rnorm(n_unit, 0, 1)
d9 <- do.call(rbind, lapply(seq_len(n_unit), function(i) rbind(
  data.frame(unit=i, trait="A", fam="g",  value = 10 + uu[i] + rnorm(2,0,3.0)),
  data.frame(unit=i, trait="A", fam="ln", value = exp(1 + rnorm(2,0,0.2))),
  data.frame(unit=i, trait="B", fam="g",  value = 5 + uu[i] + rnorm(3,0,1.0)))))
d9$unit <- factor(d9$unit); d9$trait <- factor(d9$trait)
d9$fam <- factor(d9$fam, levels = c("g","ln"))
fl9 <- list(g = gaussian(), ln = lognormal()); attr(fl9,"family_var") <- "fam"
w <- character(0)
fit9 <- withCallingHandlers(
  tryCatch(suppressMessages(gllvmTMB(value ~ 0 + trait + indep(0 + trait | unit),
    data = d9, unit="unit", trait="trait", family = fl9)), error=function(e) e),
  warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") })
if (inherits(fit9,"error")) cat("ERROR:", conditionMessage(fit9), "\n") else {
  cat("sigma_eps=", paste(signif(as.numeric(fit9$report$sigma_eps),6), collapse=", "),
      "\nconv=", fit9$opt$convergence, " pdHess=", isTRUE(fit9$sd_report$pdHess), "\n", sep="")
  cat("warnings during fit: ", if (length(w)) paste(w, collapse=" || ") else "NONE", "\n", sep="")
}
