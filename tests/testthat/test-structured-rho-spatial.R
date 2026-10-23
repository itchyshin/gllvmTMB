test_that("spatial attenuation preserves projected covariance and joint range gradients", {
  skip_if_not_installed("fmesher")
  fx <- .rho_spatial_fixture();mesh <- fx$mesh
  for(mode in c("indep","common","dep","latent","latent_psi")) {
    helper <- if(mode=="common") "indep" else if(mode=="latent_psi") "latent" else mode
    extra <- switch(mode,common=", common=TRUE",latent=", d=1",latent_psi=", d=1, unique=TRUE","")
    for(r in c("0","0.35","1","NULL")) {
      f <- as.formula(paste0("y ~ 0 + trait + spatial_",helper,"(0 + trait | group, mesh=mesh",extra,", rho=",r,")"))
      payload <- .rho_capture_payload(f,fx$data)
      obj <- do.call(TMB::MakeADFun,c(payload,list(DLL="gllvmTMB",silent=TRUE)))
      par <- obj$par
      par[names(par)=="theta_rr_spde_lv"] <- seq(.4,.8,length.out=sum(names(par)=="theta_rr_spde_lv"))
      par[names(par)=="log_sigma_eps"] <- log(.7)
      par[names(par)=="log_tau_spde"] <- -log(seq(.3,.7,length.out=sum(names(par)=="log_tau_spde")))
      par[names(par)=="eta_structured_rho"] <- qlogis(.35)
      for(kappa in c(.7,1.4)) {
        par[names(par)=="log_kappa_spde"] <- log(kappa)
        reference <- function(x) .rho_spatial_reference(x,obj,payload,
          if(r=="NULL") plogis(x[names(x)=="eta_structured_rho"]) else as.numeric(r))
        expected <- reference(par)
        expect_true(abs(obj$fn(par)-expected)/(1+abs(expected))<1e-8,info=paste(mode,r,kappa))
        h <- 1e-5
        fd <- vapply(seq_along(par),function(j) {
          up <- down <- par;up[j] <- up[j]+h;down[j] <- down[j]-h
          (reference(up)-reference(down))/(2*h)
        },numeric(1))
        expect_true(max(abs(obj$gr(par)-fd)/(1+abs(fd)))<2e-5,info=paste(mode,r,kappa))
      }
      if(r=="0") {
        expect_false(any(c("omega_spde","omega_spde_lv") %in% payload$random))
        expect_true("log_kappa_spde" %in% names(par))
      }
      TMB::FreeADFun(obj)
    }
  }
})

test_that("spatial estimated endpoints keep joint scores finite", {
  skip_if_not_installed("fmesher")
  fx <- .rho_spatial_fixture();mesh <- fx$mesh
  payload <- .rho_capture_payload(y~0+trait+spatial_latent(0+trait|group,mesh=mesh,d=1,unique=TRUE,rho=NULL),fx$data)
  obj <- do.call(TMB::MakeADFun,c(payload,list(DLL="gllvmTMB",silent=TRUE)))
  for(eta in c(-20,20)) {
    p <- obj$par;p[names(p)=="eta_structured_rho"] <- eta
    ref <- function(x) .rho_spatial_reference(x,obj,payload,plogis(x[names(x)=="eta_structured_rho"]))
    value <- ref(p);expect_true(abs(obj$fn(p)-value)/(1+abs(value))<1e-8)
    h <- 1e-5
    fd <- vapply(seq_along(p),function(j) {u <- d <- p;u[j] <- u[j]+h;d[j] <- d[j]-h;(ref(u)-ref(d))/(2*h)},numeric(1))
    expect_true(max(abs(obj$gr(p)-fd)/(1+abs(fd)))<2e-5)
  }
  TMB::FreeADFun(obj)
})

test_that("spatial geometry guards distinguish proportional and changing diagonals", {
  A <- Matrix::Diagonal(2);zero <- Matrix::Matrix(0,2,2,sparse=TRUE)
  Q <- Matrix::Matrix(matrix(c(2,-.4,-.4,1),2),sparse=TRUE)
  expect_error(gllvmTMB:::.structured_rho_spatial_admit(A,Q,zero,zero),
    class="gllvmTMB_structured_rho_identification")
  proportional <- gllvmTMB:::.structured_rho_spatial_geometry(A,Q,zero,zero,1,0)
  changing <- gllvmTMB:::.structured_rho_spatial_geometry(A,Matrix::Diagonal(x=c(1,2)),zero,Matrix::Diagonal(x=c(3,1)),1,0)
  expect_lt(proportional$fixed_rho_range_shape_norm,1e-10)
  expect_gt(changing$fixed_rho_range_shape_norm,1e-3)
  failed <- gllvmTMB:::.structured_rho_spatial_diagnostic(list(
    source_strength=list(kappa=1,value=.5),tmb_data=list(spatial_rho_A=A,spde_M0=zero,spde_M1=zero,spde_M2=zero)))
  expect_false(failed$available)
  expect_true(nzchar(failed$reason))
})

