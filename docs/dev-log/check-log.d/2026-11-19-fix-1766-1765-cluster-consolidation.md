## 2026-11-19 — consolidate omitted-cluster adoption (#1766, #1765)

Branch: `cursor/fix-1766-phylo-omitted-cluster-2990`

Commands:
- `R CMD INSTALL --no-multiarch --with-keep.source .`
- `Rscript -e 'library(gllvmTMB); testthat::test_file("tests/testthat/test-fix-1766-phylo-omitted-cluster.R")'`
- `Rscript -e 'library(gllvmTMB); testthat::test_file("tests/testthat/test-fix-1765-animal-omitted-cluster.R")'`

Result: 1766 file 24 PASS; 1765 file 13 PASS.