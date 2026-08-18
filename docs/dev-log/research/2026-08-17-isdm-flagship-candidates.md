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
