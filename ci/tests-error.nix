# THE SECOND TEST OUTPUT — cells whose subject is an ERROR MESSAGE, and why they cannot live in
# `flake.tests`.
#
# THAT a construction refuses is a boolean and `tryEval` asserts it; those cells live in the suites.
# WHICH refusal fired is a claim about the message, and `tryEval` returns `{ success, value }` and
# DISCARDS the text — so a suite of booleans alone is equally satisfied by a construction with one
# refusal in it, and a reworded message regresses nothing any cell reads. nix-unit's `expectedError`
# is the assertion for that, and this is where it goes.
#
# ★ WHY A SECOND OUTPUT RATHER THAN A SECOND SUITE. The batch asserter behind `checks.default`
# evaluates `t.expr == t.expected` UNCONDITIONALLY and quantifies over `config.flake.tests` and
# nothing else, so a cell with no `expected` and a throwing `expr` CRASHES that gate rather than
# failing it. Hosting these on `flake.testsError` puts them outside that quantifier while keeping
# them live on the nix-unit path. The split is structural, not conventional: this file is not under
# ./tests, which is the whole of `testModules`.
#
#   nix-unit --flake ./ci#tests        # the suites
#   nix-unit --flake ./ci#testsError   # these cells
#
# ★★ `expectedError.msg` IS SEARCHED, NOT WHOLE-MATCHED, so a pattern naming a PREFIX of the message
# passes against a message that says something else after it — which would make these cells agree
# with the very rewording they exist to catch. Every pattern below is anchored at both ends and
# built by ESCAPING THE LITERAL TEXT rather than by hand.
{
  genDelivery,
  genDeliveryWith,
  scope,
  lib,
  aspects,
  genMerge,
  term,
  prelude,
  ...
}:
let
  exactly = msg: "^" + lib.escapeRegex msg + "$";
  # gen-prelude's refusal text, composed with this library's own literal door, field and accepted
  # set (den-hoag-7jltk): every assertion kept, none of gen-prelude's wording copied.
  inherit (prelude) refusals;
  fx = import ./parametric-fixture.nix {
    inherit
      genDelivery
      aspects
      genMerge
      term
      ;
  };

  # Held as one binding because the text is long enough that inlining it beside the `exactly` call
  # invites a `+` that binds looser than the application and silently anchors only its first term.
  missingCategorySource =
    "gen-delivery: project: no category source — `cnf` is required and has no default. "
    + "The realization predicate reads the key-category declaration; with none it could only fall "
    + "back to a structural shape test.";

  noNodeSelector =
    "gen-delivery: project: no node selector — `selectNodes` is required and has no default. It "
    + "names WHICH resolved attrset of the caller's values holds the node instances.";

  duplicateLayer =
    "gen-delivery: realize: layerOrder repeats contribution layer(s) projection — a sequence with "
    + "duplicates is not an order, and the LAST occurrence would decide, silently inverting the "
    + "declared precedence";

  retiredNodeKeyedShape =
    "gen-delivery: realize: extraModules.n is not an attrset — extraModules is CLASS-MAJOR, "
    + "{ <class>.<node> = [ module ]; }; the node-keyed { <node> = [ module ]; } shape was retired "
    + "because it reached every class's terminal";

  noDeclaredContent =
    "gen-delivery: realize: extraModules.a.m addresses a node with no declared a content — a delivery "
    + "class realizes only on declared content, so a does not realize there and the extras would be dropped";

  # ── THE INCLUDE CLOSURE'S REFUSALS ── one tree per refusal, over a raw `hosts` attrset so a member
  # can be written as something other than a string. The expression forces the node's class names,
  # which is where the closure is walked.
  closureClasses =
    members: mods:
    let
      cnf.keySemantics.nixos.category = "class";
      values =
        (genMerge.evalModuleTree { } (
          [
            ((aspects.mkAspectSchema cnf).mkAspectModule { })
            {
              options.hosts = genMerge.mkOption {
                type = genMerge.types.attrsOf genMerge.types.raw;
                default = { };
              };
            }
            { hosts.server.aspects = members; }
          ]
          ++ mods
        )).config;
    in
    builtins.attrNames
      (genDelivery.project { selectNodes = v: v.hosts; } cnf values).nodes.server.classes;
  # A context closure: gen-aspects refuses it upstream (den-hoag-lwbb1 stage 2b), naming the gen-rules
  # door, before delivery reads it. The parametric shape that still reaches delivery's own refusals is
  # a first-order guard, `hostGuard`.
  hostFn =
    { host, ... }:
    {
      nixos.marks = [ host.name ];
    };
  hostGuard = aspects.guard (aspects.pred.has "host") { nixos.marks = [ "host" ]; };
  # gen-aspects' bare-closure refusal at `loc`, the text a user meets for a context closure. It is the
  # one pattern in this file anchored at the START only: the text is gen-aspects', so these cells pin its
  # identifying sentence and the position they exist to check, and the guidance after it is gen-aspects'
  # to reword without reddening this repository.
  upstreamClosureRefusal =
    loc:
    "^"
    + lib.escapeRegex "gen-aspects: aspect `${loc}`: a context closure reached a gen-aspects-typed position. ";

  instancesShape = "gen-delivery: project: instances must be gen-aspects' instance relation { vertices; instantiates; reaches; nestedAt; declined = { reaches; nestedAt; }; }, each an attrset";
  memberUnknown = "gen-delivery: project: node 'server' names aspect 'ghost' as a member, and no aspect has that key";
  memberNotIdentifier =
    "gen-delivery: project: node 'server' lists a member that is not an aspect identifier (a set); "
    + "a member is named by its aspect's key";
  foreignInclude =
    "gen-delivery: project: aspect 'a' includes at position 0 a reference into origin 'acme', which "
    + "this tree does not hold; project delivers only what it can reach, so federate the trees first";
  sealedInclude =
    position:
    "gen-delivery: project: aspect 'a' carries at include position ${position} an element that is "
    + "neither a reference to an aspect nor inline aspect content: a guard there is not a declared "
    + "aspect, so the instance relation can hold no instance of it (declare it as a named aspect and "
    + "include it by key), and any other value (a list, a number) is not an aspect";
  # Inside an anonymous declaration: the refusal names its node, then the aspect it was written in,
  # with the position path from that aspect (den-hoag-8hlo3).
  sealedInlineInclude =
    id: position:
    "gen-delivery: project: aspect '${id}', inline content of aspect 'a', carries at include position ${position} an element that is "
    + "neither a reference to an aspect nor inline aspect content: a guard there is not a declared "
    + "aspect, so the instance relation can hold no instance of it (declare it as a named aspect and "
    + "include it by key), and any other value (a list, a number) is not an aspect";
  noInstance =
    node: a: inst:
    "gen-delivery: project: node '${node}' reaches parametric aspect '${a}'"
    + (if inst == null then "" else " inside instance '${inst}'")
    + ", and the instance relation holds no instance of it there; project reads instances, it never mints them";
  undecided =
    node: a: inst:
    "gen-delivery: project: node '${node}' reaches parametric aspect '${a}'"
    + (if inst == null then "" else " inside instance '${inst}'")
    + ", and the instance relation neither lists an instance of it there nor declined it: either the "
    + "relation never walked it there (it was minted over other members or another tree than project "
    + "reads), or its condition read a coordinate the scope does not supply under the open world "
    + "(declare the coordinate set to make that absence FALSE)";
  declinedNotList =
    scope: t:
    "gen-delivery: project: the instance relation's declined aspects at '${scope}' must be a list of aspect ids, got ${t}";
  # THE PROJECTION-PARITY DOOR's two arms (den-hoag-htfv3-stage-c-graph-query-xm29n). The vertex
  # named is the least of the ones in dispute.
  parity =
    node: v: inQuery:
    "gen-delivery: project: node '${node}' "
    + (
      if inQuery then
        "reaches '${v}' through the instance relation's edges, and its declared include sites never reach it: the relation was minted over other members or another tree than project reads"
      else
        "delivers '${v}' in declared order, and the receiver-rooted query never reaches it"
    );
  least = xs: builtins.head (builtins.sort builtins.lessThan xs);
  # S1: `project` built with a `scope` whose `resolve` answers nothing.
  fxEmptied = import ./parametric-fixture.nix {
    genDelivery = genDeliveryWith (
      scope
      // {
        resolve =
          o: s: from:
          scope.resolve o s from // { answers = [ ]; };
      }
    );
    inherit aspects genMerge term;
  };
  # S3: `reaches.na` over-lists `nei`'s instance of `ei`, minted at another scope.
  eiAtNei = builtins.head fx.rel.reaches.nei.ei;
  overlisted = fx.withView (
    fx.rel
    // {
      reaches = fx.rel.reaches // {
        na = fx.rel.reaches.na // {
          inherit (fx.rel.reaches.nei) ei;
        };
      };
    }
  ) "na";
  # The parametric fixture's views, each planted with one fault on `na`'s edge to `p`.
  pAtNa = fx.iidOf "na" "p";
  plant = view: fx.withView (fx.rel // view) "na";
  plantEdge =
    e:
    plant {
      reaches = fx.rel.reaches // {
        na = fx.rel.reaches.na // {
          p = e;
        };
      };
    };
  edgeFrom = "gen-delivery: project: the instance relation's edge";

  # ── THE DELIVERY-CLASS MAP'S REFUSALS ── nodes a, b, c carry T content (`web`); `withU` adds U
  # content (`extra`) at a. The expression deep-forces the realization, so a refusal on any spine
  # surfaces.
  mapped =
    {
      deliveryClasses,
      withU ? false,
      terminals ? {
        T1 = _: 1;
        T2 = _: 2;
      },
      selectNodes ? v: v.hosts,
    }:
    let
      cnf.keySemantics = {
        T.category = "class";
        U.category = "class";
      };
      values =
        (genMerge.evalModuleTree { } [
          ((aspects.mkAspectSchema cnf).mkAspectModule { })
          {
            options.hosts = genMerge.mkOption {
              type = genMerge.types.attrsOf genMerge.types.raw;
              default = { };
            };
          }
          {
            aspects.web.T.marks = [ "web" ];
            aspects.extra.U.marks = [ "u" ];
            hosts = {
              a.aspects = [ "web" ] ++ (if withU then [ "extra" ] else [ ]);
              b.aspects = [ "web" ];
              c.aspects = [ "web" ];
            };
          }
        ]).config;
      r = genDelivery.realize { } terminals (
        genDelivery.project {
          inherit selectNodes;
          inherit deliveryClasses;
        } cnf values
      );
    in
    builtins.deepSeq r r;
  pinMap = {
    a.T = "T1";
    b.T = "T1";
    c.T = "T2";
  };

  # The address fixture: `n` carries a and b content, `m` carries b only; terminals a and b.
  addressed =
    extraModules:
    genDelivery.realize { inherit extraModules; }
      {
        a = args: args;
        b = args: args;
      }
      {
        nodes = {
          n = {
            bindings = { };
            classes = {
              a = [ { from = "a"; } ];
              b = [ { from = "b"; } ];
            };
          };
          m = {
            bindings = { };
            classes.b = [ { from = "b"; } ];
          };
        };
      };
