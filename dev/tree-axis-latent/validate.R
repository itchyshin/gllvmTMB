#!/usr/bin/env Rscript
## Post-process retained evidence. No optimizer calls are made by this script.
script_path <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[[1L]]))
source(file.path(dirname(script_path), "fixture.R"))
library(gllvmTMB)
fixture_checksum <- unname(tools::md5sum(file.path(dirname(script_path), "fixture.R")))
result_dir <- Sys.getenv("GLLVM_TREE_AXIS_RESULTS")
if (!nzchar(result_dir)) stop("Set GLLVM_TREE_AXIS_RESULTS")
strict <- !identical(Sys.getenv("GLLVM_TREE_AXIS_REQUIRE_COMPLETE", "true"), "false")
FIT_IDS <- c("C1", "C2", paste0("M", 1:3), paste0("S", 1:6), paste0("W", 1:3), "B2", "B3")
rel_norm <- function(x,y) sqrt(sum((x-y)^2))/max(sqrt(sum(y^2)),1e-8)
matrix_ok <- function(x,p) is.matrix(x) && identical(dim(x),c(p,p)) &&
  all(is.finite(x)) && max(abs(x-t(x))) < 1e-8 &&
  min(eigen(x,symmetric=TRUE,only.values=TRUE)$values) >= -1e-8
sigma_ok <- function(x,p) !is.null(x) && matrix_ok(x$total,p) &&
  matrix_ok(x$shared,p) && length(x$unique)==p && all(is.finite(x$unique)) &&
  all(x$unique>=0) && max(abs(x$total-x$shared-diag(x$unique,nrow=p)))<=1e-10
