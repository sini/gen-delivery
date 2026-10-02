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
  ...
}:
let
  t = genMerge.types;
  cnf.keySemantics.nixos.category = "class";

  # `hosts` is a raw attrset rather than a typed registry, so a member can be written as something
  # other than a string (the declaration-member cell) and reach `project` as written.
  tree =
    cnf: mods:
    (genMerge.evalModuleTree {
      modules = [
        ((aspects.mkAspectSchema cnf).mkAspectModule { })
        {
          options.hosts = genMerge.mkOption {
            type = t.attrsOf t.raw;
            default = { };
          };
        }
      ]
      ++ mods;
    }).config;
  server = members: mods: tree cnf ([ { hosts.server.aspects = members; } ] ++ mods);

  projectWith =
    cnf: values:
    genDelivery.project {
      inherit values cnf;
      selectNodes = v: v.hosts;
    };
  realized =
    cnf: values:
    genDelivery.realize {
      projected = projectWith cnf values;
      terminals.nixos =
        { modules, ... }:
        (genMerge.evalModuleTree {
          modules = [ { freeformType = t.lazyAttrsOf t.anything; } ] ++ modules;
        }).config;
    };
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

    # ── G9j / G9j′: a PARAMETRIC node refuses where it is reached (interim) ──
    # A guard definition beside an attrset one folds the whole aspect into a guard carrier, static
    # part included; as the only definition it is a guard leaf. Neither can be delivered, and both
    # used to be dropped with no message.
    test-parametric-node-refuses-when-reached =
      let
        split =
          members:
          server members [
            {
              aspects.p.nixos.marks = [ "attr" ];
              aspects.c.nixos.marks = [ "c" ];
            }
            { aspects.p = hostFn; }
          ];
        single =
          members:
          server members [
            {
              aspects.p = hostFn;
              aspects.c.nixos.marks = [ "c" ];
            }
          ];
      in
      {
        expr = {
          splitReached = refuses (marks (split [ "p" ]));
          splitUnreached = marks (split [ "c" ]);
          singleReached = refuses (marks (single [ "p" ]));
          singleUnreached = marks (single [ "c" ]);
        };
        expected = {
          splitReached = true;
          splitUnreached = [ "c" ];
          singleReached = true;
          singleUnreached = [ "c" ];
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
