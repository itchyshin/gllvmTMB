# One scheduled case per invocation. No replacement seeds or result overwrites.
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 3L) stop('Usage: Rscript run-case.R CASE_ID OUTPUT_DIR STAGED_LIBRARY')
id <- as.integer(args[[1L]])
if (is.na(id) || id < 1L || id > 36L) stop('CASE_ID must be 1..36')
outdir <- normalizePath(args[[2L]], mustWork=TRUE)
lib <- normalizePath(args[[3L]], mustWork=TRUE)
output <- file.path(outdir,sprintf('case-%02d.rds',id))
if (file.exists(output)) stop('Result exists: refusing overwrite')
for (v in c('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'))
  if (!identical(Sys.getenv(v),'1')) stop(v, ' must be pinned to 1')
source('dev/two-kernel-gaussian/pilot/dgp.R',local=TRUE)
.libPaths(c(lib,.libPaths()))
if (!requireNamespace('gllvmTMB',quietly=TRUE)) stop('Staged gllvmTMB not installed')
package_path <- normalizePath(find.package('gllvmTMB'))
if (!identical(package_path,normalizePath(file.path(lib,'gllvmTMB')))) stop('Staged package path mismatch')
if (!requireNamespace('digest',quietly=TRUE)) stop('digest required for provenance')
schedule <- read.csv('dev/two-kernel-gaussian/pilot/cases.csv',stringsAsFactors=FALSE)
expected <- data.frame(case=seq_len(36L),
  setting=rep(c('baseline','weak','boundary'),each=12L),
  data_seed=2026111500L+seq_len(36L))
if (!identical(schedule,expected)) stop('Schedule differs from frozen 36-case manifest')
setting <- schedule$setting[[id]]
d <- pilot_design(setting)
checks <- pilot_verify_design(d)
K_phy <- d$K$phy; K_tip <- d$K$tip
data_seed <- schedule$data_seed[[id]]
formula <- stats::as.formula("traits(H1, H2, P1, P2) ~ 1 + kernel_latent(species, K = K_phy, d = 1, name = 'phy', unique = TRUE) + kernel_latent(species, K = K_tip, d = 1, name = 'tip', unique = TRUE)",env=environment())
control <- gllvmTMB::gllvmTMBcontrol(n_init=3L,init_jitter=.3,optimizer='nlminb',se=FALSE,optArgs=list(control=list(iter.max=3000L,eval.max=5000L)))
src_inputs <- list.files('src',full.names=TRUE,recursive=TRUE,all.files=TRUE,no..=TRUE)
src_inputs <- src_inputs[!grepl('[.](o|so|dll|dylib|a|d)$',src_inputs)]
source_paths <- sort(c(list.files('R',pattern='[.]R$',full.names=TRUE),src_inputs,
  'DESCRIPTION','NAMESPACE','dev/two-kernel-gaussian/pilot/dgp.R',
  'dev/two-kernel-gaussian/pilot/run-case.R','dev/two-kernel-gaussian/pilot/PROTOCOL.md',
  'dev/two-kernel-gaussian/pilot/run-batch.sh','dev/two-kernel-gaussian/pilot/cases.csv',
  'dev/two-kernel-gaussian/pilot/summarize.R','dev/two-kernel-gaussian/pilot/check-first.R',
  'dev/two-kernel-gaussian/pilot/supervisor.py','dev/two-kernel-gaussian/pilot/test-supervisor.py'))
hash <- function(p) digest::digest(file=p,algo='sha256')
source_hash <- setNames(vapply(source_paths,hash,character(1L)),source_paths)
dll <- getLoadedDLLs()[['gllvmTMB']][['path']]; dll_hash <- hash(dll)
manifest_path <- Sys.getenv('TWO_KERNEL_BUILD_MANIFEST')
if (!nzchar(manifest_path) || !file.exists(manifest_path)) stop('Verified TWO_KERNEL_BUILD_MANIFEST required')
manifest <- readRDS(manifest_path)
if (!identical(source_hash,manifest$source_sha256) || !identical(dll_hash,manifest$dll_sha256))
  stop('Current source or installed DLL does not match verified build manifest')
