# Draft GitHub response for Ayumi / urbanisation_map

Do not post without Shinichi review.

Target threads inspected:

- https://github.com/Ayumi-495/urbanisation_map/issues/3
- https://github.com/Ayumi-495/urbanisation_map/issues/1

Draft:

> @Ayumi-495, one thing we want to make clear in the package docs is that
> `screen_gllvmTMB()` is a diagnostic screen, not an automatic species-removal
> rule. For a binary JSDM, it flags all-zero, all-one, near-constant, rare, and
> duplicate/complement species responses so we can inspect the coding, taxonomy,
> sampling design, and biological role before fitting the latent block.
>
> In JSDM/HMSC work, some analyses do filter very rare species for stated
> modelling or computational reasons, but those thresholds are analysis choices,
> not general rules. Rare species can also be one reason to use a joint model,
> because shared community structure can borrow information across species.
>
> So the package-side recommendation will be: keep biologically important rare
> species unless there is a documented reason to exclude or recode them; report
> the screen output; and when a species is constant, very rare, or redundant,
> run a sensitivity fit or document why it stays in the response block.
