suppressMessages(library(gllvm))
ns <- asNamespace("gllvm")
f <- get("gllvm.TMB", envir = ns)
txt <- deparse(f)
## find lines mentioning link handling for binomial / EVA
idx <- grep("probit|logit|method == .EVA.|method==.EVA.|link", txt, ignore.case = TRUE)
cat(length(txt), "lines total;", length(idx), "matches\n")
for (i in idx) cat(sprintf("%5d: %s\n", i, txt[i]))
