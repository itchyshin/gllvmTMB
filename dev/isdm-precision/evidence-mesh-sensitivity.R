suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(fmesher))
run <- function(max_edge, cutoff, seed = 7) {
  set.seed(seed); sp <- c("A","B","C")
  n_po <- 180; n_sv <- 90
  po <- data.frame(x=runif(n_po,0,10), y=runif(n_po,0,10))
  sv <- data.frame(x=runif(n_sv,0,10), y=runif(n_sv,0,10))
  ef <- function(x,y) 0.7*sin(x/2.5)+0.5*cos(y/3)
  po$env <- ef(po$x,po$y); sv$env <- ef(sv$x,sv$y)
  mu <- mean(c(po$env,sv$env)); sdv <- sd(c(po$env,sv$env))
  po$env <- (po$env-mu)/sdv; sv$env <- (sv$env-mu)/sdv
  mk <- function(loc,src,off) do.call(rbind, lapply(seq_along(sp), function(j)
    data.frame(site=paste0(src,"_",seq_len(nrow(loc))), x=loc$x, y=loc$y,
      env=loc$env, trait=sp[j], src=src,
      value=rpois(nrow(loc), exp(off[j]+c(0.9,-0.4,0.5)[j]*loc$env)))))
  d <- rbind(mk(po,"po",c(1.1,0.8,0.9)), mk(sv,"survey",c(0.4,0.2,0.3)))
  d$trait<-factor(d$trait,levels=sp); d$src<-factor(d$src); d$site<-factor(d$site)
  loc <- unique(d[,c("site","x","y")])
  m <- fm_mesh_2d(loc=as.matrix(loc[,c("x","y")]),
                  max.edge=c(max_edge, max_edge*2.5), cutoff=cutoff)
  t0 <- Sys.time()
  f <- try(suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0+trait+trait:env+src, data=d, trait="trait", unit="site",
    family=poisson(), mesh=m, silent=TRUE))), silent=TRUE)
  if (inherits(f,"try-error")) return(data.frame(max_edge,cutoff,nodes=m$n,
      conv=NA,secs=NA,s1=NA,s2=NA,s3=NA))
  b <- f$opt$par[names(f$opt$par)=="b_fix"]
  e <- unname(b[grep(":env$", f$X_fix_names)])
  data.frame(max_edge, cutoff, nodes=m$n, conv=f$opt$convergence,
             secs=round(as.numeric(difftime(Sys.time(),t0,units="secs")),1),
             s1=round(e[1],3), s2=round(e[2],3), s3=round(e[3],3))
}
grid <- rbind(run(0.6,0.2), run(0.9,0.3), run(1.2,0.4), run(1.8,0.6),
              run(2.5,0.9), run(4.0,1.5))
cat("true env slopes: 0.900 -0.400 0.500\n\n"); print(grid, row.names=FALSE)
