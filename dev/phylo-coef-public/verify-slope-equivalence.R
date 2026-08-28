source("dev/phylo-coef-public/helpers.R")
run_tests("(column-coef-engine-iid|column-coef-phylo-fixed-rho|column-coef-phylo-estimated-rho)")
cat("released slope equivalence verified\n")
