# Check-log — public study supplement

| Date | Slice | Command / evidence | Result |
|---|---|---|---|
| 2026-10-19 | Article link, asset and internal URL regression | `Rscript tools/test-check-pkgdown-public-surface.R` | PASS. The fixture confirms the actual article names the relative ZIP and its asset exists; the unchanged checker accepts that download and rejects the old rendered `docs/dev-log/research/...` URL. |
| 2026-10-19 | Archive content and provenance | `python3 /tmp/gllvmTMB-website-refresh-20261019/audit_archive.py` | PASS. The script checks exact member inventory, safe relative paths, source-byte equality, manifest checks, provenance pins, and absence of raw/private files. ZIP SHA-256 `a2d66869ba025ab8131830b2be1b88e0c7b8e6f12fc54392c22be7909670bffb`; 79,181 bytes. |
| 2026-10-19 | Pkgdown asset copy | `Rscript --vanilla -e 'p <- pkgdown:::as_pkgdown("."); dest <- tempfile("pkgdown-asset-copy-"); dir.create(dest); p$dst_path <- dest; pkgdown:::copy_asset_dir(p, "pkgdown/assets"); src <- "pkgdown/assets/loading-ridge-study-2026-10-18.zip"; dst <- file.path(dest, basename(src)); stopifnot(file.exists(dst), identical(unname(tools::md5sum(src)), unname(tools::md5sum(dst))))'` | PASS. The ZIP lands at the site root with matching digest. |
| 2026-10-19 | Pkgdown configuration and article links | `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`; targeted `rg -n 'loading-ridge-comparison|loading-ridge-study-2026-10-18.zip|dev-log/research' vignettes/articles/fit-diagnostics.Rmd pkgdown/assets tools/test-check-pkgdown-public-surface.R` | PASS. `check_pkgdown()` found no problems; the article points to the copied public ZIP and no longer links to the private research folder. Pandoc emitted existing `--mathml` deprecation warnings. |
| 2026-10-19 | Final local hygiene | `git diff --check` | PASS. |
| 2026-10-19 | Deliberately not run | Full-site build, article render, model fits, full package tests/check, and deployment | Root owns the main-branch pkgdown run and live-site verification; this slice changes no model code and should not start a fitting workflow. |

The original research directory and `tools/check-pkgdown-public-surface.R` are unchanged.
