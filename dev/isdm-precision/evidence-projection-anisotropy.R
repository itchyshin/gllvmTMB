suppressMessages(devtools::load_all(".", quiet = TRUE))
set.seed(21); sp <- c("A","B","C"); n <- 200
## Alberta-ish box, INSIDE one UTM zone (Pat #11: the 10-degree span straddled zones)
lon <- runif(n, -114.5, -112.5); lat <- runif(n, 53.6, 55.4)
dd <- data.frame(site = factor(seq_len(n)), lon = lon, lat = lat)
dd <- add_utm_columns(dd, ll_names = c("lon","lat"))
nm <- setdiff(names(dd), c("site","lon","lat"))
cat("added columns:", paste(nm, collapse=", "), "\n")
X <- dd[[nm[1]]]; Y <- dd[[nm[2]]]
cat(sprintf("lon span %.3f deg  lat span %.3f deg\n", diff(range(lon)), diff(range(lat))))
cat(sprintf("UTM  x span %.1f km  y span %.1f km\n", diff(range(X)), diff(range(Y))))
cat(sprintf("km per degree: lon %.1f  lat %.1f  -> ANISOTROPY %.3fx\n",
    diff(range(X))/diff(range(lon)), diff(range(Y))/diff(range(lat)),
    (diff(range(Y))/diff(range(lat))) / (diff(range(X))/diff(range(lon)))))

## A field that is ISOTROPIC IN TRUE DISTANCE (km) -- so a lon/lat mesh must distort it
fld <- 1.0 * sin(X/40) * cos(Y/40)
envv <- as.numeric(scale(0.7*sin(X/70) + 0.5*cos(Y/60)))
mkd <- function() do.call(rbind, lapply(seq_along(sp), function(j)
  data.frame(site=dd$site, lon=lon, lat=lat, ux=X, uy=Y, env=envv, trait=sp[j],
    value=rpois(n, exp(0.8 + c(0.9,-0.4,0.5)[j]*envv + fld)))))
d <- mkd(); d$trait <- factor(d$trait, levels=sp)
fitm <- function(xy, cut) {
  m <- make_mesh(d, xy_cols = xy, cutoff = cut)
  f <- try(suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0+trait+trait:env+spatial_latent(0+trait|site, d=1),
    data=d, trait="trait", unit="site", family=poisson(), mesh=m, silent=TRUE))),
    silent=TRUE)
  if (inherits(f,"try-error")) return(c(NA,NA,NA,NA,ncol(m$A_st)))
  b <- f$opt$par[names(f$opt$par)=="b_fix"]
  e <- unname(b[grep(":env$", f$X_fix_names)])
  c(f$opt$objective, e, ncol(m$A_st))
}
## cutoffs chosen to give comparable node counts
a <- fitm(c("lon","lat"), 0.06)
b <- fitm(c("ux","uy"),   4.0)
cat("\ntrue env slopes: 0.900 -0.400 0.500\n")
cat(sprintf("lon/lat mesh : obj %9.3f | nodes %3d | slopes %.3f %.3f %.3f\n", a[1],a[5],a[2],a[3],a[4]))
cat(sprintf("UTM km  mesh : obj %9.3f | nodes %3d | slopes %.3f %.3f %.3f\n", b[1],b[5],b[2],b[3],b[4]))
cat(sprintf("mean |err| lon/lat %.4f   UTM %.4f\n",
    mean(abs(a[2:4]-c(0.9,-0.4,0.5))), mean(abs(b[2:4]-c(0.9,-0.4,0.5)))))
