# THE INCLUDE CLOSURE — a node receives the content of every aspect its members reach through
# `includes`, and of every piece of inline content written at an include position.
#
# Each cell reads REALIZED marks: every aspect below carries `nixos.marks = [ "<its name>" ]`, the
# terminal folds the node's module list, and the list merge reverses module order, so a value reads
# last-delivered first. A cell that asserted only the class NAMES would pass on a closure that
# delivered one aspect of several.
#
# Every refusal is paired with an UNREACHED control over the same tree: the bad include sits on an
# aspect no member reaches, and the node still realizes. That is what makes each refusal a
# property of reach rather than of the tree.
{
  genDelivery,
  aspects,
  genMerge,
  term,
  ...
}:
let
  fx = import ../parametric-fixture.nix {
    inherit
      genDelivery
      aspects
      genMerge
      term
      ;
  };
  sx = import ../shared-eval-fixture.nix {
    inherit
      genDelivery
      aspects
      genMerge
      term
      ;
  };
  t = genMerge.types;
  cnf.keySemantics.nixos.category = "class";

  # `hosts` is a raw attrset rather than a typed registry, so a member can be written as something
  # other than a string (the declaration-member cell) and reach `project` as written.
  tree =
    cnf: mods:
    (genMerge.evalModuleTree { } (
      [
        ((aspects.mkAspectSchema cnf).mkAspectModule { })
        {
          options.hosts = genMerge.mkOption {
            type = t.attrsOf t.raw;
            default = { };
          };
        }
      ]
      ++ mods
    )).config;
  server = members: mods: tree cnf ([ { hosts.server.aspects = members; } ] ++ mods);

  projectWith = cnf: values: genDelivery.project { selectNodes = v: v.hosts; } cnf values;
  realized =
    cnf: values:
    genDelivery.realize { } {
      nixos =
        { modules, ... }:
        (genMerge.evalModuleTree { } ([ { freeformType = t.lazyAttrsOf t.anything; } ] ++ modules)).config;
    } (projectWith cnf values);
  marksWith = cnf: values: (realized cnf values).nixos.server.marks;
  marks = marksWith cnf;
  nixosCount = values: builtins.length (projectWith cnf values).nodes.server.classes.nixos;

  refuses = e: !(builtins.tryEval (builtins.deepSeq e e)).success;

  # A parametric aspect is a first-order guard: a context closure is refused upstream by gen-aspects
  # (den-hoag-lwbb1 stage 2b), so the shape that still reaches delivery's own refusals is a guard.
  hostFn = aspects.guard (aspects.pred.has "host") { nixos.marks = [ "host" ]; };
  diamond = {
    aspects.base.nixos.marks = [ "base" ];
    aspects.ssh.includes = [ "base" ];
    aspects.ssh.nixos.marks = [ "ssh" ];
    aspects.mon.includes = [
      "base"
      "ssh"
    ];
    aspects.mon.nixos.marks = [ "mon" ];
    aspects.web.includes = [
      "ssh"
      "mon"
    ];
    aspects.web.nixos.marks = [ "web" ];
  };
  sshMarks.aspects.ssh.nixos.marks = [ "ssh" ];
  splitAttr.aspects.p.nixos.marks = [ "attr" ];
  splitFn = extra: {
    aspects.p =
      { config, ... }:
      {
        nixos.marks = [ "fn" ];
      }
      // extra;
  };
  cyclic = {
    nixos.marks = [ "s" ];
    includes = [ cyclic ];
  };
  # The FOREIGN, SEALED, DANGLING and nested-DANGLING includes all sit on `a`; `c` is the control.
  onA =
    includes:
    server
      [ "a" ]
      [
        {
          aspects.a.includes = includes;
          aspects.a.nixos.marks = [ "a" ];
          aspects.c.nixos.marks = [ "c" ];
        }
      ];
  onC =
    includes:
    server
      [ "c" ]
      [
        {
          aspects.a.includes = includes;
          aspects.a.nixos.marks = [ "a" ];
          aspects.c.nixos.marks = [ "c" ];
        }
      ];
  foreignRef = aspects.keyRef {
    origin = [ "acme" ];
    path = [ "ssh" ];
  };
  danglingInline = {
    nixos.marks = [ "i" ];
    includes = [ "nope" ];
  };
