fs <- Sys.glob("/tmp/fw-n*.rds")
a <- do.call(rbind, lapply(fs, readRDS))
cat("cells:", length(fs), " rows:", nrow(a), "\n\n")
cat("=========== ACCURACY (rel_frob, median over seeds; LOWER IS BETTER) ===========\n")
acc <- aggregate(rf ~ arm + n_trials + psi_true, a, median)
w <- reshape(acc, idvar=c("n_trials","psi_true"), timevar="arm", direction="wide")
names(w) <- sub("^rf[.]","",names(w))
w <- w[order(w$psi_true, w$n_trials), ]
print(w, row.names=FALSE, digits=4)
cat("\n=========== SPEED (seconds, median; serial + interleaved) ===========\n")
sp <- aggregate(secs ~ arm + n_trials, a, median)
ws <- reshape(sp, idvar="n_trials", timevar="arm", direction="wide")
names(ws) <- sub("^secs[.]","",names(ws))
print(ws[order(ws$n_trials),], row.names=FALSE, digits=3)
cat("\n=========== psi RECOVERY (VA arms only; truth in psi_true) ===========\n")
p <- aggregate(psi ~ arm + n_trials + psi_true, a[!is.na(a$psi),], median)
wp <- reshape(p, idvar=c("n_trials","psi_true"), timevar="arm", direction="wide")
names(wp) <- sub("^psi[.]","",names(wp))
print(wp[order(wp$psi_true, wp$n_trials),], row.names=FALSE, digits=4)
cat("\n=========== WINNER per condition (best median rel_frob) ===========\n")
for (i in seq_len(nrow(w))) {
  arms <- setdiff(names(w), c("n_trials","psi_true"))
  v <- unlist(w[i, arms]); v <- v[!is.na(v)]
  cat(sprintf("  n_trials=%2d psi=%.1f  ->  %-9s %.4f   (worst %-9s %.4f)\n",
      w$n_trials[i], w$psi_true[i], names(which.min(v)), min(v),
      names(which.max(v)), max(v)))
}
