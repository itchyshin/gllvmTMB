test_that("estimated source rho likelihood and gradient match independent Gaussian covariance", {
  fx <- .rho_fixed_fixture(n_traits=4L)
  K <- fx$K; Q <- fx$Q
  tree <- ape::read.tree(text="((g1:0.6,g2:0.6):0.4,(g3:0.5,g4:0.5):0.5);")
  for (source in c("dense", "sparse", "kernel", "tree")) {
    for (mode in c("dep", "indep", "common", "latent", "latent_psi")) {
      column <- if (mode == "common") "indep" else if (grepl("latent",mode)) "latent" else mode
      prefix <- switch(source, sparse="animal", kernel="kernel", "phylo")
      grouping <- if (grepl("latent",mode) || source=="kernel") "group" else "0 + trait | group"
      source_arg <- switch(source,dense="A=K",sparse="Ainv=Q",kernel="K=K",tree="tree=tree")
      extra <- switch(mode,common=",common=TRUE",latent=",d=1",latent_psi=",d=1,unique=TRUE","")
      f <- as.formula(paste0("y ~ 0 + trait + ",prefix,"_",column,"(",grouping,",",source_arg,
                            extra,",rho=NULL)"), env=environment())
      payload <- .rho_capture_payload(f,fx$data)
      expect_identical(payload$parameters$eta_structured_rho,0)
      expect_null(payload$map$eta_structured_rho)
      expect_false("eta_structured_rho" %in% payload$random)
      expect_null(payload$map$log_sigma_eps)
      obj <- do.call(TMB::MakeADFun,c(payload,list(DLL="gllvmTMB",silent=TRUE)))
      par <- obj$par
      par[names(par)=="theta_rr_phy"] <- seq(.4,.8,length.out=sum(names(par)=="theta_rr_phy"))
      par[names(par)=="log_sd_phy_diag"] <- log(.4)
      par[names(par)=="log_sigma_eps"] <- log(.7)
      resolved <- if (source=="tree") ape::vcv(tree) else K
      resolved <- resolved[levels(fx$data$group),levels(fx$data$group)]
      if (source %in% c("dense","kernel") || mode=="common") diag(resolved) <- diag(resolved)+1e-8
      for (eta in c(-15,qlogis(.2),0,qlogis(.8),15)) {
        par[names(par)=="eta_structured_rho"] <- eta
        rho <- plogis(eta)
        ref <- .rho_independent_gaussian_nll(par,obj,payload,resolved,rho)
        expect_true(abs(obj$fn(par)-ref)/(1+abs(ref)) < 1e-8, info=paste(source,mode,eta))
        gradient <- obj$gr(par)
        h <- 1e-5
        fd <- vapply(seq_along(par), function(j) {
          up <- down <- par; up[j] <- up[j]+h; down[j] <- down[j]-h
          ru <- plogis(up[names(up)=="eta_structured_rho"])
          rd <- plogis(down[names(down)=="eta_structured_rho"])
          (.rho_independent_gaussian_nll(up,obj,payload,resolved,ru) -
           .rho_independent_gaussian_nll(down,obj,payload,resolved,rd))/(2*h)
        },numeric(1))
        expect_true(all(is.finite(gradient)))
        expect_true(max(abs(gradient-fd)/(1+abs(fd))) < 2e-5, info=paste(source,mode,eta))
      }
      TMB::FreeADFun(obj)
    }
  }
})

test_that("explicit observation-vector grouping admits source-group units", {
  fx <- .rho_fixed_fixture(n_traits=4L); K <- fx$K
  f <- y ~ 0 + trait + phylo_dep(0 + trait | group, A=K, rho=NULL)
  a <- .rho_capture_payload(f,fx$data)
  b <- .rho_capture_payload(f,fx$data,unit="group",unit_obs="obs")
  expect_identical(a$parameters$eta_structured_rho,b$parameters$eta_structured_rho)
  expect_equal(a$data$Ainv_phy_rr,b$data$Ainv_phy_rr)
  oa <- do.call(TMB::MakeADFun,c(a,list(DLL="gllvmTMB",silent=TRUE)))
  ob <- do.call(TMB::MakeADFun,c(b,list(DLL="gllvmTMB",silent=TRUE)))
  expect_identical(oa$par,ob$par)
  expect_equal(oa$fn(oa$par),ob$fn(ob$par),tolerance=1e-10)
  TMB::FreeADFun(oa); TMB::FreeADFun(ob)
})

test_that("wide recursion preserves the estimated rho request", {
  fx <- .rho_fixed_fixture(n_traits=4L); K <- fx$K
  wide <- as.data.frame(tidyr::pivot_wider(fx$data, id_cols=c("obs","group"),
    names_from="trait",values_from="y"))
  a <- .rho_capture_payload(y ~ 0 + trait + phylo_dep(0 + trait | group,A=K,rho=NULL),fx$data)
  b <- .rho_capture_payload(traits(t1,t2,t3,t4) ~ 1 + phylo_dep(1 | group,A=K,rho=NULL),wide)
  expect_identical(b$parameters$eta_structured_rho,0)
  expect_identical(a$random,b$random)
  expect_equal(a$data$y,b$data$y)
  oa <- do.call(TMB::MakeADFun,c(a,list(DLL="gllvmTMB",silent=TRUE)))
  ob <- do.call(TMB::MakeADFun,c(b,list(DLL="gllvmTMB",silent=TRUE)))
  expect_identical(oa$par,ob$par)
  expect_equal(oa$fn(oa$par),ob$fn(ob$par),tolerance=1e-10)
  TMB::FreeADFun(oa); TMB::FreeADFun(ob)
})
