# Fixed-rho native Laplace equivalence; no outer optimizer or recovery claim.
test_that("every admitted native family and structured intercept mode matches effective K", {
  fx <- .rho_fixed_fixture(3L); K <- fx$K; Q <- fx$Q
  tree <- ape::read.tree(text="((g1:0.6,g2:0.6):0.4,(g3:0.5,g4:0.5):0.5);")
  families <- list(gaussian=gaussian(),binomial=binomial(),poisson=poisson(),
    lognormal=lognormal(),Gamma=Gamma(link="log"),nbinom2=nbinom2(),tweedie=tweedie(),
    Beta=Beta(),betabinomial=betabinomial(),student=student(),
    truncated_poisson=truncated_poisson(),truncated_nbinom2=truncated_nbinom2(),
    delta_lognormal=delta_lognormal(),delta_gamma=delta_gamma(),ordinal_probit=ordinal_probit(),
    nbinom1=nbinom1(),multinomial=multinomial(),
    binomial_probit=binomial(link="probit"),binomial_cloglog=binomial(link="cloglog"))
  fid <- c(0:16,1,1)
  records <- list(); record_id <- 0L
  save_record <- function(row) {
    record_id <<- record_id+1L; records[[record_id]] <<- row
    path <- Sys.getenv("RHO_FAMILY_EVIDENCE","")
    if(nzchar(path)) write.csv(do.call(rbind,records),path,row.names=FALSE)
  }
  for (family_index in seq_along(families)) {
    family_name <- names(families)[family_index]
    dat <- if(family_name=="multinomial") .rho_fixed_fixture(1L)$data else fx$data
    n <- nrow(dat); vector <- (seq_len(n)-1L)%/%nlevels(dat$trait)
    lhs <- "y"
    dat$y <- switch(family_name,
      gaussian=sin(seq_len(n)),student=sin(seq_len(n)),
      Beta=.15+.7*(vector%%5)/4,
      ordinal_probit=as.integer(vector%%3+1L),multinomial=factor(vector%%3+1L),
      binomial=as.integer(vector%%2),binomial_probit=as.integer(vector%%2),binomial_cloglog=as.integer(vector%%2),
      betabinomial=as.integer(vector%%5),
      poisson=as.integer(vector%%4),nbinom2=as.integer(vector%%4),nbinom1=as.integer(vector%%4),
      truncated_poisson=as.integer(vector%%3+1L),truncated_nbinom2=as.integer(vector%%3+1L),
      tweedie=ifelse(vector%%3==0,0,.5+(vector%%5)/3),
      delta_lognormal=ifelse(vector%%3==0,0,.5+(vector%%5)/3),
      delta_gamma=ifelse(vector%%3==0,0,.5+(vector%%5)/3),.5+(vector%%5)/3)
    if(family_name=="betabinomial") {dat$failure <- 5L-dat$y; lhs <- "cbind(y,failure)"}
    for(strength in c(0,.35,1)) for(source in c("dense","sparse","kernel","tree")) for(mode in c("dep","indep","common","latent","latent_psi")) {
      column <- if(mode=="common") "indep" else if(grepl("latent",mode)) "latent" else mode
      prefix <- switch(source,sparse="animal",kernel="kernel","phylo")
      group <- if(grepl("latent",mode)||source=="kernel") "group" else "0+trait|group"
      argument <- switch(source,dense="A=K",sparse="Ainv=Q",kernel="K=K",tree="tree=tree")
      extra <- switch(mode,common=",common=TRUE",latent=",d=1",latent_psi=",d=1,unique=TRUE","")
      text <- paste0(lhs,"~0+trait+",prefix,"_",column,"(",group,",",argument,extra,",rho=",strength,")")
      f <- as.formula(text,env=environment())
      payload <- tryCatch(.rho_capture_payload(f,dat,family=families[[family_index]]),error=identity)
      row <- data.frame(family=family_name,source=source,mode=mode,rho=strength,status="",nll_error=NA_real_,gradient_error=NA_real_,eta_error=NA_real_,reason="")
      if(inherits(payload,"error")) {
        old <- as.formula(sub(paste0(",rho=",strength), "",text,fixed=TRUE),env=environment())
        legacy <- tryCatch(.rho_capture_payload(old,dat,family=families[[family_index]]),error=identity)
        expect_true(inherits(legacy,"error"),info=paste(family_name,source,mode))
        if(!inherits(legacy,"error")) stop("New attenuation rejected a supported legacy family cell")
        expect_identical(conditionMessage(payload),conditionMessage(legacy))
        row$status <- "legacy_rejection_preserved";row$reason <- conditionMessage(payload)
        save_record(row);next
      }
      expect_true(all(payload$data$family_id_vec==fid[family_index]))
      baseK <- if(source=="tree") ape::vcv(tree,corr=TRUE) else K
      baseK <- baseK[levels(dat$group),levels(dat$group)]
      Kref <- strength*baseK;diag(Kref) <- diag(baseK)
      # Dense legacy helper adds 1e-8. Sparse rr routes do not; undo only
      # that reference conditioning, never renormalize source diagonals.
      if(source %in% c("sparse","tree") && mode!="common") diag(Kref) <- diag(Kref)-1e-8
      ref_group <- if(grepl("latent",mode)) "group" else "0+trait|group"
      reference <- as.formula(paste0(lhs,"~0+trait+phylo_",column,"(",ref_group,",A=Kref",extra,")"),env=environment())
      ref <- .rho_capture_payload(reference,dat,family=families[[family_index]])
      a <- do.call(TMB::MakeADFun,c(payload,list(DLL="gllvmTMB",silent=TRUE)))
      b <- do.call(TMB::MakeADFun,c(ref,list(DLL="gllvmTMB",silent=TRUE)))
      point <- function(obj) {
        p <- obj$par;p[names(p)=="b_fix"] <- .1
        p[names(p)=="theta_rr_phy"] <- .4
        p[names(p)=="loglambda_phy"] <- log(.4^2)
        p[names(p)=="log_sd_phy_diag"] <- log(.3)
        p
      }
      pa <- point(a);pb <- point(b)
      va <- a$fn(pa);vb <- b$fn(pb)
      ga <- as.numeric(a$gr(pa));gb <- as.numeric(b$gr(pb))
      na <- names(pa);nb <- names(pb)
      if(mode=="common" && source=="kernel") {
        idx <- which(na=="theta_rr_phy");ga[idx] <- ga[idx]*.2;na[idx] <- "loglambda_phy"
      }
      ord <- match(make.unique(nb),make.unique(na))
      expect_false(anyNA(ord))
      row$nll_error <- abs(va-vb)/(1+abs(vb))
      row$gradient_error <- max(abs(ga[ord]-gb)/(1+abs(gb)))
      row$eta_error <- max(abs(a$report()$eta-b$report()$eta))
      # Predeclared scale-aware tolerances; do not loosen after a failure.
      expect_true(is.finite(row$nll_error)&&row$nll_error<1e-7,info=paste(family_name,source,mode,"nll"))
      expect_true(is.finite(row$gradient_error)&&row$gradient_error<2e-5,info=paste(family_name,source,mode,"gradient"))
      expect_true(is.finite(row$eta_error)&&row$eta_error<1e-6,info=paste(family_name,source,mode,"eta"))
      row$status <- "evaluated";save_record(row)
      TMB::FreeADFun(a);TMB::FreeADFun(b)
    }
  }
})
