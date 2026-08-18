# iSDM flagship real-data candidates — scouting notes (Jason)

All findings below are **UNVERIFIED** — web-sourced, not independently checked against the
raw data. The maintainer (Shinichi) must confirm before any is adopted as the flagship
analysis for gllvmTMB's Poisson-log (GBIF presence-only) + Bernoulli-cloglog (designed
survey) shared-latent-field iSDM.

---

## Candidate 1 — Wood Thrush (*Hylocichla mustelina*)

**(a) Taxon/system.** A single well-studied Nearctic-Neotropical migrant songbird,
species of conservation concern (declining, forest-interior specialist).

**(b) GBIF availability.** UNVERIFIED, queried live against the GBIF occurrence API
2026-08-17: `scientificName=Hylocichla mustelina`, `country=US` returns **count =
1,994,398** records (`https://api.gbif.org/v1/occurrence/search?scientificName=Hylocichla%20mustelina&country=US&limit=0`).
This total is dominated by eBird-sourced GBIF records, not raw incidental GBIF
observations — order-of-magnitude only, not vetted for duplicates/checklist structure.

**(c) Designed survey overlap.** North American Breeding Bird Survey (BBS, USGS) —
Wood Thrush is within BBS's eastern-US/southeastern-Canada route coverage. **Direct
literature precedent**: Fletcher et al. 2019, *Ecology*, "A practical guide for
combining data to model species distributions," uses Wood Thrush as an illustrative
species integrating planned-survey (BBS-type) data with opportunistic eBird
citizen-science data (UNVERIFIED — summarized from search results/abstract, not the
full PDF; DOI via
`https://esajournals.onlinelibrary.wiley.com/doi/abs/10.1002/ecy.2710`).

**(d) License/access.** GBIF: open, CC0/CC-BY per dataset (standard GBIF terms).
USGS BBS: public-domain US government data via `https://www.usgs.gov/centers/eesc/science/north-american-breeding-bird-survey`
and also mirrored on GBIF.us
(`https://ipt.gbif.us/resource?r=usgs_pwrc_north_american_breeding_bird_survey`) —
UNVERIFIED whether that mirror is current through present years.

**(e) Fit for flagship.** Strong: single species, direct precedent in the iSDM
methods literature (a paper Shinichi likely already knows), large record volume,
US-focused (extent would need trimming — Wood Thrush range does not reach Alberta,
so less locally resonant for an Edmonton-based maintainer).

---

## Candidate 2 — Canada Warbler (*Cardellina canadensis*)

**(a) Taxon/system.** Boreal-breeding songbird, COSEWIC-listed as Threatened in
Canada, occurs across Alberta's boreal forest — directly relevant to the maintainer's
home region.

**(b) GBIF availability.** UNVERIFIED, live GBIF API query 2026-08-17:
`scientificName=Cardellina canadensis`, no country filter, returns **count =
597,767** records globally
(`https://api.gbif.org/v1/occurrence/search?scientificName=Cardellina%20canadensis&limit=0`).
Not filtered to Alberta/Canada only — the Alberta-specific subset would be
substantially smaller and was not queried separately.

**(c) Designed survey overlap.** Two candidates: (i) North American BBS (Alberta has
active routes — UNVERIFIED count of routes; see
`https://open.canada.ca/data/en/dataset/12606fef-76f4-41fb-86b6-81f56e6bf2c4` and
`https://naturealberta.ca/breeding-bird-survey-bbs/`); (ii) Alberta Biodiversity
Monitoring Institute (ABMI) autonomous-recording-unit (ARU) bird surveys — ABMI states
it has collected data on **over 270 bird species** across a 660,000 km² monitoring
footprint, in a "collaboration between ABMI, the Boreal Avian Modelling (BAM) project,
Canadian Wildlife Service, and USGS" (UNVERIFIED, from `https://abmi.ca/biobrowser/species-group/birds-intro.html`
and `https://abmi.ca/abmi-home/what-we-do/taxonomy/birds.html`). ABMI's ARU protocol
is a designed, systematic detection/non-detection survey — a natural Bernoulli-cloglog
arm.

