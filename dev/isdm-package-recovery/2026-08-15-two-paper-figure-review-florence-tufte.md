# Figure review -- P1-F1, P2-F1, and the two paper storyboards

**Reviewer lenses:** Florence (Design 46 figure gate, read verbatim from
`docs/design/46-visualization-grammar.md` §3) and Tufte (data-ink, graphical
integrity, annotation of what matters).  Requested by the maintainer
2026-08-15 ("use Florence and Tufte and their eyes").  Objects reviewed: the
two rendered prototypes in `codex/two-paper-global-analysis`
(`results/two-paper-prototypes/`, 2026-08-13, provenance sidecar present) and
the two externally produced paper storyboards supplied by the maintainer.

## 1. P1-F1 (two-field truth raster) -- PASSES as a design prototype, with four required fixes

What it does right: title and subtitle name the scientific question; "known
DGP truth" is honest; the self-limiting caption ("no fitted field, recovery
result, or empirical claim") is exactly the claims discipline; a diverging
blue-white-red scale for a signed quantity follows the house rule; no
uncertainty ribbons on a known truth is correct, not an omission.

**F1 (integrity -- the figure hides what this week proved decisive).**  The
two panels share one "field value" legend, presenting u and h as commensurate.
They are commensurate only as *unit* fields; what enters the likelihood is
loading-scaled, the per-species amplitudes differ enormously, and the pilot
showed the design sits at the edge of even *seeing* h.  As drawn, the figure
implies two equally-estimable fields -- the precise misreading that cost this
programme six days.  Fix: caption must state the fields are unit-scale, that
per-species amplitudes differ, and that baseline GBIF effort sits near the
recoverability frontier for h (cite the pilot).

**F2 (annotation of what matters -- Tufte).**  The binding constraint of the
whole diagnosis is spatial replication: practical range 0.19 on a unit domain,
~6 independent patches per side.  One added mark -- a range scale-bar segment
of length 0.19 on either panel -- would let a reader SEE the constraint.
Highest-value single change available.

**F3 (sign honesty -- the gate's rotation row, adapted).**  Field sign is
identified only jointly with the loadings (the (Lambda,g) -> (-Lambda,-g)
orbit).  One caption clause: "field sign is identifiable only jointly with
its loadings; panels show the positive representative."

**F4 (scale symmetry).**  Legend spans roughly -1.0 to +1.5, so equal
magnitudes of opposite sign do not read equally.  Set symmetric limits so
white is a trustworthy zero.

## 2. P2-F1 (gate DAG) -- FAILS the gate for any reader-facing use

**F5 (hard fail -- internal register vocabulary).**  The terminal box reads
"frozen A-D gate / Case C: NO_CANDIDATE".  The standing repo rule is that
reader-facing surfaces carry no internal register codes, ever.  This alone
blocks the figure outside `dev/`.

**F6 (Tufte -- data-ink).**  Six boxes and five edges on a large empty canvas;
almost no information per unit ink.  The edges are undirected except one,
so the generative story (state -> sources; bias -> GBIF only) is not actually
encoded; the two crossing edges create a false focal X; the single arrowhead
collides with the terminal box's text.

**F7 (staleness).**  The box "rank-one Lambda Lambda^T + diagonal Psi" and the
A-D gate framing describe the pre-pilot understanding.  The figure predates
the week's central results (indifference region, sign-symmetric fixed point,
effort frontier) and would need redrawing regardless.

Verdict: retire P2-F1; if a schematic is still wanted, redraw with directed
edges, source-specific observation boxes labelled with their links
(Poisson/log + offset; Bernoulli/cloglog + support), and no status tokens.

## 3. The two paper storyboards (externally generated)

Excellent as **planning artifacts and talk material**; not paper figures, and
they should not drift into manuscripts as-is.  Florence gate reasons: the
"Results & Outputs" thumbnails are invented mock panels not labelled as
mock -- an integrity fail if a reader takes them as results; font sizes are
illegible at single-column width; several boxes make capability claims that
are register-governed statements, not figure content.  Tufte reason: they are
dense in *boxes*, not in *data* -- the opposite of data density.  Keep them as
the programme map; every actual figure gets built fresh from real output.

## 4. The figure the papers actually need next

The campaign will produce the first genuinely Tufte-worthy figure of this
programme: **the frontier curve** -- recovery error and pdHess rate against
GBIF effort (log-x), MCSE bands, the collapse-to-identified transition, truth
line, and the two predeclared frontier estimates with CIs.  One panel tells
the entire six-day story and is design guidance for both empirical papers.
Recommend registering it now as P1-F2 (and its Paper-2 sibling) so the
campaign's summary stage emits it directly.

## 5. Disposition

| figure | verdict | action |
| --- | --- | --- |
| P1-F1 | pass as design prototype | four fixes (F1-F4) before any reader-facing use |
| P2-F1 | fail | retire or redraw (F5-F7) |
| storyboards | keep as planning/talk artifacts | never into a manuscript as-is |
| P1-F2 (frontier curve) | proposed | emit from campaign stage 2 |
