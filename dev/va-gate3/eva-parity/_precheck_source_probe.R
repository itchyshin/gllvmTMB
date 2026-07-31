suppressMessages(library(gllvm))
ns <- asNamespace("gllvm")
nms <- ls(ns, all.names = TRUE)
## look for internal functions that build TMB data and might reference link/probit
hits <- nms[grepl("TMB|data\\.list|link", nms, ignore.case = TRUE)]
print(hits)
