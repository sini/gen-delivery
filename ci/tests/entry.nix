# THE STANDALONE ENTRY'S OWN DEFAULTS — the cells no other cell in this repository can be.
#
# Every other cell here takes `genDelivery` from `ci/flake.nix`, which builds it with `import ../lib`
# from ci's own flake INPUTS, so the root shim is never evaluated and its `ci/flake.lock`-backed
# defaults are never forced. That is precisely where this library's non-flake contract lives:
# `import ./. { }` must produce the same library the flake path does, resolving every dependency
# from `./ci/flake.lock` with no argument supplied and no search path consulted.
#
# ★★ THE CALL IS ARITY-DISPATCHED, NOT `import ../.. { }`. A dependency-free library publishes its
# root as a bare VALUE rather than a function, so the literal application is wrong at those roots by
# design; `if builtins.isFunction v then v { } else v` is the one form total over the roster, and it
# is the same construct the shim's own `dep` uses. Writing the literal here would make these cells
# assert a call convention the ecosystem deliberately does not have.
#
# ★★★ THREE CELLS, ONE ORACLE, AND THE FIRST TWO ARE HERMETIC. The obligation is per DEPENDENCY
# PATH, not per library: a cell that reds when ANY ONE dependency is unreachable measures a
# disjunction while reading like a conjunction, and a previous cell here certified this library at 1
# of its 2 paths while green — and its comment claimed both. The three below split the claim so
# nothing carries a coverage figure only a comment states:
#   1. `…-defaults-to-its-own-node` — every WIRED dependency resolves to a node of ITS OWN
#      repository. `expr` and `expected` are both `mapAttrs` over the shim's own formal-to-path map,
#      so the domain is whatever the root wires and never a hand-written list.
#   2. `…-is-the-libs-own-formals` — the DENOMINATOR, taken independently of that map, so an empty
#      map cannot read as a pass.
#   3. `…-forces-every-dependency` — the FORCING half, and the only non-hermetic cell in this file.
#
# ★★ THE DOMAIN IS THE WIRED SET, NOT THE DECLARED SET. `paths` reads the attrset the shim's body
# hands to `./lib` through `wire`, so a formal that is declared and never threaded into that attrset
# is invisible to all three cells. That is a domain statement rather than a gap — the shim's declared
# formals are read by the second cell against `../../lib`'s own, which is where a stray formal
# surfaces.
#
# ★★★ THE THIRD CELL IS NOT HERMETIC, AND THAT IS ITS WHOLE POINT. Forcing the defaults IS
# `builtins.fetchTree`, so it reaches the network — the accepted price of measuring the thing at all,
# and the reason it sits apart from the suites that must not. It remains PURE: `fetchTree` on a
# locked node is narHash-addressed, with no channel and no `<…>`.
#
# ★★ AND IT NEEDS NO WORKLOAD, WHICH IS THE WHOLE OF WHAT THE SHIM'S EAGER BODY BUYS. Of the three
# members this library publishes two are lambdas and the third is a layer-order list independent of
# the substrate, and neither `builtins.deepSeq` nor a per-member force enters a lambda — so a force
# of the SURFACE reaches nothing, and the cell that stood here had to project and realize a
# hand-built registry to reach the resolver at all. The shim now forces its dependencies at the
# boundary, so a WHNF force of the root reaches every one of them whatever the surface's shape.
# Driven per path, seal one and resolve the rest: landed body 0 of 2, landed cell 1 of 2, eager body
# 2 of 2.
{ genDelivery, ... }:
let
  entry = import ../..;
  dispatched = if builtins.isFunction entry then entry { } else entry;

  # ★★ THE SEAM-CLOSING ARGUMENT SET, BOUND RATHER THAN WRITTEN AT THE APPLICATION. `dep` stops the
  # resolver at the path instead of fetching it, and `wire` publishes the attrset the body would
  # otherwise hand to `./lib` — so this application is hermetic by CONSTRUCTION and not by luck. It
  # is bound because an argument set written as a literal at `import ../..` is the bare-application
  # shape this domain's structural cells refuse.
  pathArgs = {
    dep = segs: segs;
    wire = args: args;
  };
  paths = import ../.. pathArgs;

  # ★ THE SHIM'S OWN `following` RULE, TRANSCRIBED. A direct edge IS the node key; a `follows` value
  # is a PATH resolved segment by segment from this lock's own root. Never `lock.nodes.<label>` — a
  # last-segment shortcut reads a DIFFERENT node, and a ci lock routinely carries several same-named
  # ones. Reading the lock is pure data; nothing here fetches.
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  following =
    node: inp:
    let
      v = (lock.nodes.${node}.inputs or { }).${inp};
    in
    if builtins.isString v then v else builtins.foldl' following lock.root v;
  repoOf = segs: lock.nodes.${builtins.foldl' following lock.root segs}.locked.repo;
in
{
  # The two entry paths are ONE library. `genDelivery` is built from ci's flake inputs, `dispatched`
  # from the same `ci/flake.lock` read as data — so this compares the two suppliers of one
  # construction rather than an expression with itself.
  flake.tests.entry.test-the-defaulted-entry-publishes-the-flake-surface = {
    expr = builtins.attrNames dispatched;
    expected = builtins.attrNames genDelivery;
  };

  # ★★ EVERY WIRED DEPENDENCY RESOLVES, AND RESOLVES TO A NODE OF ITS OWN REPOSITORY. The shim states
  # its intent as a PATH; this resolves that path through the same lock by the same rule and asks
  # which repository the node it lands on belongs to. A path repointed at a live-but-wrong dependency
  # — the failure a surface comparison and a whole-seam seal both pass — reds here, naming the formal
  # and the repository it reached.
  #
  # ★ STATED CEILING: `locked.repo` is neither `owner` nor node identity. A same-named repository
  # under another owner passes, and so does a path repointed at a DIFFERENT NODE of the right
  # repository — the shim's declared path is the only statement of intent, so there is no independent
  # `expected` to compare a resolved node against. Recorded open rather than repaired.
  flake.tests.entry.test-every-declared-dependency-defaults-to-its-own-node = {
    expr = builtins.mapAttrs (_: repoOf) paths;
    expected = builtins.mapAttrs (formal: _: "gen-" + formal) paths;
  };

  # ★★ THE DENOMINATOR, TAKEN INDEPENDENTLY — without it the cell above is vacuous over an empty map.
  # `paths` is what the root WIRES; `functionArgs (import ../../lib)` is what the library REQUIRES,
  # read from a different file by a different builtin. A dependency dropped from the shim's body reds
  # here even though every surviving path still resolves.
  flake.tests.entry.test-the-wired-dependency-set-is-the-libs-own-formals = {
    expr = builtins.attrNames paths;
    expected = builtins.attrNames (builtins.functionArgs (import ../../lib));
  };

  # ★★★ THE DEFAULTS THEMSELVES, FORCED. `builtins.seq` of the dispatched root runs the shim's eager
  # body, which forces every wired dependency to WHNF before `./lib` sees it — so this reaches a
  # nonexistent node, an unresolvable follows path or a throwing root at the BOUNDARY, on every path,
  # rather than wherever a consumer first happens to reach one.
  #
  # ★ THE FORCE STOPS AT WHNF, DELIBERATELY: `seq` of an attrset does not force its members, so this
  # never reaches into a dependency's own surface and a member a dependency deliberately refuses to
  # build is not an exception to it.
  flake.tests.entry.test-the-defaulted-entry-forces-every-dependency = {
    expr = builtins.seq dispatched "forced";
    expected = "forced";
  };
}
