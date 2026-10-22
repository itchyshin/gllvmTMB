# Spatial source strength uses projected marginal variances, not mesh-node
# variances. The source-level IID field is shared by all replicates of a group.
.structured_rho_spatial_prepare <- function(spec,data,A) {
  group <- data[[spec$grouping]]
  if (is.null(group) || anyNA(group)) cli::cli_abort(c(
    "Spatial attenuation requires an observed grouping column with no missing values.",
    "i"="Use a location identifier after the bar, for example {.code spatial_dep(0 + trait | location, rho = 0.5)}."
  ),class="gllvmTMB_structured_rho_spatial_group")
  labels <- if(is.factor(group)) levels(group) else unique(as.character(group))
  id <- match(as.character(group),labels)
  first <- match(seq_along(labels),id)
  if(anyNA(first)) cli::cli_abort("Spatial attenuation requires a mesh projection for every grouping level; remove unused levels explicitly.",
    class="gllvmTMB_structured_rho_spatial_group")
  levels_A <- A[first,,drop=FALSE]
  if(max(abs(A-levels_A[id,,drop=FALSE]))>1e-12) cli::cli_abort(
    "Every spatial source group must use the same coordinates and mesh projection across traits and observation replicates.",
    class="gllvmTMB_structured_rho_spatial_group")
  list(id=id-1L,labels=labels,A=levels_A)
}

.structured_rho_spatial_cov <- function(A,M0,M1,M2,kappa) {
  Q <- kappa^4*M0+2*kappa^2*M1+M2
  as.matrix(A %*% Matrix::solve(Q,Matrix::t(A)))
}

# Scale-free local source-shape diagnostic. This is a numerical convention,
# not a proof of global identification. Three predeclared reference points
# avoid rejecting geometry solely because of one isolated rank deficiency.
.structured_rho_spatial_geometry <- function(A,M0,M1,M2,kappa,rho) {
  n_locations <- nrow(A)
  selected <- unique(as.integer(round(seq(1,n_locations,length.out=min(n_locations,64L)))))
  A <- A[selected,,drop=FALSE]
  K <- .structured_rho_spatial_cov(A,M0,M1,M2,kappa)
  h <- 1e-5
  shape <- function(k) {
    C <- .structured_rho_spatial_cov(A,M0,M1,M2,k)
    .structured_rho_covariance(C,rho)/sum(diag(C))
  }
  dr <- K-diag(diag(K));dr <- dr/sum(diag(K))
  dk <- (shape(kappa*exp(h))-shape(kappa*exp(-h)))/(2*h)
  J <- cbind(as.numeric(dr),as.numeric(dk))
  norms <- sqrt(colSums(J^2))
  values <- if(any(!is.finite(norms)) || any(norms<1e-10)) c(1,0) else
    svd(sweep(J,2L,norms,"/"),nu=0,nv=0)$d
  list(relative_singular_value=min(values)/max(values),derivative_norms=norms,
    kappa=kappa,rho=rho,tolerance=1e-8,location_indices=selected,n_locations=n_locations,
    fixed_rho_range_shape_norm=norms[2L])
}

.structured_rho_spatial_admit <- function(A,M0,M1,M2) {
  checks <- lapply(c(.5,1,2),function(k)
    .structured_rho_spatial_geometry(A,M0,M1,M2,k,.5))
  if(all(vapply(checks,function(x)x$relative_singular_value<=1e-8,logical(1))))
    cli::cli_abort(c(
      "This spatial geometry does not numerically separate range and rho at the three reference points.",
      "i"="Fix rho or supply a design with more informative spatial separation. This local numerical check is not a global identification test."
    ),class="gllvmTMB_structured_rho_identification")
  invisible(checks)
}

.structured_rho_spatial_diagnostic <- function(fit) {
  td <- fit$tmb_data;x <- fit$source_strength
  tryCatch(.structured_rho_spatial_geometry(td$spatial_rho_A,td$spde_M0,
    td$spde_M1,td$spde_M2,x$kappa,x$value),error=function(e)
      list(available=FALSE,reason=conditionMessage(e),relative_singular_value=NA_real_))
}

.structured_rho_spatial_contribution <- function(fit,redraw=FALSE) {
  td <- fit$tmb_data;ng <- length(fit$source_strength$labels)
  weights <- .structured_rho_weights(fit)
  pars <- fit$tmb_obj$env$parList(par=fit$tmb_obj$env$last.par.best)
  D <- fit$source_strength$source_diagonal
  Q <- exp(4*pars$log_kappa_spde)*td$spde_M0+
    2*exp(2*pars$log_kappa_spde)*td$spde_M1+td$spde_M2
  factor <- if(redraw && weights[1L]>0) Matrix::Cholesky(Q,perm=FALSE,LDL=FALSE) else NULL
  scores <- function(field,iid,count,sd=rep(1,count)) {
    if(redraw) {
      mesh <- if(weights[1L]>0) sweep(as.matrix(Matrix::solve(factor,
        matrix(stats::rnorm(nrow(Q)*count),nrow(Q),count),system="Lt")),2L,sd,"*") else matrix(0,nrow(Q),count)
      independent <- matrix(stats::rnorm(ng*count),ng,count)
    } else { mesh <- pars[[field]];independent <- pars[[iid]] }
    weights[1L]*(td$spatial_rho_A %*% mesh)+
      weights[2L]*sqrt(D)*sweep(independent,2L,sd,"*")
  }
  out <- matrix(0,ng,td$n_traits)
  if(td$spde_lv_k>0) out <- out+scores("omega_spde_lv","omega_spde_lv_iid",td$spde_lv_k) %*% t(fit$report$Lambda_spde)
  if(td$spde_lv_k==0 || td$spde_lv_unique==1) out <- out+
    scores("omega_spde","omega_spde_iid",td$n_traits,exp(-pars$log_tau_spde))
  out
}
