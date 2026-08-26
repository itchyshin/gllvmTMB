script_path <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script_path), "..", ".."))
source(file.path(root, "dev", "pvt02", "pvt02-contract.R"))

theta_lambda <- c(0.7, -0.3, 0.4, 0.2, -0.1)
theta_psi <- c(-0.2, 0.1, 0.3)
spec <- pvt02_target_spec(theta_lambda, theta_psi, 3, 2, 2)
fd <- pvt02_fd_gradient(function(x) {
  pvt02_target_spec(x[1:5], x[6:8], 3, 2, 2)$log_V
}, c(theta_lambda, theta_psi))
stopifnot(max(abs(spec$gradient - fd)) < 1e-6)
crit <- stats::qchisq(0.95, 1)
stopifnot(abs(pvt02_profile_root(function(q) q^2 - crit, 0, 4)$root - sqrt(crit)) < 1e-7)
stopifnot(pvt02_windows_disjoint(pvt02_seed_window(1, 40000), pvt02_seed_window(50001, 5000)))
cat("PVT02_CONTRACT_PASS\n")
