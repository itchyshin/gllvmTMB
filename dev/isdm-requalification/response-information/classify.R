## Pure predeclared classifier; no runner or package code is sourced here.

isdm_respinfo_cell_pass <- function(d, bootstrap_seed, B = ISDM_RESPINFO_BOOTSTRAP_B) {
  if (length(d) != ISDM_RESPINFO_N_SEEDS || any(!is.finite(d))) return(FALSE)
  set.seed(as.integer(bootstrap_seed))
  boot <- replicate(B, stats::median(sample(d, length(d), replace = TRUE)))
  stats::median(d) <= log(.90) && unname(stats::quantile(boot, .95, names = FALSE)) < 0
}

isdm_respinfo_classify <- function(paired, B = ISDM_RESPINFO_BOOTSTRAP_B, seed = ISDM_RESPINFO_BOOTSTRAP_SEED) {
  required <- c("cell_index", "shared_D", "full_D", "psi1_D", "psi2_D", "psi3_D")
  if (!is.data.frame(paired) || !all(required %in% names(paired)) || !identical(sort(unique(paired$cell_index)), 1:8)) stop("paired records do not cover the eight frozen cells", call. = FALSE)
  groups <- split(paired, paired$cell_index)
  targets <- c("shared_D", "full_D", "psi1_D", "psi2_D", "psi3_D")
  n_scoreable <- vapply(groups, function(x) sum(stats::complete.cases(x[targets])), integer(1L))
  if (any(vapply(groups, nrow, integer(1L)) != ISDM_RESPINFO_N_SEEDS) || any(n_scoreable != ISDM_RESPINFO_N_SEEDS)) {
    return(list(classification = "EVIDENCE_INCOMPLETE", cell_pass = NULL, n_scoreable = n_scoreable))
  }
  pass <- sapply(seq_along(groups), function(i) vapply(seq_along(targets), function(j) isdm_respinfo_cell_pass(groups[[i]][[targets[[j]]]], seed + 10000L * i + j, B), logical(1L)))
  rownames(pass) <- targets; colnames(pass) <- names(groups)
  target_count <- rowSums(pass)
  surface <- target_count[["shared_D"]] >= 6L && target_count[["full_D"]] >= 6L
  psi_count <- sum(target_count[c("psi1_D", "psi2_D", "psi3_D")] >= 6L)
  classification <- if (surface && psi_count <= 1L) "SURFACE_ONLY" else if (surface && psi_count == 3L) "JOINT" else "MIXED_OR_NULL"
  list(classification = classification, cell_pass = pass, target_count = target_count, n_scoreable = n_scoreable)
}
