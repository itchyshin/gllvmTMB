# Kernel-pair identification redesign

The failed kernel rehearsal used an ordered kernel over the same 12 series that
carried the temporal trajectories. The next DGP must use a fixed labelled,
non-proportional kernel and enough independently replicated series that its
static variation is distinguishable from persistent temporal variation. It
must include an explicit proportional-kernel negative control, retain all
seeds and gradients, and compare source-specific variance recovery before any
parser preview is reopened.
