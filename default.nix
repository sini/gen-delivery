# Standalone (non-flake) entry. Flake consumers should use the `.lib` output.
#
# THREE CHANNELS, ONE PRECEDENCE, AND NONE OF THEM IS A PROBE. A named formal per dependency wins;
# the `inputs` bag is next, tested by attrset membership so a supplied-but-throwing value throws as
# ITSELF rather than falling back; the default is resolved from `./flake.lock`, read as local
# data. There is NO `...`: an argument this root does not declare is a loud error, not a silent drop.
#
# THE PIN SOURCE IS THE ROOT `flake.lock`, NOT `ci/flake.lock` (owner-ruled Arm A, 2026-09-16:
# `den-hoag-4dfsv` §4.2). gen-delivery now declares both its dependencies as flake inputs, so a
# root lock exists and is what `import ./. { }` resolves through — the ci lock is the test graph's
# own pin source and is no longer read by this file. Both dependencies are root inputs of the root
# lock, so both paths below are one segment long.
#
# `src` AND `dep` ARE FORMALS, NOT `let` BINDINGS, AND THAT IS THE INJECTABLE RESOLVER SEAM. `src`
# is the only expression here that fetches; everything else reads the lock as data. A caller
# supplying `src = segs: throw "…"` therefore makes fetching IMPOSSIBLE for that application rather
# than merely absent. A `dep` bound in the `let` below would close over the `let`'s `src`, so the
# override would silently do nothing and the shim would fetch anyway, at rc 0.
#
# The `let` is OUTSIDE the lambda because a formal's default is evaluated in the FORMAL scope, which
# does not see a `let` in the body.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  # A direct edge IS the node key; a `follows` value is a PATH resolved segment by segment from this
  # lock's own root. Never by indexing `lock.nodes.<label>` — a last-segment shortcut reads a
  # different node. IT TAKES ITS LOCK AS AN ARGUMENT SO THAT THE ENTRY CELL CAN DRIVE THIS EXACT
  # BINDING ON A FIXTURE WHERE THE TWO RULES DISAGREE BY CONSTRUCTION; a resolver closed over this
  # library's own lock could only ever be compared against a second copy of itself. This is the ONE
  # declaration of the rule in this library — `ci/tests/entry.nix` reads this binding through the
  # record the body hands `wire`, instead of transcribing the fold a second time.
  resolve =
    lock:
    let
      following =
        node: inp:
        let
          v = (lock.nodes.${node}.inputs or { }).${inp};
        in
        if builtins.isString v then v else builtins.foldl' following lock.root v;
    in
    segs: builtins.foldl' following lock.root segs;
  fetch = resolve lock;
in
{
  inputs ? { },
  src ? segs: "${builtins.fetchTree lock.nodes.${fetch segs}.locked}",
  # Arity dispatch, because a dependency's root is a function at a shim'd library and a bare value
  # at a leaf, and neither `import p` nor `import p { }` is total over both.
  dep ?
    segs:
    let
      v = import (src segs);
    in
    if builtins.isFunction v then v { } else v,
  # `wire` IS THE THIRD SEAM, AND IT IS THE ONLY OUTWARD CHANNEL THIS FILE HAS. The only place a
  # formal NAME and its resolved PATH are both in scope is this file's argument TO `wire` — Nix
  # publishes WHETHER a formal has a default and never WHAT it is, and a formal is an INPUT channel
  # that cannot carry a value out at all, which is why `resolve` leaves through the same argument
  # rather than through a fourth formal. `wire` RECEIVES `{ deps, resolve }`, not `./lib`: what
  # `./lib` sees is whatever `wire` does with it, and the default below,
  # `{ deps, resolve }: import ./lib deps,`, is the only reason `deps` and `./lib`'s argument
  # coincide here. A cell injecting `dep = segs: segs` alongside `wire = args: args` therefore reads
  # this shim's own formal-to-path map AND its own resolver, with nothing fetched, no path restated
  # and no fold transcribed. The record destructures with no `...`, so a drifted body shape is loud
  # at the default; adding `wire` was likewise a widening that breaks no caller — there is no `...`
  # in this root's pattern, and no caller passes a name it does not declare.
  wire ? { deps, resolve }: import ./lib deps,
  algebra ? inputs.gen-algebra or (dep [ "gen-algebra" ]),
  aspects ? inputs.gen-aspects or (dep [ "gen-aspects" ]),
}:
# THE BODY IS EAGER, AND THAT IS WHAT MAKES THE ENTRY CELL TOTAL RATHER THAN PARTIAL. `forced` forces
# every wired dependency to WHNF before `./lib` sees it, so a default that cannot resolve is loud AT
# THE BOUNDARY rather than wherever a consumer first reaches an attribute. Without it a force of this
# root reaches only the dependencies the published surface happens to be derived from — and
# `builtins.deepSeq` cannot make up the difference, because it does not enter a lambda. Measured at
# this library: a pure force of the landed body reached 0 of its 2 dependency paths, and the cell
# that stood here had to CALL the library over a hand-built registry to reach the resolver at all —
# which still reached `aspects` and not `algebra`, while its own comment claimed both. With the eager
# body a WHNF force of the root reaches both, whatever the published surface's shape.
#
# THE FORCE STOPS AT WHNF DELIBERATELY: `builtins.seq` of an attrset does not force its members, so
# this reaches each dependency's root VALUE and never a member of it. A library that deliberately
# refuses to build some member is therefore not an exception to it.
let
  deps = { inherit algebra aspects; };
  forced = builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) deps) null;
in
builtins.seq forced (wire {
  inherit deps resolve;
})
