# Run with a source-pinned package already loaded or installed. No optimizer fit.
source('dev/two-kernel-gaussian/oracle.R')
stopifnot(requireNamespace('gllvmTMB', quietly = TRUE),
          requireNamespace('TMB', quietly = TRUE))
ns <- asNamespace('gllvmTMB')
get_export <- function(n) getExportedValue('gllvmTMB', n)
nside <- 8L
sp <- c(paste0('H', 1:nside), paste0('P', 1:nside))
A <- .6^abs(outer(1:nside, 1:nside, '-')); I <- diag(nside)
K_phy <- rbind(cbind(A, .55*A), cbind(.55*A, A))
K_tip <- rbind(cbind(I, .55*I), cbind(.55*I, I))
dimnames(K_phy) <- dimnames(K_tip) <- list(sp, sp)
dat <- data.frame(species = factor(sp, levels = sp), row_id = factor(sp, levels = sp),
  H1 = c(sin(1:nside), rep(NA_real_, nside)),
  H2 = c(cos(1:nside), rep(NA_real_, nside)),
  P1 = c(rep(NA_real_, nside), sin((1:nside)+.3)),
  P2 = c(rep(NA_real_, nside), cos(1:nside)))
form <- stats::as.formula("traits(H1,H2,P1,P2) ~ 1 + kernel_latent(species,K=K_phy,d=1,name='phy',unique=TRUE) + kernel_latent(species,K=K_tip,d=1,name='tip',unique=TRUE)", env = environment())
capture <- NULL
trace('MakeADFun', where = asNamespace('TMB'), print = FALSE,
      tracer = quote({ assign('.two_kernel_capture', list(data=data, parameters=parameters,
        map=map, random=random, DLL=DLL), envir=.GlobalEnv); stop('CAPTURE_TWO_KERNEL') }))
error <- tryCatch({ get_export('gllvmTMB')(form, dat, family=gaussian(),
  unit='row_id', cluster='species', missing=get_export('miss_control')(response='include'),
  control=get_export('gllvmTMBcontrol')(se=FALSE), silent=TRUE,
  known_sigma_eps=.12); NULL }, error=function(e) conditionMessage(e))
untrace('MakeADFun', where=asNamespace('TMB'))
if (!identical(error, 'CAPTURE_TWO_KERNEL') || !exists('.two_kernel_capture', .GlobalEnv)) stop(error)
z <- get('.two_kernel_capture', .GlobalEnv); rm('.two_kernel_capture', envir=.GlobalEnv)
stopifnot(identical(as.integer(z$data$kernel_has_diag), c(1L,1L)),
          all(is.na(z$map$log_sigma_eps)), abs(z$parameters$log_sigma_eps-log(.12))<1e-14)
obj <- TMB::MakeADFun(data=z$data, parameters=z$parameters, map=z$map,
                      random=z$random, DLL=z$DLL, silent=TRUE)
idx <- which(z$data$is_y_observed == 1L)
si <- z$data$kernel_group_id[idx]+1L; ti <- z$data$trait_id[idx]+1L
X <- diag(4)[ti,,drop=FALSE]; Y <- as.matrix(dat[,c('H1','H2','P1','P2')])
expected_y <- Y[cbind(si,ti)]
stopifnot(length(idx)==32L, sum(z$data$is_y_observed==0L)==32L,
          all(!is.na(expected_y)), max(abs(z$data$y[idx]-expected_y)) < 1e-12,
          identical(unname(z$data$X_fix[idx,,drop=FALSE]), unname(X)))
par_names <- names(obj$par)
stopifnot(identical(sort(unique(par_names)), sort(c('b_fix','theta_rr_kernel','log_sd_kernel_diag'))),
          sum(par_names=='b_fix')==4L, sum(par_names=='theta_rr_kernel')==8L,
          sum(par_names=='log_sd_kernel_diag')==8L)
baseline <- obj$par
for (point in seq_len(5L)) {
  p <- baseline
  beta <- c(.2,-.3,.5,-.1) + point*.01
  l <- c(.35,-.2,.5,.1,-.25,.45,.15,-.4) * (1 + point*.05)
  if (point == 3L) l[1:4] <- -l[1:4]
  a <- log(c(.3,.4,.25,.35,.2,.32,.38,.22)) + point*.02
  p[par_names=='b_fix'] <- beta; p[par_names=='theta_rr_kernel'] <- l
  p[par_names=='log_sd_kernel_diag'] <- a
  ref <- two_kernel_oracle(expected_y,X,si,ti,list(K_phy,K_tip),
                           list(matrix(l[1:4]),matrix(l[5:8])),
                           list(a[1:4],a[5:8]),beta,.12)
  g <- two_kernel_gradient_vector(ref$gradient)
  # Names in the native objective repeat; construct unique, ordered identities.
  expected_order <- c(rep('b_fix',4),rep('theta_rr_kernel',8),rep('log_sd_kernel_diag',8))
  native <- obj$gr(p); names(native) <- par_names
  stopifnot(identical(par_names,expected_order))
  names(native) <- names(g) <- paste0(expected_order,':',ave(seq_along(expected_order),expected_order,FUN=seq_along))
  cmp <- two_kernel_compare_native(ref, obj$fn(p), native, g)
  dense_value <- function(v) two_kernel_oracle(expected_y,X,si,ti,list(K_phy,K_tip),
    list(matrix(v[5:8]),matrix(v[9:12])), list(v[13:16],v[17:20]),v[1:4],.12)$nll
  v <- c(beta,l,a)
  fd <- vapply(seq_along(v), function(i) {
    hi <- lo <- v; hi[i] <- hi[i]+1e-5; lo[i] <- lo[i]-1e-5
    (dense_value(hi)-dense_value(lo))/(2e-5)
  }, numeric(1))
  fd_gap <- max(abs(unname(native)-fd))
  cat(sprintf('point=%d nll_gap=%.9g max_grad_gap=%.9g fd_gap=%.9g pass=%s\n',point,cmp$nll_gap,max(cmp$gradient_gap),fd_gap,cmp$pass && fd_gap < 1e-5))
  if (!cmp$pass || fd_gap >= 1e-5) stop('Native versus independent oracle failed')
}
cat('NATIVE_ORACLE_PASS\n')
