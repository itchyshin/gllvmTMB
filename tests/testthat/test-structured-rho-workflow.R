test_that("source draws preserve resolved marginal covariance and replication", {
  fx <- .rho_fixed_fixture(4L)
  groups <- levels(fx$data$group)
  K <- fx$K[groups,groups]
  for (representation in c("sparse","dense")) for (rho in c(0,.35,1)) {
    fit <- list(source_strength=list(value=rho,representation=representation),
      tmb_data=list(n_species=4L, structured_rho_diagonal=diag(K),
        species_id=rep(0:3,each=2), species_aug_id=rep(match(groups,rownames(fx$K))-1L,each=2),
        Ainv_phy_rr=fx$Q, structured_rho_estimated=as.integer(representation=="dense")))
    eig <- eigen(K/outer(sqrt(diag(K)),sqrt(diag(K))))
    fit$tmb_data$structured_rho_eigenvalues <- eig$values
    fit$tmb_data$structured_rho_eigenvectors <- eig$vectors
    set.seed(8134)
    draws <- gllvmTMB:::.structured_rho_scores(fit,25000L,redraw=TRUE)
    truth <- rho*K; diag(truth) <- diag(K)
    # Gaussian sample covariance SE, declared before results: six SEs per entry.
    se <- sqrt((truth^2+outer(diag(truth),diag(truth)))/24999)
    expect_true(all(abs(cov(t(draws))-truth) < 6*se), info=paste(representation,rho))
  }
})

test_that("sparse effective scores include IID fields only on modeled levels", {
  fit <- list(source_strength=list(value=.25,representation="sparse"),
    tmb_data=list(n_species=2L,structured_rho_diagonal=c(4,9),
      species_id=c(0L,0L,1L,1L),species_aug_id=c(2L,2L,1L,1L)))
  par <- list(g_phy=matrix(c(99,2,3),3),g_phy_iid=matrix(c(5,7),2))
  expect_equal(as.numeric(gllvmTMB:::.structured_rho_scores(fit,1L,parameters=par)),
    .5*c(3,2)+sqrt(.75)*c(2,3)*c(5,7))
  fit$source_strength$value <- 0
  par$g_phy[] <- NA_real_
  expect_equal(as.numeric(gllvmTMB:::.structured_rho_scores(fit,1L,parameters=par)),c(10,21))
})

test_that("public point objects retain full structured predictions and extraction", {
  fx <- .rho_fixed_fixture(4L); K <- fx$K; Q <- fx$Q
  for (source in c("sparse","dense","kernel")) for (mode in c("latent","common")) {
    for (rho in c("0",".35","NULL")) {
      prefix <- switch(source,sparse="animal",dense="phylo",kernel="kernel")
      source_arg <- switch(source,sparse="Ainv=Q",dense="A=K",kernel="K=K")
      call <- if (mode=="latent") paste0(prefix,"_latent(group,",source_arg,",d=1,unique=TRUE,rho=",rho,")") else
        paste0(prefix,"_indep(",if(source=="kernel") "group" else "0+trait|group",",",source_arg,",common=TRUE,rho=",rho,")")
      f <- as.formula(paste("y~0+trait+",call),env=environment())
      fit <- .rho_at_point(f,fx$data)
      train <- predict(fit,type="link")$est
      nd <- suppressMessages(predict(fit,newdata=fit$data,type="link"))$est
      expect_equal(nd,train,tolerance=1e-9,info=paste(source,mode,rho))
      out <- suppressMessages(extract_Sigma(fit,level="phy",link_residual="none"))
      expect_equal(out$source_strength$value,if(rho=="NULL") .35 else as.numeric(rho))
      expect_identical(out$source_strength$grouping,"group")
      expect_equal(out$source_strength$source_diagonal,fit$source_strength$source_diagonal)
      S <- if(isTRUE(fit$use$propto)) diag(as.numeric(fit$report$lam_phy),4) else
        tcrossprod(fit$report$Lambda_phy)+(if(isTRUE(fit$use$phylo_diag)) diag(fit$report$sd_phy_diag^2) else matrix(0,4,4))
      expect_equal(unname(out$Sigma),unname(S),tolerance=1e-12)
      expect_true(gllvmTMB:::.check_simulate_unconditional(fit)$can_redraw)
      expect_error(extract_phylo_signal(fit),class="gllvmTMB_structured_rho_source_allocation_unsupported")
      expect_error(extract_proportions(fit),class="gllvmTMB_structured_rho_source_allocation_unsupported")
      expect_error(VP(fit),class="gllvmTMB_structured_rho_source_allocation_unsupported")
      expect_error(bootstrap_Sigma(fit),class="gllvmTMB_structured_rho_refit_unsupported")
      expect_error(gllvmTMB:::.reconstruct_multi_formula(fit),class="gllvmTMB_structured_rho_refit_unsupported")
      TMB::FreeADFun(fit$tmb_obj)
    }
  }
})

test_that("estimated weights retain a small independent field near the boundary", {
  fit <- list(source_strength=list(status="estimated",value=plogis(40)),
    opt=list(par=c(eta_structured_rho=40)))
  w <- gllvmTMB:::.structured_rho_weights(fit)
  expect_gt(w[2],0)
  expect_equal(w[2],exp(-20),tolerance=1e-15)
})

