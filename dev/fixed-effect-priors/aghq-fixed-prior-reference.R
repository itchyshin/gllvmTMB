# Bounded numerical comparison; not an interval coverage study.
pkgload::load_all(quiet=TRUE,compile=FALSE)
normal_rule<-function(n){m<-matrix(0,n,n);m[cbind(1:(n-1),2:n)]<-sqrt(1:(n-1));m<-m+t(m);e<-eigen(m,symmetric=TRUE);list(z=e$values,w=e$vectors[1,]^2)}
rule<-normal_rule(81); check<-normal_rule(161)
criterion<-function(p,x,y,r){a<-p[1:3];b<-p[4:6];l<-p[7:9];n<-length(x);q<-length(r$z);eta<-outer(x,b)+matrix(a,n,3,byrow=TRUE);ll<-matrix(0,n,q)
 for(j in 1:3){e<-outer(eta[,j],rep(1,q))+outer(rep(1,n),r$z*l[j]);ll<-ll+pnorm(e,log.p=TRUE)*y[j,]+pnorm(e,lower.tail=FALSE,log.p=TRUE)*(1-y[j,])}
 peak<-apply(ll,1,max);-sum(peak+log(rowSums(exp(ll-peak)*rep(r$w,each=n))))+sum(l*l)/(2*.75^2)-sum(dnorm(p[1:6],0,2,log=TRUE))}
results<-list()
for(rep in 1:3){set.seed(846+rep);n<-60L;x<-as.numeric(scale(seq(-2,2,length.out=n)))/2;z<-rnorm(n);a<-c(-.3,.1,.4);b<-c(.6,-.4,.3);l<-c(.5,-.3,.4)
 dat<-expand.grid(trait=factor(c('a','b','c')),unit=factor(seq_len(n)));dat$x<-rep(x,each=3);eta<-rep(a,n)+rep(b,n)*dat$x+rep(l,n)*rep(z,each=3);dat$value<-rbinom(3*n,1,pnorm(eta));y<-matrix(dat$value,nrow=3)
 pri<-data.frame(coefficient=c(paste0('trait',letters[1:3]),paste0('trait',letters[1:3],':x')),mean=0,sd=2)
 fit<-suppressWarnings(gllvmTMB(value~0+trait+trait:x+latent(0+trait|unit,d=1,unique=FALSE),dat,trait='trait',unit='unit',family=binomial('probit'),control=gllvmTMBcontrol(fixed_effect_priors=pri,loading_ridge=.75,aghq=9L,aghq_n_adapt=150L,aghq_multistart=TRUE,svd_start=FALSE,n_init=1L)))
 p<-unname(fit$opt$par);ref<-nlminb(p,criterion,x=x,y=y,r=rule,control=list(eval.max=2000,iter.max=800));atfit<-criterion(p,x,y,check);atref<-criterion(ref$par,x,y,check)
 results[[rep]]<-list(aghq_used=fit$aghq$used,aghq_converged=fit$aghq$converged,aghq_par=p,reference=ref,objective_at_aghq=atfit,objective_at_reference=atref,check_gap=atref-ref$objective,aghq_reported=fit$objective_components$optimization_nll)
 cat('rep',rep,'used',fit$aghq$used,'converged',fit$aghq$converged,'refcode',ref$convergence,'objective_gap',atfit-atref,'quad_gap',atref-ref$objective,'aghq_objective_gap',fit$objective_components$optimization_nll-atfit,'\n');flush.console()
}
saveRDS(results,'/tmp/aghq-fixed-prior-reference.rds')
