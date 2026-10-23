source("dev/phylo-coef-public/helpers.R")
required <- c(
  "docs/dev-log/after-task/2026-08-27-phylo-coef-public.md",
  "docs/dev-log/plan-actual/2026-08-27-phylo-coef-public.md",
  "docs/dev-log/handover/2026-08-27-phylo-coef-public.md"
)
assert(all(file.exists(required)), "closeout artifact missing: %s",
       paste(required[!file.exists(required)], collapse = ", "))
text <- read_all(c(required, "docs/dev-log/check-log.md",
                   "docs/design/35-validation-debt-register.md"))
for (needle in c("column_coef", "phylo_coef", "*_slope()", "FG-20")) {
  assert(grepl(needle, text, fixed = TRUE), "closeout token absent: %s", needle)
}
cat("public coefficient closeout verified\n")
