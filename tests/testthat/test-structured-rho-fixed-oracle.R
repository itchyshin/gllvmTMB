test_that("fixed sparse and dense source likelihoods match a direct Gaussian covariance", {
  skip_if_not_installed("TMB")
  fx <- .rho_fixed_fixture()
  K <- fx$K; Q <- fx$Q
  tree <- ape::read.tree(text="((g1:0.6,g2:0.6):0.4,(g3:0.5,g4:0.5):0.5);")
  modes <- c("dep", "indep", "common", "latent", "latent_psi")
  for (source in c("dense", "sparse", "kernel", "tree")) for (mode in modes) for (r in c(0,.35,1)) {
    helper <- if (mode %in% c("latent", "latent_psi")) "phylo_latent" else paste0("phylo_",mode)
    if (mode == "common") helper <- "phylo_indep"
    # Legacy phylo(Ainv=) densifies before resolution; animal(Ainv=) retains
    # augmented precision. Exercise the actual sparse route explicitly.
    if (source == "sparse") helper <- sub("phylo_", "animal_", helper, fixed=TRUE)
    term <- if (grepl("latent", mode)) "group, d = 1" else "0 + trait | group"
    source_arg <- if (source == "dense") "A = K" else "Ainv = Q"
    if (source == "tree") source_arg <- "tree = tree"
    if (source == "kernel") {
      helper <- sub("phylo_", "kernel_", helper, fixed=TRUE)
      term <- if (grepl("latent",mode)) "group, d = 1" else "group"
      source_arg <- "K = K"
    }
    extra <- if (mode == "latent_psi") ", unique = TRUE" else ""
    if (mode == "common") extra <- ", common = TRUE"
    formula <- as.formula(paste0("y ~ 0 + trait + ", helper,"(",term,", ",source_arg,
      extra,", rho = ", r,")"), env = environment())
    payload <- .rho_capture_payload(formula, fx$data)
    obj <- do.call(TMB::MakeADFun, c(payload, list(DLL="gllvmTMB", silent=TRUE)))
    par <- obj$par
    par[names(par)=="theta_rr_phy"] <- seq(.4,.8,length.out=sum(names(par)=="theta_rr_phy"))
    par[names(par)=="log_sd_phy_diag"] <- log(.4)
    par[names(par)=="log_sigma_eps"] <- log(.7)
    resolved <- K[levels(fx$data$group),levels(fx$data$group)]
    if (source == "tree") resolved <- ape::vcv(tree)[levels(fx$data$group),levels(fx$data$group)]
    if (source %in% c("dense","kernel") || mode == "common") diag(resolved) <- diag(resolved) + 1e-8
    reference <- .rho_independent_gaussian_nll(par,obj,payload,resolved,r)
    # Declared before observations: absolute likelihood error scaled by 1+|NLL|.
    expect_true(abs(obj$fn(par)-reference)/(1+abs(reference)) < 1e-8,
                info=paste(source,mode,r))
    expect_true(all(is.finite(obj$gr(par))))
    if (source %in% c("sparse","tree") && mode != "common" && r == 0) {
      expect_false("g_phy" %in% payload$random)
      expect_true("g_phy_iid" %in% payload$random)
      expect_true(all(is.na(payload$map$g_phy)))
    }
    if (source %in% c("sparse","tree") && mode == "latent_psi" && r < 1) {
      expect_true("g_phy_diag_iid" %in% payload$random)
    }
    if (source == "sparse" && mode == "latent_psi" && r == .35) {
      # Central differences of the independent marginal likelihood, no TMB
      # quadratic/precision implementation reused in this reference.
      h <- 1e-5
      fd <- vapply(seq_along(par), function(j) {
        up <- down <- par; up[j] <- up[j]+h; down[j] <- down[j]-h
        (.rho_independent_gaussian_nll(up,obj,payload,resolved,r) -
         .rho_independent_gaussian_nll(down,obj,payload,resolved,r))/(2*h)
      }, numeric(1))
      expect_true(max(abs(obj$gr(par)-fd)/(1+abs(fd))) < 2e-5)
    }
    TMB::FreeADFun(obj)
  }
})

test_that("omitted and explicit one preserve public payloads exactly", {
  fx <- .rho_fixed_fixture(); K <- fx$K
  a <- .rho_capture_payload(y ~ 0 + trait + phylo_latent(group, A=K, unique=TRUE), fx$data)
  b <- .rho_capture_payload(y ~ 0 + trait + phylo_latent(group, A=K, unique=TRUE, rho=1), fx$data)
  expect_identical(a,b)
})
