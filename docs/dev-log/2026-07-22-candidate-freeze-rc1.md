# Candidate freeze — v0.6.0-rc.1

**Frozen 2026-07-22** on Shinichi's explicit authorisation ("Defer review, I run RC ceremony now" +
"You can do the freeze decision as well"). He is away; the page review is **deferred to rc-review**,
which is safe because the articles do not ship (`.Rbuildignore:29`), so no article wording is in the
frozen tarball. **Submission remains his act — this ceremony stops at submission-ready.**

## Freeze content decision: ZERO source edits

The frozen candidate is the current shipped identity, already proven `tarball-clean` (0/0/1). The held
items were each **deliberately not applied**, with reasons:

- **`inst/WORDLIST`** — NOT touched. It is the maintainer's **existing curated 226-term** file.
  Auto-appending the 142 new `spell_check` flags would (a) pollute a curated list and (b) risk masking
  a real issue — e.g. US "behavior" in an `en-GB` package, which a WORDLIST would hide rather than fix.
  The spelling is advisory (the CRAN lane emitted no spelling NOTE); it is flagged for the review, not
  silenced. *(A generated WORDLIST briefly overwrote the curated one during prep and was restored from
  git — no damage; recorded for honesty.)*
- **`\value` on `ordiplot` / `gllvmTMB_multi-methods`** — NOT added. The CRAN lane is satisfied without
  them; adding un-reviewed return-value prose to a frozen release is the wrong risk. Deferred to the
  review.
- **The five article borderline phrasings** — NOT applied. Articles do not ship; they can be tightened
  anytime without touching the release.

Net: the freeze introduces no un-reviewed content into the shipped package. That is the point.

## What the freeze pins

- **Frozen source commit:** recorded in the ledger at `~/gllvmTMB-0.6-evidence/m5-rc1/`.
- **Tarball:** `gllvmTMB_0.6.0.tar.gz` rebuilt at the frozen commit; SHA-256, size, inventory,
  forbidden-path scan in the ledger.
- **Tag:** `v0.6.0-rc.1` at the frozen commit.

## After the freeze (this ceremony)

1. Build the frozen tarball + ledger.
2. Cut and push `v0.6.0-rc.1`; run the exact-tag 3-OS cycle + heavy at the tag.
3. Local suite + CRAN-config at the frozen SHA.
4. Grace/Rose/Pat **NOT-READY-default** adversarial review on the frozen artifact (D-49): two
   NOT-READY votes withhold; I do not force through.
5. Stage `cran-comments.md`; record; **STOP at submission-ready**.

## Still the maintainer's, never self-granted

The **CRAN submission** (categorically his — irreversible, outward publish), the **final `v0.6.0`
tag**, and any **win-builder / macbuilder** external upload. Rung after this ceremony (if the
adversarial review holds): **`platform-clean` at the RC**; NOT `submission-ready` until the review is
done and the maintainer submits. Per D-49 the rung is named, never an unqualified "ready".

> A failed RC is retained and replaced by rc.2 after returning to the responsible arc — no hidden
> patching inside M5 (runbook).
