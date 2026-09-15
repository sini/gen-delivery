{
  description = "gen-delivery — the delivery-class realization surface: the projection that discovers declared delivery classes per node and the fold that hands each class's collected content to its target-owned terminal";

  # NO inputs, and that is what the content decided rather than what the scaffold left undone. The
  # library takes its substrate — the record algebra and the aspect layer that owns the key-category
  # declaration — as INJECTED VALUES constructed inside the consumer's own evaluation, which is the
  # gen↔gen boundary rule's shape: only plain data crosses. A library that re-declared gen-aspects
  # here would pin the aspect layer on its consumer's behalf, and the declaration this surface reads
  # is the consumer's own schema argument, so the pin belongs to whoever assembles the run.
  # gen-prelude, gen-algebra, gen-assemble and gen-program ship this same zero-input shape.
  #
  # A consequence, not an omission: zero inputs means no root lock file. The only lock in this
  # repository is ./ci/flake.lock, and it is what the acceptance run uses.
  #
  # The test runner lives in ./ci, which is a separate flake.
  #
  # ★ THE FLAKE OUTPUT IS THE ROOT, PUBLISHED UNAPPLIED. `./.` and `./lib` were two independent
  # constructions of one value and so free to disagree; there is ONE construction site now, and the
  # two entry paths differ only in who supplies the arguments. A flake can only pass `inputs.<dep>`
  # for a dependency it DECLARES, and this one declares none — so publishing the root unapplied is
  # what lets the consumer supply every argument instead of dropping the edge through to this
  # repository's own ci lock on the flake path. The hub applies this output verbatim
  # (`(input "gen-delivery").lib { algebra; aspects; }`), so an APPLIED output here would abort every
  # hub evaluation with `attempt to call something which is not a function but a set`.
  outputs = _: {
    lib = import ./.;
  };
}
