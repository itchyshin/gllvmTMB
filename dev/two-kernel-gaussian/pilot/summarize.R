# Failure-aware exploratory summary: one row per scheduled case plus metrics.
`%||%` <- function(x, y) if (is.null(x)) y else x
args <- commandArgs(trailingOnly=TRUE)
if (length(args)!=2L) stop('Usage: Rscript summarize.R OUTPUT_DIR NEW_SUMMARY_PREFIX')
outdir <- normalizePath(args[[1]],mustWork=TRUE); prefix <- args[[2]]
paths <- paste0(prefix,c('-cases.csv','-metrics.csv','-estimates.csv'))
if (any(file.exists(paths))) stop('Summary output exists; refusing overwrite')
cases <- read.csv('dev/two-kernel-gaussian/pilot/cases.csv',stringsAsFactors=FALSE)
rows <- vector('list',nrow(cases)); estimates <- list()
add <- function(id,setting,group,name,estimate,truth,converged) {
  data.frame(case=id,setting=setting,group=group,name=name,
    estimate=as.numeric(estimate),truth=as.numeric(truth),converged=converged)
}
for (i in seq_len(nrow(cases))) {
  id <- cases$case[i]; setting <- cases$setting[i]
  rds <- file.path(outdir,sprintf('case-%02d.rds',id))
  exitpath <- file.path(outdir,sprintf('case-%d.exit',id))
  status <- if (file.exists(exitpath)) trimws(readLines(exitpath,warn=FALSE)[1L]) else NA_character_
  x <- if (file.exists(rds)) tryCatch(readRDS(rds),error=function(e) NULL) else NULL
  converged <- !is.null(x) && identical(as.integer(x$convergence),0L)
  extracted <- !is.null(x) && identical(x$status,'extracted') && !is.null(x$extraction)
  fixed_mapping <- extracted && all(paste0('trait',x$design$traits) %in% names(x$extraction$fixed))
  unique_mapping <- extracted && all(vapply(names(x$design$K),function(s) {
    identical(names(x$extraction$unique[[s]]),x$design$traits)
  },logical(1L)))
  rows[[i]] <- data.frame(case=id,setting=setting,process_exit=status,
    result_status=if(is.null(x)) 'missing_or_unreadable' else x$status,
    convergence=if(is.null(x)) NA_integer_ else x$convergence,
    extracted=extracted,fixed_mapping_available=fixed_mapping,
    unique_mapping_available=unique_mapping,elapsed=if(is.null(x)) NA_real_ else x$elapsed_seconds,
    warning_count=if(is.null(x)) NA_integer_ else length(x$warnings),
    fit_error=if(is.null(x)) NA_character_ else x$fit_error %||% NA_character_,
    extraction_error=if(is.null(x)) NA_character_ else x$extraction_error %||% NA_character_)
  if (!extracted) next
  d <- x$design; e <- x$extraction
  for (s in names(d$K)) {
    for (kind in c('shared','total')) {
      truth <- if(kind=='shared') tcrossprod(d$lambda[[s]]) else d$Sigma[[s]]
      est <- e[[kind]][[s]]
      if (!identical(dim(est),dim(truth))) next
      for (a in seq_along(d$traits)) for (b in seq_along(d$traits))
        estimates[[length(estimates)+1L]] <- add(id,setting,paste(s,kind,sep='.'),
          paste(d$traits[a],d$traits[b],sep=':'),est[a,b],truth[a,b],converged)
    }
    u <- e$unique[[s]]
    if (length(u)==length(d$traits) && identical(names(u),d$traits))
      for (a in seq_along(d$traits)) estimates[[length(estimates)+1L]] <-
        add(id,setting,paste(s,'unique',sep='.'),d$traits[a],u[a],d$psi[[s]][a],converged)
  }
  # Only use an unambiguous exact trait-name mapping for fixed intercepts.
  b <- e$fixed
  fixed_names <- paste0('trait',d$traits)
  if (all(fixed_names %in% names(b))) for (a in seq_along(d$traits))
    estimates[[length(estimates)+1L]] <- add(id,setting,'fixed',d$traits[a],
      b[[fixed_names[a]]],d$beta[[a]],converged)
  if (identical(dim(e$C_HP),dim(e$C_HP_truth))) {
    err <- sqrt(sum((e$C_HP-e$C_HP_truth)^2))
    estimates[[length(estimates)+1L]] <- add(id,setting,'C_HP','absolute_frobenius_error',err,0,converged)
    denom <- sqrt(sum(e$C_HP_truth^2))
    if (is.finite(denom) && denom>0)
      estimates[[length(estimates)+1L]] <- add(id,setting,'C_HP','relative_frobenius_error',err/denom,0,converged)
  }
}
case_table <- do.call(rbind,rows)
empty <- data.frame(case=integer(),setting=character(),group=character(),name=character(),estimate=numeric(),truth=numeric(),converged=logical())
all_est <- if(length(estimates)) do.call(rbind,estimates) else empty
metric_rows <- list()
if(nrow(all_est)) {
  # Both all extracted and converged-only summaries are explicit; neither hides denominators.
  for (subset_name in c('all_extracted','converged_only')) {
    sub <- if(subset_name=='converged_only') all_est[all_est$converged,,drop=FALSE] else all_est
    if(!nrow(sub)) next
    groups <- split(sub,interaction(sub$setting,sub$group,sub$name,drop=TRUE))
    for (g in groups) {
      err <- g$estimate-g$truth; err <- err[is.finite(err)]
      metric_rows[[length(metric_rows)+1L]] <- data.frame(setting=g$setting[1],group=g$group[1],name=g$name[1],subset=subset_name,
        scheduled=sum(cases$setting==g$setting[1]),denominator=length(err),bias=if(length(err)) mean(err) else NA_real_,
        bias_mcse=if(length(err)>1L) stats::sd(err)/sqrt(length(err)) else NA_real_,
        rmse=if(length(err)) sqrt(mean(err^2)) else NA_real_)
    }
  }
}
metrics <- if(length(metric_rows)) do.call(rbind,metric_rows) else data.frame(setting=character(),group=character(),name=character(),subset=character(),scheduled=integer(),denominator=integer(),bias=numeric(),bias_mcse=numeric(),rmse=numeric())
write.csv(case_table,paths[1],row.names=FALSE,na='')
write.csv(metrics,paths[2],row.names=FALSE,na='')
write.csv(all_est,paths[3],row.names=FALSE,na='')
cat('Scheduled:',nrow(cases),'extracted:',sum(case_table$extracted),
    'converged:',sum(case_table$convergence==0L,na.rm=TRUE),'\n')
