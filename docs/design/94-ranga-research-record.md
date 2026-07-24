# Design 94 — Ranga research record

**Status:** completed research input; private and non-admissive.  
**Notebook:** `89d8ce4a-ef18-420a-b9ce-ed69c17b3d39`, *Design 94 — robust EVA
and variational inference for Bernoulli GLLVMs*.  
**Briefing request:** task `7b8ce449-439a-4855-aa18-101af63a0f72` (pending at
the time of this record).

## Question

Is there an economical, principled alternative to the raw observation-level
Taylor-EVA surrogate for a fixed Bernoulli-logit latent-factor prototype?

## Grounded findings

- Niku et al.'s GLLVM material describes variational approximation as a Jensen
  lower bound with Gaussian variational distributions.  The queried sources did
  not establish an EVA objective for this narrow target; upstream `gllvm` source
  mapping remains the evidence for the historical Taylor-EVA comparator.
- Polson, Scott and Windle's Pólya--Gamma construction gives an exact augmented
  representation for logistic likelihoods.  Its variational interpretation
  connects the Jaakkola--Jordan quadratic construction to a valid lower-bound
  route when the variational factorisation and quadratic bound are retained.
- Piecewise lower bounds are also legitimate but add state and implementation
  complexity.  Nonconjugate variational message passing is a framework, not by
  itself evidence that a chosen approximation is a lower bound.

## Design decision

Design 94 uses the fixed-loading, mean-field Jaakkola--Jordan lower-bound
prototype in `dev/design94-jj-va/`.  It is called a **robust variational
alternative**, not EVA, EVA-plus, upstream parity, or a package capability.
It does not validate a free-loading model, long-form model, structured prior,
or the shipped package engine.

## Sources held in the notebook

- Niku et al., GLLVM / `gllvm` source material (Notebook source IDs
  `78e942dd-549e-4a88-bfd5-295743a07b8e` and
  `1466e4ce-9e5b-4cdc-ab5d-14b1cc465e44`).
- Polson, Scott and Windle, *Bayesian Inference for Logistic Models Using
  Pólya--Gamma Latent Variables* (source ID
  `d57d5815-ac6c-4606-9428-e2e5d88bb614`).
- *Piecewise Bounds for Estimating Bernoulli-Logit Latent Gaussian Models*
  (source ID `d2c849c3-a273-41e7-9009-c09f3c7c5ee5`).
- Knowles and Minka, *Non-conjugate Variational Message Passing* (source ID
  `ba2c0ffb-48d3-41c3-8152-f676a6ef04d9`).

## Economy note

No audio or video artifact was generated: it would not change this code-level
decision, and the maintainer explicitly requested an economical research lane.
The requested NotebookLM briefing document is retained as the shareable
research artifact when its asynchronous task completes.
