suppressMessages(devtools::load_all(".", quiet = TRUE))
set.seed(7); sp <- c("A","B","C"); n_po<-180; n_sv<-90
po <- data.frame(x=runif(n_po,0,10), y=runif(n_po,0,10))
sv <- data.frame(x=runif(n_sv,0,10), y=runif(n_sv,0,10))
ef <- function(x,y) 0.7*sin(x/2.5)+0.5*cos(y/3)
po$env<-ef(po$x,po$y); sv$env<-ef(sv$x,sv$y)
mu<-mean(c(po$env,sv$env)); sdv<-sd(c(po$env,sv$env))
po$env<-(po$env-mu)/sdv; sv$env<-(sv$env-mu)/sdv
mk <- function(loc,src,off) do.call(rbind, lapply(seq_along(sp), function(j)
  data.frame(site=paste0(src,"_",seq_len(nrow(loc))), x=loc$x, y=loc$y,
    env=loc$env, trait=sp[j], src=src,
    value=rpois(nrow(loc), exp(off[j]+c(0.9,-0.4,0.5)[j]*loc$env)))))
d <- rbind(mk(po,"po",c(1.1,0.8,0.9)), mk(sv,"survey",c(0.4,0.2,0.3)))
d$trait<-factor(d$trait,levels=sp); d$src<-factor(d$src); d$site<-factor(d$site)
cat("shared site ids:", length(intersect(unique(d$site[d$src=="po"]),
    unique(d$site[d$src=="survey"]))), "| shared coords:",
    length(intersect(paste(po$x,po$y), paste(sv$x,sv$y))), "\n")

## THE MESH MUST BE BUILT ON THE SAME LONG-FORMAT DATA
m <- make_mesh(d, xy_cols = c("x","y"), cutoff = 0.4)
cat("mesh class:", class(m)[1], "| A rows:", nrow(m$A_st), "| nodes:", ncol(m$A_st),
    "| long rows:", nrow(d), "\n")
info <- function(lbl, fml) {
  t0 <- Sys.time()
  f <- try(suppressWarnings(suppressMessages(gllvmTMB(fml, data=d, trait="trait",
       unit="site", family=poisson(), mesh=m, silent=TRUE))), silent=TRUE)
  if (inherits(f,"try-error")) { cat(sprintf("%-24s ERROR: %s", lbl,
      sub("^Error[^:]*: ","",as.character(f)))); return(invisible()) }
  b <- f$opt$par[names(f$opt$par)=="b_fix"]
  e <- unname(b[grep(":env$", f$X_fix_names)])
  cat(sprintf("%-24s conv %s | iters %-3s | obj %9.3f | npar %2d | slopes %.3f %.3f %.3f | %.1fs\n",
      lbl, f$opt$convergence, ifelse(is.null(f$opt$iterations),"NA",f$opt$iterations),
      f$opt$objective, length(f$opt$par), e[1], e[2], e[3],
      as.numeric(difftime(Sys.time(),t0,units="secs"))))
}
cat("true env slopes: 0.900 -0.400 0.500\n")
info("no spatial term",   value ~ 0+trait+trait:env+src)
info("spatial_dep",       value ~ 0+trait+trait:env+src+spatial_dep(0+trait|site))
info("spatial_latent d=1",value ~ 0+trait+trait:env+src+spatial_latent(0+trait|site,d=1))
