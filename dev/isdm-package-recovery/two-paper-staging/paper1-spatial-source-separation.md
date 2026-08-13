# Paper 1 — keeping ecological spatial variation distinct from GBIF-only sampling bias

## Status

Private design draft. This is not a result paper, an empirical analysis, or a
claim that the estimator separates the two fields. Its eventual scope is a
two-source spatial iSDM in which the structured PA source and opportunistic
GBIF source share relative ecological intensity, whereas only GBIF receives a
source-specific bias covariate and a GBIF-only spatial field.

## The scientific problem

Opportunistic records can be concentrated where observers sample rather than
where a species occurs. A structured survey offers a different observation
process, but combining the two sources does not by itself identify ecology and
sampling bias. The article asks a narrow, falsifiable question: under a named
synthetic spatial design with source-restricted bias, can the specified model
recover the ecological and GBIF-only fields without collapsing them into one?

## Proposed estimand and model

For species \(s\) and cell \(c\), the ecological linear predictor is

\[
\eta^{(E)}_{cs}=\alpha_s+x_c\beta_s+u_c\lambda_s+\epsilon_{cs}.
\]

The GBIF branch adds a fixed source-specific bias covariate and a distinct
spatial bias field,

\[
\eta^{(G)}_{cs}=\eta^{(E)}_{cs}+b_c\gamma_s+h_c\delta_s.
\]

The structured PA branch receives \(\eta^{(E)}_{cs}\), not \(b_c\gamma_s\)
or \(h_c\delta_s\). The prototype uses the frozen Paper 1 synthetic fixture:
three species, 360 cells, three PA visits, independently drawn ecological and
GBIF-bias fields with zero DGP cross-field correlation, and a shared-range
SPDE representation. It is a **known-truth design**, not a fitted estimate.

## Evidence sequence

1. A Paper 1 no-fit classifier-domain review must first resolve the retained
   Case-D numerical admission HOLD without changing the likelihood, DGP,
   thresholds, or consumed root.
2. Only a separately approved, all-attempt spatial recovery programme can
   authorise truth-versus-estimate field maps.
3. An empirical candidate may enter only after its own data, licence, privacy,
   repeat-observation, taxonomy, support, and confounding contract passes Gate
   A. Its early maps describe observed sampling patterns only.
4. Empirical relative-intensity, bias, and uncertainty maps require a separate
   observation/prediction approval after synthetic spatial evidence.

## Figure plan

P1-F1 is a synthetic design schematic showing source routing and the two true
fields. It does not establish recovery, causal bias removal, occupancy,
detection, absolute abundance, generic zero inflation, arbitrary-source
integration, or spatial scalability. The prototype caption is authorised only
as a design figure.

## Intended contribution if the gates are passed

The contribution would be a bounded demonstration of source-restricted spatial
separation for one synthetic regime, accompanied by an empirical application
that remains within the supported spatial domain. A failed admission or
recovery gate instead supports a private STOP/HOLD conclusion; it does not
become evidence of ecological or sampling-bias separation.
