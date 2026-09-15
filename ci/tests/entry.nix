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
# ★★ AND FOUR CELLS BELOW THEM, ONE PER INVARIANT THE THREE ABOVE REST ON AND EACH OF WHICH READ
# FULLY GREEN ON A TREE CARRYING ITS OWN DEFECT before they existed: the shim's `wire` default (with
# its control), the `follows` walk this file transcribes (a control over a hermetic fixture lock, and
# the whole oracle for that rule), and channel 2 of the shim's three, the `inputs` override bag.
#
# ★★ THE DOMAIN IS THE WIRED SET, NOT THE DECLARED SET — AND IT IS THE ATTRSET THE SHIM'S BODY
# HANDS TO `wire`, NOT THE ONE `./lib` RECEIVES. The two coincide only while `wire`'s own default is
# `args: import ./lib args`, which is a property of ONE LINE OF TEXT and is held by
# `…-the-wire-default-is-the-librarys-own-application` below and by nothing else. `paths` reads the
# attrset handed to `wire`, so a formal that is declared and never threaded into it is invisible to
# every cell over it. That is a domain statement rather than a gap — the shim's declared formals are
# read by the DENOMINATOR cell against `../../lib`'s own, which is where a stray formal surfaces.
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
  # resolver at the path instead of fetching it, and replacing `wire` publishes the attrset the
  # body hands TO `wire` — which is the attrset `./lib` receives only while `wire`'s own default is
  # `args: import ./lib args`, a text property the cell at the foot of this file is what holds. So
  # this application is hermetic by CONSTRUCTION and not by luck. It is bound because an argument set
  # written as a literal at `import ../..` is the bare-application shape this domain's structural
  # cells refuse.
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

  # ★★ THE RESOLVER IS BOUND OVER ITS LOCK, AND THAT IS WHAT MAKES ITS CONTROL EXPRESSIBLE AT ALL. A
  # `repoOf` closed over THIS lock has no free parameter, so a control could only re-assert the main
  # arm's own value; taking the lock as an argument is what puts the control AT AN INPUT THE MAIN ARM
  # DOES NOT USE. The `lock` formal deliberately shadows the binding above — inside here the lock is
  # whatever this application was handed, which is the whole of the point.
  #
  # ★★★ AND THE CONTROL IS NOT CEREMONY, IT IS THE ENTIRE ORACLE FOR THIS RULE. MEASURED: with the
  # fold below replaced by the `lock.nodes.<last segment>` shortcut the comment above forbids, the
  # entry suite read FULLY GREEN at all four tranche-1 libraries. 3 of their 13 wired paths resolve
  # to a DIFFERENT NODE under that shortcut and two of those at a different REVISION — but
  # `locked.repo` is identical under both rules at all 13, so `…-defaults-to-its-own-node` cannot
  # discriminate its own resolver anywhere, and at a library whose every path agrees under both rules
  # no plant could red it even in principle. A hermetic fixture is the only thing that can.
  repoOf =
    lock:
    let
      following =
        node: inp:
        let
          v = (lock.nodes.${node}.inputs or { }).${inp};
        in
        if builtins.isString v then v else builtins.foldl' following lock.root v;
    in
    segs: lock.nodes.${builtins.foldl' following lock.root segs}.locked.repo;

  # ★ THE FIXTURE LOCK, AND IT IS TWO CLAIMS IN ONE SHAPE. `root → a` is a DIRECT edge, where the
  # value IS the node key; `a-node → b` is a `follows` PATH resolved from the lock's own root — so
  # both branches of `following` are exercised. Walking `[ "a" "b" ]` lands on `the-walked-node`;
  # indexing the last segment lands on the unrelated node keyed `b`. The two rules disagree BY
  # CONSTRUCTION, which is what makes the control total over every library rather than over the ones
  # whose own lock happens to disagree. It is a literal: nothing here reads a file or fetches.
  followsFixture = {
    root = "root";
    nodes = {
      root.inputs = {
        a = "a-node";
        elsewhere = "the-walked-node";
      };
      a-node.inputs.b = [ "elsewhere" ];
      the-walked-node.locked.repo = "gen-walked";
      b.locked.repo = "gen-indexed";
    };
  };

  # ★★ THE SHIM'S `wire` DEFAULT, COUNTED AS TEXT. `[[:space:]]` spans the newline a formatter may
  # put anywhere inside the default, and COMMENTS ARE STRIPPED FIRST — load-bearing here rather than
  # prophylactic, because the shim's own prose quotes this default, so an unstripped scan keeps
  # reading 1 on a file whose CODE has been rewired. Bound once and read by BOTH cells below: two
  # literals spelled the same are two predicates, and the control would then guard only its own copy.
  wireNeedle = ''wire[[:space:]]*\?[[:space:]]*args:[[:space:]]*import[[:space:]]+\./lib[[:space:]]+args[[:space:]]*,'';
  countWire =
    text:
    builtins.length (
      builtins.filter builtins.isList (
        builtins.split wireNeedle (
          builtins.concatStringsSep "" (builtins.filter builtins.isString (builtins.split "#[^\n]*" text))
        )
      )
    );
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
  flake.tests.entry.test-every-wired-dependency-defaults-to-its-own-node = {
    expr = builtins.mapAttrs (_: repoOf lock) paths;
    expected = builtins.mapAttrs (formal: _: "gen-" + formal) paths;
  };

  # ★★★ THE DISCRIMINATING HALF OF THE CELL ABOVE — and for the `follows` rule it is the whole
  # oracle, not a supplement to one. The two arms SHARE `repoOf`, and this one exercises it AT AN
  # INPUT THE MAIN ARM DOES NOT USE: a hand-written lock whose path walk and whose last-segment
  # shortcut land on different nodes by construction. Replace the fold with the shortcut and this
  # reds at every library carrying this file; the cell above reds at none of them, because it reads
  # `locked.repo` and the two rules agree on `locked.repo` at all 13 tranche-1 paths while disagreeing
  # on the NODE at 3 of them.
  flake.tests.entry.test-control-the-follows-resolver-discriminates = {
    expr = repoOf followsFixture [
      "a"
      "b"
    ];
    expected = "gen-walked";
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

  # ★★★ THE SHIM'S OWN `wire` DEFAULT, AND IT IS WHAT EVERY HERMETIC CELL ABOVE RESTS ON. `paths` is
  # the attrset the shim's body hands to `wire` — it is the attrset `./lib` RECEIVES only while
  # `wire`'s own default is `args: import ./lib args`, and no cell above reads that default: the two
  # hermetic cells REPLACE `wire` with `args: args`, the forcing cell stops at WHNF of whatever
  # `wire` returned, and the surface cell compares `attrNames`, which `./lib`'s structure fixes
  # independently of its arguments. MEASURED, both arms in one run: with the default replaced by
  # `args: import ./lib (args // { <a wired formal> = throw "…"; })` this suite read FULLY GREEN at
  # all four tranche-1 libraries, while `deepSeq (import ./. { }) "ok"` read rc 1 at two of them
  # against a clean rc 0 — a demonstrably broken library under a green suite.
  #
  # ★★ THE READING IS IRREDUCIBLY TEXTUAL, AND THAT IS THE SEAM'S OWN REASON FOR EXISTING: Nix
  # publishes WHETHER a formal has a default and never WHAT it is, so there is no semantic
  # construction to compare against. It is the same argument
  # `test-the-entry-is-never-applied-to-a-literal` carries in this domain — the edit that
  # reintroduces the defect is the same edit that would remove any semantic instrument for it.
  flake.tests.entry.test-the-wire-default-is-the-librarys-own-application = {
    expr = countWire (builtins.readFile ../../default.nix);
    expected = 1;
  };

  # ★★★ THE DISCRIMINATING HALF, IN THREE ARMS BECAUSE THE PREDICATE HAS THREE WAYS TO BE DEAD. Both
  # cells read the one `countWire` binding, and this one exercises it AT AN INPUT THE MAIN ARM DOES
  # NOT USE — assembled fixtures, never `../../default.nix`. `exact` proves it can count the real
  # default at all; `rewired` proves it refuses the one-token corruption the main arm exists to
  # catch; `commented` proves the comment strip is LIVE, and that arm is the sharp one — the same
  # text unstripped reads 1, which is precisely the false green a scan of a self-documenting shim
  # would otherwise return.
  flake.tests.entry.test-control-the-wire-default-check-discriminates = {
    expr = {
      exact = countWire "wire ? args: import ./lib args,";
      rewired = countWire ''wire ? args: import ./lib (args // { x = throw "no"; }),'';
      commented = countWire ''
        # wire ? args: import ./lib args,
        wire ? args: import ./lib (args // { }),
      '';
    };
    expected = {
      exact = 1;
      rewired = 0;
      commented = 0;
    };
  };

  # ★★★ CHANNEL 2 — THE `inputs` OVERRIDE BAG. The shim declares three channels and one precedence:
  # a named formal wins, the bag is next, tested by attrset membership, and the ci lock is the
  # default. Every cell above exercises the LOCK, so a formal transcribed as `x ? dep [ … ]` instead
  # of `x ? inputs.gen-x or (dep [ … ])` leaves its override silently ignored — MEASURED, both arms
  # in one run: on that one edit the supplied override is dropped and the whole entry suite reads
  # green. ★ It is the channel that matters most where the flake arm is UNAPPLIED, which is three of
  # the four libraries carrying this file: there the bag is the ONLY override path a consumer has.
  #
  # ★★ TOTAL OVER THE WIRED SET BY CONSTRUCTION. `expr` and `expected` are both derived from
  # `paths`, so the domain is whatever the root wires and never a hand-written list, and the
  # denominator is taken independently by `…-is-the-libs-own-formals`, so an empty map cannot read as
  # a pass. The sentinels are DISTINCT per formal, so a bag key wired to the wrong formal reds too.
  # It is hermetic: `pathArgs` closes `dep`, and with every formal overridden no default is reached.
  flake.tests.entry.test-the-inputs-bag-overrides-every-wired-default =
    let
      overrides = builtins.mapAttrs (formal: _: "the ${formal} override, from the inputs bag") paths;
      bag = builtins.listToAttrs (
        map (formal: {
          name = "gen-" + formal;
          value = overrides.${formal};
        }) (builtins.attrNames paths)
      );
    in
    {
      expr = import ../.. (pathArgs // { inputs = bag; });
      expected = overrides;
    };
}
