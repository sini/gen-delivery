# THE STANDALONE ENTRY'S OWN DEFAULTS, FORCED — the cell no other cell in this repository can be.
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
# is the same construct the shim's own `dep` uses. Writing the literal here would make this cell
# assert a call convention the ecosystem deliberately does not have.
#
# ★★★ THIS CELL IS NOT HERMETIC, AND THAT IS ITS WHOLE POINT. Forcing the defaults IS
# `builtins.fetchTree`, so this cell reaches the network — the accepted price of measuring the thing
# at all, and the reason it sits apart from the suites that must not. It remains PURE: `fetchTree`
# on a locked node is narHash-addressed, with no channel and no `<…>`.
#
# ★★ AND THE SURFACE COMPARISON ALONE WOULD NOT REACH THE RESOLVER. Measured over this library: of
# its three published members two are lambdas and the third is a layer-order list independent of the
# substrate, and neither `builtins.deepSeq` nor a per-member WHNF force enters a lambda — so with the
# shim's `src` seam sealed by a `throw`, a whole-surface force still returns rc 0. The second cell
# therefore CALLS the library, which is what carries the force across the argument boundary and into
# the defaults. Driven both ways: seam sealed ⇒ rc 1 at the seam, seam open ⇒ rc 0.
#
# ★ THE REGISTRY IS HAND-BUILT, for the reason `realization-predicate.nix` states about its own: this
# cell's subject is the SHIM, not the rendering, and a hand-built registry reaches the predicate
# without standing up a second aspect-schema evaluation whose substrate would then be ci's rather
# than the shim's. Both halves of the substrate are exercised — `project` reads the key-category
# declaration through `aspects`, `realize` folds contributions through `algebra`.
{ genDelivery, ... }:
let
  entry = import ../..;
  dispatched = if builtins.isFunction entry then entry { } else entry;

  cnf = {
    keySemantics.nixos.category = "class";
  };

  values = {
    aspects.web = {
      name = "web";
      nixos.imports = [ ({ ... }: { }) ];
    };
    hosts.n1 = {
      name = "n1";
      aspects = [ "web" ];
    };
  };

  projected = dispatched.project {
    inherit values cnf;
    selectHosts = v: v.hosts;
  };

  # A terminal that reports the SHAPE of what it was handed without evaluating any of it, the same
  # construction `class-content.nix` uses for the same reason.
  countingTerminal =
    { name, modules, ... }:
    {
      inherit name;
      count = builtins.length modules;
    };
in
{
  # The two entry paths are ONE library. `genDelivery` is built from ci's flake inputs, `dispatched`
  # from the same `ci/flake.lock` read as data — so this compares the two suppliers of one
  # construction rather than an expression with itself.
  flake.tests.entry.test-the-defaulted-entry-publishes-the-flake-surface = {
    expr = builtins.attrNames dispatched;
    expected = builtins.attrNames genDelivery;
  };

  # The defaults are RESOLVED, not merely declared, and both of them are: the projection reaches
  # `aspects` and the fold reaches `algebra`.
  flake.tests.entry.test-the-defaulted-entry-resolves-its-dependencies-from-its-ci-lock = {
    expr = builtins.deepSeq (dispatched.realize {
      inherit projected;
      terminals.nixos = countingTerminal;
    }) "resolved";
    expected = "resolved";
  };
}
