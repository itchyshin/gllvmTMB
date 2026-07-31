## Sweep for the defect class found while working #843: a `control$X` that the
## engine READS but that `gllvmTMBcontrol()` never PRODUCES. Such a field is always
## NULL, so the documented switch is unreachable and a caller who sets it gets only
## "Extra arguments to gllvmTMBcontrol() are ignored". `aghq_multistart` is one.
## The comment at R/gllvmTMB.R:1286 records that six AGHQ fields were already fixed
## for exactly this reason -- so the class has bitten this file before.
files <- list.files("R", pattern = "[.]R$", full.names = TRUE)
txt <- unlist(lapply(files, readLines, warn = FALSE))
pat <- "control[$][A-Za-z_.][A-Za-z0-9_.]*"
used <- unique(sub("^control[$]", "", unlist(regmatches(txt, gregexpr(pat, txt)))))

src <- readLines("R/gllvmTMB.R", warn = FALSE)
i0 <- grep("^gllvmTMBcontrol <- function", src)
i1 <- i0 + which(grepl("^\\}", src[i0:length(src)]))[1] - 1
body <- src[i0:i1]
kv <- grep("^\\s*[A-Za-z_.][A-Za-z0-9_.]*\\s*=", body, value = TRUE)
provided <- unique(sub("^\\s*([A-Za-z_.][A-Za-z0-9_.]*)\\s*=.*$", "\\1", kv))

miss <- sort(setdiff(used, provided))
cat("control$ fields READ in R/ but NOT produced by gllvmTMBcontrol():\n")
if (!length(miss)) cat("  (none)\n")
for (m in miss) {
  hits <- grep(paste0("control[$]", m, "\\b"), txt, value = TRUE)
  loc <- character(0)
  for (f in files) {
    ln <- grep(paste0("control[$]", m, "\\b"), readLines(f, warn = FALSE))
    if (length(ln)) loc <- c(loc, sprintf("%s:%s", f, paste(ln, collapse = ",")))
  }
  cat(sprintf("  - %-28s  %s\n", m, paste(loc, collapse = " ")))
}
