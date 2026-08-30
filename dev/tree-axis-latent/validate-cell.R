## Sourced by validate.R --cell; immutable receipts, no optimizer execution.
ids <- c("G1", "G2", "G3", "GW1", "GW2", "GW3")
paths <- setNames(file.path(result_dir, paste0("fit-", ids, ".rds")), ids)
receipts <- lapply(paths[file.exists(paths)], readRDS)
original_dir <- Sys.getenv("GLLVM_TREE_AXIS_ORIGINAL")
stopifnot(nzchar(original_dir), fixture_checksum == "6c3bae640dd86491171cb20fbb56b0e4")
checks <- lapply(receipts, function(r) {
  ans <- one_fit(r)
  ans$conditions <- c(ans$conditions,
    integrated=isTRUE(r$integrated_gaussian_diag_B),
    current_source=identical(r$provenance, jsonlite::read_json(
      file.path(result_dir, "provenance-v2.json"), simplifyVector=TRUE)))
  ans$pass <- all(ans$conditions %in% TRUE)
  ans
})
for (id in names(receipts)) {
  r <- receipts[[id]]
  number <- as.integer(sub("^GW?", "", id))
  is_wide <- startsWith(id, "GW")
  expected_n <- if (is_wide) 1L else 3L
  original <- paste0("M", number)
  expected_model <- c("morphology", "community_iid", "community_phylo")[[number]]
  old <- readRDS(file.path(original_dir,paste0("fit-",original,".rds")))
  start_identity <- length(r$optimizer_calls) == expected_n &&
    all(vapply(seq_along(r$optimizer_calls),function(i)
      identical(r$optimizer_calls[[i]]$start, old$optimizer_calls[[i]]$start),logical(1)))
  extra <- c(identity=identical(r$id,id) && identical(r$spec$model,expected_model) &&
      identical(r$spec$shape,if(is_wide) "wide" else "long") &&
      identical(r$spec$size,"target") && identical(r$spec$original,original),
    nlminb=is.null(r$spec$optimizer) || identical(r$spec$optimizer,"nlminb"),
    returned=length(r$optimizer_calls)==expected_n,
    entries=identical(r$optimizer_entries,expected_n), starts=start_identity)
  checks[[id]]$conditions <- c(checks[[id]]$conditions,extra)
  checks[[id]]$pass <- all(checks[[id]]$conditions %in% TRUE)
}
stability <- lapply(receipts[intersect(c("G1","G2","G3"), names(receipts))], stability_check)
for (id in names(stability)) {
  gate <- list(pass=isTRUE(checks[[id]]$pass) && isTRUE(stability[[id]]$pass),
    receipt_md5=unname(tools::md5sum(paths[[id]])),
    checks=checks[[id]], stability=stability[[id]])
  path <- file.path(result_dir,paste0("gate-",id,".rds"))
  if (file.exists(path)) stopifnot(identical(readRDS(path),gate)) else saveRDS(gate,path)
}
wide <- list()
for (i in 1:3) {
  pair <- c(paste0("G",i),paste0("GW",i))
  if (all(pair %in% names(receipts))) wide[[pair[1]]] <- wide_check(receipts[[pair[1]]],receipts[[pair[2]]])
}
## Negative controls exercise unchanged acceptance rules without fitting.
negative <- TRUE
for (id in names(stability)) {
  r <- receipts[[id]]
  bad <- r; bad$restart_snapshots$attempts[[1]]$convergence <- 1L
  negative <- negative && !stability_check(bad)$pass
  bad <- r; bad$restart_snapshots$attempts[[1]]$max_gradient <- .02
  negative <- negative && !stability_check(bad)$pass
  bad <- r; bad$restart_snapshots$attempts[[2]]$objective <- r$objective+abs(r$objective)*1e-3
  negative <- negative && !stability_check(bad)$pass
  bad <- r; bad$restart_snapshots$attempts[[2]]$covariance$unit$total <-
    2*r$restart_snapshots$attempts[[1]]$covariance$unit$total
  negative <- negative && !stability_check(bad)$pass
}
all_pass <- function(x) length(x)>0L && all(vapply(x,function(z)isTRUE(z$pass),logical(1)))
complete <- all(ids %in% names(receipts)) && length(stability)==3L && length(wide)==3L
new_entries <- sum(vapply(receipts,function(r)r$optimizer_entries,integer(1)))
cell_ledger <- list(ids=names(receipts), checks=checks, stability=stability, wide=wide,
  historical_entries=21L, new_entries=new_entries, ceiling=33L,
  negative_controls=negative, complete=complete,
  pass=complete && new_entries==12L && 21L+new_entries<=33L &&
    all_pass(checks) && all_pass(stability) && all_pass(wide) && negative)
path <- file.path(result_dir,paste0("validation-",paste(names(receipts),collapse="-"),".rds"))
if(file.exists(path)) stopifnot(identical(readRDS(path),cell_ledger)) else saveRDS(cell_ledger,path)
print(lapply(checks,function(x)x[c("pass","objective","gradient")]))
print(stability); print(wide)
if(cell_ledger$pass) cat("TREE_AXIS_VALIDATION_PASS\n") else cat("TREE_AXIS_VALIDATION_INCOMPLETE_OR_FAILED\n")
