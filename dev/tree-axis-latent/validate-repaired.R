## Called by validate.R --repaired. Reuse unchanged numerical gates, but never
## inherit a selected historical community fit or any historical pass flag.
original_dir <- Sys.getenv("GLLVM_TREE_AXIS_ORIGINAL")
stopifnot(nzchar(original_dir), fixture_checksum == "6c3bae640dd86491171cb20fbb56b0e4")
ids <- c("N2", "N3", "NW2", "NW3")
paths <- setNames(file.path(result_dir, paste0("fit-", ids, ".rds")), ids)
receipts <- lapply(paths[file.exists(paths)], readRDS)
provenance <- jsonlite::read_json(file.path(result_dir, "provenance.json"), simplifyVector=TRUE)
checks <- lapply(receipts, one_fit)
for (id in names(receipts)) {
  r <- receipts[[id]]
  expected_model <- if (id %in% c("N2", "NW2")) "community_iid" else "community_phylo"
  conditions <- c(checks[[id]]$conditions,
    identity=identical(r$id,id) && identical(r$spec$model,expected_model) &&
      identical(r$spec$size,"target") && identical(r$spec$shape,if(grepl("NW",id)) "wide" else "long"),
    provenance=identical(r$provenance,provenance),
    nlminb=is.null(r$spec$optimizer) || identical(r$spec$optimizer,"nlminb"),
    returned=length(r$optimizer_calls)==if(grepl("NW",id))1L else 3L,
    entries=r$optimizer_entries==if(grepl("NW",id))1L else 3L)
  checks[[id]]$conditions <- conditions
  checks[[id]]$pass <- all(conditions %in% TRUE)
}
stability <- lapply(receipts[intersect(c("N2","N3"),names(receipts))],stability_check)
start_identity <- lapply(names(receipts),function(id) {
  r<-receipts[[id]]
  vapply(seq_along(r$optimizer_calls),function(i) identical(r$optimizer_calls[[i]]$start,
    readRDS(file.path(original_dir,paste0("fit-",r$spec$original,".rds")))$optimizer_calls[[i]]$start),logical(1))
})
names(start_identity)<-names(receipts)
all_pass <- function(xs) length(xs)>0L && all(vapply(xs,function(x)isTRUE(x$pass),logical(1)))
long_pass <- all(c("N2","N3") %in% names(receipts)) &&
  all_pass(checks[c("N2","N3")]) && all_pass(stability) &&
  all(unlist(start_identity[c("N2","N3")]))
wide <- list()
for (i in 2:3) {
  pair<-c(paste0("N",i),paste0("NW",i))
  if(all(pair %in% names(receipts))) wide[[pair[1]]] <- wide_check(receipts[[pair[1]]],receipts[[pair[2]]])
}
## M1/W1 can be carried only with an independently re-evaluated same-source
## continuity receipt covering all three M1 starts and W1, and immutable hashes.
morphology <- list(pass=FALSE, reason="No repaired-source continuity receipt")
continuity_path <- file.path(result_dir,"morphology-continuity.rds")
if(file.exists(continuity_path)) {
  continuity<-readRDS(continuity_path)
  old_paths<-setNames(file.path(original_dir,paste0("fit-",c("M1","W1"),".rds")),c("M1","W1"))
  morph<-lapply(old_paths,readRDS)
  morphology<-list(checks=lapply(morph,one_fit),stability=stability_check(morph$M1),
    wide=wide_check(morph$M1,morph$W1),continuity=continuity)
  morphology$pass<-all_pass(morphology$checks) && isTRUE(morphology$stability$pass) &&
    isTRUE(morphology$wide$pass) && isTRUE(continuity$pass) &&
    identical(continuity$receipt_md5,as.list(tools::md5sum(old_paths))) &&
    identical(continuity$provenance,provenance)
}
repaired_ledger<-list(available_ids=names(receipts),missing_ids=setdiff(ids,names(receipts)),
  checks=checks,stability=stability,start_identity=start_identity,long_pass=long_pass,
  morphology=morphology,wide_equivalence=wide,
  receipt_md5=as.list(tools::md5sum(paths[file.exists(paths)])),
  historical_attempts=14L,new_entries=sum(vapply(receipts,function(r)r$optimizer_entries,integer(1))),
  pass=long_pass && length(receipts)==4L && all(unlist(start_identity)) &&
    all_pass(checks) && all_pass(wide) && isTRUE(morphology$pass),
  note="Frozen single realization and optimizer stability only; historical community failures remain failed.")
## md5sum names are filesystem paths; bind conditional-wide gate to logical IDs.
names(repaired_ledger$receipt_md5)<-names(receipts)
if (!file.exists(file.path(result_dir,"validation-long.rds")) && all(c("N2","N3") %in% names(receipts)))
  saveRDS(repaired_ledger,file.path(result_dir,"validation-long.rds"))
out<-file.path(result_dir,paste0("validation-",paste(names(receipts),collapse="-"),".rds"))
if(file.exists(out)) stop("Refusing to overwrite validation evidence: ",out)
saveRDS(repaired_ledger,out)
print(checks);print(stability);print(wide)
cat("LONG_PASS=",long_pass," MORPHOLOGY_PASS=",isTRUE(morphology$pass),"\n",sep="")
if(isTRUE(repaired_ledger$pass)) cat("TREE_AXIS_VALIDATION_PASS\n") else cat("TREE_AXIS_VALIDATION_INCOMPLETE_OR_FAILED\n")