wide <- pilot_generate(d,data_seed)
stopifnot(identical(unname(!is.na(as.matrix(wide[,d$traits]))),unname(d$mask)))
result <- list(schema='two-kernel-gaussian-pilot-v1',case=id,setting=setting,
  seeds=c(data=data_seed),optimizer_seed_policy='internal fixed jitter offsets; package source authoritative',
  design=d,checks=checks,input=wide,build_manifest_sha256=hash(manifest_path),
  package_path=package_path,package_version=as.character(utils::packageVersion('gllvmTMB')),
  dll_path=dll,dll_sha256=dll_hash,source_sha256=source_hash,session=utils::sessionInfo(),
  head=system2('git',c('rev-parse','HEAD'),stdout=TRUE),
  status='started',warnings=character(),fit_error=NULL,extraction_error=NULL,
  convergence=NA_integer_,objective=NA_real_,elapsed_seconds=NA_real_,extraction=NULL)
start <- proc.time()[['elapsed']]
fit <- tryCatch(withCallingHandlers(gllvmTMB::gllvmTMB(formula=formula,data=wide,
  family=stats::gaussian(),unit='row_id',cluster='species',
  missing=gllvmTMB::miss_control(response='include'),known_sigma_eps=d$sigma,
  control=control,silent=TRUE), warning=function(w) {
    result$warnings <<- c(result$warnings,conditionMessage(w)); invokeRestart('muffleWarning')
  }),error=function(e) {result$fit_error <<- conditionMessage(e); NULL})
result$elapsed_seconds <- unname(proc.time()[['elapsed']]-start)
if (!is.null(fit)) {
  result$status <- 'fit_returned'; result$convergence <- fit$opt$convergence
  result$objective <- fit$opt$objective; result$fit_health <- fit$fit_health
  result$restart_history <- fit$restart_history
  result$selected_parameters <- fit$opt$par
  result$diagnostic_availability <- list(
    transformed_gradient='fit_health and selected parameters retained; exact gradient availability depends on fit',
    raw_directional_derivative='not calculated by this runner',
    boundary='fit_health boundary flags retained when populated')
  result$extraction <- tryCatch({
    shared <- unique <- total <- list()
    for (s in names(d$K)) {
      shared[[s]] <- gllvmTMB::extract_Sigma(fit,level=s,part='shared',link_residual='none')$Sigma
      unique[[s]] <- gllvmTMB::extract_Sigma(fit,level=s,part='unique',link_residual='none')$s
      total[[s]] <- gllvmTMB::extract_Sigma(fit,level=s,part='total',link_residual='none')$Sigma
    }
    n <- d$n
    cross <- function(S) kronecker(S$phy[1:2,3:4,drop=FALSE],d$K$phy[seq_len(n),n+seq_len(n)]) +
      kronecker(S$tip[1:2,3:4,drop=FALSE],d$K$tip[seq_len(n),n+seq_len(n)])
    list(fixed=stats::coef(fit), shared=shared,unique=unique,total=total,
         C_HP=cross(total),C_HP_truth=cross(d$Sigma),
         sigma_eps=fit$report$sigma_eps,fixed_map=fit$tmb_map$log_sigma_eps,
         kernel_has_diag=fit$tmb_data$kernel_has_diag)
  },error=function(e) {result$extraction_error <<- conditionMessage(e);NULL})
  if (!is.null(result$extraction)) result$status <- 'extracted'
}
result$post_source_sha256 <- setNames(vapply(source_paths,hash,character(1L)),source_paths)
result$post_dll_sha256 <- hash(dll)
if (!identical(result$source_sha256,result$post_source_sha256) || !identical(dll_hash,result$post_dll_sha256)) result$status <- 'identity_changed'
tmp <- tempfile(pattern=paste0('.case-',id,'-'),tmpdir=outdir)
saveRDS(result,tmp); if (!file.rename(tmp,output)) stop('Atomic save failed')
cat(sprintf('case=%d setting=%s status=%s convergence=%s elapsed=%.3f\n',id,setting,result$status,result$convergence,result$elapsed_seconds))
if (result$status != 'extracted') quit(status=1L)
