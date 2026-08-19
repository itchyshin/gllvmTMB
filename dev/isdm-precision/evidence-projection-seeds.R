suppressMessages(devtools::load_all(".", quiet = TRUE))
sp <- c("A","B","C"); TRUE_B <- c(0.9,-0.4,0.5)
one <- function(seed) {
  set.seed(seed); n <- 200
  lon <- runif(n,-113.8,-112.6); lat <- runif(n,53.8,55.2)   # inside zone 12
  dd <- suppressMessages(suppressWarnings(
        add_utm_columns(data.frame(site=factor(seq_len(n)),lon=lon,lat=lat),
                        ll_names=c("lon","lat"))))
  X<-dd$X; Y<-dd$Y
  fld <- 1.0*sin(X/40)*cos(Y/40)
  ev  <- as.numeric(scale(0.7*sin(X/70)+0.5*cos(Y/60)))
  d <- do.call(rbind, lapply(seq_along(sp), function(j)
    data.frame(site=dd$site,lon=lon,lat=lat,ux=X,uy=Y,env=ev,trait=sp[j],
      value=rpois(n, exp(0.8 + TRUE_B[j]*ev + fld)))))
  d$trait <- factor(d$trait, levels=sp)
  fitm <- function(xy,cut){
    m <- make_mesh(d, xy_cols=xy, cutoff=cut)
    f <- try(suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0+trait+trait:env+spatial_latent(0+trait|site,d=1),
      data=d,trait="trait",unit="site",family=poisson(),mesh=m,silent=TRUE))),silent=TRUE)
    if(inherits(f,"try-error")) return(c(rep(NA,4),ncol(m$A_st)))
    b<-f$opt$par[names(f$opt$par)=="b_fix"]; e<-unname(b[grep(":env$",f$X_fix_names)])
    c(f$opt$objective,e,ncol(m$A_st)) }
  ## tune cutoffs to MATCH node counts as closely as possible
  a <- fitm(c("lon","lat"),0.045); b <- fitm(c("ux","uy"),3.6)
  c(ll_err=mean(abs(a[2:4]-TRUE_B)), utm_err=mean(abs(b[2:4]-TRUE_B)),
    ll_obj=a[1], utm_obj=b[1], ll_nodes=a[5], utm_nodes=b[5])
}
R <- t(sapply(1:5, one))
cat("nodes: lon/lat", paste(R[,"ll_nodes"],collapse=","), "| UTM",
    paste(R[,"utm_nodes"],collapse=","), "\n\n")
cat(sprintf("mean |err|  lon/lat %.4f   UTM %.4f\n",
    mean(R[,"ll_err"]), mean(R[,"utm_err"])))
cat(sprintf("per seed lon/lat: %s\n", paste(round(R[,"ll_err"],3),collapse=" ")))
cat(sprintf("per seed UTM    : %s\n", paste(round(R[,"utm_err"],3),collapse=" ")))
cat(sprintf("UTM better in %d of %d seeds\n", sum(R[,"utm_err"]<R[,"ll_err"]), nrow(R)))
cat(sprintf("mean obj: lon/lat %.3f  UTM %.3f  (diff %.3f)\n",
    mean(R[,"ll_obj"]), mean(R[,"utm_obj"]), mean(R[,"ll_obj"]-R[,"utm_obj"])))
