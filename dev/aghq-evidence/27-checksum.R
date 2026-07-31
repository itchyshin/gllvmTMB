## Compute the DGP checksum from 24-estimator-campaign.R's own mk(), so the DRAC
## runner's copy can be checked against it rather than trusted. In a file because
## the definition contains regex/brace characters that shell-embedded R mangles.
src <- readLines("dev/aghq-evidence/24-estimator-campaign.R")
i0 <- grep("^mk <- function", src)
ends <- grep("^\\}", src)
i1 <- min(ends[ends > i0])
eval(parse(text = paste(src[i0:i1], collapse = "\n")))
chk <- mk(25L, 3L, 1L, 1, 424242L, "binomial")
val <- sum(as.matrix(chk$df[, paste0("sp", 1:3)])) + round(sum(chk$Lt), 6)
cat(sprintf("DGP_CHECKSUM=%.6f\n", val))
