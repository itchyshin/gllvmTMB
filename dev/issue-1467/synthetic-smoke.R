library(gllvmTMB)
set.seed(1467)
n <- 60L; p <- 4L
x <- rep(c(0,1),each=n/2)
z <- rnorm(n)+0.6*x
L <- c(0.8,-0.6,0.5,-0.3)
dat <- expand.grid(article_id=seq_len(n),analysis_word=paste0('word',seq_len(p)))
dat$Fox_Nativeness <- x[dat$article_id]
dat$word_present <- rbinom(n*p,1,pnorm(-0.2+z[dat$article_id]*L[as.integer(dat$analysis_word)]))
for (d in c(1L,2L)) {
 cat('\nDIMENSION',d,'\n')
 t <- system.time(m <- gllvmTMB(word_present ~ 0 + analysis_word + latent(0 + trait | article_id,d=d,lv=~Fox_Nativeness),trait='analysis_word',unit='article_id',family=binomial(link='probit'),data=dat))
 print(t); print(summary(m)); print(extract_lv_effects(m))
 for (rot in c('none','varimax')) {
  cat('PLOT',rot,'\n')
  tryCatch({p <- plot(m,type='ordination',rotation=rot); ggplot2::ggplot_build(p); cat('BUILD OK\n')},error=function(e)cat('ERROR:',conditionMessage(e),'\n'))
 }
 saveRDS(m,paste0(file.path(tempdir(), 'issue1467-smoke-d'),d,'.rds'))
}