test_that("spatial rho workflow uses fitted diagonals and shared location draws", {
  skip_if_not_installed("fmesher")
  fx <- .rho_spatial_fixture();mesh <- fx$mesh
  for(mode in c("indep","common","dep","latent_psi")) {
    helper <- if(mode=="common") "indep" else if(mode=="latent_psi") "latent" else mode
    extra <- switch(mode,common=", common=TRUE",latent_psi=", d=1, unique=TRUE","")
    for(r in c("0","0.35","NULL")) {
      f <- as.formula(paste0("y ~ 0 + trait + spatial_",helper,"(0 + trait | group, mesh=mesh",extra,", rho=",r,")"))
      fit <- .rho_at_point(f,fx$data)
      train <- predict(fit,type="link")$est
      nd <- suppressMessages(predict(fit,newdata=fit$data,type="link"))$est
      expect_equal(nd,train,tolerance=1e-9,info=paste(mode,r))
      out <- suppressMessages(extract_Sigma(fit,level="spatial",link_residual="none"))
      expect_identical(out$source_strength$source,"spatial")
      expect_equal(out$source_strength$value,if(r=="NULL") .35 else as.numeric(r))
      expect_true(gllvmTMB:::.check_simulate_unconditional(fit)$can_redraw)
      td <- fit$tmb_data
      A <- as.matrix(td$spatial_rho_A);k <- fit$report$kappa
      K <- A %*% solve(as.matrix(k^4*td$spde_M0+2*k^2*td$spde_M1+td$spde_M2),t(A))
      expect_equal(unname(out$source_strength$source_diagonal),diag(K),tolerance=1e-10)
      if(mode=="latent_psi" && r=="NULL") {
        set.seed(319805)
        draws <- replicate(2000L,as.numeric(gllvmTMB:::.structured_rho_spatial_contribution(fit,redraw=TRUE)))
        Kr <- .35*K;diag(Kr) <- diag(K)
        truth <- kronecker(out$Sigma,Kr)
        se <- sqrt((truth^2+outer(diag(truth),diag(truth)))/1999)
        expect_true(all(abs(cov(t(draws))-truth)<6*se))
        expect_equal(dim(simulate(fit,nsim=2,condition_on_RE=FALSE)),c(nrow(fit$data),2L))
      }
      unknown <- fit$data;unknown$group <- as.character(unknown$group);unknown$group[1] <- "new"
      expect_error(predict(fit,newdata=unknown,type="link"))
      TMB::FreeADFun(fit$tmb_obj)
    }
  }
})

test_that("spatial attenuation rejects inconsistent groups and preserves endpoints", {
  skip_if_not_installed("fmesher")
  fx <- .rho_spatial_fixture();mesh <- fx$mesh
  a <- .rho_capture_payload(y~0+trait+spatial_latent(0+trait|group,mesh=mesh,unique=TRUE),fx$data)
  b <- .rho_capture_payload(y~0+trait+spatial_latent(0+trait|group,mesh=mesh,unique=TRUE,rho=1),fx$data)
  expect_identical(a,b)
  bad <- fx$data;bad$group <- "same"
  expect_error(.rho_capture_payload(y~0+trait+spatial_dep(0+trait|group,mesh=mesh,rho=.5),bad),
    class="gllvmTMB_structured_rho_spatial_group")
  expect_warning(expect_error(.rho_capture_payload(y~0+trait+spatial_dep(0+trait|absent,mesh=mesh,rho=.5),fx$data),
    class="gllvmTMB_structured_rho_spatial_group"),"Unused optional grouping")
  expect_error(.rho_capture_payload(y~0+trait+spatial_dep(0+trait|group,mesh=mesh,rho=NULL)+(1|group),fx$data),
    class="gllvmTMB_structured_rho_identification")
})

test_that("spatial rho preserves long and wide observation likelihoods", {
  skip_if_not_installed("fmesher")
  fx <- .rho_spatial_fixture();mesh <- fx$mesh
  wide <- reshape(fx$data[c("obs","group","trait","y")],idvar=c("obs","group"),
    timevar="trait",direction="wide")
  names(wide) <- sub("^y\\.","",names(wide))
  for(r in c(".35","NULL")) {
    a <- .rho_at_point(as.formula(paste0("y~0+trait+spatial_latent(0+trait|group,mesh=mesh,d=1,unique=TRUE,rho=",r,")")),fx$data)
    b <- .rho_at_point(as.formula(paste0("traits(t1,t2,t3,t4)~1+spatial_latent(1|group,mesh=mesh,d=1,unique=TRUE,rho=",r,")")),wide)
    expect_equal(as.numeric(logLik(a)),as.numeric(logLik(b)),tolerance=1e-9)
    expect_equal(a$tmb_obj$gr(a$opt$par),b$tmb_obj$gr(b$opt$par),tolerance=1e-9)
    expect_equal(a$source_strength$source_diagonal,b$source_strength$source_diagonal,tolerance=1e-12)
    TMB::FreeADFun(a$tmb_obj);TMB::FreeADFun(b$tmb_obj)
  }
})