in
{
  flake.tests.include-closure = {
    # ── G1: an aspect reached only through an include is delivered ──
    test-include-reaches-the-node = {
      expr =
        let
          v =
            server
              [ "server" ]
              [
                {
                  aspects.ssh.nixos.services.openssh.enable = true;
                  aspects.server.includes = [ "ssh" ];
                  aspects.server.nixos.marks = [ "server" ];
                }
              ];
        in
        {
          openssh = (realized cnf v).nixos.server.services.openssh.enable;
          modules = nixosCount v;
        };
      expected = {
        openssh = true;
        modules = 2;
      };
    };
    # G1′ CONTROL: the same tree with no edge does not deliver it.
    test-no-edge-delivers-nothing-more = {
      expr =
        (realized cnf (
          server
            [ "server" ]
            [
              {
                aspects.ssh.nixos.services.openssh.enable = true;
                aspects.server.includes = [ ];
                aspects.server.nixos.marks = [ "server" ];
              }
            ]
        )).nixos.server.services.openssh.enable or false;
      expected = false;
    };

    # ── G2 / G6: a diamond delivers each aspect once, in breadth-first order ──
    # Delivered web, ssh, mon, base; read reversed by the list merge.
    test-diamond-delivers-once-breadth-first = {
      expr = marks (server [ "web" ] [ diamond ]);
      expected = [
        "base"
        "mon"
        "ssh"
        "web"
      ];
    };
    # G2′: a member listed twice is delivered once.
    test-repeated-member-delivers-once = {
      expr = marks (
        server
          [
            "ssh"
            "ssh"
          ]
          [ diamond ]
      );
      expected = [
        "base"
        "ssh"
      ];
    };
    # G2x: two members with shared reach deliver each aspect once ACROSS the members, not per member.
    test-shared-reach-across-members-delivers-once = {
      expr = marks (
        server
          [
            "mon"
            "ssh"
          ]
          [ diamond ]
      );
      expected = [
        "base"
        "ssh"
        "mon"
      ];
    };

    # ── G3: a cycle between named aspects terminates, each delivered once ──
    test-named-cycle-terminates = {
      expr = marks (
        server
          [ "a" ]
          [
            {
              aspects.a.includes = [ "b" ];
              aspects.a.nixos.marks = [ "a" ];
              aspects.b.includes = [ "a" ];
              aspects.b.nixos.marks = [ "b" ];
            }
          ]
      );
      expected = [
        "b"
        "a"
      ];
    };

    # ── G4: a dangling include refuses where it is reached, and only there ──
    test-dangling-include-refuses-when-reached = {
      expr = {
        reached = refuses (marks (onA [ "nope" ]));
        unreached = marks (onC [ "nope" ]);
      };
      expected = {
        reached = true;
        unreached = [ "c" ];
      };
    };

    # ── G5: ids come from the facts, so a non-empty origin still closes ──
    test-origin-qualified-ids-close = {
      expr = marksWith (cnf // { providerPrefix = [ "acme" ]; }) (
        tree (cnf // { providerPrefix = [ "acme" ]; }) [
          {
            aspects.ssh.nixos.marks = [ "ssh" ];
            aspects.server.includes = [ "ssh" ];
            aspects.server.nixos.marks = [ "server" ];
            hosts.server.aspects = [ "server" ];
          }
        ]
      );
      expected = [
        "ssh"
        "server"
      ];
    };

    # ── G7 / G7b: a member is an aspect identifier that names an aspect ──
    test-member-naming-no-aspect-refuses = {
      expr = {
        ghost = refuses (
          marks (
            server
              [
                "a"
                "ghost"
              ]
              [ { aspects.a.nixos.marks = [ "a" ]; } ]
          )
        );
        declaration = refuses (
          marks (server [ { nixos.marks = [ "decl" ]; } ] [ { aspects.a.nixos.marks = [ "a" ]; } ])
        );
        # CONTROL: the named member alone realizes.
        control = marks (server [ "a" ] [ { aspects.a.nixos.marks = [ "a" ]; } ]);
      };
      expected = {
        ghost = true;
        declaration = true;
        control = [ "a" ];
      };
    };

    # ── G8: a foreign reference on a reached aspect refuses (defaulted, reversible) ──
    test-foreign-include-refuses-when-reached = {
      expr = {
        reached = refuses (marks (onA [ foreignRef ]));
        unreached = marks (onC [ foreignRef ]);
      };
      expected = {
        reached = true;
        unreached = [ "c" ];
      };
    };

    # ── G9: INLINE CONTENT is delivered at its position ──
    test-inline-literal-is-delivered = {
      expr = marks (onA [ { nixos.marks = [ "inline" ]; } ]);
      expected = [
        "inline"
        "a"
      ];
    };
    # G9b: an aspect split across modules (an attrset and a `{ config, ... }:` function) delivers
    # BOTH parts: `aspectType` coerces the function part into inline content.
    test-split-aspect-delivers-every-part = {
      expr = {
        split = marks (
          server
            [ "p" ]
            [
              splitAttr
              (splitFn { })
            ]
        );
        # G9bc CONTROL: the function as the only definition.
        single = marks (server [ "p" ] [ (splitFn { }) ]);
      };
      expected = {
        split = [
          "fn"
          "attr"
        ];
        single = [ "fn" ];
      };
    };
    # G9c: what the split's function part includes is delivered too.
    test-split-aspect-part-includes-are-followed = {
      expr = {
        split = marks (
          server
            [ "p" ]
            [
              sshMarks
              splitAttr
              (splitFn { includes = [ "ssh" ]; })
            ]
        );
        # G9cc CONTROL: the function alone.
        single = marks (
          server
            [ "p" ]
            [
              sshMarks
              (splitFn { includes = [ "ssh" ]; })
            ]
        );
      };
      expected = {
        split = [
          "ssh"
          "fn"
          "attr"
        ];
        single = [
          "ssh"
          "fn"
        ];
      };
    };
    # G9d: inline content inside inline content.
    test-nested-inline-content-is-delivered = {
      expr = marks (onA [
        {
          nixos.marks = [ "outer" ];
          includes = [ { nixos.marks = [ "deep" ]; } ];
        }
      ]);
      expected = [
        "deep"
        "outer"
        "a"
      ];
    };
    # G9f / G9fn: inline content takes the place in the order a named aspect would.
    test-inline-order-equals-named-order =
      let
        common = {
          aspects.x.nixos.marks = [ "x" ];
          aspects.x.includes = [ "q" ];
          aspects.z.nixos.marks = [ "z" ];
          aspects.q.nixos.marks = [ "q" ];
          aspects.a.nixos.marks = [ "a" ];
        };
      in
      {
        expr = {
          inline = marks (
            server
              [ "a" ]
              [
                common
                {
                  aspects.a.includes = [
                    "x"
                    {
                      nixos.marks = [ "y" ];
                      includes = [ "q" ];
                    }
                    "z"
                  ];
                }
              ]
          );
          named = marks (
            server
              [ "a" ]
              [
                common
                {
                  aspects.y.nixos.marks = [ "y" ];
                  aspects.y.includes = [ "q" ];
                  aspects.a.includes = [
                    "x"
                    "y"
                    "z"
                  ];
                }
              ]
          );
        };
        expected = {
          inline = [
            "q"
            "z"
            "y"
            "x"
            "a"
          ];
          named = [
            "q"
            "z"
            "y"
            "x"
            "a"
          ];
        };
      };
    # G9i: two modules each write one literal into `a.includes`, and both carry the same stamped
    # `.key` (`a/includes/0`); delivery keys by POSITION, so neither is lost.
    test-two-literals-with-one-stamp-both-deliver = {
      expr = marks (
        server
          [ "a" ]
          [
            {
              aspects.a.nixos.marks = [ "a" ];
              aspects.a.includes = [ { nixos.marks = [ "one" ]; } ];
            }
            { aspects.a.includes = [ { nixos.marks = [ "two" ]; } ]; }
          ]
      );
      expected = [
        "two"
        "one"
        "a"
      ];
    };

    # ── G9e / G9g: sealed content, and a dangling reference inside inline content, refuse ──
    test-sealed-inline-content-refuses-when-reached = {
      expr = {
        reached = refuses (marks (onA [ hostFn ]));
        unreached = marks (onC [ hostFn ]);
      };
      expected = {
        reached = true;
        unreached = [ "c" ];
      };
    };
    test-dangling-inside-inline-content-refuses-when-reached = {
      expr = {
        reached = refuses (marks (onA [ danglingInline ]));
        unreached = marks (onC [ danglingInline ]);
      };
      expected = {
        reached = true;
        unreached = [ "c" ];
      };
    };

    # ── G9j / G9j′: a reached PARAMETRIC node is delivered through its instances (den-hoag-wpn8c) ──
    # A guard definition beside an attrset one folds the whole aspect into a guard carrier, static
    # part included (`s`); as the only definition it is a guard leaf (`p`). Both are delivered from
    # the instance the relation lists at the node; with no relation, both refuse by name.
    test-parametric-node-is-delivered-when-reached = {
      expr = {
        split = builtins.all (m: builtins.elem m (fx.mW "na")) [
          "attr"
          "guard"
        ];
        single = builtins.elem "p" (fx.mW "na");
        withoutInstances = refuses (fx.marksOf fx.noRel "na");
        unreached = fx.mW "nc";
      };
      expected = {
        split = true;
        single = true;
        withoutInstances = true;
        unreached = [ "c" ];
      };
    };
    # W1 (htfv3 I1, I5): `na` and `nb` reach `e` through static `web`, and each instance's
    # context-computed include names its own host.
    test-instances-vary-by-entity = {
      expr = {
        na = fx.mW "na";
        nb = fx.mW "nb";
      };
      expected = {
        na = [
          "ha"
          "web"
          "q"
          "e"
          "guard"
          "attr"
          "p"
        ];
        nb = [
          "hb"
          "web"
          "r"
          "q"
          "e"
        ];
      };
    };
    # W5a / W5b (htfv3 I4, I4b): `q` nested inside `e`'s instance, and inside inline content of `ei`'s.
    test-nested-instances-are-delivered = {
      expr = {
        inInstance = builtins.elem "q" (fx.mW "nb");
        inInlineContent = fx.mW "nei";
      };
      expected = {
        inInstance = true;
        inInlineContent = [
          "q"
          "ei-inline"
        ];
      };
    };
    # W6 (htfv3 I7): static `hb`, reached inside `e@nb`, is walked at node scope, so its parametric
    # `r` resolves through `reaches.nb`, never `nested`.
    test-static-node-in-an-instance-walks-at-node-scope = {
      expr = builtins.elem "r" (fx.mW "nb");
      expected = true;
    };
    # W7 (htfv3 I8, delivery half): `fan` admits only the two user descendants, and both siblings are
    # delivered, in the producer's edge order: the descendants' IDENTIFIER order, canonical (gen-aspects
    # `instancesFor`, ruling 13). The realized list is that order REVERSED by the list merge, so `nf`'s
    # `[ u1 u2 ]` (uA, uB) reads `[ uB uA ]`, and `nfr`'s `[ w1 w2 ]`, the same values under
    # identifiers in the other order, reads `[ uA uB ]`. RED (siblings by identity, `seed-idorder`; or
    # by instance id, `seed-iid`): the two arms do not flip.
    test-fan-out-delivers-every-sibling = {
      expr = {
        declared = fx.mW "nf";
        reversed = fx.mW "nfr";
      };
      expected = {
        declared = [
          "uB"
          "uA"
        ];
        reversed = [
          "uA"
          "uB"
        ];
      };
    };
    # ── htfv3 U3: element identity beside delivered content (`elementIds`) ──
    # B1 (I2): each delivered element's id, positionally beside `classes` — a named node's facts id, an
    # instance's vertex id, inline content its anonymous declaration's id (den-hoag-8hlo3). S is one vertex a and b both reach, so one id; each
    # entity's E is its own. RED (an id per reaching node): S's id differs at a and b; (the view
    # `remint`, b's S under a fresh id on the same vertex): b's id differs while its marks do not, so
    # this cell alone gates it.
    test-element-ids-name-what-was-delivered = {
      expr = {
        a = sx.shared.nodes.a.elementIds.T1;
        b = sx.shared.nodes.b.elementIds.T1;
        c = sx.shared.nodes.c.elementIds.T2;
        remint = {
          id = builtins.head sx.remint.nodes.b.elementIds.T1;
          marks = sx.marksOf sx.remint.nodes.b.classes.T1 == sx.marksOf sx.shared.nodes.b.classes.T1;
        };
      };
      expected = {
        a = [
          sx.sA
          (sx.eOf "a")
          "w"
          "ha"
          "w/includes/[\"a:2\",\"aspects\",\"w\",\"includes\",0]"
        ];
        b = [
          sx.sA
          (sx.eOf "b")
          "w"
          "hb"
          "w/includes/[\"a:2\",\"aspects\",\"w\",\"includes\",0]"
        ];
        c = [
          (sx.eOf "c")
          "w"
          "hc"
          "w/includes/[\"a:2\",\"aspects\",\"w\",\"includes\",0]"
        ];
        remint = {
          id = "aspect-instance:remint-b";
          marks = true;
        };
      };
    };
    # B2: `elementIds` and `classes` have one key set and one length per class at every node; `nx`,
    # reached with no class content, is in neither. RED (ids over every reached item): a's lengths differ.
    test-element-ids-align-with-classes = {
      expr = builtins.mapAttrs (
        n: _:
        let
          node = sx.shared.nodes.${n};
        in
        builtins.attrNames node.elementIds == builtins.attrNames node.classes
        && builtins.all (k: builtins.length node.elementIds.${k} == builtins.length node.classes.${k}) (
          builtins.attrNames node.classes
        )
      ) sx.dc;
      expected = {
        a = true;
        b = true;
        c = true;
      };
    };
    # B3 (map × instances): instance content follows the delivery-class map, so a and b realize under
    # T1 (pin p1, peers a and b) with their S and E, c under T2, and `elementIds` is keyed as `classes`.
    # RED (ids keyed by authored class): keys `T`; (instance items deliver no classes): no `e`, `s`.
    test-instances-follow-the-delivery-class-map = {
      expr = {
        realized = builtins.mapAttrs (
          _: builtins.mapAttrs (_: r: { inherit (r) pin marks peers; })
        ) sx.realized;
        keys = builtins.mapAttrs (n: _: builtins.attrNames sx.shared.nodes.${n}.elementIds) sx.dc;
      };
      expected = {
        realized = {
          T1 = {
            a = {
              pin = "p1";
              marks = [
                "inl"
                "ha"
                "w"
                "e"
                "s"
              ];
              peers = [
                "a"
                "b"
              ];
            };
            b = {
              pin = "p1";
              marks = [
                "inl"
                "hb"
                "w"
                "e"
                "s"
              ];
              peers = [
                "a"
                "b"
              ];
            };
          };
          T2.c = {
            pin = "p2";
            marks = [
              "inl"
              "hc"
              "w"
              "e"
            ];
            peers = [ "c" ];
          };
        };
        keys = {
          a = [ "T1" ];
          b = [ "T1" ];
          c = [ "T2" ];
        };
      };
    };
    # B4 (I8, ids half): each fan-out sibling is its own element, and the first two ids are the
    # relation's edge list exactly. RED (an id per reaching node): they differ.
    test-fan-out-siblings-are-their-own-elements = {
      expr = builtins.genList (builtins.elemAt sx.fanned.nodes.f.elementIds.T) 2;
      expected = sx.rel.reaches.f.fan;
    };
    # B5 (I6, C2's direct-member domain): per entity, the realized digest of the shared arm equals the
    # desugared cold arm's. The views name what parity discriminates: `merged` (every entity reads
    # a's E) moves b and c; `rotated` (each E vertex holds another entity's application) moves all three.
    test-shared-evaluation-is-parity-with-the-cold-arm =
      let
        moved =
          p: builtins.filter (n: (sx.parity p).${n} != (sx.parity sx.cold).${n}) (builtins.attrNames sx.dc);
      in
      {
        expr = {
          shared = moved sx.shared;
          merged = moved sx.merged;
          rotated = moved sx.rotated;
        };
        expected = {
          shared = [ ];
          merged = [
            "b"
            "c"
          ];
          rotated = [
            "a"
            "b"
            "c"
          ];
        };
      };
    # W11: a `bindings` read forces no closure, with `instances` passed. `nmiss`'s closure refuses
    # (it is handed no scope), so a bindings read that walked it would refuse too.
    test-bindings-read-forces-no-closure-with-instances = {
      expr = {
        bindings = fx.withRel.nodes.nmiss.bindings.node.aspects;
        closureRefuses = refuses (fx.mW "nmiss");
      };
      expected = {
        bindings = [ "p" ];
        closureRefuses = true;
      };
    };
    # den-hoag-n8wb5: a reach the relation DECLINED (its condition resolved FALSE there) is no edge
    # (ADR-0019): under the closed world `nh` (no users) reaches `has user` `hm` directly and receives
    # only `home`; `nhe` receives `eu`, its nested `hm` declined at `eu`'s tuple. `nomit` reaches TRUE
    # `p`, a member its handed scope omits: never walked, so undecided, and it refuses (read on the
    # `classes` spine, where a delivered nothing is an empty set and not an uncatchable missing class).
    # Controls: `nhu`
    # (a user descendant) and `nhanded` (`p` handed) deliver. RED (head: the retired refusal): `direct`
    # and `nested` refuse; (seed: absence reads as declined): `omittedMember` = false.
    test-declined-reach-delivers-nothing = {
      expr = {
        direct = fx.mCw "nh";
        nested = fx.mCw "nhe";
        omittedMember = refuses fx.withRelCw.nodes.nomit.classes;
        conditionTrue = fx.mCw "nhu";
        memberHanded = fx.mCw "nhanded";
      };
      expected = {
        direct = [ "home" ];
        nested = [ "eu" ];
        omittedMember = true;
        conditionTrue = [
          "home"
          "hm"
        ];
        memberHanded = [ "p" ];
      };
    };
    # ADR-0019: `nh`'s `home` includes the declined `hm`, and it projects exactly what `home` without
    # that include projects, class set and marks. RED (head: the interim refusal): refused.
    test-declined-reach-equals-an-absent-include = {
      expr =
        let
          a = fx.withRelCw;
          b = fx.withoutHmCw;
        in
        {
          same =
            builtins.attrNames a.nodes.nh.classes == builtins.attrNames b.nodes.nh.classes
            && fx.marksOf a "nh" == fx.marksOf b "nh";
          marks = fx.marksOf a "nh";
        };
      expected = {
        same = true;
        marks = [ "home" ];
      };
    };
    # Under the OPEN world (no declared coordinate set) `has user` over a scope with no user is refused
    # by the evaluator (R): the relation neither lists nor declines `hm`, so the reach refuses, as the
    # omitted member does. RED (a producer that reads R as FALSE): `direct` and `nested` deliver.
    test-empty-reach-in-a-handed-scope-refuses = {
      expr = {
        direct = refuses (fx.mW "nh");
        nested = refuses (fx.mW "nhe");
        omittedMember = refuses fx.withRel.nodes.nomit.classes;
        conditionTrue = fx.mW "nhu";
        memberHanded = fx.mW "nhanded";
      };
      expected = {
        direct = true;
        nested = true;
        omittedMember = true;
        conditionTrue = [
          "home"
          "hm"
        ];
        memberHanded = [ "p" ];
      };
    };
    # den-hoag-ehkse: two guards with one condition and one non-class body, at two paths, are two
    # declarations (identity design §1), so each delivers its own marks. RED (a guard keyed by its
    # term): one instance listed under both, and the `I`-edge door refuses it. Control: distinct
    # descriptions deliver both in either arm.
    test-equal-body-guards-at-two-paths-deliver-both = {
      expr = {
        collide = fx.collide.marks;
        distinct = fx.distinct.marks;
      };
      expected = {
        collide = [
          "y"
          "x"
        ];
        distinct = [
          "y"
          "x"
        ];
      };
    };

    # den-hoag-gywcg: `aspects."f/x"` beside `aspects.f.x` are two declarations, and a node whose
    # members name both receives both. RED (a raw "/" join): both render `f/x`, so the registry holds
    # one and the `"f/x"` content is dropped at exit 0. Control: `f.y` beside `f.x` delivers both in
    # either arm.
    test-a-separator-segment-and-its-nesting-deliver-both =
      let
        sorted =
          y:
          builtins.sort builtins.lessThan (
            marks (
              server
                [
                  (aspects.pathKey [ y ])
                  (aspects.pathKey [
                    "f"
                    "x"
                  ])
                ]
                [
                  {
                    aspects.${y}.nixos.marks = [ "slash" ];
                    aspects.f.x.nixos.marks = [ "nested" ];
                  }
                ]
            )
          );
      in
      {
        expr = {
          separator = sorted "f/x";
          ctl = sorted "y";
        };
        expected = {
          separator = [
            "nested"
            "slash"
          ];
          ctl = [
            "nested"
            "slash"
          ];
        };
      };

    # ── G9k: self-referential inline content refuses by name rather than exhausting memory ──
    test-cyclic-inline-content-refuses = {
      expr = {
        cyclic = refuses (marks (onA [ cyclic ]));
        # CONTROL: finite nesting delivers (G9d's shape).
        finite = marks (onA [
          {
            nixos.marks = [ "outer" ];
            includes = [ { nixos.marks = [ "deep" ]; } ];
          }
        ]);
      };
      expected = {
        cyclic = true;
        finite = [
          "deep"
          "outer"
          "a"
        ];
      };
    };
  };
}
