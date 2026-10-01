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
  lib,
  aspects,
  genMerge,
  ...
}:
let
  exactly = msg: "^" + lib.escapeRegex msg + "$";

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
        (genMerge.evalModuleTree {
          modules = [
            ((aspects.mkAspectSchema cnf).mkAspectModule { })
            {
              options.hosts = genMerge.mkOption {
                type = genMerge.types.attrsOf genMerge.types.raw;
                default = { };
              };
            }
            { hosts.server.aspects = members; }
          ]
          ++ mods;
        }).config;
    in
    builtins.attrNames
      (genDelivery.project {
        inherit values cnf;
        selectNodes = v: v.hosts;
      }).nodes.server.classes;
  hostFn =
    { host, ... }:
    {
      nixos.marks = [ host.name ];
    };

  memberUnknown = "gen-delivery: project: node 'server' names aspect 'ghost' as a member, and no aspect has that key";
  memberNotIdentifier =
    "gen-delivery: project: node 'server' lists a member that is not an aspect identifier (a set); "
    + "a member is named by its aspect's key";
  foreignInclude =
    "gen-delivery: project: aspect 'a' includes at position 0 a reference into origin 'acme', which "
    + "this tree does not hold; project delivers only what it can reach, so federate the trees first";
  sealedInclude =
    position:
    "gen-delivery: project: aspect 'a' carries at include position ${position} parametric content (a "
    + "guard, a wrapped function or a deferred include), which delivery cannot evaluate before "
    + "parametric aspects are specified (ADR-0010 section 4)";
  guardLeaf =
    "gen-delivery: project: aspect 'p' is parametric (a guard or a wrapped function, including an "
    + "aspect with a `{ host, ... }:` definition), so none of its parts can be delivered before "
    + "parametric aspects are specified (ADR-0010 section 4); this refusal is interim and replaces a "
    + "silent drop";

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
        (genMerge.evalModuleTree {
          modules = [
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
          ];
        }).config;
      r = genDelivery.realize {
        projected = genDelivery.project {
          inherit
            values
            cnf
            selectNodes
            deliveryClasses
            ;
        };
        inherit terminals;
      };
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
    genDelivery.realize {
      projected.nodes = {
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
      terminals = {
        a = args: args;
        b = args: args;
      };
      inherit extraModules;
    };
in
{
  flake.testsError = {
    # THE MISSING DECLARATION INPUT. Its suite cell asserts THAT the surface refuses; this one
    # asserts it refuses AS the missing category source, which is the half that distinguishes it
    # from the refusal below and from any other throw the projection could produce.
    test-missing-category-source-names-the-input = {
      expr = (genDelivery.project { values = { }; }).aspects;
      expectedError.msg = exactly missingCategorySource;
    };

    # THE MISSING NODE SELECTOR — the root cause of the hub's silent empty. A default here
    # (`v: v.<name> or { }`) turned a registry spelled anything but `<name>` into a well-typed empty
    # one; the formal now has no default and names itself. `cnf.keySemantics = { }` is LOAD-BEARING,
    # not decoration: the declaration must be present or `requireCnf` fires first under `project`'s
    # `seq` and this cell would assert the wrong refusal while still reading green.
    test-missing-node-selector-names-the-formal = {
      expr =
        (genDelivery.project {
          values = { };
          cnf.keySemantics = { };
        }).nodes;
      expectedError.msg = exactly noNodeSelector;
    };

    # The caller-supplied selector must return the instance registry. A non-attrset result would
    # otherwise die inside `mapAttrs` as an anonymous "expected a set", naming neither the surface
    # nor the argument that produced it. The declaration IS present here, so the two refusals are
    # reachable independently rather than one shadowing the other.
    test-select-nodes-non-attrset-refuses-by-name = {
      expr =
        (genDelivery.project {
          values = { };
          cnf.keySemantics = { };
          selectNodes = _: "not an attrset";
        }).nodes;
      expectedError.msg = exactly "gen-delivery: project: selectNodes must return an attrset of node instances ({ <node> = <instance>; }), got string";
    };

    # A DUPLICATED layer in `layerOrder`. The seeded shape keeps every declared layer present and
    # names no unknown one, so neither sibling refusal in the totality check is reachable — only the
    # duplicate clause can throw here, and the pattern asserts the duplicated layer is NAMED. The
    # empty projection makes the same point the suite's no-nodes cell does: the check is forced at
    # realize's root, not inside the per-node fold.
    test-duplicate-layer-refuses-by-name = {
      expr = genDelivery.realize {
        projected.nodes = { };
        terminals.nixos = args: args;
        layerOrder = [
          "projection"
          "projection"
          "global"
          "refinement"
        ];
      };
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
        (genDelivery.realize {
          projected.nodes.n = {
            bindings = { };
            classes = {
              a = [ { from = "a"; } ];
              d = [ { from = "d"; } ];
            };
          };
          terminals.a = args: args;
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
    test-sealed-include-names-the-position = {
      expr = closureClasses [ "a" ] [ { aspects.a.includes = [ hostFn ]; } ];
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
      expectedError.msg = exactly (sealedInclude "0.1");
    };
    test-parametric-node-names-it-and-the-interim = {
      expr =
        closureClasses
          [ "p" ]
          [
            { aspects.p.nixos.marks = [ "attr" ]; }
            { aspects.p = hostFn; }
          ];
      expectedError.msg = exactly guardLeaf;
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

    # ── THE DOOR CHECKS (den-hoag-7gp66 P1): each refusal names the door, then the primitive ──
    # `ci/tests/doors.nix` pins that these are catchable; these pin WHICH refusal fired.
    test-project-missing-required-field-names-the-door = {
      expr = genDelivery.project { cnf.keySemantics = { }; };
      expectedError.msg = exactly "gen-delivery.project: required field 'values' is missing (required: 'values') (in prelude.checkRequired)";
    };
    test-project-unknown-option-names-the-door = {
      expr = genDelivery.project {
        values = { };
        notAnOption = 1;
      };
      expectedError.msg = exactly "gen-delivery.project: 'notAnOption' is not an option of this door; the options are closed (accepted: 'values', 'cnf', 'selectNodes', 'deliveryClasses') (in prelude.checkOptions)";
    };
    test-project-non-set-names-the-door = {
      expr = genDelivery.project 1;
      expectedError.msg = exactly "gen-delivery.project: the argument must be an attrset, not a int (required: 'values') (in prelude.checkRequired)";
    };
    test-realize-missing-required-field-names-the-door = {
      expr = genDelivery.realize { projected.nodes = { }; };
      expectedError.msg = exactly "gen-delivery.realize: required field 'terminals' is missing (required: 'projected', 'terminals') (in prelude.checkRequired)";
    };
    test-realize-unknown-option-names-the-door = {
      expr = genDelivery.realize {
        projected.nodes = { };
        terminals = { };
        notAnOption = 1;
      };
      expectedError.msg = exactly "gen-delivery.realize: 'notAnOption' is not an option of this door; the options are closed (accepted: 'projected', 'terminals', 'bindings', 'refinements', 'layerOrder', 'extraModules') (in prelude.checkOptions)";
    };
    test-realize-non-set-names-the-door = {
      expr = genDelivery.realize 1;
      expectedError.msg = exactly "gen-delivery.realize: the argument must be an attrset, not a int (required: 'projected', 'terminals') (in prelude.checkRequired)";
    };
  };
}
