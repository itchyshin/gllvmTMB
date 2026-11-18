## What does snapping the data to grid cells cost, on the 12-species design?
## Exact-point fits vs locations snapped to cells of side h (degrees), with env
## re-extracted at the snapped location -- the self-inflicted positional error
## that gridding is. Effort and responses are untouched (responses happened at
## the true locations; only the RECORDED location coarsens).
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-1132", quiet = TRUE))
source("/private/tmp/gllvmtmb-1132/dev/isdm-precision/generate-cawa12.R")

land <- cawa12_landscape(); spec <- cawa12_species()
cl <- land$cells
## Standardisation constants env used at build time (env = scale(e_raw)):
e_raw_at <- .env_raw(cl$lon, cl$lat)
MU <- mean(e_raw_at); SD <- sd(e_raw_at)

snap <- function(d, h) {                 # h = cell side, degrees
  slon <- (floor(d$lon / h) + 0.5) * h
  slat <- (floor(d$lat / h) + 0.5) * h
  d$env <- (.env_raw(slon, slat) - MU) / SD
  u <- suppressMessages(suppressWarnings(
    add_utm_columns(data.frame(lon = slon, lat = slat), c("lon", "lat"))))
  d$X <- u$X; d$Y <- u$Y
  d
}

one <- function(seed, h) {
  d <- sim_cawa12(seed, land = land, spec = spec)
  if (h > 0) d <- snap(d, h)
  f <- cawa12_fit(d)
  if (!isTRUE(f$ok)) return(NULL)
  est <- cawa12_env_slopes(f$fit)
  c(cor = cor(est, spec$beta), mae = mean(abs(est - spec$beta)),
    it = f$iterations)
}

grids <- c(0, 0.1, 0.2, 0.4)             # deg; ~ 0, 9x11, 17x22, 35x44 km cells
rows <- list()
for (h in grids) for (s in 1:6) {
  r <- one(3000 + s, h)
  cat(sprintf("h=%.1f seed %d : %s\n", h, s,
      if (is.null(r)) "REJECTED" else sprintf("cor %.3f mae %.3f it %d", r["cor"], r["mae"], r["it"])))
  if (!is.null(r)) rows[[length(rows)+1]] <- data.frame(h = h, seed = s, t(r))
}
res <- do.call(rbind, rows)
agg <- aggregate(cbind(cor, mae) ~ h, res, function(z) round(c(mean(z), sd(z)), 3))
saveRDS(list(per_fit = res, summary = do.call(data.frame, agg),
             mu = MU, sd = SD, built = format(Sys.time())),
        "/private/tmp/gllvmtmb-1132/dev/isdm-precision/cawa12-gridding.rds")
cat("\n=== SUMMARY (cell side deg; ~62 km/deg lon, 111 km/deg lat here) ===\n")
print(do.call(data.frame, agg), row.names = FALSE)