test_that("fixed source scores map unobserved modeled levels by label", {
  fx <- .rho_fixed_fixture(4L); Q <- fx$Q
  fit <- .rho_at_point(y~0+trait+animal_latent(group,Ainv=Q,d=1,unique=TRUE,rho=.35),
    fx$data[fx$data$group!="g2",])
  effects <- gllvmTMB:::.structured_rho_contribution(fit)
  expect_true(all(is.finite(effects)))
  expect_equal(nrow(effects),length(levels(fit$data$group)))
  TMB::FreeADFun(fit$tmb_obj)
})

test_that("public Gaussian simulation redraws whole latent plus Psi covariance", {
  fx <- .rho_fixed_fixture(4L); K <- fx$K; Q <- fx$Q
  for (source in c("sparse","dense")) {
    f <- if(source=="sparse") y~0+trait+animal_latent(group,Ainv=Q,d=1,unique=TRUE,rho=NULL) else
      y~0+trait+phylo_latent(group,A=K,d=1,unique=TRUE,rho=NULL)
    fit <- .rho_at_point(f,fx$data)
    td <- fit$tmb_data
    resolved <- K[levels(fit$data$group),levels(fit$data$group)]
    if(source=="dense") diag(resolved) <- diag(resolved)+1e-8
    Kr <- .35*resolved; diag(Kr) <- diag(resolved)
    S <- tcrossprod(fit$report$Lambda_phy)+diag(fit$report$sd_phy_diag^2)
    gi <- td$species_id+1L; ti <- td$trait_id+1L
    V <- Kr[gi,gi]*S[ti,ti]
    diag(V) <- diag(V)+fit$report$sigma_eps[1]^2
    y <- simulate(fit,nsim=4000L,seed=19833,condition_on_RE=FALSE)
    # Six Gaussian sample covariance SEs, declared before outcomes.
    se <- sqrt((V^2+outer(diag(V),diag(V)))/3999)
    expect_true(all(abs(cov(t(y))-V)<6*se),info=source)
    TMB::FreeADFun(fit$tmb_obj)
  }
})

test_that("weak loading diagnostics separate source strength from factor plus Psi", {
  fit <- list(source_strength=list(status="estimated",mode="latent",folded_psi=TRUE,
      source_diagonal=c(1,2)), n_traits=4L,use=list(phylo_diag=TRUE),
    report=list(Lambda_phy=matrix(c(1,0,0,0),4),sd_phy_diag=rep(1,4),sigma_eps=1))
  diag <- gllvmTMB:::.structured_rho_diagnostics(fit)
  expect_true(diag$weak_loading_psi_separation)
  expect_false(diag$weak_total_source)
  fit$source_strength$folded_psi <- FALSE
  fit$use$phylo_diag <- FALSE
  expect_false(gllvmTMB:::.structured_rho_diagnostics(fit)$weak_loading_psi_separation)
  fit$report$Lambda_phy[] <- 0
  expect_true(gllvmTMB:::.structured_rho_diagnostics(fit)$weak_total_source)
})

test_that("reported physical rho score agrees with independent Gaussian derivative", {
  fx <- .rho_fixed_fixture(4L); K <- fx$K
  fit <- .rho_at_point(y~0+trait+phylo_dep(0+trait|group,A=K,rho=NULL),fx$data)
  td <- fit$tmb_data; rho <- fit$source_strength$value
  resolved <- K[fit$source_strength$labels,fit$source_strength$labels]
  diag(resolved) <- diag(resolved)+1e-8
  Kr <- rho*resolved; diag(Kr) <- diag(resolved)
  C <- resolved; diag(C) <- 0
  S <- tcrossprod(fit$report$Lambda_phy)
  gi <- td$species_id+1L; ti <- td$trait_id+1L
  V <- Kr[gi,gi]*S[ti,ti]; diag(V) <- diag(V)+fit$report$sigma_eps[1]^2
  deriv <- C[gi,gi]*S[ti,ti]
  inverse <- solve(V)
  residual <- as.numeric(td$y-td$X_fix %*% gllvmTMB:::.gllvmTMB_b_fix_values(fit))
  a <- inverse %*% residual
  score <- .5*sum((inverse-tcrossprod(a))*deriv)
  expect_equal(fit$source_strength$nll_score_rho,score,tolerance=2e-7)
  TMB::FreeADFun(fit$tmb_obj)
})

test_that("legacy endpoint redraws folded Psi and predicts known source levels", {
  fx <- .rho_fixed_fixture(4L); Q <- fx$Q; K <- fx$K
  fit <- .rho_at_point(y~0+trait+animal_latent(group,Ainv=Q,d=1,unique=TRUE,rho=1),fx$data)
  expect_null(fit$source_strength)
  expect_true(gllvmTMB:::.check_simulate_unconditional(fit)$can_redraw)
  expect_equal(suppressMessages(predict(fit,newdata=fit$data))$est,predict(fit)$est,tolerance=1e-9)
  td <- fit$tmb_data
  resolved <- K[levels(fit$data$group),levels(fit$data$group)]
  S <- tcrossprod(fit$report$Lambda_phy)+diag(fit$report$sd_phy_diag^2)
  gi <- td$species_id+1L; ti <- td$trait_id+1L
  V <- resolved[gi,gi]*S[ti,ti];diag(V) <- diag(V)+fit$report$sigma_eps[1]^2
  y <- simulate(fit,nsim=4000,seed=19423,condition_on_RE=FALSE)
  se <- sqrt((V^2+outer(diag(V),diag(V)))/3999)
  expect_true(all(abs(cov(t(y))-V)<6*se))
  TMB::FreeADFun(fit$tmb_obj)
})
