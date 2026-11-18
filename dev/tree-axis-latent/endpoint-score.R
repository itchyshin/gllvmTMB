#!/usr/bin/env Rscript
## Fixed-endpoint diagnostic ONLY. No optimization or new acceptance threshold.
## Reuses check-gaussian-likelihood.R's V = I %x% R + (X Sigma X') %x% K.
## A thin QR X=QZ gives a 100x100 coefficient subspace covariance V2;
## the orthogonal site subspace has covariance R. Differentiating
## .5(logdet V + e'V^-1e) gives .5(V^-1-aa'), a=V^-1e.
library(gllvmTMB)
source('dev/tree-axis-latent/fixture.R')
root<-'/private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88'
provenance<-jsonlite::read_json(file.path(root,'provenance.json'),simplifyVector=TRUE)
stopifnot(identical(normalizePath(find.package('gllvmTMB')),provenance$library),
 identical(digest::digest(file=file.path(provenance$library,'libs/gllvmTMB.so'),algo='sha256'),provenance$dll_sha256),
 identical(unname(tools::md5sum('dev/tree-axis-latent/fixture.R')),provenance$fixture_md5))
for(path in names(provenance$source_sha256)) stopifnot(identical(
 digest::digest(file=path,algo='sha256'),provenance$source_sha256[[path]]))
stopifnot(!file.exists(file.path(root,'endpoint-score.rds')),
 !length(list.files(root,pattern='^endpoint-score-N[23]-start[123]\\.rds$')))
f<-make_tree_axis_fixture('target')$community
Y<-as.matrix(f$wide[f$species]); n<-nrow(Y); p<-ncol(Y)
X<-cbind(1,f$sites$latitude); Xfixed<-model.matrix(~0+pathway+latitude:pathway,f$long)
qrx<-qr(X);stopifnot(qrx$rank==2L);Q<-qr.Q(qrx);Z<-crossprod(Q,X)
idx<-matrix(0L,p,2)
idx[1,1]<-1L;idx[2,2]<-2L; cursor<-2L
for(j in 1:2) for(i in seq.int(j+1,p)){cursor<-cursor+1L;idx[i,j]<-cursor}
stopifnot(cursor==99L)
independent<-function(outer,eps,phylo,score=TRUE) {
 stopifnot(setequal(unique(names(outer)),c('b_fix','theta_rr_B','theta_diag_B',
   'theta_dep_chol',if(phylo)'eta_column_coef_rho')))
 b<-outer[names(outer)=='b_fix']; rr<-outer[names(outer)=='theta_rr_B']
 theta<-outer[names(outer)=='theta_diag_B'];co<-outer[names(outer)=='theta_dep_chol']
 stopifnot(length(b)==4L,length(rr)==99L,length(theta)==p,length(co)==3L)
 Lambda<-matrix(0,p,2);Lambda[idx>0]<-rr[idx[idx>0]]
 psi<-exp(2*theta);R<-tcrossprod(Lambda)+diag(psi+exp(2*eps),p)
 L<-matrix(c(exp(co[1]),co[3],0,exp(co[2])),2,2);Sigma<-tcrossprod(L)
 rho<-if(phylo)plogis(outer[names(outer)=='eta_column_coef_rho']) else 0
 D<-diag(diag(f$K));K<-if(phylo)rho*f$K+(1-rho)*D else diag(p)
 E<-Y-matrix(drop(Xfixed%*%b),nrow=n,byrow=TRUE)
 E2<-crossprod(Q,E);Ep<-E-Q%*%E2;H<-Z%*%Sigma%*%t(Z)
 V2<-kronecker(diag(2),R)+kronecker(H,K)
 UR<-chol(R);U2<-chol(V2);Ri<-chol2inv(UR);Vi<-chol2inv(U2)
 e2<-as.vector(t(E2));a2<-drop(Vi%*%e2);Ap<-Ep%*%Ri
 value<-.5*(n*p*log(2*pi)+(n-2)*2*sum(log(diag(UR)))+2*sum(log(diag(U2)))+
   sum(Ep*Ap)+sum(e2*a2))
 if(!score)return(value)
 W<-Vi-tcrossprod(a2); gR<-(n-2)*Ri-crossprod(Ap);gH<-matrix(0,2,2);gK<-matrix(0,p,p)
 for(a in 1:2)for(b in 1:2) {
   block<-W[((a-1)*p+1):(a*p),((b-1)*p+1):(b*p)]
   if(a==b)gR<-gR+block
   gH[a,b]<-.5*sum(block*K);gK<-gK+.5*H[a,b]*block
 }
 gR<-.5*gR;gS<-t(Z)%*%gH%*%Z;gL<-2*gS%*%L;gLambda<-2*gR%*%Lambda
 A<-Ap+Q%*%matrix(a2,nrow=2,byrow=TRUE)
 grad<-outer*0
 grad[names(outer)=='b_fix']<- -drop(crossprod(Xfixed,as.vector(t(A))))
 grr<-numeric(99);grr[idx[idx>0]]<-gLambda[idx>0]
 grad[names(outer)=='theta_rr_B']<-grr
 grad[names(outer)=='theta_diag_B']<-2*psi*diag(gR)
 grad[names(outer)=='theta_dep_chol']<-c(gL[1,1]*L[1,1],gL[2,2]*L[2,2],gL[2,1])
 if(phylo)grad[names(outer)=='eta_column_coef_rho']<-sum(gK*(f$K-D))*rho*(1-rho)
 list(value=value,gradient=grad,unit=R-diag(exp(2*eps),p),Sigma=Sigma,K=K,rho=rho)
}
## The original spectral formula is retained as an independent value cross-check.
spectral<-function(outer,eps,phylo,a) {
 E<-Y-matrix(drop(Xfixed%*%outer[names(outer)=='b_fix']),nrow=n,byrow=TRUE)
 R<-a$unit+diag(exp(2*eps),p);U<-chol(R);Ui<-solve(U)
 ec<-eigen(t(Ui)%*%a$K%*%Ui,symmetric=TRUE)
 eg<-eigen(X%*%a$Sigma%*%t(X),symmetric=TRUE)
 scales<-base::outer(pmax(eg$values,0),ec$values)
 T<-t(eg$vectors)%*%E%*%Ui%*%ec$vectors
 .5*(length(Y)*log(2*pi)+n*2*sum(log(diag(U)))+sum(log1p(scales))+sum(T^2/(1+scales)))
}
out<-list(provenance=provenance,script_sha256=digest::digest(file='dev/tree-axis-latent/endpoint-score.R',algo='sha256'),
 outer_optimizer_calls=0L,method='Exact Gaussian QR marginal value and analytic score; deterministic directional central-difference checks',endpoints=list())
