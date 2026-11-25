# Run only after the first timed case and summarize.R; does not fit or draw.
args <- commandArgs(trailingOnly=TRUE)
if (length(args)!=2L) stop('Usage: Rscript check-first.R CASE_01_RDS SUMMARY_PREFIX')
x <- readRDS(args[[1L]])
if (!identical(x$case,1L) || !identical(x$setting,'baseline') ||
    !identical(unname(x$seeds[['data']]),2026111501L)) stop('First-case schedule mismatch')
if (!identical(x$status,'extracted')) stop('First case did not complete extraction')
if (is.null(x$restart_history) || !nrow(x$restart_history)) stop('Restart history missing')
if (!all(paste0('trait',x$design$traits) %in% names(x$extraction$fixed))) stop('Fixed effects lack expected explicit trait names; resolve mapping before campaign')
for (s in names(x$design$K)) {
  if (!identical(names(x$extraction$unique[[s]]),x$design$traits)) stop('Unique variance names mismatch: ',s)
  if (!identical(dim(x$extraction$total[[s]]),c(4L,4L))) stop('Total covariance dimensions mismatch: ',s)
}
m <- read.csv(paste0(args[[2L]],'-metrics.csv'),stringsAsFactors=FALSE)
if (!nrow(m) || !all(c('fixed','phy.unique','tip.unique','phy.shared','tip.shared','phy.total','tip.total','C_HP') %in% m$group)) stop('First-case summary is missing estimands')
cat('FIRST_CASE_REVIEW_PASS\n')
