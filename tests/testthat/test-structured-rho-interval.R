test_that("raw profiling cannot expose source-strength intervals", {
  fx <- .rho_fixed_fixture(4L); K <- fx$K
  fit <- .rho_at_point(y~0+trait+phylo_dep(0+trait|group,A=K,rho=NULL),fx$data)
  called <- 0L
  local_mocked_bindings(tmbprofile=function(...) {called <<- called+1L;stop("Profiling forbidden in this negative test")},.package="TMB")
  index <- which(names(fit$opt$par)=="eta_structured_rho")
  contrast <- rep(0,length(fit$opt$par)); contrast[index] <- 1
  expect_error(tmbprofile_wrapper(fit,name="eta_structured_rho"),class="gllvmTMB_structured_rho_interval_unsupported")
  expect_error(tmbprofile_wrapper(fit,name=index),class="gllvmTMB_structured_rho_interval_unsupported")
  expect_error(tmbprofile_wrapper(fit,lincomb=contrast),class="gllvmTMB_structured_rho_interval_unsupported")
  expect_identical(called,0L)
  expect_false("eta_structured_rho" %in% profile_targets(fit)$label)
  TMB::FreeADFun(fit$tmb_obj)
})

test_that("direct phylogenetic-signal intervals cannot bypass attenuation limitations", {
 fx <- .rho_fixed_fixture(4L);K <- fx$K;called <- 0L
 local_mocked_bindings(.phylo_signal_wald_ci=function(...) {called <<- called+1L;stop("Wald allocation reached")},.package="gllvmTMB")
 for(rho_request in list(.3,NULL)) {
  fit <- .rho_at_point(y~0+trait+phylo_dep(0+trait|group,A=K,rho=rho_request),fx$data)
  expect_error(suppressMessages(profile_ci_phylo_signal(fit)),class="gllvmTMB_structured_rho_source_allocation_unsupported")
  TMB::FreeADFun(fit$tmb_obj)
 }
 expect_identical(called,0L)
})