**(d) License/access.** ABMI states "over 15 years of data freely available for use
and download by anyone for any purpose" (UNVERIFIED, from
`https://abmi.ca/abmi-home`) — an explicit license document (CC-BY vs other) was
**not located** in this search pass and should be confirmed directly at abmi.ca before
use. GBIF/BBS as above.

**(e) Fit for flagship.** Strong regional resonance (Edmonton-based maintainer,
Alberta boreal system); species is small enough in range that the spatial extent is
manageable; ABMI + BBS gives *two* independent designed-survey candidates to pick
from, plus GBIF/eBird presence-only. Main risk: ABMI license terms and ARU detection
protocol (acoustic, not point-count) would need to be understood before treating it as
a straightforward Bernoulli-cloglog arm — detection process may differ structurally
from a simple presence/absence design.

---

## Candidate 3 — Monarch butterfly (*Danaus plexippus*)

**(a) Taxon/system.** A single, extremely well-known, conservation-flagged
invertebrate (COSEWIC Endangered in Canada as of 2023 — UNVERIFIED, not directly
checked this pass). Offers a genuine taxonomic contrast to the two bird candidates.

**(b) GBIF availability.** UNVERIFIED, live GBIF API query 2026-08-17:
`scientificName=Danaus plexippus`, `country=CA`, returns **count = 82,322** records
(`https://api.gbif.org/v1/occurrence/search?scientificName=Danaus%20plexippus&country=CA&limit=0`).
Likely dominated by iNaturalist research-grade records routed through GBIF.

**(c) Designed survey overlap.** North American Butterfly Association (NABA)
Butterfly Count Program — structured, fixed 15-mile-diameter count-circle surveys run
annually since 1993 across the US, Canada, and Mexico, ~450 counts/year (UNVERIFIED,
from `https://naba.org/butterfly-counts/` and `https://legacysite.naba.org/counts/faq.html`).
Alternative: eButterfly, a structured-checklist platform analogous to eBird
(not independently verified this pass, no URL fetched — flag for follow-up).

**(d) License/access.** GBIF/iNaturalist arm: open (CC0/CC-BY per record, standard
iNaturalist licensing terms vary by observer). **NABA count data access is
NOT straightforwardly open**: per `https://naba.org/naba-butterfly-count-data/`,
access is restricted to university-affiliated scientists (or their students) who
submit a request to a scientific advisory committee and sign a memorandum of
understanding (UNVERIFIED, summarized from search result, not the full page). This is
a meaningfully higher access barrier than BBS/eBird/GBIF/ABMI and should be flagged
explicitly to Shinichi if this candidate is considered.

**(e) Fit for flagship.** Appealing for taxonomic breadth and public interest, but
the NABA access friction is a real risk to a "genuine, reproducible, end-to-end" paper
if the license does not permit redistribution/reanalysis in a public methods paper.
Should be treated as the higher-uncertainty candidate pending confirmation of (i) NABA
access terms and (ii) whether eButterfly gives a fully open alternative.

---

## Candidate 4 — Shorebirds, Central Valley California (multi-species, e.g. via BirdReturns/eBird)

**(a) Taxon/system.** A shorebird guild in California's Central Valley (specific
species not identified in this pass — the precedent paper is multi-species/guild-
level, not a single flagship taxon).

**(b) GBIF availability.** Not queried this pass (guild-level, no single binomial to
query) — would need to be scoped to specific species before a GBIF count could be
pulled.