one_fit <- function(r) {
  if (!is.null(r$alias_of)) return(list(pass=!is.null(r$snapshot), alias=r$alias_of))
  p <- if(r$spec$model=="morphology") 6L else if(r$spec$size=="canary") 20L else 50L
  good_public <- !is.null(r$public) && is.null(r$public$error)
  ## Exact Gaussian marginal sanity bound; this is not an optimizer tolerance.
  ## For this frozen unweighted Gaussian fixture V >= sigma_eps^2 I.
  lower_bound <- if (!is.null(r$fit) && length(r$gaussian$fixed_value)==1L) {
    length(r$fit$tmb_data$y)*(r$gaussian$fixed_value + log(2*pi)/2)
  } else NA_real_
  conditions <- c(
    gaussian_nll_bound=is.finite(lower_bound) && is.finite(r$objective) &&
      r$objective >= lower_bound - 1e-6,
    fit=!is.null(r$fit), finite_objective=is.finite(r$objective),
    convergence=identical(as.integer(r$convergence),0L),
    gradient=is.finite(r$max_gradient) && r$max_gradient<1e-2,
    mapped=isTRUE(r$gaussian$all_na), fixed=isTRUE(r$gaussian$fixed_value_ok),
    fixture=identical(r$fixture_checksum,fixture_checksum), public=good_public)
  if(good_public) {
    conditions <- c(conditions, unit_sigma=sigma_ok(r$public$unit,p),
      fitted=length(r$public$fitted)==p*if(r$spec$model=="morphology") {
        if(r$spec$size=="canary")20L else 80L
      } else if(r$spec$size=="canary")50L else 150L,
      finite_fitted=all(is.finite(r$public$fitted)),
      distinct_keys=!anyDuplicated(r$public$fitted_keys))
    if(r$spec$model=="morphology") {
      conditions <- c(conditions,phy_sigma=sigma_ok(r$public$phy,p))
    } else {
      co <- r$public$column_coef
      conditions <- c(conditions,coef_sigma=matrix_ok(co$Sigma,2L),
        basis=identical(co$basis,c("(Intercept)","latitude")))
      if(r$spec$model=="community_phylo") {
        conditions <- c(conditions,source=identical(co$source$type,"phylo"),
          rho=length(co$rho)==1L && is.finite(co$rho) && co$rho>=0 && co$rho<=1,
          source_matrix=matrix_ok(co$K_rho,p))
      } else conditions <- c(conditions,source=identical(co$source$type,"iid"),
                             no_rho=is.null(co$rho),no_source_matrix=is.null(co$K_rho))
    }
  }
  list(pass=all(conditions %in% TRUE), conditions=conditions,
       objective=r$objective,gradient=r$max_gradient, warnings=r$warnings)
}
blocks <- function(covariance) {
  out <- list()
  for(lev in intersect(c("phy","unit"),names(covariance))) {
    for(part in c("shared","total","unique")) out[[paste(lev,part,sep="_")]] <- covariance[[lev]][[part]]
    out[[paste0(lev,"shared_variance")]] <- diag(covariance[[lev]]$shared)
  }
  if(!is.null(covariance$column_coef)) {
    out$coefficient_sigma <- covariance$column_coef$Sigma
    if(!is.null(covariance$column_coef$K_rho)) out$coefficient_source <- covariance$column_coef$K_rho
  }
  out
}
stability_check <- function(r) {
  s <- r$restart_snapshots
  if(is.null(s) || !is.null(s$error) || length(s$attempts)!=3L)
    return(list(pass=FALSE,error="Three reconstructed optimizer attempts required"))
  a <- s$attempts
  obj <- vapply(a,function(x)x$objective,numeric(1))
  grad <- vapply(a,function(x)x$max_gradient,numeric(1))
  ref <- blocks(a[[1L]]$covariance)
  differences <- lapply(a,function(x) {
    b <- blocks(x$covariance)
    if(!identical(names(b),names(ref))) stop("Snapshot component mismatch")
    vapply(names(ref),function(n)rel_norm(b[[n]],ref[[n]]),numeric(1))
  })
  objective_spread <- diff(range(obj))/max(1,abs(min(obj)))
  conditions <- c(reconstructed=isTRUE(s$selected_reconstruction_ok),
    distinct_starts=isTRUE(s$starts_distinct),calls=s$optimizer_calls==3L,
    entries=s$optimizer_entries==3L,no_warm_restart=!isTRUE(s$warm_restart_attempted),
    finite=all(is.finite(obj)) && all(is.finite(grad)),gradients=all(grad<1e-2),
    convergence=all(vapply(a,function(x)identical(as.integer(x$convergence),0L),logical(1))),
    objectives=objective_spread<=1e-6,
    covariance=all(is.finite(unlist(differences))) && all(unlist(differences)<=.10))
  list(pass=all(conditions %in% TRUE),conditions=conditions,objectives=obj,
       gradients=grad,objective_relative_spread=objective_spread,relative_norms=differences)
}
wide_check <- function(l,w) {
  if(is.null(l$public) || is.null(w$public) || !is.null(l$public$error) || !is.null(w$public$error))
    return(list(pass=FALSE,error="Missing public fitted outputs"))
  a<-l$public; b<-w$public
  if(anyDuplicated(a$fitted_keys) || anyDuplicated(b$fitted_keys) ||
     !setequal(a$fitted_keys,b$fitted_keys)) return(list(pass=FALSE,error="Fitted row keys differ"))
  objective <- abs(l$objective-w$objective)/max(1,abs(l$objective))
  sd_y <- sd(l$fit$tmb_data$y)
  ## The stored fixed log scale also records sd(y), but use original response.
  if(!is.finite(sd_y) || sd_y<=0) stop("Missing response scale")
  fitted <- max(abs(a$fitted-b$fitted[match(a$fitted_keys,b$fitted_keys)]))/sd_y
  list(pass=is.finite(objective) && is.finite(fitted) && objective<=1e-6 && fitted<=1e-4,
       objective_relative_difference=objective,fitted_response_sd_difference=fitted)
}
.tree_axis_repair_public <- function(fit, model) {
  fitted_out <- stats::fitted(fit)
  if (!is.data.frame(fitted_out) || !"est" %in% names(fitted_out) || ncol(fitted_out) < 3L) {
    stop("fitted() did not return the documented training-row data frame.")
  }
  sigma <- function(level) list(
    shared = suppressMessages(extract_Sigma(fit, level = level, part = "shared", link_residual = "none")$Sigma),
    unique = suppressMessages(extract_Sigma(fit, level = level, part = "unique", link_residual = "none")$s),
    total = suppressMessages(extract_Sigma(fit, level = level, part = "total", link_residual = "none")$Sigma)
  )
  out <- list(
    fitted = as.numeric(fitted_out$est),
    fitted_keys = paste(fitted_out[[1L]], fitted_out[[3L]], sep = "::")
  )
  if (identical(model, "morphology")) {
    out$phy <- sigma("phy")
    out$unit <- sigma("unit")
  } else {
    out$unit <- sigma("unit")
    out$column_coef <- suppressMessages(extract_Sigma(fit, level = "column_coef"))
  }
  out
}

argv <- commandArgs(trailingOnly = TRUE)
if (length(argv) && identical(argv[[1L]], "--repaired")) {
  source(file.path(dirname(script_path), "validate-repaired.R"))
  quit(status = if (isTRUE(repaired_ledger$pass)) 0L else 1L)
}
if (length(argv) && identical(argv[[1L]], "--repair-public")) {
  repair_ids <- if (length(argv) > 1L) argv[-1L] else c("C1", "C2")
  if (!all(repair_ids %in% c("C1", "C2"))) stop("Only C1/C2 can receive a no-fit public extraction repair.")
  repair_dir <- file.path(result_dir, "derived-extraction-repair")
  dir.create(repair_dir, recursive = TRUE, showWarnings = FALSE)
  for (id in repair_ids) {
    source_path <- file.path(result_dir, paste0("fit-", id, ".rds"))
    out_path <- file.path(repair_dir, paste0("fit-", id, "-public-repair.rds"))
    if (!file.exists(source_path)) stop("Missing immutable receipt: ", source_path)
    if (file.exists(out_path)) stop("Refusing to overwrite repair receipt: ", out_path)
    receipt <- readRDS(source_path)
    if (is.null(receipt$fit)) stop("Receipt has no fit object: ", source_path)
    saveRDS(list(
      schema = "tree-axis-latent-derived-public-repair-v1", id = id,
      source_path = normalizePath(source_path), source_md5 = unname(tools::md5sum(source_path)),
      fixture_checksum = receipt$fixture_checksum,
      original_error = if (is.null(receipt$public)) NULL else receipt$public$error,
      public = .tree_axis_repair_public(receipt$fit, receipt$spec$model),
      note = "Derived public outputs only; no optimization or simulation was run."
    ), out_path)
    message("Wrote ", out_path)
  }
  quit(status = 0L)
}

