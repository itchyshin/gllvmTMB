## Private, no-fit G2f fixture: original G2d supports and six PA visits.
g2f_truth_constants <- function() list(
  alpha = c(sp1=-1.40, sp2=-1.20, sp3=-1.55, sp4=-1.35, sp5=-1.60, sp6=-1.10),
  beta = c(sp1=-.55, sp2=.35, sp3=.70, sp4=-.40, sp5=.55, sp6=.20),
  lambda = c(sp1=.70, sp2=-.55, sp3=.45, sp4=.60, sp5=-.40, sp6=.50),
  psi_sd = c(sp1=.35, sp2=.30, sp3=.40, sp4=.32, sp5=.38, sp6=.34),
  gamma = c(sp1=.45, sp2=-.35, sp3=.25, sp4=-.40, sp5=.30, sp6=.20),
  gbif_contrast = c(sp1=.30, sp2=-.20, sp3=.15, sp4=-.25, sp5=.20, sp6=-.10)
)
g2f_seed <- 86101L
g2f_make_fixture <- function(seed = g2f_seed, n_cell = 120L) {
  stopifnot(identical(n_cell, 120L)); set.seed(seed)
  tr <- g2f_truth_constants(); species <- names(tr$alpha); cells <- paste0("cell_", seq_len(n_cell))
  x <- seq(-1, 1, length.out=n_cell); b <- as.numeric(scale(rnorm(n_cell))); z <- rnorm(n_cell)
  eps <- sapply(tr$psi_sd, function(sd) rnorm(n_cell, sd=sd))
  eta <- sweep(outer(x, tr$beta), 2L, tr$alpha, "+") + outer(z, tr$lambda) + eps
  a_g <- exp(seq(log(.8), log(2), length.out=n_cell)); a_s <- exp(seq(log(.6), log(1.4), length.out=n_cell))
  grid <- expand.grid(cell_id=cells, trait=species, KEEP.OUT.ATTRS=FALSE, stringsAsFactors=FALSE)
  eta_vec <- as.vector(eta); b_vec <- rep(b, times=length(species)); g_support <- rep(a_g, times=length(species)); s_support <- rep(a_s, times=length(species))
  gbif <- transform(grid, source="gbif", survey_event_id=NA_character_, branch="count", support=g_support,
    value=rpois(nrow(grid), g_support*exp(eta_vec + rep(tr$gbif_contrast, each=n_cell) + b_vec*rep(tr$gamma, each=n_cell))), visit=NA_integer_)
  pa <- lapply(1:6, function(v) transform(grid, source="survey", survey_event_id=paste0("survey_v",v,"_",cell_id), branch="pa", support=s_support,
    value=rbinom(nrow(grid), 1L, -expm1(-s_support*exp(eta_vec))), visit=v))
  rows_six <- do.call(rbind, c(list(gbif), pa)); rows_three <- do.call(rbind, c(list(gbif), pa[1:3]))
  design <- function(rows) { ix <- match(paste(rows$cell_id,rows$trait),paste(grid$cell_id,grid$trait)); list(X=matrix(rep(x,times=length(species))[ix],ncol=1L,dimnames=list(NULL,"env")),B=matrix(ifelse(rows$source=="gbif",b_vec[ix],NA_real_),ncol=1L,dimnames=list(NULL,"bias"))) }
  list(three_visit=c(list(rows=rows_three),design(rows_three)), six_visit=c(list(rows=rows_six),design(rows_six)), truth=list(seed=seed,n_cell=n_cell,n_species=6L,n_visit=6L,support_g=a_g,support_s=a_s,eta=eta,x=x,b=b,z=z,eps=eps,shared_Sigma=tcrossprod(tr$lambda),psi_variance=tr$psi_sd^2,constants=tr))
}
g2f_validate_fixture <- function(fx) {
  stopifnot(identical(fx$truth$n_cell,120L),identical(fx$truth$n_species,6L),identical(fx$truth$n_visit,6L),identical(names(fx$truth$constants$alpha),paste0("sp",1:6)))
  six <- fx$six_visit; three <- fx$three_visit; survey <- six$rows$source=="survey"
  stopifnot(all(is.finite(six$B[six$rows$source=="gbif",1])),all(is.na(six$B[survey,1])),all(six$rows$branch[survey]=="pa"),all(six$rows$branch[!survey]=="count"),all(table(six$rows$cell_id[survey],six$rows$trait[survey])==6L),!anyDuplicated(six$rows[survey,c("cell_id","trait","survey_event_id")]))
  key <- paste(six$rows$source,six$rows$cell_id,six$rows$trait,six$rows$survey_event_id); key3 <- paste(three$rows$source,three$rows$cell_id,three$rows$trait,three$rows$survey_event_id); ix <- match(key3,key); got <- six$rows[ix,,drop=FALSE]; row.names(got)<-row.names(three$rows)<-NULL
  stopifnot(identical(three$rows,got),identical(three$X,six$X[ix,,drop=FALSE]),identical(three$B,six$B[ix,,drop=FALSE]))
  invisible(TRUE)
}
g2f_information_oracle <- function(fx) {
  ## Conditional on eta_cs, I_eta for one cloglog Bernoulli visit is
  ## (dp/deta)^2 / {p(1-p)} = lambda^2 exp(-lambda) / {1-exp(-lambda)},
  ## where lambda = a_s exp(eta).  Six independent visits multiply it by six.
  lambda_s <- outer(fx$truth$support_s, rep(1, 6)) * exp(fx$truth$eta)
  p <- -expm1(-lambda_s)
  pa_one_visit_information_eta <- lambda_s^2 * exp(-lambda_s) / p
  tr <- fx$truth$constants
  mu_g <- outer(fx$truth$support_g, rep(1, 6)) * exp(
    fx$truth$eta + rep(tr$gbif_contrast, each = fx$truth$n_cell) +
      outer(fx$truth$b, tr$gamma)
  )
  list(
    pa_expected_events_per_cell_species = 6 * p,
    pa_event_opportunity_ratio = 2,
    pa_one_visit_information_eta = pa_one_visit_information_eta,
    pa_three_visit_information_eta = 3 * pa_one_visit_information_eta,
    pa_six_visit_information_eta = 6 * pa_one_visit_information_eta,
    pa_information_ratio = 2,
    gbif_information_eta = mu_g,
    survey_probability = p
  )
}
