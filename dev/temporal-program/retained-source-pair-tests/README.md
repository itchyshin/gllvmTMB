# Retained temporal source-pair fixtures

These files preserve the former temporal combinations with kernel,
phylogenetic, animal, and spatial covariance sources. They are intentionally
outside `tests/testthat/`: the public parser refuses those combinations as of
2026-09-14. They are developer history and low-priority future-design material,
not release gates or supported workflows.

This directory also retains the former temporal--phylogenetic optimizer
qualification test and its controls fixture.  They are no longer discovered by
`testthat`, because that test exercises a covariance combination the public
parser now refuses.
