# Fixed-truth pilot data; no fitting or network side effects.
pilot_manifest <- function() {
  g <- expand.grid(family=c('binomial','gaussian','poisson'), n=c(100L,400L), strength=c(.5,2), rep=1:3, stringsAsFactors=FALSE)
  g$task <- seq_len(nrow(g)); g$data_seed <- 181000000L + g$task * 101L
  g$init_seed <- 182000000L + g$task * 101L
  first <- which(g$rep==1 & ((g$n==100 & g$strength==.5) | (g$n==400 & g$strength==2)))
  g$stage <- ifelse(g$task %in% first,'24','144'); g
}
pilot_fixture <- function(cell) {
  set.seed(cell$data_seed)
  L <- cell$strength * matrix(c(1,0,.25,1,.75,1,-.5,.8,.8,-.4,-.6,-.7),6,2,byrow=TRUE)
  beta <- c(-.6,-.3,0,.3,.6,-.2); alpha <- c(.4,-.3)
  x <- as.numeric(scale(seq(-1,1,length.out=cell$n)))
  z <- matrix(rnorm(cell$n*2),cell$n,2)
  u <- matrix(rnorm(cell$n*6,sd=.4),cell$n,6)
  eta <- sweep((z+outer(x,alpha)) %*% t(L)+u,2,beta,'+')
  visits <- if(cell$family=='binomial') 1L else 2L
  d <- expand.grid(unit=seq_len(cell$n),trait=seq_len(6),visit=seq_len(visits))
  d$eta <- eta[cbind(d$unit,d$trait)]; d$x <- x[d$unit]
  d$trials <- c(2L,7L,20L)[1L+(d$unit+d$trait-2L)%%3L]
  d$true_mean <- switch(cell$family,binomial=pnorm(d$eta),gaussian=d$eta,poisson=exp(d$eta))
  d$y <- switch(cell$family,binomial=rbinom(nrow(d),d$trials,d$true_mean),gaussian=rnorm(nrow(d),d$eta,.7),poisson=rpois(nrow(d),d$true_mean))
  d$successes <- d$y; d$failures <- d$trials-d$y
  d$row_id <- seq_len(nrow(d)); d$unit <- factor(d$unit); d$trait <- factor(paste0('t',d$trait),levels=paste0('t',1:6))
  dimnames(L) <- list(levels(d$trait),c('axis1','axis2'))
  B <- as.numeric(L %*% alpha); names(B) <- levels(d$trait)
  truth <- list(Lambda=L,beta=setNames(beta,levels(d$trait)),alpha=alpha,B=B,shared=tcrossprod(L),unique=diag(.16,6),total=tcrossprod(L)+diag(.16,6),residual_sd=.7)
  list(cell=cell,data=d,truth=truth,z=z,u=u)
}
pilot_alignment <- function(fixture, data=fixture$data, truth=fixture$truth) {
  c(row_map=identical(data$row_id,seq_len(nrow(fixture$data))) && identical(as.character(data$trait),as.character(fixture$data$trait)) && identical(as.character(data$unit),as.character(fixture$data$unit)), truth=isTRUE(all.equal(truth$B,as.numeric(truth$Lambda %*% truth$alpha),check.attributes=FALSE)) && abs(truth$B[3])<1e-12 && truth$B[1]>0 && truth$B[4]<0)
}

# Campaign seeds are disjoint from both pilot seed streams.
full_manifest <- function() {
  g <- expand.grid(family=c('binomial','gaussian','poisson'), n=c(100L,400L), strength=c(.5,2), rep=seq_len(500L), stringsAsFactors=FALSE)
  g$task <- seq_len(nrow(g)); g$data_seed <- 193000000L+g$task*101L
  g$init_seed <- 194000000L+g$task*101L
  stopifnot(nrow(g)==6000L,!anyDuplicated(c(g$data_seed,g$init_seed)), !any(c(g$data_seed,g$init_seed) %in% c(pilot_manifest()$data_seed,pilot_manifest()$init_seed)))
  g
}
