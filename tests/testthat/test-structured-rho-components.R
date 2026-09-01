test_that("fixed rho preserves ordinary covariance on the same source units", {
  fx <- .rho_fixed_fixture(4L); Q <- fx$Q; K <- fx$K
  for(rho in c(0,.35,.9)) {
    fit <- .rho_at_point(y~0+trait+animal_latent(group,Ainv=Q,d=1,unique=TRUE,rho=rho)+
      dep(0+trait|group),fx$data,unit="group")
    td <- fit$tmb_data
    S <- tcrossprod(fit$report$Lambda_phy)+diag(fit$report$sd_phy_diag^2)
    ordinary <- tcrossprod(fit$report$Lambda_B)
    resolved <- K[fit$source_strength$labels,fit$source_strength$labels]
    Kr <- rho*resolved;diag(Kr) <- diag(resolved)
    gi <- td$species_id+1L;ti <- td$trait_id+1L;ui <- td$site_id+1L
    V <- Kr[gi,gi]*S[ti,ti]+outer(ui,ui,"==")*ordinary[ti,ti]
    diag(V) <- diag(V)+fit$report$sigma_eps[1]^2
    residual <- as.numeric(td$y-td$X_fix%*%gllvmTMB:::.gllvmTMB_b_fix_values(fit))
    nll <- .5*(length(residual)*log(2*pi)+as.numeric(determinant(V,logarithm=TRUE)$modulus)+
      drop(crossprod(residual,solve(V,residual))))
    expect_true(abs(nll-fit$opt$objective)/(1+abs(nll))<1e-8)
    expect_true(isTRUE(fit$use$rr_B))
    expect_true(isTRUE(fit$use$phylo_diag))
    expect_equal(suppressMessages(predict(fit,newdata=fit$data))$est,predict(fit)$est,tolerance=1e-9)
    TMB::FreeADFun(fit$tmb_obj)
  }
  expect_error(.rho_capture_payload(y~0+trait+animal_latent(group,Ainv=Q,d=1,unique=TRUE,rho=NULL)+
    dep(0+trait|group),fx$data,unit="group",unit_obs="obs"),"competing ordinary covariance")
})

test_that("unconditional simulation preserves a separate ordinary intercept", {
  fx <- .rho_fixed_fixture(4L);Q <- fx$Q;K <- fx$K
  fx$data$block <- factor(fx$data$rep)
  fit <- .rho_at_point(y~0+trait+animal_latent(group,Ainv=Q,d=1,unique=TRUE,rho=.35)+(1|block),fx$data)
  td <- fit$tmb_data
  S <- tcrossprod(fit$report$Lambda_phy)+diag(fit$report$sd_phy_diag^2)
  resolved <- K[fit$source_strength$labels,fit$source_strength$labels]
  Kr <- .35*resolved;diag(Kr) <- diag(resolved)
  gi <- td$species_id+1L;ti <- td$trait_id+1L;bi <- td$re_int_group_id[,1]
  V <- Kr[gi,gi]*S[ti,ti]+outer(bi,bi,"==")*exp(2*fit$report$log_sigma_re_int[1])
  diag(V) <- diag(V)+fit$report$sigma_eps[1]^2
  y <- simulate(fit,nsim=4000,seed=18411,condition_on_RE=FALSE)
  se <- sqrt((V^2+outer(diag(V),diag(V)))/3999)
  expect_true(all(abs(cov(t(y))-V)<6*se))
  expect_equal(suppressMessages(predict(fit,newdata=fit$data))$est,predict(fit)$est,tolerance=1e-9)
  TMB::FreeADFun(fit$tmb_obj)
})

test_that("new fixed rho rejects ordinary augmented slopes before TMB dispatch", {
 fx <- .rho_fixed_fixture(4L);Q <- fx$Q;dat <- fx$data;dat$x <- sin(as.integer(dat$obs))
 for(term in c("latent(1+x|group,d=1,unique=FALSE)","latent(1+x|group,d=1,unique=TRUE)","unique(0+trait+(0+trait):x|group)")) {
   f <- as.formula(paste0("y~0+trait+animal_dep(0+trait|group,Ainv=Q,rho=.3)+",term))
   expect_error(suppressWarnings(.rho_capture_payload(f,dat,unit="group",unit_obs="obs")),class="gllvmTMB_structured_rho_blocks")
 }
})
