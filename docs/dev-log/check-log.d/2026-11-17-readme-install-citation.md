# Check-log: README CRAN install and citation version (refs #1807, refs #1809)

**Goal:** Confirm the README citation matches DESCRIPTION `0.8.0`, the Install
section shows the CRAN 0.7.1 command next to the GitHub `pak` route, and the
getting-started vignette points at that section.

**Commands:**

```sh
python3 - <<'PY'
from pathlib import Path
import re
readme = Path("README.md").read_text()
rmd = Path("vignettes/gllvmTMB.Rmd").read_text()
desc = Path("DESCRIPTION").read_text()
assert "The released package is available from CRAN" not in readme
assert 'pak::pak("itchyshin/gllvmTMB")' in readme
assert 'install.packages("gllvmTMB")' in readme
assert "R package version 0.8.0.9000" not in readme
assert "R package version 0.8.0." in readme
assert "Version: 0.8.0" in desc
assert "https://itchyshin.github.io/gllvmTMB/#install" in rmd
assert re.search(r"one-time warning.*per-trait Psi by default", readme, re.S)
assert "latent_unit" in readme and "indep_unit" in readme
assert "gllvmTMB_diagnose()" in readme and "check_gllvmTMB()" in readme
assert "sigma_eps" in rmd and "indep(0 + trait | individual)" in rmd
print("README/vignette string checks: PASS")
PY

rg -n "0\\.8\\.0\\.9000" README.md vignettes/gllvmTMB.Rmd
rg -n 'install.packages\("gllvmTMB"\)|pak::pak\("itchyshin/gllvmTMB"\)|R package version 0\.8\.0' README.md
rg -n "The released package is available from CRAN" README.md
rg "\\bS_B\\b|\\bS_W\\b|\\\\bf S" README.md vignettes/gllvmTMB.Rmd
rg "in prep|in preparation" README.md vignettes/gllvmTMB.Rmd
rg "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/gllvmTMB.Rmd
rg "meta_known_V" README.md vignettes/gllvmTMB.Rmd
rg "gllvmTMB_wide" README.md vignettes/gllvmTMB.Rmd
rg -n "Fixes |Closes |Resolves " README.md vignettes/gllvmTMB.Rmd
test ! -f README.Rmd && echo NO_README_RMD
```

CRAN page <https://cran.r-project.org/package=gllvmTMB> read on 2026-11-17:
Version **0.7.1**, Published **2026-10-28**.

**Results:** Python string checks PASS. `0.8.0.9000` absent from README and
the getting-started vignette. `install.packages("gllvmTMB")`,
`pak::pak("itchyshin/gllvmTMB")`, and citation `0.8.0` present. Forbidden
#1311 CRAN sentence absent. Stale-wording patterns above: no hits. No
`README.Rmd`.

**Not run:** `devtools::test()`, `pkgdown::check_pkgdown()`,
`devtools::check()`. This VM has no R binary. GitHub `R-CMD-check` is the
package check.

**Claim boundary:** Docs-only. No fit, likelihood, interval, or
validation-debt claim. CRAN version is the live page on 2026-11-17, not a
promise that 0.7.1 remains current.
