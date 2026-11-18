suppressMessages(devtools::load_all(".", quiet = TRUE))
set.seed(7); sp <- c("A","B","C"); n_po<-180; n_sv<-90
## A REAL shared spatial field, sampled at each arm's OWN locations.
fieldf <- function(x,y) 1.1*sin(x/1.6) * cos(y/2.1)
po <- data.frame(x=runif(n_po,0,10), y=runif(n_po,0,10))
sv <- data.frame(x=runif(n_sv,0,10), y=runif(n_sv,0,10))
ef <- function(x,y) 0.7*sin(x/2.5)+0.5*cos(y/3)
for (nm in c("po","sv")) { z <- get(nm); z$env <- ef(z$x,z$y); z$fld <- fieldf(z$x,z$y); assign(nm,z) }
mu<-mean(c(po$env,sv$env)); sdv<-sd(c(po$env,sv$env))
po$env<-(po$env-mu)/sdv; sv$env<-(sv$env-mu)/sdv
mk <- function(loc,src,off) do.call(rbind, lapply(seq_along(sp), function(j)
  data.frame(site=paste0(src,"_",seq_len(nrow(loc))), x=loc$x, y=loc$y,
    env=loc$env, trait=sp[j], src=src,
    value=rpois(nrow(loc), exp(off[j]+c(0.9,-0.4,0.5)[j]*loc$env + loc$fld)))))
d <- rbind(mk(po,"po",c(1.1,0.8,0.9)), mk(sv,"survey",c(0.4,0.2,0.3)))
d$trait<-factor(d$trait,levels=sp); d$src<-factor(d$src); d$site<-factor(d$site)
cat("shared site ids:", length(intersect(unique(d$site[d$src=="po"]),
    unique(d$site[d$src=="survey"]))), "| shared coords:",
    length(intersect(paste(po$x,po$y), paste(sv$x,sv$y))), "\n")
m <- make_mesh(d, xy_cols=c("x","y"), cutoff=0.4)
cat("mesh: A", nrow(m$A_st),"x", ncol(m$A_st), " long rows", nrow(d), "\n")
info <- function(lbl, fml) {
  t0<-Sys.time()
  f <- try(suppressWarnings(suppressMessages(gllvmTMB(fml,data=d,trait="trait",
       unit="site",family=poisson(),mesh=m,silent=TRUE))),silent=TRUE)
  if(inherits(f,"try-error")){cat(lbl,"ERROR\n");return(invisible(NULL))}
  b<-f$opt$par[names(f$opt$par)=="b_fix"]; e<-unname(b[grep(":env$",f$X_fix_names)])
  cat(sprintf("%-22s conv %s | iters %-3s | obj %9.3f | npar %2d | slopes %.3f %.3f %.3f | %.1fs\n",
    lbl,f$opt$convergence,ifelse(is.null(f$opt$iterations),"NA",f$opt$iterations),
    f$opt$objective,length(f$opt$par),e[1],e[2],e[3],
    as.numeric(difftime(Sys.time(),t0,units="secs"))))
  invisible(f$opt$objective)
}
cat("true env slopes: 0.900 -0.400 0.500  (a REAL shared field is present)\n")
o0 <- info("no spatial term",   value ~ 0+trait+trait:env+src)
o1 <- info("spatial_latent d=1",value ~ 0+trait+trait:env+src+spatial_latent(0+trait|site,d=1))
o2 <- info("spatial_dep",       value ~ 0+trait+trait:env+src+spatial_dep(0+trait|site))
if(!is.null(o0)&&!is.null(o1)) cat(sprintf("\ndelta logLik (no-spatial vs latent d=1): %.2f\n", o0-o1))
