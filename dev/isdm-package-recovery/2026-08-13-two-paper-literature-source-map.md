# Two-paper iSDM programme — independent literature source map

**Notebook:** Gemini Notebook `6f076d4c-4fb0-471b-bdc6-315ce09d9dec` — *Two-paper
spatial iSDM: source separation, sampling bias, and evidence reporting*.

**Status:** private planning evidence.  It informs reporting and claim fences;
it is not a novelty or package-performance review.  Sources discovered by web
research are provisional until their full text is inspected.  Shinichi-authored
and package materials were excluded from the search query and are not used as
comparative evidence.

## Readable primary anchors

| Use in programme | Source | What it supports | What it does not support |
| --- | --- | --- | --- |
| Transparent SDM reporting | Zurell et al. (2020), *A standard protocol for reporting species distribution models*, doi:10.1111/ecog.04960 | Retaining data, model, prediction, validation and uncertainty provenance alongside every figure | A specific iSDM likelihood, source-bias correction, or empirical performance claim |
| Integrating observation processes | Miller et al. (2019), *The recent past and promising future for data integration methods to estimate species' distributions*, doi:10.1111/2041-210X.13110 | Treating each observation process and its support explicitly rather than pooling records mechanically | Proof that a particular GBIF-plus-survey design separates ecology and sampling bias |
| Preferential-sampling risk | Pennino et al. (2019), *Accounting for preferential sampling in species distribution models*, doi:10.1002/ece3.4789 | Non-random sampling locations can be associated with the response and bias estimates/predictions; source-location processes therefore need an explicit role in the analysis | That a separate spatial-bias field is identifiable in this programme, that a source-specific field removes bias causally, or that the Paper 1 estimator is admitted/recovered |

Zurell and Miller were spot-checked in the notebook and contained substantive
text (102,103 and 95,813 characters, respectively).  Pennino's readable
open-access primary article was independently inspected at PMC on 2026-08-13.
It gives an especially relevant warning for this programme: its richer
preferential-sampling formulation encountered a spatial/covariate competition
that restricted model comparison.  We use that as a reason to predeclare
confounding attacks and retain non-admission, not as evidence that the present
two-field likelihood can resolve them.

## Programme implications

1. Every empirical map has a declared role: observed source pattern, covariate,
   synthetic truth, fitted prediction, uncertainty, or recovery diagnostic.
   Those roles are never interchangeable.
2. Paper 1 reports opportunistic and structured observations separately before
   showing any model result.  Its ecological and GBIF-bias maps require known
   truth recovery first; an observed GBIF map is not a bias-corrected map.
3. Paper 2 reports numerical admission, Psi recovery and profile information as
   distinct quantities.  A numerical result cannot be relabelled as recovery,
   and a recovery result cannot waive an admission hold.
4. The notebook's remaining sources are a lead list, not a citation list.  A
   later manuscript bibliography must be verified from original, readable
   sources and include the exact data/licence sources used by the case study.
5. Paper 1's two-field schematic is a design assumption with a source-purity
    guard, not an observational answer to preferential sampling.  Paper 2 has
    no spatial or empirical claim: its all-attempt numerical and Psi outcomes
    cannot be supported by this landscape literature.

## Questions this source map does not answer

- Whether the current two-field spatial estimator is numerically admitted or
  recovers known truth.
- Which empirical observation law is appropriate for a selected survey system.
- Whether a GBIF-plus-survey empirical case supports ecological inference,
  prediction, or field separation.
- Whether different observation sources, more cells, or a fitted spatial field
  solve spatial confounding in general.

Those are evidence gates in the companion case-admission and figure-claims
contracts, not literature questions.