in
{
  flake.testsError = {
    # THE MISSING DECLARATION INPUT. Its suite cell asserts THAT the surface refuses; this one
    # asserts it refuses AS the missing category source, which is the half that distinguishes it
    # from the refusal below and from any other throw the projection could produce. `cnf` is a
    # positional operand (den-hoag-7gp66 P2), so its absence is written as `null`, the absent state.
    test-missing-category-source-names-the-input = {
      expr = (genDelivery.project { } null { }).aspects;
      expectedError.msg = exactly missingCategorySource;
    };

    # THE MISSING NODE SELECTOR — the root cause of the hub's silent empty. A default here
    # (`v: v.<name> or { }`) turned a registry spelled anything but `<name>` into a well-typed empty
    # one; the formal now has no default and names itself. `cnf.keySemantics = { }` is LOAD-BEARING,
    # not decoration: the declaration must be present or `requireCnf` fires first under `project`'s
    # `seq` and this cell would assert the wrong refusal while still reading green.
    test-missing-node-selector-names-the-formal = {
      expr = (genDelivery.project { } { keySemantics = { }; } { }).nodes;
      expectedError.msg = exactly noNodeSelector;
    };

    # The caller-supplied selector must return the instance registry. A non-attrset result would
    # otherwise die inside `mapAttrs` as an anonymous "expected a set", naming neither the surface
    # nor the argument that produced it. The declaration IS present here, so the two refusals are
    # reachable independently rather than one shadowing the other.
    test-select-nodes-non-attrset-refuses-by-name = {
      expr =
        (genDelivery.project { selectNodes = _: "not an attrset"; } { keySemantics = { }; } { }).nodes;
      expectedError.msg = exactly "gen-delivery: project: selectNodes must return an attrset of node instances ({ <node> = <instance>; }), got string";
    };

    # A DUPLICATED layer in `layerOrder`. The seeded shape keeps every declared layer present and
    # names no unknown one, so neither sibling refusal in the totality check is reachable — only the
    # duplicate clause can throw here, and the pattern asserts the duplicated layer is NAMED. The
    # empty projection makes the same point the suite's no-nodes cell does: the check is forced at
    # realize's root, not inside the per-node fold.
    test-duplicate-layer-refuses-by-name = {
      expr = genDelivery.realize {
        layerOrder = [
          "projection"
          "projection"
          "global"
          "refinement"
        ];
      } { nixos = args: args; } { nodes = { }; };
      expectedError.msg = exactly duplicateLayer;
    };

    # ── THE ADDRESSED INLET: every address a point of the realization, or a refusal by name ──
    # R0 — THE RETIRED NODE-KEYED SHAPE. The honest migration mistake: read as class `n`, it would be
    # dropped silently. Refused at the root, so the result's own WHNF names it.
    test-node-keyed-extras-refuse-as-the-retired-shape = {
      expr = addressed { n = [ { x = 1; } ]; };
      expectedError.msg = exactly retiredNodeKeyedShape;
    };
    # R1 — the class has no terminal, so nothing realizes it.
    test-extras-for-a-class-with-no-terminal-refuse-by-name = {
      expr = addressed { d.n = [ { x = 1; } ]; };
      expectedError.msg = exactly "gen-delivery: realize: extraModules.d.n addresses class d, which has no terminal — the extras would be dropped";
    };
    # R2 — the node is not projected. Refused on the addressed class's spine.
    test-extras-for-an-unprojected-node-refuse-by-name = {
      expr = (addressed { a.z = [ { x = 1; } ]; }).a;
      expectedError.msg = exactly "gen-delivery: realize: extraModules.a addresses node z, which the projection does not carry — the extras would be dropped";
    };
    # R3 — the node carries no declared content for the class, so the class does not realize there
    # and the extras cannot create a realization. `m` IS projected (it realizes b), so R2 cannot
    # shadow this refusal.
    test-extras-where-the-class-does-not-realize-refuse-by-name = {
      expr = (addressed { a.m = [ { x = 1; } ]; }).a;
      expectedError.msg = exactly noDeclaredContent;
    };

    # R4 — DECLARED CONTENT addressed to a class with no terminal: the content arm of R1, refused
    # at the root for the same reason.
    test-content-for-a-class-with-no-terminal-refuses-by-name = {
      expr =
        (genDelivery.realize { } { a = args: args; } {
          nodes.n = {
            bindings = { };
            classes = {
              a = [ { from = "a"; } ];
              d = [ { from = "d"; } ];
            };
          };
        }).a;
      expectedError.msg = exactly "gen-delivery: realize: node n carries declared d content, and class d has no terminal — the content would be dropped";
    };

    # ── THE INCLUDE CLOSURE: each refusal names its subject ──
    # `ci/tests/include-closure.nix` pins that these are catchable and reach-local; these pin WHICH
    # refusal fired, since a closure refusing for the wrong reason reads green there.
    test-member-naming-no-aspect-names-it = {
      expr = closureClasses [ "a" "ghost" ] [ { aspects.a.nixos.marks = [ "a" ]; } ];
      expectedError.msg = exactly memberUnknown;
    };
    test-declaration-member-names-the-node = {
      expr = closureClasses [ { nixos.marks = [ "decl" ]; } ] [ ];
      expectedError.msg = exactly memberNotIdentifier;
    };
    test-foreign-include-names-origin-and-position = {
      expr =
        closureClasses
          [ "a" ]
          [
            {
              aspects.a.includes = [
                (aspects.keyRef {
                  origin = [ "acme" ];
                  path = [ "ssh" ];
                })
              ];
            }
          ];
      expectedError.msg = exactly foreignInclude;
    };
    # A context closure at an include position is refused UPSTREAM, by gen-aspects, naming the door;
    # the user still meets a named refusal for this input.
    test-sealed-include-names-the-position = {
      expr = closureClasses [ "a" ] [ { aspects.a.includes = [ hostFn ]; } ];
      expectedError.msg = upstreamClosureRefusal "a.includes.[definition 1-entry 1]";
    };
    # The shape that reaches delivery's own sealed-include refusal: a guard at the include position.
    test-sealed-guard-include-names-the-position = {
      expr = closureClasses [ "a" ] [ { aspects.a.includes = [ hostGuard ]; } ];
      expectedError.msg = exactly (sealedInclude "0");
    };
    # At depth, the position is the path of indices through each level's `includes`.
    test-nested-sealed-include-names-the-position-path = {
      expr =
        closureClasses
          [ "a" ]
          [
            {
              aspects.a.includes = [
                {
                  nixos.marks = [ "i" ];
                  includes = [
                    { nixos.marks = [ "j" ]; }
                    hostFn
                  ];
                }
              ];
            }
          ];
      expectedError.msg = upstreamClosureRefusal "a.includes.[definition 1-entry 1].includes.[definition 1-entry 2]";
    };
    # Inside inline content, the refusal names the anonymous node and then the aspect it was written
    # in, and the position is still the path from that aspect.
    test-nested-sealed-guard-include-names-the-position-path = {
      expr =
        closureClasses
          [ "a" ]
          [
            {
              aspects.a.includes = [
                {
                  nixos.marks = [ "i" ];
                  includes = [
                    { nixos.marks = [ "j" ]; }
                    hostGuard
                  ];
                }
              ];
            }
          ];
      expectedError.msg = exactly (
        sealedInlineInclude "a/includes/[\"a:3\",\"aspects\",\"a\",\"includes\",0]" "0.1"
      );
    };
    test-parametric-node-names-it-and-the-interim = {
      expr =
        closureClasses
          [ "p" ]
          [
            { aspects.p.nixos.marks = [ "attr" ]; }
            { aspects.p = hostFn; }
          ];
      expectedError.msg = upstreamClosureRefusal "p";
    };
    test-parametric-guard-node-names-the-node-scope-door = {
      expr =
        closureClasses
          [ "p" ]
          [
            { aspects.p.nixos.marks = [ "attr" ]; }
            { aspects.p = hostGuard; }
          ];
      expectedError.msg = exactly (noInstance "server" "p" null);
    };
    # den-hoag-bgeum (gate C2): gen-aspects publishes a parametric declaration's members, `deferred`
    # where an element reads the context. The closure never walks a guard leaf's members: they exist
    # only where its condition holds. So the reached guard node, handed no instances, reads the
    # no-instance door, never a sealed-content refusal naming a guard its include position does not hold.
    test-parametric-guard-node-with-deferred-member-names-it = {
      expr =
        closureClasses
          [ "p" ]
          [
            {
              aspects.p = aspects.guard (aspects.pred.has "host") { includes = [ (term.readCtx "host" [ ]) ]; };
            }
          ];
      expectedError.msg = exactly (noInstance "server" "p" null);
    };

    # ── THE PROJECTION-PARITY DOOR ──
    # S1: an emptied query refuses by the second arm, naming the least vertex `na`'s walk delivers:
    # `web`, `ha`, and the instances the relation lists at `na` and inside them. The expectation reads
    # the facts and the relation, never `project`, so a broken projection reds this cell alone.
    # RED (the walk alone, no query read): `na` delivers `[ web, inst ×4, ha ]` at rc 0.
    test-emptied-query-names-the-parity-door = {
      expr = fxEmptied.withRel.nodes.na.elementIds;
      expectedError.msg =
        let
          listedIn = e: builtins.concatLists (builtins.attrValues e);
          atNa = listedIn fx.rel.reaches.na;
        in
        exactly (
          parity "na" (least (
            [
              (fx.factIdOf "web")
              (fx.factIdOf "ha")
            ]
            ++ atNa
            ++ builtins.concatMap (i: listedIn (fx.rel.nestedAt.na.${i} or { })) atNa
          )) false
        );
    };
    # S3: an instance `reaches.na` lists and `na`'s include sites never reach refuses by the first
    # arm, naming the least over-listed vertex (`ei@nei` or an instance nested in it). RED (the walk
    # alone): `na` delivers unchanged at rc 0.
    test-over-listed-relation-names-the-parity-door = {
      expr = overlisted;
      expectedError.msg = exactly (
        parity "na" (least (
          [ eiAtNei ] ++ builtins.concatLists (builtins.attrValues (fx.rel.nestedAt.na.${eiAtNei} or { }))
        )) true
      );
    };

    # ── THE INSTANCE RELATION'S DOORS (den-hoag-wpn8c) ──
    # W3: a node the relation was handed no scope for reaches `p`; undecided, so it refuses.
    test-unhanded-node-reaching-a-parametric-node-names-the-node-scope-door = {
      expr = fx.mW "nmiss";
      expectedError.msg = exactly (noInstance "nmiss" "p" null);
    };
    # den-hoag-n8wb5, the undecided door under the OPEN world: `has user` over a scope with no user is
    # refused by the evaluator (R), so the relation neither lists nor declines `hm` (`nh`, `nhe`
    # nested); `nomit`'s TRUE `p` was never walked, its member omitted from the scope.
    test-condition-false-reach-names-the-undecided-door = {
      expr = fx.mW "nh";
      expectedError.msg = exactly (undecided "nh" "hm" null);
    };
    test-condition-false-nested-reach-names-the-undecided-door = {
      expr = fx.mW "nhe";
      expectedError.msg = exactly (undecided "nhe" "hm" (fx.iidOf "nhe" "eu"));
    };
    test-omitted-member-names-the-undecided-door = {
      expr = fx.mW "nomit";
      expectedError.msg = exactly (undecided "nomit" "p" null);
    };
    # den-hoag-n8wb5: under the closed world the omitted member still names the undecided door (it was
    # never walked), and a declined list that is not a list names its own door.
    test-omitted-member-closed-world-names-the-undecided-door = {
      expr = fx.mCw "nomit";
      expectedError.msg = exactly (undecided "nomit" "p" null);
    };
    # Arm 1 needs the scope's edge entry: an instance with no `nestedAt.<node>` entry meets the
    # no-instance door even where `declined.nestedAt.<node>` lists the id (a hand-built or sliced
    # relation).
    # RED (arm 1 read before the entry check): `nhe` delivers `[ eu ]`.
    test-declined-without-an-edge-entry-names-the-no-instance-door =
      let
        eu = builtins.head fx.relCw.reaches.nhe.eu;
      in
      {
        expr = fx.withViewCw (
          fx.relCw
          // {
            nestedAt = fx.relCw.nestedAt // {
              nhe = removeAttrs fx.relCw.nestedAt.nhe [ eu ];
            };
          }
        ) "nhe";
        expectedError.msg = exactly (noInstance "nhe" "hm" eu);
      };
    test-declined-not-a-list-names-the-door = {
      expr = fx.withViewCw (
        fx.relCw
        // {
          declined = fx.relCw.declined // {
            reaches = fx.relCw.declined.reaches // {
              nh = "hm";
            };
          };
        }
      ) "nh";
      expectedError.msg = exactly (declinedNotList "nh" "string");
    };
    # K1's boundary: a carrier (`s`, split) admits every tuple, so no listed instance in a handed
    # scope is never a FALSE condition; it refuses.
    test-carrier-without-an-instance-in-a-handed-scope-names-the-node-scope-door = {
      expr = plant {
        reaches = fx.rel.reaches // {
          na = removeAttrs fx.rel.reaches.na [ "s" ];
        };
      };
      expectedError.msg = exactly (noInstance "na" "s" null);
    };
    # W4 (htfv3 I9): `e@nb`'s nested entry is absent, so its `q` is undecided there.
    test-instance-without-a-nested-entry-names-the-instance-scope-door = {
      expr = fx.withView (
        fx.rel
        // {
          nestedAt = fx.rel.nestedAt // {
            nb = { };
          };
        }
      ) "nb";
      expectedError.msg = exactly (noInstance "nb" "q" (fx.iidOf "nb" "e"));
    };
    # W8a: the edge names an instance the relation holds no vertex for.
    test-edge-to-a-missing-vertex-names-it = {
      expr = plant { vertices = removeAttrs fx.rel.vertices [ pAtNa ]; };
      expectedError.msg = exactly "${edgeFrom} from 'na' names instance '${pAtNa}', which it holds no vertex for";
    };
    # W8b: the vertex listed under `p` instantiates another declaration.
    test-edge-to-another-declarations-instance-names-the-i-edge = {
      expr = plant {
        instantiates = fx.rel.instantiates // {
          ${pAtNa} = [ "q" ];
        };
      };
      expectedError.msg = exactly "${edgeFrom} from 'na' lists instance '${pAtNa}' under aspect 'p', and it does not instantiate 'p'";
    };
    # K2: each malformed view shape is refused by a named, catchable door where the walk reads it.
    test-edge-list-not-a-list-names-it = {
      expr = plantEdge "oops";
      expectedError.msg = exactly "${edgeFrom}s from 'na' under aspect 'p' must be a list of instance ids, got string";
    };
    test-edge-id-not-a-string-names-it = {
      expr = plantEdge [ 5 ];
      expectedError.msg = exactly "${edgeFrom} from 'na' under aspect 'p' names an instance with a value of type int, not an instance id (a string)";
    };
    test-vertex-entry-not-an-attrset-names-it = {
      expr = plant {
        vertices = fx.rel.vertices // {
          ${pAtNa} = fx.rel.vertices.${pAtNa} // {
            entry = 5;
          };
        };
      };
      expectedError.msg = exactly "gen-delivery: project: the instance relation's vertex '${pAtNa}' is not an attrset carrying an attrset `entry`";
    };
    test-scope-edges-not-an-attrset-names-it = {
      expr = plant {
        reaches = fx.rel.reaches // {
          na = 5;
        };
      };
      expectedError.msg = exactly "${edgeFrom}s from 'na' must be an attrset { <aspect> = [ <instance id> ]; }, got int";
    };
    # W12 (and D4): the relation is the producer's whole record; a non-record and a partial one refuse.
    test-instances-not-a-relation-names-it = {
      expr = fx.projectWith { instances = 5; };
      expectedError.msg = exactly instancesShape;
    };
    test-instances-partial-relation-names-it = {
      expr = fx.projectWith { instances.vertices = { }; };
      expectedError.msg = exactly instancesShape;
    };

    # ── THE DELIVERY-CLASS MAP: each door names its subject ──
    # E1–E5 are forced at `project`'s root; E6/E7 on the node's `classes` spine; E8 is realize's
    # existing content check, re-asserted under the map.
    test-delivery-classes-not-an-attrset-refuses-by-name = {
      expr = mapped { deliveryClasses = "T1"; };
      expectedError.msg = exactly "gen-delivery: project: deliveryClasses must be an attrset { <node> = { <authored class> = <delivery class>; }; }, got string";
    };
    test-delivery-classes-entry-not-an-attrset-refuses-by-name = {
      expr = mapped {
        deliveryClasses = pinMap // {
          a = "T1";
        };
      };
      expectedError.msg = exactly "gen-delivery: project: deliveryClasses.a must be an attrset { <authored class> = <delivery class>; }, got string";
    };
    test-delivery-classes-unknown-node-refuses-by-name = {
      expr = mapped {
        deliveryClasses = pinMap // {
          z.T = "T1";
        };
      };
      expectedError.msg = exactly "gen-delivery: project: deliveryClasses names node 'z', which the projection does not carry; the entry would readdress nothing";
    };
    # A selector returning a non-attrset is the SELECTOR's fault, so the map's node check must not
    # fire first and blame the entry.
    test-delivery-classes-bad-selector-names-the-selector = {
      expr = mapped {
        deliveryClasses = pinMap;
        selectNodes = _: "oops";
      };
      expectedError.msg = exactly "gen-delivery: project: selectNodes must return an attrset of node instances ({ <node> = <instance>; }), got string";
    };
    test-delivery-classes-undeclared-class-refuses-by-name = {
      expr = mapped {
        deliveryClasses = pinMap // {
          a = {
            T = "T1";
            marks = "T1";
          };
        };
      };
      expectedError.msg = exactly "gen-delivery: project: deliveryClasses.a.marks readdresses 'marks', which is not declared category \"class\" in cnf";
    };
    test-delivery-classes-non-string-target-refuses-by-name = {
      expr = mapped {
        deliveryClasses = pinMap // {
          a.T = [
            "T1"
            "T2"
          ];
        };
      };
      expectedError.msg = exactly "gen-delivery: project: deliveryClasses.a.T must be one delivery class name (a string), got list; an authored class is delivered to exactly one delivery class";
    };
    test-delivery-classes-two-entries-landing-together-refuse-by-name = {
      expr = mapped {
        withU = true;
        deliveryClasses = pinMap // {
          a = {
            T = "T1";
            U = "T1";
          };
        };
      };
      expectedError.msg = exactly "gen-delivery: project: authored classes T, U at node 'a' land in one delivery class 'T1' under deliveryClasses; their contents would merge in one terminal";
    };
    # One side is the identity: U was not sent by an entry, and T lands on it.
    test-delivery-classes-entry-landing-on-the-identity-refuses-by-name = {
      expr = mapped {
        withU = true;
        deliveryClasses = pinMap // {
          a.T = "U";
        };
        terminals = {
          U = _: 0;
          T1 = _: 1;
          T2 = _: 2;
        };
      };
      expectedError.msg = exactly "gen-delivery: project: authored classes T, U at node 'a' land in one delivery class 'U' under deliveryClasses; their contents would merge in one terminal";
    };
    test-delivery-classes-missing-entry-refuses-at-the-content-check = {
      expr = mapped {
        deliveryClasses = {
          a.T = "T1";
          b.T = "T1";
        };
      };
      expectedError.msg = exactly "gen-delivery: realize: node c carries declared T content, and class T has no terminal — the content would be dropped";
    };

    # ── THE DOOR CHECKS (den-hoag-7gp66 P2): each refusal names the door, then the primitive ──
    # `ci/tests/doors.nix` pins that these are catchable; these pin WHICH refusal fired. Both doors
    # take their options first, one closed set: an unknown option, a non-set options argument and
    # the old one-record shape (whose first field is not an option) are each refused by name at
    # `f opts`, before any operand.
    test-project-unknown-option-names-the-door = {
      expr = genDelivery.project { notAnOption = 1; };
      expectedError.msg = exactly (
        refusals.unknownOption "gen-delivery.project" [
          "selectNodes"
          "deliveryClasses"
          "instances"
        ] "notAnOption"
      );
    };
    test-project-old-one-record-shape-names-the-door = {
      expr = genDelivery.project {
        cnf.keySemantics = { };
        values = { };
      };
      expectedError.msg = exactly (
        refusals.unknownOption "gen-delivery.project" [
          "selectNodes"
          "deliveryClasses"
          "instances"
        ] "cnf"
      );
    };
    test-project-non-set-names-the-door = {
      expr = genDelivery.project 1;
      expectedError.msg = exactly (
        refusals.optionsNotASet "gen-delivery.project" [
          "selectNodes"
          "deliveryClasses"
          "instances"
        ] 1
      );
    };
    test-realize-unknown-option-names-the-door = {
      expr = genDelivery.realize { notAnOption = 1; };
      expectedError.msg = exactly (
        refusals.unknownOption "gen-delivery.realize" [
          "bindings"
          "refinements"
          "layerOrder"
          "extraModules"
        ] "notAnOption"
      );
    };
    test-realize-old-one-record-shape-names-the-door = {
      expr = genDelivery.realize {
        projected.nodes = { };
        terminals = { };
      };
      expectedError.msg = exactly (
        refusals.unknownOption "gen-delivery.realize" [
          "bindings"
          "refinements"
          "layerOrder"
          "extraModules"
        ] "projected"
      );
    };
    test-realize-non-set-names-the-door = {
      expr = genDelivery.realize 1;
      expectedError.msg = exactly (
        refusals.optionsNotASet "gen-delivery.realize" [
          "bindings"
          "refinements"
          "layerOrder"
          "extraModules"
        ] 1
      );
    };
  };
}