**(c) Designed survey overlap.** **Direct literature precedent**: Robinson, Ruiz-
Gutierrez, Reynolds, Golet, Strimas-Mackey & Fink (2020), *Diversity and Distributions*,
"Integrating citizen science data with expert surveys increases accuracy and spatial
extent of species distribution models" — integrates high-resolution structured survey
data (associated with The Nature Conservancy's BirdReturns program, UNVERIFIED) with
eBird citizen-science checklists for Central Valley shorebirds (UNVERIFIED, summarized
from search results, DOI at `https://onlinelibrary.wiley.com/doi/10.1111/ddi.13068`,
preprint at `https://www.biorxiv.org/content/10.1101/806547v2.full`).

**(d) License/access.** eBird: open via eBird Basic Dataset request (free,
attribution required). The structured survey arm's access terms are UNVERIFIED — not
confirmed public/downloadable in this pass; this is the weakest-documented candidate
of the four and would need direct paper review before adoption.

**(e) Fit for flagship.** Strong methodological precedent (a named integration paper
with a very similar detection-contrast logic to gllvmTMB's), but weakest on (i) a
single clean flagship taxon and (ii) confirmed open access to the structured-survey
arm. Include mainly as a "known precedent exists" pointer, not a leading pick.

---

## Comparison table

| # | Candidate | GBIF volume (approx., UNVERIFIED) | Designed survey | Survey access | Literature precedent | Regional fit (Edmonton) |
|---|---|---|---|---|---|---|
| 1 | Wood Thrush | ~2.0M (US) | North American BBS | Open (public domain / GBIF mirror) | Fletcher et al. 2019 (direct) | Weak — range doesn't reach Alberta |
| 2 | Canada Warbler | ~0.6M (global, unfiltered) | ABMI ARU surveys **or** BBS (Alberta routes) | ABMI: stated open, license doc not located; BBS: public domain | Boreal Avian Modelling / ABMI-BBS collaboration (general, not a named integration paper) | Strong — boreal Alberta species |
| 3 | Monarch butterfly | ~82K (Canada only) | NABA Butterfly Count Program | **Restricted** — MOU + committee approval required | General iSDM/citizen-science literature (no single named paper confirmed) | Moderate — occurs in Alberta but core NABA counts are US-heavy |
| 4 | Central Valley shorebirds (guild) | Not queried (guild-level) | BirdReturns-type structured survey (UNVERIFIED name/scope) | Structured-survey arm UNVERIFIED | Robinson et al. 2020 (direct) | Weak — California, not Alberta |

---

## Jason's pick + why

**Pick: Candidate 2, Canada Warbler, with ABMI ARU data as the designed-survey arm
and GBIF/eBird as the presence-only arm** — provisionally, pending Shinichi's
confirmation of the ABMI license and of exactly which BBS-vs-ABMI arm is cleaner to
extract.

Reasoning: it is the only candidate that is simultaneously (i) a single, well-defined
flagship species, (ii) directly relevant to the maintainer's own region (Alberta
boreal forest, Edmonton-based), (iii) backed by two independent open-access-labelled
designed-survey sources to choose between (BBS routes and ABMI ARU stations) rather
than one single point of failure, and (iv) a conservation-listed species (COSEWIC
Threatened, UNVERIFIED) that gives the paper an applied hook beyond methods alone.
**Runner-up: Candidate 1 (Wood Thrush)** — it has the cleanest, most directly-named
literature precedent (Fletcher et al. 2019 used this exact species for exactly this
kind of data combination), and if Shinichi prefers to anchor the flagship analysis
tightly against a published integration example rather than break new regional ground,
this is the safer choice. Both should be short-listed together for Shinichi's decision;
Candidates 3 and 4 are included for completeness but carry higher access-risk (NABA)
or weaker single-taxon framing (shorebird guild) respectively.

**Everything in this document is UNVERIFIED and must be checked by the maintainer**
before any candidate is adopted — record counts are approximate GBIF API snapshots
taken 2026-08-17, not vetted for data quality, duplicate records, or actual spatial/
temporal overlap between the two data sources at the resolution gllvmTMB would need.

---

## 2026-08-18 — Verification pass on Candidate 2 (Canada Warbler) — Ranganathan

Scope: verify or fail the provisional flagship-taxon choice (Canada Warbler,
*Cardellina canadensis*) before any analysis is built on it. Read-only against this
worktree; the candidates doc above (Jason, 2026-08-17) was read first and is not
duplicated here — only new measurements and corrections are recorded.

### VERDICT: **CONDITIONAL**

Condition: Canada Warbler remains defensible as the flagship taxon **only if** the
joint spatial model either (i) obtains ABMI's precise (non-fuzzed) site coordinates
under a data-sharing request, or (ii) is explicitly built to tolerate ABMI's public
coordinate precision (~5.5 km / 95 km², coarser still for this species specifically —
see Blockers). Neither GBIF nor ABMI access is a hard blocker on their own; the
blocker risk is specifically the **spatial-precision mismatch** between the two arms.

### 1. GBIF — measured, `rgbif` 3.x installed and used directly (not the raw API)

`Rscript -e 'requireNamespace("rgbif")'` → `TRUE`; queries run live 2026-08-18 via
`rgbif::occ_count()` / `occ_search()` against taxon key `6091946` (GBIF backbone
match for *Cardellina canadensis*, via `name_backbone()`).

| Query | Result |
|---|---|
| `occ_count(taxonKey = 6091946)` | **597,761** total records (matches Jason's 597,767 API snapshot to within normal day-to-day GBIF index drift) |
| `occ_count(taxonKey = 6091946, hasCoordinate = TRUE)` | **594,685** with coordinates (99.5% of total) |
| `occ_count(taxonKey = 6091946, country = "CA")` | **118,039** |
| `occ_count(taxonKey = 6091946, country = "CA", hasCoordinate = TRUE)` | **117,663** |
| `occ_count(taxonKey = 6091946, country = "US")` | 383,191 |
| `occ_search(..., country="CA", hasCoordinate=TRUE, facet="stateProvince")` | **Alberta: 4,184 + "Alberta (Prov.)" 14 = 4,198** — i.e. **0.7% of the global total, 3.6% of the Canada total**. Ontario (55,298) and Quebec (45,336) dominate the Canadian count; Alberta is a minor province by volume. |
| `facet="year"`, Alberta subset | Records span **1917–2026** but are trivial before ~2010 (≤26/year); the count grows sharply from 2012 (70) → 2014 (344) → sustained 300–520/year 2017–2024. Effectively a **post-2012 dataset** for any usable sample size. |
| `facet="basisOfRecord"`, Alberta subset | **4,162 / 4,198 (99.1%) = `HUMAN_OBSERVATION`**; 16 `OCCURRENCE`, 4 `PRESERVED_SPECIMEN`, 2 `MATERIAL_SAMPLE`. |
| `facet="datasetKey"`, Alberta subset, resolved via `dataset_get()` | **4,113 / 4,181 listed records (98.4%) come from a single dataset: "EOD – eBird Observation Dataset"** (key `4fa7b334-ce0d-4e88-aaae-2e0c138d049e`). The rest is iNaturalist (45), the Royal Alberta Museum bird collection (16), and small museum/barcode datasets (≤4 each). |
| Spatial spread, 300-record sample, Alberta | lat 49.66–59.96°N (full provincial N–S extent), lon −119.30 to −110.03°W (full provincial E–W extent); median lat/lon (54.6°N, −111.7 to −113.6°W) sits in the central-boreal band, consistent with the species' boreal breeding range rather than being purely an Edmonton/Calgary urban-birder artifact — but this is a coarse eyeball check on one 300-row pull, not a density map. |

**Correction to the 2026-08-17 entry**: the "~0.6M global" headline is real but the
**Alberta-specific, coordinate-present count is 4,198, not previously measured** — this
is the number that actually matters for a province-scoped iSDM, and it is two orders
of magnitude smaller than the global figure. It is also **almost entirely eBird**
(structured citizen-science checklists), not a diverse mix of GBIF-native incidental
records — same caveat Jason already flagged for Wood Thrush, now confirmed
quantitatively for Canada Warbler/Alberta specifically.

### 2. ABMI — public access, licence, and coordinate precision

Primary source used directly: `https://abmi.ca/abmi-home/terms-and-conditions`
(fetched via `curl` 2026-08-18 after `WebFetch` returned HTTP 403 on abmi.ca domains —
noted as an access quirk, not a content finding).

- **Licence: NOT a standard Creative Commons licence, contrary to a third-party
  characterization.** `re3data.org`'s registry entry for the ABMI Data & Analytics
  Portal (`https://www.re3data.org/repository/r3d100014019`, UNVERIFIED third-party
  aggregator) states the licence as CC-BY 4.0, but ABMI's own Terms and Conditions
  page contains **no "Creative Commons" or "CC-BY" text**. Instead it describes a
  bespoke policy: information products are "freely accessible" for use, provided the
  ABMI is **acknowledged as the source** in a specified citation format (example given
  in the primary text: *"Raw breeding bird data (2004–2006 inclusive) from the Alberta
  Biodiversity Monitoring Institute was used, in whole or part, to create this
  product."*), plus a recommended disclosure of data version/type and analysis method.
  This is **compatible with redistribution in a vignette/article with attribution**,
  but it should not be cited as "CC-BY 4.0" without a firmer source than re3data.org.
- **Precise coordinates are NOT part of the public release.** Verbatim from the
  primary source: *"Public coordinates identify the location of each survey site to
  within 5.5 km of the precise geographic coordinate (or 95 km²)."* Precise
  coordinates are released only "to select parties under conditions laid out in the
  ABMI's site confidentiality policy" — i.e. a separate data-access agreement, not the
  open portal. **Species at risk are singled out for an additional, coarser
  restriction**: *"The location of rare and endangered species in the White Area will
  be made publicly accessible at a broad scale only (e.g., greater than 1 ABMI
  point)."* Canada Warbler was COSEWIC-listed Threatened 2008–2020 and would very
  plausibly have triggered this rule for at least part of the ABMI record; its current
  status is Special Concern (see correction below), so it is worth re-checking whether
  the coarser rule is still applied to it going forward.
- **Data access mechanism**: bird ARU/point-count data is managed through
  **WildTrax** (`https://wildtrax.ca`), which requires account registration to manage
  projects but has a public "Data Discovery" portal for browsing/downloading already-
  published data (UNVERIFIED — summarized from search results
  `https://wildtrax.ca/resources/faqs/`, not independently confirmed by loading the
  portal itself this pass).
- **ABMI bird/ARU data is confirmed NOT present on GBIF.** `rgbif::organizations()`
  finds ABMI as a registered GBIF publishing organization (key
  `0120ece6-e235-4e11-98ee-70966cee0fca`), but `GET
  https://api.gbif.org/v1/dataset/search?publishingOrg=0120ece6-e235-4e11-98ee-70966cee0fca`
  returns **zero datasets**, and none of the 8 datasets contributing to the Alberta
  GBIF Canada Warbler pull (above) is an ABMI dataset. This is a **positive finding**:
  ABMI and GBIF are genuinely independent data streams for this species (no risk of
  double-counting the same detections across the two arms), which is exactly the
  property an iSDM's two arms need.
- **Species-specific ARU coverage, primary source**: `abmi.ca`'s birds overview page
  (`https://abmi.ca/abmi-home/what-we-do/taxonomy/birds.html`, fetched via curl)
  states verbatim: *"Monitoring federally and provincially listed bird species—e.g.,
  Canada Warbler, Bay-breasted Warbler, Black-throated Green Warbler—can be done
  directly using ARUs..."* and separately: *"Between 2015 and 2022, over 1,380 hours
  of audio recordings have been analyzed, with 265 bird species detected at sampling
  locations across the province."* ABMI's point-count program itself dates to a
  2003–2006 prototype phase and operational data from **2007** onward (UNVERIFIED,
  from search-result summary of `https://archive.abmi.ca/home/about-us/our-history.html`
  and the existence of an R data package titled "ABMI Bird Counts and Site
  Capabilities from 2007"). Canada Warbler is thus **named explicitly** as an ABMI ARU
  target species, not merely inferred from the "270+ species" aggregate figure Jason
  already cited.

### 3. Spatial and temporal overlap assessment (load-bearing)

**Temporal**: real overlap exists. GBIF/Alberta eBird records only become usable in
volume from ~2012 onward and are sustained 2014–2024; ABMI's ARU-specific bird data
was reported for the 2015–2022 window (with point-count data since 2007). The
**2015–2022 window is common to both arms** at reasonable sample sizes. Not a blocker.

**Spatial**: this is the genuine risk, and it is a **coordinate-precision mismatch**,
not an extent mismatch. Extent-wise both arms cover the province (GBIF/Alberta
records span the full lat/lon range of Alberta per the 300-row sample above; ABMI's
monitoring footprint is stated by ABMI/Jason's prior note as ~660,000 km²,
UNVERIFIED, not re-measured this pass). But:
- GBIF/eBird coordinates are typically precise (checklist-level GPS or hand-placed
  pins), while
- **ABMI's public coordinates are administratively fuzzed to 5.5 km / 95 km²**, and
  for a species-at-risk (which Canada Warbler was for most of the ABMI ARU program's
  history) the rule is explicitly coarser still ("broad scale only... greater than 1
  ABMI point").

A shared-latent-spatial-field iSDM (this package's actual use case) needs the two
arms' locations at a comparable resolution, or an explicit positional-error model for
the coarser arm. Neither this pass nor the existing doc has measured what "1 ABMI
point" resolution actually is in km, nor whether Canada Warbler's current Special
Concern status (see below) relaxes the rare-species rule going forward. **This was
not resolved — it needs either (a) a direct ABMI data request to establish what
resolution a formal collaboration would actually receive, or (b) a design decision to
model ABMI's arm at its public, fuzzed resolution and treat the mismatch explicitly.**

### 4. Licence compatibility for redistribution (vignette/article)

- GBIF/eBird: open, standard GBIF terms (CC0/CC-BY per constituent record) — no
  redistribution barrier for a vignette, consistent with Jason's prior note.
- ABMI: **not blocked**, but requires attribution in the specific format ABMI
  documents (see §2) — a vignette/article citing ABMI as a data source is compatible
  with the primary-source terms as read. The **discrepancy between ABMI's own terms
  page (acknowledgement-required, no CC-BY text) and re3data.org's CC-BY 4.0
  characterization should be resolved with ABMI directly before the article states a
  specific licence name.**

### 5. Correction: COSEWIC status (primary source)

The existing candidate doc and the ABMI find above both describe Canada Warbler as
"COSEWIC-listed Threatened" or flag it "UNVERIFIED." Per Canada's own Species at Risk
Public Registry (`https://www.canada.ca/en/environment-climate-change/services/species-risk-public-registry/cosewic-assessments-status-reports/canada-warbler-2020.html`,
a primary government source, checked via WebSearch summary — page not independently
fetched in full this pass): **COSEWIC assessed Canada Warbler as Threatened in 2008,
then re-assessed it as Special Concern in 2020**, citing a slowing/reversing
population decline (Breeding Bird Survey trend +46% over the most recent decade
reported). It remains SARA-listed (legal re-listing to Special Concern may lag the
2020 re-assessment — not independently confirmed this pass). **The "COSEWIC
Threatened" framing in the flagship pitch should be updated to reflect the 2020
downgrade**; the applied-conservation hook is weaker than the 2026-08-17 doc implies,
though still a genuine SAR-listed species.

### Anything that would BLOCK using this taxon

1. **Coordinate-precision mismatch (see §3)** — the one finding that could actually
   sink the design if ABMI cannot supply better-than-5.5-km locations under a data
   request. Not yet resolved; needs a direct answer from ABMI, not more web search.
2. Alberta-specific GBIF sample size (4,198 records, ~99% eBird, real volume only from
   ~2012) is much smaller than the headline global number and should be used, not the
   597K figure, in any capacity claim.
3. ABMI's own terms page does not literally state a CC-BY licence — do not cite CC-BY
   4.0 for ABMI data without confirming directly with ABMI; use the acknowledgement
   language instead, or ask.
4. COSEWIC status is Special Concern (2020), not Threatened, for the conservation-hook
   framing.

Nothing above is an outright kill — hence CONDITIONAL rather than FAILED — but the
spatial-precision question (§3) should be answered **before** any fitting work starts,
because it determines whether the two arms can share a spatial random field at all, or
whether ABMI's arm needs measurement-error treatment gllvmTMB does not currently have
a design for.

**Sources**: `rgbif` live queries (this session, 2026-08-18, taxonKey 6091946);
`https://abmi.ca/abmi-home/terms-and-conditions` (primary, fetched via curl after
WebFetch 403); `https://abmi.ca/abmi-home/what-we-do/taxonomy/birds.html` (primary,
via curl); `https://www.re3data.org/repository/r3d100014019` (secondary aggregator,
flagged as a discrepancy, not adopted); `https://wildtrax.ca/resources/faqs/`
(UNVERIFIED, search-result summary only); Canada's Species at Risk Public Registry
COSEWIC 2020 status page (primary government source, summary via WebSearch, not
independently fetched in full). GBIF publisher/dataset registry via
`api.gbif.org/v1/dataset/search` and `rgbif::organizations()`.
