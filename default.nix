# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# gen-delivery declares NO INPUTS, and that is a decision the content makes rather than one the
# scaffold made on its behalf: it takes its substrate — the record algebra and the aspect layer that
# owns the key-category declaration — as INJECTED VALUES constructed inside the consumer's own
# evaluation, which is what the gen↔gen boundary rule asks for. So there is nothing here to fetch
# and nothing to pin, and this entry is the library value itself: a function of the substrate the
# caller supplies.
#
# A consequence, not an omission: zero inputs means no root lock file. The only lock in this
# repository is ./ci/flake.lock, and it is what the acceptance run uses.
import ./lib