for(id in c('N2','N3')) {
 r<-readRDS(file.path(root,paste0('fit-',id,'.rds')));fit<-r$fit;phylo<-id=='N3'
 stopifnot(identical(as.numeric(t(Y)),as.numeric(fit$tmb_data$y)),
   identical(rownames(r$public$unit$total),f$species),
   identical(colnames(Xfixed),names(coef(fit))))
 obj<-TMB::MakeADFun(fit$tmb_data,fit$tmb_obj$env$parList(),map=fit$tmb_map,
   random=fit$random,DLL='gllvmTMB',silent=TRUE)
 for(i in 1:3) {
   par<-r$optimizer_calls[[i]]$result$par;a<-independent(par,r$gaussian$fixed_value,phylo)
   ref<-r$restart_snapshots$attempts[[i]]$covariance
   stopifnot(max(abs(a$unit-ref$unit$total))<1e-8,
     max(abs(a$Sigma-ref$column_coef$Sigma))<1e-8)
   if(phylo)stopifnot(max(abs(a$K-ref$column_coef$K_rho))<1e-8)
   v<-obj$fn(par);g<-as.numeric(obj$gr(par));sp<-spectral(par,r$gaussian$fixed_value,phylo,a)
   ## One deterministic normalized direction per parameter block, plus the
   ## analytic-score direction. No RNG or optimized line search is used.
   directions<-lapply(unique(names(par)),function(group){
     d<-sin(seq_along(par));d[names(par)!=group]<-0;d/sqrt(sum(d^2))})
   names(directions)<-unique(names(par))
   directions$score<-a$gradient/max(sqrt(sum(a$gradient^2)),1e-12)
   fd<-lapply(directions,function(d){
     exact<-sum(a$gradient*d)
     numeric<-vapply(c(1e-4,1e-5),function(h)
       (independent(par+h*d,r$gaussian$fixed_value,phylo,FALSE)-
        independent(par-h*d,r$gaussian$fixed_value,phylo,FALSE))/(2*h),numeric(1))
     list(analytic=exact,central_difference=numeric,error=numeric-exact)
   })
   key<-paste0(id,'-start',i)
   out$endpoints[[key]]<-list(receipt_md5=unname(tools::md5sum(file.path(root,paste0('fit-',id,'.rds')))),
     nll=a$value,retained_nll=r$optimizer_calls[[i]]$result$objective,tmb_nll=v,
     spectral_nll=sp,qr_minus_spectral=a$value-sp,qr_minus_tmb=a$value-v,
     independent_max_gradient=max(abs(a$gradient)),tmb_max_gradient=max(abs(g)),
     max_score_discrepancy=max(abs(a$gradient-g)),
     score_by_parameter_block=lapply(unique(names(par)),function(group){at<-names(par)==group
       list(group=group,independent=max(abs(a$gradient[at])),tmb=max(abs(g[at])),difference=max(abs(a$gradient[at]-g[at])))}),
     directional_checks=fd,rho=a$rho,gradient=a$gradient,tmb_gradient=g)
   message(key,' exact_grad=',max(abs(a$gradient)),' TMB_grad=',max(abs(g)),
     ' max_difference=',max(abs(a$gradient-g)))
   ## Stream each endpoint before progressing, preserving evidence on timeout.
   saveRDS(out$endpoints[[key]],file.path(root,paste0('endpoint-score-',key,'.rds')))
 }
 TMB::FreeADFun(obj)
}
path<-file.path(root,'endpoint-score.rds');stopifnot(!file.exists(path));saveRDS(out,path)
jsonlite::write_json(out,file.path(root,'endpoint-score.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)
cat('ENDPOINT_SCORE_DIAGNOSTIC_RECORDED_NO_OUTER_OPTIMIZATION\n')
