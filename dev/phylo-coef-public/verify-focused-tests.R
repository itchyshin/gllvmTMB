source("dev/phylo-coef-public/helpers.R")
run_tests("(column-coef-foundation|column-coef-engine-iid|column-coef-phylo-fixed-rho|column-coef-public-api|column-coef-phylo-estimated-rho)")
cat("focused public coefficient tests verified\n")
