## Pure receipt mutation tests; fabricated positives stay in scratch, never evidence.
library(gllvmTMB)
repo<-getwd(); root<-'/private/tmp/gllvm-tree-axis-latent-20260830'
orig<-file.path(root,'results'); result<-file.path(root,'repaired-nlminb-7c88')
prov<-jsonlite::read_json(file.path(result,'provenance.json'),simplifyVector=TRUE)
fx<-list()
for (i in 2:3) {
 r<-readRDS(file.path(orig,paste0('fit-M',i,'.rds')))
 r$id<-paste0('N',i);r$spec$original<-paste0('M',i);r$provenance<-prov
 r$convergence<-0L
 r$restart_snapshots$attempts<-lapply(r$restart_snapshots$attempts,function(a){a$convergence<-0L;a})
 fx[[r$id]]<-r
 w<-r;w$id<-paste0('NW',i);w$spec$shape<-'wide';w$spec$starts<-NULL;w$spec$start<-1L
 w$optimizer_calls<-w$optimizer_calls[1];w$optimizer_entries<-1L;fx[[w$id]]<-w
}
run<-function(name,modify,expected) {
 d<-tempfile(paste0('validator-mock-',name,'-'),tmpdir=result);dir.create(d)
 file.copy(file.path(result,c('provenance.json','morphology-continuity.rds')),d)
 inputs<-modify(fx)
 for(id in names(inputs))saveRDS(inputs[[id]],file.path(d,paste0('fit-',id,'.rds')))
 Sys.setenv(GLLVM_TREE_AXIS_RESULTS=d,GLLVM_TREE_AXIS_ORIGINAL=orig)
 log<-file.path(d,'validator.log')
 code<-system2('Rscript',c('--vanilla',file.path(repo,'dev/tree-axis-latent/validate.R'),'--repaired'),stdout=log,stderr=log)
 got<-code==0L
 cat(name,': exit=',code,' expected_pass=',expected,'\n',sep='')
 if(!identical(got,expected))stop('Unexpected mock result: ',name,' inspect ',log)
}
run('positive',identity,TRUE)
run('start-code',function(x){x$N2$restart_snapshots$attempts[[2]]$convergence<-1L;x},FALSE)
run('wide-start',function(x){x$NW2$optimizer_calls[[1]]$start[1]<-999;x},FALSE)
run('old-provenance',function(x){x$N3$provenance<-NULL;x},FALSE)
run('missing-long',function(x){x$N3<-NULL;x},FALSE)
run('covariance',function(x){x$N3$restart_snapshots$attempts[[2]]$covariance$unit$unique<-99;x},FALSE)
cat('REPAIRED_VALIDATOR_MOCK_CONTROLS_PASS_NO_FITS\n')