paths <- setNames(file.path(result_dir,paste0("fit-",FIT_IDS,".rds")),FIT_IDS)
receipts <- lapply(paths[file.exists(paths)],readRDS)
## Initial post-processing errors are repaired in separately bound artifacts.
for(id in intersect(c("C1","C2"),names(receipts))) {
  path <- file.path(result_dir,"derived-extraction-repair",paste0("fit-",id,"-public-repair.rds"))
  if(file.exists(path)) {
    derived <- readRDS(path)
    stopifnot(identical(derived$source_md5,unname(tools::md5sum(paths[[id]]))),
              identical(derived$fixture_checksum,receipts[[id]]$fixture_checksum))
    receipts[[id]]$public <- derived$public
  }
}
checks <- lapply(receipts,one_fit)
if(length(argv) && argv[[1L]]=="--self-test") {
  stopifnot("C1" %in% names(receipts),isTRUE(one_fit(receipts$C1)$pass))
  bad<-receipts$C1; bad$max_gradient<-.02; stopifnot(!one_fit(bad)$pass)
  bad<-receipts$C1; bad$public$unit$unique[1]<-bad$public$unit$unique[1]+.5
  stopifnot(!one_fit(bad)$pass)
  bad<-receipts$C1; bad$fixture_checksum<-"wrong"; stopifnot(!one_fit(bad)$pass)
  bad<-receipts$C1; bad$objective<--5.34842345053399e29
  stopifnot(!one_fit(bad)$pass)
  cat("TREE_AXIS_NEGATIVE_CONTROLS_PASS: gradient, decomposition, fixture and impossible Gaussian objective rejected\n")
  quit(status=0L)
}
## The approved BFGS adjudication adds new receipts. Original failed nlminb
## attempts remain explicit historical evidence, never overwritten or relabelled.
primary_ids <- c("M1", "B2", "B3")
stability <- lapply(receipts[intersect(primary_ids,names(receipts))],stability_check)
historical_stability <- lapply(receipts[intersect(c("M2","M3"),names(receipts))],stability_check)
cross_solver <- lapply(intersect(c("B2","B3"),names(receipts)),function(id) {
  old <- receipts[[sub("B","M",id)]]; new <- receipts[[id]]
  if(is.null(old) || is.null(new$restart_snapshots$attempts)) return(NULL)
  a <- blocks(old$restart_snapshots$attempts[[old$restart_snapshots$selected]]$covariance)
  b <- blocks(new$restart_snapshots$attempts[[new$restart_snapshots$selected]]$covariance)
  list(original_id=old$id,additional_id=id,
       objective_difference=new$objective-old$objective,
       covariance_relative_norms=vapply(names(a),function(n)rel_norm(b[[n]],a[[n]]),numeric(1)))
})
wide <- list()
for(i in 1:3) {
  ids<-c(primary_ids[i],paste0("W",i))
  if(all(ids %in% names(receipts))) wide[[ids[1L]]] <- wide_check(receipts[[ids[1L]]],receipts[[ids[2L]]])
}
for(id in intersect(paste0("S",1:6),names(receipts))) {
  r<-receipts[[id]]; parent<-receipts[[r$alias_of]]
  checks[[id]]$pass <- checks[[id]]$pass && !is.null(parent) &&
    identical(r$parent_md5,unname(tools::md5sum(paths[[r$alias_of]]))) &&
    identical(r$fixture_checksum,parent$fixture_checksum)
}
missing <- setdiff(FIT_IDS,names(receipts))
pass <- function(xs) length(xs)>0L && all(vapply(xs,function(x)isTRUE(x$pass),logical(1)))
complete <- !length(missing) && length(stability)==3L && length(wide)==3L
available_pass <- pass(checks) && (!length(stability) || pass(stability)) && (!length(wide) || pass(wide))
ledger<-list(available_ids=names(receipts),missing_ids=missing,fixture_checksum=fixture_checksum,
             checks=checks,primary_ids=primary_ids,stability=stability,
             historical_stability=historical_stability,cross_solver=cross_solver,
             wide_equivalence=wide,
             complete=complete,pass=complete && available_pass,
             note="One synthetic realization and optimizer stability, not recovery/calibration evidence")
saveRDS(ledger,file.path(result_dir,"validation.rds"))
print(lapply(checks,function(x)x[c("pass","objective","gradient")]))
print(stability)
print(historical_stability)
print(cross_solver)
print(wide)
if(complete && available_pass) cat("TREE_AXIS_VALIDATION_PASS\n") else {
  cat("TREE_AXIS_VALIDATION_INCOMPLETE_OR_FAILED; missing:",paste(missing,collapse=","),"\n")
  if(strict || !available_pass) quit(status=1L)
}
