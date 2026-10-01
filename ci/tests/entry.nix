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
# ★★ AND FOUR CELLS BELOW THEM, CLOSING THREE INVARIANTS THE THREE ABOVE REST ON, EACH OF WHICH READ
# FULLY GREEN ON A TREE CARRYING ITS OWN DEFECT AT ALL FOUR TRANCHE-1 LIBRARIES before they existed:
# the shim's `wire` default (with its control), the `follows` walk — declared ONCE, in `default.nix`,
# and READ here rather than transcribed, so the control over a hermetic fixture lock is the whole
# oracle for that rule — and channel 2 of the shim's three, the `inputs` override bag.
#
# ★★ THE DOMAIN IS THE WIRED SET, NOT THE DECLARED SET — AND IT IS THE `deps` HALF OF THE RECORD
# THE SHIM'S BODY HANDS TO `wire`, NOT THE ATTRSET `./lib` RECEIVES. The two coincide only while
# `wire`'s own default is `{ deps, resolve, lock }: import ./lib deps`, which is a property of ONE LINE OF
# TEXT and is held by `…-the-wire-default-is-the-librarys-own-application` below and by nothing else.
# `paths` reads the `deps` handed to `wire`, so a formal that is declared and never threaded into it
# is invisible to every cell over it. That is a domain statement rather than a gap — the shim's
# declared formals are read by the DENOMINATOR cell against `../../lib`'s own, which is where a stray
# formal surfaces.
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
  # resolver at the path instead of fetching it, and replacing `wire` publishes the whole record the
  # body hands TO `wire` — whose `deps` half is the attrset `./lib` receives only while `wire`'s own
  # default is `{ deps, resolve, lock }: import ./lib deps`, a text property the cell at the foot of this
  # file is what holds, and whose `resolve` half is the shim's own `follows` rule, which is why
  # nothing below transcribes that rule. So this application is hermetic by CONSTRUCTION and not by
  # luck. It is bound because an argument set written as a literal at `import ../..` is the
  # bare-application shape this domain's structural cells refuse.
  pathArgs = {
    dep = segs: segs;
    wire = args: args;
  };
  seam = import ../.. pathArgs;
  paths = seam.deps;

  # ★★★ THE SHIM'S OWN RESOLVER, READ RATHER THAN RETRANSCRIBED. `default.nix` holds the ONE
  # declaration of the `follows` rule in this library and publishes it in the record its body hands
  # to `wire`; this is that binding and not a copy of it. So the fixture control below drives the
  # expression the shim itself resolves with, and `…-defaults-to-its-own-node` resolves the shim's
  # declared paths by the shim's own rule rather than by a second copy that can agree with its own
  # expectation while both are wrong.
  shimResolve = seam.resolve;

  # ★ THE ROOT LOCK, READ AS PURE DATA — and the rule that walks it is NO LONGER TRANSCRIBED HERE:
  # `shimResolve` above IS `default.nix`'s binding. A direct edge IS the node key; a `follows` value
  # is a PATH resolved segment by segment from this lock's own root. Never `lock.nodes.<label>` — a
  # last-segment shortcut reads a DIFFERENT node, and a ci lock routinely carries several same-named
  # ones. Reading the lock is pure data; nothing here fetches.
  lock = seam.lock;

  # ★★ THE RESOLVER IS BOUND OVER ITS LOCK, AND THAT IS WHAT MAKES ITS CONTROL EXPRESSIBLE AT ALL. A
  # `repoOf` closed over THIS lock has no free parameter, so a control could only re-assert the main
  # arm's own value; taking the lock as an argument is what puts the control AT AN INPUT THE MAIN ARM
  # DOES NOT USE. `shimResolve` takes its lock the same way and for the same reason — which is why
  # `default.nix` publishes the LOCK-PARAMETERISED rule rather than its own applied `fetch`. The
  # `lock` formal here deliberately shadows the binding above.
  #
  # ★★★ AND THE CONTROL IS NOT CEREMONY, IT IS THE ENTIRE ORACLE FOR THIS RULE — which this library
  # declares EXACTLY ONCE, in `default.nix`, so *this rule* now names one expression and not two.
  # MEASURED at the four tranche-1 libraries while the cell still carried a second copy of the fold:
  # with the SHIM's fold replaced by the `lock.nodes.<last segment>` shortcut its own comment
  # forbids, the entry suite read FULLY GREEN at all four. 3 of their 13 wired paths resolve to a
  # DIFFERENT NODE under that shortcut and two of those at a different REVISION — but `locked.repo`
  # is identical under both rules at all 13, so `…-defaults-to-its-own-node` cannot discriminate a
  # resolver on this library's real lock at all. A hermetic fixture is the only thing that can, and
  # it now drives the SHIM's binding: with that same shortcut written into `default.nix`'s `resolve`,
  # the control below reds — rc 1, and exactly one failing cell, at all four tranche-1 libraries.
  #
  # ★ THE REPOSITORY OF A NODE IS READ BY gen-harness `ci-self-input.nix`'s RULE, inlined because the
  # harness exports no helper for it: a `github`/`gitlab`/`sourcehut` node names it in `locked.repo`,
  # and a `git` node, which is what every `git+file` override of a dependency locks to, names it only
  # as the last segment of `locked.url` with `.git` stripped. Any other type names no repository and
  # reads `null`, which the cell reports as a mismatch rather than throwing.
  repoOf =
    lock: segs:
    let
      l = lock.nodes.${shimResolve lock segs}.locked;
      seg = builtins.elemAt (builtins.match "(.*/)?([^/]*)" (l.url or "")) 1;
      bare = builtins.match "(.*)[.]git" seg;
    in
    if l ? repo then
      l.repo
    else if (l.type or "") == "git" && l ? url then
      (if bare == null then seg else builtins.head bare)
    else
      null;

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
  wireNeedle = ''wire[[:space:]]*\?[[:space:]]*[{][[:space:]]*deps[[:space:]]*,[[:space:]]*resolve[[:space:]]*,[[:space:]]*lock[[:space:]]*,?[[:space:]]*[}][[:space:]]*:[[:space:]]*import[[:space:]]+\./lib[[:space:]]+deps[[:space:]]*,'';
  countWire =
    text:
    builtins.length (
      builtins.filter builtins.isList (
        builtins.split wireNeedle (
          builtins.concatStringsSep "" (builtins.filter builtins.isString (builtins.split "#[^\n]*" text))
        )
      )
    );

  # ★ THE THIRD NEEDLE, AND IT SCANS THE COMPLEMENT OF THE ONE PERMITTED SHAPE, never the defect's
  # spelling: every binding of `lock` is captured, and any right-hand side other than `seam.lock` is
  # offending — so a path bound a statement earlier, an aliased `readFile` and a read moved into a
  # second file red exactly as the 2026-09-16 reversion does. The leading class keeps `lockPath =`
  # and `seedlock =` out, `[^=;]` keeps `lock ==` out, and `seamBound` counts the permitted shape
  # itself, so a binding moved into an `inherit`, which no `lock =` scan can see, reds on its
  # absence. COMMENTS ARE STRIPPED FIRST, for the reason `wireNeedle`'s scan strips them.
  lockBindingNeedle = "(^|[^[:alnum:]_'-])lock[[:space:]]*=([^=;][^;]*);";
  lockBindingsOf =
    text:
    let
      rhss = map (m: builtins.elemAt m 1) (
        builtins.filter builtins.isList (
          builtins.split lockBindingNeedle (
            builtins.concatStringsSep "" (builtins.filter builtins.isString (builtins.split "#[^\n]*" text))
          )
        )
      );
      isSeam = rhs: builtins.match "[[:space:]]*seam[.]lock[[:space:]]*" rhs != null;
    in
    {
      offending = builtins.length (builtins.filter (rhs: !isSeam rhs) rhss);
      seamBound = builtins.length (builtins.filter isSeam rhss);
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
  # oracle, not a supplement to one, because the rule has ONE declaration and `repoOf` is built over
  # it. The two arms SHARE `repoOf`, hence share `shimResolve`, hence share `default.nix`'s own
  # fold; this one exercises it AT AN INPUT THE MAIN ARM DOES NOT USE, a hand-written lock whose
  # path walk and whose last-segment shortcut land on different nodes by construction. Replace the
  # fold in `default.nix` with the shortcut and this reds at every library carrying this file —
  # measured rc 1 with exactly one failing cell at all four tranche-1 libraries, where the same plant
  # read fully green while
  # this file still transcribed the rule a second time. The cell above cannot be relied on to: it
  # reads `locked.repo`, and at tranche 1 the two rules agreed on `locked.repo` at all 13 wired
  # paths while disagreeing on the NODE at 3 of them — so it red at none of the four.
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
  # the `deps` half of the record the shim's body hands to `wire` — it is the attrset `./lib`
  # RECEIVES only while `wire`'s own default is `{ deps, resolve, lock }: import ./lib deps`, and no cell
  # above reads that default: the two hermetic cells REPLACE `wire` with `args: args`, the forcing
  # cell stops at WHNF of whatever `wire` returned, and the surface cell compares `attrNames`, which
  # `./lib`'s structure fixes independently of its arguments. MEASURED, both arms in one run: with
  # the default replaced by `args: import ./lib (args // { <a wired formal> = throw "…"; })` this
  # suite read FULLY GREEN at all four tranche-1 libraries, while `deepSeq (import ./. { }) "ok"`
  # read rc 1 at two of them against a clean rc 0 — a demonstrably broken library under a green
  # suite.
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
      exact = countWire "wire ? { deps, resolve, lock }: import ./lib deps,";
      rewired = countWire ''wire ? { deps, resolve, lock }: import ./lib (deps // { x = throw "no"; }),'';
      commented = countWire ''
        # wire ? { deps, resolve, lock }: import ./lib deps,
        wire ? { deps, resolve, lock }: import ./lib (deps // { }),
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
  # green. ★ It matters most where the flake arm is UNAPPLIED — the root published as `import ./.`
  # rather than applied — because there the bag is the ONLY override path a consumer has. At tranche
  # 1 that was three of the four.
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
      expr = (import ../.. (pathArgs // { inputs = bag; })).deps;
      expected = overrides;
    };

  # ★★★ `…-defaults-to-its-own-node` COMPARES A REPOSITORY NAME, SO IT CANNOT TELL WHICH LOCK IT
  # READ: two locks naming one repository at two revisions agree on `locked.repo`. Measured
  # 2026-09-16 (`specs/2026-09-15-gen-pin-source-split-spec.md` §2.2): `lock` above left reading the
  # ci lock after `default.nix` had moved to the root lock, and that cell stayed green. There is no
  # independently declared revision to compare against, so the fix is not a comparison: `lock` is
  # read through `seam`, the value `default.nix`'s own `fetch` closes over — the move this file
  # already makes for `resolve`. This cell makes the sharing an obligation: THIS FILE'S OWN TEXT
  # binds `lock` exactly once, to `seam.lock`, and to nothing else anywhere.
  flake.tests.entry.test-the-lock-is-read-through-the-shims-own-seam = {
    expr = lockBindingsOf (builtins.readFile ./entry.nix);
    expected = {
      offending = 0;
      seamBound = 1;
    };
  };

  # ★★ THE DETECTOR IS SHOWN ABLE TO FIRE on each way a second read of the lock comes back, and
  # silent on the permitted shape. ASSEMBLED, NOT WRITTEN: every fixture binding is split inside
  # `lock`, so the main arm's scan of this file does not read the fixtures as bindings of its own.
  flake.tests.entry.test-control-the-lock-provenance-check-discriminates = {
    expr = builtins.mapAttrs (_: lockBindingsOf) {
      permitted = "  lo" + "ck = seam.lock;\n";
      ciLock = "  lo" + "ck = builtins.fromJSON (builtins.readFile ../flake.lock);\n";
      reflowed =
        "  lo" + "ck =\n    builtins.fromJSON\n      (builtins.readFile\n        ../../flake.lock);\n";
      pathBound =
        "  lockPath = ../../flake.lock;\n  lo" + "ck = builtins.fromJSON (builtins.readFile lockPath);\n";
      aliased =
        "  readLock = builtins.readFile;\n  lo" + "ck = builtins.fromJSON (readLock ../../flake.lock);\n";
      secondFile = "  lo" + "ck = import ./lock-reader.nix;\n";
      inherited = "  inherit (import ./lock-reader.nix) lock;\n";
    };
    expected = {
      permitted = {
        offending = 0;
        seamBound = 1;
      };
      ciLock = {
        offending = 1;
        seamBound = 0;
      };
      reflowed = {
        offending = 1;
        seamBound = 0;
      };
      pathBound = {
        offending = 1;
        seamBound = 0;
      };
      aliased = {
        offending = 1;
        seamBound = 0;
      };
      secondFile = {
        offending = 1;
        seamBound = 0;
      };
      inherited = {
        offending = 0;
        seamBound = 0;
      };
    };
  };
}
