suppressMessages(devtools::load_all("/private/tmp/gtmb-item2", quiet=TRUE))
d<-3L
Lam<-matrix(c(1.2,0.2,0.0, 0.9,0.6,0.1, 0.3,1.0,0.4, 0.7,0.4,0.9, 1.0,0.5,0.2, -0.5,0.8,0.6),6,byrow=TRUE)
rn<-c("g","b","p","o","cat:2","cat:3"); R_true<-cov2cor(Lam%*%t(Lam)); dimnames(R_true)<-list(rn,rn)
build<-function(seed,N=500L,reps=6L,Ko=4L){set.seed(seed);Z<-matrix(rnorm(N*d),N,d);u<-Z%*%t(Lam);taus<-c(-Inf,sort(rnorm(Ko-1L)),Inf);rows<-list()
 for(i in seq_len(N))for(r in seq_len(reps)){yg<-u[i,1]+rnorm(1,sd=.3);yb<-rbinom(1,1,plogis(u[i,2]));yp<-rpois(1,exp(u[i,3]+0.3));yo<-as.integer(cut(u[i,4]+rnorm(1),breaks=taus));pc<-c(1,exp(u[i,5]),exp(u[i,6]));pc<-pc/sum(pc);yc<-sample.int(3L,1L,prob=pc)
  rows[[length(rows)+1L]]<-data.frame(unit=i,trait="g",family="g",value=yg);rows[[length(rows)+1L]]<-data.frame(unit=i,trait="b",family="b",value=yb);rows[[length(rows)+1L]]<-data.frame(unit=i,trait="p",family="p",value=yp);rows[[length(rows)+1L]]<-data.frame(unit=i,trait="o",family="o",value=yo);rows[[length(rows)+1L]]<-data.frame(unit=i,trait="cat",family="m",value=yc)}
 d2<-do.call(rbind,rows);d2$unit<-factor(d2$unit,levels=seq_len(N));d2$trait<-factor(d2$trait);d2$family<-factor(d2$family);d2}
fam<-list(g=gaussian(),b=binomial(),p=poisson(),o=ordinal_probit(),m=multinomial());attr(fam,"family_var")<-"family"
pairs<-rbind(c("g","cat:2"),c("g","cat:3"),c("b","cat:2"),c("p","cat:3"),c("o","cat:2"),c("g","b"),c("p","o"))
acc<-vector("list",nrow(pairs)); nconv<-0L
for(seed in 1:5){dat<-build(seed)
 fit<-tryCatch(suppressWarnings(suppressMessages(gllvmTMB(value~0+trait+latent(0+trait|unit,d=3,unique=FALSE),data=dat,family=fam,trait="trait",unit="unit"))),error=function(e)NULL)
 if(is.null(fit)||fit$opt$convergence!=0)next; nconv<-nconv+1L
 S<-suppressMessages(extract_Sigma(fit,level="unit",part="shared",link_residual="none"));Rh<-cov2cor(S$Sigma)
 for(k in seq_len(nrow(pairs)))acc[[k]]<-c(acc[[k]],Rh[pairs[k,1],pairs[k,2]])}
cat("converged:",nconv,"/5\n\npair            true    mean_hat   mcse\n")
for(k in seq_len(nrow(pairs)))cat(sprintf("%-14s %+.3f  %+.3f   %.3f\n",paste(pairs[k,],collapse="~"),R_true[pairs[k,1],pairs[k,2]],mean(acc[[k]]),sd(acc[[k]])/sqrt(length(acc[[k]]))))
