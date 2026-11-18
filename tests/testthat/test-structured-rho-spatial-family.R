test_that("fixed spatial attenuation matches an effective dense source for admitted families", {
  skip_if_not_installed("fmesher")
  fx <- .rho_spatial_fixture();mesh <- fx$mesh
  families <- list(gaussian=gaussian(),binomial=binomial(),poisson=poisson(),
    lognormal=lognormal(),Gamma=Gamma(link="log"),nbinom2=nbinom2(),tweedie=tweedie(),
    Beta=Beta(),betabinomial=betabinomial(),student=student(),
    truncated_poisson=truncated_poisson(),truncated_nbinom2=truncated_nbinom2(),
    delta_lognormal=delta_lognormal(),delta_gamma=delta_gamma(),ordinal_probit=ordinal_probit(),
    nbinom1=nbinom1(),binomial_probit=binomial(link="probit"),binomial_cloglog=binomial(link="cloglog"),
    multinomial=multinomial())
  for(fname in names(families)) {
    dat <- fx$data;n <- nrow(dat);v <- (seq_len(n)-1L)%/%4L;lhs <- "y"
    dat$y <- switch(fname,gaussian=sin(seq_len(n)),student=sin(seq_len(n)),
      Beta=.15+.7*(v%%5)/4,ordinal_probit=as.integer(v%%3+1L),
      binomial=as.integer(v%%2),binomial_probit=as.integer(v%%2),binomial_cloglog=as.integer(v%%2),
      betabinomial=as.integer(v%%5),poisson=as.integer(v%%4),nbinom2=as.integer(v%%4),nbinom1=as.integer(v%%4),
      truncated_poisson=as.integer(v%%3+1L),truncated_nbinom2=as.integer(v%%3+1L),
      tweedie=ifelse(v%%3==0,0,.5+(v%%5)/3),delta_lognormal=ifelse(v%%3==0,0,.5+(v%%5)/3),
      delta_gamma=ifelse(v%%3==0,0,.5+(v%%5)/3),.5+(v%%5)/3)
    if(fname=="betabinomial") {dat$failure <- 5L-dat$y;lhs <- "cbind(y,failure)"}
    projection_data <- dat
    if(fname=="multinomial") {
      dat <- fx$data[fx$data$trait=="t1",];dat$trait <- factor("category")
      dat$y <- factor(rep(1:3,length.out=nrow(dat)))
      projection_data <- dat[rep(seq_len(nrow(dat)),each=2L),]
      mesh <- make_mesh(projection_data,c("x","ycoord"),cutoff=.15)
    } else mesh <- fx$mesh
    for(mode in c("indep","common","dep","latent","latent_psi")) for(r in c(0,.35,1)) {
      helper <- if(mode=="common") "indep" else if(grepl("latent",mode)) "latent" else mode
      extra <- switch(mode,common=",common=TRUE",latent=",d=1",latent_psi=",d=1,unique=TRUE","")
      text <- paste0(lhs,"~0+trait+spatial_",helper,"(0+trait|group,mesh=mesh",extra,",rho=",r,")")
      a <- tryCatch(.rho_capture_payload(as.formula(text),dat,family=families[[fname]]),error=identity)
      if(inherits(a,"error")) {
        old <- tryCatch(.rho_capture_payload(as.formula(sub(paste0(",rho=",r),"",text,fixed=TRUE)),dat,family=families[[fname]]),error=identity)
        expect_true(inherits(old,"error"),info=paste(fname,mode,r))
        expect_identical(conditionMessage(a),conditionMessage(old));next
      }
      A <- as.matrix(mesh$A_st[match(levels(dat$group),as.character(projection_data$group)),,drop=FALSE])
      Q <- as.matrix(mesh$spde$c0+2*mesh$spde$g1+mesh$spde$g2)
      K <- A %*% solve(Q,t(A));Kref <- r*K;diag(Kref) <- diag(K)-1e-8
      dimnames(Kref) <- list(levels(dat$group),levels(dat$group))
      group <- if(grepl("latent",mode)) "group" else "0+trait|group"
      fref <- as.formula(paste0(lhs,"~0+trait+phylo_",helper,"(",group,",A=Kref",extra,")"))
      b <- .rho_capture_payload(fref,dat,family=families[[fname]])
      # Some legacy phylogenetic families map off their Psi companion, while
      # the spatial model retains it. Encode the SAME whole S through dep;
      # never remove spatial Psi to make the comparator agree.
      composite <- mode=="latent_psi" && b$data$use_phylo_diag==0L
      if(composite) b <- .rho_capture_payload(as.formula(paste0(lhs,
        "~0+trait+phylo_dep(0+trait|group,A=Kref)")),dat,family=families[[fname]])
      oa <- do.call(TMB::MakeADFun,c(a,list(DLL="gllvmTMB",silent=TRUE)))
      ob <- do.call(TMB::MakeADFun,c(b,list(DLL="gllvmTMB",silent=TRUE)))
      pa <- oa$par;pb <- ob$par
      pa[names(pa)=="theta_rr_spde_lv"] <- .4
      pa[names(pa)=="log_tau_spde"] <- -log(if(mode=="latent_psi") .3 else .4)
      pb[names(pb)=="theta_rr_phy"] <- .4
      pb[names(pb)=="loglambda_phy"] <- log(.4^2)
      pb[names(pb)=="log_sd_phy_diag"] <- log(.3)
      ref_parameters <- function(x) {
        z <- pb
        common <- intersect(setdiff(names(x),c("theta_rr_spde_lv","log_tau_spde","log_kappa_spde")),names(z))
        for(nm in common) z[names(z)==nm] <- x[names(x)==nm]
        L <- matrix(x[names(x)=="theta_rr_spde_lv"],4,1)
        C <- t(chol(tcrossprod(L)+diag(exp(-2*x[names(x)=="log_tau_spde"]))))
        z[names(z)=="theta_rr_phy"] <- c(diag(C),C[lower.tri(C)])
        z
      }
      if(composite) pb <- ref_parameters(pa)
      va <- oa$fn(pa);vb <- ob$fn(pb);ga <- oa$gr(pa);gb <- ob$gr(pb)
      na <- names(pa);nb <- names(pb)
      if(mode %in% c("indep","common")) {
        idx <- na=="log_tau_spde"
        ga[idx] <- ga[idx]*if(mode=="common") -.5 else -1/.4
        na[idx] <- if(mode=="common") "loglambda_phy" else "theta_rr_phy"
      } else {
        na[na=="theta_rr_spde_lv"] <- "theta_rr_phy"
        idx <- na=="log_tau_spde";ga[idx] <- -ga[idx];na[idx] <- "log_sd_phy_diag"
      }
      if(composite) {
        selected <- which(names(pa)!="log_kappa_spde");h <- 1e-5
        gb <- vapply(selected,function(j) {
          up <- down <- pa;up[j] <- up[j]+h;down[j] <- down[j]-h
          (ob$fn(ref_parameters(up))-ob$fn(ref_parameters(down)))/(2*h)
        },numeric(1))
        ga <- oa$gr(pa);ord <- selected
        ob$fn(pb)
      } else ord <- match(make.unique(nb),make.unique(na))
      expect_false(anyNA(ord))
      expect_true(abs(va-vb)/(1+abs(vb))<1e-7,info=paste(fname,mode,r,"nll"))
      expect_true(max(abs(ga[ord]-gb)/(1+abs(gb)))<2e-5,info=paste(fname,mode,r,"gradient"))
      expect_true(max(abs(oa$report()$eta-ob$report()$eta))<1e-6,info=paste(fname,mode,r,"eta"))
      TMB::FreeADFun(oa);TMB::FreeADFun(ob)
    }
  }
})
